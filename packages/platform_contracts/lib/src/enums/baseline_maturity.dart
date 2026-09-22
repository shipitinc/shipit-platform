/// Implementation/governance maturity of a baseline fact.
///
/// Provenance answers "How/from where do we know this?".
/// Maturity answers "What is the implementation/governance status?".
/// These are orthogonal dimensions — do not infer one from the other.
///
/// Examples:
///   OBSERVED + IMPLEMENTED
///   OBSERVED + NOT_IMPLEMENTED
///   HUMAN_PROVIDED + POLICY
///   HUMAN_PROVIDED + PLANNED
///   DERIVED + IMPLEMENTED
///   DERIVED + UNKNOWN
enum BaselineMaturity {
  /// The capability/structure currently exists in the Product implementation.
  implemented('implemented'),

  /// An authoritative governance/architecture rule exists. Does not imply all
  /// supporting mechanisms are implemented.
  policy('policy'),

  /// The capability is explicitly intended/approved for future implementation
  /// and has authoritative planning evidence.
  planned('planned'),

  /// The capability is explicitly postponed or intentionally outside the current
  /// implementation scope.
  deferred('deferred'),

  /// Evidence establishes that the capability does not currently exist.
  /// Does NOT imply that implementation is planned.
  notImplemented('not_implemented'),

  /// Current evidence is insufficient to determine maturity.
  unknown('unknown');

  const BaselineMaturity(this.wire);

  final String wire;

  static BaselineMaturity fromWire(String value) => values.firstWhere(
    (m) => m.wire == value,
    orElse: () => throw FormatException('Unknown baseline maturity: $value'),
  );
}