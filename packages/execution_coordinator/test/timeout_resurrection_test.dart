import 'dart:async';
import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/fake_agent.dart';
import 'support/fixture.dart';
import 'support/recording_execution_store.dart';

/// A drive path that RESUMES after its budget expired must not rewrite the
/// terminal `failed` row back to a non-terminal one.
///
/// This is the defect that let the fix re-create the incident through itself.
/// At expiry the row goes terminal; a `startSession` or `sendInstruction` wedge
/// that later unblocks walks straight past that and writes `running` again.
/// Worse, it re-registers the session in `_liveSessions` after
/// `_releaseExecution` removed it, so `hasLiveSession` then answers "alive" for
/// an execution with nothing behind it — and the production probe trusts that.
/// The zombie class became reproducible through its own fix.
///
/// These assert on the WRITE SEQUENCE, not the final row. Reading only the
/// final row hides the defect: the late `running` write is immediately followed
/// by the finalize handler writing `failed` again, so the last state looks
/// correct while the row spent real time non-terminal.
void main() {
  late Directory temp;
  late FixtureWorkspace fixture;
  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late RecordingExecutionStore executionStore;
  late FakeAgentSession session;
  late RecordingVerifier verifier;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('coordinator_resurrect_');
    fixture = FixtureWorkspace(parent: temp.path);
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    executionStore = RecordingExecutionStore();
    verifier = RecordingVerifier();
  });

  tearDown(() => fixture.dispose());

  ExecutionCoordinator coordinatorOf({
    Completer<void>? startGate,
    Completer<void>? instructionGate,
    FakeBehavior behavior = FakeBehavior.cancelRequested,
  }) {
    session = FakeAgentSession(
      executionId: 'exec-1',
      workItemId: 'wi-1',
      behavior: behavior,
      sessionId: 'ses-fake-1',
      startGate: startGate,
      instructionGate: instructionGate,
    );
    return ExecutionCoordinator(
      store: executionStore,
      workflowEngine: workflowEngine,
      runtime: AgentRuntime(
        registry: AgentAdapterRegistry()..register(FakeAgentAdapter(session)),
      ),
      verificationPlan: VerificationPlan(command: fixture.verifyCommand()),
      verifier: verifier,
    );
  }

  Future<WorkItem> workItemReadyForExecution() async {
    await workflowEngine.createWorkItem(
      workItemId: 'wi-1',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Implement calculator add',
      description: 'Item exercising the post-timeout resurrection guard',
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

  /// The honest terminal row the timeout produced, before the late drive path
  /// gets a chance to touch it.
  ///
  /// `interrupted`, not `failed`: every shape exercised here ends at the budget,
  /// and `interrupted` is what classifies as TRANSIENT downstream so the job
  /// spends an attempt and retries inside `maxAttempts`. These tests are about
  /// the verdict SURVIVING a late writer, not about which terminal class it
  /// belongs to — `budget_expiry_is_a_timeout_test.dart` owns that question.
  Future<void> expectTerminalAtExpiry() async {
    final before = await executionStore.readExecution('exec-1');
    expect(before.status, AgentSessionStatus.interrupted);
    expect(before.isTerminal, isTrue);
    expect(before.completedAt, isNotNull);
  }

  group('a drive path wedged in startSession cannot resurrect the row', () {
    test(
      'no write after the terminal verdict returns the row to non-terminal',
      () async {
        await workItemReadyForExecution();
        final gate = Completer<void>();
        final coordinator = coordinatorOf(startGate: gate);

        // The budget expires while the session has not even started.
        final timedOut = await coordinator.execute(request());
        expect(timedOut.status, AgentSessionStatus.interrupted);
        await expectTerminalAtExpiry();
        expect(coordinator.liveSessionCount, 0);

        // NOW the wedge releases and the drive path resumes.
        gate.complete();
        await _settle();

        expect(
          executionStore.resurrections,
          isEmpty,
          reason:
              'the timeout verdict must stand. Write sequence:\n'
              '${executionStore.writes.join('\n')}',
        );
        final after = await executionStore.readExecution('exec-1');
        expect(after.isTerminal, isTrue);
        expect(after.status, AgentSessionStatus.interrupted);
      },
    );

    test('the probe cannot see a live session for an execution that is already '
        'dead', () async {
      await workItemReadyForExecution();
      final gate = Completer<void>();
      final coordinator = coordinatorOf(startGate: gate);

      await coordinator.execute(request());
      expect(coordinator.hasLiveSession('exec-1'), isFalse);

      gate.complete();
      await _settle();

      // This is what made the 4.78h class reproducible: a resurrected
      // `_liveSessions` entry makes the production probe report `alive`.
      expect(
        coordinator.hasLiveSession('exec-1'),
        isFalse,
        reason: 'a resumed drive path must not re-register a released session',
      );
    });

    test(
      '_liveSessions does not grow across a timeout + late resume',
      () async {
        await workItemReadyForExecution();
        final gate = Completer<void>();
        final coordinator = coordinatorOf(startGate: gate);

        expect(coordinator.liveSessionCount, 0);
        await coordinator.execute(request());
        expect(coordinator.liveSessionCount, 0, reason: 'released at expiry');

        gate.complete();
        await _settle();

        expect(
          coordinator.liveSessionCount,
          0,
          reason: 'the late drive path leaked a session entry nothing removes',
        );
        expect(coordinator.isBusy, isFalse);
      },
    );

    test('a startSession wedge that releases into a permanently hanging '
        'instruction leaks neither the session nor the subscription', () async {
      // The shape that does not clean up after itself: the session registers,
      // the row is resurrected, and then `sendInstruction` never returns, so
      // `_finalize` is never reached and nothing ever calls `_releaseExecution`
      // again. The resurrected `_liveSessions` entry is what makes the
      // production probe report a dead execution as alive, and the staleness
      // bound never consults liveness for an execution it believes is alive.
      await workItemReadyForExecution();
      final gate = Completer<void>();
      final coordinator = coordinatorOf(
        startGate: gate,
        behavior: FakeBehavior.hangOnInstruction,
      );

      await coordinator.execute(request());
      expect(coordinator.liveSessionCount, 0);

      gate.complete();
      await _settle();

      expect(
        coordinator.liveSessionCount,
        0,
        reason:
            'nothing is driving this execution any more, so nothing would '
            'ever remove a session entry registered after release',
      );
      expect(coordinator.hasLiveSession('exec-1'), isFalse);
      expect(coordinator.isBusy, isFalse);
      expect(executionStore.resurrections, isEmpty);
      final after = await executionStore.readExecution('exec-1');
      expect(after.isTerminal, isTrue);
      expect(after.status, AgentSessionStatus.interrupted);
    });
  });

  group('a drive path wedged in sendInstruction cannot resurrect the row', () {
    test(
      'no write after the terminal verdict returns the row to non-terminal',
      () async {
        await workItemReadyForExecution();
        final gate = Completer<void>();
        final coordinator = coordinatorOf(instructionGate: gate);

        final timedOut = await coordinator.execute(request());
        expect(timedOut.status, AgentSessionStatus.interrupted);
        await expectTerminalAtExpiry();

        gate.complete();
        await _settle();

        expect(
          executionStore.resurrections,
          isEmpty,
          reason:
              'the timeout verdict must stand. Write sequence:\n'
              '${executionStore.writes.join('\n')}',
        );
        final after = await executionStore.readExecution('exec-1');
        expect(after.isTerminal, isTrue);
        expect(after.status, AgentSessionStatus.interrupted);
        expect(coordinator.hasLiveSession('exec-1'), isFalse);
        expect(coordinator.liveSessionCount, 0);
      },
    );
  });

  group('verification never runs for an execution already declared failed', () {
    test('a completion arriving after the verdict was decided by another writer '
        'does not shell out to verify the workspace', () async {
      await workItemReadyForExecution();
      final coordinator = coordinatorOf(behavior: FakeBehavior.neverTerminate);

      // A generous budget, so `_finalize` is genuinely blocked on the terminal
      // event when the verdict arrives.
      final pending = coordinator.execute(request(timeoutSeconds: 60));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Another writer decides this execution is over — a reconciler, a second
      // coordinator, or the worker layer. This is the case the guard exists
      // for: the coordinator is still waiting for a terminal event, so the
      // verdict is NOT coming from its own timeout.
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

      // The agent then finishes. Verification would spawn a real process in the
      // workspace to produce evidence for an execution that is already dead —
      // and the write that would carry that evidence is refused anyway.
      session.emitLateCompletion();
      await pending;
      await _settle();

      expect(
        verifier.calls,
        0,
        reason:
            'verification runs BEFORE the workflow transition, so an '
            'already-decided execution would shell out for nothing',
      );
      final after = await executionStore.readExecution('exec-1');
      expect(after.isTerminal, isTrue);
      expect(
        after.status,
        AgentSessionStatus.orphaned,
        reason: 'the verdict that already won must survive a late completion',
      );
      expect(executionStore.resurrections, isEmpty);
    });
  });

  group('the guard does not discard valid work', () {
    test(
      'a LATE success on an execution that was NOT timed out still lands',
      () async {
        await workItemReadyForExecution();
        final coordinator = coordinatorOf(
          behavior: FakeBehavior.neverTerminate,
        );

        // Generous budget, so the execution is never declared failed and the
        // guard must NOT interfere: the terminal event arrives after the
        // instruction round trip, and the result is real work.
        final pending = coordinator.execute(request(timeoutSeconds: 60));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        session.emitLateCompletion();

        final execution = await pending;

        expect(execution.status, AgentSessionStatus.completed);
        expect(execution.isTerminal, isTrue);
        expect(
          verifier.calls,
          1,
          reason:
              'a result that arrives while the execution is still live IS '
              'verified - the guard must not discard it',
        );
        final item = await workflowEngine.loadWorkItem('wi-1');
        expect(item.state, WorkItemState.agentCompleted);
        expect(executionStore.resurrections, isEmpty);
      },
    );

    test(
      'an execution that completes inside its budget is unaffected',
      () async {
        await workItemReadyForExecution();
        final coordinator = coordinatorOf(behavior: FakeBehavior.complete);
        fixture.implement();

        final execution = await coordinator.execute(
          request(timeoutSeconds: 60),
        );

        expect(execution.status, AgentSessionStatus.completed);
        expect(execution.reason, isNot(contains('timeout')));
        expect(verifier.calls, 1);
        expect(coordinator.liveSessionCount, 0);
        expect(executionStore.resurrections, isEmpty);
      },
    );
  });
}

/// Let every pending microtask and timer callback in the resumed drive path
/// run to completion, so a late write would have landed by now.
Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

/// Counts verifications without spawning anything. The real verifier shells out
/// to a process in the workspace, which is exactly what must not happen here.
class RecordingVerifier extends WorkspaceVerifier {
  int calls = 0;

  @override
  Future<VerificationOutcome> verify({
    required String workingDirectory,
    required List<String> command,
    List<String>? setupCommand,
    Duration? timeout,
  }) async {
    calls++;
    return VerificationOutcome(
      passed: true,
      mechanism: 'recording',
      command: command.join(' '),
      exitCode: 0,
    );
  }
}
