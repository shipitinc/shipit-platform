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

  Future<void> govern(String id) async {
    await engine.createProduct(productId: id, name: id);
    final b = await engine.proposeBaseline(productId: id, facts: [_fact()]);
    await approveBaseline(engine, productId: id, baseline: b);
  }

  Future<HumanDecision> resolve(
    HumanDecision request, {
    HumanDecisionChoice choice = HumanDecisionChoice.approve,
    Set<ProductGuard> additionalGuards = const {},
  }) =>
      engine.resolveLifecycleDecision(
        decisionId: request.decisionId,
        choice: choice,
        decider: 'operator',
        rationale: 'because',
        signature: testSignature(),
        additionalGuards: additionalGuards,
      );

  group('pause', () {
    test('a pause is a durable blocking decision, not a flag flip', () async {
      await govern('p1');
      final req = await engine.requestLifecycleDecision(
        productId: 'p1',
        action: ProductLifecycleAction.pause,
      );
      expect(req.status, HumanDecisionStatus.pending);
      expect(req.blocking, isTrue);
      // Raising the gate must not itself change state.
      expect((await engine.readProduct('p1')).state, ProductState.governed);
    });

    test('approving it stops dispatch; resuming restores it', () async {
      await govern('p1');
      await resolve(await engine.requestLifecycleDecision(
        productId: 'p1',
        action: ProductLifecycleAction.pause,
      ));
      expect((await engine.readProduct('p1')).state.allowsDispatch, isFalse);

      await resolve(await engine.requestLifecycleDecision(
        productId: 'p1',
        action: ProductLifecycleAction.resume,
      ));
      expect((await engine.readProduct('p1')).state.allowsDispatch, isTrue);
    });

    test('declining changes nothing but is still recorded', () async {
      await govern('p1');
      final res = await resolve(
        await engine.requestLifecycleDecision(
          productId: 'p1',
          action: ProductLifecycleAction.pause,
        ),
        choice: HumanDecisionChoice.reject,
      );
      expect(res.status, HumanDecisionStatus.resolved);
      expect(res.signature, isNotNull);
      expect((await engine.readProduct('p1')).state, ProductState.governed);
    });

    test('the drain choice is recorded, not left implied', () async {
      await govern('p1');
      final drain = await engine.requestLifecycleDecision(
        productId: 'p1',
        action: ProductLifecycleAction.pause,
      );
      expect(
        LifecycleDecisionBinding.tryFromMetadata(drain.metadata)!.drainInFlight,
        isTrue,
      );
      expect(drain.options!.first.description, contains('finishes'));

      await engine.createProduct(productId: 'p2', name: 'p2');
      final b = await engine.proposeBaseline(productId: 'p2', facts: [_fact()]);
      await approveBaseline(engine, productId: 'p2', baseline: b);
      final halt = await engine.requestLifecycleDecision(
        productId: 'p2',
        action: ProductLifecycleAction.pause,
        drainInFlight: false,
      );
      expect(
        LifecycleDecisionBinding.tryFromMetadata(halt.metadata)!.drainInFlight,
        isFalse,
      );
      expect(halt.options!.first.description, contains('release running'));
    });

    test('raising the same gate twice reuses the pending decision', () async {
      await govern('p1');
      final a = await engine.requestLifecycleDecision(
        productId: 'p1',
        action: ProductLifecycleAction.pause,
      );
      final b = await engine.requestLifecycleDecision(
        productId: 'p1',
        action: ProductLifecycleAction.pause,
      );
      expect(b.decisionId, a.decisionId);
    });
  });

  group('offboard', () {
    test('approving without proving work has drained is refused', () async {
      await govern('p1');
      final req = await engine.requestLifecycleDecision(
        productId: 'p1',
        action: ProductLifecycleAction.offboard,
      );
      expect(
        () => resolve(req),
        throwsA(isA<ProductLifecycleException>()),
        reason: 'noWorkInFlight was never established',
      );
      expect((await engine.readProduct('p1')).state, ProductState.governed);
    });

    test('archives once no work is in flight', () async {
      await govern('p1');
      await resolve(
        await engine.requestLifecycleDecision(
          productId: 'p1',
          action: ProductLifecycleAction.offboard,
        ),
        additionalGuards: const {ProductGuard.noWorkInFlight},
      );
      final p = await engine.readProduct('p1');
      expect(p.state, ProductState.archived);
      expect(p.state.isTerminal, isTrue);
    });

    test('an archived product keeps its baseline history readable', () async {
      await govern('p1');
      await resolve(
        await engine.requestLifecycleDecision(
          productId: 'p1',
          action: ProductLifecycleAction.offboard,
        ),
        additionalGuards: const {ProductGuard.noWorkInFlight},
      );
      final ctx = await engine.loadProductContext('p1');
      expect(ctx.activeBaseline, isNotNull);
      expect(ctx.allBaselines, isNotEmpty);
    });
  });

  group('fails closed', () {
    test('a gate that could never resolve is refused up front', () async {
      await engine.createProduct(productId: 'p1', name: 'p1');
      // registered -> paused is not an edge at all.
      expect(
        () => engine.requestLifecycleDecision(
          productId: 'p1',
          action: ProductLifecycleAction.pause,
        ),
        throwsA(isA<ProductLifecycleException>()),
      );
    });

    test('a decision goes stale if the product moves underneath it', () async {
      await govern('p1');
      final pause = await engine.requestLifecycleDecision(
        productId: 'p1',
        action: ProductLifecycleAction.pause,
      );
      // Someone offboards first; the pause was raised against `governed`.
      await resolve(
        await engine.requestLifecycleDecision(
          productId: 'p1',
          action: ProductLifecycleAction.offboard,
          decisionId: 'plc-offboard-other',
        ),
        additionalGuards: const {ProductGuard.noWorkInFlight},
      );
      expect(
        () => resolve(pause),
        throwsA(isA<StaleBaselineApprovalException>()),
      );
    });

    test('a non-lifecycle decision cannot be resolved as one', () async {
      await engine.createProduct(productId: 'p1', name: 'p1');
      final b = await engine.proposeBaseline(productId: 'p1', facts: [_fact()]);
      await engine.verifyBaseline(
        productId: 'p1',
        baselineId: b.baselineId,
        verifiedBy: 'worker-7',
      );
      final baselineReq = await engine.requestBaselineApproval(
        productId: 'p1',
        baselineId: b.baselineId,
      );
      expect(
        () => resolve(baselineReq),
        throwsA(isA<ProductLifecycleException>()),
      );
    });

    test('resolving twice is an idempotent replay, not a second action',
        () async {
      await govern('p1');
      final req = await engine.requestLifecycleDecision(
        productId: 'p1',
        action: ProductLifecycleAction.pause,
      );
      final first = await resolve(req);
      final replay = await engine.resolveLifecycleDecision(
        decisionId: req.decisionId,
        choice: HumanDecisionChoice.reject,
        decider: 'someone-else',
        rationale: 'trying to flip it',
        signature: testSignature(),
      );
      expect(replay.choice, first.choice);
      expect(replay.decider, 'operator');
      expect((await engine.readProduct('p1')).state, ProductState.paused);
    });
  });

  group('binding', () {
    test('every action maps to an edge the transition table actually has', () {
      for (final a in ProductLifecycleAction.values) {
        // A target may have several inbound edges (governed is reachable both
        // by first approval and by resume), so the action's guard must match
        // at least one of them — not merely the first one found.
        final edges = [
          for (final (f, t) in ProductTransitions.all)
            if (t == a.target) (f, ProductTransitions.requiredGuards(f, t)),
        ];
        expect(edges, isNotEmpty, reason: a.wire);
        expect(
          edges.any((e) => e.$2.contains(a.guard)),
          isTrue,
          reason: '${a.wire} guard matches no edge into ${a.target.wire}',
        );
      }
    });

    test('resume and first-approval are different edges into governed', () {
      final resumeGuards = ProductTransitions.requiredGuards(
        ProductState.paused,
        ProductState.governed,
      );
      final grantGuards = ProductTransitions.requiredGuards(
        ProductState.baselineReview,
        ProductState.governed,
      );
      expect(resumeGuards, contains(ProductGuard.resumeDecisionRecorded));
      expect(grantGuards, contains(ProductGuard.baselineApproved));
      expect(resumeGuards, isNot(contains(ProductGuard.baselineApproved)));
    });

    test('reinstate targets review, never governed directly', () {
      expect(
        ProductLifecycleAction.reinstate.target,
        ProductState.baselineReview,
      );
    });

    test('metadata round-trips and rejects foreign routing', () {
      const b = LifecycleDecisionBinding(
        productId: 'p1',
        action: ProductLifecycleAction.offboard,
        fromState: ProductState.governed,
        drainInFlight: false,
      );
      final parsed = LifecycleDecisionBinding.tryFromMetadata(b.toMetadata())!;
      expect(parsed.action, ProductLifecycleAction.offboard);
      expect(parsed.fromState, ProductState.governed);
      expect(parsed.drainInFlight, isFalse);
      expect(
        LifecycleDecisionBinding.tryFromMetadata({'routing': 'something_else'}),
        isNull,
      );
    });
  });
}
