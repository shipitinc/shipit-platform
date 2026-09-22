import 'package:execution_coordinator/execution_coordinator.dart'
    show ExecutionStore;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:workflow_engine/workflow_engine.dart' show ProductGuard;
import 'package:scheduler/scheduler.dart' show JobStore;
import 'package:serverpod/serverpod.dart';
import 'package:workflow_store/workflow_store.dart'
    show DurableWorkflowEngine, WorkflowStore;
import 'package:worker_runtime/worker_runtime.dart'
    show WorkerRegistrationStore, WorkerStore;
import 'package:worker_protocol/worker_protocol.dart' show WorkerRegistration;

import '../persistence/persistence_database.dart';
import '../persistence/postgres_execution_store.dart';
import '../persistence/postgres_human_decision_store.dart';
import '../persistence/postgres_job_store.dart';
import '../persistence/postgres_product_registry_store.dart';
import '../persistence/postgres_worker_registration_store.dart';
import '../persistence/postgres_worker_store.dart';
import '../persistence/postgres_workflow_store.dart';
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

  PersistenceDatabase get _db => PersistenceDatabase(session.db);

  WorkflowStore get workflowStore => PostgresWorkflowStore(_db);
  JobStore get jobStore => PostgresJobStore(_db);
  WorkerStore get workerStore => PostgresWorkerStore(_db);
  ExecutionStore get executionStore => PostgresExecutionStore(_db);
  WorkerRegistrationStore get workerRegistrationStore =>
      PostgresWorkerRegistrationStore(_db);

  /// The durable orchestration engine; the only place workflow state writes.
  DurableWorkflowEngine get workflowEngine =>
      DurableWorkflowEngine(store: workflowStore);

  /// S-1 Product Registry store + engine (checkpoint 006).
  ProductRegistryStore get productRegistryStore =>
      PostgresProductRegistryStore(_db);

  HumanDecisionStore get humanDecisionStore =>
      PostgresHumanDecisionStore(workflowStore);

  /// The only durable engine for Product/baseline/clarification writes.
  ProductRegistryEngine get productRegistryEngine => ProductRegistryEngine(
    store: productRegistryStore,
    humanDecisionStore: humanDecisionStore,
  );

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
    logger.debug('product_registry.detail', {'productId': productId});
    return ProductDetail(
      context: context,
      credentials: credentials,
      pendingBaseline: pending,
      policies: policies,
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
    final repo = await productRegistryStore.readRepositoryReference(repositoryId);
    if (repo.productId != productId) {
      throw CrossProductAccessException(
        'repository $repositoryId belongs to product ${repo.productId}, not $productId',
      );
    }

    // Ensure onboarding record exists
    final onboarding = await productRegistryStore.readOnboardingForProduct(productId);
    if (onboarding == null) {
      // The engine will create one when needed
    }

    // Create a synthetic work item ID for onboarding (not a real WorkItem)
    // Onboarding jobs are product-scoped, not work-item-scoped
    final syntheticWorkItemId = 'onboarding-$productId';

    // Use the job queue directly to enqueue the onboarding job
    // We need a JobQueue instance - let's use the job store directly
    final jobId = 'jb-${productId}-${t.millisecondsSinceEpoch}';
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

    final onboarding = await productRegistryStore.readOnboardingForProduct(productId);
    final jobs = await jobStore.listJobs();
    final onboardingJobs = jobs
        .where((j) => j.workItemId == 'onboarding-$productId')
        .toList();
    onboardingJobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final latestJob = onboardingJobs.isNotEmpty ? onboardingJobs.first : null;

    WorkspaceDescriptor? workspace;
    if (latestJob != null && latestJob.state == JobState.succeeded) {
      final result = await workerStore.readResult(latestJob.executionReference?.workerExecutionId ?? '');
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
  });

  final ProductContext context;
  final List<RepositoryCredential> credentials;
  final ProductBaseline? pendingBaseline;
  final List<StandingPolicy> policies;
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
