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
  defectFixVerification('defect_fix_verification'),
  // The design-review park's own question: "do the design review".
  //
  // APPENDED, not inserted next to `designApproval`, because the value's
  // ordinal position is part of nothing and `values` order is the only thing
  // an append cannot silently change. Named `designReviewRequest` rather than
  // `designReviewRequired` deliberately: the park's STATE is
  // `designReviewRequired`, and two enums carrying one name in one transition
  // table is a class of confusion this file has no reason to add to. This type
  // names the QUESTION asked; the state names the CONDITION.
  //
  // `designApproval` may NOT be re-used for the park: re-pointing that type
  // would silently move the park's other answers (`reject` -> designRejected,
  // `rework` -> designInReview), a state no JobDefinition dispatches.
  designReviewRequest('design_review_request');

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
  partiallyFixed('partially_fixed'),
  // "Send this back to triage", as its own answer.
  //
  // The park already had a way to re-triage — `cancel` and refile — and it
  // threw the item's history and the durable reason it was parked away to do
  // it. This value is the answer that does not. `wire` is `snake_case` because
  // `DurableWorkflowEngine._resolvedOptionId` matches an option's `optionId`
  // against `choice.wire` and falls back to `choice.wire` when none matches;
  // a camelCase option id records a `resolvedOptionId` the operator was never
  // shown, and nothing else in the tree fails.
  reTriage('re_triage');

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

  /// No answer can still arrive: the decision was either answered
  /// ([resolved]) or voided without one ([cancelled]).
  ///
  /// `cancelled` is deliberately NOT folded into [isResolved]: `resolved`
  /// means a decider recorded a choice, and the surfaces that ask "was this
  /// answered" — the 'Already decided' ledger, the engines' idempotent-replay
  /// checks — would mis-report a voided decision as decided. What those
  /// surfaces are usually trying to ask is the terminal property below.
  bool get isTerminal =>
      this == HumanDecisionStatus.resolved ||
      this == HumanDecisionStatus.cancelled;

  /// Still awaiting an answer — the question `!isResolved` was being asked
  /// to mean, which it cannot: `!isResolved` silently includes [cancelled],
  /// and a voided decision is exactly the one that can never be answered.
  /// `pending`, `inProgress`, `escalated` and `deferred` all still stand in
  /// front of someone.
  bool get isOpen => !isTerminal;

  static HumanDecisionStatus fromWire(String value) => values.firstWhere(
    (status) => status.wire == value,
    orElse: () =>
        throw FormatException('Unknown human decision status: $value'),
  );
}
