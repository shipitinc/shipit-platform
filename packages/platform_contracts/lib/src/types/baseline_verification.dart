import 'package:meta/meta.dart';

/// Characters that carry no identity information but are invisible in a log, a
/// terminal, or a diff — so `'agent-x'` and `'agent-x\u200B'` render the same
/// and are, for every purpose this guard exists to enforce, the same principal.
///
/// Deliberately a fixed list rather than a Unicode property table: it is the
/// zero-width and format characters that survive a visual review, which is
/// exactly the attack. It is a *defence in depth* step, not the guarantee — see
/// [normalizeBaselineIdentity] for what is and is not normalized.
const _invisibleIdentityCharacters = <String>{
  '\u00AD', // SOFT HYPHEN
  '\u180E', // MONGOLIAN VOWEL SEPARATOR
  '\u200B', // ZERO WIDTH SPACE
  '\u200C', // ZERO WIDTH NON-JOINER
  '\u200D', // ZERO WIDTH JOINER
  '\u200E', // LEFT-TO-RIGHT MARK
  '\u200F', // RIGHT-TO-LEFT MARK
  '\u2060', // WORD JOINER
  '\u2061', // FUNCTION APPLICATION
  '\u2062', // INVISIBLE TIMES
  '\u2063', // INVISIBLE SEPARATOR
  '\u2064', // INVISIBLE PLUS
  '\uFEFF', // ZERO WIDTH NO-BREAK SPACE
};

/// A run of whitespace, including the whitespace characters Dart's `\s` does
/// not cover but `String.trim` does treat as whitespace (NEXT LINE and
/// MONGOLIAN VOWEL SEPARATOR). Without them the inner collapse and the outer
/// trim would disagree about what "the same identity" means — the outer would
/// strip a leading NEXT LINE and the inner would leave an interior one, which is
/// the asymmetry this whole function exists to remove.
final _whitespaceRun = RegExp('[\\u0085\\u180e\\s]+');

/// The canonical form of a principal identity, used for **every** comparison of
/// one identity against another.
///
/// Two identities are the same principal when their canonical forms are equal,
/// and the canonical form is computed here — once, at construction — rather than
/// at each comparison site. That placement is the point. The previous code
/// validated that an identity was non-blank *after* trimming but stored the raw
/// caller string and compared it directly, so `producedBy: 'agent-x'` and
/// `verifiedBy: 'agent-x '` were two principals: the same agent re-derived its
/// own work, `matchesBaseline` passed trivially because the producer already
/// held the hash, and `ProductGuard.baselineVerifiedIndependently` was
/// satisfied by the one principal §12 forbids. Casing, leading whitespace,
/// zero-width characters and non-breaking spaces all defeated it identically.
///
/// The normalization is, in order:
///
/// 1. **remove** invisible zero-width and format characters
///    ([_invisibleIdentityCharacters]),
/// 2. **collapse** every whitespace run to a single space and trim the ends, so
///    `'worker:baseline producer'` and `'worker:  baseline   producer '` are
///    one principal,
/// 3. **lowercase**, so casing cannot stand in for a distinct identity.
///
/// Steps 1-2 make cosmetic spellings of one principal compare equal; step 3
/// makes casing cosmetic too. Nothing here can make two *genuinely different*
/// principals compare equal, which is what keeps this from becoming a denial of
/// service on honest verification.
///
/// **Stated limit — this is not Unicode canonical equivalence.** Full case
/// folding (so `'ς'` and `'σ'`, or `'ß'` and `'SS'`, are one identity) and
/// NFC/NFKC normalization (so precomposed and decomposed spellings of an
/// accented character are one identity) are NOT applied: `dart:core` has no
/// Unicode normalizer, and taking on a dependency to add one is a decision
/// beyond this type. An identity pair differing only by those remains
/// distinguishable here. That residual is recorded at the function that has the
/// limitation rather than left implied, and it sits *inside* §12's stated
/// residual hole: this comparison assumes the two identities are strings over a
/// controlled alphabet, and re-derivation assumes the verifier acquired the
/// source independently of the producer. One compromised process controlling
/// both acquisitions still defeats §12 — normalization does not close that, and
/// the human approval gate remains the final authority.
String normalizeBaselineIdentity(String identity) => identity
    .split('')
    .where((c) => !_invisibleIdentityCharacters.contains(c))
    .join()
    .replaceAll(_whitespaceRun, ' ')
    .trim()
    .toLowerCase();

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
    required this.producedByRaw,
    required this.verifiedBy,
    required this.verifiedByRaw,
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
    // Blankness is judged on the CANONICAL form, not the raw input: an identity
    // that is only zero-width characters is blank once those are removed, and
    // admitting it would record an attestation attributed to nobody.
    final canonicalProducer = normalizeBaselineIdentity(producedBy);
    if (canonicalProducer.isEmpty) {
      throw ArgumentError.value(
        producedBy,
        'producedBy',
        'independence is a claim about two principals; the producing '
            'identity must be named',
      );
    }
    final canonicalVerifier = normalizeBaselineIdentity(verifiedBy);
    if (canonicalVerifier.isEmpty) {
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
      // Both identities are canonicalized HERE, once, by the same function.
      // Every comparison this type makes — and every value it hands to the
      // engine for attribution — therefore reads the canonical form, and no
      // call site can compare raw caller input by accident.
      producedBy: canonicalProducer,
      producedByRaw: producedBy,
      verifiedBy: canonicalVerifier,
      verifiedByRaw: verifiedBy,
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

  /// Identity that produced the baseline, in canonical form
  /// (see [normalizeBaselineIdentity]).
  ///
  /// Recorded for comparison against [verifiedBy]. It is supplied by the
  /// caller rather than read back from the stored baseline, because a baseline
  /// does not currently persist its producer — see the engine's
  /// `verifyBaseline` for what that leaves unproven, and for the follow-up
  /// that closes it.
  ///
  /// This is the value compared by [isSelfAttested] and the value the engine
  /// attributes the verification to, so attribution and the independence check
  /// can never disagree about who the principal was. The caller's untransformed
  /// input is preserved in [producedByRaw] for audit and is never compared.
  final String producedBy;

  /// [producedBy] exactly as the caller supplied it, before normalization.
  ///
  /// Preserved so an auditor can see how the identity was actually spelled on
  /// the wire — a discrepancy here is itself evidence. Never used in a
  /// comparison: comparing raw caller input is the defect this type's
  /// canonicalization exists to remove.
  final String producedByRaw;

  /// Identity that performed the re-derivation, in canonical form (see
  /// [normalizeBaselineIdentity]).
  final String verifiedBy;

  /// [verifiedBy] exactly as the caller supplied it, before normalization.
  ///
  /// Audit only; see [producedByRaw].
  final String verifiedByRaw;

  /// The source the re-derivation recomputed from.
  final String sourceRef;

  /// When the re-derivation happened.
  final DateTime reDerivedAt;

  /// Whether this proof is an attestation by the identity that produced the
  /// baseline.
  ///
  /// AGENTS.md §12: no identity that produced a baseline may verify it.
  ///
  /// Both operands are canonical (normalized once at construction by
  /// [normalizeBaselineIdentity]), so this is a comparison of like with like.
  /// It was previously a comparison of raw caller strings, which made a single
  /// trailing space, a capital letter, or an invisible zero-width character
  /// enough to read one principal as two — the same agent re-verifying its own
  /// baseline and satisfying the human approval gate on its own re-derivation.
  bool get isSelfAttested =>
      normalizeBaselineIdentity(verifiedBy) ==
      normalizeBaselineIdentity(producedBy);

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
    required super.producedByRaw,
    required super.verifiedBy,
    required super.verifiedByRaw,
    required super.sourceRef,
    required super.reDerivedAt,
  }) : super._();
}
