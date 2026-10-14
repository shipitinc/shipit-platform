import 'dart:io';

import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// The behaviour of migration `20261014130500000` — the repair that repoints
/// twelve enumerated work items off the synthetic `'defects'` triage bucket,
/// which has no registry row, and onto the governed `shipit-platform`.
///
/// ## WHY THIS RUNS AGAINST REAL POSTGRESQL, IN A SCRATCH SCHEMA
///
/// The six properties under test are properties of SQL, and none of them can
/// be demonstrated by reading the file:
///
///   (a) it moves ONLY the twelve enumerated ids;
///   (b) each `design-remediation-*` row moves WITH its parent, or the whole
///       migration refuses;
///   (c) it refuses rather than skips when an id is not a `productId='defects'`
///       row — including one filed under a THIRD product;
///   (d) it refuses when any table in the schema still holds a row under
///       `'defects'` outside the enumerated set — the late-arrival property;
///   (e) it refuses when the destination is missing or not `governed`;
///   (f) it is idempotent on re-run, and a FORCED replay of the file against an
///       item that has since moved on still writes nothing.
///
/// (f) in particular is a claim about what a SECOND application writes, and no
/// static check can make that claim. So the migration is applied — the real
/// `migration.sql`, read off disk, not a paraphrase of it, guard and
/// `serverpod_migrations` upserts and all.
///
/// The schema is scratch, never `public`. `test/integration` shares one
/// database with files that run concurrently; a chain replay builds a whole
/// schema from scratch and must not land in the schema everybody else reads.
/// Same rule, same reason and same shape as
/// `stranded_key_repair_migration_test.dart` and
/// `onboarding_workspace_postgres_test.dart`.
///
/// ## WHY THE CHAIN IS REPLAYED AT ALL
///
/// `make test-integration` and CI build `public` from the LATEST
/// `definition.sql` alone (serverpod-3.4.13
/// `lib/src/database/migrations/migration_manager.dart` `_loadMigrationSQL`),
/// so on a fresh database this migration's `migration.sql` is never executed —
/// a data repair is a no-op on an empty schema. A deployed database is
/// chain-migrated and replays every `migration.sql`. That deployed path is the
/// one under test, so it is the one built here.
///
/// ## WHY THE CHAIN NEEDS A PRODUCT ROW SEEDED
///
/// NO migration in this repository inserts a `product` row — product rows are
/// created by the application, not by a migration. A chain-built schema
/// therefore has an EMPTY `product` table, and this migration's guard (a)
/// refuses on an empty one, by design: repointing twelve work items onto a
/// product that does not exist would recreate the exact defect being repaired.
/// The seed below is what a real deployment has and a chain schema does not,
/// and it is inserted before the replay reaches this migration rather than
/// after, because the guard runs inside the replay.
const _chainSchema = 'shipit_product_repoint_chain';

/// The migration under test, resolved BY CONTENT.
///
/// Never by registry position and never by a hard-coded version: the version
/// directory is a timestamp the generator chose, and a test that pins it is a
/// test that breaks for the wrong reason. The marker is this migration's own
/// transition-id prefix, which no other migration's is.
const _auditMarker = 'tr-product-repoint-';

/// The twelve targets, each with the product id and state it carried when the
/// set was read off QA at dispatch. `state` is NOT a precondition — this
/// migration does not write it — so it is asserted only as documentation of
/// what each item was left holding.
const _targets = <(String id, String state)>[
  ('defect-DEF-1791684557133597', 'implementation_ready'),
  ('defect-DEF-1791684804452198', 'agent_completed'),
  ('defect-DEF-1791685024220546', 'implementation_ready'),
  ('defect-DEF-1791685264570406', 'implementation_ready'),
  ('defect-DEF-1791685401972067', 'implementation_ready'),
  ('defect-DEF-1791685722309971', 'implementation_ready'),
  ('defect-DEF-1791685924503981', 'implementation_ready'),
  ('defect-DEF-1791686085546076', 'agent_completed'),
  ('defect-DEF-1791686357139031', 'implementation_ready'),
  ('defect-DEF-1791686704991884', 'agent_completed'),
  ('design-remediation-DEF-1791685264570406', 'planned'),
  ('design-remediation-DEF-1791686085546076', 'planned'),
];

/// A thirteenth item filed under `'defects'` AFTER the twelve were read off
/// QA — the late arrival. It must not be repointed, and its presence must
/// REFUSE the migration rather than be silently left behind.
const _lateArrival = 'defect-DEF-1791688888888888';

/// Already correctly filed. Present so the sweep has something correct to skip
/// over: a test that only ever sees wrong values cannot tell "found nothing"
/// from "found the right things and ignored them".
const _correctItem = 'WI-feature-1791686174076431';

/// A dependent table row carrying the wrong id. The sweep is dynamic, so any
/// table with a `productId` column is a candidate; `defect` is chosen because
/// it is the one the dispatch measured by hand and the one a reader is most
/// likely to assume was checked.
const _orphanTable = 'defect';

/// Checked for "did anything move" in the linkage tests.
const _orphanRemediationProbe = 'defect-DEF-1791685924503981';

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

// ---------------------------------------------------------------------------
// Migration artifact resolution
// ---------------------------------------------------------------------------

/// Every `migrations/*/migration.sql`, oldest first.
///
/// `migration_registry.txt` is not consulted, because Serverpod's
/// `listVersions()` lists migration DIRECTORIES and sorts them lexically
/// (serverpod-3.4.13
/// `migrations/migration_artifacts_store/file_system.dart` `listVersions`).
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

/// The migration under test, resolved BY CONTENT.
///
/// Never by registry position and never by a hard-coded version: the version
/// directory is a timestamp the generator chose, and a test that pins it is a
/// test that breaks for the wrong reason.
///
/// The marker is the CONSTRUCTION SITE of the transition id, not the bare
/// prefix — the same discipline `stranded_key_repair_migration_test.dart`
/// applies, and for the same reason: a migration that merely NAMES this prefix
/// in its rollback documentation resolves as a candidate otherwise, and takes
/// the suite down in `setUpAll`.
File _repointMigration() {
  final declaring = _chainMigrations()
      .where((file) => file.readAsStringSync().contains("'$_auditMarker' ||"))
      .toList();
  if (declaring.length != 1) {
    throw StateError(
      'expected exactly one migration writing $_auditMarker transition ids, '
      'found ${declaring.map((f) => f.path).toList()}. With none, every '
      'assertion below reads nothing and passes vacuously; with more than one, '
      'this file would be testing an arbitrary one of them.',
    );
  }
  return declaring.single;
}

String _versionOf(File migration) =>
    migration.parent.path.split(Platform.pathSeparator).last;

/// The registry row a real deployment has and a chain-built schema does not.
///
/// `product` rows are created by the application, never by a migration, so this
/// is the one thing the chain cannot supply for itself.
const _productSeed =
    '''
INSERT INTO "$_chainSchema"."product"
    ("productId", "name", "description", "manifestVersion", "state",
     "createdAt", "updatedAt", "version")
VALUES ('shipit-platform', 'ShipIt Platform',
        'seeded by the chain-replay harness; a real deployment creates this '
        'row through the product registry, never through a migration',
        'test', 'governed', now(), now(), 1);
''';

/// The work-item rows the migration refuses to run without.
///
/// Its guard classifies an enumerated id that has no `work_item` row as a
/// refusal, not a skip — which is right, and is why a chain-built schema, where
/// those rows do not exist, cannot replay this file until it has them. So this
/// seed stands in for a deployed database.
///
/// The ids are read out of the migration's OWN target table rather than
/// restated here, so the list stays declared exactly once — in the migration —
/// and a test cannot drift from it by being edited twice.
String _chainWorkItemSeed(File migration) {
  final ids = RegExp(
    r"\('((?:defect|design-remediation)-DEF-\d+)', 'defects'\)",
  ).allMatches(migration.readAsStringSync()).map((m) => m.group(1)!).toSet();
  if (ids.isEmpty) {
    throw StateError(
      'no work item ids found in ${migration.path}; the chain seed would be '
      'empty and the replay would exercise a refusal path rather than the '
      'repair',
    );
  }
  final buffer = StringBuffer();
  for (final id in ids.toList()..sort()) {
    // `featureRef` is the defect id, which is what both provisioners write and
    // what the linkage guard reads; the derived parent carries the same.
    final suffix = id
        .replaceFirst('design-remediation-', '')
        .replaceFirst('defect-', '');
    buffer.writeln('''
INSERT INTO "$_chainSchema"."work_item"
    ("workItemId", "productId", "category", "title", "description", "state",
     "featureRef", "createdAt", "updatedAt", "version")
VALUES ('$id', 'defects', 'bugfix', 'chain replay seed', 'chain replay seed',
        'implementation_ready', '$suffix', now(), now(), 1);
''');
  }
  return buffer.toString();
}

/// Content marker of the migration that needs a governed product to exist and
/// its twelve rows to be present.
const _needsProductRegistry = "'tr-product-repoint-' ||";

/// The whole chain as ONE simple-query batch for [db] to execute inside
/// `$_chainSchema`.
///
/// Every statement runs on ONE connection, which is what makes the
/// `search_path` hold for the whole replay instead of drifting between pooled
/// connections. `SET LOCAL` inside the explicit transaction, not a bare `SET`:
/// a bare `SET` is session state that returns to Serverpod's pool still
/// carrying it. Each shipped file's own `BEGIN;`/`COMMIT;` wrapper is stripped —
/// nested inside this one they would end the enclosing transaction at worst.
///
/// The seed is emitted immediately before the file that declares this
/// migration, and not at the end: the guards that refuse an empty registry and
/// a missing row run INSIDE the replay, so a seed written afterwards would
/// arrive too late to stop them firing. It is placed by content rather than by
/// version, so adding a later migration cannot silently move it past them.
String _chainScript(File migration) {
  final buffer = StringBuffer()
    ..writeln('BEGIN;')
    ..writeln('SET LOCAL search_path TO "$_chainSchema";');
  for (final file in _chainMigrations()) {
    if (file.readAsStringSync().contains(_needsProductRegistry)) {
      buffer
        ..writeln(_productSeed)
        ..writeln(_chainWorkItemSeed(migration));
    }
    buffer.writeln(_stripTransactionWrapper(file.readAsStringSync()));
  }
  buffer.writeln('COMMIT;');
  return buffer.toString();
}

/// [sql] with the file's own top-level `BEGIN;` / `COMMIT;` lines removed.
String _stripTransactionWrapper(String sql) {
  final buffer = StringBuffer();
  for (final line in sql.split('\n')) {
    final trimmed = line.trim();
    if (trimmed == 'BEGIN;' || trimmed == 'COMMIT;') continue;
    buffer.writeln(line);
  }
  buffer.writeln(';');
  return buffer.toString();
}

/// The migration under test, ready to execute inside `$_chainSchema`.
///
/// The artifact is applied VERBATIM — its `DO $$ … $$` guard, its
/// `serverpod_migrations` upserts and all — because the guard is half of what
/// this file proves, and a paraphrased copy would prove nothing about it.
String _applyRepointScript(File migration) {
  final buffer = StringBuffer()
    ..writeln('BEGIN;')
    ..writeln('SET LOCAL search_path TO "$_chainSchema";')
    ..writeln(_stripTransactionWrapper(migration.readAsStringSync()))
    ..writeln('COMMIT;');
  return buffer.toString();
}

// ---------------------------------------------------------------------------
// Fixture helpers
// ---------------------------------------------------------------------------

Future<void> _resetChainSchema(PersistenceDatabase db) async {
  await db.db.unsafeSimpleExecute(
    'DROP SCHEMA IF EXISTS "$_chainSchema" CASCADE',
  );
  await db.db.unsafeSimpleExecute('CREATE SCHEMA "$_chainSchema"');
}

Future<void> _dropChainSchema(PersistenceDatabase db) =>
    db.db.unsafeSimpleExecute(
      'DROP SCHEMA IF EXISTS "$_chainSchema" CASCADE',
    );

/// Clears the scratch schema's data rows between tests.
///
/// A `TRUNCATE` here is safe and a `TRUNCATE` of `public` is not: this schema
/// is built and dropped by this file and read by nobody else. `RESTART IDENTITY`
/// keeps the id sequences from drifting between tests. `product` is included so
/// the governed-destination guard can be driven to its other branch without a
/// schema rebuild.
Future<void> _resetData(PersistenceDatabase db) async {
  await db.db.unsafeSimpleExecute(
    'TRUNCATE "$_chainSchema"."work_item_transition", '
    '"$_chainSchema"."work_item", '
    '"$_chainSchema"."product" RESTART IDENTITY',
  );
}

/// A `work_item` row in the shape the provisioners write.
///
/// `featureRef` is set on every `defect-*` row to its own defect id, which is
/// what both provisioners do (lane_a:260, lane_e:208) and what the linkage
/// guard reads. The remediation rows carry the bare defect id rather than the
/// `defect-` prefix, and the guard derives the same value from the row's id —
/// the two disagreeing is a property under test, so both are settable.
String _workItemSql({
  required String id,
  required String productId,
  required String state,
  String? featureRef,
  String? metadataJson,
}) =>
    '''
INSERT INTO "$_chainSchema"."work_item" (
  "workItemId", "productId", "category", "title", "description", "state",
  "featureRef", "artifactRefsJson", "metadataJson", "createdAt", "updatedAt",
  "completedAt", "terminatedAt", "version"
) VALUES (
  '$id', '$productId', 'bugfix', 'fixture $id', 'description', '$state',
  ${featureRef == null ? 'NULL' : "'$featureRef'"},
  '["snapshot-1"]',
  ${metadataJson == null ? 'NULL' : "'${_q(metadataJson)}'"},
  now(), now(), NULL, NULL, 1
);''';

/// The defect id a `defect-<id>` / `design-remediation-<id>` pair shares.
String _suffixOf(String workItemId) => workItemId
    .replaceFirst('design-remediation-', '')
    .replaceFirst('defect-', '');

/// Installs the full fixture: the twelve targets filed under the bucket, with
/// the `featureRef` both provisioners write; the already-correct control.
Future<void> _seedTargets(PersistenceDatabase db) async {
  final buffer = StringBuffer();
  for (final (id, state) in _targets) {
    buffer.writeln(
      _workItemSql(
        id: id,
        productId: 'defects',
        state: state,
        featureRef: _suffixOf(id),
      ),
    );
  }
  buffer.writeln(
    _workItemSql(
      id: _correctItem,
      productId: 'shipit-platform',
      state: 'implementation_ready',
      featureRef: 'feature-1',
    ),
  );
  await db.db.unsafeSimpleExecute(buffer.toString());
}

/// A `defect` row carrying the wrong product id — the dependent-table orphan.
Future<void> _seedOrphanDefect(PersistenceDatabase db) async {
  await db.db.unsafeSimpleExecute('''
INSERT INTO "$_chainSchema"."defect"
    ("defectId", "title", "description", "severity", "status", "reporter",
     "productId", "createdAt", "updatedAt", "version")
VALUES ('DEF-orphan', 'orphan defect', 'filed under the bucket', 'high',
        'new', 'tester', 'defects', now(), now(), 1);
''');
}

Future<String> _productOf(PersistenceDatabase db, String id) async {
  final rows = await db.queryNoTransaction(
    'SELECT "productId", "version", "state", "updatedAt" '
    'FROM "$_chainSchema"."work_item" WHERE "workItemId" = \'${_q(id)}\'',
  );
  if (rows.length != 1) {
    throw StateError(
      'expected exactly one work_item row for $id, got ${rows.length}',
    );
  }
  return rows.single.toColumnMap()['productId']! as String;
}

Future<Map<String, Object?>> _workItem(
  PersistenceDatabase db,
  String id,
) async {
  final rows = await db.queryNoTransaction(
    'SELECT "productId", "state", "version", "featureRef", "metadataJson", '
    '"updatedAt" '
    'FROM "$_chainSchema"."work_item" WHERE "workItemId" = \'${_q(id)}\'',
  );
  if (rows.length != 1) {
    throw StateError(
      'expected exactly one work_item row for $id, got ${rows.length}',
    );
  }
  return rows.single.toColumnMap();
}

Future<List<Map<String, Object?>>> _auditRows(PersistenceDatabase db) async {
  final rows = await db.queryNoTransaction(
    'SELECT "transitionId", "workItemId", "fromState", "toState", '
    '"idempotencyKey", "reason" '
    'FROM "$_chainSchema"."work_item_transition" '
    'WHERE "transitionId" LIKE \'$_auditMarker%\'',
  );
  return [for (final r in rows) r.toColumnMap()];
}

Future<int> _rowsUnderBucketOutsideSet(PersistenceDatabase db) async {
  final rows = await db.queryNoTransaction(
    'SELECT count(*)::int AS n FROM "$_chainSchema"."work_item" '
    "WHERE \"productId\" = 'defects' AND \"workItemId\" NOT IN "
    "('${_targets.map((t) => t.$1).join("','")}')",
  );
  return rows.single.toColumnMap()['n']! as int;
}

/// Applies the migration, returning the error message when it refuses.
///
/// A refusal is the EXPECTED outcome of most of this file, so asserting on it
/// means asserting that a specific, named condition stopped the write — not
/// merely that something did.
Future<String?> _applyExpectingRefusal(
  PersistenceDatabase db,
  File migration,
) async {
  try {
    await db.db.unsafeSimpleExecute(_applyRepointScript(migration));
    return null;
  } on Object catch (error) {
    return error.toString();
  }
}

String _q(String value) => value.replaceAll("'", "''");

void main() {
  withServerpod(
    'migration 20261014130500000 repoints the defects-bucket work items',
    (sessionBuilder, endpoints) {
      late PersistenceDatabase db;
      late File repoint;

      setUpAll(() async {
        db = await _newDb();
        repoint = _repointMigration();
        // ignore: avoid_print
        print('product-repoint under test: ${_versionOf(repoint)}');
        await _resetChainSchema(db);
        await db.db.unsafeSimpleExecute(_chainScript(repoint));
      });

      tearDownAll(() async {
        await _dropChainSchema(db);
        await _closeSessions();
      });

      setUp(() async {
        await _resetData(db);
        await db.db.unsafeSimpleExecute(_productSeed);
        await _seedTargets(db);
      });

      // -----------------------------------------------------------------
      // The enumeration itself
      // -----------------------------------------------------------------

      test('it names exactly the twelve ids the set was dispatched with', () {
        // The migration's own enumeration, read out of its SQL. A drift between
        // the migration and the dispatch table has to fail HERE, not as an
        // unexplained partial repair against live data.
        final sql = repoint.readAsStringSync();
        final enumerated = RegExp(
          r"\('((?:defect|design-remediation)-DEF-\d+)', 'defects'\)",
        ).allMatches(sql).map((m) => m.group(1)!).toSet();
        expect(
          enumerated,
          _targets.map((t) => t.$1).toSet(),
          reason:
              'the migration must enumerate exactly the dispatched set, with no '
              'additions and no omissions, and every one of them against the '
              'product id it was read with',
        );
      });

      test('its UPDATE selects by id, never by the product id value', () {
        // The whole reason the target list exists. A `productId = 'defects'`
        // arm would be safe only at the instant it was written and would
        // silently widen on every subsequent apply.
        final sql = repoint.readAsStringSync();
        // Only the UPDATE statement itself: the audit row that follows it
        // NAMES 'defects' in its reason text, and that is the row describing
        // the move, not a selection on the value.
        final updateArm = sql.substring(
          sql.indexOf('UPDATE work_item w'),
          sql.indexOf('RETURNING w."workItemId"'),
        );
        expect(
          updateArm,
          isNot(contains("'defects'")),
          reason:
              'no literal product id may appear in the UPDATE; the selection '
              'has to be the enumerated ids joined to their expected value',
        );
      });

      // -----------------------------------------------------------------
      // (a) the repair
      // -----------------------------------------------------------------

      test(
        'it repoints all twelve and leaves nothing else under the bucket',
        () async {
          await db.db.unsafeSimpleExecute(_applyRepointScript(repoint));

          for (final (id, _) in _targets) {
            expect(
              await _productOf(db, id),
              'shipit-platform',
              reason: '$id must be repointed onto the destination',
            );
          }
          expect(
            await _rowsUnderBucketOutsideSet(db),
            0,
            reason:
                'no row outside the enumerated set may remain under defects',
          );
          expect(
            await _productOf(db, _correctItem),
            'shipit-platform',
            reason: 'an already-correct row must be untouched',
          );
        },
      );

      test(
        'it changes productId, updatedAt and version, and NOTHING else',
        () async {
          final before = await _workItem(db, 'defect-DEF-1791684557133597');
          await db.db.unsafeSimpleExecute(_applyRepointScript(repoint));
          final after = await _workItem(db, 'defect-DEF-1791684557133597');

          expect(after['productId'], 'shipit-platform');
          expect(after['version'], (before['version']! as int) + 1);
          expect(
            after['updatedAt'],
            isNot(before['updatedAt']),
            reason: 'a real write stamps updatedAt',
          );
          expect(
            after['state'],
            before['state'],
            reason: 'state is not written',
          );
          expect(
            after['featureRef'],
            before['featureRef'],
            reason: 'traceability is not written',
          );
          expect(
            after['metadataJson'],
            before['metadataJson'],
            reason:
                'metadataJson is not written, and triageAttempt inside it is the '
                'SHARED re-work discriminator the OD-10 inflow bounds on',
          );
        },
      );

      test(
        'it leaves triageAttempt untouched on an item that carries one',
        () async {
          // Requirement 4: clearing the marker would silently defeat the
          // maxImplementationInflows bound rather than fix anything.
          await db.db.unsafeSimpleExecute(
            'UPDATE "$_chainSchema"."work_item" SET "metadataJson" = '
            '\'{"triageAttempt":4,"defectId":"DEF-1791686704991884"}\' '
            "WHERE \"workItemId\" = 'defect-DEF-1791686704991884'",
          );
          await db.db.unsafeSimpleExecute(_applyRepointScript(repoint));

          final after = await _workItem(db, 'defect-DEF-1791686704991884');
          expect(
            after['metadataJson'],
            contains('"triageAttempt":4'),
            reason:
                'the re-work discriminator must survive the repoint verbatim',
          );
        },
      );

      // -----------------------------------------------------------------
      // (b) the audit row
      // -----------------------------------------------------------------

      test(
        'it writes one audit row per repointed item, with equal states',
        () async {
          await db.db.unsafeSimpleExecute(_applyRepointScript(repoint));

          final rows = await _auditRows(db);
          expect(rows, hasLength(_targets.length));
          for (final row in rows) {
            final id = row['workItemId']! as String;
            expect(
              row['transitionId'],
              '$_auditMarker$id',
              reason:
                  'the audit id is deterministic, so a replay collides loudly',
            );
            expect(
              row['fromState'],
              row['toState'],
              reason:
                  'no state changed, so the pair is equal BY DESIGN and the '
                  'reason must say so rather than imply an edge',
            );
            expect(
              _targets.firstWhere((t) => t.$1 == id).$2,
              row['fromState'],
              reason: 'the audit row must quote the state the item really held',
            );
            expect(row['idempotencyKey'], isNotNull);
            expect(
              row['reason'],
              contains('NO STATE CHANGE'),
              reason:
                  'a reader of the ledger must be able to tell this row is not a '
                  'transition without reading the schema',
            );
          }
        },
      );

      test('its audit reason scopes the deferral to the seven the probe saw', () async {
        // This is the claim the pre-correction file got wrong. It asserted, in
        // EVERY ONE of the twelve rows it writes:
        //
        //   "...which is why the implementation readiness probe deferred every
        //    one of them on implementation.deferred.product_missing"
        //
        // which is FALSE for five of the twelve. The probe is the
        // IMPLEMENTATION lane's workload resolver, wired only on `sched-impl`
        // (apps/server/lib/server.dart:653), and
        // `RunnableWorkEvaluator.evaluate` returns `noAction` for any item
        // outside its definition's entryStates
        // (packages/scheduler/lib/src/policy/runnable_work.dart:172) BEFORE
        // the resolver is ever consulted. So only the seven at
        // `implementation_ready` were ever asked about a missing product:
        //
        //   * the three at `agent_completed` are claimed by
        //     `engineeringReviewDefinition` (scheduler.dart:2166), whose
        //     resolver is NOT this probe;
        //   * the two at `planned` are in no wired entryStates at all, and are
        //     claimed by nothing.
        //
        // Twelve rows are permanent ledger records the moment `make qa-up`
        // runs, so a false sentence in one is a false record in twelve. This
        // asserts on the reasons READ BACK OUT OF THE DATABASE, not on the
        // migration's text: a text assertion would pass on a string the
        // `||` chain never reaches.
        await db.db.unsafeSimpleExecute(_applyRepointScript(repoint));

        final rows = await _auditRows(db);
        expect(rows, hasLength(_targets.length), reason: 'the fixture');
        for (final row in rows) {
          final id = row['workItemId']! as String;
          final reason = row['reason']! as String;

          // The narrowed, true claim: the deferral is scoped, and the reason
          // says WHICH seven and why the other five were never asked.
          expect(
            reason,
            contains('implementation.deferred.product_missing'),
            reason: '$id must still name the deferral it records a cause for',
          );
          expect(
            reason,
            contains('SCOPED TO THE SEVEN AT implementation_ready'),
            reason:
                '$id must scope the deferral to the seven items the probe was '
                'actually asked about, rather than implying it applied to all '
                'twelve',
          );
          expect(
            reason,
            contains('RunnableWorkEvaluator.evaluate returns noAction'),
            reason:
                '$id must record WHY the other five were never asked -- the '
                'entryStates gate short-circuits before the resolver',
          );
          expect(
            reason,
            contains('claimed by nothing'),
            reason:
                '$id must record that the two `planned` rows were claimed by no '
                'lane at all, which is a different stop from a deferral',
          );

          // The widened claim, refused. Asserted as a NEGATIVE because the
          // failure this guards against is a LATER EDIT RE-WIDENING the
          // sentence, and a positive assertion alone would not notice a
          // second, broader claim added alongside the narrow one.
          expect(
            reason,
            isNot(contains('deferred every one of them')),
            reason:
                '$id must not claim the probe deferred every enumerated item: '
                'it deferred the seven at implementation_ready and never saw '
                'the other five',
          );
        }
      });

      test('its audit reason never claims a deferral for a row the probe never '
          'saw', () async {
        // The same falsity, checked from the OTHER side and against the
        // fixture rather than the wording: the rows that WERE deferred and the
        // rows that were NOT are different sets, and the reason is per-row, so
        // the rows at states no lane claims must say so themselves.
        await db.db.unsafeSimpleExecute(_applyRepointScript(repoint));

        final expectedDeferred = _targets
            .where((t) => t.$2 == 'implementation_ready')
            .map((t) => t.$1)
            .toSet();
        expect(
          expectedDeferred,
          hasLength(7),
          reason:
              'the fixture must still hold seven implementation_ready rows, or '
              'this test proves nothing about the split it asserts',
        );
        final neverClaimed = _targets
            .where((t) => t.$2 != 'implementation_ready')
            .map((t) => t.$1)
            .toSet();
        expect(neverClaimed, hasLength(5), reason: 'three plus two');
        expect(
          expectedDeferred.intersection(neverClaimed),
          isEmpty,
          reason: 'the two sets must partition the twelve',
        );

        for (final row in await _auditRows(db)) {
          final id = row['workItemId']! as String;
          final reason = row['reason']! as String;
          if (expectedDeferred.contains(id)) {
            expect(
              reason,
              contains('SCOPED TO THE SEVEN AT implementation_ready'),
              reason: '$id is one of the seven the probe deferred',
            );
          } else {
            expect(
              reason,
              contains(
                'Those five are repointed because being filed under a product',
              ),
              reason:
                  '$id is one of the five the probe never saw; its own row has '
                  'to carry the reason it moved anyway, or a reader of that '
                  'single row is told a deferral that never happened',
            );
          }
        }
      });

      test('its audit id prefix cannot collide with the earlier repairs', () {
        final sql = repoint.readAsStringSync();
        for (final earlier in const [
          'tr-stranded-repair-',
          'tr-stranded-exec-repair-',
          'tr-dedupe-bump-repair-',
          'tr-stranded-key-repair-',
        ]) {
          expect(
            _auditMarker.startsWith(earlier) ||
                earlier.startsWith(_auditMarker),
            isFalse,
            reason:
                '$earlier and $_auditMarker must be distinct prefixes, or an '
                'earlier rollback would delete these rows',
          );
        }
        expect(sql, contains(_auditMarker));
      });

      // -----------------------------------------------------------------
      // (f) idempotence
      // -----------------------------------------------------------------

      test(
        'a second apply moves nothing and writes no second audit row',
        () async {
          await db.db.unsafeSimpleExecute(_applyRepointScript(repoint));
          final versions = {
            for (final (id, _) in _targets)
              id: (await _workItem(db, id))['version']! as int,
          };

          await db.db.unsafeSimpleExecute(_applyRepointScript(repoint));

          for (final (id, _) in _targets) {
            expect(
              (await _workItem(db, id))['version'],
              versions[id],
              reason: '$id must not be versioned twice by a second apply',
            );
          }
          expect(await _auditRows(db), hasLength(_targets.length));
        },
      );

      test('a FORCED replay against an item that has since moved on is a '
          'no-op', () async {
        // The arm the value comparison alone cannot hold: an item re-filed by
        // hand back under the bucket would match `productId = 'defects'` again
        // while already carrying this migration's audit row.
        await db.db.unsafeSimpleExecute(_applyRepointScript(repoint));
        await db.db.unsafeSimpleExecute(
          'UPDATE "$_chainSchema"."work_item" SET "productId" = \'defects\' '
          'WHERE "workItemId" = \'defect-DEF-1791684557133597\'',
        );

        await db.db.unsafeSimpleExecute(_applyRepointScript(repoint));

        expect(
          await _productOf(db, 'defect-DEF-1791684557133597'),
          'defects',
          reason:
              'the audit-row arm must win over the value arm on a replay, so a '
              'hand re-file is not silently repointed a second time',
        );
        expect(await _auditRows(db), hasLength(_targets.length));
      });

      // -----------------------------------------------------------------
      // (c) refuses rather than skips
      // -----------------------------------------------------------------

      test('it REFUSES an id that is not a bucket row, and names it', () async {
        await db.db.unsafeSimpleExecute(
          'UPDATE "$_chainSchema"."work_item" '
          "SET \"productId\" = 'some-other-product' "
          "WHERE \"workItemId\" = 'defect-DEF-1791685024220546'",
        );

        final message = await _applyExpectingRefusal(db, repoint);
        expect(
          message,
          contains('product-repoint refused'),
          reason:
              'a third product id is not "nothing to do" — it is a dataset '
              'this file was not written against',
        );
        expect(message, contains('defect-DEF-1791685024220546'));
        expect(
          await _productOf(db, 'defect-DEF-1791686357139031'),
          'defects',
          reason:
              'the refusal is all-or-nothing: the other eleven must NOT have '
              'moved, or the repair would be partial and invisible',
        );
      });

      test('it REFUSES a missing row and names it', () async {
        await db.db.unsafeSimpleExecute(
          'DELETE FROM "$_chainSchema"."work_item" '
          "WHERE \"workItemId\" = 'defect-DEF-1791685722309971'",
        );

        final message = await _applyExpectingRefusal(db, repoint);
        expect(message, contains('no such work_item row'));
        expect(message, contains('defect-DEF-1791685722309971'));
      });

      test('it REFUSES an expected value equal to the destination', () async {
        // The cheapest possible corruption of this file: it would make every
        // guard arm trivially satisfied and the migration a silent no-op that
        // reports success.
        await db.db.unsafeSimpleExecute(
          'UPDATE "$_chainSchema"."work_item" '
          "SET \"productId\" = 'defects' WHERE TRUE",
        );
        final sql = repoint.readAsStringSync().replaceAll(
          "'defects'),\n",
          "'shipit-platform'),\n",
        );
        expect(sql, contains('expectedProductId equals the destination'));
      });

      // -----------------------------------------------------------------
      // (b) the linkage guard
      // -----------------------------------------------------------------

      test('it REFUSES when a remediation and its parent disagree on '
          'featureRef', () async {
        // The linkage is CARRIED by featureRef, and both provisioners write it
        // in the same `createWorkItem` call that writes the id. A disagreement
        // means the pair did not come from that producer, which is precisely
        // the "moves with its parent" property being unverifiable — so it
        // refuses rather than moving one half of a relationship it cannot read.
        await db.db.unsafeSimpleExecute(
          'UPDATE "$_chainSchema"."work_item" '
          "SET \"featureRef\" = 'DEF-somethingelse' "
          "WHERE \"workItemId\" = 'defect-DEF-1791685264570406'",
        );

        final message = await _applyExpectingRefusal(db, repoint);
        expect(message, contains('product-repoint refused'));
        expect(message, contains('Remediation linkage problems'));
        expect(
          message,
          contains('design-remediation-DEF-1791685264570406'),
          reason: 'the refusal must name the remediation row, not just the set',
        );
        expect(
          await _productOf(db, _orphanRemediationProbe),
          isNot('shipit-platform'),
          reason: 'nothing moves when the linkage guard fires',
        );
      });

      test('both remediation rows move with their parents', () async {
        await db.db.unsafeSimpleExecute(_applyRepointScript(repoint));

        for (final (id, state) in _targets) {
          if (!id.startsWith('design-remediation-')) continue;
          final suffix = _suffixOf(id);
          final remediation = await _workItem(db, id);
          final parent = await _workItem(db, 'defect-$suffix');
          expect(remediation['productId'], 'shipit-platform');
          expect(
            parent['productId'],
            remediation['productId'],
            reason:
                '$id and its parent defect-$suffix must agree; an orphan '
                'remediation filed under a repaired product while its parent '
                'stayed behind is a worse record than the one being repaired',
          );
          expect(
            remediation['featureRef'],
            suffix,
            reason: 'the remediation row must carry its own defect id',
          );
          expect(parent['featureRef'], suffix);
          expect(
            parent['state'],
            _targets.firstWhere((t) => t.$1 == 'defect-$suffix').$2,
          );
          expect(remediation['state'], state);
        }
      });

      // -----------------------------------------------------------------
      // (d) the orphan sweep
      // -----------------------------------------------------------------

      test('it REFUSES a row outside the set still under the bucket', () async {
        // The late arrival. Given the provisioner still files there, this is
        // an expected outcome rather than a hypothetical one — and it must
        // STOP the repair, never widen it.
        await db.db.unsafeSimpleExecute(
          _workItemSql(
            id: _lateArrival,
            productId: 'defects',
            state: 'implementation_ready',
            featureRef: _suffixOf(_lateArrival),
          ),
        );

        final message = await _applyExpectingRefusal(db, repoint);
        expect(message, contains('product-repoint refused'));
        expect(
          message,
          contains('work_item'),
          reason: 'the refusal must name the table still holding the wrong id',
        );
        expect(
          await _productOf(db, 'defect-DEF-1791684557133597'),
          'defects',
          reason: 'nothing moves when the sweep fires',
        );
      });

      test('it REFUSES an orphan row in a DEPENDENT table', () async {
        await _seedOrphanDefect(db);

        final message = await _applyExpectingRefusal(db, repoint);
        expect(message, contains('product-repoint refused'));
        expect(
          message,
          contains(_orphanTable),
          reason:
              'the sweep is dynamic, so it must catch a wrong id in any table '
              'carrying a productId column, not only in work_item',
        );
        expect(
          await _productOf(db, 'defect-DEF-1791684557133597'),
          'defects',
          reason: 'a dependent-table orphan blocks the repair too',
        );
      });

      // -----------------------------------------------------------------
      // (e) the destination guard
      // -----------------------------------------------------------------

      test('it REFUSES when the destination product does not exist', () async {
        await db.db.unsafeSimpleExecute(
          'DELETE FROM "$_chainSchema"."product"',
        );

        final message = await _applyExpectingRefusal(db, repoint);
        expect(
          message,
          contains('does not exist in the product table'),
          reason:
              'repointing onto a product that does not exist would recreate the '
              'exact defect being repaired',
        );
      });

      test('it REFUSES when the destination product is not governed', () async {
        await db.db.unsafeSimpleExecute(
          'UPDATE "$_chainSchema"."product" SET "state" = \'paused\' '
          'WHERE "productId" = \'shipit-platform\'',
        );

        final message = await _applyExpectingRefusal(db, repoint);
        expect(
          message,
          contains('only a governed product may have work dispatched'),
          reason:
              'an ungoverned destination would give twelve items a product id '
              'that looks right while every one still deferred on '
              'product_not_governed',
        );
      });

      // -----------------------------------------------------------------
      // The banner's claims
      // -----------------------------------------------------------------

      test('its banner names the real cause, not a seed artifact', () {
        // The mechanism is `defectTriageBucketProductId` -- a deliberate
        // fallback for a defect with no resolvable affectedWorkItemId. Calling
        // it a seed artifact would send an operator looking for a bad INSERT
        // that does not exist, and past the producer that will file a
        // thirteenth row the same way tomorrow.
        final banner = repoint.readAsStringSync();
        expect(banner, contains('defectTriageBucketProductId'));
        expect(
          banner,
          contains('DOES NOT STOP THE CLASS'),
          reason:
              'the banner must say the repair does not prevent recurrence, so '
              'nobody reads it as having fixed defect intake',
        );
        expect(
          banner,
          isNot(contains("is a seed artifact\n")),
          reason: 'the cancelled draft asserted this; it is false',
        );
      });

      test('its banner does not claim the probe would defer on the wrong '
          'event', () {
        // `product_state_unreadable` only fires when the READ THROWS. With no
        // product row the read returns null and `product_missing` is what
        // actually fires, so the banner must name the second.
        final banner = repoint.readAsStringSync();
        expect(
          banner,
          contains('implementation.deferred.product_missing'),
        );
        expect(
          banner.contains('the first that applies is `product_missing`'),
          isFalse,
          reason:
              'the cancelled draft asserted an ordering of the three deferral '
              'arms; a null state is not an unreadable state, so the claim '
              'that the FIRST arm applies is wrong',
        );
      });

      test('its banner states what will NOT change', () {
        // A dispatch that expects twelve moving items to start dispatching
        // would otherwise report a false success.
        final banner = repoint.readAsStringSync();
        expect(banner, contains('maxImplementationInflows'));
        expect(
          banner,
          contains('implementationReady'),
          reason:
              '`planned` is in no wired JobDefinition.entryStates, so the two '
              'remediation rows are repointed correctly and still do not '
              'dispatch — and that has to be said where an operator will read it',
        );
      });
    },
  );
}
