import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'package:control_plane_server/src/review/engineering_review_gate.dart';

WorkItem _item(String workItemId, {String? producerActorId}) {
  final now = DateTime.utc(2026, 1, 1);
  return WorkItem(
    workItemId: workItemId,
    productId: 'prod-1',
    category: WorkItemCategory.feature,
    title: 't',
    state: WorkItemState.agentCompleted,
    createdAt: now,
    updatedAt: now,
    metadata: producerActorId == null
        ? null
        : {'producerActorId': producerActorId},
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
  String? agentExecutionId,
}) => WorkerExecution(
  workerExecutionId: id,
  workItemId: workItemId,
  repositoryPath: repositoryPath,
  requestedStartingRevision: startingRevision,
  requiredCapabilities: capabilities,
  status: WorkerExecutionStatus.executedPass,
  cleanupPolicy: WorkerCleanupPolicy.removeAlways,
  endingRevision: endingRevision,
  agentExecutionId: agentExecutionId,
  createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
);

WorkloadResolver _resolver(WorkerStore store) =>
    engineeringReviewWorkloadResolver(
      workerStore: store,
      runtimeTypeId: 'rt-review',
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
            agentExecutionId: 'agx-wx-impl',
          ),
        );
        await store.saveWorkerExecution(
          _exec(
            id: 'wx-review',
            workItemId: 'wi-1',
            endingRevision: 'rev-review',
            capabilities: const {WorkerCapability.engineeringReview},
            repositoryPath: '/review/repo',
            agentExecutionId: 'agx-wx-review',
          ),
        );

        final workload = await _resolver(store)(
          _job('wi-1'),
          _item('wi-1', producerActorId: 'agx-wx-impl'),
        );

        expect(workload, isNotNull);
        expect(workload!.repositoryPath, '/impl/repo');
        expect(workload.startingRevision, 'rev-produced');
        expect(workload.runtimeTypeId, 'rt-review');
      },
    );

    test(
      'selects the execution whose agentExecutionId matches producerActorId',
      () async {
        final store = InMemoryWorkerStore();
        await store.saveWorkerExecution(
          _exec(
            id: 'wx-impl',
            workItemId: 'wi-1',
            endingRevision: 'rev-produced',
            repositoryPath: '/impl/repo',
            agentExecutionId: 'agx-wx-impl',
          ),
        );

        final workload = await _resolver(store)(
          _job('wi-1'),
          _item('wi-1', producerActorId: 'agx-wx-impl'),
        );

        expect(workload, isNotNull);
        expect(workload!.repositoryPath, '/impl/repo');
        expect(workload.startingRevision, 'rev-produced');
      },
    );

    test('returns null when producerActorId is absent', () async {
      final store = InMemoryWorkerStore();
      await store.saveWorkerExecution(
        _exec(
          id: 'wx-impl',
          workItemId: 'wi-1',
          endingRevision: 'rev-produced',
          repositoryPath: '/impl/repo',
          agentExecutionId: 'agx-wx-impl',
        ),
      );

      // The work item carries no producer stamp at all, so there is nothing to
      // anchor to. A perfectly good artifact exists and is still NOT resolved.
      expect(await _resolver(store)(_job('wi-1'), _item('wi-1')), isNull);
    });

    test('returns null when producerActorId is empty', () async {
      final store = InMemoryWorkerStore();
      await store.saveWorkerExecution(
        _exec(
          id: 'wx-impl',
          workItemId: 'wi-1',
          endingRevision: 'rev-produced',
          agentExecutionId: 'agx-wx-impl',
        ),
      );

      expect(
        await _resolver(store)(
          _job('wi-1'),
          _item('wi-1', producerActorId: ''),
        ),
        isNull,
      );
    });

    test(
      'fails closed (null) when the only execution produced no artifact',
      () async {
        final store = InMemoryWorkerStore();
        await store.saveWorkerExecution(
          _exec(
            id: 'wx-impl',
            workItemId: 'wi-1',
            endingRevision: 'rev-start',
            agentExecutionId: 'agx-wx-impl',
          ),
        );

        // The anchor MATCHES here — this null is about the missing artifact,
        // not about a missing anchor.
        expect(
          await _resolver(store)(
            _job('wi-1'),
            _item('wi-1', producerActorId: 'agx-wx-impl'),
          ),
          isNull,
        );
      },
    );

    test(
      'returns null when the producer execution has no endingRevision',
      () async {
        final store = InMemoryWorkerStore();
        await store.saveWorkerExecution(
          _exec(
            id: 'wx-impl',
            workItemId: 'wi-1',
            agentExecutionId: 'agx-wx-impl',
          ),
        );

        expect(
          await _resolver(store)(
            _job('wi-1'),
            _item('wi-1', producerActorId: 'agx-wx-impl'),
          ),
          isNull,
        );
      },
    );

    test('ignores executions belonging to a different work item', () async {
      final store = InMemoryWorkerStore();
      await store.saveWorkerExecution(
        _exec(
          id: 'wx-other',
          workItemId: 'wi-other',
          endingRevision: 'rev-prod',
          // Even carrying the anchored id, an execution recorded against
          // another work item is not this work item's producer.
          agentExecutionId: 'agx-wx-other',
        ),
      );

      expect(
        await _resolver(store)(
          _job('wi-1'),
          _item('wi-1', producerActorId: 'agx-wx-other'),
        ),
        isNull,
      );
    });

    test('returns null when no execution carries the anchored id', () async {
      final store = InMemoryWorkerStore();
      await store.saveWorkerExecution(
        _exec(
          id: 'wx-impl',
          workItemId: 'wi-1',
          endingRevision: 'rev-produced',
          repositoryPath: '/impl/repo',
          agentExecutionId: 'agx-wx-impl',
        ),
      );

      expect(
        await _resolver(store)(
          _job('wi-1'),
          _item('wi-1', producerActorId: 'agx-wx-unknown'),
        ),
        isNull,
      );
    });

    test(
      'the anchored producer wins outright when several implementer '
      'executions exist, regardless of time',
      () async {
        final store = InMemoryWorkerStore();
        await store.saveWorkerExecution(
          _exec(
            id: 'wx-old',
            workItemId: 'wi-1',
            endingRevision: 'rev-old',
            repositoryPath: '/old',
            agentExecutionId: 'agx-wx-old',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );
        await store.saveWorkerExecution(
          _exec(
            id: 'wx-new',
            workItemId: 'wi-1',
            endingRevision: 'rev-new',
            repositoryPath: '/new',
            agentExecutionId: 'agx-wx-new',
            createdAt: DateTime.utc(2026, 2, 1),
          ),
        );

        // The stamp says the FIRST run produced this work item. The second run
        // is later but is not the producer, so it must not win.
        final workload = await _resolver(store)(
          _job('wi-1'),
          _item('wi-1', producerActorId: 'agx-wx-old'),
        );

        expect(workload, isNotNull);
        expect(workload!.repositoryPath, '/old');
        expect(workload.startingRevision, 'rev-old');
      },
    );

    test(
      'a LATER non-reviewer execution (a triage run) does NOT win over the '
      'anchored implementer execution',
      () async {
        final store = InMemoryWorkerStore();
        // The implementer: real repository, artifact committed.
        await store.saveWorkerExecution(
          _exec(
            id: 'wx-impl',
            workItemId: 'wi-1',
            startingRevision: 'rev-start',
            endingRevision: 'rev-impl',
            repositoryPath: '/repo',
            capabilities: const {WorkerCapability.git},
            agentExecutionId: 'agx-wx-impl',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );
        // A later triage run that dirtied ITS scratch worktree, so it committed
        // `shipit/impl/wi-1` there too — a real, later, non-reviewer artifact.
        await store.saveWorkerExecution(
          _exec(
            id: 'wx-triage',
            workItemId: 'wi-1',
            startingRevision: 'rev-triage-start',
            endingRevision: 'rev-triage',
            repositoryPath: '/triage-repo',
            capabilities: const {WorkerCapability.git},
            agentExecutionId: 'agx-wx-triage',
            createdAt: DateTime.utc(2026, 6, 1),
          ),
        );

        final workload = await _resolver(store)(
          _job('wi-1'),
          _item('wi-1', producerActorId: 'agx-wx-impl'),
        );

        expect(workload, isNotNull);
        expect(workload!.repositoryPath, '/repo');
        expect(workload.startingRevision, 'rev-impl');
      },
    );

    test('a reviewer execution is never returned', () async {
      final store = InMemoryWorkerStore();
      // The stamp names an execution that IS a reviewer. A reviewer never
      // produces an artifact, so resolving it would dispatch a reviewer at a
      // revision no implementer produced.
      await store.saveWorkerExecution(
        _exec(
          id: 'wx-review',
          workItemId: 'wi-1',
          endingRevision: 'rev-review',
          capabilities: const {WorkerCapability.engineeringReview},
          repositoryPath: '/review/repo',
          agentExecutionId: 'agx-wx-review',
        ),
      );

      expect(
        await _resolver(store)(
          _job('wi-1'),
          _item('wi-1', producerActorId: 'agx-wx-review'),
        ),
        isNull,
      );
    });

    test(
      'fails closed when two executions carry the same anchored id',
      () async {
        final store = InMemoryWorkerStore();
        await store.saveWorkerExecution(
          _exec(
            id: 'wx-a',
            workItemId: 'wi-1',
            endingRevision: 'rev-a',
            repositoryPath: '/a',
            agentExecutionId: 'agx-duplicate',
          ),
        );
        await store.saveWorkerExecution(
          _exec(
            id: 'wx-b',
            workItemId: 'wi-1',
            endingRevision: 'rev-b',
            repositoryPath: '/b',
            agentExecutionId: 'agx-duplicate',
          ),
        );

        // Ambiguous: picking either would be a guess about which revision the
        // reviewer must inspect.
        expect(
          await _resolver(store)(
            _job('wi-1'),
            _item('wi-1', producerActorId: 'agx-duplicate'),
          ),
          isNull,
        );
      },
    );
  });
}
