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
    WorkItemState.draft => [WorkItemWorkflowState.designInReview],
    WorkItemState.designInReview => [
      WorkItemWorkflowState.designApproved,
      WorkItemWorkflowState.designRejected,
    ],
    WorkItemState.designApproved => [WorkItemWorkflowState.agentExecuting],
    WorkItemState.designRejected => [WorkItemWorkflowState.draft],
    WorkItemState.agentExecuting => [
      WorkItemWorkflowState.agentCompleted,
      WorkItemWorkflowState.agentFailed,
    ],
    WorkItemState.agentCompleted => [WorkItemWorkflowState.qaInProgress],
    WorkItemState.agentFailed => [
      WorkItemWorkflowState.agentExecuting,
      WorkItemWorkflowState.designInReview,
    ],
    WorkItemState.qaInProgress => [
      WorkItemWorkflowState.qaPassed,
      WorkItemWorkflowState.qaFailed,
    ],
    WorkItemState.qaPassed => [WorkItemWorkflowState.deploying],
    WorkItemState.qaFailed => [
      WorkItemWorkflowState.agentExecuting,
      WorkItemWorkflowState.qaPassed,
      WorkItemWorkflowState.designInReview,
    ],
    WorkItemState.deploying => [
      WorkItemWorkflowState.deployed,
      WorkItemWorkflowState.deploymentFailed,
    ],
    WorkItemState.deployed => [WorkItemWorkflowState.done],
    WorkItemState.deploymentFailed => [WorkItemWorkflowState.deploying],
    WorkItemState.done => [],
  };

  static const draft = WorkItemWorkflowState(WorkItemState.draft);
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
  static const qaInProgress = WorkItemWorkflowState(WorkItemState.qaInProgress);
  static const qaPassed = WorkItemWorkflowState(WorkItemState.qaPassed);
  static const qaFailed = WorkItemWorkflowState(WorkItemState.qaFailed);
  static const deploying = WorkItemWorkflowState(WorkItemState.deploying);
  static const deployed = WorkItemWorkflowState(WorkItemState.deployed);
  static const deploymentFailed = WorkItemWorkflowState(
    WorkItemState.deploymentFailed,
  );
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
