import 'dart:async';
import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/fake_agent.dart';
import 'support/fixture.dart';

/// A budget expiry is a TIMEOUT. A crash is not. Both assertions are here
/// because the failure mode they guard against is the same one in both
/// directions, and only one of them is obvious.
///
/// ## What this pins
///
/// `ExecutionCoordinator._expireExecution` used to settle as
/// [AgentSessionStatus.failed]. That one word decided the rest of the chain:
///
/// ```text
/// failed      -> executedFail -> JobFailureKind.permanent -> JobState.failed,
///                                                                  0 attempts
/// interrupted -> timedOut     -> JobFailureKind.transient  -> scheduleRetry,
///                                                                  1 attempt
/// ```
///
/// so `engineeringReviewDefinition.maxAttempts: 2` could never be spent on the
/// failure this deployment actually observes — a review killed at its budget.
/// The coordinator now settles a budget expiry as [AgentSessionStatus.interrupted].
///
/// The dangerous regression is the opposite one. "Make the timeout retry" must
/// not become "make everything retry", because a runtime that throws on every
/// start would then spend one attempt per start, forever, with no operator
/// signal that the runtime is broken rather than slow. That is why the CRASH
/// cases below are asserted at the same value as the fix rather than alongside
/// it: `failed` must stay `failed`, and the two are distinguished by which
/// call site writes them, not by a guard that could later be relaxed.
void main() {
  late Directory temp;
  late FixtureWorkspace fixture;
  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('coordinator_budget_');
    fixture = FixtureWorkspace(parent: temp.path);
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();
  });

  tearDown(() => fixture.dispose());

  ExecutionCoordinator coordinatorOf(FakeAgentSession session) {
    return ExecutionCoordinator(
      store: executionStore,
      workflowEngine: workflowEngine,
      runtime: AgentRuntime(
        registry: AgentAdapterRegistry()..register(FakeAgentAdapter(session)),
      ),
      verificationPlan: VerificationPlan(command: fixture.verifyCommand()),
    );
  }

  FakeAgentSession sessionOf({
    FakeBehavior behavior = FakeBehavior.complete,
    bool throwOnStart = false,
    Completer<void>? startGate,
  }) => FakeAgentSession(
    executionId: 'exec-1',
    workItemId: 'wi-1',
    behavior: behavior,
    sessionId: 'ses-fake-1',
    throwOnStart: throwOnStart,
    startGate: startGate,
  );

  Future<WorkItem> workItemReadyForExecution() async {
    await workflowEngine.createWorkItem(
      workItemId: 'wi-1',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Implement calculator add',
      description: 'Distinguishes a budget expiry from a crash',
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

  group('a budget expiry settles as a TIMEOUT', () {
    test('a session that never reaches a terminal event', () async {
      await workItemReadyForExecution();
      final coordinator = coordinatorOf(
        sessionOf(behavior: FakeBehavior.neverTerminate),
      );

      final execution = await coordinator.execute(request());

      expect(
        execution.status,
        AgentSessionStatus.interrupted,
        reason:
            'interrupted -> WorkerExecutionStatus.timedOut -> transient, so the '
            'job spends an attempt and retries inside maxAttempts. `failed` '
            'here is what made the review budget unretryable.',
      );
    });

    test('a start that never answers is a timeout too, not a crash', () async {
      await workItemReadyForExecution();
      final never = Completer<void>();
      final coordinator = coordinatorOf(sessionOf(startGate: never));

      final execution = await coordinator.execute(request(timeoutSeconds: 2));

      expect(
        execution.status,
        AgentSessionStatus.interrupted,
        reason:
            'the two timeout branches are kept together deliberately: a runtime '
            'that will not come up in time and a session that will not finish '
            'in time are the same operational fact.',
      );
      // Leave the drive path released rather than leaving a wedged future.
      never.complete();
    });

    test(
      'the durable row, not just the returned value, says interrupted',
      () async {
        await workItemReadyForExecution();
        final coordinator = coordinatorOf(
          sessionOf(behavior: FakeBehavior.neverTerminate),
        );

        await coordinator.execute(request());

        final persisted = await executionStore.readExecution('exec-1');
        expect(persisted.status, AgentSessionStatus.interrupted);
        expect(persisted.isTerminal, isTrue);
        expect(
          persisted.reason,
          contains('never emitted a terminal event'),
          reason:
              'the row has to say WHY it was interrupted, not merely that it was: '
              '"interrupted" with no reason is indistinguishable from a '
              'cancellation an operator issued.',
        );

        // The audit trail carries the same reason, so an operator reading the
        // event stream does not have to join back to the row to learn why.
        // Asserted over EVERY terminal event rather than the first, because
        // which of the two budget paths (_finalize's bounded wait, or
        // _expireExecution) wins is a race — and both must carry the reason.
        final events = await executionStore.readEvents('exec-1');
        final failures = events
            .where((e) => e.type == AgentEventType.executionFailed)
            .toList();
        expect(failures, isNotEmpty);
        expect(
          failures.any(
            (e) => '${e.payload?['reason'] ?? e.payload?['error']}'.contains(
              'execution budget',
            ),
          ),
          isTrue,
          reason:
              'the terminal event must say the budget was exceeded, not merely '
              'that something failed. Events: '
              '${failures.map((e) => e.payload).toList()}',
        );
      },
    );
  });

  group('a CRASH still settles as `failed`, so it never retries', () {
    test('a runtime that throws while starting a session', () async {
      await workItemReadyForExecution();
      final coordinator = coordinatorOf(sessionOf(throwOnStart: true));

      final execution = await coordinator.execute(request());

      expect(
        execution.status,
        AgentSessionStatus.failed,
        reason:
            'a runtime that crashes on every start is permanently broken, not '
            'slow. Settling it as `interrupted` would make it retry until '
            'maxAttempts runs out on every job forever.',
      );
      expect(execution.reason, contains('start failure'));

      final persisted = await executionStore.readExecution('exec-1');
      expect(persisted.status, AgentSessionStatus.failed);

      final item = await workflowEngine.loadWorkItem('wi-1');
      expect(item.state, WorkItemState.agentFailed);
    });

    test('an agent that emits SessionFailed mid-run', () async {
      await workItemReadyForExecution();
      final coordinator = coordinatorOf(sessionOf(behavior: FakeBehavior.fail));

      final execution = await coordinator.execute(request(timeoutSeconds: 60));

      expect(
        execution.status,
        AgentSessionStatus.failed,
        reason:
            'the runtime reported a terminal failure of its own accord. That is '
            'a crash, and it was already `failed` before this change — the '
            'assertion is here so a future edit to the timeout path cannot '
            'quietly sweep it into the retryable class.',
      );
      expect(execution.reason, isNot(contains('timeout')));
    });

    test('the two classes never share a terminal status', () async {
      // The contract as one assertion over both halves, so removing EITHER
      // test leaves the other asserting something real rather than nothing.
      await workItemReadyForExecution();
      final timedOut = await coordinatorOf(
        sessionOf(behavior: FakeBehavior.neverTerminate),
      ).execute(request());

      final crashStore = InMemoryExecutionStore();
      final crash = ExecutionCoordinator(
        store: crashStore,
        workflowEngine: workflowEngine,
        runtime: AgentRuntime(
          registry: AgentAdapterRegistry()
            ..register(FakeAgentAdapter(sessionOf(throwOnStart: true))),
        ),
        verificationPlan: VerificationPlan(command: fixture.verifyCommand()),
      );

      final crashed = await crash.execute(
        AgentExecutionRequest(
          executionId: 'exec-crash',
          workItemId: 'wi-1',
          role: AgentRole.implementer,
          runtimeTypeId: 'fake-runtime',
          workspace: AgentWorkspace(
            workspaceId: 'ws-2',
            path: fixture.root.path,
          ),
          instruction: 'implement the calculator add function',
          timeoutSeconds: 2,
          permittedScope: 'lib/ only',
        ),
      );

      expect(timedOut.status, AgentSessionStatus.interrupted);
      expect(crashed.status, AgentSessionStatus.failed);
      expect(timedOut.status, isNot(crashed.status));
    });
  });
}
