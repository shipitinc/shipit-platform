enum ReviewVerdict {
  approved('approved'),
  approvedWithMinorFindings('approved_with_minor_findings'),
  changesRequired('changes_required'),
  rejected('rejected');

  const ReviewVerdict(this.wire);
  final String wire;

  static ReviewVerdict fromWire(String value) => values.firstWhere(
    (v) => v.wire == value,
    orElse: () => throw FormatException('Unknown review verdict: $value'),
  );

  bool get isPassing =>
      this == ReviewVerdict.approved ||
      this == ReviewVerdict.approvedWithMinorFindings;
}
