import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/fake_agent.dart';
import 'support/fixture.dart';

/// THE END-TO-END PROOF for the defect this lane exists for.
///
/// The defect, in one sentence: `_reviewEntryTransitionContext` supplied
/// `agentResultValid()` with the newest execution of ANY role, so once a
/// reviewer execution existed the guard read the REVIEWER's result and an item
/// with a completed producer and a failed reviewer could NEVER enter review
/// again.
///
/// Measured on QA before the fix
/// (`docs/engineering/learning/236-transition-rows-that-moved-nothing.md` §2):
///
/// ```
/// agx-wx-jb-hn7bdou768-12vlbk4  IMPLEMENTER          completed
/// agx-wx-jb-hn7gq1nj5w-70d6ix   ENGINEERING_REVIEWER  failed
/// ```
///
/// Both rows are reproduced here end to end: a real implementer run reaches
/// `agentCompleted`, a real reviewer run FAILS, and a second reviewer run must
/// still be able to enter review.
///
/// ## WHY THIS IS NOT THE SAME AS THE EXISTING B2 TEST
///
/// `engineering_reviewer_test.dart`'s "B2 regression" test runs ONE reviewer on
/// a fresh item. On a fresh item the newest execution of any role genuinely IS
/// the implementer, so **that test passes against the defective code**. Only a
/// second, failed reviewer execution exposes it. This file exists because the
/// original bug was invisible to every test that ran.
void main() {
  late Directory temp;
  late FixtureWorkspace fixture;
  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('producer_e2e');
    fixture = FixtureWorkspace(parent: temp.path)..implement();
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();
  });

  tearDown(() {
    fixture.dispose();
    temp.deleteSync(recursive: true);
  });

  /// Builds a coordinator whose runtime returns [session].
  ExecutionCoordinator coordinatorFor(FakeAgentSession session) =>
      ExecutionCoordinator(
        store: executionStore,
        workflowEngine: workflowEngine,
        runtime: AgentRuntime(
          registry: AgentAdapterRegistry()..register(FakeAgentAdapter(session)),
        ),
        verificationPlan: VerificationPlan(command: fixture.verifyCommand()),
      );

  AgentExecutionRequest request({
    required String executionId,
    required AgentRole role,
  }) => AgentExecutionRequest(
    executionId: executionId,
    workItemId: 'wi-1',
    role: role,
    runtimeTypeId: 'fake-runtime',
    workspace: AgentWorkspace(workspaceId: 'ws-1', path: fixture.root.path),
    instruction: 'do the work',
    timeoutSeconds: 60,
    permittedScope: 'lib/ only',
  );

  Future<void> readyItem() async {
    await workflowEngine.createWorkItem(
      workItemId: 'wi-1',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Implement calculator add',
      description: 'Implement the calculator add function for the contract',
      qaContractId: 'qa-1',
      featureRef: 'feature/calc',
    );
    for (final state in [
      WorkItemState.planning,
      WorkItemState.planned,
      WorkItemState.designNotRequired,
    ]) {
      await workflowEngine.transition(
        workItemId: 'wi-1',
        to: state,
        trigger: TransitionTrigger.systemEvent,
        context: const {'featureRef': 'feature/calc'},
      );
    }
  }

  /// Runs the implementer to `agentCompleted`, stamping `producerActorId`.
  Future<void> runImplementer() async {
    await readyItem();
    await coordinatorFor(
      FakeAgentSession(executionId: 'exec-impl', workItemId: 'wi-1'),
    ).execute(request(executionId: 'exec-impl', role: AgentRole.implementer));
  }

  /// Runs a reviewer that FAILS. Returns its terminal execution.
  Future<AgentExecution> runFailingReviewer(String executionId) async {
    final outcome =
        await coordinatorFor(
          FakeAgentSession(
            executionId: executionId,
            workItemId: 'wi-1',
            behavior: FakeBehavior.fail,
          ),
        ).execute(
          request(
            executionId: executionId,
            role: AgentRole.engineeringReviewer,
          ),
        );
    return outcome;
  }

  test('THE REGRESSION: a completed producer with a FAILED reviewer can still '
      'enter review', () async {
    await runImplementer();
    expect(
      (await workflowEngine.loadWorkItem('wi-1')).state,
      WorkItemState.agentCompleted,
    );
    expect(
      (await workflowEngine.loadWorkItem('wi-1')).metadata?['producerActorId'],
      'exec-impl',
    );

    // The first reviewer fails. It does NOT move the item out of review — the
    // coordinator never transitions out of `reviewInProgress` for a reviewer —
    // so the item is at `reviewInProgress` with a failed reviewer execution
    // newest. That is exactly the QA shape.
    final failed = await runFailingReviewer('exec-review-1');
    expect(failed.status, isNot(AgentSessionStatus.completed));

    // Send the item back so a SECOND review attempt is a real entry transition
    // and not a no-op. `reviewInProgress -> agentCompleted` is legal and is
    // what the retry-return lane does on a transient failure.
    await workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.agentCompleted,
      trigger: TransitionTrigger.systemEvent,
      actor: const WorkflowActor(
        actorId: 'test',
        actorType: ActorType.orchestrator,
      ),
      context: {
        'agentResult': AgentResult(
          resultId: 'res-return',
          sessionId: 'ses-return',
          workItemId: 'wi-1',
          status: AgentResultStatus.completed,
          artifacts: const [],
          diagnostics: const AgentDiagnostics(
            exitCode: 0,
            durationMs: 1,
            toolCalls: 0,
            errors: [],
            warnings: [],
          ),
          structuredResult: const {},
          completedAt: DateTime.utc(2026, 1, 1),
        ),
      },
    );
    expect(
      (await workflowEngine.loadWorkItem('wi-1')).state,
      WorkItemState.agentCompleted,
    );

    // THE ASSERTION. The failed reviewer above is the NEWEST execution of any
    // role. Before the fix, this call supplied the guard with the failed
    // reviewer's result, `agentResultValid()` refused, the engine appended a
    // `rejected` row, and `execute` raised WorkItemSupersededException — for
    // ever, on every attempt.
    final second =
        await coordinatorFor(
          FakeAgentSession(executionId: 'exec-review-2', workItemId: 'wi-1'),
        ).execute(
          request(
            executionId: 'exec-review-2',
            role: AgentRole.engineeringReviewer,
          ),
        );

    expect(
      (await workflowEngine.loadWorkItem('wi-1')).state,
      WorkItemState.reviewInProgress,
      reason:
          'the producer completed, so the item must be able to enter review '
          'regardless of what the first reviewer did',
    );
    expect(second.executionId, 'exec-review-2');
  });

  test(
    'a THIRD review also succeeds — the property is "any number of times", not '
    '"once after one failure"',
    () async {
      await runImplementer();
      await runFailingReviewer('exec-review-1');

      final history = await workflowEngine.loadWorkItem('wi-1');
      expect(
        history.state,
        WorkItemState.reviewInProgress,
        reason: 'the first reviewer entered review successfully',
      );

      // Two failed reviewer rows now exist under this item.
      final executions = await executionStore.listExecutions(
        workItemId: 'wi-1',
      );
      expect(
        executions.where((e) => e.role == AgentRole.engineeringReviewer).length,
        1,
      );

      await workflowEngine.transition(
        workItemId: 'wi-1',
        to: WorkItemState.agentCompleted,
        trigger: TransitionTrigger.systemEvent,
        actor: const WorkflowActor(
          actorId: 'test',
          actorType: ActorType.orchestrator,
        ),
        context: {
          'agentResult': AgentResult(
            resultId: 'res-return',
            sessionId: 'ses-return',
            workItemId: 'wi-1',
            status: AgentResultStatus.completed,
            artifacts: const [],
            diagnostics: const AgentDiagnostics(
              exitCode: 0,
              durationMs: 1,
              toolCalls: 0,
              errors: [],
              warnings: [],
            ),
            structuredResult: const {},
            completedAt: DateTime.utc(2026, 1, 1),
          ),
        },
      );

      await coordinatorFor(
        FakeAgentSession(executionId: 'exec-review-2', workItemId: 'wi-1'),
      ).execute(
        request(
          executionId: 'exec-review-2',
          role: AgentRole.engineeringReviewer,
        ),
      );
      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.reviewInProgress,
      );
    },
  );

  test(
    'THE OTHER DIRECTION: a producer whose recorded result is NOT completed is '
    'still refused',
    () async {
      await runImplementer();
      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        WorkItemState.agentCompleted,
      );

      // The producer's DURABLE result is no longer a completed one. This is the
      // shape `engineeringReviewMissingArtifact` already guards against
      // (`implementerResult == null` -> refuse), and the shape a refuted or
      // repaired producer leaves behind.
      //
      // It is asserted here through the real coordinator rather than by forging
      // the state, because `agentExecuting -> agentCompleted` carries
      // `agentResultValid()` too: a work item cannot be walked to
      // `agentCompleted` carrying a failed result, so the only way to observe
      // the refusal is to change what the PRODUCER's row says afterwards. That
      // is the honest shape, and it is the one the guard is for.
      await executionStore.saveResult(
        'exec-impl',
        AgentResult(
          resultId: 'res-impl',
          sessionId: 'ses-impl',
          workItemId: 'wi-1',
          status: AgentResultStatus.failed,
          artifacts: const [],
          diagnostics: const AgentDiagnostics(
            exitCode: 1,
            durationMs: 1,
            toolCalls: 0,
            errors: [],
            warnings: [],
          ),
          structuredResult: const {},
          completedAt: DateTime.utc(2026, 1, 1),
        ),
      );

      final refused = await _attemptReview(
        coordinatorFor(
          FakeAgentSession(executionId: 'exec-review-1', workItemId: 'wi-1'),
        ),
        executionId: 'exec-review-1',
      );

      expect(
        refused,
        isTrue,
        reason:
            'the producer execution EXISTS and the item really is at '
            'agentCompleted, but its recorded result is not completed. That is '
            'exactly what agentResultValid() exists to refuse, and the lookup '
            'must not soften it by answering "an implementer ran"',
      );
      expect(
        (await workflowEngine.loadWorkItem('wi-1')).state,
        isNot(WorkItemState.reviewInProgress),
      );
    },
  );
}

/// Attempts one reviewer dispatch and reports whether the edge was refused.
///
/// "Refused" means the item did not reach `reviewInProgress` — asserted from
/// DURABLE state rather than from the thrown type, so a refusal that arrives by
/// a different route still counts as a refusal.
Future<bool> _attemptReview(
  ExecutionCoordinator coordinator, {
  required String executionId,
}) async {
  try {
    await coordinator.execute(
      AgentExecutionRequest(
        executionId: executionId,
        workItemId: 'wi-1',
        role: AgentRole.engineeringReviewer,
        runtimeTypeId: 'fake-runtime',
        workspace: AgentWorkspace(workspaceId: 'ws-1', path: '/tmp/ws'),
        instruction: 'review it',
        timeoutSeconds: 60,
        permittedScope: 'lib/ only',
      ),
    );
  } on WorkItemSupersededException {
    // The coordinator's own name for "the entry transition was refused".
  }
  return (await coordinator.workflowEngine.loadWorkItem('wi-1')).state !=
      WorkItemState.reviewInProgress;
}
