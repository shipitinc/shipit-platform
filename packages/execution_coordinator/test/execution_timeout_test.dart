import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/fake_agent.dart';
import 'support/fixture.dart';

/// `timeoutSeconds` is a budget for the whole dispatch path.
///
/// It used to travel no further than `AgentSessionConfig`, where an adapter may
/// apply it to a single ACP call. Nothing in the coordinator enforced it end to
/// end, so a session that stopped answering left its work item in
/// `agentExecuting` indefinitely - the shape of the production stall this
/// replaces. These tests pin the two seams that could wait forever: the wait
/// for a terminal event, and the instruction round trip that precedes it.
void main() {
  late Directory temp;
  late FixtureWorkspace fixture;
  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('coordinator_timeout_');
    fixture = FixtureWorkspace(parent: temp.path);
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();
  });

  tearDown(() => fixture.dispose());

  ExecutionCoordinator coordinatorOf(FakeBehavior behavior) {
    final session = FakeAgentSession(
      executionId: 'exec-1',
      workItemId: 'wi-1',
      behavior: behavior,
      sessionId: 'ses-fake-1',
    );
    return ExecutionCoordinator(
      store: executionStore,
      workflowEngine: workflowEngine,
      runtime: AgentRuntime(
        registry: AgentAdapterRegistry()..register(FakeAgentAdapter(session)),
      ),
      verificationPlan: VerificationPlan(command: fixture.verifyCommand()),
    );
  }

  Future<WorkItem> workItemReadyForExecution() async {
    await workflowEngine.createWorkItem(
      workItemId: 'wi-1',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Implement calculator add',
      description: 'Runnable calculator item exercising the execution budget',
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

  AgentExecutionRequest request({int timeoutSeconds = 2}) =>
      AgentExecutionRequest(
        executionId: 'exec-1',
        workItemId: 'wi-1',
        role: AgentRole.implementer,
        runtimeTypeId: 'fake-runtime',
        workspace: AgentWorkspace(workspaceId: 'ws-1', path: fixture.root.path),
        instruction: 'implement the calculator add function',
        timeoutSeconds: timeoutSeconds,
        permittedScope: 'lib/ only',
      );

  group('timeoutSeconds bounds the whole dispatch path', () {
    test('a session that never emits a terminal event is terminated at its '
        'budget, in a real terminal state, and the work item is not left '
        'running', () async {
      await workItemReadyForExecution();
      final coordinator = coordinatorOf(FakeBehavior.neverTerminate);

      final stopwatch = Stopwatch()..start();
      final execution = await coordinator.execute(request(timeoutSeconds: 2));
      stopwatch.stop();

      // A REAL terminal state, carrying an honest reason - not an abandoned
      // future and not a row left at `running`.
      expect(execution.status, AgentSessionStatus.failed);
      expect(execution.isTerminal, isTrue);
      expect(execution.completedAt, isNotNull);
      expect(execution.reason, contains('never emitted a terminal event'));
      expect(execution.reason, contains('2s'));

      // The work item left execution. This is the assertion the incident
      // turns on: the job must not be left in agentExecuting. `agentFailed`
      // is not a workflow-terminal state - it is the correction gate - so the
      // claim being pinned is that execution no longer holds the item.
      final item = await workflowEngine.loadWorkItem('wi-1');
      expect(item.state, WorkItemState.agentFailed);
      expect(item.state, isNot(WorkItemState.agentExecuting));

      // The failure is durable and attributable, not just in-memory.
      final persisted = await executionStore.readExecution('exec-1');
      expect(persisted.status, AgentSessionStatus.failed);
      expect(persisted.isTerminal, isTrue);

      final events = await executionStore.readEvents('exec-1');
      expect(
        events.where((e) => e.type == AgentEventType.executionFailed),
        isNotEmpty,
        reason: 'a timed-out execution must leave an executionFailed event',
      );

      // And it actually waited for the budget rather than failing instantly.
      expect(
        stopwatch.elapsed,
        greaterThanOrEqualTo(const Duration(seconds: 1)),
        reason:
            'the terminal wait must be bounded by the budget, not by '
            'some unrelated constant',
      );
    });

    test('an instruction round trip that never answers is still terminated at '
        'its budget rather than waiting forever', () async {
      await workItemReadyForExecution();
      final coordinator = coordinatorOf(FakeBehavior.hangOnInstruction);

      final execution = await coordinator.execute(request(timeoutSeconds: 2));

      expect(execution.status, AgentSessionStatus.failed);
      expect(execution.isTerminal, isTrue);
      expect(execution.reason, contains('timeout budget'));

      final item = await workflowEngine.loadWorkItem('wi-1');
      expect(item.state, WorkItemState.agentFailed);

      final persisted = await executionStore.readExecution('exec-1');
      expect(persisted.isTerminal, isTrue);
    });

    test('a session that completes inside its budget is unaffected: the budget '
        'bounds the work without shortening it', () async {
      await workItemReadyForExecution();
      final coordinator = coordinatorOf(FakeBehavior.complete);
      fixture.implement();

      final execution = await coordinator.execute(request(timeoutSeconds: 60));

      expect(execution.status, AgentSessionStatus.completed);
      expect(execution.reason, isNot(contains('timeout')));
      final item = await workflowEngine.loadWorkItem('wi-1');
      expect(item.state, WorkItemState.agentCompleted);
    });

    test(
      'the budget is passed to the runtime as configuration as well as being '
      'enforced here',
      () async {
        await workItemReadyForExecution();
        final coordinator = coordinatorOf(FakeBehavior.complete);
        fixture.implement();

        final execution = await coordinator.execute(
          request(timeoutSeconds: 60),
        );

        final durableRequest = await executionStore.readRequest('exec-1');
        expect(durableRequest!.timeoutSeconds, 60);
        expect(execution.status, AgentSessionStatus.completed);
      },
    );
  });
}
