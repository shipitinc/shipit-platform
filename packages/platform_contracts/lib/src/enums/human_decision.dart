enum HumanDecisionType {
  designApproval('design_approval'),
  designRejection('design_rejection'),
  qaWaiver('qa_waiver'),
  qaRework('qa_rework'),
  deploymentApproval('deployment_approval'),
  deploymentRejection('deployment_rejection'),
  rollbackApproval('rollback_approval'),
  escalation('escalation'),
  policyException('policy_exception');

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
  rework('rework');

  const HumanDecisionChoice(this.wire);

  final String wire;

  static HumanDecisionChoice fromWire(String value) => values.firstWhere(
    (choice) => choice.wire == value,
    orElse: () =>
        throw FormatException('Unknown human decision choice: $value'),
  );
}
