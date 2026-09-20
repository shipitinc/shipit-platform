import 'package:control_plane_client/control_plane_client.dart';
import 'package:flutter/foundation.dart';

/// Handwritten repository for the operator UI.
///
/// Talks to the generated `control_plane_client`, mapping the typed Serverpod
/// wire models (Overview, WorkItemView, DecisionView, ...) onto the small
/// stable response objects the feature layers consume. The wire contract is
/// typed end-to-end, so the generated client needs no manual repair.
class ControlPlaneRepository {
  ControlPlaneRepository({required Client client}) : _client = client;

  final Client _client;

  /// Bumped whenever this client writes durable state.
  ///
  /// Chrome that caches derived values (the rail's counts) can listen instead
  /// of polling, so resolving a decision in place updates the whole surface.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Future<OverviewResponse> getOverview() async {
    final result = await _client.homeEndpoints.overview();
    return OverviewResponse(
      running: result.running,
      waitingOnYou: result.waitingOnYou,
      recentlyFinished: result.recentlyFinished,
      finishedPassed: result.finishedPassed,
      finishedFailed: result.finishedFailed,
      generatedAt: result.generatedAt,
      machinesBusy: result.machinesBusy,
      machinesTotal: result.machinesTotal,
      jobs: result.jobs
          .map(
            (j) => JobSummaryResponse(
              jobId: j.jobId,
              workItemId: j.workItemId,
              state: j.state,
              jobType: j.jobType,
              createdAt: j.createdAt,
              availableAt: j.availableAt,
              blockedOnDecision: j.blockedOnDecision,
              attempt: j.attempt,
              maxAttempts: j.maxAttempts,
            ),
          )
          .toList(),
    );
  }

  /// One row per registered product, for the Products screen.
  ///
  /// `allowsDispatch` is mirrored from the engine rather than re-derived here;
  /// the UI must never disagree with `ProductState` about whether work may run.
  Future<List<ProductSummaryResponse>> listProductSummaries() async {
    final rows = await _client.productRegistryEndpoints.listProductSummaries();
    return rows
        .map(
          (r) => ProductSummaryResponse(
            productId: r.productId,
            name: r.name,
            state: r.state,
            allowsDispatch: r.allowsDispatch,
            activeBaselineId: r.activeBaselineId,
            activeBaselineRevision: r.activeBaselineRevision,
            pendingBaselineId: r.pendingBaselineId,
            pendingBaselineRevision: r.pendingBaselineRevision,
            pendingBaselineVerified: r.pendingBaselineVerified,
            baselineFactCount: r.baselineFactCount,
            openClarifications: r.openClarifications,
            repositoryCount: r.repositoryCount,
            reachableRepositoryCount: r.reachableRepositoryCount,
            updatedAt: r.updatedAt,
          ),
        )
        .toList();
  }

  /// Everything the Product Detail screen reads, in one call.
  Future<ProductDetailResponse> getProductDetail(String productId) async {
    final d = await _client.productRegistryEndpoints.productDetail(
      productId: productId,
    );
    return ProductDetailResponse(
      productId: d.product.productId,
      name: d.product.name,
      description: d.product.description,
      state: d.product.state,
      allowsDispatch: d.allowsDispatch,
      updatedAt: d.product.updatedAt,
      repositories: d.repositories
          .map(
            (r) => ProductRepositoryResponse(
              repositoryId: r.repositoryId,
              uri: r.uri,
              kind: r.kind,
              provider: r.provider,
            ),
          )
          .toList(),
      credentials: d.credentials
          .map(
            (c) => CredentialResponse(
              credentialId: c.credentialId,
              repositoryId: c.repositoryId,
              referenceName: c.referenceName,
              fingerprint: c.fingerprint,
              algorithm: c.algorithm,
              status: c.status,
              hostKeyStatus: c.hostKeyStatus,
              host: c.host,
              canReachRepository: c.canReachRepository,
              lastVerifiedAt: c.lastVerifiedAt,
              lastVerifiedBy: c.lastVerifiedBy,
              lastFailureReason: c.lastFailureReason,
              hostConfirmedAt: c.hostConfirmedAt,
              hostConfirmedBy: c.hostConfirmedBy,
            ),
          )
          .toList(),
      activeBaselineId: d.activeBaseline?.baselineId,
      activeBaselineRevision: d.activeBaseline?.revision,
      activeBaselineHash: d.activeBaseline?.contentHash,
      activeBaselineAcceptedAt: d.activeBaseline?.acceptedAt,
      activeBaselineAcceptedBy: d.activeBaseline?.acceptedBy,
      activeBaselineFactCount: d.activeBaseline?.facts.length ?? 0,
      pendingBaselineId: d.pendingBaseline?.baselineId,
      pendingBaselineRevision: d.pendingBaseline?.revision,
      pendingBaselineVerified: d.pendingBaselineVerified,
      openClarifications: d.openClarifications
          .map(
            (c) => ClarificationSummary(
              clarificationId: c.clarificationId,
              question: c.question,
              section: c.section,
            ),
          )
          .toList(),
      policies: d.policies.map(_policyResponse).toList(),
    );
  }

  Future<List<WorkItemResponse>> listWorkItems({
    String? state,
    int? limit,
  }) async {
    final result = await _client.homeEndpoints.listWorkItems(
      state: state,
      limit: limit,
    );
    return result.map(_workItemResponse).toList();
  }

  Future<List<DecisionResponse>> pendingDecisions({int? limit}) async {
    final result = await _client.homeEndpoints.pendingDecisions(limit: limit);
    return result.map(_decisionResponse).toList();
  }

  /// Decisions that already carry a durable outcome, newest first.
  Future<List<DecisionResponse>> recentDecisions({
    int? limit,
    int? offset,
  }) async {
    final result = await _client.homeEndpoints.recentDecisions(
      limit: limit,
      offset: offset,
    );
    return result.map(_decisionResponse).toList();
  }

  Future<WorkItemDetailResponse> inspectWorkItem(String workItemId) async {
    final result = await _client.workflowEndpoints.inspect(
      workItemId: workItemId,
    );
    return WorkItemDetailResponse(
      workItem: _workItemResponse(result.workItem),
      transitionHistory: result.transitionHistory
          .map(
            (t) => TransitionResponse(
              transitionId: t.transitionId,
              workItemId: t.workItemId,
              fromState: t.fromState,
              toState: t.toState,
              transitionedAt: t.transitionedAt,
              reason: t.reason,
            ),
          )
          .toList(),
    );
  }

  /// Raises the durable gate that precedes a lifecycle transition.
  ///
  /// `action` is pause | resume | offboard. The engine refuses up front if
  /// the transition could never resolve, so an operator is never offered a
  /// gate nobody could action. Returns the gate to resolve.
  Future<DecisionResponse> requestLifecycleDecision({
    required String productId,
    required String action,
    bool drainInFlight = true,
  }) async {
    final m = await _client.productRegistryEndpoints.requestLifecycleDecision(
      productId: productId,
      action: action,
      drainInFlight: drainInFlight,
    );
    revision.value++;
    return _decisionResponse(m);
  }

  /// Resolves a lifecycle gate. On approve the engine performs the
  /// transition, and refuses if a required guard was never established —
  /// offboarding with work still in flight, for example.
  Future<DecisionResponse> resolveLifecycleDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    bool noWorkInFlight = false,
  }) async {
    final now = DateTime.now();
    final m = await _client.productRegistryEndpoints.resolveLifecycleDecision(
      decisionId: decisionId,
      choice: choice,
      decider: decider,
      rationale: rationale,
      algorithm: 'ed25519',
      publicKey: 'operator-pub-key',
      signature: 'operator-sig-${now.millisecondsSinceEpoch}',
      signedAt: now,
      noWorkInFlight: noWorkInFlight,
    );
    revision.value++;
    return _decisionResponse(m);
  }

  /// Raises the gate that would create a standing policy (ADR 0019).
  ///
  /// `actions` may only contain push | merge. Production promotion, baseline
  /// approval and offboarding are non-delegable and are not expressible.
  Future<DecisionResponse> requestPolicyAuthorisation({
    required String productId,
    required List<String> actions,
  }) async {
    final m = await _client.productRegistryEndpoints
        .requestPolicyAuthorisation(
          productId: productId,
          actions: actions,
        );
    revision.value++;
    return _decisionResponse(m);
  }

  /// Resolves a policy gate. On approve a standing policy is created citing
  /// this decision; any policy already live over the same scope is
  /// superseded.
  Future<PolicyResponse> resolvePolicyAuthorisation({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
  }) async {
    final now = DateTime.now();
    final m = await _client.productRegistryEndpoints
        .resolvePolicyAuthorisation(
          decisionId: decisionId,
          choice: choice,
          decider: decider,
          rationale: rationale,
          algorithm: 'ed25519',
          publicKey: 'operator-pub-key',
          signature: 'operator-sig-${now.millisecondsSinceEpoch}',
          signedAt: now,
        );
    revision.value++;
    return _policyResponse(m!);
  }

  /// Withdraws a standing policy. Revocation is itself recorded.
  Future<void> revokeStandingPolicy({
    required String productId,
    required String policyId,
    required String revokedBy,
  }) async {
    await _client.productRegistryEndpoints.revokeStandingPolicy(
      productId: productId,
      policyId: policyId,
      revokedBy: revokedBy,
    );
    revision.value++;
  }

  /// Jobs belonging to a work item, newest first. Read-only.
  /// Jobs belonging to a work item, newest first. Read-only.
  Future<List<JobSummaryResponse>> jobsForWorkItem(String workItemId) async {
    final result = await _client.workflowEndpoints.jobsForWorkItem(
      workItemId: workItemId,
    );
    return result
        .map(
          (j) => JobSummaryResponse(
            jobId: j.jobId,
            workItemId: j.workItemId,
            state: j.state,
            jobType: j.jobType,
            createdAt: j.createdAt,
            availableAt: j.availableAt,
            blockedOnDecision: j.blockedOnDecision,
            attempt: j.attempt,
            maxAttempts: j.maxAttempts,
          ),
        )
        .toList();
  }

  Future<DecisionDetailResponse> inspectDecision(String workItemId) async {
    final result = await _client.workflowEndpoints.listDecisions(
      workItemId: workItemId,
    );
    if (result.isEmpty) {
      throw StateError('No decisions found for work item $workItemId');
    }
    return DecisionDetailResponse(
      decisionId: result.first.decisionId,
      workItemId: result.first.workItemId,
      workItemTitle: result.first.workItemTitle,
      workItemDescription: result.first.workItemDescription,
      decisionType: result.first.decisionType,
      status: result.first.status,
      question: result.first.question,
      context: result.first.context == null
          ? null
          : DecisionContext(
              workflowState: result.first.context!.workflowState,
              availableOptions: result.first.context!.availableOptions,
            ),
      options: result.first.options
          ?.map(
            (o) => DecisionOption(
              optionId: o.optionId,
              label: o.label,
              description: o.description,
              recommended: o.recommended,
            ),
          )
          .toList(),
      recommendation: result.first.recommendation,
      artifactRefs: result.first.artifactRefs
          ?.map(_artifactRefResponse)
          .toList(),
      blocking: result.first.blocking,
      requestedAt: result.first.requestedAt,
      expiration: result.first.expiration,
      choice: result.first.choice,
      decider: result.first.decider,
      rationale: result.first.rationale,
      resolvedAt: result.first.resolvedAt,
      signature: result.first.signature,
    );
  }

  Future<void> resolveDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
  }) async {
    final now = DateTime.now();
    await _client.workflowEndpoints.resolveDecision(
      decisionId: decisionId,
      choice: choice,
      decider: decider,
      rationale: rationale,
      algorithm: 'ed25519',
      publicKey: 'operator-pub-key',
      signature: 'operator-sig-${now.millisecondsSinceEpoch}',
      signedAt: now,
    );
    revision.value++;
  }

  WorkItemResponse _workItemResponse(WorkItemView m) {
    return WorkItemResponse(
      workItemId: m.workItemId,
      title: m.title,
      description: m.description,
      state: m.state,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
      completedAt: m.completedAt,
      blockingHumanDecisionId: m.blockingHumanDecisionId,
      artifactRefs: m.artifactRefs?.map(_artifactRefResponse).toList(),
    );
  }

  /// Maps a standing policy as the durable record the operator cites. Same
  /// shape whether listed (search) or created (resolution) — one model, no
  /// special casing.
  PolicyResponse _policyResponse(StandingPolicyView m) {
    return PolicyResponse(
      policyId: m.policyId,
      actions: m.actions,
      authorisingDecisionId: m.authorisingDecisionId,
      authorisedBy: m.authorisedBy,
      rationale: m.rationale,
      authorisedAt: m.authorisedAt,
      isRevoked: m.isRevoked,
      revokedBy: m.revokedBy,
      revocationReason: m.revocationReason,
    );
  }

  DecisionResponse _decisionResponse(DecisionView m) {
    return DecisionResponse(
      decisionId: m.decisionId,
      workItemId: m.workItemId,
      workItemTitle: m.workItemTitle,
      workItemDescription: m.workItemDescription,
      decisionType: m.decisionType,
      status: m.status,
      question: m.question,
      context: m.context == null
          ? null
          : DecisionContext(
              workflowState: m.context!.workflowState,
              availableOptions: m.context!.availableOptions,
            ),
      options: m.options
          ?.map(
            (o) => DecisionOption(
              optionId: o.optionId,
              label: o.label,
              description: o.description,
              recommended: o.recommended,
            ),
          )
          .toList(),
      recommendation: m.recommendation,
      blocking: m.blocking,
      requestedAt: m.requestedAt,
      expiration: m.expiration,
      artifactRefs: m.artifactRefs?.map(_artifactRefResponse).toList(),
      choice: m.choice,
      decider: m.decider,
      rationale: m.rationale,
      resolvedAt: m.resolvedAt,
      signature: m.signature,
    );
  }

  ArtifactRefResponse _artifactRefResponse(ArtifactReferenceView a) {
    return ArtifactRefResponse(
      artifactId: a.artifactId,
      artifactType: a.artifactType,
      uri: a.uri,
      provider: a.provider,
      contentHash: a.contentHash,
      description: a.description,
      createdAt: a.createdAt,
    );
  }
}

class OverviewResponse {
  OverviewResponse({
    required this.running,
    required this.waitingOnYou,
    required this.recentlyFinished,
    this.finishedPassed = 0,
    this.finishedFailed = 0,
    this.generatedAt,
    this.jobs = const [],
    this.machinesBusy = 0,
    this.machinesTotal = 0,
  });

  final int running;
  final int waitingOnYou;
  final int recentlyFinished;

  /// Successful terminal states inside [recentlyFinished].
  final int finishedPassed;

  /// Cancelled/terminated states inside [recentlyFinished].
  final int finishedFailed;

  /// Server clock when the snapshot was assembled. The freshness stamp is
  /// measured against this, not against the browser clock.
  final DateTime? generatedAt;

  /// Queued/running jobs for the "Machines and next steps" strip.
  final List<JobSummaryResponse> jobs;

  final int machinesBusy;
  final int machinesTotal;
}

class JobSummaryResponse {
  JobSummaryResponse({
    required this.jobId,
    required this.workItemId,
    required this.state,
    required this.jobType,
    required this.createdAt,
    this.availableAt,
    required this.blockedOnDecision,
    required this.attempt,
    required this.maxAttempts,
  });

  final String jobId;
  final String workItemId;

  /// Durable `JobState` name. Shown verbatim only in technical details.
  final String state;
  final String jobType;
  final DateTime createdAt;
  final DateTime? availableAt;

  /// True when a pending human decision is what holds this job up.
  final bool blockedOnDecision;
  final int attempt;
  final int maxAttempts;
}

class ArtifactRefResponse {
  ArtifactRefResponse({
    required this.artifactId,
    required this.artifactType,
    required this.uri,
    this.provider,
    this.contentHash,
    this.description,
    this.createdAt,
  });

  final String artifactId;
  final String artifactType;
  final String uri;
  final String? provider;
  final String? contentHash;
  final String? description;
  final DateTime? createdAt;
}

class WorkItemResponse {
  WorkItemResponse({
    required this.workItemId,
    required this.title,
    this.description,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.blockingHumanDecisionId,
    this.artifactRefs,
  });

  final String workItemId;
  final String title;
  final String? description;
  final String state;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final String? blockingHumanDecisionId;
  final List<ArtifactRefResponse>? artifactRefs;
}

class DecisionResponse {
  DecisionResponse({
    required this.decisionId,
    required this.workItemId,
    required this.workItemTitle,
    this.workItemDescription,
    required this.decisionType,
    required this.status,
    this.question,
    this.context,
    this.options,
    this.recommendation,
    required this.blocking,
    this.requestedAt,
    this.expiration,
    this.artifactRefs,
    this.choice,
    this.decider,
    this.rationale,
    this.resolvedAt,
    this.signature,
  });

  final String decisionId;
  final String workItemId;
  final String workItemTitle;

  /// Plain-language description of the gated work item, when recorded.
  final String? workItemDescription;
  final String decisionType;
  final String status;
  final String? question;
  final DecisionContext? context;
  final List<DecisionOption>? options;
  final String? recommendation;
  final bool blocking;
  final DateTime? requestedAt;
  final DateTime? expiration;
  final List<ArtifactRefResponse>? artifactRefs;
  final String? choice;
  final String? decider;
  final String? rationale;
  final DateTime? resolvedAt;
  final String? signature;
}

class DecisionContext {
  DecisionContext({
    required this.workflowState,
    required this.availableOptions,
  });

  final String workflowState;
  final List<String> availableOptions;
}

class DecisionOption {
  DecisionOption({
    required this.optionId,
    required this.label,
    this.description,
    required this.recommended,
  });

  final String optionId;
  final String label;
  final String? description;
  final bool recommended;
}

class WorkItemDetailResponse {
  WorkItemDetailResponse({
    required this.workItem,
    required this.transitionHistory,
  });

  final WorkItemResponse workItem;
  final List<TransitionResponse> transitionHistory;
}

class TransitionResponse {
  TransitionResponse({
    required this.transitionId,
    required this.workItemId,
    required this.fromState,
    required this.toState,
    required this.transitionedAt,
    this.reason,
  });

  final String transitionId;
  final String workItemId;
  final String fromState;
  final String toState;
  final DateTime transitionedAt;
  final String? reason;
}

class DecisionDetailResponse {
  DecisionDetailResponse({
    required this.decisionId,
    required this.workItemId,
    this.workItemTitle,
    this.workItemDescription,
    required this.decisionType,
    required this.status,
    this.question,
    this.context,
    this.options,
    this.recommendation,
    this.artifactRefs,
    required this.blocking,
    this.requestedAt,
    this.expiration,
    this.choice,
    this.decider,
    this.rationale,
    this.resolvedAt,
    this.signature,
  });

  final String decisionId;
  final String workItemId;

  /// Title of the gated work item, so the decision screen can name what is
  /// being decided rather than printing an id.
  final String? workItemTitle;

  /// Plain-language description of the gated work item, when recorded.
  final String? workItemDescription;
  final String decisionType;
  final String status;
  final String? question;
  final DecisionContext? context;
  final List<DecisionOption>? options;
  final String? recommendation;

  /// What the operator is being asked to approve.
  final List<ArtifactRefResponse>? artifactRefs;
  final bool blocking;
  final DateTime? requestedAt;
  final DateTime? expiration;
  final String? choice;
  final String? decider;
  final String? rationale;
  final DateTime? resolvedAt;
  final String? signature;
}

/// One row of the Products screen, read straight from durable registry state.
class ProductSummaryResponse {
  const ProductSummaryResponse({
    required this.productId,
    required this.name,
    required this.state,
    required this.allowsDispatch,
    this.activeBaselineId,
    this.activeBaselineRevision,
    this.pendingBaselineId,
    this.pendingBaselineRevision,
    required this.pendingBaselineVerified,
    required this.baselineFactCount,
    required this.openClarifications,
    required this.repositoryCount,
    required this.reachableRepositoryCount,
    required this.updatedAt,
  });

  final String productId;
  final String name;

  /// `ProductState` wire value.
  final String state;

  /// True only for `governed`. Mirrors `ProductState.allowsDispatch`.
  final bool allowsDispatch;

  /// The accepted baseline. A product without one is not governed.
  final String? activeBaselineId;
  final int? activeBaselineRevision;

  /// The candidate awaiting a human, when in `baseline_review`.
  final String? pendingBaselineId;
  final int? pendingBaselineRevision;

  /// Whether a worker attested to the pending candidate (AGENTS.md §12). The
  /// approval gate refuses to open without it.
  final bool pendingBaselineVerified;

  /// Count of recorded baseline *claims*, not files — the registry does not
  /// track file counts.
  final int baselineFactCount;

  final int openClarifications;
  final int repositoryCount;

  /// Repositories whose credential is both host-confirmed and verified.
  final int reachableRepositoryCount;

  final DateTime updatedAt;
}

/// Everything the Product Detail screen reads.
class ProductDetailResponse {
  const ProductDetailResponse({
    required this.productId,
    required this.name,
    this.description,
    required this.state,
    required this.allowsDispatch,
    required this.updatedAt,
    required this.repositories,
    required this.credentials,
    this.activeBaselineId,
    this.activeBaselineRevision,
    this.activeBaselineHash,
    this.activeBaselineAcceptedAt,
    this.activeBaselineAcceptedBy,
    required this.activeBaselineFactCount,
    this.pendingBaselineId,
    this.pendingBaselineRevision,
    required this.pendingBaselineVerified,
    required this.openClarifications,
    required this.policies,
  });

  final String productId;
  final String name;
  final String? description;
  final String state;
  final bool allowsDispatch;
  final DateTime updatedAt;
  final List<ProductRepositoryResponse> repositories;
  final List<CredentialResponse> credentials;
  final String? activeBaselineId;
  final int? activeBaselineRevision;
  final String? activeBaselineHash;
  final DateTime? activeBaselineAcceptedAt;
  final String? activeBaselineAcceptedBy;

  /// Recorded baseline claims, not files.
  final int activeBaselineFactCount;

  final String? pendingBaselineId;
  final int? pendingBaselineRevision;
  final bool pendingBaselineVerified;
  final List<ClarificationSummary> openClarifications;

  /// Active first, then revoked. Revoked policies are retained, not deleted.
  final List<PolicyResponse> policies;
}

class ProductRepositoryResponse {
  const ProductRepositoryResponse({
    required this.repositoryId,
    required this.uri,
    required this.kind,
    required this.provider,
  });

  final String repositoryId;
  final String uri;
  final String kind;
  final String provider;
}

/// A repository credential. Never carries key material.
class CredentialResponse {
  const CredentialResponse({
    required this.credentialId,
    required this.repositoryId,
    required this.referenceName,
    required this.fingerprint,
    required this.algorithm,
    required this.status,
    required this.hostKeyStatus,
    this.host,
    required this.canReachRepository,
    this.lastVerifiedAt,
    this.lastVerifiedBy,
    this.lastFailureReason,
    this.hostConfirmedAt,
    this.hostConfirmedBy,
  });

  final String credentialId;
  final String repositoryId;

  /// Name of the local secret-store entry. Never the value.
  final String referenceName;
  final String fingerprint;
  final String algorithm;
  final String status;
  final String hostKeyStatus;
  final String? host;

  /// Requires both a confirmed host and a proven connection.
  final bool canReachRepository;

  final DateTime? lastVerifiedAt;
  final String? lastVerifiedBy;
  final String? lastFailureReason;
  final DateTime? hostConfirmedAt;
  final String? hostConfirmedBy;
}

class ClarificationSummary {
  const ClarificationSummary({
    required this.clarificationId,
    required this.question,
    required this.section,
  });

  final String clarificationId;
  final String question;
  final String section;
}

class PolicyResponse {
  const PolicyResponse({
    required this.policyId,
    required this.actions,
    required this.authorisingDecisionId,
    required this.authorisedBy,
    required this.rationale,
    required this.authorisedAt,
    required this.isRevoked,
    this.revokedBy,
    this.revocationReason,
  });

  final String policyId;
  final List<String> actions;

  /// The gated decision that created this policy — the citation.
  final String authorisingDecisionId;
  final String authorisedBy;
  final String rationale;
  final DateTime authorisedAt;
  final bool isRevoked;
  final String? revokedBy;
  final String? revocationReason;
}
