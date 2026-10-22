import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/fake_agent.dart';
import 'support/fixture.dart';

void main() {
  late Directory temp;
  late FixtureWorkspace fixture;
  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;
  late ExecutionCoordinator coordinator;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('eng_review_coord');
    fixture = FixtureWorkspace(parent: temp.path)..implement();
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();

    final session = FakeAgentSession(
      executionId: 'exec-impl',
      workItemId: 'wi-1',
    );
    final runtime = AgentRuntime(
      registry: AgentAdapterRegistry()..register(FakeAgentAdapter(session)),
    );
    coordinator = ExecutionCoordinator(
      store: executionStore,
      workflowEngine: workflowEngine,
      runtime: runtime,
      verificationPlan: VerificationPlan(command: fixture.verifyCommand()),
    );
  });

  tearDown(() {
    fixture.dispose();
    temp.deleteSync(recursive: true);
  });

  AgentExecutionRequest request({
    required String executionId,
    required AgentRole role,
  }) => AgentExecutionRequest(
    executionId: executionId,
    workItemId: 'wi-1',
    role: role,
    runtimeTypeId: 'fake-runtime',
    workspace: AgentWorkspace(workspaceId: 'ws-1', path: fixture.root.path),
    instruction: 'do the work',
    timeoutSeconds: 60,
    permittedScope: 'lib/ only',
  );

  /// A work item carrying a QA contract, walked to `designNotRequired` so the
  /// implementer edge `designNotRequired -> agentExecuting` is legal.
  Future<void> readyItem() async {
    await workflowEngine.createWorkItem(
      workItemId: 'wi-1',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Implement calculator add',
      description: 'Implement the calculator add function for the contract',
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
    await workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );
  }

  /// Runs the implementer to `agentCompleted`, which records the producing
  /// execution id on the work item (the producer identity M2 relies on).
  Future<void> runImplementer() => readyItem().then(
    (_) => coordinator.execute(
      request(executionId: 'exec-impl', role: AgentRole.implementer),
    ),
  );

  test(
    'implementer completion records producerActorId and reaches agentCompleted',
    () async {
      await runImplementer();

      final item = await workflowEngine.loadWorkItem('wi-1');
      expect(item.state, WorkItemState.agentCompleted);
      expect(item.metadata?['producerActorId'], 'exec-impl');
    },
  );

  test(
    'B2 regression: the reviewer entry moves agent_completed -> review_in_progress',
    () async {
      await runImplementer();
      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.agentCompleted,
      );

      await coordinator.execute(
        request(
          executionId: 'exec-review',
          role: AgentRole.engineeringReviewer,
        ),
      );

      final item = await workflowEngine.loadWorkItem('wi-1');
      expect(
        item.state,
        WorkItemState.reviewInProgress,
        reason:
            'the coordinator must supply the implementer AgentResult so '
            'agentResultValid() passes on agentCompleted -> reviewInProgress',
      );
    },
  );

  test('a DESIGN reviewer runs IN designInReview and is not moved to '
      'agentCompleted', () async {
    // The design approval is raised from `designInReview` (§5.3/§5.4 of the
    // design-governance-runtime design). If the coordinator treated the
    // design reviewer like an ordinary producing role it would take
    // `designInReview -> agentExecuting` and then `agentExecuting ->
    // agentCompleted`, which both loses the state the approval gate reads and
    // hands the item to the ENGINEERING review lane's entry state.
    await workflowStore.saveWorkItem(
      WorkItem(
        workItemId: 'wi-1',
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Design the calculator add screen',
        state: WorkItemState.designInReview,
        qaContractId: 'qa-1',
        createdAt: DateTime.utc(2026, 10, 22),
        updatedAt: DateTime.utc(2026, 10, 22),
      ),
    );

    await coordinator.execute(
      request(
        executionId: 'exec-design-review',
        role: AgentRole.designReviewer,
      ),
    );

    final item = await workflowEngine.loadWorkItem('wi-1');
    expect(
      item.state,
      WorkItemState.designInReview,
      reason:
          'reviewInProgress is the ENGINEERING reviewer\'s state; the design '
          'review happens while the item is designInReview',
    );
  });

  test('a reviewer terminal outcome performs NO workflow transition', () async {
    await runImplementer();
    await coordinator.execute(
      request(executionId: 'exec-review', role: AgentRole.engineeringReviewer),
    );

    final before = await workflowEngine.loadWorkItem('wi-1');
    expect(before.state, WorkItemState.reviewInProgress);

    // The reviewer already ran to completion inside `execute`; the item must
    // still be parked at the review gate. A non-reviewer completion moves to
    // agentCompleted (proved above), so reaching here unchanged is the
    // reviewer-specific behaviour.
    final after = await workflowEngine.loadWorkItem('wi-1');
    expect(after.state, WorkItemState.reviewInProgress);
    expect(after.version, before.version);
  });
}
