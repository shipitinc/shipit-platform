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
  /// A NULL [expectedVersion] is what marks this write as a MINT, and a mint is
  /// INSERT-ONLY. It is the shape `ProductRegistryEngine.recordGeneratedCredential`
  /// uses, and no other call site passes null.
  ///
  /// KEY MATERIAL IS IMMUTABLE (ADR 0018 A1). Key material — `publicKey`,
  /// `fingerprint`, `algorithm` and `referenceName` — is chosen once, when the
  /// credential is minted, and is never changed afterwards by any path. A write
  /// whose `credentialId` already exists but whose key material differs MUST
  /// throw and MUST leave the stored row untouched.
  ///
  /// THE SCOPE SET IS IMMUTABLE TOO. `productId` and `repositoryId` are the
  /// fields that say what the key is allowed to reach (ADR 0018 A1, "scope is
  /// the repository"), and they are fixed at mint like the key material. A write
  /// that moves an existing credential to another `productId` or `repositoryId`
  /// MUST throw and MUST leave the stored row untouched — otherwise an installed
  /// deploy key is silently re-pointed at another repository with no rotation
  /// record, and any host confirmation travels with it to a host whose key was
  /// never shown to anybody (ADR 0018 "the operator is shown the host, key type
  /// and fingerprint and must confirm it").
  ///
  /// MINTING NEVER OVERWRITES AN EXISTING IDENTITY. On the mint path a
  /// `credentialId` that already exists MUST be refused and the row MUST be left
  /// exactly as it was, whether or not the supplied key material matches.
  /// Two things follow that this contract used to leave open:
  ///
  ///   * an identical-material re-mint used to take an upsert branch and rewrite
  ///     the row from the freshly minted object — resetting `status` to
  ///     `generated` and `hostKeyStatus` to `unknown`, and clearing host
  ///     confirmation, verification, diagnostics and revocation evidence. No key
  ///     substitution is needed to do that;
  ///   * a REVOKED credential could be resurrected the same way. The active-set
  ///     read excludes revoked rows, so the engine's one-active guard cannot
  ///     fire against one, and the resurrected row then both claims a deploy key
  ///     whose private half was destroyed on revocation and occupies the active
  ///     set, so the legitimate replacement mint is refused.
  ///
  ///   Rotation is the supported way to replace a key, and it mints a NEW
  ///   `credentialId` — so refusing a re-mint of an existing one costs no
  ///   legitimate path.
  ///
  /// DURABLE EVIDENCE CANNOT BE CLEARED. The seven guarded columns are
  /// `hostConfirmedAt`, `hostConfirmedBy`, `lastVerifiedAt`, `lastVerifiedBy`,
  /// `hostKeyFingerprint`, `revokedAt` and `revokedReason` — they record
  /// decisions and events that happened. A CAS write MUST NOT set any of them
  /// back to null on an existing row. `RepositoryCredential.copyWith` cannot
  /// express that (each nullable parameter falls back to the current value), so
  /// today no engine call site attempts it — but the store contract is
  /// unconditional, and a store that accepted it would let one be written.
  ///
  /// `hostKeyFingerprint` belongs in that list and was missing from an earlier
  /// wording of this contract: both tiers have always guarded it, and a reader
  /// of the prose alone would have concluded that re-recording a host key was
  /// permitted. All SEVEN names are written out, in both tiers' order, so this
  /// paragraph does not have to be edited again when the set changes.
  ///
  /// NOT YET GUARDED, and deliberately not claimed here: `lastFailureReason`,
  /// the eighth recorded column. Design rev5's `D-6` requires eight columns and
  /// both tiers currently enforce seven. It is latent, not live —
  /// `copyWith` preserves it on a null argument and the only engine writer sets
  /// it without clearing it, so no engine path can erase it today — but a
  /// store-level caller handing in a null would erase it on both tiers, and it is
  /// live on the Postgres `SET` clause. It must be guarded before migration
  /// `20261006150645000` reaches a deployed database. Naming it in the list above
  /// would overstate what the tiers enforce today, which is the same defect as
  /// omitting `hostKeyFingerprint` was.
  ///
  /// These are store contracts, not engine conventions. `copyWith` cannot change
  /// these fields, but `copyWith` is not on the mint path:
  /// `ProductRegistryEngine.recordGeneratedCredential` constructs a fresh
  /// credential and writes it with no `expectedVersion`. Every check is enforced
  /// in the write itself, not by a read before it, so it holds against any other
  /// connection and cannot be raced.
  ///
  /// When a guard refuses, an implementation reports the immutability refusal
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
