import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/controlled_dispatcher.dart';
import 'support/settle.dart';

/// OD-10's discriminator is not fooled by the retry return.
///
/// ## THE QUESTION
///
/// Decision `3659984d-4e2a-4625-81ff-37aa73252375` (option A) adds
/// `reviewInProgress -> agentCompleted`. That puts an item BACK at
/// `agentCompleted` — which is exactly the state `OD-10`'s completion inflow
/// reads. So a new question exists that did not before:
///
/// > can a returned review item be mistaken for an implementation-ready item
/// > that produced no commit?
///
/// Getting that wrong in this direction would send real, already-committed
/// work to a SECOND implementer and manufacture a duplicate commit into a
/// governed repository, which is the failure `OD-10` was written to make
/// impossible.
///
/// ## WHY THE ANSWER IS YES IT IS SAFE, AND WHY IT IS NOT A COINCIDENCE
///
/// The discriminator is [producedCommitFor], and it reads durable EVIDENCE
/// about the producer — a `producerActorId` on the item and the worker
/// execution carrying it — not the item's position in the lifecycle. The return
/// moves the item and touches nothing else, so the evidence it is judged on is
/// byte-identical before and after.
///
/// There is also a stronger fact underneath. The review lane only ever
/// DISPATCHED this item because its workload resolver — the very function that
/// calls [producedCommitFor] — returned a workload, which it does only for
/// `CommitProduced`. So an item at `reviewInProgress` has, by construction, a
/// producer that left a commit. Both halves are asserted here: the review gate
/// refuses the no-commit shape, and the inflow routes the commit shape back to
/// review after the return.
///
/// ## WHY REAL `WorkerExecution` ROWS
///
/// Asserting against a stubbed reader would prove only that the function
/// switches on a boolean someone handed it. These tests assemble the three
/// records the way production assembles them — `producerActorId` on the item,
/// `agentExecutionId` on the execution, `endingRevision` set by the committer —
/// so a change to any one of the three rules breaks them.
const _startRevision = '0f9a1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b';
const _producedCommit = '3f8a2b1c9d0e7f6a5b4c3d2e1f0a9b8c7d6e5f4a';

/// The implementer's execution, shaped the way `LocalWorker._finish` records it.
WorkerExecution _producerExecution({
  String workItemId = 'wi-1',
  required String agentExecutionId,
  required String? endingRevision,
}) => WorkerExecution(
  workerExecutionId: 'wx-impl-1',
  workItemId: workItemId,
  repositoryPath: '/durable/clone',
  requestedStartingRevision: _startRevision,
  requiredCapabilities: const {WorkerCapability.linux, WorkerCapability.git},
  agentExecutionId: agentExecutionId,
  endingRevision: endingRevision,
  status: WorkerExecutionStatus.executedPass,
  cleanupPolicy: WorkerCleanupPolicy.removeAlways,
);

/// The IMPLEMENTER's completed result, which
/// `GuardConditions.agentResultValid()` reads out of `context['agentResult']`.
/// The coordinator supplies it from the execution store; a test supplies it
/// directly, because building a whole execution history is not what the retry
/// return is under test.
AgentResult _producerResult(String workItemId) => AgentResult(
  resultId: 'result-impl-$workItemId',
  sessionId: 'ses-impl',
  workItemId: workItemId,
  status: AgentResultStatus.completed,
  artifacts: const [],
  diagnostics: const AgentDiagnostics(
    exitCode: 0,
    durationMs: 1000,
    toolCalls: 1,
    errors: [],
    warnings: [],
  ),
  structuredResult: const {},
  executionId: 'agx-exec-impl-1',
  role: AgentRole.implementer,
  completedAt: DateTime.utc(2026, 3, 1, 11),
);

WorkItem _atAgentCompleted({
  String workItemId = 'wi-1',
  Object? producerActorId = 'agx-exec-impl-1',
}) => WorkItem(
  workItemId: workItemId,
  productId: 'prod-1',
  category: WorkItemCategory.feature,
  title: 'Federated feed routing',
  description: 'A producer finished and left whatever it left.',
  state: WorkItemState.agentCompleted,
  qaContractId: 'qa-1',
  metadata: {if (producerActorId != null) 'producerActorId': producerActorId},
  createdAt: DateTime.utc(2026, 3, 1, 11),
  updatedAt: DateTime.utc(2026, 3, 1, 11),
);

const _workload = SchedulerWorkload(
  repositoryPath: '/durable/clone',
  startingRevision: _producedCommit,
  timeoutSeconds: 300,
  runtimeTypeId: 'rt-product',
);

/// `apps/server`'s `engineeringReviewWorkloadResolver`, re-used here for the
/// same reason production re-uses it: the review lane must refuse to dispatch
/// with no artifact, and that refusal is what guarantees an item at
/// `reviewInProgress` had a commit-producing producer.
WorkloadResolver _reviewWorkloadResolver(WorkerStore workerStore) {
  return (job, item) async {
    final produced = await producedCommitFor(workerStore, item);
    switch (produced) {
      case CommitProduced(:final repositoryPath, :final commit):
        return SchedulerWorkload(
          repositoryPath: repositoryPath,
          startingRevision: commit,
          timeoutSeconds: 300,
          runtimeTypeId: 'rt-product',
        );
      case NoCommitProduced():
        return null;
    }
  };
}

/// One durable world shared by BOTH lanes, exactly as production shares it:
/// one `WorkflowStore`, one `JobStore`, one `WorkerStore`, two `Scheduler`s.
class _World {
  _World._({required WorkerExecution producer, required DateTime now})
    : now = now {
    workflowStore = InMemoryWorkflowStore();
    jobStore = InMemoryJobStore();
    workerStore = InMemoryWorkerStore();
    engine = DurableWorkflowEngine(store: workflowStore);
    dispatch = ControlledDispatcher()..workerStore = workerStore;

    implementation = Scheduler(
      schedulerId: 'sched-impl',
      workflowStore: workflowStore,
      jobStore: jobStore,
      workerStore: workerStore,
      dispatch: dispatch,
      definition: implementFeatureDefinition,
      workload: _workload,
      clock: () => this.now,
      dedupeKeyBuilder: implementFeatureDedupeKey,
      instructionBuilder: implementFeatureInstruction,
      requestBuilder: implementFeatureRequest,
    );
    review = Scheduler(
      schedulerId: 'sched-review',
      workflowStore: workflowStore,
      jobStore: jobStore,
      workerStore: workerStore,
      dispatch: dispatch,
      definition: engineeringReviewDefinition,
      workload: _workload,
      clock: () => this.now,
      dedupeKeyBuilder: engineeringReviewDedupeKey,
      instructionBuilder: engineeringReviewInstruction,
      requestBuilder: engineeringReviewRequest,
      workloadResolver: _reviewWorkloadResolver(workerStore),
    );
  }

  /// Movable, because `RetryPolicy.retryDelay` is one minute and the second
  /// review cannot be claimed until it has elapsed. A clock frozen at the
  /// dispatch instant would make "the retry really ran" unobservable.
  DateTime now;

  late InMemoryWorkflowStore workflowStore;
  late InMemoryJobStore jobStore;
  late InMemoryWorkerStore workerStore;
  late DurableWorkflowEngine engine;
  late ControlledDispatcher dispatch;

  /// Lets the detached run's continuation release its claim,
  /// then ticks BOTH lanes — reconcile-adoption is lane-agnostic
  /// (F-237).
  Future<void> settle() async {
    await settleHeldJobs(jobStore, implementation);
    await settleHeldJobs(jobStore, review);
  }

  late Scheduler implementation;
  late Scheduler review;

  /// The producer row is AWAITED, not fired and forgotten: `producedCommitFor`
  /// reads it on the very next line, and a store write still in flight is a
  /// flaky test rather than a finding.
  static Future<_World> start({
    required WorkerExecution producer,
    required DateTime now,
  }) async {
    final world = _World._(producer: producer, now: now);
    await world.workerStore.saveWorkerExecution(producer);
    return world;
  }

  Future<WorkItem> item() => workflowStore.readWorkItem('wi-1');
}

void main() {
  final t0 = DateTime.utc(2026, 3, 1, 12);

  test('a returned review item goes back in front of a REVIEWER, and the '
      'implementation lane never sees it', () async {
    final world = await _World.start(
      producer: _producerExecution(
        agentExecutionId: 'agx-exec-impl-1',
        endingRevision: _producedCommit,
      ),
      now: t0,
    );
    await world.workflowStore.saveWorkItem(_atAgentCompleted());

    // ---- the reviewer runs and fails transiently.
    //
    // `agentCompleted` is the REVIEW lane's entry state, which is why a
    // committing producer is review's item. `OD-10`'s inflow DOES name
    // `reviewInProgress` as the route for a committing producer, but the
    // scheduler in this lane cannot supply the `agentResult` that edge's
    // guard needs, so the observable effect is that the item is LEFT at
    // `agentCompleted` where `sched-review` dispatches it. This test asserts
    // the effect that is actually observable, not the one the comment
    // describes.
    world.dispatch.resultBuilder = (request) async {
      await world.engine.transition(
        workItemId: request.workItemId,
        to: WorkItemState.reviewInProgress,
        trigger: TransitionTrigger.systemEvent,
        actor: const WorkflowActor(
          actorId: 'orchestrator',
          actorType: ActorType.orchestrator,
        ),
        // The coordinator supplies the IMPLEMENTER's completed result here,
        // from the execution store (`_reviewEntryTransitionContext`); the
        // `agentResultValid()` guard needs it and the scheduler cannot.
        context: {
          'agentAvailable': true,
          'capabilitiesMatch': true,
          'agentResult': _producerResult(request.workItemId),
        },
      );
      return WorkerExecutionResult(
        workerExecutionId: request.workerExecutionId,
        workItemId: request.workItemId,
        status: WorkerExecutionStatus.timedOut,
        workerId: 'w-scripted-1',
        workspaceId: 'ws-1',
        startingRevision: request.startingRevision,
        startedAt: t0,
        endedAt: t0,
        cleanupStatus: WorkerCleanupStatus.removed,
        failureCode: WorkerFailureCode.none,
      );
    };
    await world.review.tick();
    final dispatchedJob = (await world.jobStore.listJobs()).singleWhere(
      (j) => j.jobType == JobType.engineeringReview,
    );
    // The detached run ends when its continuation drops the claim — the
    // durable signal the crashed reviewer left the item HERE. That state is
    // read BEFORE any tick adopts the outcome: adoption and the retry-return
    // pass are one tick now, so post-adoption the item is already back at
    // agentCompleted.
    await waitUntil(
      () async =>
          await world.jobStore.readClaimForJob(dispatchedJob.jobId) == null,
      because: 'the crashed reviewer run to release its claim',
    );
    expect(
      (await world.item()).state,
      WorkItemState.reviewInProgress,
      reason: 'and the coordinator left a crashed reviewer HERE',
    );

    // ---- THE IMPL LANE TICK WHILE THE REVIEW RETRY IS OWED.
    //
    // This is the collision the scoping exists to prevent. The review lane's
    // job is `retryWaiting` and the item is outside the implementation lane's
    // entry states, so without `job.jobType == _definition.jobType` this lane
    // would consider returning an item it does not own.
    final implDuringReview = await world.implementation.tick();
    final reviewJob = (await world.jobStore.listJobs()).singleWhere(
      (j) => j.jobType == JobType.engineeringReview,
    );
    expect(
      reviewJob.state,
      JobState.retryWaiting,
      reason:
          'a retry really is owed — the implementation lane\'s reconcile '
          'adopted the terminal run, and only its OWN return pass is scoped',
    );
    expect(
      implDuringReview.retryReturned,
      isEmpty,
      reason:
          'the implementation lane must not touch the REVIEW lane\'s retry. '
          'Two schedulers share one job store and a lane is only entitled to '
          'move a work item for its OWN job — the day an '
          '`reviewInProgress -> implementationReady` edge existed, the '
          'unscoped pass would hijack a reviewer\'s retry.',
    );
    expect(
      implDuringReview.cancelledQueued,
      isNot(contains(reviewJob.jobId)),
      reason: 'nor retire it',
    );

    // ---- the review lane returns the item to ITS OWN entry state. Its
    // return pass sees the parked retry — nothing is adopted in this tick,
    // so no settle is needed between it and the assertions.
    final returned = await world.review.tick();
    expect(returned.retryReturned.where((m) => m.returned).map((m) => m.to), [
      WorkItemState.agentCompleted,
    ]);
    expect((await world.item()).state, WorkItemState.agentCompleted);

    // ---- THE DISCRIMINATOR, ON THE RETURNED ITEM.
    //
    // This is the whole point. The item is back at `agentCompleted`, the
    // exact state the inflow reads, and it must still be judged on the
    // PRODUCER'S ARTIFACT — which the return did not touch.
    final afterReturn = await world.item();
    final produced = await producedCommitFor(world.workerStore, afterReturn);
    expect(
      produced.isProduced,
      isTrue,
      reason:
          'the return moved the item and nothing else, so the producer '
          'evidence the discriminator reads is byte-identical. It is checked '
          'through the REAL function rather than by re-deriving, because the '
          'rule lives there.',
    );
    expect(completionRouteFor(produced), WorkItemState.reviewInProgress);
    expect(
      afterReturn.metadata?['producerActorId'],
      'agx-exec-impl-1',
      reason: 'and the return left the producer stamp exactly where it was',
    );

    // ---- THE IMPLEMENTATION LANE LOOKS AT THE RETURNED ITEM.
    world.dispatch.resultBuilder = null;
    world.dispatch.statusSeries = () => const [
      WorkerExecutionStatus.executedPass,
    ];
    final implTick = await world.implementation.tick();
    await world.settle();

    expect(
      implTick.completionInflow.where((m) => m.moved),
      isEmpty,
      reason:
          'A returned review item is NOT routed to `implementationReady`. '
          'The producer left a commit, so the discriminator says REVIEW, and '
          'the implementation lane must not act on it. Sending it to '
          'implementation would dispatch a SECOND implementer at a commit '
          'that already exists — the exact harm `OD-10` exists to prevent.',
    );
    expect(
      implTick.enqueued,
      isEmpty,
      reason: 'and no implementation job was minted for it',
    );
    expect(
      (await world.jobStore.listJobs()).where(
        (j) => j.jobType == JobType.implementFeature,
      ),
      isEmpty,
      reason:
          'there is no implementation job AT ALL — the discriminator kept '
          'the item out of that lane entirely',
    );

    // ---- AND THE REVIEW LANE PICKS IT UP AGAIN.
    //
    // Not merely "it was not stolen": the work really is wanted, and the
    // retry that was owed is the thing that collects it. Past the one-minute
    // back-off, or the retry is still parked and this proves nothing.
    world.now = t0.add(const Duration(minutes: 2));
    expect(
      world.review.queue.isEligibleAt(reviewJob, world.now),
      isTrue,
      reason: 'the back-off has elapsed, so the queue considers the retry due',
    );
    expect((await world.review.tick()).dispatched, hasLength(1));
    await world.settle();
    expect(
      world.dispatch.runs,
      hasLength(2),
      reason:
          'a SECOND REVIEWER really ran. That is the whole point of the '
          'return: the work was not stranded, and it was not duplicated into '
          'the wrong lane either.',
    );
    expect((await world.jobStore.listJobs()).single.state, JobState.succeeded);
  });
  test('the REVIEW gate refuses a no-commit producer, so an item can never sit '
      'at reviewInProgress with nothing to review', () async {
    // The stronger half of the answer, and the reason the two halves are not
    // a single assertion. The review lane's workload resolver returns null for
    // a no-commit producer, so the scheduler never dispatches and reports the
    // job in `blockedArtifactMissing` instead.
    //
    // Which means: an item at `reviewInProgress` ALWAYS had a committing
    // producer when this lane put it there. A returned review item therefore
    // cannot be an implementation-ready no-commit case even in principle —
    // the premise of the mistake is unreachable.
    final world = await _World.start(
      producer: _producerExecution(
        agentExecutionId: 'agx-exec-impl-1',
        // The triage shape: the run finished and committed NOTHING.
        endingRevision: _startRevision,
      ),
      now: t0,
    );
    await world.workflowStore.saveWorkItem(_atAgentCompleted());

    final tick = await world.review.tick();
    // No settle: the job was refused before any execution, so there is no
    // detached run to adopt — and the bundled implementation tick would
    // legitimately route this no-commit item, which is not what is asserted.

    expect(
      tick.blockedArtifactMissing,
      hasLength(1),
      reason:
          'the review lane refuses to dispatch with no artifact and REPORTS '
          'it, rather than sending a reviewer at a revision nobody committed',
    );
    expect(tick.dispatched, isEmpty);
    expect(
      (await world.item()).state,
      WorkItemState.agentCompleted,
      reason: 'and the item never entered review at all',
    );
    expect(
      (await world.jobStore.listJobs()).single.state,
      JobState.queued,
      reason: 'so there is no review retry for anything to return',
    );
  });

  test(
    'a returned item is still judged on its producer, and the two routes stay '
    'complementary',
    () async {
      // `apps/server/test/inflow_vs_review_route_test.dart` already executes
      // both mappings over the same durable rows and fails if they disagree.
      // What is asserted here is only the fact the return could have broken:
      // that the REVIEW lane and the INFLOW cannot both act on one item in one
      // tick, and that the review lane's stand-down logic keys off the SAME
      // discriminator rather than a second transcription of it.
      final world = await _World.start(
        producer: _producerExecution(
          agentExecutionId: 'agx-exec-impl-1',
          endingRevision: _producedCommit,
        ),
        now: t0,
      );
      final item = _atAgentCompleted();
      await world.workflowStore.saveWorkItem(item);

      final produced = await producedCommitFor(world.workerStore, item);
      final route = completionRouteFor(produced);

      expect(produced, isA<CommitProduced>());
      expect(route, WorkItemState.reviewInProgress);
      expect(
        engineeringReviewDefinition.entryStates,
        contains(WorkItemState.agentCompleted),
        reason: 'the state the return lands on is the review lane\'s entry',
      );
      expect(
        route,
        isNot(WorkItemState.implementationReady),
        reason:
            'so a committing producer is never mistaken for a no-commit one',
      );
      expect(
        implementFeatureDefinition.entryStates,
        isNot(contains(WorkItemState.reviewInProgress)),
        reason:
            'and the return target is never an implementation entry state, so '
            'the return cannot itself create the confusion',
      );
    },
  );
}
