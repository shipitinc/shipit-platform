import 'dart:convert';
import 'dart:io';

import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// The behaviour of migration `20261014093000000` — the repair that returns
/// eight enumerated defect work items to `triage_defect` at a fresh dedupe
/// attempt.
///
/// ## WHY THIS RUNS AGAINST REAL POSTGRESQL, IN A SCRATCH SCHEMA
///
/// The five properties under test are properties of SQL, and none of them can
/// be demonstrated by reading the file:
///
///   (a) it advances the `triageAttempt` marker so a fresh `:aN` key is built;
///   (b) it moves ONLY the eight enumerated ids;
///   (c) it leaves `planned` and `draft` items untouched;
///   (d) it is idempotent on re-run;
///   (e) it does NOT touch an item that entered the set after dispatch.
///
/// (d) in particular is a claim about what a SECOND application writes, and no
/// static check can make that claim. So the migration is applied — the real
/// `migration.sql`, read off disk, not a paraphrase of it.
///
/// The schema is scratch, never `public`. `test/integration` shares one
/// database with files that run concurrently; a chain replay builds a whole
/// schema from scratch and must not land in the schema everybody else reads.
/// Same rule, same reason and same shape as
/// `onboarding_workspace_postgres_test.dart` and
/// `product_credential_immutability_postgres_test.dart`.
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
/// This also corrects a mis-statement worth correcting out loud: a dispatch
/// brief asserted this migration "will run against the disposable test
/// database in `make test-integration`". It will not. The disposable database
/// takes the fresh path and never replays a `migration.sql`; this file is what
/// actually exercises the artifact.
const _chainSchema = 'shipit_key_repair_chain';

/// The eight targets, each with the state and `triageAttempt` marker it carried
/// when the set was read off QA at dispatch.
///
/// `marker` is null for an ABSENT marker, which is five of the eight. That is
/// not an edge case to be tidied away: `readTriageAttempt` returns null for it,
/// `triageDefectDedupeKey` then builds the BARE unsuffixed key, and any
/// migration that assumed a marker exists would write `':a' || NULL` and either
/// fail or build the wrong key.
const _targets = <(String id, String state, int? marker)>[
  ('defect-DEF-1791684804452198', 'agent_completed', 3),
  ('defect-DEF-1791686704991884', 'agent_completed', 3),
  ('defect-DEF-1791686085546076', 'design_not_required', 2),
  ('defect-DEF-1791684557133597', 'agent_failed', null),
  ('defect-DEF-1791685024220546', 'agent_failed', null),
  ('defect-DEF-1791685264570406', 'agent_failed', null),
  ('defect-DEF-1791685722309971', 'agent_failed', null),
  ('defect-DEF-1791685924503981', 'agent_failed', null),
];

/// A ninth stranded item in the IDENTICAL shape to the `agent_failed` five,
/// deliberately absent from the migration's enumerated list. This is property
/// (e): the set was read off QA at dispatch, and an item that shows up after
/// that must be left alone, not swept up by a `state = 'agent_failed'` arm.
const _lateArrival = 'defect-DEF-1791689999999999';

/// Awaiting intake, not stranded. Both must survive untouched — including the
/// `draft` one, whose `metadataJson` is the EMPTY STRING, the one value in this
/// repository that makes a bare `::jsonb` cast raise.
const _plannedId = 'skr-control-planned';
const _draftId = 'skr-control-draft';

/// One target id, parked in a state it was not dispatched in.
const _movedOnId = 'defect-DEF-1791685024220546';

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
/// test that breaks for the wrong reason. The marker is the transition-id
/// prefix, which is this migration's own and no other migration's.
File _repairMigration() {
  const marker = 'tr-stranded-key-repair-';
  final declaring = _chainMigrations()
      .where(
        (file) => file.readAsStringSync().contains(
          "INSERT INTO \"work_item_transition\"",
        ),
      )
      .where((file) => file.readAsStringSync().contains(marker))
      .toList();
  if (declaring.length != 1) {
    throw StateError(
      'expected exactly one migration writing $marker transition ids, found '
      '${declaring.map((f) => f.path).toList()}. With none, every assertion '
      'below reads nothing and passes vacuously; with more than one, this file '
      'would be testing an arbitrary one of them.',
    );
  }
  return declaring.single;
}

String _versionOf(File migration) =>
    migration.parent.path.split(Platform.pathSeparator).last;

/// The whole chain as ONE simple-query batch for [db] to execute inside
/// `$_chainSchema`.
///
/// Every statement runs on ONE connection, which is what makes the
/// `search_path` hold for the whole replay instead of drifting between pooled
/// connections. `SET LOCAL` inside the explicit transaction, not a bare `SET`:
/// a bare `SET` is session state that returns to Serverpod's pool still
/// carrying it. Each shipped file's own `BEGIN;`/`COMMIT;` wrapper is stripped —
/// nested inside this one they would end the enclosing transaction at worst.
String _chainScript() {
  final buffer = StringBuffer()
    ..writeln('BEGIN;')
    ..writeln('SET LOCAL search_path TO "$_chainSchema";');
  for (final file in _chainMigrations()) {
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
String _applyRepairScript(File migration) {
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
/// keeps the id sequences from drifting between tests.
Future<void> _resetData(PersistenceDatabase db) async {
  await db.db.unsafeSimpleExecute(
    'TRUNCATE "$_chainSchema"."work_item_transition", '
    '"$_chainSchema"."job", '
    '"$_chainSchema"."work_item" RESTART IDENTITY',
  );
}

/// A `work_item` row carrying a realistic defect payload, so a merge that
/// replaced the document instead of merging into it would be visible.
String _workItemSql({
  required String id,
  required String state,
  int? marker,
  String? qaContractId,
  String? metadataOverride,
}) {
  final metadata =
      metadataOverride ??
      jsonEncode({
        'defectId': 'DEF-$id',
        'defectTitle': 'triage key repair fixture',
        'defectDescription': 'a defect payload the retried triage job reads',
        'defectSeverity': 'high',
        if (marker != null) 'triageAttempt': marker,
      });
  return '''
INSERT INTO "$_chainSchema"."work_item" (
  "workItemId", "productId", "category", "title", "description", "state",
  "designContractId", "agentSessionId", "qaContractId", "artifactRefsJson",
  "metadataJson", "createdAt", "updatedAt", "completedAt", "terminatedAt",
  "version"
) VALUES (
  '$id', 'skr-product', 'bugfix', 'fixture $id', 'description',
  '$state', 'design-contract-1', 'session-1',
  ${qaContractId == null ? 'NULL' : "'$qaContractId'"},
  '["snapshot-1"]',
  '${_q(metadata)}'::text,
  now(), now(), NULL, NULL, 1
);''';
}

/// A terminal `triage_defect` job that already CONSUMES [key].
///
/// `activeDedupeKey` is NULL, which is what a terminal job carries: the unique
/// index is on `activeDedupeKey`, so a terminal job releases the key it held —
/// but `enqueueIfAbsent` resolves against `dedupeKey`, and that is the history
/// this repair exists to step around.
String _consumedJobSql({
  required String workItemId,
  required String key,
  required String state,
}) =>
    '''
INSERT INTO "$_chainSchema"."job" (
  "jobId", "workItemId", "jobType", "requiredRole",
  "requiredCapabilitiesJson", "priority", "state", "dedupeKey",
  "activeDedupeKey", "createdAt", "instruction", "attempt", "maxAttempts",
  "version"
) VALUES (
  'skr-job-$workItemId-${key.hashCode.abs()}', '$workItemId', 'triage_defect',
  'TRIAGE_DEFECT', '["linux","git"]', 'high', '$state', '$key', NULL,
  now(), 'triage it', 1, 2, 1
);''';

Future<Map<String, Object?>> _workItem(
  PersistenceDatabase db,
  String id,
) async {
  final rows = await db.queryNoTransaction(
    'SELECT "state", "version", "metadataJson", "qaContractId", "title", '
    '"description", "designContractId", "agentSessionId", "artifactRefsJson", '
    '"completedAt", "terminatedAt" '
    'FROM "$_chainSchema"."work_item" WHERE "workItemId" = \'${_q(id)}\'',
  );
  if (rows.length != 1) {
    throw StateError(
      'expected exactly one work_item row for $id, got ${rows.length}',
    );
  }
  return rows.single.toColumnMap();
}

/// How many `triage_defect` jobs exist on [key] for [workItemId]. Zero is the
/// property that makes a repaired item dispatchable.
Future<int> _holders(
  PersistenceDatabase db,
  String workItemId,
  String key,
) async {
  final rows = await db.queryNoTransaction(
    'SELECT count(*)::int AS n FROM "$_chainSchema"."job" '
    'WHERE "workItemId" = \'${_q(workItemId)}\' AND "dedupeKey" = \'${_q(key)}\'',
  );
  return rows.single.toColumnMap()['n']! as int;
}

Future<List<Map<String, Object?>>> _repairAuditRows(
  PersistenceDatabase db,
) async {
  final rows = await db.queryNoTransaction(
    'SELECT "transitionId", "workItemId", "fromState", "toState", '
    '"idempotencyKey", "guardEvaluationsJson", "reason" '
    'FROM "$_chainSchema"."work_item_transition" '
    "WHERE \"transitionId\" LIKE 'tr-stranded-key-repair-%'",
  );
  return [for (final r in rows) r.toColumnMap()];
}

String _q(String value) => value.replaceAll("'", "''");

/// Installs the full stranded fixture: the eight targets, each on a consumed
/// key with a QA contract; the three controls; and the terminal jobs that make
/// the keys consumed.
Future<void> _seedStrandedSet(PersistenceDatabase db) async {
  final buffer = StringBuffer();

  for (final (id, state, marker) in _targets) {
    buffer.writeln(
      _workItemSql(
        id: id,
        state: state,
        marker: marker,
        qaContractId: 'qa-$id',
      ),
    );
    if (marker == null) {
      // The bare, unsuffixed key -- what an ABSENT marker computes to. A
      // succeeded triage job holds it, which is precisely the strand.
      buffer.writeln(
        _consumedJobSql(
          workItemId: id,
          key: '$id:triage_defect',
          state: 'succeeded',
        ),
      );
    } else {
      // Attempts 1..marker-1 are consumed, so the job floor sits BELOW the
      // marker and the two terms of the `greatest` are independently exercised.
      for (var attempt = 1; attempt < marker; attempt++) {
        buffer.writeln(
          _consumedJobSql(
            workItemId: id,
            key: '$id:triage_defect:a$attempt',
            state: attempt == 1 ? 'failed' : 'succeeded',
          ),
        );
      }
      // And the CURRENT key is held too, by the job that stranded it.
      buffer.writeln(
        _consumedJobSql(
          workItemId: id,
          key: '$id:triage_defect:a$marker',
          state: 'succeeded',
        ),
      );
    }
  }

  // (c) Awaiting intake. The `planned` item even carries a HIGHER marker than
  // any target, so a repair that swept by marker rather than by id would move
  // it. The `draft` item carries the empty-string metadataJson.
  buffer.writeln(
    _workItemSql(
      id: _plannedId,
      state: 'planned',
      marker: 9,
      qaContractId: 'qa-$_plannedId',
    ),
  );
  buffer.writeln(
    _consumedJobSql(
      workItemId: _plannedId,
      key: '$_plannedId:triage_defect:a9',
      state: 'succeeded',
    ),
  );
  buffer.writeln(
    _workItemSql(
      id: _draftId,
      state: 'draft',
      metadataOverride: '',
      qaContractId: null,
    ),
  );

  // (e) The ninth stranded item: identical shape, absent from the list.
  buffer.writeln(
    _workItemSql(
      id: _lateArrival,
      state: 'agent_failed',
      marker: null,
      qaContractId: 'qa-$_lateArrival',
    ),
  );
  buffer.writeln(
    _consumedJobSql(
      workItemId: _lateArrival,
      key: '$_lateArrival:triage_defect',
      state: 'succeeded',
    ),
  );

  await db.db.unsafeSimpleExecute(buffer.toString());
}

int? _markerOf(Map<String, Object?> row) {
  final raw = row['metadataJson'] as String?;
  if (raw == null || raw.isEmpty) return null;
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final value = decoded['triageAttempt'];
  return value is int ? value : null;
}

void main() {
  withServerpod(
    'migration 20261014093000000 repairs the stranded triage dedupe keys',
    (sessionBuilder, endpoints) {
      late PersistenceDatabase db;
      late File repair;

      setUpAll(() async {
        db = await _newDb();
        repair = _repairMigration();
        // ignore: avoid_print
        print('stranded-key-repair under test: ${_versionOf(repair)}');
        await _resetChainSchema(db);
        await db.db.unsafeSimpleExecute(_chainScript());
      });

      tearDownAll(() async {
        await _dropChainSchema(db);
        await _closeSessions();
      });

      setUp(() => _resetData(db));

      test('it names exactly the eight ids the set was dispatched with', () {
        // The migration's own enumeration, read out of its SQL. A drift between
        // the migration and the dispatch table has to fail HERE, not as an
        // unexplained zero-row repair against live data.
        final sql = repair.readAsStringSync();
        final enumerated = RegExp(
          r"'(defect-DEF-\d+)'\s*,\s*'(?:agent_|design_)",
        ).allMatches(sql).map((m) => m.group(1)!).toSet();
        expect(
          enumerated,
          _targets.map((t) => t.$1).toSet(),
          reason:
              'the migration must enumerate exactly the dispatched set, with '
              'no additions and no omissions',
        );
        for (final (id, state, _) in _targets) {
          expect(
            sql.contains("('$id', '$state')"),
            isTrue,
            reason: '$id must be listed with its expected pre-repair state',
          );
        }
      });

      test('its banner does not deny the engineering_review entry state', () {
        // `agent_completed` IS a wired entry state --
        // `engineeringReviewDefinition.entryStates == {agentCompleted}`
        // (packages/scheduler/lib/src/scheduler.dart:2166), wired at
        // apps/server/lib/server.dart:105. A banner that denies this is not
        // merely imprecise: it is the stated reason the two `agent_completed`
        // items are being moved, and it would send monitoring to watch for the
        // wrong strand. `agent_failed` really is in no wired entry state, so
        // the negation is asserted only for `agent_completed`.
        final banner = repair.readAsStringSync();
        expect(
          banner,
          isNot(
            contains(
              '`agent_completed` and `agent_failed` are in no wired',
            ),
          ),
          reason:
              'only agent_failed is in no wired entryStates; agent_completed '
              'IS engineeringReviewDefinition.entryStates.',
        );
        expect(
          banner,
          isNot(contains('agent_completed / agent_failed are in no wired')),
          reason:
              'the same denial appears a second time in the DOWN warning, so '
              'asserting only the first occurrence would leave the false '
              'claim standing in the rollback instructions.',
        );
        expect(
          banner,
          contains('engineeringReviewDefinition'),
          reason:
              'the banner must name the definition that actually claims '
              'agent_completed, so the correction cannot be silently undone.',
        );
        expect(
          banner,
          contains('engineeringReviewDedupeKey'),
          reason:
              'the unsuffixed engineering_review key is the actual blocker for '
              'the two agent_completed items and must be stated.',
        );
        expect(
          banner,
          contains('engineering_review'),
          reason: 'the wire form of that key is what is consumed for ever.',
        );
      });

      test('its DOWN does not claim absent and 0 read alike', () {
        // Executed, not asserted: `readTriageAttempt` returns `null` for an
        // ABSENT marker (`marker == null` -> null,
        // durable_workflow_engine.dart:346-365) and `0` for a stored zero, and
        // `triageDefectDedupeKey` then builds the BARE key for the first and
        // `':a0'` for the second (triage_defect.dart:118-123). The old comment
        // claimed they "mean the same thing to readTriageAttempt" and then
        // undercut itself in the same breath -- and durable_workflow_engine.dart
        // :381-383 says the opposite outright ("ABSENT means `1`, so the FIRST
        // re-triage ... is never `:a0`"). `nextTriageAttempt` is
        // `max(floor, marker ?? 0) + 1`, so no writer ever mints 0 and `:a0` is
        // a key nothing can reach.
        final down = repair.readAsStringSync();
        expect(
          down,
          contains('NOT the same to `readTriageAttempt`'),
          reason:
              'absent reads null and builds the bare key; 0 reads 0 and '
              'builds :a0. They are not the same.',
        );
        expect(
          down,
          contains('a value `nextTriageAttempt`'),
          reason:
              'the :a0 half of the difference must be stated, because it is '
              'what makes the two stored values behave differently.',
        );
        expect(
          down,
          contains(
            'never mints. The difference does not bite because of the STATE, '
            'not the',
          ),
          reason:
              '`:a0` is a key nextTriageAttempt never mints, and the '
              'harmlessness is the STATE'
              's doing. Asserted on single source '
              'lines: a substring spanning a `--` line break would have to '
              'match the comment prefix too, which is how the first draft of '
              'this assertion failed on text that was already correct.',
        );
        expect(
          down,
          contains('because of the STATE, not the'),
          reason:
              'the causal clause is what makes the difference harmless, and it '
              'is the STATE (every affected row returns to `agent_failed`, '
              'which no JobDefinition claims) -- not the marker. Getting this '
              'backwards is the defect the previous wording had.',
        );
        // Absence, as a REGEX rather than one literal, so any rewording that
        // reintroduces reader-equivalence fails and not only the exact string
        // that was corrected.
        expect(
          down,
          isNot(
            matches(
              RegExp(
                r'Absent and 0[^.]*\bsame thing to .?readTriageAttempt',
                caseSensitive: false,
              ),
            ),
          ),
          reason:
              'no sentence may claim readTriageAttempt treats absent and 0 '
              'alike. This is the claim that was false, and the regex covers '
              'every phrasing of it, not just the one that was written.',
        );
        expect(
          down,
          isNot(contains('Absent and 0 mean')),
          reason:
              'the exact false opener, asserted separately so the '
              'correction cannot be reverted by a partial edit.',
        );
      });

      // The marker-writer enumeration is asserted in test (b) instead, against
      // the MATERIALISED `reason` rather than this file's source: it is SQL
      // string concatenation, so the prose only exists once Postgres has joined
      // the literals. Asserting it here would be matching source fragments, not
      // the sentence that lands in eight permanent rows.

      test(
        '(a) it advances the marker to a key nothing holds, for every target',
        () async {
          await _seedStrandedSet(db);
          await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

          for (final (id, state, marker) in _targets) {
            final row = await _workItem(db, id);
            final written = _markerOf(row);
            expect(
              written,
              isNotNull,
              reason:
                  '$id must carry a marker after the repair, including '
                  'the five that had none',
            );
            expect(
              written,
              (marker ?? 0) + 1,
              reason:
                  '$id: the new attempt must be greater than BOTH the marker '
                  'it had ($marker) and the highest attempt its triage job '
                  'keys had already consumed',
            );
            // The property that makes the repair worth anything: the key the
            // scheduler will now compute must have ZERO holders, or
            // enqueueIfAbsent returns created:false and nothing moves.
            expect(
              await _holders(db, id, '$id:triage_defect:a$written'),
              0,
              reason:
                  '$id: the repaired key must be provably unheld, or the item '
                  'stays dispatchable and inert',
            );
            // And the state it is dispatched FROM.
            expect(
              row['state'],
              'design_not_required',
              reason:
                  '$id must land in triageDefectDefinition\'s entry state. It '
                  'was $state, which no wired JobDefinition lists.',
            );
          }
        },
      );

      test(
        '(b) it moves exactly the eight enumerated ids and nothing else',
        () async {
          await _seedStrandedSet(db);
          final before = <String, Map<String, Object?>>{
            for (final (id, _, _) in _targets) id: await _workItem(db, id),
          };

          await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

          // Not "the eight are right" but "the eight are the ONLY ones that
          // changed": a repair that quietly moved a tenth row is the failure
          // this test is here to catch, and asserting only the eight cannot
          // see it.
          final moved = await db.queryNoTransaction(
            'SELECT count(*)::int AS n FROM "$_chainSchema"."work_item" '
            'WHERE "version" <> 1',
          );
          expect(
            moved.single.toColumnMap()['n'],
            8,
            reason:
                'exactly eight rows may carry a version bump. A ninth means the '
                'selection reached an item it was not told about.',
          );

          final audit = await _repairAuditRows(db);
          expect(
            audit.map((r) => r['workItemId']).toSet(),
            _targets.map((t) => t.$1).toSet(),
          );
          expect(audit, hasLength(8));
          for (final row in audit) {
            expect(
              row['toState'],
              'design_not_required',
            );
            expect(
              row['guardEvaluationsJson'],
              isNull,
              reason:
                  'this repair does not walk the transition table at all -- it '
                  'writes the column directly -- so no guard was evaluated. '
                  'A value here would claim a verdict nobody took. Note this '
                  'is NOT because "no edge exists": an '
                  'agent_failed -> design_not_required edge does exist '
                  '(work_item_transitions.dart:149-151).',
            );
            expect(
              row['idempotencyKey'],
              'stranded-key-repair:consumed-triage-dedupe-key',
            );
          }

          // THE AUDIT ROW IS PERMANENT LEDGER TEXT. These eight rows are
          // written to a live table the moment this migration is applied and
          // are never rewritten, so a false claim in the `reason` is a false
          // claim on the record for good. `agent_failed ->
          // design_not_required` DOES exist; only `agent_completed ->
          // design_not_required` does not. Asserting the TRUTH here is what
          // stops the old wording coming back.
          for (final row in audit) {
            final reason = row['reason']! as String;
            expect(
              reason,
              contains('NO agent_completed -> design_not_required edge exists'),
              reason: 'the absent edge must be named.',
            );
            expect(
              reason,
              contains('agent_failed -> design_not_required DOES exist'),
              reason:
                  'the five agent_failed rows are repaired around an edge that '
                  'legally exists, and the ledger must say so.',
            );
            expect(
              reason,
              isNot(contains('no agent_completed -> design_not_required or')),
              reason:
                  'the old text denied BOTH edges, which is false for five of '
                  'the eight.',
            );
            expect(
              reason,
              isNot(
                contains('agent_failed -> design_not_required edge exists'),
              ),
              reason:
                  'the agent_failed edge must never be described as absent.',
            );

            // THE MARKER-WRITER ENUMERATION. Three writers of
            // `triageAttempt` exist in production code, not two:
            //
            //   * `DurableWorkflowEngine.operatorRetry`
            //     (durable_workflow_engine.dart:486-497) -- `metadataMerge` on
            //     the engine's own `transition` call;
            //   * `DurableWorkflowEngine.resolveHumanDecision`
            //     (durable_workflow_engine.dart:822-824, 845-847) -- NOT a
            //     `metadataMerge` call: it merges the key into a COPY of the
            //     item's metadata and persists that with `tx.saveWorkItem`
            //     directly. The `metadataMerge` argument belongs to
            //     `transition()` (:136, :230-232), which this method never
            //     calls;
            //   * the scheduler's completion-inflow route
            //     (packages/scheduler/lib/src/scheduler.dart:950-975) --
            //     `metadataMerge` on `engine.transition` (:952, :973-975),
            //     added by the OD-10 completion inflow in 951d7db.
            //
            // Two of the three share a mechanism; the third does not. A list
            // that named only the first two was not exhaustive, and this text
            // is written into eight permanent live rows.
            expect(
              reason,
              contains(
                'none of the THREE writers of the marker is an edge',
              ),
              reason:
                  'the enumeration must be stated as complete and as three, so '
                  'it cannot read as a two-item list that happens to end.',
            );
            expect(
              reason,
              contains(
                'DurableWorkflowEngine.operatorRetry '
                '(durable_workflow_engine.dart:486-497)',
              ),
              reason: 'writer one, with the site that writes the marker.',
            );
            expect(
              reason,
              contains(
                // `\'`, NOT `''`: in a Dart single-quoted literal `''`
                // closes and reopens, so adjacent-literal concatenation would
                // silently swallow the apostrophe and the assertion would then
                // be vacuous against a text that does carry one.
                'the scheduler\'s completion-inflow route '
                '(packages/scheduler/lib/src/scheduler.dart:950-975)',
              ),
              reason:
                  'writer three is the one the old text omitted entirely; it '
                  'is a live writer introduced by 951d7db.',
            );
            expect(
              reason,
              contains(
                'DurableWorkflowEngine.resolveHumanDecision '
                '(durable_workflow_engine.dart:822-824, 845-847)',
              ),
              reason: 'writer two, with the site that writes the marker.',
            );
            expect(
              reason,
              isNot(
                matches(RegExp(r'operatorRetry and resolveHumanDecision')),
              ),
              reason:
                  'the stale two-name enumeration must be gone; a false claim '
                  'in this column is a false claim on the record for ever.',
            );
            expect(
              reason,
              isNot(contains('never by an edge')),
              reason:
                  'the old sentence drew the conclusion from an exhaustive-'
                  'looking two-writer list that was not exhaustive.',
            );
            // The clause that was NOT verifiable: `resolveHumanDecision` does
            // not pass the marker as `metadataMerge`, so the replacement text
            // must not group it with the two that do.
            expect(
              reason,
              contains(
                'merges it into a COPY of the item\'s metadata',
              ),
              reason:
                  'resolveHumanDecision writes the marker by merging into a '
                  'copy of the item\'s metadata and saving that directly '
                  '(durable_workflow_engine.dart:818-833, 845-847). It never '
                  'passes `metadataMerge`, which is an argument of '
                  '`transition()` that this method does not call. Asserted so '
                  'the grouping cannot be silently "simplified" back.',
            );
            expect(
              reason,
              contains('so no edge could have performed this repair'),
              reason:
                  'the conclusion the enumeration supports, in its own words.',
            );
          }

          // Every other column the requirement calls "preserve everything else"
          // must be byte-identical across the move.
          for (final (id, _, _) in _targets) {
            final after = await _workItem(db, id);
            for (final column in [
              'title',
              'description',
              'designContractId',
              'agentSessionId',
              'qaContractId',
              'artifactRefsJson',
              'completedAt',
              'terminatedAt',
            ]) {
              expect(
                after[column],
                before[id]![column],
                reason: '$id.$column must survive the repair',
              );
            }
            final merged =
                jsonDecode(after['metadataJson']! as String)
                    as Map<String, dynamic>;
            final original =
                jsonDecode(before[id]!['metadataJson']! as String)
                    as Map<String, dynamic>;
            for (final key in original.keys) {
              if (key == 'triageAttempt') continue;
              expect(
                merged[key],
                original[key],
                reason:
                    '$id.metadataJson.$key must survive: the marker is merged '
                    'with a jsonb ||, never written over the document',
              );
            }
          }
        },
      );

      test(
        '(c) it leaves `planned` and `draft` items completely alone',
        () async {
          await _seedStrandedSet(db);
          final plannedBefore = await _workItem(db, _plannedId);
          final draftBefore = await _workItem(db, _draftId);

          await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

          expect(
            await _workItem(db, _plannedId),
            plannedBefore,
            reason:
                'a `planned` item is awaiting intake, not stranded. Its marker is '
                'HIGHER than every target\'s, so a repair that swept by marker '
                'rather than by id would move it.',
          );
          expect(
            await _workItem(db, _draftId),
            draftBefore,
            reason:
                'a `draft` item is awaiting intake, and its metadataJson is the '
                'EMPTY STRING -- the one value in this repository that makes a '
                'bare ::jsonb cast raise. The migration must never touch it.',
          );
        },
      );

      test('(d) it is idempotent on re-run', () async {
        await _seedStrandedSet(db);
        await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

        final afterFirst = <String, Map<String, Object?>>{
          for (final (id, _, _) in _targets) id: await _workItem(db, id),
        };
        final auditAfterFirst = await _repairAuditRows(db);

        // Second and third applications, in one batch each.
        await db.db.unsafeSimpleExecute(_applyRepairScript(repair));
        await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

        for (final (id, _, _) in _targets) {
          final afterSecond = await _workItem(db, id);
          expect(
            afterSecond['version'],
            afterFirst[id]!['version'],
            reason:
                '$id: a second application must write nothing. The marker '
                'arithmetic is `greatest(marker, jobFloor) + 1`, so an '
                'unguarded replay would advance it again on every run.',
          );
          expect(
            _markerOf(afterSecond),
            _markerOf(afterFirst[id]!),
            reason: '$id: the marker must not advance again',
          );
        }
        expect(
          await _repairAuditRows(db),
          auditAfterFirst,
          reason:
              'a replay must write no second audit row. The ids are '
              'deterministic, so a forced replay collides on '
              'work_item_transition_id_unique rather than duplicating history.',
        );
      });

      test(
        '(e) it does NOT touch an item that entered the set after dispatch',
        () async {
          await _seedStrandedSet(db);
          final lateBefore = await _workItem(db, _lateArrival);

          await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

          expect(
            await _workItem(db, _lateArrival),
            lateBefore,
            reason:
                '$_lateArrival is stranded in exactly the same shape as the '
                'five agent_failed targets but is absent from the enumerated '
                'list. The set was read off QA at dispatch, and an item that '
                'appears after that must be left for a human -- a broad '
                '"state = \'agent_failed\'" arm would silently start work '
                'nobody asked for.',
          );
          expect(
            await _repairAuditRows(
              db,
            ).then((r) => r.map((e) => e['workItemId']).toList()),
            isNot(contains(_lateArrival)),
          );
        },
      );

      test('it leaves an enumerated target alone if it moved on by itself', () async {
        // The expected-state arm. Between dispatch and apply, an operator or a
        // scheduler tick could move one of the eight; rewriting its state back
        // would resurrect a defect someone already resolved.
        await _seedStrandedSet(db);
        await db.db.unsafeSimpleExecute(
          'UPDATE "$_chainSchema"."work_item" SET "state" = \'review_rejected\' '
          'WHERE "workItemId" = \'$_movedOnId\'',
        );
        final before = await _workItem(db, _movedOnId);

        await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

        expect(
          await _workItem(db, _movedOnId),
          before,
          reason:
              '$_movedOnId no longer holds the state it held at dispatch, so the '
              'migration must not touch it.',
        );
        expect(
          (await _repairAuditRows(db)).map((r) => r['workItemId']),
          isNot(contains(_movedOnId)),
        );
      });

      test(
        'it refuses, and changes nothing, when an in-scope target has no QA '
        'contract',
        () async {
          await _seedStrandedSet(db);
          // Strip the QA contract from ONE of the eight. Re-triaging an item
          // without one means the agentExecuting -> agentCompleted guard
          // (GuardConditions.qaContractExists()) refuses the finish and the
          // item strands in agentExecuting -- a worse strand than the one
          // being repaired.
          await db.db.unsafeSimpleExecute(
            'UPDATE "$_chainSchema"."work_item" SET "qaContractId" = NULL '
            'WHERE "workItemId" = \'${_targets.first.$1}\'',
          );
          final before = <String, Map<String, Object?>>{
            for (final (id, _, _) in _targets) id: await _workItem(db, id),
          };

          Object? failure;
          try {
            await db.db.unsafeSimpleExecute(_applyRepairScript(repair));
          } catch (error) {
            failure = error;
          }

          expect(
            failure,
            isNotNull,
            reason:
                'the migration must abort rather than repair an item that '
                'cannot finish',
          );
          expect(
            failure.toString(),
            allOf(
              contains(_targets.first.$1),
              contains('no qa_contract'),
              contains('Nothing was changed'),
            ),
            reason:
                'a loud failure that names neither the offending work item nor '
                'the all-or-nothing outcome is not a loud failure an operator '
                'can act on',
          );

          // All eight, not just the one that tripped the guard: the migration
          // is one transaction, so a partial repair would leave a mix of
          // repaired and unrepaired items with nothing distinguishing them.
          for (final (id, _, _) in _targets) {
            expect(
              await _workItem(db, id),
              before[id],
              reason:
                  '$id: the transaction rolled back, so no target moved -- '
                  'including the seven that were perfectly repairable.',
            );
          }
          expect(await _repairAuditRows(db), isEmpty);
        },
      );

      test('a target with an absent marker is repaired, not skipped', () async {
        // The dispatch flagged this explicitly: five of the eight have NO
        // marker at all. A migration that read `metadata['triageAttempt']` and
        // assumed it was there would either raise or build ':a' || NULL.
        await _seedStrandedSet(db);
        final bare = _targets.firstWhere((t) => t.$3 == null);
        expect(
          _markerOf(await _workItem(db, bare.$1)),
          isNull,
          reason: 'the fixture must genuinely start without a marker',
        );

        await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

        final row = await _workItem(db, bare.$1);
        expect(
          _markerOf(row),
          1,
          reason:
              'an absent marker contributes 0 to the greatest, so the first '
              'repaired attempt of a never-re-triaged item is :a1 -- never '
              ':a0 and never the bare key a terminal job still holds',
        );
        expect(row['state'], 'design_not_required');
        expect(await _holders(db, bare.$1, '${bare.$1}:triage_defect:a1'), 0);
      });

      test('it is a no-op against an empty schema', () async {
        // The fresh-database path in `make test-integration` builds `public`
        // from the newest definition.sql and never replays this file, so this
        // is literally what a brand-new database gets from it. It must not
        // fail, and it must not invent rows.
        await db.db.unsafeSimpleExecute(_applyRepairScript(repair));
        expect(await _repairAuditRows(db), isEmpty);
        final items = await db.queryNoTransaction(
          'SELECT count(*)::int AS n FROM "$_chainSchema"."work_item"',
        );
        expect(items.single.toColumnMap()['n'], 0);
      });
    },
  );
}
