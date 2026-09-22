import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';

import 'support/baseline_approval.dart';

BaselineFact _fact() => BaselineFact(
  factId: 'f-1',
  section: BaselineSectionKey.repository,
  claim: 'single pubspec at root',
  provenance: Provenance.observed,
  maturity: BaselineMaturity.implemented,
);

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
    return engine.proposeBaseline(productId: id, facts: [_fact()]);
  }

  group('registering is not governing', () {
    test('a new product starts registered, not governed', () async {
      final p = await engine.createProduct(productId: 'p1', name: 'P1');
      expect(p.state, ProductState.registered);
      expect(p.state.allowsDispatch, isFalse);
    });

    test('proposing a baseline moves the product to baselinePending', () async {
      await proposeFor('p1');
      final p = await engine.readProduct('p1');
      expect(p.state, ProductState.baselinePending);
      expect(p.state.allowsDispatch, isFalse);
    });

    test('the removed activateProduct bypass refuses to govern', () async {
      await engine.createProduct(productId: 'p1', name: 'P1');
      expect(
        // ignore: deprecated_member_use_from_same_package
        () => engine.activateProduct('p1'),
        throwsA(isA<ProductLifecycleException>()),
      );
      final p = await engine.readProduct('p1');
      expect(p.state, ProductState.registered);
    });

    test('no path reaches governed without going through the gate', () async {
      await proposeFor('p1');
      expect(
        () => engine.transitionProduct('p1', to: ProductState.governed),
        throwsA(isA<ProductLifecycleException>()),
      );
    });
  });

  group('independent verification gates the human gate', () {
    test('an unverified baseline cannot be sent for approval', () async {
      final b = await proposeFor('p1');
      expect(
        () => engine.requestBaselineApproval(
          productId: 'p1',
          baselineId: b.baselineId,
        ),
        throwsA(isA<BaselineNotVerifiedException>()),
      );
      expect((await engine.readProduct('p1')).state,
          ProductState.baselinePending);
    });

    test("an agent's own claim is not independent verification", () async {
      final b = await proposeFor('p1');
      await engine.verifyBaseline(
        productId: 'p1',
        baselineId: b.baselineId,
        verifiedBy: 'agent-that-produced-it',
        kind: EvidenceKind.agentClaimedEvidence,
      );
      expect(
        () => engine.requestBaselineApproval(
          productId: 'p1',
          baselineId: b.baselineId,
        ),
        throwsA(isA<BaselineNotVerifiedException>()),
      );
    });

    test('worker verification unlocks the gate and records who attested',
        () async {
      final b = await proposeFor('p1');
      final v = await engine.verifyBaseline(
        productId: 'p1',
        baselineId: b.baselineId,
        verifiedBy: 'worker-7',
      );
      expect(v.isIndependentlyVerified, isTrue);
      expect(v.verifiedBy, 'worker-7');
      expect(v.verificationKind, EvidenceKind.platformVerifiedEvidence);

      await engine.requestBaselineApproval(
        productId: 'p1',
        baselineId: b.baselineId,
      );
      expect(
        (await engine.readProduct('p1')).state,
        ProductState.baselineReview,
      );
    });
  });

  group('approval grants governance', () {
    test('approving a verified baseline governs the product', () async {
      final b = await proposeFor('p1');
      await approveBaseline(engine, productId: 'p1', baseline: b);
      final p = await engine.readProduct('p1');
      expect(p.state, ProductState.governed);
      expect(p.state.allowsDispatch, isTrue);
    });

    test('rejecting returns the product to registered, not governed',
        () async {
      final b = await proposeFor('p1');
      await engine.verifyBaseline(
        productId: 'p1',
        baselineId: b.baselineId,
        verifiedBy: 'worker-7',
      );
      final req = await engine.requestBaselineApproval(
        productId: 'p1',
        baselineId: b.baselineId,
      );
      await engine.resolveBaselineApproval(
        decisionId: req.decisionId,
        choice: HumanDecisionChoice.reject,
        decider: 'human-gate',
        rationale: 'not the right file set',
        signature: testSignature(),
      );
      final p = await engine.readProduct('p1');
      expect(p.state, ProductState.registered);
      expect(p.state.allowsDispatch, isFalse);
    });
  });

  group('operating a governed product', () {
    Future<void> govern(String id) async {
      final b = await proposeFor(id);
      await approveBaseline(engine, productId: id, baseline: b);
    }

    test('pause stops dispatch and resume restores it', () async {
      await govern('p1');
      await engine.transitionProduct(
        'p1',
        to: ProductState.paused,
        satisfiedGuards: const {
          ProductGuard.pauseDecisionRecorded,
          ProductGuard.decisionActorIsHuman,
        },
      );
      expect((await engine.readProduct('p1')).state.allowsDispatch, isFalse);

      await engine.transitionProduct(
        'p1',
        to: ProductState.governed,
        satisfiedGuards: const {
          ProductGuard.resumeDecisionRecorded,
          ProductGuard.decisionActorIsHuman,
        },
      );
      expect((await engine.readProduct('p1')).state.allowsDispatch, isTrue);
    });

    test('pausing without a recorded human decision is refused', () async {
      await govern('p1');
      expect(
        () => engine.transitionProduct('p1', to: ProductState.paused),
        throwsA(isA<ProductLifecycleException>()),
      );
    });

    test('offboarding requires no work in flight', () async {
      await govern('p1');
      expect(
        () => engine.transitionProduct(
          'p1',
          to: ProductState.archived,
          satisfiedGuards: const {
            ProductGuard.offboardDecisionRecorded,
            ProductGuard.decisionActorIsHuman,
          },
        ),
        throwsA(isA<ProductLifecycleException>()),
        reason: 'noWorkInFlight was not established',
      );
    });

    test('re-baselining a governed product does not drop governance',
        () async {
      await govern('p1');
      await engine.proposeBaseline(productId: 'p1', facts: [_fact()]);
      expect((await engine.readProduct('p1')).state, ProductState.governed);
    });
  });

  group('legacy rows', () {
    test('a persisted draft row still deserialises and can move on', () {
      final row = Product.fromJson({
        'productId': 'legacy',
        'name': 'Legacy',
        'state': 'draft',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
        'version': 1,
      });
      expect(row.state.isLegacy, isTrue);
      expect(row.state.canonical, ProductState.registered);
      expect(
        ProductTransitions.isLegalTransition(
          row.state,
          ProductState.baselinePending,
        ),
        isTrue,
      );
    });

    test('state serialises as its wire string, never as .name', () {
      final p = Product(
        productId: 'p1',
        name: 'P1',
        state: ProductState.baselinePending,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      expect(p.toJson()['state'], 'baseline_pending');
    });
  });
}
