import 'dart:async';
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
  late FakeAgentSession session;
  late AgentRuntime runtime;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('coordinator_');
    fixture = FixtureWorkspace(parent: temp.path);
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();
  });

  tearDown(() {
    fixture.dispose();
  });

  ExecutionCoordinator coordinatorOf({
    FakeBehavior behavior = FakeBehavior.complete,
  }) {
    session = FakeAgentSession(
      executionId: 'exec-1',
      workItemId: 'wi-1',
      behavior: behavior,
      sessionId: 'ses-fake-1',
    );
    runtime = AgentRuntime(
      registry: AgentAdapterRegistry()..register(FakeAgentAdapter(session)),
    );
    return ExecutionCoordinator(
      store: executionStore,
      workflowEngine: workflowEngine,
      runtime: runtime,
      verificationPlan: VerificationPlan(command: fixture.verifyCommand()),
    );
  }

  /// A work item parked at [WorkItemState.designNotRequired] with a QA
  /// contract attached, ready to be routed into execution.
  Future<WorkItem> workItemReadyForExecution() async {
    await workflowEngine.createWorkItem(
      workItemId: 'wi-1',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Implement calculator add',
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
    final item = await workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );
    return item;
  }

  AgentExecutionRequest request({
    String? executionId,
    int timeoutSeconds = 60,
  }) {
    return AgentExecutionRequest(
      executionId: executionId ?? 'exec-1',
      workItemId: 'wi-1',
      role: AgentRole.implementer,
      runtimeTypeId: 'fake-runtime',
      workspace: AgentWorkspace(workspaceId: 'ws-1', path: fixture.root.path),
      instruction: 'implement the calculator add function',
      timeoutSeconds: timeoutSeconds,
      permittedScope: 'lib/ only',
    );
  }

  group('ExecutionCoordinator happy path', () {
    test(
      'moves the work item through execution and records platform evidence',
      () async {
        await workItemReadyForExecution();
        final coordinator = coordinatorOf();
        fixture.implement();

        final execution = await coordinator.execute(request());

        expect(execution.status, AgentSessionStatus.completed);
        expect(execution.sessionId, 'ses-fake-1');
        expect(execution.role, AgentRole.implementer);

        final item = await workflowEngine.loadWorkItem('wi-1');
        expect(item.state, WorkItemState.agentCompleted);

        final result = await executionStore.readResult('exec-1');
        expect(result, isNotNull);
        expect(result!.role, AgentRole.implementer);
        expect(result.executionId, 'exec-1');
        expect(result.status, AgentResultStatus.completed);

        final verification = await executionStore.readVerifications('exec-1');
        expect(verification, hasLength(1));
        expect(verification.single.status, AgentClaimStatus.passed);
        expect(
          verification.single.evidenceKind,
          EvidenceKind.platformVerifiedEvidence,
        );

        final events = await executionStore.readEvents('exec-1');
        final types = events.map((e) => e.type).toList();
        expect(types.first, AgentEventType.executionStarted);
        expect(types, contains(AgentEventType.toolStarted));
        expect(types, contains(AgentEventType.toolCompleted));
        expect(types, contains(AgentEventType.executionCompleted));
        for (var i = 0; i < events.length; i++) {
          expect(events[i].sequence, i + 1);
        }

        final transitions = await workflowEngine.transitionHistory('wi-1');
        expect(
          transitions.any((t) => t.toState == WorkItemState.agentCompleted),
          isTrue,
          reason: 'agentCompleted must be recorded in transition history',
        );
      },
    );

    test(
      're-running a terminal execution id replays the durable record',
      () async {
        await workItemReadyForExecution();
        final coordinator = coordinatorOf();
        fixture.implement();

        final first = await coordinator.execute(request());
        final replay = await coordinator.execute(request());
        expect(replay.executionId, first.executionId);
        expect(replay.status, AgentSessionStatus.completed);
        expect(await executionStore.listExecutions(), hasLength(1));
        // A replay must not spawn a second session.
        expect(
          await workflowEngine
              .transitionHistory('wi-1')
              .then(
                (t) => t
                    .where((e) => e.toState == WorkItemState.agentExecuting)
                    .length,
              ),
          1,
        );
      },
    );

    test('records a failed verification without faking a pass', () async {
      await workItemReadyForExecution();
      final coordinator = coordinatorOf();
      // Do NOT implement the fixture: the agent claims completion but the
      // platform's independent check must fail.

      final execution = await coordinator.execute(request());
      expect(execution.status, AgentSessionStatus.completed);

      final verification = await executionStore.readVerifications('exec-1');
      expect(verification.single.status, AgentClaimStatus.failed);
      // The agent claim and the platform evidence explicitly differ: the
      // platform never promotes the agent's claim.
      final result = await executionStore.readResult('exec-1');
      expect(result!.status, AgentResultStatus.completed);
    });
  });

  group('ExecutionCoordinator failure and control paths', () {
    test('failed session moves the work item to agentFailed', () async {
      await workItemReadyForExecution();
      final coordinator = coordinatorOf(behavior: FakeBehavior.fail);

      final execution = await coordinator.execute(request());
      expect(execution.status, AgentSessionStatus.failed);

      final item = await workflowEngine.loadWorkItem('wi-1');
      expect(item.state, WorkItemState.agentFailed);
      final events = await executionStore.readEvents('exec-1');
      expect(
        events.map((e) => e.type),
        contains(AgentEventType.executionFailed),
      );
    });

    test(
      'interrupted session is recorded as interrupted and agentFailed',
      () async {
        await workItemReadyForExecution();
        final coordinator = coordinatorOf(behavior: FakeBehavior.interrupt);

        final execution = await coordinator.execute(request());
        expect(execution.status, AgentSessionStatus.interrupted);
        expect(
          (await workflowEngine.loadWorkItem('wi-1')).state,
          WorkItemState.agentFailed,
        );
      },
    );

    test('cancel tears the session down and finalizes as cancelled', () async {
      await workItemReadyForExecution();
      final coordinator = coordinatorOf(behavior: FakeBehavior.cancelRequested);

      final pending = coordinator.execute(request());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final execution = await coordinator.cancelExecution(
        'exec-1',
        'operator canceled',
      );

      expect(execution.status, AgentSessionStatus.cancelled);
      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.agentFailed,
      );
      final result = await executionStore.readResult('exec-1');
      expect(result!.status, AgentResultStatus.cancelled);
      await pending;
    });

    test(
      'unknown provider fails the execution without spawning a session',
      () async {
        await workItemReadyForExecution();
        session = FakeAgentSession(executionId: 'exec-1', workItemId: 'wi-1');
        runtime = AgentRuntime();
        final coordinator = ExecutionCoordinator(
          store: executionStore,
          workflowEngine: workflowEngine,
          runtime: runtime,
        );

        final deadRequest = AgentExecutionRequest(
          executionId: 'exec-1',
          workItemId: 'wi-1',
          role: AgentRole.implementer,
          runtimeTypeId: 'does-not-exist',
          workspace: AgentWorkspace(
            workspaceId: 'ws-1',
            path: fixture.root.path,
          ),
          instruction: 'implement add',
          timeoutSeconds: 60,
        );

        final execution = await coordinator.execute(deadRequest);
        expect(execution.status, AgentSessionStatus.failed);
        expect(
          (await workflowEngine.loadWorkItem('wi-1')).state,
          WorkItemState.agentFailed,
        );
      },
    );
  });

  group('ExecutionCoordinator durability', () {
    test(
      'reconcileOrphans marks stranded executions and exits the work item',
      () async {
        await workItemReadyForExecution();
        // Simulate a crashed process: another coordinator instance owned the
        // session and wrote a running execution, then vanished.
        final pre = DirichletExecutionStore();
        await pre.saveRequest(request(executionId: 'exec-stranded'));
        await pre.saveExecution(
          AgentExecution(
            executionId: 'exec-stranded',
            workItemId: 'wi-1',
            requestId: 'exec-stranded',
            runtimeTypeId: 'fake-runtime',
            role: AgentRole.implementer,
            status: AgentSessionStatus.running,
            workspace: AgentWorkspace(
              workspaceId: 'ws-1',
              path: fixture.root.path,
            ),
            sessionId: 'ses-gone',
            startedAt: DateTime.now(),
          ),
        );
        await workflowEngine.transition(
          workItemId: 'wi-1',
          to: WorkItemState.agentExecuting,
          trigger: TransitionTrigger.systemEvent,
          context: const {'agentAvailable': true, 'capabilitiesMatch': true},
        );

        final fresh = ExecutionCoordinator(
          store: pre,
          workflowEngine: workflowEngine,
          runtime: AgentRuntime(
            registry: AgentAdapterRegistry()
              ..register(
                FakeAgentAdapter(
                  FakeAgentSession(executionId: 'exec-1', workItemId: 'wi-1'),
                ),
              ),
          ),
        );

        final orphans = await fresh.reconcileOrphans();
        expect(orphans.single.status, AgentSessionStatus.orphaned);
        expect(
          (await workflowEngine.loadWorkItem('wi-1')).state,
          WorkItemState.agentFailed,
        );
      },
    );

    test(
      'FileJsonExecutionStore survives a full coordinator round-trip',
      () async {
        final file = File('${temp.path}/executions.json');
        final durableStore = FileJsonExecutionStore(file);
        final durableWorkflow = DurableWorkflowEngine(
          store: InMemoryWorkflowStore(),
        );
        await durableWorkflow.createWorkItem(
          workItemId: 'wi-1',
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'Implement calculator add',
          qaContractId: 'qa-1',
          featureRef: 'feature/calc',
        );
        await durableWorkflow.transition(
          workItemId: 'wi-1',
          to: WorkItemState.planning,
          trigger: TransitionTrigger.systemEvent,
        );
        await durableWorkflow.transition(
          workItemId: 'wi-1',
          to: WorkItemState.planned,
          trigger: TransitionTrigger.systemEvent,
          context: const {'featureRef': 'feature/calc'},
        );
        await durableWorkflow.transition(
          workItemId: 'wi-1',
          to: WorkItemState.designNotRequired,
          trigger: TransitionTrigger.systemEvent,
        );

        session = FakeAgentSession(
          executionId: 'exec-file',
          workItemId: 'wi-1',
          sessionId: 'ses-file',
        );
        runtime = AgentRuntime(
          registry: AgentAdapterRegistry()..register(FakeAgentAdapter(session)),
        );
        final coordinator = ExecutionCoordinator(
          store: durableStore,
          workflowEngine: durableWorkflow,
          runtime: runtime,
          verificationPlan: VerificationPlan(command: fixture.verifyCommand()),
        );
        fixture.implement();

        // Resolve the workspace path used by the request/execution record.
        final realRequest = AgentExecutionRequest(
          executionId: 'exec-file',
          workItemId: 'wi-1',
          role: AgentRole.integrator,
          runtimeTypeId: 'fake-runtime',
          workspace: AgentWorkspace(
            workspaceId: 'ws-file',
            path: fixture.root.path,
          ),
          instruction: 'implement add',
          timeoutSeconds: 60,
        );
        await coordinator.execute(realRequest);

        // A new store instance backed by the same file observes everything.
        final reloaded = FileJsonExecutionStore(file);
        expect(
          (await reloaded.readExecution('exec-file')).status,
          AgentSessionStatus.completed,
        );
        expect(await reloaded.readResult('exec-file'), isNotNull);
        expect(await reloaded.readVerifications('exec-file'), isNotEmpty);
        expect(await reloaded.readEvents('exec-file'), isNotEmpty);
      },
    );
  });
}

/// Minimal in-memory store alias used by the orphan test to keep concerns
/// distinct from the coordinator-under-test store.
class DirichletExecutionStore implements ExecutionStore {
  final _store = InMemoryExecutionStore();

  @override
  Future<void> appendEvent(AgentEventRecord event) => _store.appendEvent(event);

  @override
  Future<List<AgentExecution>> listExecutions({String? workItemId}) =>
      _store.listExecutions(workItemId: workItemId);

  @override
  Future<AgentExecution?> latestExecutionForWorkItem(String workItemId) =>
      _store.latestExecutionForWorkItem(workItemId);

  @override
  Future<AgentExecution> readExecution(String executionId) =>
      _store.readExecution(executionId);

  @override
  Future<AgentExecution?> readExecutionOrNull(String executionId) =>
      _store.readExecutionOrNull(executionId);

  @override
  Future<List<AgentEventRecord>> readEvents(String executionId) =>
      _store.readEvents(executionId);

  @override
  Future<AgentExecutionRequest?> readRequest(String executionId) =>
      _store.readRequest(executionId);

  @override
  Future<AgentResult?> readResult(String executionId) =>
      _store.readResult(executionId);

  @override
  Future<List<PlatformVerification>> readVerifications(String executionId) =>
      _store.readVerifications(executionId);

  @override
  Future<void> saveExecution(
    AgentExecution execution, {
    int? expectedVersion,
  }) => _store.saveExecution(execution, expectedVersion: expectedVersion);

  @override
  Future<void> saveRequest(AgentExecutionRequest request) =>
      _store.saveRequest(request);

  @override
  Future<void> saveResult(String executionId, AgentResult result) =>
      _store.saveResult(executionId, result);

  @override
  Future<void> saveVerification(PlatformVerification verification) =>
      _store.saveVerification(verification);

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(ExecutionStore store) body,
  ) async => body(this);
}
