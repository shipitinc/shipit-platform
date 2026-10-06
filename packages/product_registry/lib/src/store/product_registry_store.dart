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

  /// Writes [credential], optionally guarded by [expectedVersion].
  ///
  /// KEY MATERIAL IS IMMUTABLE (ADR 0018 A1). Key material — `publicKey`,
  /// `fingerprint`, `algorithm` and `referenceName` — is chosen once, when the
  /// credential is minted, and is never changed afterwards by any path. A write
  /// whose `credentialId` already exists but whose key material differs MUST
  /// throw and MUST leave the stored row untouched.
  ///
  /// This is a store contract, not an engine convention. `RepositoryCredential
  /// .copyWith` cannot change these fields, but `copyWith` is not on the mint
  /// path: `ProductRegistryEngine.recordGeneratedCredential` constructs a fresh
  /// credential and writes it. Without this contract the upsert silently
  /// replaced the key an operator had installed — same `credentialId`, no
  /// rotation record, verification state and host confirmation discarded.
  ///
  /// The guard is enforced in the write itself, not by a read before it, on
  /// BOTH paths: with a null [expectedVersion] and with a CAS. A check-then-write
  /// is a race against any other connection, and the mint path reaches this
  /// write with a null [expectedVersion] precisely because a new credential has
  /// no prior version — so the CAS cannot carry this on its own.
  ///
  /// When the guard refuses, an implementation reports the immutability refusal
  /// rather than a version conflict, even if the supplied [expectedVersion] was
  /// also stale. Telling a caller that re-pointed key material that it lost a
  /// concurrency race invites it to retry the same re-point.
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
  Future<void> saveBaselineFacts(String baselineId, List<BaselineFact> facts);

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
