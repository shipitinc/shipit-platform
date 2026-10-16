import 'package:control_plane_server/server.dart';
import 'package:control_plane_server/src/review/engineering_review_gate.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';
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
///
/// ## THE THIRD GROUP: THE ROUTE THAT ENDS THE DEAD END
///
/// Added by `IMPL-verdict-absent-autoroute` under decision
/// `92d567e3-da03-4c43-99f4-e3726472f0ab` (`REREVIEW -> AUTOMATIC`).
///
/// It lives HERE, and not in the longer file, for the reason this file exists at
/// all: every test in it names no new Dart symbol, so it COMPILES against
/// `184a9ec` — the reviewed HEAD this lane corrected from — and is RED there for
/// a behavioural reason that can be read in the failure output. That is what
/// makes the NON-VACUITY claim checkable by anyone: `git stash` this file and run
/// it, and all six routing tests fail on an assertion about STATE, not on a
/// compile error. A test that cannot compile at the base revision proves
/// nothing about behaviour, only about the diff.
///
/// Both tick orders are run because the previous behaviour of this handler won or
/// lost on `await` ordering alone, and a route that only holds in one order is
/// the same defect wearing a different shape.
void main() {
  test(
    'a COMPLETED review that produced no verdict reaches a person, asserts no '
    'verdict, and moves when answered',
    () async {
      final store = InMemoryWorkflowStore();
      final engine = DurableWorkflowEngine(store: store);
      final executions = InMemoryExecutionStore();
      final jobs = InMemoryJobStore();
      final workers = await _producerCommitted(
        workItemId: 'wi-no-verdict',
        producerActorId: 'agx-wx-impl',
      );

      final now = DateTime.utc(2026, 10, 15, 12);
      await store.saveWorkItem(
        WorkItem(
          workItemId: 'wi-no-verdict',
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'A change nobody could review',
          description: 'The implementer committed; the review said nothing.',
          state: WorkItemState.reviewInProgress,
          metadata: {
            'producerActorId': 'agx-wx-impl',
            // The automatic re-review budget is already spent, so the ROUTE
            // cannot take this item and the fallback decision is what is
            // left. See `_producerCommitted`.
            engineeringReviewAutoRerouteMetadataKey: {
              'productionPass': null,
              'spent': maxAutomaticReviewReroutes,
            },
          },
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
        // Holding the producer's real commit — see `_producerCommitted`. These
        // two hosts are the FALLBACK: a real artifact and a spent automatic
        // re-review budget, which is the only shape in which a person is the
        // right answer now that the route exists.
        workerStore: workers,
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
      final workers = await _producerCommitted(
        workItemId: 'wi-review-crashed',
        producerActorId: 'agx-wx-impl',
      );

      final now = DateTime.utc(2026, 10, 15, 12);
      await store.saveWorkItem(
        WorkItem(
          workItemId: 'wi-review-crashed',
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'A change nobody could review',
          description: 'The implementer committed; the reviewer timed out.',
          state: WorkItemState.reviewInProgress,
          metadata: {
            'producerActorId': 'agx-wx-impl',
            // Spent, for the same reason and with the same consequence as above.
            engineeringReviewAutoRerouteMetadataKey: {
              'productionPass': null,
              'spent': maxAutomaticReviewReroutes,
            },
          },
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
        // Holding the producer's real commit — see `_producerCommitted`. These
        // two hosts are the FALLBACK: a real artifact and a spent automatic
        // re-review budget, which is the only shape in which a person is the
        // right answer now that the route exists.
        workerStore: workers,
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

  // ══════════════════════════════════════════════════════════════════════════
  // AUTOMATIC ROUTING — decision 92d567e3-da03-4c43-99f4-e3726472f0ab.
  //
  // THE OPERATOR'S OWN WORDS, from the live QA database on 2026-10-16:
  //
  //   "An item at review_in_progress whose reviewer concluded nothing raises a
  //    verdict-less Human Decision whose options are exactly
  //    [{"optionId":"rework","label":"Rework"},{"optionId":"reject","label":"Reject"}]"
  //
  //   "how would a reviewer actually review it."
  //
  // That decision is the one `engineeringReviewMissingArtifact` raises, and it
  // is a dead end: `rework` runs the IMPLEMENTATION lane again — discarding a
  // commit that already exists — and `reject` records a reviewer having
  // rejected work no reviewer assessed. Neither reaches a reviewer. The
  // decision resolved `REREVIEW -> AUTOMATIC`: the platform routes, rather than
  // offering a human a third option.
  //
  // EVERY TEST IN THIS GROUP NAMES NO NEW DART SYMBOL — only the handler, the
  // states, the two real schedulers and the log lines, all of which existed at
  // `184a9ec`. That is what makes the NON-VACUITY claim below checkable: a test
  // that cannot compile at the base revision proves nothing about behaviour,
  // only about the diff. `git stash` this file's group against `184a9ec` and all
  // three fail, in both tick orders, with the counts reported in the lane result.
  // ══════════════════════════════════════════════════════════════════════════

  group(
    'the platform ROUTES a review that concluded nothing instead of asking a '
    'human a question nobody asked',
    () {
      // THE ORDER IS NOT THE POINT. Both orders are run because the previous
      // behaviour of this handler won or lost on `await` ordering alone — see
      // `implementation_inflow_tick_order_test.dart`, which pins the same
      // property for the `agentCompleted` stand-down. A route that only holds in
      // one order is the same defect wearing a different shape.
      for (final reviewFirst in const [false, true]) {
        final order = reviewFirst ? 'review first' : 'implementation first';

        test(
          '$order: implementation DID commit -> routed to RE-REVIEW, no '
          'decision raised',
          () async {
            // THE OPERATOR'S OTHER HALF. There IS a revision to review; nobody
            // reviewed it. The old pair could not express that: `rework` throws
            // the commit away and `reject` kills work nobody assessed.
            final host = await _RoutingHost.atReviewInProgress(
              endingRevision: _RoutingHost.producedCommit,
            );

            await host.runReviewGate();

            final routed = await host.item();
            expect(
              routed.state,
              WorkItemState.agentCompleted,
              reason:
                  'review-first is $order. `agentCompleted` is the fan-out both '
                  'lanes read, and it is `engineeringReviewDefinition'
                  '.entryStates`, so the item is back in front of a reviewer. '
                  'At the base revision this item was parked at '
                  'waiting_for_human_decision behind [rework, reject], which '
                  'reaches no reviewer at all',
            );
            expect(
              routed.blockingHumanDecisionId,
              isNull,
              reason:
                  'no question is put to a human about an item the platform can '
                  'move. Asking is not forbidden by the decision; it is simply '
                  'not what happens when the route exists',
            );
            expect(
              await host.workflowStore.readHumanDecisionsForWorkItem(
                _RoutingHost.id,
              ),
              isEmpty,
            );

            // AND THE ROUTE IS REPORTED WITH ITS EVIDENCE. A move between
            // states that leaves no record of WHY is indistinguishable from a
            // move that guessed.
            final route = host.routeLog;
            expect(
              route,
              isNotNull,
              reason: 'the branch that fired was logged',
            );
            expect(route!['route'], 're_review');
            expect(route['artifactProduced'], isTrue);
            expect(
              route['artifactEvidence'],
              contains(_RoutingHost.producedCommit),
              reason:
                  'the evidence is the revision itself. A log line that says '
                  '"routed for re-review" without naming what was found is '
                  'unfalsifiable by the next operator',
            );
            expect(
              route['carriesVerdict'],
              isFalse,
              reason:
                  'a route is not a verdict, and the log line says so in the '
                  'field a reader looks at',
            );

            // AND A REVIEWER REALLY IS DISPATCHED, at the revision the producer
            // left. This is the answer to "how would a reviewer actually review
            // it": the platform routes it, and the real resolver resolves the
            // real commit.
            await host.tickReview();
            final dispatched = host.dispatched(AgentRole.engineeringReviewer);
            expect(
              dispatched,
              isNotEmpty,
              reason:
                  'review-first is $order. The route is only worth taking if '
                  'something acts on it, so this runs the REAL review scheduler '
                  'with the REAL workload resolver rather than asserting a state',
            );
            // EVERY reviewer, at the revision the producer left. Sending one to
            // any other revision is the wrong-revision dispatch this gate exists
            // to prevent, and that is the property — so it is asserted over the
            // whole list rather than on a `single`.
            //
            // Why the COUNT is not asserted here: this fixture's job is
            // `queued`, because it models a review job the scheduler refused to
            // dispatch, which is what `SchedulerTickResult.blockedArtifactMissing`
            // carries. The route stamps the dispatch discriminator, so the lane
            // ALSO mints a fresh job under a key no earlier one holds, and both
            // are dispatchable. In production the exhausted job is TERMINAL and
            // only the fresh one can be dispatched; that shape — and the
            // "exactly one reviewer" property with it — is asserted against a
            // terminal job in
            // `apps/server/test/engineering_review_composition_order_test.dart`.
            expect(
              dispatched.map((r) => r.startingRevision),
              everyElement(_RoutingHost.producedCommit),
            );
          },
        );

        test(
          '$order: implementation produced NOTHING -> routed back to '
          'implementationReady, no decision raised',
          () async {
            final host = await _RoutingHost.atReviewInProgress(
              endingRevision: null,
            );

            await host.runReviewGate();

            final routed = await host.item();
            expect(
              routed.state,
              WorkItemState.agentCompleted,
              reason:
                  'review-first is $order. This is the completion fan-out, and '
                  'it is where the platform stops deciding and starts acting: '
                  '`sched-impl`\'s `completionInflowFrom` IS this state, so the '
                  'implementation lane owns the item on this very tick',
            );
            expect(routed.blockingHumanDecisionId, isNull);

            // THE SECOND HOP IS NOT TAKEN BY THE GATE, and the reason is
            // load-bearing: `agentCompleted -> implementationReady` is written in
            // the same transaction as the dispatch discriminator stamp, so a move
            // taken here without that stamp would re-use an
            // `implementFeatureDedupeKey` the previous implementation job already
            // consumed. So the assertion is on what the REAL inflow does.
            await host.tickImplementation();
            final implemented = await host.item();
            expect(
              implemented.state,
              WorkItemState.implementationReady,
              reason:
                  'review-first is $order. The gate returns the item to the '
                  'fan-out and `completionRouteFor` — the one function that '
                  'already maps a no-commit producer onto this lane — routes it '
                  'to the lane that can do the work that is missing. At the base '
                  'revision this item sat at waiting_for_human_decision for ever',
            );
            expect(implemented.blockingHumanDecisionId, isNull);
            expect(
              implemented.metadata?[DurableWorkflowEngine
                  .triageAttemptMetadataKey],
              isNotNull,
              reason:
                  'and the dispatch discriminator moved with it, in the same '
                  'transaction. A route that leaves the dedupe key unspent is '
                  'a route that enqueues nothing and looks healthy',
            );
            expect(
              host.dispatched(AgentRole.implementer),
              hasLength(1),
              reason:
                  'the implementer is genuinely DISPATCHED for another pass, '
                  'not merely routed and left for a tick nobody is running',
            );

            final route = host.routeLog;
            expect(route, isNotNull);
            expect(route!['route'], 'implementation');
            expect(route['artifactProduced'], isFalse);
            expect(route['carriesVerdict'], isFalse);
            expect(
              route['implementationLaneWillRoute'],
              isTrue,
              reason:
                  'the route claims the lane will take it, and the assertion '
                  'above is the claim being kept. A log that asserted it and a '
                  'platform that did not do it would be the false-state class '
                  'this whole file exists to end',
            );
          },
        );

        test(
          '$order: the artifact CANNOT BE READ -> still reaches a human, and '
          'nothing was routed on an answer nobody established',
          () async {
            // Invariant 4 of this lane, RE-BASELINED. An item whose artifact
            // cannot be determined must NOT be dropped and must NOT be looped:
            // it reaches a person on the decision that was already there.
            //
            // THE INPUT CHANGED AND THE PROPERTY DID NOT. This used to drive the
            // case with the re-work discriminator at its bound and assert the
            // `verdict-absent-not-routed` line that `ReviewGateRoute
            // .humanDecision` emits. Decision
            // `92d567e3-da03-4c43-99f4-e3726472f0ab` answered
            // `RETRY_LIMIT -> REMOVE`, so that bound no longer exists, a
            // no-artifact producer is routed to the implementation lane
            // unconditionally, and `owns: false` now means only "the producer
            // DID commit" — which `reviewGateRouteFor` turns into `reReview`.
            // So `humanDecision` has no input that reaches it, and the case it
            // used to carry is now reached by a DIFFERENT question entirely: not
            // "the lane has no budget" but "the artifact could not be READ".
            //
            // Deleting the assertion would have been the easy way to reach green
            // and would have deleted the only thing this file exists to hold:
            // that automatic routing which cannot route answers with a person.
            // The one input that still cannot be routed on evidence is an
            // unreadable artifact, and it is asserted here instead — on the real
            // handler, through the real store, in both tick orders.
            final host = await _RoutingHost.atReviewInProgress(
              endingRevision: _RoutingHost.producedCommit,
              artifactReadThrows: true,
            );

            await host.runReviewGate();

            // NOTHING WAS ROUTED, and that is the first half of the property.
            // A commit exists here — the fixture produced one — so every other
            // test in this group routes this item. It is NOT routed in this one,
            // because the platform never got to look: the answer is an exception,
            // not a finding. Asserting the ABSENCE of the route log is what
            // distinguishes "parked because it could not be read" from "parked
            // because it was read and still went nowhere".
            expect(
              host.routeLog,
              isNull,
              reason:
                  'review-first is $order. The item is not returned to the '
                  'fan-out on an unreadable answer. Routing here would move a '
                  'work item on the strength of a failure to read, and the '
                  'revision it would route to is precisely what is unknown',
            );
            expect(
              host.eventNamed('engineering-review-verdict-absent-not-routed'),
              isNull,
              reason:
                  'review-first is $order. `ReviewGateRoute.humanDecision` has '
                  'no input that reaches it any more — the caller skips '
                  '`reviewGateRouteFor` entirely when the read fails — so this '
                  'line cannot be what carries this item to a person. Asserted '
                  'so this test cannot quietly keep passing through the branch '
                  'the Human Decision removed',
            );

            // AND THE PARK IS ON THE RECORD.
            expect(
              host.eventNamed('engineering-review-missing-artifact.parked'),
              isNotNull,
              reason:
                  'the platform must SAY that it parked, not merely do it: an '
                  'item that silently stops moving is the failure this whole '
                  'gate exists to end',
            );

            // IT REACHED A PERSON, on the existing decision and unchanged.
            final parked = await host.item();
            expect(
              parked.state,
              WorkItemState.waitingForHumanDecision,
              reason: 'a person is the only thing left who can move this item',
            );
            final decision = await host.workflowStore.readHumanDecision(
              parked.blockingHumanDecisionId!,
            );
            expect(decision.decisionType, HumanDecisionType.engineeringReview);
            expect(decision.blocking, isTrue);
            expect(
              decision.options!.map((o) => o.optionId),
              ['rework', 'reject'],
              reason:
                  'the existing decision, unchanged. A new option set invented '
                  'here would be a third thing this lane could get wrong, and '
                  'the operator did not choose one — they chose AUTOMATIC',
            );
            expect(
              decision.metadata?.containsKey('reviewVerdict'),
              isFalse,
              reason:
                  'the fallback has to keep the anti-fabrication property too: '
                  'reaching a human is not inventing an assessment',
            );
          },
        );
      }
    },
  );
}

/// A producer `WorkerExecution` with a real commit, recorded in [workers], so
/// `producedCommitFor` answers `CommitProduced` for an item stamped with
/// [producerActorId].
///
/// ## WHY THE FIRST TWO TESTS HERE NEED IT
///
/// RE-BASELINED by the B2 correction. They used to carry no producer execution
/// at all, which meant the artifact read answered `producerExecutionMissing` —
/// and the verdict-absent ROUTE sends that to the implementation lane rather
/// than to a person. That is correct: nothing was produced, so there is nothing
/// to review and the implementation lane can do the work.
///
/// These two tests are about the FALLBACK, so their items now carry a real
/// commit AND a spent automatic re-review budget
/// ([engineeringReviewAutoRerouteMetadataKey]). That is the shape the operator's
/// dead end has in production after the platform has already re-reviewed once
/// and that reviewer also concluded nothing — and the shape in which a person is
/// genuinely the right answer.
Future<InMemoryWorkerStore> _producerCommitted({
  required String workItemId,
  required String producerActorId,
}) async {
  final workers = InMemoryWorkerStore();
  await workers.saveWorkerExecution(
    WorkerExecution(
      workerExecutionId: 'wx-impl',
      workItemId: workItemId,
      repositoryPath: '/durable/clone',
      requestedStartingRevision: _startingRevision,
      requiredCapabilities: const {
        WorkerCapability.linux,
        WorkerCapability.git,
      },
      agentExecutionId: producerActorId,
      endingRevision: _producedCommit,
      status: WorkerExecutionStatus.executedPass,
      cleanupPolicy: WorkerCleanupPolicy.removeAlways,
    ),
  );
  return workers;
}

/// The revision a producer execution starts at. Any `endingRevision` equal to it
/// is the "committed nothing" shape, which is the triage report and — after
/// `db6ec6e` — seven IMPLEMENTER runs on the live QA stack.
const _startingRevision = 'aaaaaaa';

/// A real commit, so `_producerCommitted` produces `CommitProduced`.
const _producedCommit = 'c0ffee1';

/// Reports "no compatible worker" so each scheduler BUILDS the request — proving
/// what it would have dispatched — and never runs one. The technique
/// `implementation_inflow_tick_order_test.dart` uses, and the reason the
/// assertions can say "dispatched" about a test that runs no worker.
class _NoWorkerDispatch implements WorkerDispatch {
  final List<WorkerExecutionRequest> requests = [];

  @override
  WorkerSelection select(WorkerExecutionRequest request) {
    requests.add(request);
    return WorkerSelection.noCompatibleWorker();
  }

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) =>
      throw StateError('no execution may run in this file');

  @override
  Future<void> cancel(String workerId, String reason) async {}
}

/// A real-by-construction host for the automatic route.
///
/// Everything is the production object: the real [Scheduler] for both lanes, the
/// real [engineeringReviewWorkloadResolver], the real [implementFeatureDefinition]
/// and [engineeringReviewDefinition], the real [DurableWorkflowEngine], and the
/// real [engineeringReviewMissingArtifact]. The only fake is the worker dispatch.
///
/// The item is at `reviewInProgress` throughout, which is where the operator
/// found theirs and the only state this handler routes from.
class _RoutingHost {
  _RoutingHost._({
    required this.workflowStore,
    required this.engine,
    required this.workerStore,
    required this.executionStore,
    required this.jobStore,
    required this.job,
    required this.dispatch,
    required this.implScheduler,
    required this.reviewScheduler,
  });

  static const workItemId = 'wi-verdict-absent-autoroute';
  static const producerExecutionId = 'agx-wx-impl';
  static const producedCommit = 'c0ffee1';
  static final _now = DateTime.utc(2026, 10, 16, 11);

  /// An item a reviewer entered and that concluded nothing.
  ///
  /// [endingRevision] is the whole experiment: a commit that differs from
  /// [_startingRevision] is an artifact, and anything else — null included — is
  /// the "it produced a report, not an artifact" shape. Both are written the way
  /// `LocalWorker` writes them, against the same `producerActorId` the coordinator
  /// stamps, because [producedCommitFor] joins the two records on exactly that
  /// pair and refuses to guess.
  ///
  /// The producer's own [AgentExecution] and result are recorded because the
  /// re-review dispatch's `agentResultValid()` guard needs them. Without them the
  /// route would still be taken and the reviewer still refused, which would be a
  /// second, quieter version of a dead end.
  ///
  /// [artifactReadThrows] makes the one durable read this whole gate decides on
  /// fail, which is the input that reaches the human fallback. It is simulated
  /// on the store rather than by stubbing `producedCommitFor`, because the
  /// handler catches that read itself: a test that replaced the function would
  /// not be running the code that has to survive the exception, which is the
  /// entire reason `_readProducedCommit` exists.
  static Future<_RoutingHost> atReviewInProgress({
    required String? endingRevision,
    Map<String, dynamic> extraMetadata = const {},
    bool artifactReadThrows = false,
  }) async {
    final workflowStore = InMemoryWorkflowStore();
    final durableWorkerStore = InMemoryWorkerStore();
    final workerStore = artifactReadThrows
        ? _UnreadableWorkerStore(durableWorkerStore)
        : durableWorkerStore;
    final executionStore = InMemoryExecutionStore();
    final jobStore = InMemoryJobStore();
    final dispatch = _NoWorkerDispatch();

    await workflowStore.saveWorkItem(
      WorkItem(
        workItemId: workItemId,
        productId: 'prod-1',
        category: WorkItemCategory.bugfix,
        title: 'A defect whose reviewer concluded nothing',
        description: 'The implementer ran; the reviewer said nothing.',
        state: WorkItemState.reviewInProgress,
        metadata: {
          'producerActorId': producerExecutionId,
          ...extraMetadata,
        },
        createdAt: _now,
        updatedAt: _now,
      ),
    );

    await workerStore.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: 'wx-impl',
        workItemId: workItemId,
        repositoryPath: '/durable/clone',
        requestedStartingRevision: _startingRevision,
        requiredCapabilities: const {
          WorkerCapability.linux,
          WorkerCapability.git,
        },
        agentExecutionId: producerExecutionId,
        endingRevision: endingRevision,
        status: WorkerExecutionStatus.executedPass,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
      ),
    );
    await executionStore.saveExecution(
      AgentExecution(
        executionId: producerExecutionId,
        workItemId: workItemId,
        requestId: 'req-impl',
        runtimeTypeId: 'rt-impl',
        role: AgentRole.implementer,
        status: AgentSessionStatus.completed,
        sessionId: 'ses-impl',
        resultId: 'res-impl',
        workspace: const AgentWorkspace(
          workspaceId: 'ws-impl',
          path: '/durable/clone',
          startingRevision: _startingRevision,
        ),
        startedAt: _now,
        completedAt: _now,
      ),
    );
    await executionStore.saveResult(
      producerExecutionId,
      AgentResult(
        resultId: 'res-impl',
        sessionId: 'ses-impl',
        workItemId: workItemId,
        executionId: producerExecutionId,
        role: AgentRole.implementer,
        status: AgentResultStatus.completed,
        artifacts: const [],
        diagnostics: const AgentDiagnostics(
          exitCode: 0,
          durationMs: 1,
          toolCalls: 1,
          errors: [],
          warnings: [],
        ),
        structuredResult: const {},
        summary: 'implementer run',
        completedAt: _now,
      ),
    );

    // A real `JobQueue`-minted job, exactly as the composition root reads it
    // back out of `SchedulerTickResult.blockedArtifactMissing` and hands to the
    // handler. Minted rather than written as a literal so `attempt`/`maxAttempts`
    // are the definition's.
    final enqueued = await JobQueue(store: jobStore).enqueueIfAbsent(
      workItemId: workItemId,
      definition: engineeringReviewDefinition,
      dedupeKey: '$workItemId:engineering_review',
      instruction: 'Review the produced artifact.',
    );
    await jobStore.saveJob(enqueued.job);

    final workload = SchedulerWorkload(
      repositoryPath: '/durable/clone',
      startingRevision: _startingRevision,
      timeoutSeconds: 1800,
      runtimeTypeId: 'rt-review',
    );
    DateTime clock() => _now;

    return _RoutingHost._(
      workflowStore: workflowStore,
      engine: DurableWorkflowEngine(store: workflowStore),
      workerStore: workerStore,
      executionStore: executionStore,
      jobStore: jobStore,
      job: enqueued.job,
      dispatch: dispatch,
      implScheduler: Scheduler(
        schedulerId: 'sched-impl',
        workflowStore: workflowStore,
        jobStore: jobStore,
        workerStore: workerStore,
        dispatch: dispatch,
        definition: implementFeatureDefinition,
        workload: workload,
        dedupeKeyBuilder: implementFeatureDedupeKey,
        instructionBuilder: implementFeatureInstruction,
        requestBuilder: implementFeatureRequest,
        workloadResolver: (job, item) async => workload,
        clock: clock,
      ),
      reviewScheduler: Scheduler(
        schedulerId: 'sched-review',
        workflowStore: workflowStore,
        jobStore: jobStore,
        workerStore: workerStore,
        dispatch: dispatch,
        definition: engineeringReviewDefinition,
        workload: workload,
        dedupeKeyBuilder: engineeringReviewDedupeKey,
        instructionBuilder: engineeringReviewInstruction,
        requestBuilder: engineeringReviewRequest,
        workloadResolver: engineeringReviewWorkloadResolver(
          workerStore: workerStore,
          runtimeTypeId: 'rt-review',
          // The one production budget, named so the resolver holds no literal of
          // its own. See `AgentExecutionBudgets` — PROVISIONAL.
          timeoutSeconds: AgentExecutionBudgets.engineeringReviewSeconds,
        ),
        clock: clock,
      ),
    );
  }

  final InMemoryWorkflowStore workflowStore;
  final DurableWorkflowEngine engine;
  final WorkerStore workerStore;
  final InMemoryExecutionStore executionStore;
  final InMemoryJobStore jobStore;
  final Job job;
  final _NoWorkerDispatch dispatch;
  final Scheduler implScheduler;
  final Scheduler reviewScheduler;
  final List<(String, Map<String, dynamic>)> loggedEvents = [];

  Future<void> runReviewGate() => engineeringReviewMissingArtifact(
    workflowEngine: engine,
    executionStore: executionStore,
    workerStore: workerStore,
    job: job,
    logger: (message, context) => loggedEvents.add((message, context)),
  );

  Future<void> tickReview() => reviewScheduler.tick().then((_) {});
  Future<void> tickImplementation() => implScheduler.tick().then((_) {});

  Future<WorkItem> item() => engine.loadWorkItem(workItemId);

  /// The one work item id, for callers outside the class.
  static const id = workItemId;

  List<WorkerExecutionRequest> dispatched(AgentRole role) =>
      dispatch.requests.where((r) => r.role == role).toList(growable: false);

  Map<String, dynamic>? eventNamed(String name) {
    for (final entry in loggedEvents) {
      if (entry.$1 == name) return entry.$2;
    }
    return null;
  }

  /// The log line for the branch that actually FIRED — as opposed to the branch
  /// that did not. A test that read `not-routed` would pass on a run where
  /// nothing was routed at all.
  Map<String, dynamic>? get routeLog =>
      eventNamed('engineering-review-verdict-absent-routed');
}

/// A [WorkerStore] whose ONE read the artifact predicate depends on fails.
///
/// `producedCommitFor` reaches durable state through exactly one call —
/// `listWorkerExecutions` — and this fails that and nothing else. So the
/// fixture underneath is a real store holding a real commit, and the handler
/// cannot tell the difference between "there was nothing" and "I could not
/// look", which is the whole point: the second must not be read as the first.
///
/// It throws rather than returning empty on purpose. An empty list is a
/// legible answer and takes the `producerExecutionMissing` branch, which the
/// gate routes; only an exception produces the `produced == null` the human
/// fallback is written for.
class _UnreadableWorkerStore implements WorkerStore {
  _UnreadableWorkerStore(this._inner);

  final WorkerStore _inner;

  @override
  Future<List<WorkerExecution>> listWorkerExecutions() =>
      throw const _DurableStateUnreadable();

  @override
  Future<T> inTransaction<T>(Future<T> Function(WorkerStore store) body) =>
      _inner.inTransaction(body);

  @override
  Future<void> saveWorkerExecution(
    WorkerExecution execution, {
    int? expectedVersion,
  }) => _inner.saveWorkerExecution(execution, expectedVersion: expectedVersion);

  @override
  Future<WorkerExecution?> readWorkerExecution(String id) =>
      _inner.readWorkerExecution(id);

  @override
  Future<void> saveResult(WorkerExecutionResult result) =>
      _inner.saveResult(result);

  @override
  Future<WorkerExecutionResult?> readResult(String id) => _inner.readResult(id);

  @override
  Future<void> appendEvent(WorkerEventRecord event) =>
      _inner.appendEvent(event);

  @override
  Future<List<WorkerEventRecord>> readEvents(String id) =>
      _inner.readEvents(id);
}

/// The shape a real durable read fails with. Named so the parking log line
/// carries a cause an operator can recognise rather than a bare `StateError`.
class _DurableStateUnreadable implements Exception {
  const _DurableStateUnreadable();

  @override
  String toString() =>
      'durable worker state is unreadable: the worker store could not be '
      'listed, so no artifact can be confirmed OR denied';
}
