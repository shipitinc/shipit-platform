import 'dart:async';
import 'dart:io';

import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_human_decision_store.dart';
import 'package:control_plane_server/src/persistence/postgres_product_registry_store.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// Store-level proof that SHIP IT's credential persistence upholds the
/// immutability guarantee its own domain contract asserts (ADR 0018 A1).
///
/// This runs against REAL PostgreSQL, not a fake, because the two defects it
/// covers are properties of the database and cannot be demonstrated by an
/// in-memory map:
///
///   * `T-A` — a same-id re-mint must be refused. The guard is a predicating
///     `ON CONFLICT ... DO UPDATE ... WHERE`, so only the real statement proves
///     it; a read-then-write implementation would look identical here and be
///     racy against another connection.
///   * `T-B` — two concurrent mints for one repository must yield exactly one
///     active row. That is a unique index, and an in-memory store cannot have
///     one.
///   * `M-2` — the CAS branch of `saveProductCredential` must refuse a
///     key-material change too. Asserted on this tier as well as in-memory,
///     because a predicate that exists on only one tier is the same defect this
///     file exists to catch.
///   * `GAP-2` — a CHAIN-MIGRATED database must carry the index, not just a
///     freshly bootstrapped one. That is the entire reason the index has a
///     migration counterpart: a fresh database already had it, so testing only
///     the fresh path proves nothing about what deployment actually applies.
///
/// Both run through `ProductRegistryEngine`, i.e. the public domain API, with
/// no feature code in the picture — these paths are reachable today.
const _productId = 'credimm-fixture';
const _repoId = 'credimm-repo-1';

/// The partial unique index enforcing one active credential per repository.
const _activeIndexName = 'product_credential_active_repository_unique';

/// Schema the chain replay below builds.
///
/// NOT `public`: `test/integration` shares one database with files that run
/// concurrently, and a chain replay creates a whole schema from scratch. It is
/// dropped in `tearDown` and re-created per test, so it cannot outlive the run.
const _chainSchema = 'shipit_chain_replay';

const _pub = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO8vK2mN shipit+repo-1';
const _fp = 'SHA256:0Hq7xK2mN8vR4tL9wQ3sB6y';
const _hostFp = 'SHA256:+DiY3wvvV6TuJJhbpZisF';
const _pub2 = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP4mQ8 shipit+repo-2';
const _fp2 = 'SHA256:P4mQ8new';

/// Every session opened during a test is registered so it can be closed in
/// [tearDown]; the test host's connection pool is finite and leaked sessions
/// starve concurrent sibling test groups.
final List<Session> _openSessions = <Session>[];

Future<PersistenceDatabase> _newDb() async {
  final session = await Serverpod.instance.createSession(enableLogging: false);
  _openSessions.add(session);
  return PersistenceDatabase(session.db);
}

Future<void> _closeSessions() async {
  for (final session in List.of(_openSessions)) {
    await session.close();
  }
  _openSessions.clear();
}

/// Removes only this suite's rows, in an order that satisfies foreign keys.
///
/// Targeted DELETEs, never a TRUNCATE: `test/integration` shares one database
/// with files that run concurrently, and truncating `product` out from under
/// them breaks their assertions. Every statement is scoped to this file's
/// fixture Product, so no other file's row can match. Runs in `setUp` as well
/// as `tearDown`, because a previous run that aborted mid-test leaves rows
/// behind and re-registering the Product would then violate a unique
/// constraint.
Future<void> _purgeSuiteRows() async {
  final db = await _newDb();
  const statements = <String>[
    'DELETE FROM "product_credential" WHERE "productId" = \'$_productId\'',
    'DELETE FROM "repository_reference" WHERE "productId" = \'$_productId\'',
    'DELETE FROM "product" WHERE "productId" = \'$_productId\'',
  ];
  for (final statement in statements) {
    await db.query(statement);
  }
}

Future<ProductRegistryEngine> _engine(ProductRegistryStore store) async {
  final db = await _newDb();
  return ProductRegistryEngine(
    store: store,
    humanDecisionStore: PostgresHumanDecisionStore(PostgresWorkflowStore(db)),
  );
}

// ---------------------------------------------------------------------------
// Chain replay helpers (GAP-2)
//
// These read `migrations/*/migration.sql` off disk and replay them into a
// scratch schema. That is deliberately NOT the same as what `make
// test-integration` does to `public` (Serverpod's fresh-database path, which
// applies only the latest `definition.sql`, plus `tool/schema_bootstrap.sql`):
// the path under test here is the one a database that already has a recorded
// migration version takes, which is the path a deployed database takes.
// ---------------------------------------------------------------------------

/// Every `migrations/*/migration.sql`, oldest first.
///
/// That is the order Serverpod replays them in: `listVersions()` lists the
/// migration DIRECTORIES and sorts them lexically
/// (serverpod-3.4.13 `migrations/migration_artifacts_store/file_system.dart:37-42`),
/// and `_getVersionsToApply` returns a positional slice of that sorted list.
/// `migration_registry.txt` is not consulted at all, so it is not read here.
List<File> _chainMigrations() {
  final directory = Directory('migrations');
  if (!directory.existsSync()) {
    throw StateError(
      'migrations/ not found from ${Directory.current.path}. The chain replay '
      'must run with apps/server as the working directory.',
    );
  }
  final files =
      directory
          .listSync()
          .whereType<Directory>()
          .map((d) => File('${d.path}/migration.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    throw StateError('no migrations/*/migration.sql found to replay');
  }
  return files;
}

/// The oldest migration whose `migration.sql` declares [_activeIndexName].
///
/// Located by content rather than hard-coded to a version, so adding a later
/// unrelated migration cannot silently turn this into a test of the wrong file.
File _migrationDeclaringIndex() {
  final declaring = _chainMigrations()
      .where((file) => file.readAsStringSync().contains(_activeIndexName))
      .toList();
  if (declaring.isEmpty) {
    throw StateError(
      'no migrations/*/migration.sql declares $_activeIndexName, so the chain '
      'cannot create it and a chain-migrated database will not have it. This '
      'is GAP-2: the index exists in tool/schema_bootstrap.sql only.',
    );
  }
  return declaring.first;
}

/// The migration version a chain file belongs to, i.e. its directory name.
String _versionOf(File migration) =>
    migration.parent.path.split(Platform.pathSeparator).last;

/// The chain as ONE simple-query batch for [db] to execute inside
/// `$_chainSchema`.
///
/// Three properties of the shape below are load-bearing, and each one was a
/// real failure before it was pinned:
///
///   * every statement runs on ONE connection, which is what makes the
///     `search_path` hold for the whole replay instead of drifting between
///     pooled connections;
///   * `SET LOCAL`, inside the explicit transaction, not a bare `SET`. A bare
///     `SET` is session state: the connection goes back to Serverpod's pool
///     still carrying it, and the next statement to borrow that connection runs
///     against the wrong schema. That is not hypothetical — it surfaced as
///     `relation "product_credential" does not exist` in this file's own
///     `tearDown`. `SET LOCAL` is scoped to the transaction, so the reverted
///     statement never touches the connection, and it reverts even when the
///     transaction aborts;
///   * the explicit `BEGIN`/`COMMIT`, so a migration that fails rolls the whole
///     replay back. That is what lets the duplicate-credential case below assert
///     the failed migration changed nothing at all.
///
/// Each shipped file's own `BEGIN;`/`COMMIT;` wrapper is stripped first:
/// nested inside this one they are a no-op at best and would end the enclosing
/// transaction at worst. Nothing else is altered — the statements replayed are
/// the shipped ones, in the shipped order.
///
/// [omit] drops one migration from the replay; [only] replays just that one.
/// Exactly one of them is ever passed.
String _chainScript({File? omit, File? only}) {
  final buffer = StringBuffer()
    ..writeln('BEGIN;')
    ..writeln('SET LOCAL search_path TO "$_chainSchema";');
  for (final file in _chainMigrations()) {
    if (only != null) {
      if (file.path != only.path) continue;
    } else if (omit != null && file.path == omit.path) {
      continue;
    }
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed == 'BEGIN;' || trimmed == 'COMMIT;') continue;
      buffer.writeln(line);
    }
    buffer.writeln(';');
  }
  buffer.writeln('COMMIT;');
  return buffer.toString();
}

/// `pg_indexes.indexdef` for [_activeIndexName] in [schema], or null.
Future<String?> _indexDefinition(PersistenceDatabase db, String schema) async {
  final rows = await db.queryNoTransaction(
    'SELECT indexdef FROM pg_indexes WHERE schemaname = \'$schema\' '
    'AND indexname = \'$_activeIndexName\'',
  );
  return rows.isEmpty ? null : rows.first.toColumnMap()['indexdef'] as String;
}

/// The `control_plane` version [schema] recorded, or null when it recorded none.
Future<String?> _recordedControlPlaneVersion(
  PersistenceDatabase db,
  String schema,
) async {
  final rows = await db.queryNoTransaction(
    'SELECT version FROM "$schema"."serverpod_migrations" '
    "WHERE module = 'control_plane'",
  );
  return rows.isEmpty ? null : rows.first.toColumnMap()['version'] as String;
}

/// Drops and re-creates the scratch schema, so a run that aborted mid-replay
/// cannot make the next one fail on objects that already exist.
Future<void> _resetChainSchema(PersistenceDatabase db) async {
  await db.db.unsafeSimpleExecute(
    'DROP SCHEMA IF EXISTS "$_chainSchema" CASCADE',
  );
  await db.db.unsafeSimpleExecute('CREATE SCHEMA "$_chainSchema"');
}

/// Removes the scratch schema. Called from `tearDown` so the database this run
/// touched carries nothing of it forward.
Future<void> _dropChainSchema(PersistenceDatabase db) =>
    db.db.unsafeSimpleExecute('DROP SCHEMA IF EXISTS "$_chainSchema" CASCADE');

/// Mints `cred-1` and takes it all the way to verified-with-confirmed-host, so
/// the row under test holds state a silent overwrite would destroy.
Future<RepositoryCredential> _fullyVerified(
  ProductRegistryEngine engine,
) async {
  await engine.recordGeneratedCredential(
    productId: _productId,
    repositoryId: _repoId,
    referenceName: 'GIT_PRODUCT_CREDIMM_REPO1_SSH',
    publicKey: _pub,
    fingerprint: _fp,
    host: 'github.com',
    credentialId: 'cred-1',
  );
  await engine.confirmHostKey(
    productId: _productId,
    credentialId: 'cred-1',
    hostKeyFingerprint: _hostFp,
    confirmedBy: 'operator',
  );
  return engine.recordCredentialCheck(
    productId: _productId,
    credentialId: 'cred-1',
    succeeded: true,
    checkedBy: 'operator',
  );
}

void main() {
  withServerpod(
    'Postgres upholds credential key-material immutability (ADR 0018 A1)',
    (sessionBuilder, endpoints) {
      setUp(() async {
        await _purgeSuiteRows();
        final db = await _newDb();
        final engine = await _engine(PostgresProductRegistryStore(db));
        await engine.createProduct(productId: _productId, name: 'CredImm');
        await engine.addRepositoryReference(
          repositoryId: _repoId,
          productId: _productId,
          uri: 'git@github.com:acme/shipit-platform.git',
          provider: RepositoryProvider.github,
        );
      });

      tearDown(() async {
        await _purgeSuiteRows();
        // Before the sessions close: the scratch schema belongs to a connection
        // they own, and this database is shared with files that run
        // concurrently.
        await _dropChainSchema(await _newDb());
        await _closeSessions();
      });

      test(
        'T-A: a same-id re-mint is refused and the stored row is untouched',
        () async {
          final engine = await _engine(
            PostgresProductRegistryStore(await _newDb()),
          );
          final before = await _fullyVerified(engine);
          expect(before.publicKey, _pub);

          await expectLater(
            engine.recordGeneratedCredential(
              productId: _productId,
              repositoryId: _repoId,
              // Same identity, self-superseding: passes the engine's one-active
              // rule (engine:940-941) and reaches the write with a NULL
              // expectedVersion.
              credentialId: 'cred-1',
              supersedesCredentialId: 'cred-1',
              referenceName: 'GIT_PRODUCT_CREDIMM_REPO1_ROTATED',
              publicKey: _pub2,
              fingerprint: _fp2,
              algorithm: 'ecdsa-sha2-nistp256',
              host: 'github.com',
            ),
            throwsA(isA<CredentialNotUsableException>()),
          );

          final after = await engine.readCredentials(_productId);
          final stored = after.firstWhere((c) => c.credentialId == 'cred-1');
          expect(
            stored.publicKey,
            _pub,
            reason: 'the installed key must survive the refused write',
          );
          expect(stored.fingerprint, _fp);
          expect(stored.algorithm, 'ed25519');
          expect(stored.referenceName, 'GIT_PRODUCT_CREDIMM_REPO1_SSH');
          expect(stored.status, CredentialStatus.verified);
          expect(stored.hostKeyStatus, HostKeyStatus.confirmed);
          expect(stored.hostConfirmedAt, isNotNull);
          expect(stored.hostConfirmedBy, 'operator');
          expect(stored.version, before.version);
          expect(
            stored,
            before,
            reason: 'the refusal must change nothing at all on the row',
          );
        },
      );

      test(
        'the first mint of a new id still succeeds against Postgres',
        () async {
          // The guard predicates the immutable fields, so it must not refuse a
          // row that does not exist. A CAS-shaped guard breaks exactly here: the
          // mint passes no `expectedVersion`, and the hardcoded `version: 1`
          // would match no row, so a first mint would throw
          // ConcurrentModificationException(expected 1, actual 0).
          final engine = await _engine(
            PostgresProductRegistryStore(await _newDb()),
          );
          final minted = await engine.recordGeneratedCredential(
            productId: _productId,
            repositoryId: _repoId,
            referenceName: 'GIT_PRODUCT_CREDIMM_REPO1_SSH',
            publicKey: _pub,
            fingerprint: _fp,
            host: 'github.com',
            credentialId: 'cred-first',
          );
          expect(minted.status, CredentialStatus.generated);
          final stored = await engine.readCredentials(_productId);
          expect(stored, hasLength(1));
          expect(stored.single.publicKey, _pub);
        },
      );

      test('rotation still works and mints a new id with a new key', () async {
        final engine = await _engine(
          PostgresProductRegistryStore(await _newDb()),
        );
        await _fullyVerified(engine);

        final rotated = await engine.rotateCredential(
          productId: _productId,
          repositoryId: _repoId,
          referenceName: 'GIT_PRODUCT_CREDIMM_REPO1_SSH',
          publicKey: _pub2,
          fingerprint: _fp2,
          reason: 'scheduled rotation',
          credentialId: 'cred-2',
        );

        expect(rotated.credentialId, 'cred-2');
        expect(rotated.supersedesCredentialId, 'cred-1');
        expect(rotated.publicKey, _pub2);
        expect(rotated.status, CredentialStatus.generated);
        expect(
          rotated.hostKeyStatus,
          HostKeyStatus.unknown,
          reason: 'host confirmation does not carry over to a new key',
        );
        expect(rotated.hostConfirmedAt, isNull);
        expect(rotated.hostConfirmedBy, isNull);

        final all = await engine.readCredentials(_productId);
        expect(all, hasLength(2));
        final old = all.firstWhere((c) => c.credentialId == 'cred-1');
        expect(
          old.publicKey,
          _pub,
          reason: 'the superseded row keeps the key it was minted with',
        );
        expect(old.status, CredentialStatus.revoked);
        final active = all.where((c) => c.status != CredentialStatus.revoked);
        expect(active, hasLength(1), reason: 'rotation leaves one active row');
      });

      test(
        'T-B: two concurrent mints for one repository yield one active row',
        () async {
          // Both engines must get PAST the engine's one-active read before
          // either writes, otherwise the second is refused by that read and the
          // test would pass without the database ever being asked to choose.
          // [_GatedStore] blocks each caller's read until both have arrived.
          //
          // THIS IS THE D-2 TEST, and it is the only thing that can hold it
          // green: the refusal has to come from a partial unique index on the
          // active set,
          //
          //   CREATE UNIQUE INDEX "product_credential_active_repository_unique"
          //     ON "product_credential" USING btree ("repositoryId")
          //     WHERE ("status" <> 'revoked');
          //
          // declared in `tool/schema_bootstrap.sql`, whose predicate is
          // identical to the read that defines "active" in
          // `readActiveCredentialForRepository`. No application-level change can
          // substitute for it: both of these calls have already passed every
          // check the domain makes.
          final gate = _ReadBarrier();
          final dbA = await _newDb();
          final dbB = await _newDb();
          final engineA = await _engine(_GatedStore(dbA, gate));
          final engineB = await _engine(_GatedStore(dbB, gate));

          Future<RepositoryCredential> mint(
            ProductRegistryEngine engine,
            String credentialId,
            String publicKey,
            String fingerprint,
          ) => engine.recordGeneratedCredential(
            productId: _productId,
            repositoryId: _repoId,
            referenceName: 'GIT_PRODUCT_CREDIMM_REPO1_SSH',
            publicKey: publicKey,
            fingerprint: fingerprint,
            host: 'github.com',
            credentialId: credentialId,
          );

          /// Runs a mint, turning its refusal into a value so both attempts are
          /// observable. What is asserted below is that exactly one succeeded
          /// and exactly one was refused.
          Future<Object?> attempt(
            Future<RepositoryCredential> Function() body,
          ) async {
            try {
              return await body();
            } catch (error) {
              return error;
            }
          }

          final results = await Future.wait([
            attempt(() => mint(engineA, 'cred-a', _pub, _fp)),
            attempt(() => mint(engineB, 'cred-b', _pub2, _fp2)),
          ]);

          // Exactly one caller wins; the other is refused rather than joined.
          expect(
            results.whereType<RepositoryCredential>(),
            hasLength(1),
            reason:
                'a concurrent double mint must not both succeed; results were '
                '$results',
          );
          expect(
            results.where((r) => r is! RepositoryCredential),
            hasLength(1),
            reason: 'the loser must be refused, not silently accepted',
          );

          // The refusal is a typed DOMAIN exception, not a raw driver error.
          // The index is enforced by Postgres, so without the translation in
          // PostgresProductRegistryStore.saveProductCredential a caller of
          // recordGeneratedCredential would have to catch a DatabaseQueryException
          // to learn that a repository already has an active credential — a
          // persistence detail leaking through the domain API, and a different
          // exception type for the same refusal the pre-read already raises.
          final refusal = results.firstWhere((r) => r is! RepositoryCredential);
          expect(
            refusal,
            isA<CredentialNotUsableException>(),
            reason:
                'the losing mint must fail the way every other refusal '
                'does, but it was $refusal',
          );

          // And the durable truth is exactly one active row.
          final all = await engineA.readCredentials(_productId);
          final active = all.where((c) => c.status != CredentialStatus.revoked);
          expect(
            active,
            hasLength(1),
            reason: 'repositoryId must carry at most one active credential',
          );
          expect(
            all,
            hasLength(1),
            reason: 'no second row may be written at all',
          );
        },
      );

      test(
        'M-2: the CAS path refuses a key-material change against Postgres too',
        () async {
          // The in-memory tier already asserts this (credential_test.dart), but
          // the PREDICATE lives in the Postgres UPDATE, so the in-memory test
          // says nothing about it. Before the predicate was added, this exact
          // call rewrote `publicKey` — the "in-memory green, Postgres red" shape
          // this whole change exists to remove, reintroduced inside its own fix.
          //
          // Unreachable through the engine today: every CAS call site uses
          // `copyWith`, which cannot set the four immutable fields. It is
          // asserted against the store interface because that is the contract a
          // future caller would be held to, and it must be discoverable as
          // failing here rather than in production.
          final store = PostgresProductRegistryStore(await _newDb());
          final engine = await _engine(store);
          final before = await _fullyVerified(engine);

          // Built field by field: `copyWith` cannot set the four immutable
          // fields, which is precisely why no engine call site gets here today.
          final rekeyed = RepositoryCredential(
            credentialId: before.credentialId,
            productId: before.productId,
            repositoryId: before.repositoryId,
            referenceName: before.referenceName,
            publicKey: _pub2,
            fingerprint: _fp2,
            algorithm: before.algorithm,
            status: before.status,
            createdAt: before.createdAt,
            lastVerifiedAt: before.lastVerifiedAt,
            lastVerifiedBy: before.lastVerifiedBy,
            lastFailureReason: before.lastFailureReason,
            hostKeyStatus: before.hostKeyStatus,
            host: before.host,
            hostKeyFingerprint: before.hostKeyFingerprint,
            hostConfirmedAt: before.hostConfirmedAt,
            hostConfirmedBy: before.hostConfirmedBy,
            revokedAt: before.revokedAt,
            revokedReason: before.revokedReason,
            supersedesCredentialId: before.supersedesCredentialId,
            version: before.version,
          );

          // A MATCHING expectedVersion must not buy a key-material rewrite.
          // This is the exact call the review found the Postgres store
          // accepting: `expectedVersion: 1` matches the stored `version: 1`, so
          // an UPDATE with no predicate overwrote the installed key.
          await expectLater(
            store.saveProductCredential(
              rekeyed,
              expectedVersion: before.version,
            ),
            throwsA(isA<CredentialNotUsableException>()),
            reason: 'a matching expectedVersion must not buy a rewrite',
          );
          expect(
            await store.readProductCredential(before.credentialId),
            before,
            reason: 'the refusal must change nothing at all on the row',
          );

          // A STALE expectedVersion is still the immutability refusal, not a
          // lost race. The store reads the row back to tell the two apart
          // (postgres_product_registry_store.dart:270-303); it must prefer the
          // immutability refusal, or a caller that re-points key material is
          // invited to retry the same re-point until a version happens to match.
          await expectLater(
            store.saveProductCredential(
              rekeyed,
              expectedVersion: before.version + 99,
            ),
            throwsA(isA<CredentialNotUsableException>()),
            reason:
                'the immutability refusal takes precedence over the version',
          );

          // And a legitimate CAS write of a NON-key-material field still lands,
          // so the predicate is not simply refusing every update.
          await store.saveProductCredential(
            before.copyWith(lastFailureReason: 'transient'),
            expectedVersion: before.version,
          );
          expect(
            (await store.readProductCredential(
              before.credentialId,
            )).lastFailureReason,
            'transient',
            reason: 'a non-key-material CAS write must still land',
          );
        },
      );

      test(
        'GAP-2: replaying the migration chain alone creates the index',
        () async {
          // The fresh path is not the claim. `tool/schema_bootstrap.sql` already
          // puts the index into every fresh and CI database — that half was
          // green before this migration existed. What a deployed database gets
          // is the CHAIN: `migration.sql` files, and nothing else. This replays
          // exactly that, into a schema no bootstrap ever touched.
          final db = await _newDb();
          final declaring = _migrationDeclaringIndex();
          await _resetChainSchema(db);
          await db.db.unsafeSimpleExecute(_chainScript());

          final definition = await _indexDefinition(db, _chainSchema);
          expect(
            definition,
            isNotNull,
            reason:
                'replaying every migrations/*/migration.sql must create '
                '$_activeIndexName; the whole chain is otherwise a no-op for '
                'the one-active-credential invariant. Declared by '
                '${declaring.path}.',
          );
          // `expect` does not promote, and every assertion below reads the text.
          final index = definition!;
          expect(index, contains('CREATE UNIQUE INDEX'));
          expect(
            index,
            contains('("repositoryId")'),
            reason: 'the key is the repository, not the credential id',
          );
          expect(
            index.toUpperCase(),
            contains('WHERE'),
            reason:
                'the index must be PARTIAL. A non-partial index also refuses a '
                'second active credential — so the "one active per '
                'repository" test above passes against one — but it also '
                'refuses the revoked row `rotateCredential` writes, which would '
                'break rotation outright.',
          );
          expect(
            await _recordedControlPlaneVersion(db, _chainSchema),
            _versionOf(_chainMigrations().last),
            reason: 'the replayed chain must record its own tip version',
          );
        },
      );

      test(
        'GAP-2 negative control: without that migration the chain does not '
        'enforce it, and duplicates block it',
        () async {
          // A green "the index exists after the replay" proves nothing unless
          // the replay can also be seen to MISS it. This replays the same chain
          // with the declaring migration omitted — the shape of every database
          // that was at the previous version before this change — and asserts
          // both halves: the index is absent, and the invariant it encodes does
          // not hold. Then it shows the migration refuses to apply where
          // duplicates already exist, rather than quietly reconciling them.
          final db = await _newDb();
          final declaring = _migrationDeclaringIndex();
          await _resetChainSchema(db);
          await db.db.unsafeSimpleExecute(
            _chainScript(omit: declaring),
          );

          expect(
            await _indexDefinition(db, _chainSchema),
            isNull,
            reason:
                'the chain minus ${declaring.path} must not create '
                '$_activeIndexName, otherwise this file proves nothing',
          );
          final versionBefore = await _recordedControlPlaneVersion(
            db,
            _chainSchema,
          );
          expect(versionBefore, isNotNull);

          // The invariant genuinely does not hold there: two non-revoked
          // credentials for one repository are accepted.
          await db.db.unsafeSimpleExecute(
            'INSERT INTO "$_chainSchema"."product_credential" ('
            '"credentialId", "productId", "repositoryId", "referenceName", '
            '"publicKey", "fingerprint", "algorithm", "status", "createdAt", '
            '"hostKeyStatus", "version") VALUES '
            "('gapdup-1', 'gapdup-product', 'gapdup-repo', 'GAP_DUP_A', "
            "'ssh-ed25519 AAAAGAPDUPA', 'SHA256:gapdupa', 'ed25519', "
            "'generated', now(), 'unknown', 1), "
            "('gapdup-2', 'gapdup-product', 'gapdup-repo', 'GAP_DUP_B', "
            "'ssh-ed25519 AAAAGAPDUPB', 'SHA256:gapdupb', 'ed25519', "
            "'verified', now(), 'unknown', 1)",
          );
          final duplicates = await db.queryNoTransaction(
            'SELECT count(*)::int AS n FROM "$_chainSchema"."product_credential" '
            "WHERE \"repositoryId\" = 'gapdup-repo' AND \"status\" <> 'revoked'",
          );
          expect(
            duplicates.first.toColumnMap()['n'],
            2,
            reason:
                'the un-migrated chain must accept both, or this proves '
                'nothing about the index',
          );

          // Now the prerequisite the migration documents: it FAILS on this
          // database and changes nothing. Reconciling live credential rows is
          // a human decision, so the migration refuses rather than deleting or
          // rewriting anything to make itself applicable.
          await expectLater(
            db.db.unsafeSimpleExecute(_chainScript(only: declaring)),
            throwsA(
              isA<Object>().having(
                (e) => e.toString(),
                'message',
                allOf(contains(_activeIndexName), contains('duplicate')),
              ),
            ),
            reason: 'CREATE UNIQUE INDEX must fail where duplicates exist',
          );
          expect(
            await _indexDefinition(db, _chainSchema),
            isNull,
            reason: 'the failed migration must not leave the index behind',
          );
          expect(
            await _recordedControlPlaneVersion(db, _chainSchema),
            versionBefore,
            reason: 'the failed migration must not record its version',
          );
        },
      );
    },
  );
}

/// Releases N waiters only once N of them are waiting, so every caller
/// observes the database state from before any of them wrote.
class _ReadBarrier {
  static const _expected = 2;
  static const _waitLimit = Duration(seconds: 30);

  final List<Completer<void>> _waiting = <Completer<void>>[];

  /// Blocks the caller until [_expected] callers have arrived here.
  ///
  /// The timeout is a diagnosability guard, not a synchronisation: a caller
  /// that never gets a partner must surface as a readable failure instead of a
  /// suite that hangs until CI kills it.
  Future<void> arrive() {
    final mine = Completer<void>();
    _waiting.add(mine);
    if (_waiting.length >= _expected) {
      // Release every arrival, not just this one: each caller is waiting on
      // its OWN completer, so completing some separate "released" signal would
      // leave them all blocked.
      for (final waiter in _waiting) {
        if (!waiter.isCompleted) waiter.complete();
      }
    }
    return mine.future.timeout(
      _waitLimit,
      onTimeout: () => throw StateError(
        'credential read barrier timed out: only ${_waiting.length} of '
        '$_expected concurrent callers reached the active-credential read',
      ),
    );
  }
}

/// A [PostgresProductRegistryStore] whose active-credential read blocks until
/// every concurrent caller has issued its own read.
///
/// TEST-ONLY, and it changes no assertion: it only forces the interleaving the
/// race needs. Every other call goes to the real store.
class _GatedStore extends PostgresProductRegistryStore {
  _GatedStore(super.db, this._gate);

  final _ReadBarrier _gate;

  @override
  Future<RepositoryCredential?> readActiveCredentialForRepository(
    String repositoryId,
  ) async {
    final result = await super.readActiveCredentialForRepository(repositoryId);
    await _gate.arrive();
    return result;
  }
}
