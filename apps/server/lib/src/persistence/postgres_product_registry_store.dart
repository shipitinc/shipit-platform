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
  //
  // THREE GUARDS, all in the statement, none of them in a read before it.
  //
  // 1. KEY MATERIAL IS IMMUTABLE — `publicKey`, `fingerprint`, `algorithm`,
  //    `referenceName` — on the CAS branch below.
  //
  // 2. THE SCOPE SET IS IMMUTABLE — `productId`, `repositoryId`. ADR 0018 A1
  //    makes the repository the unit of scope, so these two fields say what the
  //    key is allowed to reach, and they are as fixed-at-mint as the key
  //    itself. They were in `$assignments` on both branches and in no predicate,
  //    so a CAS write could move an installed deploy key to another repository
  //    of the same product: no rotation record, `supersedesCredentialId`
  //    untouched, and any host confirmation travelling with it to a host whose
  //    key was never shown to anybody (ADR 0018: "the operator is shown the
  //    host, key type and fingerprint and must confirm it").
  //
  // 3. A MINT NEVER OVERWRITES AN EXISTING IDENTITY — the null-`expectedVersion`
  //    branch is `DO NOTHING`, not a predicated `DO UPDATE`. `DO UPDATE` was the
  //    wrong construct for a predicate that is SATISFIED by identical values:
  //    an identical-material re-mint passed it and rewrote every mutable column
  //    from the freshly minted object, resetting `status` to `generated`,
  //    `hostKeyStatus` to `unknown` and nulling host confirmation, verification,
  //    diagnostics and revocation evidence. It also made a REVOKED credential
  //    resurrectable, because `readActiveCredentialForRepository` excludes
  //    revoked rows, so the engine's one-active guard cannot fire against one —
  //    and the resurrected row then occupies the active set, so the legitimate
  //    replacement mint is refused by `_activeCredentialUniqueIndex`. `DO
  //    NOTHING` refuses the conflict regardless of what the caller supplied,
  //    which is also why it cannot keep the key-material distinction alive on
  //    this branch: there is nothing left to update.
  //
  //    Rotation mints a NEW `credentialId`, so nothing legitimate is lost.
  //
  // DURABLE EVIDENCE CANNOT BE CLEARED on the CAS branch: `hostConfirmedAt`,
  // `hostConfirmedBy`, `lastVerifiedAt`, `lastVerifiedBy`, `revokedAt`,
  // `revokedReason` and `hostKeyFingerprint` record decisions and events that
  // happened. `copyWith` cannot unset them, which is what keeps every engine
  // call site away from this today; the predicate is what makes it true against
  // any other connection.
  //
  // ONE ACTIVE CREDENTIAL PER REPOSITORY is enforced by
  // `_activeCredentialUniqueIndex`, a partial unique index declared in
  // `tool/schema_bootstrap.sql`. It cannot be an `ON CONFLICT` arbiter like
  // `credentialId` is, because the two are different invariants: here the
  // correct outcome of a conflict is to REFUSE, not to update. So the loser of
  // that race reaches this method as a Postgres unique violation and is
  // translated below into the same typed refusal every other refusal here
  // raises, rather than leaking a driver exception through the domain API.
  // ---------------------------------------------------------------------

  /// Name of the partial unique index that enforces one active credential per
  /// repository. Must match `tool/schema_bootstrap.sql`; it is the name the
  /// driver reports in [DatabaseQueryException.constraintName] when the index
  /// refuses a write.
  static const _activeCredentialUniqueIndex =
      'product_credential_active_repository_unique';

  /// Postgres SQLSTATE for `unique_violation`.
  static const _uniqueViolationSqlState = '23505';

  /// The predicate refusing a CAS write that CLEARS the recorded value of
  /// `"column"`, while still allowing one that sets it or leaves it alone.
  ///
  /// THE CAST IS LOAD-BEARING, and so is [type]. Serverpod binds every
  /// parameter here as `Type.unspecified` and lets the server infer the type,
  /// and a bare `@param IS NOT NULL` gives Postgres nothing to infer from: the
  /// statement then fails at Parse time with `42P08 could not determine data
  /// type of parameter $n`, before a single row is examined. Verified on this
  /// file's own statement, not read out of the docs. Casting to `text` does not
  /// work either — it pins the parameter to `text`, and the assignment in SET
  /// then fails with `42804 column "lastVerifiedAt" is of type timestamp
  /// without time zone but expression is of type text`. The cast has to name
  /// the column's real type, which is what [type] is.
  ///
  /// [type] is read off `migrations/*/definition.sql`. If a column's type ever
  /// changes, this statement starts failing at Parse time on every CAS write —
  /// loudly, and inside this file's integration tests, not silently.
  static String _noClear(String column, String type) =>
      'AND ("$column" IS NULL OR CAST(@$column AS $type) IS NOT NULL)';

  /// `timestamp without time zone`, as declared for the credential timestamps
  /// in `migrations/*/definition.sql`.
  static const _timestampType = 'timestamp';

  @override
  Future<void> saveProductCredential(
    RepositoryCredential credential, {
    int? expectedVersion,
  }) async {
    const cols =
        '"credentialId", "productId", "repositoryId", '
        '"referenceName", "publicKey", "fingerprint", "algorithm", "status", '
        '"createdAt", "lastVerifiedAt", "lastVerifiedBy", "lastFailureReason", '
        '"hostKeyStatus", "host", "hostKeyFingerprint", "hostConfirmedAt", '
        '"hostConfirmedBy", "revokedAt", "revokedReason", '
        '"supersedesCredentialId", "version"';
    const vals =
        '@credentialId, @productId, @repositoryId, @referenceName, '
        '@publicKey, @fingerprint, @algorithm, @status, @createdAt, '
        '@lastVerifiedAt, @lastVerifiedBy, @lastFailureReason, '
        '@hostKeyStatus, @host, @hostKeyFingerprint, @hostConfirmedAt, '
        '@hostConfirmedBy, @revokedAt, @revokedReason, '
        '@supersedesCredentialId, @version';
    const assignments =
        '"productId" = @productId, '
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

    final params = _credentialParams(credential);

    if (expectedVersion != null) {
      // Three predicates, all UNCONDITIONAL: the store contract in
      // `product_registry_store.dart` holds whether or not the caller passed a
      // version, because a matching `expectedVersion` must not buy a rewrite of
      // anything fixed at mint.
      //
      //   * key material — without this the CAS branch silently rewrote
      //     `publicKey`, so the two tiers disagreed: the in-memory store
      //     refused, this one accepted;
      //   * scope — `productId`/`repositoryId` were in `$assignments` and in no
      //     predicate, so a CAS write could re-point an installed deploy key;
      //   * durable evidence — each clause refuses a non-null → null
      //     transition, so re-recording a host confirmation with a fresh
      //     timestamp still lands and erasing what is on the record does not.
      //
      // All of it is in the statement, not in a read before it, so it holds
      // against any other connection.
      final affected = await _db.execute(
        'UPDATE "product_credential" SET $assignments '
        'WHERE "credentialId" = @credentialId AND "version" = @expected '
        'AND "publicKey" = @publicKey '
        'AND "fingerprint" = @fingerprint '
        'AND "algorithm" = @algorithm '
        'AND "referenceName" = @referenceName '
        'AND "productId" = @productId '
        'AND "repositoryId" = @repositoryId '
        '${_noClear("hostConfirmedAt", _timestampType)} '
        '${_noClear("hostConfirmedBy", 'text')} '
        '${_noClear("lastVerifiedAt", _timestampType)} '
        '${_noClear("lastVerifiedBy", 'text')} '
        '${_noClear("hostKeyFingerprint", 'text')} '
        '${_noClear("revokedAt", _timestampType)} '
        '${_noClear("revokedReason", 'text')}',
        parameters: QueryParameters.named({
          ...params,
          'expected': expectedVersion,
        }),
      );
      if (affected == 1) return;

      // Zero rows is ambiguous: the version may have moved, the key material may
      // have been re-pointed, the scope may have been changed, or recorded
      // evidence may have been cleared. Distinguish them by reading the row
      // back, so the caller is told WHICH invariant it violated. A caller that
      // re-points key material must not be told "concurrent modification", or it
      // will retry the same re-point and eventually succeed on a version match.
      final rows = await _db.query(
        'SELECT "version", "publicKey", "fingerprint", "algorithm", '
        '"referenceName", "productId", "repositoryId", "hostConfirmedAt", '
        '"hostConfirmedBy", "lastVerifiedAt", "lastVerifiedBy", '
        '"hostKeyFingerprint", "revokedAt", "revokedReason" '
        'FROM "product_credential" WHERE "credentialId" = @credentialId',
        parameters: QueryParameters.named({
          'credentialId': credential.credentialId,
        }),
      );

      if (rows.isEmpty) {
        throw ConcurrentModificationException(
          entityId: credential.credentialId,
          expectedVersion: expectedVersion,
          actualVersion: 0,
        );
      }

      final existing = rows[0].toColumnMap();
      // Immutability refusals FIRST, in a fixed order, and ahead of the version
      // conflict. Order among them is only for a stable message: each is its own
      // defect and none of them is a lost race.
      if (existing['publicKey'] != credential.publicKey ||
          existing['fingerprint'] != credential.fingerprint ||
          existing['algorithm'] != credential.algorithm ||
          existing['referenceName'] != credential.referenceName) {
        throw CredentialNotUsableException(
          credential.credentialId,
          'the key material of an existing credential cannot be changed; rotate '
          'it to issue a new credentialId instead',
        );
      }
      if (existing['productId'] != credential.productId ||
          existing['repositoryId'] != credential.repositoryId) {
        throw CredentialNotUsableException(
          credential.credentialId,
          'the scope of an existing credential cannot be changed; it belongs to '
          'the product and repository it was minted for, and re-pointing a key '
          'means minting a new credentialId',
        );
      }
      for (final column in const [
        'hostConfirmedAt',
        'hostConfirmedBy',
        'lastVerifiedAt',
        'lastVerifiedBy',
        'hostKeyFingerprint',
        'revokedAt',
        'revokedReason',
      ]) {
        // Only a null on either side can clear the column, so this compares
        // presence rather than values — the stored side comes back as a
        // `DateTime` for the timestamp columns and the supplied one is a
        // string, so a value comparison would be wrong twice over.
        if (existing[column] != null && params[column] == null) {
          throw CredentialNotUsableException(
            credential.credentialId,
            'the $column of an existing credential is a recorded fact and '
            'cannot be cleared; host confirmation, verification and revocation '
            'stay readable',
          );
        }
      }

      throw ConcurrentModificationException(
        entityId: credential.credentialId,
        expectedVersion: expectedVersion,
        actualVersion: existing['version'] as int,
      );
    }

    // THE MINT IS INSERT-ONLY. `DO NOTHING`, not a predicated `DO UPDATE`:
    // a conflicting `credentialId` updates nothing at all, whatever the caller
    // supplied. That is the whole point — the previous `DO UPDATE` predicated on
    // the four immutable fields being UNCHANGED, so a re-mint with identical
    // material satisfied it and rewrote every mutable column of an existing
    // row, and a predicating `DO UPDATE … WHERE <always false>` would have the
    // same effect while keeping the predicate alive as an accidental second
    // source of truth for a rule that is now "a mint never writes".
    //
    // `RETURNING` is the detection mechanism: `DO NOTHING` returns no row for a
    // conflict, and an empty result cannot be ignored by accident the way an
    // affected-row count can.
    //
    // Only THIS branch can be refused by `_activeCredentialUniqueIndex`, and so
    // only this one translates it. The `expectedVersion` branch above is an
    // UPDATE, and no reachable path moves a credential from revoked back into
    // the active set: `revokeCredential` is the only writer of `revoked`,
    // `recordCredentialCheck` refuses a revoked credential outright, and D-4
    // removes the mint's ability to resurrect one — so the index can never be
    // the constraint an UPDATE trips. `rotateCredential` relies on that
    // ordering: it revokes first, so the old row leaves the index before the
    // replacement is inserted.
    DatabaseResult written;
    try {
      written = await _db.query(
        'INSERT INTO "product_credential" ($cols) VALUES ($vals) '
        'ON CONFLICT ("credentialId") DO NOTHING '
        'RETURNING "credentialId"',
        parameters: QueryParameters.named(params),
      );
    } on DatabaseQueryException catch (error) {
      if (error.code != _uniqueViolationSqlState ||
          error.constraintName != _activeCredentialUniqueIndex) {
        rethrow;
      }
      // Another caller minted for this repository first. Matched on SQLSTATE
      // AND index name, not on message text: this refuses exactly the race
      // `_activeCredentialUniqueIndex` exists to refuse, and every other
      // database error keeps its own type and reaches the caller unchanged.
      throw CredentialNotUsableException(
        credential.credentialId,
        'repository ${credential.repositoryId} already has an active '
        'credential; another caller recorded one first, so rotate it instead '
        'of issuing a second one',
      );
    }
    if (written.isNotEmpty) return;

    // The id is taken. Reported as an IDENTITY conflict and not as a
    // key-material one: `DO NOTHING` cannot see the supplied material, and
    // telling a caller that re-minted with a different key that its key was
    // refused would be false. Both are defects, both leave the row untouched,
    // and the remedy is the same — a NEW `credentialId`, or `rotateCredential`.
    throw CredentialNotUsableException(
      credential.credentialId,
      'a credential with this id already exists; minting is insert-only, so '
      'issue a NEW credentialId — or use rotateCredential — instead of '
      're-minting this one',
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
    const cols =
        '"policyId", "productId", "actionsJson", '
        '"authorisingDecisionId", "authorisedBy", "rationale", '
        '"authorisedAt", "revokedAt", "revokedBy", "revocationDecisionId", '
        '"revocationReason", "version"';
    const vals =
        '@policyId, @productId, @actionsJson, '
        '@authorisingDecisionId, @authorisedBy, @rationale, @authorisedAt, '
        '@revokedAt, @revokedBy, @revocationDecisionId, @revocationReason, '
        '@version';
    const assignments =
        '"productId" = @productId, '
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
          'evidenceRefsJson': PersistenceDatabase.encodeJson(
            json['evidenceRefs'],
          ),
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
      'evidenceRefs':
          decodeJsonArray(m['evidenceRefsJson'] as String?) ?? const [],
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
