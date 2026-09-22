enum DefectStatus {
  reported('reported'),
  triaging('triaging'),
  needsClarification('needs_clarification'),
  confirmed('confirmed'),
  notReproducible('not_reproducible'),
  duplicate('duplicate'),
  remediationPlanned('remediation_planned'),
  fixInProgress('fix_in_progress'),
  fixReadyForVerification('fix_ready_for_verification'),
  resolved('resolved'),
  closed('closed');

  const DefectStatus(this.wire);

  final String wire;

  bool get isTerminal => switch (this) {
    closed || duplicate || notReproducible => true,
    _ => false,
  };

  bool get isReopenable => this == notReproducible;

  static DefectStatus fromWire(String value) => values.firstWhere(
    (status) => status.wire == value,
    orElse: () => throw FormatException('Unknown defect status: $value'),
  );
}