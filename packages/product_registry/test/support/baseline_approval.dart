import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';

DecisionSignature testSignature() => DecisionSignature(
  algorithm: 'ed25519',
  publicKey: 'pk-test-human-gate',
  signature: 'sig-test-human-gate',
  signedAt: DateTime.utc(2026, 1, 1),
);

/// Drives the governed acceptance path: request approval for [baseline],
/// resolve it as an approving HumanDecision, and return the accepted baseline.
Future<ProductBaseline> approveBaseline(
  ProductRegistryEngine engine, {
  required String productId,
  required ProductBaseline baseline,
  String decider = 'human-gate',
  String rationale = 'Baseline reviewed and approved',
  String verifiedBy = 'worker-test-verifier',
  DateTime? now,
}) async {
  // A worker attests to the baseline before any human is asked to approve it
  // (AGENTS.md §12). The gate now fails closed without this.
  await engine.verifyBaseline(
    productId: productId,
    baselineId: baseline.baselineId,
    verifiedBy: verifiedBy,
    now: now,
  );
  final request = await engine.requestBaselineApproval(
    productId: productId,
    baselineId: baseline.baselineId,
    now: now,
  );
  await engine.resolveBaselineApproval(
    decisionId: request.decisionId,
    choice: HumanDecisionChoice.approve,
    decider: decider,
    rationale: rationale,
    signature: testSignature(),
    now: now,
  );
  return engine.readBaselineRevision(productId, baseline.revision);
}
