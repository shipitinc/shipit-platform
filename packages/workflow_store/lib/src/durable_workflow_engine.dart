import 'dart:math';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_engine/workflow_engine.dart';

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

  Future<WorkItem> createWorkItem({
    required String productId,
    required WorkItemCategory category,
    required String title,
    String? workItemId,
    String? description,
    String? designContractId,
    String? agentSessionId,
    String? qaContractId,
    String? featureRef,
    String? requirementRef,
    List<ArtifactReference>? artifactRefs,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) async {
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
  Future<WorkItem> transition({
    required String workItemId,
    required WorkItemState to,
    required TransitionTrigger trigger,
    WorkflowActor actor = _defaultActor,
    Map<String, dynamic> context = const {},
    String? decisionId,
    String? idempotencyKey,
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
      reason: transition.rejectionReason,
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
    );

    final finalItem = updated.copyWith(
      completedAt: to == WorkItemState.completed ? now : updated.completedAt,
      terminatedAt:
          (to == WorkItemState.cancelled || to == WorkItemState.terminated)
          ? now
          : updated.terminatedAt,
    );

    try {
      await _store.saveWorkItem(finalItem, expectedVersion: item.version);
    } on ConcurrentModificationException {
      rethrow;
    }
    await _store.appendTransitionRecord(record);
    return finalItem;
  }

  /// Creates the blocking human decision and enters the human decision gate.
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
    DateTime? expiration,
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
      options: options,
      recommendation: recommendation,
      blocking: blocking,
      requestedAt: now,
      expiration: expiration,
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

    await _store.saveHumanDecision(decision);

    final now2 = DateTime.now();
    final updated = item.copyWith(
      state: WorkItemState.waitingForHumanDecision,
      blockingHumanDecisionId: id,
      blockingReason: question ?? 'Awaiting human decision',
      updatedAt: now2,
      version: item.version + 1,
    );

    try {
      await _store.saveWorkItem(updated, expectedVersion: item.version);
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
    await _store.appendTransitionRecord(acceptedRecord);

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
      expiration: decision.expiration,
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

    final validationContext = {
      'workItemId': decision.workItemId,
      'humanDecision': resolved,
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
    final updated = item.copyWith(
      state: target,
      blockingHumanDecisionId: null,
      blockingReason: null,
      updatedAt: now,
      version: item.version + 1,
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

    try {
      await _store.saveWorkItem(finalItem, expectedVersion: item.version);
    } on ConcurrentModificationException {
      rethrow;
    }

    await _store.appendTransitionRecord(
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
    return finalItem;
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
      outcome: reason == null
          ? TransitionOutcome.accepted
          : TransitionOutcome.rejected,
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
