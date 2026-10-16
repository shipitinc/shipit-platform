import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/fake_agent.dart';
import 'support/git_fixture.dart';

/// Finding H1's first half: the `UNDETERMINED` verdict has to reach the
/// scheduler, and it used to reach nobody.
///
/// ## WHAT WAS WRONG, MEASURED
///
/// The marker was written into `_Completion.eventPayload` only. That becomes
/// `ExecutionStore.appendEvent` and the `agent_event` table — and the
/// scheduler's production worker store reads `worker_execution`, `worker_result`
/// and `worker_event`, never `agent_event`. So the verdict was recorded
/// faithfully, in a table nobody reads, by a package `packages/scheduler` does
/// not depend on at all. The platform could not act on it, and the completion
/// cycle it describes ran unattended and for ever.
///
/// ## WHAT THIS FILE PINS
///
/// The verdict is ALSO on `WorkItem.metadata`, which is the one durable channel
/// the scheduler already reads for the producer identity, and this file asserts
/// it is written on EVERY completion — `true`, `false` and (on the branches
/// that never reach `agentCompleted`) not at all. The "false overwrites a
/// previous true" case is the load-bearing one: the flag describes the LAST
/// completion, so a determined run after an undetermined one must clear it, or
/// the scheduler's streak counts a fault that stopped happening.
///
/// The `agent_event` write is kept and asserted too. It was correct — it is the
/// operator's record — and it was simply not the whole of what the platform
/// needed.
void main() {
  late Directory temp;
  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('undetermined_publication_');
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// A probe whose `git` cannot be spawned at all: the "missing git" shape the
  /// finding names.
  ///
  /// The REAL `GitWorkspaceDeltaProbe`, not a stubbed answer. `Process.run`
  /// throws `ProcessException` for a binary that does not exist, `_capture`
  /// answers null, and `WorkspaceDelta.unreadable` follows from production code
  /// rather than from a return value this test dictated.
  const noGit = RoleAwareSuccessArtifacts(
    probe: GitWorkspaceDeltaProbe(git: '/no/such/git-binary'),
  );

  ExecutionCoordinator coordinatorOf(
    FakeAgentSession session, {
    SuccessArtifactChecker? successArtifacts,
  }) => ExecutionCoordinator(
    store: executionStore,
    workflowEngine: workflowEngine,
    runtime: AgentRuntime(
      registry: AgentAdapterRegistry()..register(FakeAgentAdapter(session)),
    ),
    successArtifacts: successArtifacts,
  );

  AgentExecutionRequest requestFor({
    required String executionId,
    required AgentWorkspace workspace,
    AgentRole role = AgentRole.implementer,
    String workItemId = 'wi-1',
  }) => AgentExecutionRequest(
    executionId: executionId,
    workItemId: workItemId,
    role: role,
    runtimeTypeId: 'fake-runtime',
    workspace: workspace,
    instruction: 'do the work',
    timeoutSeconds: 60,
  );

  Future<void> readyItem({String id = 'wi-1'}) async {
    await workflowEngine.createWorkItem(
      workItemId: id,
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Fix the defect filtering logic',
      description: 'Runs whose artifact cannot be established',
      qaContractId: 'qa-1',
      featureRef: 'feature/defect-filter',
    );
    await workflowEngine.transition(
      workItemId: id,
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
    );
    await workflowEngine.transition(
      workItemId: id,
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      context: const {'featureRef': 'feature/defect-filter'},
    );
    await workflowEngine.transition(
      workItemId: id,
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );
  }

  /// A workspace whose path is not a git worktree at all — the "wedged or
  /// wrong filesystem" shape, distinct from "no git binary".
  AgentWorkspace unreadableWorkspace({String workspaceId = 'ws-blind'}) =>
      AgentWorkspace(
        workspaceId: workspaceId,
        path: '${temp.path}/not-a-worktree',
        startingRevision: 'a1b2c3d4e5f60718293a4b5c6d7e8f9012345678',
      );

  /// Reads the flag the way the scheduler does — out of the store, through the
  /// engine, not from the object this test happens to hold.
  Future<Object?> flagFor(String workItemId) async =>
      (await workflowEngine.loadWorkItem(
        workItemId,
      )).metadata?[SuccessArtifactArtifacts.undeterminedMetadataKey];

  group('the verdict reaches WorkItem.metadata', () {
    test(
      'an UNDETERMINED completion stamps true, and the store serves it',
      () async {
        await readyItem();
        final directory = Directory('${temp.path}/not-a-worktree')
          ..createSync(recursive: true);

        await coordinatorOf(
          FakeAgentSession(executionId: 'exec-blind', workItemId: 'wi-1'),
          successArtifacts: noGit,
        ).execute(
          requestFor(
            executionId: 'exec-blind',
            workspace: unreadableWorkspace(),
          ),
        );

        expect(
          (await workflowEngine.loadWorkItem('wi-1')).state,
          WorkItemState.agentCompleted,
          reason:
              'undetermined is NOT a failure — see the class doc — so the item '
              'does reach agentCompleted. That is exactly why it needs a brake '
              'rather than a rejection',
        );
        expect(
          await flagFor('wi-1'),
          isTrue,
          reason:
              'this is the whole of finding H1. The scheduler reads the verdict '
              'from this key, through the store, and nothing else it reads '
              'carries it: `agent_event` is not a table `PostgresWorkerStore` '
              'opens, and `packages/scheduler` cannot import this package',
        );
        expect(directory.existsSync(), isTrue);
      },
    );

    test('a SATISFIED completion stamps false — and CLEARS a previous true', () async {
      // THE CASE THAT DECIDES WHETHER THE FLAG IS WRITTEN OR SET.
      //
      // The flag describes the LAST completion. If the coordinator only wrote
      // `true` and left it there, an item whose tooling recovered would carry a
      // stale `true` for ever, and the scheduler's brake would keep counting a
      // fault that had stopped happening — parking a recoverable item in front
      // of a person.
      final git = GitWorkspaceFixture.create(temp.path);
      addTearDown(git.dispose);
      await readyItem();

      // Pass 1: the probe cannot be run at all.
      await coordinatorOf(
        FakeAgentSession(executionId: 'exec-1', workItemId: 'wi-1'),
        successArtifacts: noGit,
      ).execute(
        requestFor(executionId: 'exec-1', workspace: git.toWorkspace()),
      );
      expect(await flagFor('wi-1'), isTrue);

      // The one route production takes between two passes of the completion
      // cycle: the inflow puts the item back on this lane's entry state.
      await workflowEngine.transition(
        workItemId: 'wi-1',
        to: WorkItemState.implementationReady,
        trigger: TransitionTrigger.systemEvent,
        actor: const WorkflowActor(
          actorId: 'sched-impl',
          actorType: ActorType.orchestrator,
        ),
        context: const {'agentAvailable': true, 'capabilitiesMatch': true},
      );

      // Pass 2: real git, and the run committed its own work.
      git.writeFile(
        'lib/defect_filter.dart',
        'bool matches(String r) => true;\n',
      );
      git.commitAll('implement the defect filter');
      await coordinatorOf(
        FakeAgentSession(executionId: 'exec-2', workItemId: 'wi-1'),
      ).execute(
        requestFor(
          executionId: 'exec-2',
          workspace: git.toWorkspace(workspaceId: 'ws-git'),
        ),
      );

      expect(
        await flagFor('wi-1'),
        isFalse,
        reason:
            'the platform could read this one, so the flag says so. Leaving the '
            'previous `true` in place would make the brake count a fault that '
            'stopped happening and park a recoverable item for a human',
      );
    });

    test('a MISSING completion stamps nothing, because the item never reaches '
        'agentCompleted', () async {
      await readyItem();
      final git = GitWorkspaceFixture.create(temp.path);
      addTearDown(git.dispose);
      // A REAL git repository, cleanly read, with the agent having produced
      // nothing — the `MISSING` verdict, which is a permanent failure.
      await coordinatorOf(
        FakeAgentSession(executionId: 'exec-empty', workItemId: 'wi-1'),
      ).execute(
        requestFor(
          executionId: 'exec-empty',
          workspace: git.toWorkspace(workspaceId: 'ws-git'),
        ),
      );

      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.agentFailed,
        reason:
            'a clean finish that produced nothing is a PERMANENT failure, so '
            'the item is handed to a person and never enters this cycle',
      );
      expect(
        await flagFor('wi-1'),
        isNull,
        reason:
            'nothing is written about a verdict on a state this completion '
            'never reached. A flag here would describe an artifact check for an '
            'item that is not at agentCompleted',
      );
    });
  });

  group('the agent_event record is kept, not replaced', () {
    test(
      'the undetermined verdict is still written to the event stream',
      () async {
        await readyItem();
        await coordinatorOf(
          FakeAgentSession(executionId: 'exec-obs', workItemId: 'wi-1'),
          successArtifacts: noGit,
        ).execute(
          requestFor(executionId: 'exec-obs', workspace: unreadableWorkspace()),
        );

        final events = await executionStore.readEvents('exec-obs');
        final payload =
            events
                .lastWhere((e) => e.type == AgentEventType.executionCompleted)
                .payload ??
            const <String, dynamic>{};
        expect(
          payload['successArtifactUndetermined'],
          isNotNull,
          reason:
              'the operator-facing record is the right home for the verdict and it '
              'was right before this change. It is now joined by the work-item '
              'flag rather than replaced by it: the event says what happened to '
              'one run, the flag says what the scheduler must decide',
        );
      },
    );
  });
}
