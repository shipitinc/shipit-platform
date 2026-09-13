enum ArtifactType {
  designContract('design_contract'),
  designRevision('design_revision'),
  codeDiff('code_diff'),
  qaContract('qa_contract'),
  qaEvidence('qa_evidence'),
  buildArtifact('build_artifact'),
  deploymentRecord('deployment_record'),
  humanDecision('human_decision'),
  migration('migration'),
  other('other');

  const ArtifactType(this.wire);

  final String wire;

  static ArtifactType fromWire(String value) => values.firstWhere(
    (type) => type.wire == value,
    orElse: () => throw FormatException('Unknown artifact type: $value'),
  );
}
