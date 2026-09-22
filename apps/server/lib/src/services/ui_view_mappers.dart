import 'package:platform_contracts/platform_contracts.dart';

import '../generated/artifact_reference_view.dart';
import '../generated/baseline_fact_view.dart';
import '../generated/clarification_view.dart';
import '../generated/decision_context_view.dart';
import '../generated/decision_option_view.dart';
import '../generated/decision_view.dart';
import '../generated/job_summary_view.dart';
import '../generated/product_baseline_view.dart';
import '../generated/product_context_view.dart';
import '../generated/product_detail_view.dart';
import '../generated/repository_credential_view.dart';
import '../generated/standing_policy_view.dart';
import '../generated/product_summary_view.dart';
import '../generated/product_view.dart';
import 'control_plane_service.dart' show ProductDetail, ProductSummary;
import '../generated/repository_reference_view.dart';
import '../generated/work_item_view.dart';

/// Handwritten mapping from `platform_contracts` domain objects to the typed
/// Serverpod protocol response models that form the operator-UI wire contract.
///
/// Keeping the wire contract typed (Serverpod models) instead of raw
/// `Map<String, dynamic>` documents is what lets the generated client
/// deserialize responses without manual repair (see repository governance).
class UiViewMappers {
  UiViewMappers._();

  /// Projects a durable job onto the Overview "Machines and next steps" strip.
  ///
  /// [blockedOnDecision] is supplied by the caller because it is a fact about
  /// the job's *work item*, not about the job row itself.
  static JobSummaryView jobSummaryView(
    Job job, {
    required bool blockedOnDecision,
  }) {
    return JobSummaryView(
      jobId: job.jobId,
      workItemId: job.workItemId,
      state: job.state.wire,
      jobType: job.jobType.name,
      createdAt: job.createdAt,
      availableAt: job.availableAt,
      blockedOnDecision: blockedOnDecision,
      attempt: job.attempt,
      maxAttempts: job.maxAttempts,
    );
  }

  static WorkItemView workItemView(WorkItem item) {
    return WorkItemView(
      workItemId: item.workItemId,
      title: item.title,
      description: item.description,
      state: item.state.wire,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      completedAt: item.completedAt,
      blockingHumanDecisionId: item.blockingHumanDecisionId,
      artifactRefs: artifactRefs(item.artifactRefs),
    );
  }

  static List<ArtifactReferenceView>? artifactRefs(
    List<ArtifactReference>? refs,
  ) {
    if (refs == null) return null;
    return refs
        .map(
          (a) => ArtifactReferenceView(
            artifactId: a.artifactId,
            artifactType: a.artifactType.wire,
            uri: a.uri,
            provider: a.provider,
            contentHash: a.contentHash,
            description: a.description,
            createdAt: a.createdAt,
          ),
        )
        .toList();
  }

  static DecisionView decisionView({
    required HumanDecision decision,
    required WorkItem workItem,
  }) {
    return DecisionView(
      decisionId: decision.decisionId,
      workItemId: decision.workItemId,
      workItemTitle: workItem.title,
      workItemDescription: workItem.description,
      decisionType: decision.decisionType.wire,
      status: decision.status.wire,
      question: decision.question,
      context: decision.context == null
          ? null
          : DecisionContextView(
              workflowState: decision.context!.workflowState,
              availableOptions: decision.context!.availableOptions,
            ),
      options: decision.options
          ?.map(
            (o) => DecisionOptionView(
              optionId: o.optionId,
              label: o.label,
              description: o.description,
              recommended: o.recommended ?? false,
            ),
          )
          .toList(),
      recommendation: decision.recommendation,
      blocking: decision.blocking ?? false,
      requestedAt: decision.requestedAt,
      artifactRefs: artifactRefs(workItem.artifactRefs),
      choice: decision.choice?.wire,
      decider: decision.decider,
      rationale: decision.rationale,
      resolvedAt: decision.timestamp,
      signature: decision.signature?.signature,
    );
  }

  // ---------------------------------------------------------------------
  // Product registry (S-1)
  // ---------------------------------------------------------------------

  static ProductView productView(Product product) {
    return ProductView(
      productId: product.productId,
      name: product.name,
      description: product.description,
      manifestVersion: product.manifestVersion,
      // Every other enum on this surface emits its wire string; ProductState
      // only used .name because it had none until ADR 0018.
      state: product.state.wire,
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
      version: product.version,
    );
  }

  static ProductSummaryView productSummaryView(ProductSummary summary) {
    final product = summary.product;
    return ProductSummaryView(
      productId: product.productId,
      name: product.name,
      state: product.state.wire,
      // Mirrors ProductState.allowsDispatch rather than re-deriving it, so the
      // UI can never disagree with the engine about whether work may run.
      allowsDispatch: product.state.allowsDispatch,
      activeBaselineId: summary.accepted?.baselineId,
      activeBaselineRevision: summary.accepted?.revision,
      pendingBaselineId: summary.pending?.baselineId,
      pendingBaselineRevision: summary.pending?.revision,
      pendingBaselineVerified:
          summary.pending?.isIndependentlyVerified ?? false,
      baselineFactCount: summary.baselineFactCount,
      openClarifications: summary.openClarifications,
      repositoryCount: summary.repositoryCount,
      reachableRepositoryCount: summary.reachableRepositoryCount,
      updatedAt: product.updatedAt,
    );
  }

  static RepositoryCredentialView repositoryCredentialView(
    RepositoryCredential c,
  ) {
    return RepositoryCredentialView(
      credentialId: c.credentialId,
      repositoryId: c.repositoryId,
      // Reference name only — the private half is never in this payload.
      referenceName: c.referenceName,
      fingerprint: c.fingerprint,
      algorithm: c.algorithm,
      status: c.status.wire,
      hostKeyStatus: c.hostKeyStatus.wire,
      host: c.host,
      // Both halves of the trust chain, resolved by the domain rather than
      // re-derived here.
      canReachRepository: c.canReachRepository,
      lastVerifiedAt: c.lastVerifiedAt,
      lastVerifiedBy: c.lastVerifiedBy,
      lastFailureReason: c.lastFailureReason,
      hostConfirmedAt: c.hostConfirmedAt,
      hostConfirmedBy: c.hostConfirmedBy,
    );
  }

  static StandingPolicyView standingPolicyView(StandingPolicy p) {
    return StandingPolicyView(
      policyId: p.policyId,
      actions: p.actions.map((a) => a.wire).toList(),
      authorisingDecisionId: p.authorisingDecisionId,
      authorisedBy: p.authorisedBy,
      rationale: p.rationale,
      authorisedAt: p.authorisedAt,
      isRevoked: p.isRevoked,
      revokedAt: p.revokedAt,
      revokedBy: p.revokedBy,
      revocationReason: p.revocationReason?.wire,
    );
  }

  static ProductDetailView productDetailView(ProductDetail detail) {
    final context = detail.context;
    return ProductDetailView(
      product: productView(context.product),
      allowsDispatch: context.product.state.allowsDispatch,
      repositories: context.repositories
          .map(repositoryReferenceView)
          .toList(),
      credentials: detail.credentials
          .map(repositoryCredentialView)
          .toList(),
      activeBaseline: context.activeBaseline == null
          ? null
          : productBaselineView(context.activeBaseline!),
      pendingBaseline: detail.pendingBaseline == null
          ? null
          : productBaselineView(detail.pendingBaseline!),
      pendingBaselineVerified:
          detail.pendingBaseline?.isIndependentlyVerified ?? false,
      allBaselines: context.allBaselines.map(productBaselineView).toList(),
      openClarifications: context.openClarifications
          .map(clarificationView)
          .toList(),
      policies: detail.policies.map(standingPolicyView).toList(),
    );
  }

  static RepositoryReferenceView repositoryReferenceView(
    RepositoryReference repository,
  ) {
    return RepositoryReferenceView(
      repositoryId: repository.repositoryId,
      productId: repository.productId,
      kind: repository.kind.name,
      uri: repository.uri,
      provider: repository.provider.name,
      addedAt: repository.addedAt,
      version: repository.version,
    );
  }

  static BaselineFactView baselineFactView(BaselineFact fact) {
    return BaselineFactView(
      factId: fact.factId,
      section: fact.section.wire,
      claim: fact.claim,
      provenance: fact.provenance.wire,
      evidenceRefs: fact.evidenceRefs,
      assumptionNote: fact.assumptionNote,
      redacted: fact.redacted,
    );
  }

  static ProductBaselineView productBaselineView(ProductBaseline baseline) {
    return ProductBaselineView(
      baselineId: baseline.baselineId,
      productId: baseline.productId,
      revision: baseline.revision,
      status: baseline.status.wire,
      facts: baseline.facts.map(baselineFactView).toList(),
      contentHash: baseline.contentHash,
      contentHashVersion: baseline.contentHashVersion,
      supersedesBaselineId: baseline.supersedesBaselineId,
      proposedAt: baseline.proposedAt,
      reviewedAt: baseline.reviewedAt,
      acceptedAt: baseline.acceptedAt,
      acceptedBy: baseline.acceptedBy,
      acceptedDecisionId: baseline.acceptedDecisionId,
      createdAt: baseline.createdAt,
      updatedAt: baseline.updatedAt,
      version: baseline.version,
    );
  }

  static ClarificationView clarificationView(
    ClarificationRequest clarification,
  ) {
    return ClarificationView(
      clarificationId: clarification.clarificationId,
      productId: clarification.productId,
      onboardingId: clarification.onboardingId,
      section: clarification.section.wire,
      question: clarification.question,
      status: clarification.status.wire,
      answer: clarification.answer,
      createdAt: clarification.createdAt,
      answeredAt: clarification.answeredAt,
      answeredBy: clarification.answeredBy,
    );
  }

  static ProductContextView productContextView(ProductContext context) {
    return ProductContextView(
      product: productView(context.product),
      repositories: context.repositories.map(repositoryReferenceView).toList(),
      activeBaseline: context.activeBaseline == null
          ? null
          : productBaselineView(context.activeBaseline!),
      allBaselines: context.allBaselines.map(productBaselineView).toList(),
      openClarifications: context.openClarifications
          .map(clarificationView)
          .toList(),
      snapshotId: context.snapshotId,
    );
  }
}
