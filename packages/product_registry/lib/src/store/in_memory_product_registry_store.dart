import 'package:platform_contracts/platform_contracts.dart';

import 'product_registry_store.dart';
import '../exceptions.dart';

/// Deterministic in-memory [ProductRegistryStore] for unit tests and
/// restart-simulation (a fresh instance + persisted manifest replay). Not the
/// production store: Production Product Registry state belongs in PostgreSQL
/// (checkpoint 006 §persistence).
class InMemoryProductRegistryStore implements ProductRegistryStore {
  final Map<String, Product> _products = {};
  final Map<String, RepositoryReference> _repositories = {};
  final Map<String, RepositoryCredential> _credentials = {};
  final Map<String, ProductBaseline> _baselines = {};
  final Map<String, List<BaselineFact>> _baselineFacts = {};
  final Map<String, StandingPolicy> _policies = {};
  final Map<String, ClarificationRequest> _clarifications = {};
  final Map<String, OnboardingRecord> _onboardings = {};
  final List<ProductRegistryAudit> _audit = [];

  // ---- snapshot/restore for restart simulation ----

  List<Map<String, dynamic>> snapshotProducts() =>
      _products.values.map((p) => p.toJson()).toList();

  List<Map<String, dynamic>> snapshotRepositories() =>
      _repositories.values.map((r) => r.toJson()).toList();

  List<Map<String, dynamic>> snapshotCredentials() =>
      _credentials.values.map((c) => c.toJson()).toList();

  List<Map<String, dynamic>> snapshotBaselines() =>
      _baselines.values.map((b) => b.toJson()).toList();

  List<Map<String, dynamic>> snapshotBaselineFacts() => _baselineFacts.entries
      .expand((e) => e.value.map((f) => {'baselineId': e.key, ...f.toJson()}))
      .toList();

  List<Map<String, dynamic>> snapshotPolicies() =>
      _policies.values.map((p) => p.toJson()).toList();

  List<Map<String, dynamic>> snapshotClarifications() =>
      _clarifications.values.map((c) => c.toJson()).toList();

  List<Map<String, dynamic>> snapshotOnboardings() =>
      _onboardings.values.map((o) => o.toJson()).toList();

  List<Map<String, dynamic>> snapshotAudit() =>
      _audit.map((a) => a.toJson()).toList();

  /// Replays a durable snapshot into this fresh instance — the store-level
  /// analogue of "process restarts, durable state reloads". Each list comes
  /// from the matching [snapshotX] method.
  void restore({
    List<Map<String, dynamic>> products = const [],
    List<Map<String, dynamic>> repositories = const [],
    List<Map<String, dynamic>> credentials = const [],
    List<Map<String, dynamic>> baselines = const [],
    List<Map<String, dynamic>> baselineFacts = const [],
    List<Map<String, dynamic>> policies = const [],
    List<Map<String, dynamic>> clarifications = const [],
    List<Map<String, dynamic>> onboardings = const [],
    List<Map<String, dynamic>> audit = const [],
  }) {
    for (final json in products) {
      final p = Product.fromJson(json);
      _products[p.productId] = p;
    }
    for (final json in repositories) {
      final r = RepositoryReference.fromJson(json);
      _repositories[r.repositoryId] = r;
    }
    for (final json in credentials) {
      final c = RepositoryCredential.fromJson(json);
      _credentials[c.credentialId] = c;
    }
    for (final json in baselines) {
      final b = ProductBaseline.fromJson(json);
      _baselines[b.baselineId] = b;
    }
    for (final json in baselineFacts) {
      final baselineId = json['baselineId'] as String;
      final fact = BaselineFact.fromJson(json);
      _baselineFacts.putIfAbsent(baselineId, () => []).add(fact);
    }
    for (final json in policies) {
      final pol = StandingPolicy.fromJson(json);
      _policies[pol.policyId] = pol;
    }
    for (final json in clarifications) {
      final c = ClarificationRequest.fromJson(json);
      _clarifications[c.clarificationId] = c;
    }
    for (final json in onboardings) {
      final o = OnboardingRecord.fromJson(json);
      _onboardings[o.productId] = o;
    }
    for (final json in audit) {
      _audit.add(ProductRegistryAudit.fromJson(json));
    }
  }

  // ---- Product ----

  @override
  Future<void> saveProduct(Product product, {int? expectedVersion}) async {
    final existing = _products[product.productId];
    if (expectedVersion != null) {
      final actual = existing?.version ?? 0;
      if (actual != expectedVersion) {
        throw ConcurrentModificationException(
          entityId: product.productId,
          expectedVersion: expectedVersion,
          actualVersion: actual,
        );
      }
    }
    _products[product.productId] = product;
  }

  @override
  Future<Product> readProduct(String productId) async {
    final p = _products[productId];
    if (p == null) throw ProductNotFoundException(productId);
    return p;
  }

  @override
  Future<List<Product>> readAllProducts() async =>
      _products.values.toList()
        ..sort((a, b) => a.productId.compareTo(b.productId));

  // ---- Repository references ----

  @override
  Future<void> saveRepositoryReference(RepositoryReference reference) async {
    _repositories[reference.repositoryId] = reference;
  }

  @override
  Future<RepositoryReference> readRepositoryReference(
    String repositoryId,
  ) async {
    final r = _repositories[repositoryId];
    if (r == null) throw RepositoryNotFoundException(repositoryId);
    return r;
  }

  @override
  Future<List<RepositoryReference>> readRepositoriesForProduct(
    String productId,
  ) async => _repositories.values
      .where((r) => r.productId == productId)
      .toList()
      .cast<RepositoryReference>();

  // ---- Product credentials (ADR 0018) ----

  @override
  Future<void> saveProductCredential(
    RepositoryCredential credential, {
    int? expectedVersion,
  }) async {
    final existing = _credentials[credential.credentialId];

    // A null `expectedVersion` is what marks this write as a MINT, and a mint
    // is INSERT-ONLY. Checked FIRST, and ahead of the key-material check below,
    // because that is the order the Postgres store is forced into: its mint
    // branch is a single `ON CONFLICT ("credentialId") DO NOTHING`, which
    // returns nothing for a conflicting row whatever the supplied material, so
    // the two tiers must not disagree about which invariant the caller violated.
    //
    // Without this, an identical-material re-mint reaches
    // `_credentials[id] = credential` below and overwrites the row with the
    // freshly minted object: `status` back to `generated`, `hostKeyStatus` back
    // to `unknown`, and host confirmation, verification, diagnostics and
    // revocation evidence all cleared. It also resurrects a REVOKED credential,
    // which no other guard here could see — `readActiveCredentialForRepository`
    // excludes revoked rows, so the engine's one-active guard cannot fire
    // against one.
    if (existing != null && expectedVersion == null) {
      throw CredentialNotUsableException(
        credential.credentialId,
        'a credential with this id already exists; minting is insert-only, so '
        'issue a NEW credentialId — or use rotateCredential — instead of '
        're-minting this one',
      );
    }

    // Key material is chosen once, at mint. Checked BEFORE the version guard
    // so an attempt to re-point an existing credential reports the reason it
    // was refused rather than a version number.
    //
    // Unlike the Postgres store this needs no predicating write: the map read
    // above and the write below are separated by no `await`, so no other
    // coroutine on this isolate can interleave between them. The Postgres
    // implementation cannot claim that and must therefore close the guard in
    // the statement itself.
    if (existing != null && !_sameKeyMaterial(existing, credential)) {
      throw CredentialNotUsableException(
        credential.credentialId,
        'the key material of an existing credential cannot be changed; rotate '
        'it to issue a new credentialId instead',
      );
    }

    // Scope is chosen once, at mint, for the same reason as the key: it says
    // what the key may reach (ADR 0018 A1). A re-point would move an installed
    // deploy key to another repository of the same product with no rotation
    // record, carrying any host confirmation with it to a host nobody confirmed.
    //
    // Reachable on the mint path too, and deliberately so: the identity guard
    // above fires first there, so in practice it is the CAS branch that needs
    // this. But the two guards are independent rules and a re-point must be
    // refused whichever one happens to be running — a change to `repositoryId`
    // is the defect, not the branch it arrived on. (Its reason still names the
    // scope, never the key, so the two refusals stay tellable apart.)
    if (existing != null &&
        (existing.productId != credential.productId ||
            existing.repositoryId != credential.repositoryId)) {
      throw CredentialNotUsableException(
        credential.credentialId,
        'the scope of an existing credential cannot be changed; it belongs to '
        'the product and repository it was minted for, and re-pointing a key '
        'means minting a new credentialId',
      );
    }

    // Durable evidence is evidence. CAS branch ONLY — and that restriction is
    // load-bearing, not tidiness. The Postgres mint branch is a single
    // `ON CONFLICT ("credentialId") DO NOTHING`, which evaluates no column
    // predicate at all: on that branch the ONLY guard is the identity conflict
    // above. Applying this check on the mint path here would mean the in-memory
    // store refuses a re-mint for a reason the Postgres one cannot see, which
    // would (and did) mask the identity guard behind it in T-D.
    //
    // `copyWith` cannot express a null here, so no engine call site attempts it;
    // this is the contract one would be held to.
    if (existing != null &&
        expectedVersion != null &&
        _clearsDurableEvidence(existing, credential)) {
      throw CredentialNotUsableException(
        credential.credentialId,
        'host confirmation, verification and revocation are recorded facts; a '
        'write that clears them is refused, so the record stays readable',
      );
    }

    if (expectedVersion != null) {
      final actual = existing?.version ?? 0;
      if (actual != expectedVersion) {
        throw ConcurrentModificationException(
          entityId: credential.credentialId,
          expectedVersion: expectedVersion,
          actualVersion: actual,
        );
      }
    }
    _credentials[credential.credentialId] = credential;
  }

  /// Whether [next] carries the same key material as [previous].
  ///
  /// The four fields that identify the keypair itself. `credentialId` is the
  /// map key, so it cannot differ here. `repositoryId`/`productId` are checked
  /// separately, above: they are immutable too, but for a different reason —
  /// they are the scope, not the key — and they get their own refusal message.
  static bool _sameKeyMaterial(
    RepositoryCredential previous,
    RepositoryCredential next,
  ) =>
      previous.publicKey == next.publicKey &&
      previous.fingerprint == next.fingerprint &&
      previous.algorithm == next.algorithm &&
      previous.referenceName == next.referenceName;

  /// Whether [next] drops any decision or event [previous] had recorded.
  ///
  /// Only a non-null → null transition counts. Re-recording a host confirmation
  /// with a fresh timestamp, or replacing one value with another, is something
  /// `copyWith` can express and nothing legitimate does today; erasing what is
  /// already on the record is not.
  static bool _clearsDurableEvidence(
    RepositoryCredential previous,
    RepositoryCredential next,
  ) =>
      _clears(previous.hostConfirmedAt, next.hostConfirmedAt) ||
      _clears(previous.hostConfirmedBy, next.hostConfirmedBy) ||
      _clears(previous.lastVerifiedAt, next.lastVerifiedAt) ||
      _clears(previous.lastVerifiedBy, next.lastVerifiedBy) ||
      _clears(previous.revokedAt, next.revokedAt) ||
      _clears(previous.revokedReason, next.revokedReason) ||
      _clears(previous.hostKeyFingerprint, next.hostKeyFingerprint);

  static bool _clears(Object? previous, Object? next) =>
      previous != null && next == null;

  @override
  Future<RepositoryCredential> readProductCredential(
    String credentialId,
  ) async {
    final c = _credentials[credentialId];
    if (c == null) throw CredentialNotFoundException(credentialId);
    return c;
  }

  @override
  Future<RepositoryCredential?> readActiveCredentialForRepository(
    String repositoryId,
  ) async {
    for (final c in _credentials.values) {
      if (c.repositoryId == repositoryId &&
          c.status != CredentialStatus.revoked) {
        return c;
      }
    }
    return null;
  }

  @override
  Future<List<RepositoryCredential>> readCredentialsForProduct(
    String productId,
  ) async => _credentials.values
      .where((c) => c.productId == productId)
      .toList(growable: false);

  // ---- Baselines ----

  @override
  Future<void> saveBaseline(
    ProductBaseline baseline, {
    int? expectedVersion,
  }) async {
    final existing = _baselines[baseline.baselineId];
    if (expectedVersion != null) {
      final actual = existing?.version ?? 0;
      if (actual != expectedVersion) {
        throw ConcurrentModificationException(
          entityId: baseline.baselineId,
          expectedVersion: expectedVersion,
          actualVersion: actual,
        );
      }
    }
    _baselines[baseline.baselineId] = baseline;
  }

  @override
  Future<ProductBaseline> readBaseline(String baselineId) async {
    final b = _baselines[baselineId];
    if (b == null) throw BaselineNotFoundException(baselineId);
    return b;
  }

  @override
  Future<ProductBaseline?> readBaselineByRevision(
    String productId,
    int revision,
  ) async {
    for (final b in _baselines.values) {
      if (b.productId == productId && b.revision == revision) return b;
    }
    return null;
  }

  @override
  Future<List<ProductBaseline>> readBaselinesForProduct(
    String productId,
  ) async {
    final list = _baselines.values
        .where((b) => b.productId == productId)
        .toList()
        .cast<ProductBaseline>();
    list.sort((a, b) => b.revision.compareTo(a.revision));
    return list;
  }

  @override
  Future<int> nextBaselineRevision(String productId) async {
    var max = 0;
    for (final b in _baselines.values) {
      if (b.productId == productId && b.revision > max) max = b.revision;
    }
    return max + 1;
  }

  // ---- Baseline facts (normalized, queryable) ----

  @override
  Future<void> saveBaselineFacts(
    String baselineId,
    List<BaselineFact> facts,
  ) async {
    _baselineFacts[baselineId] = facts;
  }

  @override
  Future<List<BaselineFact>> readBaselineFacts(String baselineId) async {
    return _baselineFacts[baselineId] ?? const [];
  }

  // ---- Standing policies ----

  @override
  Future<void> saveStandingPolicy(
    StandingPolicy policy, {
    int? expectedVersion,
  }) async {
    if (expectedVersion != null) {
      final actual = _policies[policy.policyId]?.version ?? 0;
      if (actual != expectedVersion) {
        throw ConcurrentModificationException(
          entityId: policy.policyId,
          expectedVersion: expectedVersion,
          actualVersion: actual,
        );
      }
    }
    _policies[policy.policyId] = policy;
  }

  @override
  Future<StandingPolicy> readStandingPolicy(String policyId) async {
    final p = _policies[policyId];
    if (p == null) throw PolicyNotFoundException(policyId);
    return p;
  }

  @override
  Future<List<StandingPolicy>> readPoliciesForProduct(String productId) async =>
      _policies.values
          .where((p) => p.productId == productId)
          .toList(growable: false);

  // ---- Clarifications ----

  @override
  Future<void> saveClarification(ClarificationRequest request) async {
    _clarifications[request.clarificationId] = request;
  }

  @override
  Future<ClarificationRequest> readClarification(String clarificationId) async {
    final c = _clarifications[clarificationId];
    if (c == null) throw ClarificationNotFoundException(clarificationId);
    return c;
  }

  @override
  Future<List<ClarificationRequest>> readClarificationsForProduct(
    String productId, {
    ClarificationStatus status = ClarificationStatus.needsAnswer,
  }) async => _clarifications.values
      .where((c) => c.productId == productId && c.status == status)
      .toList()
      .cast<ClarificationRequest>();

  // ---- Onboarding ----

  @override
  Future<void> saveOnboarding(OnboardingRecord record) async {
    _onboardings[record.productId] = record;
  }

  @override
  Future<OnboardingRecord?> readOnboardingForProduct(String productId) async =>
      _onboardings[productId];

  // ---- Audit log (append-only) ----

  @override
  Future<void> appendAudit(ProductRegistryAudit audit) async {
    _audit.add(audit);
  }

  @override
  Future<List<ProductRegistryAudit>> readAuditForProduct(
    String productId, {
    int? limit,
  }) async {
    final result = _audit
        .where((a) => a.productId == productId)
        .toList(growable: false);
    if (limit != null && result.length > limit) {
      return result.sublist(result.length - limit);
    }
    return result;
  }

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(ProductRegistryStore store) body,
  ) => body(this);
}
