import 'dart:convert';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
// `scheduler.dart` does not barrel-export its capacity directory yet — see the
// identical, identical-reasoned import in `apps/server/lib/server.dart`, and the
// L1 barrel-export TODO that notes there. Narrow, explicit, and expected to be
// deleted when the barrel exports it.
// ignore: implementation_imports
import 'package:scheduler/src/capacity/execution_capacity.dart'
    show ExecutionCapacityResolution, agentExecutionBudget;
import 'package:serverpod/serverpod.dart';
import 'package:workflow_engine/workflow_engine.dart' show WorkItemTransitions;
import 'package:workflow_store/workflow_store.dart'
    show
        DurableWorkflowEngine,
        OperatorActionKind,
        OperatorActionRecord,
        WorkflowTransitionRejectedException;

import '../generated/execution_capacity_view.dart';
import '../generated/operator_action_summary_view.dart';
import '../generated/work_item_action_context_view.dart';
import '../generated/work_item_action_result.dart';
import '../generated/work_item_action_view.dart';
import '../generated/work_item_failure_view.dart';
import '../services/control_plane_service.dart';
import '../services/ui_view_mappers.dart';

/// The single environment variable that bounds how many times one operator may
/// restart one work item.
///
/// ## WHY IT IS REQUIRED, NOT DEFAULTED (HD-3, `5d9a1f62`)
///
/// The decision says both *"default 3 per work item"* and *"if the limit is
/// unset the retry action is not offered"*. Those are true together under one
/// reading only: **3 is the value operators must configure; there is no
/// fallback constant in this file, and there never will be.** An operator
/// action that spends real credits must never be armed by a missing
/// configuration.
///
/// So there is no `const int defaultMaxRetries = 3;` here, and a reviewer
/// should treat the appearance of one as the defect it would be. The same
/// reasoning is already recorded for the concurrency cap: *"a cap that defaults
/// to 'unlimited' re-creates the host exhaustion it was built to prevent"*
/// (`execution_capacity.dart:88-92`).
const String operatorRetryLimitEnvVar = 'SHIPIT_OPERATOR_MAX_RETRIES';

/// A resolved, usable per-work-item operator-retry limit.
///
/// Private constructor: the only way to obtain one is for
/// [OperatorRetryLimitResolution.fromEnvironment] to have succeeded with a
/// value of zero or more. There is no named constant and no static default,
/// so a caller cannot accidentally hand this screen "unlimited", and cannot
/// hand it a guessed number while logging the guess as fact.
class OperatorRetryLimit {
  const OperatorRetryLimit._({required this.maximumRetriesPerWorkItem});

  /// The operator-configured value: how many times ONE work item may be
  /// restarted.
  ///
  /// **Zero is a resolved value, not a failure.** It means *permanently
  /// disabled* — a deliberate configuration choice, not a broken machine, and
  /// its diagnostic reads as configuration rather than as an error (AC-15c).
  final int maximumRetriesPerWorkItem;

  /// One line naming the resolved value, for the startup log.
  ///
  /// Stated in the success direction as well, for the same reason
  /// `ExecutionCapacity.startupSummary` is: an operator who cannot see the cap
  /// in force cannot tell a bounded button from an absent one.
  String get startupSummary =>
      'operator retry limit resolved: $operatorRetryLimitEnvVar='
      '$maximumRetriesPerWorkItem (maximum operator retries per work item)';

  @override
  String toString() => 'OperatorRetryLimit(max=$maximumRetriesPerWorkItem)';
}

/// The outcome of reading [operatorRetryLimitEnvVar]: either a usable
/// [OperatorRetryLimit], or a named reason why there is none.
///
/// ## WHY THIS DOES NOT REUSE `ExecutionCapacityResolution` (design-brief.md
/// §6.6, reviewer's M1)
///
/// That helper is the right PATTERN — fail closed, name the variable, say what
/// was wrong, never substitute a number — and it is reused here as a pattern
/// only. Its helper is not reusable verbatim, because it resolves
/// `parsed < 1` to UNRESOLVED with a *"below the minimum of 1"* diagnostic
/// (`execution_capacity.dart:156-164`). That is the right answer for a
/// concurrency cap, where `0` would deny all work forever, and the WRONG answer
/// here: `0` is a valid configuration meaning *permanently disabled*, and AC-15c
/// requires it to resolve to a RESOLVED value with a diagnostic that reads as
/// configuration rather than failure.
class OperatorRetryLimitResolution {
  const OperatorRetryLimitResolution({
    required this.diagnostic,
    this.limit,
    this.permanentlyDisabled = false,
  });

  /// The resolved limit, or null when the configuration is unusable or is
  /// zero. Never a fallback value.
  final OperatorRetryLimit? limit;

  /// True when the variable resolved to an explicit `0` — switched off on
  /// purpose, which is a CONFIGURATION and not a failure (AC-15c). Kept apart
  /// from [limit] so the client can word "you have used all three" and
  /// "restarting is switched off here" differently from one flag.
  final bool permanentlyDisabled;

  /// A human-readable, log-line-safe statement naming the variable and what was
  /// wrong with it — or, on success, what was resolved. Safe to log verbatim:
  /// it never contains a credential, only the variable name and the offending
  /// value.
  final String diagnostic;

  /// True when a usable configuration was read: a positive limit, or an
  /// explicit `0` that switches restarting off on purpose.
  ///
  /// It answers "did we read a configuration?", NOT "may an operator retry?" —
  /// see [retryIsAvailable], which is false for an explicit zero.
  bool get isResolved => limit != null || permanentlyDisabled;

  /// Whether the retry action may be offered at all.
  bool get retryIsAvailable => limit != null;

  /// Reads the limit out of [environment] (`Platform.environment` in
  /// production; a literal map in tests, so the resolution is pure and the
  /// environment process cannot be mutated into a bad state mid-test).
  ///
  /// ## FAILS CLOSED, with one deliberate difference from the capacity cap
  ///
  /// Absent, blank, unparseable and negative all resolve to null, never to a
  /// number: a missing value must not mean "unlimited". **Zero is the
  /// exception, and it resolves** — it is a decision, not a mistake.
  factory OperatorRetryLimitResolution.fromEnvironment(
    Map<String, String> environment,
  ) {
    final raw = environment[operatorRetryLimitEnvVar];
    if (raw == null) {
      return OperatorRetryLimitResolution(
        diagnostic:
            'operator retry NOT available: $operatorRetryLimitEnvVar is unset. '
            'Refusing to offer an action that spends model credits without a '
            'configured bound. Set $operatorRetryLimitEnvVar to an integer >= 0 '
            'before an operator can restart work.',
      );
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return OperatorRetryLimitResolution(
        diagnostic:
            'operator retry NOT available: $operatorRetryLimitEnvVar is empty. '
            'Refusing to offer an action that spends model credits without a '
            'configured bound. Set $operatorRetryLimitEnvVar to an integer >= 0 '
            'before an operator can restart work.',
      );
    }
    // STRICT DECIMAL, and this is load-bearing rather than pedantic.
    //
    // `int.tryParse` accepts more than an operator's decimal integer: it reads
    // `0x3` as 3, and `+3` as 3. So a value that looks like a mistake to the
    // human who typed it would silently ARM the one action in this repository
    // that spends real model credits — the exact inversion HD-3 exists to
    // prevent ("an operator action that spends real credits must never be armed
    // by a missing configuration"), reached by a mistyped configuration rather
    // than an absent one. Fail-closed means failing closed on a value the
    // operator did not mean to write, too.
    //
    // A leading `-` is permitted so the negative case below still reports the
    // value it refused rather than calling it unparseable.
    //
    // The REGEX is necessary but NOT sufficient, and the second half is why
    // this cannot be `int.parse`: a long run of digits passes the shape check
    // and then `int.parse` THROWS — "Positive input exceeds the limit of
    // integer". That exception would escape `resolveRetryLimit()` into both
    // `actionContext` and `retryFailedWorkItem`, so a mistyped configuration
    // would take down the READ path and hand the operator an unhandled 500.
    // The money would still be safe (nothing is armed), but the surface that
    // exists to tell an operator the truth would itself be the thing that
    // breaks. `int.tryParse` routes the overflow to the SAME fail-closed
    // branch as every other unusable value.
    final parsed = int.tryParse(trimmed);
    if (parsed == null || !RegExp(r'^-?[0-9]+$').hasMatch(trimmed)) {
      return OperatorRetryLimitResolution(
        diagnostic:
            'operator retry NOT available: $operatorRetryLimitEnvVar="$raw" is not '
            'an integer. Refusing to offer an action that spends model credits '
            'without a configured bound. Set $operatorRetryLimitEnvVar to an '
            'integer >= 0 before an operator can restart work.',
      );
    }
    if (parsed < 0) {
      return OperatorRetryLimitResolution(
        diagnostic:
            'operator retry NOT available: $operatorRetryLimitEnvVar=$parsed is '
            'negative. A negative number of retries is not a limit, so it is not '
            'honoured. Set $operatorRetryLimitEnvVar to an integer >= 0, or to 0 to '
            'switch restarting off deliberately.',
      );
    }
    if (parsed == 0) {
      // RESOLVED, and deliberately worded as CONFIGURATION. This is the row
      // that would come out as a failure-styled diagnostic under a verbatim
      // reuse of `ExecutionCapacityResolution`, and AC-15c is the criterion
      // that fails when it does.
      return OperatorRetryLimitResolution(
        permanentlyDisabled: true,
        diagnostic:
            'operator retry disabled by configuration: $operatorRetryLimitEnvVar=0 '
            '(maximum operator retries per work item is 0, so restarting is '
            'switched off on this machine and nothing has been changed)',
      );
    }
    final limit = OperatorRetryLimit._(
      maximumRetriesPerWorkItem: parsed,
    );
    return OperatorRetryLimitResolution(
      limit: limit,
      diagnostic: limit.startupSummary,
    );
  }
}

/// Binds each operator action to the ONE edge it may take.
///
/// The closed set itself is NOT declared here: it is [OperatorActionKind], the
/// durable `operator_action` ledger's own enum, so the token written to the
/// audit row and the token offered on screen cannot drift apart. This extension
/// only adds what the ledger does not carry — which state the action lands in,
/// and whether it ends the work item.
///
/// Nothing here is a state string on the wire and nothing is a hand-built
/// transition: the edge's legality is asked of [WorkItemTransitions] at call
/// time, and the move itself goes through [DurableWorkflowEngine] under the
/// injected policy (§6.4, §10 N2).
///
/// ## Why `terminated` is not here, and not merely absent from the buttons
///
/// `agentFailed -> terminated` IS legal — the generic escape permits it, for
/// `orchestrator` and `system`. It is withheld because it is the same effect as
/// `stop` under a word an operator cannot act on, and two buttons for one effect
/// is worse than one (design-brief.md §5.2, HD-1). It is also the escape
/// `system` takes; offering it would put a machine's escape in a human's hands
/// under a name that reads like a status rather than an act. So the offer is
/// restricted at the ENUM, not at the widget: a future state that grows a
/// `terminated` edge cannot acquire a third button by accident, because there is
/// no enum member to render.
extension WorkItemActionEdge on OperatorActionKind {
  /// The state this action moves the work item to.
  WorkItemState get targetState => switch (this) {
    OperatorActionKind.retry => WorkItemState.designNotRequired,
    OperatorActionKind.stop => WorkItemState.cancelled,
  };

  /// Whether the action ends the work item irreversibly. Drives the word on the
  /// button and the panel edge — never colour alone (§9 A6).
  bool get destructive => this == OperatorActionKind.stop;
}

/// The retry idempotency-key prefix.
///
/// **A REPLAY KEY ONLY. NEVER AUTHORIZATION.** The audit row written in the
/// transition's own transaction is the authorization
/// (`operator_action_request_unique`); this prefix exists so a replay can find
/// the prior transition cheaply. A caller that formats this prefix correctly
/// has authorised nothing, and no code anywhere treats it as a predicate
/// (design-brief.md §13.1, N12, AC-13).
const String operatorRetryIdempotencyKeyPrefix = 'operator-retry:';

/// Operator actions on a work item parked in a failure state.
///
/// The SECOND legal request-side write path, after
/// `WorkflowEndpoints.resolveDecision`, and deliberately a separate class: the
/// existing class's doc comment claims resolveDecision is the only one, and
/// widening it in place would have left that comment false.
///
/// ## The retry is ONE durable write, and it deliberately does nothing else
///
/// `retryFailedWorkItem` performs exactly one durable transaction — the state
/// change, the transition record, the `operator_action` audit row and the
/// attempt marker — through [DurableWorkflowEngine.operatorRetry]. It does NOT
/// enqueue a job, does NOT claim one, does NOT dispatch one, and does NOT
/// consult the capacity guard.
///
/// The item lands in `designNotRequired`, a triage entry state the scheduler
/// already treats as runnable, so the ordinary tick does the rest on the
/// ordinary path. That is why there is no dispatch path here to get wrong, and
/// why a capacity denial is the scheduler's ordinary behaviour rather than an
/// outcome this method has to design.
///
/// **It does not pre-check capacity either, and must never be given one.** A
/// pre-check is a time-of-check/time-of-use race and would produce a button
/// that says "go" and then does nothing — the dead-button class this design has
/// been burned by three times. The item simply stays runnable until a slot
/// frees (§7.1, N1).
class WorkItemActionEndpoints extends Endpoint {
  @override
  bool get logSessions => true;

  /// The service every method in this class reads and writes through.
  ///
  /// An overridable seam rather than a `ControlPlaneService(session)` written
  /// inline at each of the three call sites, and it exists for one reason: the
  /// refusals this surface makes — `alreadyRunning`, the blank reason, the
  /// retry bound — are the whole safety story, and until this seam existed
  /// there was NO way to reach them in a test. `ControlPlaneService` builds its
  /// stores from `session.db`, so exercising any of them meant standing up a
  /// Postgres, and a guard that no test can reach is a guard that no test
  /// protects.
  ///
  /// Production behaviour is unchanged: this returns the same
  /// `ControlPlaneService(session)` the three methods constructed before, with
  /// the same lazy `PersistenceDatabase`. It is deliberately NOT a
  /// capability override — a test substitutes the STORE, never the refusal.
  ///
  /// `@doNotGenerate` is REQUIRED and is not decoration. Serverpod treats every
  /// public, non-`@doNotGenerate`, `Session`-first method on an `Endpoint` as a
  /// wire endpoint and fails generation unless it returns `Future` or `Stream`;
  /// this returns a plain `ControlPlaneService`, so without the annotation
  /// `serverpod generate` exits 1.
  @doNotGenerate
  ControlPlaneService serviceFor(Session session) =>
      ControlPlaneService(session);

  /// Reads the retry limit for this request.
  ///
  /// A method rather than a constant so a test can inject a literal map — the
  /// environment of a process cannot be mutated into a bad state mid-test, and
  /// the resolution is the safety invariant this surface turns on
  /// (design-brief.md §6.6), so it is the thing most worth being able to drive
  /// directly. Production resolves it per request from the real environment,
  /// which is what makes an unset variable observable on the very next call
  /// rather than only at process start.
  OperatorRetryLimitResolution resolveRetryLimit() =>
      OperatorRetryLimitResolution.fromEnvironment(Platform.environment);

  /// READ. The legal action set for this work item, computed server-side from
  /// [WorkItemTransitions], plus the failure record and the capacity snapshot.
  ///
  /// An empty [WorkItemActionContextView.actions] is the whole signal the page
  /// uses to keep today's existing right-column text instead of the action
  /// panel, so it must be empty for exactly the right reason and not merely
  /// because a lookup failed.
  Future<WorkItemActionContextView> actionContext(
    Session session, {
    required String workItemId,
  }) async {
    final service = serviceFor(session);
    final item = await service.readWorkItem(workItemId);
    final recorded = await service.workflowStore.readOperatorActionsForWorkItem(
      workItemId,
    );
    final limit = resolveRetryLimit();

    // The capacity snapshot is an OBSERVATION, never a promise: the same
    // predicate over the same durable rows `JobCapacityGuard` uses at claim
    // time, read without taking the budget lock because no lock-holding probe
    // exists and inventing one would be a lie (§7.2).
    final allJobs = await service.listJobs();
    final inFlight = allJobs
        .where(
          (j) => j.state == JobState.claimed || j.state == JobState.running,
        )
        .length;
    final cap = ExecutionCapacityResolution.fromEnvironment(
      Platform.environment,
    );

    final jobs = await service.listJobsForWorkItem(workItemId);
    final history = await service.readTransitionHistory(workItemId);

    return WorkItemActionContextView(
      workItemId: workItemId,
      state: item.state.wire,
      actions: actionsFor(
        item.state,
        retryCount: _retryCount(recorded),
        limit: limit,
      ),
      failure: _failureView(history, jobs),
      capacity: ExecutionCapacityView(
        budget: agentExecutionBudget,
        cap: cap.capacity?.maxConcurrentExecutions ?? 0,
        inFlight: inFlight,
        snapshotOnly: true,
        resolved: cap.isResolved,
      ),
      // Reported, never inferred by omission: an unset variable is a state the
      // operator must be able to SEE (§6.6.1 obligation 1, A11).
      retryLimitResolved: limit.isResolved,
      retryLimitDiagnostic: limit.diagnostic,
      priorActions: recorded.map(_summaryView).toList(growable: false),
    );
  }

  /// WRITE. `agentFailed -> designNotRequired` through
  /// [DurableWorkflowEngine.operatorRetry].
  ///
  /// One durable transaction, no enqueue, no dispatch, no capacity check. The
  /// ordering below is §6.4's, and each step's position is load-bearing:
  ///
  ///  1. **Replay.** The `operator_action` row is unique on
  ///     `(workItemId, requestId)`, so it is the authoritative idempotency
  ///     record. A client that retries one operator intent — a lost response, a
  ///     double-click — finds its own row and returns the current item without
  ///     writing again. This is what makes a network retry mint no second job:
  ///     no second write means no second `triageAttempt`, so no second dedupe
  ///     key.
  ///  2. **State.** Not `agent_failed` ⇒ `notApplicable`, nothing written.
  ///  3. **Edge legality**, asked of the real table.
  ///  4. **The bound.** Reached ⇒ `notConfigured`, nothing written. Unresolved
  ///     ⇒ `notConfigured`, nothing written, and the diagnostic names the
  ///     variable.
  ///  5. **The reason.** Blank ⇒ `invalidRequest`, nothing written. The record
  ///     must say why, not just what (§6.4 step 1, §6.3).
  ///  6. **`alreadyRunning`.** Any non-terminal job for this item means a
  ///     second operator action could be layered on top of a live attempt.
  ///  7. **The write.** One transaction.
  ///
  /// `requestId` is minted by the client ONCE per operator intent — on confirm,
  /// not on load and not per HTTP attempt — and reused for every network retry
  /// of that intent.
  Future<WorkItemActionResult> retryFailedWorkItem(
    Session session, {
    required String workItemId,
    required String requestId,
    required String requestedBy,
    required String reason,
  }) async {
    final service = serviceFor(session);
    final limit = resolveRetryLimit();
    final recorded = await service.workflowStore.readOperatorActionsForWorkItem(
      workItemId,
    );

    // (1) REPLAY, before any authorisation: a request that already happened
    // reports what it did, whatever the item has become since.
    if (_priorFor(recorded, requestId, OperatorActionKind.retry) != null) {
      final item = await service.readWorkItem(workItemId);
      return _result(
        outcome: 'accepted',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    final item = await service.readWorkItem(workItemId);

    // (2) The panel is for work that stopped; anything else has nothing to
    // offer.
    if (item.state != WorkItemState.agentFailed) {
      return _result(
        outcome: 'notApplicable',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    // (3) The real table, not an assumption about it.
    if (!WorkItemTransitions.isLegalTransition(
      item.state,
      OperatorActionKind.retry.targetState,
    )) {
      return _result(
        outcome: 'notApplicable',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    // (4) THE BOUND. Two different refusals that share an outcome, told apart
    // by `retryLimitResolved` on the way out so the client can word each
    // truthfully without server-authored copy.
    if (!limit.retryIsAvailable) {
      service.logger.info('work_item.retry.not_configured', {
        'workItemId': workItemId,
        'diagnostic': limit.diagnostic,
      });
      return _result(
        outcome: 'notConfigured',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }
    if (_retryCount(recorded) >= limit.limit!.maximumRetriesPerWorkItem) {
      service.logger.info('work_item.retry.limit_reached', {
        'workItemId': workItemId,
        'retries': _retryCount(recorded),
        'limit': limit.limit!.maximumRetriesPerWorkItem,
      });
      return _result(
        outcome: 'notConfigured',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    // (5) A blank reason is refused before anything is written.
    if (reason.trim().isEmpty) {
      return _result(
        outcome: 'invalidRequest',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    // (6) A live attempt is never stacked on.
    final jobs = await service.listJobsForWorkItem(workItemId);
    if (jobs.any((j) => j.state.isActive)) {
      return _result(
        outcome: 'alreadyRunning',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    // (7) THE ONE DURABLE WRITE. Everything durable about this action happens
    // inside `DurableWorkflowEngine`'s own transaction — the state change, the
    // transition record carrying the operator's reason, the audit row naming the
    // human, and the attempt marker that makes the next dispatch possible.
    try {
      final updated = await service.workflowEngine.operatorRetry(
        workItemId: workItemId,
        requestedBy: requestedBy,
        reason: reason.trim(),
        requestId: requestId,
        // Replay key only. Nothing authorizes on this prefix (§13.1, N12).
        idempotencyKey: '$operatorRetryIdempotencyKeyPrefix$requestId',
      );
      service.logger.info('work_item.retry.accepted', {
        'workItemId': workItemId,
        'requestId': requestId,
        'requestedBy': requestedBy,
        'state': updated.state.wire,
        'version': updated.version,
      });
      return _result(
        outcome: 'accepted',
        item: updated,
        limit: limit,
        retryCount: _retryCount(recorded) + 1,
      );
    } on WorkflowTransitionRejectedException {
      // Someone else moved it between the read above and this write. Nothing
      // was taken, so nothing is audited; the rejected transition record
      // already carries the attempt and its key (§6.4 step 3).
      return _result(
        outcome: 'notApplicable',
        item: await service.readWorkItem(workItemId),
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }
  }

  /// WRITE. `agentFailed -> cancelled` through [DurableWorkflowEngine].
  ///
  /// The generic non-terminal escape and nothing synthesised: `stop` writes
  /// exactly the edge `WorkItemTransitions` already permits, under the same
  /// actor the retry uses, and records the human and their reason on the same
  /// durable write. A stop is terminal and irreversible — there is no edge back
  /// from `cancelled` — which is why it is offered as an `OutlinedButton` with
  /// a `negative` panel edge and the SAME confirmation strip as the retry, and
  /// why it is never styled as the safe option (§10 N11, §9 A6).
  ///
  /// Unlike the retry, this does NOT refuse while a job is running: stopping is
  /// precisely what an operator reaches for when work is already in flight, and
  /// the brief withholds `alreadyRunning` from the stop path (design-brief.md
  /// §6.4 step 1, §7.3 — "offers no retry button while it holds").
  Future<WorkItemActionResult> stopFailedWorkItem(
    Session session, {
    required String workItemId,
    required String requestId,
    required String requestedBy,
    required String reason,
  }) async {
    final service = serviceFor(session);
    final limit = resolveRetryLimit();
    final recorded = await service.workflowStore.readOperatorActionsForWorkItem(
      workItemId,
    );

    if (_priorFor(recorded, requestId, OperatorActionKind.stop) != null) {
      final item = await service.readWorkItem(workItemId);
      return _result(
        outcome: 'alreadyStopped',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    final item = await service.readWorkItem(workItemId);
    if (item.state != WorkItemState.agentFailed ||
        !WorkItemTransitions.isLegalTransition(
          item.state,
          OperatorActionKind.stop.targetState,
        )) {
      return _result(
        outcome: 'notApplicable',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }
    if (reason.trim().isEmpty) {
      return _result(
        outcome: 'invalidRequest',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    try {
      final updated = await service.workflowEngine.transition(
        workItemId: workItemId,
        to: OperatorActionKind.stop.targetState,
        trigger: TransitionTrigger.systemEvent,
        actor: DurableWorkflowEngine.operatorRetryActor,
        context: {'operatorStop': true, 'requestedBy': requestedBy},
        idempotencyKey: 'operator-stop:$requestId',
        reason: reason.trim(),
        operatorAction: OperatorActionRecord(
          actionId: 'oa-stop-$requestId',
          workItemId: workItemId,
          action: OperatorActionKind.stop.wire,
          fromState: item.state.wire,
          toState: OperatorActionKind.stop.targetState.wire,
          requestedBy: requestedBy,
          reason: reason.trim(),
          requestId: requestId,
          // A stop arms no job, so it consumes no attempt.
          attemptNumber: null,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      service.logger.info('work_item.stop.accepted', {
        'workItemId': workItemId,
        'requestId': requestId,
        'requestedBy': requestedBy,
        'state': updated.state.wire,
        'version': updated.version,
      });
      return _result(
        outcome: 'accepted',
        item: updated,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    } on WorkflowTransitionRejectedException {
      return _result(
        outcome: 'notApplicable',
        item: await service.readWorkItem(workItemId),
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }
  }

  // ---------------------------------------------------------------------
  // The server-computed action set
  // ---------------------------------------------------------------------

  /// The work-item states this surface exists for.
  ///
  /// ## WHY THE SURFACE IS SCOPED AT ALL, WHEN THE TABLE IS THE AUTHORITY
  ///
  /// [WorkItemTransitions.isLegalTransition] is consulted for every candidate
  /// action, but it is consulted FROM a state, and the generic non-terminal
  /// escape (`_isGenericEscape`) makes `(anything non-terminal -> cancelled)`
  /// legal. Asked of the table alone, that means `actionsFor` would answer
  /// `[stop]` for `draft`, `planning`, `deploying` and every other state still
  /// in flight — and `[retry, stop]` for `planned`, because
  /// `planned -> designNotRequired` is a PRE-EXISTING edge that has nothing to
  /// do with an operator restarting failed work.
  ///
  /// Both would be wrong, and the second one is the dangerous one. `planned`
  /// would get a **"Try again" button bound to an edge the design never
  /// approved**, and that button's write would be refused by
  /// [retryFailedWorkItem] — a panel that offers an action and then declines it.
  /// That is the dead-button failure this whole design exists to close, arriving
  /// through the door the panel was built to open.
  ///
  /// So the scope is stated once, here, and the TABLE still decides the actions
  /// within it. Scoping is not the hardcoding AC-1/N4 forbid: AC-1 is about not
  /// hardcoding the action ids (`retry`/`stop`), which would keep being returned
  /// after the table stopped permitting them. Nothing here names an action —
  /// ask the table and it answers.
  ///
  /// `agentFailed` is the state the brief analyses (§5.1), the state both write
  /// methods already refuse anything but, and the state whose exclusion from
  /// `RunnableWorkEvaluator` is what routes it to a human in the first place.
  /// A failure state the brief never analysed is NOT added here: `qa_failed`
  /// and `deployment_failed` would acquire a "Stop this work" button through
  /// the escape alone, on a screen nobody specified (§8.1, §10 N9).
  static bool _isOperatorActionSurface(WorkItemState state) =>
      state == WorkItemState.agentFailed;

  /// The actions legal from [from], in [WorkItemActionEdge] declaration order.
  ///
  /// ## Computed, never declared
  ///
  /// Every candidate is checked against [WorkItemTransitions.isLegalTransition]
  /// at call time. That is the whole reason this is a function and not a
  /// literal `['retry', 'stop']`: a hardcoded list would keep answering
  /// `[retry, stop]` for a state the table no longer permits an edge out of,
  /// and would keep answering it after the table grows a different escape. The
  /// set is a property of the transition table, and this reads it from the
  /// table.
  ///
  /// States outside [_isOperatorActionSurface] get `[]` before the table is
  /// asked, which is AC-2: the action set is the signal the page uses to decide
  /// between this panel and today's existing right-column text, so a `planned`
  /// or an `agent_completed` item must still read "Nothing needs you here".
  ///
  /// `retry` is then withheld for either of the two honest reasons and NOT for
  /// any third: the limit was never configured, or this item has used it up.
  /// `stop` is withheld by no configuration at all — HD-1 decided an operator
  /// who cannot retry must still have both answers, and a missing environment
  /// variable must not remove the only exit left (design-brief.md
  /// §6.6.1 obligation 2, AC-15d).
  ///
  /// Public rather than private so a test can drive it directly against the
  /// real transition table without a `Session`; it reads no state and the
  /// endpoint is the only production caller.
  List<WorkItemActionView> actionsFor(
    WorkItemState from, {
    required int retryCount,
    required OperatorRetryLimitResolution limit,
  }) {
    if (!_isOperatorActionSurface(from)) return const [];

    final attemptsUsed = _retryCountFrom(retryCount);
    final remaining = limit.retryIsAvailable
        ? limit.limit!.maximumRetriesPerWorkItem - attemptsUsed
        : 0;

    return [
      for (final kind in OperatorActionKind.values)
        if (WorkItemTransitions.isLegalTransition(from, kind.targetState))
          if (kind != OperatorActionKind.retry || remaining > 0)
            WorkItemActionView(
              action: kind.wire,
              toState: kind.targetState.wire,
              // Both actions require an explicit confirmation: one spends real
              // credits, the other is irreversible (§10 N11, AC-6).
              confirmRequired: true,
              destructive: kind.destructive,
              attemptNumber: kind == OperatorActionKind.retry
                  ? attemptsUsed + 1
                  : null,
              attemptLimit: limit.retryIsAvailable
                  ? limit.limit!.maximumRetriesPerWorkItem
                  : 0,
            ),
    ];
  }

  // ---------------------------------------------------------------------
  // Projections
  // ---------------------------------------------------------------------

  /// The durable facts of why this item stopped. Raw, untranslated, and null
  /// fields preserved as null: the panel reports a missing reason AS MISSING
  /// (AC-21) rather than substituting a generic sentence for it.
  WorkItemFailureView? _failureView(
    List<WorkflowTransitionRecord> history,
    List<Job> jobs,
  ) {
    // The transition that ENTERED the failure state, not merely the latest
    // one: on a retried item the latest transition is the operator's own.
    final entering = history
        .where((t) => t.toState == WorkItemState.agentFailed)
        .lastOrNull;
    final latestJob = jobs.isEmpty
        ? null
        : (jobs.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
              .first;

    if (entering == null && latestJob == null) return null;

    return WorkItemFailureView(
      transitionId: entering?.transitionId,
      at: entering?.occurredAt ?? latestJob?.completedAt,
      reason: entering?.reason,
      actorType: entering?.actorType.wire,
      jobId: latestJob?.jobId,
      jobState: latestJob?.state.wire,
      jobFailureCode: latestJob?.failure?.code.name,
      jobFailureReason: latestJob?.failure?.reason,
      jobFailureJson: latestJob?.failure == null
          ? null
          : jsonEncode(latestJob!.failure!.toJson()),
    );
  }

  OperatorActionSummaryView _summaryView(OperatorActionRecord record) =>
      OperatorActionSummaryView(
        action: record.action,
        requestedBy: record.requestedBy,
        reason: record.reason,
        at: record.createdAt,
        attemptNumber: record.attemptNumber,
      );

  WorkItemActionResult _result({
    required String outcome,
    required WorkItem item,
    required OperatorRetryLimitResolution limit,
    required int retryCount,
  }) => WorkItemActionResult(
    outcome: outcome,
    workItem: UiViewMappers.workItemView(item),
    attemptNumber: retryCount,
    retryLimitResolved: limit.isResolved,
    attemptLimit: limit.retryIsAvailable
        ? limit.limit!.maximumRetriesPerWorkItem
        : 0,
  );

  // ---------------------------------------------------------------------
  // Ledger reads
  // ---------------------------------------------------------------------

  /// The number of `retry` operator actions already recorded for this item.
  ///
  /// Counted from the durable append-only ledger, never from a counter in
  /// memory, so it survives a restart and a network replay identically.
  static int _retryCount(List<OperatorActionRecord> recorded) =>
      _retryCountFrom(
        recorded.where((a) => a.action == OperatorActionKind.retry.wire).length,
      );

  static int _retryCountFrom(int value) => value < 0 ? 0 : value;

  /// The first ledger row for this exact operator intent, if there is one.
  ///
  /// `readOperatorActionsForWorkItem` is documented OLDEST FIRST precisely so
  /// this finds the FIRST row for a `requestId`; the count above is
  /// order-independent.
  static OperatorActionRecord? _priorFor(
    List<OperatorActionRecord> recorded,
    String requestId,
    OperatorActionKind kind,
  ) => recorded
      .where((a) => a.requestId == requestId && a.action == kind.wire)
      .firstOrNull;
}
