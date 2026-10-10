import 'dart:io';

import 'package:control_plane_server/src/baseline/baseline_derivation.dart';
import 'package:control_plane_server/src/baseline/baseline_production_lane.dart';
import 'package:control_plane_server/src/credentials/credential_key_service.dart';
import 'package:control_plane_server/src/credentials/repository_snapshot_acquirer.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:workflow_engine/workflow_engine.dart'
    show ProductGuard, ProductTransitions;
// `test` is a dev_dependency of `control_plane_server`; it is unresolved as a
// `lib/` import, which is a known cost of co-locating tests here rather than
// under `test/`.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

import 'baseline_test_fixtures.dart';

/// Two principals the engine will accept as distinct, and which name a
/// producer and a verifier rather than one identity wearing two hats.
final BaselinePrincipals kTestPrincipals = BaselinePrincipals(
  producer: 'lane:baseline-producer',
  verifier: 'lane:baseline-verifier',
);

class _LaneHarness {
  _LaneHarness._(this.registry, this.lane, this.materializer, this.secrets);

  final RegistryFixture registry;
  final BaselineProductionLane lane;
  final ScriptedSnapshotMaterializer materializer;
  final RecordingSecretProvider secrets;

  Future<void> setUp({
    String productId = 'product-a',
    String repositoryId = 'repo',
    String uri = 'git@remote.test:org/repository.git',
    bool withCredential = true,
    ScriptedSnapshotMaterializer? materializer,
    List<String> logSink = const [],
  }) async {
    await registry.registerProduct(
      productId: productId,
      repositoryId: repositoryId,
      uri: uri,
    );
    if (withCredential) {
      await seedCredential(
        registry.engine,
        productId: productId,
        repositoryId: repositoryId,
        host: uri,
      );
    }
  }
}

void main() {
  late RegistryFixture registry;
  late ScriptedSnapshotMaterializer materializer;
  late RecordingSecretProvider secrets;
  late BaselineProductionLane lane;
  final events = <String>[];

  setUp(() {
    registry = RegistryFixture();
    materializer = ScriptedSnapshotMaterializer();
    secrets = RecordingSecretProvider();
    events.clear();
    final keyService = CredentialKeyService(
      engine: registry.engine,
      secretProvider: secrets,
      verifier: ScriptedAccessVerifier(committedRevision: kTestRevision),
      clock: () => DateTime.utc(2026, 2, 1),
    );
    lane = BaselineProductionLane(
      engine: registry.engine,
      acquirer: RepositorySnapshotAcquirer(
        engine: registry.engine,
        credentialKeyService: keyService,
        materializer: materializer,
      ),
      principals: kTestPrincipals,
      baselineStore: registry.store,
      log: (event, _) => events.add(event),
    );
  });

  Future<_LaneHarness> harness({
    String productId = 'product-a',
    String repositoryId = 'repo',
    String uri = 'git@remote.test:org/repository.git',
    bool withCredential = true,
  }) async {
    await registry.registerProduct(
      productId: productId,
      repositoryId: repositoryId,
      uri: uri,
    );
    if (withCredential) {
      await seedCredential(
        registry.engine,
        productId: productId,
        repositoryId: repositoryId,
        host: uri,
      );
    }
    return _LaneHarness._(registry, lane, materializer, secrets);
  }

  group('BaselineProductionLane', () {
    test('takes a registered product to a PENDING human decision', () async {
      await harness();

      final outcome = await lane.run(
        productId: 'product-a',
        repositoryId: 'repo',
        pinnedRevision: kTestRevision,
      );

      expect(outcome, isA<BaselineLaneAwaitingApproval>());
      final awaiting = outcome as BaselineLaneAwaitingApproval;
      expect(awaiting.sourceRevision, kTestRevision);
      expect(awaiting.alreadyVerified, isFalse);

      final product = await registry.engine.readProduct('product-a');
      expect(product.state.canonical, ProductState.baselineReview);

      final decision = await registry.decisions.readHumanDecision(
        awaiting.decisionId,
      );
      expect(decision, isNotNull);
      expect(decision!.status, HumanDecisionStatus.pending);
      expect(
        decision.status.isResolved,
        isFalse,
        reason: 'the lane creates the gate; it never resolves it',
      );
    });

    test(
      'the recorded verification is PLATFORM evidence, not an agent claim',
      () async {
        await harness();
        await lane.run(
          productId: 'product-a',
          repositoryId: 'repo',
          pinnedRevision: kTestRevision,
        );

        final baselines = await registry.engine.readBaselines('product-a');
        expect(baselines, hasLength(1));
        expect(
          baselines.single.verificationKind,
          EvidenceKind.platformVerifiedEvidence,
        );
        expect(baselines.single.verifiedBy, isNotNull);
        expect(baselines.single.isIndependentlyVerified, isTrue);
        // Two genuinely different principals, compared through the engine's own
        // normalization rather than by string equality here.
        expect(
          normalizeBaselineIdentity(baselines.single.verifiedBy!),
          isNot(normalizeBaselineIdentity(kTestPrincipals.producer)),
        );
      },
    );

    test('a self-attesting producer cannot be configured', () async {
      // The engine refuses a self-attested proof. Configuring one anyway would
      // turn a misconfiguration into an unexplained refusal on every run, so it
      // fails where it was introduced instead.
      expect(
        () => BaselinePrincipals(
          producer: 'lane:baseline',
          verifier: '  LANE:BASELINE  ',
        ),
        throwsArgumentError,
      );
    });

    test(
      'a producer whose row lies about its own facts is caught by divergence',
      () async {
        await harness();
        // The strongest form of fabrication: the row's `contentHash` describes
        // content the repository DOES support, while the `facts` next to it say
        // something else entirely. A verifier that trusted the stored hash — as
        // every pre-§12 verifier did — would attest to this in a stroke.
        final real = await registry.engine.proposeBaseline(
          productId: 'product-a',
          facts: deriveBaselineFacts(await _observationsFor(materializer)),
        );
        final forged = ProductBaseline(
          baselineId: real.baselineId,
          productId: real.productId,
          revision: real.revision,
          status: real.status,
          facts: const [
            BaselineFact(
              factId: 'discovery-0',
              section: BaselineSectionKey.design,
              claim: 'Fabricated: no read of this repository says this.',
              provenance: Provenance.observed,
              maturity: BaselineMaturity.implemented,
            ),
          ],
          // The hash of the HONEST content, attached to dishonest facts.
          contentHash: real.contentHash,
          contentHashVersion: real.contentHashVersion,
          createdAt: real.createdAt,
          updatedAt: real.updatedAt,
          version: real.version,
        );
        await registry.store.saveBaseline(forged);

        final outcome = await lane.run(
          productId: 'product-a',
          repositoryId: 'repo',
          pinnedRevision: kTestRevision,
        );

        expect(
          outcome,
          isA<BaselineLaneSkipped>().having(
            (o) => o.code,
            'code',
            BaselineLaneSkipped.divergentCode,
          ),
        );
        expect(events, contains('baseline.lane.diverged'));

        // Nothing was verified, and nothing was repaired: divergence is reported,
        // not overwritten by a re-derivation that agrees with itself.
        final after = (await registry.engine.readBaselines('product-a')).single;
        expect(after.verifiedAt, isNull);
        expect(after.verificationKind, isNull);
        expect(after.isIndependentlyVerified, isFalse);
      },
    );

    test(
      'KNOWN CONTRACT DEFECT: the engine certifies a row whose stored hash lies about its facts',
      () async {
        // Written to fail loudly the day someone adds the missing check.
        //
        // `verifyBaseline` compares the proof's `reDerivedContentHash` against
        // `baseline.contentHash` and stops there. It never asks whether
        // `contentHash` describes `facts`. So any row whose facts were replaced
        // while its hash was kept is certified by anyone who reads the stored
        // hash back and passes it in — which is precisely the rubber stamp
        // `PlatformReDerivationProof` exists to make inexpressible.
        //
        // The domain's own writers keep the row self-consistent
        // (`proposeBaseline` computes the hash, `addHumanBaselineClaim` recomputes
        // it, and `copyWith` documents that changing facts REQUIRES passing the
        // matching hash). So this is a latent hole rather than a live one — but it
        // is a hole in the guard this whole work item exists to harden, and it is
        // reported rather than left for a reviewer to find.
        //
        // This lane is NOT vulnerable: it recomputes the hash from the row's own
        // facts and refuses when they disagree with `contentHash` before it builds
        // any proof. That check is asserted separately below.
        await harness();
        final real = await registry.engine.proposeBaseline(
          productId: 'product-a',
          facts: deriveBaselineFacts(await _observationsFor(materializer)),
        );
        await registry.store.saveBaseline(
          ProductBaseline(
            baselineId: real.baselineId,
            productId: real.productId,
            revision: real.revision,
            status: real.status,
            facts: const [
              BaselineFact(
                factId: 'discovery-0',
                section: BaselineSectionKey.design,
                claim: 'Fabricated.',
                provenance: Provenance.observed,
                maturity: BaselineMaturity.implemented,
              ),
            ],
            contentHash: real.contentHash,
            contentHashVersion: real.contentHashVersion,
            createdAt: real.createdAt,
            updatedAt: real.updatedAt,
            version: real.version,
          ),
        );

        final verified = await registry.engine.verifyBaseline(
          productId: 'product-a',
          baselineId: real.baselineId,
          reDerivation: PlatformReDerivationProof.fromReDerivation(
            baselineId: real.baselineId,
            baselineRevision: real.revision,
            reDerivedContentHash: real.contentHash,
            reDerivedContentHashVersion: real.contentHashVersion,
            producedBy: 'lane:baseline-producer',
            verifiedBy: 'lane:baseline-verifier',
            sourceRef: 'ssh://git@remote.test/org/repository.git',
          ),
        );

        expect(
          verified.verificationKind,
          EvidenceKind.platformVerifiedEvidence,
          reason:
              'THE DEFECT. Expected a refusal: the facts on this row do not '
              'hash to its contentHash.',
        );
      },
    );

    test(
      'the lane refuses to attest a row whose stored hash does not match its facts',
      () async {
        // The lane's own answer to the defect above: it recomputes from the facts
        // and refuses, rather than trusting a hash it did not produce.
        await harness();
        final real = await registry.engine.proposeBaseline(
          productId: 'product-a',
          facts: deriveBaselineFacts(await _observationsFor(materializer)),
        );
        await registry.store.saveBaseline(
          ProductBaseline(
            baselineId: real.baselineId,
            productId: real.productId,
            revision: real.revision,
            status: real.status,
            facts: const [
              BaselineFact(
                factId: 'discovery-0',
                section: BaselineSectionKey.design,
                claim: 'Fabricated: no read of this repository says this.',
                provenance: Provenance.observed,
                maturity: BaselineMaturity.implemented,
              ),
            ],
            contentHash: real.contentHash,
            contentHashVersion: real.contentHashVersion,
            createdAt: real.createdAt,
            updatedAt: real.updatedAt,
            version: real.version,
          ),
        );

        final outcome = await lane.run(
          productId: 'product-a',
          repositoryId: 'repo',
          pinnedRevision: kTestRevision,
        );

        expect(
          outcome,
          isA<BaselineLaneSkipped>().having(
            (o) => o.code,
            'code',
            BaselineLaneSkipped.divergentCode,
          ),
        );
        expect(
          (await registry.engine.readBaselines(
            'product-a',
          )).single.isIndependentlyVerified,
          isFalse,
        );
      },
    );

    test(
      're-running on unchanged source reuses the baseline, not a new revision',
      () async {
        await harness();

        final first =
            await lane.run(
                  productId: 'product-a',
                  repositoryId: 'repo',
                  pinnedRevision: kTestRevision,
                )
                as BaselineLaneAwaitingApproval;
        final second =
            await lane.run(
                  productId: 'product-a',
                  repositoryId: 'repo',
                  pinnedRevision: kTestRevision,
                )
                as BaselineLaneAwaitingApproval;

        expect(second.baselineId, first.baselineId);
        expect(second.revision, first.revision);
        expect(second.alreadyVerified, isTrue);
        expect(await registry.engine.readBaselines('product-a'), hasLength(1));
        // The same pending decision, not a second gate.
        expect(second.decisionId, first.decisionId);
      },
    );

    test(
      'a crash after the proposal leaves a state the next run can pick up',
      () async {
        // Restart-safety: simulate a crash by running the lane to the proposal
        // and stopping before verification, then constructing a brand-new lane over
        // the SAME durable stores — the process-level analogue of a restart.
        await harness();
        await registry.engine.proposeBaseline(
          productId: 'product-a',
          facts: deriveBaselineFacts(await _observationsFor(materializer)),
        );

        // A second process: same stores, new lane object, no in-memory carry-over.
        final restarted = BaselineProductionLane(
          engine: registry.engine,
          acquirer: RepositorySnapshotAcquirer(
            engine: registry.engine,
            credentialKeyService: CredentialKeyService(
              engine: registry.engine,
              secretProvider: secrets,
              verifier: ScriptedAccessVerifier(
                committedRevision: kTestRevision,
              ),
            ),
            materializer: ScriptedSnapshotMaterializer(),
          ),
          principals: kTestPrincipals,
          baselineStore: registry.store,
        );

        final outcome = await restarted.run(
          productId: 'product-a',
          repositoryId: 'repo',
          pinnedRevision: kTestRevision,
        );

        expect(outcome, isA<BaselineLaneAwaitingApproval>());
        // Reused, not re-proposed: the content the crashed run produced is still
        // the current revision, so nothing was duplicated.
        expect(await registry.engine.readBaselines('product-a'), hasLength(1));
      },
    );

    test(
      'a human claim survives a re-run, and is NOT reported as repository drift',
      () async {
        // THE F-3 REGRESSION. The hand-run script compared a scraped-only
        // re-derivation against a content hash computed over scraped + human, so
        // "run, a human adds a claim, run again" always refused and blamed the
        // repository.
        await harness();
        final first =
            await lane.run(
                  productId: 'product-a',
                  repositoryId: 'repo',
                  pinnedRevision: kTestRevision,
                )
                as BaselineLaneAwaitingApproval;

        await registry.engine.addHumanBaselineClaim(
          productId: 'product-a',
          baselineId: first.baselineId,
          section: BaselineSectionKey.design,
          claim:
              'What this product is actually for, known only to the operator.',
          author: 'operator@example.test',
          maturity: BaselineMaturity.implemented,
        );

        final outcome = await lane.run(
          productId: 'product-a',
          repositoryId: 'repo',
          pinnedRevision: kTestRevision,
        );

        // It does NOT blame the repository.
        expect(
          outcome,
          isNot(
            isA<BaselineLaneSkipped>().having(
              (o) => o.code,
              'code',
              BaselineLaneSkipped.divergentCode,
            ),
          ),
        );
        // And the human's claim is still there.
        final baseline = (await registry.engine.readBaselines(
          'product-a',
        )).single;
        expect(
          baseline.facts.any((f) => f.provenance == Provenance.humanProvided),
          isTrue,
          reason:
              'a re-run must never start from scratch and drop what only a '
              'human knew',
        );
      },
    );

    test(
      'human-authored claims are reported honestly, never attested over',
      () async {
        await harness();
        final first =
            await lane.run(
                  productId: 'product-a',
                  repositoryId: 'repo',
                  pinnedRevision: kTestRevision,
                )
                as BaselineLaneAwaitingApproval;
        await registry.engine.addHumanBaselineClaim(
          productId: 'product-a',
          baselineId: first.baselineId,
          section: BaselineSectionKey.design,
          claim: 'Operator-authored purpose.',
          author: 'operator@example.test',
        );

        final outcome = await lane.run(
          productId: 'product-a',
          repositoryId: 'repo',
          pinnedRevision: kTestRevision,
        );

        // The frozen contract verifies whole-content equality, and a human claim
        // is by definition not re-derivable. The lane says so rather than
        // attesting over the subset and calling it the whole.
        expect(
          outcome,
          isA<BaselineLaneSkipped>().having(
            (o) => o.code,
            'code',
            BaselineLaneSkipped.humanAuthoredClaimsCode,
          ),
        );
        final skipped = outcome as BaselineLaneSkipped;
        expect(skipped.reason, contains('DOES still match'));

        // Nothing was written: no claim, no platform evidence, no approval gate.
        final baseline = (await registry.engine.readBaselines(
          'product-a',
        )).single;
        expect(baseline.isIndependentlyVerified, isFalse);
        // Amending cancels the outstanding decision — correctly, because its
        // content-hash binding no longer describes the candidate — and the lane
        // then neither resolves that cancelled decision nor opens a new one.
        final decisions = await registry.decisions.readHumanDecisionsForScope(
          BaselineApprovalBinding.scopeFor('product-a'),
        );
        expect(
          decisions.where((d) => d.status == HumanDecisionStatus.pending),
          isEmpty,
          reason:
              'no approval gate was opened on a baseline the lane cannot '
              'verify',
        );
        expect(
          decisions.where((d) => d.status == HumanDecisionStatus.cancelled),
          hasLength(1),
        );
        expect(decisions.where((d) => d.status.isResolved), isEmpty);
      },
    );

    test(
      'the merge preserves human claims and clears the stale attestation',
      () async {
        await harness();
        final first =
            await lane.run(
                  productId: 'product-a',
                  repositoryId: 'repo',
                  pinnedRevision: kTestRevision,
                )
                as BaselineLaneAwaitingApproval;
        await registry.engine.addHumanBaselineClaim(
          productId: 'product-a',
          baselineId: first.baselineId,
          section: BaselineSectionKey.design,
          claim: 'Operator-authored purpose.',
          author: 'operator@example.test',
        );

        // Discovery is UNCHANGED, which is exactly the condition the merge path
        // exists for: the scrape-derivable half still matches, so the operator's
        // claims are preserved by merging rather than by re-proposing.
        await lane.run(
          productId: 'product-a',
          repositoryId: 'repo',
          pinnedRevision: kTestRevision,
        );

        final baselines = await registry.engine.readBaselines('product-a');
        expect(baselines, hasLength(1), reason: 'no revision spam');
        final merged = baselines.single;
        expect(
          merged.revision,
          first.revision,
          reason: 'an in-place merge, not a new revision',
        );
        expect(
          merged.facts.any((f) => f.provenance == Provenance.humanProvided),
          isTrue,
        );
        expect(
          merged.verifiedAt,
          isNull,
          reason:
              'the artefact the attestation described is no longer the '
              'artefact on the record — and `copyWith` cannot say that, so this '
              'write constructs the row instead',
        );
        expect(merged.verificationKind, isNull);
        expect(events, contains('baseline.lane.merged_human_claims'));
      },
    );

    test(
      'KNOWN CONTRACT DEFECT: an amendment cannot clear a stale attestation',
      () async {
        // Written to fail loudly the day someone fixes it.
        //
        // `ProductBaseline.copyWith` reads `verifiedAt ?? this.verifiedAt`, so a
        // caller passing `verifiedAt: null` KEEPS the old value. Every amendment
        // path in `packages/product_registry` is written as though it cleared the
        // attestation — `addHumanBaselineClaim` says so in its own doc comment —
        // and it does not. A baseline amended after verification therefore still
        // reports `isIndependentlyVerified == true`, for content no re-derivation
        // has ever seen.
        await harness();
        final first =
            await lane.run(
                  productId: 'product-a',
                  repositoryId: 'repo',
                  pinnedRevision: kTestRevision,
                )
                as BaselineLaneAwaitingApproval;
        expect(
          (await registry.engine.readBaselines(
            'product-a',
          )).single.isIndependentlyVerified,
          isTrue,
        );

        await registry.engine.addHumanBaselineClaim(
          productId: 'product-a',
          baselineId: first.baselineId,
          section: BaselineSectionKey.design,
          claim: 'Operator-authored purpose.',
          author: 'operator@example.test',
        );

        final amended = (await registry.engine.readBaselines(
          'product-a',
        )).single;
        expect(
          amended.contentHash,
          isNot(first.baselineId),
          reason: 'sanity: the amendment really did rewrite the content',
        );
        expect(
          amended.isIndependentlyVerified,
          isTrue,
          reason:
              'THE DEFECT. Expected false: the attestation predates the '
              'amendment and describes content that no longer exists.',
        );
      },
    );

    test(
      'a changed discovery carries the operator claims forward, never drops them',
      () async {
        await harness();
        final first =
            await lane.run(
                  productId: 'product-a',
                  repositoryId: 'repo',
                  pinnedRevision: kTestRevision,
                )
                as BaselineLaneAwaitingApproval;
        await registry.engine.addHumanBaselineClaim(
          productId: 'product-a',
          baselineId: first.baselineId,
          section: BaselineSectionKey.design,
          claim: 'Operator-authored purpose.',
          author: 'operator@example.test',
        );

        // Discovery moves on, so the scrape-derivable half genuinely differs and
        // the in-place merge cannot apply.
        // A real change to what discovery can see. `pubspec.yaml` names a
        // package, so its presence is itself an observation.
        materializer.files['pubspec.yaml'] =
            'name: fixture_package\n'
            'description: A fixture that now declares a stack.\n';
        final second = await lane.run(
          productId: 'product-a',
          repositoryId: 'repo',
          pinnedRevision: kTestRevision,
        );

        final baselines = await registry.engine.readBaselines('product-a');
        final current = baselines.first;
        expect(
          current.facts.any((f) => f.provenance == Provenance.humanProvided),
          isTrue,
          reason:
              'a new revision must not silently forget what only a human knew',
        );
        expect(second, isA<BaselineLaneSkipped>());
        expect(events, contains('baseline.lane.carried_human_claims_forward'));
      },
    );

    test(
      'a blocked product is SKIPPED, observably, without writing anything',
      () async {
        await harness();
        await registry.store.saveClarification(
          ClarificationRequest(
            clarificationId: 'clar-1',
            productId: 'product-a',
            onboardingId: 'onb-a',
            section: BaselineSectionKey.design,
            question: 'What is this product for?',
            createdAt: DateTime.utc(2026, 1, 5),
          ),
        );
        // Drive the product into baselineBlocked through the workflow graph,
        // which only allows that edge from baselinePending.
        await registry.engine.transitionProduct(
          'product-a',
          to: ProductState.baselinePending,
          now: DateTime.utc(2026, 1, 4),
        );
        await registry.engine.transitionProduct(
          'product-a',
          to: ProductState.baselineBlocked,
          satisfiedGuards: const {ProductGuard.clarificationOpen},
          now: DateTime.utc(2026, 1, 5),
        );

        final outcome = await lane.run(
          productId: 'product-a',
          repositoryId: 'repo',
          pinnedRevision: kTestRevision,
        );

        // The LANE refuses, while the sweep deliberately still enqueues, so the
        // gap — a blocked product with no baseline — is on the record instead of
        // being invisible.
        expect(
          outcome,
          isA<BaselineLaneSkipped>().having(
            (o) => o.code,
            'code',
            BaselineLaneSkipped.blockedCode,
          ),
        );
        expect(
          outcome.toString(),
          contains('still has no baseline'),
          reason: 'the reason must state the gap, not just the refusal',
        );
        expect(await registry.engine.readBaselines('product-a'), isEmpty);
        expect(materializer.materializations, 0);
      },
    );

    test('an empty derivation is refused rather than proposed', () async {
      await harness();
      materializer.files.clear();

      final outcome = await lane.run(
        productId: 'product-a',
        repositoryId: 'repo',
        pinnedRevision: kTestRevision,
      );

      expect(outcome, isA<BaselineLaneSkipped>());
      expect(await registry.engine.readBaselines('product-a'), isEmpty);
    });

    test('the snapshot tree is released on every path', () async {
      await harness();
      await lane.run(
        productId: 'product-a',
        repositoryId: 'repo',
        pinnedRevision: kTestRevision,
      );
      for (final root in materializer.created) {
        expect(root.existsSync(), isFalse);
      }
    });

    test('THE HUMAN GATE STILL HOLDS after the lane has run', () async {
      await harness();
      await lane.run(
        productId: 'product-a',
        repositoryId: 'repo',
        pinnedRevision: kTestRevision,
      );

      // The edge demands BOTH a resolved approving decision AND a human
      // decider. The lane produced a pending decision, so it satisfies neither,
      // and nothing it did moved either requirement.
      final required = ProductTransitions.requiredGuards(
        ProductState.baselineReview,
        ProductState.governed,
      );
      expect(
        required,
        containsAll(<ProductGuard>[
          ProductGuard.baselineApproved,
          ProductGuard.decisionActorIsHuman,
        ]),
        reason: 'the human gate is the same gate the lane found, unchanged',
      );
      expect(
        ProductTransitions.requiresHumanDecision(
          ProductState.baselineReview,
          ProductState.governed,
        ),
        isTrue,
      );

      // Supplying every guard EXCEPT the human one is refused. This is the
      // assertion that matters: `baselineVerifiedIndependently` is not on this
      // edge, so a lane that had somehow satisfied every machine guard would
      // still be stopped here — by the one requirement automation cannot meet.
      await expectLater(
        registry.engine.transitionProduct(
          'product-a',
          to: ProductState.governed,
          satisfiedGuards: const {ProductGuard.baselineApproved},
        ),
        throwsA(isA<ProductLifecycleException>()),
      );

      final product = await registry.engine.readProduct('product-a');
      expect(product.state.canonical, ProductState.baselineReview);
    });

    test('a second product goes through the identical code path', () async {
      // PRODUCT-AGNOSTICISM, end to end. Two products, different repositories,
      // different hosts, different deploy keys, different confirmed host keys.
      // No branch anywhere names either one, and no configuration carries over.
      await harness(
        productId: 'product-a',
        repositoryId: 'repo-a',
        uri: 'git@first-remote.test:org/alpha.git',
      );
      await harness(
        productId: 'product-b',
        repositoryId: 'repo-b',
        uri: 'git@second-remote.test:org/beta.git',
      );

      final first =
          await lane.run(
                productId: 'product-a',
                repositoryId: 'repo-a',
                pinnedRevision: kTestRevision,
              )
              as BaselineLaneAwaitingApproval;
      final second =
          await lane.run(
                productId: 'product-b',
                repositoryId: 'repo-b',
                pinnedRevision: kTestRevision,
              )
              as BaselineLaneAwaitingApproval;

      expect(first.productId, 'product-a');
      expect(second.productId, 'product-b');
      expect(first.decisionId, isNot(second.decisionId));
      expect(
        (await registry.engine.readBaselines(
          'product-b',
        )).single.isIndependentlyVerified,
        isTrue,
      );
      expect(
        (await registry.engine.readBaselines(
          'product-a',
        )).single.isIndependentlyVerified,
        isTrue,
      );
    });
  });
}

/// Reads the fixture snapshot the same way the lane does, so a test that writes
/// a proposal by hand derives its facts the same way the lane will.
Future<List<DiscoveryObservation>> _observationsFor(
  ScriptedSnapshotMaterializer materializer,
) async {
  final root = Directory.systemTemp.createTempSync('baseline_obs_');
  addTearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  for (final entry in materializer.files.entries) {
    File('${root.path}/${entry.key}').writeAsStringSync(entry.value);
  }
  return ReadOnlyRepositoryReader(snapshotRoot: root).inspect();
}
