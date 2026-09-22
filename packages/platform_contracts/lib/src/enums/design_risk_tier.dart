enum DesignRiskTier {
  low('low'),
  medium('medium'),
  high('high');

  const DesignRiskTier(this.wire);

  final String wire;

  static DesignRiskTier fromWire(String value) => values.firstWhere(
    (tier) => tier.wire == value,
    orElse: () => throw FormatException('Unknown design risk tier: $value'),
  );
}