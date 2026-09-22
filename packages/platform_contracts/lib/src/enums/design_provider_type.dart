enum DesignProviderType {
  penpot('penpot');

  const DesignProviderType(this.wire);

  final String wire;

  static DesignProviderType fromWire(String value) => values.firstWhere(
    (provider) => provider.wire == value,
    orElse: () => throw FormatException('Unknown design provider type: $value'),
  );
}