import 'package:platform_contracts/platform_contracts.dart';
import 'package:workflow_engine/workflow_engine.dart';

import 'lifecycle_decision_binding.dart';

import '../store/product_registry_store.dart';
import '../store/human_decision_store.dart';
import '../exceptions.dart';
import 'baseline_content_hash_v3.dart';
import 'baseline_approval_binding.dart';

/// Durable S-1 engine: Product creation, repository attribution, baseline
/// proposal/acceptance, durable clarification, and bounded ProductContext
/// loading.
///
/// Rules enforced here (checkpoint 006):
/// - No "currentProduct" global; every op is explicitly scoped by [productId].
/// - Repository/baseline/clarification reads reject cross-Product access.
/// - Accepted baseline revisions are immutable; new material change = a NEW
///   revision, never silent mutation of v1.
/// - Onboarding can durably stop on a material unknown; a restarted execution
///   resumes the same Product/onboarding/baseline lineage via the store.
/// - Product lifecycle stays on the existing `ProductState` enum
///   (draft → active | archived | deprecated).
class ProductRegistryEngine {
  ProductRegistryEngine({
    required ProductRegistryStore store,
    required HumanDecisionStore humanDecisionStore,
  }) : _store = store,
       _decisions = humanDecisionStore;

  final ProductRegistryStore _store;

  /// Port to the authoritative durable HumanDecision record. Baseline
  /// acceptance is authorized by a resolved decision here, never by an
  /// unauthenticated field update.
  final HumanDecisionStore _decisions;

  // ---------------------------------------------------------------------
  // Product
  // ---------------------------------------------------------------------

  Future<Product> createProduct({
    required String productId,
    required String name,
    String? description,
    DateTime? now,
  }) async {
    final t = now ?? DateTime.now().toUtc();
    final product = Product(
      productId: productId,
      name: name,
      description: description,
      state: ProductState.registered,
      createdAt: t,
      updatedAt: t,
      version: 1,
    );
    await _store.saveProduct(product);
    return product;
  }

  Future<Product> readProduct(String productId) =>
      _store.readProduct(productId);

  Future<List<Product>> readAllProducts() => _store.readAllProducts();

  /// Moves [productId] to [to], refusing anything `ProductTransitions` does
  /// not allow.
  ///
  /// [satisfiedGuards] are the conditions the caller has actually established.
  /// Every guard the edge requires must be present, so a caller cannot reach
  /// `governed` without having proved a human approved a verified baseline.
  Future<Product> transitionProduct(
    String productId, {
    required ProductState to,
    Set<ProductGuard> satisfiedGuards = const {},
    DateTime? now,
  }) async {
    final product = await _store.readProduct(productId);
    final from = product.state;

    if (from.canonical == to) return product;

    final rejection = ProductTransitions.explainRejection(from, to);
    if (rejection != null) {
      throw ProductLifecycleException('cannot transition $productId: $rejection');
    }

    final required = ProductTransitions.requiredGuards(from, to);
    final missing = required.where((g) => !satisfiedGuards.contains(g)).toList();
    if (missing.isNotEmpty) {
      throw ProductLifecycleException(
        'cannot transition $productId from ${from.wire} to ${to.wire}: '
        'unsatisfied ${missing.map((g) => g.wire).join(", ")}',
      );
    }

    final updated = product.copyWith(
      state: to,
      updatedAt: now ?? DateTime.now().toUtc(),
      version: product.version + 1,
    );
    await _store.saveProduct(updated, expectedVersion: product.version);
    return updated;
  }

  /// Marking a product governed without an approved, independently verified
  /// baseline was a governance bypass: it let `draft -> active` happen with no
  /// baseline at all. Governance is now only reachable through
  /// [ProductState.baselineReview].
  @Deprecated(
    'Governance is granted by approving a baseline, not by activating a '
    'product. Use transitionProduct or resolveBaselineApproval.',
  )
  Future<Product> activateProduct(String productId, {DateTime? now}) async {
    throw ProductLifecycleException(
      'activateProduct is removed: a product becomes governed only by '
      'approving an independently verified baseline (ADR 0013, checkpoint '
      '006). Route $productId through baselineReview instead.',
    );
  }

  Future<Product> updateProduct(
    String productId, {
    String? description,
    String? manifestVersion,
    DateTime? now,
  }) async {
    final product = await _store.readProduct(productId);
    final updated = product.copyWith(
      description: description,
      manifestVersion: manifestVersion,
      updatedAt: now ?? DateTime.now().toUtc(),
      version: product.version + 1,
    );
    await _store.saveProduct(updated, expectedVersion: product.version);
    return updated;
  }

  // ---------------------------------------------------------------------
  // Repository attribution
  // ---------------------------------------------------------------------

  /// Attributes a repository to exactly one Product (checkpoint 006 §8).
  Future<RepositoryReference> addRepositoryReference({
    required String repositoryId,
    required String productId,
    required String uri,
    RepositoryKind kind = RepositoryKind.monorepo,
    RepositoryProvider provider = RepositoryProvider.local,
    DateTime? now,
  }) async {
    await _store.readProduct(productId); // existence + scope
    final reference = RepositoryReference(
      repositoryId: repositoryId,
      productId: productId,
      kind: kind,
      uri: uri,
      provider: provider,
      addedAt: now ?? DateTime.now().toUtc(),
      version: 1,
    );
    await _store.saveRepositoryReference(reference);
    return reference;
  }

  Future<List<RepositoryReference>> readRepositories(String productId) =>
      _store.readRepositoriesForProduct(productId);

  /// Durable repository identity — never derived from worktree/path/process.
  Future<RepositoryReference> resolveRepository(
    String productId,
    String repositoryId,
  ) async {
    final ref = await _store.readRepositoryReference(repositoryId);
    _ensureOwned(productId, ref.productId, 'repository $repositoryId');
    return ref;
  }

  // ---------------------------------------------------------------------
  // Baseline lifecycle
  // ---------------------------------------------------------------------


  // ---------------------------------------------------------------------
  // Product lifecycle (ProductTransitions is the single source of policy)
  // ---------------------------------------------------------------------

  /// Moves a product toward [ProductState.baselinePending], tolerating
  /// products that are already there or further along (re-baselining a
  /// governed product must not knock it out of governance).
  Future<void> _enterBaselinePending(String productId, {DateTime? now}) async {
    final product = await _store.readProduct(productId);
    final from = product.state.canonical;
    // Governed/paused: re-baselining must not knock a product out of
    // governance — the accepted baseline stays active until the new one is
    // decided.
    //
    // baselineReview: superseding the candidate under review is a machine
    // action, not a human one. The product is still awaiting a human decision;
    // only *which* revision they are being asked about has changed. Moving it
    // back to pending here would require a "request changes" decision that
    // nobody made.
    if (from == ProductState.governed ||
        from == ProductState.paused ||
        from == ProductState.baselineReview) {
      return;
    }
    if (!ProductTransitions.isLegalTransition(
      from,
      ProductState.baselinePending,
    )) {
      return;
    }
    await transitionProduct(
      productId,
      to: ProductState.baselinePending,
      now: now,
    );
  }

  /// Moves a product into the durable approval gate. Fails closed when the
  /// baseline has not been independently verified (AGENTS.md §12).
  Future<void> _enterBaselineReview(
    String productId,
    ProductBaseline baseline, {
    DateTime? now,
  }) async {
    if (baseline.status != ProductBaselineStatus.proposed) {
      throw ProductLifecycleException(
        'baseline ${baseline.baselineId} is ${baseline.status.wire}, '
        'not proposed',
      );
    }
    if (!baseline.isIndependentlyVerified) {
      throw BaselineNotVerifiedException(baseline.baselineId);
    }
    await transitionProduct(
      productId,
      to: ProductState.baselineReview,
      satisfiedGuards: const {
        ProductGuard.baselineProposed,
        ProductGuard.baselineVerifiedIndependently,
      },
      now: now,
    );
  }

  /// Records that [baselineId] was verified by a worker.
  ///
  /// AGENTS.md §12: an agent may *produce* a baseline but may never attest to
  /// it. Only [EvidenceKind.platformVerifiedEvidence] satisfies
  /// [ProductGuard.baselineVerifiedIndependently]; an agent's own claim is
  /// recorded but does not unlock the approval gate.
  Future<ProductBaseline> verifyBaseline({
    required String productId,
    required String baselineId,
    required String verifiedBy,
    EvidenceKind kind = EvidenceKind.platformVerifiedEvidence,
    DateTime? now,
  }) async {
    final baseline = await _store.readBaseline(baselineId);
    _ensureOwned(productId, baseline.productId, 'baseline $baselineId');
    if (verifiedBy.isEmpty) {
      throw BaselineApprovalRequiredException(
        'verifyBaseline requires a non-empty verifier identity',
      );
    }
    final t = now ?? DateTime.now().toUtc();
    final updated = baseline.copyWith(
      verifiedAt: t,
      verifiedBy: verifiedBy,
      verificationKind: kind,
      updatedAt: t,
      version: baseline.version + 1,
    );
    await _store.saveBaseline(updated, expectedVersion: baseline.version);
    return updated;
  }

  /// Proposes the next baseline revision for [productId]. To enforce
  /// "[accepted] revisions are immutable", the new revision supersedes the
  /// previous revision and is written as a NEW row. Human acceptance binds to
  /// the exact revision + contentHash.
  Future<ProductBaseline> proposeBaseline({
    required String productId,
    required List<BaselineFact> facts,
    String? baselineIdOverride,
    DateTime? now,
  }) async {
    await _store.readProduct(productId);
    final revision = await _store.nextBaselineRevision(productId);
    final accepted = await _store.readBaselineByRevision(
      productId,
      revision - 1,
    );
    final supersedes = accepted?.baselineId;
    final t = now ?? DateTime.now().toUtc();
    final baseline = ProductBaseline(
      baselineId: baselineIdOverride ?? 'bl-${productId}-$revision',
      productId: productId,
      revision: revision,
      status: ProductBaselineStatus.proposed,
      facts: facts,
      contentHash: baselineContentHashV3(facts),
      contentHashVersion: 3,
      supersedesBaselineId: supersedes,
      proposedAt: t,
      createdAt: t,
      updatedAt: t,
      version: 1,
    );
    await _store.saveBaseline(baseline);
    await _touchOnboarding(
      productId,
      currentBaselineRevision: revision,
      now: t,
    );
    await _enterBaselinePending(productId, now: t);
    return baseline;
  }

  /// Human baseline gate. Acceptance requires a **resolved, approving
  /// [HumanDecision]** ([approvalDecisionId]) whose binding matches this exact
  /// baseline id, revision, and contentHash.
  ///
  /// An unauthenticated `(productId, baselineId, acceptedBy)` update is no
  /// longer sufficient public authority: `acceptedBy` is derived from the
  /// decision's `decider`, and the decision reference is persisted as evidence.
  /// Fails closed on a stale/superseded candidate or a cross-Product decision.
  Future<ProductBaseline> acceptBaseline({
    required String productId,
    required String baselineId,
    required String approvalDecisionId,
    DateTime? now,
  }) async {
    final baseline = await _store.readBaseline(baselineId);
    _ensureOwned(productId, baseline.productId, 'baseline $baselineId');

    final decision = await _decisions.readHumanDecision(approvalDecisionId);
    if (decision == null) {
      throw BaselineApprovalNotFoundException(approvalDecisionId);
    }
    final binding = BaselineApprovalBinding.tryFromMetadata(decision.metadata);
    if (binding == null) {
      throw BaselineApprovalRequiredException(
        'decision $approvalDecisionId is not a Product baseline approval',
      );
    }

    // Cross-Product authority: knowing decisionId + baselineId + productId does
    // not bypass the ownership graph.
    if (binding.productId != productId) {
      throw CrossProductAccessException(
        'decision $approvalDecisionId authorizes product ${binding.productId}, '
        'not $productId',
      );
    }
    if (!decision.status.isResolved) {
      throw BaselineApprovalRequiredException(
        'decision $approvalDecisionId is not resolved',
      );
    }
    if (decision.choice != HumanDecisionChoice.approve) {
      throw BaselineApprovalRejectedException(
        approvalDecisionId,
        decision.choice?.wire ?? 'none',
      );
    }
    if (decision.decider == null || decision.decider!.isEmpty) {
      throw BaselineApprovalRequiredException(
        'decision $approvalDecisionId has no decider',
      );
    }
    if (decision.signature == null) {
      throw BaselineApprovalRequiredException(
        'decision $approvalDecisionId has no signature evidence',
      );
    }
    if (decision.timestamp == null) {
      throw BaselineApprovalRequiredException(
        'decision $approvalDecisionId has no resolution timestamp',
      );
    }

    // Exact candidate binding (TOCTOU / stale-approval protection).
    if (!binding.matches(
      productId: baseline.productId,
      baselineId: baseline.baselineId,
      baselineRevision: baseline.revision,
      contentHash: baseline.contentHash,
      contentHashVersion: baseline.contentHashVersion,
    )) {
      throw StaleBaselineApprovalException(
        'decision $approvalDecisionId binds '
        '${binding.baselineId}@r${binding.baselineRevision} '
        'v${binding.contentHashVersion} '
        '${binding.contentHash}, but $baselineId is '
        '@r${baseline.revision} v${baseline.contentHashVersion} '
        '${baseline.contentHash}',
      );
    }

    // Idempotent replay: the exact revision was already accepted by this same
    // decision. Any other decision re-accepting it is refused.
    if (baseline.status == ProductBaselineStatus.accepted) {
      if (baseline.acceptedDecisionId == approvalDecisionId) return baseline;
      throw ImmutableBaselineException(baselineId);
    }

    // The candidate must still be proposed — superseded/rejected baselines
    // cannot be newly accepted via this authority.
    if (baseline.status != ProductBaselineStatus.proposed) {
      throw StaleBaselineApprovalException(
        'baseline $baselineId is ${baseline.status.wire}, not proposed; '
        'approval decision $approvalDecisionId is stale',
      );
    }

    // Only the actual current revision for the Product can be accepted.
    final latest = await _store.readBaselineByRevision(
      productId,
      baseline.revision,
    );
    if (latest == null || latest.baselineId != baselineId) {
      throw ProductLifecycleException(
        'baseline $baselineId is not the actual revision '
        '${baseline.revision} for $productId',
      );
    }

    final t = now ?? decision.timestamp!;
    final accepted = baseline.copyWith(
      status: ProductBaselineStatus.accepted,
      acceptedAt: t,
      acceptedBy: decision.decider,
      acceptedDecisionId: decision.decisionId,
      updatedAt: t,
      version: baseline.version + 1,
    );
    await _store.saveBaseline(accepted, expectedVersion: baseline.version);

    // Mark all older revisions superseded.
    final earlier = await _store.readBaselinesForProduct(productId);
    for (final other in earlier) {
      if (other.baselineId == baselineId) continue;
      if (other.status == ProductBaselineStatus.proposed) {
        final superseded = other.copyWith(
          status: ProductBaselineStatus.superseded,
          updatedAt: t,
          version: other.version + 1,
        );
        await _store.saveBaseline(superseded, expectedVersion: other.version);
      }
    }

    final onboarding = await _store.readOnboardingForProduct(productId);
    if (onboarding != null) {
      final done = onboarding.copyWith(
        completed: true,
        currentBaselineRevision: baseline.revision,
        updatedAt: t,
        version: onboarding.version + 1,
      );
      await _store.saveOnboarding(done);
    }
    return accepted;
  }

  Future<ProductBaseline> readBaselineRevision(
    String productId,
    int revision,
  ) async {
    final baseline = await _store.readBaselineByRevision(productId, revision);
    if (baseline == null) {
      throw BaselineNotFoundException('${productId}/r$revision');
    }
    return baseline;
  }

  Future<List<ProductBaseline>> readBaselines(String productId) =>
      _store.readBaselinesForProduct(productId);

  // ---------------------------------------------------------------------
  // Baseline acceptance authority (durable HumanDecision)
  // ---------------------------------------------------------------------

  static const String approveBaselineOptionId = 'approve_baseline';
  static const String requestCorrectionOptionId = 'request_baseline_correction';
  static const String rejectBaselineOptionId = 'reject_baseline';

  static const List<HumanDecisionOption> baselineApprovalOptions =
      <HumanDecisionOption>[
        HumanDecisionOption(
          optionId: approveBaselineOptionId,
          label: 'Approve baseline',
          description:
              'Accept this exact baseline revision as the authoritative '
              'Product understanding.',
          recommended: true,
        ),
        HumanDecisionOption(
          optionId: requestCorrectionOptionId,
          label: 'Request correction',
          description:
              'Send the baseline back for a new proposed revision; does not '
              'accept.',
        ),
        HumanDecisionOption(
          optionId: rejectBaselineOptionId,
          label: 'Reject baseline',
          description: 'Reject this proposed baseline; does not accept.',
        ),
      ];

  /// Creates (or returns an existing, still-unresolved) durable approval
  /// [HumanDecision] bound to the **exact** current revision + contentHash of
  /// [baselineId]. Idempotent for the same candidate.
  Future<HumanDecision> requestBaselineApproval({
    required String productId,
    required String baselineId,
    String? decisionId,
    DateTime? now,
  }) async {
    final baseline = await _store.readBaseline(baselineId);
    _ensureOwned(productId, baseline.productId, 'baseline $baselineId');
    if (baseline.status == ProductBaselineStatus.accepted) {
      throw ImmutableBaselineException(baselineId);
    }
    await _enterBaselineReview(productId, baseline, now: now);
    final binding = BaselineApprovalBinding(
      productId: productId,
      baselineId: baselineId,
      baselineRevision: baseline.revision,
      contentHash: baseline.contentHash,
      contentHashVersion: baseline.contentHashVersion,
    );
    final scope = BaselineApprovalBinding.scopeFor(productId);

    // Idempotent: reuse an unresolved decision for the same exact binding.
    final existing = await _decisions.readHumanDecisionsForScope(scope);
    for (final decision in existing) {
      final prior = BaselineApprovalBinding.tryFromMetadata(decision.metadata);
      if (prior != null &&
          prior.matches(
            productId: binding.productId,
            baselineId: binding.baselineId,
            baselineRevision: binding.baselineRevision,
            contentHash: binding.contentHash,
            contentHashVersion: binding.contentHashVersion,
          ) &&
          !decision.status.isResolved) {
        return decision;
      }
    }

    final t = now ?? DateTime.now().toUtc();
    final request = HumanDecision(
      decisionId: decisionId ?? 'blappr-$baselineId',
      workItemId: scope,
      decisionType: HumanDecisionType.productDecision,
      status: HumanDecisionStatus.pending,
      question:
          'Approve Product baseline $baselineId (revision ${baseline.revision}) '
          'for $productId?',
      context: DecisionContext(
        workflowState: baseline.status.wire,
        availableOptions: const <String>[
          approveBaselineOptionId,
          requestCorrectionOptionId,
          rejectBaselineOptionId,
        ],
      ),
      options: baselineApprovalOptions,
      recommendation: approveBaselineOptionId,
      blocking: true,
      requestedAt: t,
      metadata: binding.toMetadata(),
      updatedAt: t,
    );
    await _decisions.saveHumanDecision(request);
    return request;
  }

  /// Records the human's resolution of a baseline-approval decision. On
  /// `approve`, the decision's choice/decider/rationale/signature/timestamp are
  /// persisted **and** the bound baseline is accepted via [acceptBaseline].
  /// Non-approving choices persist the resolution but do not accept.
  ///
  /// Re-resolving an already-resolved decision is an idempotent replay: the
  /// recorded authority is preserved and never overwritten.
  Future<HumanDecision> resolveBaselineApproval({
    required String decisionId,
    required HumanDecisionChoice choice,
    required String decider,
    required String rationale,
    required DecisionSignature signature,
    DateTime? now,
  }) async {
    final decision = await _decisions.readHumanDecision(decisionId);
    if (decision == null) {
      throw BaselineApprovalNotFoundException(decisionId);
    }
    final binding = BaselineApprovalBinding.tryFromMetadata(decision.metadata);
    if (binding == null) {
      throw BaselineApprovalRequiredException(
        'decision $decisionId is not a Product baseline approval',
      );
    }
    if (decider.isEmpty) {
      throw BaselineApprovalRequiredException(
        'decision $decisionId requires a decider',
      );
    }

    final alreadyResolved = decision.status.isResolved;
    final effectiveChoice = alreadyResolved && decision.choice != null
        ? decision.choice!
        : choice;
    final effectiveDecider = alreadyResolved && decision.decider != null
        ? decision.decider!
        : decider;
    final effectiveRationale = alreadyResolved && decision.rationale != null
        ? decision.rationale!
        : rationale;
    final effectiveSignature = alreadyResolved && decision.signature != null
        ? decision.signature!
        : signature;
    final resolvedAt = alreadyResolved && decision.timestamp != null
        ? decision.timestamp!
        : (now ?? DateTime.now().toUtc());

    // Fail closed BEFORE recording approval: an approving choice is only valid
    // while the bound candidate still exists unchanged.
    if (effectiveChoice == HumanDecisionChoice.approve) {
      final live = await _store.readBaseline(binding.baselineId);
      if (!binding.matches(
        productId: live.productId,
        baselineId: live.baselineId,
        baselineRevision: live.revision,
        contentHash: live.contentHash,
        contentHashVersion: live.contentHashVersion,
      )) {
        throw StaleBaselineApprovalException(
          'decision $decisionId no longer matches '
          '${binding.baselineId}@r${live.revision} '
          'v${live.contentHashVersion} ${live.contentHash}',
        );
      }
    }

    final resolved = HumanDecision(
      decisionId: decision.decisionId,
      workItemId: decision.workItemId,
      decisionType: decision.decisionType,
      status: HumanDecisionStatus.resolved,
      question: decision.question,
      context: decision.context,
      options: decision.options,
      recommendation: decision.recommendation,
      blocking: decision.blocking,
      requestedAt: decision.requestedAt,
      expiration: decision.expiration,
      decider: effectiveDecider,
      choice: effectiveChoice,
      rationale: effectiveRationale,
      timestamp: resolvedAt,
      signature: effectiveSignature,
      resolvedOptionId: _optionIdForChoice(effectiveChoice),
      metadata: decision.metadata,
      updatedAt: resolvedAt,
    );
    if (!alreadyResolved) {
      await _decisions.saveHumanDecision(resolved);

      if (effectiveChoice == HumanDecisionChoice.approve) {
        await acceptBaseline(
          productId: binding.productId,
          baselineId: binding.baselineId,
          approvalDecisionId: decisionId,
          now: resolvedAt,
        );
        // The decision above is resolved, approved, and carries a human
        // decider — exactly the two guards governance requires.
        await transitionProduct(
          binding.productId,
          to: ProductState.governed,
          satisfiedGuards: const {
            ProductGuard.baselineApproved,
            ProductGuard.decisionActorIsHuman,
          },
          now: resolvedAt,
        );
      } else if (effectiveChoice == HumanDecisionChoice.reject) {
        await transitionProduct(
          binding.productId,
          to: ProductState.registered,
          satisfiedGuards: const {
            ProductGuard.baselineRejected,
            ProductGuard.decisionActorIsHuman,
          },
          now: resolvedAt,
        );
      }
    }
    return resolved;
  }

  /// Reads the durable approval decision governing [baselineId]'s exact current
  /// candidate, or null when none has been requested.
  Future<HumanDecision?> readBaselineApproval({
    required String productId,
    required String baselineId,
  }) async {
    final baseline = await _store.readBaseline(baselineId);
    _ensureOwned(productId, baseline.productId, 'baseline $baselineId');
    final decisions = await _decisions.readHumanDecisionsForScope(
      BaselineApprovalBinding.scopeFor(productId),
    );
    HumanDecision? match;
    for (final decision in decisions) {
      final binding = BaselineApprovalBinding.tryFromMetadata(
        decision.metadata,
      );
      if (binding != null &&
          binding.matches(
            productId: productId,
            baselineId: baselineId,
            baselineRevision: baseline.revision,
            contentHash: baseline.contentHash,
            contentHashVersion: baseline.contentHashVersion,
          )) {
        // Prefer a resolved decision over a pending one.
        if (match == null ||
            (!match.status.isResolved && decision.status.isResolved)) {
          match = decision;
        }
      }
    }
    return match;
  }

  static String _optionIdForChoice(HumanDecisionChoice choice) =>
      switch (choice) {
        HumanDecisionChoice.approve => approveBaselineOptionId,
        HumanDecisionChoice.rework => requestCorrectionOptionId,
        HumanDecisionChoice.reject => rejectBaselineOptionId,
        _ => choice.wire,
      };



  // ---------------------------------------------------------------------
  // Repository credentials (ADR 0018 A1 — scope is one repository)
  // ---------------------------------------------------------------------
  //
  // This engine never generates or holds key material. Key generation is
  // local device I/O and belongs in an adapter; what is recorded here is the
  // *public* half plus the reference name under which the private half sits
  // in the operator's secret store. A private key must never reach this
  // package.

  /// Records a newly generated credential for [repositoryId].
  ///
  /// The credential starts [CredentialStatus.generated] with an
  /// [HostKeyStatus.unknown] host: it cannot reach anything until a human
  /// confirms the host key and a real connection succeeds.
  Future<RepositoryCredential> recordGeneratedCredential({
    required String productId,
    required String repositoryId,
    required String referenceName,
    required String publicKey,
    required String fingerprint,
    String? host,
    String algorithm = 'ed25519',
    String? credentialId,
    String? supersedesCredentialId,
    DateTime? now,
  }) async {
    final repo = await _store.readRepositoryReference(repositoryId);
    _ensureOwned(productId, repo.productId, 'repository $repositoryId');
    if (publicKey.trim().isEmpty || fingerprint.trim().isEmpty) {
      throw CredentialNotUsableException(
        credentialId ?? '<new>',
        'a credential needs both a public key and a fingerprint',
      );
    }
    // Guard against key material being passed in by mistake.
    if (publicKey.contains('PRIVATE KEY')) {
      throw CredentialNotUsableException(
        credentialId ?? '<new>',
        'publicKey contains private key material; only the public half may '
        'be recorded',
      );
    }
    final active = await _store.readActiveCredentialForRepository(repositoryId);
    if (active != null && active.credentialId != supersedesCredentialId) {
      throw CredentialNotUsableException(
        active.credentialId,
        'repository $repositoryId already has an active credential; rotate '
        'it instead of issuing a second one',
      );
    }

    final t = now ?? DateTime.now().toUtc();
    final credential = RepositoryCredential(
      credentialId: credentialId ?? 'cred-$repositoryId-${t.microsecondsSinceEpoch}',
      productId: productId,
      repositoryId: repositoryId,
      referenceName: referenceName,
      publicKey: publicKey,
      fingerprint: fingerprint,
      algorithm: algorithm,
      status: CredentialStatus.generated,
      createdAt: t,
      host: host,
      supersedesCredentialId: supersedesCredentialId,
      version: 1,
    );
    await _store.saveProductCredential(credential);
    return credential;
  }

  /// Records a human's trust-on-first-use confirmation of a host key.
  ///
  /// ShipIt cannot verify a host on the operator's behalf, so this is a human
  /// decision and is attributed. Confirming a *different* fingerprint than one
  /// already confirmed fails closed rather than silently re-trusting.
  Future<RepositoryCredential> confirmHostKey({
    required String productId,
    required String credentialId,
    required String hostKeyFingerprint,
    required String confirmedBy,
    DateTime? now,
  }) async {
    final c = await _store.readProductCredential(credentialId);
    _ensureOwned(productId, c.productId, 'credential $credentialId');
    if (confirmedBy.isEmpty) {
      throw CredentialNotUsableException(
        credentialId,
        'host confirmation must record who confirmed it',
      );
    }
    if (c.hostKeyFingerprint != null &&
        c.hostKeyFingerprint != hostKeyFingerprint) {
      // Record the change, then refuse. The operator must resolve it.
      final changed = c.copyWith(
        hostKeyStatus: HostKeyStatus.changed,
        hostKeyFingerprint: hostKeyFingerprint,
        version: c.version + 1,
      );
      await _store.saveProductCredential(
        changed,
        expectedVersion: c.version,
      );
      throw HostKeyNotConfirmedException(
        c.host ?? 'unknown host',
        HostKeyStatus.changed,
      );
    }
    final t = now ?? DateTime.now().toUtc();
    final updated = c.copyWith(
      hostKeyStatus: HostKeyStatus.confirmed,
      hostKeyFingerprint: hostKeyFingerprint,
      hostConfirmedAt: t,
      hostConfirmedBy: confirmedBy,
      version: c.version + 1,
    );
    await _store.saveProductCredential(updated, expectedVersion: c.version);
    return updated;
  }

  /// Records the outcome of a real connectivity check.
  ///
  /// This is the only way a credential becomes usable. A check against an
  /// unconfirmed host is refused outright — ShipIt will not connect to a host
  /// it does not recognise, so there is no result to record.
  Future<RepositoryCredential> recordCredentialCheck({
    required String productId,
    required String credentialId,
    required bool succeeded,
    required String checkedBy,
    String? failureReason,
    DateTime? now,
  }) async {
    final c = await _store.readProductCredential(credentialId);
    _ensureOwned(productId, c.productId, 'credential $credentialId');
    if (c.status == CredentialStatus.revoked) {
      throw CredentialNotUsableException(credentialId, 'credential is revoked');
    }
    if (!c.hostKeyStatus.permitsConnection) {
      throw HostKeyNotConfirmedException(
        c.host ?? 'unknown host',
        c.hostKeyStatus,
      );
    }
    final t = now ?? DateTime.now().toUtc();
    final updated = succeeded
        ? c.copyWith(
            status: CredentialStatus.verified,
            lastVerifiedAt: t,
            lastVerifiedBy: checkedBy,
            version: c.version + 1,
          )
        : c.copyWith(
            status: CredentialStatus.failing,
            lastFailureReason: failureReason ?? 'connection failed',
            version: c.version + 1,
          );
    await _store.saveProductCredential(updated, expectedVersion: c.version);
    return updated;
  }

  /// Revokes a credential. Never deletes it: the historical record stays
  /// readable (ADR 0018).
  Future<RepositoryCredential> revokeCredential({
    required String productId,
    required String credentialId,
    required String reason,
    DateTime? now,
  }) async {
    final c = await _store.readProductCredential(credentialId);
    _ensureOwned(productId, c.productId, 'credential $credentialId');
    if (c.status == CredentialStatus.revoked) return c;
    final t = now ?? DateTime.now().toUtc();
    final updated = c.copyWith(
      status: CredentialStatus.revoked,
      revokedAt: t,
      revokedReason: reason,
      version: c.version + 1,
    );
    await _store.saveProductCredential(updated, expectedVersion: c.version);
    return updated;
  }

  /// Replaces the active credential for a repository.
  ///
  /// The old credential is revoked and the new one records it in
  /// [RepositoryCredential.supersedesCredentialId], so the chain stays
  /// readable. Host confirmation does not carry over automatically — the new
  /// key still has to prove it can connect.
  Future<RepositoryCredential> rotateCredential({
    required String productId,
    required String repositoryId,
    required String referenceName,
    required String publicKey,
    required String fingerprint,
    required String reason,
    String? credentialId,
    DateTime? now,
  }) async {
    final active = await _store.readActiveCredentialForRepository(repositoryId);
    if (active == null) {
      throw CredentialNotFoundException(
        'active credential for repository $repositoryId',
      );
    }
    _ensureOwned(productId, active.productId, 'repository $repositoryId');
    final t = now ?? DateTime.now().toUtc();
    await revokeCredential(
      productId: productId,
      credentialId: active.credentialId,
      reason: reason,
      now: t,
    );
    return recordGeneratedCredential(
      productId: productId,
      repositoryId: repositoryId,
      referenceName: referenceName,
      publicKey: publicKey,
      fingerprint: fingerprint,
      host: active.host,
      credentialId: credentialId,
      supersedesCredentialId: active.credentialId,
      now: t,
    );
  }

  Future<RepositoryCredential?> readActiveCredential(
    String productId,
    String repositoryId,
  ) async {
    final repo = await _store.readRepositoryReference(repositoryId);
    _ensureOwned(productId, repo.productId, 'repository $repositoryId');
    return _store.readActiveCredentialForRepository(repositoryId);
  }

  Future<List<RepositoryCredential>> readCredentials(String productId) =>
      _store.readCredentialsForProduct(productId);

  /// The credential that may actually be used to reach [repositoryId], or
  /// throws explaining why none can be.
  ///
  /// Callers that are about to clone or push use this rather than reading the
  /// credential directly, so "assumed working" never happens.
  Future<RepositoryCredential> requireUsableCredential({
    required String productId,
    required String repositoryId,
  }) async {
    final c = await readActiveCredential(productId, repositoryId);
    if (c == null) {
      throw CredentialNotFoundException(
        'no credential for repository $repositoryId',
      );
    }
    if (!c.hostKeyStatus.permitsConnection) {
      throw HostKeyNotConfirmedException(
        c.host ?? 'unknown host',
        c.hostKeyStatus,
      );
    }
    if (!c.status.isUsable) {
      throw CredentialNotUsableException(
        c.credentialId,
        'status is ${c.status.wire}; a successful check is required',
      );
    }
    return c;
  }

  // ---------------------------------------------------------------------
  // Product lifecycle decisions (pause / resume / offboard / reinstate)
  // ---------------------------------------------------------------------

  static const String lifecycleProceedOptionId = 'proceed';
  static const String lifecycleDeclineOptionId = 'decline';

  /// Raises a durable, blocking decision for a product lifecycle [action].
  ///
  /// Follows the baseline-approval pattern: the engine owns the decision
  /// shape, so no caller can raise a pause that forgets its signature or
  /// invents a transition the table forbids. Idempotent — an unresolved
  /// decision for the same product and action is reused.
  Future<HumanDecision> requestLifecycleDecision({
    required String productId,
    required ProductLifecycleAction action,
    bool drainInFlight = true,
    String? decisionId,
    DateTime? now,
  }) async {
    final product = await _store.readProduct(productId);
    final from = product.state.canonical;

    // Refuse to raise a gate for something that could never be resolved.
    final rejection = ProductTransitions.explainRejection(from, action.target);
    if (rejection != null) {
      throw ProductLifecycleException(
        'cannot request ${action.wire} for $productId: $rejection',
      );
    }

    final binding = LifecycleDecisionBinding(
      productId: productId,
      action: action,
      fromState: from,
      drainInFlight: drainInFlight,
    );
    final scope = LifecycleDecisionBinding.scopeFor(productId);

    final existing = await _decisions.readHumanDecisionsForScope(scope);
    for (final decision in existing) {
      final prior = LifecycleDecisionBinding.tryFromMetadata(
        decision.metadata,
      );
      if (prior != null &&
          prior.action == action &&
          prior.matches(productId: productId, fromState: from) &&
          !decision.status.isResolved) {
        return decision;
      }
    }

    final t = now ?? DateTime.now().toUtc();
    final request = HumanDecision(
      decisionId: decisionId ?? 'plc-${action.wire}-$productId',
      workItemId: scope,
      decisionType: HumanDecisionType.productDecision,
      status: HumanDecisionStatus.pending,
      question: _lifecycleQuestion(action, product.name),
      context: DecisionContext(
        workflowState: from.wire,
        availableOptions: const <String>[
          lifecycleProceedOptionId,
          lifecycleDeclineOptionId,
        ],
      ),
      options: _lifecycleOptions(action, drainInFlight),
      recommendation: lifecycleProceedOptionId,
      blocking: true,
      requestedAt: t,
      metadata: binding.toMetadata(),
      updatedAt: t,
    );
    await _decisions.saveHumanDecision(request);
    return request;
  }

  /// Records the human's resolution and, on approval, performs the transition.
  ///
  /// Fails closed when the product has moved since the decision was raised:
  /// a pause approved against a governed product must not silently apply to
  /// one that has since been archived.
  Future<HumanDecision> resolveLifecycleDecision({
    required String decisionId,
    required HumanDecisionChoice choice,
    required String decider,
    required String rationale,
    required DecisionSignature signature,
    Set<ProductGuard> additionalGuards = const {},
    DateTime? now,
  }) async {
    final decision = await _decisions.readHumanDecision(decisionId);
    if (decision == null) {
      throw BaselineApprovalNotFoundException(decisionId);
    }
    final binding = LifecycleDecisionBinding.tryFromMetadata(
      decision.metadata,
    );
    if (binding == null) {
      throw ProductLifecycleException(
        'decision $decisionId is not a product lifecycle decision',
      );
    }
    if (decider.isEmpty) {
      throw ProductLifecycleException(
        'decision $decisionId requires a decider',
      );
    }

    final alreadyResolved = decision.status.isResolved;
    final effectiveChoice = alreadyResolved && decision.choice != null
        ? decision.choice!
        : choice;
    final resolvedAt = alreadyResolved && decision.timestamp != null
        ? decision.timestamp!
        : (now ?? DateTime.now().toUtc());

    if (!alreadyResolved && effectiveChoice == HumanDecisionChoice.approve) {
      final live = await _store.readProduct(binding.productId);
      if (!binding.matches(
        productId: binding.productId,
        fromState: live.state,
      )) {
        throw StaleBaselineApprovalException(
          'decision $decisionId was raised against '
          '${binding.fromState.wire} but ${binding.productId} is now '
          '${live.state.canonical.wire}',
        );
      }
    }

    final resolved = HumanDecision(
      decisionId: decision.decisionId,
      workItemId: decision.workItemId,
      decisionType: decision.decisionType,
      status: HumanDecisionStatus.resolved,
      question: decision.question,
      context: decision.context,
      options: decision.options,
      recommendation: decision.recommendation,
      blocking: decision.blocking,
      requestedAt: decision.requestedAt,
      expiration: decision.expiration,
      decider: alreadyResolved && decision.decider != null
          ? decision.decider!
          : decider,
      choice: effectiveChoice,
      rationale: alreadyResolved && decision.rationale != null
          ? decision.rationale!
          : rationale,
      timestamp: resolvedAt,
      signature: alreadyResolved && decision.signature != null
          ? decision.signature!
          : signature,
      resolvedOptionId: effectiveChoice == HumanDecisionChoice.approve
          ? lifecycleProceedOptionId
          : lifecycleDeclineOptionId,
      metadata: decision.metadata,
      updatedAt: resolvedAt,
    );

    if (!alreadyResolved) {
      await _decisions.saveHumanDecision(resolved);
      if (effectiveChoice == HumanDecisionChoice.approve) {
        await transitionProduct(
          binding.productId,
          to: binding.action.target,
          satisfiedGuards: {
            binding.action.guard,
            ProductGuard.decisionActorIsHuman,
            ...additionalGuards,
          },
          now: resolvedAt,
        );
      }
    }
    return resolved;
  }

  static String _lifecycleQuestion(
    ProductLifecycleAction action,
    String name,
  ) => switch (action) {
    ProductLifecycleAction.pause => 'Pause work for $name?',
    ProductLifecycleAction.resume => 'Resume work for $name?',
    ProductLifecycleAction.offboard => 'Offboard $name?',
    ProductLifecycleAction.reinstate => 'Reinstate $name?',
  };

  static List<HumanDecisionOption> _lifecycleOptions(
    ProductLifecycleAction action,
    bool drainInFlight,
  ) {
    final proceed = switch (action) {
      ProductLifecycleAction.pause => drainInFlight
          ? 'Stop dispatching new work; work already running finishes.'
          : 'Stop dispatching new work and release running leases now.',
      ProductLifecycleAction.resume =>
        'Start dispatching work for this product again.',
      ProductLifecycleAction.offboard => drainInFlight
          ? 'Archive once running work finishes. Nothing is deleted.'
          : 'Archive now and cancel running work. Nothing is deleted.',
      ProductLifecycleAction.reinstate =>
        'Send a fresh baseline for approval. Governance is not restored '
            'directly.',
    };
    return <HumanDecisionOption>[
      HumanDecisionOption(
        optionId: lifecycleProceedOptionId,
        label: switch (action) {
          ProductLifecycleAction.pause => 'Pause',
          ProductLifecycleAction.resume => 'Resume',
          ProductLifecycleAction.offboard => 'Offboard',
          ProductLifecycleAction.reinstate => 'Reinstate',
        },
        description: proceed,
        recommended: true,
      ),
      const HumanDecisionOption(
        optionId: lifecycleDeclineOptionId,
        label: 'Leave as is',
        description: 'Nothing changes.',
      ),
    ];
  }


  // ---------------------------------------------------------------------
  // Standing policy authorisations (ADR 0019)
  // ---------------------------------------------------------------------

  static const String policyAuthoriseOptionId = 'authorise';
  static const String policyDeclineOptionId = 'keep_asking';

  static const String _policyRoutingKey = 'routing';
  static const String _policyRoutingValue = 'standing_policy_authorisation';
  static const String _policyProductKey = 'productId';
  static const String _policyActionsKey = 'actions';

  /// Raises the gate that creates a standing policy.
  ///
  /// Creating a standing authorisation is itself consequential, so it goes
  /// through a normal ADR 0013 gate rather than being a setting someone
  /// toggles.
  Future<HumanDecision> requestPolicyAuthorisation({
    required String productId,
    required List<PolicyAction> actions,
    String? decisionId,
    DateTime? now,
  }) async {
    final product = await _store.readProduct(productId);
    if (actions.isEmpty) {
      throw InvalidPolicyScopeException(
        'a policy must authorise at least one action; an empty policy is a '
        'config flag pretending to be a decision',
      );
    }
    if (product.state.canonical != ProductState.governed) {
      throw InvalidPolicyScopeException(
        'only a governed product can carry a standing policy; $productId is '
        '${product.state.canonical.wire}',
      );
    }

    final scope = 'product-policy:$productId';
    final existing = await _decisions.readHumanDecisionsForScope(scope);
    for (final d in existing) {
      if (d.metadata?[_policyRoutingKey] == _policyRoutingValue &&
          d.metadata?[_policyProductKey] == productId &&
          !d.status.isResolved) {
        return d;
      }
    }

    final t = now ?? DateTime.now().toUtc();
    final wires = actions.map((a) => a.wire).toList();
    final request = HumanDecision(
      decisionId: decisionId ?? 'pol-$productId',
      workItemId: scope,
      decisionType: HumanDecisionType.productDecision,
      status: HumanDecisionStatus.pending,
      question:
          'Let ShipIt ${wires.join(" and ")} for ${product.name} without '
          'asking each time?',
      context: DecisionContext(
        workflowState: product.state.canonical.wire,
        availableOptions: const <String>[
          policyAuthoriseOptionId,
          policyDeclineOptionId,
        ],
      ),
      options: <HumanDecisionOption>[
        HumanDecisionOption(
          optionId: policyAuthoriseOptionId,
          label: 'Authorise',
          description:
              'Work stops asking for ${wires.join(" and ")}. Promotion to '
              'production still always waits for you.',
          recommended: true,
        ),
        const HumanDecisionOption(
          optionId: policyDeclineOptionId,
          label: 'Keep asking me each time',
          description: 'Nothing changes.',
        ),
      ],
      recommendation: policyAuthoriseOptionId,
      blocking: true,
      requestedAt: t,
      metadata: <String, dynamic>{
        _policyRoutingKey: _policyRoutingValue,
        _policyProductKey: productId,
        _policyActionsKey: wires,
      },
      updatedAt: t,
    );
    await _decisions.saveHumanDecision(request);
    return request;
  }

  /// Resolves the gate. On approval a [StandingPolicy] is created carrying the
  /// decider, rationale and authorising decision id, so every later action can
  /// cite it.
  Future<StandingPolicy?> resolvePolicyAuthorisation({
    required String decisionId,
    required HumanDecisionChoice choice,
    required String decider,
    required String rationale,
    required DecisionSignature signature,
    String? policyId,
    DateTime? now,
  }) async {
    final decision = await _decisions.readHumanDecision(decisionId);
    if (decision == null) {
      throw BaselineApprovalNotFoundException(decisionId);
    }
    if (decision.metadata?[_policyRoutingKey] != _policyRoutingValue) {
      throw InvalidPolicyScopeException(
        'decision $decisionId is not a standing policy authorisation',
      );
    }
    if (decider.isEmpty) {
      throw InvalidPolicyScopeException(
        'decision $decisionId requires a decider',
      );
    }
    if (rationale.isEmpty) {
      throw InvalidPolicyScopeException(
        'a standing policy must record why it was authorised',
      );
    }

    final productId = decision.metadata![_policyProductKey] as String;
    final actions = (decision.metadata![_policyActionsKey] as List)
        .map((w) => PolicyAction.fromWire(w as String))
        .toList();

    if (decision.status.isResolved) {
      // Idempotent replay: return the policy this decision already created.
      final existing = await _store.readPoliciesForProduct(productId);
      for (final p in existing) {
        if (p.authorisingDecisionId == decisionId) return p;
      }
      return null;
    }

    final t = now ?? DateTime.now().toUtc();
    await _decisions.saveHumanDecision(
      HumanDecision(
        decisionId: decision.decisionId,
        workItemId: decision.workItemId,
        decisionType: decision.decisionType,
        status: HumanDecisionStatus.resolved,
        question: decision.question,
        context: decision.context,
        options: decision.options,
        recommendation: decision.recommendation,
        blocking: decision.blocking,
        requestedAt: decision.requestedAt,
        expiration: decision.expiration,
        decider: decider,
        choice: choice,
        rationale: rationale,
        timestamp: t,
        signature: signature,
        resolvedOptionId: choice == HumanDecisionChoice.approve
            ? policyAuthoriseOptionId
            : policyDeclineOptionId,
        metadata: decision.metadata,
        updatedAt: t,
      ),
    );

    if (choice != HumanDecisionChoice.approve) return null;

    // Supersede any policy already in force over the same scope, so two
    // overlapping authorisations can never both be live.
    for (final live in await _store.readPoliciesForProduct(productId)) {
      if (!live.isRevoked) {
        await _store.saveStandingPolicy(
          live.revoke(
            at: t,
            by: decider,
            reason: PolicyRevocationReason.superseded,
            decisionId: decisionId,
          ),
          expectedVersion: live.version,
        );
      }
    }

    final policy = StandingPolicy(
      policyId: policyId ?? 'pol-$productId-${t.microsecondsSinceEpoch}',
      productId: productId,
      actions: actions,
      authorisingDecisionId: decisionId,
      authorisedBy: decider,
      rationale: rationale,
      authorisedAt: t,
    );
    await _store.saveStandingPolicy(policy);
    return policy;
  }

  /// Withdraws a policy. Revocation is itself recorded and attributed.
  Future<StandingPolicy> revokeStandingPolicy({
    required String productId,
    required String policyId,
    required String revokedBy,
    PolicyRevocationReason reason = PolicyRevocationReason.revokedByHuman,
    String? decisionId,
    DateTime? now,
  }) async {
    final policy = await _store.readStandingPolicy(policyId);
    _ensureOwned(productId, policy.productId, 'policy $policyId');
    if (policy.isRevoked) return policy;
    final revoked = policy.revoke(
      at: now ?? DateTime.now().toUtc(),
      by: revokedBy,
      reason: reason,
      decisionId: decisionId,
    );
    await _store.saveStandingPolicy(revoked, expectedVersion: policy.version);
    return revoked;
  }

  Future<List<StandingPolicy>> readPolicies(String productId) =>
      _store.readPoliciesForProduct(productId);

  /// The policy authorising [action] for [productId] at [at], or null.
  ///
  /// This is the citation mechanism: a caller about to push records the
  /// returned [StandingPolicy.policyId] alongside the action, so "why did this
  /// happen without me?" resolves to a signed decision.
  Future<StandingPolicy?> authorisationFor({
    required String productId,
    required PolicyAction action,
    DateTime? at,
  }) async {
    final t = at ?? DateTime.now().toUtc();
    for (final p in await _store.readPoliciesForProduct(productId)) {
      if (p.covers(productId: productId, action: action, at: t)) return p;
    }
    return null;
  }

  /// Whether [action] may proceed without raising a gate, and under whose
  /// authority.
  ///
  /// A product that is not governed never qualifies — pausing a product must
  /// actually stop work, not leave a policy quietly authorising pushes.
  Future<StandingPolicy?> mayProceedUnderPolicy({
    required String productId,
    required PolicyAction action,
    DateTime? at,
  }) async {
    final product = await _store.readProduct(productId);
    if (!product.state.allowsDispatch) return null;
    return authorisationFor(productId: productId, action: action, at: at);
  }

  // ---------------------------------------------------------------------
  // Uncertainty / clarification (durable)
  // ---------------------------------------------------------------------

  /// Records a durable stop: onboarding cannot proceed because a material
  /// piece of information is unknown. Survives process restart; a new
  /// execution resumes the same lineage after the human answers.
  Future<ClarificationRequest> requireClarification({
    required String productId,
    required BaselineSectionKey section,
    required String question,
    String? onboardingId,
    String? clarificationId,
    DateTime? now,
  }) async {
    await _store.readProduct(productId);
    final effectiveOnboardingId =
        onboardingId ??
        (await _ensureOnboarding(productId, now: now)).onboardingId;
    final t = now ?? DateTime.now().toUtc();
    final request = ClarificationRequest(
      clarificationId:
          clarificationId ?? 'clar-${productId}-${t.microsecondsSinceEpoch}',
      productId: productId,
      onboardingId: effectiveOnboardingId,
      section: section,
      question: question,
      status: ClarificationStatus.needsAnswer,
      createdAt: t,
    );
    await _store.saveClarification(request);

    final record = await _store.readOnboardingForProduct(productId);
    if (record != null) {
      final updated = record.copyWith(
        pendingClarifications: record.pendingClarifications + 1,
        updatedAt: t,
        version: record.version + 1,
      );
      await _store.saveOnboarding(updated);
    }
    return request;
  }

  /// A new execution resumes the same Product/onboarding/baseline lineage by
  /// answering the durable clarification.
  Future<ClarificationRequest> answerClarification({
    required String clarificationId,
    required String answer,
    required String answeredBy,
    DateTime? now,
  }) async {
    final request = await _store.readClarification(clarificationId);
    if (request.status == ClarificationStatus.answered) {
      return request; // idempotent
    }
    final t = now ?? DateTime.now().toUtc();
    final answered = request.copyWith(
      status: ClarificationStatus.answered,
      answer: answer,
      answeredAt: t,
      answeredBy: answeredBy,
    );
    await _store.saveClarification(answered);

    final record = await _store.readOnboardingForProduct(request.productId);
    if (record != null && record.pendingClarifications > 0) {
      final updated = record.copyWith(
        pendingClarifications: record.pendingClarifications - 1,
        updatedAt: t,
        version: record.version + 1,
      );
      await _store.saveOnboarding(updated);
    }
    return answered;
  }

  Future<List<ClarificationRequest>> readOpenClarifications(String productId) =>
      _store.readClarificationsForProduct(productId);

  // ---------------------------------------------------------------------
  // ProductContext (bounded load boundary)
  // ---------------------------------------------------------------------

  /// Loads bounded, authoritative Product context for a completely new
  /// execution — no prior chat, no memory, no session, no process-global.
  Future<ProductContext> loadProductContext(String productId) async {
    final product = await _store.readProduct(productId);
    final repositories = await _store.readRepositoriesForProduct(productId);
    final baselines = await _store.readBaselinesForProduct(productId);

    ProductBaseline? active;
    for (final b in baselines) {
      if (b.status == ProductBaselineStatus.accepted && active == null) {
        active = b;
      }
    }
    final open = await _store.readClarificationsForProduct(productId);

    return ProductContext(
      product: product,
      repositories: repositories,
      activeBaseline: active,
      allBaselines: baselines,
      openClarifications: open,
    );
  }

  // ---------------------------------------------------------------------
  // Derived product scope (helpers so scope derivation isn't duplicated)
  // ---------------------------------------------------------------------

  /// Derives the authoritative Product for any entity whose ID is known,
  /// verifying the caller's requested [productId] matches. Knowing an entity
  /// ID does NOT authorize cross-Product retrieval (checkpoint 006 §12).
  ///
  /// [entityProductId] must be the owning Product of the entity — e.g. an
  /// `AgentExecution` derives `productId` via its `WorkItem`, which carries
  /// `productId` directly. Callers obtain it from the durable work item, never
  /// from chat/session globals.
  Future<T> scoped<T>({
    required String productId,
    required String entityProductId,
    required String entityLabel,
    required Future<T> Function() read,
  }) async {
    _ensureOwned(productId, entityProductId, entityLabel);
    await readProduct(productId);
    return read();
  }

  void _ensureOwned(String requested, String actual, String entity) {
    if (requested != actual) {
      throw CrossProductAccessException(
        '$entity belongs to product $actual, not $requested',
      );
    }
  }

  Future<OnboardingRecord> _ensureOnboarding(
    String productId, {
    DateTime? now,
  }) async {
    final existing = await _store.readOnboardingForProduct(productId);
    if (existing != null) return existing;
    final t = now ?? DateTime.now().toUtc();
    final record = OnboardingRecord(
      onboardingId: 'ob-$productId',
      productId: productId,
      currentBaselineRevision: 0,
      pendingClarifications: 0,
      completed: false,
      createdAt: t,
      updatedAt: t,
      version: 1,
    );
    await _store.saveOnboarding(record);
    return record;
  }

  Future<void> _touchOnboarding(
    String productId, {
    required int currentBaselineRevision,
    DateTime? now,
  }) async {
    final record = await _store.readOnboardingForProduct(productId);
    if (record == null) return;
    final updated = record.copyWith(
      currentBaselineRevision: currentBaselineRevision,
      updatedAt: now ?? DateTime.now().toUtc(),
      version: record.version + 1,
    );
    await _store.saveOnboarding(updated);
  }
}
