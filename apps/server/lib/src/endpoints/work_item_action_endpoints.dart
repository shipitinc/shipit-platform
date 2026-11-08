import 'dart:convert';
import 'dart:io';

// Narrow: the reviewer's own execution store. The provenance read below is
// separate from the decision's own claim precisely because it must never
// consult the decision for evidence; the producer read is separate from
// "whatever ran last" for the same reason.
import 'package:execution_coordinator/execution_coordinator.dart'
    show ExecutionStore;
import 'package:platform_contracts/platform_contracts.dart';
// `scheduler.dart` does not barrel-export its capacity directory yet — see the
// identical, identical-reasoned import in `apps/server/lib/server.dart`, and the
// L1 barrel-export TODO that notes there. Narrow, explicit, and expected to be
// deleted when the barrel exports it.
// ignore: implementation_imports
import 'package:scheduler/src/capacity/execution_capacity.dart'
    show ExecutionCapacityResolution, agentExecutionBudget;
import 'package:serverpod/serverpod.dart';
import 'package:workflow_engine/workflow_engine.dart'
    show WorkItemTransitions, operatorRerouteContextKey;
// `product_registry` and `postgres_defect_store` each export a
// `ConcurrentModificationException` of their own; this is the work-item
// compare-and-swap one, named by the single import that shows it.
import 'package:workflow_store/workflow_store.dart'
    show
        ConcurrentModificationException,
        DurableWorkflowEngine,
        OperatorActionKind,
        OperatorActionRecord,
        WorkflowTransitionRejectedException;

import '../deploy/deploy_advance.dart'
    show deploymentArtifactFor, raiseDeploymentApproval;
import '../deploy/deploy_landing.dart'
    show
        DeployLanding,
        DeployLandingException,
        deployLandingStampedItem,
        deployRelandIsOwed,
        deployRelandMechanismName,
        relandDeployedItem;
import '../generated/execution_capacity_view.dart';
import '../generated/operator_action_summary_view.dart';
import '../generated/review_repair_result.dart';
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

/// The deploy-advance idempotency-key prefix. A REPLAY KEY ONLY, exactly like
/// [operatorRetryIdempotencyKeyPrefix]: a caller that formats it correctly has
/// authorised nothing, and nothing treats it as a predicate.
const String operatorDeployIdempotencyKeyPrefix = 'operator-deploy:';

/// The stranded-execution reclaim idempotency-key prefix. Same replay-key-only
/// rule.
const String operatorReclaimIdempotencyKeyPrefix = 'operator-reclaim:';

/// The `deployed -> implementation_ready` reroute idempotency-key prefix.
/// Same replay-key-only rule.
const String operatorRerouteIdempotencyKeyPrefix = 'operator-reroute:';

/// The `operator_action.action` wire token for the deploy advance.
///
/// A free-form string rather than an [OperatorActionKind] member: the enum is
/// closed over the failed-work actions and lives in `workflow_store`, which
/// this lane does not own. The column stores `action` as a plain string, so a
/// new token needs no schema change and no enum widening.
const String operatorDeployActionWire = 'deploy';

/// The `operator_action.action` wire token for the stranded-execution reclaim.
const String operatorReclaimActionWire = 'reclaim';

/// The `operator_action.action` wire token for the re-land of a `deployed`
/// item that was never stamped (F-259).
///
/// Same free-form-string rule as [operatorDeployActionWire]: the ledger
/// column carries a plain string, so a new token needs no schema change and
/// no [OperatorActionKind] widening — the enum is closed over the
/// failed-work actions and lives in `workflow_store`, which this lane does
/// not own.
const String operatorRelandActionWire = 'reland';

/// The `operator_action.action` wire token for the reroute of a `deployed`
/// item back to implementation entry (F-261).
///
/// Same free-form-string rule as [operatorRelandActionWire]: the ledger
/// column carries a plain string, so a new token needs no schema change and
/// no [OperatorActionKind] widening — the enum is closed over the
/// failed-work actions and lives in `workflow_store`, which this lane does
/// not own.
const String operatorRerouteActionWire = 'reroute';

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

    // The two newer offers are computed from the same durable facts their
    // write paths re-check, so an offered button is one that can complete —
    // the dead-button class this surface exists to close.
    final deployable =
        item.state == WorkItemState.qaPassed &&
        await deploymentArtifactFor(
              executionStore: service.executionStore,
              workerStore: service.workerStore,
              item: item,
              advanceId: 'offer',
              builtBy: 'offer',
              raisedBy: 'work_item_action.advanceToDeploy',
              log: (event, data) => service.logger.info(event, data),
            ) !=
            null;
    final stranded =
        item.state == WorkItemState.agentExecuting &&
        !jobs.any((j) => j.state.isActive) &&
        !(await service.executionStore.listExecutions(
          workItemId: workItemId,
        )).any((e) => !e.isTerminal);
    final deployGateMissing =
        item.state == WorkItemState.deploying &&
        item.blockingHumanDecisionId == null;

    // The deployed offers are computed from the same durable facts their
    // write paths re-check — the owed test each method applies and the
    // live-job refusal both share — so an offered button is one that can
    // complete, the same rule the deploy and reclaim offers keep.
    final deployedIdle =
        item.state == WorkItemState.deployed &&
        !jobs.any((j) => j.state.isActive);

    return WorkItemActionContextView(
      workItemId: workItemId,
      state: item.state.wire,
      actions: actionsFor(
        item.state,
        retryCount: _retryCount(recorded),
        limit: limit,
        deployableArtifact: deployable,
        deployGateMissing: deployGateMissing,
        strandedExecution: stranded,
        relandOwed: deployRelandIsOwed(item),
        deployedIdle: deployedIdle,
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

  /// WRITE. `qaPassed -> deploying`, then the `deploymentApproval` gate.
  ///
  /// The honest deploy sequence, in two durable steps: the transition asserts
  /// the artifact exists (`artifactBuilt()` reads `context['deploymentArtifact']`,
  /// built here from the PRODUCER'S OWN durable `AgentResult` — resolved by
  /// `resolveProducerExecution`, the platform's rule, never "whatever ran
  /// last"), and [requestHumanDecision] then parks the item at
  /// `waiting_for_human_decision` for a real approve/reject. A deploy is never
  /// TAKEN by this endpoint; it is asked for.
  ///
  /// The audit row ('deploy') rides the transition's own transaction. A crash
  /// between the two halves leaves the item at `deploying` with no gate: a
  /// replay of the same `requestId` finds its ledger row and finishes the
  /// raise, and a FRESH `requestId` on an item still at `deploying` with no
  /// blocking decision finishes it too — the interrupted advance is the same
  /// intent, not a second deploy.
  Future<WorkItemActionResult> advanceToDeploy(
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

    // (1) REPLAY. If the original request crashed between the transition and
    // the raise, the item sits at `deploying` gateless; finishing the raise
    // IS that intent, not a new action.
    if (_priorForAction(recorded, requestId, operatorDeployActionWire) !=
        null) {
      var item = await service.readWorkItem(workItemId);
      if (item.state == WorkItemState.deploying) {
        item = await raiseDeploymentApproval(
          workflowEngine: service.workflowEngine,
          workflowStore: service.workflowStore,
          item: item,
          actor: _operatorDeployActor,
          raisedBy: 'work_item_action.advanceToDeploy',
          log: (event, data) => service.logger.info(event, data),
        );
      }
      return _result(
        outcome: 'accepted',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    final item = await service.readWorkItem(workItemId);
    final trimmedReason = reason.trim();
    final trimmedBy = requestedBy.trim();

    // (2) Blank reason or requester is refused before anything is written.
    if (trimmedReason.isEmpty || trimmedBy.isEmpty) {
      return _result(
        outcome: 'invalidRequest',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    // (3) THE INTERRUPTED ADVANCE — `deploying` with no gate. The transition
    // already committed under an earlier intent; only the raise is owed. The
    // audit row is written first so a crash after it still converges: a
    // replay finds the row and finishes the raise.
    if (item.state == WorkItemState.deploying &&
        item.blockingHumanDecisionId == null) {
      await service.workflowStore.appendOperatorAction(
        OperatorActionRecord(
          actionId: 'oa-deploy-$requestId',
          workItemId: workItemId,
          action: operatorDeployActionWire,
          fromState: item.state.wire,
          toState: WorkItemState.waitingForHumanDecision.wire,
          requestedBy: trimmedBy,
          reason: trimmedReason,
          requestId: requestId,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      final parked = await raiseDeploymentApproval(
        workflowEngine: service.workflowEngine,
        workflowStore: service.workflowStore,
        item: item,
        actor: _operatorDeployActor,
        raisedBy: 'work_item_action.advanceToDeploy',
        log: (event, data) => service.logger.info(event, data),
      );
      service.logger.info('work_item.deploy.gate_raised', {
        'workItemId': workItemId,
        'requestId': requestId,
        'requestedBy': trimmedBy,
      });
      return _result(
        outcome: 'accepted',
        item: parked,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    if (item.state != WorkItemState.qaPassed ||
        !WorkItemTransitions.isLegalTransition(
          item.state,
          WorkItemState.deploying,
        )) {
      return _result(
        outcome: 'notApplicable',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    // (4) A live attempt is never stacked on.
    final jobs = await service.listJobsForWorkItem(workItemId);
    if (jobs.any((j) => j.state.isActive)) {
      return _result(
        outcome: 'alreadyRunning',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    // (5) THE ARTIFACT. No durable producer result means there is nothing
    // honest to deploy — refused rather than fabricated.
    final artifact = await deploymentArtifactFor(
      executionStore: service.executionStore,
      workerStore: service.workerStore,
      item: item,
      advanceId: requestId,
      builtBy: trimmedBy,
      raisedBy: 'work_item_action.advanceToDeploy',
      log: (event, data) => service.logger.info(event, data),
    );
    if (artifact == null) {
      service.logger.info('work_item.deploy.no_artifact', {
        'workItemId': workItemId,
      });
      return _result(
        outcome: 'notApplicable',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    // (6) THE ONE DURABLE WRITE, then the gate.
    try {
      final updated = await service.workflowEngine.transition(
        workItemId: workItemId,
        to: WorkItemState.deploying,
        trigger: TransitionTrigger.systemEvent,
        actor: _operatorDeployActor,
        context: {
          'deploymentArtifact': artifact,
          'operatorDeploy': true,
          'requestedBy': trimmedBy,
        },
        idempotencyKey: '$operatorDeployIdempotencyKeyPrefix$requestId',
        reason: trimmedReason,
        operatorAction: OperatorActionRecord(
          actionId: 'oa-deploy-$requestId',
          workItemId: workItemId,
          action: operatorDeployActionWire,
          fromState: item.state.wire,
          toState: WorkItemState.deploying.wire,
          requestedBy: trimmedBy,
          reason: trimmedReason,
          requestId: requestId,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      final parked = await raiseDeploymentApproval(
        workflowEngine: service.workflowEngine,
        workflowStore: service.workflowStore,
        item: updated,
        actor: _operatorDeployActor,
        artifactId: artifact.artifactId,
        raisedBy: 'work_item_action.advanceToDeploy',
        log: (event, data) => service.logger.info(event, data),
      );
      service.logger.info('work_item.deploy.accepted', {
        'workItemId': workItemId,
        'requestId': requestId,
        'requestedBy': trimmedBy,
        'state': parked.state.wire,
      });
      return _result(
        outcome: 'accepted',
        item: parked,
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

  /// WRITE. `agentExecuting -> agentFailed`, for a work item that claims to be
  /// running but nothing holds: no non-terminal `AgentExecution` and no active
  /// job.
  ///
  /// The scheduler's `_reclaimZombie` cannot reach this item — it only fires
  /// on held-job/stale-execution reconciliation, and a JOBLESS stranded item
  /// has no job to be reconciled through. This is the operator path for that
  /// hole: the item lands at `agent_failed`, where the existing retry surface
  /// takes over, and the audit row records the reclaim as its own action.
  ///
  /// Refusals mirror the retry's: a live execution or an active job means the
  /// item is NOT stranded (`alreadyRunning`), a blank reason is `invalidRequest`,
  /// and a refusal writes NOTHING.
  Future<WorkItemActionResult> reclaimStrandedExecution(
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

    // (1) REPLAY — same rule as retry: the ledger is the idempotency record.
    if (_priorForAction(recorded, requestId, operatorReclaimActionWire) !=
        null) {
      final item = await service.readWorkItem(workItemId);
      return _result(
        outcome: 'accepted',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    final item = await service.readWorkItem(workItemId);
    final trimmedReason = reason.trim();
    final trimmedBy = requestedBy.trim();

    if (trimmedReason.isEmpty || trimmedBy.isEmpty) {
      return _result(
        outcome: 'invalidRequest',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    if (item.state != WorkItemState.agentExecuting ||
        !WorkItemTransitions.isLegalTransition(
          item.state,
          WorkItemState.agentFailed,
        )) {
      return _result(
        outcome: 'notApplicable',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    // (2) STRANDED, PROVED — a non-terminal agent_execution row or a live job
    // means the item is not stranded at all, and reclaiming it would stack an
    // operator failure on top of live work.
    final executions = await service.executionStore.listExecutions(
      workItemId: workItemId,
    );
    if (executions.any((e) => !e.isTerminal)) {
      return _result(
        outcome: 'alreadyRunning',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }
    final jobs = await service.listJobsForWorkItem(workItemId);
    if (jobs.any((j) => j.state.isActive)) {
      return _result(
        outcome: 'alreadyRunning',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    // (3) THE ONE DURABLE WRITE. `agent_failed` is the honest landing: the
    // `_reclaimZombie` precedent — the only non-terminal exit out of
    // `agent_executing`, recoverable via the existing retry surface.
    try {
      final updated = await service.workflowEngine.transition(
        workItemId: workItemId,
        to: WorkItemState.agentFailed,
        trigger: TransitionTrigger.systemEvent,
        actor: _operatorReclaimActor,
        context: {'operatorReclaim': true, 'requestedBy': trimmedBy},
        idempotencyKey: '$operatorReclaimIdempotencyKeyPrefix$requestId',
        reason: trimmedReason,
        operatorAction: OperatorActionRecord(
          actionId: 'oa-reclaim-$requestId',
          workItemId: workItemId,
          action: operatorReclaimActionWire,
          fromState: item.state.wire,
          toState: WorkItemState.agentFailed.wire,
          requestedBy: trimmedBy,
          reason: trimmedReason,
          requestId: requestId,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      service.logger.info('work_item.reclaim.accepted', {
        'workItemId': workItemId,
        'requestId': requestId,
        'requestedBy': trimmedBy,
        'state': updated.state.wire,
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

  /// WRITE. `deployed` -> `deployed`, with the land the label always claimed.
  ///
  /// ## THE SHAPE IT EXISTS FOR — F-259
  ///
  /// An item whose `deployment_approval` resolved under the pre-deploy
  /// artifact — before `deploy_landing` existed — sits at `deployed` as a
  /// bare LABEL: `deployedCommit` NULL, nothing merged into any recorded
  /// checkout. The approval arm cannot reach it:
  /// `maybeLandApprovedDeployment` fires only on a PENDING
  /// `deployment_approval` resolution, and `deployed` has no edge back to a
  /// state that could raise one. Measured live: 13 items in exactly this
  /// shape.
  ///
  /// This is the operator action for that shape. It lands the produced
  /// commit through the SAME mechanism the approve path dispatches —
  /// [relandDeployedItem] over `landApprovedDeployment`: same producer
  /// resolution, same commit resolution, same verify-not-remerge merge, and
  /// since F-258 the same verified push to the product remote — then stamps
  /// the `deployed*` evidence and writes one `reland` audit row.
  /// The item does not move; the stamp is the change.
  ///
  /// ## THE OWED TEST
  ///
  /// [deployRelandIsOwed] is the whole predicate, kept in the deploy module
  /// next to the stamp keys it reads: `deployed` AND `deployedCommit`
  /// absent. A STAMPED item is `notApplicable` — nothing is owed, and
  /// re-landing it would overwrite the evidence it already carries (a
  /// stamped-but-unmerged item is a fabricated stamp, a different repair).
  /// A non-`deployed` item is `notApplicable` — the pending-approval path
  /// already owns that land. A no-producer, no-commit, missing-checkout or
  /// unverifiable-merge item is refused by the land itself as a
  /// [DeployLandingException], mapped here to `notApplicable` with the
  /// reason logged — every refusal writes NOTHING.
  ///
  /// ## ORDERING, AND WHAT A CRASH LEAVES
  ///
  /// The merge runs BEFORE any durable write and is verify-not-remerge, so a
  /// crash after it leaves the commit landed but unstamped — the next call
  /// takes the already-landed arm and stamps it, finishing the interrupted
  /// intent rather than merging twice. The stamp's compare-and-swap and the
  /// audit row commit in one transaction, in that order: a concurrent move
  /// fails the CAS before the audit row exists, so a refusal still writes
  /// nothing.
  ///
  /// ## OFFERED THROUGH `actionContext` — THE UI ARM LANDED WITH IT
  ///
  /// This action was originally withheld from [actionContext] on purpose:
  /// the control plane dispatches an offered action by wire token
  /// (`run_detail_bloc.dart`), and an action it did not name fell through to
  /// `stopFailedWorkItem` — a button that called the wrong method. The UI
  /// arm — the `reland` switch arm, its panel copy and its repository call —
  /// is now in place (F-260), so [actionsFor] offers it for a `deployed`
  /// item with no `deployedCommit` stamp and nothing live holding it, which
  /// is exactly the owed test plus the live-job refusal below.
  Future<WorkItemActionResult> relandDeployedWorkItem(
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

    // (1) REPLAY, before any read that could refuse: the ledger is the
    // idempotency record, exactly as it is for retry, deploy and reclaim. A
    // request that already happened reports what it did.
    if (_priorForAction(recorded, requestId, operatorRelandActionWire) !=
        null) {
      final item = await service.readWorkItem(workItemId);
      return _result(
        outcome: 'accepted',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    final item = await service.readWorkItem(workItemId);
    final trimmedReason = reason.trim();
    final trimmedBy = requestedBy.trim();

    // (2) Who and why. A merge into the product's own checkout is the most
    // consequential write on this surface, so the record must name both
    // before anything happens.
    if (trimmedReason.isEmpty || trimmedBy.isEmpty) {
      return _result(
        outcome: 'invalidRequest',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    // (3) THE OWED TEST, asked of the deploy module that owns the stamp
    // vocabulary: `deployed` AND no `deployedCommit`. Anything else has a
    // different path or nothing owed.
    if (!deployRelandIsOwed(item)) {
      service.logger.info('work_item.reland.not_owed', {
        'workItemId': workItemId,
        'state': item.state.wire,
        'deployedCommit': item.metadata?['deployedCommit'],
      });
      return _result(
        outcome: 'notApplicable',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    // (4) A live attempt is never merged on top of.
    final jobs = await service.listJobsForWorkItem(workItemId);
    if (jobs.any((j) => j.state.isActive)) {
      return _result(
        outcome: 'alreadyRunning',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    // (5) THE LAND. A [DeployLandingException] is the land's own refusal —
    // no producer, no commit, no recorded checkout, a merge that failed or
    // could not be verified — and nothing was merged or written. It is
    // mapped onto the surface's refusal vocabulary rather than thrown at
    // the operator.
    final DeployLanding landing;
    try {
      landing = await relandDeployedItem(
        executionStore: service.executionStore,
        workerStore: service.workerStore,
        item: item,
        deployPush: service.deployPusher,
        log: (event, data) => service.logger.info(event, data),
      );
    } on DeployLandingException catch (e) {
      service.logger.info('work_item.reland.refused', {
        'workItemId': workItemId,
        'reason': e.reason,
      });
      return _result(
        outcome: 'notApplicable',
        item: await service.readWorkItem(workItemId),
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    // (6) THE DURABLE WRITES. The stamp's compare-and-swap goes FIRST — it
    // is the statement that can fail on a concurrent writer, so ordering it
    // first is what keeps "a refusal writes nothing" true on a store that
    // cannot roll back. The audit row commits in the same transaction: a
    // crash between merge and stamp leaves the commit landed but unstamped,
    // which the next call finishes through the already-landed arm rather
    // than merging twice.
    final now = DateTime.now().toUtc();
    try {
      await service.workflowStore.inTransaction((tx) async {
        await tx.saveWorkItem(
          deployLandingStampedItem(
            item,
            landing: landing,
            mechanism: deployRelandMechanismName,
            at: now,
          ),
          expectedVersion: item.version,
        );
        await tx.appendOperatorAction(
          OperatorActionRecord(
            actionId: 'oa-reland-$requestId',
            workItemId: workItemId,
            action: operatorRelandActionWire,
            // The state does not move — `deployed` was already the label; the
            // stamp is the change — so from and to are honestly the same.
            fromState: item.state.wire,
            toState: item.state.wire,
            requestedBy: trimmedBy,
            reason: trimmedReason,
            requestId: requestId,
            createdAt: now,
          ),
        );
      });
    } on ConcurrentModificationException {
      // Someone else moved the item between the read and this write. The
      // merge is already verified idempotent, so the next attempt finishes
      // the same intent on the item it actually is — nothing was stamped,
      // nothing was audited.
      return _result(
        outcome: 'notApplicable',
        item: await service.readWorkItem(workItemId),
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    service.logger.info('work_item.reland.accepted', {
      'workItemId': workItemId,
      'requestId': requestId,
      'requestedBy': trimmedBy,
      'commit': landing.commit,
      'repositoryPath': landing.repositoryPath,
      'targetBranch': landing.targetBranch,
      'headAfter': landing.headAfter,
      'alreadyLanded': landing.alreadyLanded,
      'commitBasis': landing.commitBasis,
    });
    return _result(
      outcome: 'accepted',
      item: await service.readWorkItem(workItemId),
      limit: limit,
      retryCount: _retryCount(recorded),
    );
  }

  /// WRITE. `deployed -> implementationReady` — the rework path for a deploy
  /// that can never be made true (F-261).
  ///
  /// ## THE SHAPE IT EXISTS FOR
  ///
  /// A `deployed` item whose re-land refuses — the producer completed but
  /// left NO commit, so there is nothing honest to merge — has no other
  /// exit: `deployed -> completed` is the only edge out, and completing it
  /// would record work that was never produced as shipped. The reroute is
  /// the honest answer: the item goes back to the implementation lane's own
  /// entry state, where the ordinary tick re-dispatches it, and one
  /// `reroute` audit row names the human who asked. Measured live: six
  /// items stranded in exactly this shape.
  ///
  /// It applies to a `deployed` item whether or not it carries a
  /// `deployedCommit` stamp — the owed test is the STATE alone, because the
  /// question this action answers ("send this back to implementation") is
  /// the same question for a label-only deploy and for a real deploy being
  /// reworked. A non-`deployed` item is `notApplicable`: every other state
  /// has its own surface.
  ///
  /// ## THE EDGE IS NOT FREE
  ///
  /// The transition goes through [DurableWorkflowEngine.transition] against
  /// the real table, which guards `deployed -> implementationReady` with
  /// `actorAllowed([orchestrator])` AND `operatorRerouteRequested()`. The
  /// second guard reads [operatorRerouteContextKey] from the transition
  /// context — set below and only below — so no sweep or engine path that
  /// happens to hold an orchestrator actor can walk a deployed item
  /// backwards without the audit row this action writes in the same
  /// transaction.
  ///
  /// ## THE DISCRIMINATOR
  ///
  /// The item re-enters `implementationReady`, whose `implement_feature`
  /// dedupe key the run that produced this deploy already consumed —
  /// `enqueueIfAbsent` would refuse the re-run's key and the rerouted item
  /// would sit dispatchable forever with nothing running, which is the
  /// exact silent no-op the `triageAttempt` marker exists to close. The
  /// bump is [DurableWorkflowEngine.nextTriageAttempt] with the highest
  /// attempt this item's own `implement_feature` jobs consumed as the
  /// floor — the same second-watermark rule the review repair applies to
  /// `engineering_review` jobs — computed BEFORE the write so an
  /// unreadable marker fails with nothing written.
  ///
  /// ## REFUSALS WRITE NOTHING
  ///
  /// Replay (`accepted` reporting the prior intent), blank reason or
  /// requester (`invalidRequest`), a non-`deployed` state
  /// (`notApplicable`), a live job (`alreadyRunning`), and the engine's own
  /// rejection all return before or inside a write that never happens —
  /// the `operatorAction` audit row rides the transition's transaction, so
  /// a rejected transition writes no row.
  ///
  /// ## OFFERED THROUGH `actionContext` — THE UI ARM LANDED WITH IT
  ///
  /// Same history as [relandDeployedWorkItem]: the action was withheld
  /// until the control plane could dispatch and render it, and that arm —
  /// the `reroute` switch arm, its panel copy and its repository call — is
  /// now in place (F-262). [actionsFor] offers it for any idle `deployed`
  /// item, stamped or not, because the owed test here is the state alone.
  Future<WorkItemActionResult> rerouteToImplementation(
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

    // (1) REPLAY, before any read that could refuse: the ledger is the
    // idempotency record, exactly as it is for retry, deploy, reclaim and
    // reland. A request that already happened reports what it did.
    if (_priorForAction(recorded, requestId, operatorRerouteActionWire) !=
        null) {
      final item = await service.readWorkItem(workItemId);
      return _result(
        outcome: 'accepted',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    final item = await service.readWorkItem(workItemId);
    final trimmedReason = reason.trim();
    final trimmedBy = requestedBy.trim();

    // (2) Who and why. Sending deployed work back into production is a
    // consequential move, so the record must name both before anything
    // happens.
    if (trimmedReason.isEmpty || trimmedBy.isEmpty) {
      return _result(
        outcome: 'invalidRequest',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    // (3) THE OWED TEST — `deployed`, and the reroute edge exists in the
    // real table. Anything else has a different path or nothing owed.
    if (item.state != WorkItemState.deployed ||
        !WorkItemTransitions.isLegalTransition(
          item.state,
          WorkItemState.implementationReady,
        )) {
      service.logger.info('work_item.reroute.not_owed', {
        'workItemId': workItemId,
        'state': item.state.wire,
      });
      return _result(
        outcome: 'notApplicable',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    // (4) A live attempt is never stacked on.
    final jobs = await service.listJobsForWorkItem(workItemId);
    if (jobs.any((j) => j.state.isActive)) {
      return _result(
        outcome: 'alreadyRunning',
        item: item,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }

    // (5) THE DISCRIMINATOR, before the write — the same ordering the
    // review repair keeps: an unreadable `triageAttempt` marker throws here
    // with nothing written rather than landing an item whose next dedupe
    // key collides with the job that stranded it.
    final attempt = DurableWorkflowEngine.nextTriageAttempt(
      item,
      floor: _consumedImplementAttempt(jobs),
    );

    // (6) THE ONE DURABLE WRITE. State, transition record, audit row and
    // the `triageAttempt` marker are one commit — the `operatorReroute`
    // context key is what the edge's second guard reads.
    try {
      final updated = await service.workflowEngine.transition(
        workItemId: workItemId,
        to: WorkItemState.implementationReady,
        trigger: TransitionTrigger.systemEvent,
        actor: _operatorRerouteActor,
        context: {
          operatorRerouteContextKey: true,
          'requestedBy': trimmedBy,
        },
        idempotencyKey: '$operatorRerouteIdempotencyKeyPrefix$requestId',
        reason: trimmedReason,
        // MERGED, never replacing: the defect payload the re-run's
        // instruction reads must survive the reroute.
        metadataMerge: {
          DurableWorkflowEngine.triageAttemptMetadataKey: attempt,
        },
        operatorAction: OperatorActionRecord(
          actionId: 'oa-reroute-$requestId',
          workItemId: workItemId,
          action: operatorRerouteActionWire,
          fromState: item.state.wire,
          toState: WorkItemState.implementationReady.wire,
          requestedBy: trimmedBy,
          reason: trimmedReason,
          requestId: requestId,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      service.logger.info('work_item.reroute.accepted', {
        'workItemId': workItemId,
        'requestId': requestId,
        'requestedBy': trimmedBy,
        'state': updated.state.wire,
        'version': updated.version,
        'triageAttempt': attempt,
      });
      return _result(
        outcome: 'accepted',
        item: updated,
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    } on WorkflowTransitionRejectedException {
      // The edge refused — a concurrent move, or a context the guard does
      // not admit. Nothing was taken, so nothing is audited; the rejected
      // transition record already carries the attempt and its key.
      return _result(
        outcome: 'notApplicable',
        item: await service.readWorkItem(workItemId),
        limit: limit,
        retryCount: _retryCount(recorded),
      );
    }
  }

  // ---------------------------------------------------------------------
  // Deploy + reclaim internals
  // ---------------------------------------------------------------------

  /// The actor the deploy advance transitions as: [ActorType.orchestrator],
  /// the only type `qaPassed -> deploying` permits, named for the path the
  /// human acted through — exactly the convention [operatorRetryActor] keeps.
  static const WorkflowActor _operatorDeployActor = WorkflowActor(
    actorId: 'operator-deploy',
    actorType: ActorType.orchestrator,
  );

  /// The actor the reclaim transitions as. `agentExecuting -> agentFailed`
  /// permits the orchestrator alone; `operator-reclaim` names the path.
  static const WorkflowActor _operatorReclaimActor = WorkflowActor(
    actorId: 'operator-reclaim',
    actorType: ActorType.orchestrator,
  );

  /// The actor the reroute transitions as. `deployed -> implementationReady`
  /// permits the orchestrator alone; `operator-reroute` names the path —
  /// the second guard on that edge additionally requires the
  /// [operatorRerouteContextKey] marker this action alone sets.
  static const WorkflowActor _operatorRerouteActor = WorkflowActor(
    actorId: 'operator-reroute',
    actorType: ActorType.orchestrator,
  );

  // The artifact build and the decision raise the deploy advance is made of
  // are SHARED with the deploy-gate sweep in `../deploy/deploy_advance.dart`:
  // the sweep fires the same advance for every `qa_passed` item, and two
  // constructions of "what is being deployed" must never drift apart.

  /// The first ledger row for this exact operator intent, by raw wire token —
  /// the 'deploy'/'reclaim' actions are not [OperatorActionKind] members.
  static OperatorActionRecord? _priorForAction(
    List<OperatorActionRecord> recorded,
    String requestId,
    String actionWire,
  ) => recorded
      .where((a) => a.requestId == requestId && a.action == actionWire)
      .firstOrNull;

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
    bool deployableArtifact = false,
    bool deployGateMissing = false,
    bool strandedExecution = false,
    bool relandOwed = false,
    bool deployedIdle = false,
  }) {
    // THE DEPLOY ADVANCE — `qaPassed -> deploying`, offered only when the
    // caller has already established that the producer's durable result can
    // build the artifact `artifactBuilt()` requires (the write path builds it
    // again; the flag only decides whether the BUTTON exists). The second arm
    // is the interrupted advance: an item at `deploying` whose
    // `deployment_approval` gate was never raised (a crash between the
    // transition and the decision write) has no other way out, so the same
    // action is offered to finish it.
    final deployOffered =
        (from == WorkItemState.qaPassed &&
            deployableArtifact &&
            WorkItemTransitions.isLegalTransition(
              from,
              WorkItemState.deploying,
            )) ||
        (from == WorkItemState.deploying &&
            deployGateMissing &&
            WorkItemTransitions.isLegalTransition(
              from,
              WorkItemState.waitingForHumanDecision,
            ));
    if (deployOffered) {
      return [
        WorkItemActionView(
          action: operatorDeployActionWire,
          toState: WorkItemState.waitingForHumanDecision.wire,
          // Asking to deploy is asking for a decision, not taking one — the
          // confirm strip is still required, and the decision itself stays
          // the human's.
          confirmRequired: true,
          destructive: false,
          attemptLimit: limit.wireAttemptLimit,
        ),
      ];
    }

    // THE STRANDED RECLAIM — offered only when the caller PROVED the item is
    // stranded: `agent_executing` with no non-terminal AgentExecution and no
    // active job. Offered blindly it would be a button that "reclaims" live
    // work, so the flag is computed from durable rows in `actionContext`, and
    // the write path re-checks it.
    if (from == WorkItemState.agentExecuting &&
        strandedExecution &&
        WorkItemTransitions.isLegalTransition(
          from,
          WorkItemState.agentFailed,
        )) {
      return [
        WorkItemActionView(
          action: operatorReclaimActionWire,
          toState: WorkItemState.agentFailed.wire,
          confirmRequired: true,
          destructive: false,
          attemptLimit: limit.wireAttemptLimit,
        ),
      ];
    }

    // THE DEPLOYED PAIR (F-260, F-262).
    //
    // 'reland' is offered only for a LABEL-ONLY deploy — `deployed` with no
    // `deployedCommit` stamp — because [deployRelandIsOwed] is the whole owed
    // test: a stamped item has nothing owed, and re-landing it would
    // overwrite the evidence it already carries.
    //
    // 'reroute' is offered for ANY deployed item, stamped or not. That is the
    // honest condition — the write path's owed test is the STATE alone,
    // because "send this back to implementation" is the same question for a
    // label-only deploy and for a real deploy being reworked: a landed item
    // can legitimately be sent back to build. An unstamped item therefore
    // gets both: land it (make the record true) or send it back.
    //
    // `deployedIdle` is the caller's PROOF that nothing live holds the item,
    // computed in `actionContext` from the same job rows both write paths
    // refuse on (`alreadyRunning`) — the same durable-facts rule the deploy
    // and reclaim offers keep: an offered button is one that can complete.
    if (from == WorkItemState.deployed && deployedIdle) {
      return [
        if (relandOwed)
          WorkItemActionView(
            action: operatorRelandActionWire,
            // The item does not move — `deployed` was already the label and
            // the stamp is the change — so the target is honestly the same
            // state. There is no edge to ask the table about.
            toState: WorkItemState.deployed.wire,
            confirmRequired: true,
            destructive: false,
            attemptLimit: limit.wireAttemptLimit,
          ),
        if (WorkItemTransitions.isLegalTransition(
          from,
          WorkItemState.implementationReady,
        ))
          WorkItemActionView(
            action: operatorRerouteActionWire,
            toState: WorkItemState.implementationReady.wire,
            confirmRequired: true,
            destructive: false,
            attemptLimit: limit.wireAttemptLimit,
          ),
      ];
    }

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
  // The review repair: an operator path for a work item parked behind a
  // decision that claims a reviewer verdict nobody produced.
  // ---------------------------------------------------------------------

  /// WRITE. Returns a work item parked behind a fabricated engineering-review
  /// decision to `agentCompleted` — retryable and dispatchable — and retires the
  /// decision without destroying it.
  ///
  /// ## WHY THIS IS NOT A TRANSITION
  ///
  /// `waitingForHumanDecision -> agentCompleted` has no edge in
  /// `WorkItemTransitions`, exactly as `agentCompleted ->
  /// waitingForHumanDecision` never had one (`engineering_review_gate.dart`
  /// reaches the gate by entering `reviewInProgress` first). Nothing in the
  /// state machine models "a question was asked that nobody asked", so this
  /// writes the item directly inside one transaction, and says in its audit row
  /// that no edge was taken. The same is true of every repair migration in this
  /// repository, and the reason is the same: there is no edge to take.
  ///
  /// ## WHAT IT IS PROVABLY SCOPED TO
  ///
  /// [readReviewVerdictProvenance] decides repairability, and it decides from the
  /// REVIEWER'S OWN durable result. The decision's `metadata` is read only for the
  /// execution id it names; its `reviewVerdict` is never taken as evidence that
  /// anyone reviewed anything. Only [ReviewAssessment.noReviewerOutput] — no
  /// result at all, or a result with neither a structured payload nor a
  /// summary — reaches the write, and only for a decision that IS an
  /// `engineering_review`.
  ///
  /// ## WHAT IT REFUSES, AND WHY EACH REFUSAL IS THE SAFE SIDE
  ///
  ///  * [ReviewAssessment.assessed] → `reviewerProducedVerdict`. A reviewer
  ///    really returned this verdict. Discarding it would destroy a real review.
  ///    This is the guardrail, and it is the whole reason the provenance is
  ///    RE-DERIVED rather than read off the decision.
  ///  * [ReviewAssessment.reviewerProseOnly] → `reviewerProducedProse`. A real
  ///    reviewer wrote a real assessment that the machine channel failed to
  ///    capture and the operator has never seen. Measured live in QA on
  ///    2026-10-14: one such reviewer wrote
  ///    *"**Verdict: `APPROVE_WITH_NON_BLOCKING_FOLLOWUP`**"* while the decision
  ///    it produced claimed `changes_required`. Refusing here is deliberate and
  ///    is the conservative side of the choice — an operator-triggered path that
  ///    can throw away a genuine review is worse than the bug it repairs. The
  ///    operator's safe answer on one of these is to RESOLVE the decision
  ///    (reject routes to `reviewRejected`, a triage entry state), which keeps
  ///    the reviewer's prose on the execution record.
  ///  * [ReviewAssessment.unreadable] → `reviewerOutputUnreadable`. "I could not
  ///    check" is not "there was nothing there".
  ///  * a decision that is not an `engineering_review` at all →
  ///    `decisionTypeNotReviewable`. Said TWICE on purpose, by two independent
  ///    gates — step (5) reads `decisionType` off the row, and step (6) asks
  ///    [readReviewVerdictProvenance], which classifies the same fact as
  ///    [ReviewAssessment.decisionTypeNotReviewable] — because this is the one
  ///    method here that can void a PENDING human decision and it must not fail
  ///    OPEN. Until 2026-10-15 both gates answered "no reviewer output", the only
  ///    repairable class, for all eighteen non-review types: a pending
  ///    `deployment_approval` or `destructive_migration_approval` was retired as
  ///    "unreviewed" and its work item re-queued. Latent in production (both
  ///    `requestHumanDecision` callers raise `engineeringReview`, and every other
  ///    blocking type uses a synthetic scope that is not a `work_item` row), but
  ///    the affordance's documentation promised a refusal that did not exist, and
  ///    a documented safety property that is false is worse than an undocumented
  ///    one because it is relied on. See
  ///    [ReviewAssessment.decisionTypeNotReviewable].
  ///  * a decision a human has already RESOLVED → `alreadyDecided`. Someone
  ///    answered the question. Overwriting that answer is not a repair, it is
  ///    discarding a real human decision — and QA has one on record: an operator
  ///    approved `dec-hn7h7daum6-2atjhe`, whose reviewer had in fact timed out,
  ///    and the work item moved to `reviewApproved`. This refusal is what stops
  ///    this method being the thing that did that.
  ///
  ///    THE OPERATOR HAS SINCE GONE THE OTHER WAY ON THAT ONE, and the two
  ///    positions are deliberately not the same. Voiding a human approval is
  ///    `HUMAN_DECISION_REQUIRED` by construction: migration
  ///    `20261014210000000` did it for all five fabricated decisions under
  ///    recorded decision `8f1ed5bf-4147-449a-a221-558aac2303a9`, after being
  ///    shown that one of them had an approval resting on nothing. THIS method
  ///    still refuses, because an operator clicking a button on one item is not
  ///    that: the consent was given for five named rows with a stated reason,
  ///    and generalising it to an ad-hoc action would hand the one authority
  ///    nobody granted it. The two decisions disagree on purpose.
  ///  * a decision that is not the item's blocking one, or an item not at
  ///    `waitingForHumanDecision` → `notApplicable`. There is nothing parked.
  ///  * a non-terminal job → `alreadyRunning`. A second operator action must not
  ///    be layered on a live attempt.
  ///  * a blank reason or a blank requester → `invalidRequest`. The record must
  ///    say who and why.
  ///
  /// EVERY refusal returns before the transaction opens, so every refusal writes
  /// NOTHING — no audit row, no decision change, no version bump.
  ///
  /// ## THE FRESH DEDUPE KEY IS AN ARITHMETIC BORROW, NOT A RE-DERIVATION
  ///
  /// `engineeringReviewDedupeKey` (packages/scheduler/lib/src/scheduler.dart)
  /// builds `'<workItemId>:engineering_review'` plus `':a<n>'` when
  /// `metadata.triageAttempt` is readable — and the terminal job that stranded
  /// the item already holds its key, so the item is inert without a bump. The
  /// bump reuses [DurableWorkflowEngine.nextTriageAttempt] with the HIGHEST
  /// attempt this item's own `engineering_review` jobs have consumed as the
  /// floor, which is the same second-watermark rule
  /// `20261014093000000` used for the triage key and the same one
  /// `operatorRetry` uses. The arithmetic is not restated here; only the floor
  /// is computed, and it is computed from the item's own job rows so the key it
  /// writes is provably unheld.
  ///
  /// ## REPLAY
  ///
  /// `requestId` is minted by the caller once per operator intent. A repeat
  /// finds its own audit row by idempotency key and returns what that request
  /// DID, without writing again — so a double-click cannot mint a second
  /// discriminator bump, which would queue a second review.
  ///
  /// ## ON THE WIRE
  ///
  /// Serverpod dispatches methods from the GENERATED connector table
  /// (`lib/src/generated/endpoints.dart`), and the matching client method lives
  /// in `packages/control_plane_client/lib/src/protocol/client.dart`. This
  /// method used to carry `@doNotGenerate` and to return a hand-written Dart
  /// class, which made it unreachable from any control-plane client: the
  /// generator emits an import for a file it never writes, and a type declared
  /// outside `lib/src/models/` appears ZERO times in `protocol.dart`, so the
  /// `SerializationManager` cannot decode the return value in either direction.
  /// A green `dart analyze` on the server proved nothing about that, because
  /// nothing exercised it.
  ///
  /// [ReviewRepairResult] is therefore a YAML model
  /// (`lib/src/models/review_repair_result.yaml`) and the connector row, the
  /// client method, the serialization entry and both generated copies all come
  /// from `serverpod generate`. The evidence that closed it is in
  /// docs/engineering/learning/a-generated-client-can-reference-a-file-it-never-emitted.md
  /// and the wire proof is `apps/server/test/integration/review_repair_wire_e2e_test.dart`,
  /// which drives this method through the REAL generated client over HTTP.
  Future<ReviewRepairResult> repairUnreviewedReview(
    Session session, {
    required String workItemId,
    required String requestId,
    required String requestedBy,
    required String reason,
    String? decisionId,
  }) async {
    final service = serviceFor(session);

    // (1) REPLAY, before any read that could refuse: a request that already
    // happened reports what it did, whatever the item has become since.
    final prior = await service.workflowStore.findTransitionByIdempotencyKey(
      workItemId,
      reviewRepairIdempotencyKey(requestId),
    );
    if (prior != null) {
      return ReviewRepairResult(
        outcome: 'accepted',
        detail:
            'this operator intent was already carried out; reporting it rather '
            'than running it a second time',
        workItem: UiViewMappers.workItemView(
          await service.readWorkItem(prior.workItemId),
        ),
        decisionId: prior.decisionId,
      );
    }

    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty || requestedBy.trim().isEmpty) {
      return _refuse(
        service,
        workItemId,
        'invalidRequest',
        'the action must record who pressed it and why; both were blank',
      );
    }

    final item = await service.readWorkItem(workItemId);
    final blockingId = item.blockingHumanDecisionId;

    // (2) THERE IS NOTHING PARKED. Not an error — the item has moved on since
    // the operator looked at it.
    if (blockingId == null ||
        item.state != WorkItemState.waitingForHumanDecision) {
      return _refuse(
        service,
        workItemId,
        'notApplicable',
        'this work item is at ${item.state.wire} with '
            '${blockingId == null ? 'no blocking decision' : 'a blocking decision '
                      'that is not holding it'}, so there is no fabricated question to '
            'repair',
        decisionId: blockingId,
      );
    }

    // (3) THE DECISION NAMED MUST BE THE ONE HOLDING THE ITEM. Repairing some
    // other pending decision on the same item would clear a gate that a real
    // reviewer had raised.
    if (decisionId != null && decisionId != blockingId) {
      return _refuse(
        service,
        workItemId,
        'notApplicable',
        'decision $decisionId is not the decision holding this item '
            '($blockingId is)',
        decisionId: decisionId,
      );
    }

    final decision = await service.workflowStore.readHumanDecision(blockingId);

    // (4) A HUMAN ALREADY ANSWERED, OR SOMETHING ALREADY CLOSED IT.
    //
    // `isResolved` is false for `cancelled`, so two further arms are needed and
    // they are DIFFERENT facts, kept apart deliberately:
    //
    //  * the marker means THIS METHOD retired it before, and re-running must
    //    not queue a second review;
    //  * a bare `cancelled` means something ELSE closed it, so writing the
    //    marker here would assert a retirement that did not happen.
    //
    // Both refuse, because "the decision is no longer pending" is the only
    // thing either of them establishes, and over either is discarding a real
    // human decision.
    //
    // THIS ARM IS NOT OBSOLETE AFTER MIGRATION 20261014210000000, and it is
    // worth saying why, because the migration voided exactly the decision this
    // arm was named after. The `choice != null` arm is what now catches it:
    // migration `20261014210000000` sets `status = cancelled` but does NOT
    // write `decider`, `choice`, `rationale`, `signatureJson`,
    // `resolvedOptionId` or `timestamp`, so the recorded approval is still
    // there and this method still refuses. Widening the migration to clear
    // those columns would erase the evidence that a human approved anything,
    // and would make this arm blind to exactly the case it exists for.
    final alreadyRetired =
        decisionIsRetiredUnreviewed(decision) ||
        decision.status == HumanDecisionStatus.cancelled;
    if (decision.isResolved || decision.choice != null || alreadyRetired) {
      return _refuse(
        service,
        workItemId,
        'alreadyDecided',
        alreadyRetired
            ? 'this decision was already retired as unreviewable and is kept '
                  'only as a record'
            : 'a human already resolved this decision '
                  '(choice ${decision.choice?.wire ?? 'unknown'} by '
                  '${decision.decider ?? 'unknown'}); repairing it would '
                  'discard a real human decision, and QA holds one of those',
        decisionId: decision.decisionId,
      );
    }

    // (5) THE DECISION TYPE GATE — defence in depth, and the FIRST of two
    // independent gates.
    //
    // [readReviewVerdictProvenance] answers
    // [ReviewAssessment.decisionTypeNotReviewable] for a decision that is not an
    // engineering review, which is already a refusal. This does not rely on that
    // being true. The refusal here does not depend on the reader's
    // classification at all: it reads `decisionType` off the row itself and says
    // no.
    //
    // Two gates on one path is proportionate and not redundant belt-and-braces.
    // This is the only path in the repository that can retire a PENDING HUMAN
    // DECISION, and the reader is one `if` away from being re-classified by a
    // future change to the reviewer's result shape — a change with every reason
    // to look innocuous. If that happened and the classification moved, one gate
    // would refuse and the other would write, and which one won would depend on
    // which side of a single `if` a reader happened to fall. The gates are
    // independent by construction (one reads the decision's type, the other reads
    // the reviewer's durable result), they are ordered, and they agree.
    //
    // Checked BEFORE the provenance read so the cheapest, most fundamental
    // question is asked first, and so a future reader that returned
    // [ReviewAssessment.noReviewerOutput] here would still be caught by step (6)
    // rather than reaching the write.
    if (decision.decisionType != HumanDecisionType.engineeringReview) {
      return _refuse(
        service,
        workItemId,
        'decisionTypeNotReviewable',
        'this work item is parked behind a ${decision.decisionType.wire} '
            'decision, not an engineering review, so no reviewer verdict is '
            'claimed by it and there is nothing here for this repair to have '
            'fabricated. Answer the question the decision is actually asking, '
            'or resolve it — nothing has been changed',
        decisionId: decision.decisionId,
        logContext: {'decisionType': decision.decisionType.wire},
      );
    }

    // (6) THE FABRICATION TEST. Re-derived from the reviewer's own result,
    // never read off the decision. This is the guardrail, and it is the SECOND
    // of the two independent gates: it is asked of the REVIEWER'S OWN durable
    // result, on a decision already known to be an engineering review, and it
    // is what decides repairability among the classes that remain.
    final provenance = await readReviewVerdictProvenance(
      executionStore: service.executionStore,
      decision: decision,
    );
    if (!provenance.assessment.isRepairable) {
      return _refuse(
        service,
        workItemId,
        // EXHAUSTIVE on purpose. The `_` this replaced defaulted every unknown
        // class to `reviewerOutputUnreadable`, which would mislabel a
        // `decisionTypeNotReviewable` read as a reader failure — the exact
        // conflation [ReviewAssessment.decisionTypeNotReviewable] exists to stop.
        // A new arm now breaks this switch at compile time instead of silently
        // acquiring the wrong sentence.
        switch (provenance.assessment) {
          ReviewAssessment.assessed => 'reviewerProducedVerdict',
          ReviewAssessment.reviewerProseOnly => 'reviewerProducedProse',
          ReviewAssessment.unreadable => 'reviewerOutputUnreadable',
          ReviewAssessment.decisionTypeNotReviewable =>
            'decisionTypeNotReviewable',
          ReviewAssessment.noReviewerOutput =>
            'reviewerOutputUnreadable', // unreachable: isRepairable is true.
        },
        switch (provenance.assessment) {
          ReviewAssessment.assessed =>
            'a reviewer really returned '
                '${provenance.verdict?.wire ?? 'a verdict'} for this work item '
                '(${provenance.detail}), so this is a real question and '
                'repairing it would discard a real review result',
          ReviewAssessment.reviewerProseOnly =>
            'the verdict this decision claims is still unsupported, but a real '
                'reviewer assessment exists and the operator has never been '
                'shown it: ${provenance.detail}. Read it, then resolve the '
                'decision — repairing it here would throw that assessment away',
          // Reachable only if step (5) is ever removed. It must still say what
          // was checked, so the operator is not told a reader failed.
          ReviewAssessment.decisionTypeNotReviewable =>
            '${provenance.detail}. This repair only applies to engineering '
                'review decisions, so nothing is changed',
          _ =>
            '${provenance.detail}. "I could not check" is not "there was '
                'nothing there", so nothing is changed',
        },
        decisionId: decision.decisionId,
        logContext: {
          'assessment': provenance.assessment.name,
          'reviewExecutionId': provenance.reviewExecutionId,
        },
      );
    }

    // (7) A LIVE ATTEMPT IS NEVER STACKED ON.
    final jobs = await service.listJobsForWorkItem(workItemId);
    if (jobs.any((j) => j.state.isActive)) {
      return _refuse(
        service,
        workItemId,
        'alreadyRunning',
        'this work item already holds a non-terminal job, so a repair would '
            'be layered on top of a live attempt',
        decisionId: decision.decisionId,
      );
    }

    // (8) THE DISCRIMINATOR, computed BEFORE the write so an unreadable marker
    // fails with nothing written — the same discipline `operatorRetry` uses.
    final attempt = DurableWorkflowEngine.nextTriageAttempt(
      item,
      floor: _consumedReviewAttempt(jobs),
    );
    final now = DateTime.now().toUtc();
    final updated = item.copyWith(
      state: WorkItemState.agentCompleted,
      blockingHumanDecisionId: null,
      blockingReason: null,
      // MERGED, never replacing: the defect payload the next triage or review
      // reads must survive, or the re-run classifies nothing while looking
      // healthy.
      metadata: Map<String, dynamic>.from(item.metadata ?? const {})
        ..[DurableWorkflowEngine.triageAttemptMetadataKey] = attempt,
      updatedAt: now,
      version: item.version + 1,
    );

    // (9) THE ONE DURABLE WRITE. The work item's compare-and-swap goes FIRST:
    // it is the only statement that can fail on a concurrent writer, so
    // ordering it first is what makes "a refusal writes nothing" true on a
    // store that cannot roll back (`InMemoryWorkflowStore.inTransaction` is
    // `body(this)` — there is no rollback to rely on here).
    try {
      await service.workflowStore.inTransaction((tx) async {
        await tx.saveWorkItem(updated, expectedVersion: item.version);
        // The decision is RETIRED, not deleted and not rewritten: status
        // `cancelled`, everything a human could read preserved verbatim
        // (question, options, recommendation, context), and a marker naming
        // why. `HumanDecision.copyWith` offers exactly `status`, `metadata` and
        // `updatedAt` — it deliberately refuses `decider`/`choice`/
        // `rationale`/`signature`, so this cannot forge an approval even by
        // accident.
        await tx.saveHumanDecision(
          decision.copyWith(
            status: HumanDecisionStatus.cancelled,
            metadata: {
              ...(decision.metadata ?? const <String, dynamic>{}),
              reviewUnreviewableMetadataKey: true,
              'reviewUnreviewableRetiredAt': now.toIso8601String(),
              'reviewUnreviewableRetiredBy': requestedBy.trim(),
              'reviewUnreviewableReason': trimmedReason,
              'reviewUnreviewedExecutionId': provenance.reviewExecutionId,
              'reviewUnreviewableAssessment': provenance.assessment.name,
              'reviewUnreviewableDetail': provenance.detail,
              // What the decision CLAIMED, kept verbatim as evidence and
              // explicitly NOT as a verdict.
              'reviewUnreviewableClaimedVerdict': decision
                  .metadata?['reviewVerdict']
                  ?.toString(),
            },
            updatedAt: now,
          ),
        );
        await tx.appendTransitionRecord(
          WorkflowTransitionRecord(
            transitionId: reviewRepairTransitionId(requestId),
            workItemId: workItemId,
            fromState: item.state,
            toState: WorkItemState.agentCompleted,
            trigger: TransitionTrigger.systemEvent,
            actorType: ActorType.orchestrator,
            actorId: requestedBy.trim(),
            decisionId: decision.decisionId,
            outcome: TransitionOutcome.accepted,
            reason: _repairReason(
              decision: decision,
              provenance: provenance,
              fromAttempt: DurableWorkflowEngine.readTriageAttempt(item),
              jobFloor: _consumedReviewAttempt(jobs),
              toAttempt: attempt,
              by: requestedBy.trim(),
              because: trimmedReason,
            ),
            idempotencyKey: reviewRepairIdempotencyKey(requestId),
            occurredAt: now,
          ),
        );
      });
    } on ConcurrentModificationException {
      // Someone else moved the item between the read and this write. Nothing
      // was taken, so nothing is audited.
      return _refuse(
        service,
        workItemId,
        'concurrentWrite',
        'this work item was moved by another writer while the repair was being '
            'applied; nothing was changed',
        decisionId: decision.decisionId,
      );
    }

    service.logger.info('work_item.review_repair.accepted', {
      'workItemId': workItemId,
      'decisionId': decision.decisionId,
      'requestId': requestId,
      'requestedBy': requestedBy.trim(),
      'assessment': provenance.assessment.name,
      'reviewExecutionId': provenance.reviewExecutionId,
      'fromTriageAttempt': DurableWorkflowEngine.readTriageAttempt(item),
      'toTriageAttempt': attempt,
    });
    return ReviewRepairResult(
      outcome: 'accepted',
      detail:
          'the decision was retired as unreviewable and the work item returned '
          'to agent_completed at review attempt $attempt',
      workItem: UiViewMappers.workItemView(updated),
      decisionId: decision.decisionId,
    );
  }

  /// A refusal. Reads the item once and writes NOTHING.
  Future<ReviewRepairResult> _refuse(
    ControlPlaneService service,
    String workItemId,
    String outcome,
    String detail, {
    String? decisionId,
    Map<String, dynamic>? logContext,
  }) async {
    service.logger.info('work_item.review_repair.refused', {
      'workItemId': workItemId,
      'decisionId': decisionId,
      'outcome': outcome,
      'detail': detail,
      ...?logContext,
    });
    return ReviewRepairResult(
      outcome: outcome,
      detail: detail,
      workItem: UiViewMappers.workItemView(
        await service.readWorkItem(workItemId),
      ),
      decisionId: decisionId,
    );
  }

  /// The highest attempt number this item's OWN `engineering_review` jobs have
  /// already consumed, as the second watermark for the discriminator.
  ///
  /// Reads the item's real job rows rather than assuming a number, for the same
  /// reason `20261014093000000` did: the only place an attempt number can
  /// already have a holder is a job, so taking the max over the jobs is what
  /// makes the key this writes provably unheld. An UNSUFFIXED key consumes no
  /// attempt and so contributes nothing, which is correct — it is the bare
  /// `workItemId:engineering_review` form that every attempt suffix moves away
  /// from.
  static int _consumedReviewAttempt(List<Job> jobs) {
    var floor = 0;
    for (final job in jobs) {
      if (job.jobType != JobType.engineeringReview) continue;
      final match = RegExp(r':engineering_review:a(\d+)$').firstMatch(
        job.dedupeKey,
      );
      if (match == null) continue;
      final value = int.tryParse(match.group(1)!);
      if (value != null && value > floor) floor = value;
    }
    return floor;
  }

  /// The highest attempt number this item's OWN `implement_feature` jobs
  /// have already consumed, as the second watermark for the reroute's
  /// discriminator — the same shape [_consumedReviewAttempt] computes for
  /// review jobs, for the same reason: the only place an
  /// `implement_feature` dedupe key can already have a holder is a job, so
  /// taking the max over the jobs is what makes the `triageAttempt` the
  /// reroute writes provably unheld. An UNSUFFIXED key consumes no attempt
  /// and so contributes nothing; the bump to `1` is what moves a rerouted
  /// item off the bare `<workItemId>:implement_feature` key its stranded
  /// run still holds.
  static int _consumedImplementAttempt(List<Job> jobs) {
    var floor = 0;
    for (final job in jobs) {
      if (job.jobType != JobType.implementFeature) continue;
      final match = RegExp(r':implement_feature:a(\d+)$').firstMatch(
        job.dedupeKey,
      );
      if (match == null) continue;
      final value = int.tryParse(match.group(1)!);
      if (value != null && value > floor) floor = value;
    }
    return floor;
  }

  /// The audit row's `reason`: what happened, what was NOT taken, and why.
  static String _repairReason({
    required HumanDecision decision,
    required ReviewVerdictProvenance provenance,
    required int? fromAttempt,
    required int jobFloor,
    required int toAttempt,
    required String by,
    required String because,
  }) =>
      'Operator review repair, by $by: $because. The blocking engineering '
      'review decision ${decision.decisionId} claimed the verdict '
      '"${decision.metadata?['reviewVerdict'] ?? 'none'}", but re-deriving '
      'the verdict from the REVIEWER\'S OWN durable result found none: '
      '${provenance.detail}. The decision is RETIRED, not deleted: its status '
      'is cancelled, every human-readable field is preserved verbatim, and it '
      'carries a marker naming this repair, so the claim stays on the record as '
      'evidence. The work item returns to agent_completed, which IS '
      'engineeringReviewDefinition.entryStates, and metadata.triageAttempt '
      'advances from ${fromAttempt ?? 'absent'} to $toAttempt so '
      'engineeringReviewDedupeKey offers a key no engineering_review job holds '
      '(the highest attempt this item\'s own review jobs had consumed was '
      '$jobFloor, and the discriminator is greatest(marker, that floor) + 1). '
      'NO TRANSITION EDGE WAS TAKEN: '
      'waitingForHumanDecision -> agentCompleted does not exist in '
      'WorkItemTransitions, because no edge models "a question was asked that '
      'nobody asked", so the state is written directly inside one transaction '
      'with this row as its record. No verdict was invented, none was read '
      'from the decision itself, and no row outside human_decision, work_item '
      'and work_item_transition was written.';

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

// ---------------------------------------------------------------------------
// The review repair: vocabulary.
//
// NOT server-authored UI copy. Every string here is a wire value or a
// log-line-safe sentence, and the control plane words it — the same boundary
// `WorkItemActionResult.outcome` keeps. `detail` is deliberately diagnostic
// rather than presentational: it is the "why", and it is the whole value of a
// refusal that an operator has to act on.
// ---------------------------------------------------------------------------

/// The `human_decision.metadata` key naming a decision as RETIRED because no
/// reviewer produced the verdict it claims.
///
/// It is a durable marker rather than a status, because `HumanDecisionStatus`
/// has no member meaning "this question was never really asked" and adding one
/// would be a `platform_contracts` change — a shared-type change belonging to a
/// different owner. The status is set to
/// [HumanDecisionStatus.cancelled] alongside it; this key is what says WHY.
///
/// Read by exactly ONE call site — this endpoint's replay and double-repair
/// refusal. That is stated rather than glossed because an earlier revision of
/// this comment claimed three readers, naming
/// `WorkflowEndpoints.resolveDecision` and the decision projections. Neither
/// reads it: `resolveDecision` has no marker check, and the operator-UI reads
/// key off `blockingHumanDecisionId` and `isResolved` instead, which a retired
/// decision fails on either count. A comment that claims a reader which does not
/// exist is worse than no comment, because the next reader concludes the
/// property is enforced somewhere and stops checking.
///
/// Migration `20261014210000000` writes this same key, so the marker is a
/// SHARED vocabulary between the migration and this method and not a private
/// one — which is why it lives at the top level with a name rather than as a
/// constant buried in a method.
const String reviewUnreviewableMetadataKey = 'reviewUnreviewable';

/// The repair action's idempotency-key prefix. A REPLAY KEY ONLY, exactly like
/// [operatorRetryIdempotencyKeyPrefix]: a caller that formats it correctly has
/// authorised nothing, and nothing treats it as a predicate.
const String reviewRepairIdempotencyKeyPrefix = 'review-repair:';

/// The idempotency key one operator intent writes.
///
/// Deterministic in the caller's `requestId`, so a replay — a lost response, a
/// double-click — finds its own row and does nothing. It is deliberately NOT
/// derived from the work item: a work item that is fabricated a SECOND time,
/// months later, must be repairable again, and a per-item key would forbid
/// that for ever.
String reviewRepairIdempotencyKey(String requestId) =>
    '$reviewRepairIdempotencyKeyPrefix$requestId';

/// The audit row id one operator intent writes. Deterministic in `requestId`
/// for the same reason the idempotency key is, and distinct from every earlier
/// repair's prefix in this repository (`tr-stranded-repair-`,
/// `tr-stranded-exec-repair-`, `tr-dedupe-bump-repair-`,
/// `tr-stranded-key-repair-`, `tr-product-repoint-`) so no rollback of one of
/// those can delete this action's rows.
String reviewRepairTransitionId(String requestId) =>
    'tr-review-repair-$requestId';

// ---------------------------------------------------------------------------
// WHAT A PENDING `engineering_review` DECISION ACTUALLY RESTS ON.
//
// This is the guardrail, so it is written down once and read by the repair and
// by nothing else — there is exactly one caller, and one caller cannot come to
// disagree with itself. A SECOND copy of "did a reviewer return a verdict" is
// how a repair and the guard that protects the repair come to disagree about
// which decisions are repairable, and the disagreement is silent: the repair
// would discard a review the guard had promised to protect.
//
// THE DECISION'S OWN CLAIM IS NEVER EVIDENCE. `HumanDecision.metadata` is read
// for the execution id it names and for nothing else; its `reviewVerdict` says
// nothing about whether anyone reviewed the code, which is the whole defect this
// read exists to settle.
// ---------------------------------------------------------------------------

/// What a reviewer actually produced, read back from the reviewer's OWN durable
/// result.
///
/// The four classes exist because "the decision claims a verdict" and "a
/// reviewer produced one" come apart, and the ways they come apart need
/// DIFFERENT answers. Collapsing them into a boolean is how the repair would
/// come to discard real reviews.
enum ReviewAssessment {
  /// A [ReviewVerdict] a reviewer actually produced is present in the reviewer's
  /// own `AgentResult`. NEVER repairable.
  assessed,

  /// The reviewer produced nothing a human or a machine could read: no result at
  /// all, or a result whose structured payload is empty AND whose human summary
  /// is empty too. This is the ONLY repairable class.
  noReviewerOutput,

  /// A reviewer turn COMPLETED and wrote human-readable prose into the result's
  /// `summary`, but no machine-readable verdict.
  ///
  /// Deliberately NOT repairable, and this is the class the guardrail exists for.
  /// The decision's verdict claim is still fabricated — nothing in the machine
  /// channel supports it — but a human assessment of the code EXISTS, it is
  /// durable, and the operator has never been shown it. Repairing one of these
  /// would silently throw away a review a real reviewer spent real credits
  /// producing.
  ///
  /// MEASURED LIVE IN QA ON 2026-10-14, which is why this class is not
  /// theoretical. Two reviewer executions COMPLETED and wrote 2000 characters of
  /// prose each, while the decisions they produced claimed `changes_required`:
  ///
  ///   * `agx-wx-jb-hn7gq1n2dc-1llxxyk` (`defect-DEF-1791685024220546`)
  ///     opens *"## Engineering Review"* and states **"Verdict:
  ///     `APPROVE_WITH_NON_BLOCKING_FOLLOWUP`"**, then reviews the fix,
  ///     verifies the `qaContractDefectIdMetadataKey` swap is value-preserving,
  ///     and lists three non-blocking findings.
  ///   * `agx-wx-jb-hn7itcezii-1igc7vp` (`defect-DEF-1791686357139031`)
  ///     confirms all three diagnoses by inspection, checks the round-trip drift
  ///     is the real blank-page cause, and checks two claims the commit message
  ///     does NOT make.
  ///
  /// A repair keyed on "no machine-readable verdict" would have destroyed both.
  reviewerProseOnly,

  /// A result exists and could not be read, or names an execution that is not
  /// readable. Never repairable: "I could not check" must not be laundered into
  /// "there was nothing there".
  unreadable,

  /// The decision is not an engineering review at all, so there is no reviewer
  /// whose output this action could have fabricated.
  ///
  /// NEVER repairable, and it is its OWN arm rather than an overload of
  /// [unreadable] because it is a different statement. [unreadable] says "I
  /// could not check"; this says "this is not the kind of thing I repair". Only
  /// one of those is true here, and conflating them would tell the operator a
  /// reader failed when in fact there was never anything to read.
  ///
  /// ## WHY THIS ARM EXISTS AT ALL — EIGHTEEN OF NINETEEN TYPES
  ///
  /// [readReviewVerdictProvenance] used to answer [noReviewerOutput] for every
  /// non-review decision type — the ONLY repairable class — with the reason
  /// "this is not an engineering review decision, so no reviewer verdict is
  /// claimed by it". That reason is true and the conclusion drawn from it was
  /// exactly backwards: "no verdict is claimed" is not "a verdict was
  /// fabricated", and the difference is the whole subject of this repair. Eighteen
  /// of the nineteen [HumanDecisionType]s — `deployment_approval`,
  /// `destructive_migration_approval`, `securityDecision` and the rest — took that
  /// path, so a single operator click would retire a live, pending, consequential
  /// human question as "unreviewed" and re-queue the work behind it.
  ///
  /// It was LATENT rather than live: both `requestHumanDecision` callers raise
  /// `engineeringReview`, and every other blocking type uses a synthetic scope
  /// that is not a `work_item` row, so no non-review decision could reach this
  /// method in production as the code stands. It is still a HIGH rather than a
  /// theoretical one, for two reasons that survive the latency: this is the one
  /// path in the repository that can void a human decision, so it must not be the
  /// path that fails OPEN; and the affordance's own documentation promises the
  /// server refuses an unrepairable item, which was false for 18 of 19 types. A
  /// documented safety property that is false is worse than an undocumented one,
  /// because it is relied on.
  decisionTypeNotReviewable;

  /// Whether this class may be repaired by the operator action.
  ///
  /// Exactly one class may, and this getter is the single place that says so, so
  /// the action and its refusal cannot drift apart.
  bool get isRepairable => this == ReviewAssessment.noReviewerOutput;
}

/// The outcome of reading a decision's verdict provenance: WHAT was found, and
/// the reviewer execution it was read from.
class ReviewVerdictProvenance {
  const ReviewVerdictProvenance({
    required this.assessment,
    required this.decisionId,
    required this.workItemId,
    this.reviewExecutionId,
    this.verdict,
    this.detail = '',
  });

  final ReviewAssessment assessment;
  final String decisionId;
  final String workItemId;

  /// The reviewer execution the decision names, or null when it names none.
  final String? reviewExecutionId;

  /// The verdict the reviewer actually produced, when it produced one. Null in
  /// every other case — and in particular null NEVER means
  /// [ReviewVerdict.changesRequired] or any other stand-in.
  final ReviewVerdict? verdict;

  /// One sentence naming what was found and where. Carried on refusal paths so
  /// the operator is told WHY, not only THAT.
  final String detail;
}

/// Reads the reviewer verdict provenance of [decision].
///
/// [executionStore] is the reviewer's own execution store, and the ONLY thing
/// consulted.
///
/// ## THE ORDER OF THE ARMS IS THE GATE'S ORDER
///
/// `EngineeringReviewGate._readReviewVerdict` reads an embedded
/// `engineeringReviewResult` first and falls THROUGH to a top-level `verdict` on
/// a parse failure. This reads the same two arms in the same order, with the
/// same two fail-closed outcomes, and it deliberately does NOT simplify either:
/// an answer that is right about "the reviewer was silent" and wrong about "the
/// reviewer answered in a form we can read" is an answer that will eventually
/// let a real verdict be repaired away.
///
/// ## NOTHING HERE INVENTS A VERDICT
///
/// There is no default member and no fallback. Every path either reports the
/// verdict the reviewer actually produced or reports that it could not find one,
/// and [ReviewAssessment.unreadable] exists so that "I could not read the
/// result" is never silently read as "the reviewer said nothing".
///
/// ## IT NEVER THROWS
///
/// Every failure mode resolves to [ReviewAssessment.unreadable] with the reason
/// in [ReviewVerdictProvenance.detail], because a repair action that crashed on
/// a bad row would leave the item exactly as stuck as it was and would tell the
/// operator nothing.
Future<ReviewVerdictProvenance> readReviewVerdictProvenance({
  required ExecutionStore executionStore,
  required HumanDecision decision,
}) async {
  if (decision.decisionType != HumanDecisionType.engineeringReview) {
    // NOT `noReviewerOutput`. See [ReviewAssessment.decisionTypeNotReviewable]:
    // answering "the reviewer said nothing" here answered a question nobody
    // asked, and the only repairable class was the one it picked.
    return ReviewVerdictProvenance(
      assessment: ReviewAssessment.decisionTypeNotReviewable,
      decisionId: decision.decisionId,
      workItemId: decision.workItemId,
      detail:
          'this is a ${decision.decisionType.wire} decision, not an engineering '
          'review, so it claims no reviewer verdict and there is no reviewer '
          'output for this action to have fabricated',
    );
  }

  final metadata = decision.metadata ?? const <String, dynamic>{};
  final rawExecutionId = metadata['reviewExecutionId'];
  final executionId = rawExecutionId is String ? rawExecutionId : '';
  if (executionId.isEmpty) {
    return ReviewVerdictProvenance(
      assessment: ReviewAssessment.noReviewerOutput,
      decisionId: decision.decisionId,
      workItemId: decision.workItemId,
      detail:
          'this decision names no reviewer execution, so there is no reviewer '
          'output behind it at all',
    );
  }

  final AgentResult? result;
  try {
    result = await executionStore.readResult(executionId);
  } on Object catch (error) {
    return ReviewVerdictProvenance(
      assessment: ReviewAssessment.unreadable,
      decisionId: decision.decisionId,
      workItemId: decision.workItemId,
      reviewExecutionId: executionId,
      detail: 'the reviewer result could not be read: $error',
    );
  }
  if (result == null) {
    return ReviewVerdictProvenance(
      assessment: ReviewAssessment.noReviewerOutput,
      decisionId: decision.decisionId,
      workItemId: decision.workItemId,
      reviewExecutionId: executionId,
      detail:
          'reviewer execution $executionId reached a terminal state without '
          'writing an agent result',
    );
  }

  // The reader refuses on an unreadable payload for the same reason the gate
  // does: `structuredResult` throws on malformed JSON, and "the reviewer
  // answered in something this build cannot parse" is not "the reviewer said
  // nothing".
  final Map<String, dynamic> structured;
  try {
    structured = result.structuredResult;
  } on Object catch (error) {
    return ReviewVerdictProvenance(
      assessment: ReviewAssessment.unreadable,
      decisionId: decision.decisionId,
      workItemId: decision.workItemId,
      reviewExecutionId: executionId,
      detail: 'the reviewer result payload could not be read: $error',
    );
  }

  // ARM 1 — the embedded, fully-formed result. Read first, exactly as the gate
  // reads it, and a verdict is taken from it only when the WHOLE result parses:
  // a half-parsed assessment is not a verdict.
  final embedded = structured['engineeringReviewResult'];
  if (embedded is Map) {
    try {
      final parsed = EngineeringReviewResult.fromJson(
        Map<String, dynamic>.from(embedded),
      );
      return ReviewVerdictProvenance(
        assessment: ReviewAssessment.assessed,
        decisionId: decision.decisionId,
        workItemId: decision.workItemId,
        reviewExecutionId: executionId,
        verdict: parsed.verdict,
        detail:
            'the reviewer returned an embedded engineering review result '
            'carrying the verdict ${parsed.verdict.wire}',
      );
    } on Object {
      // FALLS THROUGH to arm 2, deliberately, for the reason the gate gives:
      // that path can still produce an honest verdict from the same payload.
    }
  }

  // ARM 2 — a top-level wire verdict. `ReviewVerdict.fromWire` throws on
  // anything outside the closed set of four, and that throw is the answer: an
  // unrecognised string is a reviewer answering in a dialect this build does
  // not speak, which is not an assessment and is certainly not "no assessment".
  final rawVerdict = structured['verdict'];
  if (rawVerdict is String && rawVerdict.isNotEmpty) {
    try {
      final verdict = ReviewVerdict.fromWire(rawVerdict);
      return ReviewVerdictProvenance(
        assessment: ReviewAssessment.assessed,
        decisionId: decision.decisionId,
        workItemId: decision.workItemId,
        reviewExecutionId: executionId,
        verdict: verdict,
        detail:
            'the reviewer returned the verdict ${verdict.wire} in its own '
            'result payload',
      );
    } on Object catch (error) {
      return ReviewVerdictProvenance(
        assessment: ReviewAssessment.unreadable,
        decisionId: decision.decisionId,
        workItemId: decision.workItemId,
        reviewExecutionId: executionId,
        detail: "'$rawVerdict' is not a review verdict ($error)",
      );
    }
  }

  // NO VERDICT IN THE MACHINE CHANNEL. What distinguishes the two remaining
  // classes is whether a reviewer wrote anything a human could read: the
  // `summary` is where this repository stores a reviewer's prose, and it is
  // truncated at 2000 characters by the runtime. Both classes exist in QA today
  // — see [ReviewAssessment.reviewerProseOnly] for the two that do.
  final summary = result.summary?.trim() ?? '';
  if (summary.isEmpty) {
    return ReviewVerdictProvenance(
      assessment: ReviewAssessment.noReviewerOutput,
      decisionId: decision.decisionId,
      workItemId: decision.workItemId,
      reviewExecutionId: executionId,
      detail:
          'reviewer execution $executionId produced no agent result payload '
          'and no summary, so there is no reviewer output of any kind',
    );
  }
  return ReviewVerdictProvenance(
    assessment: ReviewAssessment.reviewerProseOnly,
    decisionId: decision.decisionId,
    workItemId: decision.workItemId,
    reviewExecutionId: executionId,
    detail:
        'reviewer execution $executionId wrote ${summary.length} characters of '
        'review into its summary but no machine-readable verdict, so a real '
        'assessment exists and must be read before it is discarded',
  );
}

/// Whether [decision] has already been RETIRED by a repair.
///
/// The durable marker is checked rather than the status alone, because
/// `HumanDecisionStatus.cancelled` is reachable by other routes and only this
/// marker means "no reviewer produced the verdict this claims". The value is
/// compared to `true` rather than tested for presence, so a row that carries the
/// key for any other reason is not mistaken for a retired one.
bool decisionIsRetiredUnreviewed(HumanDecision decision) =>
    (decision.metadata?[reviewUnreviewableMetadataKey] ?? false) == true;
