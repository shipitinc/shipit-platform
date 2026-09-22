enum DefectEventType {
  created('created'),
  triageStarted('triage_started'),
  triageCompleted('triage_completed'),
  clarificationRequested('clarification_requested'),
  clarificationAnswered('clarification_answered'),
  statusChanged('status_changed'),
  evidenceAdded('evidence_added'),
  remediationCreated('remediation_created'),
  remediationStarted('remediation_started'),
  remediationCompleted('remediation_completed'),
  verificationRequested('verification_requested'),
  verificationCompleted('verification_completed'),
  reopened('reopened'),
  closed('closed'),
  duplicateLinked('duplicate_linked'),
  manualAction('manual_action');

  const DefectEventType(this.wire);

  final String wire;

  static DefectEventType fromWire(String value) => values.firstWhere(
    (type) => type.wire == value,
    orElse: () => throw FormatException('Unknown defect event type: $value'),
  );
}