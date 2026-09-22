enum DefectClassification {
  implementationDefect('implementation_defect'),
  designDefect('design_defect'),
  requirementGap('requirement_gap'),
  environmentDefect('environment_defect');

  const DefectClassification(this.wire);

  final String wire;

  static DefectClassification fromWire(String value) => values.firstWhere(
    (classification) => classification.wire == value,
    orElse: () => throw FormatException('Unknown defect classification: $value'),
  );
}