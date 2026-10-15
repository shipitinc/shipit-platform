import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';
import 'package:workflow_store/workflow_store.dart';

/// A scheduled retry REALLY produces a second dispatch — and a crash really
/// never does.
///
/// ## Why this harness is scripted rather than end-to-end
///
/// `budget_exhaustion_retries_test.dart` drives the real
/// `Scheduler` → `LocalWorker` → `ExecutionCoordinator` chain and proves the
/// classification at every seam. It also pins, in its GAP test, that the real
/// chain cannot re-dispatch: the failed execution leaves the work item outside
/// the lane's `entryStates`, so the next tick retires the scheduled retry as
/// superseded.
///
/// That gap is a separate defect in a package this lane does not own, and it
/// makes an end-to-end second dispatch impossible to assert today. This harness
/// removes exactly that one variable — the work item never leaves the lane's
/// entry state, because no coordinator is involved — and asserts the thing the
/// coordinator change is FOR: that `WorkerExecutionStatus.timedOut` re-enters
/// the scheduler as a retry that runs again, and that
/// `WorkerExecutionStatus.executedFail` does not.
///
/// Read the two files together. Neither is the whole claim; together they are,
/// and the seam between them is named rather than glossed.
///
/// ## THE DANGEROUS DIRECTION
///
/// "Make the timeout retry" becoming "retry forever". The bound is
/// `engineeringReviewDefinition.maxAttempts`, and the test below asserts the
/// attempt counter reaches exactly it and no further dispatch happens.
void main() {
  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryWorkerStore workerStore;
  late InMemoryJobStore jobStore;

  /// The worker's clock, independent of the scheduler's so `RetryPolicy`'s
  /// one-minute back-off can be skipped deliberately rather than slept through.
  var clock = DateTime.utc(2026, 1, 1);
  DateTime now() => clock;

  setUp(() {
    clock = DateTime.utc(2026, 1, 1);
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    workerStore = InMemoryWorkerStore();
    jobStore = InMemoryJobStore();
  });

  Future<void> readyWorkItem(String workItemId) async {
    await workflowEngine.createWorkItem(
      workItemId: workItemId,
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Triage: login button does nothing',
      description: 'A defect-shaped item for the retry contract',
      qaContractId: 'qa-1',
      featureRef: 'feature/login',
    );
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
    );
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      context: const {'featureRef': 'feature/login'},
    );
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );
  }

  Scheduler schedulerOver(ScriptedDispatch dispatch) => Scheduler(
    schedulerId: 'sched-scripted',
    workflowStore: workflowStore,
    jobStore: jobStore,
    workerStore: workerStore,
    dispatch: dispatch,
    definition: triageDefectDefinition,
    dedupeKeyBuilder: triageDefectDedupeKey,
    instructionBuilder: triageDefectInstruction,
    requestBuilder: triageDefectRequest,
    workload: const SchedulerWorkload(
      repositoryPath: '/tmp/scripted',
      startingRevision: 'deadbeef',
      timeoutSeconds: 60,
      runtimeTypeId: 'scripted-runtime',
    ),
    clock: now,
  );

  Future<Job> triageJob(String workItemId) async {
    final jobs = await jobStore.listJobsForWorkItem(workItemId);
    return jobs.singleWhere((j) => j.jobType == JobType.triageDefect);
  }

  test(
    'a TIMED-OUT run spends an attempt and the retry really runs again',
    () async {
      await readyWorkItem('wi-retry');
      final dispatch = ScriptedDispatch([WorkerExecutionStatus.timedOut]);
      final scheduler = schedulerOver(dispatch);

      final first = await scheduler.tick();
      expect(first.dispatched, isNotEmpty, reason: 'the first attempt ran');
      expect(dispatch.runCount, 1);

      final afterTimeout = await triageJob('wi-retry');
      expect(
        afterTimeout.state,
        JobState.retryWaiting,
        reason:
            'timedOut classifies as TRANSIENT, so the job waits rather than '
            'failing. Under the old settlement this was `failed` and no retry '
            'was ever possible.',
      );
      expect(
        afterTimeout.attempt,
        2,
        reason:
            'a job is created at attempt=1 and `scheduleRetry` charges the '
            'second, so 2 of maxAttempts 2 means the whole budget is spent and a '
            'THIRD attempt is impossible',
      );
      expect(afterTimeout.attempt, afterTimeout.maxAttempts);
      expect(afterTimeout.failure?.kind, JobFailureKind.transient);
      expect(afterTimeout.isTerminal, isFalse);

      // Not yet eligible: `RetryPolicy.retryDelay` is one minute. Asserted so a
      // change to the back-off cannot be mistaken for "it retried immediately".
      final tooEarly = await scheduler.tick();
      expect(tooEarly.dispatched, isEmpty, reason: 'still inside the back-off');
      expect(dispatch.runCount, 1);

      // Past the back-off: the SECOND DISPATCH.
      clock = clock.add(const Duration(minutes: 2));
      dispatch.add(WorkerExecutionStatus.executedPass);
      final second = await scheduler.tick();

      expect(
        second.dispatched,
        isNotEmpty,
        reason: 'the retry is not merely eligible — it ran',
      );
      expect(dispatch.runCount, 2);

      final done = await triageJob('wi-retry');
      expect(done.state, JobState.succeeded);
      expect(done.attempt, 2, reason: 'exactly one retry was spent');
    },
  );

  test('a run that FAILS spends no attempt and is never retried', () async {
    await readyWorkItem('wi-crash');
    final dispatch = ScriptedDispatch([WorkerExecutionStatus.executedFail]);
    final scheduler = schedulerOver(dispatch);

    await scheduler.tick();
    expect(dispatch.runCount, 1);

    final afterFailure = await triageJob('wi-crash');
    expect(
      afterFailure.state,
      JobState.failed,
      reason:
          'a coding or crash result is PERMANENT. Making it retryable is the '
          'regression this lane must not introduce — a permanently broken '
          'runtime would be re-dispatched on every item for ever.',
    );
    expect(
      afterFailure.attempt,
      1,
      reason:
          'a permanent failure spends NO additional attempt: the job is still '
          'at the 1 it was created with, while the timeout case above moved to '
          '2. The DELTA is the invariant — `maxAttempts` bounds TIME-OUT '
          'retries only.',
    );
    expect(afterFailure.failure?.kind, JobFailureKind.permanent);

    // However many ticks run afterwards, and however far the clock moves.
    for (var i = 0; i < 3; i++) {
      clock = clock.add(const Duration(minutes: 2));
      final tick = await scheduler.tick();
      expect(tick.dispatched, isEmpty, reason: 'a terminal job never re-runs');
    }
    expect(
      dispatch.runCount,
      1,
      reason: 'one execution, ever',
    );
  });

  test("the bound is the definition's: a timeout that never resolves stops at "
      'maxAttempts', () async {
    await readyWorkItem('wi-bound');
    final dispatch = ScriptedDispatch(
      List.filled(6, WorkerExecutionStatus.timedOut),
    );
    final scheduler = schedulerOver(dispatch);

    for (var i = 0; i < 4; i++) {
      clock = clock.add(const Duration(minutes: 2));
      await scheduler.tick();
      if ((await triageJob('wi-bound')).isTerminal) break;
    }

    final bounded = await triageJob('wi-bound');
    expect(
      bounded.state,
      JobState.failed,
      reason:
          'once the budget is spent the retry stops. A timeout that never '
          'resolves must not be the thing that never stops.',
    );
    expect(
      dispatch.runCount,
      triageDefectDefinition.maxAttempts,
      reason:
          'the observable half of the bound: exactly maxAttempts executions '
          'were started, no more.',
    );
    expect(bounded.attempt, triageDefectDefinition.maxAttempts);
  });
}

/// A [WorkerDispatch] whose every call to `run` returns the next status in
/// [script], and which never moves a work item.
///
/// That last property is the whole point: it isolates the scheduler's retry
/// bookkeeping from the workflow-state question that the real chain raises and
/// that `budget_exhaustion_retries_test.dart` pins separately.
class ScriptedDispatch implements WorkerDispatch {
  ScriptedDispatch(List<WorkerExecutionStatus> script)
    : _script = List<WorkerExecutionStatus>.of(script);

  final List<WorkerExecutionStatus> _script;
  int runCount = 0;

  /// Appends the outcome the next `run` should report.
  void add(WorkerExecutionStatus status) => _script.add(status);

  final _worker = WorkerRegistration(
    workerId: 'w-scripted',
    poolId: 'scripted-pool',
    capabilities: const {
      WorkerCapability.linux: CapabilitySpec(
        capability: WorkerCapability.linux,
        version: '1',
      ),
      WorkerCapability.git: CapabilitySpec(
        capability: WorkerCapability.git,
        version: '1',
      ),
    },
    status: WorkerStatus.idle,
    currentLoad: 0,
    maxConcurrency: 1,
    lastHeartbeat: DateTime.utc(2026, 1, 1),
    platform: 'linux-x64',
  );

  @override
  WorkerSelection select(WorkerExecutionRequest request) =>
      WorkerSelection.dispatched(_worker);

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) async {
    final status = runCount < _script.length
        ? _script[runCount]
        : WorkerExecutionStatus.executedPass;
    runCount++;
    final ended = DateTime.utc(2026, 1, 1).add(Duration(seconds: runCount));
    return WorkerExecutionResult(
      workerExecutionId: request.workerExecutionId,
      workItemId: request.workItemId,
      status: status,
      startingRevision: request.startingRevision,
      workerId: _worker.workerId,
      workspaceId: 'ws-scripted',
      startedAt: DateTime.utc(2026, 1, 1),
      endedAt: ended,
      cleanupStatus: WorkerCleanupStatus.notApplicable,
      failureCode: status == WorkerExecutionStatus.timedOut
          ? WorkerFailureCode.timedOut
          : WorkerFailureCode.none,
      failureDetail: status == WorkerExecutionStatus.timedOut
          ? 'agent session timed out'
          : null,
    );
  }

  @override
  Future<void> cancel(String workerId, String reason) async {}
}
