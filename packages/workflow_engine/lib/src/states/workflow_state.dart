import 'package:platform_contracts/platform_contracts.dart';

sealed class WorkflowState<T> {
  const WorkflowState();

  T get value;

  List<WorkflowState<T>> get allowedTransitions;

  bool canTransitionTo(WorkflowState<T> target) {
    return allowedTransitions.contains(target);
  }
}

final class WorkItemWorkflowState extends WorkflowState<WorkItemState> {
  const WorkItemWorkflowState(this.value);

  @override
  final WorkItemState value;

  /// Mirror of the accepted pairs in `WorkItemTransitions._legalTransitions`
  /// plus the generic non-terminal -> `cancelled`/`terminated` escapes.
  ///
  /// This list is CORRECTNESS-OF-RECORD, not a runtime authority: nothing
  /// consults it. `WorkItemTransitions.isLegalTransition` reads the table
  /// directly, `TransitionValidator` only ever sees guards handed to it, and
  /// `canTransitionTo` (the only reader of this list) has zero callers. It is
  /// kept in sync anyway because a stale list here is a lie that the next
  /// reader will believe, and `transition_consistency_test.dart` fails if the
  /// two ever diverge again.
  @override
  List<WorkflowState<WorkItemState>> get allowedTransitions => switch (value) {
    WorkItemState.draft => [
      WorkItemWorkflowState.planning,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.planning => [
      WorkItemWorkflowState.planned,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.planned => [
      WorkItemWorkflowState.designRequired,
      WorkItemWorkflowState.designNotRequired,
      WorkItemWorkflowState.featureIntakeParked,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.featureIntakeParked => [
      WorkItemWorkflowState.waitingForHumanDecision,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.designRequired => [
      WorkItemWorkflowState.designInReview,
      WorkItemWorkflowState.agentExecuting,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.designNotRequired => [
      WorkItemWorkflowState.agentExecuting,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.designInReview => [
      WorkItemWorkflowState.waitingForHumanDecision,
      WorkItemWorkflowState.agentExecuting,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.designApproved => [
      WorkItemWorkflowState.agentExecuting,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.designRejected => [
      WorkItemWorkflowState.designInReview,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.implementationReady => [
      WorkItemWorkflowState.agentExecuting,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.agentExecuting => [
      WorkItemWorkflowState.agentCompleted,
      WorkItemWorkflowState.agentFailed,
      WorkItemWorkflowState.featureIntakeParked,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.agentCompleted => [
      WorkItemWorkflowState.implementationReady,
      WorkItemWorkflowState.reviewInProgress,
      WorkItemWorkflowState.designInReview,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.agentFailed => [
      WorkItemWorkflowState.agentExecuting,
      WorkItemWorkflowState.designNotRequired,
      // The RETRY RETURN edges (decision 3659984d, option A). Each lands on a
      // state that is ALREADY an entry state of a wired `JobDefinition`; none of
      // them adds a state to any entry set. Exactly one per entry set, so the
      // scheduler's policy-derived return target stays unambiguous — see
      // `work_item_transitions.dart` and `Scheduler._returnRetryableItems`.
      WorkItemWorkflowState.implementationReady,
      WorkItemWorkflowState.designRequired,
      WorkItemWorkflowState.designInReview,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.reviewInProgress => [
      WorkItemWorkflowState.waitingForHumanDecision,
      // The REVIEW lane's retry return. Not an approval: `agentCompleted` has no
      // route to `reviewApproved`, it only puts the item back in front of a
      // reviewer.
      WorkItemWorkflowState.agentCompleted,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.reviewApproved => [
      WorkItemWorkflowState.qaInProgress,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.reviewRejected => [
      WorkItemWorkflowState.designNotRequired,
      WorkItemWorkflowState.designInReview,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.qaInProgress => [
      WorkItemWorkflowState.qaPassed,
      WorkItemWorkflowState.qaFailed,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.qaPassed => [
      WorkItemWorkflowState.waitingForHumanDecision,
      WorkItemWorkflowState.deploying,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.qaFailed => [
      WorkItemWorkflowState.waitingForHumanDecision,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.waitingForHumanDecision => [
      WorkItemWorkflowState.designApproved,
      WorkItemWorkflowState.designRejected,
      WorkItemWorkflowState.designInReview,
      WorkItemWorkflowState.reviewApproved,
      WorkItemWorkflowState.reviewRejected,
      WorkItemWorkflowState.agentExecuting,
      WorkItemWorkflowState.designNotRequired,
      WorkItemWorkflowState.implementationReady,
      WorkItemWorkflowState.planning,
      WorkItemWorkflowState.qaPassed,
      WorkItemWorkflowState.deployed,
      WorkItemWorkflowState.deploymentFailed,
      WorkItemWorkflowState.completed,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.deploying => [
      WorkItemWorkflowState.waitingForHumanDecision,
      WorkItemWorkflowState.deployed,
      WorkItemWorkflowState.deploymentFailed,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.deployed => [
      WorkItemWorkflowState.completed,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.deploymentFailed => [
      WorkItemWorkflowState.deploying,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.completed => [],
    WorkItemState.cancelled => [],
    WorkItemState.terminated => [],
    WorkItemState.done => [],
  };

  static const draft = WorkItemWorkflowState(WorkItemState.draft);
  static const planning = WorkItemWorkflowState(WorkItemState.planning);
  static const planned = WorkItemWorkflowState(WorkItemState.planned);
  static const featureIntakeParked = WorkItemWorkflowState(
    WorkItemState.featureIntakeParked,
  );
  static const designRequired = WorkItemWorkflowState(
    WorkItemState.designRequired,
  );
  static const designNotRequired = WorkItemWorkflowState(
    WorkItemState.designNotRequired,
  );
  static const designInReview = WorkItemWorkflowState(
    WorkItemState.designInReview,
  );
  static const designApproved = WorkItemWorkflowState(
    WorkItemState.designApproved,
  );
  static const designRejected = WorkItemWorkflowState(
    WorkItemState.designRejected,
  );
  static const implementationReady = WorkItemWorkflowState(
    WorkItemState.implementationReady,
  );
  static const agentExecuting = WorkItemWorkflowState(
    WorkItemState.agentExecuting,
  );
  static const agentCompleted = WorkItemWorkflowState(
    WorkItemState.agentCompleted,
  );
  static const agentFailed = WorkItemWorkflowState(WorkItemState.agentFailed);
  static const reviewInProgress = WorkItemWorkflowState(
    WorkItemState.reviewInProgress,
  );
  static const reviewApproved = WorkItemWorkflowState(
    WorkItemState.reviewApproved,
  );
  static const reviewRejected = WorkItemWorkflowState(
    WorkItemState.reviewRejected,
  );
  static const qaInProgress = WorkItemWorkflowState(WorkItemState.qaInProgress);
  static const qaPassed = WorkItemWorkflowState(WorkItemState.qaPassed);
  static const qaFailed = WorkItemWorkflowState(WorkItemState.qaFailed);
  static const waitingForHumanDecision = WorkItemWorkflowState(
    WorkItemState.waitingForHumanDecision,
  );
  static const deploying = WorkItemWorkflowState(WorkItemState.deploying);
  static const deployed = WorkItemWorkflowState(WorkItemState.deployed);
  static const deploymentFailed = WorkItemWorkflowState(
    WorkItemState.deploymentFailed,
  );
  static const completed = WorkItemWorkflowState(WorkItemState.completed);
  static const cancelled = WorkItemWorkflowState(WorkItemState.cancelled);
  static const terminated = WorkItemWorkflowState(WorkItemState.terminated);
  static const done = WorkItemWorkflowState(WorkItemState.done);
}

final class DesignContractState extends WorkflowState<DesignContractStatus> {
  const DesignContractState(this.value);

  @override
  final DesignContractStatus value;

  @override
  List<WorkflowState<DesignContractStatus>> get allowedTransitions =>
      switch (value) {
        DesignContractStatus.draft => [DesignContractState.underReview],
        DesignContractStatus.underReview => [
          DesignContractState.approved,
          DesignContractState.rejected,
          DesignContractState.expired,
        ],
        DesignContractStatus.approved => [],
        DesignContractStatus.rejected => [DesignContractState.draft],
        DesignContractStatus.expired => [DesignContractState.draft],
      };

  static const draft = DesignContractState(DesignContractStatus.draft);
  static const underReview = DesignContractState(
    DesignContractStatus.underReview,
  );
  static const approved = DesignContractState(DesignContractStatus.approved);
  static const rejected = DesignContractState(DesignContractStatus.rejected);
  static const expired = DesignContractState(DesignContractStatus.expired);
}

final class QAState extends WorkflowState<QAStatus> {
  const QAState(this.value);

  @override
  final QAStatus value;

  @override
  List<WorkflowState<QAStatus>> get allowedTransitions => switch (value) {
    QAStatus.pending => [QAState.inProgress],
    QAStatus.inProgress => [QAState.passed, QAState.failed, QAState.waived],
    QAStatus.passed => [],
    QAStatus.failed => [QAState.inProgress, QAState.waived],
    QAStatus.waived => [],
  };

  static const pending = QAState(QAStatus.pending);
  static const inProgress = QAState(QAStatus.inProgress);
  static const passed = QAState(QAStatus.passed);
  static const failed = QAState(QAStatus.failed);
  static const waived = QAState(QAStatus.waived);
}

final class DeploymentState extends WorkflowState<DeploymentPhase> {
  const DeploymentState(this.value);

  @override
  final DeploymentPhase value;

  @override
  List<WorkflowState<DeploymentPhase>> get allowedTransitions =>
      switch (value) {
        DeploymentPhase.building => [DeploymentState.promoting],
        DeploymentPhase.promoting => [DeploymentState.deploying],
        DeploymentPhase.deploying => [DeploymentState.validating],
        DeploymentPhase.validating => [
          DeploymentState.completed,
          DeploymentState.failed,
        ],
        DeploymentPhase.completed => [],
        DeploymentPhase.failed => [
          DeploymentState.rolledBack,
          DeploymentState.deploying,
        ],
        DeploymentPhase.rolledBack => [DeploymentState.deploying],
      };

  static const building = DeploymentState(DeploymentPhase.building);
  static const promoting = DeploymentState(DeploymentPhase.promoting);
  static const deploying = DeploymentState(DeploymentPhase.deploying);
  static const validating = DeploymentState(DeploymentPhase.validating);
  static const completed = DeploymentState(DeploymentPhase.completed);
  static const failed = DeploymentState(DeploymentPhase.failed);
  static const rolledBack = DeploymentState(DeploymentPhase.rolledBack);
}
