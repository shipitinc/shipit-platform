import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';

WorkItem _itemAt(WorkItemState state) {
  final now = DateTime.utc(2026, 1, 1);
  return WorkItem(
    workItemId: 'wi-1',
    productId: 'prod-1',
    category: WorkItemCategory.feature,
    title: 'Implement the calculator',
    description: 'Implement the calculator add function for the contract',
    state: state,
    qaContractId: 'qa-1',
    featureRef: 'feature/calc',
    createdAt: now,
    updatedAt: now,
  );
}

Job _reviewJob() => Job(
  jobId: 'jb-review-1',
  workItemId: 'wi-1',
  jobType: JobType.engineeringReview,
  requiredRole: AgentRole.engineeringReviewer,
  requiredCapabilities: const {WorkerCapability.engineeringReview},
  priority: JobPriority.high,
  state: JobState.queued,
  dedupeKey: 'wi-1:engineering_review',
  createdAt: DateTime.utc(2026, 1, 1),
  instruction: 'review the implementation',
  attempt: 1,
  maxAttempts: 2,
  version: 1,
);

void main() {
  group('engineeringReviewDefinition', () {
    test('targets the reviewer at agent_completed', () {
      expect(engineeringReviewDefinition.jobType, JobType.engineeringReview);
      expect(
        engineeringReviewDefinition.requiredRole,
        AgentRole.engineeringReviewer,
      );
      expect(engineeringReviewDefinition.requiredCapabilities, {
        WorkerCapability.engineeringReview,
      });
      expect(engineeringReviewDefinition.entryStates, {
        WorkItemState.agentCompleted,
      });
      expect(engineeringReviewDefinition.priority, JobPriority.high);
      expect(
        engineeringReviewDefinition.targetState,
        WorkItemState.reviewInProgress,
      );
      // B1: the local policy probe asks for `agentCompleted -> reviewInProgress`
      // with a context that cannot carry the implementer's AgentResult, so the
      // probe is skipped. The real edge is enforced by the workflow engine at
      // the coordinator, which DOES supply the result.
      expect(engineeringReviewDefinition.skipWorkflowPolicyCheck, isTrue);
    });

    test('B1 regression: an item at agent_completed is runnable', () {
      const policy = WorkflowEngine();
      final evaluator = RunnableWorkEvaluator(policy: policy);

      expect(
        evaluator.evaluate(
          _itemAt(WorkItemState.agentCompleted),
          engineeringReviewDefinition,
        ),
        RunnableWorkStatus.runnable,
      );
    });

    test('the same item is noAction when the local policy probe is NOT skipped '
        '(that is why B1 needs skipWorkflowPolicyCheck)', () {
      const policy = WorkflowEngine();
      final evaluator = RunnableWorkEvaluator(policy: policy);
      const probe = JobDefinition(
        jobType: JobType.engineeringReview,
        requiredRole: AgentRole.engineeringReviewer,
        requiredCapabilities: {WorkerCapability.engineeringReview},
        entryStates: {WorkItemState.agentCompleted},
        priority: JobPriority.high,
        maxAttempts: 2,
        targetState: WorkItemState.reviewInProgress,
      );

      expect(
        evaluator.evaluate(_itemAt(WorkItemState.agentCompleted), probe),
        RunnableWorkStatus.noAction,
      );
    });
  });

  group('engineeringReview builders', () {
    test('dedupe key is work-item scoped', () {
      expect(
        engineeringReviewDedupeKey(
          _itemAt(WorkItemState.agentCompleted),
          engineeringReviewDefinition,
        ),
        'wi-1:engineering_review',
      );
    });

    test('instruction names the work item', () {
      final instruction = engineeringReviewInstruction(
        _itemAt(WorkItemState.agentCompleted),
        engineeringReviewDefinition,
      );
      expect(instruction, contains('wi-1'));
    });

    test('request carries the reviewer role and capability', () async {
      final request = await engineeringReviewRequest(
        _reviewJob(),
        const SchedulerWorkload(
          repositoryPath: '/repo',
          startingRevision: 'abc123',
          timeoutSeconds: 300,
          runtimeTypeId: 'rt-1',
        ),
        _itemAt(WorkItemState.agentCompleted),
        null,
      );

      expect(request.workItemId, 'wi-1');
      expect(request.role, AgentRole.engineeringReviewer);
      expect(request.repositoryPath, '/repo');
      expect(request.startingRevision, 'abc123');
      expect(request.requiredCapabilities, {
        WorkerCapability.engineeringReview,
      });
    });
  });
}
