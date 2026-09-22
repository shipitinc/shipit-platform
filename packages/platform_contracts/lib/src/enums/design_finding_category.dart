enum DesignFindingCategory {
  requirementCoverage('requirement_coverage'),
  designSystemCompliance('design_system_compliance'),
  interactionCompleteness('interaction_completeness'),
  responsiveCoverage('responsive_coverage'),
  accessibility('accessibility'),
  feasibility('feasibility'),
  assetIntegrity('asset_integrity'),
  designSystemChangeImpact('design_system_change_impact');

  const DesignFindingCategory(this.wire);

  final String wire;

  static DesignFindingCategory fromWire(String value) => values.firstWhere(
    (category) => category.wire == value,
    orElse: () => throw FormatException('Unknown design finding category: $value'),
  );
}