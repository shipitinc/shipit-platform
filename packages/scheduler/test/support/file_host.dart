import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'controlled_dispatcher.dart';

/// File-backed harness for scheduler crash/restart tests. Constructing a new
/// instance over the same [Directory] simulates a fresh process that must
/// resume from the persisted workflow, job, and worker stores alone.
class FileRestartHarness {
  FileRestartHarness(
    this.dir, {
    required DateTime Function() clock,
    WorkerDispatch? dispatch,
    JobDefinition definition = defaultImplementFeatureDefinition,
    Duration claimLease = const Duration(minutes: 10),
  }) {
    workflowStore = FileJsonWorkflowStore(File('${dir.path}/workflow.json'));
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    jobStore = FileJsonJobStore(File('${dir.path}/jobs.json'));
    workerStore = FileJsonWorkerStore(File('${dir.path}/workers.json'));
    this.dispatch = dispatch ?? ControlledDispatcher();
    scheduler = Scheduler(
      schedulerId: 'sched-1',
      workflowStore: workflowStore,
      jobStore: jobStore,
      workerStore: workerStore,
      dispatch: this.dispatch,
      definition: definition,
      workload: SchedulerWorkload(
        repositoryPath: '${dir.path}/repo',
        startingRevision: 'deadbeef',
        timeoutSeconds: 60,
        runtimeTypeId: 'fake-runtime',
      ),
      clock: clock,
      claimLease: claimLease,
    );
  }

  final Directory dir;

  late FileJsonWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late FileJsonJobStore jobStore;
  late FileJsonWorkerStore workerStore;
  late WorkerDispatch dispatch;
  late Scheduler scheduler;

  String get dedupeKey =>
      'wi-1:design_not_required:implement_feature:IMPLEMENTER';

  Future<WorkItem> itemRunnable() async {
    await workflowEngine.createWorkItem(
      workItemId: 'wi-1',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Implement calculator add',
      description:
          'Implement the calculator add function for the contract suite',
      qaContractId: 'qa-1',
      featureRef: 'feature/calc',
    );
    await workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
    );
    await workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      context: const {'featureRef': 'feature/calc'},
    );
    return workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );
  }

  Future<Job> enqueueJob({String? jobId}) async {
    final result = await scheduler.queue.enqueueIfAbsent(
      workItemId: 'wi-1',
      definition: defaultImplementFeatureDefinition,
      dedupeKey: dedupeKey,
      instruction: 'Implement the feature.',
      now: DateTime.utc(2026, 1, 1),
    );
    return result.job;
  }

  /// Plants a claimed (or running) job plus its lease. Returns the job in its
  /// claimed state (before any worker dispatch).
  Future<Job> plantClaimedJob(DateTime t0) async {
    final job = await enqueueJob();
    final claim = await scheduler.queue.claim(
      job: job,
      ownerId: 'sched-1',
      now: t0,
      lease: const Duration(minutes: 10),
    );
    expectClaimed(claim!);
    return (await jobStore.readJob(job.jobId))!;
  }

  /// Marks the claimed job as dispatched to a worker (execution reference
  /// durably recorded with the requested workerExecutionId).
  Future<Job> plantRunningJob(DateTime t0) async {
    final job = await plantClaimedJob(t0);
    return scheduler.queue.markRunning(
      job: job,
      now: t0,
      workerId: 'w-1',
      workerExecutionId: 'wx-${job.jobId}',
    );
  }
}

void expectClaimed(JobClaim claim) {
  assert(claim.jobId.isNotEmpty, 'claim must reference a job');
}
