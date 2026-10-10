import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:test/test.dart';

import 'support/baseline_approval.dart';

BaselineFact _fact(String claim) => BaselineFact(
  factId: 'f-1',
  section: BaselineSectionKey.repository,
  claim: claim,
  provenance: Provenance.observed,
  maturity: BaselineMaturity.implemented,
);

/// AGENTS.md §12 made independence structural rather than conventional: the
/// guard is satisfied by a comparison the verifier performed, not by an identity
/// someone wrote into a field. These are the three ways the old convention-only
/// guard could be walked past, and each is now refused mechanically.
///
/// The defect these cover: `verifyBaseline` took
/// `EvidenceKind kind = EvidenceKind.platformVerifiedEvidence` — the PERMISSIVE
/// value as the DEFAULT — and `isIndependentlyVerified` tested only that kind
/// plus a non-empty `verifiedBy`. Any caller omitting `kind` self-certified, and
/// the same default was hardcoded on the wire, so an API client could forge
/// `verifiedBy` and unlock `ProductGuard.baselineVerifiedIndependently`.
void main() {
  late ProductRegistryEngine engine;

  setUp(() {
    engine = ProductRegistryEngine(
      store: InMemoryProductRegistryStore(),
      humanDecisionStore: InMemoryHumanDecisionStore(),
    );
  });

  Future<ProductBaseline> proposeFor(String id) async {
    await engine.createProduct(productId: id, name: id);
    return engine.proposeBaseline(productId: id, facts: [_fact('single repo')]);
  }

  group('negative case 1 — a fabricating producer is caught by divergence', () {
    test(
      'a re-derivation that does not reproduce the proposal is refused',
      () async {
        final b = await proposeFor('p1');

        // The honest verifier recomputes the hash from the source and gets
        // something the producer never claimed.
        final divergent = PlatformReDerivationProof.fromReDerivation(
          baselineId: b.baselineId,
          baselineRevision: b.revision,
          reDerivedContentHash:
              '00000000000000000000000000000000000000000000000000000000deadbeef',
          reDerivedContentHashVersion: b.contentHashVersion,
          producedBy: 'agent-that-produced-it',
          verifiedBy: 'independent-worker-7',
          sourceRef: 'git@example.invalid:acme/p1.git@refs/heads/main',
        );

        await expectLater(
          engine.verifyBaseline(
            productId: 'p1',
            baselineId: b.baselineId,
            reDerivation: divergent,
          ),
          throwsA(isA<BaselineReDerivationDivergenceException>()),
        );

        // Refused means refused: no attestation is left behind that a later
        // store read could mistake for a pass.
        final after = await engine.readBaselineRevision('p1', b.revision);
        expect(after.isIndependentlyVerified, isFalse);
        expect(after.verificationKind, isNull);
      },
    );

    test(
      'a hash computed under a different contract is also divergence',
      () async {
        final b = await proposeFor('p1');
        // Right digest, wrong contract: two hashes are only comparable when the
        // contract that produced them is the same.
        final mismatchedVersion = PlatformReDerivationProof.fromReDerivation(
          baselineId: b.baselineId,
          baselineRevision: b.revision,
          reDerivedContentHash: b.contentHash,
          reDerivedContentHashVersion: 2,
          producedBy: 'agent-that-produced-it',
          verifiedBy: 'independent-worker-7',
          sourceRef: 'git@example.invalid:acme/p1.git@refs/heads/main',
        );

        await expectLater(
          engine.verifyBaseline(
            productId: 'p1',
            baselineId: b.baselineId,
            reDerivation: mismatchedVersion,
          ),
          throwsA(isA<BaselineReDerivationDivergenceException>()),
        );
      },
    );

    test("a proof for another baseline cannot be replayed", () async {
      final b = await proposeFor('p1');
      final elsewhere = PlatformReDerivationProof.fromReDerivation(
        baselineId: 'bl-other-product-1',
        baselineRevision: b.revision,
        reDerivedContentHash: b.contentHash,
        reDerivedContentHashVersion: b.contentHashVersion,
        producedBy: 'someone-else',
        verifiedBy: 'independent-worker-7',
        sourceRef: 'git@example.invalid:acme/other.git@refs/heads/main',
      );

      await expectLater(
        engine.verifyBaseline(
          productId: 'p1',
          baselineId: b.baselineId,
          reDerivation: elsewhere,
        ),
        throwsA(isA<BaselineReDerivationDivergenceException>()),
      );
    });

    test(
      'the proposal hash is genuinely the derived content, not a constant',
      () async {
        // Guards the fixture above: if two different baselines shared a content
        // hash, "divergence" would be unfalsifiable.
        final a = await proposeFor('p1');
        await engine.proposeBaseline(
          productId: 'p1',
          facts: [_fact('a different repository layout')],
        );
        final b = await engine.readBaselineRevision('p1', 2);
        expect(a.contentHash, isNot(b.contentHash));
      },
    );
  });

  group('negative case 2 — the producing identity may not verify', () {
    test(
      'a self-re-derivation is refused even though the hash agrees',
      () async {
        final b = await proposeFor('p1');

        // The hash matches perfectly — that is the point. Re-deriving your own
        // work reproduces your own work, so agreement here proves consistency,
        // not independence.
        final selfAttested = PlatformReDerivationProof.fromReDerivation(
          baselineId: b.baselineId,
          baselineRevision: b.revision,
          reDerivedContentHash: b.contentHash,
          reDerivedContentHashVersion: b.contentHashVersion,
          producedBy: 'worker:baseline-producer/onboard_shipit_dev',
          verifiedBy: 'worker:baseline-producer/onboard_shipit_dev',
          sourceRef: 'local-directory/onboard_shipit_dev',
        );

        await expectLater(
          engine.verifyBaseline(
            productId: 'p1',
            baselineId: b.baselineId,
            reDerivation: selfAttested,
          ),
          throwsA(isA<BaselineSelfVerificationException>()),
        );

        final after = await engine.readBaselineRevision('p1', b.revision);
        expect(after.isIndependentlyVerified, isFalse);
        expect(
          () => engine.requestBaselineApproval(
            productId: 'p1',
            baselineId: b.baselineId,
          ),
          throwsA(isA<BaselineNotVerifiedException>()),
        );
      },
    );

    test(
      'a genuinely separate verifier on the same content is accepted',
      () async {
        // The control for the case above: the ONLY difference is the identity, so
        // the refusal above is attributable to self-attestation and not to some
        // incidental property of the proof.
        final b = await proposeFor('p1');
        final v = await engine.verifyBaseline(
          productId: 'p1',
          baselineId: b.baselineId,
          reDerivation: agreeingProof(
            b,
            producedBy: 'worker:baseline-producer/onboard_shipit_dev',
            verifiedBy: 'worker:baseline-verifier/independent',
          ),
        );
        expect(v.isIndependentlyVerified, isTrue);
      },
    );

    test('divergence outranks self-attestation', () async {
      // A fabricator who also signs its own work has produced the most
      // indefensible claim there is. It is refused as divergence, because the
      // content is untrustworthy regardless of who signed it.
      final b = await proposeFor('p1');
      final bad = PlatformReDerivationProof.fromReDerivation(
        baselineId: b.baselineId,
        baselineRevision: b.revision,
        reDerivedContentHash:
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        reDerivedContentHashVersion: b.contentHashVersion,
        producedBy: 'the-producer',
        verifiedBy: 'the-producer',
        sourceRef: 'local-directory/fabricated',
      );
      await expectLater(
        engine.verifyBaseline(
          productId: 'p1',
          baselineId: b.baselineId,
          reDerivation: bad,
        ),
        throwsA(isA<BaselineReDerivationDivergenceException>()),
      );
    });
  });

  group('negative case 3 — an identity-only call cannot unlock the gate', () {
    test('a bare identity records a claim and nothing else', () async {
      final b = await proposeFor('p1');
      final claimed = await engine.verifyBaseline(
        productId: 'p1',
        baselineId: b.baselineId,
        verifiedBy: 'worker:baseline-verifier/onboard_shipit_dev',
      );

      // Preserved as real evidence of what was asserted...
      expect(claimed.verifiedBy, 'worker:baseline-verifier/onboard_shipit_dev');
      expect(claimed.verifiedAt, isNotNull);
      expect(claimed.verificationKind, EvidenceKind.agentClaimedEvidence);
      // ...and it unlocks nothing.
      expect(claimed.isIndependentlyVerified, isFalse);
      expect(
        () => engine.requestBaselineApproval(
          productId: 'p1',
          baselineId: b.baselineId,
        ),
        throwsA(isA<BaselineNotVerifiedException>()),
      );
    });

    test('an identity cannot be upgraded to platform evidence alongside a '
        'proof that names a different verifier', () async {
      final b = await proposeFor('p1');
      final proof = agreeingProof(b, verifiedBy: 'real-verifier');
      await expectLater(
        engine.verifyBaseline(
          productId: 'p1',
          baselineId: b.baselineId,
          verifiedBy: 'attacker-supplied-identity',
          reDerivation: proof,
        ),
        throwsA(isA<BaselineIndependenceRefusedException>()),
      );
    });

    test(
      'a blank identity is refused outright, not recorded as a claim',
      () async {
        final b = await proposeFor('p1');
        await expectLater(
          engine.verifyBaseline(
            productId: 'p1',
            baselineId: b.baselineId,
            verifiedBy: '   ',
          ),
          throwsA(isA<BaselineApprovalRequiredException>()),
        );
        final after = await engine.readBaselineRevision('p1', b.revision);
        expect(after.verificationKind, isNull);
      },
    );

    test(
      'a claim cannot be silently upgraded by a later identity-only call',
      () async {
        final b = await proposeFor('p1');
        await engine.verifyBaseline(
          productId: 'p1',
          baselineId: b.baselineId,
          verifiedBy: 'first-claimer',
        );
        final second = await engine.verifyBaseline(
          productId: 'p1',
          baselineId: b.baselineId,
          verifiedBy: 'second-claimer',
        );
        expect(second.verificationKind, EvidenceKind.agentClaimedEvidence);
        expect(second.isIndependentlyVerified, isFalse);
      },
    );

    test(
      'a blank identity does not satisfy the guard when persisted directly',
      () async {
        // The engine refuses a blank identity, so this has to be written at the
        // type level to be reached: `isIndependentlyVerified` must still fail
        // closed for a record that never came through the engine.
        final b = await proposeFor('p1');
        final forged = b.copyWith(
          verificationKind: EvidenceKind.platformVerifiedEvidence,
          verifiedBy: '   ',
          verifiedAt: DateTime.utc(2026, 1, 1),
        );
        expect(forged.isIndependentlyVerified, isFalse);
      },
    );
  });

  group('re-baselining a governed product is covered by the same guard', () {
    test(
      'a fabricated second revision cannot be pushed through the gate',
      () async {
        await approveBaseline(
          engine,
          productId: 'p1',
          baseline: await proposeFor('p1'),
        );
        expect((await engine.readProduct('p1')).state, ProductState.governed);

        // The bypass applied to re-baselining a governed product too, not only
        // to a first baseline.
        final v2 = await engine.proposeBaseline(
          productId: 'p1',
          facts: [_fact('a new and different claim')],
        );
        final forged = PlatformReDerivationProof.fromReDerivation(
          baselineId: v2.baselineId,
          baselineRevision: v2.revision,
          reDerivedContentHash: 'cafebabe${'0' * 56}',
          reDerivedContentHashVersion: v2.contentHashVersion,
          producedBy: 'attacker',
          verifiedBy: 'attacker',
          sourceRef: 'local-directory/forged',
        );
        await expectLater(
          engine.verifyBaseline(
            productId: 'p1',
            baselineId: v2.baselineId,
            reDerivation: forged,
          ),
          throwsA(isA<BaselineReDerivationDivergenceException>()),
        );
        await expectLater(
          engine.requestBaselineApproval(
            productId: 'p1',
            baselineId: v2.baselineId,
          ),
          throwsA(isA<BaselineNotVerifiedException>()),
        );
        // Still governed on the accepted revision; the forged one changed nothing.
        expect((await engine.readProduct('p1')).state, ProductState.governed);
      },
    );
  });
}
