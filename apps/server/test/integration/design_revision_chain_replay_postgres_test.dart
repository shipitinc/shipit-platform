import 'dart:convert';
import 'dart:io';

import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// Runtime proof that migration `20261019010044759` — the authorised destructive
/// route — leaves a CHAIN-REPLAYED database with the two invariants its
/// `DROP TABLE "design_revision" CASCADE` removes.
///
/// ## WHY A CHAIN REPLAY AND NOT A FRESH DATABASE
///
/// `make test-integration` and CI build FRESH: Serverpod applies only the
/// newest `definition.sql` to a database with no recorded migration version,
/// and then `tool/schema_bootstrap.sql` is applied on top. That path recreates
/// `design_revision_approved_unique_per_work_item` and
/// `trigger_design_revision_immutability` by hand, so a test against it is green
/// whether or not this migration restores anything — it cannot tell the two
/// routes apart, and would report coverage it does not have.
///
/// A chain-replayed database is the other route and the only one a deployment
/// takes: it applies `migration.sql` files in order and nothing else. This
/// replays the two shipped files that concern `design_revision` into a scratch
/// schema no bootstrap has ever touched, then reads the resulting CATALOG and
/// makes the database try to violate each invariant.
///
/// The harness shape — read the files off disk, strip their `BEGIN;`/`COMMIT;`,
/// concatenate into ONE simple-query batch, `SET LOCAL search_path` inside an
/// explicit transaction — is `product_credential_immutability_postgres_test.dart`'s
/// GAP-2 harness, followed rather than reinvented, for the reasons that file
/// gives: one connection so the `search_path` holds for the whole replay,
/// `SET LOCAL` rather than a bare `SET` so the connection does not carry the
/// scratch schema back to the pool, and explicit `BEGIN`/`COMMIT` so a failed
/// migration rolls the replay back whole.
///
/// ## WHAT IS NOT REPLAYED, STATED PLAINLY
///
/// The two migrations only. The full chain does not replay cleanly in this
/// environment: `20261014130500000` refuses by design on a schema built from
/// migrations alone, because no migration inserts a `product` row and it will
/// not repoint work items onto a destination that does not exist. That refusal
/// is pre-existing, is unrelated to `design_revision`, and is why this file does
/// not depend on the chain tip. Everything `design_revision` needs is created by
/// these two files.
///
/// ## THE SCAFFOLD, AND WHY IT IS NOT THE CLAIM
///
/// `20260920232118956` ends with an index on `job`, a table a different
/// migration creates and which nothing in `design_revision`'s DDL touches. A
/// minimal stand-in for it, and for `serverpod_migrations` (every migration
/// stamps a version row), is created so the replay can run. The two migrations
/// themselves are replayed VERBATIM — nothing is edited, and the negative
/// control below reconstructs the pre-fix file from the shipped one rather than
/// carrying a second hand-written copy that could drift.
///
/// ## NON-VACUITY
///
/// A green "the index is there after the replay" proves nothing unless the
/// replay can also be seen to MISS it. The negative control replays the same
/// pair with the restore block removed and asserts both halves: the objects are
/// absent AND the invariants they encode genuinely do not hold. The scaffold is
/// excluded from the orphan sweep and created outside the transaction under
/// test, so it cannot mask a missing restore.
///
/// ## RESOURCE HYGIENE
///
/// A scratch SCHEMA inside the database `make test-integration` already owns.
/// No compose project, no container, no volume, no shared table: nothing is
/// written to `public`, so no concurrent file in `test/integration` can be
/// affected. The schema is dropped in `tearDown` and re-created per test, so an
/// aborted run leaves nothing behind.
const _chainSchema = 'shipit_chain_replay_design_rev';
const _originVersion = '20260920232118956';
const _destructiveVersion = '20261019010044759';
const _indexName = 'design_revision_approved_unique_per_work_item';
const _triggerName = 'trigger_design_revision_immutability';
const _functionName = 'enforce_design_revision_immutability';
const _table = 'design_revision';

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

/// Drops and re-creates the scratch schema, so a run that aborted mid-replay
/// cannot make the next one fail on objects that already exist.
Future<void> _resetChainSchema(PersistenceDatabase db) async {
  await db.db.unsafeSimpleExecute(
    'DROP SCHEMA IF EXISTS "$_chainSchema" CASCADE',
  );
  await db.db.unsafeSimpleExecute('CREATE SCHEMA "$_chainSchema"');
  await db.db.unsafeSimpleExecute(
    'CREATE TABLE "$_chainSchema"."serverpod_migrations" ('
    '"module" text PRIMARY KEY, '
    '"version" text NOT NULL, '
    '"timestamp" timestamp without time zone NOT NULL)',
  );
  await db.db.unsafeSimpleExecute(
    'CREATE TABLE "$_chainSchema"."job" ("dedupeKey" text, "state" text)',
  );
}

Future<void> _dropChainSchema(PersistenceDatabase db) =>
    db.db.unsafeSimpleExecute('DROP SCHEMA IF EXISTS "$_chainSchema" CASCADE');

String _migrationSql(String version) {
  final file = File('migrations/$version/migration.sql');
  if (!file.existsSync()) {
    throw StateError(
      'missing ${file.path}. This replay reads the shipped SQL off disk; with '
      'nothing to read it would prove nothing.',
    );
  }
  return file.readAsStringSync();
}

/// The two migrations as ONE simple-query batch for [db] to execute inside
/// `$_chainSchema`.
///
/// [stripRestoresFrom] rebuilds that migration as it stood BEFORE this lane's
/// fix — everything up to the partial index, then the version stamps — so the
/// negative control replays a reconstruction of the real pre-fix file instead of
/// a second hand-written copy that could drift away from the shipped one.
String _chainScript({String? stripRestoresFrom}) {
  final buffer = StringBuffer()
    ..writeln('BEGIN;')
    ..writeln('SET LOCAL search_path TO "$_chainSchema";');
  for (final version in const [_originVersion, _destructiveVersion]) {
    var sql = _migrationSql(version);
    if (version == stripRestoresFrom) {
      sql = _withoutRestoreBlock(sql);
    }
    for (final line in const LineSplitter().convert(sql)) {
      final trimmed = line.trim();
      if (trimmed == 'BEGIN;' || trimmed == 'COMMIT;') continue;
      buffer.writeln(line);
    }
    buffer.writeln(';');
  }
  buffer.writeln('COMMIT;');
  return buffer.toString();
}

/// [sql] with everything from the partial unique index up to the version stamps
/// removed — the exact shape `20261019010044759` had before the restore block.
String _withoutRestoreBlock(String sql) {
  final lines = const LineSplitter().convert(sql);
  final cutAt = lines.indexWhere(
    (l) => l.contains('CREATE UNIQUE INDEX "$_indexName"'),
  );
  final stampAt = lines.indexWhere(
    (l) => l.startsWith('INSERT INTO "serverpod_migrations"'),
  );
  if (cutAt < 0 || stampAt < 0 || stampAt < cutAt) {
    throw StateError(
      'could not locate the restore block in $_destructiveVersion: cutAt=$cutAt '
      'stampAt=$stampAt. The negative control cannot reconstruct the pre-fix '
      'file and must say so rather than replay something else.',
    );
  }
  return [...lines.sublist(0, cutAt), ...lines.sublist(stampAt)].join('\n');
}

/// A `design_revision` INSERT with every NOT NULL column bound, so a refusal is
/// about the invariant under test and not about a missing column.
String _insertSql({
  required String revisionId,
  required String workItemId,
  String status = 'approved',
}) =>
    'INSERT INTO "$_chainSchema"."$_table" ('
    '"revisionId", "workItemId", "productId", "designSystemRevision", '
    '"providerType", "boardIdsJson", "responsiveTargetsJson", '
    '"statesRepresentedJson", "artifactRefsJson", "designerExecutionId", '
    '"reviewExecutionIdsJson", "fidelityAnchorSchemaVersion", "status", '
    '"riskTier", "createdAt", "updatedAt", "version") VALUES '
    "('$revisionId', '$workItemId', 'chainrev-product', 'chainrev-dsr', "
    "'penpot', '[]', '[]', '[]', '[]', 'chainrev-exec', '[]', "
    "'chainrev-v1', '$status', 'low', now(), now(), 1)";

Future<String?> _indexDefinition(PersistenceDatabase db) async {
  final rows = await db.queryNoTransaction(
    "SELECT indexdef FROM pg_indexes WHERE schemaname = '$_chainSchema' "
    "AND indexname = '$_indexName'",
  );
  return rows.isEmpty ? null : rows.first.toColumnMap()['indexdef'] as String;
}

Future<String?> _triggerDefinition(PersistenceDatabase db) async {
  final rows = await db.queryNoTransaction(
    "SELECT pg_get_triggerdef(t.oid) AS def FROM pg_trigger t "
    "JOIN pg_class c ON c.oid = t.tgrelid "
    "JOIN pg_namespace n ON n.oid = c.relnamespace "
    "WHERE n.nspname = '$_chainSchema' AND t.tgname = '$_triggerName' "
    'AND NOT t.tgisinternal',
  );
  return rows.isEmpty ? null : rows.first.toColumnMap()['def'] as String;
}

Future<String?> _recordedVersion(PersistenceDatabase db) async {
  final rows = await db.queryNoTransaction(
    'SELECT version FROM "$_chainSchema"."serverpod_migrations" '
    "WHERE module = 'control_plane'",
  );
  return rows.isEmpty ? null : rows.first.toColumnMap()['version'] as String;
}

Future<List<String>> _columnNames(PersistenceDatabase db) async {
  final rows = await db.queryNoTransaction(
    'SELECT column_name FROM information_schema."columns" '
    "WHERE table_schema = '$_chainSchema' AND table_name = '$_table' "
    'ORDER BY ordinal_position',
  );
  return rows.map((r) => '${r.toColumnMap()['column_name']}').toList();
}

/// Runs [body], returning the error it threw or `null` when it completed.
Future<Object?> _errorFrom(Future<void> Function() body) async {
  try {
    await body();
    return null;
  } catch (error) {
    return error;
  }
}

void main() {
  withServerpod(
    'Chain replay: the destructive migration restores the objects its CASCADE '
    'removed',
    (sessionBuilder, endpoints) {
      tearDown(() async {
        try {
          final db = await _newDb();
          await _dropChainSchema(db);
        } finally {
          await _closeSessions();
        }
      });

      group('replaying the chain leaves both invariants enforced', () {
        test('the objects exist, and they are the declared ones', () async {
          final db = await _newDb();
          await _resetChainSchema(db);
          await db.db.unsafeSimpleExecute(_chainScript());

          // The destructive migration really ran. Without this the two
          // assertions below could be satisfied by the ORIGIN migration's
          // objects alone, which is exactly the state this lane is repairing.
          expect(
            await _columnNames(db),
            contains('fidelityAnchorSchemaVersion'),
            reason:
                'the replay did not apply $_destructiveVersion — a column only '
                'that migration adds must exist. Everything below would '
                'otherwise be reading objects created by $_originVersion.',
          );
          expect(await _recordedVersion(db), _destructiveVersion);

          final index = await _indexDefinition(db);
          expect(
            index,
            isNotNull,
            reason:
                'the chain must recreate $_indexName. The CASCADE above dropped '
                'it and the generated CREATE TABLE cannot render it, so nothing '
                'else puts it back on this path.',
          );
          expect(index, contains('CREATE UNIQUE INDEX'));
          expect(index, contains('("workItemId")'));
          expect(
            index!.toUpperCase(),
            contains('WHERE'),
            reason:
                'the index must be PARTIAL. A plain unique index on workItemId '
                'would also refuse a second approved revision — so a test that '
                'only checks the refusal passes against one — but it would '
                'also refuse the superseded rows a revision transition writes.',
          );
          expect(index, contains("status = 'approved'"));

          final trigger = await _triggerDefinition(db);
          expect(trigger, isNotNull);
          expect(trigger, contains('BEFORE UPDATE'));
          expect(trigger, contains(_table));
          expect(trigger, contains('FOR EACH ROW'));
          expect(trigger, contains('$_functionName()'));
        });

        test('a SECOND approved revision for one work item is refused', () async {
          final db = await _newDb();
          await _resetChainSchema(db);
          await db.db.unsafeSimpleExecute(_chainScript());

          await db.db.unsafeSimpleExecute(
            _insertSql(revisionId: 'chainrev-r1', workItemId: 'chainrev-wi'),
          );
          final error = await _errorFrom(
            () => db.db.unsafeSimpleExecute(
              _insertSql(revisionId: 'chainrev-r2', workItemId: 'chainrev-wi'),
            ),
          );

          expect(
            error,
            isNotNull,
            reason:
                'two approved revisions for one work item were accepted. The '
                'index is what makes approval exclusive under concurrency, and '
                'this is the database refusing rather than a caller checking.',
          );
          expect(
            (error! as DatabaseQueryException).code,
            '23505',
            reason: 'the refusal must be the unique index, not something else',
          );

          // The control: a DIFFERENT work item is unaffected, so what was
          // refused is approval exclusivity and not the table.
          await db.db.unsafeSimpleExecute(
            _insertSql(revisionId: 'chainrev-r3', workItemId: 'chainrev-wi2'),
          );
          // ...and so is a non-approved second revision for the same item.
          await db.db.unsafeSimpleExecute(
            _insertSql(
              revisionId: 'chainrev-r4',
              workItemId: 'chainrev-wi',
              status: 'draft',
            ),
          );
        });

        test('an approved revision cannot be edited in place', () async {
          final db = await _newDb();
          await _resetChainSchema(db);
          await db.db.unsafeSimpleExecute(_chainScript());
          await db.db.unsafeSimpleExecute(
            _insertSql(revisionId: 'chainrev-u1', workItemId: 'chainrev-wiu'),
          );

          final error = await _errorFrom(
            () => db.db.unsafeSimpleExecute(
              'UPDATE "$_chainSchema"."$_table" SET "boardIdsJson" = '
              "'[\"tampered\"]' WHERE \"revisionId\" = 'chainrev-u1'",
            ),
          );
          expect(
            error,
            isNotNull,
            reason:
                'an approved design revision accepted a content UPDATE. It is '
                'an audit record; once approved it may only be superseded by a '
                'new revision, never edited in place.',
          );
          expect(
            error!,
            anyOf(
              isA<DatabaseQueryException>().having(
                (e) => e.message,
                'message',
                contains('Cannot modify approved design revision'),
              ),
              isA<DatabaseQueryException>().having(
                (e) => e.code,
                'code',
                'P0001',
              ),
            ),
          );

          // The control: a NON-approved revision is still updatable, so what
          // was refused is the immutability of an APPROVED one.
          await db.db.unsafeSimpleExecute(
            _insertSql(
              revisionId: 'chainrev-u2',
              workItemId: 'chainrev-wiu',
              status: 'draft',
            ),
          );
          await db.db.unsafeSimpleExecute(
            'UPDATE "$_chainSchema"."$_table" SET "boardIdsJson" = '
            "'[\"ok\"]' WHERE \"revisionId\" = 'chainrev-u2'",
          );
        });
      });

      group('negative control: without the restores the chain enforces nothing', () {
        // A green replay proves nothing unless the replay can also be seen to
        // MISS the objects. This replays the same pair as the migration stood
        // before this lane's fix, and asserts that the invariants genuinely do
        // not hold there.
        test('the objects are absent and both duplicates are accepted', () async {
          final db = await _newDb();
          await _resetChainSchema(db);
          await db.db.unsafeSimpleExecute(
            _chainScript(stripRestoresFrom: _destructiveVersion),
          );

          expect(
            await _columnNames(db),
            contains('fidelityAnchorSchemaVersion'),
            reason:
                'the destructive migration must still have run; this control '
                'varies ONLY the restore block.',
          );
          expect(
            await _indexDefinition(db),
            isNull,
            reason:
                'the pre-fix chain recreates the table without the partial '
                'index. If this is not null the positive tests above are not '
                'proving what they claim.',
          );
          expect(await _triggerDefinition(db), isNull);

          await db.db.unsafeSimpleExecute(
            _insertSql(revisionId: 'chainrev-n1', workItemId: 'chainrev-win'),
          );
          await db.db.unsafeSimpleExecute(
            _insertSql(revisionId: 'chainrev-n2', workItemId: 'chainrev-win'),
          );
          final approved = await db.queryNoTransaction(
            'SELECT count(*)::int AS n FROM "$_chainSchema"."$_table" '
            "WHERE \"workItemId\" = 'chainrev-win' AND \"status\" = 'approved'",
          );
          expect(
            approved.first.toColumnMap()['n'],
            2,
            reason:
                'two approved revisions for one work item were accepted by the '
                'pre-fix chain. This is the loss: the guarantee was never in '
                'the generated CREATE TABLE, so only the restore brings it '
                'back.',
          );

          await db.db.unsafeSimpleExecute(
            'UPDATE "$_chainSchema"."$_table" SET "boardIdsJson" = '
            "'[\"tampered\"]' WHERE \"revisionId\" = 'chainrev-n1'",
          );
          final tampered = await db.queryNoTransaction(
            'SELECT "boardIdsJson" AS v FROM "$_chainSchema"."$_table" '
            "WHERE \"revisionId\" = 'chainrev-n1'",
          );
          expect(
            '${tampered.first.toColumnMap()['v']}',
            '["tampered"]',
            reason:
                'an approved revision accepted a content UPDATE on the pre-fix '
                'chain; the immutability trigger was gone with the CASCADE.',
          );
        });
      });
    },
  );
}
