import 'dart:convert';
import 'dart:io';

import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// The behaviour of migration `20261014210000000` — the repair that retires
/// engineering-review decisions no reviewer ever backed, without deleting them,
/// and returns their work items to a dispatchable review at a fresh key.
///
/// ## WHY THIS RUNS AGAINST REAL POSTGRESQL, IN A SCRATCH SCHEMA
///
/// Every property under test is a property of SQL. None of them can be
/// demonstrated by reading the file:
///
///   (a) it retires the decision WITHOUT deleting it, preserving the fabricated
///       question, options and recommendation verbatim as evidence;
///   (b) it moves ONLY the enumerated targets, to `agent_completed`, with the
///       blocking decision cleared;
///   (c) it advances `triageAttempt` to a review key nothing holds — the
///       property that makes the item dispatchable rather than inert;
///   (d) it REFUSES, changing nothing, when an enumerated target turns out to
///       have real reviewer output — the guardrail;
///   (e) it never touches a `reviewerProseOnly` decision, which is a real
///       review the machine channel failed to capture;
///   (f) it is idempotent on re-run; and
///   (g) its `down` restores the prior values EXACTLY, including an absent
///       `triageAttempt`.
///
/// (d), (f) and (g) in particular are claims about what a SECOND or REVERSED
/// application writes, and no static check can make such a claim. So the
/// migration is applied — the real `migration.sql`, read off disk, not a
/// paraphrase of it — and, for (g), so is the real `down`.
///
/// The schema is scratch, never `public`. `test/integration` shares one
/// database with files that run concurrently; a chain replay builds a whole
/// schema from scratch and must not land in the schema everybody else reads.
/// Same rule, same reason and same shape as
/// `stranded_key_repair_migration_test.dart` and
/// `product_repoint_migration_test.dart`.
///
/// ## WHY THE CHAIN IS REPLAYED AT ALL
///
/// `make test-integration` and CI build `public` from the LATEST
/// `definition.sql` alone, so on a fresh database this migration's
/// `migration.sql` is never executed — a data repair is a no-op on an empty
/// schema. A deployed database is chain-migrated and replays every
/// `migration.sql`. That deployed path is the one under test, so it is the one
/// built here.
const _chainSchema = 'shipit_unreviewed_review_chain';

/// The two targets, as enumerated by the migration.
///
/// These are the LIVE QA ids, read off the QA database on 2026-10-14. They are
/// not invented fixtures: `dec-hn7h7daum6-2atjhe` was in the dispatch table
/// too, and is deliberately NOT here, because by the time this was written it
/// had already been APPROVED by an operator and its work item had moved on to
/// `review_approved`. See `_approvedByHuman` below.
const _targets = <(String decisionId, String workItemId)>[
  ('dec-hn7h7d9j8i-1oh8pgm', 'defect-DEF-1791684557133597'),
  ('dec-hn7h7db3w9-hdzu8c', 'defect-DEF-1791685924503981'),
];

/// The `triageAttempt` marker both targets carried in QA, and the attempt their
/// `engineering_review` job keys had consumed. Both review job keys were the
/// UNSUFFIXED form, which consumes no attempt, so the expected new attempt is
/// `2 + 1 = 3` and the key the repair must make available is `:a3`.
const _markerBefore = 2;
const _expectedAttempt = 3;

/// A `reviewerProseOnly` decision, in the EXACT shape QA holds today.
///
/// Its reviewer execution COMPLETED and wrote 2000 characters of a real
/// engineering review — `defect-DEF-1791685024220546`'s review literally opens
/// "## Engineering Review" and states "Verdict:
/// `APPROVE_WITH_NON_BLOCKING_FOLLOWUP`" — while the decision it produced
/// claims `changes_required`.
///
/// It is NOT in the migration's enumerated list, and it must survive completely
/// untouched. This is the single most important assertion in the file: a repair
/// keyed on "no machine-readable verdict" rather than on "no reviewer output at
/// all" would have destroyed this review, and the summary is the only place it
/// exists.
const _proseOnlyId = 'dec-hn7h7dagw5-l4o193';
const _proseOnlyWorkItem = 'defect-DEF-1791685024220546';
const _proseOnlyExecution = 'agx-wx-jb-hn7gq1n2dc-1llxxyk';

/// The third decision from the dispatch table, which QA shows is no longer
/// pending: an operator approved it, and its work item moved to
/// `review_approved`. Repairing it would mean overwriting a recorded human
/// approval, so the migration must not select it — and if it were selected, the
/// `choice IS NOT NULL` arm must refuse.
const _approvedByHumanId = 'dec-hn7h7daum6-2atjhe';
const _approvedByHumanWorkItem = 'defect-DEF-1791685264570406';

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
/// Never by registry position and never by a hard-coded version. The marker is
/// the CONSTRUCTION SITE of the transition id, not the bare prefix: matching the
/// prefix alone would also match a later migration that merely NAMES the prefix
/// while documenting which prefixes its own rollback must not delete — and this
/// repository already has several such migrations.
File _repairMigration() {
  const marker = "'tr-unreviewed-review-repair-' ||";
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

/// The registry row a real deployment has and a chain-built schema does not.
///
/// NO migration in this repository inserts a `product` row, so a schema replayed
/// from `migration.sql` alone has an EMPTY `product` table, and migration
/// `20261014130500000` (the product repoint) refuses on an empty one by design.
/// Placed by CONTENT, immediately before that migration's file, because the
/// guard runs INSIDE the replay. Test scaffolding standing in for a registry
/// production populates, and it says so in the row it inserts.
const _productRegistrySeed =
    '''
INSERT INTO "$_chainSchema"."product"
    ("productId", "name", "description", "manifestVersion", "state",
     "createdAt", "updatedAt", "version")
VALUES ('shipit-platform', 'ShipIt Platform',
        'seeded by the chain-replay harness; a real deployment creates this '
        'row through the product registry, never through a migration',
        'test', 'governed', now(), now(), 1);
''';

/// The work-item rows migration `20261014130500000` refuses to replay without.
///
/// Read out of that migration's OWN target table rather than restated here, so
/// the id list stays declared exactly once.
String _repointTargetSeed() {
  final declaring = _chainMigrations()
      .where(
        (file) => file.readAsStringSync().contains("'tr-product-repoint-' ||"),
      )
      .toList();
  if (declaring.length != 1) {
    throw StateError(
      'expected exactly one migration writing tr-product-repoint- transition '
      'ids, found ${declaring.map((f) => f.path).toList()}.',
    );
  }
  final ids =
      RegExp(
            r"\('((?:defect|design-remediation)-DEF-\d+)', 'defects'\)",
          )
          .allMatches(declaring.single.readAsStringSync())
          .map((m) => m.group(1)!)
          .toSet();
  if (ids.isEmpty) {
    throw StateError(
      'no work item ids found in ${declaring.single.path}; the chain seed '
      'would be empty',
    );
  }
  final buffer = StringBuffer();
  for (final id in ids.toList()..sort()) {
    // `featureRef` is the parent DEF id, with the work-item prefix stripped.
    // Migration `20261014130500000` checks exactly this: every
    // `design-remediation-DEF-n` row must agree with its parent on
    // `featureRef`, and the expected value is `DEF-n`. A synthetic prefix here
    // makes that guard refuse the whole chain replay, which is a correct
    // refusal of a wrong fixture rather than a defect in the migration under
    // test -- but it takes the suite down in `setUpAll`, so it is worth getting
    // right.
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

const _needsProductRegistry = "'tr-product-repoint-' ||";

/// The whole chain as ONE simple-query batch, in `$_chainSchema`.
String _chainScript() {
  final buffer = StringBuffer()
    ..writeln('BEGIN;')
    ..writeln('SET LOCAL search_path TO "$_chainSchema";');
  for (final file in _chainMigrations()) {
    if (file.readAsStringSync().contains(_needsProductRegistry)) {
      buffer
        ..writeln(_productRegistrySeed)
        ..writeln(_repointTargetSeed());
    }
    buffer.writeln(_stripTransactionWrapper(file.readAsStringSync()));
  }
  buffer.writeln('COMMIT;');
  return buffer.toString();
}

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

/// The migration under test, applied VERBATIM in `$_chainSchema`.
String _applyRepairScript(File migration) {
  final buffer = StringBuffer()
    ..writeln('BEGIN;')
    ..writeln('SET LOCAL search_path TO "$_chainSchema";')
    ..writeln(_stripTransactionWrapper(migration.readAsStringSync()))
    ..writeln('COMMIT;');
  return buffer.toString();
}

/// The migration's DOWN section, executed rather than asserted.
///
/// Extracted by content between its own markers, so a `down` that lies cannot
/// pass this file by being well-commented: the statements that are actually
/// written are the ones that run.
String _downScript(File migration) {
  final sql = migration.readAsStringSync();
  const start = '-- -- DOWN SCRIPT START\n';
  const end = '-- -- DOWN SCRIPT END';
  final begin = sql.indexOf(start);
  final stop = begin == -1 ? -1 : sql.indexOf(end, begin);
  if (begin == -1 || stop == -1) {
    throw StateError(
      'the DOWN section of ${migration.path} has no delimited executable '
      'region, so it cannot be run here and a lying rollback would pass',
    );
  }
  final buffer = StringBuffer()
    ..writeln('BEGIN;')
    ..writeln('SET LOCAL search_path TO "$_chainSchema";');
  for (final line in sql.substring(begin + start.length, stop).split('\n')) {
    if (line.trim() == '--') continue;
    if (line.startsWith('-- ')) {
      buffer.writeln(line.substring(3));
    } else if (line.trim().isNotEmpty) {
      throw StateError(
        'every line in the DOWN executable region must carry the `-- ` prefix, '
        'so the block is inert until deliberately run. Found: $line',
      );
    }
  }
  buffer.writeln('COMMIT;');
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
/// Safe here and unsafe in `public`: this schema is built and dropped by this
/// file and read by nobody else.
Future<void> _resetData(PersistenceDatabase db) async {
  await db.db.unsafeSimpleExecute(
    'TRUNCATE "$_chainSchema"."work_item_transition", '
    '"$_chainSchema"."human_decision", '
    '"$_chainSchema"."agent_result", '
    '"$_chainSchema"."agent_execution", '
    '"$_chainSchema"."job", '
    '"$_chainSchema"."work_item" RESTART IDENTITY',
  );
}

String _q(String value) => value.replaceAll("'", "''");

String _workItemSql({
  required String id,
  required String state,
  required String? blockingDecisionId,
  String? blockingReason =
      'Engineering review requires changes. '
      'Approve, reject, or request rework?',
  int? marker = _markerBefore,
}) {
  final metadata = jsonEncode({
    'defectId': 'DEF-$id',
    'defectTitle': 'unreviewed review repair fixture',
    'defectDescription': 'a defect payload the re-run lane reads',
    if (marker != null) 'triageAttempt': marker,
  });
  return '''
INSERT INTO "$_chainSchema"."work_item" (
  "workItemId", "productId", "category", "title", "description", "state",
  "blockingHumanDecisionId", "blockingReason", "qaContractId", "artifactRefsJson",
  "metadataJson", "createdAt", "updatedAt", "version"
) VALUES (
  '$id', 'shipit-platform', 'bugfix', 'fixture $id', 'description', '$state',
  ${blockingDecisionId == null ? 'NULL' : "'${_q(blockingDecisionId)}'"},
  ${blockingReason == null ? 'NULL' : "'${_q(blockingReason)}'"},
  'qa-$id', '["snapshot-1"]', '${_q(metadata)}'::text,
  now(), now(), 1
);''';
}

/// A pending `engineering_review` decision claiming `changes_required`.
String _decisionSql({
  required String id,
  required String workItemId,
  required String executionId,
  String status = 'pending',
  String? choice,
  String? decider,
  String recommendation = 'CHANGES_REQUIRED',
}) {
  final metadata = jsonEncode({
    'engineeringReviewResult': {
      'reviewExecutionId': executionId,
      'workItemId': workItemId,
      'verdict': 'changes_required',
      'findings': <Object>[],
      'assessedDimensions': <Object>[],
      'createdAt': '2026-10-14T15:00:45.773090Z',
      'version': 1,
      'reviewerRole': 'ENGINEERING_REVIEWER',
    },
    'reviewExecutionId': executionId,
    'reviewVerdict': 'changes_required',
  });
  return '''
INSERT INTO "$_chainSchema"."human_decision" (
  "decisionId", "workItemId", "decisionType", "status", "question",
  "optionsJson", "recommendation", "blocking", "requestedAt", "updatedAt",
  "decider", "choice", "metadataJson"
) VALUES (
  '$id', '$workItemId', 'engineering_review', '$status',
  'Engineering review requires changes. Approve, reject, or request rework?',
  '[{"optionId":"approve"},{"optionId":"reject"},{"optionId":"rework"}]',
  '$recommendation', true, now(), now(),
  ${decider == null ? 'NULL' : "'${_q(decider)}'"},
  ${choice == null ? 'NULL' : "'${_q(choice)}'"},
  '${_q(metadata)}'::text
);''';
}

/// The reviewer execution plus, optionally, its result.
///
/// [summary] and [structured] are the two channels the repair reads. The QA
/// fabrication is `structuredResultJson = '{}'` with an empty summary and a
/// FAILED execution — "session never emitted a terminal event within the 300s
/// execution budget".
String _executionSql({
  required String executionId,
  required String workItemId,
  String status = 'failed',
  String? reason =
      'session never emitted a terminal event within the 300s '
      'execution budget',
  String? structured = '{}',
  String? summary,
}) {
  final buffer = StringBuffer()
    ..writeln('''
INSERT INTO "$_chainSchema"."agent_execution" (
  "executionId", "workItemId", "requestId", "runtimeTypeId", "role", "status",
  "workspaceJson", "reason", "startedAt", "completedAt", "version"
) VALUES (
  '$executionId', '$workItemId', 'req-$executionId', 'opencode', 'ENGINEERING_REVIEWER',
  '$status', '{}', ${reason == null ? 'NULL' : "'${_q(reason)}'"}, now(), now(), 1
);''');
  if (structured == null && summary == null) {
    // The reviewer reached a terminal state without writing ANY result row --
    // a shape the guard treats as repairable.
    return buffer.toString();
  }
  buffer.writeln('''
INSERT INTO "$_chainSchema"."agent_result" (
  "resultId", "sessionId", "workItemId", "status", "artifactsJson",
  "diagnosticsJson", "structuredResultJson", "executionId", "role", "summary",
  "completedAt"
) VALUES (
  'result-$executionId', 'ses-$executionId', '$workItemId', '$status', '[]', '[]',
  '${_q(structured ?? '{}')}'::text, '$executionId', 'ENGINEERING_REVIEWER',
  ${summary == null ? 'NULL' : "'${_q(summary)}'"}, now()
);''');
  return buffer.toString();
}

/// The terminal `engineering_review` job that stranded the item.
///
/// Its dedupe key is the UNSUFFIXED form, exactly as QA holds it, so it
/// consumes no attempt and contributes nothing to the job floor.
String _reviewJobSql({required String workItemId}) =>
    '''
INSERT INTO "$_chainSchema"."job" (
  "jobId", "workItemId", "jobType", "requiredRole",
  "requiredCapabilitiesJson", "priority", "state", "dedupeKey",
  "activeDedupeKey", "createdAt", "instruction", "attempt", "maxAttempts",
  "version"
) VALUES (
  'jb-$workItemId-review', '$workItemId', 'engineering_review',
  'ENGINEERING_REVIEWER', '["git"]', 'high', 'failed',
  '$workItemId:engineering_review', NULL, now(), 'review it', 1, 2, 1
);''';

/// A realistic reviewer summary for the `reviewerProseOnly` fixture.
String _realReviewSummary(String workItemId) =>
    '''
## Engineering Review — $workItemId

**Verdict: `APPROVE_WITH_NON_BLOCKING_FOLLOWUP`**
Reviewed revision: `e7959d0f3765bc45b94afc341921d29cf3172486`.

### What the fix does
A defect is triaged via a work item filed as `category: feature`, so the
Feature requests register leaked every defect alongside the Defects tab.

### Verification highlights
- The constant swap is value-preserving, so there is no reader drift.
- Exactly one defect-triage writer exists; it sets the key.
''';

/// The full live-QA-shaped fixture.
Future<void> _seedFixture(PersistenceDatabase db) async {
  final buffer = StringBuffer();
  for (final (decisionId, workItemId) in _targets) {
    final executionId = 'agx-$workItemId-review';
    buffer
      ..writeln(
        _workItemSql(
          id: workItemId,
          state: 'waiting_for_human_decision',
          blockingDecisionId: decisionId,
        ),
      )
      ..writeln(
        _decisionSql(
          id: decisionId,
          workItemId: workItemId,
          executionId: executionId,
        ),
      )
      // The fabrication: a FAILED execution with an empty payload and no summary.
      ..writeln(
        _executionSql(
          executionId: executionId,
          workItemId: workItemId,
        ),
      )
      ..writeln(_reviewJobSql(workItemId: workItemId));
  }

  // The reviewerProseOnly decision. Real reviewer work, absent from the
  // migration's list, and the reason the list is a list.
  buffer
    ..writeln(
      _workItemSql(
        id: _proseOnlyWorkItem,
        state: 'waiting_for_human_decision',
        blockingDecisionId: _proseOnlyId,
      ),
    )
    ..writeln(
      _decisionSql(
        id: _proseOnlyId,
        workItemId: _proseOnlyWorkItem,
        executionId: _proseOnlyExecution,
        status: 'pending',
      ),
    )
    ..writeln(
      _executionSql(
        executionId: _proseOnlyExecution,
        workItemId: _proseOnlyWorkItem,
        status: 'completed',
        reason: null,
        summary: _realReviewSummary(_proseOnlyWorkItem),
      ),
    );

  // The decision an operator has ALREADY approved. Absent from the list, and
  // its work item is at review_approved rather than parked.
  buffer
    ..writeln(
      _workItemSql(
        id: _approvedByHumanWorkItem,
        state: 'review_approved',
        blockingDecisionId: null,
        blockingReason: null,
      ),
    )
    ..writeln(
      _decisionSql(
        id: _approvedByHumanId,
        workItemId: _approvedByHumanWorkItem,
        executionId: 'agx-$_approvedByHumanWorkItem-review',
        status: 'resolved',
        choice: 'approve',
        decider: 'operator',
      ),
    )
    ..writeln(
      _executionSql(
        executionId: 'agx-$_approvedByHumanWorkItem-review',
        workItemId: _approvedByHumanWorkItem,
      ),
    );

  await db.db.unsafeSimpleExecute(buffer.toString());
}

Future<Map<String, Object?>> _row(
  PersistenceDatabase db,
  String table,
  String column,
  String id,
) async {
  final rows = await db.queryNoTransaction(
    'SELECT * FROM "$_chainSchema"."$table" WHERE "$column" = \'${_q(id)}\'',
  );
  if (rows.length != 1) {
    throw StateError(
      'expected exactly one $table row for $id, got ${rows.length}',
    );
  }
  return rows.single.toColumnMap();
}

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

Future<List<Map<String, Object?>>> _auditRows(PersistenceDatabase db) async {
  final rows = await db.queryNoTransaction(
    'SELECT "transitionId", "workItemId", "fromState", "toState", '
    '"idempotencyKey", "guardEvaluationsJson", "reason" '
    'FROM "$_chainSchema"."work_item_transition" '
    "WHERE \"transitionId\" LIKE 'tr-unreviewed-review-repair-%'",
  );
  return [for (final r in rows) r.toColumnMap()];
}

int? _markerOf(Map<String, Object?> row) {
  final raw = row['metadataJson'] as String?;
  if (raw == null || raw.isEmpty) return null;
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final value = decoded['triageAttempt'];
  return value is int ? value : null;
}

Map<String, dynamic> _metaOf(Map<String, Object?> row) =>
    jsonDecode(row['metadataJson']! as String) as Map<String, dynamic>;

void main() {
  withServerpod(
    'migration 20261014210000000 retires unreviewed engineering-review decisions',
    (sessionBuilder, endpoints) {
      late PersistenceDatabase db;
      late File repair;

      setUpAll(() async {
        db = await _newDb();
        repair = _repairMigration();
        // ignore: avoid_print
        print('unreviewed-review-repair under test: ${_versionOf(repair)}');
        await _resetChainSchema(db);
        await db.db.unsafeSimpleExecute(_chainScript());
      });

      tearDownAll(() async {
        await _dropChainSchema(db);
        await _closeSessions();
      });

      setUp(() => _resetData(db));

      test('it enumerates exactly the two decisions QA proved unreviewed', () {
        final sql = repair.readAsStringSync();
        final enumerated = RegExp(
          r"\('(dec-[a-z0-9-]+)', '(defect-DEF-\d+)', 'waiting_for_human_decision'\)",
        ).allMatches(sql).map((m) => '${m.group(1)}|${m.group(2)}').toSet();
        expect(
          enumerated,
          _targets.map((t) => '${t.$1}|${t.$2}').toSet(),
          reason:
              'the migration must enumerate exactly the dispatched set, with no '
              'additions and no omissions',
        );
        // The three the dispatch table named, and what happened to each. The
        // already-approved one is named in the banner -- it MUST be, because the
        // reason it is excluded is the most important thing in this file -- so
        // the assertion is that it is absent from the TARGET LIST specifically.
        // Asserting it is absent from the whole file would forbid the
        // migration from explaining itself, which is the opposite of what the
        // reviewer should want.
        final targetList = sql.substring(
          sql.indexOf('INSERT INTO "shipit_unreviewed_review_repair_target"'),
          sql.indexOf(
            '--\n-- FAIL LOUDLY',
            sql.indexOf('INSERT INTO "shipit_unreviewed_review_repair_target"'),
          ),
        );
        expect(
          targetList,
          isNot(contains(_approvedByHumanId)),
          reason:
              '$_approvedByHumanId was approved by an operator and its work item '
              'is at review_approved. Repairing it would overwrite a recorded '
              'human approval, which is worse than the defect being repaired.',
        );
        expect(
          sql,
          contains(_approvedByHumanId),
          reason:
              'and it must still be NAMED in the banner, because "we declined '
              'this and here is why" is only useful if the why is written down',
        );
        expect(
          targetList,
          isNot(contains(_proseOnlyId)),
          reason:
              'a prose-only decision must never be enumerated -- repairing it '
              'would destroy the only copy of a real review. Its exclusion '
              'belongs in the banner, where it is argued, not in the list that '
              'retires decisions.',
        );
        expect(
          sql,
          contains(_proseOnlyId),
          reason:
              'and the banner must NAME it, so "we declined this and here is '
              'why" is a written decision rather than a silent omission',
        );
      });

      test('it records the two reviewed-with-prose decisions as declined', () {
        final banner = repair.readAsStringSync();
        expect(
          banner,
          contains('agx-wx-jb-hn7gq1n2dc-1llxxyk'),
          reason:
              'the live execution id of a reviewer that DID real work is the '
              'evidence for declining it, and evidence decays if it is not '
              'written down where the next reader will find it',
        );
        expect(
          banner,
          contains('APPROVE_WITH_NON_BLOCKING_FOLLOWUP'),
          reason:
              'a reviewer wrote that verdict in prose while the decision it '
              'produced claimed changes_required. That contradiction is the '
              'whole reason the prose class exists.',
        );
      });

      test(
        '(a)(b)(c) it retires each decision without deleting it, and returns '
        'its item to a dispatchable review at an unheld key',
        () async {
          await _seedFixture(db);

          final decisionsBefore = <String, Map<String, Object?>>{
            for (final (decisionId, _) in _targets)
              decisionId: await _row(
                db,
                'human_decision',
                'decisionId',
                decisionId,
              ),
          };
          final itemsBefore = <String, Map<String, Object?>>{
            for (final (_, workItemId) in _targets)
              workItemId: await _row(db, 'work_item', 'workItemId', workItemId),
          };

          await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

          for (final (decisionId, workItemId) in _targets) {
            final decision = await _row(
              db,
              'human_decision',
              'decisionId',
              decisionId,
            );
            final item = await _row(db, 'work_item', 'workItemId', workItemId);

            // (a) RETIRED, NOT DELETED. The row is still here...
            expect(
              decision['status'],
              'cancelled',
              reason: '$decisionId must be retired so it can never be approved',
            );
            // ...and everything a human could read is byte-identical. The
            // fabricated question, its options and its recommendation are the
            // EVIDENCE of what was claimed.
            final before = decisionsBefore[decisionId]!;
            for (final column in [
              'question',
              'optionsJson',
              'recommendation',
              'contextJson',
              'blocking',
              'requestedAt',
              'decisionType',
              'workItemId',
            ]) {
              expect(
                decision[column],
                before[column],
                reason: '$decisionId.$column must survive the repair verbatim',
              );
            }
            // The columns that would FORGE a human answer are never written.
            for (final column in [
              'decider',
              'choice',
              'rationale',
              'resolvedOptionId',
            ]) {
              expect(
                decision[column],
                isNull,
                reason:
                    '$decisionId.$column must stay NULL. Writing a value here '
                    'would invent a human resolution the repair has no business '
                    'recording.',
              );
            }

            final meta = _metaOf(decision);
            expect(meta['reviewUnreviewable'], isTrue);
            expect(
              meta['reviewUnreviewableClaimedVerdict'],
              'changes_required',
              reason:
                  'the claimed verdict is kept as evidence and stored under a '
                  'key that NAMES it a claim, so it cannot later be mistaken '
                  'for a verdict somebody reached',
            );
            expect(
              meta['reviewUnreviewedExecutionId'],
              'agx-$workItemId-review',
            );

            // (b) THE WORK ITEM IS RETURNED, AND UNBLOCKED.
            expect(
              item['state'],
              'agent_completed',
              reason:
                  'agent_completed IS engineeringReviewDefinition.entryStates '
                  '(packages/scheduler/lib/src/scheduler.dart:2166), so the '
                  'ordinary tick dispatches the re-review',
            );
            expect(
              item['blockingHumanDecisionId'],
              isNull,
              reason:
                  'the blocking decision must be cleared or the item is still parked',
            );
            expect(item['blockingReason'], isNull);
            expect(
              item['version'],
              (itemsBefore[workItemId]!['version']! as int) + 1,
              reason:
                  'version must bump exactly once, exactly as a real transition '
                  'writes it, so the engine\'s compare-and-swap still behaves',
            );

            // (c) THE NEW KEY IS PROVABLY UNHELD.
            expect(
              _markerOf(item),
              _expectedAttempt,
              reason:
                  'the discriminator is greatest(marker=$_markerBefore, highest '
                  'attempt this item\'s own review job keys consumed=0) + 1. The '
                  'live review job holds the UNSUFFIXED key, which consumes no '
                  'attempt, so the floor is 0 and the result is $_expectedAttempt.',
            );
            expect(
              await _holders(
                db,
                workItemId,
                '$workItemId:engineering_review:a$_expectedAttempt',
              ),
              0,
              reason:
                  '$workItemId: the key the scheduler will now compute must have '
                  'zero holders, or enqueueIfAbsent returns created:false and '
                  'the item is dispatchable and inert -- the exact strand this '
                  'repair exists to end',
            );
            expect(
              await _holders(db, workItemId, '$workItemId:engineering_review'),
              1,
              reason:
                  'the terminal job that stranded the item is left exactly as it '
                  'was: no job row is touched by this migration',
            );
          }

          // The defect payload merges rather than being replaced.
          final merged = _metaOf(
            await _row(db, 'work_item', 'workItemId', _targets.first.$2),
          );
          expect(
            merged['defectTitle'],
            'unreviewed review repair fixture',
            reason:
                'the marker is merged with a jsonb ||, never written over the '
                'document; a replacement would make the re-run classify nothing '
                'while looking healthy',
          );
        },
      );

      test('it moves exactly the two enumerated targets and nothing else', () async {
        await _seedFixture(db);
        await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

        final audit = await _auditRows(db);
        expect(
          audit.map((r) => r['workItemId']).toSet(),
          _targets.map((t) => t.$2).toSet(),
        );
        expect(audit, hasLength(2));
        for (final row in audit) {
          expect(row['fromState'], 'waiting_for_human_decision');
          expect(row['toState'], 'agent_completed');
          expect(
            row['idempotencyKey'],
            'unreviewed-review-repair:no-real-reviewer-verdict',
          );
          // The restore payload. A rollback that recomputes instead of reading
          // this is the defect 20261014093000000's DOWN documents.
          final payload =
              jsonDecode(row['guardEvaluationsJson']! as String)
                  as Map<String, dynamic>;
          expect(payload['migration'], '20261014210000000');
          expect(payload['priorDecisionStatus'], 'pending');
          expect(payload['priorTriageAttempt'], _markerBefore);
          expect(payload['newTriageAttempt'], _expectedAttempt);
          expect(
            payload['priorDecisionMetadataJson'],
            isNotNull,
            reason:
                'the decision\'s own metadata is the before-image the rollback '
                'restores; without it the rollback can only merge, and cannot '
                'remove the keys this migration added',
          );
          // The audit row is permanent ledger text.
          final reason = row['reason']! as String;
          expect(reason, contains('NO TRANSITION EDGE WAS TAKEN'));
          expect(reason, contains('No verdict was invented'));
        }

        final bumped = await db.queryNoTransaction(
          'SELECT count(*)::int AS n FROM "$_chainSchema"."work_item" '
          'WHERE "version" <> 1',
        );
        expect(
          bumped.single.toColumnMap()['n'],
          2,
          reason:
              'exactly two rows may carry a version bump. A third means the '
              'selection reached an item it was not told about -- which is how '
              'a blanket sweep would have taken the real review below',
        );
      });

      test(
        '(e) it NEVER touches a decision whose reviewer wrote a real review in '
        'prose',
        () async {
          await _seedFixture(db);
          final decisionBefore = await _row(
            db,
            'human_decision',
            'decisionId',
            _proseOnlyId,
          );
          final itemBefore = await _row(
            db,
            'work_item',
            'workItemId',
            _proseOnlyWorkItem,
          );
          final resultBefore = await _row(
            db,
            'agent_result',
            'executionId',
            _proseOnlyExecution,
          );

          await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

          expect(
            await _row(db, 'human_decision', 'decisionId', _proseOnlyId),
            decisionBefore,
            reason:
                '$_proseOnlyExecution COMPLETED and wrote a real engineering '
                'review into its summary. Its decision\'s verdict claim is still '
                'fabricated, but a human assessment EXISTS and the operator has '
                'never seen it. Retiring the decision would destroy the only '
                'copy of that review.',
          );
          expect(
            await _row(db, 'work_item', 'workItemId', _proseOnlyWorkItem),
            itemBefore,
          );
          expect(
            await _row(db, 'agent_result', 'executionId', _proseOnlyExecution),
            resultBefore,
            reason: 'the reviewer\'s prose is evidence and must be untouched',
          );
        },
      );

      test('it never touches the decision an operator already approved', () async {
        await _seedFixture(db);
        final before = await _row(
          db,
          'human_decision',
          'decisionId',
          _approvedByHumanId,
        );

        await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

        expect(
          await _row(db, 'human_decision', 'decisionId', _approvedByHumanId),
          before,
          reason:
              'choice=approve by operator, item at review_approved. Overwriting '
              'a recorded human approval to replace one fabricated verdict with '
              'another is worse than the defect being repaired, and is a human '
              'decision rather than a data one',
        );
      });

      test(
        '(d) it REFUSES, changing nothing, when an enumerated target turns out '
        'to have real reviewer output',
        () async {
          await _seedFixture(db);
          final (_, proseWorkItem) = _targets.last;
          final proseDecision = _targets.last.$1;

          // Turn the SECOND enumerated target into the prose-only shape: its
          // reviewer now writes a real review. The enumeration was read off QA
          // at dispatch and has since gone stale.
          await db.db.unsafeSimpleExecute(
            'UPDATE "$_chainSchema"."agent_result" SET "summary" = '
            '\'${_q(_realReviewSummary(proseWorkItem))}\'::text '
            'WHERE "executionId" = \'agx-$proseWorkItem-review\'',
          );
          final itemsBefore = <String, Map<String, Object?>>{
            for (final (_, workItemId) in _targets)
              workItemId: await _row(db, 'work_item', 'workItemId', workItemId),
          };

          Object? failure;
          try {
            await db.db.unsafeSimpleExecute(_applyRepairScript(repair));
          } catch (error) {
            failure = error;
          }

          expect(failure, isNotNull, reason: 'the migration must abort');
          expect(
            failure.toString(),
            allOf(
              contains(proseDecision),
              contains('real review'),
              contains('Nothing was changed'),
            ),
            reason:
                'a loud failure that names neither the offending decision nor '
                'the all-or-nothing outcome is not one an operator can act on',
          );

          for (final (_, workItemId) in _targets) {
            expect(
              await _row(db, 'work_item', 'workItemId', workItemId),
              itemsBefore[workItemId],
              reason:
                  '$workItemId: the transaction rolled back, so no target '
                  'moved -- including the one that was perfectly repairable',
            );
          }
          expect(await _auditRows(db), isEmpty);
        },
      );

      test(
        'it REFUSES when an enumerated target carries a real machine verdict',
        () async {
          await _seedFixture(db);
          final (_, workItemId) = _targets.last;
          await db.db.unsafeSimpleExecute(
            'UPDATE "$_chainSchema"."agent_result" SET "structuredResultJson" = '
            '\'{"verdict":"approved"}\'::text '
            'WHERE "executionId" = \'agx-$workItemId-review\'',
          );

          Object? failure;
          try {
            await db.db.unsafeSimpleExecute(_applyRepairScript(repair));
          } catch (error) {
            failure = error;
          }
          expect(failure, isNotNull);
          expect(failure.toString(), contains('carries the verdict approved'));
          expect(await _auditRows(db), isEmpty);
        },
      );

      test(
        'it REFUSES when an enumerated target was already answered',
        () async {
          await _seedFixture(db);
          final (decisionId, _) = _targets.last;
          await db.db.unsafeSimpleExecute(
            'UPDATE "$_chainSchema"."human_decision" '
            "SET \"status\" = 'resolved', \"choice\" = 'approve', "
            "\"decider\" = 'operator' WHERE \"decisionId\" = '$decisionId'",
          );

          Object? failure;
          try {
            await db.db.unsafeSimpleExecute(_applyRepairScript(repair));
          } catch (error) {
            failure = error;
          }
          expect(failure, isNotNull);
          expect(failure.toString(), contains('already resolved by a human'));
          expect(await _auditRows(db), isEmpty);
        },
      );

      test('it REFUSES when a target\'s metadata cannot be merged', () async {
        await _seedFixture(db);
        final (decisionId, _) = _targets.first;
        // The EMPTY STRING: the one value in this repository that makes a bare
        // `::jsonb` cast raise.
        await db.db.unsafeSimpleExecute(
          'UPDATE "$_chainSchema"."human_decision" SET "metadataJson" = \'\' '
          "WHERE \"decisionId\" = '$decisionId'",
        );

        Object? failure;
        try {
          await db.db.unsafeSimpleExecute(_applyRepairScript(repair));
        } catch (error) {
          failure = error;
        }
        expect(failure, isNotNull);
        expect(failure.toString(), contains('not parseable JSON'));
        expect(await _auditRows(db), isEmpty);
      });

      test('(f) it is idempotent on re-run', () async {
        await _seedFixture(db);
        await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

        final itemsAfterFirst = <String, Map<String, Object?>>{
          for (final (_, workItemId) in _targets)
            workItemId: await _row(db, 'work_item', 'workItemId', workItemId),
        };
        final decisionsAfterFirst = <String, Map<String, Object?>>{
          for (final (decisionId, _) in _targets)
            decisionId: await _row(
              db,
              'human_decision',
              'decisionId',
              decisionId,
            ),
        };
        final auditAfterFirst = await _auditRows(db);

        await db.db.unsafeSimpleExecute(_applyRepairScript(repair));
        await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

        for (final (_, workItemId) in _targets) {
          expect(
            await _row(db, 'work_item', 'workItemId', workItemId),
            itemsAfterFirst[workItemId],
            reason:
                '$workItemId: a second application must write nothing. The '
                'arithmetic is greatest(marker, jobFloor) + 1, so an unguarded '
                'replay would advance the marker on every run and queue a new '
                'review each time.',
          );
        }
        for (final (decisionId, _) in _targets) {
          expect(
            await _row(db, 'human_decision', 'decisionId', decisionId),
            decisionsAfterFirst[decisionId],
          );
        }
        expect(
          await _auditRows(db),
          auditAfterFirst,
          reason:
              'a replay must write no second audit row. The ids are '
              'deterministic, so a forced replay collides on '
              'work_item_transition_id_unique rather than duplicating history',
        );
      });

      test(
        '(g) its DOWN restores every prior value, reading the before-image off '
        'the audit row rather than recomputing it',
        () async {
          await _seedFixture(db);

          // HONEST SCOPE. Neither enumerated target had an ABSENT marker at
          // dispatch, so the `absent` branch of the restore cannot be exercised
          // by replaying this migration: it would need a target whose marker
          // was missing, and fabricating one outside the enumeration would
          // assert against a set the migration does not act on. It is pinned as
          // text below instead, and the limit is stated rather than papered
          // over -- the same discipline 20261014093000000's DOWN uses where it
          // records what it cannot restore.
          final before = <String, Map<String, Object?>>{
            for (final (_, workItemId) in _targets)
              workItemId: await _row(db, 'work_item', 'workItemId', workItemId),
          };
          final decisionsBefore = <String, Map<String, Object?>>{
            for (final (decisionId, _) in _targets)
              decisionId: await _row(
                db,
                'human_decision',
                'decisionId',
                decisionId,
              ),
          };

          await db.db.unsafeSimpleExecute(_applyRepairScript(repair));
          await db.db.unsafeSimpleExecute(_downScript(repair));

          for (final (_, workItemId) in _targets) {
            final after = await _row(db, 'work_item', 'workItemId', workItemId);
            final original = before[workItemId]!;
            for (final column in [
              'state',
              'blockingHumanDecisionId',
              'blockingReason',
              'title',
              'qaContractId',
              'artifactRefsJson',
            ]) {
              expect(
                after[column],
                original[column],
                reason:
                    '$workItemId.$column must be restored byte-for-byte by the '
                    'rollback, read off this migration\'s own audit row rather '
                    'than recomputed',
              );
            }
            // `metadataJson` is restored SEMANTICALLY, not textually, and the
            // difference is inherent rather than a defect: the UP migration
            // writes it through `::jsonb`, and jsonb normalises on the way in
            // -- it reorders keys and adds a space after each colon. Once the
            // document has been through that, no rollback can return the exact
            // original bytes, because they no longer exist. What must be
            // restored is every key and every value, which is what a merge is
            // for and what the assertion below actually checks.
            //
            // Asserting textual identity here would be asserting a falsehood
            // about a correct rollback -- the same class of defect as the prior
            // art's DOWN, which documents at length that it does NOT restore
            // its marker and says so rather than hiding it.
            final restored =
                jsonDecode(after['metadataJson']! as String)
                    as Map<String, dynamic>;
            expect(
              restored,
              jsonDecode(original['metadataJson']! as String)
                  as Map<String, dynamic>,
              reason:
                  '$workItemId.metadataJson must be restored key for key and '
                  'value for value -- so no key is added or lost, and '
                  '`triageAttempt` is back where it was',
            );
          }
          for (final (decisionId, _) in _targets) {
            final after = await _row(
              db,
              'human_decision',
              'decisionId',
              decisionId,
            );
            final original = decisionsBefore[decisionId]!;
            expect(
              after['status'],
              original['status'],
              reason: '$decisionId must go back to pending',
            );
            expect(
              after['metadataJson'],
              original['metadataJson'],
              reason:
                  '$decisionId: the decision\'s prior metadata is restored as '
                  'the EXACT text it was, so the keys this migration added are '
                  'removed rather than merged over',
            );
          }
          expect(await _auditRows(db), isEmpty);

          // The absent-marker branch, pinned as text because no enumerated
          // target reaches it. Absent and 0 read DIFFERENTLY
          // (`readTriageAttempt` returns null for absent and 0 for a stored
          // zero; `engineeringReviewDedupeKey` then builds the BARE key for the
          // first and ':a0' for the second, and nothing ever mints ':a0'), so
          // the restore must REMOVE the key rather than set it to 0. A rollback
          // that wrote 0 would be subtly, permanently wrong.
          final down = repair.readAsStringSync();
          expect(
            down,
            contains("priorTriageAttemptForm' = 'absent'"),
            reason: 'the absent branch must be selected on the recorded form',
          );
          expect(
            down,
            contains("END) - 'triageAttempt'"),
            reason:
                'and it must REMOVE the marker key. Setting it to 0 would leave '
                'the item computing a discriminator no writer ever mints, which '
                'is exactly the untruthfulness the DOWN section of '
                '20261014093000000 documents in itself.',
          );
        },
      );

      test('it is a no-op against an empty schema', () async {
        // Literally what a brand-new database gets from it: the fresh-database
        // path builds from definition.sql and never replays this file.
        await db.db.unsafeSimpleExecute(_applyRepairScript(repair));
        expect(await _auditRows(db), isEmpty);
        final items = await db.queryNoTransaction(
          'SELECT count(*)::int AS n FROM "$_chainSchema"."work_item"',
        );
        expect(items.single.toColumnMap()['n'], 0);
      });
    },
  );
}
