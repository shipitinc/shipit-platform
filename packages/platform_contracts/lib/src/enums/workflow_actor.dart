enum ActorType {
  orchestrator('orchestrator'),
  human('human'),
  implementationAgent('implementation_agent'),
  designAgent('design_agent'),
  designReviewer('design_reviewer'),
  engineeringReviewer('engineering_reviewer'),
  qaArchitect('qa_architect'),
  qaExecutor('qa_executor'),
  releaseEngineer('release_engineer'),
  deploymentAuthority('deployment_authority'),
  triageAgent('triage_agent'),
  system('system');

  const ActorType(this.wire);

  final String wire;

  static ActorType fromWire(String value) => values.firstWhere(
    (type) => type.wire == value,
    orElse: () => throw FormatException('Unknown actor type: $value'),
  );
}