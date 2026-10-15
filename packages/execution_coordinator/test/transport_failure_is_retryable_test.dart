import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/fake_agent.dart';
import 'support/fixture.dart';

/// A start that fails because the WIRE went quiet is a TIMEOUT. A start that
/// fails because the runtime CRASHED is not.
///
/// ## Why this is a separate file from `budget_expiry_is_a_timeout_test.dart`
///
/// That file pins the budget expiring. This one pins the case that produced the
/// live incident in the first place: `OpenCodeSession.start` converts its own
/// `TimeoutException` into an `AcpTransportException`, so the `on TimeoutException`
/// branch in `_drive` was **unreachable for the adapter the coordinator actually
/// drives**. A review that could not get off the ground landed in the bare
/// `catch (e)` beside it and settled `failed` — permanent, zero attempts spent —
/// which is the same dead end as the 300-second budget, one layer in.
///
/// ## The classification is by WHAT WAS THROWN, not by how it reads
///
/// There are three call sites out of `runtime.startSession` and they are the
/// mechanism, exactly as `budget_expiry_is_a_timeout_test.dart` says about its
/// two. A reviewer should treat "there is a check inside `_settleWithoutSession`
/// that keeps a crash out" as false: there is none, and there must not be one —
/// a guard in the shared method would be exactly the place a later change
/// relaxes.
///
///  * `TimeoutException`                  -> interrupted (transient)
///  * `AcpTransportException`            -> interrupted (transient)
///  * anything else, incl. `StateError`  -> failed      (permanent)
///
/// A missing `opencode` binary is a `ProcessException`, not a transport
/// exception, and stays permanent: it fails identically on every attempt, so
/// retrying it would spend the retry budget on a certainty.
void main() {
  late Directory temp;
  late FixtureWorkspace fixture;
  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('coordinator_transport_');
    fixture = FixtureWorkspace(parent: temp.path);
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();
  });

  tearDown(() => fixture.dispose());

  ExecutionCoordinator coordinatorOf(FakeAgentSession session) =>
      ExecutionCoordinator(
        store: executionStore,
        workflowEngine: workflowEngine,
        runtime: AgentRuntime(
          registry: AgentAdapterRegistry()..register(FakeAgentAdapter(session)),
        ),
        verificationPlan: VerificationPlan(command: fixture.verifyCommand()),
      );

  Future<void> workItemReadyForExecution() async {
    await workflowEngine.createWorkItem(
      workItemId: 'wi-1',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Implement calculator add',
      description: 'Distinguishes a quiet wire from a crashed runtime',
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

  AgentExecutionRequest request({
    String executionId = 'exec-1',
    int timeoutSeconds = 2,
  }) => AgentExecutionRequest(
    executionId: executionId,
    workItemId: 'wi-1',
    role: AgentRole.implementer,
    runtimeTypeId: 'fake-runtime',
    workspace: AgentWorkspace(workspaceId: 'ws-1', path: fixture.root.path),
    instruction: 'implement the calculator add function',
    timeoutSeconds: timeoutSeconds,
    permittedScope: 'lib/ only',
  );

  group('a start that fails on the WIRE settles interrupted', () {
    test(
      'an AcpTransportException out of start is transient, not permanent',
      () async {
        await workItemReadyForExecution();
        final coordinator = coordinatorOf(
          FakeAgentSession(
            executionId: 'exec-1',
            workItemId: 'wi-1',
            throwTransportOnStart: true,
          ),
        );

        final execution = await coordinator.execute(request());

        expect(
          execution.status,
          AgentSessionStatus.interrupted,
          reason:
              'interrupted is what classifies as JobFailureKind.transient. '
              '`failed` here classified as permanent and spent zero attempts — '
              'the state two live review jobs died in.',
        );
        expect(
          execution.reason,
          contains('start transport failure'),
          reason: 'and the durable reason says what happened, in those words',
        );
      },
    );

    test('the work item still leaves execution, so it is not stranded', () async {
      await workItemReadyForExecution();
      final coordinator = coordinatorOf(
        FakeAgentSession(
          executionId: 'exec-1',
          workItemId: 'wi-1',
          throwTransportOnStart: true,
        ),
      );

      await coordinator.execute(request());

      final item = await workflowEngine.loadWorkItem('wi-1');
      expect(
        item.state,
        WorkItemState.agentFailed,
        reason:
            'retryable is not the same as ignored: the item still gets a '
            'terminal state and a history entry saying why. The live incident '
            'left two items at `review_in_progress` with no blocking decision.',
      );
    });
  });

  group('a start that CRASHES is still permanent', () {
    test('a plain exception out of start settles failed', () async {
      await workItemReadyForExecution();
      final coordinator = coordinatorOf(
        FakeAgentSession(
          executionId: 'exec-1',
          workItemId: 'wi-1',
          throwOnStart: true,
        ),
      );

      final execution = await coordinator.execute(request());

      expect(
        execution.status,
        AgentSessionStatus.failed,
        reason:
            'the control. A runtime that throws a StateError on every start is '
            'broken, not slow, and re-dispatching it on every item would spend '
            'the retry budget on a certainty.',
      );
      expect(execution.reason, contains('start failure'));
      expect(
        execution.reason,
        isNot(contains('transport')),
        reason: 'the two must not be reported in the same words',
      );
    });

    test('the two start failures are different statuses, not the same one '
        'twice', () async {
      // A DISTINCT execution id for the second run. `execute` is single-shot
      // and returns the existing record for a terminal id, so reusing `exec-1`
      // here would assert that a cached verdict equals itself — the kind of
      // test that passes because it measured nothing.
      await workItemReadyForExecution();
      final quiet = await coordinatorOf(
        FakeAgentSession(
          executionId: 'exec-1',
          workItemId: 'wi-1',
          throwTransportOnStart: true,
        ),
      ).execute(request());
      final quietStatus = quiet.status;

      final crashed = await coordinatorOf(
        FakeAgentSession(
          executionId: 'exec-2',
          workItemId: 'wi-1',
          throwOnStart: true,
        ),
      ).execute(request(executionId: 'exec-2'));

      expect(quietStatus, AgentSessionStatus.interrupted);
      expect(crashed.status, AgentSessionStatus.failed);
      expect(quietStatus, isNot(crashed.status));
    });
  });

  group('a transport failure DURING the run settles interrupted too', () {
    test('the adapter\'s SessionInterrupted reaches the durable record', () async {
      // This is the path production took: `OpenCodeSession` emits
      // SessionInterrupted when the wire goes quiet, and `_failureDetails` maps
      // it to `interrupted`. Asserted here so the two halves of the change are
      // proven to meet.
      await workItemReadyForExecution();
      final coordinator = coordinatorOf(
        FakeAgentSession(
          executionId: 'exec-1',
          workItemId: 'wi-1',
          behavior: FakeBehavior.interrupt,
        ),
      );

      final execution = await coordinator.execute(request());

      expect(execution.status, AgentSessionStatus.interrupted);
      expect(
        execution.reason,
        contains('instruction timeout'),
        reason: 'the reason the adapter wrote is carried through verbatim',
      );
    });
  });
}
