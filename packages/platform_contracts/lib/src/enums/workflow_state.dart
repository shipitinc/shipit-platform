enum WorkItemState {
  draft('draft'),
  planning('planning'),
  planned('planned'),
  designRequired('design_required'),
  designNotRequired('design_not_required'),
  designInReview('design_in_review'),
  designApproved('design_approved'),
  designRejected('design_rejected'),
  agentExecuting('agent_executing'),
  agentCompleted('agent_completed'),
  agentFailed('agent_failed'),
  reviewInProgress('review_in_progress'),
  reviewApproved('review_approved'),
  reviewRejected('review_rejected'),
  qaInProgress('qa_in_progress'),
  qaPassed('qa_passed'),
  qaFailed('qa_failed'),
  waitingForHumanDecision('waiting_for_human_decision'),
  deploying('deploying'),
  deployed('deployed'),
  deploymentFailed('deployment_failed'),
  completed('completed'),
  cancelled('cancelled'),
  terminated('terminated'),
  @Deprecated(
    'Use completed instead. done is parse-only and never a legal '
    'transition target.',
  )
  done('done');

  const WorkItemState(this.wire);

  final String wire;

  bool get isTerminal => switch (this) {
    completed || cancelled || terminated || done => true,
    _ => false,
  };

  bool get isWaitingForHumanDecision =>
      this == WorkItemState.waitingForHumanDecision;

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
