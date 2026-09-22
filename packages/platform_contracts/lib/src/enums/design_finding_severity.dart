enum DesignFindingSeverity {
  blocker('blocker'),
  major('major'),
  minor('minor'),
  advisory('advisory');

  const DesignFindingSeverity(this.wire);

  final String wire;

  static DesignFindingSeverity fromWire(String value) => values.firstWhere(
    (severity) => severity.wire == value,
    orElse: () => throw FormatException('Unknown design finding severity: $value'),
  );

  bool get blocksApproval => this == DesignFindingSeverity.blocker ||
      this == DesignFindingSeverity.major;
}