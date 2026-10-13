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

/// `PostgresProductRegistryStore` round-trips an onboarding record's pinned
/// git revision and workspace.
///
/// This runs against REAL PostgreSQL because the claim under test is a claim
/// about the DATABASE: the record carries a 40-hex SHA and a JSON document in
/// two new `text` columns, and an in-memory map cannot demonstrate that either
/// one survives an `INSERT ... ON CONFLICT` — the branch that silently drops a
/// column added to the INSERT but not to the `DO UPDATE SET` clause, which is
/// write-once and would pass every in-memory test in this repository.
///
/// The row-tolerance case is asserted against a REAL NULL as well, by writing
/// the columns to NULL through raw SQL. That is the only way to prove the
/// forward path accepts what a row written before the migration would look
/// like, without a migration to roll back.
///
/// The chain replay at the bottom is the other half. `make test-integration`
/// and CI build `public` from the LATEST `definition.sql` alone, so the suite
/// above proves only the FRESH path; a deployed database replays
/// `migration.sql` instead and gets the columns only if that statement is
/// right. A test that only exercises the fresh path would stay green on a
/// migration that never ran.
const _productId = 'onbws-fixture';
const _otherProductId = 'onbws-fixture-2';
const _sha = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4';
const _otherSha = 'f0e1d2c3b4a5968778695a4b3c2d1e0f9a8b7c6d';

/// NOT `public`: `test/integration` shares one database with files that run
/// concurrently, and a chain replay creates a whole schema from scratch. It is
/// dropped in `tearDown`, so it cannot outlive the run.
const _chainSchema = 'shipit_onboarding_chain';

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

/// Removes only this suite's rows.
///
/// Targeted DELETEs, never a TRUNCATE: `test/integration` shares one database
/// with files that run concurrently, and truncating `product` or
/// `onboarding_record` out from under them breaks their assertions. Every
/// statement is scoped to this file's fixture id prefix, so no other file's row
/// can match. Runs in `setUp` as well as `tearDown`, because a run that
/// aborted mid-test leaves rows behind and re-registering the Product would
/// then violate a unique constraint.
Future<void> _purgeSuiteRows() async {
  final db = await _newDb();
  for (final statement in const [
    // No foreign key orders these relative to `product`, but onboarding rows
    // are this file's only, so the order is about readability rather than
    // referential integrity.
    'DELETE FROM "onboarding_record" WHERE "productId" LIKE \'onbws-%\'',
    'DELETE FROM "product" WHERE "productId" LIKE \'onbws-%\'',
  ]) {
    await db.query(statement);
  }
}

Future<ProductRegistryEngine> _engine() async {
  final db = await _newDb();
  return ProductRegistryEngine(
    store: PostgresProductRegistryStore(db),
    humanDecisionStore: PostgresHumanDecisionStore(PostgresWorkflowStore(db)),
  );
}

final _t = DateTime.utc(2026, 10, 12, 21, 30, 45);

WorkspaceDescriptor _workspace({
  String startingRevision = _sha,
  DateTime? cleanedAt,
}) => WorkspaceDescriptor(
  workspaceId: 'ws-onbws-1',
  workerExecutionId: 'we-onbws-1',
  workerId: 'wk-local-1',
  repositoryPath: '/var/shipit/repos/shipit-platform',
  startingRevision: startingRevision,
  worktreePath: '/var/shipit/workspaces/shipit-platform-ws-onbws-1',
  createdAt: _t,
  cleanedAt: cleanedAt,
);

/// The pre-migration document: exactly the eight keys a row written before
/// `20261012213045000` carries, and nothing else.
Map<String, dynamic> _preMigrationRowJson() => {
  'onboardingId': 'ob-onbws-fixture',
  'productId': _productId,
  'currentBaselineRevision': 1,
  'pendingClarifications': 1,
  'completed': false,
  'createdAt': '2026-09-16T12:00:00Z',
  'updatedAt': '2026-09-16T12:00:00Z',
  'version': 1,
};

void main() {
  withServerpod(
    'Onboarding record carries a pinned revision and a workspace',
    (sessionBuilder, endpoints) {
      setUp(() async {
        await _purgeSuiteRows();
        await (await _engine()).createProduct(
          productId: _productId,
          name: 'OnboardingWorkspace',
        );
      });

      tearDown(() async {
        await _purgeSuiteRows();
        // Before the sessions close: the scratch schema belongs to a connection
        // they own, and this database is shared with files running
        // concurrently.
        await _dropChainSchema(await _newDb());
        await _closeSessions();
      });

      test(
        'a pinned record round-trips the SHA and the whole descriptor',
        () async {
          final store = PostgresProductRegistryStore(await _newDb());
          final record = OnboardingRecord(
            onboardingId: 'ob-$_productId',
            productId: _productId,
            currentBaselineRevision: 1,
            pendingClarifications: 0,
            completed: true,
            pinnedRevision: _sha,
            workspace: _workspace(),
            completedBaselineId: 'bl-onbws-1',
            createdAt: _t,
            updatedAt: _t,
          );
          await store.saveOnboarding(record);

          final loaded = await store.readOnboardingForProduct(_productId);
          // Whole-object equality: a dropped field is a failure rather than an
          // omission from the assertion.
          expect(loaded, record);
          expect(loaded!.hasDurableWorkspace, isTrue);
          expect(loaded.hasCompletionEvidence, isTrue);
        },
      );

      test(
        'the descriptor keeps EVERY field, not just the path and revision',
        () async {
          // `includeIfNull: false` omits null fields on the way out, so a
          // descriptor that round-trips only its non-null fields would still
          // pass a check on the SHA. Asserted field by field because the JSON
          // column is the only place the descriptor's shape is ever persisted.
          final store = PostgresProductRegistryStore(await _newDb());
          await store.saveOnboarding(
            OnboardingRecord(
              onboardingId: 'ob-$_productId',
              productId: _productId,
              pinnedRevision: _sha,
              workspace: _workspace(cleanedAt: _t.add(const Duration(days: 2))),
              createdAt: _t,
              updatedAt: _t,
            ),
          );
          final ws = (await store.readOnboardingForProduct(
            _productId,
          ))!.workspace!;
          expect(ws.workspaceId, 'ws-onbws-1');
          expect(ws.workerExecutionId, 'we-onbws-1');
          expect(ws.workerId, 'wk-local-1');
          expect(ws.repositoryPath, '/var/shipit/repos/shipit-platform');
          expect(ws.startingRevision, _sha);
          expect(
            ws.worktreePath,
            '/var/shipit/workspaces/shipit-platform-ws-onbws-1',
          );
          expect(ws.detached, isTrue);
          expect(ws.branch, isNull);
          expect(ws.createdAt, _t);
          expect(ws.cleanedAt, _t.add(const Duration(days: 2)));
          expect(ws.isCleaned, isTrue);
        },
      );

      test(
        'the ON CONFLICT branch UPDATES the pin, it does not keep the first',
        () async {
          // The write-once defect: a column named in the INSERT but absent from
          // `DO UPDATE SET` takes the first value and ignores every later one.
          // Only a second write against a real row can show that.
          final store = PostgresProductRegistryStore(await _newDb());
          await store.saveOnboarding(
            OnboardingRecord(
              onboardingId: 'ob-$_productId',
              productId: _productId,
              pinnedRevision: _sha,
              workspace: _workspace(),
              createdAt: _t,
              updatedAt: _t,
            ),
          );
          await store.saveOnboarding(
            OnboardingRecord(
              onboardingId: 'ob-$_productId',
              productId: _productId,
              pinnedRevision: _otherSha,
              workspace: _workspace(startingRevision: _otherSha),
              completedBaselineId: 'bl-onbws-2',
              createdAt: _t,
              updatedAt: _t.add(const Duration(hours: 1)),
              version: 2,
            ),
          );
          final loaded = await store.readOnboardingForProduct(_productId);
          expect(loaded!.pinnedRevision, _otherSha);
          expect(loaded.workspace!.startingRevision, _otherSha);
          expect(loaded.completedBaselineId, 'bl-onbws-2');
          expect(loaded.version, 2);
        },
      );

      test('a row with the new columns NULL still reads back', () async {
        // The backward-compatibility direction, written as real NULLs rather
        // than as an object that happens to omit them: this is what a row
        // predating the migration looks like to this store once the columns
        // exist.
        final db = await _newDb();
        final store = PostgresProductRegistryStore(db);
        await store.saveOnboarding(
          OnboardingRecord(
            onboardingId: 'ob-$_productId',
            productId: _productId,
            createdAt: _t,
            updatedAt: _t,
          ),
        );
        await db.query(
          'UPDATE "onboarding_record" SET "pinnedRevision" = NULL, '
          '"workspace" = NULL, "completedBaselineId" = NULL '
          'WHERE "productId" = @productId',
          parameters: QueryParameters.named({'productId': _productId}),
        );
        final loaded = await store.readOnboardingForProduct(_productId);
        expect(loaded, isNotNull);
        expect(loaded!.pinnedRevision, isNull);
        expect(loaded.workspace, isNull);
        expect(loaded.completedBaselineId, isNull);
        expect(loaded.hasDurableWorkspace, isFalse);
        expect(loaded.onboardingId, 'ob-$_productId');
      });

      test(
        'a row written with the PRE-MIGRATION columns present loads',
        () async {
          // The same claim from the other direction: the store can read back a
          // row whose provenance is the old eight-column insert. It is written
          // through raw SQL naming only those columns, so the test fails if the
          // INSERT ever grows a NOT NULL that a pre-migration row cannot supply.
          final db = await _newDb();
          await db.query(
            'INSERT INTO "onboarding_record" ("onboardingId", "productId", '
            '"currentBaselineRevision", "pendingClarifications", "completed", '
            '"createdAt", "updatedAt", "version") '
            'VALUES (@onboardingId, @productId, 1, 1, false, @createdAt, '
            '@createdAt, 1)',
            parameters: QueryParameters.named({
              'onboardingId': 'ob-onbws-legacy',
              'productId': _otherProductId,
              'createdAt': DateTime.utc(2026, 9, 16, 12),
            }),
          );
          final loaded = await PostgresProductRegistryStore(
            db,
          ).readOnboardingForProduct(_otherProductId);
          expect(loaded, isNotNull);
          expect(loaded!.onboardingId, 'ob-onbws-legacy');
          expect(loaded.currentBaselineRevision, 1);
          expect(loaded.pendingClarifications, 1);
          expect(loaded.pinnedRevision, isNull);
          expect(loaded.hasDurableWorkspace, isFalse);
          // And it matches the document a pre-migration reader would have
          // produced, key for key.
          expect(
            loaded.toJson().keys.toSet(),
            _preMigrationRowJson().keys.toSet(),
          );
        },
      );

      test('the engine writes the pin through a real database', () async {
        final engine = await _engine();
        await engine.recordWorkspace(
          productId: _productId,
          workspace: _workspace(),
          pinnedRevision: _sha,
          now: _t,
        );
        final completed = await engine.completeOnboarding(
          productId: _productId,
          pinnedRevision: _sha,
          workspace: _workspace(),
          completedBaselineId: 'bl-onbws-1',
          now: _t.add(const Duration(hours: 1)),
        );
        expect(completed.completed, isTrue);

        // Read back through a SEPARATE store instance on a separate
        // connection, so a write that only landed in a local cache could not
        // be mistaken for a durable one.
        final loaded = await PostgresProductRegistryStore(
          await _newDb(),
        ).readOnboardingForProduct(_productId);
        expect(loaded!.pinnedRevision, _sha);
        expect(loaded.completedBaselineId, 'bl-onbws-1');
        expect(loaded.hasDurableWorkspace, isTrue);
      });

      test('a malformed pin is refused by the database tier and the row is '
          'UNCHANGED', () async {
        final store = PostgresProductRegistryStore(await _newDb());
        await store.saveOnboarding(
          OnboardingRecord(
            onboardingId: 'ob-$_productId',
            productId: _productId,
            pinnedRevision: _sha,
            workspace: _workspace(),
            createdAt: _t,
            updatedAt: _t,
          ),
        );
        await expectLater(
          store.saveOnboarding(
            OnboardingRecord(
              onboardingId: 'ob-$_productId',
              productId: _productId,
              pinnedRevision: 'HEAD',
              workspace: _workspace(),
              updatedAt: _t.add(const Duration(hours: 1)),
              version: 2,
              createdAt: _t,
            ),
          ),
          throwsA(isA<FormatException>()),
        );
        // The validation runs before the statement, so the previous answer is
        // still readable and the version did not move.
        final loaded = await store.readOnboardingForProduct(_productId);
        expect(loaded!.pinnedRevision, _sha);
        expect(loaded.version, 1);
      });

      test('the columns are REAL columns, so the pin is queryable', () async {
        // "One persisted, QUERYABLE home" is the claim: a column a reader
        // cannot select is a JSON blob, and a blob is what the record is
        // supposed to have moved away from for the pin.
        final db = await _newDb();
        final store = PostgresProductRegistryStore(db);
        await store.saveOnboarding(
          OnboardingRecord(
            onboardingId: 'ob-$_productId',
            productId: _productId,
            pinnedRevision: _sha,
            workspace: _workspace(),
            createdAt: _t,
            updatedAt: _t,
          ),
        );
        final rows = await db.query(
          'SELECT "productId", "pinnedRevision" FROM "onboarding_record" '
          'WHERE "pinnedRevision" = @sha',
          parameters: QueryParameters.named({'sha': _sha}),
        );
        expect(rows.map((r) => r.toColumnMap()['productId']), [_productId]);
      });

      test('a CHAIN-MIGRATED database carries the columns too', () async {
        // The deployment path. `make test-integration` builds `public` from
        // the newest definition.sql alone, so nothing above exercises
        // migration.sql; a deployed database replays the chain. The columns
        // exist on a chain database only if this migration's own statement
        // creates them, and only the replay proves it.
        final db = await _newDb();
        final declaring = _migrationAddingColumns();
        await _resetChainSchema(db);
        await db.db.unsafeSimpleExecute(_chainScript());

        for (final column in [
          'pinnedRevision',
          'workspace',
          'completedBaselineId',
        ]) {
          final rows = await db.queryNoTransaction(
            'SELECT column_name, is_nullable, data_type '
            'FROM information_schema.columns '
            'WHERE table_schema = \'$_chainSchema\' '
            'AND table_name = \'onboarding_record\' AND column_name = \'$column\'',
          );
          expect(
            rows,
            hasLength(1),
            reason:
                'replaying every migrations/*/migration.sql must create '
                'onboarding_record.$column. Declared by ${declaring.path}.',
          );
          final m = rows.single.toColumnMap();
          expect(
            m['is_nullable'],
            'YES',
            reason:
                '$column must stay nullable or a pre-migration row '
                'cannot be written after the chain is replayed',
          );
          expect(m['data_type'], 'text');
        }

        // And the columns are USABLE on a chain database, not merely present: a
        // column that exists and rejects every write is the same failure with
        // extra steps, and a row written the pre-migration way must still fit.
        //
        // The table is SCHEMA-QUALIFIED, not reached through a `search_path`.
        // `SET LOCAL` only has meaning inside a transaction, so issuing it on
        // its own is a no-op with a warning — the statement that follows then
        // resolves against whatever `search_path` the pooled connection
        // happens to carry, which on a `public`-migrated test database is
        // `public`. That silently writes this row into the SHARED schema and
        // reads it back from the scratch one, and the read comes back empty
        // for reasons that have nothing to do with the columns.
        final legacy = _preMigrationRowJson();
        await db.db.unsafeSimpleExecute(
          'INSERT INTO "$_chainSchema"."onboarding_record" ("onboardingId", '
          '"productId", "currentBaselineRevision", "pendingClarifications", '
          '"completed", "createdAt", "updatedAt", "version") '
          'VALUES (\'${legacy['onboardingId']}\', \'${legacy['productId']}\', '
          '1, 0, false, now(), now(), 1)',
        );
        final read = await db.db.unsafeQuery(
          'SELECT "pinnedRevision", "workspace", "completedBaselineId" '
          'FROM "$_chainSchema"."onboarding_record" '
          'WHERE "productId" = \'${legacy['productId']}\'',
        );
        expect(read, hasLength(1));
        final m = read.single.toColumnMap();
        expect(m['pinnedRevision'], isNull);
        expect(m['workspace'], isNull);
        expect(m['completedBaselineId'], isNull);

        // Nothing was written outside the scratch schema: `public` is shared
        // with every other file in this directory, and a row this file forgot
        // to scope is a row the next concurrent file trips over.
        final leaked = await db.db.unsafeQuery(
          'SELECT count(*) AS n FROM "public"."onboarding_record" '
          'WHERE "onboardingId" = \'${legacy['onboardingId']}\'',
        );
        expect(
          leaked.single.toColumnMap()['n'],
          0,
          reason: 'the chain row must land in $_chainSchema only',
        );

        await _dropChainSchema(db);
      });
    },
  );
}

// ---------------------------------------------------------------------------
// Chain replay helpers
//
// These read `migrations/*/migration.sql` off disk and replay them into a
// scratch schema. That is deliberately NOT what `make test-integration` does
// to `public` (the fresh-database path, which applies only the latest
// `definition.sql`, plus `tool/schema_bootstrap.sql`): the path under test is
// the one a database that already has a recorded migration version takes,
// which is the path a deployed database takes.
// ---------------------------------------------------------------------------

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

/// The chain as ONE simple-query batch for [db] to execute inside
/// `$_chainSchema`.
///
/// Every statement runs on ONE connection, which is what makes the
/// `search_path` hold for the whole replay instead of drifting between pooled
/// connections. `SET LOCAL` inside the explicit transaction, not a bare `SET`:
/// a bare `SET` is session state that goes back to Serverpod's pool still
/// carrying it, and the next statement to borrow that connection runs against
/// the wrong schema. Each shipped file's own `BEGIN;`/`COMMIT;` wrapper is
/// stripped — nested inside this one they would end the enclosing transaction
/// at worst.
String _chainScript() {
  final buffer = StringBuffer()
    ..writeln('BEGIN;')
    ..writeln('SET LOCAL search_path TO "$_chainSchema";');
  for (final file in _chainMigrations()) {
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

/// The oldest migration whose `migration.sql` adds a column to
/// `onboarding_record`.
///
/// Located by content rather than hard-coded to a version, so adding a later
/// unrelated migration cannot silently turn this into a test of the wrong
/// file.
File _migrationAddingColumns() {
  final declaring = _chainMigrations()
      .where(
        (file) => file.readAsStringSync().contains(
          'ALTER TABLE "onboarding_record" ADD COLUMN',
        ),
      )
      .toList();
  if (declaring.isEmpty) {
    throw StateError(
      'no migrations/*/migration.sql adds a column to "onboarding_record", so '
      'a chain-migrated database will not have the pinned revision at all — '
      'the definition.sql path alone would keep this test green.',
    );
  }
  return declaring.first;
}

Future<void> _resetChainSchema(PersistenceDatabase db) async {
  await db.db.unsafeSimpleExecute(
    'DROP SCHEMA IF EXISTS "$_chainSchema" CASCADE',
  );
  await db.db.unsafeSimpleExecute('CREATE SCHEMA "$_chainSchema"');
}

Future<void> _dropChainSchema(PersistenceDatabase db) =>
    db.db.unsafeSimpleExecute('DROP SCHEMA IF EXISTS "$_chainSchema" CASCADE');
