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

  group('identity comparison is normalization-insensitive', () {
    // The defect this covers: `isSelfAttested` compared the RAW, caller-supplied
    // strings, so `'agent-x'` and `'agent-x '` were two principals. The
    // producer re-derived its own work, agreement was trivially satisfied, and
    // the separation of principals that AGENTS.md §12 mandates was defeated by
    // one trailing space. The same held for leading whitespace, casing, and
    // zero-width characters. Normalization happens ONCE, at construction, and
    // the SAME function is applied to both sides — an asymmetric comparison
    // would be the bypass rather than the fix.

    test(
      'the same principal is still self-attested with trailing whitespace',
      () {
        expect(build(verifiedBy: 'producer\u00A0').isSelfAttested, isTrue);
        expect(build(verifiedBy: 'producer\t').isSelfAttested, isTrue);
        expect(build(verifiedBy: 'producer\n').isSelfAttested, isTrue);
      },
    );

    test(
      'the same principal is still self-attested with leading whitespace',
      () {
        expect(build(verifiedBy: ' producer').isSelfAttested, isTrue);
        expect(build(verifiedBy: '\tproducer').isSelfAttested, isTrue);
      },
    );

    test('the same principal is still self-attested with different casing', () {
      expect(build(verifiedBy: 'PRODUCER').isSelfAttested, isTrue);
      expect(build(verifiedBy: 'Producer').isSelfAttested, isTrue);
      // Case folding is Unicode-aware, not ASCII-only: the KELVIN SIGN (U+212A)
      // lowercases to ASCII 'k', so even a cross-script spelling of one letter
      // cannot stand in for a second principal.
      expect(
        build(
          producedBy: 'producer-k',
          verifiedBy: 'producer-\u212A',
        ).isSelfAttested,
        isTrue,
      );
    });

    test('interior whitespace repetition is one principal, and an inserted '
        'space is a different one', () {
      // Collapsing a RUN to a single space is normalization; turning no space
      // into one would be conflating two identities, which is the over-block
      // this fix must not introduce. The boundary is drawn here, on purpose.
      expect(
        build(producedBy: 'worker a', verifiedBy: 'worker   a').isSelfAttested,
        isTrue,
      );
      expect(
        build(producedBy: 'worker a', verifiedBy: 'workera').isSelfAttested,
        isFalse,
      );
      expect(
        build(producedBy: 'worker a', verifiedBy: 'worker  a').isSelfAttested,
        isTrue,
      );
    });

    test(
      'the same principal is self-attested behind every cosmetic disguise',
      () {
        // One test for the whole class: normalization is applied to both sides,
        // so no cosmetic spelling of one principal can pass as two. Every entry
        // here differs from `'producer'` ONLY in characters this normalization
        // folds away — surrounding whitespace, casing, or invisible
        // zero-width/format characters. Interior whitespace is covered by its own
        // test above, which draws the boundary explicitly.
        for (final disguise in [
          '  producer  ',
          'Producer',
          '\tPRODUCER\n',
          '\u200Bproducer',
          'producer\u200B',
          'pro\u200Cducer',
          'pr\uFEFFoducer', // BOM mid-string
          'pr\u00ADoducer', // soft hyphen
          'producer\u00A0', // non-breaking space at the end
        ]) {
          expect(
            build(verifiedBy: disguise).isSelfAttested,
            isTrue,
            reason: '"$disguise" must not read as a second principal',
          );
        }
      },
    );

    test('a genuinely distinct verifier is NOT self-attested', () {
      // The control. Normalization must not become a denial of service: a real
      // second principal is still accepted, however it is spelled, as long as
      // the underlying identity differs.
      expect(build(verifiedBy: 'verifier').isSelfAttested, isFalse);
      expect(build(verifiedBy: 'VERIFIER').isSelfAttested, isFalse);
      expect(build(verifiedBy: '  verifier  ').isSelfAttested, isFalse);
      expect(build(verifiedBy: 'producer-2').isSelfAttested, isFalse);
    });

    test('both sides are normalized, symmetrically', () {
      // The comparison is symmetric, so disguising the PRODUCER is caught just
      // as disguising the verifier is. Normalizing only one side would make the
      // check trivially bypassable in the direction left un-normalized.
      expect(
        build(producedBy: ' producer ', verifiedBy: 'producer').isSelfAttested,
        isTrue,
      );
      expect(
        build(producedBy: '  PRODUCER', verifiedBy: 'producer').isSelfAttested,
        isTrue,
      );
    });

    test('the recorded identity is the normalized one, and the raw input is '
        'kept for audit', () {
      final proof = build(producedBy: '  Producer ', verifiedBy: 'Verifier\t');
      // Attribution and the comparison read the SAME value, so what is recorded
      // is exactly what the independence check compared.
      expect(proof.producedBy, 'producer');
      expect(proof.verifiedBy, 'verifier');
      // The raw caller input survives for an auditor who needs to see how the
      // identity was actually spelled on the wire.
      expect(proof.producedByRaw, '  Producer ');
      expect(proof.verifiedByRaw, 'Verifier\t');
    });

    test(
      'an identity that normalizes to nothing is refused at construction',
      () {
        // `'   '` was already refused; a string made only of zero-width
        // characters normalizes to nothing and must be refused too, or it would
        // be recorded as a principal named by no one.
        expect(() => build(producedBy: '\u200B'), throwsArgumentError);
        expect(() => build(verifiedBy: '\u200B\u200B'), throwsArgumentError);
        // A word joiner, a non-breaking space and a zero-width space together:
        // three characters that each look like nothing at all.
        expect(
          () => build(verifiedBy: '\u2060\u00A0\u200B'),
          throwsArgumentError,
        );
      },
    );
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
