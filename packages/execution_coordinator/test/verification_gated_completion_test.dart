import 'dart:async';
import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/fake_agent.dart';
import 'support/fixture.dart';

/// The platform's independent verdict is the completion transition.
///
/// `_completeSuccess` ran the verification, persisted the outcome, and then
/// advanced the work item to `agentCompleted` whatever that outcome was. The
/// consequence was a work item the platform had just refuted sitting in a state
/// that asserts success: production stranded 10 of them at `agent_completed`
/// with `executedFail` executions and failed jobs behind them, and nothing
/// re-derived the failure from the verification row.
///
/// A verification that FAILED now settles the item at `agentFailed` — the state
/// the operator affordance already accepts. These tests pin that gate and, just
/// as importantly, the three cases that must NOT be swept into it: a passing
/// check, no check at all, and the engineering reviewer (which must not leave
/// the review gate for any verification outcome).
void main() {
  late Directory temp;
  late FixtureWorkspace fixture;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;
  var _sessions = 0;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('verification_gate_');
    fixture = FixtureWorkspace(parent: temp.path);
    workflowEngine = DurableWorkflowEngine(store: InMemoryWorkflowStore());
    executionStore = InMemoryExecutionStore();
  });

  tearDown(() {
    fixture.dispose();
    temp.deleteSync(recursive: true);
  });

  /// A coordinator over a FRESH session.
  ///
  /// One session per coordinator, not one per test: the coordinator closes the
  /// session when it finalizes (`_finalize` calls `session.close()`, and
  /// `FakeAgentSession.close()` closes its broadcast controller), so a second
  /// `execute` through the same session throws inside `start()` and never
  /// reaches `_completeSuccess` — which would let any assertion about that
  /// method pass without it ever running. The stores are shared, so the
  /// reviewer entry still finds the implementer's execution and result.
  ExecutionCoordinator coordinatorOf({
    bool withPlan = true,
    String executionId = 'exec-1',
  }) {
    final session = FakeAgentSession(
      executionId: executionId,
      workItemId: 'wi-1',
      sessionId: 'ses-fake-${++_sessions}',
    );
    return ExecutionCoordinator(
      store: executionStore,
      workflowEngine: workflowEngine,
      runtime: AgentRuntime(
        registry: AgentAdapterRegistry()..register(FakeAgentAdapter(session)),
      ),
      // The REAL verifier, not a stub: the defect is specifically about a
      // check that genuinely ran in the workspace and genuinely disagreed
      // with the agent. A stubbed verdict would not reproduce it.
      verificationPlan: withPlan
          ? VerificationPlan(command: fixture.verifyCommand())
          : null,
    );
  }

  /// A work item parked at [WorkItemState.designNotRequired] with a QA contract
  /// attached, so the implementer edge `-> agentExecuting` is legal.
  Future<WorkItem> readyItem() async {
    await workflowEngine.createWorkItem(
      workItemId: 'wi-1',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Implement calculator add',
      description:
          'Item exercising the verification-gated completion transition',
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

  AgentExecutionRequest request({
    String executionId = 'exec-1',
    AgentRole role = AgentRole.implementer,
    int timeoutSeconds = 60,
  }) => AgentExecutionRequest(
    executionId: executionId,
    workItemId: 'wi-1',
    role: role,
    runtimeTypeId: 'fake-runtime',
    workspace: AgentWorkspace(workspaceId: 'ws-1', path: fixture.root.path),
    instruction: 'implement the calculator add function',
    timeoutSeconds: timeoutSeconds,
    permittedScope: 'lib/ only',
  );

  Future<void> _settle() =>
      Future<void>.delayed(const Duration(milliseconds: 100));

  group('a verification that ran and failed gates the completion', () {
    test('the work item settles at agentFailed, not agentCompleted', () async {
      await readyItem();
      final coordinator = coordinatorOf();
      // The agent reports success; the workspace was never implemented, so the
      // platform's independent check contradicts it.
      await coordinator.execute(request());

      final verifications = await executionStore.readVerifications('exec-1');
      expect(
        verifications.single.status,
        AgentClaimStatus.failed,
        reason: 'precondition: the check ran and refuted the claim',
      );

      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.agentFailed,
        reason:
            'a refuted result must not be recorded as a completed work item',
      );
    });

    test(
      'agentCompleted is never entered, in the history or the metadata',
      () async {
        await readyItem();
        final coordinator = coordinatorOf();
        await coordinator.execute(request());

        final history = await workflowEngine.transitionHistory('wi-1');
        expect(
          history.map((t) => t.toState),
          contains(WorkItemState.agentFailed),
        );
        expect(
          history.map((t) => t.toState),
          isNot(contains(WorkItemState.agentCompleted)),
          reason:
              'the defect was precisely the agentCompleted transition firing',
        );

        // `producerActorId` names the execution whose result the engineering
        // review gate's `actorIsNotSelf()` guard is checked against. A refuted
        // result is not a producer.
        expect(
          (await workflowEngine.loadWorkItem(
            'wi-1',
          )).metadata?['producerActorId'],
          isNull,
        );
      },
    );

    test('the agent-level outcome is unchanged by the gate', () async {
      await readyItem();
      final coordinator = coordinatorOf();

      final execution = await coordinator.execute(request());

      // The MODEL run did complete; only its independent verification failed.
      // The returned completion describes the agent session, and is
      // deliberately NOT rewritten by this change — downstream already derives
      // job failure from the persisted verification row.
      expect(execution.status, AgentSessionStatus.completed);
      expect(
        (await executionStore.readResult('exec-1'))!.status,
        AgentResultStatus.completed,
      );
    });

    test('the failure reason from the verification reaches the item', () async {
      await readyItem();
      final coordinator = coordinatorOf();
      await coordinator.execute(request());

      final history = await workflowEngine.transitionHistory('wi-1');
      final settled = history.lastWhere(
        (t) => t.toState == WorkItemState.agentFailed,
      );
      final detail = (await executionStore.readVerifications(
        'exec-1',
      )).single.detail;
      expect(
        settled.reason,
        detail,
        reason:
            'the reason is PERSISTED on the transition record, so the item is '
            'never left failed with nothing in its history saying why',
      );
      expect(settled.outcome, TransitionOutcome.accepted);
    });
  });

  group('a verification that ran and passed is unchanged', () {
    test('the work item still reaches agentCompleted', () async {
      await readyItem();
      final coordinator = coordinatorOf();
      fixture.implement();

      await coordinator.execute(request());

      expect(
        (await executionStore.readVerifications('exec-1')).single.status,
        AgentClaimStatus.passed,
      );
      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.agentCompleted,
      );
    });

    test('producerActorId is still merged onto the success path', () async {
      await readyItem();
      final coordinator = coordinatorOf();
      fixture.implement();

      await coordinator.execute(request());

      final item = await workflowEngine.loadWorkItem('wi-1');
      expect(item.state, WorkItemState.agentCompleted);
      expect(
        item.metadata?['producerActorId'],
        'exec-1',
        reason:
            'the engineering-review gate compares the reviewer execution id '
            'against this; losing it makes actorIsNotSelf() unfailable',
      );
      // The additive merge must not drop the rest of the metadata.
      expect(item.qaContractId, 'qa-1');
    });
  });

  group('no verification plan is not a failure', () {
    test('the work item still reaches agentCompleted', () async {
      await readyItem();
      final coordinator = coordinatorOf(withPlan: false);
      // Deliberately NOT implemented: nothing checks it, and a check that never
      // ran has no verdict to enforce.
      await coordinator.execute(request());

      expect(
        await executionStore.readVerifications('exec-1'),
        isEmpty,
        reason: 'precondition: no check ran at all',
      );
      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.agentCompleted,
      );
    });
  });

  group('the engineering reviewer is untouched by the gate', () {
    test(
      'a FAILED reviewer verification still does not leave reviewInProgress',
      () async {
        await readyItem();
        final coordinator = coordinatorOf();
        fixture.implement();
        await coordinator.execute(request());
        expect(
          (await workflowEngine.loadWorkItem('wi-1')).state,
          WorkItemState.agentCompleted,
        );

        // The reviewer's own check now fails — the exact condition the gate
        // branches on, reached with the reviewer role. A fresh coordinator is
        // required: the implementer's session was closed when it finalized.
        fixture.makeVerifyImpossible();
        await coordinatorOf(executionId: 'exec-review').execute(
          request(
            executionId: 'exec-review',
            role: AgentRole.engineeringReviewer,
          ),
        );

        final after = await workflowEngine.loadWorkItem('wi-1');
        expect(
          after.state,
          WorkItemState.reviewInProgress,
          reason:
              'the reviewer branch precedes the verification gate: the tick '
              'handler raises a human decision, not a transition',
        );
        expect(
          (await executionStore.readVerifications('exec-review')).single.status,
          AgentClaimStatus.failed,
          reason:
              'precondition: the gate condition was true, so this proves the '
              'reviewer branch won rather than the test passing vacuously',
        );
      },
    );
  });

  group('the alreadySettled short-circuit is preserved', () {
    test(
      'a completion arriving after another writer settled the row still lands '
      'on the success path',
      () async {
        await readyItem();

        // A session that never terminates on its own, so the completion below
        // arrives AFTER the durable row was settled elsewhere — the exact shape
        // `alreadySettled` guards.
        final wedged = FakeAgentSession(
          executionId: 'exec-1',
          workItemId: 'wi-1',
          behavior: FakeBehavior.neverTerminate,
          sessionId: 'ses-wedged',
        );
        final coordinator = ExecutionCoordinator(
          store: executionStore,
          workflowEngine: workflowEngine,
          runtime: AgentRuntime(
            registry: AgentAdapterRegistry()
              ..register(FakeAgentAdapter(wedged)),
          ),
          verificationPlan: VerificationPlan(command: fixture.verifyCommand()),
        );

        final pending = coordinator.execute(request(timeoutSeconds: 60));
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final open = await executionStore.readExecution('exec-1');
        await executionStore.saveExecution(
          open.copyWith(
            status: AgentSessionStatus.orphaned,
            reason: 'decided elsewhere',
            completedAt: DateTime.now(),
            version: open.version + 1,
          ),
          expectedVersion: open.version,
        );

        wedged.emitLateCompletion();
        await pending;
        await _settle();

        // Verification was skipped, so there is no verdict — and no verdict
        // must not be manufactured into one.
        expect(await executionStore.readVerifications('exec-1'), isEmpty);
        expect(
          (await workflowEngine.loadWorkItem('wi-1')).state,
          WorkItemState.agentCompleted,
          reason: 'the skip is unchanged: only a verdict that exists can gate',
        );
      },
    );
  });
}
