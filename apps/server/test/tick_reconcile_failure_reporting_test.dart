import 'dart:async';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:control_plane_server/server.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';

/// A reconciliation failure must reach an operator.
///
/// The per-row guard in `Scheduler.tick` stops one unreconcilable row from
/// aborting the whole tick. That is correct — but it also means a row that
/// cannot be reconciled produces a tick that otherwise looks healthy: the tick
/// returns, fresh work keeps dispatching, capacity keeps leaking, and nothing
/// anywhere says so. An earlier version of this code swallowed the failure and
/// pointed at the row's absence from `reconciled` as the observable effect.
///
/// That claim was false. `reconciled` is never logged anywhere in the server, so
/// the failure was invisible: no `scheduler.tick.failed`, no `failedSections`
/// entry, and a completion line indistinguishable from a healthy tick.
///
/// This file pins the path END TO END — a real `Scheduler` tick with an
/// unreconcilable row, the resulting `SchedulerTickResult`, the `TickOutcome`
/// the composition root builds from it, and the record
/// `TickSingleFlight` actually emits — because a test that only proves a field
/// was populated proves nothing about whether an operator ever sees it.
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('tick_reconcile_reporting_');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test(
    'a swallowed reconciliation row reaches the emitted scheduler.tick.completed '
    'record',
    () async {
      final t0 = DateTime.utc(2026, 1, 1, 12);
      final workflowStore = InMemoryWorkflowStore();
      final jobStore = InMemoryJobStore();
      final workerStore = InMemoryWorkerStore();
      final scheduler = Scheduler(
        schedulerId: 'sched-triage',
        workflowStore: _FaultingWorkflowStore(workflowStore, failing: 'wi-bad'),
        jobStore: jobStore,
        workerStore: workerStore,
        dispatch: const _NoopDispatch(),
        definition: defaultImplementFeatureDefinition,
        workload: const SchedulerWorkload(
          repositoryPath: '/tmp/repo',
          startingRevision: 'deadbeef',
          timeoutSeconds: 300,
          runtimeTypeId: 'fake-runtime',
        ),
        clock: () => DateTime.utc(2026, 1, 1, 12, 11),
      );

      // A held job whose claim has expired, whose work item cannot be read.
      final job = Job(
        jobId: 'job-bad',
        workItemId: 'wi-bad',
        jobType: JobType.implementFeature,
        requiredRole: AgentRole.implementer,
        requiredCapabilities: const {},
        priority: JobPriority.normal,
        state: JobState.running,
        dedupeKey: 'wi-bad:dedupe',
        instruction: 'Implement the feature.',
        attempt: 1,
        maxAttempts: 2,
        version: 1,
        createdAt: t0,
        startedAt: t0,
        // The reclaim only runs for a job that vended an execution to the
        // worker layer; without this reference the row is requeued instead.
        executionReference: JobExecutionReference(
          workerExecutionId: 'wx-job-bad',
          createdAt: t0,
        ),
      );
      await jobStore.saveJob(job);

      // A zombie: non-terminal, and older than any staleness bound.
      await workerStore.saveWorkerExecution(
        WorkerExecution(
          workerExecutionId: 'wx-job-bad',
          workItemId: 'wi-bad',
          repositoryPath: '/tmp/repo',
          requestedStartingRevision: 'deadbeef',
          requiredCapabilities: const {},
          status: WorkerExecutionStatus.agentExecuting,
          cleanupPolicy: WorkerCleanupPolicy.removeAlways,
          workerId: 'w-1',
          startedAt: t0.subtract(const Duration(hours: 5)),
        ),
      );
      await jobStore.saveClaim(
        JobClaim(
          claimId: 'c-1',
          jobId: job.jobId,
          ownerId: 'sched-triage',
          leasedUntil: t0.add(const Duration(minutes: 5)),
          createdAt: t0,
        ),
      );

      // --- the tick itself ---
      final tickResult = await scheduler.tick();

      expect(
        tickResult.reconcileFailed,
        hasLength(1),
        reason:
            'the tick result is the scheduler\'s only channel outward; a '
            'failure that reaches nobody is a silent leak',
      );
      expect(tickResult.reconcileFailed.single.jobId, 'job-bad');
      expect(tickResult.reconciled, isEmpty);

      // --- what the composition root builds from it ---
      final outcome = TickOutcome(failedSections: <String>[])
        ..reconcileFailed.addAll(
          tickResult.reconcileFailed.map((f) => f.toString()),
        );

      // --- and the record that actually gets emitted ---
      final lines = <String, Map<String, dynamic>>{};
      final tick = TickSingleFlight(
        log: (event, data) => lines[event] = data,
        runTick: () async => outcome,
      );

      await tick.trigger();

      final completed = lines['scheduler.tick.completed'];
      expect(
        completed,
        isNotNull,
        reason: 'the completion line must be emitted',
      );
      expect(
        completed!['reconcileFailed'],
        isNotEmpty,
        reason:
            'a row that could not be reconciled must be visible on the '
            'completion line, or a worker-store fault looks exactly like a '
            'healthy tick while reclaim capacity leaks forever',
      );
      expect(completed['reconcileFailedCount'], 1);
      expect(
        '${completed['reconcileFailed']}',
        contains('job-bad'),
        reason: 'the record must name WHICH job could not be reconciled',
      );
      // Still a tick that reports clean in its other respects — that is exactly
      // why the failure needs its own field rather than being folded into
      // failedSections.
      expect(completed['failedSections'], isEmpty);
    },
  );

  test(
    'a healthy tick emits an EMPTY reconcileFailed, so the field means '
    '"nothing failed" and not "we did not measure"',
    () async {
      final lines = <String, Map<String, dynamic>>{};
      final tick = TickSingleFlight(
        log: (event, data) => lines[event] = data,
        runTick: () async => TickOutcome(failedSections: <String>[]),
      );

      await tick.trigger();

      final completed = lines['scheduler.tick.completed']!;
      expect(completed['reconcileFailed'], isEmpty);
      expect(completed['reconcileFailedCount'], 0);
    },
  );

  test(
    'an overlapped tick reports the same shape, with nothing failed',
    () async {
      final lines = <String, Map<String, dynamic>>{};
      final release = Completer<void>();
      final tick = TickSingleFlight(
        log: (event, data) => lines[event] = data,
        runTick: () async {
          await release.future;
          return TickOutcome(failedSections: <String>[]);
        },
      );

      // Hold the first tick open, then let a second overlap it. The second is
      // dropped and emits its own completion line.
      final first = tick.trigger();
      await tick.trigger();

      expect(
        lines['scheduler.tick.completed']!['reconcileFailed'],
        isEmpty,
      );
      expect(
        lines['scheduler.tick.completed']!['reconcileFailedCount'],
        0,
        reason:
            'the dropped-tick line must carry the same shape as the clean '
            'one, so an operator reading one shape never has to guess whether a '
            'field is missing or merely empty',
      );

      release.complete();
      await first;
    },
  );
}

/// Fails on the work item ids in [failing], so a tick genuinely cannot
/// reconcile them.
class _FaultingWorkflowStore implements WorkflowStore {
  _FaultingWorkflowStore(this._inner, {required this.failing});

  final WorkflowStore _inner;
  final String failing;

  @override
  Future<WorkItem> readWorkItem(String workItemId) {
    if (workItemId == failing) {
      throw StateError('unreconcilable row for $workItemId');
    }
    return _inner.readWorkItem(workItemId);
  }

  @override
  Future<List<WorkItem>> readAllWorkItems() => _inner.readAllWorkItems();

  @override
  Future<void> saveWorkItem(WorkItem item, {int? expectedVersion}) =>
      _inner.saveWorkItem(item, expectedVersion: expectedVersion);

  @override
  Future<HumanDecision> readHumanDecision(String decisionId) =>
      _inner.readHumanDecision(decisionId);

  @override
  Future<List<HumanDecision>> readHumanDecisionsForWorkItem(
    String workItemId,
  ) => _inner.readHumanDecisionsForWorkItem(workItemId);

  @override
  Future<void> saveHumanDecision(HumanDecision decision) =>
      _inner.saveHumanDecision(decision);

  @override
  Future<List<WorkflowTransitionRecord>> readTransitionHistory(
    String workItemId,
  ) => _inner.readTransitionHistory(workItemId);

  @override
  Future<WorkflowTransitionRecord?> findTransitionByIdempotencyKey(
    String workItemId,
    String idempotencyKey,
  ) => _inner.findTransitionByIdempotencyKey(workItemId, idempotencyKey);

  @override
  Future<void> appendTransitionRecord(WorkflowTransitionRecord record) =>
      _inner.appendTransitionRecord(record);

  @override
  Future<void> appendOperatorAction(OperatorActionRecord record) =>
      _inner.appendOperatorAction(record);

  @override
  Future<List<OperatorActionRecord>> readOperatorActionsForWorkItem(
    String workItemId,
  ) => _inner.readOperatorActionsForWorkItem(workItemId);

  @override
  Future<T> inTransaction<T>(Future<T> Function(WorkflowStore store) body) =>
      body(this);
}

/// A dispatch that never dispatches: these tests are about reconciliation, and a
/// real worker would need a git worktree and an agent.
class _NoopDispatch implements WorkerDispatch {
  const _NoopDispatch();

  @override
  WorkerSelection select(WorkerExecutionRequest request) =>
      WorkerSelection.busy(compatibleWorkers: const []);

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) =>
      throw StateError('not used');

  @override
  Future<void> cancel(String workerId, String reason) async {}
}
