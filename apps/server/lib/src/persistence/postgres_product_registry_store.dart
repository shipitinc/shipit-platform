import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:serverpod/database.dart';

import 'persistence_database.dart';

import 'util/db_row_util.dart';

/// PostgreSQL implementation of [ProductRegistryStore].
///
/// Scope-carrying keys (`productId`, `baselineId`, `repositoryId`,
/// `clarificationId`) are real columns — never JSON. Only nested
/// structures (baseline facts) are stored as JSON documents. Optimistic
/// concurrency uses the same `version` + `ON CONFLICT` CAS pattern as the
/// workflow/job stores (checkpoint 006 §persistence, §3.3).
class PostgresProductRegistryStore implements ProductRegistryStore {
  PostgresProductRegistryStore(this._db);

  final PersistenceDatabase _db;

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(ProductRegistryStore store) body,
  ) {
    return _db.inTransaction<T>(() => body(this));
  }

  // ---------------------------------------------------------------------
  // Product
  // ---------------------------------------------------------------------

  @override
  Future<void> saveProduct(Product product, {int? expectedVersion}) async {
    const bareInsert = '''INSERT INTO "product" (
           "productId", "name", "description", "manifestVersion",
           "state", "createdAt", "updatedAt", "version"
         ) VALUES (
           @productId, @name, @description, @manifestVersion,
           @state, @createdAt, @updatedAt, @version
         )''';

    if (expectedVersion != null) {
      final affected = await _db.execute(
        '''UPDATE "product" SET
             "name" = @name,
             "description" = @description,
             "manifestVersion" = @manifestVersion,
             "state" = @state,
             "createdAt" = @createdAt,
             "updatedAt" = @updatedAt,
             "version" = @version
           WHERE "productId" = @productId AND "version" = @expected''',
        parameters: QueryParameters.named({
          ..._productParams(product),
          'version': product.version,
          'expected': expectedVersion,
        }),
      );
      if (affected == 1) return;

      final rows = await _db.query(
        'SELECT "version" FROM "product" WHERE "productId" = @productId',
        parameters: QueryParameters.named({'productId': product.productId}),
      );
      final actual = rows.isEmpty ? 0 : rows[0].toColumnMap()['version'] as int;
      if (rows.isEmpty && expectedVersion == 0) {
        final inserted = await _db.execute(
          '$bareInsert ON CONFLICT ("productId") DO NOTHING',
          parameters: QueryParameters.named(_productParams(product)),
        );
        if (inserted == 1) return;
        final current = await _db.query(
          'SELECT "version" FROM "product" WHERE "productId" = @productId',
          parameters: QueryParameters.named({'productId': product.productId}),
        );
        throw ConcurrentModificationException(
          entityId: product.productId,
          expectedVersion: 0,
          actualVersion: current.isEmpty
              ? 0
              : (current[0].toColumnMap()['version'] as int),
        );
      }
      throw ConcurrentModificationException(
        entityId: product.productId,
        expectedVersion: expectedVersion,
        actualVersion: actual,
      );
    }

    await _db.execute(
      '''$bareInsert ON CONFLICT ("productId") DO UPDATE SET
             "name" = EXCLUDED."name",
             "description" = EXCLUDED."description",
             "manifestVersion" = EXCLUDED."manifestVersion",
             "state" = EXCLUDED."state",
             "createdAt" = EXCLUDED."createdAt",
             "updatedAt" = EXCLUDED."updatedAt",
             "version" = EXCLUDED."version"''',
      parameters: QueryParameters.named(_productParams(product)),
    );
  }

  @override
  Future<Product> readProduct(String productId) async {
    final result = await _db.query(
      'SELECT * FROM "product" WHERE "productId" = @productId',
      parameters: QueryParameters.named({'productId': productId}),
    );
    if (result.isEmpty) throw ProductNotFoundException(productId);
    return _productFromRow(result[0]);
  }

  @override
  Future<List<Product>> readAllProducts() async {
    final result = await _db.query(
      'SELECT * FROM "product" ORDER BY "createdAt" ASC',
    );
    return result.map(_productFromRow).toList();
  }

  // ---------------------------------------------------------------------
  // Repository references
  // ---------------------------------------------------------------------

  @override
  Future<void> saveRepositoryReference(RepositoryReference reference) async {
    await _db.execute(
      '''INSERT INTO "repository_reference" (
             "repositoryId", "productId", "kind", "uri", "provider",
             "addedAt", "version"
           ) VALUES (
             @repositoryId, @productId, @kind, @uri, @provider,
             @addedAt, @version
           )
           ON CONFLICT ("repositoryId") DO UPDATE SET
             "productId" = EXCLUDED."productId",
             "kind" = EXCLUDED."kind",
             "uri" = EXCLUDED."uri",
             "provider" = EXCLUDED."provider",
             "addedAt" = EXCLUDED."addedAt",
             "version" = EXCLUDED."version"''',
      parameters: QueryParameters.named(_repositoryParams(reference)),
    );
  }

  @override
  Future<RepositoryReference> readRepositoryReference(
    String repositoryId,
  ) async {
    final result = await _db.query(
      '''SELECT * FROM "repository_reference" WHERE "repositoryId" = @repositoryId''',
      parameters: QueryParameters.named({'repositoryId': repositoryId}),
    );
    if (result.isEmpty) throw RepositoryNotFoundException(repositoryId);
    return _repositoryFromRow(result[0]);
  }

  @override
  Future<List<RepositoryReference>> readRepositoriesForProduct(
    String productId,
  ) async {
    final result = await _db.query(
      '''SELECT * FROM "repository_reference" WHERE "productId" = @productId
         ORDER BY "addedAt" ASC''',
      parameters: QueryParameters.named({'productId': productId}),
    );
    return result.map(_repositoryFromRow).toList();
  }


  // ---------------------------------------------------------------------
  // ProductCredential (ADR 0018 A1 — one per repository, no key material)
  // Table: product_credential
  // ---------------------------------------------------------------------

  @override
  Future<void> saveProductCredential(
    RepositoryCredential credential, {
    int? expectedVersion,
  }) async {
    const cols = '"credentialId", "productId", "repositoryId", '
        '"referenceName", "publicKey", "fingerprint", "algorithm", "status", '
        '"createdAt", "lastVerifiedAt", "lastVerifiedBy", "lastFailureReason", '
        '"hostKeyStatus", "host", "hostKeyFingerprint", "hostConfirmedAt", '
        '"hostConfirmedBy", "revokedAt", "revokedReason", '
        '"supersedesCredentialId", "version"';
    const vals = '@credentialId, @productId, @repositoryId, @referenceName, '
        '@publicKey, @fingerprint, @algorithm, @status, @createdAt, '
        '@lastVerifiedAt, @lastVerifiedBy, @lastFailureReason, '
        '@hostKeyStatus, @host, @hostKeyFingerprint, @hostConfirmedAt, '
        '@hostConfirmedBy, @revokedAt, @revokedReason, '
        '@supersedesCredentialId, @version';
    const assignments = '"productId" = @productId, '
        '"repositoryId" = @repositoryId, "referenceName" = @referenceName, '
        '"publicKey" = @publicKey, "fingerprint" = @fingerprint, '
        '"algorithm" = @algorithm, "status" = @status, '
        '"createdAt" = @createdAt, "lastVerifiedAt" = @lastVerifiedAt, '
        '"lastVerifiedBy" = @lastVerifiedBy, '
        '"lastFailureReason" = @lastFailureReason, '
        '"hostKeyStatus" = @hostKeyStatus, "host" = @host, '
        '"hostKeyFingerprint" = @hostKeyFingerprint, '
        '"hostConfirmedAt" = @hostConfirmedAt, '
        '"hostConfirmedBy" = @hostConfirmedBy, "revokedAt" = @revokedAt, '
        '"revokedReason" = @revokedReason, '
        '"supersedesCredentialId" = @supersedesCredentialId, '
        '"version" = @version';

    if (expectedVersion != null) {
      final affected = await _db.execute(
        'UPDATE "product_credential" SET $assignments '
        'WHERE "credentialId" = @credentialId AND "version" = @expected',
        parameters: QueryParameters.named({
          ..._credentialParams(credential),
          'expected': expectedVersion,
        }),
      );
      if (affected == 1) return;

      final rows = await _db.query(
        'SELECT "version" FROM "product_credential" '
        'WHERE "credentialId" = @credentialId',
        parameters: QueryParameters.named({
          'credentialId': credential.credentialId,
        }),
      );
      final actual = rows.isEmpty ? 0 : rows[0].toColumnMap()['version'] as int;
      throw ConcurrentModificationException(
        entityId: credential.credentialId,
        expectedVersion: expectedVersion,
        actualVersion: actual,
      );
    }

    await _db.execute(
      'INSERT INTO "product_credential" ($cols) VALUES ($vals) '
      'ON CONFLICT ("credentialId") DO UPDATE SET $assignments',
      parameters: QueryParameters.named(_credentialParams(credential)),
    );
  }

  @override
  Future<RepositoryCredential> readProductCredential(
    String credentialId,
  ) async {
    final result = await _db.query(
      'SELECT * FROM "product_credential" WHERE "credentialId" = @id',
      parameters: QueryParameters.named({'id': credentialId}),
    );
    if (result.isEmpty) throw CredentialNotFoundException(credentialId);
    return _credentialFromRow(result[0]);
  }

  @override
  Future<RepositoryCredential?> readActiveCredentialForRepository(
    String repositoryId,
  ) async {
    final result = await _db.query(
      'SELECT * FROM "product_credential" '
      'WHERE "repositoryId" = @repositoryId AND "status" <> \'revoked\' '
      'ORDER BY "createdAt" DESC LIMIT 1',
      parameters: QueryParameters.named({'repositoryId': repositoryId}),
    );
    if (result.isEmpty) return null;
    return _credentialFromRow(result[0]);
  }

  @override
  Future<List<RepositoryCredential>> readCredentialsForProduct(
    String productId,
  ) async {
    final result = await _db.query(
      'SELECT * FROM "product_credential" WHERE "productId" = @productId '
      'ORDER BY "createdAt" ASC',
      parameters: QueryParameters.named({'productId': productId}),
    );
    return result.map(_credentialFromRow).toList();
  }

  Map<String, Object?> _credentialParams(RepositoryCredential c) {
    final json = c.toJson();
    return {
      'credentialId': json['credentialId'],
      'productId': json['productId'],
      'repositoryId': json['repositoryId'],
      'referenceName': json['referenceName'],
      'publicKey': json['publicKey'],
      'fingerprint': json['fingerprint'],
      'algorithm': json['algorithm'],
      'status': json['status'],
      'createdAt': PersistenceDatabase.toUtc(c.createdAt),
      'lastVerifiedAt': PersistenceDatabase.toUtc(c.lastVerifiedAt),
      'lastVerifiedBy': json['lastVerifiedBy'],
      'lastFailureReason': json['lastFailureReason'],
      'hostKeyStatus': json['hostKeyStatus'],
      'host': json['host'],
      'hostKeyFingerprint': json['hostKeyFingerprint'],
      'hostConfirmedAt': PersistenceDatabase.toUtc(c.hostConfirmedAt),
      'hostConfirmedBy': json['hostConfirmedBy'],
      'revokedAt': PersistenceDatabase.toUtc(c.revokedAt),
      'revokedReason': json['revokedReason'],
      'supersedesCredentialId': json['supersedesCredentialId'],
      'version': c.version,
    };
  }

  RepositoryCredential _credentialFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return RepositoryCredential.fromJson({
      'credentialId': m['credentialId'],
      'productId': m['productId'],
      'repositoryId': m['repositoryId'],
      'referenceName': m['referenceName'],
      'publicKey': m['publicKey'],
      'fingerprint': m['fingerprint'],
      'algorithm': m['algorithm'],
      'status': m['status'],
      'createdAt': decodeUtc(m['createdAt'])?.toIso8601String(),
      'lastVerifiedAt': decodeUtc(m['lastVerifiedAt'])?.toIso8601String(),
      'lastVerifiedBy': m['lastVerifiedBy'],
      'lastFailureReason': m['lastFailureReason'],
      'hostKeyStatus': m['hostKeyStatus'],
      'host': m['host'],
      'hostKeyFingerprint': m['hostKeyFingerprint'],
      'hostConfirmedAt': decodeUtc(m['hostConfirmedAt'])?.toIso8601String(),
      'hostConfirmedBy': m['hostConfirmedBy'],
      'revokedAt': decodeUtc(m['revokedAt'])?.toIso8601String(),
      'revokedReason': m['revokedReason'],
      'supersedesCredentialId': m['supersedesCredentialId'],
      'version': m['version'],
    });
  }


  // ---------------------------------------------------------------------
  // StandingPolicy (ADR 0019)
  // ---------------------------------------------------------------------

  @override
  Future<void> saveStandingPolicy(
    StandingPolicy policy, {
    int? expectedVersion,
  }) async {
    const cols = '"policyId", "productId", "actionsJson", '
        '"authorisingDecisionId", "authorisedBy", "rationale", '
        '"authorisedAt", "revokedAt", "revokedBy", "revocationDecisionId", '
        '"revocationReason", "version"';
    const vals = '@policyId, @productId, @actionsJson, '
        '@authorisingDecisionId, @authorisedBy, @rationale, @authorisedAt, '
        '@revokedAt, @revokedBy, @revocationDecisionId, @revocationReason, '
        '@version';
    const assignments = '"productId" = @productId, '
        '"actionsJson" = @actionsJson, '
        '"authorisingDecisionId" = @authorisingDecisionId, '
        '"authorisedBy" = @authorisedBy, "rationale" = @rationale, '
        '"authorisedAt" = @authorisedAt, "revokedAt" = @revokedAt, '
        '"revokedBy" = @revokedBy, '
        '"revocationDecisionId" = @revocationDecisionId, '
        '"revocationReason" = @revocationReason, "version" = @version';

    if (expectedVersion != null) {
      final affected = await _db.execute(
        'UPDATE "standing_policy" SET $assignments '
        'WHERE "policyId" = @policyId AND "version" = @expected',
        parameters: QueryParameters.named({
          ..._policyParams(policy),
          'expected': expectedVersion,
        }),
      );
      if (affected == 1) return;

      final rows = await _db.query(
        'SELECT "version" FROM "standing_policy" WHERE "policyId" = @policyId',
        parameters: QueryParameters.named({'policyId': policy.policyId}),
      );
      final actual = rows.isEmpty ? 0 : rows[0].toColumnMap()['version'] as int;
      throw ConcurrentModificationException(
        entityId: policy.policyId,
        expectedVersion: expectedVersion,
        actualVersion: actual,
      );
    }

    await _db.execute(
      'INSERT INTO "standing_policy" ($cols) VALUES ($vals) '
      'ON CONFLICT ("policyId") DO UPDATE SET $assignments',
      parameters: QueryParameters.named(_policyParams(policy)),
    );
  }

  @override
  Future<StandingPolicy> readStandingPolicy(String policyId) async {
    final result = await _db.query(
      'SELECT * FROM "standing_policy" WHERE "policyId" = @policyId',
      parameters: QueryParameters.named({'policyId': policyId}),
    );
    if (result.isEmpty) throw PolicyNotFoundException(policyId);
    return _policyFromRow(result[0]);
  }

  @override
  Future<List<StandingPolicy>> readPoliciesForProduct(String productId) async {
    final result = await _db.query(
      'SELECT * FROM "standing_policy" WHERE "productId" = @productId '
      'ORDER BY "authorisedAt" ASC',
      parameters: QueryParameters.named({'productId': productId}),
    );
    return result.map(_policyFromRow).toList();
  }

  Map<String, Object?> _policyParams(StandingPolicy p) {
    final json = p.toJson();
    return {
      'policyId': json['policyId'],
      'productId': json['productId'],
      'actionsJson': PersistenceDatabase.encodeJson(json['actions']),
      'authorisingDecisionId': json['authorisingDecisionId'],
      'authorisedBy': json['authorisedBy'],
      'rationale': json['rationale'],
      'authorisedAt': PersistenceDatabase.toUtc(p.authorisedAt),
      'revokedAt': PersistenceDatabase.toUtc(p.revokedAt),
      'revokedBy': json['revokedBy'],
      'revocationDecisionId': json['revocationDecisionId'],
      'revocationReason': json['revocationReason'],
      'version': p.version,
    };
  }

  StandingPolicy _policyFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return StandingPolicy.fromJson({
      'policyId': m['policyId'],
      'productId': m['productId'],
      'actions': decodeJsonArray(m['actionsJson'] as String?) ?? const [],
      'authorisingDecisionId': m['authorisingDecisionId'],
      'authorisedBy': m['authorisedBy'],
      'rationale': m['rationale'],
      'authorisedAt': decodeUtc(m['authorisedAt'])?.toIso8601String(),
      'revokedAt': decodeUtc(m['revokedAt'])?.toIso8601String(),
      'revokedBy': m['revokedBy'],
      'revocationDecisionId': m['revocationDecisionId'],
      'revocationReason': m['revocationReason'],
      'version': m['version'],
    });
  }

  // ---------------------------------------------------------------------
  // ProductBaseline
  // ---------------------------------------------------------------------

  @override
  Future<void> saveBaseline(
    ProductBaseline baseline, {
    int? expectedVersion,
  }) async {
    const bareInsert = '''INSERT INTO "product_baseline" (
           "baselineId", "productId", "revision", "status", "factsJson",
           "contentHash", "contentHashVersion", "supersedesBaselineId",
           "proposedAt", "reviewedAt", "acceptedAt", "acceptedBy",
           "acceptedDecisionId", "verifiedAt", "verifiedBy", "verificationKind",
           "createdAt", "updatedAt", "version"
         ) VALUES (
           @baselineId, @productId, @revision, @status, @factsJson,
           @contentHash, @contentHashVersion, @supersedesBaselineId,
           @proposedAt, @reviewedAt, @acceptedAt, @acceptedBy,
           @acceptedDecisionId, @verifiedAt, @verifiedBy, @verificationKind,
           @createdAt, @updatedAt, @version
         )''';

    if (expectedVersion != null) {
      final affected = await _db.execute(
        '''UPDATE "product_baseline" SET
             "productId" = @productId,
             "revision" = @revision,
             "status" = @status,
             "factsJson" = @factsJson,
             "contentHash" = @contentHash,
             "contentHashVersion" = @contentHashVersion,
             "supersedesBaselineId" = @supersedesBaselineId,
             "proposedAt" = @proposedAt,
             "reviewedAt" = @reviewedAt,
             "acceptedAt" = @acceptedAt,
             "acceptedBy" = @acceptedBy,
             "acceptedDecisionId" = @acceptedDecisionId,
             "verifiedAt" = @verifiedAt,
             "verifiedBy" = @verifiedBy,
             "verificationKind" = @verificationKind,
             "createdAt" = @createdAt,
             "updatedAt" = @updatedAt,
             "version" = @version
           WHERE "baselineId" = @baselineId AND "version" = @expected''',
        parameters: QueryParameters.named({
          ..._baselineParams(baseline),
          'version': baseline.version,
          'expected': expectedVersion,
        }),
      );
      if (affected == 1) {
        // Also update facts in baseline_fact table
        await saveBaselineFacts(baseline.baselineId, baseline.facts);
        return;
      }

      final rows = await _db.query(
        '''SELECT "version" FROM "product_baseline" WHERE "baselineId" = @baselineId''',
        parameters: QueryParameters.named({'baselineId': baseline.baselineId}),
      );
      final actual = rows.isEmpty ? 0 : rows[0].toColumnMap()['version'] as int;
      throw ConcurrentModificationException(
        entityId: baseline.baselineId,
        expectedVersion: expectedVersion,
        actualVersion: actual,
      );
    }

    await _db.execute(
      '''$bareInsert ON CONFLICT ("baselineId") DO UPDATE SET
             "productId" = EXCLUDED."productId",
             "revision" = EXCLUDED."revision",
             "status" = EXCLUDED."status",
             "factsJson" = EXCLUDED."factsJson",
             "contentHash" = EXCLUDED."contentHash",
             "contentHashVersion" = EXCLUDED."contentHashVersion",
             "supersedesBaselineId" = EXCLUDED."supersedesBaselineId",
             "proposedAt" = EXCLUDED."proposedAt",
             "reviewedAt" = EXCLUDED."reviewedAt",
             "acceptedAt" = EXCLUDED."acceptedAt",
             "acceptedBy" = EXCLUDED."acceptedBy",
             "acceptedDecisionId" = EXCLUDED."acceptedDecisionId",
             "verifiedAt" = EXCLUDED."verifiedAt",
             "verifiedBy" = EXCLUDED."verifiedBy",
             "verificationKind" = EXCLUDED."verificationKind",
             "createdAt" = EXCLUDED."createdAt",
             "updatedAt" = EXCLUDED."updatedAt",
             "version" = EXCLUDED."version"''',
      parameters: QueryParameters.named(_baselineParams(baseline)),
    );
    // Also save facts to baseline_fact table
    await saveBaselineFacts(baseline.baselineId, baseline.facts);
  }

  @override
  Future<ProductBaseline> readBaseline(String baselineId) async {
    final result = await _db.query(
      '''SELECT * FROM "product_baseline" WHERE "baselineId" = @baselineId''',
      parameters: QueryParameters.named({'baselineId': baselineId}),
    );
    if (result.isEmpty) throw BaselineNotFoundException(baselineId);
    final baseline = _baselineFromRow(result[0]);
    // Load facts from normalized table
    final facts = await readBaselineFacts(baselineId);
    return baseline.copyWith(facts: facts);
  }

  @override
  Future<ProductBaseline?> readBaselineByRevision(
    String productId,
    int revision,
  ) async {
    final result = await _db.query(
      '''SELECT * FROM "product_baseline"
         WHERE "productId" = @productId AND "revision" = @revision
         LIMIT 1''',
      parameters: QueryParameters.named({
        'productId': productId,
        'revision': revision,
      }),
    );
    if (result.isEmpty) return null;
    return _baselineFromRow(result[0]);
  }

  @override
  Future<List<ProductBaseline>> readBaselinesForProduct(
    String productId,
  ) async {
    final result = await _db.query(
      '''SELECT * FROM "product_baseline" WHERE "productId" = @productId
         ORDER BY "revision" DESC''',
      parameters: QueryParameters.named({'productId': productId}),
    );
    return result.map(_baselineFromRow).toList();
  }

  @override
  Future<int> nextBaselineRevision(String productId) async {
    final result = await _db.query(
      '''SELECT COALESCE(MAX("revision"), 0) + 1 AS next_revision
         FROM "product_baseline" WHERE "productId" = @productId''',
      parameters: QueryParameters.named({'productId': productId}),
    );
    final value = result[0].toColumnMap()['next_revision'];
    return value == null ? 1 : (value as num).toInt();
  }

  // ---------------------------------------------------------------------
  // Baseline facts (normalized, queryable)
  // Table: baseline_fact
  // ---------------------------------------------------------------------

  @override
  Future<void> saveBaselineFacts(
    String baselineId,
    List<BaselineFact> facts,
  ) async {
    // Delete existing facts for this baseline
    await _db.execute(
      'DELETE FROM "baseline_fact" WHERE "baselineId" = @baselineId',
      parameters: QueryParameters.named({'baselineId': baselineId}),
    );

    // Insert new facts
    for (final fact in facts) {
      final json = fact.toJson();
      await _db.execute(
        '''INSERT INTO "baseline_fact" (
              "factId", "baselineId", "section", "claim", "provenance",
              "maturity", "evidenceRefsJson", "assumptionNote", "redacted", "version"
            ) VALUES (
              @factId, @baselineId, @section, @claim, @provenance,
              @maturity, @evidenceRefsJson, @assumptionNote, @redacted, @version
            )''',
        parameters: QueryParameters.named({
          'factId': json['factId'],
          'baselineId': baselineId,
          'section': json['section'],
          'claim': json['claim'],
          'provenance': json['provenance'],
          'maturity': json['maturity'],
          'evidenceRefsJson': PersistenceDatabase.encodeJson(json['evidenceRefs']),
          'assumptionNote': json['assumptionNote'],
          'redacted': json['redacted'] ?? false,
          'version': 1,
        }),
      );
    }
  }

  @override
  Future<List<BaselineFact>> readBaselineFacts(String baselineId) async {
    final result = await _db.query(
      '''SELECT * FROM "baseline_fact" WHERE "baselineId" = @baselineId
         ORDER BY "factId" ASC''',
      parameters: QueryParameters.named({'baselineId': baselineId}),
    );
    return result.map(_baselineFactFromRow).toList();
  }

  BaselineFact _baselineFactFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return BaselineFact.fromJson({
      'factId': m['factId'],
      'section': m['section'],
      'claim': m['claim'],
      'provenance': m['provenance'],
      'maturity': m['maturity'],
      'evidenceRefs': decodeJsonArray(m['evidenceRefsJson'] as String?) ?? const [],
      'assumptionNote': m['assumptionNote'],
      'redacted': m['redacted'] ?? false,
    });
  }

  // ---------------------------------------------------------------------
  // Audit log (append-only)
  // Table: product_registry_audit
  // ---------------------------------------------------------------------

  @override
  Future<void> appendAudit(ProductRegistryAudit audit) async {
    final json = audit.toJson();
    await _db.execute(
      '''INSERT INTO "product_registry_audit" (
            "auditId", "productId", "entityType", "entityId", "action",
            "beforeJson", "afterJson", "actor", "timestamp"
          ) VALUES (
            @auditId, @productId, @entityType, @entityId, @action,
            @beforeJson, @afterJson, @actor, @timestamp
          )''',
      parameters: QueryParameters.named({
        'auditId': json['auditId'],
        'productId': json['productId'],
        'entityType': json['entityType'],
        'entityId': json['entityId'],
        'action': json['action'],
        'beforeJson': json['beforeJson'],
        'afterJson': json['afterJson'],
        'actor': json['actor'],
        'timestamp': PersistenceDatabase.toUtc(audit.timestamp),
      }),
    );
  }

  @override
  Future<List<ProductRegistryAudit>> readAuditForProduct(
    String productId, {
    int? limit,
  }) async {
    String sql = '''SELECT * FROM "product_registry_audit"
        WHERE "productId" = @productId
        ORDER BY "timestamp" DESC''';
    if (limit != null) {
      sql += ' LIMIT $limit';
    }
    final result = await _db.query(
      sql,
      parameters: QueryParameters.named({'productId': productId}),
    );
    return result.map(_auditFromRow).toList();
  }

  ProductRegistryAudit _auditFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return ProductRegistryAudit.fromJson({
      'auditId': m['auditId'],
      'productId': m['productId'],
      'entityType': m['entityType'],
      'entityId': m['entityId'],
      'action': m['action'],
      'beforeJson': m['beforeJson'],
      'afterJson': m['afterJson'],
      'actor': m['actor'],
      'timestamp': decodeUtc(m['timestamp'])?.toIso8601String(),
    });
  }

  // ---------------------------------------------------------------------
  // Clarification requests
  // ---------------------------------------------------------------------

  @override
  Future<void> saveClarification(ClarificationRequest request) async {
    await _db.execute(
      '''INSERT INTO "clarification_request" (
             "clarificationId", "productId", "onboardingId", "section",
             "question", "status", "answer", "createdAt",
             "answeredAt", "answeredBy"
           ) VALUES (
             @clarificationId, @productId, @onboardingId, @section,
             @question, @status, @answer, @createdAt,
             @answeredAt, @answeredBy
           )
           ON CONFLICT ("clarificationId") DO UPDATE SET
             "section" = EXCLUDED."section",
             "question" = EXCLUDED."question",
             "status" = EXCLUDED."status",
             "answer" = EXCLUDED."answer",
             "answeredAt" = EXCLUDED."answeredAt",
             "answeredBy" = EXCLUDED."answeredBy"''',
      parameters: QueryParameters.named(_clarificationParams(request)),
    );
  }

  @override
  Future<ClarificationRequest> readClarification(
    String clarificationId,
  ) async {
    final result = await _db.query(
      '''SELECT * FROM "clarification_request" WHERE "clarificationId" = @clarificationId''',
      parameters: QueryParameters.named({'clarificationId': clarificationId}),
    );
    if (result.isEmpty) throw ClarificationNotFoundException(clarificationId);
    return _clarificationFromRow(result[0]);
  }

  @override
  Future<List<ClarificationRequest>> readClarificationsForProduct(
    String productId, {
    ClarificationStatus status = ClarificationStatus.needsAnswer,
  }) async {
    final result = await _db.query(
      '''SELECT * FROM "clarification_request"
         WHERE "productId" = @productId AND "status" = @status
         ORDER BY "createdAt" ASC''',
      parameters: QueryParameters.named({
        'productId': productId,
        'status': status.wire,
      }),
    );
    return result.map(_clarificationFromRow).toList();
  }

  // ---------------------------------------------------------------------
  // Onboarding records
  // ---------------------------------------------------------------------

  @override
  Future<void> saveOnboarding(OnboardingRecord record) async {
    await _db.execute(
      '''INSERT INTO "onboarding_record" (
             "onboardingId", "productId", "currentBaselineRevision",
             "pendingClarifications", "completed", "createdAt",
             "updatedAt", "version"
           ) VALUES (
             @onboardingId, @productId, @currentBaselineRevision,
             @pendingClarifications, @completed, @createdAt,
             @updatedAt, @version
           )
           ON CONFLICT ("productId") DO UPDATE SET
             "onboardingId" = EXCLUDED."onboardingId",
             "currentBaselineRevision" = EXCLUDED."currentBaselineRevision",
             "pendingClarifications" = EXCLUDED."pendingClarifications",
             "completed" = EXCLUDED."completed",
             "createdAt" = EXCLUDED."createdAt",
             "updatedAt" = EXCLUDED."updatedAt",
             "version" = EXCLUDED."version"''',
      parameters: QueryParameters.named(_onboardingParams(record)),
    );
  }

  @override
  Future<OnboardingRecord?> readOnboardingForProduct(
    String productId,
  ) async {
    final result = await _db.query(
      '''SELECT * FROM "onboarding_record" WHERE "productId" = @productId LIMIT 1''',
      parameters: QueryParameters.named({'productId': productId}),
    );
    if (result.isEmpty) return null;
    return _onboardingFromRow(result[0]);
  }

  // ---------------------------------------------------------------------
  // Row mappers
  // ---------------------------------------------------------------------

  Product _productFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return Product.fromJson({
      'productId': m['productId'],
      'name': m['name'],
      'description': m['description'],
      'manifestVersion': m['manifestVersion'],
      'state': m['state'],
      'createdAt': decodeUtc(m['createdAt'])?.toIso8601String(),
      'updatedAt': decodeUtc(m['updatedAt'])?.toIso8601String(),
      'version': m['version'],
    });
  }

  RepositoryReference _repositoryFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return RepositoryReference.fromJson({
      'repositoryId': m['repositoryId'],
      'productId': m['productId'],
      'kind': m['kind'],
      'uri': m['uri'],
      'provider': m['provider'],
      'addedAt': decodeUtc(m['addedAt'])?.toIso8601String(),
      'version': m['version'],
    });
  }

  ProductBaseline _baselineFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return ProductBaseline.fromJson({
      'baselineId': m['baselineId'],
      'productId': m['productId'],
      'revision': m['revision'],
      'status': m['status'],
      'facts': decodeJsonArray(m['factsJson'] as String?) ?? const [],
      'contentHash': m['contentHash'],
      'contentHashVersion': m['contentHashVersion'] ?? 1,
      'supersedesBaselineId': m['supersedesBaselineId'],
      'proposedAt': decodeUtc(m['proposedAt'])?.toIso8601String(),
      'reviewedAt': decodeUtc(m['reviewedAt'])?.toIso8601String(),
      'acceptedAt': decodeUtc(m['acceptedAt'])?.toIso8601String(),
      'acceptedBy': m['acceptedBy'],
      'acceptedDecisionId': m['acceptedDecisionId'],
      'verifiedAt': decodeUtc(m['verifiedAt'])?.toIso8601String(),
      'verifiedBy': m['verifiedBy'],
      'verificationKind': m['verificationKind'],
      'createdAt': decodeUtc(m['createdAt'])?.toIso8601String(),
      'updatedAt': decodeUtc(m['updatedAt'])?.toIso8601String(),
      'version': m['version'],
    });
  }

  ClarificationRequest _clarificationFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return ClarificationRequest.fromJson({
      'clarificationId': m['clarificationId'],
      'productId': m['productId'],
      'onboardingId': m['onboardingId'],
      'section': m['section'],
      'question': m['question'],
      'status': m['status'],
      'answer': m['answer'],
      'createdAt': decodeUtc(m['createdAt'])?.toIso8601String(),
      'answeredAt': decodeUtc(m['answeredAt'])?.toIso8601String(),
      'answeredBy': m['answeredBy'],
    });
  }

  OnboardingRecord _onboardingFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return OnboardingRecord.fromJson({
      'onboardingId': m['onboardingId'],
      'productId': m['productId'],
      'currentBaselineRevision': m['currentBaselineRevision'],
      'pendingClarifications': m['pendingClarifications'],
      'completed': m['completed'],
      'createdAt': decodeUtc(m['createdAt'])?.toIso8601String(),
      'updatedAt': decodeUtc(m['updatedAt'])?.toIso8601String(),
      'version': m['version'],
    });
  }

  // ---------------------------------------------------------------------
  // Param mappers
  // ---------------------------------------------------------------------

  Map<String, Object?> _productParams(Product product) {
    final json = product.toJson();
    return {
      'productId': json['productId'],
      'name': json['name'],
      'description': json['description'],
      'manifestVersion': json['manifestVersion'],
      'state': json['state'],
      'createdAt': PersistenceDatabase.toUtc(product.createdAt),
      'updatedAt': PersistenceDatabase.toUtc(product.updatedAt),
      'version': product.version,
    };
  }

  Map<String, Object?> _repositoryParams(RepositoryReference reference) {
    final json = reference.toJson();
    return {
      'repositoryId': json['repositoryId'],
      'productId': json['productId'],
      'kind': json['kind'],
      'uri': json['uri'],
      'provider': json['provider'],
      'addedAt': PersistenceDatabase.toUtc(reference.addedAt),
      'version': reference.version,
    };
  }

  Map<String, Object?> _baselineParams(ProductBaseline baseline) {
    final json = baseline.toJson();
    return {
      'baselineId': json['baselineId'],
      'productId': json['productId'],
      'revision': json['revision'],
      'status': json['status'],
      'factsJson': PersistenceDatabase.encodeJson(json['facts']),
      'contentHash': json['contentHash'],
      'contentHashVersion': json['contentHashVersion'] ?? 1,
      'supersedesBaselineId': json['supersedesBaselineId'],
      'proposedAt': PersistenceDatabase.toUtc(baseline.proposedAt),
      'reviewedAt': PersistenceDatabase.toUtc(baseline.reviewedAt),
      'acceptedAt': PersistenceDatabase.toUtc(baseline.acceptedAt),
      'acceptedBy': json['acceptedBy'],
      'acceptedDecisionId': json['acceptedDecisionId'],
      'verifiedAt': PersistenceDatabase.toUtc(baseline.verifiedAt),
      'verifiedBy': json['verifiedBy'],
      'verificationKind': json['verificationKind'],
      'createdAt': PersistenceDatabase.toUtc(baseline.createdAt),
      'updatedAt': PersistenceDatabase.toUtc(baseline.updatedAt),
      'version': baseline.version,
    };
  }

  Map<String, Object?> _clarificationParams(ClarificationRequest request) {
    final json = request.toJson();
    return {
      'clarificationId': json['clarificationId'],
      'productId': json['productId'],
      'onboardingId': json['onboardingId'],
      'section': json['section'],
      'question': json['question'],
      'status': json['status'],
      'answer': json['answer'],
      'createdAt': PersistenceDatabase.toUtc(request.createdAt),
      'answeredAt': PersistenceDatabase.toUtc(request.answeredAt),
      'answeredBy': json['answeredBy'],
    };
  }

  Map<String, Object?> _onboardingParams(OnboardingRecord record) {
    final json = record.toJson();
    return {
      'onboardingId': json['onboardingId'],
      'productId': json['productId'],
      'currentBaselineRevision': json['currentBaselineRevision'],
      'pendingClarifications': json['pendingClarifications'],
      'completed': json['completed'],
      'createdAt': PersistenceDatabase.toUtc(record.createdAt),
      'updatedAt': PersistenceDatabase.toUtc(record.updatedAt),
      'version': record.version,
    };
  }
}
