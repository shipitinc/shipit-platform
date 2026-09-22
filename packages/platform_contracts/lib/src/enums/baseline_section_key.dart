/// Structured ProductBaseline sections (checkpoint 006 §ProductBaseline).
///
/// Facts are grouped into these typed sections; control flow may branch on the
/// section key, so the vocabulary is fixed, not free-form.
enum BaselineSectionKey {
  repository('repository'),
  techStack('tech_stack'),
  architecture('architecture'),
  design('design'),
  qa('qa'),
  ciCd('ci_cd'),
  environments('environments'),
  data('data'),
  deployment('deployment'),
  governance('governance'),
  knownGaps('known_gaps');

  const BaselineSectionKey(this.wire);

  final String wire;

  static BaselineSectionKey fromWire(String value) => values.firstWhere(
    (s) => s.wire == value,
    orElse: () => throw FormatException('Unknown baseline section: $value'),
  );
}
