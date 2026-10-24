import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';

void main() {
  const workItemId = 'wi-design-review-test';
  const revisionId = 'rev-test-1';
  const designerExecutionId = 'agx-designer-1';

  WorkItem makeItem({
    String? designRevisionId,
    String? designerExecutionId,
    int? designReviewAttempt,
  }) {
    return WorkItem(
      workItemId: workItemId,
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Design the login screen',
      state: WorkItemState.designInReview,
      qaContractId: 'qa-1',
      metadata: {
        if (designRevisionId != null) 'designRevisionId': designRevisionId,
        if (designerExecutionId != null)
          'designerExecutionId': designerExecutionId,
        if (designReviewAttempt != null)
          'designReviewAttempt': designReviewAttempt,
      },
      createdAt: DateTime.utc(2026, 10, 22, 12),
      updatedAt: DateTime.utc(2026, 10, 22, 12),
    );
  }

  JobDefinition makeDef() => JobDefinition(
    jobType: JobType.designReview,
    requiredRole: AgentRole.designReviewer,
    requiredCapabilities: const {
      WorkerCapability.penpotRead,
      WorkerCapability.designReview,
    },
    entryStates: {WorkItemState.designInReview},
    priority: JobPriority.high,
    maxAttempts: 2,
  );

  group('designReviewInstruction contract', () {
    test('includes the machine-readable JSON contract block', () {
      final item = makeItem(
        designRevisionId: revisionId,
        designerExecutionId: designerExecutionId,
      );
      final def = makeDef();

      final instruction = designReviewInstruction(item, def);

      // Prose part
      expect(instruction, contains('Review the design revision for'));
      expect(instruction, contains(workItemId));
      expect(instruction, contains('independent assessment'));

      // JSON contract block (tolerates a single surrounding code fence)
      expect(instruction, contains('verdict'));
      expect(instruction, contains('assessedDimensions'));
      expect(instruction, contains('findings'));
      expect(instruction, contains('category'));
      expect(instruction, contains('severity'));
      expect(instruction, contains('dimension'));
      expect(instruction, contains('evidence'));
      expect(instruction, contains('requiredCorrection'));
      expect(instruction, contains('affectedSurface'));
      expect(instruction, contains('reviewScope'));
      expect(instruction, contains('revisionId'));
      expect(instruction, contains('designSystemRevision'));
      expect(instruction, contains('provider'));
      expect(instruction, contains('fileId'));
      expect(instruction, contains('pageId'));
      expect(instruction, contains('boardIds'));

      // The contract is wrapped in a code fence
      expect(instruction, contains('```json'));
      expect(instruction, contains('```'));
    });
  });

  group('designReviewRequest fail-closed on missing designerExecutionId', () {
    test('throws StateError when designerExecutionId is absent', () async {
      final item = makeItem(
        designRevisionId: revisionId,
        designerExecutionId: null, // Missing!
      );
      final job = Job(
        jobId: 'job-review-1',
        workItemId: workItemId,
        jobType: JobType.designReview,
        requiredRole: AgentRole.designReviewer,
        requiredCapabilities: const {
          WorkerCapability.penpotRead,
          WorkerCapability.designReview,
        },
        priority: JobPriority.high,
        state: JobState.queued,
        dedupeKey: '$workItemId:$revisionId:${JobType.designReview.wire}',
        createdAt: DateTime.utc(2026, 10, 22, 12),
        instruction: 'Review the design',
        attempt: 1,
        maxAttempts: 2,
        version: 1,
      );
      final workload = SchedulerWorkload(
        repositoryPath: '/repo',
        startingRevision: 'main',
        timeoutSeconds: 300,
        runtimeTypeId: 'opencode',
      );

      expect(
        () => designReviewRequest(job, workload, item, null),
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'message',
            contains('designerExecutionId is missing'),
          ),
        ),
      );
    });

    test(
      'throws StateError when designerExecutionId is empty string',
      () async {
        final item = makeItem(
          designRevisionId: revisionId,
          designerExecutionId: '', // Empty!
        );

        final job = Job(
          jobId: 'job-review-2',
          workItemId: workItemId,
          jobType: JobType.designReview,
          requiredRole: AgentRole.designReviewer,
          requiredCapabilities: const {
            WorkerCapability.penpotRead,
            WorkerCapability.designReview,
          },
          priority: JobPriority.high,
          state: JobState.queued,
          dedupeKey: '$workItemId:$revisionId:${JobType.designReview.wire}',
          createdAt: DateTime.utc(2026, 10, 22, 12),
          instruction: 'Review the design',
          attempt: 1,
          maxAttempts: 2,
          version: 1,
        );
        final workload = SchedulerWorkload(
          repositoryPath: '/repo',
          startingRevision: 'main',
          timeoutSeconds: 300,
          runtimeTypeId: 'opencode',
        );

        expect(
          () => designReviewRequest(job, workload, item, null),
          throwsA(
            isA<StateError>().having(
              (e) => e.toString(),
              'message',
              contains('designerExecutionId is missing'),
            ),
          ),
        );
      },
    );

    test('succeeds when designerExecutionId is present', () async {
      final item = makeItem(
        designRevisionId: revisionId,
        designerExecutionId: designerExecutionId,
      );

      final job = Job(
        jobId: 'job-review-3',
        workItemId: workItemId,
        jobType: JobType.designReview,
        requiredRole: AgentRole.designReviewer,
        requiredCapabilities: const {
          WorkerCapability.penpotRead,
          WorkerCapability.designReview,
        },
        priority: JobPriority.high,
        state: JobState.queued,
        dedupeKey: '$workItemId:$revisionId:${JobType.designReview.wire}',
        createdAt: DateTime.utc(2026, 10, 22, 12),
        instruction: 'Review the design',
        attempt: 1,
        maxAttempts: 2,
        version: 1,
      );
      final workload = SchedulerWorkload(
        repositoryPath: '/repo',
        startingRevision: 'main',
        timeoutSeconds: 300,
        runtimeTypeId: 'opencode',
      );

      final request = await designReviewRequest(job, workload, item, null);

      expect(request.excludedExecutionIds, [designerExecutionId]);
    });
  });

  group('designReviewDedupeKey attempt discriminator', () {
    test('includes attempt discriminator a0 for attempt 0', () {
      final item = makeItem(
        designRevisionId: revisionId,
        designerExecutionId: designerExecutionId,
        designReviewAttempt: 0,
      );
      final def = makeDef();

      final key = designReviewDedupeKey(item, def);

      expect(
        key,
        '${workItemId}:${revisionId}:a0:${JobType.designReview.wire}',
      );
    });

    test('includes attempt discriminator a1 for attempt 1 (rework)', () {
      final item = makeItem(
        designRevisionId: revisionId,
        designerExecutionId: designerExecutionId,
        designReviewAttempt: 1,
      );

      final def = makeDef();

      final key = designReviewDedupeKey(item, def);

      expect(
        key,
        '${workItemId}:${revisionId}:a1:${JobType.designReview.wire}',
      );
    });

    test('includes attempt discriminator a2 for attempt 2', () {
      final item = makeItem(
        designRevisionId: revisionId,
        designerExecutionId: designerExecutionId,
        designReviewAttempt: 2,
      );

      final def = makeDef();

      final key = designReviewDedupeKey(item, def);

      expect(
        key,
        '${workItemId}:${revisionId}:a2:${JobType.designReview.wire}',
      );
    });

    test('defaults to a0 when designReviewAttempt is absent', () {
      final item = makeItem(
        designRevisionId: revisionId,
        designerExecutionId: designerExecutionId,
        designReviewAttempt: null,
      );

      final def = makeDef();

      final key = designReviewDedupeKey(item, def);

      expect(
        key,
        '${workItemId}:${revisionId}:a0:${JobType.designReview.wire}',
      );
    });

    test('uses unknown when designRevisionId is absent', () {
      final item = makeItem(
        designRevisionId: null,
        designerExecutionId: designerExecutionId,
        designReviewAttempt: 1,
      );

      final def = makeDef();

      final key = designReviewDedupeKey(item, def);

      expect(key, '${workItemId}:unknown:a1:${JobType.designReview.wire}');
    });
  });
}
