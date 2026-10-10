import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';

/// The provenance discovery produces, and the only one a repository read can
/// reproduce.
///
/// Everything else in a baseline — above all [Provenance.humanProvided] — was
/// authored by a person and is *not* obtainable from a repository. That
/// distinction is the whole basis of [comparableFacts] below.
const Provenance kHumanAuthoredProvenance = Provenance.humanProvided;

/// Builds the fact list a snapshot derives into.
///
/// PURE AND DETERMINISTIC, and that is the whole point of it being its own
/// function rather than a loop inside the lane.
///
/// AGENTS.md §12's mechanism is that a verifier recomputes the content hash and
/// the proposal is accepted only when the recomputation agrees. That only works
/// if "recompute" means "run the same function over the same snapshot" — so the
/// derivation has to be a total function of its input with no clock, no
/// randomness, and no ordering that depends on anything but the input. It is
/// here, separately, precisely so a reader can check that.
///
/// `factId` is positional (`discovery-0`, `discovery-1`, …) and therefore
/// depends only on the order [ReadOnlyRepositoryReader] returned, which is the
/// order it walked the snapshot. A fact id derived from a timestamp or a UUID
/// would make the hash non-reproducible, and every re-derivation would
/// diverge from a proposal that is perfectly correct.
List<BaselineFact> deriveBaselineFacts(
  List<DiscoveryObservation> observations, {
  MaturityClassifier classifier = const MaturityClassifier(),
}) => <BaselineFact>[
  for (var i = 0; i < observations.length; i++)
    BaselineFact(
      factId: 'discovery-$i',
      section: observations[i].section,
      claim: observations[i].claim,
      provenance: observations[i].provenance,
      maturity: classifier.classify(
        claim: observations[i].claim,
        evidencePaths: observations[i].evidencePaths,
        provenance: observations[i].provenance,
        assumptionNote: observations[i].assumptionNote,
        redacted: observations[i].redacted,
      ),
      evidenceRefs: observations[i].evidencePaths,
      assumptionNote: observations[i].assumptionNote,
      redacted: observations[i].redacted,
    ),
];

/// The subset of [facts] a repository read can reproduce.
///
/// ## This function is the correction for the defect the F-3 finding recorded
///
/// The hand-run onboarding script compared two different sets on its
/// first-visit branch:
///
/// ```text
///   recheckHash  = hash(re-derived SCRAPED facts only)   // :327
///   proposedHash = proposed.contentHash                  // which, on the merge
///                                                            path, is
///                                                            hash(SCRAPED + HUMAN)
/// ```
///
/// and it took that branch precisely when the proposal carried human-authored
/// claims — because the merge path is what clears `verifiedAt`. So "a human
/// adds a claim, then the script is re-run" always ended in a refusal whose
/// message blamed the repository. The human's own claim was reported as
/// repository drift.
///
/// The correction is not a different comparison in the other branch. It is
/// naming what is comparable once, here, and applying it to BOTH sides of the
/// one comparison. "Scrape-derivable, from a fresh read of the snapshot" and
/// "scrape-derivable, according to the proposal" are the only two things that
/// can be equal by construction.
///
/// ## What this does NOT do
///
/// It does not make a baseline containing human claims verifiable by
/// re-derivation. Hashing a subset proves the *scrape-derivable* part; the
/// human part is still unattested, and a platform verification of the whole
/// content hash remains impossible. [containsHumanAuthoredClaims] is what the
/// lane uses to notice that and stop rather than pretend.
List<BaselineFact> comparableFacts(List<BaselineFact> facts) => facts
    .where((fact) => fact.provenance != kHumanAuthoredProvenance)
    .toList(growable: false);

/// Whether [facts] carry anything a repository read could not reproduce.
bool containsHumanAuthoredClaims(List<BaselineFact> facts) =>
    facts.any((fact) => fact.provenance == kHumanAuthoredProvenance);

/// Content hash of [facts] under the V3 contract.
///
/// There is no V2 branch here. The V2 hash is documented as historically
/// defective and never usable for a new approval candidate; a call site that
/// fell back to it would produce a digest that agrees with itself and proves
/// nothing, which is the precise false negative this lane exists to remove.
String comparableContentHash(List<BaselineFact> facts) =>
    baselineContentHashV3(facts);

/// The two principals a baseline proposal and its independent re-derivation are
/// attributed to.
///
/// AGENTS.md §12 makes producer and verifier separate principals, and
/// `ProductRegistryEngine.verifyBaseline` refuses a proof whose
/// `isSelfAttested` is true. These two strings MUST be able to differ after
/// [normalizeBaselineIdentity]; the [create] constructor refuses a pair that
/// does not, so a self-attesting configuration fails where it was introduced
/// rather than as an unexplained refusal at the last step of every run.
class BaselinePrincipals {
  const BaselinePrincipals._(this.producer, this.verifier);

  /// Identity recorded as producing the proposal.
  final String producer;

  /// Identity recorded as independently re-deriving it.
  final String verifier;

  factory BaselinePrincipals({
    required String producer,
    required String verifier,
  }) {
    final canonicalProducer = normalizeBaselineIdentity(producer);
    final canonicalVerifier = normalizeBaselineIdentity(verifier);
    if (canonicalProducer.isEmpty || canonicalVerifier.isEmpty) {
      throw ArgumentError(
        'baseline independence is a claim about two principals; neither '
        'identity may be blank',
      );
    }
    if (canonicalProducer == canonicalVerifier) {
      throw ArgumentError(
        'baseline producer and verifier must be different principals; '
        '"$canonicalProducer" was supplied for both, and AGENTS.md §12 forbids '
        'an identity from attesting to its own baseline',
      );
    }
    return BaselinePrincipals._(producer, verifier);
  }

  @override
  String toString() =>
      'BaselinePrincipals(produced by $producer, verified by $verifier)';
}
