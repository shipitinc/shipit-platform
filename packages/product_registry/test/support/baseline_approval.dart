import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';

DecisionSignature testSignature() => DecisionSignature(
  algorithm: 'ed25519',
  publicKey: 'pk-test-human-gate',
  signature: 'sig-test-human-gate',
  signedAt: DateTime.utc(2026, 1, 1),
);

/// A re-derivation proof that **agrees** with [baseline]: same artifact, same
/// revision, and the same content hash, recomputed by a verifier that is not
/// the producer.
///
/// This is what an honest verifier produces after acquiring the same source and
/// recomputing the hash. Tests that need a *fabricating* producer or a
/// *self*-verifying one build the proof inline instead, so the deviation from
/// this helper is visible at the call site.
PlatformReDerivationProof agreeingProof(
  ProductBaseline baseline, {
  String producedBy = 'worker-test-producer',
  String verifiedBy = 'worker-test-verifier',
  String sourceRef = 'test-fixture-repository',
}) => PlatformReDerivationProof.fromReDerivation(
  baselineId: baseline.baselineId,
  baselineRevision: baseline.revision,
  reDerivedContentHash: baseline.contentHash,
  reDerivedContentHashVersion: baseline.contentHashVersion,
  producedBy: producedBy,
  verifiedBy: verifiedBy,
  sourceRef: sourceRef,
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
  // A worker independently re-derives the baseline before any human is asked to
  // approve it (AGENTS.md §12). The gate fails closed on anything weaker: an
  // identity with no re-derivation proof is recorded as a claim and does not
  // unlock it.
  await engine.verifyBaseline(
    productId: productId,
    baselineId: baseline.baselineId,
    reDerivation: agreeingProof(baseline, verifiedBy: verifiedBy),
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
