import 'dart:math';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_engine/workflow_engine.dart';

import 'human_facing_description.dart';
import 'operator_action_record.dart';
import 'store/workflow_store.dart';

/// Thrown when the workflow policy rejects a transition. The rejected attempt
/// is still appended to the transition history for auditability.
class WorkflowTransitionRejectedException implements Exception {
  WorkflowTransitionRejectedException(this.record);

  final WorkflowTransitionRecord record;

  @override
  String toString() =>
      'Workflow transition rejected: '
      '${record.fromState} -> ${record.toState} (${record.reason ?? 'no reason'})';
}

/// A durable orchestration layer on top of the pure [WorkflowEngine] policy.
///
/// It is the only place workflow state is written: every accepted or rejected
/// transition is appended to the store's history, work items move via
/// compare-and-swap on [WorkItem.version], and human decisions are persisted
/// before any blocking gate is entered. Because execution terminates while
/// waiting for a human and resumes by re-reading the store, the exact policy
/// object used here must be deterministic across restarts (it is: it is
/// constructed from the same pure rule tables).
class DurableWorkflowEngine {
  DurableWorkflowEngine({required WorkflowStore store, WorkflowEngine? policy})
    : _store = store,
      _policy = policy ?? const WorkflowEngine();

  final WorkflowStore _store;
  final WorkflowEngine _policy;
  final Random _random = Random();

  static const WorkflowActor _defaultActor = WorkflowActor(
    actorId: 'orchestrator',
    actorType: ActorType.orchestrator,
  );

  /// Creates a new work item at the authoritative application boundary.
  ///
  /// [description] is required and must be meaningful human-readable prose
  /// (PL-6, effective 2026-09-15): every new `WorkItem` is eligible for a
  /// human-facing control-plane surface. `String?` on the persisted type
  /// remains for legacy records; stores stay permissive so pre-contract data
  /// and tooling can round-trip untouched.
  Future<WorkItem> createWorkItem({
    required String productId,
    required WorkItemCategory category,
    required String title,
    required String description,
    String? workItemId,
    String? designContractId,
    String? agentSessionId,
    String? qaContractId,
    String? featureRef,
    String? requirementRef,
    List<ArtifactReference>? artifactRefs,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) async {
    final violation = humanFacingDescriptionViolation(
      description,
      title: title,
    );
    if (violation != null) {
      throw ArgumentError.value(description, 'description', violation);
    }
    final now = createdAt ?? DateTime.now();
    final item = WorkItem(
      workItemId: workItemId ?? _newId('wi'),
      productId: productId,
      category: category,
      title: title,
      description: description,
      state: WorkItemState.draft,
      designContractId: designContractId,
      agentSessionId: agentSessionId,
      qaContractId: qaContractId,
      featureRef: featureRef,
      requirementRef: requirementRef,
      artifactRefs: artifactRefs,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
      version: 1,
    );
    await _store.saveWorkItem(item);
    return item;
  }

  /// Applies a work item transition through the policy engine. The operation
  /// is idempotent under [idempotencyKey]: replaying the same key returns the
  /// prior outcome instead of re-running the transition. Rejected attempts
  /// are appended to history and raised as
  /// [WorkflowTransitionRejectedException].
  ///
  /// [reason], [operatorAction] and [metadataMerge] are ADDITIVE and all
  /// default to null, which means "behave exactly as today". No existing
  /// caller changes behaviour by omitting them, and every one of them is
  /// written inside the transaction that already moves the work item, so a
  /// crash can never leave the reason, the audit row or the attempt marker
  /// describing a move that did not happen.
  ///
  /// * [reason] — recorded on the transition record. Defaults to the policy's
  ///   own rejection reason, so on an accepted transition it stays null exactly
  ///   as it always has. Supplying it does NOT make the record rejected: the
  ///   outcome is decided by whether the policy accepted the edge, never by
  ///   whether a reason was written.
  /// * [operatorAction] — appended to the audit ledger through the SAME
  ///   transaction handle the item and the transition record are written with.
  ///   A rejected transition takes the path below before any transaction
  ///   opens, so a refused action writes NO audit row: nothing was taken, so
  ///   there is nothing to audit, and the rejected transition record already
  ///   carries the attempt and its idempotency key.
  /// * [metadataMerge] — MERGED into [WorkItem.metadata], never replacing it.
  ///   A replace would silently wipe the defect payload the triage instruction
  ///   reads, producing a retried job that classifies nothing while looking
  ///   healthy. See [operatorRetry] for the caller that relies on this.
  Future<WorkItem> transition({
    required String workItemId,
    required WorkItemState to,
    required TransitionTrigger trigger,
    WorkflowActor actor = _defaultActor,
    Map<String, dynamic> context = const {},
    String? decisionId,
    String? idempotencyKey,
    String? reason,
    OperatorActionRecord? operatorAction,
    Map<String, dynamic>? metadataMerge,
  }) async {
    final item = await _store.readWorkItem(workItemId);

    if (idempotencyKey != null) {
      final prior = await _store.findTransitionByIdempotencyKey(
        workItemId,
        idempotencyKey,
      );
      if (prior != null) {
        if (prior.outcome == TransitionOutcome.accepted) {
          return _store.readWorkItem(workItemId);
        }
        throw WorkflowTransitionRejectedException(prior);
      }
    }

    if (to == item.state) {
      final rejectedRecord = _buildRecord(
        item,
        from: item.state,
        to: to,
        trigger: trigger,
        actor: actor,
        decisionId: decisionId,
        reason: 'Work item is already in state ${item.state}',
        idempotencyKey: idempotencyKey,
      );
      await _store.appendTransitionRecord(rejectedRecord);
      throw WorkflowTransitionRejectedException(rejectedRecord);
    }

    final transition = _policy.evaluateWorkItemTransition(
      from: item.state,
      to: to,
      trigger: trigger,
      actor: actor,
      context: {'workItemId': workItemId, ...context},
      decisionId: decisionId,
    );

    final record = _buildRecord(
      item,
      from: item.state,
      to: to,
      trigger: trigger,
      actor: actor,
      decisionId: decisionId,
      reason: reason ?? transition.rejectionReason,
      // The outcome follows the POLICY, not the presence of a reason. Before
      // `reason` was a parameter the two were the same thing — an accepted
      // transition had no reason to record — so inferring the outcome from
      // `reason == null` would silently relabel an accepted retry as
      // `rejected` the moment an operator supplied their own text.
      outcome: transition.isValid
          ? TransitionOutcome.accepted
          : TransitionOutcome.rejected,
      guardEvaluations: transition.guardResults
          .map(
            (g) => TransitionGuardEvaluation(
              guardName: g.name,
              passed: g.passed,
              message: g.message,
            ),
          )
          .toList(),
      idempotencyKey: idempotencyKey,
    );

    if (!transition.isValid) {
      await _store.appendTransitionRecord(record);
      throw WorkflowTransitionRejectedException(record);
    }

    final now = DateTime.now();
    final updated = item.copyWith(
      state: to,
      updatedAt: now,
      version: item.version + 1,
      blockingHumanDecisionId: to == WorkItemState.waitingForHumanDecision
          ? context['humanDecision'] is HumanDecision
                ? (context['humanDecision'] as HumanDecision).decisionId
                : item.blockingHumanDecisionId
          : identical(to, item.state)
          ? item.blockingHumanDecisionId
          : null,
      blockingReason: to == WorkItemState.waitingForHumanDecision
          ? context['blockingReason'] as String? ??
                'Awaiting human decision at ${DateTime.now().toUtc().toIso8601String()}'
          : null,
      // MERGE, never replace. `WorkItem.copyWith` is
      // `metadata: metadata ?? this.metadata`, so the merged map has to be
      // built before the call; a null [metadataMerge] leaves the item's own
      // map exactly as it was.
      metadata: metadataMerge == null
          ? item.metadata
          : {...?item.metadata, ...metadataMerge},
    );

    final finalItem = updated.copyWith(
      completedAt: to == WorkItemState.completed ? now : updated.completedAt,
      terminatedAt:
          (to == WorkItemState.cancelled || to == WorkItemState.terminated)
          ? now
          : updated.terminatedAt,
    );

    await _store.inTransaction((tx) async {
      try {
        await tx.saveWorkItem(finalItem, expectedVersion: item.version);
      } on ConcurrentModificationException {
        // Rethrown, so the whole transaction rolls back. Nothing has been
        // written yet — the audit row below is never even reached — which is
        // what makes "no audit row without the move" true by ordering rather
        // than by hope.
        rethrow;
      }
      await tx.appendTransitionRecord(record);
      if (operatorAction != null) {
        // Inside the SAME transaction, written through the SAME `tx` handle,
        // and stamped with the transition id minted BEFORE the transaction
        // opened. There is deliberately no path that writes an audit row
        // outside this block.
        await tx.appendOperatorAction(
          operatorAction.copyWith(transitionId: record.transitionId),
        );
      }
    });
    return finalItem;
  }

  /// The actor an operator retry transitions as.
  ///
  /// [ActorType.orchestrator] is the only type the
  /// `agentFailed -> designNotRequired` edge permits, and it is what this
  /// engine already acts as everywhere else. The id names the PATH, not the
  /// person: a human clicking a button is not an orchestrator, and the way
  /// this repository records a human acting through the engine is exactly how
  /// `resolveDecision` does it — the engine performs the move and the human's
  /// identity and stated reason are recorded as data on the same durable
  /// write. No new [ActorType] is introduced and nothing about
  /// `actorIsNotSelf()` changes anywhere.
  static const WorkflowActor operatorRetryActor = WorkflowActor(
    actorId: 'operator-retry',
    actorType: ActorType.orchestrator,
  );

  /// Metadata key carrying the RE-TRIAGE DISCRIMINATOR.
  ///
  /// It lives on the work item because it is the only per-intent discriminator
  /// a `DedupeKeyBuilder` can read: that builder is
  /// `String Function(WorkItem, JobDefinition)` — synchronous, no store, no
  /// request context. An item's original job key is consumed for ever
  /// (`JobQueue.enqueueIfAbsent` refuses a key ANY job holds, terminal or not),
  /// so without this marker the SECOND arrival at a triage entry state would
  /// silently enqueue nothing.
  ///
  /// ## IT COUNTS INTENTS, NOT RETRIES
  ///
  /// It was named for the operator retry because the retry was the only thing
  /// that stamped it, and it was counted from the operator-action ledger for
  /// the same reason. Both are wrong now, and both wrong the same way: an
  /// item reaches a triage entry state by several routes, and a counter that
  /// only knows about one of them hands two different intents the same number.
  ///
  /// It is ONE monotone counter with ONE arithmetic rule, [nextTriageAttempt],
  /// advanced by every human-initiated re-triage — the operator retry and the
  /// resolved rework/reject decisions alike. Two writers, two different rules,
  /// one counter is how the two collide: a rework decision advancing it to 3
  /// while the ledger still counts two retries hands the NEXT operator retry
  /// the number 3 as well, and that retry reuses the key the rework just
  /// consumed — the same silent no-op, reached from the other end.
  ///
  /// Strict monotonicity is the whole safety argument. A number that only ever
  /// goes UP cannot name a key some earlier attempt already holds, whatever
  /// order intents arrive in.
  static const String triageAttemptMetadataKey = 'triageAttempt';

  /// The discriminator stamped on [item], or null when it is ABSENT.
  ///
  /// ## THE ONE READER
  ///
  /// [nextTriageAttempt] and `triageDefectDedupeKey`
  /// (packages/scheduler/lib/src/triage_defect.dart, which builds
  /// `'<workItemId>:triage_defect:a<n>'` from it on every tick) both call this,
  /// so the number the engine stamps and the number the scheduler reads cannot
  /// be derived by two different rules and drift apart. That drift is not
  /// hypothetical: it is the shape of the defect this counter is here to fix.
  ///
  /// `null` is returned for an ABSENT marker and for an explicitly null one,
  /// because both mean the same thing — this work item has never been
  /// re-triaged — and both resolve to the historical, byte-identical
  /// `'<workItemId>:triage_defect'` key. That key is the one every already
  /// persisted job still matches, so the absent case may not change.
  ///
  /// ## WHY A PRESENT-BUT-UNREADABLE MARKER THROWS
  ///
  /// A marker that is present but unreadable must not fall back to the
  /// historical key. That key is already consumed by the terminal job the
  /// re-triage exists to replace, so `enqueueIfAbsent` would return
  /// `created: false` and the human would watch their decision do nothing —
  /// the exact silent-no-op class this marker exists to close, reached through
  /// a type coercion rather than through a missing edge. A loud failure on one
  /// work item is the better of the two failures.
  ///
  /// The forms accepted are every shape the marker legitimately takes on its
  /// way through JSON and back: an `int`, a whole-valued `double` (a `1.0` is
  /// still attempt one, and truncating `1.5` would let two different attempts
  /// collide on one key), and a numeric `String`. Anything else is a defect in
  /// whatever wrote the marker and is reported as one.
  static int? readTriageAttempt(WorkItem item) {
    final marker =
        (item.metadata ?? const <String, dynamic>{})[triageAttemptMetadataKey];
    if (marker == null) return null;
    return switch (marker) {
      final int value => value,
      final double value
          when value.isFinite && value == value.roundToDouble() =>
        value.toInt(),
      final String value when int.tryParse(value) != null => int.parse(value),
      _ => throw FormatException(
        'Unreadable $triageAttemptMetadataKey on work '
        'item ${item.workItemId}: expected an int, a whole-valued double or a '
        'numeric String, got ${marker.runtimeType} ($marker). Falling back to '
        "the historical unsuffixed key would reuse one the previous attempt "
        'already consumed, so the re-triage would enqueue nothing while '
        'looking healthy.',
      ),
    };
  }

  /// The next discriminator value for [item]: strictly greater than both the
  /// value it already carries and [floor].
  ///
  /// ONE arithmetic rule for both writers ([operatorRetry] and
  /// [resolveHumanDecision]) — see [triageAttemptMetadataKey] for why two
  /// rules over one counter collide.
  ///
  /// [floor] lets a caller that knows a higher watermark pass it in without a
  /// second mechanism: [operatorRetry] passes the operator-action ledger
  /// count, so a retry can never be handed a number at or below a retry that
  /// came before it even if the marker itself was tampered with or reset
  /// out-of-band. The default of `0` is right for callers that have no second
  /// watermark, because the marker is then the only record that exists.
  ///
  /// ABSENT means `1`, so the FIRST re-triage of a never-re-triaged item is
  /// `:a1` and never `:a0` — and, critically, is never the unsuffixed
  /// historical key that a terminal job already holds.
  static int nextTriageAttempt(WorkItem item, {int floor = 0}) =>
      max(floor, readTriageAttempt(item) ?? 0) + 1;

  /// The number of `retry` operator actions already recorded for
  /// [workItemId] — the durable audit ledger, never a counter in memory.
  Future<int> operatorRetryCount(String workItemId) async {
    final recorded = await _store.readOperatorActionsForWorkItem(workItemId);
    return recorded
        .where((a) => a.action == OperatorActionKind.retry.wire)
        .length;
  }

  /// The AUDIT position of the next retry of [workItemId] — how many `retry`
  /// rows exist, plus one.
  ///
  /// This is the number written to `OperatorActionRecord.attemptNumber` and
  /// shown to the operator, and it is deliberately NOT the dispatch
  /// discriminator. The two used to be the same value and must no longer be:
  /// a resolved rework decision advances the discriminator without recording a
  /// retry row, so from that point on the audit position and the dedupe
  /// suffix legitimately diverge. Read [nextTriageAttempt] for the latter.
  Future<int> nextOperatorRetryAttempt(String workItemId) async =>
      (await operatorRetryCount(workItemId)) + 1;

  /// Performs ONE operator retry of a failed work item.
  ///
  /// This is the engine half of the retry: it performs the single durable
  /// write and stamps the attempt marker that makes the next dispatch
  /// possible. It deliberately does NOT enqueue a job, does not claim one, and
  /// does not resolve a retry-count limit — the item lands in
  /// `designNotRequired`, which the scheduler already treats as a runnable
  /// entry state, so the ordinary tick does the rest on the ordinary path.
  ///
  /// Ordering, and why each piece is where it is:
  ///
  ///  1. **Replay.** The audit row is unique on `(workItemId, requestId)`, so
  ///     it is the authoritative idempotency record. A caller that replays one
  ///     operator intent — a lost response retried with the same [requestId] —
  ///     finds its own row and returns the current item without writing again.
  ///     This is what makes a network retry mint no second job: there is no
  ///     second write, so there is no second `triageAttempt`, so there is no
  ///     second dedupe key.
  ///  2. **Audit position**, counted from the ledger, NOT from a counter.
  ///     Re-counted on every pass of the bounded loop below, because the
  ///     competing writer may have moved the item on. This is what
  ///     `OperatorActionRecord.attemptNumber` records — how many retries this
  ///     item has had.
  ///  3. **Discriminator**, from [nextTriageAttempt] with the ledger count as
  ///     its floor. This is a DIFFERENT number from step 2 and is no longer
  ///     derived from it: a resolved rework decision advances the same
  ///     discriminator without recording a retry row, so from the first rework
  ///     onward the two legitimately differ. Deriving the marker from the
  ///     ledger alone is what let a decision's fresh key be handed straight
  ///     back to the next retry.
  ///  4. **One transaction.** The state change, the transition record, the
  ///     audit row and the attempt marker are the same commit.
  ///
  /// Two operators pressing retry on one item concurrently both compute the
  /// same discriminator. The work-item compare-and-swap admits one writer; the
  /// loser re-reads, sees the committed marker, and computes a strictly higher
  /// one. That is the correct outcome — two deliberate operator actions are two
  /// attempts — and the loop is the same shape the scheduler's own reclaim
  /// uses.
  ///
  /// A refused action — the item is not in `agent_failed`, the edge does not
  /// apply, another operator already moved it — throws
  /// [WorkflowTransitionRejectedException] and writes NO audit row, because
  /// nothing was taken. The rejected transition record carries the attempt.
  Future<WorkItem> operatorRetry({
    required String workItemId,
    required String requestedBy,
    required String reason,
    required String requestId,
    String? idempotencyKey,
    int maxCompareAndSwapAttempts = 3,
    TransitionTrigger trigger = TransitionTrigger.systemEvent,
    WorkflowActor actor = operatorRetryActor,
  }) async {
    for (var pass = 1; ; pass++) {
      // (1) REPLAY — the audit row is the idempotency record.
      final recorded = await _store.readOperatorActionsForWorkItem(workItemId);
      final prior = recorded.where((a) => a.requestId == requestId).firstOrNull;
      if (prior != null) {
        return _store.readWorkItem(workItemId);
      }

      // (2) AUDIT POSITION — from the ledger, re-counted every pass.
      final auditPosition =
          recorded
              .where((a) => a.action == OperatorActionKind.retry.wire)
              .length +
          1;

      final item = await _store.readWorkItem(workItemId);

      // (3) DISCRIMINATOR — one monotone counter shared with the resolved
      // decision path, with the ledger count as the floor so a retry can never
      // be handed a number at or below an earlier retry. Computed BEFORE the
      // write so an unreadable marker fails with nothing written.
      final attempt = nextTriageAttempt(item, floor: auditPosition - 1);

      try {
        return await transition(
          workItemId: workItemId,
          to: WorkItemState.designNotRequired,
          trigger: trigger,
          actor: actor,
          context: {'operatorRetry': true, 'requestedBy': requestedBy},
          idempotencyKey: idempotencyKey,
          reason: reason,
          // MERGED, never replacing: the defect payload the triage instruction
          // reads must survive, or the retried job classifies nothing while
          // looking healthy.
          metadataMerge: {triageAttemptMetadataKey: attempt},
          operatorAction: OperatorActionRecord(
            actionId: _newId('oa'),
            workItemId: workItemId,
            action: OperatorActionKind.retry.wire,
            fromState: item.state.wire,
            toState: WorkItemState.designNotRequired.wire,
            requestedBy: requestedBy,
            reason: reason,
            requestId: requestId,
            attemptNumber: auditPosition,
            createdAt: DateTime.now().toUtc(),
          ),
        );
      } on ConcurrentModificationException {
        // Another writer took the work item. Re-count and try the whole block
        // again, bounded so a writer continuously rewriting the item cannot
        // make this spin.
        if (pass >= maxCompareAndSwapAttempts) rethrow;
      }
    }
  }

  ///
  /// ## WHY `context` IS BUILT HERE AND NOT LEFT NULL
  ///
  /// `HumanDecision.context` used to be left null on every request, and the
  /// `human_decision` table's `contextJson` column is written straight from it —
  /// so every decision this method ever created persisted an EMPTY `contextJson`.
  /// The persistence layer was faithful; the value handed to it was not there.
  ///
  /// Both fields are derived from facts this method already holds and invents
  /// nothing: [DecisionContext.workflowState] is the state the decision is being
  /// raised FROM (the item is still at `item.state` here — the gate entry
  /// happens below), and [DecisionContext.availableOptions] is the caller's own
  /// option ids, in the caller's order. A caller that passes no options records
  /// an empty list rather than a guess.
  ///
  /// It does NOT carry `metadata`. [DecisionContext] is a closed three-field
  /// shape in `platform_contracts` and has nowhere to put an arbitrary payload;
  /// stuffing a review result into `relatedDecisions` would be a lie about what
  /// that field means. The review result travels on `metadata` (`metadataJson`),
  /// which this method has always persisted — getting it onto the operator's
  /// screen is a wire-contract change in `apps/server/lib/src/generated/` and is
  /// reported separately rather than faked here.
  ///
  /// The pending decision is persisted before the gate is entered, so a crash
  /// between the two leaves a durable (but unused) pending decision. Passing
  /// an explicit [decisionId] makes request retries idempotent.
  Future<HumanDecision> requestHumanDecision({
    required String workItemId,
    required HumanDecisionType decisionType,
    String? question,
    List<HumanDecisionOption>? options,
    String? recommendation,
    bool blocking = true,
    DateTime? requestedAt,
    Map<String, dynamic>? metadata,
    WorkflowActor actor = _defaultActor,
    Map<String, dynamic> extraContext = const {},
    String? decisionId,
  }) async {
    final item = await _store.readWorkItem(workItemId);

    // A retry after a crash mid-gate-entry observes a work item already at
    // the gate with a pending decision of the same type and returns it, which
    // makes request retries with an explicit [decisionId] idempotent.
    if (item.state == WorkItemState.waitingForHumanDecision &&
        item.blockingHumanDecisionId != null) {
      final existing = await _store.readHumanDecision(
        item.blockingHumanDecisionId!,
      );
      if (existing.decisionType == decisionType &&
          !existing.status.isResolved) {
        return existing;
      }
      throw WorkflowTransitionRejectedException(
        _buildRecord(
          item,
          from: item.state,
          to: item.state,
          trigger: TransitionTrigger.humanDecision,
          actor: actor,
          decisionId: item.blockingHumanDecisionId,
          reason: 'Work item is already waiting for a blocking human decision',
        ),
      );
    }

    final id = decisionId ?? _newId('dec');
    final now = requestedAt ?? DateTime.now();
    final decision = HumanDecision(
      decisionId: id,
      workItemId: workItemId,
      decisionType: decisionType,
      status: HumanDecisionStatus.pending,
      question: question,
      context: DecisionContext(
        workflowState: item.state.wire,
        availableOptions:
            options?.map((o) => o.optionId).toList(growable: false) ??
            const <String>[],
      ),
      options: options,
      recommendation: recommendation,
      blocking: blocking,
      requestedAt: now,
      metadata: metadata,
      updatedAt: now,
    );

    final validationContext = {
      'workItemId': workItemId,
      'humanDecision': decision,
      'blockingReason': question ?? 'Awaiting human decision',
      ...extraContext,
    };
    final gateEntry = _policy.evaluateWorkItemTransition(
      from: item.state,
      to: WorkItemState.waitingForHumanDecision,
      trigger: TransitionTrigger.humanDecision,
      actor: actor,
      context: validationContext,
      decisionId: id,
    );

    if (!gateEntry.isValid) {
      final record = _buildRecord(
        item,
        from: item.state,
        to: WorkItemState.waitingForHumanDecision,
        trigger: TransitionTrigger.humanDecision,
        actor: actor,
        decisionId: id,
        reason: gateEntry.rejectionReason,
        guardEvaluations: gateEntry.guardResults
            .map(
              (g) => TransitionGuardEvaluation(
                guardName: g.name,
                passed: g.passed,
                message: g.message,
              ),
            )
            .toList(),
      );
      await _store.appendTransitionRecord(record);
      throw WorkflowTransitionRejectedException(record);
    }

    await _store.inTransaction((tx) async {
      await tx.saveHumanDecision(decision);

      final now2 = DateTime.now();
      final updated = item.copyWith(
        state: WorkItemState.waitingForHumanDecision,
        blockingHumanDecisionId: id,
        blockingReason: question ?? 'Awaiting human decision',
        updatedAt: now2,
        version: item.version + 1,
      );

      try {
        await tx.saveWorkItem(updated, expectedVersion: item.version);
      } on ConcurrentModificationException {
        rethrow;
      }

      final acceptedRecord = _buildRecord(
        item,
        from: item.state,
        to: WorkItemState.waitingForHumanDecision,
        trigger: TransitionTrigger.humanDecision,
        actor: actor,
        decisionId: id,
        guardEvaluations: gateEntry.guardResults
            .map(
              (g) => TransitionGuardEvaluation(
                guardName: g.name,
                passed: g.passed,
                message: g.message,
              ),
            )
            .toList(),
      );
      await tx.appendTransitionRecord(acceptedRecord);
    });

    return decision;
  }

  /// Resolves a pending human decision and, when the (type, choice) routing
  /// unlocks a workflow state, advances the work item out of the gate.
  ///
  /// The resolved decision is persisted before the work item advances. A
  /// retry after a crash observes an already-resolved decision and replays
  /// the unlock, so resolution is idempotent.
  Future<WorkItem> resolveHumanDecision({
    required String decisionId,
    required HumanDecisionChoice choice,
    required String decider,
    required String rationale,
    required DecisionSignature signature,
  }) async {
    final decision = await _store.readHumanDecision(decisionId);
    final item = await _store.readWorkItem(decision.workItemId);

    // A previously resolved decision is treated as an idempotent replay: the
    // already-recorded choice drives the unlock, new arguments are ignored,
    // and the resolved decision is never mutated.
    final alreadyResolved = decision.status.isResolved;
    final effectiveChoice = alreadyResolved && decision.choice != null
        ? decision.choice!
        : choice;
    final effectiveDecider = alreadyResolved && decision.decider != null
        ? decision.decider!
        : decider;
    final effectiveRationale = alreadyResolved && decision.rationale != null
        ? decision.rationale
        : rationale;
    final effectiveSignature = alreadyResolved && decision.signature != null
        ? decision.signature
        : signature;

    final resolvedAt = alreadyResolved && decision.timestamp != null
        ? decision.timestamp!
        : DateTime.now();
    final resolved = HumanDecision(
      decisionId: decision.decisionId,
      workItemId: decision.workItemId,
      decisionType: decision.decisionType,
      status: HumanDecisionStatus.resolved,
      question: decision.question,
      context: decision.context,
      options: decision.options,
      recommendation: decision.recommendation,
      blocking: decision.blocking,
      requestedAt: decision.requestedAt,
      decider: effectiveDecider,
      choice: effectiveChoice,
      rationale: effectiveRationale,
      timestamp: resolvedAt,
      signature: effectiveSignature,
      resolvedOptionId: _resolvedOptionId(decision, effectiveChoice),
      metadata: decision.metadata,
      updatedAt: resolvedAt,
    );

    // Only a blocking decision attached to the work item at the gate can move
    // the workflow. Non-blocking resolutions are recorded and left alone.
    final isBlocking =
        item.blockingHumanDecisionId == decisionId &&
        item.state == WorkItemState.waitingForHumanDecision &&
        decision.blocking != false;

    if (!isBlocking) {
      if (!alreadyResolved) {
        await _store.saveHumanDecision(resolved);
      }
      return item;
    }

    final target = HumanDecisionRouting.targetFor(
      decision.decisionType,
      effectiveChoice,
    );
    if (target == null) {
      if (!alreadyResolved) {
        await _store.saveHumanDecision(resolved);
      }
      return item;
    }

    // Check if this is an escalation transition (review gate reject/rework)
    final isEscalationTransition = _isEscalationTransition(
      decision.decisionType,
      effectiveChoice,
      target,
    );

    // THE RE-TRIAGE DISCRIMINATOR, advanced here and nowhere else.
    //
    // Computed BEFORE `saveHumanDecision` below, and before the policy is even
    // consulted, so that an unreadable marker fails with NOTHING written: the
    // decision stays pending and the human may retry once the data is
    // repaired, instead of finding a resolved decision attached to a work item
    // that never moved.
    //
    // `null` means "this resolution does not re-triage anything" and leaves the
    // item's metadata exactly as it was. See [_isReWorkDecision] for what
    // counts and, more importantly, for what is deliberately NOT asked: the
    // target state.
    final isReWorkDecision = _isReWorkDecision(
      decision.decisionType,
      effectiveChoice,
    );
    final reTriageAttempt = isReWorkDecision ? nextTriageAttempt(item) : null;

    // Prepare context with escalation index and max escalation for validation
    final currentEscalationIndex =
        item.metadata?['escalationIndex'] as int? ?? 0;
    final maxEscalation = _getMaxEscalationForDecisionType(
      decision.decisionType,
    );
    final validationContext = {
      'workItemId': decision.workItemId,
      'humanDecision': resolved,
      'escalationIndex': currentEscalationIndex,
      'maxEscalation': maxEscalation,
    };

    final unlock = _policy.evaluateWorkItemTransition(
      from: WorkItemState.waitingForHumanDecision,
      to: target,
      trigger: TransitionTrigger.humanDecision,
      actor: _defaultActor,
      context: validationContext,
      decisionId: decisionId,
    );

    if (!alreadyResolved) {
      await _store.saveHumanDecision(resolved);
    }

    if (!unlock.isValid) {
      throw WorkflowTransitionRejectedException(
        _buildRecord(
          item,
          from: WorkItemState.waitingForHumanDecision,
          to: target,
          trigger: TransitionTrigger.humanDecision,
          actor: _defaultActor,
          decisionId: decisionId,
          reason: unlock.rejectionReason,
          guardEvaluations: unlock.guardResults
              .map(
                (g) => TransitionGuardEvaluation(
                  guardName: g.name,
                  passed: g.passed,
                  message: g.message,
                ),
              )
              .toList(),
        ),
      );
    }

    final now = DateTime.now();

    // Increment escalation index for escalation transitions
    final updatedMetadata = Map<String, dynamic>.from(item.metadata ?? {});
    if (isEscalationTransition) {
      updatedMetadata['escalationIndex'] = currentEscalationIndex + 1;
    }
    if (reTriageAttempt != null) {
      updatedMetadata[triageAttemptMetadataKey] = reTriageAttempt;
    }

    final updated = item.copyWith(
      state: target,
      blockingHumanDecisionId: null,
      blockingReason: null,
      updatedAt: now,
      version: item.version + 1,
      metadata: updatedMetadata,
    );
    final finalItem = updated.copyWith(
      completedAt: target == WorkItemState.completed
          ? now
          : updated.completedAt,
      terminatedAt:
          (target == WorkItemState.cancelled ||
              target == WorkItemState.terminated)
          ? now
          : updated.terminatedAt,
    );

    await _store.inTransaction((tx) async {
      try {
        await tx.saveWorkItem(finalItem, expectedVersion: item.version);
      } on ConcurrentModificationException {
        rethrow;
      }

      // Append the main transition record
      await tx.appendTransitionRecord(
        _buildRecord(
          item,
          from: WorkItemState.waitingForHumanDecision,
          to: target,
          trigger: TransitionTrigger.humanDecision,
          actor: _defaultActor,
          decisionId: decisionId,
          guardEvaluations: unlock.guardResults
              .map(
                (g) => TransitionGuardEvaluation(
                  guardName: g.name,
                  passed: g.passed,
                  message: g.message,
                ),
              )
              .toList(),
        ),
      );

      // Append EscalationTriggered event for audit trail
      if (isEscalationTransition) {
        await tx.appendTransitionRecord(
          _buildEscalationRecord(
            item,
            decision.decisionType,
            effectiveChoice,
            target,
            currentEscalationIndex + 1,
            decisionId,
          ),
        );
      }
    });
    return finalItem;
  }

  /// True when this (type, choice) resolution means "do this work again".
  ///
  /// This is the predicate that advances [triageAttemptMetadataKey] in
  /// [resolveHumanDecision], and it is the WHOLE of the re-triage rule. It
  /// reads the CHOICE — the human's intent — and deliberately does not read
  /// [target].
  ///
  /// ## WHY THE TARGET STATE IS NOT ASKED
  ///
  /// Two reasons, and the second one is the load-bearing half.
  ///
  /// First, the obvious alternative — "advance whenever the routing table
  /// lands the item on a triage entry state" — needs a list of those states,
  /// and `workflow_store` cannot ask `scheduler` for it: the dependency runs
  /// the other way, so the list would be a copy. This repository has already
  /// been bitten by exactly that copy. `HumanDecisionRouting.escalationTargetFor`
  /// is a second transcription of `targetFor` that has silently diverged from
  /// it on two pairs, and that divergence is documented in
  /// `human_decision_routing.dart` as a real incoherence in the escalation
  /// accounting rather than a theoretical one. A second copy of "which states
  /// re-dispatch for triage" would be a third, in a file with no test that can
  /// notice it going stale.
  ///
  /// Second — and this is why the predicate is safe to make WIDE — over-stamping
  /// costs nothing and under-stamping is the defect. The discriminator only
  /// ever increases, so a bump on a route that turns out not to need one
  /// produces a key nothing holds and the dispatch proceeds normally. A route
  /// that needs a bump and does not get one reuses a key a terminal job already
  /// holds and the item is inert for ever. The asymmetry is total, so the rule
  /// is written to err towards stamping.
  ///
  /// ## THE CHOICES, AND WHY EACH IS HERE
  ///
  ///  * `rework` and `reject` — the two answers that mean the delivered work
  ///    is not accepted and must be produced again. `HumanDecisionRouting`
  ///    sends `(engineeringReview, rework)`, `(qaWaiver, reject)`,
  ///    `(qaRework, reject)` and `(humanQaApproval, reject)` straight to
  ///    `designNotRequired`, a `triageDefectDefinition` entry state, so each of
  ///    them re-enters triage with a key the previous run already consumed.
  ///  * `(escalation, approve)` — the one approve that means "again". It is
  ///    described in `work_item_transitions.dart` as "a human chose to resume
  ///    after a failure was escalated to them", and it routes to
  ///    `designNotRequired` like the four above. It is listed here rather than
  ///    folded into "rework or reject" because a rule keyed on the choice alone
  ///    would miss it, and missing it reintroduces the defect on the exact
  ///    route the dogfood work item took.
  ///
  /// Every other choice — approve, waive, cancel, defer, fixed, stillBroken,
  /// partiallyFixed — expresses either acceptance, abandonment, or a deferral,
  /// and none of them re-enters triage. They leave the discriminator untouched,
  /// which is the "a transition that carries no new intent must not inflate the
  /// counter" half of the rule.
  ///
  /// ## WHAT THIS DELIBERATELY DOES NOT COVER
  ///
  /// Transitions taken through the generic [transition] API are NOT stamped,
  /// including `planned -> designNotRequired` and `reviewRejected ->
  /// designNotRequired`. `transition` is called for ordinary progress as well
  /// as for operator intent, and stamping there would put this key on every
  /// write path in the engine — the thing that would turn a per-intent marker
  /// into a per-transition stamp. The routes that need a stamp reach triage
  /// through a human DECISION or through [operatorRetry], and those are the two
  /// places it is written.
  ///
  /// A consequence worth stating plainly: an item that is moved into a triage
  /// entry state by neither — a data repair, for instance — still arrives
  /// without a fresh discriminator. Repairing that means stamping at the repair
  /// site, which is a deliberate, reviewed act, not something this predicate
  /// can do from the other side of the store.
  bool _isReWorkDecision(
    HumanDecisionType decisionType,
    HumanDecisionChoice choice,
  ) {
    return switch (choice) {
      HumanDecisionChoice.rework => true,
      HumanDecisionChoice.reject => true,
      // The one approve that means "again" — see above.
      HumanDecisionChoice.approve =>
        decisionType == HumanDecisionType.escalation,
      HumanDecisionChoice.waive ||
      HumanDecisionChoice.cancel ||
      HumanDecisionChoice.defer ||
      HumanDecisionChoice.fixed ||
      HumanDecisionChoice.stillBroken ||
      HumanDecisionChoice.partiallyFixed => false,
    };
  }

  /// Checks if a decision resolution constitutes an escalation transition.
  bool _isEscalationTransition(
    HumanDecisionType decisionType,
    HumanDecisionChoice choice,
    WorkItemState target,
  ) {
    if (choice != HumanDecisionChoice.reject &&
        choice != HumanDecisionChoice.rework) {
      return false;
    }
    return HumanDecisionRouting.routesToEscalation(
      decisionType,
      choice,
      target,
    );
  }

  /// Gets the maximum escalation index for a decision type based on the
  /// ModelPolicy chain length.
  int _getMaxEscalationForDecisionType(HumanDecisionType decisionType) {
    // This would typically be fetched from a ModelPolicyStore.
    // For now, return -1 to indicate unlimited (fallback model applies).
    // In a full implementation, this would look up the policy chain length.
    return -1;
  }

  WorkflowTransitionRecord _buildEscalationRecord(
    WorkItem item,
    HumanDecisionType decisionType,
    HumanDecisionChoice choice,
    WorkItemState target,
    int newEscalationIndex,
    String? decisionId,
  ) {
    return WorkflowTransitionRecord(
      transitionId: _newId('tr'),
      workItemId: item.workItemId,
      fromState: WorkItemState.waitingForHumanDecision,
      toState: target,
      trigger: TransitionTrigger.humanDecision,
      actorType: ActorType.orchestrator,
      actorId: 'orchestrator',
      decisionId: decisionId,
      outcome: TransitionOutcome.accepted,
      reason:
          'Escalation triggered: $decisionType ${choice.wire} -> $target (escalationIndex=$newEscalationIndex)',
      guardEvaluations: const [],
      idempotencyKey: 'escalation-$decisionId',
      occurredAt: DateTime.now(),
    );
  }

  Future<WorkItem> loadWorkItem(String workItemId) =>
      _store.readWorkItem(workItemId);

  Future<bool> isWaitingForHumanDecision(String workItemId) async {
    final item = await _store.readWorkItem(workItemId);
    return item.state == WorkItemState.waitingForHumanDecision;
  }

  Future<List<WorkflowTransitionRecord>> transitionHistory(String workItemId) =>
      _store.readTransitionHistory(workItemId);

  WorkflowTransitionRecord _buildRecord(
    WorkItem item, {
    required WorkItemState from,
    required WorkItemState to,
    required TransitionTrigger trigger,
    required WorkflowActor actor,
    String? decisionId,
    String? reason,
    TransitionOutcome? outcome,
    List<TransitionGuardEvaluation> guardEvaluations = const [],
    String? idempotencyKey,
  }) {
    return WorkflowTransitionRecord(
      transitionId: _newId('tr'),
      workItemId: item.workItemId,
      fromState: from,
      toState: to,
      trigger: trigger,
      actorType: actor.actorType,
      actorId: actor.actorId,
      decisionId: decisionId,
      // Callers that pass [outcome] decide it from the policy. Callers that do
      // not keep the original inference, so every pre-existing record — the
      // scheduler's zombie reclaim, `work_entry`, the human-decision unlock —
      // is unchanged byte for byte.
      outcome:
          outcome ??
          (reason == null
              ? TransitionOutcome.accepted
              : TransitionOutcome.rejected),
      reason: reason,
      guardEvaluations: guardEvaluations,
      idempotencyKey: idempotencyKey,
      occurredAt: DateTime.now(),
    );
  }

  String? _resolvedOptionId(
    HumanDecision decision,
    HumanDecisionChoice choice,
  ) {
    final option = decision.options
        ?.where((o) => o.optionId == choice.wire)
        .firstOrNull;
    return option?.optionId ?? choice.wire;
  }

  String _newId(String prefix) {
    final suffix =
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
        '${_random.nextInt(1 << 32).toRadixString(36)}';
    return '$prefix-$suffix';
  }
}
