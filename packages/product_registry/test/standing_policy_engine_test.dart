import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:test/test.dart';

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

  Future<void> govern(String id) async {
    await engine.createProduct(productId: id, name: id);
    final b = await engine.proposeBaseline(productId: id, facts: [_fact()]);
    await approveBaseline(engine, productId: id, baseline: b);
  }

  Future<StandingPolicy?> authorise(
    String productId, {
    List<PolicyAction> actions = const [PolicyAction.push, PolicyAction.merge],
    HumanDecisionChoice choice = HumanDecisionChoice.approve,
    String rationale = 'Approved 31 of 31 unchanged',
  }) async {
    final req = await engine.requestPolicyAuthorisation(
      productId: productId,
      actions: actions,
    );
    return engine.resolvePolicyAuthorisation(
      decisionId: req.decisionId,
      choice: choice,
      decider: 'operator',
      rationale: rationale,
      signature: testSignature(),
    );
  }

  group('creating a policy is itself gated', () {
    test('the request is a blocking decision, and creates nothing yet',
        () async {
      await govern('p1');
      final req = await engine.requestPolicyAuthorisation(
        productId: 'p1',
        actions: const [PolicyAction.push],
      );
      expect(req.status, HumanDecisionStatus.pending);
      expect(req.blocking, isTrue);
      expect(await engine.readPolicies('p1'), isEmpty);
    });

    test('declining records the decision but authorises nothing', () async {
      await govern('p1');
      final policy = await authorise(
        'p1',
        choice: HumanDecisionChoice.reject,
      );
      expect(policy, isNull);
      expect(await engine.readPolicies('p1'), isEmpty);
      expect(
        await engine.authorisationFor(
          productId: 'p1',
          action: PolicyAction.push,
        ),
        isNull,
      );
    });

    test('approving creates a policy citing the decision that made it',
        () async {
      await govern('p1');
      final policy = (await authorise('p1'))!;
      expect(policy.authorisedBy, 'operator');
      expect(policy.rationale, contains('31 of 31'));
      expect(policy.authorisingDecisionId, isNotEmpty);
      expect(policy.actions, [PolicyAction.push, PolicyAction.merge]);
    });

    test('a policy must record why it was authorised', () async {
      await govern('p1');
      final req = await engine.requestPolicyAuthorisation(
        productId: 'p1',
        actions: const [PolicyAction.push],
      );
      expect(
        () => engine.resolvePolicyAuthorisation(
          decisionId: req.decisionId,
          choice: HumanDecisionChoice.approve,
          decider: 'operator',
          rationale: '',
          signature: testSignature(),
        ),
        throwsA(isA<InvalidPolicyScopeException>()),
      );
    });
  });

  group('scope cannot be open-ended', () {
    test('an empty policy is refused', () async {
      await govern('p1');
      expect(
        () => engine.requestPolicyAuthorisation(
          productId: 'p1',
          actions: const [],
        ),
        throwsA(isA<InvalidPolicyScopeException>()),
      );
    });

    test('an ungoverned product cannot carry a policy', () async {
      await engine.createProduct(productId: 'p1', name: 'p1');
      expect(
        () => engine.requestPolicyAuthorisation(
          productId: 'p1',
          actions: const [PolicyAction.push],
        ),
        throwsA(isA<InvalidPolicyScopeException>()),
      );
    });

    test('a policy never covers another product', () async {
      await govern('p1');
      await govern('p2');
      await authorise('p1');
      expect(
        await engine.authorisationFor(
          productId: 'p2',
          action: PolicyAction.push,
        ),
        isNull,
      );
    });
  });

  group('citation', () {
    test('an authorised action resolves to a signed decision', () async {
      await govern('p1');
      final created = (await authorise('p1'))!;
      final citing = await engine.mayProceedUnderPolicy(
        productId: 'p1',
        action: PolicyAction.push,
      );
      expect(citing!.policyId, created.policyId);
      expect(citing.authorisingDecisionId, created.authorisingDecisionId);
    });

    test('an action the policy does not name is not covered', () async {
      await govern('p1');
      await authorise('p1', actions: const [PolicyAction.push]);
      expect(
        await engine.mayProceedUnderPolicy(
          productId: 'p1',
          action: PolicyAction.merge,
        ),
        isNull,
      );
    });

    test('pausing a product suspends its policy in practice', () async {
      await govern('p1');
      await authorise('p1');
      await engine.resolveLifecycleDecision(
        decisionId: (await engine.requestLifecycleDecision(
          productId: 'p1',
          action: ProductLifecycleAction.pause,
        ))
            .decisionId,
        choice: HumanDecisionChoice.approve,
        decider: 'operator',
        rationale: 'stopping for now',
        signature: testSignature(),
      );
      expect(
        await engine.mayProceedUnderPolicy(
          productId: 'p1',
          action: PolicyAction.push,
        ),
        isNull,
        reason: 'pausing must actually stop work, policy or not',
      );
      // The policy itself is untouched — it resumes with the product.
      expect((await engine.readPolicies('p1')).single.isRevoked, isFalse);
    });
  });

  group('revocation', () {
    test('is attributed and stops future authorisation', () async {
      await govern('p1');
      final policy = (await authorise('p1'))!;
      final revoked = await engine.revokeStandingPolicy(
        productId: 'p1',
        policyId: policy.policyId,
        revokedBy: 'operator',
        decisionId: 'gd-revoke-1',
      );
      expect(revoked.isRevoked, isTrue);
      expect(revoked.revokedBy, 'operator');
      expect(revoked.revocationDecisionId, 'gd-revoke-1');
      expect(
        await engine.authorisationFor(
          productId: 'p1',
          action: PolicyAction.push,
        ),
        isNull,
      );
    });

    test('a revoked policy stays readable, never deleted', () async {
      await govern('p1');
      final policy = (await authorise('p1'))!;
      await engine.revokeStandingPolicy(
        productId: 'p1',
        policyId: policy.policyId,
        revokedBy: 'operator',
      );
      final all = await engine.readPolicies('p1');
      expect(all, hasLength(1));
      expect(all.single.rationale, contains('31 of 31'));
    });

    test('another product cannot revoke this policy', () async {
      await govern('p1');
      await govern('p2');
      final policy = (await authorise('p1'))!;
      expect(
        () => engine.revokeStandingPolicy(
          productId: 'p2',
          policyId: policy.policyId,
          revokedBy: 'attacker',
        ),
        throwsA(isA<CrossProductAccessException>()),
      );
    });
  });

  group('no two live policies over one scope', () {
    test('authorising again supersedes the previous policy', () async {
      await govern('p1');
      final first = (await authorise('p1', actions: const [PolicyAction.push]))!;
      final second = (await authorise(
        'p1',
        actions: const [PolicyAction.push, PolicyAction.merge],
      ))!;

      final all = await engine.readPolicies('p1');
      final old = all.firstWhere((p) => p.policyId == first.policyId);
      expect(old.isRevoked, isTrue);
      expect(old.revocationReason, PolicyRevocationReason.superseded);

      final live = all.where((p) => !p.isRevoked).toList();
      expect(live, hasLength(1));
      expect(live.single.policyId, second.policyId);
    });

    test('replaying a resolved authorisation returns the same policy',
        () async {
      await govern('p1');
      final req = await engine.requestPolicyAuthorisation(
        productId: 'p1',
        actions: const [PolicyAction.push],
      );
      final a = await engine.resolvePolicyAuthorisation(
        decisionId: req.decisionId,
        choice: HumanDecisionChoice.approve,
        decider: 'operator',
        rationale: 'first',
        signature: testSignature(),
      );
      final b = await engine.resolvePolicyAuthorisation(
        decisionId: req.decisionId,
        choice: HumanDecisionChoice.reject,
        decider: 'someone-else',
        rationale: 'trying to flip it',
        signature: testSignature(),
      );
      expect(b!.policyId, a!.policyId);
      expect((await engine.readPolicies('p1')).where((p) => !p.isRevoked),
          hasLength(1));
    });
  });
}
