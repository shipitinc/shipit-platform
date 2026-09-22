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

  @override
  List<WorkflowState<WorkItemState>> get allowedTransitions => switch (value) {
    WorkItemState.draft => [WorkItemWorkflowState.planning],
    WorkItemState.planning => [
      WorkItemWorkflowState.planned,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.planned => [
      WorkItemWorkflowState.designRequired,
      WorkItemWorkflowState.designNotRequired,
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
    WorkItemState.agentExecuting => [
      WorkItemWorkflowState.agentCompleted,
      WorkItemWorkflowState.agentFailed,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.agentCompleted => [
      WorkItemWorkflowState.reviewInProgress,
      WorkItemWorkflowState.designInReview,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.agentFailed => [
      WorkItemWorkflowState.agentExecuting,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.reviewInProgress => [
      WorkItemWorkflowState.waitingForHumanDecision,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.reviewApproved => [
      WorkItemWorkflowState.qaInProgress,
      WorkItemWorkflowState.cancelled,
      WorkItemWorkflowState.terminated,
    ],
    WorkItemState.reviewRejected => [
      WorkItemWorkflowState.agentExecuting,
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
