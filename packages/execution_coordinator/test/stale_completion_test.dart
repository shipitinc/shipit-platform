import 'dart:async';
import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/fake_agent.dart';
import 'support/fixture.dart';

/// A completion that arrives after its work item has moved on is ordinary
/// staleness. Live QA caught it reported as a hard execution failure carrying
/// the workflow engine's raw "transition rejected ... is not allowed" text —
/// which reads as a platform fault in the state machine, when the state machine
/// in fact behaved correctly.
///
/// Every session here is driven with a FRESH [FakeAgentSession] per execution:
/// `FakeAgentSession.close()` closes its broadcast controller, so a second
/// `start()` on the same instance throws and the run dies in session setup
/// before any terminal event — which is how `engineering_reviewer_test.dart`
/// comes to assert on a reviewer path that never executes.
void main() {
  late Directory temp;
  late FixtureWorkspace fixture;
  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('stale_completion_test');
    fixture = FixtureWorkspace(parent: temp.path)..implement();
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();
  });

  tearDown(() {
    fixture.dispose();
    temp.deleteSync(recursive: true);
  });

  ExecutionCoordinator coordinatorOver(FakeAgentSession session) =>
      ExecutionCoordinator(
        store: executionStore,
        workflowEngine: workflowEngine,
        runtime: AgentRuntime(
          registry: AgentAdapterRegistry()..register(FakeAgentAdapter(session)),
        ),
        verificationPlan: VerificationPlan(command: fixture.verifyCommand()),
      );

  AgentExecutionRequest request(String executionId, AgentRole role) =>
      AgentExecutionRequest(
        executionId: executionId,
        workItemId: 'wi-1',
        role: role,
        runtimeTypeId: 'fake-runtime',
        workspace: AgentWorkspace(workspaceId: 'ws-1', path: fixture.root.path),
        instruction: 'do the work',
        timeoutSeconds: 60,
        permittedScope: 'lib/ only',
      );

  /// A work item parked at `designNotRequired`: the state live QA found the
  /// stale reviewer looking at.
  Future<void> itemAtDesignNotRequired() async {
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

  test('a stale reviewer dispatch is reported as supersession, NOT as the '
      "engine's raw 'transition rejected' text", () async {
    await itemAtDesignNotRequired();
    final coordinator = coordinatorOver(
      FakeAgentSession(executionId: 'exec-review', workItemId: 'wi-1'),
    );

    // Exactly the production failure: the item is at designNotRequired and no
    // longer accepts a reviewer run, which requires reviewInProgress.
    Object? thrown;
    try {
      await coordinator.execute(
        request('exec-review', AgentRole.engineeringReviewer),
      );
    } catch (e) {
      thrown = e;
    }

    expect(
      thrown,
      isA<WorkItemSupersededException>(),
      reason:
          'staleness must be its own classification, not a raw engine '
          'rejection surfacing as a permanent execution failure',
    );

    final supersession = thrown! as WorkItemSupersededException;
    expect(supersession.workItemId, 'wi-1');
    expect(supersession.observedState, WorkItemState.designNotRequired);
    expect(supersession.requiredState, WorkItemState.reviewInProgress);
    expect(supersession.role, AgentRole.engineeringReviewer);

    final message = supersession.toString();
    expect(
      message,
      isNot(contains('Workflow transition rejected')),
      reason:
          'this exact string is what made staleness look like a platform '
          'fault in live QA',
    );
    expect(message, contains('design_not_required'));
    expect(message, contains('review_in_progress'));
    expect(message, contains('nothing was produced'));
  });

  test(
    'the state machine still refuses the stale transition: supersession is a '
    'classification, not a relaxation',
    () async {
      await itemAtDesignNotRequired();

      await expectLater(
        workflowEngine.transition(
          workItemId: 'wi-1',
          to: WorkItemState.reviewInProgress,
          trigger: TransitionTrigger.systemEvent,
        ),
        throwsA(isA<WorkflowTransitionRejectedException>()),
      );

      // And the item did not move.
      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.designNotRequired,
      );
    },
  );

  test(
    'the message carries the machine-readable MARKER the scheduler acts on',
    () async {
      const superseded = WorkItemSupersededException(
        workItemId: 'wi-1',
        observedState: WorkItemState.designNotRequired,
        requiredState: WorkItemState.reviewInProgress,
        role: AgentRole.engineeringReviewer,
      );

      // The exception never reaches the scheduler as a TYPE. `WorkerDispatch`
      // catches it as a plain `Object`, the worker flattens `toString()` into
      // `WorkerExecutionResult.failureDetail`, and the only positively
      // identifying signal left is this prefix. If it moves, supersession
      // detection silently reverts to a terminal `failed` and nothing raises.
      //
      // So this pins the PRODUCER half of a contract whose CONSUMER half is
      // pinned by `supersession_requeue_test.dart` in packages/scheduler.
      // Either side changing alone breaks a test rather than the behaviour.
      expect(
        WorkItemSupersededException.marker,
        'work_item_superseded:',
        reason: 'this literal is a wire contract, not a message',
      );
      expect(
        superseded.toString(),
        startsWith(WorkItemSupersededException.marker),
      );
      expect(
        superseded.toString(),
        contains('Superseded execution'),
        reason:
            'the marker is a prefix, not a replacement — the prose is still '
            'what a human reads',
      );
    },
  );

  test(
    'a superseded dispatch writes no execution row and starts no session',
    () async {
      await itemAtDesignNotRequired();
      final session = FakeAgentSession(
        executionId: 'exec-review',
        workItemId: 'wi-1',
      );
      final coordinator = coordinatorOver(session);

      await expectLater(
        coordinator.execute(
          request('exec-review', AgentRole.engineeringReviewer),
        ),
        throwsA(isA<WorkItemSupersededException>()),
      );

      // Nothing ran, so there is nothing to strand and nothing to discard.
      expect(await executionStore.readExecutionOrNull('exec-review'), isNull);
      expect(await executionStore.readEvents('exec-review'), isEmpty);
      expect(session.status, AgentSessionStatus.starting);
      expect(coordinator.liveSessionCount, 0);
    },
  );

  test(
    'the refused transition is still durably audited, so supersession loses no '
    'evidence about WHY the item was not there',
    () async {
      await itemAtDesignNotRequired();

      await expectLater(
        workflowEngine.transition(
          workItemId: 'wi-1',
          to: WorkItemState.reviewInProgress,
          trigger: TransitionTrigger.systemEvent,
        ),
        throwsA(isA<WorkflowTransitionRejectedException>()),
      );

      final history = await workflowStore.readTransitionHistory('wi-1');
      expect(
        history.any(
          (t) =>
              t.toState == WorkItemState.reviewInProgress &&
              t.outcome.name != 'accepted',
        ),
        isTrue,
        reason:
            'the engine appends the rejected attempt; supersession must not '
            'be the thing that makes it disappear',
      );
    },
  );

  test(
    'a completion that lands AFTER the item moved on is classified as staleness, '
    'and its real result is still persisted and readable',
    () async {
      await itemAtDesignNotRequired();

      final gate = Completer<void>();
      final session = FakeAgentSession(
        executionId: 'exec-impl',
        workItemId: 'wi-1',
        instructionGate: gate,
      );
      final coordinator = coordinatorOver(session);

      final run = coordinator.execute(
        request('exec-impl', AgentRole.implementer),
      );

      // The coordinator has moved the item into execution and parked the agent.
      await _awaitState(
        () => workflowEngine.loadWorkItem('wi-1'),
        WorkItemState.agentExecuting,
      );

      // ...and NOW the item moves on, underneath a session that is still live.
      await workflowEngine.transition(
        workItemId: 'wi-1',
        to: WorkItemState.agentFailed,
        trigger: TransitionTrigger.systemEvent,
      );

      gate.complete();
      // The finalize path still reports the refusal to its caller; what changed
      // is how it is recorded, not whether the policy is enforced.
      await expectLater(
        run,
        throwsA(isA<WorkflowTransitionRejectedException>()),
      );

      final events = await executionStore.readEvents('exec-impl');
      final stale = events.firstWhere(
        (e) => e.payload?['kind'] == 'staleCompletion',
        orElse: () => throw StateError('no staleCompletion event was recorded'),
      );
      expect(
        stale.payload?['error'],
        contains('Workflow transition rejected'),
        reason:
            'the raw engine detail is kept for audit — classification adds '
            'to the record, it never deletes from it',
      );

      // The execution row names the condition in readable prose rather than
      // reporting a coordinator fault.
      final record = await executionStore.readExecution('exec-impl');
      expect(record.status, AgentSessionStatus.failed);
      expect(record.reason, contains('late completion could not be applied'));
      expect(record.reason, isNot(contains('coordinator finalize error')));

      // THE POINT: a real result exists and is still inspectable. Nothing is
      // discarded to make the classification tidy.
      final result = await executionStore.readResult('exec-impl');
      expect(result, isNotNull);
      expect(result!.status, AgentResultStatus.completed);
      expect(result.executionId, 'exec-impl');
      expect(await executionStore.readVerifications('exec-impl'), hasLength(1));

      // And the item was never dragged backwards by the stale outcome.
      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.agentFailed,
      );
    },
  );
}

/// Polls the item until it reaches [target], so the test observes the coordinator
/// mid-dispatch without depending on a timer.
Future<void> _awaitState(
  Future<WorkItem> Function() read,
  WorkItemState target,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    if ((await read()).state == target) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError('work item never reached $target');
}
