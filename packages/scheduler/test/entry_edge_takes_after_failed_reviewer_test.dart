import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';

import 'support/controlled_dispatcher.dart';
import 'support/file_host.dart';

/// THE LANE-LEVEL REGRESSION, and the count that proves it.
///
/// ## THE TWO HALVES, AND WHY ONLY RUNNING BOTH MEANS ANYTHING
///
///  * **The item can enter review.** A work item at `agent_completed` whose
///    producer execution COMPLETED, with a FAILED engineering-reviewer
///    execution already recorded. That shape is measured QA state, not a
///    thought experiment:
///
///    ```
///    agx-wx-jb-hn7bdou768-12vlbk4  IMPLEMENTER          completed
///    agx-wx-jb-hn7gq1nj5w-70d6ix   ENGINEERING_REVIEWER  failed
///    ```
///
///    Before the root-cause fix this item could never enter review again —
///    `_reviewEntryTransitionContext` handed `agentResultValid()` the newest
///    execution of ANY role, which was the failed reviewer. It burned 243
///    refused attempts and 214 jobs.
///
///  * **Exactly one job exists after N ticks.** Asserted as a COUNT, never as a
///    final state: the item reads `agent_completed` while the lane spins AND
///    while it does not, so a state assertion cannot tell the two apart. That
///    is why the defect sat in the catalogue for a whole project.
///
/// ## WHAT IS MODELLED HERE, AND WHAT IS NOT
///
/// The scheduler never runs a coordinator — `engineeringReviewDefinition`
/// carries `skipWorkflowPolicyCheck: true` precisely because the scheduler
/// cannot supply the producer result and the REAL edge is enforced later, by
/// `ExecutionCoordinator.execute`. So the dispatch below models the coordinator
/// **after the fix**: it takes the entry transition, which moves the item.
///
/// This is the honest seam. The "can enter review" half is proved for real,
/// with a real `ExecutionCoordinator` and a real engine, in
/// `packages/execution_coordinator/test/producer_evidence_entry_test.dart` —
/// including a non-vacuity check that reverts to the role-blind lookup and
/// turns it red. What is proved HERE is the other half, which only exists at
/// this level: that a lane whose dispatches actually move the item does not
/// churn, and does not get mistaken for a stall.
///
/// The complement already exists and must keep passing: when the entry edge is
/// genuinely refused forever, `review_stall_test.dart` asserts exactly one job.
/// Between them, both readings of the same counter are pinned.
/// A completed producer result. `agentResultValid()` requires one on the entry
/// edge, so this is what a real producer leaves behind.
AgentResult _completedResult() => AgentResult(
  resultId: 'res-1',
  sessionId: 'ses-1',
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
  completedAt: DateTime.utc(2026, 1, 1, 12),
);

void main() {
  late Directory dir;
  final t0 = DateTime.utc(2026, 1, 1, 12);

  setUp(() => dir = Directory.systemTemp.createTempSync('entry_takes'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// A work item at `agent_completed` — the review lane's entry state — reached
  /// through the real engine, with a completed producer stamped the way
  /// `_completeSuccess` stamps it (same transition that moves the item).
  Future<void> itemAwaitingReview(FileRestartHarness host) async {
    await host.workflowEngine.createWorkItem(
      workItemId: 'wi-1',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Implement calculator add',
      description:
          'Implement the calculator add function for the contract suite',
      qaContractId: 'qa-1',
      featureRef: 'feature/calc',
    );
    const hop = {
      'agentAvailable': true,
      'capabilitiesMatch': true,
      // `planning -> planned` carries the traceability guard.
      'featureRef': 'feature/calc',
    };
    for (final state in [
      WorkItemState.planning,
      WorkItemState.planned,
      WorkItemState.designNotRequired,
      WorkItemState.agentExecuting,
    ]) {
      await host.workflowEngine.transition(
        workItemId: 'wi-1',
        to: state,
        trigger: TransitionTrigger.systemEvent,
        context: hop,
      );
    }
    await host.workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.agentCompleted,
      trigger: TransitionTrigger.agentResult,
      actor: const WorkflowActor(
        actorId: 'orchestrator',
        actorType: ActorType.orchestrator,
      ),
      context: {
        ...hop,
        'qaContractId': 'qa-1',
        'agentResult': _completedResult(),
      },
      metadataMerge: const {'producerActorId': 'exec-impl'},
    );
  }

  /// The coordinator AS IT BEHAVES AFTER THE FIX: the entry edge is taken and
  /// the review runs, so the review comes back for a fresh decision.
  ///
  /// `reviewInProgress -> agentCompleted` is the review lane's retry return, the
  /// same edge B4's `retry_return_to_entry_state_test.dart` covers, so the item
  /// cycles back into the entry state rather than dead-ending.
  ControlledDispatcher fixedCoordinator(FileRestartHarness host) {
    return ControlledDispatcher(
        capabilities: {WorkerCapability.engineeringReview},
      )
      ..resultBuilder = (request) async {
        await host.workflowEngine.transition(
          workItemId: request.workItemId,
          to: WorkItemState.reviewInProgress,
          trigger: TransitionTrigger.agentResult,
          actor: const WorkflowActor(
            actorId: 'orchestrator',
            actorType: ActorType.orchestrator,
          ),
          context: {
            'agentAvailable': true,
            'capabilitiesMatch': true,
            'agentResult': _completedResult(),
          },
        );
        await host.workflowEngine.transition(
          workItemId: request.workItemId,
          to: WorkItemState.agentCompleted,
          trigger: TransitionTrigger.systemEvent,
          actor: const WorkflowActor(
            actorId: 'test',
            actorType: ActorType.orchestrator,
          ),
          context: {
            'agentAvailable': true,
            'capabilitiesMatch': true,
            'agentResult': _completedResult(),
          },
        );
        final t = DateTime.utc(2026, 1, 1, 12);
        return WorkerExecutionResult(
          workerExecutionId: request.workerExecutionId,
          workItemId: request.workItemId,
          status: WorkerExecutionStatus.executedPass,
          workerId: 'w-fixed-1',
          workspaceId: 'ws-1',
          startingRevision: 'deadbeef',
          startedAt: t,
          endedAt: t,
          cleanupStatus: WorkerCleanupStatus.removed,
          failureCode: WorkerFailureCode.none,
          agentResultStatus: AgentResultStatus.completed,
          verificationPassed: true,
          changedFiles: const [],
          endingRevision: 'cafebabe',
        );
      };
  }

  test(
    'an item the coordinator can now move is never stalled, and N ticks leave '
    'exactly ONE job behind',
    () async {
      late FileRestartHarness host;
      final dispatch = ControlledDispatcher(
        capabilities: {WorkerCapability.engineeringReview},
      );
      host = FileRestartHarness(
        dir,
        clock: () => t0,
        dispatch: dispatch,
        definition: engineeringReviewDefinition,
      );
      await itemAwaitingReview(host);
      dispatch.resultBuilder = fixedCoordinator(host).resultBuilder;

      const ticks = 12;
      for (var i = 0; i < ticks; i++) {
        final result = await host.scheduler.tick();
        expect(
          result.stalled,
          isEmpty,
          reason:
              'a lane whose dispatches genuinely move the item must never be '
              'reported as stalled. Before the root-cause fix every dispatch '
              'was refused, which is exactly what the stall was correctly '
              'detecting — the fix removes the refusal, and a stall here would '
              'mean the fix did not take',
        );
      }

      final jobs = await host.jobStore.listJobsForWorkItem('wi-1');
      expect(
        jobs,
        hasLength(1),
        reason:
            'the COUNT is the property, not the final state. This item read '
            'agent_completed while the lane spun at four jobs a minute AND '
            'while it did not, which is why 243 refused attempts went '
            'unnoticed for a whole project. One job after $ticks ticks is the '
            'difference between "reviewed" and "spinning".',
      );

      expect(
        dispatch.runs,
        isNotEmpty,
        reason: 'precondition: the lane really did dispatch work',
      );
    },
  );

  test(
    'the fix does not turn the stall off — an item whose entry edge is STILL '
    'refused keeps exactly one job',
    () async {
      // The complement, re-asserted because the fix changes what the scheduler
      // sees. If wiring the fixed coordinator had somehow disabled the cap,
      // this would go back to one job per tick — and a state assertion would
      // not notice, because the item ends at agent_completed either way.
      final dispatch = ControlledDispatcher()
        ..resultBuilder = (r) async {
          final t = DateTime.utc(2026, 1, 1, 12);
          return WorkerExecutionResult(
            workerExecutionId: r.workerExecutionId,
            workItemId: r.workItemId,
            status: WorkerExecutionStatus.executedFail,
            workerId: 'w-scripted-1',
            workspaceId: 'ws-1',
            startingRevision: 'deadbeef',
            startedAt: t,
            endedAt: t,
            cleanupStatus: WorkerCleanupStatus.removed,
            failureCode: WorkerFailureCode.agentFailed,
            failureDetail:
                '$supersededExecutionMarker Superseded execution: the entry '
                'edge is refused.',
            agentResultStatus: null,
            verificationPassed: null,
            changedFiles: const [],
            endingRevision: null,
          );
        };
      final host = FileRestartHarness(
        dir,
        clock: () => t0,
        dispatch: dispatch,
        definition: engineeringReviewDefinition,
      );
      await itemAwaitingReview(host);

      for (var i = 0; i < 12; i++) {
        await host.scheduler.tick();
      }

      expect(
        await host.jobStore.listJobsForWorkItem('wi-1'),
        hasLength(1),
        reason:
            'the stall is a backstop for items that genuinely cannot move, and '
            'the root-cause fix narrows that population without emptying it',
      );
    },
  );
}
