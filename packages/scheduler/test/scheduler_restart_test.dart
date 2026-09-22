import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

import 'support/controlled_dispatcher.dart';
import 'support/file_host.dart';

void main() {
  late Directory dir;
  final t0 = DateTime.utc(2026, 1, 1, 12);
  final t1 = t0.add(const Duration(minutes: 11)); // lease (10 min) is expired

  setUp(() {
    dir = Directory.systemTemp.createTempSync('scheduler_restart_test');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('claim-crash: a claim persisted but never dispatched is safely requeued '
      'and executed exactly once by a fresh process', () async {
    final first = FileRestartHarness(dir, clock: () => t0);
    await first.itemRunnable();
    await first.plantClaimedJob(t0); // crash between claim and dispatch

    final second = FileRestartHarness(dir, clock: () => t1);
    final tick = await second.scheduler.tick();

    expect(tick.reconciled, hasLength(1));
    final job = (await second.jobStore.listJobs()).single;
    expect(job.state, JobState.succeeded);
    expect(job.failure, isNull);
    expect((second.dispatch as ControlledDispatcher).runs, hasLength(1));
    expect(await second.jobStore.readClaimForJob(job.jobId), isNull);

    // Lifecycle: queued -> claimed (crashed) -> QUEUED (reclaim) ->
    // claimed -> dispatched -> completed. Exactly one real dispatch.
    final events = await second.jobStore.readEvents(job.jobId);
    expect(events.map((e) => e.type), [
      SchedulerEventType.jobQueued,
      SchedulerEventType.jobClaimed,
      SchedulerEventType.jobQueued,
      SchedulerEventType.jobClaimed,
      SchedulerEventType.jobDispatched,
      SchedulerEventType.jobCompleted,
    ]);
    expect(
      events.where((e) => e.type == SchedulerEventType.jobDispatched),
      hasLength(1),
    );
  });

  test('crash with a LIVE worker execution: the scheduler never dispatches a '
      'duplicate, it only renews the lease and leaves orphaning to the worker '
      'layer', () async {
    final first = FileRestartHarness(dir, clock: () => t0);
    await first.itemRunnable();
    final running = await first.plantRunningJob(t0);
    final wx = running.executionReference!.workerExecutionId;
    await first.workerStore.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: wx,
        workItemId: 'wi-1',
        repositoryPath: '${dir.path}/repo',
        requestedStartingRevision: 'deadbeef',
        requiredCapabilities: running.requiredCapabilities,
        status: WorkerExecutionStatus.agentExecuting,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
        workerId: 'w-1',
        startedAt: t0,
      ),
    );
    // crash before the execution finished and before adoption

    final second = FileRestartHarness(dir, clock: () => t1);
    final tick = await second.scheduler.tick();

    expect(tick.reconciled, hasLength(1));
    final job = (await second.jobStore.listJobs()).single;
    expect(job.state, JobState.running); // NOT duplicated, NOT abandoned
    expect((second.dispatch as ControlledDispatcher).runs, isEmpty);

    // The lease was renewed, not dropped, so a live execution is protected
    // from being stomped by a second scheduler tick.
    final renewed = await second.jobStore.readClaimForJob(job.jobId);
    expect(renewed!.leasedUntil, t1.add(const Duration(minutes: 10)));
  });

  test(
    'crash after the worker finished but before adoption: the durably-stored '
    'terminal result is adopted and no new execution is started',
    () async {
      final first = FileRestartHarness(dir, clock: () => t0);
      await first.itemRunnable();
      final running = await first.plantRunningJob(t0);
      final wx = running.executionReference!.workerExecutionId;
      await first.workerStore.saveWorkerExecution(
        WorkerExecution(
          workerExecutionId: wx,
          workItemId: 'wi-1',
          repositoryPath: '${dir.path}/repo',
          requestedStartingRevision: 'deadbeef',
          requiredCapabilities: running.requiredCapabilities,
          status: WorkerExecutionStatus.executedPass,
          cleanupPolicy: WorkerCleanupPolicy.removeAlways,
          workerId: 'w-1',
          startedAt: t0,
          endedAt: t1,
        ),
      );
      await first.workerStore.saveResult(
        WorkerExecutionResult(
          workerExecutionId: wx,
          workItemId: 'wi-1',
          status: WorkerExecutionStatus.executedPass,
          workerId: 'w-1',
          workspaceId: 'ws-$wx',
          startingRevision: 'deadbeef',
          startedAt: t0,
          endedAt: t1,
          cleanupStatus: WorkerCleanupStatus.removed,
          failureCode: WorkerFailureCode.none,
        ),
      );

      final second = FileRestartHarness(dir, clock: () => t1);
      final tick = await second.scheduler.tick();

      expect(tick.reconciled, hasLength(1));
      final job = (await second.jobStore.listJobs()).single;
      expect(job.state, JobState.succeeded);
      expect((second.dispatch as ControlledDispatcher).runs, isEmpty);
      expect(await second.jobStore.readClaimForJob(job.jobId), isNull);
    },
  );

  test('a work item reaching a terminal state cancels its residual queued job '
      'without ever starting an execution', () async {
    final host = FileRestartHarness(dir, clock: () => t0);
    await host.itemRunnable();
    await host.enqueueJob(); // queued, never dispatched

    // The workflow moves the item to a terminal state.
    await host.workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.cancelled,
      trigger: TransitionTrigger.systemEvent,
    );

    final tick = await host.scheduler.tick();

    final job = (await host.jobStore.listJobs()).single;
    expect(job.state, JobState.cancelled);
    expect(job.cancelReason, contains('work item is cancelled'));
    expect(tick.cancelledQueued, [job.jobId]);
    expect((host.dispatch as ControlledDispatcher).runs, isEmpty);
    final events = await host.jobStore.readEvents(job.jobId);
    expect(events.last.type, SchedulerEventType.jobCancelled);
  });

  test('a blocked item leaves its (never-created) queue completely empty even '
      'after a process restart', () async {
    final first = FileRestartHarness(dir, clock: () => t0);
    await first.workflowEngine.createWorkItem(
      workItemId: 'wi-1',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Blocked',
      description: 'Blocked work item for restart durability',
      designContractId: 'dc-1',
      featureRef: 'feature/blocked',
    );
    await first.workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
    );
    await first.workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      context: const {'featureRef': 'feature/blocked'},
    );
    await first.workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.designRequired,
      trigger: TransitionTrigger.systemEvent,
      context: const {'designContractId': 'dc-1'},
    );
    await first.workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.designInReview,
      trigger: TransitionTrigger.systemEvent,
      context: const {
        'designContractId': 'dc-1',
        'designContractStatus': DesignContractStatus.underReview,
      },
    );
    await first.workflowEngine.requestHumanDecision(
      workItemId: 'wi-1',
      decisionType: HumanDecisionType.designApproval,
      blocking: true,
      question: 'Approve?',
    );

    final second = FileRestartHarness(dir, clock: () => t1);
    final tick = await second.scheduler.tick();
    expect(tick.enqueued, isEmpty);
    expect(await second.jobStore.listJobs(), isEmpty);
    expect(await second.jobStore.readEvents('any'), isEmpty);
  });
}
