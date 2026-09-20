/// Wire → presentation mapping for human decision choices.
///
/// The authoritative wire/domain values are the lowercase
/// `HumanDecisionChoice` enum values (`approve`, `reject`, `waive`, `rework`,
/// `cancel`, `defer`) — parsed server-side by `HumanDecisionChoice.fromWire`.
/// `HumanDecisionOption.label` is free-form caller text and MUST NOT be
/// submitted as the choice. This is the single boundary where a wire value
/// becomes human-facing copy, so presentation never leaks into the wire and
/// wire values never leak into the UI unaudited.
library;

const Set<String> knownDecisionChoices = {
  'approve',
  'reject',
  'waive',
  'rework',
  'cancel',
  'defer',
};

bool isKnownDecisionChoice(String value) =>
    knownDecisionChoices.contains(value);

/// Human-facing label for a wire choice value. Unknown values fall back to
/// `fallback` (the caller-provided option label) when supplied, otherwise the
/// exact durable value is shown verbatim — never fabricated.
///
/// [decisionType] selects the phrasing the design uses for that gate: the
/// board labels the same `approve` choice "Approve" on a design gate and
/// "Resume" on an escalation, and `cancel` becomes "Stop this work". The wire
/// value submitted is unaffected — only the words change.
String decisionChoiceLabel(
  String wireValue, {
  String? fallback,
  String? decisionType,
}) {
  if (decisionType == 'escalation') {
    final escalation = switch (wireValue) {
      'approve' => 'Resume',
      'cancel' => 'Stop this work',
      'rework' => 'Send it back',
      'defer' => 'Decide later',
      _ => null,
    };
    if (escalation != null) return escalation;
  }

  return switch (wireValue) {
    'approve' => 'Approve',
    'reject' => 'Reject',
    'defer' => 'Defer',
    'waive' => 'Skip the check',
    'rework' => 'Request changes',
    'cancel' => 'Stop this work',
    _ => fallback ?? wireValue,
  };
}

/// A renderable choice: `value` is what is submitted to the wire/domain,
/// `label` is what is shown to the human.
class DecisionChoiceOption {
  const DecisionChoiceOption({
    required this.value,
    required this.label,
    this.description,
    this.recommended = false,
  });

  final String value;
  final String label;
  final String? description;
  final bool recommended;
}
