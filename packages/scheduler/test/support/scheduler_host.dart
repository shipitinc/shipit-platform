import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'gate_fake_agent.dart';
import 'git_repo_fixture.dart';

/// Full-stack deterministic host: real workflow engine + store, real
/// execution coordinator, real worker (git worktree + capacity-1 + verifier)
/// with a gated writing fake runtime, plus the scheduler on top of all of it.
/// One [SchedulerHost] is one capacity-1 worker with a persistent job store.
class SchedulerHost {
  SchedulerHost({
    required GitRepoFixture repo,
    required String workspaceRoot,
    required JobStore jobStore,
    SchedulerWorkload? workload,
    JobDefinition definition = defaultImplementFeatureDefinition,
    Duration claimLease = const Duration(minutes: 10),
  }) {
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();
    session = GateFakeAgentSession(
      executionId: 'agx-fixed',
      workItemId: 'wi-1',
    );
    runtime = AgentRuntime(
      registry: AgentAdapterRegistry()..register(GateFakeAgentAdapter(session)),
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
    worker = LocalWorker(
      workerId: 'w-linux-1',
      poolId: 'linux-pool',
      capabilities: const {
        WorkerCapability.linux,
        WorkerCapability.docker,
        WorkerCapability.flutter,
      },
      workspaceManager: workspaceManager,
      executionDriver: driver,
      workerStore: workerStore,
      platform: 'linux-x64',
    );
    dispatcher = WorkerDispatcher(registry: WorkerRegistry()..register(worker));
    this.jobStore = jobStore;
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
    );
  }

  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;
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
    await workflowEngine.createWorkItem(
      workItemId: workItemId,
      productId: productId,
      category: WorkItemCategory.feature,
      title: title,
      description: 'Blocked item awaiting a human decision',
      designContractId: 'dc-$workItemId',
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
      context: {'designContractId': 'dc-$workItemId'},
    );
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.designInReview,
      trigger: TransitionTrigger.systemEvent,
      context: {
        'designContractId': 'dc-$workItemId',
        'designContractStatus': DesignContractStatus.underReview,
      },
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
