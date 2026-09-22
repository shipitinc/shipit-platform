enum EvidenceIntakeKind {
  screenshot('screenshot'),
  logExcerpt('log_excerpt'),
  diagnosticBundle('diagnostic_bundle'),
  textDescription('text_description'),
  agentEventReference('agent_event_reference'),
  platformVerificationReference('platform_verification_reference'),
  transitionHistoryReference('transition_history_reference');

  const EvidenceIntakeKind(this.wire);

  final String wire;

  static EvidenceIntakeKind fromWire(String value) => values.firstWhere(
    (kind) => kind.wire == value,
    orElse: () => throw FormatException('Unknown evidence intake kind: $value'),
  );
}