import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'dispatch/worker_dispatch.dart';
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
    WorkflowEngine? policy,
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
       _queue = JobQueue(store: jobStore, clock: clock);

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
  final JobQueue _queue;
  final RetryPolicy _retryPolicy = const RetryPolicy();

  JobQueue get queue => _queue;

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
    for (final job in await _jobStore.listJobs()) {
      final isHeld =
          job.state == JobState.claimed || job.state == JobState.running;
      if (!isHeld) continue;
      final claim = await _jobStore.readClaimForJob(job.jobId);
      final expired = claim == null || claim.isExpiredAt(now);
      if (!expired) continue;
      await _reconcileClaim(job, claim, now);
      reconciled.add(job.jobId);
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
          final dedupeKey = _dedupeKey(item);
          final instruction = _instructionFor(item);
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
    //      completed during this tick free a capacity slot for the next one.
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
        } else if (job.state == JobState.queued ||
            job.state == JobState.retryWaiting) {
          deferred.add(job.jobId);
        }
        if (outcome.dispatched || outcome.terminalJob != null) {
          attempted.add(job.jobId);
        } else if (!outcome.dispatched) {
          // Busy/no-worker/lost-claim/placement failure: do not spin on the
          // same job within one tick; a later tick will retry it.
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

    final request = _requestFor(current);
    final selection = _dispatch.select(request);
    if (!selection.isDispatched) {
      await _queue.recordDeferred(job: current, outcome: selection.outcome);
      return const _DispatchOutcome();
    }

    final claim = await _queue.claim(
      job: current,
      ownerId: schedulerId,
      now: now,
      lease: claimLease,
    );
    if (claim == null) return const _DispatchOutcome();

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

  Future<Job> _adopt(
    Job prior,
    WorkerExecutionResult result,
    DateTime now,
  ) async {
    final current = (await _jobStore.readJob(prior.jobId)) ?? prior;
    if (current.isTerminal) return current;
    final failure = _retryPolicy.classify(result.status, result.failureDetail);
    if (failure == null) {
      return _queue.complete(
        job: current,
        terminal: JobState.succeeded,
        now: now,
      );
    }
    switch (failure.kind) {
      case JobFailureKind.cancelled:
        return _queue.complete(
          job: current,
          terminal: JobState.cancelled,
          failure: failure,
          now: now,
        );
      case JobFailureKind.transient:
        if (_retryPolicy.canRetry(current)) {
          return _queue.scheduleRetry(
            job: current,
            failure: failure,
            now: now,
            retryDelay: _retryPolicy.retryDelay,
          );
        }
        return _queue.complete(
          job: current,
          terminal: JobState.failed,
          failure: failure,
          now: now,
        );
      case JobFailureKind.permanent:
      case JobFailureKind.none:
        return _queue.complete(
          job: current,
          terminal: JobState.failed,
          failure: failure,
          now: now,
        );
    }
  }

  /// Reconciles a claim that expired without a terminal job. Guarantees
  /// at-least-once semantics WITHOUT double execution:
  ///  - never dispatched           -> requeue (reclaim is safe);
  ///  - vended to the worker layer -> consult the worker store: if the
  ///    execution already ended, adopt its result; if it is still alive, DO
  ///    NOT start a duplicate (worker_runtime's reconciler owns orphaning),
  ///    just renew the lease so a live-but-slow execution is not interrupted.
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
      // Still alive: renew the lease instead of duplicating.
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

  String _dedupeKey(WorkItem item) =>
      '${item.workItemId}:${item.state.wire}:${_definition.jobType.wire}:'
      '${_definition.requiredRole.wire}';

  String _instructionFor(WorkItem item) =>
      'Implement "${item.title}" (${item.workItemId}) inside the worktree.';

  WorkerExecutionRequest _requestFor(Job job) {
    final itemWorkItemId = job.workItemId;
    return WorkerExecutionRequest(
      workerExecutionId: 'wx-${job.jobId}',
      workItemId: itemWorkItemId,
      repositoryPath: _workload.repositoryPath,
      startingRevision: _workload.startingRevision,
      requiredCapabilities: job.requiredCapabilities,
      role: job.requiredRole,
      instruction: job.instruction,
      timeoutSeconds: _workload.timeoutSeconds,
      runtimeTypeId: _workload.runtimeTypeId,
      cleanupPolicy: _workload.cleanupPolicy,
    );
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

/// Result of a single dispatch attempt.
class _DispatchOutcome {
  const _DispatchOutcome({this.dispatched = false, this.terminalJob});

  final bool dispatched;
  final Job? terminalJob;
}
