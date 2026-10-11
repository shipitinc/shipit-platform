import 'dart:async';
import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/fake_agent.dart';
import 'support/fixture.dart';

/// `hasLiveSession` is the one question durable state cannot answer: a worker
/// execution row that is still `agentExecuting` is identical whether a process
/// is behind it or died an hour ago. It is what an `ExecutionLivenessProbe`
/// asks, so its contract has to be exact — in particular, `false` means "no
/// live session HERE", which is not the same as "provably dead".
void main() {
  late Directory temp;
  late FixtureWorkspace fixture;
  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('coordinator_liveness_');
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
      description: 'Item exercising live-session observation',
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

  AgentExecutionRequest request() => AgentExecutionRequest(
    executionId: 'exec-1',
    workItemId: 'wi-1',
    role: AgentRole.implementer,
    runtimeTypeId: 'fake-runtime',
    workspace: AgentWorkspace(workspaceId: 'ws-1', path: fixture.root.path),
    instruction: 'implement the calculator add function',
    timeoutSeconds: 60,
    permittedScope: 'lib/ only',
  );

  group('hasLiveSession observes without mutating', () {
    test(
      'an execution that is genuinely running reports a live session',
      () async {
        await workItemReadyForExecution();
        // This behaviour accepts the instruction, emits activity, and then never
        // emits a terminal event — so the session stays live and observable.
        final coordinator = coordinatorOf(FakeBehavior.cancelRequested);

        final running = coordinator.execute(request());
        // Let the drive path get past startSession and into the terminal wait.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          coordinator.hasLiveSession('exec-1'),
          isTrue,
          reason: 'a session this process is driving is live',
        );
        expect(coordinator.isBusy, isTrue);

        await coordinator.cancelExecution('exec-1', 'test teardown');
        await running;
      },
    );

    test('the session is no longer live once the execution settles', () async {
      await workItemReadyForExecution();
      final coordinator = coordinatorOf(FakeBehavior.complete);
      fixture.implement();

      final execution = await coordinator.execute(request());

      expect(execution.status, AgentSessionStatus.completed);
      expect(
        coordinator.hasLiveSession('exec-1'),
        isFalse,
        reason: 'the coordinator released its bookkeeping when it settled',
      );
      expect(coordinator.isBusy, isFalse);
    });

    test('an execution id this coordinator never saw is not live', () async {
      final coordinator = coordinatorOf(FakeBehavior.complete);

      expect(coordinator.hasLiveSession('never-dispatched'), isFalse);
      expect(coordinator.hasLiveSession(''), isFalse);
    });

    test(
      'observing is side-effect free: it cannot register a session or move the '
      'busy flag',
      () async {
        final coordinator = coordinatorOf(FakeBehavior.complete);

        // Repeated observation of an unknown id changes nothing observable.
        for (var i = 0; i < 5; i++) {
          expect(coordinator.hasLiveSession('never-dispatched'), isFalse);
        }
        expect(coordinator.isBusy, isFalse);
        // And it did not write an execution row into existence.
        expect(
          await executionStore.readExecutionOrNull('never-dispatched'),
          isNull,
        );
      },
    );
  });

  group('the observation a liveness probe depends on', () {
    test('a running execution is live, and after cancellation it is not — the '
        'transition a probe keys on', () async {
      await workItemReadyForExecution();
      final coordinator = coordinatorOf(FakeBehavior.cancelRequested);
      final running = coordinator.execute(request());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // The verdict a probe would report while the work is actually happening.
      expect(coordinator.hasLiveSession('exec-1') ? 'alive' : 'dead', 'alive');

      final settled = await coordinator.cancelExecution('exec-1', 'stop');
      await running;

      expect(settled.isTerminal, isTrue);
      expect(
        coordinator.hasLiveSession('exec-1'),
        isFalse,
        reason: 'once the session is gone the probe may report dead',
      );
    });

    test(
      'an execution killed by its budget leaves no live session, so the zombie '
      'this incident produced is observable as dead',
      () async {
        await workItemReadyForExecution();
        final coordinator = coordinatorOf(FakeBehavior.neverTerminate);

        final timedOut = await coordinator.execute(
          AgentExecutionRequest(
            executionId: 'exec-1',
            workItemId: 'wi-1',
            role: AgentRole.implementer,
            runtimeTypeId: 'fake-runtime',
            workspace: AgentWorkspace(
              workspaceId: 'ws-1',
              path: fixture.root.path,
            ),
            instruction: 'implement the calculator add function',
            timeoutSeconds: 2,
            permittedScope: 'lib/ only',
          ),
        );

        expect(timedOut.status, AgentSessionStatus.failed);
        expect(
          coordinator.hasLiveSession('exec-1'),
          isFalse,
          reason: 'a timed-out execution has nothing behind it',
        );
      },
    );
  });
}
