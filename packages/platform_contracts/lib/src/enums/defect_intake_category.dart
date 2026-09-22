enum DefectIntakeCategory {
  visualBug('visual_bug'),
  incorrectBehavior('incorrect_behavior'),
  usabilityIssue('usability_issue'),
  browserSpecific('browser_specific'),
  intermittentFailure('intermittent_failure'),
  unexpectedState('unexpected_state'),
  other('other');

  const DefectIntakeCategory(this.wire);

  final String wire;

  static DefectIntakeCategory fromWire(String value) => values.firstWhere(
    (category) => category.wire == value,
    orElse: () => throw FormatException('Unknown defect intake category: $value'),
  );
}