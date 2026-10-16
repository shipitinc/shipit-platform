/// BLOCKER B2: the automatic route was built, tested green, and UNREACHABLE.
///
/// ## WHAT WENT WRONG, AND WHY ONLY A TEST LIKE THIS ONE COULD HAVE CAUGHT IT
///
/// Independent review returned `DO_NOT_MERGE` on `integrate/combined-3@43b2faa`
/// with this finding, and it is the most serious kind: the operator's directive
/// was not delivered. Decision `92d567e3-da03-4c43-99f4-e3726472f0ab`
/// (`ARCHITECTURE`, `RESOLVED`) answered `REREVIEW -> AUTOMATIC` — "platform
/// routes automatically" — and the reviewer's words for the dead end it was
/// meant to end were
///
/// > how would a reviewer actually review it.
///
/// The route existed, was reviewed, and every test of it was green. It was also
/// dead in production, for TWO independent reasons, and neither is visible from
/// a test that calls one handler in isolation:
///
///  1. **ORDER.** The composition root drains terminal review jobs to
///     `engineeringReviewTickHandler` FIRST and only then walks
///     `SchedulerTickResult.blockedArtifactMissing`. The handler parked the item
///     at `waitingForHumanDecision`, so by the time `engineeringReviewMissing-
///     Artifact` — which holds the route — was called, it returned at its very
///     first guard on an already-parked item. The new `reviewInProgress` branch
///     could not run.
///  2. **STRUCTURE.** `blockedArtifactMissing` is populated by
///     `Scheduler._dispatchOne` while dispatching a job this lane minted from
///     `entryStates = {agentCompleted}`, and the review lane's entry hop is a
///     no-op for such an item because the edge `agentCompleted ->
///     reviewInProgress` exists. So NO job can ever be `blockedArtifactMissing`
///     for an item at `reviewInProgress`, and that branch had no input at all.
///
/// So this file drives [runReviewLaneTick] — the composition root's own review
/// section, extracted for exactly this purpose — against the real [Scheduler]
/// for both lanes, the real workload resolvers, the real queue, and real
/// durable rows. It does not reproduce the order in a test-local replica, which
/// would drift on the next edit and re-open the same hole.
///
/// ## THE PROPERTY ASSERTED, IN ONE SENTENCE
///
/// A reviewer that concludes nothing, whose job is TERMINAL, whose item is at
/// `reviewInProgress`, and whose producer left a real commit is ROUTED — not
/// parked — when the composition root runs in its production order, and a
/// reviewer is genuinely dispatched afterwards at the revision the producer
/// left.
///
/// The two shapes of "cannot route" are asserted too, because a route that
/// cannot route is a dropped work item: the spent automatic re-review budget
/// and the unreadable artifact both still reach a person.
library;

import 'package:control_plane_server/server.dart';
import 'package:control_plane_server/src/review/engineering_review_gate.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';
import 'package:workflow_store/workflow_store.dart';

void main() {
  group('the REAL composition order routes a review that concluded nothing', () {
    // THE PRODUCED-COMMIT CASE, and the operator's own dead end: there IS a
    // revision to review, nobody reviewed it, and the decision it used to raise
    // offered exactly `[rework, reject]` — neither of which reaches a reviewer.
    test(
      'a permanently failed review job ROUTES to a fresh reviewer, and no '
      'blocking human decision is raised',
      () async {
        final host = await _CompositionHost.withExhaustedReview(
          producerEndingRevision: _CompositionHost.producedCommit,
        );

        // The item as the operator found it: `reviewInProgress`, a terminal
        // review job, nothing on any operator screen.
        expect(
          (await host.item).state,
          WorkItemState.reviewInProgress,
          reason:
              'the starting point, asserted so the test cannot pass by accident',
        );

        await host.runCompositionTick();

        // 1. IT ROUTED. Not parked — routed, to the lane that can act.
        final routed = await host.item;
        expect(
          routed.state,
          WorkItemState.agentCompleted,
          reason:
              'the whole point. At the reviewed HEAD this item was at '
              'waiting_for_human_decision behind `[rework, reject]`, which '
              'reaches no reviewer and no implementer',
        );
        expect(
          routed.blockingHumanDecisionId,
          isNull,
          reason:
              'the operator\'s directive was AUTOMATIC routing, not a third '
              'option on a human decision',
        );
        expect(
          await host.workflowStore.readHumanDecisionsForWorkItem(
            _CompositionHost.workItemId,
          ),
          isEmpty,
          reason:
              'no question was put to anybody about an item the platform can move',
        );

        // 2. THROUGH THE REAL ORDER, and the log line says so.
        expect(
          host.eventNamed('engineering-review-verdict-absent-routed')?['route'],
          're_review',
        );
        expect(
          host.eventNamed('engineering-review-gate-no-verdict-decision'),
          isNull,
          reason:
              'the raise is AFTER the route and returns with it. A log claiming '
              'a decision was raised on a routed item is the false-state class '
              'this file exists to end',
        );

        // 3. AND A REVIEWER REALLY IS DISPATCHED. A route to a consumed dedupe
        //    key would leave the item at `agentCompleted` with an artifact
        //    nobody has read, no job, and no operator screen — the silent no-op
        //    class, and WORSE than the decision it replaced because a human at
        //    least saw the decision.
        await host.tickReview();
        final reviewers = host.dispatched(AgentRole.engineeringReviewer);
        expect(
          reviewers,
          hasLength(1),
          reason:
              'exactly one, and the exhausted job cannot be it: it is terminal. '
              'This is the assertion the reviewed HEAD could not have passed — '
              'its route moved the item without spending the dispatch '
              'discriminator, so the lane minted nothing and this list was '
              'empty',
        );
        expect(
          reviewers.single.startingRevision,
          _CompositionHost.producedCommit,
          reason:
              'at the revision the producer left. Sending a reviewer to any '
              'other revision is the wrong-revision dispatch the gate exists to '
              'prevent, and it is the answer to "how would a reviewer actually '
              'review it"',
        );
      },
    );

    test(
      'the route is taken from the DRAIN, not from the blocked-artifact loop — '
      'the branch that could never run',
      () async {
        // WHY THIS TEST EXISTS SEPARATELY, even though it looks redundant.
        //
        // The route has to arrive through the drain, because
        // `blockedArtifactMissing` structurally cannot carry an item at
        // `reviewInProgress`. Asserting it indirectly would let that regress
        // back to "unreachable but passing", so this pins WHICH handler ran:
        // the job is terminal and `queued`-free, so it is in the drain's
        // `terminal` set, and the drain's outcome names it.
        final host = await _CompositionHost.withExhaustedReview(
          producerEndingRevision: _CompositionHost.producedCommit,
        );

        final result = await host.runCompositionTick();

        expect(
          result.drain.succeededJobIds,
          contains(host.job.jobId),
          reason:
              'the terminal review job was handed to `engineeringReviewTick-'
              'Handler` by the drain. `blockedArtifactMissing` is populated '
              'only for jobs still `queued` at `agentCompleted`, so this job '
              'cannot be in it, and a fix that put the route only behind the '
              'blocked-artifact loop would leave this list empty',
        );
        expect(
          result.missingArtifactJobIds,
          isEmpty,
          reason:
              'and it never appears on that channel at all, for the same '
              'structural reason. This is the finding, made executable',
        );

        // AND THE DRAIN IS WHAT ACTED. Without this the test asserts only that
        // the job travelled on a particular channel, which is true of the
        // reviewed build too — it parked the item from that same drain. The
        // channel is how the route becomes reachable; what it does is the part
        // the operator's directive is about.
        expect(
          (await host.item).state,
          WorkItemState.agentCompleted,
          reason:
              'routed by the drain. At the reviewed HEAD this item left the '
              'same drain parked at `waitingForHumanDecision`, which is how a '
              'feature can be complete, reviewed, green and dead',
        );
      },
    );

    test(
      'a reviewer that produced NOTHING is routed to the implementation lane, '
      'and the lane really dispatches an implementer',
      () async {
        final host = await _CompositionHost.withExhaustedReview(
          producerEndingRevision: null,
        );

        await host.runCompositionTick();

        // The decision the operator complained about "neither reaches
        // implementation". This is the branch that reaches it.
        expect((await host.item).state, WorkItemState.agentCompleted);
        expect((await host.item).blockingHumanDecisionId, isNull);
        expect(
          host.eventNamed('engineering-review-verdict-absent-routed')?['route'],
          'implementation',
        );

        await host.tickImplementation();
        final reimplemented = await host.item;
        expect(
          reimplemented.state,
          WorkItemState.implementationReady,
          reason:
              'the second hop is the implementation lane\'s own completion '
              'inflow, which advances the dispatch discriminator in the same '
              'transaction. The gate returns the item to the fan-out and lets '
              'the component that owns the decision make it',
        );
        expect(
          reimplemented.metadata?[DurableWorkflowEngine
              .triageAttemptMetadataKey],
          isNotNull,
          reason:
              'and the key moved with it, so the re-run is not a silent no-op',
        );
        expect(host.dispatched(AgentRole.implementer), hasLength(1));
      },
    );
  });

  group('automatic routing that CANNOT route still reaches a person', () {
    // Invariant 4 of this lane, and the reason `ReviewGateRoute.humanDecision`
    // exists at all. A route that cannot route is a dropped work item, and a
    // dropped work item is the failure this whole gate was written to end.
    //
    // At the reviewed HEAD this member of the enum had NO input that reached it:
    // `reviewGateRouteFor` turned every `CommitProduced` into `reReview`
    // unconditionally. The B2 correction gave it one, and these two tests are
    // the reason the correction may claim it.

    test(
      'the automatic re-review budget is spent, so a second verdict-absent '
      'review reaches a human instead of re-arming the lane for ever',
      () async {
        final host = await _CompositionHost.withExhaustedReview(
          producerEndingRevision: _CompositionHost.producedCommit,
        );

        // Tick 1 spends the budget and routes.
        await host.runCompositionTick();
        expect((await host.item).state, WorkItemState.agentCompleted);
        expect(
          host.eventNamed(
            'engineering-review-verdict-absent-routed',
          )?['automaticReroutesSpent'],
          maxAutomaticReviewReroutes,
          reason: 'the route reports what it SPENT, not merely what it allows',
        );

        // The fresh reviewer runs and also concludes nothing, on a real commit.
        await host.tickReview();
        await host.failTheReroutedReviewWithNothingSaid();

        // Tick 2: the budget is gone, so the item must reach a person.
        //
        // The log buffer is reset first, because `eventNamed` reads the FIRST
        // match and tick 1 legitimately logged a route. Asserting on tick 1's
        // line here would be asserting that the budget was NOT spent, which is
        // the opposite of what this test is for.
        host.resetLogs();
        await host.runCompositionTick();

        final parked = await host.item;
        expect(
          parked.state,
          WorkItemState.waitingForHumanDecision,
          reason:
              'an unbounded automatic re-arm would be an unbounded automatic '
              'LLM retry loop — the thing `RetryPolicy` and '
              '`engineeringReviewDefinition.maxAttempts` exist to prevent, and '
              'what the operator\'s own principle forbids. The reviewers that '
              'reached this gate died on `AgpTransportException: ACP request '
              'timed out`; a second attempt at the same transport is the same '
              'transport',
        );
        expect(parked.blockingHumanDecisionId, isNotNull);
        expect(
          host.eventNamed('engineering-review-verdict-absent-routed'),
          isNull,
          reason: 'no route was taken on the spent budget',
        );
        expect(
          host.eventNamed(
            'engineering-review-verdict-absent-not-routed',
          )?['maxAutomaticReroutes'],
          maxAutomaticReviewReroutes,
        );

        final decision = await host.workflowStore.readHumanDecision(
          parked.blockingHumanDecisionId!,
        );
        expect(decision.blocking, isTrue);
        expect(
          decision.metadata?.containsKey('reviewVerdict'),
          isFalse,
          reason:
              'reaching a human is not inventing an assessment. The fallback '
              'carries the same anti-fabrication property the route does',
        );
      },
    );

    test(
      'an artifact that CANNOT BE READ is not routed on — the answer is an '
      'exception, not a finding',
      () async {
        final host = await _CompositionHost.withExhaustedReview(
          producerEndingRevision: _CompositionHost.producedCommit,
          artifactReadThrows: true,
        );

        await host.runCompositionTick();

        final parked = await host.item;
        expect(
          parked.state,
          WorkItemState.waitingForHumanDecision,
          reason:
              'a commit exists in the fixture, so every other test routes this '
              'item. It is not routed here because the platform never got to '
              'look, and the revision it would route to is exactly what is '
              'unknown',
        );
        expect(
          host.eventNamed('engineering-review-verdict-absent-routed'),
          isNull,
          reason:
              'asserting the ABSENCE of the route log is what distinguishes '
              '"parked because it could not be read" from "parked because it '
              'was read and still went nowhere"',
        );
        expect(
          host.eventNamed(
            'engineering-review-gate-no-verdict-decision',
          )?['outcome'],
          'raised',
          reason: 'and the fallback decision IS raised, so the human sees it',
        );

        // AND IT IS A FALLBACK, NOT THE ONLY BEHAVIOUR. The identical host with
        // a READABLE artifact routes and parks nobody — that contrast is what
        // proves this test is measuring the unreadable answer rather than
        // asserting a general "no route happens" rule that would also pass
        // against a build that never routes at all.
        final readable = await _CompositionHost.withExhaustedReview(
          producerEndingRevision: _CompositionHost.producedCommit,
        );
        await readable.runCompositionTick();
        expect(
          (await readable.item).state,
          WorkItemState.agentCompleted,
          reason: 'same fixture, readable artifact: routed, not parked',
        );
        expect(
          await readable.workflowStore.readHumanDecisionsForWorkItem(
            _CompositionHost.workItemId,
          ),
          isEmpty,
        );
      },
    );
  });

  group('a route fabricates no verdict, through the real order', () {
    // The b1 invariant, restated on the branch this correction moved rather than
    // re-proved where it already lived. Scanned across the WHOLE diff for any
    // write of `reviewVerdict`, `engineeringReviewResult` or a verdict-shaped
    // token: this is the place one would have to appear, because this is the
    // path a routed item actually takes.
    test(
      'nothing verdict-shaped is written on the routed item, its decision, or '
      'its transition record',
      () async {
        final host = await _CompositionHost.withExhaustedReview(
          producerEndingRevision: _CompositionHost.producedCommit,
        );

        await host.runCompositionTick();

        final metadata = (await host.item).metadata ?? const {};
        for (final key in const [
          'reviewVerdict',
          'engineeringReviewResult',
          'verdictRecorded',
          'verdict',
        ]) {
          expect(
            metadata.containsKey(key),
            isFalse,
            reason:
                '`$key` on the item is read downstream as "a reviewer assessed '
                'this". Nothing assessed it, and the route must not leave a '
                'field a reader could take one from',
          );
        }

        expect(
          await host.workflowStore.readHumanDecisionsForWorkItem(
            _CompositionHost.workItemId,
          ),
          isEmpty,
        );

        // The durable transition record is the one artifact that outlives the
        // tick, so its text is asserted to deny the assessment rather than to
        // be merely silent about it.
        final records = await host.workflowStore.readTransitionHistory(
          _CompositionHost.workItemId,
        );
        final route = records.lastWhere(
          (r) => r.toState == WorkItemState.agentCompleted,
          orElse: () => throw StateError('no route was recorded'),
        );
        expect(route.outcome, TransitionOutcome.accepted);
        expect(route.actorType, ActorType.orchestrator);
        final reason = route.reason ?? '';
        expect(reason, contains('the reviewer concluded nothing'));
        expect(
          reason,
          contains('No reviewer assessed this work'),
          reason:
              'the record has to deny the assessment in its own words, because '
              'the state it moves to cannot. `agent_completed` says "a '
              'producer finished"; only the reason can say nobody looked',
        );
        expect(reason, contains('asserts no verdict'));
        expect(reason, contains(_CompositionHost.producedCommit));
        for (final wire in ReviewVerdict.values) {
          expect(
            reason,
            isNot(contains(wire.wire)),
            reason:
                '`${wire.wire}` is a reviewer assessment. Reading it off this '
                'record six weeks later is exactly the fabrication this route '
                'must never commit',
          );
        }
      },
    );
  });
}

/// A host built from production objects only.
///
/// The real [Scheduler] for BOTH lanes, the real
/// [engineeringReviewWorkloadResolver], the real definitions, dedupe keys,
/// instruction and request builders, the real [DurableWorkflowEngine], the real
/// [JobQueue], and the real [runReviewLaneTick]. The only fakes are the worker
/// dispatch (which records what WOULD be dispatched and runs nothing) and the
/// clock.
class _CompositionHost {
  _CompositionHost._({
    required this.workflowStore,
    required this.engine,
    required this.workerStore,
    required this.executionStore,
    required this.jobStore,
    required this.job,
    required this.implScheduler,
    required this.reviewScheduler,
    required this.dispatch,
  });

  static const workItemId = 'wi-composition-order';
  static const producerExecutionId = 'agx-wx-impl';
  static const reviewerExecutionId = 'agx-wx-review';
  static const producedCommit = 'c0ffee1';
  static const startingRevision = 'aaaaaaa';
  static final _now = DateTime.utc(2026, 10, 16, 12);

  /// The live shape, verbatim: `defect-DEF-1791685024220546` and
  /// `-DEF-1791686357139031`, both at `review_in_progress` with
  /// `AgpTransportException: ACP request timed out` and a job `failed` with
  /// `kind: permanent`.
  ///
  /// ## WHY THE JOB IS `running` AND NOT ALREADY `failed`
  ///
  /// This is the detail the whole finding turns on, and it took a wrong fixture
  /// to see it.
  ///
  /// A terminal job settled in an EARLIER tick is never reported again: step 1
  /// of `Scheduler.tick` only reconciles `claimed`/`running` rows, and step 5-9
  /// only attempts runnable ones. So the first version of this fixture — a job
  /// hand-written as `failed` — produced a drain that considered nothing, and a
  /// test that asserted on the route would have been asserting on a hand-built
  /// precondition rather than on the composition order.
  ///
  /// What production actually is: the reviewer ran, died, and left its job
  /// `running` with a claim nothing renews. The NEXT tick reclaims it —
  /// `Scheduler._reconcileClaim` finds the referenced `WorkerExecution` terminal,
  /// `_adoptFromExecution` classifies `executedFail` as `permanent`, the job
  /// settles `failed`, and the tick reports it on `reconciled`. That report is
  /// what the drain consumes, in this tick, before the `blockedArtifactMissing`
  /// loop.
  ///
  /// So the reviewer is modelled by its two durable rows — a terminal
  /// `WorkerExecution` and a terminal `AgentExecution` with NO result — and no
  /// worker runs in this file at all.
  ///
  /// [producerEndingRevision] null is the "produced nothing" shape — the triage
  /// report, and after `db6ec6e` seven IMPLEMENTER runs on live QA.
  ///
  /// [artifactReadThrows] fails the one durable read the artifact predicate
  /// depends on, which is the input that reaches the human fallback. It is
  /// simulated on the store rather than by stubbing `producedCommitFor`,
  /// because the handler catches that read itself: a test that replaced the
  /// function would not be running the code that has to survive the exception.
  static Future<_CompositionHost> withExhaustedReview({
    required String? producerEndingRevision,
    bool artifactReadThrows = false,
  }) async {
    final workflowStore = InMemoryWorkflowStore();
    final durableWorkers = InMemoryWorkerStore();
    final workerStore = artifactReadThrows
        ? _UnreadableWorkerStore(durableWorkers)
        : durableWorkers;
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
        // The coordinator stamps the producing execution id on success, and
        // `producedCommitFor` joins the two durable records on exactly this
        // pair.
        metadata: const {'producerActorId': producerExecutionId},
        createdAt: _now,
        updatedAt: _now,
      ),
    );

    await workerStore.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: 'wx-impl',
        workItemId: workItemId,
        repositoryPath: '/durable/clone',
        requestedStartingRevision: startingRevision,
        requiredCapabilities: const {
          WorkerCapability.linux,
          WorkerCapability.git,
        },
        agentExecutionId: producerExecutionId,
        endingRevision: producerEndingRevision,
        status: WorkerExecutionStatus.executedPass,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
      ),
    );

    // THE REVIEWER'S OWN WORKER EXECUTION. Terminal and FAILED, with no result —
    // which is why the job reconciles as `executedFail` rather than succeeding.
    await workerStore.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: 'wx-review',
        workItemId: workItemId,
        repositoryPath: '/durable/clone',
        requestedStartingRevision: producedCommit,
        requiredCapabilities: const {WorkerCapability.engineeringReview},
        agentExecutionId: reviewerExecutionId,
        status: WorkerExecutionStatus.executedFail,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
        reason: 'AgpTransportException: ACP request timed out',
        startedAt: _now,
        endedAt: _now,
      ),
    );

    final enqueued = await JobQueue(store: jobStore).enqueueIfAbsent(
      workItemId: workItemId,
      definition: engineeringReviewDefinition,
      dedupeKey: engineeringReviewDedupeKey(
        (await DurableWorkflowEngine(store: workflowStore).loadWorkItem(
          workItemId,
        )),
        engineeringReviewDefinition,
      ),
      instruction: 'Review the produced artifact.',
    );
    // `running`, with the execution reference the reclaim path chases, and NO
    // claim — so step 1 of the next tick treats the lease as expired. Minted
    // through the real queue so `attempt`/`maxAttempts` are the definition's.
    final job = enqueued.job.copyWith(
      state: JobState.running,
      executionReference: JobExecutionReference(
        workerExecutionId: 'wx-review',
        agentExecutionId: reviewerExecutionId,
        createdAt: _now,
      ),
    );
    await jobStore.saveJob(job);

    // The reviewer's own agent execution: terminal, FAILED, and — as on the
    // live victims — it never wrote a result. This is what makes the drain read
    // an ABSENCE of a verdict rather than a verdict of anything.
    await executionStore.saveExecution(
      AgentExecution(
        executionId: reviewerExecutionId,
        workItemId: workItemId,
        requestId: reviewerExecutionId,
        runtimeTypeId: 'rt-review',
        role: AgentRole.engineeringReviewer,
        status: AgentSessionStatus.failed,
        workspace: const AgentWorkspace(
          workspaceId: 'ws-review',
          path: '/worktrees/review',
          startingRevision: producedCommit,
        ),
        startedAt: _now,
        completedAt: _now,
        reason: 'AgpTransportException: ACP request timed out',
      ),
    );

    final workload = SchedulerWorkload(
      repositoryPath: '/durable/clone',
      startingRevision: startingRevision,
      timeoutSeconds: 1800,
      runtimeTypeId: 'rt-review',
    );
    DateTime clock() => _now;

    return _CompositionHost._(
      workflowStore: workflowStore,
      engine: DurableWorkflowEngine(store: workflowStore),
      // The very store handed to both schedulers, so the one the composition
      // section reads is the one the lanes wrote.
      workerStore: workerStore,
      executionStore: executionStore,
      jobStore: jobStore,
      job: job,
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
          // its own.
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
  final Scheduler implScheduler;
  final Scheduler reviewScheduler;
  final _NoWorkerDispatch dispatch;
  final List<(String, Map<String, dynamic>)> loggedEvents = [];

  /// THE PRODUCTION ORDER. Not a replica of it: this calls
  /// [runReviewLaneTick], which is the very function `run()` calls, so the
  /// composition root and this test cannot disagree about what order the review
  /// section runs in.
  Future<ReviewLaneTickResult> runCompositionTick() => runReviewLaneTick(
    reviewScheduler: reviewScheduler,
    jobStore: jobStore,
    triageProcessor: null,
    // Stalls this section raised are the composition root's to report, so the
    // test collects them rather than asserting on them: the lane under test
    // raises none.
    foldStalls: (_) {},
    workflowEngine: engine,
    executionStore: executionStore,
    workerStore: workerStore,
    log: (message, context) => loggedEvents.add((message, context)),
  );

  Future<WorkItem> get item => engine.loadWorkItem(workItemId);

  Future<void> tickReview() => reviewScheduler.tick().then((_) {});

  Future<void> tickImplementation() => implScheduler.tick().then((_) {});

  List<WorkerExecutionRequest> dispatched(AgentRole role) =>
      dispatch.requests.where((r) => r.role == role).toList(growable: false);

  Map<String, dynamic>? eventNamed(String name) {
    for (final entry in loggedEvents) {
      if (entry.$1 == name) return entry.$2;
    }
    return null;
  }

  /// Forgets the previous tick's log lines, so a multi-tick test asserts about
  /// the tick it is on rather than about whichever tick happened to log the
  /// event first.
  void resetLogs() => loggedEvents.clear();

  /// Lets the re-routed reviewer run and ALSO conclude nothing, so the second
  /// verdict-absent tick has a real terminal job to drain.
  ///
  /// The fresh job the route minted is marked terminal with the same permanent
  /// failure the live victims had, and a fresh reviewer execution is recorded
  /// against it. Without this the budget test would be asserting against a
  /// fabricated absence.
  Future<void> failTheReroutedReviewWithNothingSaid() async {
    final jobs = await jobStore.listJobsForWorkItem(workItemId);
    final fresh = jobs.firstWhere(
      (j) => j.jobType == JobType.engineeringReview && j.jobId != job.jobId,
    );
    // `running` with a terminal FAILED execution behind it and no claim, for the
    // same reason the first job is shaped that way: `Scheduler.tick` step 1
    // reconciles `claimed`/`running` rows and nothing else, so a job written as
    // already-`failed` would never be reported and the drain would consider
    // nothing. This way the SECOND verdict-absent tick reconciles it itself,
    // through the same production path as the first.
    await workerStore.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: 'wx-review-2',
        workItemId: workItemId,
        repositoryPath: '/durable/clone',
        requestedStartingRevision: producedCommit,
        requiredCapabilities: const {WorkerCapability.engineeringReview},
        agentExecutionId: 'agx-wx-review-2',
        status: WorkerExecutionStatus.executedFail,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
        reason: 'AgpTransportException: ACP request timed out',
        startedAt: _now,
        endedAt: _now,
      ),
    );
    await jobStore.saveJob(
      fresh.copyWith(
        state: JobState.running,
        executionReference: JobExecutionReference(
          workerExecutionId: 'wx-review-2',
          agentExecutionId: 'agx-wx-review-2',
          createdAt: _now,
        ),
      ),
    );
    await executionStore.saveExecution(
      AgentExecution(
        executionId: 'agx-wx-review-2',
        workItemId: workItemId,
        requestId: 'agx-wx-review-2',
        runtimeTypeId: 'rt-review',
        role: AgentRole.engineeringReviewer,
        status: AgentSessionStatus.failed,
        workspace: const AgentWorkspace(
          workspaceId: 'ws-review-2',
          path: '/worktrees/review',
          startingRevision: producedCommit,
        ),
        startedAt: _now,
        completedAt: _now,
        reason: 'AgpTransportException: ACP request timed out',
      ),
    );
    // The item is back at `reviewInProgress`, which is the state a real
    // reviewer occupies: the route left it at `agentCompleted` and the review
    // lane's dispatch moves it.
    //
    // Carrying the implementer's `agentResult` is not decoration. The edge
    // `agentCompleted -> reviewInProgress` carries `agentResultValid()` — the
    // guard `engineeringReviewDefinition.skipWorkflowPolicyCheck` exists
    // because the SCHEDULER cannot supply it — so the transition is refused
    // without it. Supplying it is exactly what `ExecutionCoordinator.execute`
    // does when it starts a reviewer, and supplying it here rather than forcing
    // the state is what keeps this test honest.
    final current = await item;
    if (current.state != WorkItemState.reviewInProgress) {
      await engine.transition(
        workItemId: workItemId,
        to: WorkItemState.reviewInProgress,
        trigger: TransitionTrigger.agentResult,
        actor: const WorkflowActor(
          actorId: 'orchestrator',
          actorType: ActorType.orchestrator,
        ),
        context: {
          'agentAvailable': true,
          'capabilitiesMatch': true,
          'agentResult': await _producerResult(),
        },
        reason: 'the re-routed reviewer entered the review lane',
      );
    }
  }

  /// The implementer's completed `AgentResult`, written the way the coordinator
  /// writes it on the success branch. It exists only for
  /// `agentResultValid()` on the edge above and is never inspected.
  Future<AgentResult> _producerResult() async {
    await executionStore.saveExecution(
      AgentExecution(
        executionId: producerExecutionId,
        workItemId: workItemId,
        requestId: producerExecutionId,
        runtimeTypeId: 'rt-impl',
        role: AgentRole.implementer,
        status: AgentSessionStatus.completed,
        sessionId: 'ses-impl',
        resultId: 'res-impl',
        workspace: const AgentWorkspace(
          workspaceId: 'ws-impl',
          path: '/durable/clone',
          startingRevision: startingRevision,
        ),
        startedAt: _now,
        completedAt: _now,
      ),
    );
    final result = AgentResult(
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
    );
    await executionStore.saveResult(producerExecutionId, result);
    return result;
  }
}

/// A [WorkerStore] whose ONE read the artifact predicate depends on fails.
///
/// `producedCommitFor` reaches durable state through exactly one call —
/// `listWorkerExecutions` — and this fails that and nothing else. So the fixture
/// underneath is a real store holding a real commit, and the handler cannot
/// tell the difference between "there was nothing" and "I could not look",
/// which is the whole point: the second must not be read as the first.
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
