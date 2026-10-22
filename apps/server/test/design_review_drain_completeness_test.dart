import 'package:control_plane_server/server.dart'
    show runReviewLaneTick, triageSectionDrainHandlers;
import 'package:control_plane_server/src/triage/lane_i_tick_hook.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';
import 'package:workflow_store/workflow_store.dart';

/// THE PROOF that a terminal `designReview` job is observed by BOTH drains that
/// can reconcile it.
///
/// ## THE DEFECT THIS CLOSES (review B1 on `1a027e9`)
///
/// Step 8 mounted `sched-design-review` but registered `JobType.designReview`
/// only in the two DESIGN-lane tables. Every `Scheduler.tick()` step 1
/// reconciles EVERY held job in the shared `JobStore` — not only its own lane's
/// rows — and the triage scheduler ticks first. A design-review lease expiry
/// therefore surfaced in the triage drain, which dispatches BY TYPE and throws
/// [UnhandledJobTypeException] for a considered job with no handler BEFORE its
/// `!job.isTerminal` skip. The triage section was marked failed and
/// `observeCompletedDesignReviewJob` / the design tick's `unconsumedReviewJobIds`
/// were never reached.
///
/// At `1a027e9` the triage table has no `designReview` entry, so the first test
/// below raises `UnhandledJobTypeException` for `job-design-review-triage`; the
/// review-section table has no entry either, so the second test throws for
/// `job-design-review-review`. Both are green only when both tables name the
/// type.
///
/// ## WHY THE TRIAGE TEST CALLS `triageSectionDrainHandlers`
///
/// That function IS the production table: `run()` passes its result straight to
/// `drainTriageOutcomesFromTick`. The test does not transcribe the table — a copy
/// is only ever consistent with itself and would stay green through the exact
/// omission this file exists to catch.
void main() {
  const workItemId = 'wi-design-review-drain';
  const triageJobId = 'job-design-review-triage';
  const reviewJobId = 'job-design-review-review';
  const repositoryPath = '/durable/clone';
  const startingRevision = 'aaaaaaa';
  final now = DateTime.utc(2026, 10, 22, 12);

  Job terminalDesignReviewJob(String jobId) => Job(
    jobId: jobId,
    workItemId: workItemId,
    jobType: JobType.designReview,
    requiredRole: AgentRole.designReviewer,
    requiredCapabilities: const {
      WorkerCapability.penpotRead,
      WorkerCapability.designReview,
    },
    priority: JobPriority.high,
    state: JobState.succeeded,
    dedupeKey: '$workItemId:$jobId:${JobType.designReview.wire}',
    createdAt: now,
    instruction: 'Review the design revision',
    attempt: 1,
    maxAttempts: designReviewDefinition.maxAttempts,
    version: 1,
  );

  group('the TRIAGE drain registers designReview', () {
    test('a terminal designReview job is observed instead of throwing '
        'UnhandledJobTypeException', () async {
      final jobStore = InMemoryJobStore();
      await jobStore.saveJob(terminalDesignReviewJob(triageJobId));

      final logs = <(String, Map<String, dynamic>)>[];
      final handlers = triageSectionDrainHandlers(
        workflowEngine: DurableWorkflowEngine(store: InMemoryWorkflowStore()),
        executionStore: InMemoryExecutionStore(),
        workerStore: InMemoryWorkerStore(),
        logger: (event, data) => logs.add((event, data)),
      );

      // The table itself must name the type, not merely tolerate the job
      // because some other handler happened to answer.
      expect(
        handlers.keys,
        contains(JobType.designReview),
        reason:
            'the triage section shares one JobStore with every scheduler; a '
            'type any of them can reconcile must be registered here',
      );

      // There is no unconsumed-review list on this drain, so the observation is
      // `observeCompletedDesignReviewJob`'s own log line. Reaching it at all is
      // the fix; the event name is the evidence.
      final drain = await drainTriageOutcomesFromTick(
        tickResult: const SchedulerTickResult(
          reconciled: [],
          enqueued: [],
          dispatched: [],
          cancelledQueued: [],
          deferred: [],
          terminal: [triageJobId],
        ),
        jobStore: jobStore,
        handlers: handlers,
        logger: (event, data) => logs.add((event, data)),
      );

      expect(drain.succeededJobIds, contains(triageJobId));
      expect(drain.failedJobIds, isEmpty);
      expect(
        logs.map((event) => event.$1),
        contains('design.review.completed'),
      );
    });
  });

  group('the REVIEW-SECTION drain registers designReview', () {
    test('a terminal designReview job reconciled by the review tick is '
        'observed instead of throwing UnhandledJobTypeException', () async {
      final workflowStore = InMemoryWorkflowStore();
      final workflowEngine = DurableWorkflowEngine(store: workflowStore);
      final executionStore = InMemoryExecutionStore();
      final jobStore = InMemoryJobStore();
      final workerStore = InMemoryWorkerStore();

      // `agentCompleted` rather than `designInReview`: the review scheduler's
      // entry state is `designInReview`, and leaving the item there would make
      // THIS tick mint a second review job. The job under test is the `running`
      // row step 1 reconciles, which is exactly the lease-expiry shape that
      // reached the triage drain first in production.
      await workflowStore.saveWorkItem(
        WorkItem(
          workItemId: workItemId,
          productId: 'prod-1',
          category: WorkItemCategory.feature,
          title: 'Review the login screen revision',
          state: WorkItemState.agentCompleted,
          qaContractId: 'qa-1',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await workerStore.saveWorkerExecution(
        WorkerExecution(
          workerExecutionId: 'wx-review',
          workItemId: workItemId,
          repositoryPath: repositoryPath,
          requestedStartingRevision: startingRevision,
          requiredCapabilities: const {
            WorkerCapability.penpotRead,
            WorkerCapability.designReview,
          },
          agentExecutionId: 'agx-review',
          endingRevision: 'c0ffee1',
          status: WorkerExecutionStatus.executedPass,
          cleanupPolicy: WorkerCleanupPolicy.removeAlways,
          startedAt: now,
          endedAt: now,
        ),
      );

      await jobStore.saveJob(
        Job(
          jobId: reviewJobId,
          workItemId: workItemId,
          jobType: JobType.designReview,
          requiredRole: AgentRole.designReviewer,
          requiredCapabilities: const {
            WorkerCapability.penpotRead,
            WorkerCapability.designReview,
          },
          priority: JobPriority.high,
          state: JobState.running,
          dedupeKey: '$workItemId:revision-1:${JobType.designReview.wire}',
          createdAt: now,
          instruction: 'Review the design revision',
          attempt: 1,
          maxAttempts: designReviewDefinition.maxAttempts,
          version: 1,
          executionReference: JobExecutionReference(
            workerExecutionId: 'wx-review',
            agentExecutionId: 'agx-review',
            createdAt: now,
          ),
        ),
      );

      final logs = <(String, Map<String, dynamic>)>[];
      final reviewScheduler = Scheduler(
        schedulerId: 'sched-design-review',
        workflowStore: workflowStore,
        jobStore: jobStore,
        workerStore: workerStore,
        dispatch: _NoWorkerDispatch(),
        definition: designReviewDefinition,
        workload: const SchedulerWorkload(
          repositoryPath: repositoryPath,
          startingRevision: startingRevision,
          timeoutSeconds: 300,
          runtimeTypeId: 'rt-design',
        ),
        dedupeKeyBuilder: designReviewDedupeKey,
        instructionBuilder: designReviewInstruction,
        requestBuilder: designReviewRequest,
        clock: () => now,
      );

      // `runReviewLaneTick` is the production REVIEW section. At `1a027e9` its
      // drain table has no `designReview` entry and this call throws
      // `UnhandledJobTypeException` for `job-design-review-review`.
      final result = await runReviewLaneTick(
        reviewScheduler: reviewScheduler,
        jobStore: jobStore,
        triageProcessor: null,
        workflowEngine: workflowEngine,
        executionStore: executionStore,
        workerStore: workerStore,
        foldStalls: (_) {},
        log: (event, data) => logs.add((event, data)),
      );

      expect(result.drain.succeededJobIds, contains(reviewJobId));
      expect(result.drain.failedJobIds, isEmpty);
      expect(
        logs.map((event) => event.$1),
        contains('design.review.completed'),
      );
    });
  });
}

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
