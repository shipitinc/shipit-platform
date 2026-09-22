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

  List<Map<String, dynamic>> snapshotBaselineFacts() =>
      _baselineFacts.entries
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
    if (expectedVersion != null) {
      final actual = _credentials[credential.credentialId]?.version ?? 0;
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
