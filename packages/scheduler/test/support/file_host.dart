import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'controlled_dispatcher.dart';
import 'settle.dart';

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
    ExecutionLivenessProbe? executionLiveness,
    AgentExecutionRetirement? agentExecutionRetirement,
    Duration? zombieStalenessAfter,
    WorkflowStore? workflowStoreOverride,
  }) {
    workflowStore =
        workflowStoreOverride ??
        FileJsonWorkflowStore(File('${dir.path}/workflow.json'));
    // The same mount `SchedulerHost` makes and the composition root makes with
    // `PostgresDesignContractStore`: `designContractExists()` confirms the
    // work item's `designContractId` column against a store, so an engine with
    // none mounted refuses `planned -> designRequired` outright.
    designContractStore = InMemoryDesignContractStore();
    workflowEngine = DurableWorkflowEngine(
      store: workflowStore,
      designContractStore: designContractStore,
    );
    jobStore = FileJsonJobStore(File('${dir.path}/jobs.json'));
    workerStore = FileJsonWorkerStore(File('${dir.path}/workers.json'));
    // The default dispatcher writes its terminal worker rows into the same
    // store the scheduler reconciles from, so a dispatched job settles via
    // `_reconcileClaim` -> `_adoptFromExecution` on the tick after its run —
    // the same path a real `LocalWorker` run takes. A caller-supplied
    // dispatcher is wired to the same store unless it already has one.
    this.dispatch = dispatch ?? ControlledDispatcher(workerStore: workerStore);
    final supplied = this.dispatch;
    if (supplied is ControlledDispatcher) {
      // Re-point, never ??=: a dispatcher shared across a restart would keep
      // writing durable tails into the FIRST host's store, while
      // FileJsonWorkerStore snapshots at construction — the resumed host's
      // reconcile would never see the run's rows and would requeue forever.
      supplied.workerStore = workerStore;
    }
    final modelPolicyStore = InMemoryModelPolicyStore();
    final modelSelection = ModelSelectionService(modelPolicyStore);
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
      executionLiveness: executionLiveness,
      agentExecutionRetirement: agentExecutionRetirement,
      zombieStalenessAfter: zombieStalenessAfter,
      modelSelection: modelSelection,
    );
  }

  final Directory dir;

  late WorkflowStore workflowStore;
  late InMemoryDesignContractStore designContractStore;
  late DurableWorkflowEngine workflowEngine;
  late FileJsonJobStore jobStore;
  late FileJsonWorkerStore workerStore;

  /// The id of a design contract row written and read back for [workItemId].
  ///
  /// Returns the store's READ-BACK id rather than the submitted one, so a
  /// fixture never stamps a work item with an id it has not seen resolve.
  Future<String> provisionDesignContractFor(
    String workItemId, {
    String productId = 'prod-1',
  }) async =>
      (await DesignContractProvisioner(
            contractStore: designContractStore,
          ).provisionForWorkItem(workItemId: workItemId, productId: productId))
          .contractId;
  late WorkerDispatch dispatch;
  late Scheduler scheduler;

  String get dedupeKey =>
      'wi-1:design_not_required:implement_feature:IMPLEMENTER';

  Future<WorkItem> itemRunnable({String workItemId = 'wi-1'}) async {
    await workflowEngine.createWorkItem(
      workItemId: workItemId,
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Implement calculator add',
      description:
          'Implement the calculator add function for the contract suite',
      qaContractId: 'qa-1-$workItemId',
      featureRef: 'feature/calc',
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
      context: const {'featureRef': 'feature/calc'},
    );
    return workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );
  }

  Future<Job> enqueueJob({String? jobId, String workItemId = 'wi-1'}) async {
    final result = await scheduler.queue.enqueueIfAbsent(
      workItemId: workItemId,
      definition: defaultImplementFeatureDefinition,
      dedupeKey: workItemId == 'wi-1'
          ? dedupeKey
          : '$workItemId:design_not_required:implement_feature:IMPLEMENTER',
      instruction: 'Implement the feature.',
      now: DateTime.utc(2026, 1, 1),
    );
    return result.job;
  }

  /// Moves the item to `agentExecuting`, which is the state a dispatched job's
  /// work item really sits in while its execution runs. `plantRunningJob` records
  /// the worker half of the chain; this records the workflow half, so a reclaim
  /// test starts from the state QA observed rather than from `designNotRequired`.
  Future<WorkItem> itemExecuting({String workItemId = 'wi-1'}) =>
      workflowEngine.transition(
        workItemId: workItemId,
        to: WorkItemState.agentExecuting,
        trigger: TransitionTrigger.systemEvent,
        // The edge is guarded by `agentAvailable()`, and the context that
        // satisfies it is the same one `RunnableWorkEvaluator` supplies.
        context: const {'agentAvailable': true, 'capabilitiesMatch': true},
      );

  /// Plants a claimed (or running) job plus its lease. Returns the job in its
  /// claimed state (before any worker dispatch).
  Future<Job> plantClaimedJob(DateTime t0, {String workItemId = 'wi-1'}) async {
    final job = await enqueueJob(workItemId: workItemId);
    final claim = await scheduler.queue.claim(
      job: job,
      ownerId: 'sched-1',
      now: t0,
      lease: const Duration(minutes: 10),
    );
    expectClaimed(claim!);
    return (await jobStore.readJob(job.jobId))!;
  }

  /// Waits for every currently-held job's detached run to release its claim,
  /// then runs the tick that settles it through reconcile-adoption — the two
  /// halves a production tick interval provides between "the run ended" and
  /// "the job was adopted".
  ///
  /// Dispatch is detached (F-237): a tick STARTS the execution and returns,
  /// and the run's continuation drops the claim so the NEXT tick's
  /// `_reconcileClaim` adopts the terminal worker execution. Tests must not
  /// observe that release with a fixed sleep; the claim going absent is the
  /// durable signal itself.
  Future<SchedulerTickResult> settle() => settleHeldJobs(jobStore, scheduler);

  /// Marks the claimed job as dispatched to a worker (execution reference
  /// durably recorded with the requested workerExecutionId).
  Future<Job> plantRunningJob(DateTime t0, {String workItemId = 'wi-1'}) async {
    final job = await plantClaimedJob(t0, workItemId: workItemId);
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
