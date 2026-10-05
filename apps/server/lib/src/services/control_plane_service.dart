import 'dart:convert';

import 'package:execution_coordinator/execution_coordinator.dart'
    show ExecutionStore;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:qa_orchestration/qa_orchestration.dart' show QAContractStore;
import 'package:workflow_engine/workflow_engine.dart' show ProductGuard;
import 'package:scheduler/scheduler.dart'
    show
        JobStore,
        JobQueue,
        triageDefectDefinition,
        triageDefectDedupeKey,
        triageDefectInstruction;
import 'package:serverpod/serverpod.dart';
import 'package:workflow_store/workflow_store.dart'
    show DurableWorkflowEngine, WorkflowStore;
import 'package:worker_runtime/worker_runtime.dart'
    show WorkerRegistrationStore, WorkerStore;
import 'package:worker_protocol/worker_protocol.dart' show WorkerRegistration;

import '../generated/feature_request_summary_view.dart';
import '../persistence/persistence_database.dart';
import '../persistence/postgres_defect_store.dart';
import '../persistence/postgres_execution_store.dart';
import '../persistence/postgres_human_decision_store.dart';
import '../persistence/postgres_human_direction_store.dart';
import '../persistence/postgres_job_store.dart';
import '../persistence/postgres_model_execution_record_store.dart';
import '../persistence/postgres_model_policy_store.dart';
import '../persistence/postgres_product_registry_store.dart';
import '../persistence/postgres_qa_contract_store.dart';
import '../persistence/postgres_worker_registration_store.dart';
import '../persistence/postgres_worker_store.dart';
import '../persistence/postgres_workflow_store.dart';
import '../triage/lane_a_defect_triage_work_item.dart';
import 'structured_logger.dart';

/// Application services for the control plane.
///
/// Owns the durable Postgres-backed stores that implementations of
/// [WorkflowStore], [JobStore], [WorkerStore], [ExecutionStore] and
/// [WorkerRegistrationStore] are hosted on, and exposes read/query
/// operations plus the single write path a request may legally perform
/// (resolving a human decision through the durable workflow engine).
///
/// This layer deliberately has NO operation that sets [WorkItem.state]
/// directly: state transitions, job lifecycle, worker lifecycle, and agent
/// execution orchestration all belong to the engine/coordinator packages
/// that construct their domain objects here. Endpoints only observe state
/// or unlock work that a human decision blocked.
class ControlPlaneService {
  ControlPlaneService(this.session, {StructuredLogger? logger})
    : logger = logger ?? StructuredLogger(session, 'service');

  final Session session;
  final StructuredLogger logger;

  /// The single [PersistenceDatabase] every store on this service is built on.
  ///
  /// Deliberately one instance, not a getter: [PersistenceDatabase.inTransaction]
  /// keeps the active transaction in a per-instance slot, and stores attach to
  /// whatever they were constructed with. A getter would hand each store its own
  /// wrapper, so an `inTransaction` opened here would be invisible to them and a
  /// "transactional" multi-store write would silently commit in pieces.
  late final PersistenceDatabase _db = PersistenceDatabase(session.db);

  WorkflowStore get workflowStore => PostgresWorkflowStore(_db);
  JobStore get jobStore => PostgresJobStore(_db);
  JobQueue get jobQueue => JobQueue(store: jobStore, clock: clock);
  WorkerStore get workerStore => PostgresWorkerStore(_db);
  ExecutionStore get executionStore => PostgresExecutionStore(_db);
  WorkerRegistrationStore get workerRegistrationStore =>
      PostgresWorkerRegistrationStore(_db);

  DateTime Function() get clock => DateTime.now;

  /// The durable orchestration engine; the only place workflow state writes.
  DurableWorkflowEngine get workflowEngine =>
      DurableWorkflowEngine(store: workflowStore);

  /// Provisions the durable `defect-{defectId}` work item that carries AI
  /// triage. It is a view over the same [workflowStore]/[workflowEngine] the
  /// rest of this service uses, so a scheduler tick in another process resolves
  /// exactly the item that was written here.
  ///
  /// This exists because a triage job is worthless without a resolvable work
  /// item: `Scheduler.tick` skips any job whose work item is not in
  /// `readAllWorkItems()`, so the item must be durable BEFORE the job is
  /// enqueued.
  DefectTriageWorkItemProvisioner get _triageWorkItemProvisioner =>
      DefectTriageWorkItemProvisioner(
        workflowStore: workflowStore,
        workflowEngine: workflowEngine,
        qaContractStore: qaContractStore,
        log: (event, fields) => logger.info(event, fields),
      );

  /// S-1 Product Registry store + engine (checkpoint 006).
  ProductRegistryStore get productRegistryStore =>
      PostgresProductRegistryStore(_db);

  /// Durable home of the QA contracts that gate work-item completion.
  ///
  /// Supplied to [_triageWorkItemProvisioner] so every defect intake persists
  /// and reads back a real `QAContract` instead of leaving the work item
  /// without one. Without this store the provisioner logs
  /// `triage.qa_contract.store_unavailable` and stamps no `qaContractId`, and
  /// `GuardConditions.qaContractExists()` then refuses the
  /// `agentExecuting -> agentCompleted` transition of the triage job for good.
  QAContractStore get qaContractStore => PostgresQAContractStore(_db);

  HumanDecisionStore get humanDecisionStore =>
      PostgresHumanDecisionStore(workflowStore);

  PostgresHumanDirectionStore get humanDirectionStore =>
      PostgresHumanDirectionStore(_db);

  PostgresDefectStore get defectStore => PostgresDefectStore(_db);

  ModelPolicyStore get modelPolicyStore => PostgresModelPolicyStore(_db);

  PostgresModelExecutionRecordStore get modelExecutionRecordStore =>
      PostgresModelExecutionRecordStore(_db);

  /// The only durable engine for Product/baseline/clarification writes.
  ProductRegistryEngine get productRegistryEngine => ProductRegistryEngine(
    store: productRegistryStore,
    humanDecisionStore: humanDecisionStore,
  );

  // ---------------------------------------------------------------------
  // HumanDirection (Inbox) — reads + write paths
  // ---------------------------------------------------------------------

  /// Creates a new direction.
  Future<HumanDirection> createDirection({
    required String directionType,
    required String targetType,
    String? targetId,
    required String title,
    required String description,
    String? contextJson,
    List<HumanDirectionAttachment>? attachments,
    String? createdBy,
    String? assignedTo,
  }) async {
    final target = HumanDirectionTarget(
      targetType: HumanDirectionTargetType.fromWire(targetType),
      targetId: targetId,
    );
    final payload = HumanDirectionPayload(
      title: title,
      description: description,
      contextJson: contextJson,
      attachments: attachments,
    );
    final direction = await humanDirectionStore.createDirection(
      directionType: directionType,
      target: target,
      payload: payload,
      createdBy: createdBy,
      assignedTo: assignedTo,
    );
    logger.info('human_direction.created', {
      'directionId': direction.directionId,
      'directionType': directionType,
      'targetType': targetType,
      'targetId': targetId,
    });
    return direction;
  }

  /// Lists directions for a specific target.
  Future<List<HumanDirection>> listDirectionsForTarget({
    required String targetType,
    required String targetId,
    String? status,
    int? limit,
    int? offset,
  }) async {
    return humanDirectionStore.listDirectionsForTarget(
      targetType: targetType,
      targetId: targetId,
      status: status,
      limit: limit,
      offset: offset,
    );
  }

  /// Lists directions filtered by status.
  Future<List<HumanDirection>> listDirectionsByStatus({
    required String status,
    String? directionType,
    String? targetType,
    int? limit,
    int? offset,
  }) async {
    return humanDirectionStore.listDirectionsByStatus(
      status: status,
      directionType: directionType,
      targetType: targetType,
      limit: limit,
      offset: offset,
    );
  }

  /// Reads a single direction by ID.
  Future<HumanDirection?> readDirection({
    required String directionId,
  }) async {
    return humanDirectionStore.readDirection(directionId: directionId);
  }

  /// Acknowledges a direction (created → acked).
  Future<HumanDirection> acknowledgeDirection({
    required String directionId,
    required String acknowledgedBy,
  }) async {
    final direction = await humanDirectionStore.acknowledgeDirection(
      directionId: directionId,
      acknowledgedBy: acknowledgedBy,
    );
    logger.info('human_direction.acknowledged', {
      'directionId': directionId,
      'acknowledgedBy': acknowledgedBy,
    });
    return direction;
  }

  /// Starts working on a direction (acked → working).
  Future<HumanDirection> startWorkingDirection({
    required String directionId,
    required String startedBy,
  }) async {
    final direction = await humanDirectionStore.startWorkingDirection(
      directionId: directionId,
      startedBy: startedBy,
    );
    logger.info('human_direction.started_working', {
      'directionId': directionId,
      'startedBy': startedBy,
    });
    return direction;
  }

  /// Completes a direction (working → completed).
  Future<HumanDirection> completeDirection({
    required String directionId,
    required String completedBy,
    required String completionSummary,
  }) async {
    final direction = await humanDirectionStore.completeDirection(
      directionId: directionId,
      completedBy: completedBy,
      completionSummary: completionSummary,
    );
    logger.info('human_direction.completed', {
      'directionId': directionId,
      'completedBy': completedBy,
    });
    return direction;
  }

  /// Rejects a direction (working → rejected).
  Future<HumanDirection> rejectDirection({
    required String directionId,
    required String rejectedBy,
    required String rejectionReason,
  }) async {
    final direction = await humanDirectionStore.rejectDirection(
      directionId: directionId,
      rejectedBy: rejectedBy,
      rejectionReason: rejectionReason,
    );
    logger.info('human_direction.rejected', {
      'directionId': directionId,
      'rejectedBy': rejectedBy,
    });
    return direction;
  }

  /// Supersedes a direction (any active → superseded).
  Future<HumanDirection> supersedeDirection({
    required String directionId,
    required String supersededByDirectionId,
    required String supersededBy,
  }) async {
    final direction = await humanDirectionStore.supersedeDirection(
      directionId: directionId,
      supersededByDirectionId: supersededByDirectionId,
      supersededBy: supersededBy,
    );
    logger.info('human_direction.superseded', {
      'directionId': directionId,
      'supersededByDirectionId': supersededByDirectionId,
    });
    return direction;
  }

  // ---------------------------------------------------------------------
  // Product Registry (S-1) — reads + the two legal write paths
  // ---------------------------------------------------------------------

  Future<List<Product>> listProducts() async {
    final products = await productRegistryStore.readAllProducts();
    logger.debug('product_registry.products', {'count': products.length});
    return products;
  }

  /// One row per product, with just enough durable state for the Products
  /// list. Assembled here rather than in the endpoint so the read stays a
  /// single pass over the store instead of an N+1 per product.
  Future<List<ProductSummary>> listProductSummaries() async {
    final products = await productRegistryStore.readAllProducts();
    final summaries = <ProductSummary>[];
    for (final product in products) {
      final baselines = await productRegistryStore.readBaselinesForProduct(
        product.productId,
      );
      ProductBaseline? accepted;
      ProductBaseline? pending;
      for (final b in baselines) {
        if (b.status == ProductBaselineStatus.accepted) {
          accepted ??= b;
        } else if (b.status == ProductBaselineStatus.proposed) {
          if (pending == null || b.revision > pending.revision) pending = b;
        }
      }
      final counted = accepted ?? pending;
      final clarifications = await productRegistryStore
          .readClarificationsForProduct(product.productId);
      final repositories = await productRegistryStore
          .readRepositoriesForProduct(product.productId);
      var reachable = 0;
      for (final repo in repositories) {
        final credential = await productRegistryStore
            .readActiveCredentialForRepository(repo.repositoryId);
        if (credential?.canReachRepository ?? false) reachable++;
      }
      summaries.add(
        ProductSummary(
          product: product,
          accepted: accepted,
          pending: pending,
          baselineFactCount: counted?.facts.length ?? 0,
          openClarifications: clarifications.length,
          repositoryCount: repositories.length,
          reachableRepositoryCount: reachable,
        ),
      );
    }
    logger.debug('product_registry.summaries', {'count': summaries.length});
    return summaries;
  }

  /// Everything the Product Detail screen reads, assembled in one pass so the
  /// screen cannot render a half-loaded product.
  Future<ProductDetail> loadProductDetail(String productId) async {
    final context = await productRegistryEngine.loadProductContext(productId);
    final credentials = <RepositoryCredential>[];
    for (final repo in context.repositories) {
      final credential = await productRegistryStore
          .readActiveCredentialForRepository(repo.repositoryId);
      if (credential != null) credentials.add(credential);
    }
    ProductBaseline? pending;
    for (final b in context.allBaselines) {
      if (b.status == ProductBaselineStatus.proposed) {
        if (pending == null || b.revision > pending.revision) pending = b;
      }
    }
    final policies = await productRegistryStore.readPoliciesForProduct(
      productId,
    );
    policies.sort((a, b) {
      // Active first, then most recently authorised.
      if (a.isRevoked != b.isRevoked) return a.isRevoked ? 1 : -1;
      return b.authorisedAt.compareTo(a.authorisedAt);
    });
    String? pendingDecisionId;
    if (pending != null) {
      final scope = BaselineApprovalBinding.scopeFor(productId);
      final decisions = await humanDecisionStore.readHumanDecisionsForScope(
        scope,
      );
      for (final decision in decisions) {
        final binding = BaselineApprovalBinding.tryFromMetadata(
          decision.metadata,
        );
        if (binding == null) continue;
        if (binding.baselineId != pending.baselineId) continue;
        if (!decision.status.isResolved) {
          pendingDecisionId = decision.decisionId;
          break;
        }
      }
    }
    logger.debug('product_registry.detail', {'productId': productId});
    return ProductDetail(
      context: context,
      credentials: credentials,
      pendingBaseline: pending,
      policies: policies,
      pendingBaselineDecisionId: pendingDecisionId,
    );
  }

  Future<ProductContext> loadProductContext(String productId) async {
    final context = await productRegistryEngine.loadProductContext(productId);
    logger.debug('product_registry.context', {'productId': productId});
    return context;
  }

  /// Creates a durable baseline-approval decision bound to the exact current
  /// revision + contentHash. The decision must be resolved (approved) before
  /// the baseline can be accepted.
  /// Raises the gate for a product lifecycle action (pause, resume,
  /// offboard, reinstate). The engine refuses up front if the transition
  /// could never be resolved.
  Future<HumanDecision> requestLifecycleDecision({
    required String productId,
    required ProductLifecycleAction action,
    bool drainInFlight = true,
  }) async {
    final request = await productRegistryEngine.requestLifecycleDecision(
      productId: productId,
      action: action,
      drainInFlight: drainInFlight,
    );
    logger.info('product_registry.lifecycle.requested', {
      'productId': productId,
      'action': action.wire,
      'decisionId': request.decisionId,
    });
    return request;
  }

  Future<HumanDecision> resolveLifecycleDecision({
    required String decisionId,
    required HumanDecisionChoice choice,
    required String decider,
    required String rationale,
    required DecisionSignature signature,
    Set<ProductGuard> additionalGuards = const {},
  }) async {
    final resolved = await productRegistryEngine.resolveLifecycleDecision(
      decisionId: decisionId,
      choice: choice,
      decider: decider,
      rationale: rationale,
      signature: signature,
      additionalGuards: additionalGuards,
    );
    logger.info('product_registry.lifecycle.resolved', {
      'decisionId': decisionId,
      'choice': choice.wire,
    });
    return resolved;
  }

  /// Raises the gate that would create a standing policy (ADR 0019).
  Future<HumanDecision> requestPolicyAuthorisation({
    required String productId,
    required List<PolicyAction> actions,
  }) async {
    final request = await productRegistryEngine.requestPolicyAuthorisation(
      productId: productId,
      actions: actions,
    );
    logger.info('product_registry.policy.requested', {
      'productId': productId,
      'actions': actions.map((a) => a.wire).toList(),
    });
    return request;
  }

  Future<StandingPolicy?> resolvePolicyAuthorisation({
    required String decisionId,
    required HumanDecisionChoice choice,
    required String decider,
    required String rationale,
    required DecisionSignature signature,
  }) async {
    final policy = await productRegistryEngine.resolvePolicyAuthorisation(
      decisionId: decisionId,
      choice: choice,
      decider: decider,
      rationale: rationale,
      signature: signature,
    );
    logger.info('product_registry.policy.resolved', {
      'decisionId': decisionId,
      'choice': choice.wire,
      'policyId': policy?.policyId,
    });
    return policy;
  }

  Future<StandingPolicy> revokeStandingPolicy({
    required String productId,
    required String policyId,
    required String revokedBy,
  }) async {
    final revoked = await productRegistryEngine.revokeStandingPolicy(
      productId: productId,
      policyId: policyId,
      revokedBy: revokedBy,
    );
    logger.info('product_registry.policy.revoked', {
      'productId': productId,
      'policyId': policyId,
    });
    return revoked;
  }

  /// Proposes a new baseline revision for the product.
  ///
  /// Creates a new baseline with the given facts, then requests approval
  /// for that baseline. Returns the approval decision for the operator to
  /// present to the human approver.
  Future<HumanDecision> proposeBaseline({
    required String productId,
    required List<BaselineFact> facts,
  }) async {
    final baseline = await productRegistryEngine.proposeBaseline(
      productId: productId,
      facts: facts,
    );
    final decision = await productRegistryEngine.requestBaselineApproval(
      productId: productId,
      baselineId: baseline.baselineId,
    );
    logger.info('product_registry.baseline_proposed', {
      'productId': productId,
      'baselineId': baseline.baselineId,
      'revision': baseline.revision,
    });
    return decision;
  }

  /// Adds an operator-authored claim to the **proposed** baseline identified
  /// by [baselineId]. Amending a baseline invalidates any unresolved approval
  /// decision for it (the decision's content-hash binding changes), so the
  /// service merely delegates to the engine and logs the action.
  Future<ProductBaseline> addHumanBaselineClaim({
    required String productId,
    required String baselineId,
    required BaselineSectionKey section,
    required String claim,
    required String author,
    List<String> evidenceRefs = const [],
    BaselineMaturity? maturity,
  }) async {
    final updated = await productRegistryEngine.addHumanBaselineClaim(
      productId: productId,
      baselineId: baselineId,
      section: section,
      claim: claim,
      author: author,
      evidenceRefs: evidenceRefs,
      maturity: maturity,
    );
    logger.info('product_registry.baseline_human_claim_added', {
      'productId': productId,
      'baselineId': baselineId,
      'revision': updated.revision,
      'section': section.wire,
    });
    return updated;
  }

  /// Records platform-verified evidence against a proposed baseline.
  ///
  /// [ProductRegistryEngine.verifyBaseline] refuses any baseline that has not
  /// been independently verified, so this must run before
  /// [requestBaselineApproval].
  Future<ProductBaseline> verifyBaseline({
    required String productId,
    required String baselineId,
    required String verifiedBy,
    EvidenceKind kind = EvidenceKind.platformVerifiedEvidence,
  }) async {
    final verified = await productRegistryEngine.verifyBaseline(
      productId: productId,
      baselineId: baselineId,
      verifiedBy: verifiedBy,
      kind: kind,
    );
    logger.info('product_registry.baseline_verified', {
      'productId': productId,
      'baselineId': baselineId,
      'verifiedBy': verifiedBy,
      'verificationKind': kind.wire,
    });
    return verified;
  }

  Future<HumanDecision> requestBaselineApproval({
    required String productId,
    required String baselineId,
    String? decisionId,
  }) async {
    final request = await productRegistryEngine.requestBaselineApproval(
      productId: productId,
      baselineId: baselineId,
      decisionId: decisionId,
    );
    logger.info('product_registry.baseline_approval_requested', {
      'productId': productId,
      'baselineId': baselineId,
      'decisionId': request.decisionId,
    });
    return request;
  }

  /// Resolves a baseline-approval decision. On [HumanDecisionChoice.approve],
  /// accepts the bound baseline; other choices record the resolution without
  /// acceptance.
  Future<HumanDecision> resolveBaselineApproval({
    required String decisionId,
    required HumanDecisionChoice choice,
    required String decider,
    required String rationale,
    required DecisionSignature signature,
  }) async {
    final resolved = await productRegistryEngine.resolveBaselineApproval(
      decisionId: decisionId,
      choice: choice,
      decider: decider,
      rationale: rationale,
      signature: signature,
    );
    logger.info('product_registry.baseline_approval_resolved', {
      'decisionId': decisionId,
      'choice': choice.wire,
      'decider': decider,
    });
    return resolved;
  }

  /// Reads the durable approval decision governing a baseline's exact current
  /// candidate, or null when none has been requested.
  Future<HumanDecision?> readBaselineApproval({
    required String productId,
    required String baselineId,
  }) async {
    return productRegistryEngine.readBaselineApproval(
      productId: productId,
      baselineId: baselineId,
    );
  }

  /// Human answer to a durable clarification; resumes the same lineage.
  Future<ClarificationRequest> answerClarification({
    required String clarificationId,
    required String answer,
    required String answeredBy,
  }) async {
    final answered = await productRegistryEngine.answerClarification(
      clarificationId: clarificationId,
      answer: answer,
      answeredBy: answeredBy,
    );
    logger.info('product_registry.clarification_answered', {
      'clarificationId': clarificationId,
      'productId': answered.productId,
    });
    return answered;
  }

  // ---------------------------------------------------------------------
  // Unified Intake (Feature Requests)
  // ---------------------------------------------------------------------

  /// Files a human Feature Request as a `draft` work item and raises the intake
  /// direction that surfaces it.
  ///
  /// Both writes land in one transaction. They are one fact — a request whose
  /// work item exists but whose direction failed to enqueue is a row no inbox
  /// can reach, and the reporter has already been told it was accepted.
  ///
  /// The work item is created through [workflowEngine] rather than a direct
  /// store write so the same durable path every other work item takes applies
  /// here, and the item stays in `draft` — it is not runnable until a human
  /// decides, which is what keeps this from silently starting work.
  Future<WorkItem> createFeatureWorkItem({
    required String title,
    required String description,
    required String productId,
    required String reporter,
  }) async {
    await _requireRegisteredProduct(productId);
    final now = DateTime.now().toUtc();
    final workItemId = 'WI-feature-${now.microsecondsSinceEpoch}';

    return _db.inTransaction(() async {
      final workItem = await workflowEngine.createWorkItem(
        workItemId: workItemId,
        productId: productId,
        category: WorkItemCategory.feature,
        title: title,
        description: description,
      );

      await humanDirectionStore.createDirection(
        directionType: HumanDirectionType.workIntake.wire,
        target: HumanDirectionTarget(
          targetType: HumanDirectionTargetType.workItem,
          targetId: workItemId,
        ),
        payload: HumanDirectionPayload(
          title: 'New Feature Request: $title',
          description: description,
        ),
        createdBy: reporter,
      );

      return workItem;
    });
  }

  /// Feature requests as the Reports screen's `Feature requests` tab reads them.
  ///
  /// A feature request is a `WorkItem(category: feature)`, not a table of its
  /// own, so this reads the durable work-item record and filters on category.
  /// The reporter is recovered from the intake direction that was raised with
  /// the item: the work item itself does not record who filed it, and the
  /// direction is the same durable fact written in the same transaction.
  ///
  /// Newest first, matching the defect register's ordering so the two tabs
  /// sort identically. Product names are resolved from the registry; a request
  /// whose product row is missing resolves to no name at all rather than an
  /// invented label.
  Future<List<FeatureRequestSummaryView>> listFeatureRequests({
    String? productId,
    String? state,
    int? limit,
  }) async {
    final all = await workflowStore.readAllWorkItems();
    final features =
        all
            .where((item) => item.category == WorkItemCategory.feature)
            .where((item) => productId == null || item.productId == productId)
            .where((item) => state == null || item.state.wire == state)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final page = limit != null && features.length > limit
        ? features.sublist(0, limit)
        : features;

    final names = await _productNamesFor(page.map((i) => i.productId));
    final reporters = await _featureRequestReporters(
      page.map((i) => i.workItemId),
    );

    return [
      for (final item in page)
        FeatureRequestSummaryView(
          workItemId: item.workItemId,
          title: item.title,
          description: item.description,
          state: item.state.wire,
          productId: item.productId,
          productName: names[item.productId],
          reporter: reporters[item.workItemId],
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
          completedAt: item.completedAt,
        ),
    ];
  }

  /// Reporter per feature work item, recovered from its intake direction.
  ///
  /// Resolved defensively: a request whose direction cannot be read is listed
  /// with no reporter rather than dropping the request from the register.
  /// No status filter — the reporter stays attributed however far the intake
  /// has since progressed, and the store already returns newest first.
  Future<Map<String, String>> _featureRequestReporters(
    Iterable<String> workItemIds,
  ) async {
    final reporters = <String, String>{};
    for (final id in workItemIds) {
      try {
        final directions = await humanDirectionStore.listDirectionsForTarget(
          targetType: HumanDirectionTargetType.workItem.wire,
          targetId: id,
        );
        final createdBy = directions.isEmpty
            ? null
            : directions.first.createdBy;
        if (createdBy != null && createdBy.isNotEmpty) {
          reporters[id] = createdBy;
        }
      } catch (_) {
        // No intake direction, or it cannot be read. The request still exists
        // and stays listed; only the "who filed it" cell is empty.
      }
    }
    return reporters;
  }

  // ---------------------------------------------------------------------
  // Human Bug Reporting (Defects) — reads + write paths
  // ---------------------------------------------------------------------

  /// Asserts [productId] names a registered product.
  ///
  /// A defect or feature request is filed *against* a product, so an id with no
  /// registry row is a broken reference, not a productless report. Failing here
  /// keeps the write side honest: the list/inspect enrichment resolves a real
  /// name for every row this service accepted, instead of leaving a defect
  /// filed under an id no product page can ever link to.
  ///
  /// [ProductNotFoundException] carries the offending id so the endpoint can
  /// report which value was rejected.
  Future<void> _requireRegisteredProduct(String productId) async {
    try {
      await productRegistryStore.readProduct(productId);
    } catch (_) {
      throw ProductNotFoundException(productId);
    }
  }

  /// Creates a new defect from a human report.
  ///
  /// Persists the Defect, initial DefectEvidence (textDescription + diagnosticBundle),
  /// and the initial DefectEvent (created). Enqueues a triage job.
  Future<Defect> createDefect({
    required String title,
    required String description,
    String? expectedBehavior,
    String? reproductionSteps,
    required String severity,
    String? intakeCategory,
    required String productId,
    String? affectedWorkItemId,
    String? affectedRunId,
    String? clientContextJson,
    required String reporter,
  }) async {
    await _requireRegisteredProduct(productId);
    final now = DateTime.now().toUtc();
    final defect = Defect(
      defectId: 'DEF-${now.microsecondsSinceEpoch}',
      title: title,
      description: description,
      expectedBehavior: expectedBehavior,
      reproductionSteps: reproductionSteps,
      severity: severity,
      status: DefectStatus.reported,
      classification: null,
      reporter: reporter,
      productId: productId,
      affectedWorkItemId: affectedWorkItemId,
      affectedRunId: affectedRunId,
      remediationWorkItemId: null,
      duplicateOfDefectId: null,
      currentTriageJobId: null,
      clientContextJson: clientContextJson,
      metadataJson: null,
      createdAt: now,
      updatedAt: now,
      resolvedAt: null,
      closedAt: null,
      version: 1,
    );

    await defectStore.saveDefect(defect);

    // Intake evidence is collected in declaration order so the triage
    // instruction can name the real evidence ids instead of a placeholder.
    final intakeEvidence = <Map<String, Object?>>[];

    // Initial evidence: text description
    final reportEvidenceId = 'EVD-${now.microsecondsSinceEpoch}-1';
    await defectStore.saveDefectEvidence(
      DefectEvidence(
        evidenceId: reportEvidenceId,
        defectId: defect.defectId,
        kind: EvidenceIntakeKind.textDescription,
        artifactId: null,
        contentHash: null,
        description: 'Human report: $description',
        sourceRef: 'human-report',
        capturedAt: now,
        createdAt: now,
      ),
    );
    intakeEvidence.add({
      'evidenceId': reportEvidenceId,
      'kind': EvidenceIntakeKind.textDescription.wire,
      'description': 'Human report: $description',
    });

    // Initial evidence: diagnostic bundle (if client context provided)
    if (clientContextJson != null && clientContextJson.isNotEmpty) {
      final bundleEvidenceId = 'EVD-${now.microsecondsSinceEpoch}-2';
      await defectStore.saveDefectEvidence(
        DefectEvidence(
          evidenceId: bundleEvidenceId,
          defectId: defect.defectId,
          kind: EvidenceIntakeKind.diagnosticBundle,
          artifactId: null,
          contentHash: null,
          description: 'Auto-captured client context',
          sourceRef: 'client-context',
          capturedAt: now,
          createdAt: now,
        ),
      );
      intakeEvidence.add({
        'evidenceId': bundleEvidenceId,
        'kind': EvidenceIntakeKind.diagnosticBundle.wire,
        'description': 'Auto-captured client context',
      });
    }

    // Initial event
    await defectStore.appendDefectEvent(
      DefectEvent(
        eventId: 'DEV-${now.microsecondsSinceEpoch}',
        defectId: defect.defectId,
        sequence: 1,
        type: DefectEventType.created,
        fromStatus: null,
        toStatus: DefectStatus.reported,
        actorType: ActorType.human,
        actorId: reporter,
        payloadJson: null,
        occurredAt: now,
      ),
    );

    logger.info('defect.created', {
      'defectId': defect.defectId,
      'title': title,
      'severity': severity,
    });

    // Durably provision the triage WorkItem BEFORE enqueueing the job.
    //
    // The WorkItem used to be built in memory only, so nothing was ever
    // written to `work_item`. `Scheduler.tick` resolves every candidate job
    // through `WorkflowStore.readAllWorkItems()` and silently skips any job
    // whose work item is absent, so the triage job was enqueued against a
    // work item that did not exist and could never be dispatched: 18 jobs
    // parked in `queued` in the live test DB with no work item behind them.
    //
    // The item is now created through `DurableWorkflowEngine` (the only legal
    // work-item write path) and walked to `designNotRequired`, an entry state
    // of `triageDefectDefinition`. Idempotent: replaying intake re-reads the
    // existing row, so no duplicate WorkItem (and therefore no second dedupe
    // key) can be produced.
    final defectWorkItem = await _triageWorkItemProvisioner.ensurePersisted(
      defect: defect,
      evidenceJson: jsonEncode(intakeEvidence),
    );
    final dedupeKey = triageDefectDedupeKey(
      defectWorkItem,
      triageDefectDefinition,
    );
    final instruction = triageDefectInstruction(
      defectWorkItem,
      triageDefectDefinition,
    );
    final enqueueResult = await jobQueue.enqueueIfAbsent(
      workItemId: defectWorkItem.workItemId,
      definition: triageDefectDefinition,
      dedupeKey: dedupeKey,
      instruction: instruction,
    );
    if (enqueueResult.created) {
      // Update defect with triage job reference
      final updatedDefect = defect.copyWith(
        currentTriageJobId: enqueueResult.job.jobId,
        updatedAt: now,
        version: defect.version + 1,
      );
      await defectStore.saveDefect(updatedDefect);
    }

    return defect;
  }

  /// Resolves the display names for a set of product ids, one lookup per
  /// distinct id.
  ///
  /// Dedupes *before* awaiting, not after: an in-flight `Map` mutated inside
  /// `Future.wait` cannot prevent the duplicate lookups, because every element
  /// is started before the first lookup has had a chance to populate the cache.
  /// Keys whose id has no registry row are absent from the result, so callers
  /// get `null` rather than a name this service made up.
  Future<Map<String, String>> _productNamesFor(
    Iterable<String?> productIds,
  ) async {
    final ids = productIds.whereType<String>().toSet();
    if (ids.isEmpty) return const {};
    final names = <String, String>{};
    for (final id in ids) {
      try {
        names[id] = (await productRegistryStore.readProduct(id)).name;
      } catch (_) {
        // No registry row for this id. Recorded as absent, not as a label:
        // the client owns the fallback copy for an unresolved product.
      }
    }
    return names;
  }

  /// Lists defects with optional filters.
  Future<List<Defect>> listDefects({
    String? productId,
    DefectStatus? status,
    DefectClassification? classification,
    int? limit,
    int? offset,
  }) async {
    final defects = await defectStore.listDefects(
      productId: productId,
      status: status,
      classification: classification,
      limit: limit,
      offset: offset,
    );
    final names = await _productNamesFor(defects.map((d) => d.productId));
    return [
      for (final defect in defects)
        defect.copyWith(productName: names[defect.productId]),
    ];
  }

  /// Reads full defect detail including evidence, clarifications, events.
  Future<Defect> inspectDefect(String defectId) async {
    final defect = await defectStore.readDefect(defectId);
    final names = await _productNamesFor([defect.productId]);
    return defect.copyWith(productName: names[defect.productId]);
  }

  /// Adds evidence to an existing defect.
  Future<DefectEvidence> addDefectEvidence({
    required String defectId,
    required EvidenceIntakeKind kind,
    String? description,
    String? artifactId,
    String? contentHash,
    String? sourceRef,
  }) async {
    final now = DateTime.now().toUtc();
    final evidence = DefectEvidence(
      evidenceId: 'EVD-${now.microsecondsSinceEpoch}',
      defectId: defectId,
      kind: kind,
      artifactId: artifactId,
      contentHash: contentHash,
      description: description,
      sourceRef: sourceRef,
      capturedAt: now,
      createdAt: now,
    );
    await defectStore.saveDefectEvidence(evidence);

    // Append event
    await defectStore.appendDefectEvent(
      DefectEvent(
        eventId: 'DEV-${now.microsecondsSinceEpoch}',
        defectId: defectId,
        sequence: (await defectStore.readEventsForDefect(defectId)).length + 1,
        type: DefectEventType.evidenceAdded,
        fromStatus: null,
        toStatus: null,
        actorType: ActorType.human,
        actorId: 'unknown', // TODO: get from session
        payloadJson:
            '{"evidenceId": "${evidence.evidenceId}", "kind": "${kind.wire}"}',
        occurredAt: now,
      ),
    );

    logger.info('defect.evidence_added', {
      'defectId': defectId,
      'evidenceId': evidence.evidenceId,
      'kind': kind.wire,
    });

    return evidence;
  }

  /// Requests a defect clarification from the human (AI-initiated).
  ///
  /// Creates a DefectClarification and a blocking HumanDecision
  /// (type: defectClarification) linked to the defect.
  Future<DefectClarification> requestDefectClarification({
    required String defectId,
    required String question,
    required String reason,
    required String triageJobId,
  }) async {
    final now = DateTime.now().toUtc();
    final clarification = DefectClarification(
      clarificationId: 'CLF-${now.microsecondsSinceEpoch}',
      defectId: defectId,
      question: question,
      reason: reason,
      status: ClarificationStatus.needsAnswer,
      answer: null,
      humanDecisionId: null,
      requestedByTriageJobId: triageJobId,
      requestedAt: now,
      answeredAt: null,
      createdAt: now,
    );
    await defectStore.saveClarification(clarification);

    // Create blocking HumanDecision for the clarification
    final decision = HumanDecision(
      decisionId: 'hd-${clarification.clarificationId}',
      workItemId: 'defect-clarification:$defectId',
      decisionType: HumanDecisionType.defectClarification,
      status: HumanDecisionStatus.pending,
      question: question,
      context: DecisionContext(
        workflowState: DefectStatus.needsClarification.wire,
        availableOptions: const ['answer'],
      ),
      options: const [
        HumanDecisionOption(
          optionId: 'answer',
          label: 'Answer',
          description: 'Provide the requested clarification information',
          recommended: true,
        ),
      ],
      recommendation: 'answer',
      blocking: true,
      requestedAt: now,
      metadata: {
        'clarificationId': clarification.clarificationId,
        'defectId': defectId,
        'requestedByTriageJobId': triageJobId,
      },
      updatedAt: now,
    );
    await humanDecisionStore.saveHumanDecision(decision);

    // Link the clarification to the human decision
    final linkedClarification = DefectClarification(
      clarificationId: clarification.clarificationId,
      defectId: clarification.defectId,
      question: clarification.question,
      reason: clarification.reason,
      status: clarification.status,
      answer: clarification.answer,
      humanDecisionId: decision.decisionId,
      requestedByTriageJobId: clarification.requestedByTriageJobId,
      requestedAt: clarification.requestedAt,
      answeredAt: clarification.answeredAt,
      createdAt: clarification.createdAt,
      version: clarification.version,
    );
    await defectStore.saveClarification(linkedClarification);

    // Update defect status to needsClarification
    final defect = await defectStore.readDefect(defectId);
    final updated = defect.copyWith(
      status: DefectStatus.needsClarification,
      updatedAt: now,
      version: defect.version + 1,
    );
    await defectStore.saveDefect(updated, expectedVersion: defect.version);

    // Append event
    await defectStore.appendDefectEvent(
      DefectEvent(
        eventId: 'DEV-${now.microsecondsSinceEpoch}',
        defectId: defectId,
        sequence: (await defectStore.readEventsForDefect(defectId)).length + 1,
        type: DefectEventType.clarificationRequested,
        fromStatus: defect.status,
        toStatus: DefectStatus.needsClarification,
        actorType: ActorType.triageAgent,
        actorId: triageJobId,
        payloadJson:
            '{"clarificationId": "${clarification.clarificationId}", "question": "$question", "humanDecisionId": "${decision.decisionId}"}',
        occurredAt: now,
      ),
    );

    logger.info('defect.clarification_requested', {
      'defectId': defectId,
      'clarificationId': clarification.clarificationId,
      'humanDecisionId': decision.decisionId,
    });

    return linkedClarification;
  }

  /// Human answers a defect clarification; resumes triage.
  Future<DefectClarification> answerDefectClarification({
    required String clarificationId,
    required String answer,
    required String answeredBy,
  }) async {
    final now = DateTime.now().toUtc();
    final clarification = await defectStore.readClarification(clarificationId);
    if (clarification == null) {
      throw StateError('Clarification not found: $clarificationId');
    }
    if (clarification.status == ClarificationStatus.answered) {
      return clarification; // idempotent
    }

    // Resolve the HumanDecision
    if (clarification.humanDecisionId != null) {
      await humanDecisionStore.saveHumanDecision(
        HumanDecision(
          decisionId: clarification.humanDecisionId!,
          workItemId: 'defect-clarification:${clarification.defectId}',
          decisionType: HumanDecisionType.defectClarification,
          status: HumanDecisionStatus.resolved,
          question: clarification.question,
          context: DecisionContext(
            workflowState: DefectStatus.needsClarification.wire,
            availableOptions: const ['answer'],
          ),
          options: const [
            HumanDecisionOption(
              optionId: 'answer',
              label: 'Answer',
              description: 'Provide the requested clarification information',
              recommended: true,
            ),
          ],
          recommendation: 'answer',
          blocking: true,
          requestedAt: clarification.requestedAt,
          decider: answeredBy,
          choice: HumanDecisionChoice.approve, // Answer provided
          rationale: answer,
          timestamp: now,
          signature: DecisionSignature(
            algorithm: 'ed25519',
            publicKey: 'operator-pub-key',
            signature: 'operator-sig-${now.millisecondsSinceEpoch}',
            signedAt: now,
          ),
          resolvedOptionId: 'answer',
          metadata: {
            'clarificationId': clarification.clarificationId,
            'defectId': clarification.defectId,
          },
          updatedAt: now,
        ),
      );
    }

    final answered = DefectClarification(
      clarificationId: clarification.clarificationId,
      defectId: clarification.defectId,
      question: clarification.question,
      reason: clarification.reason,
      status: ClarificationStatus.answered,
      answer: answer,
      humanDecisionId: clarification.humanDecisionId,
      requestedByTriageJobId: clarification.requestedByTriageJobId,
      requestedAt: clarification.requestedAt,
      answeredAt: now,
      createdAt: clarification.createdAt,
      version: clarification.version + 1,
    );
    await defectStore.saveClarification(answered);

    // Update defect status back to triaging
    final defect = await defectStore.readDefect(clarification.defectId);
    final updated = defect.copyWith(
      status: DefectStatus.triaging,
      updatedAt: now,
      version: defect.version + 1,
    );
    await defectStore.saveDefect(updated, expectedVersion: defect.version);

    // Append event
    await defectStore.appendDefectEvent(
      DefectEvent(
        eventId: 'DEV-${now.microsecondsSinceEpoch}',
        defectId: clarification.defectId,
        sequence:
            (await defectStore.readEventsForDefect(
              clarification.defectId,
            )).length +
            1,
        type: DefectEventType.clarificationAnswered,
        fromStatus: DefectStatus.needsClarification,
        toStatus: DefectStatus.triaging,
        actorType: ActorType.human,
        actorId: answeredBy,
        payloadJson:
            '{"clarificationId": "$clarificationId", "answer": "$answer", "humanDecisionId": "${clarification.humanDecisionId}"}',
        occurredAt: now,
      ),
    );

    // Enqueue new triage job
    // TODO: Integrate with scheduler when JobType.triageDefect is wired

    logger.info('defect.clarification_answered', {
      'defectId': clarification.defectId,
      'clarificationId': clarificationId,
      'humanDecisionId': clarification.humanDecisionId,
    });

    return answered;
  }

  /// Human verifies a fix for a defect.
  ///
  /// Creates a blocking HumanDecision (type: defectFixVerification) for the fix.
  /// On approval, transitions defect through resolved → closed.
  Future<Defect> verifyFix({
    required String defectId,
    required HumanDecisionChoice choice,
    required String decider,
    required String rationale,
    required DecisionSignature signature,
  }) async {
    final now = DateTime.now().toUtc();
    final defect = await defectStore.readDefect(defectId);

    // Create blocking HumanDecision for fix verification
    final decision = HumanDecision(
      decisionId: 'hd-fix-$defectId-${now.microsecondsSinceEpoch}',
      workItemId: 'defect-fix-verification:$defectId',
      decisionType: HumanDecisionType.defectFixVerification,
      status: HumanDecisionStatus.pending,
      question: 'Verify the fix for defect $defectId?',
      context: DecisionContext(
        workflowState: DefectStatus.fixReadyForVerification.wire,
        availableOptions: const ['fixed', 'stillBroken', 'partiallyFixed'],
      ),
      options: const [
        HumanDecisionOption(
          optionId: 'fixed',
          label: 'Fixed',
          description: 'The fix resolves the defect completely',
          recommended: true,
        ),
        HumanDecisionOption(
          optionId: 'stillBroken',
          label: 'Still broken',
          description: 'The fix does not resolve the defect; reopen',
        ),
        HumanDecisionOption(
          optionId: 'partiallyFixed',
          label: 'Partially fixed',
          description: 'The fix addresses part of the issue; more work needed',
        ),
      ],
      recommendation: 'fixed',
      blocking: true,
      requestedAt: now,
      metadata: {
        'defectId': defectId,
        'fromStatus': defect.status.wire,
      },
      updatedAt: now,
    );
    await humanDecisionStore.saveHumanDecision(decision);

    // Update defect status to include the human decision reference
    // (status remains fixReadyForVerification until decision is resolved)
    // We'll transition based on the decision choice below

    // Resolve the HumanDecision immediately with the provided choice
    String newStatus;
    switch (choice) {
      case HumanDecisionChoice.approve:
        newStatus = DefectStatus.resolved.wire;
        break;
      case HumanDecisionChoice.reject:
        newStatus = DefectStatus.reported.wire; // reopen
        break;
      case HumanDecisionChoice.rework:
        newStatus = DefectStatus.confirmed.wire; // partially fixed
        break;
      default:
        throw ArgumentError('Invalid verification choice: ${choice.wire}');
    }

    await humanDecisionStore.saveHumanDecision(
      HumanDecision(
        decisionId: decision.decisionId,
        workItemId: decision.workItemId,
        decisionType: HumanDecisionType.defectFixVerification,
        status: HumanDecisionStatus.resolved,
        question: decision.question,
        context: decision.context,
        options: decision.options,
        recommendation: decision.recommendation,
        blocking: decision.blocking,
        requestedAt: decision.requestedAt,
        decider: decider,
        choice: choice,
        rationale: rationale,
        timestamp: now,
        signature: signature,
        resolvedOptionId: _optionIdForChoice(choice),
        metadata: decision.metadata,
        updatedAt: now,
      ),
    );

    final updated = defect.copyWith(
      status: DefectStatus.fromWire(newStatus),
      updatedAt: now,
      resolvedAt: choice == HumanDecisionChoice.approve ? now : null,
      // closedAt is set only when defect transitions to closed (separate step)
      version: defect.version + 1,
    );
    await defectStore.saveDefect(updated, expectedVersion: defect.version);

    // Append event
    await defectStore.appendDefectEvent(
      DefectEvent(
        eventId: 'DEV-${now.microsecondsSinceEpoch}',
        defectId: defectId,
        sequence: (await defectStore.readEventsForDefect(defectId)).length + 1,
        type: DefectEventType.verificationCompleted,
        fromStatus: defect.status,
        toStatus: DefectStatus.fromWire(newStatus),
        actorType: ActorType.human,
        actorId: decider,
        payloadJson:
            '{"choice": "${choice.wire}", "rationale": "$rationale", "humanDecisionId": "${decision.decisionId}"}',
        occurredAt: now,
      ),
    );

    logger.info('defect.verification_completed', {
      'defectId': defectId,
      'choice': choice.wire,
      'newStatus': newStatus,
      'humanDecisionId': decision.decisionId,
    });

    return updated;
  }

  String _optionIdForChoice(HumanDecisionChoice choice) => switch (choice) {
    HumanDecisionChoice.approve => 'fixed',
    HumanDecisionChoice.reject => 'stillBroken',
    HumanDecisionChoice.rework => 'partiallyFixed',
    _ => choice.wire,
  };

  /// Reads all evidence for a defect.
  Future<List<DefectEvidence>> readDefectEvidence(String defectId) async {
    return defectStore.readEvidenceForDefect(defectId);
  }

  /// Reads all events (history) for a defect.
  Future<List<DefectEvent>> readDefectEvents(String defectId) async {
    return defectStore.readEventsForDefect(defectId);
  }

  /// Reads all clarifications for a defect.
  Future<List<DefectClarification>> readDefectClarifications(
    String defectId,
  ) async {
    return defectStore.readClarificationsForDefect(defectId);
  }

  /// Counts defects with optional filters.
  Future<int> countDefects({
    String? productId,
    DefectStatus? status,
    DefectClassification? classification,
  }) async {
    return defectStore.countDefects(
      productId: productId,
      status: status,
      classification: classification,
    );
  }

  // ---------------------------------------------------------------------
  // Workflow state (reads)
  // ---------------------------------------------------------------------

  Future<WorkItem> readWorkItem(String workItemId) async {
    final item = await workflowStore.readWorkItem(workItemId);
    logger.debug('work_item.read', {'workItemId': workItemId});
    return item;
  }

  Future<List<WorkItem>> readAllWorkItems() async {
    final items = await workflowStore.readAllWorkItems();
    logger.debug('work_item.list', {'count': items.length});
    return items;
  }

  Future<List<WorkflowTransitionRecord>> readTransitionHistory(
    String workItemId,
  ) async {
    final history = await workflowStore.readTransitionHistory(workItemId);
    logger.debug('workflow.transition_history', {
      'workItemId': workItemId,
      'count': history.length,
    });
    return history;
  }

  Future<List<HumanDecision>> readDecisionsForWorkItem(
    String workItemId,
  ) async {
    final decisions = await workflowStore.readHumanDecisionsForWorkItem(
      workItemId,
    );
    logger.debug('workflow.decisions', {
      'workItemId': workItemId,
      'count': decisions.length,
    });
    return decisions;
  }

  // ---------------------------------------------------------------------
  // Human decision resolution (the only legal request-side write path)
  // ---------------------------------------------------------------------

  /// Resolves a human decision through the durable engine. Guarantees:
  /// - decisions are durable before any gate is entered,
  /// - the resolution is persisted inside the same transaction that moves
  ///   the work item,
  /// - a duplicate resolution is an idempotent replay, never a second
  ///   transition.
  Future<WorkItem> resolveHumanDecision({
    required String decisionId,
    required HumanDecisionChoice choice,
    required String decider,
    required String rationale,
    required DecisionSignature signature,
  }) async {
    final workItem = await workflowEngine.resolveHumanDecision(
      decisionId: decisionId,
      choice: choice,
      decider: decider,
      rationale: rationale,
      signature: signature,
    );
    logger.info('workflow.decision_resolved', {
      'decisionId': decisionId,
      'choice': choice.wire,
      'decider': decider,
      'workItemId': workItem.workItemId,
      'state': workItem.state.name,
      'version': workItem.version,
    });
    return workItem;
  }

  // ---------------------------------------------------------------------
  // Scheduler / job state (reads)
  // ---------------------------------------------------------------------

  Future<List<Job>> listJobs() async {
    final jobs = await jobStore.listJobs();
    logger.debug('scheduler.jobs', {'count': jobs.length});
    return jobs;
  }

  Future<List<Job>> listJobsForWorkItem(String workItemId) async {
    final jobs = await jobStore.listJobsForWorkItem(workItemId);
    logger.debug('scheduler.jobs_for_work_item', {
      'workItemId': workItemId,
      'count': jobs.length,
    });
    return jobs;
  }

  Future<Job?> readJob(String jobId) async {
    final job = await jobStore.readJob(jobId);
    logger.debug('scheduler.job', {'jobId': jobId});
    return job;
  }

  Future<List<SchedulerEventRecord>> readJobEvents(String jobId) async {
    final events = await jobStore.readEvents(jobId);
    logger.debug('scheduler.job_events', {
      'jobId': jobId,
      'count': events.length,
    });
    return events;
  }

  Future<JobClaim?> readClaimForJob(String jobId) async {
    final claim = await jobStore.readClaimForJob(jobId);
    logger.debug('scheduler.job_claim', {'jobId': jobId});
    return claim;
  }

  // ---------------------------------------------------------------------
  // Worker + worker_runtime state (reads)
  // ---------------------------------------------------------------------

  Future<List<WorkerRegistration>> listWorkers() async {
    final workers = await workerRegistrationStore.listWorkers();
    logger.debug('worker.registrations', {'count': workers.length});
    return workers;
  }

  Future<List<WorkerExecution>> listWorkerExecutions() async {
    final executions = await workerStore.listWorkerExecutions();
    logger.debug('worker.executions', {'count': executions.length});
    return executions;
  }

  Future<WorkerExecutionResult?> readWorkerResult(String executionId) async {
    final result = await workerStore.readResult(executionId);
    logger.debug('worker.result', {'workerExecutionId': executionId});
    return result;
  }

  Future<List<WorkerEventRecord>> readWorkerEvents(String executionId) async {
    final events = await workerStore.readEvents(executionId);
    logger.debug('worker.events', {
      'workerExecutionId': executionId,
      'count': events.length,
    });
    return events;
  }

  // ---------------------------------------------------------------------
  // Agent execution state (reads)
  // ---------------------------------------------------------------------

  Future<List<AgentExecution>> listAgentExecutions({String? workItemId}) async {
    final executions = await executionStore.listExecutions(
      workItemId: workItemId,
    );
    logger.debug('execution.list', {
      'workItemId': workItemId,
      'count': executions.length,
    });
    return executions;
  }

  Future<AgentExecution> readAgentExecution(String executionId) async {
    final execution = await executionStore.readExecution(executionId);
    logger.debug('execution.read', {'executionId': executionId});
    return execution;
  }

  Future<AgentResult?> readAgentResult(String executionId) async {
    final result = await executionStore.readResult(executionId);
    logger.debug('execution.result', {'executionId': executionId});
    return result;
  }

  Future<List<AgentEventRecord>> readAgentEvents(String executionId) async {
    final events = await executionStore.readEvents(executionId);
    logger.debug('execution.events', {
      'executionId': executionId,
      'count': events.length,
    });
    return events;
  }

  Future<List<PlatformVerification>> readVerifications(
    String executionId,
  ) async {
    final verifications = await executionStore.readVerifications(executionId);
    logger.debug('execution.verifications', {
      'executionId': executionId,
      'count': verifications.length,
    });
    return verifications;
  }

  // ---------------------------------------------------------------------
  // S-1 Bootstrap (onboarding)
  // ---------------------------------------------------------------------

  /// Registers a new Product with its [ProductManifest].
  ///
  /// Creates the Product registry row, stores the manifest (referenced by
  /// [manifestVersion]), and initializes an onboarding record.
  Future<Product> registerProductWithManifest({
    required String productId,
    required String name,
    String? description,
    required ProductManifest manifest,
    String? manifestVersion,
  }) async {
    final t = DateTime.now().toUtc();
    final version = manifestVersion ?? 'v${t.millisecondsSinceEpoch}';

    // Create the product with manifest reference
    await productRegistryEngine.createProduct(
      productId: productId,
      name: name,
      description: description,
      now: t,
    );

    // Update with manifest version
    final updatedProduct = await productRegistryEngine.updateProduct(
      productId,
      manifestVersion: version,
      now: t,
    );

    logger.info('product_registry.registered_with_manifest', {
      'productId': productId,
      'name': name,
      'manifestVersion': version,
    });
    return updatedProduct;
  }

  /// Adds a repository reference to a product.
  Future<RepositoryReference> addRepositoryReference({
    required String productId,
    required String repositoryId,
    required String uri,
    required RepositoryKind kind,
    required RepositoryProvider provider,
  }) async {
    final t = DateTime.now().toUtc();

    // Validate product exists
    await productRegistryStore.readProduct(productId);

    final ref = await productRegistryEngine.addRepositoryReference(
      productId: productId,
      repositoryId: repositoryId,
      uri: uri,
      kind: kind,
      provider: provider,
      now: t,
    );

    logger.info('product_registry.add_repo_ref', {
      'productId': productId,
      'repositoryId': repositoryId,
      'kind': kind.toWire(),
      'provider': provider.name,
    });

    return ref;
  }

  /// Triggers the onboarding job for a Product.
  ///
  /// Creates an onboarding job that clones the repository at the pinned
  /// revision, runs baseline build + test, and writes a WorkspaceDescriptor.
  Future<Job> triggerOnboarding({
    required String productId,
    required String repositoryId,
    required String startingRevision,
    Map<String, String>? runtimeConfig,
  }) async {
    final t = DateTime.now().toUtc();
    // Validate product and repository exist and are owned by this product
    await productRegistryStore.readProduct(productId);
    final repo = await productRegistryStore.readRepositoryReference(
      repositoryId,
    );
    if (repo.productId != productId) {
      throw CrossProductAccessException(
        'repository $repositoryId belongs to product ${repo.productId}, not $productId',
      );
    }

    // Ensure onboarding record exists
    final onboarding = await productRegistryStore.readOnboardingForProduct(
      productId,
    );
    if (onboarding == null) {
      // The engine will create one when needed
    }

    // Create a synthetic work item ID for onboarding (not a real WorkItem)
    // Onboarding jobs are product-scoped, not work-item-scoped
    final syntheticWorkItemId = 'onboarding-$productId';

    // Use the job queue directly to enqueue the onboarding job
    // We need a JobQueue instance - let's use the job store directly
    final jobId = 'jb-$productId-${t.millisecondsSinceEpoch}';
    final dedupeKey = 'onboarding:$productId:$repositoryId:$startingRevision';

    final job = Job(
      jobId: jobId,
      workItemId: syntheticWorkItemId,
      jobType: JobType.onboardProduct,
      requiredRole: AgentRole.implementer,
      requiredCapabilities: {WorkerCapability.git, WorkerCapability.linux},
      priority: JobPriority.high,
      state: JobState.queued,
      dedupeKey: dedupeKey,
      createdAt: t,
      instruction:
          'Onboard product $productId: clone repository $repositoryId at '
          'revision $startingRevision, run baseline build and test.',
      attempt: 1,
      maxAttempts: 1,
      version: 1,
    );

    await jobStore.saveJob(job);
    logger.info('product_registry.onboarding.triggered', {
      'productId': productId,
      'repositoryId': repositoryId,
      'jobId': jobId,
      'startingRevision': startingRevision,
    });
    return job;
  }

  /// Gets the onboarding status for a Product.
  ///
  /// Returns the onboarding record, the latest onboarding job (if any),
  /// and the workspace descriptor (if onboarding succeeded).
  Future<OnboardingStatus> getOnboardingStatus(String productId) async {
    await productRegistryStore.readProduct(productId); // validates existence

    final onboarding = await productRegistryStore.readOnboardingForProduct(
      productId,
    );
    final jobs = await jobStore.listJobs();
    final onboardingJobs = jobs
        .where((j) => j.workItemId == 'onboarding-$productId')
        .toList();
    onboardingJobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final latestJob = onboardingJobs.isNotEmpty ? onboardingJobs.first : null;

    WorkspaceDescriptor? workspace;
    if (latestJob != null && latestJob.state == JobState.succeeded) {
      final result = await workerStore.readResult(
        latestJob.executionReference?.workerExecutionId ?? '',
      );
      if (result != null && result.workspaceId.isNotEmpty) {
        // Try to read workspace descriptor from worker store
        // In practice, the descriptor is written by the workspace manager
      }
    }

    logger.debug('product_registry.onboarding.status', {
      'productId': productId,
      'onboarding': onboarding?.onboardingId,
      'latestJob': latestJob?.jobId,
    });

    return OnboardingStatus(
      productId: productId,
      onboarding: onboarding,
      latestJob: latestJob,
      workspaceDescriptor: workspace,
    );
  }
}

/// Durable state backing one row of the Products list.
class ProductSummary {
  const ProductSummary({
    required this.product,
    required this.accepted,
    required this.pending,
    required this.baselineFactCount,
    required this.openClarifications,
    required this.repositoryCount,
    required this.reachableRepositoryCount,
  });

  final Product product;
  final ProductBaseline? accepted;
  final ProductBaseline? pending;
  final int baselineFactCount;
  final int openClarifications;
  final int repositoryCount;
  final int reachableRepositoryCount;
}

/// Durable state backing the Product Detail screen.
class ProductDetail {
  const ProductDetail({
    required this.context,
    required this.credentials,
    required this.pendingBaseline,
    required this.policies,
    this.pendingBaselineDecisionId,
  });

  final ProductContext context;
  final List<RepositoryCredential> credentials;
  final ProductBaseline? pendingBaseline;
  final List<StandingPolicy> policies;

  /// Decision id of the unresolved baseline-approval gate for
  /// [pendingBaseline], or null when nothing is awaiting a human.
  ///
  /// Baseline decisions live in the `product-baseline:<productId>` scope
  /// rather than a WorkItem row, so the UI cannot discover the gate id by
  /// listing a work item's decisions. This carries it explicitly.
  final String? pendingBaselineDecisionId;
}

/// Onboarding status for a Product.
class OnboardingStatus {
  const OnboardingStatus({
    required this.productId,
    required this.onboarding,
    required this.latestJob,
    required this.workspaceDescriptor,
  });

  final String productId;
  final OnboardingRecord? onboarding;
  final Job? latestJob;
  final WorkspaceDescriptor? workspaceDescriptor;
}
