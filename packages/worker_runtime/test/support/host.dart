import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'fake_agent.dart';
import 'git_repo_fixture.dart';

/// Wires the worker layer to the REAL [ExecutionCoordinator] (real workflow
/// engine, real execution store) with a writing fake runtime, so worker tests
/// exercise the full stack deterministically without a real LLM.
class WorkerHost {
  WorkerHost({
    required GitRepoFixture repo,
    required String workspaceRoot,
    WritingBehavior behavior = WritingBehavior.writeImplementation,
  }) {
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();
    session = WritingFakeAgentSession(
      executionId: 'agx-fixed',
      workItemId: 'wi-1',
      behavior: behavior,
    );
    runtime = AgentRuntime(
      registry: AgentAdapterRegistry()
        ..register(WritingFakeAgentAdapter(session)),
    );
    coordinator = ExecutionCoordinator(
      store: executionStore,
      workflowEngine: workflowEngine,
      runtime: runtime,
      // Relative command: the verifier runs in the WORKTREE (the workspace),
      // so `tool/verify.dart` and its `../lib/calculator.dart` import resolve
      // against the isolated worktree, not the source checkout.
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
  }

  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;
  late WritingFakeAgentSession session;
  late AgentRuntime runtime;
  late ExecutionCoordinator coordinator;
  late CoordinatorAgentExecutionDriver driver;
  late InMemoryWorkerStore workerStore;
  late GitWorktreeWorkspaceManager workspaceManager;
  late LocalWorker worker;
  late WorkerDispatcher dispatcher;

  /// Mirrors the coordinator's own fixture: a work item parked at
  /// designNotRequired with a QA contract, ready for execution.
  Future<void> workItemReady({String workItemId = 'wi-1'}) async {
    await workflowEngine.createWorkItem(
      workItemId: workItemId,
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Implement calculator add',
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
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );
  }

  WorkerExecutionRequest request({
    required String repositoryPath,
    required String startingRevision,
    Set<WorkerCapability> requiredCapabilities = const {WorkerCapability.linux},
    String workItemId = 'wi-1',
    String workerExecutionId = 'wx-1',
    int timeoutSeconds = 60,
    WorkerCleanupPolicy cleanupPolicy = WorkerCleanupPolicy.removeAlways,
    List<String>? envAllowlist,
    Map<String, String>? environment,
    String instruction = 'Implement add(2,3)==5 inside the worktree.',
  }) => WorkerExecutionRequest(
    workerExecutionId: workerExecutionId,
    workItemId: workItemId,
    repositoryPath: repositoryPath,
    startingRevision: startingRevision,
    requiredCapabilities: requiredCapabilities,
    role: AgentRole.implementer,
    instruction: instruction,
    timeoutSeconds: timeoutSeconds,
    runtimeTypeId: 'fake-runtime',
    cleanupPolicy: cleanupPolicy,
    envAllowlist: envAllowlist,
    environment: environment,
  );
}
