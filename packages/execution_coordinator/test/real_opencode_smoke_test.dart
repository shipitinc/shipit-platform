import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/fixture.dart';

/// Opt-in real-runtime smoke tests: they spawn the ACTUAL `opencode` binary over
/// ACP and let a real model edit the disposable workspace. They are skipped
/// unless the harness is explicitly enabled:
///
///   SHIPIT_REAL_OPENCODE=true dart test test/real_opencode_smoke_test.dart
///
/// Everything else (phantom providers, scripted sessions, capability routing)
/// is covered deterministically by the unit tests. These tests are the
/// platform-independent end-of-slice proof: one real runtime, one durable work
/// item, one bounded task.
void main() {
  final runReal = Platform.environment['SHIPIT_REAL_OPENCODE'] == 'true';
  if (!runReal) {
    test(
      'real OpenCode smoke tests are opt-in',
      () => print(
        'Skipping real OpenCode smoke tests. '
        'Set SHIPIT_REAL_OPENCODE=true to run against a live opencode binary.',
      ),
      skip: 'opt-in via SHIPIT_REAL_OPENCODE=true',
    );
    return;
  }

  late Directory temp;
  late FixtureWorkspace fixture;
  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('real_opencode_');
    fixture = FixtureWorkspace(parent: temp.path);
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();
  });

  tearDown(() => fixture.dispose());

  Future<void> parkWorkItem() async {
    await workflowEngine.createWorkItem(
      workItemId: 'wi-real',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Implement calculator add',
      description:
          'Implement the calculator add function for the contract suite',
      qaContractId: 'qa-1',
      featureRef: 'feature/calc',
    );
    await workflowEngine.transition(
      workItemId: 'wi-real',
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
    );
    await workflowEngine.transition(
      workItemId: 'wi-real',
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      context: const {'featureRef': 'feature/calc'},
    );
    await workflowEngine.transition(
      workItemId: 'wi-real',
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );
  }

  AgentExecutionRequest realRequest({
    required String instruction,
    Map<String, String> runtimeConfig = const {'pure': 'true'},
  }) {
    return AgentExecutionRequest(
      executionId: 'exec-real',
      workItemId: 'wi-real',
      role: AgentRole.implementer,
      runtimeTypeId: 'opencode',
      workspace: AgentWorkspace(
        workspaceId: 'ws-real',
        path: fixture.root.path,
        allowedPaths: [fixture.root.path],
      ),
      instruction: instruction,
      timeoutSeconds: 300,
      permittedScope: 'lib/calculator.dart only',
      runtimeConfig: runtimeConfig,
    );
  }

  ExecutionCoordinator coordinator({required VerificationPlan plan}) {
    return ExecutionCoordinator(
      store: executionStore,
      workflowEngine: workflowEngine,
      runtime: AgentRuntime(
        registry: AgentAdapterRegistry()..register(OpencodeAdapter()),
      ),
      verificationPlan: plan,
    );
  }

  test('happy path: real opencode edits the workspace and the platform verifies '
      'the change independently', () async {
    await parkWorkItem();
    final coordination = coordinator(
      plan: VerificationPlan(command: fixture.verifyCommand()),
    );

    final execution = await coordination.execute(
      realRequest(
        instruction:
            'Implement the add function in lib/calculator.dart so that '
            'add(2, 3) returns 5. Write the body; do not touch tool/verify.dart '
            'or any other file. Do not add dependencies.',
      ),
    );

    expect(
      execution.status,
      AgentSessionStatus.completed,
      reason:
          'execution must end with a completed status\n'
          'reason=${execution.reason}\n'
          'events=${(await executionStore.readEvents('exec-real')).map((e) => '${e.type}:${e.payload}').toList()}'
          '\nNOTE: a timed-out initialize/session/new typically means the '
          'machine could not cold-start `opencode acp` within the session '
          'timeout (network/catalog fetch). Retry on a healthy connection.',
    );
    expect(execution.sessionId, isNotEmpty);

    final item = await workflowEngine.loadWorkItem('wi-real');
    expect(
      item.state,
      WorkItemState.agentCompleted,
      reason: 'the durable workflow must land on agentCompleted',
    );

    final verification = await executionStore.readVerifications('exec-real');
    expect(
      verification.single.status,
      AgentClaimStatus.passed,
      reason: 'the platform check must observe add(2,3) == 5',
    );

    // Prove the real edit landed in the workspace.
    final result = await executionStore.readResult('exec-real');
    expect(result!.changedFiles, isNotEmpty);

    final events = await executionStore.readEvents('exec-real');
    expect(events.map((e) => e.type), contains(AgentEventType.toolCompleted));
  }, timeout: const Timeout(Duration(minutes: 15)));

  test(
    'failure demo: verification is independent of the agent and may disagree',
    () async {
      await parkWorkItem();
      final coordination = coordinator(
        plan: VerificationPlan(command: fixture.verifyCommand()),
      );
      fixture.makeVerifyImpossible();

      final execution = await coordination.execute(
        realRequest(
          instruction:
              'Implement the add function in lib/calculator.dart so that '
              'add(2, 3) returns 5. Write the body; do not touch tool/verify.dart '
              'or any other file.',
        ),
      );

      expect(
        execution.status,
        AgentSessionStatus.completed,
        reason: 'the agent may genuinely complete its own task',
      );

      final verification = await executionStore.readVerifications('exec-real');
      expect(verification, isNotEmpty);
      expect(
        verification.where((v) => v.status == AgentClaimStatus.failed),
        isNotEmpty,
        reason:
            'the independent check (expecting 999) must record a failure '
            'regardless of what the agent did',
      );
      // The agent's claim is persisted as a claim, never promoted.
      final result = await executionStore.readResult('exec-real');
      expect(result!.claimedChecks, isNot(contains('platform-verified')));
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
