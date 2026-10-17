/// Wire → presentation mapping for human decision choices.
///
/// The authoritative wire/domain values are the lowercase
/// `HumanDecisionChoice` enum values (`approve`, `reject`, `waive`, `rework`,
/// `cancel`, `defer`, `re_triage`, ...) — parsed server-side by
/// `HumanDecisionChoice.fromWire`. That list is spelled here for readability
/// only; it is not the set of choices, and [knownDecisionChoices] below is
/// also not the set of choices. A choice is offered wherever a decision's own
/// option list names it, so membership here is about LABELLED COPY, not about
/// what any operator can be shown.
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
  're_triage',
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

  if (decisionType == 'design_review_request') {
    // The park's four answers, in the words the park uses for them. Same
    // shape as the escalation arm above and for the same reason: the gate
    // decides what "approve" MEANS. On an escalation it resumes work that was
    // paused; on the design-review park it is the review itself, which is the
    // only one of these four answers that moves the item toward the thing it
    // is parked waiting for.
    final designReview = switch (wireValue) {
      'approve' => 'Do the design review',
      'rework' => 'Put it back in the lane',
      're_triage' => 'Re-triage',
      'cancel' => 'Stop',
      _ => null,
    };
    if (designReview != null) return designReview;
  }

  return switch (wireValue) {
    'approve' => 'Approve',
    'reject' => 'Reject',
    'defer' => 'Defer',
    'waive' => 'Skip the check',
    'rework' => 'Request changes',
    'cancel' => 'Stop this work',
    // Present in the generic arm as well as in the per-type arm above. A
    // [decisionType] that this function does not know — or none at all — must
    // still render mapped copy, because the fallback shows the raw wire and
    // `re_triage` is a wire no human should have to read.
    're_triage' => 'Re-triage',
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
