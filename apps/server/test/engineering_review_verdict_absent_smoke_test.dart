import 'package:control_plane_server/src/review/engineering_review_gate.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

/// ## WHY THIS FILE IS SEPARATE, AND WHY IT IS SHORT
///
/// Everything else about this change lives in
/// `engineering_review_verdict_absent_decision_test.dart`, which names the new
/// API (`reviewVerdictAbsentMetadataKey`, `isVerdictAbsentDecision`, …) and
/// therefore cannot COMPILE against `2b29bdd` — the reviewed HEAD this lane
/// corrected from. A test that cannot compile at the base revision proves
/// nothing about behaviour, only about the diff.
///
/// This file names NO new symbol. Everything it touches existed at `2b29bdd`, so
/// it can be run against that revision unchanged, and it is RED there for a
/// reason worth reading:
///
/// ```
/// $ git stash && dart test test/engineering_review_verdict_absent_smoke_test.dart
///   Expected: <null>
///     Actual: 'wi-no-verdict'
///   a completed review that produced no verdict left the item at
///   review_in_progress with no decision and nothing on any operator screen
/// ```
///
/// That is the four parked items, in one assertion. The longer file proves the
/// decision is honest, distinguishable, idempotent and recoverable; this one
/// proves the thing happens at all.
///
/// The reviewer shape is the one QA actually recorded: `end_turn`, `{}` in
/// `structuredResultJson`, ~2000 bytes of markdown in `summary`, against a real
/// commit.
///
/// The second test is the THIRD stranded class, measured on the same day: a
/// review job that failed PERMANENTLY. It is here for the same reason as the
/// first — it names no new symbol, and it is one assertion that the thing
/// happens at all.
void main() {
  test(
    'a COMPLETED review that produced no verdict reaches a person, asserts no '
    'verdict, and moves when answered',
    () async {
      final store = InMemoryWorkflowStore();
      final engine = DurableWorkflowEngine(store: store);
      final executions = InMemoryExecutionStore();
      final jobs = InMemoryJobStore();

      final now = DateTime.utc(2026, 10, 15, 12);
      await store.saveWorkItem(
        WorkItem(
          workItemId: 'wi-no-verdict',
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'A change nobody could review',
          description: 'The implementer committed; the review said nothing.',
          state: WorkItemState.reviewInProgress,
          metadata: const {'producerActorId': 'agx-wx-impl'},
          createdAt: now,
          updatedAt: now,
        ),
      );

      final enqueued = await JobQueue(store: jobs).enqueueIfAbsent(
        workItemId: 'wi-no-verdict',
        definition: engineeringReviewDefinition,
        dedupeKey: 'wi-no-verdict:engineering_review:a0',
        instruction: 'Review the implementation.',
      );
      final job = enqueued.job.copyWith(
        state: JobState.succeeded,
        executionReference: JobExecutionReference(
          workerExecutionId: 'wx-review',
          agentExecutionId: 'agx-wx-review',
          createdAt: now,
        ),
      );
      await jobs.saveJob(job);

      // The reviewer's own execution, terminal and COMPLETED.
      await executions.saveExecution(
        AgentExecution(
          executionId: 'agx-wx-review',
          workItemId: 'wi-no-verdict',
          requestId: 'agx-wx-review',
          runtimeTypeId: 'eng-review-runtime',
          role: AgentRole.engineeringReviewer,
          status: AgentSessionStatus.completed,
          workspace: const AgentWorkspace(
            workspaceId: 'ws-review',
            path: '/worktrees/review',
            startingRevision: '18ad90a',
          ),
          startedAt: now,
          completedAt: now,
        ),
      );
      // And the result it actually left: `{}` in the structured payload, real
      // findings in the summary. Exactly what four reviewers wrote on 2026-10-15.
      await executions.saveResult(
        'agx-wx-review',
        AgentResult(
          resultId: 'res-1',
          sessionId: 'ses-review',
          workItemId: 'wi-no-verdict',
          executionId: 'agx-wx-review',
          role: AgentRole.engineeringReviewer,
          status: AgentResultStatus.completed,
          artifacts: const [],
          diagnostics: AgentDiagnostics(
            exitCode: 0,
            durationMs: 160000,
            toolCalls: 41,
            errors: const [],
            warnings: const [],
          ),
          structuredResult: const {},
          summary:
              '## Engineering Review\n\n'
              'I read the diff on 18ad90a. The _DesktopSkeletonRow is given a '
              'column count of 5 while the header reserves 6; at the 1280px '
              'breakpoint the trailing cell wraps and every row below is offset '
              'by 4px. This is blocking.',
          completedAt: now,
        ),
      );

      await engineeringReviewTickHandler(
        workflowEngine: engine,
        executionStore: executions,
        logger: (message, context) {},
      )(job);

      // 1. THERE IS SOMETHING TO ACT ON. At 2b29bdd this is null, and the item
      //    is still at review_in_progress with no decision and no operator
      //    affordance of any kind.
      final item = await engine.loadWorkItem('wi-no-verdict');
      expect(
        item.blockingHumanDecisionId,
        isNotNull,
        reason:
            'a completed review with no verdict left the item at '
            'review_in_progress with no decision and nothing on any operator '
            'screen. The job SUCCEEDED, so maxAttempts never retries it. This '
            'is decision c495e02f-5c5d-4b45-8124-42ad0e90d6d4, option A',
      );
      expect(item.state, WorkItemState.waitingForHumanDecision);

      final decision = await store.readHumanDecision(
        item.blockingHumanDecisionId!,
      );

      // 2. IT ASSERTS NO VERDICT. The invariant is "no decision asserts a
      //    verdict that was not parsed" — not "no decision exists without one".
      expect(
        decision.metadata?.containsKey('reviewVerdict'),
        isFalse,
        reason:
            'no key a reader could mistake for an assessment may exist here, '
            'not even carrying null',
      );
      expect(
        decision.metadata?.containsKey('engineeringReviewResult'),
        isFalse,
        reason: 'a result object would classify this as an assessed review',
      );
      expect(
        decision.recommendation,
        isNot(anyOf('APPROVE', 'CHANGES_REQUIRED')),
        reason: 'the recommendation is rendered under "WHAT WE SUGGEST"',
      );

      // 3. THE OPERATOR CAN SEE WHAT ACTUALLY HAPPENED, AND CAN ACT.
      expect(
        decision.question,
        contains('The _DesktopSkeletonRow is given a column count of 5'),
        reason:
            'the reviewer did real work against a real commit. Hiding its prose '
            'would replace one false state with another',
      );
      final moved = await engine.resolveHumanDecision(
        decisionId: decision.decisionId,
        choice: HumanDecisionChoice.rework,
        decider: 'operator@example.com',
        rationale: 'It said real things in prose; have it reviewed properly.',
        signature: DecisionSignature(
          algorithm: 'test',
          publicKey: 'test',
          signature: 'test',
          signedAt: now,
        ),
      );
      expect(
        moved.state,
        WorkItemState.implementationReady,
        reason:
            'engineeringReview/rework is the implementation lane\'s entry state: '
            'the work runs again and is reviewed again',
      );
    },
  );

  test(
    'a review job that failed PERMANENTLY reaches a person, and the decision '
    'still asserts no verdict',
    () async {
      // `defect-DEF-DEF-1791685024220546` / `-DEF-1791686357139031`, verbatim:
      // `AgpTransportException: ACP request timed out`, job `failed` with
      // `kind: permanent`.
      //
      // The old trigger was `execution.status == completed`, and a permanent
      // failure settles `failed` — so it never matched, no decision was raised,
      // and nothing else could move the item: `reviewInProgress` is not in
      // `engineeringReviewDefinition.entryStates`, so `RunnableWorkEvaluator`
      // answers `noAction` before any policy probe.
      final store = InMemoryWorkflowStore();
      final engine = DurableWorkflowEngine(store: store);
      final executions = InMemoryExecutionStore();
      final jobs = InMemoryJobStore();

      final now = DateTime.utc(2026, 10, 15, 12);
      await store.saveWorkItem(
        WorkItem(
          workItemId: 'wi-review-crashed',
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'A change nobody could review',
          description: 'The implementer committed; the reviewer timed out.',
          state: WorkItemState.reviewInProgress,
          metadata: const {'producerActorId': 'agx-wx-impl'},
          createdAt: now,
          updatedAt: now,
        ),
      );

      final enqueued = await JobQueue(store: jobs).enqueueIfAbsent(
        workItemId: 'wi-review-crashed',
        definition: engineeringReviewDefinition,
        dedupeKey: 'wi-review-crashed:engineering_review:a0',
        instruction: 'Review the implementation.',
      );
      // Exactly what `Scheduler._adopt` writes for `permanent`: completed
      // `failed`, no `scheduleRetry`, so no retry is owed by anything.
      final job = enqueued.job.copyWith(
        state: JobState.failed,
        failure: const JobFailure(
          code: JobFailureCode.executionFailed,
          kind: JobFailureKind.permanent,
          reason: 'AgpTransportException: ACP request timed out',
        ),
        executionReference: JobExecutionReference(
          workerExecutionId: 'wx-review',
          agentExecutionId: 'agx-wx-review',
          createdAt: now,
        ),
      );
      await jobs.saveJob(job);

      // The reviewer's own execution: terminal, FAILED, and — as on the live
      // victims — it never wrote a result.
      await executions.saveExecution(
        AgentExecution(
          executionId: 'agx-wx-review',
          workItemId: 'wi-review-crashed',
          requestId: 'agx-wx-review',
          runtimeTypeId: 'eng-review-runtime',
          role: AgentRole.engineeringReviewer,
          status: AgentSessionStatus.failed,
          workspace: const AgentWorkspace(
            workspaceId: 'ws-review',
            path: '/worktrees/review',
            startingRevision: '18ad90a',
          ),
          startedAt: now,
          completedAt: now,
          reason: 'AgpTransportException: ACP request timed out',
        ),
      );

      await engineeringReviewTickHandler(
        workflowEngine: engine,
        executionStore: executions,
        logger: (message, context) {},
      )(job);

      // 1. THERE IS SOMETHING TO ACT ON. Without this the item sits at
      //    review_in_progress for ever, which is the defect.
      final item = await engine.loadWorkItem('wi-review-crashed');
      expect(
        item.blockingHumanDecisionId,
        isNotNull,
        reason:
            'a permanently failed review job is terminal on BOTH sides: there is '
            'no verdict, and no retry is owed. Nothing in the platform can move '
            'this item again, so only a person can.',
      );
      expect(item.state, WorkItemState.waitingForHumanDecision);

      final decision = await store.readHumanDecision(
        item.blockingHumanDecisionId!,
      );

      // 2. IT STILL ASSERTS NO VERDICT. Reaching a human is not inventing an
      //    assessment — that is the whole invariant of this file.
      expect(decision.metadata?.containsKey('reviewVerdict'), isFalse);
      expect(
        decision.metadata?.containsKey('engineeringReviewResult'),
        isFalse,
      );
      expect(
        decision.recommendation,
        isNot(anyOf('APPROVE', 'CHANGES_REQUIRED')),
        reason: 'the recommendation is rendered under "WHAT WE SUGGEST"',
      );

      // 3. AND IT NEVER CLAIMS A REVIEW RAN THAT DID NOT. The completed-review
      //    text says "ran to completion"; repeating that here would be a
      //    confident sentence about a fact nobody established.
      expect(decision.question, isNot(contains('ran to completion')));
      expect(decision.question, contains('did not finish'));
      expect(
        decision.question,
        contains('AgpTransportException: ACP request timed out'),
        reason:
            'the raw worker text survives only on `JobFailure.reason`, and it is '
            'what an operator is choosing between when they pick rework or '
            'cancel',
      );
    },
  );
}
