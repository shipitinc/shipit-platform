import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'gate_fake_agent.dart';
import 'git_repo_fixture.dart';
import 'hooked_workspace_manager.dart';

/// Full-stack deterministic host: real workflow engine + store, real
/// execution coordinator, real worker (git worktree + capacity-1 + verifier)
/// with a gated writing fake runtime, plus the scheduler on top of all of it.
/// One [SchedulerHost] is one capacity-1 worker with a persistent job store.
class SchedulerHost {
  /// Runs inside the real worker's prepare window — after the git worktree
  /// exists, before the coordinator is asked to start the execution — with the
  /// work item id the worker is about to execute. Null means the window is not
  /// observed and the worker path is untouched.
  final Future<void> Function(String workItemId)? onWorkspacePrepared;

  SchedulerHost({
    required GitRepoFixture repo,
    required String workspaceRoot,
    required JobStore jobStore,
    SchedulerWorkload? workload,
    JobDefinition definition = defaultImplementFeatureDefinition,
    Duration claimLease = const Duration(minutes: 10),
    Set<WorkerCapability> workerCapabilities = const {
      WorkerCapability.linux,
      WorkerCapability.docker,
      WorkerCapability.flutter,
    },
    this.onWorkspacePrepared,
    AgentAdapter? adapter,
  }) {
    workflowStore = InMemoryWorkflowStore();
    // `designContractExists()` reads the work item's `designContractId` column
    // and confirms it against a store, so an engine with no store mounted can
    // never take `planned -> designRequired`. This is the mount the production
    // composition root makes with `PostgresDesignContractStore`; the in-memory
    // tier is the honest equivalent for a test, and the rows it holds are real
    // rows rather than context strings.
    designContractStore = InMemoryDesignContractStore();
    workflowEngine = DurableWorkflowEngine(
      store: workflowStore,
      designContractStore: designContractStore,
    );
    executionStore = InMemoryExecutionStore();
    session = GateFakeAgentSession(
      executionId: 'agx-fixed',
      workItemId: 'wi-1',
    );
    runtime = AgentRuntime(
      registry: AgentAdapterRegistry()
        ..register(adapter ?? GateFakeAgentAdapter(this.session)),
    );
    coordinator = ExecutionCoordinator(
      store: executionStore,
      workflowEngine: workflowEngine,
      runtime: runtime,
      verificationPlan: VerificationPlan(
        command: [Platform.resolvedExecutable, 'tool/verify.dart'],
      ),
    );
    driver = CoordinatorAgentExecutionDriver(coordinator);
    workerStore = InMemoryWorkerStore();
    workspaceManager = GitWorktreeWorkspaceManager(
      workspaceRoot: workspaceRoot,
    );
    // The prepare hook decorates the REAL manager rather than replacing it, so
    // a test that uses it still gets a real git worktree and every later step
    // of the worker's real path. It only runs BETWEEN prepare and the
    // coordinator's `execute` — the window `LocalWorker` genuinely opens at
    // local_worker.dart:152 and closes at :186, and the window in which a work
    // item can legitimately move under a dispatched job.
    final baseManager = workspaceManager;
    final afterPrepared = onWorkspacePrepared;
    final effectiveManager = afterPrepared == null
        ? baseManager
        : HookedWorkspaceManager(
            baseManager,
            afterPrepared: (request, descriptor) =>
                afterPrepared(request.workItemId),
          );
    worker = LocalWorker(
      workerId: 'w-linux-1',
      poolId: 'linux-pool',
      capabilities: workerCapabilities,
      workspaceManager: effectiveManager,
      executionDriver: driver,
      workerStore: workerStore,
      platform: 'linux-x64',
    );
    dispatcher = WorkerDispatcher(registry: WorkerRegistry()..register(worker));
    this.jobStore = jobStore;
    final modelPolicyStore = InMemoryModelPolicyStore();
    final modelSelection = ModelSelectionService(modelPolicyStore);
    scheduler = Scheduler(
      schedulerId: 'sched-1',
      workflowStore: workflowStore,
      jobStore: jobStore,
      workerStore: workerStore,
      dispatch: WorkerDispatcherAdapter(dispatcher),
      definition: definition,
      workload:
          workload ??
          SchedulerWorkload(
            repositoryPath: repo.root.path,
            startingRevision: repo.startingRevision,
            timeoutSeconds: 60,
            runtimeTypeId: 'fake-runtime',
          ),
      claimLease: claimLease,
      modelSelection: modelSelection,
    );
  }

  late InMemoryWorkflowStore workflowStore;
  late InMemoryDesignContractStore designContractStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;

  /// The `designContractId` to stamp on a work item that will be walked to
  /// `designRequired`, having written the contract row it names.
  ///
  /// Returns the id of the row the store READ BACK, not the id that was
  /// submitted — the same discipline `DesignContractProvisioner` exists to
  /// enforce, and the reason these fixtures no longer pass
  /// `context: {'designContractId': …}`: a string in context is no longer what
  /// the guard reads, so a fixture that kept passing one would go on working
  /// while proving nothing.
  Future<String> provisionDesignContractFor(
    String workItemId, {
    String productId = 'prod-1',
  }) async =>
      (await DesignContractProvisioner(
            contractStore: designContractStore,
          ).provisionForWorkItem(workItemId: workItemId, productId: productId))
          .contractId;

  /// The gated fake agent the coordinator drives by default: it parks a run so a
  /// test can observe it in flight, then writes a real implementation into the
  /// prepared worktree so the verifier behaves exactly as it would in
  /// production.
  ///
  /// It is the DEFAULT runtime, not the only one: a test that needs a genuine
  /// agent failure injects an [adapter] for a failing session rather than
  /// scripting a failure at the scheduler boundary, and then ignores this field.
  late GateFakeAgentSession session;
  late AgentRuntime runtime;
  late ExecutionCoordinator coordinator;
  late CoordinatorAgentExecutionDriver driver;
  late InMemoryWorkerStore workerStore;
  late GitWorktreeWorkspaceManager workspaceManager;
  late LocalWorker worker;
  late WorkerDispatcher dispatcher;
  late JobStore jobStore;
  late Scheduler scheduler;

  /// A work item politely parked at `designNotRequired`: RUNNABLE.
  Future<WorkItem> itemRunnable({
    String workItemId = 'wi-1',
    String productId = 'prod-1',
    String title = 'Implement calculator add',
  }) async {
    await workflowEngine.createWorkItem(
      workItemId: workItemId,
      productId: productId,
      category: WorkItemCategory.feature,
      title: title,
      description: 'Runnable calculator item exercising scheduler capacity',
      qaContractId: 'qa-1',
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

  /// A work item parked at a BLOCKING human decision gate
  /// (`waitingForHumanDecision` under a pending designApproval): BLOCKED,
  /// consumes zero capacity.
  Future<WorkItem> itemBlocked({
    String workItemId = 'wi-a',
    String productId = 'prod-1',
    String title = 'Blocked item',
  }) async {
    final contractId = await provisionDesignContractFor(
      workItemId,
      productId: productId,
    );
    await workflowEngine.createWorkItem(
      workItemId: workItemId,
      productId: productId,
      category: WorkItemCategory.feature,
      title: title,
      description: 'Blocked item awaiting a human decision',
      designContractId: contractId,
      qaContractId: 'qa-$workItemId',
      featureRef: 'feature/blocked',
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
      context: const {'featureRef': 'feature/blocked'},
    );
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.designRequired,
      trigger: TransitionTrigger.systemEvent,
    );
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.designInReview,
      trigger: TransitionTrigger.systemEvent,
      context: const {'designContractStatus': DesignContractStatus.underReview},
    );
    await workflowEngine.requestHumanDecision(
      workItemId: workItemId,
      decisionType: HumanDecisionType.designApproval,
      blocking: true,
      question: 'Approve the design for $title?',
    );
    return workflowEngine.loadWorkItem(workItemId);
  }

  /// The human resolves the design gate: the item leaves its blocking gate
  /// and becomes RUNNABLE via designApproved, WITHOUT replaying any history.
  Future<WorkItem> humanApproves({
    required String workItemId,
    String? decisionId,
  }) async {
    final item = await workflowEngine.loadWorkItem(workItemId);
    final id = decisionId ?? item.blockingHumanDecisionId!;
    return workflowEngine.resolveHumanDecision(
      decisionId: id,
      choice: HumanDecisionChoice.approve,
      decider: 'hum@shipit.platform',
      rationale: 'design approved by engineering lead',
      signature: DecisionSignature(
        algorithm: 'ed25519',
        publicKey: 'test-public-key',
        signature: 'sig-approve-$workItemId',
        signedAt: DateTime.now().toUtc(),
      ),
    );
  }
}
