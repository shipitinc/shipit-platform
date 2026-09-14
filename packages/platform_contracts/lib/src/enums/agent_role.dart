enum AgentRole {
  implementer('IMPLEMENTER'),
  engineeringReviewer('ENGINEERING_REVIEWER'),
  designAgent('DESIGN_AGENT'),
  designReviewer('DESIGN_REVIEWER'),
  qaArchitect('QA_ARCHITECT'),
  qaExecutor('QA_EXECUTOR'),
  releaseEngineer('RELEASE_ENGINEER'),
  deploymentAuthority('DEPLOYMENT_AUTHORITY'),
  correctionImplementer('CORRECTION_IMPLEMENTER'),
  focusedReviewer('FOCUSED_REVIEWER'),
  integrator('INTEGRATOR');

  const AgentRole(this.wire);

  final String wire;

  static AgentRole fromWire(String value) => values.firstWhere(
    (role) => role.wire == value,
    orElse: () => throw FormatException('Unknown agent role: $value'),
  );
}
