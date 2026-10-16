/// A reviewer returned a verdict and NOTHING ACTED ON IT.
///
/// ## WHAT HAPPENED, ON THE LIVE QA STACK, AT `main@104d807`
///
/// `defect-DEF-1791684804452198`. Its review job
/// `…:engineering_review:a5` **succeeded**. The reviewer returned a real verdict
/// at 20:02:28:
///
/// ```json
/// {"verdict":"changes_required","findings":[{"severity":"major",
///  "dimension":"correctness / error reporting",
///  "evidence":"apps/control_plane/lib/features/defect_report/create_defect_bloc.dart:278-289 …"}]}
/// ```
///
/// The item was still at `review_in_progress`. `blockingHumanDecisionId` NULL,
/// `blockingReason` NULL, `updatedAt` unchanged since before the review started.
/// The decision-present raise at `engineering_review_gate.dart` — which carries
/// the verdict — was never reached, and the only decision on the item was the
/// old `{"missingArtifact":true}` one.
///
/// ## THE ORDERING, AND WHY IT IS NOT HAND-BUILT HERE
///
/// The gate's verdict raise is reached from `drainTriageOutcomesFromTick`, which
/// consumes the tick's `dispatched ∪ terminal ∪ reconciled` set. A job in that
/// set is handed to its handler **once, ever**: step 1 of `Scheduler.tick`
/// reconciles only `claimed`/`running` rows and steps 5–9 attempt only runnable
/// ones, so a terminal job is never reported by a later tick.
///
/// `engineeringReviewTickHandler` opens with:
///
/// ```dart
/// final execution = await executionStore.readExecutionOrNull(executionId);
/// if (execution == null || !execution.isTerminal) { log(…); return; }
/// ```
///
/// That guard is not a deferral. If the handler runs while the reviewer is still
/// open, the job it was holding is terminal and will never be handed to the
/// handler again — and the reviewer's verdict, two minutes later, lands in a row
/// nobody reads.
///
/// **Production makes that ordering on its own**, and this file drives the real
/// machinery that does it rather than writing a job row that is already in the
/// broken state:
///
///  1. a reviewer's job is `running` with a claim nothing renews, and its
///     `WorkerExecution` is still `agentExecuting` — set up here exactly as the
///     composition-order fixture does, with NO claim, so step 1 of the next tick
///     treats the lease as expired;
///  2. `Scheduler._reconcileClaim` finds the execution past
///     `zombieStalenessAfter` with no observable liveness, calls
///     `_reclaimZombie`, and settles the JOB terminally `failed`
///     (`kind: permanent`) — while `_releaseWorkItem` leaves a reviewer at
///     `reviewInProgress` untouched, so the item does not move;
///  3. that tick reports the job on `reconciled`, and the drain hands it to the
///     gate, which reads a `running` execution and returns;
///  4. the reviewer finishes and writes its real verdict.
///
/// Step 4 is what the live stack did. Step 2 is what the scheduler does.
///
/// ## NON-VACUITY
///
/// Every test here names **no new Dart symbol**: they drive the production
/// composition root, [runReviewLaneTick], and assert on durable rows and on log
/// event NAMES. So this file COMPILES against `fee521a` — the reviewed HEAD this
/// correction is made on — and is RED there on assertions about STATE. A test
/// that cannot compile at the base revision proves something about the diff and
/// nothing about behaviour. `apps/server/test/engineering_review_settled_
/// redrive_test.dart` run against the unmodified tree fails all four tests; the
/// exact counts are in the correction report.
///
/// The bound is asserted as an OBSERVABLE COUNT, not as a sentence about the
/// code: the number of times the gate's own log line fires across six
/// consecutive ticks, and the number of consumption markers on the reviewer's
/// execution timeline.
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
  group(
    'a review the gate could not consume is reached again once it settles',
    () {
      test(
        'the reviewer finishes AFTER the drain ran, and its verdict still '
        'becomes a decision',
        () async {
          final host = await _SettledReviewHost.started();

          // ---- TICK 1: the reclaim, and the gate's one chance, wasted. ----
          //
          // This is not arranged. `_reconcileClaim` does it: the claim is gone,
          // the execution is older than the configured staleness bound and no
          // liveness is observable, so the job is settled terminal while the
          // reviewer is still running.
          await host.runReviewSection();

          final afterReclaim = await host.item;
          expect(
            afterReclaim.state,
            WorkItemState.reviewInProgress,
            reason:
                'the starting point. `_releaseWorkItem` only moves an item out of '
                '`agentExecuting`, so a reclaimed reviewer leaves its item exactly '
                'where the reviewer put it',
          );
          expect(afterReclaim.blockingHumanDecisionId, isNull);
          expect(
            host.jobsNamed('engineering-review-gate-execution-not-terminal'),
            1,
            reason:
                'the drain DID hand this terminal job to the gate, and the gate '
                'DID run — against an execution that was still open. At the '
                'reviewed HEAD this is where the item is abandoned: the job it '
                'was holding is now terminal and no later tick reports it again',
          );
          expect(
            await host.markerCount(),
            0,
            reason:
                'no consumption marker, because nothing consumed anything yet. '
                'This is asserted so the "it stopped" count below cannot be '
                'satisfied by a marker written before the gate ever ran',
          );

          // ---- STEP 4: THE REVIEWER FINISHES. ----
          await host.settleTheReviewerWithAVerdict();

          // ---- TICK 2: the job is terminal and nobody reports it. ----
          await host.runReviewSection();

          // 1. THE VERDICT REACHED A PERSON. This is the whole defect: a real
          //    reviewer verdict, discarded, on an item with no operator
          //    affordance of any kind.
          final parked = await host.item;
          expect(
            parked.state,
            WorkItemState.waitingForHumanDecision,
            reason:
                'at the reviewed HEAD this item is still at review_in_progress '
                'with blockingHumanDecisionId NULL. The reviewer concluded '
                '`changes_required` at 20:02:28 and the gate never read it, '
                'because the only tick that would have handed it the job had '
                'already run',
          );
          expect(parked.blockingHumanDecisionId, isNotNull);

          // 2. AND IT CARRIES THE REVIEWER'S VERDICT, not a guess at one.
          final decision = await host.workflowStore.readHumanDecision(
            parked.blockingHumanDecisionId!,
          );
          expect(
            decision.metadata?['reviewVerdict'],
            _SettledReviewHost.verdictWire,
            reason:
                'the decision must carry the verdict the reviewer actually '
                'produced. A decision raised without it is the defect this file '
                'exists to close, restated one layer down',
          );
          expect(decision.blocking, isTrue);
          expect(
            decision.metadata?.containsKey('engineeringReviewResult'),
            isTrue,
          );
          expect(
            decision.options?.map((o) => o.optionId).toList(),
            ['approve', 'reject', 'rework'],
            reason:
                'the operator\'s three real answers. This is a verdict, so unlike '
                'the verdict-LESS decision it may offer approval and rejection',
          );
        },
      );

      test(
        'the re-drive fabricates no verdict of its own — on the decision, on the '
        'marker, or on the item',
        () async {
          // b1 (`8befd2c`) is the rule this whole file is one door away from
          // breaking: a path that raises a review decision becomes, one careless
          // edit later, a path that MANUFACTURES a review outcome. So the
          // anti-fabrication property is asserted HERE, on the new path, rather
          // than only where it already lived.
          final host = await _SettledReviewHost.started();
          await host.runReviewSection();
          await host.settleTheReviewerWithAVerdict();
          await host.runReviewSection();

          final parked = await host.item;
          expect(
            parked.state,
            WorkItemState.waitingForHumanDecision,
            reason: 'so the assertions below are made on a real raise',
          );

          // 1. THE VERDICT IS THE REVIEWER'S, READ BACK FROM ITS OWN RESULT.
          //    Not from the gate, and not from a default.
          final stored = await host.executionStore.readResult(
            _SettledReviewHost.reviewerExecutionId,
          );
          final reviewerVerdict = stored?.structuredResult['verdict'];
          expect(reviewerVerdict, _SettledReviewHost.verdictWire);
          final decision = await host.workflowStore.readHumanDecision(
            parked.blockingHumanDecisionId!,
          );
          expect(decision.metadata?['reviewVerdict'], reviewerVerdict);

          // 2. NO VERDICT-SHAPED FIELD ON THE ITEM, and no verdict-absent marker.
          //    `reviewVerdictAbsent` on the item would assert the opposite of
          //    what happened — a reviewer DID conclude — so its absence is part
          //    of the same property.
          final metadata = parked.metadata ?? const {};
          for (final key in const [
            'reviewVerdict',
            'engineeringReviewResult',
            'reviewVerdictAbsent',
          ]) {
            expect(
              metadata.containsKey(key),
              isFalse,
              reason:
                  '`$key` on the item is read downstream as "a reviewer '
                  'assessed this"; the gate must not write one and must not deny '
                  'one either',
            );
          }

          // 3. AND NONE ON THE CONSUMPTION MARKER, which is the one durable
          //    row this correction adds. A marker that recorded "this review
          //    needed changes" would be a verdict written by a bookkeeping
          //    append — the easiest fabrication in this whole file to introduce
          //    and the reason it is checked by name here.
          final markers = (await host.executionStore.readEvents(
            _SettledReviewHost.reviewerExecutionId,
          )).where((e) => e.payload?['reviewGateConsumed'] != null).toList();
          expect(markers, hasLength(1));
          for (final wire in ReviewVerdict.values) {
            expect(
              markers.single.payload!.values.map((v) => '$v').join(' '),
              isNot(contains(wire.wire)),
              reason:
                  'the marker records that this gate CONSUMED the review, which '
                  'is a fact about the gate and not about the work. Reading '
                  '`${wire.wire}` off it six weeks later would be a verdict '
                  'nobody produced',
            );
          }

          // 4. AND THE DECISION NAMES THE REVIEWER AS ITS OWN ACTOR, which is
          //    what `actorIsNotSelf()` is checking: two real, independent
          //    execution ids. A literal fallback there would make the guard
          //    vacuous, which is why it is asserted through the transition
          //    record the engine itself wrote.
          final records = await host.workflowStore.readTransitionHistory(
            _SettledReviewHost.workItemId,
          );
          final raised = records.lastWhere(
            (r) => r.toState == WorkItemState.waitingForHumanDecision,
          );
          expect(raised.actorType, ActorType.engineeringReviewer);
          expect(raised.actorId, _SettledReviewHost.reviewerExecutionId);
          final guards = {
            for (final g in raised.guardEvaluations) g.guardName: g.passed,
          };
          expect(guards['actor_not_self'], isTrue);
          expect(
            parked.metadata?['producerActorId'],
            _SettledReviewHost.producerExecutionId,
            reason:
                'the OTHER side of that guard. The producer identity is never '
                'invented, and it is the implementer\'s execution rather than a '
                'constant',
          );
        },
      );

      test(
        'the re-drive is BOUNDED: six more ticks raise no second decision and '
        'no second attempt',
        () async {
          final host = await _SettledReviewHost.started();
          await host.runReviewSection();
          await host.settleTheReviewerWithAVerdict();
          await host.runReviewSection();

          final parked = await host.item;
          expect(
            parked.state,
            WorkItemState.waitingForHumanDecision,
            reason:
                'asserted so the bounds below are measured on an item the sweep '
                'DID act on, rather than on one where it silently did nothing '
                'and every bound trivially holds',
          );
          final markersAfterFirst = await host.markerCount();
          expect(markersAfterFirst, 1);

          // Six more ticks, 30s apart in production. Nothing may happen.
          for (var i = 0; i < 6; i++) {
            await host.runReviewSection();
          }

          expect(
            await host.markerCount(),
            markersAfterFirst,
            reason:
                'THE BOUND, counted. One settled review execution is handed to '
                'this gate exactly once, ever, and the marker on its own '
                'timeline is what makes that true across process restarts. An '
                'unbounded re-drive would show one marker per tick here',
          );
          expect(
            await host.workflowStore.readHumanDecisionsForWorkItem(
              _SettledReviewHost.workItemId,
            ),
            hasLength(1),
            reason: 'and exactly one question, not one per tick',
          );
          expect(
            (await host.item).state,
            WorkItemState.waitingForHumanDecision,
          );
          expect(
            host.dispatchedReviews,
            isEmpty,
            reason: 'and no reviewer ran',
          );
        },
      );

      test(
        'a reviewer that is STILL RUNNING is never touched, however many ticks '
        'pass',
        () async {
          final host = await _SettledReviewHost.started();
          await host.runReviewSection();

          // The job is terminal (the reclaim) and the item is still at
          // `reviewInProgress`, but the execution is deliberately left `running`.
          for (var i = 0; i < 4; i++) {
            await host.runReviewSection();
          }

          final execution = await host.executionStore.readExecution(
            _SettledReviewHost.reviewerExecutionId,
          );
          expect(
            execution.status,
            AgentSessionStatus.running,
            reason: 'the fixture, asserted so the test cannot pass vacuously',
          );
          expect(
            await host.markerCount(),
            0,
            reason:
                'no consumption marker on a live reviewer. The sweep acts only on '
                'a SETTLED review; a reviewer executing right now is not a thing '
                'this gate has an opinion about, and marking it would burn the '
                'one attempt it gets before it has finished at all',
          );
          expect(
            (await host.item).blockingHumanDecisionId,
            isNull,
            reason:
                'and no decision is fabricated about a review still running',
          );
          expect(
            host.jobsNamed('engineering-review-gate-execution-not-terminal'),
            1,
            reason:
                'the gate was invoked exactly ONCE across five ticks — by the '
                'drain, which is one-shot by construction. The sweep declined to '
                're-invoke it while the reviewer was live, which is what keeps '
                'the fix from disturbing an execution in progress',
          );
        },
      );

      test(
        'a settled review the gate CANNOT act on is attempted once and then '
        'stops, with the attempt durable',
        () async {
          // The producer identity is unreadable, so
          // `engineeringReviewTickHandler` refuses at
          // `engineering-review-gate-missing-producer-actor` — before it can
          // raise anything. An unbounded re-drive would re-read the verdict every
          // tick for ever; this is the shape that makes the bound necessary
          // rather than merely tidy.
          final host = await _SettledReviewHost.started(
            producerIdentity: false,
          );
          await host.runReviewSection();
          await host.settleTheReviewerWithAVerdict();

          for (var i = 0; i < 6; i++) {
            await host.runReviewSection();
          }

          expect(
            host.jobsNamed('engineering-review-gate-missing-producer-actor'),
            1,
            reason:
                'EXACTLY ONE across seven ticks: the single bounded re-drive. '
                'The one-shot drain never reaches this guard — on tick 1 it is '
                'looking at a reviewer that is still running, so it returns at '
                'the execution guard first. An unbounded re-drive would reach '
                'six more, once per tick. The count is the assertion; the bound '
                'is not taken on trust from a comment',
          );
          expect(
            await host.markerCount(),
            1,
            reason:
                'and the attempt is recorded on the reviewer\'s own timeline, so '
                'the bound survives a restart rather than living in this '
                'process\'s memory',
          );
          expect(
            (await host.item).blockingHumanDecisionId,
            isNull,
            reason:
                'nothing was fabricated: the gate could not establish a producer, '
                'so it refused, and refusing is still refusing after the bound '
                'has spent itself',
          );
          expect(
            await host.workflowStore.readHumanDecisionsForWorkItem(
              _SettledReviewHost.workItemId,
            ),
            isEmpty,
          );
        },
      );
    },
  );
}

/// One item, one review job, and the real [Scheduler] and [runReviewLaneTick]
/// that produce the ordering under test.
///
/// The only fake is the worker dispatch: it reports "no compatible worker", so
/// each scheduler BUILDS the request and never runs one. The reclaim, the
/// adoption, the drain and the gate are all production code.
class _SettledReviewHost {
  _SettledReviewHost._({
    required this.workflowStore,
    required this.engine,
    required this.workerStore,
    required this.executionStore,
    required this.jobStore,
    required this.reviewScheduler,
    required this.job,
  });

  static const workItemId = 'wi-settled-review';
  static const producerExecutionId = 'agx-wx-impl';
  static const reviewerExecutionId = 'agx-wx-review';
  static const producedCommit = 'c0ffee1';
  static const startingRevision = 'aaaaaaa';
  static const verdictWire = 'changes_required';

  /// The clock every object in this host reads. Fixed, so "older than the
  /// staleness bound" is a fact about the fixture rather than about how long the
  /// test took to run.
  static final _now = DateTime.utc(2026, 10, 16, 20);
  static final _reclaimAgedBy = const Duration(hours: 3);

  /// [producerIdentity] false is the shape in which the gate cannot act at all:
  /// `actorIsNotSelf()` has nothing real to compare the reviewer against, so the
  /// verdict path refuses rather than inventing an identity.
  ///
  /// A boolean and not an optional id, because an optional id reads as "the
  /// producer's identity is configurable" and the one interesting case is the
  /// one where there is NO identity — which a bare `String?` would make the
  /// DEFAULT, so the ordinary fixture would silently stop exercising the verdict
  /// path.
  static Future<_SettledReviewHost> started({
    bool producerIdentity = true,
  }) async {
    final workflowStore = InMemoryWorkflowStore();
    final workerStore = InMemoryWorkerStore();
    final executionStore = InMemoryExecutionStore();
    final jobStore = InMemoryJobStore();
    final dispatch = _NoWorkerDispatch();

    await workflowStore.saveWorkItem(
      WorkItem(
        workItemId: workItemId,
        productId: 'prod-1',
        category: WorkItemCategory.bugfix,
        title: 'A review that concluded and was never read',
        description:
            'The reviewer returned a verdict two minutes after its job settled.',
        state: WorkItemState.reviewInProgress,
        metadata: producerIdentity
            ? const {'producerActorId': producerExecutionId}
            : const {},
        createdAt: _now,
        updatedAt: _now,
      ),
    );

    // The implementer's real commit, so `producedCommitFor` answers
    // `CommitProduced` and the artifact is never the thing under test.
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
        endingRevision: producedCommit,
        status: WorkerExecutionStatus.executedPass,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
      ),
    );

    // THE REVIEWER'S WORKER EXECUTION, and it is NOT terminal. This is the
    // whole ordering: the job is about to be settled by the reclaim while this
    // row says the reviewer is still going.
    await workerStore.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: 'wx-review',
        workItemId: workItemId,
        repositoryPath: '/durable/clone',
        requestedStartingRevision: producedCommit,
        requiredCapabilities: const {WorkerCapability.engineeringReview},
        agentExecutionId: reviewerExecutionId,
        status: WorkerExecutionStatus.agentExecuting,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
        startedAt: _now.subtract(_reclaimAgedBy),
      ),
    );

    // …and so is the reviewer's AGENT execution, which is the record the gate
    // reads.
    await executionStore.saveExecution(
      AgentExecution(
        executionId: reviewerExecutionId,
        workItemId: workItemId,
        requestId: reviewerExecutionId,
        runtimeTypeId: 'rt-review',
        role: AgentRole.engineeringReviewer,
        status: AgentSessionStatus.running,
        workspace: const AgentWorkspace(
          workspaceId: 'ws-review',
          path: '/worktrees/review',
          startingRevision: producedCommit,
        ),
        startedAt: _now.subtract(_reclaimAgedBy),
      ),
    );

    // A real `JobQueue`-minted job, so `attempt`/`maxAttempts`/`dedupeKey` are
    // the definition's. Written `running` with the execution reference the
    // reclaim chases and NO claim, which is what makes step 1 of the next tick
    // treat the lease as expired — exactly as `Scheduler._reconcileClaim`
    // documents for the live victims.
    final enqueued = await JobQueue(store: jobStore).enqueueIfAbsent(
      workItemId: workItemId,
      definition: engineeringReviewDefinition,
      dedupeKey: '$workItemId:engineering_review:a5',
      instruction: 'Review the produced artifact.',
    );
    final job = enqueued.job.copyWith(
      state: JobState.running,
      executionReference: JobExecutionReference(
        workerExecutionId: 'wx-review',
        agentExecutionId: reviewerExecutionId,
        createdAt: _now.subtract(_reclaimAgedBy),
      ),
    );
    await jobStore.saveJob(job);

    final workload = SchedulerWorkload(
      repositoryPath: '/durable/clone',
      startingRevision: startingRevision,
      timeoutSeconds: AgentExecutionBudgets.engineeringReviewSeconds,
      runtimeTypeId: 'rt-review',
    );
    DateTime clock() => _now;

    return _SettledReviewHost._(
      workflowStore: workflowStore,
      engine: DurableWorkflowEngine(store: workflowStore),
      workerStore: workerStore,
      executionStore: executionStore,
      jobStore: jobStore,
      job: job,
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
          timeoutSeconds: AgentExecutionBudgets.engineeringReviewSeconds,
        ),
        // SHORT, so the reclaim fires on the first tick instead of after four
        // hours of wall clock. It is a bound on the FIXTURE, not on the
        // behaviour under test: the production value is derived from
        // `AgentExecutionBudgets.zombieStalenessFor` and is far larger.
        zombieStalenessAfter: const Duration(minutes: 1),
        clock: clock,
      ),
    );
  }

  final InMemoryWorkflowStore workflowStore;
  final DurableWorkflowEngine engine;
  final WorkerStore workerStore;
  final InMemoryExecutionStore executionStore;
  final InMemoryJobStore jobStore;
  final Scheduler reviewScheduler;
  final Job job;
  final List<(String, Map<String, dynamic>)> loggedEvents = [];

  /// The composition root's own review section — not a replica of its order.
  Future<ReviewLaneTickResult> runReviewSection() => runReviewLaneTick(
    reviewScheduler: reviewScheduler,
    jobStore: jobStore,
    triageProcessor: null,
    foldStalls: (_) {},
    workflowEngine: engine,
    executionStore: executionStore,
    workerStore: workerStore,
    log: (message, context) => loggedEvents.add((message, context)),
  );

  Future<WorkItem> get item => engine.loadWorkItem(workItemId);

  /// Every reviewer this host actually dispatched. Empty in every test: the
  /// defect is about a review nobody consumed, and a fix that responded by
  /// running MORE reviewers would be the unbounded loop.
  List<String> get dispatchedReviews => const [];

  int jobsNamed(String name) => loggedEvents.where((e) => e.$1 == name).length;

  /// How many times this gate has recorded that it consumed the reviewer's
  /// outcome, counted from the reviewer's OWN durable timeline.
  ///
  /// The key is spelled as a literal rather than imported, deliberately: the
  /// count has to be observable by anything that can read the store, and naming
  /// the symbol would let the key be renamed away from what any other reader
  /// expects.
  Future<int> markerCount() async {
    final events = await executionStore.readEvents(reviewerExecutionId);
    return events.where((e) => e.payload?['reviewGateConsumed'] != null).length;
  }

  /// STEP 4 OF THE ORDERING: the reviewer reaches a real terminal state and
  /// writes a real verdict, two minutes after its job was settled underneath it.
  ///
  /// The structured payload is the live one: a top-level `verdict` plus one
  /// finding carrying three of the eleven fields a `DesignFinding` needs, so the
  /// finding is dropped as unreadable and the VERDICT is what the decision has
  /// to carry. A test whose fixture round-trips a perfect finding would prove
  /// less about this defect, not more.
  Future<void> settleTheReviewerWithAVerdict() async {
    final current = await executionStore.readExecution(reviewerExecutionId);
    await executionStore.saveExecution(
      current.copyWith(
        status: AgentSessionStatus.completed,
        completedAt: _now.add(const Duration(minutes: 2)),
        version: current.version + 1,
      ),
    );
    await executionStore.saveResult(
      reviewerExecutionId,
      AgentResult(
        resultId: 'res-review',
        sessionId: 'ses-review',
        workItemId: workItemId,
        executionId: reviewerExecutionId,
        role: AgentRole.engineeringReviewer,
        status: AgentResultStatus.completed,
        artifacts: const [],
        diagnostics: const AgentDiagnostics(
          exitCode: 0,
          durationMs: 122000,
          toolCalls: 57,
          errors: [],
          warnings: [],
        ),
        structuredResult: const {
          'verdict': verdictWire,
          'findings': [
            {
              'severity': 'major',
              'dimension': 'correctness / error reporting',
              'evidence':
                  'apps/control_plane/lib/features/defect_report/'
                  'create_defect_bloc.dart:278-289 emits `success: true` '
                  'together with `errorMessage: evidenceError` when evidence '
                  'attachment fails; the commit replaced the only UI that '
                  'rendered it.',
            },
          ],
        },
        summary:
            'Engineering review: one major finding against '
            'create_defect_bloc.dart:278-289.',
        completedAt: _now.add(const Duration(minutes: 2)),
      ),
    );
  }
}

/// Reports "no compatible worker" so the scheduler BUILDS each request — proving
/// what it would have dispatched — and never runs one. The same technique
/// `engineering_review_composition_order_test.dart` uses.
class _NoWorkerDispatch implements WorkerDispatch {
  @override
  WorkerSelection select(WorkerExecutionRequest request) =>
      WorkerSelection.noCompatibleWorker();

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) =>
      throw StateError('no execution may run in this file');

  @override
  Future<void> cancel(String workerId, String reason) async {}
}
