/// Lifecycle of a ProductBaseline revision (checkpoint 006 §Baseline
/// Versioning). Accepted revisions are immutable historical authority.
enum ProductBaselineStatus {
  /// Proposed by discovery/review; not yet authoritative.
  proposed('proposed'),

  /// Human accepted this exact revision.
  accepted('accepted'),

  /// A newer revision superseded this one; the historical record is kept.
  superseded('superseded'),

  /// Reviewed and rejected; no longer a candidate.
  rejected('rejected');

  const ProductBaselineStatus(this.wire);

  final String wire;

  static ProductBaselineStatus fromWire(String value) => values.firstWhere(
    (s) => s.wire == value,
    orElse: () =>
        throw FormatException('Unknown product baseline status: $value'),
  );
}
