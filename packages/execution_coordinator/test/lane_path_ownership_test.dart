import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/fake_agent.dart';
import 'support/fixture.dart';

/// THE DISPATCH-TIME CAPTURE OF THE LANE'S DECLARED OWNED PATHS.
///
/// ## WHAT THIS FILE MEASURES
///
/// Decision `4e1c9b52` says the F2 gate's missing input is the lane's
/// declared owned paths, and that they must be persisted AT DISPATCH — not
/// reconstructed after the work is known, and not inferred from the diff.
///
/// The dispatch-time moment is the coordinator creating the execution row.
/// This file measures that the declaration on the dispatch request is in the
/// DURABLE record from that moment on: the row the QA gate later reads.
///
/// ## WHY THE EMPTY CASE IS ASSERTED TOO
///
/// "Dispatched and declared nothing" and "no capture was made" are different
/// records. Both refuse the gate, but only one of them is a statement about
/// the lane, and the record has to be able to tell them apart — so the key is
/// written even when the declaration is empty.
void main() {
  late Directory temp;
  late FixtureWorkspace fixture;
  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('coordinator_ownership_');
    fixture = FixtureWorkspace(parent: temp.path);
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();
  });

  tearDown(() {
    fixture.dispose();
  });

  ExecutionCoordinator coordinatorOf() {
    final session = FakeAgentSession(
      executionId: 'exec-1',
      workItemId: 'wi-1',
      behavior: FakeBehavior.complete,
      sessionId: 'ses-fake-1',
    );
    final runtime = AgentRuntime(
      registry: AgentAdapterRegistry()..register(FakeAgentAdapter(session)),
    );
    return ExecutionCoordinator(
      store: executionStore,
      workflowEngine: workflowEngine,
      runtime: runtime,
      verificationPlan: VerificationPlan(command: fixture.verifyCommand()),
    );
  }

  Future<void> workItemReadyForExecution() async {
    await workflowEngine.createWorkItem(
      workItemId: 'wi-1',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Implement calculator add',
      description: 'Implement the calculator add function for this suite',
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

  AgentExecutionRequest request({List<String> declaredOwnedPaths = const []}) {
    return AgentExecutionRequest(
      executionId: 'exec-1',
      workItemId: 'wi-1',
      role: AgentRole.implementer,
      runtimeTypeId: 'fake-runtime',
      workspace: AgentWorkspace(workspaceId: 'ws-1', path: fixture.root.path),
      instruction: 'implement the calculator add function',
      timeoutSeconds: 60,
      permittedScope: 'lib/ only',
      declaredOwnedPaths: declaredOwnedPaths,
    );
  }

  group('the declaration is captured into the durable record at dispatch', () {
    test('the persisted execution carries the declared owned paths', () async {
      await workItemReadyForExecution();
      final coordinator = coordinatorOf();
      fixture.implement();

      await coordinator.execute(
        request(declaredOwnedPaths: const ['apps/server/**']),
      );

      final execution = await executionStore.readExecutionOrNull('exec-1');
      expect(execution, isNotNull);
      expect(execution!.metadata?[declaredOwnedPathsMetadataKey], [
        'apps/server/**',
      ]);
    });

    test(
      'the capture is on the row the FIRST write created, not a later one',
      () async {
        // The capture belongs to the dispatch-time write: the row that says
        // "this lane was dispatched" must already say what it was dispatched
        // with. A capture bolted onto the terminal write would be a declaration
        // reconstructed after the work was known — the thing the decision
        // forbids.
        await workItemReadyForExecution();
        fixture.implement();

        final writes = <Map<String, dynamic>?>[];
        final recording = _RecordingStore(writes);
        final recordingCoordinator = ExecutionCoordinator(
          store: recording,
          workflowEngine: workflowEngine,
          runtime: AgentRuntime(
            registry: AgentAdapterRegistry()
              ..register(
                FakeAgentAdapter(
                  FakeAgentSession(
                    executionId: 'exec-1',
                    workItemId: 'wi-1',
                    behavior: FakeBehavior.complete,
                    sessionId: 'ses-fake-1',
                  ),
                ),
              ),
          ),
          verificationPlan: VerificationPlan(command: fixture.verifyCommand()),
        );

        await recordingCoordinator.execute(
          request(declaredOwnedPaths: const ['apps/server/**']),
        );

        expect(writes, isNotEmpty);
        expect(
          writes.first?[declaredOwnedPathsMetadataKey],
          ['apps/server/**'],
          reason:
              'the FIRST durable write of the execution must already carry '
              'the dispatch-time declaration',
        );
      },
    );

    test('a lane that declared nothing records an EMPTY declaration, not an '
        'absent one', () async {
      await workItemReadyForExecution();
      final coordinator = coordinatorOf();
      fixture.implement();

      await coordinator.execute(request());

      final execution = await executionStore.readExecutionOrNull('exec-1');
      expect(execution, isNotNull);
      expect(
        execution!.metadata,
        contains(declaredOwnedPathsMetadataKey),
        reason:
            '"dispatched and declared nothing" and "no capture was made" '
            'are different records, and only one of them is a statement about '
            'the lane',
      );
      expect(execution.metadata![declaredOwnedPathsMetadataKey], isEmpty);
    });
  });
}

/// An execution store that records the metadata of every row it is asked to
/// persist, in order.
class _RecordingStore extends InMemoryExecutionStore {
  _RecordingStore(this.writes);

  final List<Map<String, dynamic>?> writes;

  @override
  Future<void> saveExecution(
    AgentExecution execution, {
    int? expectedVersion,
  }) async {
    writes.add(execution.metadata);
    await super.saveExecution(execution, expectedVersion: expectedVersion);
  }
}
