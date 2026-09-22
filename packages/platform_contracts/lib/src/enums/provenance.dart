/// Provenance of a material baseline assertion (checkpoint 006 §provenance).
///
/// An inferred conclusion must never silently become an observed fact: a
/// `derived`/`assumed` assertion is recorded with the derivation that produced
/// it, and `unknown` is recorded instead of fabricating an answer.
enum Provenance {
  /// Directly observed in the inspected repository/evidence (file read,
  /// config parsed, git object inspected).
  observed('observed'),

  /// Supplied by a human (clarification answer, onboarding input, review).
  humanProvided('human_provided'),

  /// Inferred from observed facts by a deterministic rule (e.g. "single
  /// pubspec.yaml at root ⇒ likely monorepo").
  derived('derived'),

  /// Assumed because evidence was absent; the assumption is recorded and is a
  /// finding/correction candidate.
  assumed('assumed'),

  /// Not known; recorded instead of fabricating an answer.
  unknown('unknown');

  const Provenance(this.wire);

  final String wire;

  static Provenance fromWire(String value) => values.firstWhere(
    (p) => p.wire == value,
    orElse: () => throw FormatException('Unknown provenance: $value'),
  );
}
