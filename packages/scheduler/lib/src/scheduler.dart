import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'capacity/execution_capacity.dart';
import 'capacity/job_capacity_guard.dart';
import 'dispatch/worker_dispatch.dart';
import 'health/provider_health_monitor.dart';
import 'policy/retry_policy.dart';
import 'policy/runnable_work.dart';
import 'queue/job_queue.dart';
import 'store/job_store.dart';

/// Static place-and-run parameters the scheduler stamps into every job. The
/// scheduler itself never owns a worker, a workspace, or an agent runtime;
/// it merely carries the worker-facing configuration that was decided when
/// the platform was configured.
@immutable
class SchedulerWorkload {
  const SchedulerWorkload({
    required this.repositoryPath,
    required this.startingRevision,
    required this.timeoutSeconds,
    required this.runtimeTypeId,
    this.cleanupPolicy = WorkerCleanupPolicy.removeAlways,
  });

  final String repositoryPath;
  final String startingRevision;
  final int timeoutSeconds;
  final String runtimeTypeId;
  final WorkerCleanupPolicy cleanupPolicy;
}

/// What reconciliation was able to observe about the process behind a
/// non-terminal worker execution.
///
/// This exists because liveness is not a property that can be read off a status
/// string. A live worker and a worker whose process died mid-execution both
/// leave a row that is not terminal, and the old reconciler asked only the
/// second question, which is why a zombie outlived a 10 minute lease for hours.
enum ExecutionLiveness {
  /// Observed alive right now. Renew the lease; never dispatch a duplicate.
  alive,

  /// Observed NOT alive. Nothing is running, so the claim must be reclaimed.
  dead,

  /// Liveness could not be observed from here.
  unknown,
}

/// Observes whether anything is still running behind [execution].
///
/// Injected rather than derived because the scheduler cannot answer this from
/// durable state alone: the worker row records what the execution was doing,
/// not whether the process doing it still exists. A probe that can actually
/// observe the runtime (the coordinator's live sessions, a worker heartbeat, an
/// agent-runtime query) is what turns "is this row terminal" into "is there a
/// process behind it".
typedef ExecutionLivenessProbe =
    Future<ExecutionLiveness> Function(WorkerExecution execution, DateTime now);

/// Builds the probe that answers liveness from a live-session oracle.
///
/// The oracle is the thing that actually knows: a predicate over an AGENT
/// execution id that is true only while a session for it is running in this
/// process. The composition root supplies the real one — the execution
/// coordinator's live-session set — and this function owns the DECISION about
/// what a failed observation means, which is the part worth testing and the
/// part that is easy to get backwards.
///
/// It lives here, next to [ExecutionLiveness] and the staleness bound it feeds,
/// rather than in the composition root, because a fail-direction rule that
/// cannot be executed is a rule nobody has checked. The composition root still
/// chooses WHAT to observe; this only says what to conclude.
///
/// ## Fail direction
///
/// `unknown` — renew the lease, let the staleness bound decide — is returned
/// whenever liveness cannot be observed:
///
///  * an execution that recorded no agent execution id has nothing to ask
///    about. That is an absence of evidence, not evidence of death, and
///    reporting `dead` would let a worker be reclaimed because its first agent
///    execution id failed to persist;
///  * an oracle that throws, for the same reason.
///
/// `unknown` does NOT reclaim immediately. Live work is never killed on a
/// failure to observe, and a duplicate is never dispatched; an execution this
/// probe genuinely cannot see falls back to the staleness bound, which is what
/// stops an unobservable zombie from being renewed forever.
ExecutionLivenessProbe liveSessionLivenessProbe(
  bool Function(String agentExecutionId) hasLiveSession,
) {
  return (WorkerExecution execution, DateTime now) async {
    final agentExecutionId = execution.agentExecutionId;
    if (agentExecutionId == null || agentExecutionId.isEmpty) {
      return ExecutionLiveness.unknown;
    }
    try {
      return hasLiveSession(agentExecutionId)
          ? ExecutionLiveness.alive
          : ExecutionLiveness.dead;
    } catch (_) {
      return ExecutionLiveness.unknown;
    }
  };
}

/// Function to build a dedupe key for a work item.
typedef DedupeKeyBuilder =
    String Function(WorkItem item, JobDefinition definition);

/// Function to build an instruction for a work item.
typedef InstructionBuilder =
    String Function(WorkItem item, JobDefinition definition);

/// Function to build a worker execution request for a job.
typedef RequestBuilder =
    Future<WorkerExecutionRequest> Function(
      Job job,
      SchedulerWorkload workload,
      WorkItem item,

      /// Null when the Scheduler was constructed without a model selector, in
      /// which case a builder must leave the request's model unpinned.
      ModelSelectionService? modelSelection,
    );

/// Resolves the per-role model policy into a request's runtime config.
///
/// Model pinning is opt-in. Without a [ModelSelectionService] the returned map
/// is empty, the request carries no model override, and the adapter applies
/// its own default — so constructing a Scheduler without a selector behaves
/// exactly as it did before per-role model selection existed.
///
/// The escalation index is read from `WorkItem.metadata`, which is the single
/// durable home for it.
Future<Map<String, String>> modelRuntimeConfig(
  Job job,
  WorkItem item,
  ModelSelectionService? modelSelection,
) async {
  if (modelSelection == null) return const {};
  final escalationIndex = item.metadata?['escalationIndex'] as int? ?? 0;
  final selection = await modelSelection.select(
    role: job.requiredRole,
    escalationIndex: escalationIndex,
  );
  return {
    'model': selection.modelId,
    'provider': selection.provider,
    'escalationIndex': selection.escalationIndex.toString(),
    'isFallback': selection.isFallback.toString(),
  };
}

/// What one [Scheduler.tick] did, for tests and for the audit tail.
@immutable
class SchedulerTickResult {
  const SchedulerTickResult({
    required this.reconciled,
    required this.enqueued,
    required this.dispatched,
    required this.cancelledQueued,
    required this.deferred,
    required this.terminal,
  });

  final List<String> reconciled;
  final List<String> enqueued;
  final List<String> dispatched;
  final List<String> cancelledQueued;
  final List<String> deferred;
  final List<String> terminal;
}

/// The durable scheduler: derivation + enqueue + dispatch + outcome adoption
/// for ONE job type (this slice implements feature implementation). It asks
/// worker_runtime for placement and worker selection, workflow_engine for
/// legal-execution policy, and workflow_store for work item state. It defines
/// no workflow transition and starts no execution on its own.
class Scheduler {
  Scheduler({
    required String schedulerId,
    required WorkflowStore workflowStore,
    required JobStore jobStore,
    required WorkerStore workerStore,
    required WorkerDispatch dispatch,
    required JobDefinition definition,
    required SchedulerWorkload workload,
    DateTime Function()? clock,
    this.claimLease = const Duration(minutes: 10),
    ExecutionLivenessProbe? executionLiveness,
    Duration? zombieStalenessAfter,
    WorkflowEngine? policy,
    ModelSelectionService? modelSelection,
    DedupeKeyBuilder? dedupeKeyBuilder,
    InstructionBuilder? instructionBuilder,
    RequestBuilder? requestBuilder,
    ProviderHealthMonitor? providerHealthMonitor,
    this.capacityGuard,
  }) : schedulerId = schedulerId,
       _workflowStore = workflowStore,
       _jobStore = jobStore,
       _workerStore = workerStore,
       _dispatch = dispatch,
       _definition = definition,
       _workload = workload,
       _clock = clock ?? DateTime.now,
       _evaluator = RunnableWorkEvaluator(
         policy: policy ?? const WorkflowEngine(),
       ),
       // Built over the store this scheduler already reads work items from, and
       // over the SAME policy object `RunnableWorkEvaluator` uses, so a reclaim
       // cannot decide an edge that scheduling would consider illegal.
       //
       // Present because a reclaim has to move the work item, not just the job.
       // It exists ONLY for that; the scheduler otherwise never writes workflow
       // state, and `policy` stays the optional injection it always was.
       _reclaimEngine = DurableWorkflowEngine(
         store: workflowStore,
         policy: policy,
       ),
       _queue = JobQueue(store: jobStore, clock: clock),
       _dedupeKeyBuilder = dedupeKeyBuilder ?? _defaultDedupeKey,
       _instructionBuilder = instructionBuilder ?? _defaultInstruction,
       _modelSelection = modelSelection,
       _requestBuilder = requestBuilder ?? _defaultRequest,
       _executionLiveness = executionLiveness,
       _configuredZombieStaleness = zombieStalenessAfter,
       _providerHealthMonitor = providerHealthMonitor;

  final String schedulerId;
  final Duration claimLease;

  final WorkflowStore _workflowStore;
  final JobStore _jobStore;
  final WorkerStore _workerStore;
  final WorkerDispatch _dispatch;
  final JobDefinition _definition;
  final SchedulerWorkload _workload;
  final DateTime Function() _clock;
  final RunnableWorkEvaluator _evaluator;
  final DurableWorkflowEngine _reclaimEngine;

  /// How many times a reclaim re-reads the work item and retries after losing
  /// the store's compare-and-swap. Bounded on purpose: a reclaim must converge
  /// against ordinary contention without spinning against a writer that is
  /// rewriting the item continuously.
  static const int _maxReclaimAttempts = 3;

  /// The actor a reclaim transitions as. [ActorType.orchestrator] is what the
  /// `agentExecuting -> agentFailed` edge permits, and it is what the scheduler
  /// already acts as everywhere else in the transition graph.
  static const WorkflowActor _reclaimActor = WorkflowActor(
    actorId: 'scheduler',
    actorType: ActorType.orchestrator,
  );
  final JobQueue _queue;
  final RetryPolicy _retryPolicy = const RetryPolicy();
  final DedupeKeyBuilder _dedupeKeyBuilder;
  final InstructionBuilder _instructionBuilder;
  final ModelSelectionService? _modelSelection;
  final RequestBuilder _requestBuilder;
  final ProviderHealthMonitor? _providerHealthMonitor;

  /// Observes whether the process behind a non-terminal execution is alive.
  /// Null means this scheduler has no way to observe it, which is itself a
  /// visible state rather than a silent default: reconciliation then falls back
  /// to the [zombieStalenessBound] window instead of renewing forever.
  final ExecutionLivenessProbe? _executionLiveness;

  final Duration? _configuredZombieStaleness;

  /// The longest a non-terminal execution may go unobserved before it is
  /// reclaimed. This is the bound that turns "fail open" into "fail open, but
  /// not forever" - the difference between protecting live work and the
  /// indefinite renewal that let a zombie outlive its lease for hours.
  Duration get zombieStalenessBound {
    final configured = _configuredZombieStaleness;
    if (configured != null) return configured;
    // A worker execution legitimately outlasts its agent only by the work
    // around it: workspace preparation, the coordinator's independent
    // verification, and cleanup. Four agent budgets plus one claim lease is far
    // beyond any honest execution and far below a multi-hour stall.
    return Duration(seconds: _workload.timeoutSeconds * 4) + claimLease;
  }

  /// One line for a startup log naming the liveness policy in force. A
  /// scheduler that cannot observe liveness must say so, because the
  /// diagnostic is otherwise invisible.
  String get livenessSummary => _executionLiveness == null
      ? 'execution liveness NOT observable from this scheduler: a '
            'non-terminal execution is renewed until it has been non-terminal '
            'for ${zombieStalenessBound.inMinutes}m, then reclaimed.'
      : 'execution liveness observable; a non-terminal execution proven dead is '
            'reclaimed, and one unobservable past ${zombieStalenessBound.inMinutes}m '
            'is reclaimed.';

  /// The global execution-capacity budget, enforced at claim time. Null means
  /// this scheduler is UNBOUNDED, and that is a deliberate, visible state
  /// rather than a default:
  ///
  ///  * the cap is required configuration
  ///    ([ExecutionCapacityResolution.fromEnvironment] resolves nothing when
  ///    the environment variable is absent or unusable, so an unbounded
  ///    scheduler cannot be produced by accident from a missing value);
  ///  * the composition root owns wiring it, and [capacitySummary] is meant to
  ///    be surfaced in the startup log so an operator can see which of the two
  ///    states a running process is in.
  ///
  /// A process running with a null guard has no bound on concurrent agent
  /// executions beyond whatever the worker registry happens to enforce.
  final JobCapacityGuard? capacityGuard;

  /// One line describing the capacity policy actually in force, for a startup
  /// log. Never omits the fact that a cap is missing — the failure this guards
  /// against is invisible, so the diagnostic has to carry it.
  String get capacitySummary => capacityGuard == null
      ? 'execution capacity NOT configured: this scheduler is UNBOUNDED and '
            'will dispatch as many agent executions as the queue offers. Set '
            '$executionCapacityEnvVar and inject a capacity guard before '
            'starting the scheduler.'
      : capacityGuard!.capacity.startupSummary;

  JobQueue get queue => _queue;

  static String _defaultDedupeKey(WorkItem item, JobDefinition definition) =>
      '${item.workItemId}:${item.state.wire}:${definition.jobType.wire}:'
      '${definition.requiredRole.wire}';

  static String _defaultInstruction(WorkItem item, JobDefinition definition) =>
      'Implement "${item.title}" (${item.workItemId}) inside the worktree.';

  static Future<WorkerExecutionRequest> _defaultRequest(
    Job job,
    SchedulerWorkload workload,
    WorkItem item,
    ModelSelectionService? modelSelection,
  ) async {
    final runtimeConfig = await modelRuntimeConfig(job, item, modelSelection);
    return WorkerExecutionRequest(
      workerExecutionId: 'wx-${job.jobId}',
      workItemId: job.workItemId,
      repositoryPath: workload.repositoryPath,
      startingRevision: workload.startingRevision,
      requiredCapabilities: job.requiredCapabilities,
      role: job.requiredRole,
      instruction: job.instruction,
      timeoutSeconds: workload.timeoutSeconds,
      runtimeTypeId: workload.runtimeTypeId,
      cleanupPolicy: workload.cleanupPolicy,
      runtimeConfig: runtimeConfig,
    );
  }

  /// One full, synchronous pass over the durable state. Deterministic:
  /// ordering is fixed, the process is event-loop serialized, and every step
  /// re-reads the store so re-entrant or interleaved ticks behave identically.
  Future<SchedulerTickResult> tick() async {
    final now = _clock().toUtc();
    final reconciled = <String>[];
    final enqueued = <String>[];
    final dispatched = <String>[];
    final cancelledQueued = <String>[];
    final deferred = <String>[];
    final terminal = <String>[];

    // 1. Recover claims that outlived their lease without ever persisting a
    //    terminal outcome.
    //
    //    Each row is reconciled inside its own guard. One unreconcilable row —
    //    a concurrent writer, a transient store fault — must not abort the loop
    //    and starve every OTHER expired claim behind it. This is defence in
    //    depth, NOT a substitute for handling failures at their source: the
    //    reclaim path catches its own rejection signals, and a test asserts that
    //    it does so without relying on this guard.
    //
    //    A row that throws is deliberately NOT added to `reconciled`: it did not
    //    reconcile. Its claim is still held and still expired, so the next tick
    //    picks it up again — the failure is a delay, never a loss.
    for (final job in await _jobStore.listJobs()) {
      final isHeld =
          job.state == JobState.claimed || job.state == JobState.running;
      if (!isHeld) continue;
      final claim = await _jobStore.readClaimForJob(job.jobId);
      final expired = claim == null || claim.isExpiredAt(now);
      if (!expired) continue;
      try {
        await _reconcileClaim(job, claim, now);
        reconciled.add(job.jobId);
      } catch (_) {
        // Swallowed deliberately, and this is the honest accounting of it: the
        // scheduler has no log channel of its own, so the only observable
        // effect is that this job is absent from `reconciled` and retried on the
        // next tick. Adding a logger is a composition-root change this lane does
        // not own.
        continue;
      }
    }

    // 2. Ask the WORKFLOW POLICY what it may schedule for every item. Never a
    //    local reconstruction of the transition graph.
    final items = await _workflowStore.readAllWorkItems();
    items.sort((a, b) => a.workItemId.compareTo(b.workItemId));
    final byId = {for (final i in items) i.workItemId: i};
    final statusOf = {
      for (final i in items) i.workItemId: _evaluator.evaluate(i, _definition),
    };

    // 3. Terminal items: cancel any residual queued jobs. Runnable items:
    //    enqueue the missing job idempotently. Blocked/no-action items: leave
    //    every existing job untouched (never cancelled, never dispatched).
    for (final item in items) {
      final status = statusOf[item.workItemId]!;
      switch (status) {
        case RunnableWorkStatus.terminal:
          final cancelled = await _cancelQueuedForItem(
            item.workItemId,
            reason: 'work item is ${item.state.wire}',
          );
          cancelledQueued.addAll(cancelled);
        case RunnableWorkStatus.blocked:
        case RunnableWorkStatus.noAction:
          break;
        case RunnableWorkStatus.runnable:
          final dedupeKey = _dedupeKeyBuilder(item, _definition);
          final instruction = _instructionBuilder(item, _definition);
          final result = await _queue.enqueueIfAbsent(
            workItemId: item.workItemId,
            definition: _definition,
            dedupeKey: dedupeKey,
            instruction: instruction,
            now: now,
          );
          if (result.created) enqueued.add(result.job.jobId);
      }
    }

    // 4-8. Dispatch every eligible job, in fixed order, at most ONE attempt per
    //      job per tick. Re-reading live state each round lets a job that
    //      completed during this tick free a capacity slot for the next one —
    //      and that slot is now a real, durable, counted one, released only by
    //      the job reaching a terminal state or being reclaimed.
    final attempted = <String>{};
    for (;;) {
      final eligible = (await _eligibleRunnableJobs(
        now,
        byId,
        statusOf,
      )).where((j) => !attempted.contains(j.jobId)).toList();
      if (eligible.isEmpty) break;
      for (final job in eligible) {
        final outcome = await _dispatchOne(job, now);
        if (outcome.dispatched) {
          dispatched.add(job.jobId);
        } else if (outcome.terminalJob != null) {
          terminal.add(outcome.terminalJob!.jobId);
        } else if (outcome.capacityDenied) {
          // Refused a slot by the global capacity budget. Reported through the
          // SAME `deferred` channel as "no worker was free" because it is the
          // same situation: the job is still queued and still wanted. It is not
          // a failure, it is not terminal, and it is not dropped — the next
          // tick retries it against whatever capacity exists then.
          deferred.add(job.jobId);
        } else if (job.state == JobState.queued ||
            job.state == JobState.retryWaiting) {
          deferred.add(job.jobId);
        }
        if (outcome.dispatched || outcome.terminalJob != null) {
          attempted.add(job.jobId);
        } else if (!outcome.dispatched) {
          // Busy/no-worker/lost-claim/capacity-denied/placement failure: do not
          // spin on the same job within one tick; a later tick will retry it.
          attempted.add(job.jobId);
        }
      }
    }

    return SchedulerTickResult(
      reconciled: reconciled,
      enqueued: enqueued,
      dispatched: dispatched,
      cancelledQueued: cancelledQueued,
      deferred: deferred,
      terminal: terminal,
    );
  }

  Future<List<Job>> _eligibleRunnableJobs(
    DateTime now,
    Map<String, WorkItem> byId,
    Map<String, RunnableWorkStatus> statusOf,
  ) async {
    final candidates = <Job>[];
    for (final job in await _jobStore.listJobs()) {
      if (!_queue.isEligibleAt(job, now)) continue;
      final item = byId[job.workItemId];
      if (item == null ||
          statusOf[job.workItemId] != RunnableWorkStatus.runnable) {
        continue;
      }
      // Check if all providers for this job's role are down.
      if (_providerHealthMonitor != null &&
          _providerHealthMonitor.hasAllProvidersDown(
            _definition.requiredRole,
          )) {
        // Skip dispatch - log and defer
        continue;
      }
      // Re-validate legality against today's item state at claim time so a
      // human decision that landed between enqueue and dispatch cannot slip
      // through.
      final legal = await _evaluator.isRunnable(job, item, _definition);
      if (!legal) continue;
      candidates.add(job);
    }
    candidates.sort(JobQueue.orderEligible);
    return candidates;
  }

  /// Dispatches a single job. `null` means the job either isn't runnable
  /// anymore (workflow moved) or remains queued because no worker could be
  /// acquired, or another scheduler won the claim CAS.
  Future<_DispatchOutcome> _dispatchOne(Job job, DateTime now) async {
    final current = (await _jobStore.readJob(job.jobId)) ?? job;
    if (current.isTerminal) {
      return _DispatchOutcome(terminalJob: current);
    }
    if (!_queue.isEligibleAt(current, now)) {
      return const _DispatchOutcome();
    }

    final item = await _workflowStore.readWorkItem(current.workItemId);
    final request = await _requestBuilder(
      current,
      _workload,
      item,
      _modelSelection,
    );
    final selection = _dispatch.select(request);
    if (!selection.isDispatched) {
      await _queue.recordDeferred(job: current, outcome: selection.outcome);
      return const _DispatchOutcome();
    }

    final admission = await _claim(current, now);
    if (admission.claim == null) {
      return _DispatchOutcome(capacityDenied: admission.capacityDenied);
    }

    await _queue.markRunning(
      job: current,
      now: now,
      workerId: selection.candidate!.workerId,
      workerExecutionId: 'wx-${current.jobId}',
    );

    try {
      final result = await _dispatch.run(request);
      final adopted = await _adopt(current, result, now);
      return _DispatchOutcome(
        dispatched: true,
        terminalJob: adopted.isTerminal ? adopted : null,
      );
    } on WorkerDispatchException catch (e) {
      // Placement failed AFTER the claim but no execution was ever started:
      // safe to release the claim and let a later tick retry.
      await _queue.revertToQueued(
        job: current,
        reason: e.toString(),
        outcome: e.outcome,
      );
      return const _DispatchOutcome();
    }
  }

  /// Claims [current], taking a capacity slot first when the budget is
  /// configured.
  ///
  /// Returns the durable claim on success, or a null claim when the job must
  /// simply not be dispatched this tick. The two refusals are reported apart:
  /// losing the claim CAS means someone else took this specific job, whereas
  /// `capacityDenied` means the shared budget was full and no job at all could
  /// start this tick. Both leave the job queued for a later tick; conflating
  /// them would make a saturated budget look like a contention bug.
  Future<({JobClaim? claim, bool capacityDenied})> _claim(
    Job current,
    DateTime now,
  ) async {
    final guard = capacityGuard;
    if (guard == null) {
      final claim = await _queue.claim(
        job: current,
        ownerId: schedulerId,
        now: now,
        lease: claimLease,
      );
      return (claim: claim, capacityDenied: false);
    }

    final admission = await guard.tryAdmit(
      job: current,
      ownerId: schedulerId,
      now: now,
      lease: claimLease,
    );
    switch (admission) {
      case CapacityAdmitted(:final claim):
        return (claim: claim, capacityDenied: false);
      case CapacityDenied():
        // A denied job is left EXACTLY as it was. No claim is written, no state
        // is written, and no failure is recorded — the honest record is "no
        // capacity right now", which is what `deferred` already means. The job
        // stays eligible, so a later tick retries it with no intervention and
        // no loss.
        await _queue.recordCapacityDenied(
          job: current,
          payload: admission.toEventPayload(),
        );
        return (claim: null, capacityDenied: true);
      case CapacityClaimLost():
        return (claim: null, capacityDenied: false);
    }
  }

  /// Adopts a worker execution's terminal outcome onto its job: merges the
  /// reported agent execution id into the job's execution reference, then lets
  /// the retry policy pick the resulting state.
  Future<Job> _adopt(
    Job prior,
    WorkerExecutionResult result,
    DateTime now,
  ) async {
    final current = (await _jobStore.readJob(prior.jobId)) ?? prior;
    if (current.isTerminal) return current;
    final failure = _retryPolicy.classify(result.status, result.failureDetail);
    // Null when the outcome adds nothing to the chain, in which case the queue
    // preserves whatever the job already holds.
    final adopted = _executionReference(current, result, now);
    if (failure == null) {
      return _queue.complete(
        job: current,
        terminal: JobState.succeeded,
        now: now,
        executionReference: adopted,
      );
    }
    switch (failure.kind) {
      case JobFailureKind.cancelled:
        return _queue.complete(
          job: current,
          terminal: JobState.cancelled,
          failure: failure,
          now: now,
          executionReference: adopted,
        );
      case JobFailureKind.transient:
        if (_retryPolicy.canRetry(current)) {
          return _queue.scheduleRetry(
            job: current,
            failure: failure,
            now: now,
            retryDelay: _retryPolicy.retryDelay,
            executionReference: adopted,
          );
        }
        return _queue.complete(
          job: current,
          terminal: JobState.failed,
          failure: failure,
          now: now,
          executionReference: adopted,
        );
      case JobFailureKind.permanent:
      case JobFailureKind.none:
        return _queue.complete(
          job: current,
          terminal: JobState.failed,
          failure: failure,
          now: now,
          executionReference: adopted,
        );
    }
  }

  /// The job's execution reference with [WorkerExecutionResult.agentExecutionId]
  /// merged in, which is the only half of the chain a terminal outcome adds.
  ///
  /// INVARIANT: a job's `executionReference` is either null, or names a real
  /// worker execution. It is never written with an empty `workerExecutionId`.
  ///
  /// [JobQueue.markRunning] normally stamps the worker half before the worker
  /// runs, and the existing reference is then extended in place. It can lose
  /// that CAS to a concurrent writer, leaving a job whose reference is absent
  /// while its execution is already running. The correct value in that case is
  /// the worker execution that produced the outcome being adopted - the
  /// execution the dispatch request named - never a placeholder. When even that
  /// id is empty the reference is omitted entirely rather than persisted as a
  /// dangling link, because a reader follows this chain and an empty id names
  /// nothing.
  JobExecutionReference? _executionReference(
    Job job,
    WorkerExecutionResult result,
    DateTime now,
  ) {
    final current = job.executionReference;
    final agentExecutionId = result.agentExecutionId;
    if (agentExecutionId == null) return current;
    if (current != null) {
      return current.copyWith(agentExecutionId: agentExecutionId);
    }
    if (result.workerExecutionId.isEmpty) return null;
    return JobExecutionReference(
      workerExecutionId: result.workerExecutionId,
      createdAt: now,
      agentExecutionId: agentExecutionId,
    );
  }

  /// Reconciles a claim that expired without a terminal job. Guarantees
  /// at-least-once semantics WITHOUT double execution:
  ///  - never dispatched           -> requeue (reclaim is safe);
  ///  - vended to the worker layer -> consult the worker store: if the
  ///    execution already ended, adopt its result; if it is still alive, DO
  ///    NOT start a duplicate, just renew the lease;
  ///  - vended, non-terminal, and NOT observably alive -> the execution is a
  ///    zombie and is reclaimed to a terminal job state. This is the branch
  ///    that was missing: the old code treated "not terminal" as "alive", so a
  ///    worker row whose process had died was renewed on every tick forever and
  ///    the lease could never expire.
  Future<void> _reconcileClaim(Job job, JobClaim? claim, DateTime now) async {
    final ref = job.executionReference;
    if (ref == null) {
      await _queue.requeueFromStaleClaim(
        job: job,
        reason: claim == null
            ? 'claim record missing'
            : 'claim expired before dispatch',
      );
      return;
    }
    final execution = await _workerStore.readWorkerExecution(
      ref.workerExecutionId,
    );
    if (execution == null) {
      await _queue.requeueFromStaleClaim(
        job: job,
        reason: 'referenced execution ${ref.workerExecutionId} not found',
      );
      return;
    }
    if (!execution.isTerminal) {
      final liveness = await _livenessOf(execution, now);
      if (_shouldReclaimZombie(execution, now, liveness)) {
        await _reclaimZombie(job, execution, now, liveness);
        return;
      }
      // Observed alive, or not yet old enough to judge: renew the lease rather
      // than duplicating, so a genuinely live-but-slow execution is protected.
      final renewed = JobClaim(
        claimId: JobQueue.newClaimId(),
        jobId: job.jobId,
        ownerId: schedulerId,
        leasedUntil: now.add(claimLease),
        createdAt: now,
      );
      await _jobStore.saveClaim(renewed);
      return;
    }
    final result = await _workerStore.readResult(ref.workerExecutionId);
    await _adoptFromExecution(job, execution, result, now);
  }

  /// What could be observed about [execution] right now.
  ///
  /// A probe that throws is treated as `unknown`, not as `dead`: an
  /// observation failure is not evidence of death, and must not be allowed to
  /// kill live work.
  Future<ExecutionLiveness> _livenessOf(
    WorkerExecution execution,
    DateTime now,
  ) async {
    final probe = _executionLiveness;
    if (probe == null) return ExecutionLiveness.unknown;
    try {
      return await probe(execution, now);
    } catch (_) {
      return ExecutionLiveness.unknown;
    }
  }

  /// Whether a non-terminal execution must be reclaimed as a zombie.
  ///
  /// Reclaimed when liveness is proven dead, and when liveness could not be
  /// observed and the execution has outlived [zombieStalenessBound]. An
  /// execution with no recorded start is reclaimed too: there is nothing to
  /// judge it against, and an execution that cannot even say when it started is
  /// not one whose progress anyone has been able to observe.
  bool _shouldReclaimZombie(
    WorkerExecution execution,
    DateTime now,
    ExecutionLiveness liveness,
  ) {
    if (liveness == ExecutionLiveness.alive) return false;
    if (liveness == ExecutionLiveness.dead) return true;
    final since = execution.startedAt ?? execution.createdAt;
    if (since == null) return true;
    return now.difference(since) > zombieStalenessBound;
  }

  /// Drives a job whose execution nothing is running behind to a TERMINAL
  /// state, so it is no longer left running and its lease is no longer renewed.
  ///
  /// FAIL DIRECTION: this is the fail-CLOSED branch, and it is reached only
  /// when liveness was either proven dead or has been unobservable for longer
  /// than [zombieStalenessBound]. The unobservable case fails open *within a
  /// bound* rather than open forever: renewing an execution nobody is running
  /// is exactly the defect that produced a 4.78 hour stall, whereas the harm of
  /// failing closed is bounded by that same window and surfaces as a visible
  /// failed job rather than a silent duplicate.
  ///
  /// The job goes to `failed` rather than to a retry, deliberately. A retry
  /// would re-dispatch against a work item still in
  /// [WorkItemState.agentExecuting] that the scheduler is not allowed to move,
  /// and a second execution writing the same worktree while the first may still
  /// hold it is the worse of the two harms.
  ///
  /// ## ORDER IS THE POINT
  ///
  /// The work item and the worker execution are reclaimed BEFORE the job, not
  /// after. Failing the job first would be safe only if the process never died
  /// between the two writes — but a terminal job is never re-reconciled
  /// (`tick` only considers held jobs with an expired claim), so a crash in that
  /// window would strand the work item permanently with no path back. In this
  /// order a crash anywhere leaves the claim held and the claim expired, so the
  /// next tick re-enters [_reconcileClaim] and converges: the work item is
  /// already out of [WorkItemState.agentExecuting], so that step is a no-op, and
  /// the job is still failed.
  Future<void> _reclaimZombie(
    Job job,
    WorkerExecution execution,
    DateTime now,
    ExecutionLiveness liveness,
  ) async {
    final current = (await _jobStore.readJob(job.jobId)) ?? job;
    if (current.isTerminal) return;

    final age = _durationSinceStart(execution, now);
    final reason = switch (liveness) {
      ExecutionLiveness.dead =>
        'execution ${execution.workerExecutionId} is still ${execution.status.name} '
            'but nothing is running behind it (observed dead after $age)',
      _ =>
        'execution ${execution.workerExecutionId} is still ${execution.status.name}, '
            'no live execution could be observed, and it has been non-terminal '
            'for $age (beyond the ${zombieStalenessBound.inMinutes}m bound)',
    };

    await _releaseWorkItem(current.workItemId, execution, reason);
    await _retireWorkerExecution(execution, now, reason);

    await _queue.complete(
      job: current,
      terminal: JobState.failed,
      failure: JobFailure(
        code: JobFailureCode.executionInterrupted,
        kind: JobFailureKind.permanent,
        reason: 'zombie execution reclaimed: $reason',
      ),
      now: now,
      executionReference: current.executionReference,
    );
  }

  /// Moves the work item out of [WorkItemState.agentExecuting] so a zombie does
  /// not strand the work forever.
  ///
  /// ## Why `agentFailed`, from the real transition table
  ///
  /// Edges out of `agentExecuting` in `WorkItemTransitions` are exactly two, plus
  /// the generic orchestrator escape:
  ///
  ///  * `agentCompleted` — guarded by `qaContractExists()` AND
  ///    `agentResultValid()`. A zombie has no agent result, so this edge is not
  ///    available and asserting it would be a lie about what ran.
  ///  * `agentFailed` — guarded by `actorAllowed([orchestrator])` alone.
  ///  * `cancelled` / `terminated` — the generic escape, but BOTH are workflow
  ///    terminal states. Choosing them would turn a recoverable reclaim into
  ///    permanent loss, which is the exact harm this method exists to prevent.
  ///
  /// So `agentFailed` is the only honest non-terminal exit, and it is recoverable:
  /// `(agentFailed -> agentExecuting)` is itself a legal edge, so a human or a
  /// re-plan can put the work back into execution. It is deliberately NOT
  /// auto-re-dispatched — `RunnableWorkEvaluator` does not list `agentFailed` in
  /// any entry set, because reworking a failed result routes through the
  /// workflow's correction gate rather than an automatic re-run. It therefore
  /// surfaces to a human instead of silently re-running or silently vanishing.
  ///
  /// This is the same state a genuine agent failure lands in, so a reclaim is
  /// indistinguishable from a real failure to anything reading the item.
  ///
  /// ## Idempotent and safe under a concurrent writer
  ///
  /// Three layers, because a reclaim must never resurrect or double-transition:
  /// the current state is re-read and the call is skipped unless the item is
  /// still in [WorkItemState.agentExecuting]; the transition carries an
  /// `idempotencyKey`, so a replay after a partial write returns the accepted
  /// outcome instead of transitioning again; and the store's compare-and-swap on
  /// the item version rejects a concurrent writer.
  ///
  /// ## Both rejection signals are caught, and they are not interchangeable
  ///
  /// Losing the compare-and-swap raises [ConcurrentModificationException], which
  /// is a SIBLING of [WorkflowTransitionRejectedException] — neither extends the
  /// other — and `DurableWorkflowEngine.transition` rethrows it out of the
  /// transaction rather than swallowing it. Catching only the rejected case
  /// therefore let a lost race escape `_releaseWorkItem` entirely, and because
  /// `tick` did not guard its reconciliation loop the exception aborted the
  /// WHOLE tick: the job was never failed, its claim never released, its worker
  /// execution never retired, and every other job's reconciliation was skipped
  /// too. A reclaim that fails that way is strictly worse than the stranding
  /// this method exists to prevent.
  ///
  /// The two are handled differently on purpose:
  ///
  ///  * [WorkflowTransitionRejectedException] means the transition was refused —
  ///    the item is not where we thought, or the edge is illegal. Someone else
  ///    owns the decision now, so this returns without retrying.
  ///  * [ConcurrentModificationException] means the decision was legal but the
  ///    item changed underneath the read. That is a lost race, not a refusal, so
  ///    the state is re-read and the attempt retried, bounded by
  ///    [_maxReclaimAttempts]. Catching it and moving straight on would leave the
  ///    item exactly as stranded as before whenever the competing writer had not
  ///    itself taken the item out of [WorkItemState.agentExecuting].
  Future<void> _releaseWorkItem(
    String workItemId,
    WorkerExecution execution,
    String reason,
  ) async {
    for (var attempt = 0; attempt < _maxReclaimAttempts; attempt++) {
      final item = await _workflowStore.readWorkItem(workItemId);
      if (item.state != WorkItemState.agentExecuting) return;

      try {
        await _reclaimEngine.transition(
          workItemId: workItemId,
          to: WorkItemState.agentFailed,
          trigger: TransitionTrigger.systemEvent,
          actor: _reclaimActor,
          context: {
            'zombieReclaimed': true,
            'workerExecutionId': execution.workerExecutionId,
            'workerId': execution.workerId,
            'lastStatus': execution.status.name,
            'reason': 'zombie execution reclaimed: $reason',
          },
          idempotencyKey: 'zombie-reclaim:${execution.workerExecutionId}',
        );
        return;
      } on WorkflowTransitionRejectedException {
        // A concurrent writer moved the item first — a real result arriving from
        // the wedged path, or another tick. Either way the item is no longer
        // stranded, which is the whole job of this call, so a refused transition
        // is a correct outcome and must not be retried or escalated.
        return;
      } on ConcurrentModificationException {
        // Lost the compare-and-swap. Re-read and decide again: the competing
        // writer may have taken the item out of `agentExecuting`, in which case
        // the loop's first line returns.
        continue;
      }
    }
    // Still being contended after the bounded retries. The job is failed
    // regardless, so the reclaim as a whole still converges; this is recorded by
    // leaving the item alone rather than by fighting a writer indefinitely.
  }

  /// Drives the zombie worker execution row to a terminal state.
  ///
  /// ## Why the scheduler does this, rather than "leaving it to the worker layer"
  ///
  /// The previous version deferred this to `worker_runtime`'s reconciler. In
  /// this topology that deferral is dead: the coordinator's `reconcileOrphans()`
  /// finds nothing because `agent_execution` has no row for this execution, and
  /// once the job is terminal no later tick re-reaches this execution at all —
  /// `tick` only reconciles held jobs whose claim expired. QA showed the
  /// consequence directly: the job failed, capacity was released, and the
  /// `worker_execution` row stayed `agentExecuting` forever.
  ///
  /// The scheduler already holds the verdict that this execution is dead, so
  /// leaving the row asserting otherwise is the scheduler contradicting itself.
  /// `orphaned` is the status `WorkerReconciler` itself uses for "the executor
  /// went away", which keeps the two paths converging on one vocabulary instead
  /// of inventing a second way of saying the same thing.
  ///
  /// `cleanupStatus` is deliberately NOT touched. Nothing in this repository
  /// consumes `WorkerExecution.cleanupMissing`, and claiming cleanup happened
  /// would be a lie; leaving the recorded value alone keeps the row honest about
  /// what is still outstanding for whoever owns workspaces.
  ///
  /// The compare-and-swap is the concurrency guard: a worker that is somehow
  /// still alive and writing will lose to a verdict that was already durably
  /// recorded, which is the correct ordering. That rejection is caught rather
  /// than propagated — the job must still be failed.
  Future<void> _retireWorkerExecution(
    WorkerExecution execution,
    DateTime now,
    String reason,
  ) async {
    if (execution.isTerminal) return;
    try {
      await _workerStore.saveWorkerExecution(
        execution.copyWith(
          status: WorkerExecutionStatus.orphaned,
          failureCode: WorkerFailureCode.agentFailed,
          reason: 'orphaned by scheduler zombie reclaim: $reason',
          endedAt: now,
          version: execution.version + 1,
        ),
        expectedVersion: execution.version,
      );
    } on ConcurrentWorkerModificationException {
      // Another writer already moved this row; its verdict stands.
    }
  }

  String _durationSinceStart(WorkerExecution execution, DateTime now) {
    final since = execution.startedAt ?? execution.createdAt;
    if (since == null) return 'an unknown time';
    return '${now.difference(since).inMinutes}m';
  }

  Future<void> _adoptFromExecution(
    Job job,
    WorkerExecution execution,
    WorkerExecutionResult? result,
    DateTime now,
  ) async {
    final current = (await _jobStore.readJob(job.jobId)) ?? job;
    if (current.isTerminal) return;
    if (result != null) {
      await _adopt(current, result, now);
      return;
    }
    final synthesized = WorkerExecutionResult(
      workerExecutionId: execution.workerExecutionId,
      workItemId: current.workItemId,
      status: execution.status,
      workerId: execution.workerId ?? 'unknown',
      workspaceId: execution.workspaceId ?? 'unknown',
      startingRevision: execution.requestedStartingRevision,
      startedAt: execution.startedAt ?? execution.createdAt ?? now,
      endedAt: execution.endedAt ?? now,
      cleanupStatus: execution.cleanupStatus ?? WorkerCleanupStatus.pending,
      failureCode: execution.failureCode ?? WorkerFailureCode.none,
      failureDetail: execution.reason,
    );
    await _adopt(current, synthesized, now);
  }

  /// Cancels a job queued for a terminal work item (retryWaiting included).
  Future<List<String>> _cancelQueuedForItem(
    String workItemId, {
    required String reason,
  }) async {
    final cancelled = <String>[];
    for (final job in await _jobStore.listJobs()) {
      if (job.workItemId != workItemId) continue;
      if (job.isTerminal) continue;
      if (job.state == JobState.queued || job.state == JobState.retryWaiting) {
        await _queue.cancelQueued(job: job, reason: reason);
        cancelled.add(job.jobId);
      }
    }
    return cancelled;
  }

  /// Public cancellation entrypoint: queued/retryWaiting jobs are cancelled
  /// durably here; claimed/running jobs are cancelled through the worker and
  /// converge to `cancelled` via outcome adoption.
  Future<Job> cancelJob(String jobId, String reason) async {
    final job = (await _jobStore.readJob(jobId))!;
    switch (job.state) {
      case JobState.queued:
      case JobState.retryWaiting:
        return _queue.cancelQueued(job: job, reason: reason);
      case JobState.claimed:
      case JobState.running:
        if (job.workerId != null) {
          await _dispatch.cancel(job.workerId!, reason);
        }
        return (await _jobStore.readJob(jobId))!;
      case JobState.succeeded:
      case JobState.failed:
      case JobState.cancelled:
        return job;
    }
  }
}

/// Default definition registered for the demo and used by
/// [Scheduler.definition] wiring in fixtures.
const JobDefinition defaultImplementFeatureDefinition = JobDefinition(
  jobType: JobType.implementFeature,
  requiredRole: AgentRole.implementer,
  requiredCapabilities: {WorkerCapability.linux},
  entryStates: {WorkItemState.designNotRequired, WorkItemState.designApproved},
  priority: JobPriority.normal,
  maxAttempts: 2,
);

/// Design revision job: produces a design revision in Penpot.
const JobDefinition designRevisionDefinition = JobDefinition(
  jobType: JobType.designRevision,
  requiredRole: AgentRole.designAgent,
  requiredCapabilities: {
    WorkerCapability.penpotWrite,
    WorkerCapability.visualDesign,
  },
  entryStates: {WorkItemState.designRequired, WorkItemState.designRejected},
  priority: JobPriority.normal,
  maxAttempts: 3,
  skipWorkflowPolicyCheck: true,
);

/// Design review job: independently reviews a design revision produced by
/// a different worker. Must exclude the designer's execution.
const JobDefinition designReviewDefinition = JobDefinition(
  jobType: JobType.designReview,
  requiredRole: AgentRole.designReviewer,
  requiredCapabilities: {
    WorkerCapability.penpotRead,
    WorkerCapability.designReview,
  },
  entryStates: {WorkItemState.designInReview},
  priority: JobPriority.high,
  maxAttempts: 2,
  skipWorkflowPolicyCheck: true,
);

/// Builds a dedupe key for design revision jobs: (workItemId, jobType).
/// Only one active design revision job per work item at a time.
String designRevisionDedupeKey(WorkItem item, JobDefinition definition) =>
    '${item.workItemId}:${definition.jobType.wire}';

/// Builds a dedupe key for design review jobs: (workItemId, designRevisionId, jobType).
/// Prevents duplicate reviews of the same revision. Reads designRevisionId from
/// WorkItem.metadata['designRevisionId'] (set by workflow on transition to designInReview).
String designReviewDedupeKey(WorkItem item, JobDefinition definition) {
  final revisionId = item.metadata?['designRevisionId'] as String?;
  return '${item.workItemId}:${revisionId ?? 'unknown'}:${definition.jobType.wire}';
}

/// Builds an instruction for design revision jobs.
String designRevisionInstruction(WorkItem item, JobDefinition definition) =>
    'Produce a design revision for "${item.title}" (${item.workItemId}) in Penpot.';

/// Builds an instruction for design review jobs.
String designReviewInstruction(WorkItem item, JobDefinition definition) =>
    'Review the design revision for "${item.title}" (${item.workItemId}) in Penpot. '
    'Provide independent assessment without consulting the designer.';

/// Builds a worker execution request for design revision jobs.
Future<WorkerExecutionRequest> designRevisionRequest(
  Job job,
  SchedulerWorkload workload,
  WorkItem item,
  ModelSelectionService? modelSelection,
) async {
  final runtimeConfig = await modelRuntimeConfig(job, item, modelSelection);
  return WorkerExecutionRequest(
    workerExecutionId: 'wx-${job.jobId}',
    workItemId: job.workItemId,
    repositoryPath: workload.repositoryPath,
    startingRevision: workload.startingRevision,
    requiredCapabilities: job.requiredCapabilities,
    role: job.requiredRole,
    instruction: job.instruction,
    timeoutSeconds: workload.timeoutSeconds,
    runtimeTypeId: workload.runtimeTypeId,
    cleanupPolicy: workload.cleanupPolicy,
    runtimeConfig: runtimeConfig,
  );
}

/// Builds a worker execution request for design review jobs.
/// Includes excludedExecutionIds to enforce independence at dispatch.
/// Reads designerExecutionId from WorkItem.metadata['designerExecutionId']
/// (set by workflow on transition to designInReview).
Future<WorkerExecutionRequest> designReviewRequest(
  Job job,
  SchedulerWorkload workload,
  WorkItem item,
  ModelSelectionService? modelSelection,
) async {
  final designerExecutionId = item.metadata?['designerExecutionId'] as String?;
  final runtimeConfig = await modelRuntimeConfig(job, item, modelSelection);
  return WorkerExecutionRequest(
    workerExecutionId: 'wx-${job.jobId}',
    workItemId: job.workItemId,
    repositoryPath: workload.repositoryPath,
    startingRevision: workload.startingRevision,
    requiredCapabilities: job.requiredCapabilities,
    role: job.requiredRole,
    instruction: job.instruction,
    timeoutSeconds: workload.timeoutSeconds,
    runtimeTypeId: workload.runtimeTypeId,
    cleanupPolicy: workload.cleanupPolicy,
    excludedExecutionIds: designerExecutionId != null
        ? [designerExecutionId]
        : const [],
    runtimeConfig: runtimeConfig,
  );
}

class _DispatchOutcome {
  const _DispatchOutcome({
    this.dispatched = false,
    this.terminalJob,
    this.capacityDenied = false,
  });

  final bool dispatched;
  final Job? terminalJob;

  /// The global capacity budget was full, so this job was not attempted. The
  /// job is untouched and still queued.
  final bool capacityDenied;
}
