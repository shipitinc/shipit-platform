// `_classifier` and `_log` take initializers rather than `this._classifier`
// formals only because their defaults are named constants; the formals would
// have to repeat them.
// ignore_for_file: prefer_initializing_formals

import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';

import '../credentials/repository_snapshot_acquirer.dart';
import 'baseline_derivation.dart';

/// What one run of the baseline lane did.
///
/// Every terminal state is NAMED here and none of them is inferred by the
/// caller from an absence. A lane that quietly did nothing is the exact failure
/// class this work item was opened for — `JobType.onboardProduct` sat `queued`
/// for ever because nothing reported that it had never run — so "nothing
/// happened" is not one of the options this type can express.
sealed class BaselineLaneOutcome {
  const BaselineLaneOutcome();
}

/// A baseline was proposed, independently re-derived, and a human was asked to
/// approve it. The terminal state of this lane, and the only one that opens a
/// gate.
final class BaselineLaneAwaitingApproval extends BaselineLaneOutcome {
  const BaselineLaneAwaitingApproval({
    required this.productId,
    required this.baselineId,
    required this.revision,
    required this.sourceRevision,
    required this.decisionId,
    required this.factCount,
    required this.alreadyVerified,
  });

  final String productId;
  final String baselineId;
  final int revision;

  /// The pinned revision both the proposal and the re-derivation read.
  final String sourceRevision;

  final String decisionId;
  final int factCount;

  /// True when the baseline was already verified and this run only re-checked
  /// that the source still reproduces its scrape-derivable content. Recorded
  /// rather than inferred, because "re-verified" and "verified for the first
  /// time" produce the same durable state and an operator reading the job record
  /// is owed the difference.
  final bool alreadyVerified;

  @override
  String toString() =>
      'awaiting human approval of $baselineId@r$revision (product $productId, '
      '$factCount facts from $sourceRevision, decision $decisionId'
      '${alreadyVerified ? ', re-checked an existing verification' : ''})';
}

/// The lane refused to act, and says why on the job record.
///
/// Refusal is a legitimate terminal state here and is never an error: a product
/// blocked on a clarification is *waiting for a human*, not failing.
final class BaselineLaneSkipped extends BaselineLaneOutcome {
  const BaselineLaneSkipped({
    required this.productId,
    required this.reason,
    required this.code,
  });

  final String productId;

  /// Operator-facing. Carries no credential material and no fingerprint.
  final String reason;

  /// Stable, greppable, comparable in a test.
  final String code;

  /// The lane deliberately skips a product blocked on a clarification, while the
  /// sweep deliberately still enqueues for it.
  ///
  /// That split is the point and it is easy to undo by accident. A product
  /// blocked on a clarification still has **no baseline**, so excluding it from
  /// the sweep would hide the gap permanently — there would be nothing on the
  /// record saying a baseline was never produced. Including it means the job
  /// exists, the lane examines it, and the refusal lands on the job where an
  /// operator can see it.
  static const String blockedCode = 'BASELINE_BLOCKED_ON_CLARIFICATION';

  /// The product is archived; nothing may be dispatched for it.
  static const String archivedCode = 'PRODUCT_ARCHIVED';

  /// The product has no repository reference to acquire.
  static const String noRepositoryCode = 'NO_REPOSITORY_REFERENCE';

  /// An empty snapshot-derived fact list. Never proposed: `proposeBaseline`
  /// refuses it, and a baseline with no facts would sail through the human gate
  /// while asserting nothing.
  static const String emptyDerivationCode = 'EMPTY_DERIVATION';

  /// The scrape-derivable content the proposal holds is not what a fresh read of
  /// the pinned source produces. The proposal is NOT touched; this is what a
  /// fabricating or drifting producer looks like from the outside.
  static const String divergentCode = 'RE_DERIVATION_DIVERGED';

  /// The proposal carries human-authored claims, and the frozen contract
  /// verifies whole-content equality only. See the lane's own note.
  static const String humanAuthoredClaimsCode =
      'HUMAN_CLAIMS_NOT_MACHINE_VERIFIABLE';

  @override
  String toString() => 'skipped $productId ($code): $reason';
}

/// Produces a baseline for one product and asks a human to approve it.
///
/// ## Where it stops, and why that is not negotiable
///
/// The lane's terminal state is `BaselineLaneAwaitingApproval`: a PENDING
/// `HumanDecision`. It never resolves one, and no code path in this class can
/// produce a resolved decision with a non-human actor. AGENTS.md §12 makes the
/// human approval gate the final authority for what "governed" means, and an
/// automation that approved its own baseline would forge exactly the authority
/// that makes a governed product worth anything.
///
/// `decisionActorIsHuman` is never supplied by this lane, so `governed` is
/// unreachable from here even if every other guard were satisfied.
///
/// ## What the re-derivation in here does and does not establish
///
/// It establishes that the STORED facts still correspond to a fresh read of the
/// pinned source, and a producer that fabricates is caught by divergence rather
/// than by policy — there is no policy for it to violate, because the hash it
/// must match is computed from the source instead of asserted.
///
/// It is **not** an independent second opinion. Both acquisitions happen in
/// this process, over the same credential, against the same host. §12 states
/// that residual hole and it is stated again here, at the point the code would
/// otherwise be read as closing it: a single compromised process controlling
/// both acquisitions defeats this check, re-derivation does not narrow that, and
/// the human approval gate remains the final authority for that reason.
class BaselineProductionLane {
  BaselineProductionLane({
    required this.engine,
    required this.acquirer,
    required this.principals,
    required this.baselineStore,
    MaturityClassifier classifier = const MaturityClassifier(),
    void Function(String event, Map<String, dynamic> data)? log,
  }) : _classifier = classifier,
       _log = log;

  final ProductRegistryEngine engine;
  final RepositorySnapshotAcquirer acquirer;
  final BaselinePrincipals principals;

  /// Used **only** by the merge path.
  ///
  /// `ProductRegistryEngine` exposes propose/verify/amend but no
  /// compare-and-swap write for an existing baseline, and
  /// `packages/product_registry` is frozen for this work item. The merge path
  /// needs one: merging human-authored claims rewrites an existing proposal's
  /// facts, and writing it without a CAS against the version that was read would
  /// let two concurrent runs both merge and silently drop one of the two sets of
  /// human claims. Taking the store here is the honest alternative to writing
  /// through the engine — which is unavailable — or writing without one — which
  /// is a data-loss bug. Recorded as a finding: the engine should expose
  /// `amendBaseline(productId, baselineId, facts, expectedVersion)`.
  final ProductRegistryStore baselineStore;

  final MaturityClassifier _classifier;
  final void Function(String event, Map<String, dynamic> data)? _log;

  /// Runs the lane for [productId] against [repositoryId] at [pinnedRevision].
  ///
  /// Restart-safe: every step is either a fresh derivation from the pinned
  /// source or a compare-and-swap against the version it read, so a crash
  /// between any two steps leaves the durable record at a state this method can
  /// pick up from. Nothing here resumes partial work, because nothing here
  /// leaves partial work behind.
  Future<BaselineLaneOutcome> run({
    required String productId,
    required String repositoryId,
    required String pinnedRevision,
  }) async {
    // ---- 0. Refusals that cost nothing, recorded rather than thrown. ----
    final product = await engine.readProduct(productId);
    final state = product.state.canonical;
    if (state == ProductState.baselineBlocked) {
      return BaselineLaneSkipped(
        productId: productId,
        code: BaselineLaneSkipped.blockedCode,
        reason:
            'the product is blocked on an open clarification. It still has no '
            'baseline, which is why the sweep enqueued it; producing one now '
            'would decide the very question the clarification was opened to '
            'ask.',
      );
    }
    if (state == ProductState.archived) {
      return BaselineLaneSkipped(
        productId: productId,
        code: BaselineLaneSkipped.archivedCode,
        reason:
            'the product is archived. An archived product is never moved, and '
            'reinstating it opens a fresh baseline gate.',
      );
    }
    if ((await engine.readRepositories(productId)).isEmpty) {
      return BaselineLaneSkipped(
        productId: productId,
        code: BaselineLaneSkipped.noRepositoryCode,
        reason:
            'the product has no repository reference, so there is no source to '
            'derive from.',
      );
    }

    // ---- 1. Acquire. A refusal here is an external dependency, not a fault. ----
    final snapshot = await acquirer.acquire(
      productId: productId,
      repositoryId: repositoryId,
      pinnedRevision: pinnedRevision,
    );
    try {
      return await _runAgainstSnapshot(
        productId: productId,
        snapshot: snapshot,
      );
    } finally {
      // Unconditional, on success and on failure alike, and idempotent — a
      // crash between the derivation and the release must not turn the next
      // attempt into a second attempt at deleting a tree that is already gone.
      snapshot.release();
    }
  }

  Future<BaselineLaneOutcome> _runAgainstSnapshot({
    required String productId,
    required RepositorySnapshot snapshot,
  }) async {
    // ---- 2. Derive. Read-only; the reader never writes to the snapshot. ----
    final observations = await ReadOnlyRepositoryReader(
      snapshotRoot: snapshot.root,
    ).inspect();
    if (observations.isEmpty) {
      return BaselineLaneSkipped(
        productId: productId,
        code: BaselineLaneSkipped.emptyDerivationCode,
        reason:
            'discovery produced no observations from the pinned snapshot; a '
            'baseline with no facts would attest to nothing while remaining '
            'verifiable.',
      );
    }
    final derived = deriveBaselineFacts(observations, classifier: _classifier);
    _log?.call('baseline.lane.derived', {
      'productId': productId,
      'repositoryId': snapshot.repositoryId,
      'revision': snapshot.revision,
      'observationCount': observations.length,
      'factCount': derived.length,
    });

    // ---- 3. Propose, reusing rather than superseding. ----
    final proposed = await _proposeOrReuse(
      productId: productId,
      derived: derived,
    );

    // ---- 4. Re-derive, independently, and compare like with like. ----
    final reDerived = deriveBaselineFacts(
      await ReadOnlyRepositoryReader(snapshotRoot: snapshot.root).inspect(),
      classifier: _classifier,
    );
    final proposalComparable = comparableFacts(proposed.facts);
    final reDerivedComparable = comparableFacts(reDerived);
    final proposalHash = comparableContentHash(proposalComparable);
    final reDerivedHash = comparableContentHash(reDerivedComparable);

    if (proposalHash != reDerivedHash) {
      // Nothing is written. A refused verification must not leave a passing
      // attestation behind, and the proposal is not touched either: the
      // divergence is reported, not repaired.
      _log?.call('baseline.lane.diverged', {
        'productId': productId,
        'baselineId': proposed.baselineId,
        'revision': proposed.revision,
        'proposalComparableHash': proposalHash,
        'reDerivedComparableHash': reDerivedHash,
        'action': 'no verification written; the proposal is unchanged',
      });
      return BaselineLaneSkipped(
        productId: productId,
        code: BaselineLaneSkipped.divergentCode,
        reason:
            'a fresh read of ${snapshot.repositoryId} at '
            '${snapshot.revision} does not reproduce the scrape-derivable '
            'content of ${proposed.baselineId}@r${proposed.revision}. The '
            'stored baseline does not match the repository, so it must not go '
            'to human review.',
      );
    }

    if (containsHumanAuthoredClaims(proposed.facts)) {
      return _humanClaimsOutcome(productId, proposed, snapshot);
    }

    // With no human-authored claims the comparable subset IS the whole
    // baseline, so `proposalHash` and `proposed.contentHash` are the same value
    // — and asserting that here rather than assuming it is what stops a future
    // change to `comparableFacts` from quietly producing a proof that no longer
    // matches the artifact it claims to describe.
    if (proposalHash != proposed.contentHash) {
      return BaselineLaneSkipped(
        productId: productId,
        code: BaselineLaneSkipped.divergentCode,
        reason:
            'the re-derived hash covers the whole baseline but does not equal '
            'the persisted content hash, so the two artifacts disagree and no '
            'proof can honestly describe them.',
      );
    }

    if (proposed.verifiedAt != null) {
      // Already verified by an earlier run. The comparable subset has just been
      // re-derived and matched, so the source still says what the attestation
      // said it said. Nothing to re-attest: re-verifying would bump the version
      // and rewrite `verifiedAt` on every sweep for no change in meaning.
      return _awaitApproval(
        productId: productId,
        proposed: proposed,
        snapshot: snapshot,
        alreadyVerified: true,
      );
    }

    // The proof is built from the hash THIS RUN JUST RECOMPUTED, not from the
    // hash it read off the stored baseline. That distinction is the whole
    // mechanism: `PlatformReDerivationProof` cannot be constructed without a
    // recomputed content hash, so passing the stored hash back would be
    // indistinguishable from a caller asserting its own claim.
    final proof = PlatformReDerivationProof.fromReDerivation(
      baselineId: proposed.baselineId,
      baselineRevision: proposed.revision,
      reDerivedContentHash: reDerivedHash,
      reDerivedContentHashVersion: proposed.contentHashVersion,
      producedBy: principals.producer,
      verifiedBy: principals.verifier,
      sourceRef: snapshot.sourceRef,
    );
    final verified = await engine.verifyBaseline(
      productId: productId,
      baselineId: proposed.baselineId,
      reDerivation: proof,
    );
    if (!verified.isIndependentlyVerified) {
      // Fails loudly rather than leaving a claim on the record and walking on
      // to the approval request, which would then be refused by the engine for
      // a reason the operator has to diagnose from a stack trace.
      throw StateError(
        'baseline ${verified.baselineId} recorded a verification of '
        '${verified.verificationKind?.wire}, which does not open the human '
        'approval gate. Refusing to request approval.',
      );
    }
    _log?.call('baseline.lane.verified', {
      'productId': productId,
      'baselineId': verified.baselineId,
      'revision': verified.revision,
      'verificationKind': verified.verificationKind?.wire,
      'sourceRevision': snapshot.revision,
    });

    return _awaitApproval(
      productId: productId,
      proposed: verified,
      snapshot: snapshot,
      alreadyVerified: false,
    );
  }

  /// Proposes the next revision, or reuses an existing baseline whose content
  /// already says exactly this.
  ///
  /// ## The two rules here, both preserved deliberately
  ///
  /// **Reuse, do not supersede.** Re-running must not spam revisions, so if the
  /// newest baseline already asserts this content it is reused rather than
  /// replaced by an identical copy. Revision numbers are the human's index into
  /// what changed; a run that increments one without changing anything teaches
  /// the reviewer to distrust them.
  ///
  /// **Merge, do not restart.** A proposed baseline carrying
  /// [Provenance.humanProvided] claims holds knowledge no scanner can re-derive
  /// — what a product is *for* is not in its source tree. Starting from scratch
  /// would delete it, so fresh discovery is merged with the human claims and
  /// both survive into the new revision.
  ///
  /// The merge clears `verifiedAt`, because the artefact the attestation
  /// described is no longer the artefact on the record. That clearing is what
  /// makes [comparableFacts] load-bearing rather than cosmetic.
  Future<ProductBaseline> _proposeOrReuse({
    required String productId,
    required List<BaselineFact> derived,
  }) async {
    final candidateHash = comparableContentHash(derived);
    final context = await engine.loadProductContext(productId);

    // An existing revision already asserting exactly this content, whatever its
    // status.
    final existingByHash = context.allBaselines
        .where((b) => b.contentHash == candidateHash)
        .toList();

    final proposed =
        context.allBaselines
            .where((b) => b.status == ProductBaselineStatus.proposed)
            .toList()
          ..sort((a, b) => b.revision.compareTo(a.revision));

    if (proposed.isNotEmpty) {
      // Prefer the candidate a human most recently amended: it is the one
      // carrying their claims, and merging into a different proposal would
      // strand them on a revision nobody is looking at.
      final withHumanClaims =
          proposed.where((b) => containsHumanAuthoredClaims(b.facts)).toList()
            ..sort(
              (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(
                    a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                  ),
            );
      final current = withHumanClaims.isNotEmpty
          ? withHumanClaims.first
          : proposed.first;

      final humanFacts = current.facts
          .where((f) => f.provenance == kHumanAuthoredProvenance)
          .toList();
      final scrapedFacts = current.facts
          .where((f) => f.provenance != kHumanAuthoredProvenance)
          .toList();

      if (humanFacts.isNotEmpty &&
          comparableContentHash(scrapedFacts) == candidateHash) {
        // Discovery matches the scraped portion; preserve the human claims by
        // merging them with it.
        final merged = <BaselineFact>[...scrapedFacts, ...humanFacts];
        // Constructed rather than `copyWith`, and that difference is load
        // bearing.
        //
        // `ProductBaseline.copyWith` reads `verifiedAt ?? this.verifiedAt`, so
        // passing `null` KEEPS the existing value: it cannot express "no
        // verification" at all. Every amendment path in `packages/product_registry`
        // is written as though it could — `addHumanBaselineClaim` says in its own
        // doc comment that the attestation "is dropped", and it is not — so a
        // baseline amended after verification keeps reporting
        // `isIndependentlyVerified == true` for content no re-derivation has
        // seen. `baseline_production_lane_test.dart` characterises that defect.
        //
        // This write is the one place the lane CAN say "no verification", and it
        // says it here. Repairing the frozen package's own amendment path is
        // not this lane's to do and is reported as a finding.
        final updated = ProductBaseline(
          baselineId: current.baselineId,
          productId: current.productId,
          revision: current.revision,
          status: current.status,
          facts: merged,
          contentHash: comparableContentHash(merged),
          supersedesBaselineId: current.supersedesBaselineId,
          proposedAt: current.proposedAt,
          reviewedAt: current.reviewedAt,
          acceptedAt: current.acceptedAt,
          acceptedBy: current.acceptedBy,
          acceptedDecisionId: current.acceptedDecisionId,
          createdAt: current.createdAt,
          updatedAt: DateTime.now().toUtc(),
          version: current.version + 1,
          contentHashVersion: current.contentHashVersion,
        );
        // Compare-and-swap against the version read above: two runs racing here
        // must not both merge, and the loser fails loudly instead of clobbering
        // the winner's human claims.
        await baselineStore.saveBaseline(
          updated,
          expectedVersion: current.version,
        );
        _log?.call('baseline.lane.merged_human_claims', {
          'productId': productId,
          'baselineId': updated.baselineId,
          'revision': updated.revision,
          'humanClaimCount': humanFacts.length,
          'verificationCleared': true,
        });
        return updated;
      }

      // A human claim exists and discovery has moved on since it was written.
      // The claims are CARRIED INTO THE NEW REVISION rather than dropped.
      //
      // This is a deliberate divergence from the hand-run script, whose `else`
      // branch proposed `facts` alone and therefore published a revision that
      // silently forgot what the operator had said. The rule the script was
      // carrying is "preserve human-authored claims by merging rather than
      // starting from scratch"; the `else` branch broke that rule in exactly the
      // case where it would hurt most, and a revision that forgets an operator's
      // claim is a baseline that asserts less than the one before it while
      // looking like progress.
      //
      // Whether a claim is still true after discovery moved is not the lane's
      // call. It is the human's, at the approval gate this revision opens.
      if (humanFacts.isNotEmpty) {
        final carried = await engine.proposeBaseline(
          productId: productId,
          facts: <BaselineFact>[...derived, ...humanFacts],
        );
        _log?.call('baseline.lane.carried_human_claims_forward', {
          'productId': productId,
          'baselineId': carried.baselineId,
          'revision': carried.revision,
          'humanClaimCount': humanFacts.length,
        });
        return carried;
      }

      if (candidateHash == current.contentHash) {
        return current;
      }
      return engine.proposeBaseline(productId: productId, facts: derived);
    }

    if (existingByHash.isNotEmpty) {
      existingByHash.sort((a, b) => b.revision.compareTo(a.revision));
      return existingByHash.first;
    }

    return engine.proposeBaseline(productId: productId, facts: derived);
  }

  /// What the lane does when a proposal carries human-authored claims.
  ///
  /// ## A gap in the frozen contract, stated rather than worked around
  ///
  /// `PlatformReDerivationProof.matchesBaseline` compares the re-derived hash
  /// against the baseline's **whole** `contentHash`. A baseline with a
  /// human-authored claim has a whole content hash that includes a fact no
  /// repository read can reproduce, so a re-derivation of that baseline is
  /// impossible by construction — not because anything is wrong, but because
  /// the thing being verified was never derivable.
  ///
  /// The design anticipated this: it specified a `comparableSubsetHash` field
  /// and a proof carrying `comparableSubsetHash` and
  /// `comparableFactCount`, precisely so "what is comparable" would be an
  /// explicit shared contract. Those names are not in the shipped contract,
  /// which instead verifies whole-content equality. This lane therefore cannot
  /// mint platform evidence for a human-amended baseline, and the honest thing
  /// is to say so on the job record rather than either (a) re-attesting the
  /// scrape-derivable subset as though it covered the whole, or (b) leaving the
  /// operator to discover the wedge by trying to approve.
  ///
  /// Nothing is written to the baseline here: an `agentClaimedEvidence` claim
  /// would record that an agent looked at it and could not verify it, which is
  /// not evidence of anything and would only make the row harder to read.
  BaselineLaneSkipped _humanClaimsOutcome(
    String productId,
    ProductBaseline proposed,
    RepositorySnapshot snapshot,
  ) {
    final humanClaims = proposed.facts
        .where((f) => f.provenance == kHumanAuthoredProvenance)
        .length;
    _log?.call('baseline.lane.human_claims_not_verifiable', {
      'productId': productId,
      'baselineId': proposed.baselineId,
      'revision': proposed.revision,
      'humanClaimCount': humanClaims,
      'action': 'no verification written; the human gate is unchanged',
    });
    return BaselineLaneSkipped(
      productId: productId,
      code: BaselineLaneSkipped.humanAuthoredClaimsCode,
      reason:
          'the proposal carries $humanClaims human-authored claim(s), and a '
          'repository read cannot reproduce their content. The scrape-derivable '
          'portion of ${proposed.baselineId}@r${proposed.revision} DOES still '
          'match a fresh read of ${snapshot.repositoryId} at '
          '${snapshot.revision}; what is unverifiable is the human part, which '
          'is a human to verify. No platform evidence was minted and no approval '
          'was requested.',
    );
  }

  /// Opens the human gate, and stops there.
  Future<BaselineLaneOutcome> _awaitApproval({
    required String productId,
    required ProductBaseline proposed,
    required RepositorySnapshot snapshot,
    required bool alreadyVerified,
  }) async {
    // `requestBaselineApproval` CREATES a pending decision. This lane has no
    // code path that resolves one, and adding one would forge the authority
    // that makes a governed product meaningful.
    final decision = await engine.requestBaselineApproval(
      productId: productId,
      baselineId: proposed.baselineId,
    );
    _log?.call('baseline.lane.awaiting_approval', {
      'productId': productId,
      'baselineId': proposed.baselineId,
      'revision': proposed.revision,
      'sourceRevision': snapshot.revision,
      'decisionId': decision.decisionId,
      'decisionStatus': decision.status.wire,
      'alreadyVerified': alreadyVerified,
    });
    return BaselineLaneAwaitingApproval(
      productId: productId,
      baselineId: proposed.baselineId,
      revision: proposed.revision,
      sourceRevision: snapshot.revision,
      decisionId: decision.decisionId,
      factCount: proposed.facts.length,
      alreadyVerified: alreadyVerified,
    );
  }
}
