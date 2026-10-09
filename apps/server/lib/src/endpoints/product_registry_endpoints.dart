import 'dart:convert';

import 'package:platform_contracts/platform_contracts.dart'
    show
        BaselineFact,
        BaselineMaturity,
        HumanDecisionChoice,
        HumanDecision,
        DecisionSignature,
        PolicyAction,
        ProductManifest,
        ProductContracts,
        DesignContractSpec,
        QAContractSpec,
        DeploymentContractSpec,
        EvidenceKind,
        RepositoryKind,
        RepositoryProvider;
import 'package:product_registry/product_registry.dart'
    show ProductLifecycleAction;
import 'package:workflow_engine/workflow_engine.dart' show ProductGuard;
import 'package:serverpod/serverpod.dart';

import '../generated/clarification_view.dart';
import '../generated/decision_context_view.dart';
import '../generated/decision_option_view.dart';
import '../generated/decision_view.dart';
import '../generated/product_context_view.dart';
import '../generated/product_detail_view.dart';
import '../generated/repository_reference_added_view.dart';
import '../generated/standing_policy_view.dart';
import '../generated/product_summary_view.dart';
import '../generated/product_view.dart';
import '../services/control_plane_service.dart';
import '../services/ui_view_mappers.dart';
import 'package:platform_contracts/platform_contracts.dart'
    show BaselineSectionKey;

/// Endpoints for the durable Product registry and onboarding (S-1).
///
/// Every product-scoped read takes an explicit `productId`: there is no
/// implicit "current Product" on the server, so a client can never be handed
/// another Product's context by omitting a parameter (checkpoint 006 §2/§13).
///
/// The two write endpoints delegate to the durable engine — an endpoint never
/// sets state directly. `acceptBaseline` is the human baseline gate and binds
/// acceptance to the exact revision + contentHash the caller names.
class ProductRegistryEndpoints extends Endpoint {
  @override
  bool get logSessions => true;

  /// Lists every registered Product (global registry read).
  Future<List<ProductView>> listProducts(Session session) async {
    final service = ControlPlaneService(session);
    final products = await service.listProducts();
    return products.map(UiViewMappers.productView).toList();
  }

  /// One row per product for the Products list, with the baseline,
  /// clarification and credential-reachability counts already resolved.
  Future<List<ProductSummaryView>> listProductSummaries(Session session) async {
    final service = ControlPlaneService(session);
    final summaries = await service.listProductSummaries();
    return summaries.map(UiViewMappers.productSummaryView).toList();
  }

  /// Everything the Product Detail screen reads, in one call.
  Future<ProductDetailView> productDetail(
    Session session, {
    required String productId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final detail = await service.loadProductDetail(productId);
      return UiViewMappers.productDetailView(detail);
    } catch (error, stackTrace) {
      service.logger.error('product_registry.detail.failed', {
        'productId': productId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Loads the bounded `ProductContext(productId)`: exactly that Product and
  /// everything scoped to it. A scope mismatch is a fault, not a filter.
  Future<ProductContextView> productContext(
    Session session, {
    required String productId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final context = await service.loadProductContext(productId);
      return UiViewMappers.productContextView(context);
    } catch (error, stackTrace) {
      service.logger.error('product_registry.context.failed', {
        'productId': productId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Creates a durable baseline-approval decision bound to the exact current
  /// revision + contentHash. Returns the decision for the client to present to
  /// the human approver.
  Future<DecisionView> proposeBaseline(
    Session session, {
    required String productId,
    required List<BaselineFact> facts,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final decision = await service.proposeBaseline(
        productId: productId,
        facts: facts,
      );
      return _baselineApprovalDecisionView(decision);
    } catch (error, stackTrace) {
      service.logger.error(
        'product_registry.baseline_propose.failed',
        {
          'productId': productId,
          'error': error.toString(),
        },
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Creates a durable baseline-approval decision bound to the exact current
  /// revision + contentHash. Returns the decision for the client to present to
  /// the human approver.
  Future<DecisionView> requestBaselineApproval(
    Session session, {
    required String productId,
    required String baselineId,
    String? decisionId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final decision = await service.requestBaselineApproval(
        productId: productId,
        baselineId: baselineId,
        decisionId: decisionId,
      );
      return _baselineApprovalDecisionView(decision);
    } catch (error, stackTrace) {
      service.logger.error(
        'product_registry.baseline_approval.request_failed',
        {
          'productId': productId,
          'baselineId': baselineId,
          'error': error.toString(),
        },
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Raises the durable gate for a product lifecycle action.
  ///
  /// `action` is one of pause | resume | offboard | reinstate. The engine
  /// refuses up front if the transition could never be resolved, so a gate is
  /// never created that nobody can action.
  Future<DecisionView> requestLifecycleDecision(
    Session session, {
    required String productId,
    required String action,
    bool drainInFlight = true,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final decision = await service.requestLifecycleDecision(
        productId: productId,
        action: ProductLifecycleAction.fromWire(action),
        drainInFlight: drainInFlight,
      );
      return _baselineApprovalDecisionView(decision);
    } catch (error, stackTrace) {
      service.logger.error('product_registry.lifecycle.request_failed', {
        'productId': productId,
        'action': action,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Resolves a lifecycle gate. On approve the engine performs the
  /// transition, and refuses if a required guard was never established —
  /// offboarding with work still in flight, for example.
  Future<DecisionView> resolveLifecycleDecision(
    Session session, {
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    required String signature,
    required String publicKey,
    required String algorithm,
    required DateTime signedAt,
    bool noWorkInFlight = false,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final resolved = await service.resolveLifecycleDecision(
        decisionId: decisionId,
        choice: HumanDecisionChoice.fromWire(choice),
        decider: decider,
        rationale: rationale,
        signature: DecisionSignature(
          algorithm: algorithm,
          publicKey: publicKey,
          signature: signature,
          signedAt: signedAt,
        ),
        additionalGuards: noWorkInFlight
            ? const {ProductGuard.noWorkInFlight}
            : const {},
      );
      return _baselineApprovalDecisionView(resolved);
    } catch (error, stackTrace) {
      service.logger.error('product_registry.lifecycle.resolve_failed', {
        'decisionId': decisionId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Raises the gate that would create a standing policy (ADR 0019).
  ///
  /// `actions` may only contain push | merge. Production promotion, baseline
  /// approval and offboarding are non-delegable and are not expressible.
  Future<DecisionView> requestPolicyAuthorisation(
    Session session, {
    required String productId,
    required List<String> actions,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final decision = await service.requestPolicyAuthorisation(
        productId: productId,
        actions: actions.map(PolicyAction.fromWire).toList(),
      );
      return _baselineApprovalDecisionView(decision);
    } catch (error, stackTrace) {
      service.logger.error('product_registry.policy.request_failed', {
        'productId': productId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Resolves a policy gate. On approve a [StandingPolicy] is created citing
  /// this decision; any policy already live over the same scope is superseded.
  Future<StandingPolicyView?> resolvePolicyAuthorisation(
    Session session, {
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    required String signature,
    required String publicKey,
    required String algorithm,
    required DateTime signedAt,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final policy = await service.resolvePolicyAuthorisation(
        decisionId: decisionId,
        choice: HumanDecisionChoice.fromWire(choice),
        decider: decider,
        rationale: rationale,
        signature: DecisionSignature(
          algorithm: algorithm,
          publicKey: publicKey,
          signature: signature,
          signedAt: signedAt,
        ),
      );
      return policy == null ? null : UiViewMappers.standingPolicyView(policy);
    } catch (error, stackTrace) {
      service.logger.error('product_registry.policy.resolve_failed', {
        'decisionId': decisionId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Withdraws a standing policy. Revocation is itself recorded.
  Future<StandingPolicyView> revokeStandingPolicy(
    Session session, {
    required String productId,
    required String policyId,
    required String revokedBy,
  }) async {
    final service = ControlPlaneService(session);
    final revoked = await service.revokeStandingPolicy(
      productId: productId,
      policyId: policyId,
      revokedBy: revokedBy,
    );
    return UiViewMappers.standingPolicyView(revoked);
  }

  /// Resolves a baseline-approval decision. On approve, accepts the bound
  /// baseline; other choices record the resolution without acceptance.
  Future<DecisionView> resolveBaselineApproval(
    Session session, {
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    required String signature,
    required String publicKey,
    required String algorithm,
    required DateTime signedAt,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final resolved = await service.resolveBaselineApproval(
        decisionId: decisionId,
        choice: HumanDecisionChoice.fromWire(choice),
        decider: decider,
        rationale: rationale,
        signature: DecisionSignature(
          algorithm: algorithm,
          publicKey: publicKey,
          signature: signature,
          signedAt: signedAt,
        ),
      );
      return _baselineApprovalDecisionView(resolved);
    } catch (error, stackTrace) {
      service.logger.error(
        'product_registry.baseline_approval.resolve_failed',
        {
          'decisionId': decisionId,
          'error': error.toString(),
        },
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Reads the durable approval decision governing a baseline's exact current
  /// candidate, or 404 when none has been requested.
  Future<DecisionView> baselineApproval(
    Session session, {
    required String productId,
    required String baselineId,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final decision = await service.readBaselineApproval(
        productId: productId,
        baselineId: baselineId,
      );
      if (decision == null) {
        throw StateError(
          'No baseline approval decision found for '
          '$productId/$baselineId',
        );
      }
      return _baselineApprovalDecisionView(decision);
    } catch (error, stackTrace) {
      service.logger.error('product_registry.baseline_approval.read_failed', {
        'productId': productId,
        'baselineId': baselineId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  DecisionView _baselineApprovalDecisionView(HumanDecision decision) {
    // Baseline approval uses a synthetic scope as workItemId; we construct a
    // minimal DecisionView without requiring a real WorkItem.
    return DecisionView(
      decisionId: decision.decisionId,
      workItemId: decision.workItemId,
      workItemTitle: 'Product Baseline Approval',
      workItemDescription: decision.question,
      decisionType: decision.decisionType.wire,
      status: decision.status.wire,
      question: decision.question,
      context: decision.context == null
          ? null
          : DecisionContextView(
              workflowState: decision.context!.workflowState,
              availableOptions: decision.context!.availableOptions,
            ),
      options:
          decision.options
              ?.map(
                (o) => DecisionOptionView(
                  optionId: o.optionId,
                  label: o.label,
                  description: o.description,
                  recommended: o.recommended ?? false,
                ),
              )
              .toList() ??
          [],
      recommendation: decision.recommendation,
      blocking: decision.blocking ?? false,
      requestedAt: decision.requestedAt,
      choice: decision.choice?.wire,
      decider: decision.decider,
      rationale: decision.rationale,
      resolvedAt: decision.timestamp,
      signature: decision.signature?.signature,
    );
  }

  /// Answers a durable clarification, resuming the same onboarding lineage.
  Future<ClarificationView> answerClarification(
    Session session, {
    required String clarificationId,
    required String answer,
    required String answeredBy,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final answered = await service.answerClarification(
        clarificationId: clarificationId,
        answer: answer,
        answeredBy: answeredBy,
      );
      return UiViewMappers.clarificationView(answered);
    } catch (error, stackTrace) {
      service.logger.error('product_registry.answer_clarification.failed', {
        'clarificationId': clarificationId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Creates a new product with its manifest.
  Future<ProductDetailView> createProduct(
    Session session, {
    required String productId,
    required String name,
    String? description,
    String? manifestJson,
    String? manifestVersion,
  }) async {
    final service = ControlPlaneService(session);
    try {
      ProductManifest manifest;
      if (manifestJson == null ||
          manifestJson.trim().isEmpty ||
          manifestJson.trim() == '{}') {
        // Create a minimal default manifest for product registration
        final now = DateTime.now().toUtc();
        manifest = ProductManifest(
          productId: productId,
          name: name,
          version: '1.0.0',
          description: description,
          capabilities: const [],
          environments: const [],
          contracts: ProductContracts(
            workItemCategories: const [],
            designContract: DesignContractSpec(
              requiredArtifacts: const [],
              reviewers: const [],
              approvalThreshold: 1,
            ),
            qaContract: QAContractSpec(gates: const []),
            deploymentContract: DeploymentContractSpec(
              promotionPath: const [],
              approvalGates: const [],
            ),
          ),
          createdAt: now,
          updatedAt: now,
        );
      } else {
        manifest = ProductManifest.fromJson(
          jsonDecode(manifestJson) as Map<String, dynamic>,
        );
      }
      final product = await service.registerProductWithManifest(
        productId: productId,
        name: name,
        description: description,
        manifest: manifest,
        manifestVersion: manifestVersion,
      );
      final detail = await service.loadProductDetail(product.productId);
      return UiViewMappers.productDetailView(detail);
    } catch (error, stackTrace) {
      service.logger.error('product_registry.create.failed', {
        'productId': productId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Adds a repository reference to a product.
  ///
  /// THIS RETURN TYPE IS LOAD-BEARING, and it used to be
  /// `Future<Map<String, dynamic>>`.
  ///
  /// The Add Product flow calls this through
  /// `AddProductBloc._ensureProductAndRepository` immediately BEFORE
  /// `credentialEndpoints.generate`, in the same press of the same control
  /// (`add_product_page.dart:143` then `:147`). The old body was the NON-EMPTY
  /// map `{'success': true, 'repositoryId': …}`, and the generated client's
  /// `Protocol.deserialize<Map<String, dynamic>>` reads every value with
  /// `deserialize<dynamic>`, for which Serverpod registers nothing. So the
  /// request went out, the server answered 200, and the browser died in
  /// `parseData` at THIS call — the deploy key was never minted.
  ///
  /// An EMPTY map deserialises fine, which is the whole reason this defect class
  /// presents as intermittent and gets blamed on whichever endpoint happened to
  /// be nearest the symptom.
  Future<RepositoryReferenceAddedView> addRepositoryReference(
    Session session, {
    required String productId,
    required String repositoryId,
    required String uri,
    required String kind,
    required String provider,
  }) async {
    final service = ControlPlaneService(session);
    try {
      final ref = await service.addRepositoryReference(
        productId: productId,
        repositoryId: repositoryId,
        uri: uri,
        kind: RepositoryKind.fromWire(kind),
        provider: RepositoryProvider.fromWire(provider),
      );
      return RepositoryReferenceAddedView(
        success: true,
        repositoryId: ref.repositoryId,
      );
    } catch (error, stackTrace) {
      service.logger.error('product_registry.add_repo_ref.failed', {
        'productId': productId,
        'repositoryId': repositoryId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Records platform-verified evidence against a proposed baseline.
  Future<ProductDetailView> verifyBaseline(
    Session session, {
    required String productId,
    required String baselineId,
    required String verifiedBy,
    String kind = 'platform_verified_evidence',
  }) async {
    final service = ControlPlaneService(session);
    try {
      await service.verifyBaseline(
        productId: productId,
        baselineId: baselineId,
        verifiedBy: verifiedBy,
        kind: EvidenceKind.fromWire(kind),
      );
      final detail = await service.loadProductDetail(productId);
      return UiViewMappers.productDetailView(detail);
    } catch (error, stackTrace) {
      service.logger.error('product_registry.verify_baseline.failed', {
        'productId': productId,
        'baselineId': baselineId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Adds an operator-authored claim to a **proposed** baseline. Amending a
  /// baseline cancels any unresolved approval decision (new hash binding), so
  /// the client must request approval again against the new revision.
  Future<ProductDetailView> addHumanBaselineClaim(
    Session session, {
    required String productId,
    required String baselineId,
    required String section, // BaselineSectionKey.wire
    required String claim,
    required String author,
    List<String>? evidenceRefs,
    String?
    maturity, // BaselineMaturity.wire (e.g. 'implemented', 'policy', 'not_implemented')
  }) async {
    final service = ControlPlaneService(session);
    try {
      final updated = await service.addHumanBaselineClaim(
        productId: productId,
        baselineId: baselineId,
        section: BaselineSectionKey.fromWire(section),
        claim: claim,
        author: author,
        evidenceRefs: evidenceRefs ?? <String>[],
        maturity: maturity != null ? BaselineMaturity.fromWire(maturity) : null,
      );
      service.logger.info('endpoint.product_registry.baseline_human_claim', {
        'productId': productId,
        'baselineId': baselineId,
        'revision': updated.revision,
      });
      final detail = await service.loadProductDetail(productId);
      return UiViewMappers.productDetailView(detail);
    } catch (error, stackTrace) {
      service.logger.error('product_registry.add_human_claim.failed', {
        'productId': productId,
        'baselineId': baselineId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
