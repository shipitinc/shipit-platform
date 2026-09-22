import 'package:platform_contracts/platform_contracts.dart';

/// Durable container for everything S-1 Product ownership needs to persist and
/// resume across process restarts:
/// - Product registry rows (identity + lifecycle)
/// - Repository references (durable identity, product-scoped)
/// - Product credentials (per-repository SSH access, ADR 0018 A1)
/// - ProductBaseline revisions (versioned, immutable-on-accept)
/// - BaselineFact rows (normalized, queryable provenance/maturity/section)
/// - Standing policy authorisations (ADR 0019)
/// - Clarification requests (durable stop / resume)
/// - Onboarding records (bounded bootstrap progress)
/// - Audit log (append-only, every mutation recorded)
///
/// All scope-carrying reads are parameterized by [productId] and must reject
/// cross-Product access (checkpoint 006 §4.4 / §5). No "currentProduct"
/// global.
abstract interface class ProductRegistryStore {
  // ---- Product ----
  Future<void> saveProduct(Product product, {int? expectedVersion});

  Future<Product> readProduct(String productId);

  Future<List<Product>> readAllProducts();

  // ---- Repository references ----
  Future<void> saveRepositoryReference(RepositoryReference reference);

  Future<RepositoryReference> readRepositoryReference(String repositoryId);

  Future<List<RepositoryReference>> readRepositoriesForProduct(
    String productId,
  );

  // ---- Product credentials (ADR 0018) ----
  //
  // Scoped to one repository. The store never sees key material: only the
  // public half and a reference name to the local secret store.
  Future<void> saveProductCredential(
    RepositoryCredential credential, {
    int? expectedVersion,
  });

  Future<RepositoryCredential> readProductCredential(String credentialId);

  /// The credential currently in force for [repositoryId], or null when none
  /// has been generated. Revoked credentials are never returned here.
  Future<RepositoryCredential?> readActiveCredentialForRepository(
    String repositoryId,
  );

  /// Every credential ever issued for [productId], including revoked ones, so
  /// the historical record stays readable.
  Future<List<RepositoryCredential>> readCredentialsForProduct(
    String productId,
  );

  // ---- Baselines ----
  Future<void> saveBaseline(ProductBaseline baseline, {int? expectedVersion});

  Future<ProductBaseline> readBaseline(String baselineId);

  Future<ProductBaseline?> readBaselineByRevision(
    String productId,
    int revision,
  );

  Future<List<ProductBaseline>> readBaselinesForProduct(String productId);

  /// Next monotonic revision for a product (max existing + 1, or 1).
  Future<int> nextBaselineRevision(String productId);

  // ---- Baseline facts (normalized, queryable) ----
  Future<void> saveBaselineFacts(
    String baselineId,
    List<BaselineFact> facts,
  );

  Future<List<BaselineFact>> readBaselineFacts(String baselineId);

  // ---- Standing policies (ADR 0019) ----
  //
  // A policy is a signed decision that authorises a class of future actions.
  // Revoked policies are never deleted: the record of what was authorised,
  // by whom, and when it stopped must stay readable.
  Future<void> saveStandingPolicy(
    StandingPolicy policy, {
    int? expectedVersion,
  });

  Future<StandingPolicy> readStandingPolicy(String policyId);

  /// Every policy ever created for [productId], revoked ones included.
  Future<List<StandingPolicy>> readPoliciesForProduct(String productId);

  // ---- Clarifications ----
  Future<void> saveClarification(ClarificationRequest request);

  Future<ClarificationRequest> readClarification(String clarificationId);

  Future<List<ClarificationRequest>> readClarificationsForProduct(
    String productId, {
    ClarificationStatus status = ClarificationStatus.needsAnswer,
  });

  // ---- Onboarding ----
  Future<void> saveOnboarding(OnboardingRecord record);

  Future<OnboardingRecord?> readOnboardingForProduct(String productId);

  // ---- Audit log (append-only) ----
  Future<void> appendAudit(ProductRegistryAudit audit);

  Future<List<ProductRegistryAudit>> readAuditForProduct(
    String productId, {
    int? limit,
  });

  /// Runs [body] within a single transaction. Implementations backed by a
  /// transactional database must make every store call inside [body] atomic;
  /// the default implementation has no transaction.
  Future<T> inTransaction<T>(
    Future<T> Function(ProductRegistryStore store) body,
  ) async => body(this);
}
