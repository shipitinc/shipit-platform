enum HumanDecisionType {
  designApproval('design_approval'),
  designRejection('design_rejection'),
  qaWaiver('qa_waiver'),
  qaRework('qa_rework'),
  deploymentApproval('deployment_approval'),
  deploymentRejection('deployment_rejection'),
  rollbackApproval('rollback_approval'),
  escalation('escalation'),
  policyException('policy_exception'),
  productDecision('product_decision'),
  architectureDecision('architecture_decision'),
  engineeringReview('engineering_review'),
  humanQaApproval('human_qa_approval'),
  destructiveMigrationApproval('destructive_migration_approval'),
  securityDecision('security_decision'),
  infrastructureDecision('infrastructure_decision'),
  otherConsequential('other_consequential'),
  defectClarification('defect_clarification'),
  defectFixVerification('defect_fix_verification');

  const HumanDecisionType(this.wire);

  final String wire;

  static HumanDecisionType fromWire(String value) => values.firstWhere(
    (type) => type.wire == value,
    orElse: () => throw FormatException('Unknown human decision type: $value'),
  );
}

enum HumanDecisionChoice {
  approve('approve'),
  reject('reject'),
  waive('waive'),
  rework('rework'),
  cancel('cancel'),
  defer('defer'),
  fixed('fixed'),
  stillBroken('still_broken'),
  partiallyFixed('partially_fixed');

  const HumanDecisionChoice(this.wire);

  final String wire;

  static HumanDecisionChoice fromWire(String value) => values.firstWhere(
    (choice) => choice.wire == value,
    orElse: () =>
        throw FormatException('Unknown human decision choice: $value'),
  );
}

enum HumanDecisionStatus {
  pending('pending'),
  inProgress('in_progress'),
  resolved('resolved'),
  escalated('escalated'),
  deferred('deferred'),
  cancelled('cancelled');

  const HumanDecisionStatus(this.wire);

  final String wire;

  bool get isResolved => this == HumanDecisionStatus.resolved;

  static HumanDecisionStatus fromWire(String value) => values.firstWhere(
    (status) => status.wire == value,
    orElse: () =>
        throw FormatException('Unknown human decision status: $value'),
  );
}