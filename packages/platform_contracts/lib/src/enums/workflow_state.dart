enum ProductState { draft, active, archived, deprecated }

enum WorkItemState {
  draft('draft'),
  designInReview('design_in_review'),
  designApproved('design_approved'),
  designRejected('design_rejected'),
  agentExecuting('agent_executing'),
  agentCompleted('agent_completed'),
  agentFailed('agent_failed'),
  qaInProgress('qa_in_progress'),
  qaPassed('qa_passed'),
  qaFailed('qa_failed'),
  deploying('deploying'),
  deployed('deployed'),
  deploymentFailed('deployment_failed'),
  done('done');

  const WorkItemState(this.wire);

  final String wire;

  static WorkItemState fromWire(String value) => values.firstWhere(
    (state) => state.wire == value,
    orElse: () => throw FormatException('Unknown work item state: $value'),
  );
}

enum DesignContractStatus { draft, underReview, approved, rejected, expired }

enum QAStatus { pending, inProgress, passed, failed, waived }

enum DeploymentPhase {
  building,
  promoting,
  deploying,
  validating,
  completed,
  failed,
  rolledBack,
}
