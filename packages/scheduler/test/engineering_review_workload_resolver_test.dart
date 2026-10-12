import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';

/// Captures the request the scheduler built, and reports "no compatible
/// worker" so no execution ever runs. The request is the observable under
/// test: whether it was built at all, and from WHICH workload.
class _CapturingDispatch implements WorkerDispatch {
  final List<WorkerExecutionRequest> requests = [];

  @override
  WorkerSelection select(WorkerExecutionRequest request) {
    requests.add(request);
    return WorkerSelection.noCompatibleWorker();
  }

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) =>
      throw StateError('run must never be called by this test');

  @override
  Future<void> cancel(String workerId, String reason) async {}
}

WorkItem _itemAt(WorkItemState state) {
  final now = DateTime.utc(2026, 1, 1);
  return WorkItem(
    workItemId: 'wi-1',
    productId: 'prod-1',
    category: WorkItemCategory.feature,
    title: 'Implement the calculator',
    description: 'desc',
    state: state,
    qaContractId: 'qa-1',
    featureRef: 'feature/calc',
    createdAt: now,
    updatedAt: now,
  );
}

/// The construction-time workload. Every test proves it is NOT what the review
/// job dispatched against when a resolver is configured.
const _fallbackWorkload = SchedulerWorkload(
  repositoryPath: '/fallback/repo',
  startingRevision: 'fallback-rev',
  timeoutSeconds: 300,
  runtimeTypeId: 'rt-fallback',
);

Scheduler _reviewScheduler({
  required WorkflowStore workflowStore,
  required JobStore jobStore,
  required WorkerDispatch dispatch,
  WorkloadResolver? workloadResolver,
  RequestBuilder? requestBuilder,
}) => Scheduler(
  schedulerId: 'sched-review',
  workflowStore: workflowStore,
  jobStore: jobStore,
  workerStore: InMemoryWorkerStore(),
  dispatch: dispatch,
  definition: engineeringReviewDefinition,
  workload: _fallbackWorkload,
  dedupeKeyBuilder: engineeringReviewDedupeKey,
  instructionBuilder: engineeringReviewInstruction,
  requestBuilder: requestBuilder ?? engineeringReviewRequest,
  workloadResolver: workloadResolver,
);

void main() {
  group('Scheduler workloadResolver', () {
    test('builds the review request from the RESOLVED workload, not the '
        'construction-time default', () async {
      final workflowStore = InMemoryWorkflowStore();
      await workflowStore.saveWorkItem(_itemAt(WorkItemState.agentCompleted));
      final jobStore = InMemoryJobStore();
      final dispatch = _CapturingDispatch();
      var resolverCalls = 0;

      final scheduler = _reviewScheduler(
        workflowStore: workflowStore,
        jobStore: jobStore,
        dispatch: dispatch,
        workloadResolver: (job, item) async {
          resolverCalls++;
          // The produced revision, resolved from durable state.
          return const SchedulerWorkload(
            repositoryPath: '/produced/repo',
            startingRevision: 'produced-rev-42',
            timeoutSeconds: 300,
            runtimeTypeId: 'rt-produced',
          );
        },
      );

      final result = await scheduler.tick();

      expect(resolverCalls, 1);
      expect(dispatch.requests, hasLength(1));
      final request = dispatch.requests.single;
      expect(request.repositoryPath, '/produced/repo');
      expect(request.startingRevision, 'produced-rev-42');
      expect(request.runtimeTypeId, 'rt-produced');
      expect(request.role, AgentRole.engineeringReviewer);
      expect(result.blockedArtifactMissing, isEmpty);
      expect(result.dispatched, isEmpty); // no compatible worker
    });

    test(
      'fails closed when the resolver returns null: no request is built, '
      'the job is reported blocked (not deferred) and stays queued',
      () async {
        final workflowStore = InMemoryWorkflowStore();
        await workflowStore.saveWorkItem(_itemAt(WorkItemState.agentCompleted));
        final jobStore = InMemoryJobStore();
        final dispatch = _CapturingDispatch();
        var builderCalls = 0;

        final scheduler = _reviewScheduler(
          workflowStore: workflowStore,
          jobStore: jobStore,
          dispatch: dispatch,
          workloadResolver: (job, item) async => null,
          requestBuilder: (job, workload, item, selection) async {
            builderCalls++;
            return engineeringReviewRequest(job, workload, item, selection);
          },
        );

        final result = await scheduler.tick();

        // The request builder is never reached, so nothing can be dispatched
        // against the construction-time fallback workload.
        expect(builderCalls, 0);
        expect(dispatch.requests, isEmpty);

        // Reported as blocked-artifact-missing, NOT ordinary deferral, and the
        // job is untouched and still queued for the composition root to act on.
        expect(result.blockedArtifactMissing, hasLength(1));
        expect(result.deferred, isEmpty);
        final jobs = await jobStore.listJobs();
        expect(jobs, hasLength(1));
        expect(jobs.single.state, JobState.queued);
        expect(jobs.single.jobType, JobType.engineeringReview);
      },
    );

    test('a scheduler without a resolver keeps using its construction-time '
        'workload', () async {
      final workflowStore = InMemoryWorkflowStore();
      await workflowStore.saveWorkItem(_itemAt(WorkItemState.agentCompleted));
      final jobStore = InMemoryJobStore();
      final dispatch = _CapturingDispatch();

      final scheduler = _reviewScheduler(
        workflowStore: workflowStore,
        jobStore: jobStore,
        dispatch: dispatch,
      );

      final result = await scheduler.tick();

      expect(dispatch.requests, hasLength(1));
      expect(dispatch.requests.single.repositoryPath, '/fallback/repo');
      expect(dispatch.requests.single.startingRevision, 'fallback-rev');
      expect(result.blockedArtifactMissing, isEmpty);
    });
  });
}
