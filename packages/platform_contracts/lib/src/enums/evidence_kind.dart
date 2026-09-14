enum EvidenceKind {
  agentClaimedEvidence('agent_claimed_evidence'),
  platformVerifiedEvidence('platform_verified_evidence');

  const EvidenceKind(this.wire);

  final String wire;

  static EvidenceKind fromWire(String value) => values.firstWhere(
    (kind) => kind.wire == value,
    orElse: () => throw FormatException('Unknown evidence kind: $value'),
  );
}

enum AgentClaimStatus {
  passed('passed'),
  failed('failed');

  const AgentClaimStatus(this.wire);

  final String wire;

  static AgentClaimStatus fromWire(String value) => values.firstWhere(
    (status) => status.wire == value,
    orElse: () => throw FormatException('Unknown claim status: $value'),
  );
}
