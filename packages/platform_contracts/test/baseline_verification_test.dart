import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

/// AGENTS.md §12: independence is structural. `PlatformReDerivationProof` is
/// the structure that carries it, and the property that matters most is that it
/// CANNOT BE CONSTRUCTED WITHOUT THE RE-DERIVED HASH — there is no default to
/// omit, and therefore nothing for a caller to leave out.
void main() {
  const _baselineId = 'bl-p1-1';

  /// A second 64-hex-char digest, to stand in for content the verifier would
  /// compute if the producer had fabricated its baseline.
  const _otherHash =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  /// A 64-hex-char digest, written out because a default parameter value must be
  /// a compile-time constant and `'a' * 64` is not one.
  const _hash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  PlatformReDerivationProof build({
    String baselineId = _baselineId,
    int revision = 1,
    String reDerivedContentHash = _hash,
    int reDerivedContentHashVersion = 3,
    String producedBy = 'producer',
    String verifiedBy = 'verifier',
    String sourceRef = 'git@example.invalid:acme/p1.git',
  }) => PlatformReDerivationProof.fromReDerivation(
    baselineId: baselineId,
    baselineRevision: revision,
    reDerivedContentHash: reDerivedContentHash,
    reDerivedContentHashVersion: reDerivedContentHashVersion,
    producedBy: producedBy,
    verifiedBy: verifiedBy,
    sourceRef: sourceRef,
  );

  group('construction requires the re-derived hash', () {
    test('a proof cannot be built without naming the re-derived hash', () {
      // This is the whole point: the permissive value is not merely discouraged,
      // it is unrepresentable. `reDerivedContentHash` is a required parameter —
      // omitting it is a compile error, and a blank one is a refusal.
      expect(() => build(reDerivedContentHash: ''), throwsArgumentError);
      expect(() => build(reDerivedContentHash: '   '), throwsArgumentError);
    });

    test('every other identity input is required too', () {
      expect(() => build(baselineId: ''), throwsArgumentError);
      expect(() => build(producedBy: ''), throwsArgumentError);
      expect(() => build(verifiedBy: ''), throwsArgumentError);
      expect(() => build(sourceRef: ''), throwsArgumentError);
      expect(() => build(revision: 0), throwsArgumentError);
      expect(() => build(reDerivedContentHashVersion: 0), throwsArgumentError);
    });

    test('a proof records what it re-derived and from where', () {
      final proof = build();
      expect(proof.baselineId, _baselineId);
      expect(proof.baselineRevision, 1);
      expect(proof.reDerivedContentHash, _hash);
      expect(proof.reDerivedContentHashVersion, 3);
      expect(proof.producedBy, 'producer');
      expect(proof.verifiedBy, 'verifier');
      expect(proof.sourceRef, 'git@example.invalid:acme/p1.git');
      expect(proof.reDerivedAt, isNotNull);
    });
  });

  group('agreement is a comparison, not an assertion', () {
    test('matches only the exact artifact it re-derived', () {
      final proof = build();
      expect(
        proof.matchesBaseline(
          baselineId: _baselineId,
          baselineRevision: 1,
          contentHash: _hash,
          contentHashVersion: 3,
        ),
        isTrue,
      );
    });

    test('a different digest is divergence', () {
      final proof = build();
      expect(
        proof.matchesBaseline(
          baselineId: _baselineId,
          baselineRevision: 1,
          contentHash: _otherHash,
          contentHashVersion: 3,
        ),
        isFalse,
      );
    });

    test('a different hash contract is divergence', () {
      final proof = build();
      expect(
        proof.matchesBaseline(
          baselineId: _baselineId,
          baselineRevision: 1,
          contentHash: _hash,
          contentHashVersion: 2,
        ),
        isFalse,
      );
    });

    test('a different artifact is divergence', () {
      final proof = build();
      expect(
        proof.matchesBaseline(
          baselineId: 'bl-other-9',
          baselineRevision: 1,
          contentHash: _hash,
          contentHashVersion: 3,
        ),
        isFalse,
      );
      expect(
        proof.matchesBaseline(
          baselineId: _baselineId,
          baselineRevision: 2,
          contentHash: _hash,
          contentHashVersion: 3,
        ),
        isFalse,
      );
    });
  });

  group('self-attestation is identifiable from the proof alone', () {
    test('a proof by the producing identity is self-attested', () {
      expect(build(verifiedBy: 'producer').isSelfAttested, isTrue);
    });

    test('a proof by a different identity is not self-attested', () {
      expect(build(verifiedBy: 'someone-else').isSelfAttested, isFalse);
    });
  });

  group('both principals are legible to an auditor', () {
    test('a rendered proof names the producer AND the verifier', () {
      // A self-attested proof is detectable by reading it, not only by
      // evaluating a boolean on it — so the limitation is visible wherever the
      // proof is logged.
      final rendered = build().toString();
      expect(rendered, contains('produced by producer'));
      expect(rendered, contains('by verifier'));
      expect(
        build(verifiedBy: 'producer').toString(),
        contains('produced by producer'),
      );
    });
  });
}
