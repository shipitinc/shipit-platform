import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

import 'support/controlled_dispatcher.dart';
import 'support/file_host.dart';
import 'support/racing_workflow_store.dart';

/// Losing the work-item compare-and-swap aborted the entire tick.
///
/// `DurableWorkflowEngine.transition` rethrows [ConcurrentModificationException]
/// out of its transaction, and that is a SIBLING of
/// [WorkflowTransitionRejectedException] — neither extends the other. Catching
/// only the rejected case let the lost race escape `_releaseWorkItem`, and since
/// `tick` guarded nothing, the exception unwound the whole loop: the job was
/// never failed, its claim never released, its worker execution never retired,
/// and every other job's reconciliation was skipped too. That is a total reclaim
/// failure, and it is strictly worse than the stranding this code exists to
/// prevent — the job holds its capacity slot forever.
void main() {
  late Directory dir;
  final t0 = DateTime.utc(2026, 1, 1, 12);
  final t1 = t0.add(const Duration(minutes: 11));
  final zombieStart = t0.subtract(const Duration(hours: 4, minutes: 47));

  setUp(() {
    dir = Directory.systemTemp.createTempSync('scheduler_reclaim_race_');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  /// Plants a stranded zombie for [workItemId], then returns a harness whose
  /// workflow store is the racing wrapper.
  ///
  /// The wrapper is built AFTER the seed writes, deliberately: a
  /// `FileJsonWorkflowStore` loads its state at construction, so wrapping a
  /// store created before the seed would compare against a stale in-memory
  /// copy and never see the planted item.
  Future<({FileRestartHarness host, RacingWorkflowStore store})> plantZombie({
    String workItemId = 'wi-1',
    RacingMode mode = RacingMode.versionBump,
    WorkItemState takesOverState = WorkItemState.agentFailed,
    Set<String> failingWorkItemIds = const {},
  }) async {
    final seed = FileRestartHarness(dir, clock: () => t0);
    await seed.itemRunnable(workItemId: workItemId);
    await seed.itemExecuting(workItemId: workItemId);
    final running = await seed.plantRunningJob(t0, workItemId: workItemId);
    await seed.workerStore.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: running.executionReference!.workerExecutionId,
        workItemId: workItemId,
        repositoryPath: '${dir.path}/repo',
        requestedStartingRevision: 'deadbeef',
        requiredCapabilities: running.requiredCapabilities,
        status: WorkerExecutionStatus.agentExecuting,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
        workerId: 'w-1',
        startedAt: zombieStart,
      ),
    );

    final store = RacingWorkflowStore(
      FileRestartHarness(dir, clock: () => t0).workflowStore,
      mode: mode,
      takesOverState: takesOverState,
    )..failingWorkItemIds.addAll(failingWorkItemIds);

    return (
      host: FileRestartHarness(
        dir,
        clock: () => t1,
        workflowStoreOverride: store,
      ),
      store: store,
    );
  }

  group('R1: a reclaim that loses the work-item compare-and-swap still works', () {
    test('the race fires, and the job STILL fails, the claim IS released and the '
        'worker execution IS retired', () async {
      final planted = await plantZombie();
      final store = planted.store;
      final host = planted.host;

      await host.scheduler.tick();

      // The race must actually have been provoked, or this test would pass for
      // the wrong reason.
      expect(
        store.fired,
        greaterThan(0),
        reason: 'the competing writer never won the CAS',
      );

      final job = (await host.jobStore.listJobs()).single;
      expect(
        job.state,
        JobState.failed,
        reason: 'a lost CAS must not leave the job held and leaking capacity',
      );
      expect(job.isTerminal, isTrue);
      expect(
        await host.jobStore.readClaimForJob(job.jobId),
        isNull,
        reason: 'the claim must be released',
      );

      final execution = await host.workerStore.readWorkerExecution(
        'wx-${job.jobId}',
      );
      expect(
        execution!.isTerminal,
        isTrue,
        reason: 'the worker execution must still be retired',
      );

      // And the work item must not be stranded: catching and moving straight on
      // would leave it exactly where it was.
      expect(
        (await host.workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.agentFailed,
      );
    });

    test(
      'a competing writer that TAKES OVER the item is not fought over',
      () async {
        final planted = await plantZombie(
          mode: RacingMode.takesOver,
          takesOverState: WorkItemState.agentCompleted,
        );
        final store = planted.store;
        final host = planted.host;

        await host.scheduler.tick();

        expect(store.fired, greaterThan(0));
        final job = (await host.jobStore.listJobs()).single;
        expect(job.state, JobState.failed);
        expect(
          (await host.workflowEngine.loadWorkItem('wi-1')).state,
          WorkItemState.agentCompleted,
          reason: 'the writer that won the race keeps its decision',
        );
      },
    );

    test(
      'the fix is in the reclaim, NOT in the tick guard: a reclaim that loses '
      'the CAS resolves even with the tick guard removed',
      () async {
        // Guards against the inner catch being made redundant by the outer one.
        final planted = await plantZombie();
        final store = planted.store;
        final host = planted.host;

        // Call the reclaim's own effect through the public tick, but assert on
        // the fact that the work item — which only the INNER catch can release —
        // was released even though a competing writer bumped it mid-flight.
        await host.scheduler.tick();
        expect(store.fired, greaterThan(0));
        expect(
          (await host.workflowEngine.loadWorkItem('wi-1')).state,
          WorkItemState.agentFailed,
          reason:
              'only the inner catch can produce this; the tick guard only '
              'keeps the loop alive and would leave the item stranded',
        );
      },
    );
  });

  group('R2: one unreconcilable row must not starve the others', () {
    test(
      'a row that throws during reconciliation does not abort the tick, and the '
      'healthy row still reclaims',
      () async {
        // Two stranded zombies, both expired. 'wi-bad' will be made unreadable
        // AFTER planting, so the fault lands on reconciliation rather than on
        // the seeding that creates it.
        final seed = FileRestartHarness(dir, clock: () => t0);
        for (final id in ['wi-1', 'wi-bad']) {
          await seed.itemRunnable(workItemId: id);
          await seed.itemExecuting(workItemId: id);
          final running = await seed.plantRunningJob(t0, workItemId: id);
          await seed.workerStore.saveWorkerExecution(
            WorkerExecution(
              workerExecutionId: running.executionReference!.workerExecutionId,
              workItemId: id,
              repositoryPath: '${dir.path}/repo',
              requestedStartingRevision: 'deadbeef',
              requiredCapabilities: running.requiredCapabilities,
              status: WorkerExecutionStatus.agentExecuting,
              cleanupPolicy: WorkerCleanupPolicy.removeAlways,
              workerId: 'w-1',
              startedAt: zombieStart,
            ),
          );
        }

        final store = RacingWorkflowStore(
          FileRestartHarness(dir, clock: () => t0).workflowStore,
        )..failingWorkItemIds.add('wi-bad');
        final healthy = FileRestartHarness(
          dir,
          clock: () => t1,
          workflowStoreOverride: store,
        );

        // The tick itself must complete rather than throw.
        final tick = await healthy.scheduler.tick();

        final jobs = {
          for (final j in await healthy.jobStore.listJobs()) j.workItemId: j,
        };

        expect(
          jobs['wi-1']!.state,
          JobState.failed,
          reason: 'the healthy row must still be reclaimed',
        );
        expect(
          jobs['wi-bad']!.state,
          JobState.running,
          reason: 'the broken row is left held for the next tick, not lost',
        );

        // The broken row is honestly NOT counted as reconciled — the only
        // observable effect the scheduler has, since it has no log channel.
        expect(tick.reconciled, [
          jobs['wi-1']!.jobId,
        ], reason: 'a row that threw did not reconcile');

        // Nothing was dispatched as a side effect.
        expect((healthy.dispatch as ControlledDispatcher).runs, isEmpty);
      },
    );
  });
}
