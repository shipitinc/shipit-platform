import 'package:platform_contracts/platform_contracts.dart';

/// A re-derivation proof that **agrees** with [baseline]: the same artifact, the
/// same revision, and the same content hash, recomputed by a verifier that is
/// not the producer.
///
/// ## Why these tests need a proof at all
///
/// `ProductRegistryEngine.verifyBaseline` has two paths, and only one of them
/// reaches `platformVerifiedEvidence`:
///
///  * an identity alone records `EvidenceKind.agentClaimedEvidence` — a claim,
///    preserved as evidence of what was asserted, which is false for
///    `isIndependentlyVerified` and therefore never opens the approval gate;
///  * a `PlatformReDerivationProof` that reproduces the stored hash is a
///    platform verification.
///
/// Every integration test that walks a baseline to `baselineReview` therefore
/// needs the second path, or `requestBaselineApproval` refuses with
/// `BaselineNotVerifiedException`. That is the fail-closed behaviour working,
/// not a test defect.
///
/// ## Why the verifier identity differs from the producer
///
/// `isSelfAttested` compares the two canonically and refuses when they match.
/// The defaults below are two distinct principals on purpose; a caller that
/// needs to exercise the *refusal* builds its proof inline with one identity so
/// the deviation from this helper is visible at the call site.
///
/// The source reference is a fixture label rather than a URL. It is recorded so
/// a reader can see what "the same source" was, and the contract does not
/// independently check it — nothing here pretends these tests performed a real
/// SSH clone. The verification guarantee under test is the engine's agreement
/// and independence checks, which are exactly what this exercises.
PlatformReDerivationProof agreeingProof(
  ProductBaseline baseline, {
  String producedBy = 'integration-test-producer',
  String verifiedBy = 'integration-test-verifier',
  String sourceRef = 'integration-test-fixture-repository',
}) => PlatformReDerivationProof.fromReDerivation(
  baselineId: baseline.baselineId,
  baselineRevision: baseline.revision,
  reDerivedContentHash: baseline.contentHash,
  reDerivedContentHashVersion: baseline.contentHashVersion,
  producedBy: producedBy,
  verifiedBy: verifiedBy,
  sourceRef: sourceRef,
);
