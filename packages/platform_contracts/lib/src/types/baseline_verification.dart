import 'package:meta/meta.dart';

/// Evidence that a verifier **independently re-derived** a baseline's content
/// from the same source the producer used, and that the re-derivation
/// reproduces the proposal exactly.
///
/// AGENTS.md §12 makes independence *structural*: a producer may not attest to
/// its own baseline, and "independently verified" is not an identity that was
/// written into a field. It is a comparison. A verifier acquires the source,
/// recomputes the baseline content hash, and the proposal is accepted only when
/// the recomputation agrees. A producer that fabricates is caught by
/// **divergence**, not by policy — there is no policy for it to violate,
/// because the hash it would have to match is computed from the source rather
/// than asserted.
///
/// This type is [sealed]: it cannot be extended or implemented outside this
/// library, and its only public constructor ([fromReDerivation]) *requires* the
/// re-derived hash. There is therefore no permissive default to omit and no
/// wire-shaped field a client can set — a caller that supplies only an identity
/// cannot construct a proof at all, and cannot reach
/// `ProductGuard.baselineVerifiedIndependently`.
///
/// **Stated residual hole — this guarantee is not absolute.** Re-derivation
/// assumes the verifier acquires the source *independently of the producer*. A
/// single compromised process that controls both acquisitions defeats it: it can
/// hand the verifier the source it already shaped, and the re-derivation will
/// agree with a fabricated proposal. This is a known limit, recorded here at
/// the point the proof is constructed rather than left implied, and it is why
/// the human approval gate in §12's own lifecycle remains the final authority
/// and is never automated away.
@immutable
sealed class PlatformReDerivationProof {
  const PlatformReDerivationProof._({
    required this.baselineId,
    required this.baselineRevision,
    required this.reDerivedContentHash,
    required this.reDerivedContentHashVersion,
    required this.producedBy,
    required this.verifiedBy,
    required this.sourceRef,
    required this.reDerivedAt,
  });

  /// Records the result of an independent re-derivation of [baselineId].
  ///
  /// Every field is required and validated here, so a proof cannot exist
  /// without the re-derived hash — the one input that makes the attestation
  /// more than an identity string.
  ///
  /// [sourceRef] names the source both acquisitions read (a repository URL, a
  /// workspace path, an archive digest). It is recorded so a later reader can
  /// see what "the same source" was; it is not independently checked here.
  factory PlatformReDerivationProof.fromReDerivation({
    required String baselineId,
    required int baselineRevision,
    required String reDerivedContentHash,
    required int reDerivedContentHashVersion,
    required String producedBy,
    required String verifiedBy,
    required String sourceRef,
    DateTime? reDerivedAt,
  }) {
    if (baselineId.trim().isEmpty) {
      throw ArgumentError.value(
        baselineId,
        'baselineId',
        'a re-derivation proof must name the baseline it re-derived',
      );
    }
    if (baselineRevision < 1) {
      throw ArgumentError.value(
        baselineRevision,
        'baselineRevision',
        'baseline revisions start at 1',
      );
    }
    if (reDerivedContentHash.trim().isEmpty) {
      throw ArgumentError.value(
        reDerivedContentHash,
        'reDerivedContentHash',
        'a re-derivation proof REQUIRES the recomputed content hash; without '
            'it this is an identity string, not independent evidence',
      );
    }
    if (reDerivedContentHashVersion < 1) {
      throw ArgumentError.value(
        reDerivedContentHashVersion,
        'reDerivedContentHashVersion',
        'content hash versions start at 1',
      );
    }
    if (producedBy.trim().isEmpty) {
      throw ArgumentError.value(
        producedBy,
        'producedBy',
        'independence is a claim about two principals; the producing '
            'identity must be named',
      );
    }
    if (verifiedBy.trim().isEmpty) {
      throw ArgumentError.value(
        verifiedBy,
        'verifiedBy',
        'a re-derivation proof must name the identity that performed it',
      );
    }
    if (sourceRef.trim().isEmpty) {
      throw ArgumentError.value(
        sourceRef,
        'sourceRef',
        'a re-derivation must record the source it recomputed from',
      );
    }
    return _IndependentReDerivation(
      baselineId: baselineId,
      baselineRevision: baselineRevision,
      reDerivedContentHash: reDerivedContentHash,
      reDerivedContentHashVersion: reDerivedContentHashVersion,
      producedBy: producedBy,
      verifiedBy: verifiedBy,
      sourceRef: sourceRef,
      reDerivedAt: reDerivedAt ?? DateTime.now().toUtc(),
    );
  }

  /// The exact baseline revision this proof describes.
  ///
  /// A proof is bound to one artifact. It cannot be replayed against a later
  /// revision of the same baseline, because the hash below would no longer
  /// describe that revision's content.
  final String baselineId;

  /// Revision of [baselineId] that was re-derived.
  final int baselineRevision;

  /// SHA-256 over the canonical payload, recomputed by the verifier from the
  /// source. Compared against the proposal's own hash by [matchesBaseline].
  final String reDerivedContentHash;

  /// Hash contract version used for [reDerivedContentHash]. A hash computed
  /// under one contract cannot be compared against another, so a mismatch here
  /// is divergence just as a hash mismatch is.
  final int reDerivedContentHashVersion;

  /// Identity that produced the baseline.
  ///
  /// Recorded for comparison against [verifiedBy]. It is supplied by the
  /// caller rather than read back from the stored baseline, because a baseline
  /// does not currently persist its producer — see the engine's
  /// `verifyBaseline` for what that leaves unproven, and for the follow-up
  /// that closes it.
  final String producedBy;

  /// Identity that performed the re-derivation.
  final String verifiedBy;

  /// The source the re-derivation recomputed from.
  final String sourceRef;

  /// When the re-derivation happened.
  final DateTime reDerivedAt;

  /// Whether this proof is an attestation by the identity that produced the
  /// baseline.
  ///
  /// AGENTS.md §12: no identity that produced a baseline may verify it.
  bool get isSelfAttested => verifiedBy == producedBy;

  /// Whether the independent re-derivation reproduces exactly the baseline
  /// described by [baselineId], [baselineRevision], [contentHash] and
  /// [contentHashVersion].
  ///
  /// `false` on any disagreement — a different artifact, a different revision,
  /// or a different hash — because each of those means the verifier computed
  /// something other than what is proposed.
  bool matchesBaseline({
    required String baselineId,
    required int baselineRevision,
    required String contentHash,
    required int contentHashVersion,
  }) =>
      this.baselineId == baselineId &&
      this.baselineRevision == baselineRevision &&
      reDerivedContentHash == contentHash &&
      reDerivedContentHashVersion == contentHashVersion;

  @override
  String toString() =>
      'PlatformReDerivationProof($baselineId@r$baselineRevision '
      'v$reDerivedContentHashVersion by $verifiedBy, produced by $producedBy, '
      'source $sourceRef)';
}

/// The one and only implementation of [PlatformReDerivationProof].
///
/// It is private and `final`, so no other library — inside or outside this
/// package — can produce a second implementation or extend this one. The set of
/// values that can exist as a proof is therefore closed at its only source:
/// the validating factory above.
final class _IndependentReDerivation extends PlatformReDerivationProof {
  _IndependentReDerivation({
    required super.baselineId,
    required super.baselineRevision,
    required super.reDerivedContentHash,
    required super.reDerivedContentHashVersion,
    required super.producedBy,
    required super.verifiedBy,
    required super.sourceRef,
    required super.reDerivedAt,
  }) : super._();
}
