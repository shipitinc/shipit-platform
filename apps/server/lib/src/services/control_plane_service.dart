import 'dart:convert';

import 'package:execution_coordinator/execution_coordinator.dart'
    show ExecutionStore;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart'
        // `product_registry` exports its own `ConcurrentModificationException`, as
        // does `postgres_defect_store` below and `workflow_store`. Three distinct
        // types share one name, so the work-item compare-and-swap this file retries
        // on is named by the single import that shows it below and hidden from the
        // two that would otherwise make it ambiguous.
        hide
        ConcurrentModificationException;
import 'package:qa_orchestration/qa_orchestration.dart'
    show
        QAContractStore,
        ProductQAContractDeclaration,
        ProductQAContractProvisioner,
        ProductQAContractSpecRefusal,
        ProductQAContractSpecStore,
        ProductQAContractSpecUnavailable;
import 'package:design_governance/design_governance.dart'
    show DesignGovernanceStore;
import 'package:workflow_engine/workflow_engine.dart' show ProductGuard;
import 'package:scheduler/scheduler.dart'
    show JobStore, JobQueue, onboardingJob, onboardingWorkItemId;
import 'package:serverpod/serverpod.dart';
import 'package:workflow_store/workflow_store.dart'
    show
        ConcurrentModificationException,
        DesignContractStore,
        DurableWorkflowEngine,
        WorkflowStore;
import 'package:worker_runtime/worker_runtime.dart'
    show WorkerRegistrationStore, WorkerStore;
import 'package:worker_protocol/worker_protocol.dart' show WorkerRegistration;

import '../baseline/durable_workspace_runtime.dart'
    show DurableWorkspaceRuntime;
import '../design/design_approval_handoff.dart' show DesignApprovalHandoff;
import '../design/design_review_recorder.dart'
    show
        designApprovalAbsentChoiceIsResolvable,
        designApprovalAbsentResolvableChoices;
import '../generated/feature_request_summary_view.dart';
import '../implementation/design_scope_grant.dart';
import '../persistence/persistence_database.dart';
import '../persistence/postgres_defect_store.dart'
        // See the note on the `product_registry` import: a same-named exception
        // lives here too, and this one is about a defect row, not a work item.
        hide
        ConcurrentModificationException;
import '../persistence/postgres_design_contract_store.dart';
import '../persistence/postgres_design_governance_store.dart';
import '../persistence/postgres_execution_store.dart';
import '../persistence/postgres_human_decision_store.dart';
import '../persistence/postgres_human_direction_store.dart';
import '../persistence/postgres_job_store.dart';
import '../persistence/postgres_model_execution_record_store.dart';
import '../persistence/postgres_model_policy_store.dart';
import '../persistence/postgres_product_registry_store.dart';
import '../persistence/postgres_product_qa_contract_spec_store.dart';
import '../persistence/postgres_qa_contract_store.dart';
import '../persistence/postgres_worker_registration_store.dart';
import '../persistence/postgres_worker_store.dart';
import '../persistence/postgres_workflow_store.dart';
import '../review/engineering_review_gate.dart'
    show verdictAbsentChoiceIsResolvable, verdictAbsentResolvableChoices;
import '../triage/lane_a_defect_triage_work_item.dart';
import '../triage/work_entry.dart';
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
///
/// ## There are now TWO request-side write paths, and both go through the engine
///
///  1. `resolveHumanDecision` — a human decision resolved through
///     `DurableWorkflowEngine.resolveHumanDecision`.
///  2. `WorkItemActionEndpoints` — the operator action surface on a work item
///     parked in a failure state (`retryFailedWorkItem` / `stopFailedWorkItem`),
///     which performs ONE durable transaction through
///     `DurableWorkflowEngine.operatorRetry` / `.transition` and deliberately
///     does not enqueue, dispatch or pre-check capacity.
///
/// The property that made the original comment true is unchanged and is what
/// still makes it true: neither path writes SQL, neither calls
/// `workflowStore.saveWorkItem` directly, and neither synthesises a transition
/// the workflow engine does not already permit. Adding a third path without
/// that would be the thing to refuse.
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

  /// The store `designContractExists()` confirms a work item's durable
  /// `designContractId` column against.
  ///
  /// Built over the SAME [_db] as every other store here, so the confirmation
  /// reads the same durable row the rest of the platform reads — and over the
  /// PostgreSQL implementation rather than an in-memory one, because confirming
  /// against process state a redeploy erases would satisfy a guard whose entire
  /// purpose is durability.
  DesignContractStore get designContractStore =>
      PostgresDesignContractStore(_db);

  /// The durable store for design governance (revisions, reviews, findings, events).
  ///
  /// Built over the SAME [_db] as every other store here, so the revision
  /// status updates read and write the same durable rows the rest of the
  /// platform reads. Implements [DesignRevisionStore] interface.
  DesignGovernanceStore get designGovernanceStore =>
      PostgresDesignGovernanceStore(_db);

  DateTime Function() get clock => DateTime.now;

  /// The durable orchestration engine; the only place workflow state writes.
  ///
  /// [designContractStore] is mounted here, not left to a caller, for the same
  /// reason `TriageProcessor` derives its QA-contract provisioner from `db`
  /// rather than accepting an injected one: an engine with no store mounted
  /// cannot take `planned -> designRequired` or the `designParked ->
  /// designRequired` release, so a deployment that forgot to wire it would
  /// refuse every design release **for the wrong reason** — "no store to ask"
  /// rather than "no contract on this item" — and the distinction is invisible
  /// on the row.
  DurableWorkflowEngine get workflowEngine => DurableWorkflowEngine(
    store: workflowStore,
    designContractStore: designContractStore,
  );

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

  /// The one work-entry operation, over the same stores this service already
  /// uses, so an item walked here resolves identically in the process that
  /// ticks the scheduler.
  ///
  /// A getter rather than a field for the same reason
  /// [_triageWorkItemProvisioner] is one: the stores are themselves views over
  /// the single [PersistenceDatabase] this service owns, and the trigger holds
  /// a [JobQueue] built from that store. Constructing it once and keeping it
  /// would work today and silently detach from the transaction slot the moment
  /// anything about how the stores are built changed.
  ///
  /// Both intake paths route through this rather than enqueueing themselves, so
  /// the `governed` dispatch gate has exactly one implementation. Adding a
  /// second check here would be the same gate decided twice, and two gates can
  /// disagree.
  WorkEntryTrigger get workEntryTrigger => WorkEntryTrigger(
    workflowStore: workflowStore,
    workflowEngine: workflowEngine,
    productRegistryEngine: productRegistryEngine,
    jobStore: jobStore,
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

  /// Durable home of the QA contract each PRODUCT declares.
  ///
  /// The other half of [qaContractStore]: that one holds the contracts that
  /// govern individual work items, this one holds the per-product declarations
  /// they are built from. Both were needed — the declaration table did not exist
  /// at all, and the declaration it would hold was being discarded on write by
  /// `registerProductWithManifest`, so no product could ever produce a
  /// contract for a non-triage work item to be governed by.
  ProductQAContractSpecStore get productQAContractSpecStore =>
      PostgresProductQAContractSpecStore(_db);

  /// Builds the contracts for work items on the paths that never had one.
  ///
  /// Over the same two stores the rest of this service uses, so a contract
  /// provisioned from a product's declaration resolves identically in whichever
  /// process provisions it. A getter for the same reason
  /// [_triageWorkItemProvisioner] is one: the stores are views over the single
  /// [PersistenceDatabase] this service owns.
  ProductQAContractProvisioner get _productQAContractProvisioner =>
      ProductQAContractProvisioner(
        contractStore: qaContractStore,
        specStore: productQAContractSpecStore,
      );

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
  Future<HumanDirection?> readDirection({required String directionId}) async {
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
    final lifecycleGate = await openLifecycleGate(productId);
    logger.debug('product_registry.detail', {
      'productId': productId,
      'openLifecycleGateId': lifecycleGate?.decisionId,
    });
    return ProductDetail(
      context: context,
      credentials: credentials,
      pendingBaseline: pending,
      policies: policies,
      pendingBaselineDecisionId: pendingDecisionId,
      pendingLifecycleGate: lifecycleGate,
    );
  }

  /// The oldest unresolved lifecycle gate for [productId], or null when none is
  /// open.
  ///
  /// Read from the decision store on every load rather than remembered from the
  /// call that raised it. That is the whole difference: a lifecycle decision
  /// hangs off the synthetic scope `product-lifecycle:<productId>`, which is
  /// not a WorkItem row, so `pendingDecisions()` and `recentDecisions()` cannot
  /// see it and this read is the ONLY way a client can find a gate it raised in
  /// an earlier session. A client that holds the gate in memory forgets it the
  /// moment the route is left, and a forgotten `blocking: true` gate cannot be
  /// raised again (`archived -> paused` is not an edge once the product has been
  /// offboarded) or listed or resolved by anything else.
  ///
  /// `readHumanDecisionsForScope` orders by `updatedAt ASC`, so the OLDEST open
  /// gate is returned. That is what makes an already-stranded product
  /// recoverable rather than merely detectable: resolving this one exposes the
  /// next on the following read, so the screen drains them in the order they
  /// were raised.
  ///
  /// The action comes from the decision's own `LifecycleDecisionBinding`
  /// metadata for the same reason — a screen that re-read only the id would not
  /// know whether the gate was raised under `no_work_in_flight`, and would
  /// either demand an attestation it does not need or skip one that it does.
  Future<OpenLifecycleGate?> openLifecycleGate(String productId) async {
    final decisions = await humanDecisionStore.readHumanDecisionsForScope(
      LifecycleDecisionBinding.scopeFor(productId),
    );
    for (final decision in decisions) {
      if (decision.status.isResolved) continue;
      final binding = LifecycleDecisionBinding.tryFromMetadata(
        decision.metadata,
      );
      // A decision recorded at this scope that is not a lifecycle binding is
      // not something this screen can action, and a binding naming another
      // product must never be shown here: it would let one product's operator
      // resolve another product's gate.
      if (binding == null || binding.productId != productId) continue;
      return OpenLifecycleGate(
        decisionId: decision.decisionId,
        action: binding.action,
        decision: decision,
      );
    }
    return null;
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

  /// Records what is known about a baseline's verification.
  ///
  /// **This is a SERVER-SIDE method, deliberately not reachable over RPC.**
  ///
  /// [ProductRegistryEngine.verifyBaseline] has two paths, and only one of them
  /// reaches `platformVerifiedEvidence`:
  ///
  ///  * no [reDerivation] — an identity alone is recorded as
  ///    [EvidenceKind.agentClaimedEvidence], which is real evidence of what was
  ///    asserted and never opens the human approval gate;
  ///  * a [reDerivation] proof that reproduces the stored hash — a platform
  ///    verification. The proof cannot be constructed without a recomputed
  ///    content hash, so there is nothing for a caller to assert instead.
  ///
  /// The `kind` parameter this used to take defaulted to
  /// [EvidenceKind.platformVerifiedEvidence], which made every caller that
  /// omitted it self-certify — and the same permissive value was hardcoded on
  /// the wire. There is no evidence kind here now: the KIND is a consequence of
  /// which path was taken, decided by the engine, not chosen by a caller.
  ///
  /// `verifiedBy` is deliberately NOT a required parameter. On the proof path it
  /// would be a second name for [PlatformReDerivationProof.verifiedBy], and
  /// accepting both is how one verification ends up attributed to two
  /// principals; the engine refuses that combination outright. The returned
  /// baseline carries the recorded `verifiedBy`, which is the only identity
  /// this record should quote.
  Future<ProductBaseline> verifyBaseline({
    required String productId,
    required String baselineId,
    PlatformReDerivationProof? reDerivation,
    String? verifiedBy,
  }) async {
    final verified = await productRegistryEngine.verifyBaseline(
      productId: productId,
      baselineId: baselineId,
      verifiedBy: verifiedBy,
      reDerivation: reDerivation,
    );
    logger.info('product_registry.baseline_verified', {
      'productId': productId,
      'baselineId': baselineId,
      // Quoted from the RETURNED baseline, not from the request, so the log
      // describes the principal that was actually recorded.
      'verifiedBy': verified.verifiedBy,
      'verificationKind': verified.verificationKind?.wire,
      // Stated rather than implied: whether this crossed a gate.
      'independentReDerivation': verified.isIndependentlyVerified,
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

  /// Metadata key on a feature work item whose QA contract could NOT be
  /// provisioned, carrying the named refusal reason.
  ///
  /// It is on the work item's own row and not only in a log line because the log
  /// is gone the next time the process restarts, while the row is what an
  /// operator meets when the item is refused at `agentExecuting -> agentCompleted`
  /// by `GuardConditions.qaContractExists()`. This is the same shape as lane E's
  /// `blockedBy` (`lane_e_design_remediation_work_item.dart`): a work item that
  /// cannot progress says WHY on itself, rather than leaving the reason to be
  /// inferred from the guard error alone.
  static const String featureQAContractBlockedByKey =
      'qaContractNotProvisioned';

  /// Metadata key carrying the full refusal message, including the product and
  /// the remedy.
  static const String featureQAContractBlockedByReasonKey =
      'qaContractNotProvisionedReason';

  /// Files a human Feature Request, raises the intake direction that surfaces
  /// it, and hands the new work item to the work-entry trigger.
  ///
  /// The work item and the direction land in one transaction. They are one fact
  /// — a request whose work item exists but whose direction failed to enqueue is
  /// a row no inbox can reach, and the reporter has already been told it was
  /// accepted. The trigger runs immediately after that transaction commits,
  /// because it cannot share it; see the note at the call site.
  ///
  /// The work item is created through [workflowEngine] rather than a direct
  /// store write so the same durable path every other work item takes applies
  /// here, and the trigger then decides how far it may travel: a feature is
  /// parked at `planned` with its reason recorded, because no consumer runtime
  /// exists that would read a feature triage result. It is never walked to an
  /// entry state, which is the only thing keeping the product-blind scheduler
  /// from triaging a feature as a defect.
  ///
  /// Per human decision `58bad3d1` a feature against a product that is not
  /// `governed` is ACCEPTED and PARKED, never refused. The intake direction is
  /// the human gate; a platform-lifecycle condition is not a reason to reject a
  /// request about it.
  ///
  /// ## WHY THE QA CONTRACT IS PROVISIONED HERE
  ///
  /// `WorkEntryTrigger` walks this item `planned -> designNotRequired`, and
  /// `designNotRequired` is an entry state of `triageDefectDefinition`, so the
  /// scheduler dispatches the item and an agent really runs. Completion is then
  /// refused by `GuardConditions.qaContractExists()`, which null-checks
  /// `context['qaContractId']` — and nothing on this path ever set one. That is
  /// the measured defect: 0 of the 4 non-triage work items carried a
  /// `qaContractId` where 10 of 10 triage items did.
  ///
  /// So the contract is provisioned from the PRODUCT's declared spec, inside
  /// this same transaction, and stamped on the item at creation. It goes here
  /// rather than downstream because that is where the contract becomes true, and
  /// the id handed to `createWorkItem` is the id of a row
  /// `provisionQAContract` read back — never a string invented to satisfy the
  /// guard.
  ///
  /// ## WHAT HAPPENS WHEN THE PRODUCT HAS DECLARED NOTHING
  ///
  /// Per [ProductQAContractSpecUnavailable], provisioning FAILS CLOSED with a
  /// named reason and no contract row is written. That refusal does NOT refuse
  /// the human's request: the same human decision `58bad3d1` that governs the
  /// lifecycle gate above governs this, and a missing QA declaration is a
  /// platform-side condition, not a reason to reject a request ABOUT the
  /// product. So the item is created, the named reason is recorded on it in
  /// [featureQAContractBlockedByKey] together with
  /// [featureQAContractBlockedByReasonKey], and it is logged. The consequence
  /// is unchanged from before this change and is now stated rather than
  /// discovered: such an item is refused at completion, and the reason it can
  /// name is the one on its own row.
  ///
  /// Refusing to CREATE the item instead is the other available choice and is
  /// deliberately not taken here: it would make the platform's missing
  /// configuration a veto over a human's request, which is the thing
  /// `58bad3d1` forbids. It is a governance call and is flagged as one.
  ///
  /// ## THE LANE'S PATH-OWNERSHIP GRANT
  ///
  /// [declaredOwnedPaths] is the set of repository-relative path globs the
  /// implementation lane that produces this item is GRANTED — the paths it may
  /// touch. The grant is a decision about the work, made BEFORE the work is
  /// known, and the QA gate judges the change against the grant. It therefore
  /// has to be a durable fact of the item, recorded when the item is created —
  /// not something reconstructed from the diff afterwards, which would be a
  /// claim made by the change itself.
  ///
  /// Empty is not "owns everything": an item with no grant grants nothing, and
  /// the gate that judges the grant refuses an empty owned set. The key is
  /// written either way, so a reader can tell "this item's lane was granted
  /// nothing" from "this item's record never carried a grant".
  Future<WorkItem> createFeatureWorkItem({
    required String title,
    required String description,
    required String productId,
    required String reporter,
    List<String> declaredOwnedPaths = const [],
  }) async {
    await _requireRegisteredProduct(productId);
    final now = DateTime.now().toUtc();
    final workItemId = 'WI-feature-${now.microsecondsSinceEpoch}';

    await _db.inTransaction(() async {
      // Inside the transaction, and BEFORE the item exists, so a contract that
      // cannot be provisioned leaves no half-created work item behind. The
      // provisioner opens no transaction of its own — it calls `saveWorkItem`/
      // `saveQAContract`/`readQAContract` directly — so this nests no worse
      // than `createWorkItem` below already does.
      final provisioned = await _provisionFeatureQAContract(
        productId: productId,
        workItemId: workItemId,
        now: now,
      );

      await workflowEngine.createWorkItem(
        workItemId: workItemId,
        productId: productId,
        category: WorkItemCategory.feature,
        title: title,
        description: description,
        // The id of a QA contract that was persisted AND read back, or null when
        // the product has declared none — in which case
        // [featureQAContractBlockedByKey] on this item's metadata says so by
        // name. Never a placeholder string.
        qaContractId: provisioned.contractId,
        // The `planning -> planned` hop is guarded by `planningEvidenceProvided`
        // (work_item_transitions.dart), which accepts `featureRef` OR
        // `requirementRef`. A feature request is its own requirement reference
        // and points at itself, so the reference is real rather than invented.
        // Without it the graph refuses the hop and the trigger answers
        // `NO_PLANNING_EVIDENCE` — the request would be accepted and then sit
        // at `planning` with no recorded reason for having stopped.
        featureRef: workItemId,
        // The QA-contract refusal keys (when there was one) and the lane's
        // path-ownership grant travel together: they are two facts about the
        // item that the rest of the platform reads off its metadata.
        metadata: {
          ...?provisioned.metadata,
          ...declaredOwnedPathsMetadata(declaredOwnedPaths),
        },
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
    });

    // The trigger runs AFTER this transaction commits, not inside it.
    //
    // `DurableWorkflowEngine.transition` opens its own transaction on the same
    // [PersistenceDatabase] this service owns, and `PersistenceDatabase
    // .inTransaction` refuses to nest — it throws `StateError` rather than
    // silently reusing the outer transaction. `createWorkItem` above is safe to
    // call inside only because it calls `saveWorkItem` directly and never opens
    // one. So the trigger cannot join this transaction, and pretending otherwise
    // would raise on every single feature request.
    //
    // Ordering is what keeps the guarantee this method needs: by the time the
    // trigger runs, the work item and the intake direction are durable, so a
    // request whose trigger does not reach a decision is still a recorded,
    // accepted request that the periodic sweep can find again — never a row
    // stranded mid-write.
    final parked = await _ensureWorkEntryConverging(
      workItemId: workItemId,
      kind: WorkEntryKind.featureIntake,
    );

    // The item as it now IS, not the `draft` snapshot taken before the trigger
    // ran. Returning a stale copy would tell the Reports screen the request is
    // sitting in `draft` while the durable row says `planned` with a recorded
    // reason — the reporting dishonesty this lane exists to close, in the one
    // place a human is about to read it.
    return parked.item;
  }

  /// Provisions the QA contract a feature work item is governed by, from the
  /// product's own declaration.
  ///
  /// Returns the contract on success. On failure it does NOT return null and it
  /// does NOT swallow the refusal: [ProductQAContractSpecUnavailable] is caught
  /// here, the ONLY place it is caught on this path, and what comes back instead
  /// is a null id plus the named reason written into the work item's metadata —
  /// so the "silent null" this method could be accused of is replaced by a
  /// recorded one, and the item cannot be mistaken for one that simply has no
  /// contract yet.
  ///
  /// A refusal is caught rather than propagated for the reason given on
  /// [createFeatureWorkItem]: refusing the work item would make a missing QA
  /// declaration a veto over a human's request, which human decision `58bad3d1`
  /// forbids for the lifecycle condition and which this lane does not extend to
  /// a second platform condition on its own authority.
  ///
  /// Anything that is NOT a [ProductQAContractSpecUnavailable] propagates
  /// untouched. A database failure, a malformed `gatesJson`, a store that
  /// returned the wrong id: none of those is "this product declared nothing",
  /// and collapsing them into the same recorded reason would hide a real fault
  /// behind a plausible-looking explanation.
  Future<FeatureQAContractProvisioning> _provisionFeatureQAContract({
    required String productId,
    required String workItemId,
    required DateTime now,
  }) async {
    try {
      final contract = await _productQAContractProvisioner.provisionForWorkItem(
        productId: productId,
        workItemCategory: WorkItemCategory.feature,
        workItemId: workItemId,
        now: now,
      );
      return FeatureQAContractProvisioning.provisioned(contract.contractId);
    } on ProductQAContractSpecUnavailable catch (refusal) {
      logger.info('feature_intake.qa_contract.not_provisioned', {
        'workItemId': workItemId,
        'productId': productId,
        'refusal': refusal.refusal.name,
        'reason': refusal.toString(),
      });
      return FeatureQAContractProvisioning.refused(
        refusal.refusal.name,
        refusal.toString(),
      );
    }
  }

  /// How many times an intake re-reads and retries when another writer wins the
  /// compare-and-swap on the work item.
  ///
  /// Three because the conflict is only ever produced by a concurrent writer
  /// advancing the same item, and each retry continues from wherever the winner
  /// left it — so the attempts converge rather than collide. A fourth attempt
  /// would be waiting on a writer that is not going to stop.
  static const int _workEntryConvergenceAttempts = 3;

  /// Drives [WorkEntryTrigger.ensureWorkEntry] to convergence, and returns the
  /// decision it reached together with the work item as it stands afterwards.
  ///
  /// `decision` is null only when every attempt lost its compare-and-swap; see
  /// the exhaustion boundary below.
  ///
  /// ## The contract this implements, and why retry-and-converge
  ///
  /// The trigger walks a work item through `DurableWorkflowEngine.transition`,
  /// which is a compare-and-swap that **rethrows**
  /// [ConcurrentModificationException] rather than retrying. Two callers walking
  /// the same item therefore cannot both win, and the loser would otherwise see
  /// that exception escape intake.
  ///
  /// A conflict is not a failure here, it is *another writer advancing the item
  /// towards the same goal*, so the correct response is to re-read and continue
  /// rather than to fail. Re-running is safe because the operation is
  /// idempotent by construction: every hop carries a fixed per-work-item
  /// idempotency key, and `JobQueue.enqueueIfAbsent` resolves a duplicate
  /// dedupe key to the winning job inside one transaction instead of minting a
  /// second one. The alternative — rethrow and let the periodic sweep retry —
  /// was rejected because it turns a benign race into a user-visible failure:
  /// intake has already committed the request and told the reporter it was
  /// accepted, so surfacing a conflict as an error contradicts a fact that is
  /// already on disk.
  ///
  /// Retrying is safe with respect to the store's transaction handling too, and
  /// not by luck: `PostgresWorkflowStore.saveWorkItem` issues
  /// `UPDATE ... WHERE "version" = @expected` and raises the conflict from the
  /// affected-row count **in Dart**, so no statement ever fails and Postgres
  /// never aborts a surrounding transaction. A conflict detected by a failed
  /// SQL statement would poison the transaction it was raised in and make a
  /// retry impossible; this one does not.
  ///
  /// ## The two boundaries this must not cross
  ///
  /// * **Only [ConcurrentModificationException] is retried.** A blanket catch
  ///   would let a `WorkflowTransitionRejectedException`, a store failure or a
  ///   rejected argument be retried and then reported as convergence — the
  ///   "everything is fine, nothing happened" outcome this path exists to
  ///   eliminate.
  /// * **Exhaustion is reported, never thrown.** By then the work item and the
  ///   intake direction are durable and the reporter has been told the request
  ///   was accepted; failing here would contradict a fact already on disk and
  ///   teach humans that our success message is unreliable. The
  ///   non-convergence is logged under a named event and the caller returns the
  ///   accepted item, leaving the periodic sweep as the backstop.
  ///
  /// Anything that is NOT a compare-and-swap conflict still propagates. A dead
  /// database is a real failure and answering it with a cheerful "accepted"
  /// would be its own kind of lie; the trigger's own refusals arrive as
  /// [WorkEntrySkipped] values rather than exceptions precisely so that the
  /// ordinary decisions never need this escape hatch.
  ///
  /// No new [WorkEntrySkipCodes] member is introduced for the exhausted case,
  /// and `work_entry.dart` states why: it is the one place work-entry codes
  /// live, and a code minted here would be a second spelling of the same
  /// vocabulary.
  Future<({WorkEntryDecision? decision, WorkItem item})>
  _ensureWorkEntryConverging({
    required String workItemId,
    required WorkEntryKind kind,
  }) async {
    for (var attempt = 1; attempt <= _workEntryConvergenceAttempts; attempt++) {
      // Re-read on every attempt, including the first. The point is to continue
      // from wherever the winning writer left the item, so continuing from a
      // snapshot taken before it moved would replay the same losing write.
      final current = await workflowStore.readWorkItem(workItemId);
      try {
        final decision = await workEntryTrigger.ensureWorkEntry(
          item: current,
          kind: kind,
        );
        // Re-read rather than trusting `current`: the trigger moves the item, so
        // the state that belongs in this log line is the one it left behind.
        final settled = await workflowStore.readWorkItem(workItemId);
        logger.info('work_entry.intake.decided', {
          'workItemId': workItemId,
          'kind': kind.name,
          'attempt': attempt,
          'state': settled.state.wire,
          'decision': decision.toString(),
          'code': decision.code,
        });
        return (decision: decision, item: settled);
      } on ConcurrentModificationException {
        // Someone else moved this item between the read above and the write
        // below. Nothing rolled back and nothing failed; the next iteration
        // continues from their result.
        logger.info('work_entry.intake_contended', {
          'workItemId': workItemId,
          'kind': kind.name,
          'attempt': attempt,
          'maxAttempts': _workEntryConvergenceAttempts,
          'action':
              'another writer advanced this work item; re-reading and '
              'continuing from where it now is',
        });
      }
    }

    logger.info('work_entry.intake_not_converged', {
      'workItemId': workItemId,
      'kind': kind.name,
      'attempts': _workEntryConvergenceAttempts,
      'action':
          'this request is durable and is returned as accepted; no triage job '
          'was enqueued by this path. NO SWEEP EXISTS YET to retry it, so the '
          'work item stays where it is until the work-entry sweep lands. '
          'Nothing is discarded, but nothing retries it either — read this as '
          '"recorded and not dispatched", not as "pending automatic retry".',
    });
    return (decision: null, item: await workflowStore.readWorkItem(workItemId));
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
  /// and the initial DefectEvent (created), then hands the durable triage work
  /// item to [WorkEntryTrigger.ensureWorkEntry], which decides whether a triage
  /// job may be created for this product at all.
  ///
  /// The report is always accepted and recorded. Whether it is also *dispatched*
  /// depends on the product being `governed` (human decision `1a8d9769`), and a
  /// defect that is not dispatched is a normal outcome with a recorded reason,
  /// not a failure of the submission. `currentTriageJobId` is therefore null on
  /// every outcome where no job exists, which is the honest report.
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

    // Durably provision the triage WorkItem BEFORE any job is enqueued, and
    // let the work-entry trigger decide whether this defect may be triaged.
    //
    // The WorkItem used to be built in memory only, so nothing was ever
    // written to `work_item`. `Scheduler.tick` resolves every candidate job
    // through `WorkflowStore.readAllWorkItems()` and silently skips any job
    // whose work item is absent, so the triage job was enqueued against a
    // work item that did not exist and could never be dispatched: 18 jobs
    // parked in `queued` in the live test DB with no work item behind them.
    // The item is therefore created through the provisioner, which is the only
    // place that resolves the QA contract, the description and the metadata the
    // triage instruction is built from.
    //
    // ## Why `ensurePersistedWithoutWalk` and not `ensurePersisted`
    //
    // This used to be `ensurePersisted` followed by an unconditional
    // `enqueueIfAbsent`. Both halves of that are gone, and the reason is that
    // they made the governed gate decorative.
    //
    // `ensurePersisted` walks the item to `designNotRequired`, which is an entry
    // state of `triageDefectDefinition`. Walking is the exposure: the triage
    // `Scheduler` is product-blind AND category-blind — `RunnableWorkEvaluator`
    // reads neither `item.productId` nor `item.category`, and `Scheduler.tick`
    // iterates every work item — so an item parked at an entry state is
    // enqueued on the next tick no matter what the product's state is. Gating
    // the enqueue while still walking would therefore have stopped nothing;
    // the scheduler would have re-created the job thirty seconds later.
    //
    // So the item is persisted PRE-WALK and handed to
    // `WorkEntryTrigger.ensureWorkEntry`, whose `governed` gate runs before its
    // own walk. That ordering is the whole of human decision `1a8d9769`: a
    // defect on an `offboarded` product is accepted and recorded, and no triage
    // job is created for it.
    //
    // The gate is NOT re-implemented here. It lives in the trigger, and the
    // trigger also owns the dedupe key, the instruction and the enqueue, so
    // intake and the periodic sweep cannot drift. A second check at this call
    // site would be the same gate decided twice, and two gates can disagree.
    final defectWorkItem = await _triageWorkItemProvisioner
        .ensurePersistedWithoutWalk(
          defect: defect,
          evidenceJson: jsonEncode(intakeEvidence),
        );
    final outcome = await _ensureWorkEntryConverging(
      workItemId: defectWorkItem.workItemId,
      kind: WorkEntryKind.defectTriage,
    );

    // Only a job that actually exists is recorded on the defect. Every other
    // outcome — gated, already triaged, a state no lane claims — leaves
    // `currentTriageJobId` null, which is the honest answer: the report was
    // accepted, and it is not currently being triaged.
    final decision = outcome.decision;
    final jobId = decision is WorkEntryEnqueued ? decision.jobId : null;
    if (jobId != null) {
      final updatedDefect = defect.copyWith(
        currentTriageJobId: jobId,
        updatedAt: now,
        version: defect.version + 1,
      );
      await defectStore.saveDefect(updatedDefect);
      return updatedDefect;
    }

    logger.info('defect.triage_not_enqueued', {
      'defectId': defect.defectId,
      'workItemId': defectWorkItem.workItemId,
      'code': decision?.code,
      'decision':
          decision?.toString() ?? 'no decision (intake did not converge)',
      'action':
          'the defect report is recorded and returned to the reporter; no '
          'triage job was created. Re-dispatch requires the work-entry sweep, '
          'which DOES NOT EXIST YET — until it lands, a gated defect stays '
          'gated and will not be picked up on its own.',
    });

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
      metadata: {'defectId': defectId, 'fromStatus': defect.status.wire},
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
  // The design/plan submission (the producer of the lane's path grant)
  // ---------------------------------------------------------------------

  /// Submits a design/plan for approval, carrying the SCOPING LANE's declared
  /// owned-path grant.
  ///
  /// ## WHY THIS EXISTS
  ///
  /// Decision `7d2a81f0` settled that the grant is made by whoever scoped the
  /// work: *"the work item's planner or designer records the owned globs when
  /// the item is scoped"*, and that it is *"recorded as a durable fact of the
  /// work item and read at dispatch"*.
  ///
  /// The READ half already existed; the WRITE half did not, and the consequence
  /// was that every production F2 evaluation refused with an empty owned set
  /// (ledger F-215). This method is that write half: it is the seam through
  /// which a plan is submitted for approval, and it carries the declared paths
  /// into the durable decision record as the DECLARATION.
  ///
  /// The declaration is promoted onto the work item by
  /// [resolveHumanDecision] when the plan is ACCEPTED — not here. A
  /// declaration is a proposal; a grant is an accepted fact, and the step that
  /// turns one into the other is the human-governed one.
  ///
  /// ## WHY THE DECLARATION IS NOT TAKEN FROM THE INTAKE REQUEST
  ///
  /// Because the requester of an intake form does not know the path layout.
  /// That is the decision's own words, and it is why the grant cannot be
  /// widened by a field on the intake form: it would be empty for most items,
  /// and empty still refuses, so most items would still queue. The scoping
  /// lane is the one actor in the lifecycle that both knows the layout and is
  /// accountable for the scope.
  ///
  /// ## WHY [declaredBy] IS REQUIRED
  ///
  /// A grant whose author is unknown is a grant nobody is accountable for.
  /// The platform has no business inventing an author, so it does not offer a
  /// default: the caller names the scoping lane, and an empty name is refused
  /// rather than recorded.
  Future<HumanDecision> requestDesignApproval({
    required String workItemId,
    required List<String> declaredOwnedPaths,
    required String question,
    required String declaredBy,
    List<HumanDecisionOption>? options,
    String? recommendation,
    HumanDecisionType decisionType = HumanDecisionType.designApproval,
    bool blocking = true,
    DateTime? declaredAt,
  }) async {
    if (declaredBy.trim().isEmpty) {
      throw ArgumentError.value(
        declaredBy,
        'declaredBy',
        'A design/plan submission must name the lane that scoped the work. '
            'The platform does not invent an author for a grant.',
      );
    }
    final now = declaredAt ?? clock();
    final decision = await workflowEngine.requestHumanDecision(
      workItemId: workItemId,
      decisionType: decisionType,
      question: question,
      options: options ?? designApprovalOptions,
      recommendation: recommendation,
      blocking: blocking,
      metadata: designScopeDeclarationMetadata(
        declaredOwnedPaths: declaredOwnedPaths,
        decisionType: decisionType,
        declaredBy: declaredBy.trim(),
        declaredAt: now,
      ),
    );
    logger.info('workflow.design_scope_declared', {
      'workItemId': workItemId,
      'decisionId': decision.decisionId,
      'decisionType': decisionType.wire,
      'declaredBy': declaredBy.trim(),
      'declaredPathCount': declaredOwnedPaths.length,
    });
    return decision;
  }

  // ---------------------------------------------------------------------
  // Human decision resolution (the only legal request-side write path)
  // ---------------------------------------------------------------------

  /// Resolves a human decision through the durable engine. Guarantees:
  /// - decisions are durable before any gate is entered,
  /// - the resolution is persisted inside the same transaction that moves
  ///   the work item,
  /// - a duplicate resolution is an idempotent replay, never a second
  /// transition.
  ///
  /// ## AND A VERDICT-LESS DECISION CANNOT BE RESOLVED AS A VERDICT
  ///
  /// `WorkflowEndpoints.resolveDecision` takes a `choice` off the wire and hands
  /// it straight to `HumanDecisionChoice.fromWire` — it never checks the choice
  /// against the decision's own `options`, because that is the shape every
  /// lifecycle gate in this platform already uses. So "the screen does not offer
  /// it" is a property of the screen and not of the record, and a request
  /// crafted against this method would answer `approve` on a decision raised
  /// precisely because NO reviewer approved anything.
  ///
  /// TWO guards close that, one per lane, and no others:
  ///
  ///  * [verdictAbsentChoiceIsResolvable] for an engineering-review decision
  ///    carrying `reviewVerdictAbsentMetadataKey`, which is the marker
  ///    `raiseVerdictAbsentDecision` writes; and
  ///  * [designApprovalAbsentChoiceIsResolvable] for a design-approval decision
  ///    carrying `designReviewVerdictAbsentMetadataKey`, which is the marker the
  ///    design recorder writes.
  ///
  /// Each is scoped deliberately — "every choice must be one of the decision's
  /// options" is a change to every lifecycle gate's behaviour and is not what
  /// decision `c495e02f-5c5d-4b45-8124-42ad0e90d6d4` asked for. What it asked
  /// for is that a decision carrying no verdict cannot be turned into one, and
  /// that is enforced here, before the engine writes anything. The design guard
  /// calls the recorder's own helper rather than re-deriving the choice set, so
  /// the menu the recorder documents and the menu this path enforces cannot
  /// drift.
  Future<WorkItem> resolveHumanDecision({
    required String decisionId,
    required HumanDecisionChoice choice,
    required String decider,
    required String rationale,
    required DecisionSignature signature,
  }) async {
    final decision = await workflowStore.readHumanDecision(decisionId);
    if (!verdictAbsentChoiceIsResolvable(decision, choice)) {
      // Nothing is written: no resolution, no transition, no audit row. The
      // refusal names the choices that ARE open, because an operator who cannot
      // pick one needs to be told what they can.
      logger.warning('workflow.decision_choice_refused', {
        'decisionId': decisionId,
        'workItemId': decision.workItemId,
        'choice': choice.wire,
        'verdictRecorded': false,
        'allowedChoices': verdictAbsentResolvableChoices
            .map((c) => c.wire)
            .toList(),
        'reason':
            'this decision records that NO reviewer returned a verdict, so it '
            'cannot be resolved with a choice that asserts one. Nothing was '
            'written',
      });
      throw StateError(
        'decision $decisionId records no reviewer verdict, so it cannot be '
        'resolved as "${choice.wire}". Resolve it with '
        '${verdictAbsentResolvableChoices.map((c) => c.wire).join(' or ')}. '
        'Nothing was written.',
      );
    }

    if (!designApprovalAbsentChoiceIsResolvable(decision, choice)) {
      // The design lane's mirror of the guard above. Without this call the
      // recorder's helper is dead code and a crafted `approve` resolves an
      // absent-verdict design decision as though a reviewer had spoken: the
      // empty scope grant is recorded and the engine moves the item to
      // `designApproved`. Same discipline — nothing is written.
      logger.warning('workflow.decision_choice_refused', {
        'decisionId': decisionId,
        'workItemId': decision.workItemId,
        'choice': choice.wire,
        'verdictRecorded': false,
        'allowedChoices': designApprovalAbsentResolvableChoices
            .map((c) => c.wire)
            .toList(),
        'reason':
            'this design approval records that NO reviewer returned a verdict, '
            'so it cannot be resolved with a choice that asserts one. Nothing '
            'was written',
      });
      throw StateError(
        'decision $decisionId records no design reviewer verdict, so it cannot '
        'be resolved as "${choice.wire}". Resolve it with '
        '${designApprovalAbsentResolvableChoices.map((c) => c.wire).join(' or ')}'
        '. Nothing was written.',
      );
    }

    // THE DESIGN/PLAN ACCEPTANCE — the lane's path grant becomes a durable
    // fact of the work item HERE, before the engine moves the item.
    //
    // Before the engine call, and that order is the whole point: the engine's
    // transition RELEASES the item, and the released item is dispatchable. A
    // grant written after the release would be read by a dispatch that had
    // already gone out without it, and the QA gate would judge the change
    // against an empty owned set — the exact defect this lane exists to close.
    //
    // It is a SEPARATE write from the engine's, and it cannot be folded into
    // it: `DurableWorkflowEngine.transition` takes the metadata merge as an
    // argument, and the engine is not this lane's to edit. `PersistenceDatabase
    // .inTransaction` refuses a nested transaction, so the two cannot share one
    // commit either. The consequence is stated rather than hidden: if the
    // engine then refuses the transition, the grant is already recorded and the
    // item has NOT moved. That is the safe order — the grant is a fact about
    // the plan, and an item still parked at its gate dispatches nothing.
    await _recordDesignScopeGrant(decision: decision, choice: choice);

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

    // DESIGN APPROVAL HANDOFF (§5.4(b)) — after a designApproval/approve resolution,
    // advance the design revision status and transition the work item from
    // designApproved to implementationReady.
    if (decision.decisionType == HumanDecisionType.designApproval &&
        choice == HumanDecisionChoice.approve) {
      final handoff = DesignApprovalHandoff(
        workflowEngine: workflowEngine,
        workflowStore: workflowStore,
        designGovernanceStore: designGovernanceStore,
        logger: (event, fields) => logger.info(event, fields),
      );
      final handoffResult = await handoff.execute(
        decision: decision,
        choice: choice,
        item: workItem,
      );
      // The handoff never throws; it records failures via metadata and logs.
      // We return the potentially-updated work item from the handoff result.
      if (handoffResult.succeeded && handoffResult.workItem != workItem) {
        logger.info('workflow.design_approval_handoff_transitioned', {
          'workItemId': handoffResult.workItem.workItemId,
          'fromState': workItem.state.wire,
          'toState': handoffResult.workItem.state.wire,
        });
        return handoffResult.workItem;
      }
      if (!handoffResult.succeeded) {
        logger.info('workflow.design_approval_handoff_did_not_transition', {
          'workItemId': workItem.workItemId,
          'failureCode': handoffResult.failureCode,
          'failureDetail': handoffResult.failureDetail,
        });
      }
    }

    return workItem;
  }

  /// Records the scoping lane's owned-path grant on the work item, at the
  /// design/plan acceptance.
  ///
  /// ## THE FOUR PRECONDITIONS, AND WHY EACH IS ONE
  ///
  ///  1. **The resolution is an acceptance.** [isDesignPlanAcceptance] asks
  ///     the routing table, so this cannot drift from where the engine will
  ///     actually put the item. A rejected plan records nothing.
  ///  2. **The item is at the gate.** `waitingForHumanDecision` is where the
  ///     acceptance happens. An item that has already moved on is not being
  ///     accepted now, and re-recording a grant on it would be the post-hoc
  ///     widening decision `7d2a81f0` refused.
  ///  3. **This decision is the item's blocking decision.** A decision that is
  ///     not the one holding the item at the gate moves nothing, and a grant
  ///     recorded for it would be a grant for a question nobody asked.
  ///  4. **The declaration is read from THIS decision.** A grant is recorded
  ///     for the plan that was accepted, not for another plan and not for the
  ///     diff. An empty declaration records an EMPTY scope — which replaces
  ///     whatever an earlier step recorded — and the item stays refused.
  ///
  /// ## WHY THE SCOPE IS REPLACED RATHER THAN ADDED TO
  ///
  /// The design/plan acceptance is where the scope is AUTHORED, so its value
  /// is the authoritative one. An item that arrived carrying a scope from an
  /// earlier step — an intake form, whose requester does not know the path
  /// layout — has that scope replaced here. Leaving it would mean the
  /// effective grant still originates at intake, and decision `7d2a81f0` would
  /// not have been implemented at all. Replacing a wide scope with a narrow
  /// one cannot widen anything; leaving it could.
  ///
  /// ## WHY THE WRITE IS A COMPARE-AND-SWAP
  ///
  /// The work item's metadata carries the plan, the producer identity, the
  /// triage marker and the escalation index, and two writers touching it at
  /// once must not silently overwrite each other. `saveWorkItem`'s
  /// `expectedVersion` is the mechanism, and a refusal is surfaced rather than
  /// swallowed: if the grant cannot be recorded durably, the acceptance must
  /// not proceed, because an item released without its grant is exactly the
  /// state this lane exists to prevent.
  Future<void> _recordDesignScopeGrant({
    required HumanDecision decision,
    required HumanDecisionChoice choice,
  }) async {
    final decisionId = decision.decisionId;
    if (!isDesignPlanAcceptance(
      decisionType: decision.decisionType,
      choice: choice,
    )) {
      return;
    }

    final item = await workflowStore.readWorkItem(decision.workItemId);
    if (item.state != WorkItemState.waitingForHumanDecision) return;
    if (item.blockingHumanDecisionId != decisionId) return;

    final declared = declaredOwnedPathsFromDesignDecision(decision);
    final declaration = decision.metadata?[designScopeDeclarationProvenanceKey];
    final declaredBy = declaration is Map
        ? (declaration['declaredBy'] as String? ?? '')
        : '';
    final grant = designScopeGrantMetadata(
      declaredOwnedPaths: declared,
      decisionType: decision.decisionType,
      decisionId: decisionId,
      declaredBy: declaredBy,
      grantedAt: clock(),
    );

    if (declared.isEmpty) {
      // Fail closed, and say so in the log: an accepted plan that declared no
      // paths leaves the item with an EMPTY scope — which REPLACES any scope
      // an earlier step recorded — so the item carries no grant and the gate
      // will refuse it.
      logger.warning('workflow.design_scope_grant_absent', {
        'decisionId': decisionId,
        'workItemId': item.workItemId,
        'decisionType': decision.decisionType.wire,
        'reason':
            'the accepted design/plan declared no owned paths, so the scope on '
            'the work item is empty and the item carries no grant. The '
            'scope gate will refuse it',
      });
    }

    try {
      await workflowStore.saveWorkItem(
        item.copyWith(
          metadata: mergeDesignScopeGrant(item.metadata, grant),
          updatedAt: clock(),
          version: item.version + 1,
        ),
        expectedVersion: item.version,
      );
    } on ConcurrentModificationException catch (e) {
      logger.warning('workflow.design_scope_grant_conflict', {
        'decisionId': decisionId,
        'workItemId': item.workItemId,
        'error': e.toString(),
        'reason':
            'the work item changed while the grant was being recorded, so the '
            'grant was NOT recorded and the acceptance is refused. Nothing '
            'was written',
      });
      throw StateError(
        'The design/plan grant for work item ${item.workItemId} could not be '
        'recorded: the work item changed concurrently ($e). Nothing was '
        'written, and the plan was not accepted.',
      );
    }

    logger.info('workflow.design_scope_grant_recorded', {
      'decisionId': decisionId,
      'workItemId': item.workItemId,
      'decisionType': decision.decisionType.wire,
      'declaredBy': declaredBy,
      'declaredPathCount': declared.length,
    });
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

  /// Registers a new Product with its [manifest].
  ///
  /// Creates the Product registry row, stores the manifest's DECLARED QA
  /// contract (referenced by [manifestVersion]), and initializes an onboarding
  /// record.
  ///
  /// ## [manifest] is nullable, AND THAT IS THE POINT
  ///
  /// It used to be a required non-null parameter that was never read: this
  /// method recorded [manifestVersion] and discarded the rest of the manifest,
  /// so `ProductManifest.contracts.qaContract` — a declaration that had existed
  /// as a type since the beginning and whose only production construction site
  /// wrote it EMPTY — was unreachable. No product could declare a QA contract,
  /// and therefore every work item not created by the defect-triage lane was
  /// refused for ever at `agentExecuting -> agentCompleted` by
  /// `GuardConditions.qaContractExists()`.
  ///
  /// Making it nullable means the CALLER states whether a manifest was supplied
  /// at all, instead of this method inferring that from a default object the
  /// caller had to manufacture to satisfy the type. `manifest: null` is a claim
  /// ("this product declared nothing"); a default manifest carrying
  /// `QAContractSpec(gates: const [])` was a fabricated one.
  ///
  /// ## WHAT IS PERSISTED FROM A SUPPLIED MANIFEST
  ///
  /// `contracts.qaContract` and its [manifestVersion], and nothing else. The
  /// rest of `ProductManifest` — capabilities, environments, the design and
  /// deployment contract specs — is still NOT persisted, and this method does
  /// not pretend otherwise: persisting the QA declaration was necessary to make
  /// the completion guard satisfiable, and widening this into "the whole
  /// manifest is durable now" would be a claim about code that does not exist.
  ///
  /// ## A DECLARATION WITH NO GATES IS NOT PERSISTED
  ///
  /// An empty gate list is the absence of a declaration, not a declaration of
  /// nothing: a contract built from it would satisfy
  /// `context['qaContractId'] != null` while constraining nothing, which is
  /// precisely the fiction the QA-contract route exists to remove. Such a
  /// manifest is still registered — the product IS created, and a human who
  /// filed a request about this product is not refused for the platform's sake
  /// — but no declaration row is written, the omission is logged by name, and
  /// the first attempt to provision a contract for that product fails closed
  /// with [ProductQAContractSpecRefusal.declaresNoGates].
  ///
  /// ## RE-REGISTRATION MERGES — IT DOES NOT RE-CREATE
  ///
  /// Human decision `6e83b1c7-4d92-4a06-bf58-3c7a9e0d24f6`. This used to route
  /// EVERY registration through `createProduct` + `updateProduct`, and both of
  /// those are lifecycle writes, not merges:
  ///
  /// - `createProduct` builds a fresh `Product` with `state:
  ///   ProductState.registered`, `createdAt: now` and `version: 1` and saves it
  ///   with a NULL `expectedVersion`, which on the Postgres store is
  ///   `INSERT ... ON CONFLICT ("productId") DO UPDATE SET name, description,
  ///   manifestVersion, state, createdAt, updatedAt, version`. On a product that
  ///   already exists that branch is not an upsert in the harmless sense — it
  ///   overwrites `state`, `createdAt` and `version` from the fabricated
  ///   object.
  /// - `updateProduct` then passes `description: null`, and
  ///   `ProductRegistryEngine.updateProduct` copies a null straight through, so
  ///   the description is nulled as well.
  ///
  /// `ProductTransitions` has NO edge from `registered` back to `governed`
  /// (`product_transitions.dart:81` is `registered -> baselinePending`, `:138`
  /// is `registered -> archived` and human-gated). So re-registering the live
  /// `shipit-platform` — verified `governed`, `description` present,
  /// `manifestVersion=v1791564352899`, `version=5`, with an ACCEPTED baseline
  /// `bl-shipit-platform-1` rev 1 — did not merely rewrite the row. It knocked
  /// the product out of governance with no way back, and recovery meant a new
  /// baseline revision, a new independent verification and a new human approval.
  /// A re-registration is an operator pressing a button, and it destroyed the
  /// product's governance.
  ///
  /// THE MERGE: for a product that already exists, `state`, `description`,
  /// `createdAt` and `version` are PRESERVED and the ONLY write is the declared
  /// QA contract — added if absent, updated if present. The product row is not
  /// written at all, so preservation is true by construction rather than by four
  /// careful assignments.
  ///
  /// ## WHAT THE MERGE DOES *NOT* UPDATE, STATED RATHER THAN LEFT IMPLICIT
  ///
  /// `name` and the product row's `manifestVersion` are also left as they are,
  /// because the decision says the only write is the declared QA contract.
  /// Nothing joins the two: the declaration carries its own `manifestVersion`
  /// (`ProductQAContractDeclaration.manifestVersion`), and that is the value
  /// `ProductQAContractProvisioner` puts in a contract's
  /// `qaContractManifestVersionMetadataKey`. `product.manifestVersion` is read
  /// back only to display it (`ui_view_mappers.dart:138`), so a stale one there
  /// is cosmetic and cannot make a provisioner serve a stale gate list.
  ///
  /// ## THE ON/OFFBOARD PATH IS NOT THIS PATH
  ///
  /// `apps/server/bin/onboard_shipit_dev.dart:90-101` and
  /// `apps/server/onboard_shipit_serverpod.dart:90-97` both call
  /// `engine.createProduct` DIRECTLY, and only inside `on
  /// ProductNotFoundException`, so they reach it only for a product that does
  /// not exist. They are separate call sites: the merge below is a decision in
  /// [registerProduct], which neither of them goes through.
  Future<Product> registerProductWithManifest({
    required String productId,
    required String name,
    String? description,
    required ProductManifest? manifest,
    String? manifestVersion,
  }) {
    return registerProduct(
      engine: productRegistryEngine,
      specStore: productQAContractSpecStore,
      log: (event, fields) => logger.info(event, fields),
      productId: productId,
      name: name,
      description: description,
      manifest: manifest,
      manifestVersion: manifestVersion,
    );
  }

  /// [registerProductWithManifest] over injected [engine] and [specStore].
  ///
  /// A static, store-taking seam rather than logic reachable only through a
  /// `Session`, because the merge is the one behaviour on this path that has to
  /// be PROVABLE: it is a claim that four durable columns survive a
  /// re-registration, and a claim about durable bytes wants an assertion rather
  /// than a comment. `ControlPlaneService` needs a `Session` to construct, so
  /// without this the merge could only be observed against a live database, and
  /// `dart test` could not hold it at all. No annotation marks it: `meta` is not
  /// a direct dependency of this package and adding one to carry an annotation
  /// is not worth a pubspec change.
  ///
  /// [log] is the structured sink, injected for the same reason.
  static Future<Product> registerProduct({
    required ProductRegistryEngine engine,
    required ProductQAContractSpecStore specStore,
    required void Function(String event, Map<String, Object?> fields) log,
    required String productId,
    required String name,
    String? description,
    required ProductManifest? manifest,
    String? manifestVersion,
    DateTime? now,
  }) async {
    final t = now ?? DateTime.now().toUtc();
    final version = manifestVersion ?? 'v${t.millisecondsSinceEpoch}';

    // THE MERGE DECISION, and the only place it is made. Read first: a product
    // that is absent raises `ProductNotFoundException` here and takes the create
    // path below, which is unchanged.
    Product? existing;
    try {
      existing = await engine.readProduct(productId);
    } on ProductNotFoundException {
      existing = null;
    }

    if (existing != null) {
      // The product row is NOT written. See the class-level note on
      // `registerProductWithManifest` for why a write here would be a defect
      // and not a merge.
      await _persistDeclaredQAContract(
        specStore: specStore,
        log: log,
        productId: productId,
        manifest: manifest,
        manifestVersion: version,
        now: t,
      );

      log('product_registry.registered_with_manifest', {
        'productId': productId,
        'name': existing.name,
        'manifestVersion': version,
        'manifestSupplied': manifest != null,
        'mergedIntoExisting': true,
        // The preserved lifecycle, logged so an operator can see from the log
        // that the press was a merge and not a create, and see WHICH state was
        // preserved rather than being told "governance is safe".
        'preservedState': existing.state.wire,
        'preservedVersion': existing.version,
        'preservedCreatedAt': existing.createdAt.toUtc().toIso8601String(),
        'preservedDescription': existing.description,
      });
      return existing;
    }

    // Create the product with manifest reference
    await engine.createProduct(
      productId: productId,
      name: name,
      description: description,
      now: t,
    );

    // Update with manifest version
    final updatedProduct = await engine.updateProduct(
      productId,
      manifestVersion: version,
      now: t,
    );

    await _persistDeclaredQAContract(
      specStore: specStore,
      log: log,
      productId: productId,
      manifest: manifest,
      manifestVersion: version,
      now: t,
    );

    log('product_registry.registered_with_manifest', {
      'productId': productId,
      'name': name,
      'manifestVersion': version,
      'manifestSupplied': manifest != null,
      'mergedIntoExisting': false,
    });
    return updatedProduct;
  }

  /// Records what [manifest] DECLARED about QA, or names why it declared
  /// nothing.
  ///
  /// Separate from [registerProduct] so that "is this a declaration or the
  /// absence of one" has one implementation called from one place, rather than
  /// three restatements of `gates.isEmpty` that can drift apart.
  ///
  /// Runs on BOTH registration paths — a merge writes the declaration, which is
  /// the whole of what a merge is allowed to write — so an already-registered
  /// product that re-declares its gates updates them rather than keeping the
  /// ones it had.
  static Future<void> _persistDeclaredQAContract({
    required ProductQAContractSpecStore specStore,
    required void Function(String event, Map<String, Object?> fields) log,
    required String productId,
    required ProductManifest? manifest,
    required String manifestVersion,
    required DateTime now,
  }) async {
    if (manifest == null) {
      log('product_registry.qa_contract_spec.not_declared', {
        'productId': productId,
        'reason':
            'no manifest was supplied, so this product has declared no '
            'QA contract; work items filed under it cannot be provisioned and '
            'fail closed with ProductQAContractSpecRefusal.notDeclared',
      });
      return;
    }

    final spec = manifest.contracts.qaContract;
    // `QAContractSpec.gates.isEmpty` IS the definition of "this product
    // declared no QA contract" (`ProductQAContractDeclaration.declaresQAContract`
    // is the same test on the stored side), written out here because the
    // declaration type's helper lives on a class in `qa_orchestration` and this
    // is a `platform_contracts` type. Both sides answer from one meaning.
    if (spec.gates.isEmpty) {
      // Stated rather than swallowed: a manifest WAS supplied, and it is
      // specifically the QA contract inside it that is empty. A log that only
      // said "no manifest" would send an operator to look in the wrong place.
      log('product_registry.qa_contract_spec.not_declared', {
        'productId': productId,
        'reason':
            'the supplied manifest declares contracts.qaContract with no '
            'gates, which is the absence of a declaration rather than one; work '
            'items filed under this product fail closed with '
            'ProductQAContractSpecRefusal.declaresNoGates',
        'manifestVersion': manifestVersion,
      });
      return;
    }

    await specStore.saveQAContractSpec(
      ProductQAContractDeclaration(
        productId: productId,
        gates: spec.gates,
        manifestVersion: manifestVersion,
        createdAt: now,
        updatedAt: now,
      ),
    );

    log('product_registry.qa_contract_spec.declared', {
      'productId': productId,
      'manifestVersion': manifestVersion,
      'gateCount': spec.gates.length,
      'gateIds': spec.gates.map((gate) => gate.gateId).toList(),
    });
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
  ///
  /// [startingRevision] is what the operator ASKS the run to start from, and
  /// this method deliberately does NOT persist it as the product's
  /// `pinnedRevision`. A request is not a fact: nothing has been cloned yet,
  /// so writing it here would make `OnboardingRecord.hasDurableWorkspace`
  /// answer "yes" for a product that has no workspace, and would make the
  /// record name a commit that may never have been materialised. The run that
  /// actually creates the workspace is what calls
  /// `ProductRegistryEngine.completeOnboarding`, and that write is the one that
  /// makes the pin durable.
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

    // Ids are the store's to allocate in principle; it takes what it is given.
    final jobId = 'jb-$productId-${t.millisecondsSinceEpoch}';

    // The job SHAPE is now built by the same factory the sweep uses, not just
    // its dedupe key. The key was single-sourced first and the shape was left
    // behind, which is how two triggers under one dedupe key ended up writing
    // two different jobs — and dedupe is by key, not by shape, so both were
    // admitted as distinct work.
    //
    // The differences that mattered: `maxAttempts: 1` here against the
    // definition's `2`, which silently denied an operator-triggered onboarding
    // the one bounded retry a sweep-triggered one got; and an instruction that
    // stopped at "run baseline build and test" without stating the boundary the
    // canonical one states — that this produces a baseline and asks a human to
    // approve it, and that the gate is human-only.
    //
    // `onboardingJob` also owns the synthetic work-item id, so
    // `getOnboardingStatus` keeps finding these jobs by the shape it has always
    // searched for.
    final job = onboardingJob(
      jobId: jobId,
      productId: productId,
      repositoryId: repositoryId,
      startingRevision: startingRevision,
      now: t,
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
    // Read through the ONE function that mints that id. It used to be
    // interpolated here a second time, and two spellings of one id is how
    // `triggerOnboarding`'s jobs became invisible to the status lookup written
    // for them.
    final onboardingWorkItemIdForProduct = onboardingWorkItemId(productId);
    final onboardingJobs = jobs
        .where((j) => j.workItemId == onboardingWorkItemIdForProduct)
        .toList();
    onboardingJobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final latestJob = onboardingJobs.isNotEmpty ? onboardingJobs.first : null;

    // The workspace is READ FROM THE ONBOARDING RECORD, which is where it is
    // persisted. It used to be declared here and never assigned — the branch
    // below looked the job's `workspaceId` up, found the result, and then
    // stopped at a comment, so `OnboardingStatus.workspaceDescriptor` was
    // structurally always null and the only descriptor in the system
    // (`WorkspaceDescriptor`) had no persisted home to be read from.
    //
    // The record is the authoritative answer for the PRODUCT-scoped question
    // "where does this product's code live", and it is the one place a
    // restarted process can read it from: the `WorkerStore` lookup below needs
    // a live job whose execution reference is still resolvable, which a
    // product whose onboarding job has been reaped cannot satisfy.
    //
    // It is an `OnboardingWorkspace` and not a bare `WorkspaceDescriptor`,
    // because the column legitimately carries TWO shapes now: a per-execution
    // descriptor and a product-scoped `DurableWorkspaceDescriptor`. They are
    // told apart by the durable shape's constant `kind` discriminator and are
    // never interchangeable, so the `kind` is logged next to the id below —
    // an id alone would read as though the two were the same kind of thing,
    // which is exactly the confusion this two-line neighbourhood exists to
    // prevent.
    final workspace = onboarding?.workspace;

    if (latestJob != null && latestJob.state == JobState.succeeded) {
      final result = await workerStore.readResult(
        latestJob.executionReference?.workerExecutionId ?? '',
      );
      if (result != null && result.workspaceId.isNotEmpty) {
        // `result.workspaceId` identifies the EXECUTION-scoped workspace. It
        // is not used to answer the product-scoped question above, because
        // the product's workspace is recorded on the onboarding record by the
        // run that created it, and an execution's workspace is not the
        // product's — a product is materialised by many executions and only
        // one of them is the onboarding run.
        logger.debug('product_registry.onboarding.workspace', {
          'productId': productId,
          'executionWorkspaceId': result.workspaceId,
          'recordedWorkspaceKind': workspace?.kind,
          'recordedWorkspaceId': workspace?.workspaceId,
          'recordedWorkspaceRepositoryPath': workspace?.repositoryPath,
        });
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

// ---------------------------------------------------------------------
// A3 — the OPERATOR-TRIGGERED durable-workspace provision
// ---------------------------------------------------------------------

/// Creates a governed product's DURABLE clone because an operator asked for it,
/// and records where it now lives.
///
/// ## What this is, and what it is not
///
/// `DurableWorkspaceRuntime.provision` has been merged, reviewed, and reachable
/// from nowhere in production. This is the caller it was written for. Until a
/// clone exists, `ImplementationReadinessProbe` correctly DEFERs every
/// implementation work item for want of a checkout to run in, and no amount of
/// scheduler work changes that.
///
/// It is NOT a job, a sweep, or a repair. It creates the product's writable
/// checkout once, on an explicit human action, and writes down the answer. The
/// clone itself, the credential trust chain, and the six obligations that keep
/// key material off the disk are A1's — this class decides only whether to ask,
/// at what commit, and whether the record may be written.
///
/// ## OPERATOR-TRIGGERED, and that is structural rather than a promise
///
/// Provisioning authenticates to a git host with a deploy key and writes a
/// writable checkout outside the repository tree. It is therefore reachable only
/// from an action a human took. Nothing here is called by a timer, a scheduler
/// tick, a sweep or a probe, and `run()` in `server.dart` is its single
/// production caller — an explicit boot-time instruction. A lane that "also calls
/// it from the onboarding sweep" would run unattended against a governed
/// product's repository.
///
/// Two gates check that mechanically, and they check DIFFERENT things, which is
/// why there are two. `test/durable_workspace_provision_trigger_test.dart` greps
/// `lib/` and fails if this class is named anywhere but this file and
/// `server.dart` — which catches a second named caller. The same file separately
/// scans for the provisioning CAPABILITY (`DurableWorkspaceRuntime`,
/// `DurableWorkspaceProvisioner`, `DurableWorkspaceMaterializer`) and for a
/// `.provision(` call on any receiver other than `trigger`, which catches a
/// direct call that bypasses this class entirely.
///
/// THE CAPABILITY GATE'S EXEMPTION IS THIS CLASS, NOT THIS FILE. It was the
/// whole file, and a file this size is not a boundary a reader can hold in their
/// head: a direct `runtime.provision(` planted in a private helper anywhere else
/// in here passed both gates and every test in the suite. Only the class, the
/// doc comment that documents it, and the file's own import of the capability
/// type (which this class's field requires, and which is what put the type in
/// scope everywhere) are exempt; every other declaration in the file is scanned
/// like any other file in `lib/`.
///
/// What neither gate proves: a call that reaches the capability without naming
/// any of the three types and without spelling `.provision(` on a recognisable
/// receiver — an object handed in from elsewhere in the process, say. That is
/// review's job, and the gates are here so that the ordinary accident — a new
/// lane calling the runtime because it is the obvious API to call — fails CI
/// instead.
///
/// ## A request is not a fact, and nothing here records one
///
/// [ControlPlaneService.triggerOnboarding] establishes the principle for the job
/// lane: the operator's requested starting point is a REQUEST, so it is carried
/// in a job definition and never written to the product's `pinnedRevision`,
/// because nothing has been cloned yet and a record naming a commit that may
/// never have been materialised would make `hasDurableWorkspace` answer "yes"
/// for a product with no workspace.
///
/// This class is the other half of that principle. Here something IS cloned, so
/// the pin is written — but it is written by `DurableWorkspaceRuntime`, in the
/// one call that also creates the tree, and it is written as the RESOLVED COMMIT
/// and never as the operator's word for it. Nothing in this file writes an
/// onboarding record.
///
/// ## Idempotence: a product that already has a clone is REFUSED, never
/// re-provisioned
///
/// See [DurableWorkspaceProvisionTrigger.provision] for the hazard behind that
/// refusal and for why it is still the right layer to enforce it, now that the
/// materialiser enforces a second, independent guard of its own.
class DurableWorkspaceProvisionTrigger {
  const DurableWorkspaceProvisionTrigger({
    required this.store,
    required this.engine,
    required this.runtime,
    required this.log,
  });

  /// The registry store, used for the existence, ownership and
  /// already-provisioned reads. The same store the engine writes through, so a
  /// read here and a write one line later cannot disagree about a transaction
  /// this process never opened.
  final ProductRegistryStore store;

  /// The ONE registry engine for this process. Injected rather than rebuilt so
  /// there is no second place to change if its construction ever does.
  final ProductRegistryEngine engine;

  /// A1's runtime. Never reimplemented, never reconfigured, and never handed a
  /// substitute materialiser: the six credential obligations ride on it.
  final DurableWorkspaceRuntime runtime;

  final void Function(String event, Map<String, dynamic> data) log;

  /// Clones [productId]'s [repositoryId] at [startingRevision] and records it.
  ///
  /// ## The order of the checks, and why it is this order
  ///
  /// Every refusal below happens BEFORE anything is cloned, so a refused
  /// trigger leaves no tree, no credential material and no record behind. The
  /// order is cheapest-and-most-absolute first, because each one names a
  /// different mistake:
  ///
  ///  1. the product exists, and the repository is THIS product's — the same
  ///     ownership check [ControlPlaneService.triggerOnboarding] makes, so a
  ///     product id cannot be used to reach another product's repository;
  ///  2. [startingRevision] is a commit, not a ref;
  ///  3. the durable-workspace runtime exists in this deployment at all;
  ///  4. a human has ACCEPTED a baseline for this product;
  ///  5. the product has no durable clone yet.
  ///
  /// ## 2 — why a ref cannot be resolved here
  ///
  /// Pinning `main` would record a revision that does not exist:
  /// `OnboardingRecord.gitRevisionPattern` is `^[0-9a-f]{40}$` precisely because
  /// "a pin that cannot be resolved to exactly one commit is not a pin", and
  /// `recordWorkspace` writes this argument straight into that column.
  ///
  /// Resolving a ref needs an authenticated `git ls-remote` against the product's
  /// own deploy key, behind its confirmed host key. That trust chain is A1's,
  /// and it is deliberately not reachable from a caller standing in front of it:
  /// a caller with custody in hand is a caller who can skip the host-key
  /// decision, which is the one thing ADR 0018 A2 was closed to prevent. The one
  /// authenticated resolver that exists (`PinnedRevisionResolver`) resolves
  /// `HEAD`, and using it here would substitute the remote's default branch for
  /// whatever the operator named — the exact fallback this must not do.
  ///
  /// So a non-commit is refused BY NAME and told how to become one. The runtime
  /// is not a workaround either: its materialiser fetches the ref, reads a SHA
  /// off `HEAD`, finds it is not the pin it was given, and destroys the tree.
  /// Refusing here is faster and says something true.
  ///
  /// ## 4 — the accepted baseline is a PRECONDITION, checked before the clone
  ///
  /// `DurableWorkspaceProvisioner.completeOnboarding` re-checks the same fact
  /// against the stored baseline's own status and refuses a mismatch; that check
  /// is the §6.6 prohibition made mechanical and it is kept, not routed around.
  /// This class checks it EARLIER for the same reason it checks everything else
  /// early: completing onboarding names a baseline as the human acceptance that
  /// made the product's state meaningful, and a clone made only to be thrown
  /// away by that refusal is a checkout an operator never asked for. A product
  /// whose baseline is still `proposed` is a product whose human has not
  /// finished, and the trigger waits for them.
  ///
  /// Its reason is SURFACED, not swallowed: this class adds no catch around the
  /// call, so A1's own wording reaches the operator.
  ///
  /// ## 5 — the idempotence decision, and the hazard behind it
  ///
  /// **A product that already has a durable clone is refused, always. There is
  /// no re-provision, no force, and no replacement path in this lane.**
  ///
  /// **TWO GUARDS, NOT ONE. THIS IS THE OUTER ONE.**
  ///
  /// This check decides from the RECORD: `readOnboardingForProduct`, then
  /// `hasDurableProductClone`, before A1 is asked for anything at all. The
  /// materialiser has an independent guard of its own — `SshDurableWorkspaceMaterializer.materialize()`
  /// refuses a product root that pre-existed, and its `on Object` handler now
  /// destroys a root only when THIS call created it. That is `A1B`'s fix
  /// (`e82a120`), and it means the claim this section used to make — that the
  /// guard is here and ONLY here, and that reaching the runtime directly "is
  /// the deletion" — is **false and has been since that merge**.
  ///
  /// The two are defence in depth, and each covers a case the other cannot see.
  /// It would be wrong to say that removing either one alone still deletes the
  /// tree: the materialiser's own entry refusal holds the filesystem property on
  /// every path, including a direct call, and this check holds it on the
  /// production path without costing a credential. What is true is narrower and
  /// is what A1B actually measured — within the materialiser, TWO guards are
  /// independently load-bearing, and removing either still deletes the tree:
  /// remove the entry refusal and the run reaches `git remote add` and destroys;
  /// remove only the `createdRoot &&` condition on the destroy, keep the entry
  /// refusal, and the refusal throws inside the `try`, is caught by `on Object`,
  /// and destroys. **Refusing became the deletion.** So keeping this check is
  /// not redundant — it refuses **before** the credential is read and the
  /// confirmed host key is matched, so a refused re-provision through this class
  /// is free and is reported as *"already provisioned at `<sha>`"* rather than as
  /// a collision; the materialiser's refusal costs a full credential
  /// acquisition and arrives as `DurableWorkspaceRootCollisionException`. This
  /// guard also owns a case the materialiser's cannot see — a record write that
  /// fails after a successful clone leaves an orphan tree with nothing recorded —
  /// while the materialiser's owns a case this one cannot: any caller at all, in
  /// any order, against any root it did not create. One precondition on the
  /// materialiser's side is not stated here and is not this class's to hold: a
  /// SINGLE WRITER per product root. Two concurrent `materialize()` calls both
  /// observe `rootPreExisted == false`, both claim the root, and the loser's
  /// destroy takes the winner's tree — measured 6/6. See
  /// `docs/engineering/learning/a-second-clone-attempt-is-a-clone-deletion.md`.
  ///
  /// Never call `DurableWorkspaceRuntime.provision()` or
  /// `SshDurableWorkspaceMaterializer.materialize()` from outside this class.
  /// The reason is no longer "you will delete a clone"; it is that you will
  /// acquire a credential, re-materialise into a root that already exists,
  /// rewrite the onboarding row without noticing, and be handed a collision error
  /// instead of the answer. `DurableWorkspaceRuntime.provision()` still reads no
  /// onboarding record of its own, so "the runtime has no idempotence guard" is
  /// still true of it and only of it.
  ///
  /// The hazard itself, unchanged and still the reason both guards exist: a
  /// second provisioner run materialises into the SAME
  /// `$workspaceRoot/$productId` tree that already holds the clone. `git init`
  /// succeeds against the existing repository and `git remote add origin` then
  /// FAILS, because `origin` is already there. That is why the second run was
  /// the destructive one before the provenance fix, and it is the shape of the
  /// `docker_postgres_data_qa` incident this repository already has.
  ///
  /// Re-pinning to a newer commit is a real need and is explicitly NOT what
  /// this trigger does. It is OD-7.2 / OD-7.3 — how long a clone lives and who
  /// presses it — both still open, and A1's own startup banner says so:
  /// `reclamationPolicy: none`.
  ///
  /// What this class does NOT do is delete or overwrite a durable clone, so
  /// there is no destructive path *here* to name and reach deliberately: the
  /// answer is always "refused", on every call. That is a statement about this
  /// class's own code, and the two gates described on it are what check the
  /// surrounding lane — not a proof about code no gate reads.
  Future<DurableWorkspaceProvisioned> provision({
    required String productId,
    required String repositoryId,
    required String startingRevision,
  }) async {
    final pin = startingRevision.trim();

    // ---- 1. Existence and ownership. ----
    //
    // The same shape `triggerOnboarding` uses, deliberately: knowing a
    // repository id is NOT authorisation to use it for another product.
    await store.readProduct(productId);
    final repository = await store.readRepositoryReference(repositoryId);
    if (repository.productId != productId) {
      throw CrossProductAccessException(
        'repository $repositoryId belongs to product '
        '${repository.productId}, not $productId',
      );
    }

    // ---- 2. The pin is a commit, not a ref. ----
    //
    // Checked against the platform's OWN definition of a pin rather than a
    // pattern written here, so this trigger and the column it writes cannot
    // drift apart.
    if (!OnboardingRecord.gitRevisionPattern.hasMatch(pin)) {
      throw _refuse(
        code: DurableWorkspaceProvisionRefused.unresolvableRevision,
        reason:
            'the starting point ${_safeToEcho(pin) ?? '<unprintable>'} is not a '
            'full 40-character commit SHA, so it cannot be the pin a durable '
            'clone is recorded at. This trigger does not resolve refs for you '
            'and will not fall back to a branch or a default: resolving one '
            'means an authenticated `git ls-remote` with the product\'s deploy '
            'key behind its confirmed host key, and that trust chain belongs to '
            'the durable-workspace runtime rather than to a caller in front of '
            'it. Read the commit out of band — `git ls-remote <repository uri> '
            '<ref>` with your own operator credentials — and pass the SHA.',
        log: log,
        productId: productId,
        repositoryId: repositoryId,
      );
    }

    // ---- 3. The runtime exists in this deployment. ----
    //
    // `provisioner != null` and `isAvailable` are the same fact read two ways;
    // both are checked so that a runtime whose fields ever disagree fails
    // closed instead of being believed on one of them.
    final provisioner = runtime.provisioner;
    if (!runtime.isAvailable || provisioner == null) {
      throw _refuse(
        code: DurableWorkspaceProvisionRefused.runtimeUnavailable,
        reason:
            runtime.availableReason ??
            'the durable-workspace runtime is not available in this '
                'deployment and named no reason. Nothing was cloned and '
                'nothing was recorded; no substitute root or credential was '
                'used.',
        log: log,
        productId: productId,
        repositoryId: repositoryId,
      );
    }

    // ---- 4. A human accepted a baseline. ----
    final baselines = await engine.readBaselines(productId);
    final accepted =
        baselines
            .where(
              (baseline) => baseline.status == ProductBaselineStatus.accepted,
            )
            .toList()
          ..sort((a, b) => a.baselineId.compareTo(b.baselineId));
    if (accepted.isEmpty) {
      throw _refuse(
        code: DurableWorkspaceProvisionRefused.baselineNotAccepted,
        reason:
            'no baseline of $productId has been accepted by a human'
            '${baselines.isEmpty ? ' (the product has none at all)' : ''}, so '
            'there is nothing for onboarding to be completed against. '
            'Onboarding waits for the approval; it does not pre-empt it. '
            'Baselines found: ${_describeBaselines(baselines)}.',
        log: log,
        productId: productId,
        repositoryId: repositoryId,
      );
    }
    if (accepted.length > 1) {
      // Deterministic rather than arbitrary. Accepting a baseline supersedes the
      // previous one, so two accepted rows mean the data is not what this
      // engine produces — and picking "the first" would bind the product's
      // completion to whichever row sorted first.
      throw _refuse(
        code: DurableWorkspaceProvisionRefused.baselineAmbiguous,
        reason:
            '$productId has ${accepted.length} accepted baselines '
            '(${accepted.map((b) => b.baselineId).join(', ')}), so the '
            'acceptance this clone would be completed against is not '
            'determinable. Nothing was cloned and nothing was recorded.',
        log: log,
        productId: productId,
        repositoryId: repositoryId,
      );
    }
    final baseline = accepted.single;

    // ---- 5. Idempotence. ----
    final existing = await store.readOnboardingForProduct(productId);
    if (existing != null && existing.hasDurableProductClone) {
      // `requireDurable`, not a cast and not the deprecated shape-blind
      // `hasDurableWorkspace`: `hasDurableProductClone` is the read that proves
      // the recorded workspace IS the product's clone, so this can only ever
      // yield the durable shape.
      final recorded = existing.workspace!.requireDurable();
      throw _refuse(
        code: DurableWorkspaceProvisionRefused.alreadyProvisioned,
        reason:
            'product $productId already has a durable clone, recorded at '
            '${existing.pinnedRevision} in ${recorded.repositoryPath} '
            '(workspace ${recorded.workspaceId}). It was NOT re-provisioned and '
            'NOT replaced: a clone may hold unreviewed commits, and a second '
            'materialisation into the same tree would fail on its own `git '
            'remote add origin`. This trigger refuses before any of that starts — '
            'the materialiser would refuse the colliding root too, but only '
            'after acquiring the credential. Re-pinning a product is a '
            'decision about how long a clone lives and who presses it (OD-7.2 / '
            'OD-7.3), and both are still open.',
        log: log,
        productId: productId,
        repositoryId: repositoryId,
      );
    }

    // ---- 6. Ask A1, and write down what it established. ----
    //
    // `provision` is the ONLY call here that clones, reads a secret, or records
    // anything. This class never touches the engine's workspace write itself.
    final descriptor = await runtime.provision(
      productId: productId,
      repositoryId: repositoryId,
      pinnedRevision: pin,
    );

    // A1's own completion, which re-checks the acceptance above against the
    // stored baseline's status and refuses a mismatch. Called through the
    // provisioner rather than the engine so that check is never bypassed, and
    // not wrapped in a catch, so its refusal reaches the operator in its own
    // words.
    final record = await provisioner.completeOnboarding(
      productId: productId,
      pinnedRevision: pin,
      workspace: descriptor,
      completedBaselineId: baseline.baselineId,
    );

    log('durable_workspace.provision.triggered', {
      'productId': productId,
      'repositoryId': repositoryId,
      'pinnedRevision': pin,
      'requestedStartingPoint': pin,
      'repositoryPath': descriptor.repositoryPath,
      'workspaceId': descriptor.workspaceId,
      'onboardingId': record.onboardingId,
      'completedBaselineId': baseline.baselineId,
      'completedBaselineRevision': baseline.revision,
      'triggeredBy': 'an explicit operator action',
      'note':
          'the recorded pin is the commit the clone was verified to be at, '
          'read back off the tree — never the string the operator typed',
    });

    return DurableWorkspaceProvisioned(
      productId: productId,
      repositoryId: repositoryId,
      pinnedRevision: pin,
      workspace: descriptor,
      onboardingId: record.onboardingId,
      completedBaselineId: baseline.baselineId,
    );
  }

  /// Logs a refusal and returns it, so the throw below is one statement and the
  /// operator log always has the code even when a caller catches.
  static DurableWorkspaceProvisionRefused _refuse({
    required String code,
    required String reason,
    required void Function(String event, Map<String, dynamic> data) log,
    required String productId,
    required String repositoryId,
  }) {
    final refusal = DurableWorkspaceProvisionRefused(
      code: code,
      reason: reason,
    );
    log('durable_workspace.provision.refused', {
      'code': refusal.code,
      'productId': productId,
      'repositoryId': repositoryId,
      'reason': refusal.reason,
      'action':
          'nothing was cloned, no credential was read, and no onboarding '
          'record was written',
    });
    return refusal;
  }

  /// A refusal reason's baseline list, in a form safe to log and to show.
  static String _describeBaselines(List<ProductBaseline> baselines) {
    if (baselines.isEmpty) return 'none';
    final described =
        baselines
            .map(
              (b) =>
                  '${_safeToEcho(b.baselineId) ?? '<unnamed>'} '
                  '(${b.status.wire})',
            )
            .toList()
          ..sort();
    return described.join(', ');
  }

  /// The operator's own words, or `null` when they are not safe to repeat.
  ///
  /// An allow-list of one shape — short, single-line, no spaces — rather than a
  /// block-list of key markers. A PEM private key contains newlines, spaces and
  /// `-----BEGIN`, so it cannot match; the check does not have to know what key
  /// material looks like, and it cannot be defeated by a marker this file never
  /// heard of. These reasons are logged and shown, so repeating the input must
  /// be a decision rather than an accident.
  static String? _safeToEcho(String value) =>
      RegExp(r'^[A-Za-z0-9._/@:+-]{1,80}$').hasMatch(value) ? value : null;
}

/// What one successful [DurableWorkspaceProvisionTrigger.provision] call
/// established, read back from the record it wrote.
class DurableWorkspaceProvisioned {
  const DurableWorkspaceProvisioned({
    required this.productId,
    required this.repositoryId,
    required this.pinnedRevision,
    required this.workspace,
    required this.onboardingId,
    required this.completedBaselineId,
  });

  final String productId;
  final String repositoryId;

  /// The commit the clone was verified to be at. Forty hex characters, because
  /// `recordWorkspace` will not have accepted anything else.
  final String pinnedRevision;

  final DurableWorkspaceDescriptor workspace;
  final String onboardingId;

  /// The baseline whose human acceptance named this completion.
  final String completedBaselineId;

  @override
  String toString() =>
      'DurableWorkspaceProvisioned($productId/$repositoryId@$pinnedRevision in '
      '${workspace.repositoryPath}, completed against $completedBaselineId)';
}

/// A refusal to provision, as a code an operator can act on plus a reason they
/// can read.
///
/// A code and not only a sentence, because the sentences are long by design and
/// an operator triaging a log line needs something short and stable to match on.
/// Every code is named here, once, and no code is ever reused for a second
/// meaning — the failure mode this exists to prevent is a monitoring rule that
/// fires on one mistake and silently misses the next.
class DurableWorkspaceProvisionRefused implements Exception {
  const DurableWorkspaceProvisionRefused({
    required this.code,
    required this.reason,
  });

  /// No durable-workspace runtime exists in this deployment — no resolved root,
  /// or no custody substrate. The reason is the runtime's own.
  static const String runtimeUnavailable = 'DURABLE_RUNTIME_UNAVAILABLE';

  /// The requested starting point is not a commit SHA, so it cannot be pinned.
  static const String unresolvableRevision = 'REVISION_NOT_A_COMMIT_SHA';

  /// No baseline of this product has been accepted by a human.
  static const String baselineNotAccepted = 'NO_ACCEPTED_BASELINE';

  /// More than one baseline is accepted, so the completion target is ambiguous.
  static const String baselineAmbiguous = 'AMBIGUOUS_ACCEPTED_BASELINE';

  /// The product already has a durable clone. Nothing was changed.
  static const String alreadyProvisioned = 'WORKSPACE_ALREADY_PROVISIONED';

  final String code;

  /// Safe to log and to show: every value interpolated into it is operator
  /// input, a configuration fact or a refusal reason — never key material. The
  /// only operator input repeated back is filtered to a shape a key cannot take.
  final String reason;

  @override
  String toString() => 'DurableWorkspaceProvisionRefused($code): $reason';
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
    this.pendingLifecycleGate,
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

  /// The unresolved lifecycle gate for [context]'s product, or null when none
  /// is open. See [ControlPlaneService.openLifecycleGate] for why this has to
  /// be re-read rather than remembered.
  final OpenLifecycleGate? pendingLifecycleGate;
}

/// An unresolved lifecycle human gate, as read from the durable decision
/// record.
///
/// The whole [decision] is carried rather than a projection of it so the wire
/// mapper can present the engine's own wording — question, options, blocking
/// flag — exactly as it declared it, the same way the baseline gate does.
class OpenLifecycleGate {
  const OpenLifecycleGate({
    required this.decisionId,
    required this.action,
    required this.decision,
  });

  final String decisionId;

  /// The action this gate authorises, read from the decision's own
  /// `LifecycleDecisionBinding`. Not a parameter of the raise call: this object
  /// exists to answer "what is outstanding" long after that call returned.
  final ProductLifecycleAction action;

  final HumanDecision decision;
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

  /// The workspace named by the onboarding record, in whichever of the two
  /// shapes the column carries.
  ///
  /// An [OnboardingWorkspace] and not a bare `WorkspaceDescriptor`, because the
  /// column now legitimately holds either a per-execution descriptor or a
  /// product-scoped [DurableWorkspaceDescriptor]. A consumer that needs a
  /// checkout path reads `workspaceDescriptor?.repositoryPath`, which is
  /// defined for both shapes; a consumer that needs to know WHICH shape it got
  /// reads `workspaceDescriptor?.kind`, and the two are never interchangeable —
  /// there is no accessor that hands back a descriptor without the caller
  /// having discriminated for it.
  final OnboardingWorkspace? workspaceDescriptor;
}

/// Outcome of trying to provision the QA contract for a feature work item.
///
/// A two-armed result rather than a nullable id, so the "provisioned" and "we
/// could not, and here is which of the two named reasons" cases are different
/// values and a caller cannot pass the second off as the first by dropping a
/// null.
///
/// [metadata] is what goes on the work item: null when a contract WAS
/// provisioned — the item's `qaContractId` already says so, and a parallel
/// marker would be a second thing to keep in step with it — and the named
/// refusal otherwise. So the only `null` [contractId] can carry is one with a
/// reason attached to it, which is what makes the absent-contract case
/// greppable instead of invisible.
class FeatureQAContractProvisioning {
  const FeatureQAContractProvisioning._({
    required this.contractId,
    required this.metadata,
  });

  /// A contract was persisted and read back.
  const FeatureQAContractProvisioning.provisioned(String contractId)
    : this._(contractId: contractId, metadata: null);

  /// No contract could be provisioned, for one of the named reasons.
  factory FeatureQAContractProvisioning.refused(
    String refusal,
    String reason,
  ) => FeatureQAContractProvisioning._(
    contractId: null,
    metadata: <String, dynamic>{
      ControlPlaneService.featureQAContractBlockedByKey: refusal,
      ControlPlaneService.featureQAContractBlockedByReasonKey: reason,
    },
  );

  /// The id of a row that was persisted and read back, or null when no contract
  /// could be provisioned. Never a placeholder string.
  final String? contractId;

  final Map<String, dynamic>? metadata;
}
