enum AuditEntityType {
  product('product'),
  repositoryReference('repository_reference'),
  productBaseline('product_baseline'),
  baselineFact('baseline_fact'),
  clarificationRequest('clarification_request'),
  onboardingRecord('onboarding_record'),
  productCredential('product_credential'),
  standingPolicy('standing_policy');

  const AuditEntityType(this.wire);

  final String wire;

  static AuditEntityType fromWire(String value) {
    return values.firstWhere(
      (e) => e.wire == value,
      orElse: () => throw ArgumentError('Unknown AuditEntityType wire: $value'),
    );
  }
}