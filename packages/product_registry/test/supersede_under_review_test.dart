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

void main() {
  late ProductRegistryEngine engine;

  setUp(() async {
    engine = ProductRegistryEngine(
      store: InMemoryProductRegistryStore(),
      humanDecisionStore: InMemoryHumanDecisionStore(),
    );
    await engine.createProduct(productId: 'p1', name: 'P1');
  });

  Future<ProductBaseline> proposeVerified(String claim) async {
    final b = await engine.proposeBaseline(
      productId: 'p1',
      facts: [_fact(claim)],
    );
    await engine.verifyBaseline(
      productId: 'p1',
      baselineId: b.baselineId,
      verifiedBy: 'worker-7',
    );
    return b;
  }

  test('superseding the candidate under review is a machine action', () async {
    final v1 = await proposeVerified('v1');
    await engine.requestBaselineApproval(
      productId: 'p1',
      baselineId: v1.baselineId,
    );
    expect((await engine.readProduct('p1')).state, ProductState.baselineReview);

    // Proposing v2 supersedes the candidate. Nobody requested changes, so the
    // product must stay in review rather than demanding a human decision that
    // was never made.
    await proposeVerified('v2');
    expect(
      (await engine.readProduct('p1')).state,
      ProductState.baselineReview,
      reason: 'still awaiting a human; only the candidate changed',
    );
  });

  test('the superseded revision stops being approvable', () async {
    final v1 = await proposeVerified('v1');
    await engine.requestBaselineApproval(
      productId: 'p1',
      baselineId: v1.baselineId,
    );
    final v2 = await proposeVerified('v2');

    // v2 is now the live revision; approving it governs the product.
    await approveBaseline(engine, productId: 'p1', baseline: v2);
    final p = await engine.readProduct('p1');
    expect(p.state, ProductState.governed);

    final revisions = await engine.readBaselines('p1');
    final first = revisions.firstWhere((b) => b.baselineId == v1.baselineId);
    expect(first.status, isNot(ProductBaselineStatus.accepted));
  });

  test('a rejected baseline returns to registered and can start over',
      () async {
    final v1 = await proposeVerified('v1');
    final req = await engine.requestBaselineApproval(
      productId: 'p1',
      baselineId: v1.baselineId,
    );
    await engine.resolveBaselineApproval(
      decisionId: req.decisionId,
      choice: HumanDecisionChoice.reject,
      decider: 'operator',
      rationale: 'wrong file set',
      signature: testSignature(),
    );
    expect((await engine.readProduct('p1')).state, ProductState.registered);

    // Starting over is a clean registered -> baselinePending hop.
    await proposeVerified('v2');
    expect(
      (await engine.readProduct('p1')).state,
      ProductState.baselinePending,
    );
  });
}
