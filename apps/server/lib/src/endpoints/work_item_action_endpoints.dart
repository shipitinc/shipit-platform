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

/// The single environment variable that may BOUND how many times one operator
/// may restart one work item.
///
/// ## REVERSED 2026-10-12 — unset now means NO COUNT BOUND, not "unavailable"
///
/// This variable used to be REQUIRED and fail-closed: unset, blank, unparseable
/// or negative all resolved to `notConfigured`, and the retry action was never
/// offered, on the reasoning that *"an operator action that spends real credits
/// must never be armed by a missing configuration"* (HD-3, `5d9a1f62`).
///
/// A human asked for the opposite, and the reversal is deliberate: *"it is ok
/// to retry a job unlimited times as long as the try is human triggered and not
/// automatic. We'd only want to limit the retries if it was an agent driven
/// process."*
///
/// **WHY THAT IS SAFE HERE, WHICH IS THE WHOLE BASIS OF THE REVERSAL:**
///
///  1. The only production caller is the operator UI behind an authenticated
///     Serverpod session — `run_detail_bloc.dart` → `control_plane_repository.dart`
///     → this endpoint. There is no automation, cron or agent-driven caller
///     (asserted by `operator_retry_limit_test.dart`, which pins the caller
///     chain by name so a future automation path fails loudly).
///  2. Every invocation is a separate, deliberate, confirm-required spend. The
///     panel already requires an explicit confirmation strip and a non-blank
///     reason per attempt, and each attempt is one row in an append-only audit
///     ledger naming the human.
///  3. **AUTOMATIC retries are a different mechanism and remain bounded.** They
///     are the job's own `Job.maxAttempts`, enforced by `RetryPolicy.canRetry`
///     (`job.attempt < job.maxAttempts`) in the scheduler's own tick and in
///     `baseline_dispatch.dart`. Removing a bound here touches nothing there:
///     `triageDefectDefinition.maxAttempts` is still `2`, whatever an operator
///     does to this variable. The reversal moves a bound on a HUMAN action, not
///     a bound on an agent.
///
/// ## WHAT THE VARIABLE STILL DOES
///
/// It remains a real, usable control, and both of its remaining settings are
/// honoured:
///
///  * **unset / blank / unparseable / negative ⇒ no count bound.** The operator
///    may restart the item any number of times.
///  * **an explicit positive `N` ⇒ capped at N** for that work item.
///  * **an explicit `0` ⇒ operator retry is switched off entirely.** This is
///    the only setting that removes the action, and it is deliberately
///    distinct from "unbounded".
///
/// So there is still no `const int defaultMaxRetries = 3;` here: 3 is not a
/// default any more, it is a value an operator may choose. A reviewer should
/// treat the appearance of a default constant here as the defect it would be.
const String operatorRetryLimitEnvVar = 'SHIPIT_OPERATOR_MAX_RETRIES';

/// A resolved, usable per-work-item operator-retry limit.
///
/// Private constructor: the only way to obtain one is for
/// [OperatorRetryLimitResolution.fromEnvironment] to have succeeded with a
/// positive value. There is no named constant and no static default, so a
/// caller cannot accidentally hand this screen a guessed number while logging
/// the guess as fact.
class OperatorRetryLimit {
  const OperatorRetryLimit._({required this.maximumRetriesPerWorkItem});

  /// The operator-configured value: how many times ONE work item may be
  /// restarted.
  ///
  /// **Always positive.** Zero is not represented here — it resolves to
  /// [OperatorRetryLimitResolution.permanentlyDisabled] instead, so "switched
  /// off" and "capped at zero" can never be confused (AC-15c).
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

/// The outcome of reading [operatorRetryLimitEnvVar].
///
/// Exactly three resolved shapes, and every input reaches one of them — there
/// is no longer a fourth "unresolved" shape:
///
/// | input | shape | retry offered? |
/// |---|---|---|
/// | unset / blank / unparseable / negative | [unbounded] | yes, without a count |
/// | explicit positive `N` | [limit] | yes, up to N |
/// | explicit `0` | [permanentlyDisabled] | no |
///
/// ## WHY THIS STILL DOES NOT REUSE `ExecutionCapacityResolution`
/// (design-brief.md §6.6, reviewer's M1)
///
/// That helper is the right PATTERN — name the variable, say what was wrong,
/// never substitute a number — and it is reused here as a pattern only. Its
/// helper is not reusable verbatim, because it resolves `parsed < 1` to
/// UNRESOLVED with a *"below the minimum of 1"* diagnostic
/// (`execution_capacity.dart:156-164`). That is the right answer for a
/// concurrency cap, where `0` would deny all work forever, and the WRONG answer
/// here: `0` is a valid configuration meaning *permanently disabled*, and
/// AC-15c requires it to resolve to a RESOLVED value with a diagnostic that
/// reads as configuration rather than failure.
///
/// **What it means to fail closed has itself reversed**, deliberately and only
/// on this axis. Failing closed now means: an unreadable value is IGNORED and
/// the operator's UNBOUNDED default stands, rather than silently switching a
/// human's action off behind their back. The concurrency cap is untouched and
/// still fails closed hard — a host crash on 2026-10-10 came from unbounded
/// AGENT work, which is precisely the work this endpoint does not do.
class OperatorRetryLimitResolution {
  const OperatorRetryLimitResolution({
    required this.diagnostic,
    this.limit,
    this.permanentlyDisabled = false,
    this.unbounded = false,
  });

  /// The resolved count, or null when no count was configured (either
  /// [unbounded] or [permanentlyDisabled]). Never a fallback value.
  final OperatorRetryLimit? limit;

  /// True when the variable resolved to an explicit `0` — switched off on
  /// purpose, which is a CONFIGURATION and not a failure (AC-15c). Kept apart
  /// from [limit] so the client can word "you have used all three" and
  /// "restarting is switched off here" differently from one flag.
  final bool permanentlyDisabled;

  /// True when no count bound applies — the REVERSED 2026-10-12 default.
  ///
  /// Retry IS available in this state; there is simply no count to exhaust.
  /// This is deliberately not "no resolution": [isResolved] is true, because
  /// the variable's meaning is known exactly, and a client that renders "this
  /// variable is not configured" about the DEFAULT state would be telling an
  /// operator their machine is broken when it is working normally.
  final bool unbounded;

  /// A human-readable, log-line-safe statement naming the variable and what it
  /// resolved to — including, in the unbounded case, what did NOT happen (no
  /// count bound was applied). Safe to log verbatim: it never contains a
  /// credential, only the variable name and the offending value.
  final String diagnostic;

  /// True when the variable's meaning is known: a positive count, an explicit
  /// `0`, or no count bound at all.
  ///
  /// It answers "do we know what this variable means?", NOT "may an operator
  /// retry?" — see [retryIsAvailable], which is false only for an explicit zero.
  bool get isResolved => limit != null || permanentlyDisabled || unbounded;

  /// Whether the retry action may be offered at all.
  ///
  /// True for [unbounded]: the 2026-10-12 reversal, under which an operator may
  /// restart a work item any number of times. False ONLY for an explicit `0`.
  bool get retryIsAvailable => limit != null || unbounded;

  /// Whether a real, exhaustible count is in force.
  ///
  /// The single predicate the RPC's bound check asks, so the "is it spent?"
  /// question is never accidentally asked of an [unbounded] resolution — which
  /// has no number to compare against and would compare against `0`.
  bool get isCountBounded => limit != null;

  /// The count to put on the wire.
  ///
  /// The wire field is a non-nullable `int` and this repository's models are
  /// frozen, so "there is no count" and "the count is zero" share the value
  /// `0`. That ambiguity is REAL and is handed to the Manager as a finding
  /// rather than papered over: the two states are distinguished by
  /// [retryIsAvailable] (and therefore by whether `retry` appears in the
  /// offered action set at all), not by this number.
  int get wireAttemptLimit => limit?.maximumRetriesPerWorkItem ?? 0;

  /// Reads the limit out of [environment] (`Platform.environment` in
  /// production; a literal map in tests, so the resolution is pure and the
  /// environment process cannot be mutated into a bad state mid-test).
  ///
  /// ## NO VALUE IS SUBSTITUTED, IN EITHER DIRECTION
  ///
  /// There is no fallback number here and there never was one; the reversal did
  /// not add one. What it changed is which answer an unusable value produces:
  /// rather than `notConfigured`, an unusable value produces [unbounded]. Both
  /// behaviours refuse to invent a number, and that shared property is what
  /// makes this change a change of POLICY rather than the reintroduction of a
  /// default.
  factory OperatorRetryLimitResolution.fromEnvironment(
    Map<String, String> environment,
  ) {
    final raw = environment[operatorRetryLimitEnvVar];

    // One sentence for every "no number here" case. It must name the variable
    // (so the next operator reading the log knows what to look at) and it must
    // NOT tell them to set the variable in order to make the action appear —
    // since the reversal, the action already appears without it, and copy that
    // says otherwise is exactly the "must be configured before it works" lie
    // this reversal exists to delete.
    String unboundedBecause(String what) =>
        'operator retry UNBOUNDED: $operatorRetryLimitEnvVar is $what, so no '
        'count bound is applied and a human may restart this work item any '
        'number of times. This is the default as of 2026-10-12 (human-triggered '
        'retries are deliberately uncounted; automatic/agent-driven retries '
        'remain bounded by the job maxAttempts). Set '
        '$operatorRetryLimitEnvVar to a positive integer to cap it, or to 0 to '
        'switch operator retry off.';

    if (raw == null) {
      return OperatorRetryLimitResolution(
        unbounded: true,
        diagnostic: unboundedBecause('unset'),
      );
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return OperatorRetryLimitResolution(
        unbounded: true,
        diagnostic: unboundedBecause('empty'),
      );
    }
    // STRICT DECIMAL, and this is load-bearing rather than pedantic — but the
    // failure it guards has CHANGED, and the comment above has to say so.
    //
    // `int.tryParse` accepts more than an operator's decimal integer: it reads
    // `0x3` as 3, and `+3` as 3. Under the OLD fail-closed rule such a value
    // silently ARMED the one action in this repository that spends real model
    // credits — the exact inversion HD-3 existed to prevent, reached by a
    // mistyped configuration rather than an absent one.
    //
    // Under the REVERSED rule that concern is gone, because the action is
    // already armed by default and this variable cannot arm it. Strictness is
    // kept for the two properties that are still real, both of which are
    // unaffected by the policy reversal:
    //
    //  1. **No input throws.** A long run of digits passes a shape check and
    //     then `int.parse` THROWS ("Positive input exceeds the limit of
    //     integer"). That exception would escape `resolveRetryLimit()` into
    //     both `actionContext` and `retryFailedWorkItem`, so a mistyped
    //     configuration would take down the READ path and hand the operator an
    //     unhandled 500. `int.tryParse` routes the overflow to the same
    //     branch as every other unusable value.
    //  2. **A number that was not meant is not honoured as one.** `0x3` and
    //     `-3` are not counts an operator chose; treating them as `3` and as
    //     "negative, refused" respectively would both be pretending the value
    //     said something it did not. Both now read as what they are — unusable
    //     — and both land on the same truthful answer as unset: no bound.
    //
    //  3. **A stray minus cannot switch the action OFF.** The sign test below
    //     is `parsed < 0 || trimmed.startsWith('-')`, not `parsed < 0`, and
    //     the second half is load-bearing: `int.tryParse('-0')` returns `0`,
    //     so a value-check on the PARSED NUMBER alone would let `-0` fall
    //     through to the disable branch. That is the worst available reading —
    //     a typo would remove the operator's only way to restart work, and
    //     "disabled by configuration" is precisely the outcome this reversal
    //     removes a broken configuration from being able to cause on its own.
    //     Disabling the action is the most consequential thing this variable
    //     does, so it takes the unambiguous spelling `0` and nothing else.
    //
    // A leading `-` is permitted so the negative case below still reports the
    // value it refused rather than calling it unparseable.
    final parsed = int.tryParse(trimmed);
    if (parsed == null || !RegExp(r'^-?[0-9]+$').hasMatch(trimmed)) {
      return OperatorRetryLimitResolution(
        unbounded: true,
        diagnostic: unboundedBecause(
          '"$raw", which is not an integer, and so is being ignored',
        ),
      );
    }
    if (parsed < 0 || trimmed.startsWith('-')) {
      return OperatorRetryLimitResolution(
        unbounded: true,
        diagnostic: unboundedBecause(
          '$parsed, which is negative and therefore not a limit, so it is '
          'being ignored',
        ),
      );
    }
    if (parsed == 0) {
      // RESOLVED, and deliberately worded as CONFIGURATION. This is the ONE
      // setting that removes the action, and it is worded so an operator
      // reading it cannot mistake it for the unset case: it says what was set,
      // what it does, and that nothing was changed. It must NOT carry the old
      // default's language ("set this to 3 to arm restarting") — under the
      // reversal that advice is inverted, and copying it forward would tell an
      // operator who switched retrying OFF how to switch it on again.
      return OperatorRetryLimitResolution(
        permanentlyDisabled: true,
        diagnostic:
            'operator retry disabled by configuration: $operatorRetryLimitEnvVar=0 '
            '(operator-triggered restart of a work item is switched off on this '
            'machine, and nothing has been changed. This is an explicit choice: '
            'leaving $operatorRetryLimitEnvVar unset instead would leave retries '
            'uncounted, not disabled)',
      );
    }
    final limit = OperatorRetryLimit._(maximumRetriesPerWorkItem: parsed);
    return OperatorRetryLimitResolution(
      limit: limit,
      // States the cap AND that it is the cap that applies — an operator who
      // cannot see the number in force cannot tell a bounded button from an
      // absent one.
      diagnostic:
          '${limit.startupSummary} (an explicit cap; unset would instead mean '
          'uncounted since the 2026-10-12 reversal)',
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
  /// refusals this surface makes — `alreadyRunning`, the blank reason, and the
  /// two surviving refusals of the bound (an explicit `0`, a spent count) — are
  /// the whole safety story, and until this seam existed there was NO way to
  /// reach them in a test. `ControlPlaneService` builds its stores from
  /// `session.db`, so exercising any of them meant standing up a Postgres, and
  /// a guard that no test can reach is a guard that no test protects.
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
  ///  4. **The bound.** Reached ⇒ `notConfigured`, nothing written. Switched
  ///     off by an explicit `0` ⇒ `notConfigured`, nothing written. Unset ⇒
  ///     **no bound and no refusal** — this step does not stop it (reversed
  ///     2026-10-12; see [operatorRetryLimitEnvVar]).
  ///  5. **The reason.** Blank ⇒ `invalidRequest`, nothing written. The record
  ///     must say why, not just what (§6.4 step 1, §6.3).
  ///  6. **`alreadyRunning`.** Any non-terminal job for this item means a
  ///     second operator action could be layered on top of a live attempt.
  ///  7. **The write.** One transaction.
  ///
  /// Steps 1, 2, 3, 5, 6 and 7 are UNCHANGED by the 2026-10-12 reversal, and
  /// that is the point worth stating: an uncounted retry is still one
  /// deliberate, reasoned, non-double-spending, non-concurrent action per
  /// invocation. Only step 4 changed.
  ///
  /// ## HOW OFTEN THIS MAY BE CALLED
  ///
  /// Unbounded, by a human, one deliberate confirm-and-reason at a time. What
  /// bounds it is not a counter but the guards above: an item must be parked
  /// in `agent_failed`, must not already be running, and each call writes one
  /// audit row. What bounds AUTOMATIC re-running is a different mechanism
  /// entirely — the job's own `maxAttempts` — and this method does not consult
  /// it (nor could it: it never enqueues or claims a job).
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

    // (4) THE BOUND, now narrowed to the two cases that can still refuse.
    //
    // Before 2026-10-12 this step had a third refusal — "unresolved", which
    // covered unset/blank/unparseable and returned `notConfigured`. That is
    // deliberately reversed: those inputs now resolve to `unbounded`, which
    // passes [OperatorRetryLimitResolution.retryIsAvailable] and has no count
    // to exhaust. So exactly two things still reach `notConfigured` here, and
    // both are a DELEGATE'S OWN CHOICE rather than an accident of missing
    // configuration:
    //
    //   * an explicit `0` — operator retry switched off on purpose;
    //   * an explicit positive N that this item has used up.
    //
    // `retryLimitResolved` still distinguishes them on the way out, which is
    // what lets the client word "switched off" and "you have used all N"
    // differently without server-authored copy.
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
    // `isCountBounded`, NOT `retryIsAvailable`: an `unbounded` resolution has a
    // null [OperatorRetryLimitResolution.limit], and `!limit!.…` would throw
    // on exactly the default path this reversal created. The old expression
    // was safe only because an available limit always implied a number.
    if (limit.isCountBounded &&
        _retryCount(recorded) >= limit.limit!.maximumRetriesPerWorkItem) {
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
  /// `retry` is then withheld for exactly two reasons, both of which are a
  /// deliberate configuration rather than an accident (reversed 2026-10-12): an
  /// explicit `0` switched it off, or an explicit count is spent. An
  /// UNCONFIGURED variable withholds nothing — that is the whole reversal, and
  /// it is why the default state of every stack offers `retry`. `stop` is
  /// withheld by no configuration at all — HD-1 decided an operator who cannot
  /// retry must still have both answers (design-brief.md §6.6.1 obligation 2,
  /// AC-15d).
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
    // `null` means "no count bound" and is therefore always offerable. A number
    // is a real budget and can be exhausted. Zero means unavailable.
    //
    // Modelled as nullable rather than as a sentinel number on purpose: the
    // pre-reversal code computed `retryIsAvailable ? limit - used : 0`, which
    // collapses "unbounded" and "disabled" onto the same value and would make
    // the new default indistinguishable from the switch-off it must never be
    // confused with.
    final remaining = switch (limit) {
      OperatorRetryLimitResolution(unbounded: true) => null,
      OperatorRetryLimitResolution(limit: final l?) =>
        l.maximumRetriesPerWorkItem - attemptsUsed,
      _ => 0,
    };

    return [
      for (final kind in OperatorActionKind.values)
        if (WorkItemTransitions.isLegalTransition(from, kind.targetState))
          if (kind != OperatorActionKind.retry ||
              remaining == null ||
              remaining > 0)
            WorkItemActionView(
              action: kind.wire,
              toState: kind.targetState.wire,
              // Both actions require an explicit confirmation: one spends real
              // credits, the other is irreversible (§10 N11, AC-6).
              confirmRequired: true,
              destructive: kind.destructive,
              // The attempt position is still a real, 1-based count of audit
              // rows under the reversal — the operator is on their seventh
              // deliberate restart, and the panel should say so.
              attemptNumber: kind == OperatorActionKind.retry
                  ? attemptsUsed + 1
                  : null,
              // 0 here means "no count", which on the wire is shared with
              // "switched off". See [OperatorRetryLimitResolution
              // .wireAttemptLimit]; the two are separated by whether this
              // action is in the list at all.
              attemptLimit: limit.wireAttemptLimit,
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
    attemptLimit: limit.wireAttemptLimit,
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
