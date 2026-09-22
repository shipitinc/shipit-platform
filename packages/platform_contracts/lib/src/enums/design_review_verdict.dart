enum DesignReviewVerdict {
  approved('approved'),
  approvedWithMinorFindings('approved_with_minor_findings'),
  changesRequired('changes_required'),
  rejected('rejected');

  const DesignReviewVerdict(this.wire);

  final String wire;

  static DesignReviewVerdict fromWire(String value) => values.firstWhere(
    (verdict) => verdict.wire == value,
    orElse: () => throw FormatException('Unknown design review verdict: $value'),
  );

  bool get isPassing => this == DesignReviewVerdict.approved ||
      this == DesignReviewVerdict.approvedWithMinorFindings;
}