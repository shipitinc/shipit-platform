import 'package:test/test.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';

import 'support/baseline_approval.dart';

void main() {
  group('ProductRegistryEngine', () {
    late InMemoryProductRegistryStore store;
    late InMemoryHumanDecisionStore decisions;
    late ProductRegistryEngine engine;

    setUp(() {
      store = InMemoryProductRegistryStore();
      decisions = InMemoryHumanDecisionStore();
      engine = ProductRegistryEngine(
        store: store,
        humanDecisionStore: decisions,
      );
    });

    BaselineFact fact({
      String id = 'f-1',
      BaselineSectionKey section = BaselineSectionKey.repository,
      String claim = 'shipit-platform is the monorepo',
      Provenance provenance = Provenance.observed,
    }) => BaselineFact(
      factId: id,
      section: section,
      claim: claim,
      provenance: provenance,
      maturity: BaselineMaturity.implemented,
      evidenceRefs: const ['shipit-platform'],
      redacted: false,
    );

    test('propose then accept baseline binds revision + contentHash', () async {
      await engine.createProduct(productId: 'shipit', name: 'ShipIt');
      final b1 = await engine.proposeBaseline(
        productId: 'shipit',
        facts: [fact()],
      );
      expect(b1.revision, 1);
      final h1 = b1.contentHash;

      final accepted = await approveBaseline(
        engine,
        productId: 'shipit',
        baseline: b1,
        decider: 'human-gate',
      );
      expect(accepted.status, ProductBaselineStatus.accepted);
      expect(accepted.acceptedBy, 'human-gate');
      expect(accepted.acceptedDecisionId, isNotNull);
      expect(accepted.contentHash, h1);

      // v1 is immutable: replaying the SAME authority is idempotent, and a
      // different decision cannot re-accept the same revision.
      final replay = await engine.acceptBaseline(
        productId: 'shipit',
        baselineId: b1.baselineId,
        approvalDecisionId: accepted.acceptedDecisionId!,
      );
      expect(replay.acceptedAt, accepted.acceptedAt);
      expect(replay.version, accepted.version);

      // New material change = v2, never silent mutation of v1.
      final b2 = await engine.proposeBaseline(
        productId: 'shipit',
        facts: [fact(id: 'f-1', claim: 'shipit-platform is THE monorepo')],
      );
      expect(b2.revision, 2);
      expect(b2.contentHash, isNot(h1));
      expect(b2.supersedesBaselineId, b1.baselineId);
    });

    test('accepted baseline content survives store round-trip', () async {
      await engine.createProduct(productId: 'shipit', name: 'ShipIt');
      final b = await engine.proposeBaseline(
        productId: 'shipit',
        facts: [fact(provenance: Provenance.derived)],
      );
      await approveBaseline(
        engine,
        productId: 'shipit',
        baseline: b,
        decider: 'reviewer',
      );

      final reloaded = await engine.readBaselineRevision('shipit', 1);
      expect(reloaded.facts.single.provenance, Provenance.derived);
      expect(reloaded.contentHash, b.contentHash);
    });

    test('clarification durably stops onboarding, then resumes', () async {
      await engine.createProduct(productId: 'shipit', name: 'ShipIt');
      final clar = await engine.requireClarification(
        productId: 'shipit',
        section: BaselineSectionKey.deployment,
        question: 'Where does ShipIt deploy in prod?',
      );
      expect(clar.status, ClarificationStatus.needsAnswer);

      final record = (await store.readOnboardingForProduct('shipit'))!;
      expect(record.pendingClarifications, 1);
      expect(record.completed, false);

      // A brand-new engine (new process) resumes the SAME lineage.
      final engine2 = ProductRegistryEngine(
        store: store,
        humanDecisionStore: decisions,
      );
      final open = await engine2.readOpenClarifications('shipit');
      expect(open.single.clarificationId, clar.clarificationId);

      final answered = await engine2.answerClarification(
        clarificationId: clar.clarificationId,
        answer: 'us-east-1',
        answeredBy: 'anthony',
      );
      expect(answered.status, ClarificationStatus.answered);
      expect(answered.answer, 'us-east-1');

      final r2 = (await store.readOnboardingForProduct('shipit'))!;
      expect(r2.pendingClarifications, 0);
    });

    test('ProductContext loads bounded authoritative state fresh', () async {
      await engine.createProduct(productId: 'shipit', name: 'ShipIt');
      await engine.addRepositoryReference(
        repositoryId: 'repo-shipit',
        productId: 'shipit',
        uri: 'shipit-platform',
      );
      final b = await engine.proposeBaseline(
        productId: 'shipit',
        facts: [fact(section: BaselineSectionKey.repository)],
      );
      await approveBaseline(
        engine,
        productId: 'shipit',
        baseline: b,
        decider: 'human-gate',
      );
      await engine.requireClarification(
        productId: 'shipit',
        section: BaselineSectionKey.deployment,
        question: 'Q?',
      );

      // fresh engine, no chat/session/global (request-scoped load)
      final ctx = await ProductRegistryEngine(
        store: store,
        humanDecisionStore: decisions,
      ).loadProductContext('shipit');
      expect(ctx.product.productId, 'shipit');
      expect(ctx.repositories.single.uri, 'shipit-platform');
      expect(ctx.activeBaseline!.status, ProductBaselineStatus.accepted);
      expect(ctx.openClarifications.single.question, 'Q?');
    });

    test('multi-product isolation in cache + cross-product negative', () async {
      await engine.createProduct(productId: 'shipit', name: 'ShipIt');
      await engine.createProduct(productId: 'other', name: 'Other');
      await engine.addRepositoryReference(
        repositoryId: 'repo-other',
        productId: 'other',
        uri: 'repo-other-uri',
      );
      final b = await engine.proposeBaseline(
        productId: 'other',
        facts: [fact(id: 'f-o')],
      );

      // Cross-Product access must be rejected at the derived-scope boundary.
      expect(
        () => engine.resolveRepository('shipit', 'repo-other'),
        throwsA(isA<CrossProductAccessException>()),
      );
      expect(
        () => engine.acceptBaseline(
          productId: 'shipit',
          baselineId: b.baselineId,
          approvalDecisionId: 'blappr-${b.baselineId}',
        ),
        throwsA(isA<CrossProductAccessException>()),
      );
    });

    test('repository reference read is durable and scoped', () async {
      await engine.createProduct(productId: 'shipit', name: 'ShipIt');
      await engine.addRepositoryReference(
        repositoryId: 'r1',
        productId: 'shipit',
        uri: 'https://github.com/acme/shipit-platform',
        provider: RepositoryProvider.github,
      );
      final ref = await engine.resolveRepository('shipit', 'r1');
      expect(ref.productId, 'shipit');
      expect(ref.provider, RepositoryProvider.github);
    });

    test('proposeBaseline uses Hash Contract V3', () async {
      await engine.createProduct(productId: 'shipit', name: 'ShipIt');
      final b = await engine.proposeBaseline(
        productId: 'shipit',
        facts: [fact()],
      );
      expect(b.contentHashVersion, 3);
      expect(
        b.contentHash,
        baselineContentHashV3(b.facts),
      );
    });

    test(
      'BASELINE_APPROVAL_BINDS_HASH_VERSION: approval metadata binds all five',
      () async {
        await engine.createProduct(productId: 'shipit', name: 'ShipIt');
        final b = await engine.proposeBaseline(
          productId: 'shipit',
          facts: [fact()],
        );
        await engine.verifyBaseline(
          productId: 'shipit',
          baselineId: b.baselineId,
          verifiedBy: 'worker-test-verifier',
        );
        final request = await engine.requestBaselineApproval(
          productId: 'shipit',
          baselineId: b.baselineId,
        );
        final binding = BaselineApprovalBinding.tryFromMetadata(
          request.metadata,
        );
        expect(binding, isNotNull);
        expect(
          binding!.matches(
            productId: b.productId,
            baselineId: b.baselineId,
            baselineRevision: b.revision,
            contentHash: b.contentHash,
            contentHashVersion: b.contentHashVersion,
          ),
          isTrue,
        );
        expect(binding.contentHashVersion, 3);
      },
    );

    test(
      'BASELINE_APPROVAL_STALE_HASH_VERSION_REJECTED: wrong hash version fails '
      'closed',
      () async {
        await engine.createProduct(productId: 'shipit', name: 'ShipIt');
        final b = await engine.proposeBaseline(
          productId: 'shipit',
          facts: [fact()],
        );
        await engine.verifyBaseline(
          productId: 'shipit',
          baselineId: b.baselineId,
          verifiedBy: 'worker-test-verifier',
        );
        final stale = await engine.requestBaselineApproval(
          productId: 'shipit',
          baselineId: b.baselineId,
        );
        // Rewrite the persisted binding to a different (defective/historical)
        // hash version while keeping the same namespace, and make it a
        // resolved approval so the staleness check is actually reached.
        final staleMetadata = BaselineApprovalBinding(
          productId: b.productId,
          baselineId: b.baselineId,
          baselineRevision: b.revision,
          contentHash: b.contentHash,
          contentHashVersion: 2,
        ).toMetadata();
        final staleJson = stale.toJson()
          ..['metadata'] = staleMetadata
          ..['status'] = HumanDecisionStatus.resolved.wire
          ..['choice'] = HumanDecisionChoice.approve.wire
          ..['decider'] = 'human-gate'
          ..['rationale'] = 'approved under a stale hash version'
          ..['timestamp'] = DateTime.utc(2026, 1, 1).toIso8601String()
          ..['signature'] = testSignature().toJson();
        decisions = InMemoryHumanDecisionStore();
        await decisions.saveHumanDecision(HumanDecision.fromJson(staleJson));
        final engine2 = ProductRegistryEngine(
          store: store,
          humanDecisionStore: decisions,
        );
        expect(
          () => engine2.acceptBaseline(
            productId: 'shipit',
            baselineId: b.baselineId,
            approvalDecisionId: stale.decisionId,
          ),
          throwsA(isA<StaleBaselineApprovalException>()),
        );
      },
    );

    test('BASELINE_APPROVAL_REQUEST_IDEMPOTENCY: no duplicate pending gate', () async {
      await engine.createProduct(productId: 'shipit', name: 'ShipIt');
      final b = await engine.proposeBaseline(
        productId: 'shipit',
        facts: [fact()],
      );
      await engine.verifyBaseline(
        productId: 'shipit',
        baselineId: b.baselineId,
        verifiedBy: 'worker-test-verifier',
      );
      final first = await engine.requestBaselineApproval(
        productId: 'shipit',
        baselineId: b.baselineId,
      );
      final second = await engine.requestBaselineApproval(
        productId: 'shipit',
        baselineId: b.baselineId,
      );
      expect(first.decisionId, second.decisionId);
      final pending = await decisions.readHumanDecisionsForScope(
        BaselineApprovalBinding.scopeFor('shipit'),
      );
      expect(pending.where((d) => !d.status.isResolved).length, 1);
    });
  });
}
