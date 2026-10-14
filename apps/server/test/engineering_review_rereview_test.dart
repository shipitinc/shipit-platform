import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';
import 'package:workflow_store/workflow_store.dart';

import 'package:control_plane_server/src/review/engineering_review_gate.dart';

/// ## WHAT THIS FILE EXISTS TO PROVE
///
/// The end-to-end shape of the live strand, executed rather than described.
///
/// Five work items sat at `agent_completed` in the QA database on 2026-10-14,
/// each holding a fresh producer commit and each with a TERMINAL `failed`
/// `engineering_review` job from 2026-10-12/13. Because
/// `JobQueue.enqueueIfAbsent` refuses a key ANY job holds, terminal or not,
/// and `engineeringReviewDedupeKey` built `'<workItemId>:engineering_review'`
/// with no discriminator, the review lane could never claim them: every tick
/// returned `created: false`, no reviewer ever ran, and `artifactRefsJson` stayed
/// empty because the job that would have written it never started.
///
/// So the item below is built in exactly that shape — real `Scheduler`, real
/// `JobQueue`, real `implementFeatureDefinition` completion inflow, real
/// `engineeringReviewWorkloadResolver`, real `DurableWorkflowEngine`, and a
/// `WorkerExecution` row carrying a commit that differs from the revision the
/// producer started at — and the assertion is that ONE `sched-review` tick mints
/// the SECOND review job under a fresh key and offers it to a reviewer at the
/// produced revision.
///
/// ## WHY THE IMPL FLOWER RUNS HERE AT ALL
///
/// Because it is what puts the item in front of `sched-review` in production.
/// `sched-impl` ticks first (`server.dart`), and its completion inflow routes
/// every `agentCompleted` item away: a commit goes to `reviewInProgress`, no
/// commit goes to `implementationReady`. The one exception is the bound — when
/// `triageAttempt` is already at `maxImplementationInflows` the inflow
/// STANDS DOWN and leaves the item at `agentCompleted` precisely so the review
/// lane can take it (`implementation_inflow.dart`, "WHY A BOUND IS NOT
/// OPTIONAL"). Every one of the five stranded items reads 3 or 4, so this is
/// the real path and not a corner: the test runs `implScheduler.tick()` first
/// and asserts the stand-down happened, rather than asserting the review lane
/// in isolation and calling that end to end.
///
/// ## WHY IT IS NOT VACUOUS
///
/// The seeded terminal holder is created through the real `JobQueue`, not
/// asserted to exist, and the test then asks the queue for the OLD key directly
/// and requires `created: false` naming that holder. If the suffix were absent,
/// that enqueue is what the scheduler would perform — and the second test in
/// this file shows it producing nothing at all.
///
/// ## WHAT IT DELIBERATELY DOES NOT CLAIM
///
/// It does not claim the whole class is closed, and it is not written to look
/// as if it did. Once `triageAttempt` reaches `maxImplementationInflows` the
/// completion inflow stands down BEFORE it writes, so the marker stops moving
/// on its own: a SECOND exhausted review job on the same item, with no re-work
/// in between, would ask for the same `:a<n>` and be refused. That residual is
/// recorded in `engineeringReviewDedupeKey`'s own documentation and needs a
/// discriminator that counts review attempts and a writer for it, which does not
/// exist and is not being smuggled in here. The test below shows the stand-down
/// behaving as documented rather than pretending the stand-down is a fix.
const _itemId = 'wi-1';
const _startingRevision = 'aaaaaaa';

/// The commit today's implementation run left. It differs from
/// `_startingRevision`, which is the only thing that makes it a produced
/// artifact rather than a triage report.
const _producedCommit = 'bbbbbbb';

/// Reports "no compatible worker" so the scheduler builds the request — proving
/// what it WOULD have dispatched, and at which revision — and never runs one.
/// Same technique, and the same reason, as
/// `implementation_inflow_tick_order_test.dart`.
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

class _Host {
  _Host._({
    required this.workflowStore,
    required this.engine,
    required this.jobStore,
    required this.dispatch,
    required this.implScheduler,
    required this.reviewScheduler,
  });

  /// Builds the QA state: a work item at `agentCompleted` whose producer left
  /// [_producedCommit], with `triageAttempt` at [maxImplementationInflows].
  ///
  /// The `WorkerExecution` row is written the way a real `LocalWorker` writes
  /// it: `agentExecutionId` is the same id the coordinator stamped on the item
  /// as `producerActorId`, and `endingRevision` is set only because the run
  /// committed. `producedCommitFor` joins on that equality, so an item without
  /// the row would read as a producer that committed nothing — which routes to
  /// the implementation lane and would prove nothing about review at all.
  static Future<_Host> strandedReviewItem() async {
    final workflowStore = InMemoryWorkflowStore();
    final workerStore = InMemoryWorkerStore();
    final jobStore = InMemoryJobStore();
    final dispatch = _NoWorkerDispatch();
    final now = DateTime.utc(2026, 1, 1);

    await workflowStore.saveWorkItem(
      WorkItem(
        workItemId: _itemId,
        productId: 'prod-1',
        category: WorkItemCategory.bugfix,
        title: 'Models page seems broken',
        description: 'A defect whose implementation produced a real commit.',
        state: WorkItemState.agentCompleted,
        metadata: const {
          'producerActorId': 'agx-wx-1',
          'triageAttempt': maxImplementationInflows,
        },
        createdAt: now,
        updatedAt: now,
      ),
    );
    await workerStore.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: 'wx-1',
        workItemId: _itemId,
        repositoryPath: '/durable/clone',
        requestedStartingRevision: _startingRevision,
        requiredCapabilities: const {
          WorkerCapability.linux,
          WorkerCapability.git,
        },
        agentExecutionId: 'agx-wx-1',
        endingRevision: _producedCommit,
        status: WorkerExecutionStatus.executedPass,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
      ),
    );

    final workload = SchedulerWorkload(
      repositoryPath: '/durable/clone',
      startingRevision: _startingRevision,
      timeoutSeconds: 1800,
      runtimeTypeId: 'rt-review',
    );
    DateTime clock() => DateTime.utc(2026, 1, 1);

    return _Host._(
      workflowStore: workflowStore,
      engine: DurableWorkflowEngine(store: workflowStore),
      jobStore: jobStore,
      dispatch: dispatch,
      implScheduler: Scheduler(
        schedulerId: 'sched-impl',
        workflowStore: workflowStore,
        jobStore: jobStore,
        workerStore: workerStore,
        dispatch: dispatch,
        definition: implementFeatureDefinition,
        dedupeKeyBuilder: implementFeatureDedupeKey,
        instructionBuilder: implementFeatureInstruction,
        requestBuilder: implementFeatureRequest,
        workloadResolver: (job, item) async => workload,
        workload: workload,
        clock: clock,
      ),
      reviewScheduler: Scheduler(
        schedulerId: 'sched-review',
        workflowStore: workflowStore,
        jobStore: jobStore,
        workerStore: workerStore,
        dispatch: dispatch,
        definition: engineeringReviewDefinition,
        dedupeKeyBuilder: engineeringReviewDedupeKey,
        instructionBuilder: engineeringReviewInstruction,
        requestBuilder: engineeringReviewRequest,
        // The REAL resolver, stated explicitly rather than inherited from a
        // default: it is the thing that turns the producer's commit into a
        // reviewable workload, and a reviewer pointed anywhere else would make
        // this file prove that the wrong revision is reviewed.
        workloadResolver: engineeringReviewWorkloadResolver(
          workerStore: workerStore,
          runtimeTypeId: 'rt-review',
        ),
        workload: workload,
        clock: clock,
      ),
    );
  }

  final InMemoryWorkflowStore workflowStore;
  final DurableWorkflowEngine engine;
  final InMemoryJobStore jobStore;
  final _NoWorkerDispatch dispatch;
  final Scheduler implScheduler;
  final Scheduler reviewScheduler;

  /// The composition root's order, transcribed: `sched-impl` first, then
  /// `sched-review`. See `implementation_inflow_tick_order_test.dart` for why
  /// that order is the design and not a line-number accident.
  Future<SchedulerTickResult> runCompositionOrder() async {
    await implScheduler.tick();
    return reviewScheduler.tick();
  }

  /// The CONSUMED-KEY HISTORY, created through the REAL queue so the keys are
  /// genuinely held rather than assumed to be.
  ///
  /// `'<id>:engineering_review'` is what the pre-fix builder asked for, and it
  /// is what every one of the five stranded items still holds.
  Future<Job> holdTerminalReviewJob(String dedupeKey) async {
    final queue = JobQueue(store: jobStore);
    final created = await queue.enqueueIfAbsent(
      workItemId: _itemId,
      definition: engineeringReviewDefinition,
      dedupeKey: dedupeKey,
      instruction: 'seeded terminal holder: the QA state on 2026-10-12',
    );
    expect(
      created.created,
      isTrue,
      reason: '$dedupeKey must actually be free when this seeds it',
    );
    return queue.complete(job: created.job, terminal: JobState.failed);
  }

  Future<List<Job>> reviewJobs() async => (await jobStore.listJobsForWorkItem(
    _itemId,
  )).where((j) => j.jobType == JobType.engineeringReview).toList();
}

void main() {
  group('a stranded review is recovered under a FRESH key', () {
    test(
      'one sched-review tick mints the SECOND review and offers it a reviewer',
      () async {
        final host = await _Host.strandedReviewItem();

        // The QA state, verbatim: a terminal failed review job holding the key
        // the pre-fix builder asked for.
        final stranded = await host.holdTerminalReviewJob(
          '$_itemId:engineering_review',
        );
        expect(stranded.state, JobState.failed);

        // NON-VACUITY, EXECUTED. This is the enqueue the pre-fix key builder
        // made every tick: `created: false`, naming the terminal job, no new
        // job. If the suffix the review lane now builds were absent, this is
        // what the scheduler would do and the item would be inert for ever.
        final oldKeyAttempt = await JobQueue(store: host.jobStore)
            .enqueueIfAbsent(
              workItemId: _itemId,
              definition: engineeringReviewDefinition,
              dedupeKey: '$_itemId:engineering_review',
              instruction: 'the pre-fix enqueue',
            );
        expect(
          oldKeyAttempt.created,
          isFalse,
          reason:
              'the old key is consumed, and that is what makes the new one '
              'necessary rather than cosmetic',
        );
        expect(oldKeyAttempt.job.jobId, stranded.jobId);
        expect(oldKeyAttempt.job.state, JobState.failed);

        // The composition's order: implementation first. It must STAND DOWN —
        // its budget is spent — and leave the item at `agentCompleted` for the
        // review lane. Asserted, not assumed: if the inflow took this item the
        // rest of this file would be proving something about implementation.
        final implTick = await host.implScheduler.tick();
        expect(
          implTick.completionInflow.single.to,
          isNull,
          reason:
              'with a commit produced and no budget left the inflow must refuse '
              'the route. This is the documented hand-off to sched-review '
              '(`implementation_inflow.dart`, WHY A BOUND IS NOT OPTIONAL).',
        );
        expect(
          (await host.engine.loadWorkItem(_itemId)).state,
          WorkItemState.agentCompleted,
        );

        // THE FIX. One ordinary tick of the review lane.
        final reviewTick = await host.reviewScheduler.tick();

        expect(
          reviewTick.enqueued,
          hasLength(1),
          reason: 'exactly one second review job, and it must be new',
        );
        final second = (await host.reviewJobs()).singleWhere(
          (j) => j.jobId != stranded.jobId,
        );
        expect(
          second.dedupeKey,
          '$_itemId:engineering_review:a$maxImplementationInflows',
          reason:
              'the attempt suffix read from the durable marker is the whole '
              'fix. The item\'s marker reads '
              '$maxImplementationInflows, the completion inflow\'s bound is '
              '$maxImplementationInflows, and the keys the old review jobs '
              'hold are unsuffixed — so `:a$maxImplementationInflows` has no '
              'holder anywhere.',
        );

        // AND IT IS A REAL REVIEW OF THE REAL ARTIFACT, not an inert row.
        expect(
          host.dispatch.requests
              .where((r) => r.role == AgentRole.engineeringReviewer)
              .single
              .startingRevision,
          _producedCommit,
          reason:
              'the reviewer must be offered the revision the IMPLEMENTER '
              'produced. The five stranded items carry real commits, and a '
              'review pointed anywhere else would look like a recovery while '
              'reviewing nothing.',
        );
        expect(reviewTick.blockedArtifactMissing, isEmpty);
      },
    );

    test(
      'the OLD key still cannot be had — the suffix is the only route out',
      () async {
        // The same statement as above, isolated so that a change which somehow
        // made BOTH keys available would be caught by an assertion about the
        // consumed one rather than passing unnoticed behind the `:a<n>`
        // assertion.
        final host = await _Host.strandedReviewItem();
        await host.holdTerminalReviewJob('$_itemId:engineering_review');

        await host.runCompositionOrder();

        final queue = JobQueue(store: host.jobStore);
        final oldKey = await queue.enqueueIfAbsent(
          workItemId: _itemId,
          definition: engineeringReviewDefinition,
          dedupeKey: '$_itemId:engineering_review',
          instruction: 'the pre-fix enqueue',
        );
        final newKey = await queue.enqueueIfAbsent(
          workItemId: _itemId,
          definition: engineeringReviewDefinition,
          dedupeKey: engineeringReviewDedupeKey(
            await host.engine.loadWorkItem(_itemId),
            engineeringReviewDefinition,
          ),
          instruction: 'the post-fix enqueue',
        );

        expect(oldKey.created, isFalse, reason: 'consumed, terminal, refused');
        expect(newKey.created, isFalse, reason: 'the tick already took it');
        expect(
          newKey.job.jobId,
          isNot(oldKey.job.jobId),
          reason: 'they are different jobs, and only the new one is live',
        );
        expect(
          (await host.reviewJobs()).where((j) => !j.isTerminal),
          hasLength(1),
        );
      },
    );
  });

  group('the ACTIVE-review invariant is not what was traded away', () {
    test(
      'a terminal holder AT the suffixed key still blocks a second review',
      () async {
        // The suffix varies per ATTEMPT. It must not become "any key will do",
        // which is the failure mode of adding a discriminator: the guard that
        // stops an unattended machine re-reviewing the same artifact for ever.
        final host = await _Host.strandedReviewItem();
        await host.holdTerminalReviewJob(
          '$_itemId:engineering_review:a$maxImplementationInflows',
        );

        await host.runCompositionOrder();

        expect(
          await host.reviewJobs(),
          hasLength(1),
          reason: 'nothing new was minted',
        );
        expect(
          host.dispatch.requests.where(
            (r) => r.role == AgentRole.engineeringReviewer,
          ),
          isEmpty,
          reason: 'no reviewer may be dispatched against a consumed key',
        );
        expect(
          (await host.engine.loadWorkItem(_itemId)).state,
          WorkItemState.agentCompleted,
          reason:
              'the item is left where it is rather than parked or moved: the '
              'queue refused, which is the same answer the unsuffixed key gave '
              'before this change, and the reason the residual is documented '
              'rather than hidden',
        );
      },
    );

    test(
      'two review ticks of the same item still mint ONE review job',
      () async {
        final host = await _Host.strandedReviewItem();
        await host.holdTerminalReviewJob('$_itemId:engineering_review');

        await host.runCompositionOrder();
        final second = await host.reviewScheduler.tick();

        expect(
          second.enqueued,
          isEmpty,
          reason: 'the key is held by the live job',
        );
        expect(
          (await host.reviewJobs()).where((j) => !j.isTerminal),
          hasLength(1),
          reason: 'two ticks, one active review',
        );
      },
    );
  });
}
