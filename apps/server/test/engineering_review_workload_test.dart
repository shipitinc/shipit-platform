import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'package:control_plane_server/src/review/engineering_review_gate.dart';

WorkItem _item(String workItemId) {
  final now = DateTime.utc(2026, 1, 1);
  return WorkItem(
    workItemId: workItemId,
    productId: 'prod-1',
    category: WorkItemCategory.feature,
    title: 't',
    state: WorkItemState.agentCompleted,
    createdAt: now,
    updatedAt: now,
  );
}

Job _job(String workItemId) {
  final now = DateTime.utc(2026, 1, 1);
  return Job(
    jobId: 'job-1',
    workItemId: workItemId,
    jobType: JobType.engineeringReview,
    requiredRole: AgentRole.engineeringReviewer,
    requiredCapabilities: const {WorkerCapability.engineeringReview},
    priority: JobPriority.normal,
    state: JobState.queued,
    dedupeKey: 'dedupe',
    createdAt: now,
    instruction: 'review',
    attempt: 0,
    maxAttempts: 3,
    version: 1,
  );
}

WorkerExecution _exec({
  required String id,
  required String workItemId,
  String startingRevision = 'rev-start',
  String? endingRevision,
  Set<WorkerCapability> capabilities = const {WorkerCapability.flutter},
  String repositoryPath = '/repo',
  DateTime? createdAt,
}) => WorkerExecution(
  workerExecutionId: id,
  workItemId: workItemId,
  repositoryPath: repositoryPath,
  requestedStartingRevision: startingRevision,
  requiredCapabilities: capabilities,
  status: WorkerExecutionStatus.executedPass,
  cleanupPolicy: WorkerCleanupPolicy.removeAlways,
  endingRevision: endingRevision,
  createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
);

void main() {
  group('engineeringReviewWorkloadResolver', () {
    test(
      'resolves the produced revision from the implementer execution, never '
      'from a reviewer execution',
      () async {
        final store = InMemoryWorkerStore();
        await store.saveWorkerExecution(
          _exec(
            id: 'wx-impl',
            workItemId: 'wi-1',
            endingRevision: 'rev-produced',
            repositoryPath: '/impl/repo',
          ),
        );
        await store.saveWorkerExecution(
          _exec(
            id: 'wx-review',
            workItemId: 'wi-1',
            endingRevision: 'rev-review',
            capabilities: const {WorkerCapability.engineeringReview},
            repositoryPath: '/review/repo',
          ),
        );

        final resolver = engineeringReviewWorkloadResolver(
          workerStore: store,
          runtimeTypeId: 'rt-review',
        );

        final workload = await resolver(_job('wi-1'), _item('wi-1'));

        expect(workload, isNotNull);
        expect(workload!.repositoryPath, '/impl/repo');
        expect(workload.startingRevision, 'rev-produced');
        expect(workload.runtimeTypeId, 'rt-review');
      },
    );

    test(
      'fails closed (null) when the only execution produced no artifact',
      () async {
        final store = InMemoryWorkerStore();
        await store.saveWorkerExecution(
          _exec(
            id: 'wx-impl',
            workItemId: 'wi-1',
            endingRevision: 'rev-start',
          ),
        );

        final resolver = engineeringReviewWorkloadResolver(
          workerStore: store,
          runtimeTypeId: 'rt-review',
        );

        expect(await resolver(_job('wi-1'), _item('wi-1')), isNull);
      },
    );

    test('ignores executions belonging to a different work item', () async {
      final store = InMemoryWorkerStore();
      await store.saveWorkerExecution(
        _exec(
          id: 'wx-other',
          workItemId: 'wi-other',
          endingRevision: 'rev-prod',
        ),
      );

      final resolver = engineeringReviewWorkloadResolver(
        workerStore: store,
        runtimeTypeId: 'rt-review',
      );

      expect(await resolver(_job('wi-1'), _item('wi-1')), isNull);
    });

    test(
      'selects the most recent produced artifact when several exist',
      () async {
        final store = InMemoryWorkerStore();
        await store.saveWorkerExecution(
          _exec(
            id: 'wx-old',
            workItemId: 'wi-1',
            endingRevision: 'rev-old',
            repositoryPath: '/old',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );
        await store.saveWorkerExecution(
          _exec(
            id: 'wx-new',
            workItemId: 'wi-1',
            endingRevision: 'rev-new',
            repositoryPath: '/new',
            createdAt: DateTime.utc(2026, 2, 1),
          ),
        );

        final resolver = engineeringReviewWorkloadResolver(
          workerStore: store,
          runtimeTypeId: 'rt-review',
        );

        final workload = await resolver(_job('wi-1'), _item('wi-1'));
        expect(workload, isNotNull);
        expect(workload!.repositoryPath, '/new');
        expect(workload.startingRevision, 'rev-new');
      },
    );
  });
}
