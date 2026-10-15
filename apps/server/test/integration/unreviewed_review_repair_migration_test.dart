import 'dart:convert';
import 'dart:io';

import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:platform_contracts/src/enums/human_decision.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// The behaviour of migration `20261014210000000` — the repair that VOIDS every
/// fabricated engineering-review decision, without deleting them, and returns
/// their work items to a dispatchable review at a fresh key so the review is
/// genuinely re-run.
///
/// ## WHY THIS RUNS AGAINST REAL POSTGRESQL, IN A SCRATCH SCHEMA
///
/// Every property under test is a property of SQL. None of them can be
/// demonstrated by reading the file:
///
///   (a) it voids each decision WITHOUT deleting it, preserving the fabricated
///       question, options and recommendation verbatim as evidence;
///   (b) it moves ONLY the enumerated targets, to `agent_completed`, with the
///       blocking decision cleared;
///   (c) it advances `triageAttempt` to a review key nothing holds — the
///       property that makes the item dispatchable rather than inert;
///   (d) it VOIDS THE APPROVED ONE while PRESERVING the approval, so a human's
///       recorded act survives its own voiding;
///   (e) it voids the two decisions whose reviewers wrote real assessments, and
///       still leaves the assessments themselves untouched in `agent_result`;
///   (f) it REFUSES, changing nothing, when an enumerated target has moved since
///       the list was written — the drift guard;
///   (g) it is idempotent on re-run;
///   (h) its `down` restores the prior values EXACTLY, including an absent
///       `triageAttempt`.
///
/// (d), (f), (g) and (h) in particular are claims about what a SECOND or
/// REVERSED application writes, and no static check can make such a claim. So
/// the migration is applied — the real `migration.sql`, read off disk, not a
/// paraphrase of it — and, for (h), so is the real `down`.
///
/// ## WHY THE BOOTSTRAP PATH NEVER TOUCHES THIS MIGRATION — AND ONLY THAT
///
/// The integration suite builds its database through
/// `tool/schema_bootstrap.dart`, which hands Serverpod `--apply-migrations`; on
/// a fresh database Serverpod applies the LATEST `definition.sql` ALONE. This
/// migration's `migration.sql` is therefore never executed against `public` — a
/// data repair is a no-op on an empty schema, which is why the last test in this
/// file asserts exactly that. A DEPLOYED database is chain-migrated and replays
/// every `migration.sql`, and that path is the one under test, which is why it is
/// built here rather than assumed.
///
/// So THIS FILE is what says whether the migration works. It would be wrong to
/// put it more strongly than that, and an earlier version of this comment DID:
/// it said "Read a green integration run as saying nothing about whether this
/// migration works", which is FALSE. This test lives in `test/integration/` and
/// passes in the integration gate, so a green gate IS meaningful evidence here.
/// The gap is the BOOTSTRAP PATH specifically — what the gate does not do is run
/// `migration.sql` against `public` — not the gate. Narrowing the claim is the
/// whole correction; the test itself is unchanged and was not weakened.
///
/// The schema is scratch, never `public`. `test/integration` shares one
/// database with files that run concurrently; a chain replay builds a whole
/// schema from scratch and must not land in the schema everybody else reads.
/// Same rule, same reason and same shape as
/// `stranded_key_repair_migration_test.dart` and
/// `product_repoint_migration_test.dart`.
const _chainSchema = 'shipit_unreviewed_review_chain';

/// The `idempotencyKey` the migration writes. Read once, here, and compared
/// against the file by a test, so a rename cannot quietly desynchronise the
/// test from the migration it claims to exercise.
const _idempotencyKey = 'unreviewed-review-repair:void-fabricated-verdict';

/// The recorded human decision that scopes this migration.
///
/// Quoted, not paraphrased, because it is the ONLY thing that puts the two
/// prose-only decisions and the approved one in scope. Asserted against the
/// migration's own banner in `_scopeIsADecisionNotAProperty` so the citation
/// cannot rot into a vague attribution.
const _humanDecision = '8f1ed5bf-4147-449a-a221-558aac2303a9';

/// One enumerated target, exactly as live QA held it on 2026-10-15.
///
/// [executionId], [reviewCreatedAt] and [approvalSignature] are reproduced
/// verbatim because the migration PINS a digest over them: the drift guard
/// compares the live row's `md5(jsonb_build_object(...))` against a literal, so
/// a fixture that does not reproduce QA's bytes reproduces a DIFFERENT digest
/// and the migration refuses. That is the guard working, and
/// `(scope) every pinned digest is a real decision` asserts the two agree rather
/// than leaving it to be discovered as an unexplained failure.
class _Target {
  const _Target({
    required this.decisionId,
    required this.workItemId,
    required this.executionId,
    required this.reviewCreatedAt,
    required this.fromState,
    required this.blockingDecisionId,
    required this.status,
    required this.choice,
    required this.resolvedOptionId,
    required this.decider,
    required this.rationale,
    required this.approvalSignature,
    required this.resolvedAt,
    required this.markerBefore,
    required this.heldReviewKeys,
    required this.expectedAttempt,
    required this.reviewerWroteProse,
  });

  final String decisionId;
  final String workItemId;
  final String executionId;
  final String reviewCreatedAt;
  final String fromState;
  final String? blockingDecisionId;
  final String status;
  final String? choice;
  final String? resolvedOptionId;
  final String? decider;
  final String? rationale;
  final String? approvalSignature;
  final String? resolvedAt;

  /// `work_item.metadataJson.triageAttempt` as QA held it.
  final int markerBefore;

  /// The `engineering_review` job dedupe keys QA held for this item. The
  /// UNSUFFIXED form consumes no attempt; a suffixed one is the job floor.
  final List<String> heldReviewKeys;

  /// `greatest(marker, jobFloor) + 1`, as the migration's own arithmetic
  /// computes it. Pinned per target and asserted against this formula in
  /// `(scope) the fresh key arithmetic is what the migration claims`, so a
  /// literal cannot drift away from the rule it is an example of.
  final int expectedAttempt;

  /// The highest attempt encoded in [heldReviewKeys].
  int get jobFloor => heldReviewKeys
      .map((k) => RegExp(r':a(\d+)$').firstMatch(k)?.group(1))
      .whereType<String>()
      .map((s) => int.parse(s))
      .fold<int>(0, (a, b) => a > b ? a : b);

  /// Whether this reviewer's execution COMPLETED and wrote a real assessment
  /// into `agent_result.summary`.
  final bool reviewerWroteProse;
}

/// The five targets, read off live QA and re-verified read-only immediately
/// before this revision.
///
/// They are LIVE ids, not invented fixtures. The grouping is the migration's
/// own, because the grouping is what the operator's decision turned on:
///
///   * groups 1 and 2 — reviewer produced nothing, and reviewer produced a real
///     assessment the gate could not read. Both voided.
///   * group 3 — ALREADY APPROVED by an operator, item already at
///     `review_approved`. Voided too, by decision.
const _targets = <_Target>[
  _Target(
    decisionId: 'dec-hn7h7d9j8i-1oh8pgm',
    workItemId: 'defect-DEF-1791684557133597',
    executionId: 'agx-wx-jb-hn7gq1knzr-zmtj6i',
    reviewCreatedAt: '2026-10-14T15:00:45.773090Z',
    fromState: 'waiting_for_human_decision',
    blockingDecisionId: 'dec-hn7h7d9j8i-1oh8pgm',
    status: 'pending',
    choice: null,
    resolvedOptionId: null,
    decider: null,
    rationale: null,
    approvalSignature: '',
    resolvedAt: null,
    markerBefore: 2,
    heldReviewKeys: ['defect-DEF-1791684557133597:engineering_review'],
    expectedAttempt: 3,
    reviewerWroteProse: false,
  ),
  _Target(
    decisionId: 'dec-hn7h7db3w9-hdzu8c',
    workItemId: 'defect-DEF-1791685924503981',
    executionId: 'agx-wx-jb-hn7gq1om0m-1op4o60',
    reviewCreatedAt: '2026-10-14T15:13:10.337117Z',
    fromState: 'waiting_for_human_decision',
    blockingDecisionId: 'dec-hn7h7db3w9-hdzu8c',
    status: 'pending',
    choice: null,
    resolvedOptionId: null,
    decider: null,
    rationale: null,
    // QA holds an EMPTY STRING here, not NULL. `jsonb_build_object` renders
    // those two differently (`""` vs `null`), so the pinned digest separates
    // them and the fixture has to reproduce it exactly.
    approvalSignature: '',
    resolvedAt: null,
    markerBefore: 2,
    heldReviewKeys: ['defect-DEF-1791685924503981:engineering_review'],
    expectedAttempt: 3,
    reviewerWroteProse: false,
  ),
  _Target(
    decisionId: 'dec-hn7h7dagw5-l4o193',
    workItemId: 'defect-DEF-1791685024220546',
    executionId: 'agx-wx-jb-hn7gq1n2dc-1llxxyk',
    reviewCreatedAt: '2026-10-14T15:03:02.670431Z',
    fromState: 'waiting_for_human_decision',
    blockingDecisionId: 'dec-hn7h7dagw5-l4o193',
    status: 'pending',
    choice: null,
    resolvedOptionId: null,
    decider: null,
    rationale: null,
    // QA holds an EMPTY STRING here, not NULL. `jsonb_build_object` renders
    // those two differently (`""` vs `null`), so the pinned digest separates
    // them and the fixture has to reproduce it exactly.
    approvalSignature: '',
    resolvedAt: null,
    markerBefore: 2,
    heldReviewKeys: ['defect-DEF-1791685024220546:engineering_review'],
    expectedAttempt: 3,
    // "## Engineering Review" ... "Verdict: APPROVE_WITH_NON_BLOCKING_FOLLOWUP".
    reviewerWroteProse: true,
  ),
  _Target(
    decisionId: 'dec-hn7iw644nz-rmmpcn',
    workItemId: 'defect-DEF-1791686357139031',
    executionId: 'agx-wx-jb-hn7itcezii-1igc7vp',
    reviewCreatedAt: '2026-10-14T16:14:20.452278Z',
    fromState: 'waiting_for_human_decision',
    blockingDecisionId: 'dec-hn7iw644nz-rmmpcn',
    status: 'pending',
    choice: null,
    resolvedOptionId: null,
    decider: null,
    rationale: null,
    // QA holds an EMPTY STRING here, not NULL. `jsonb_build_object` renders
    // those two differently (`""` vs `null`), so the pinned digest separates
    // them and the fixture has to reproduce it exactly.
    approvalSignature: '',
    resolvedAt: null,
    // The ONE target whose marker alone is not enough: it already holds `:a3`,
    // so `marker + 1` would hand back a key a job holds and the re-review would
    // deduplicate against the attempt it is replacing.
    markerBefore: 3,
    heldReviewKeys: [
      'defect-DEF-1791686357139031:engineering_review',
      'defect-DEF-1791686357139031:engineering_review:a3',
    ],
    expectedAttempt: 4,
    reviewerWroteProse: true,
  ),
  _Target(
    decisionId: 'dec-hn7h7daum6-2atjhe',
    workItemId: 'defect-DEF-1791685264570406',
    executionId: 'agx-wx-jb-hn7gq1nj5w-70d6ix',
    reviewCreatedAt: '2026-10-14T15:08:06.213987Z',
    fromState: 'review_approved',
    blockingDecisionId: null,
    status: 'resolved',
    choice: 'approve',
    resolvedOptionId: 'approve',
    decider: 'operator',
    rationale: 'gotta get this rolling',
    approvalSignature:
        '{"algorithm":"ed25519","publicKey":"operator-pub-key",'
        '"signature":"operator-sig-1792005550089",'
        '"signedAt":"2026-10-14T19:19:10.089Z"}',
    resolvedAt: '2026-10-14 19:19:10.289486',
    markerBefore: 2,
    heldReviewKeys: ['defect-DEF-1791685264570406:engineering_review'],
    expectedAttempt: 3,
    reviewerWroteProse: false,
  ),
];

/// The target whose approval this migration voids, named rather than searched
/// for, so a test about it cannot silently start passing against a different
/// row.
final _approved = _targets.singleWhere(
  (t) => t.decisionId == 'dec-hn7h7daum6-2atjhe',
);

/// The two targets whose reviewers wrote real assessments.
final _prose = _targets.where((t) => t.reviewerWroteProse).toList();

/// A decision the migration must NEVER touch, and the control for "the
/// enumeration did not widen".
///
/// It is a genuine `engineering_review` decision: its reviewer produced a real
/// machine-readable verdict, so nothing about it is fabricated. It is not in the
/// enumerated list, and if the migration ever grew a predicate — the mistake the
/// manager's note explicitly warns the next reader about making — this is the
/// row that would be taken by it.
const _controlDecisionId = 'dec-control-unfabricated-0000001';
const _controlWorkItem = 'defect-DEF-0000000000000';

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
  required int marker,
}) {
  final metadata = jsonEncode({
    'defectId': 'DEF-${id.replaceFirst('defect-', '')}',
    'defectTitle': 'unreviewed review repair fixture',
    'defectDescription': 'a defect payload the re-run lane reads',
    'triageAttempt': marker,
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

/// An `engineering_review` decision in the EXACT shape QA holds.
///
/// The metadata is built from [executionId] and [reviewCreatedAt] in QA's key
/// order with `jsonEncode`, which reproduces QA's stored bytes exactly — and
/// those bytes are what the migration's pinned `md5` was computed over. A
/// fixture that reproduced the same SHAPE but different bytes would produce a
/// different digest and the drift guard would refuse, which is correct and is
/// what `(scope) every pinned digest is a real decision` checks for directly.
String _decisionSql(_Target target, {String executionIdOverride = ''}) {
  final executionId = executionIdOverride.isEmpty
      ? target.executionId
      : executionIdOverride;
  final metadata = jsonEncode({
    'engineeringReviewResult': {
      'reviewExecutionId': executionId,
      'workItemId': target.workItemId,
      'verdict': 'changes_required',
      'findings': <Object>[],
      'assessedDimensions': <Object>[],
      'createdAt': target.reviewCreatedAt,
      'version': 1,
      'reviewerRole': 'ENGINEERING_REVIEWER',
    },
    'reviewExecutionId': executionId,
    'reviewVerdict': 'changes_required',
  });
  String q(String? v) => v == null ? 'NULL' : "'${_q(v)}'";
  return '''
INSERT INTO "$_chainSchema"."human_decision" (
  "decisionId", "workItemId", "decisionType", "status", "question",
  "optionsJson", "recommendation", "blocking", "requestedAt", "updatedAt",
  "decider", "choice", "rationale", "signatureJson", "resolvedOptionId",
  "timestamp", "metadataJson"
) VALUES (
  '${target.decisionId}', '${target.workItemId}', 'engineering_review',
  '${target.status}',
  'Engineering review requires changes. Approve, reject, or request rework?',
  '[{"optionId":"approve"},{"optionId":"reject"},{"optionId":"rework"}]',
  'CHANGES_REQUIRED', true, now(), now(),
  ${q(target.decider)}, ${q(target.choice)}, ${q(target.rationale)},
  ${q(target.approvalSignature)}, ${q(target.resolvedOptionId)},
  ${target.resolvedAt == null ? 'NULL' : "'${target.resolvedAt}'::timestamp"},
  '${_q(metadata)}'::text
);''';
}

/// The reviewer execution plus, optionally, its result.
///
/// [summary] and [structured] are the two channels the defect appears in. The QA
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
    // The reviewer reached a terminal state without writing ANY result row.
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

/// The `engineering_review` jobs that hold this item's dedupe keys.
///
/// QA holds the UNSUFFIXED form on all five, and `:a3` additionally on the one
/// whose marker alone would collide with it.
String _reviewJobsSql(_Target target) {
  final buffer = StringBuffer();
  var n = 0;
  for (final key in target.heldReviewKeys) {
    // QA's five hold the UNSUFFIXED form, and the `:a3` job is on the one item
    // whose marker already reads 3 -- so the suffixed job is the one that
    // succeeded and the bare one that stranded the item.
    final consumedAttempt = RegExp(r':a(\d+)$').firstMatch(key);
    buffer.writeln('''
INSERT INTO "$_chainSchema"."job" (
  "jobId", "workItemId", "jobType", "requiredRole",
  "requiredCapabilitiesJson", "priority", "state", "dedupeKey",
  "activeDedupeKey", "createdAt", "instruction", "attempt", "maxAttempts",
  "version"
) VALUES (
  'jb-${target.workItemId}-review-${n++}', '${target.workItemId}',
  'engineering_review', 'ENGINEERING_REVIEWER', '["git"]', 'high',
  ${consumedAttempt == null ? "'failed'" : "'succeeded'"},
  '$key', NULL, now(), 'review it', ${int.tryParse(consumedAttempt?.group(1) ?? '1') ?? 1}, 2, 1
);''');
  }
  return buffer.toString();
}

/// A realistic reviewer summary, for the two reviewers that did real work.
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

/// The full live-QA-shaped fixture: all five targets, plus one control row the
/// migration has no business touching.
Future<void> _seedFixture(PersistenceDatabase db) async {
  final buffer = StringBuffer();
  for (final target in _targets) {
    buffer
      ..writeln(
        _workItemSql(
          id: target.workItemId,
          state: target.fromState,
          blockingDecisionId: target.blockingDecisionId,
          blockingReason: target.blockingDecisionId == null
              ? null
              : 'Engineering review requires changes. '
                    'Approve, reject, or request rework?',
          marker: target.markerBefore,
        ),
      )
      ..writeln(_decisionSql(target))
      ..writeln(
        _executionSql(
          executionId: target.executionId,
          workItemId: target.workItemId,
          status: target.reviewerWroteProse ? 'completed' : 'failed',
          // The QA fabrication: a FAILED reviewer with no reason but the
          // timeout. A COMPLETED reviewer has no failure to record.
          reason: target.reviewerWroteProse
              ? null
              : 'session never emitted a terminal event within the 300s '
                    'execution budget',
          summary: target.reviewerWroteProse
              ? _realReviewSummary(target.workItemId)
              : null,
        ),
      )
      ..writeln(_reviewJobsSql(target));
  }

  // THE CONTROL. A genuine engineering_review decision whose reviewer DID return
  // a machine-readable verdict, so nothing about it is fabricated. It is not in
  // the enumerated list. If this row moves, the enumeration widened.
  buffer
    ..writeln(
      _workItemSql(
        id: _controlWorkItem,
        state: 'waiting_for_human_decision',
        blockingDecisionId: _controlDecisionId,
        marker: 1,
      ),
    )
    ..writeln(
      _decisionSql(
        const _Target(
          decisionId: _controlDecisionId,
          workItemId: _controlWorkItem,
          executionId: 'agx-control-review',
          reviewCreatedAt: '2026-10-14T09:00:00.000000Z',
          fromState: 'waiting_for_human_decision',
          blockingDecisionId: _controlDecisionId,
          status: 'pending',
          choice: null,
          resolvedOptionId: null,
          decider: null,
          rationale: null,
          approvalSignature: '',
          resolvedAt: null,
          markerBefore: 1,
          heldReviewKeys: [],
          expectedAttempt: 0,
          reviewerWroteProse: false,
        ),
      ),
    )
    ..writeln(
      _executionSql(
        executionId: 'agx-control-review',
        workItemId: _controlWorkItem,
        status: 'completed',
        reason: null,
        structured: '{"verdict":"approved"}',
        summary: _realReviewSummary(_controlWorkItem),
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

/// The `md5` the migration pins, computed by the DATABASE rather than by Dart.
///
/// Deliberately the same SQL the migration uses, verbatim, so this test asserts
/// the pin matches the row instead of reimplementing a hash and agreeing with
/// itself. A copy in Dart would agree with a wrong migration too.
const _digestExpression = '''
  md5(jsonb_build_object(
        'status', d."status",
        'choice', d."choice",
        'resolvedOptionId', d."resolvedOptionId",
        'decider', d."decider",
        'rationale', d."rationale",
        'signatureJson', d."signatureJson",
        'timestamp', d."timestamp",
        'metadataJson', d."metadataJson")::text)
''';

Future<String> _digestOf(PersistenceDatabase db, String decisionId) async {
  final rows = await db.queryNoTransaction(
    'SELECT ${_digestExpression.trim()} AS digest '
    'FROM "$_chainSchema"."human_decision" d '
    'WHERE d."decisionId" = \'${_q(decisionId)}\'',
  );
  return rows.single.toColumnMap()['digest']! as String;
}

/// The migration's target INSERT, and nothing else.
///
/// Sliced out of the file rather than matched against the whole of it. The
/// banner names all five decisions, so a whole-file match would find ids that
/// are prose explaining the repair and conclude the list was wider than it is.
String _targetList(File migration) {
  final sql = migration.readAsStringSync();
  const head = 'INSERT INTO "shipit_unreviewed_review_repair_target"';
  final begin = sql.indexOf(head);
  final stop = sql.indexOf('--\n-- FAIL LOUDLY', begin);
  if (begin == -1 || stop == -1) {
    throw StateError(
      'cannot locate the target INSERT in ${migration.path}; a target list that '
      'cannot be found would make every scope assertion below vacuous',
    );
  }
  return sql.substring(begin, stop);
}

/// The `expectedDecisionDigest` the migration pins for [decisionId], parsed out
/// of the target INSERT rather than restated here — so there is one list.
String _pinnedDigest(String decisionId) {
  // `allMatches` is non-overlapping and each row's match ends at its own
  // digest, so scanning resumes inside the next row and every row is found.
  for (final m in RegExp(
    r"\('(dec-[a-z0-9-]+)', '(defect-DEF-\d+)',[\s\S]*?'([0-9a-f]{32})'",
  ).allMatches(_targetList(_repairMigration()))) {
    if (m.group(1) == decisionId) return m.group(3)!;
  }
  throw StateError(
    'no pinned digest found for $decisionId. The target INSERT must name the '
    'decision and its md5, and this test must fail rather than skip when it '
    'cannot find one.',
  );
}

void main() {
  withServerpod(
    'migration 20261014210000000 voids every fabricated engineering-review '
    'decision',
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

      // ---------------------------------------------------------------------
      // SCOPE. What this file touches is a DECISION, not a property of the
      // data, and the whole point of pinning the five ids is that a predicate
      // cannot widen on a later apply.
      // ---------------------------------------------------------------------

      test(
        '(scope) it enumerates exactly the five decisions the operator voided',
        () {
          final sql = repair.readAsStringSync();
          final targetList = _targetList(repair);
          final enumerated = RegExp(
            r"\('(dec-[a-z0-9-]+)', '(defect-DEF-\d+)'",
          ).allMatches(targetList).map((m) => m.group(1)!).toSet();
          expect(
            enumerated,
            _targets.map((t) => t.decisionId).toSet(),
            reason:
                'the migration must enumerate exactly the set the operator '
                'voided, with no additions and no omissions',
          );
          expect(enumerated, hasLength(5));
          // Every enumerated id also appears EXACTLY ONCE in the whole file.
          // A second mention of a decision id in a statement would be a second
          // definition of what this migration does to it, and the two would
          // eventually disagree.
          for (final id in enumerated) {
            final mentions = RegExp(id).allMatches(sql).length;
            expect(
              mentions,
              lessThanOrEqualTo(4),
              reason:
                  '$id is named $mentions times across the file. Naming it in '
                  'the banner and in its own audit `reason` text is expected; '
                  'naming it in a second statement is how a guard and the '
                  'statement it guards come to test different sets.',
            );
          }
          // The control is not in the file at all.
          expect(sql, isNot(contains(_controlDecisionId)));
        },
      );

      test(
        '(scope) the file SAYS the scope is a decision, not a property of the '
        'data, so the next reader does not narrow it back',
        () {
          final sql = repair.readAsStringSync();
          expect(
            sql,
            contains(
              'THE SCOPE OF THIS FILE IS A DECISION, NOT A PROPERTY OF THE DATA',
            ),
            reason:
                'the operator chose consistency over a narrower predicate, and '
                'the next reader to find two targets carrying real reviewer '
                'prose will read this file looking for a reason to narrow the '
                'list. The reason has to be written down, in the file, at the '
                'point where the narrowing looks obviously correct.',
          );
          expect(
            sql,
            contains(_humanDecision),
            reason:
                'the citation must name the recorded decision, so "we voided '
                'these because someone said so" is checkable rather than '
                'asserted',
          );
          expect(
            sql,
            contains('re-run the review from scratch'),
            reason:
                'the operator\'s resolution, quoted rather than paraphrased. The '
                'whole scope of the file rests on that sentence being what it is '
                'quoted as.',
          );
        },
      );

      test('(scope) every pinned digest is a real decision', () async {
        await _seedFixture(db);
        for (final target in _targets) {
          expect(
            await _digestOf(db, target.decisionId),
            _pinnedDigest(target.decisionId),
            reason:
                '${target.decisionId}: the migration pins an md5 over this '
                'decision\'s resolution columns and metadata, and the fixture '
                'does not reproduce the bytes that digest was taken over. Either '
                'the pin is stale or the fixture drifted from QA; both mean the '
                'drift guard would refuse a real database for the wrong reason.',
          );
        }
      });

      test(
        '(scope) the fresh key arithmetic is what the migration claims, and the '
        'marker is READ rather than assumed',
        () {
          for (final t in _targets) {
            expect(
              t.expectedAttempt,
              (t.markerBefore > t.jobFloor ? t.markerBefore : t.jobFloor) + 1,
              reason:
                  '${t.workItemId}: greatest(marker=${t.markerBefore}, '
                  'jobFloor=${t.jobFloor}) + 1',
            );
          }

          // THE FIFTH IS THE ONE THAT CATCHES A LAZY READER, and not for the
          // reason it first appears. Its marker is 3, not the 2 the other four
          // carry, and a live job already holds `:a3` -- so the key the
          // scheduler computes for it today is SPENT. A repair that read only
          // the bare dedupe key and copied `2` from its neighbours would hand
          // back `:a3` and recreate the exact strand this migration exists to
          // end, while looking completely correct.
          final spent = _targets.firstWhere(
            (t) => t.heldReviewKeys.any((k) => k.endsWith(':a3')),
          );
          expect(spent.markerBefore, 3);
          expect(
            spent.expectedAttempt,
            4,
            reason:
                'the new key must be one past the held `:a3`, not the held key '
                'itself',
          );

          // AND THE HONEST PART: the second watermark changes the answer for
          // NONE of these five, because marker >= floor everywhere. The job
          // floor guards a shape QA does not currently contain. A test that
          // asserted it was load-bearing HERE would be asserting a falsehood
          // about a correct migration -- the same class of defect as
          // `20261014093000000`'s DOWN, which documents at length what it does
          // NOT restore.
          for (final t in _targets) {
            expect(
              t.markerBefore >= t.jobFloor,
              isTrue,
              reason:
                  '${t.workItemId}: if any target\'s marker lagged its job '
                  'floor, the floor arm would be load-bearing after all and '
                  'this test would have to say so instead',
            );
          }
          expect(
            repair.readAsStringSync(),
            contains('changes the answer for NONE of these five'),
            reason:
                'a banner claiming its own guard does more work than it does is '
                'worse than no banner, because the next reader sizes their '
                'trust to the claim',
          );
        },
      );

      test(
        '(a)(b)(c) it voids each decision without deleting it, and returns '
        'its item to a dispatchable review at an unheld key',
        () async {
          await _seedFixture(db);

          final decisionsBefore = <String, Map<String, Object?>>{
            for (final t in _targets)
              t.decisionId: await _row(
                db,
                'human_decision',
                'decisionId',
                t.decisionId,
              ),
          };
          final itemsBefore = <String, Map<String, Object?>>{
            for (final t in _targets)
              t.workItemId: await _row(
                db,
                'work_item',
                'workItemId',
                t.workItemId,
              ),
          };

          await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

          for (final t in _targets) {
            final decision = await _row(
              db,
              'human_decision',
              'decisionId',
              t.decisionId,
            );
            final item = await _row(
              db,
              'work_item',
              'workItemId',
              t.workItemId,
            );

            // (a) VOIDED, NOT DELETED. The row is still here...
            expect(
              decision['status'],
              'cancelled',
              reason:
                  '${t.decisionId} must be voided so it can never be approved. '
                  '`cancelled` and not `resolved` is load-bearing: the only '
                  'guard that reads a decision requires `status.isResolved`.',
            );
            // ...and everything a human could read is byte-identical. The
            // fabricated question, its options and its recommendation are the
            // EVIDENCE of what was claimed.
            final before = decisionsBefore[t.decisionId]!;
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
                reason:
                    '${t.decisionId}.$column must survive the repair verbatim',
              );
            }
            // The columns that would FORGE a human answer are never written --
            // and for the approved target they are never written AWAY either.
            for (final column in [
              'decider',
              'choice',
              'rationale',
              'signatureJson',
              'resolvedOptionId',
              'timestamp',
            ]) {
              expect(
                decision[column],
                before[column],
                reason:
                    '${t.decisionId}.$column is NOT written by this migration. '
                    'Writing one would invent a human resolution the repair has '
                    'no business recording; CLEARING one would erase the record '
                    'that a human resolved this at all.',
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
            expect(meta['reviewUnreviewedExecutionId'], t.executionId);
            expect(meta['reviewUnreviewedByDecision'], _humanDecision);

            // (b) THE WORK ITEM IS RETURNED, AND UNBLOCKED.
            expect(
              item['state'],
              'agent_completed',
              reason:
                  'agent_completed IS engineeringReviewDefinition.entryStates, '
                  'so the ordinary tick dispatches the re-review. From '
                  '${t.fromState} -- including review_approved, which is the '
                  'state the voided approval had put it in.',
            );
            expect(
              item['blockingHumanDecisionId'],
              isNull,
              reason:
                  'the blocking decision must be cleared or the item is still '
                  'parked',
            );
            expect(item['blockingReason'], isNull);
            expect(
              item['version'],
              (itemsBefore[t.workItemId]!['version']! as int) + 1,
              reason:
                  'version must bump exactly once, exactly as a real transition '
                  'writes it, so the engine\'s compare-and-swap still behaves',
            );

            // (c) THE NEW KEY IS PROVABLY UNHELD.
            expect(
              _markerOf(item),
              t.expectedAttempt,
              reason:
                  'the discriminator is greatest(marker=${t.markerBefore}, '
                  'highest attempt this item\'s own review job keys consumed='
                  '${t.jobFloor}) + 1 = ${t.expectedAttempt}',
            );
            expect(
              await _holders(
                db,
                t.workItemId,
                '${t.workItemId}:engineering_review:a${t.expectedAttempt}',
              ),
              0,
              reason:
                  '${t.workItemId}: the key the scheduler will now compute must '
                  'have zero holders, or enqueueIfAbsent returns created:false '
                  'and the item is dispatchable and inert -- the exact strand '
                  'this repair exists to end',
            );
            for (final key in t.heldReviewKeys) {
              expect(
                await _holders(db, t.workItemId, key),
                1,
                reason:
                    '$key: the job that stranded the item is left exactly as '
                    'it was. No job row is touched by this migration.',
              );
            }
          }

          // The defect payload merges rather than being replaced.
          final merged = _metaOf(
            await _row(
              db,
              'work_item',
              'workItemId',
              _targets.first.workItemId,
            ),
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

      test(
        'it moves exactly the five enumerated targets and nothing else',
        () async {
          await _seedFixture(db);
          final controlBefore = await _row(
            db,
            'human_decision',
            'decisionId',
            _controlDecisionId,
          );
          final controlItemBefore = await _row(
            db,
            'work_item',
            'workItemId',
            _controlWorkItem,
          );

          await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

          final audit = await _auditRows(db);
          expect(
            audit.map((r) => r['workItemId']).toSet(),
            _targets.map((t) => t.workItemId).toSet(),
          );
          expect(audit, hasLength(5));
          for (final row in audit) {
            final t = _targets.firstWhere(
              (t) => t.workItemId == row['workItemId'],
            );
            expect(row['fromState'], t.fromState);
            expect(row['toState'], 'agent_completed');
            expect(row['idempotencyKey'], _idempotencyKey);

            final payload =
                jsonDecode(row['guardEvaluationsJson']! as String)
                    as Map<String, dynamic>;
            expect(payload['migration'], '20261014210000000');
            expect(payload['priorDecisionStatus'], t.status);
            expect(payload['priorTriageAttempt'], t.markerBefore);
            expect(payload['newTriageAttempt'], t.expectedAttempt);
            expect(
              payload['priorDecisionMetadataJson'],
              isNotNull,
              reason:
                  'the decision\'s own metadata is the before-image the '
                  'rollback restores; without it the rollback can only merge, '
                  'and cannot remove the keys this migration added',
            );
            // The approval, carried through the before-image. For the four
            // unresolved targets this is the ABSENCE of a resolution, which is
            // itself the thing a reader needs to see recorded.
            expect(payload['voidedHumanApproval'], t == _approved);
            expect(
              payload['priorDecisionChoice'],
              t == _approved ? _approved.choice : null,
              reason:
                  'priorDecisionChoice is the record of whether an approval '
                  'existed. For the four unresolved targets it must be absent, '
                  'not empty and not copied forward from somewhere',
            );
            expect(
              payload['priorDecisionDecider'],
              t == _approved ? _approved.decider : null,
            );
            expect(
              payload['priorDecisionRationale'],
              t == _approved ? _approved.rationale : null,
            );
            expect(
              payload['priorDecisionSignatureJson'],
              t == _approved ? _approved.approvalSignature : '',
              reason:
                  'the operator signature must survive into the before-image '
                  'verbatim. A re-serialised signature would not be evidence '
                  'of what was signed.',
            );
            expect(
              payload['priorDecisionTimestamp'],
              t == _approved ? '2026-10-14T19:19:10.289486' : null,
            );
            // The audit row is permanent ledger text.
            final reason = row['reason']! as String;
            expect(reason, contains('NO TRANSITION EDGE WAS TAKEN'));
            expect(reason, contains('No verdict was invented'));
            expect(reason, contains(_humanDecision));
            if (t == _approved) {
              expect(
                reason,
                contains('ALREADY BEEN APPROVED BY A HUMAN'),
                reason:
                    'the ledger row for the voided approval is the only place '
                    'an auditor reads that a human approval was undone. Saying '
                    'it in the row rather than only in a comment is the '
                    'difference between a recorded act and a buried one.',
              );
              expect(reason, contains('PRESERVED VERBATIM'));
            }
          }

          expect(
            await _row(db, 'human_decision', 'decisionId', _controlDecisionId),
            controlBefore,
            reason:
                'the control is a GENUINE engineering_review decision whose '
                'reviewer returned a real machine-readable verdict. It is not '
                'in the enumerated list, so it must be untouched. If this row '
                'ever moves, the migration grew a predicate.',
          );
          expect(
            await _row(db, 'work_item', 'workItemId', _controlWorkItem),
            controlItemBefore,
          );

          final bumped = await db.queryNoTransaction(
            'SELECT count(*)::int AS n FROM "$_chainSchema"."work_item" '
            'WHERE "version" <> 1',
          );
          expect(
            bumped.single.toColumnMap()['n'],
            5,
            reason:
                'exactly five rows may carry a version bump. A sixth means the '
                'selection reached an item it was not told about -- which is '
                'how a blanket sweep would take the control',
          );
        },
      );

      // ---------------------------------------------------------------------
      // THE APPROVED ONE. The case the manager called the hard one.
      // ---------------------------------------------------------------------

      test(
        '(d) it VOIDS the recorded human approval and PRESERVES it three ways',
        () async {
          await _seedFixture(db);
          final before = await _row(
            db,
            'human_decision',
            'decisionId',
            _approved.decisionId,
          );

          await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

          final after = await _row(
            db,
            'human_decision',
            'decisionId',
            _approved.decisionId,
          );
          final meta = _metaOf(after);

          // PRESERVED, WAY ONE: the columns are untouched. Voiding is not
          // erasing, and the mechanism is that nothing ever wrote them.
          expect(
            after['choice'],
            before['choice'],
            reason:
                'the operator\'s answer must still be in the row. A migration '
                'that cleared it would have erased the fact that a human '
                'resolved this, which is a different and much worse act.',
          );
          for (final column in const [
            'decider',
            'rationale',
            'signatureJson',
            'resolvedOptionId',
            'timestamp',
          ]) {
            expect(after[column], before[column], reason: column);
          }

          // PRESERVED, WAY TWO: copied into the metadata under a key that says
          // it is void. Emitted for every target, including the four with no
          // approval, so `? 'reviewUnreviewedApprovalVoided'` is a question
          // about this migration rather than about whichever row happened to be
          // resolved.
          expect(
            after['metadataJson'],
            contains('reviewUnreviewedApprovalVoided'),
          );
          final voided =
              meta['reviewUnreviewedApprovalVoided'] as Map<String, dynamic>;
          expect(voided['preservedChoice'], 'approve');
          expect(voided['preservedDecider'], 'operator');
          expect(voided['preservedRationale'], 'gotta get this rolling');
          expect(voided['preservedResolvedOptionId'], 'approve');
          expect(
            (voided['preservedSignature'] as Map<String, dynamic>)['algorithm'],
            'ed25519',
          );
          expect(voided['preservedTimestamp'], isNotNull);
          expect(voided['voidedUnderHumanDecision'], _humanDecision);
          expect(voided['why'], isNotEmpty);

          // PRESERVED, WAY THREE: in the audit row's before-image.
          final audit = (await _auditRows(db)).singleWhere(
            (r) => r['workItemId'] == _approved.workItemId,
          );
          final payload =
              jsonDecode(audit['guardEvaluationsJson']! as String)
                  as Map<String, dynamic>;
          expect(payload['voidedHumanApproval'], isTrue);
          expect(payload['priorDecisionChoice'], 'approve');
          expect(payload['priorDecisionDecider'], 'operator');
          expect(payload['priorDecisionRationale'], 'gotta get this rolling');
          expect(
            payload['priorDecisionSignatureJson'],
            _approved.approvalSignature,
          );
          expect(
            payload['priorDecisionTimestamp'],
            '2026-10-14T19:19:10.289486',
          );

          // AND THE VOID IS EXPLICIT, not merely the absence of an effect.
          expect(after['status'], 'cancelled');
          expect(meta['reviewUnreviewable'], isTrue);
        },
      );

      test(
        '(d) a voided approval CANNOT be read as a resolved decision by the '
        'code that decides whether an item may advance',
        () async {
          // The safety argument for voiding by STATUS rather than by clearing
          // the columns is that `cancelled` fails every reader that could turn
          // a preserved `choice` back into an approval. This asserts the
          // predicate those readers actually use, against the value the
          // migration actually writes, rather than restating the argument in a
          // comment.
          expect(
            HumanDecisionStatus.cancelled.isResolved,
            isFalse,
            reason:
                '`blockingHumanDecisionResolved` requires '
                '`decision.status.isResolved`. If a future enum change made '
                '`cancelled` resolved, the preserved `choice = approve` on the '
                'voided decision would start satisfying that guard again, and '
                'this migration would have left a live approval behind after '
                'promising it had removed one.',
          );
          expect(HumanDecisionStatus.resolved.isResolved, isTrue);

          await _seedFixture(db);
          await db.db.unsafeSimpleExecute(_applyRepairScript(repair));
          final after = await _row(
            db,
            'human_decision',
            'decisionId',
            _approved.decisionId,
          );
          expect(
            after['status'],
            HumanDecisionStatus.cancelled.wire,
            reason:
                'the status the SQL writes must be the enum member the guard '
                'reads. Asserting the wire value against the enum closes the '
                'gap between the two vocabularies.',
          );
          // The work item is unblocked, so the operator-UI reads that key off
          // `blockingHumanDecisionId` cannot reach it either.
          final item = await _row(
            db,
            'work_item',
            'workItemId',
            _approved.workItemId,
          );
          expect(item['blockingHumanDecisionId'], isNull);
          expect(item['state'], 'agent_completed');
        },
      );

      test(
        '(e) it voids the two decisions whose reviewers wrote real assessments, '
        'and still leaves the assessments untouched',
        () async {
          await _seedFixture(db);
          expect(_prose, hasLength(2));
          final resultsBefore = <String, Map<String, Object?>>{
            for (final t in _prose)
              t.executionId: await _row(
                db,
                'agent_result',
                'executionId',
                t.executionId,
              ),
          };

          await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

          for (final t in _prose) {
            final decision = await _row(
              db,
              'human_decision',
              'decisionId',
              t.decisionId,
            );
            final meta = _metaOf(decision);
            expect(
              decision['status'],
              'cancelled',
              reason:
                  '${t.executionId} COMPLETED and wrote a real engineering '
                  'review. Its decision\'s verdict claim is still fabricated, '
                  'and the operator was shown that and chose to re-run the '
                  'review from scratch rather than derive a claim from prose '
                  'the same corrupted run produced. So the decision is '
                  'voided.',
            );
            expect(
              meta['reviewUnreviewedProsePreservedAt'],
              '${t.executionId} (agent_result.summary, untouched)',
              reason:
                  'the migration must name WHERE the real review survives. '
                  'Voiding the decision makes the summary unreachable from the '
                  'decision, and a reader who is not told where it went will '
                  'assume it was thrown away.',
            );
            // The review itself is untouched: the migration writes no
            // agent_result row, so the only copy of the assessment is exactly
            // as the reviewer wrote it.
            expect(
              await _row(db, 'agent_result', 'executionId', t.executionId),
              resultsBefore[t.executionId],
              reason:
                  'the reviewer\'s prose is evidence and must be untouched, '
                  'even though the decision that misrepresented it is voided',
            );

            // AND THE LEDGER SAYS SO. The audit row is the permanent, human
            // readable record of what this migration did and why, and "we threw
            // away a review" is a sentence that has to be IN it. An earlier
            // revision computed this clause by asking the DECISION whether it
            // carried a marker -- the wrong source, and at a point in the
            // transaction where that marker has not been written yet, so the
            // clause could never fire and two discarded reviews silently
            // looked like the three ordinary voids.
            final audit = (await _auditRows(db)).singleWhere(
              (r) => r['workItemId'] == t.workItemId,
            );
            expect(
              audit['reason'],
              allOf(
                contains('THE REVIEWER DID WRITE A REAL ASSESSMENT'),
                contains(t.executionId),
                contains('and it is voided anyway'),
              ),
              reason:
                  'the review being discarded has to be named in the row that '
                  'discards it. A reader auditing this migration in a year finds '
                  'this row, not the banner',
            );
          }

          // AND THE OTHER THREE DO NOT CARRY THE SENTENCE. The clause is
          // computed from the reviewer's own result, so a target whose reviewer
          // wrote nothing cannot receive it by accident.
          for (final t in _targets.where((t) => !t.reviewerWroteProse)) {
            final audit = (await _auditRows(db)).singleWhere(
              (r) => r['workItemId'] == t.workItemId,
            );
            expect(
              audit['reason'],
              isNot(contains('THE REVIEWER DID WRITE A REAL ASSESSMENT')),
              reason:
                  '${t.workItemId}: no reviewer wrote prose for this one, and a '
                  'ledger claiming otherwise is worse than one saying nothing',
            );
          }
        },
      );

      // ---------------------------------------------------------------------
      // THE DRIFT GUARD. Load-bearing, not belt-and-braces.
      // ---------------------------------------------------------------------

      Future<String?> applyAndCatch() async {
        try {
          await db.db.unsafeSimpleExecute(_applyRepairScript(repair));
          return null;
        } catch (error) {
          return error.toString();
        }
      }

      test(
        '(f) it REFUSES, naming the decision, when the APPROVED decision has '
        'moved -- and changes nothing at all',
        () async {
          await _seedFixture(db);
          // A DIFFERENT human act from the one the operator reasoned about: the
          // approval was re-signed. Voiding that off a stale row would destroy
          // an approval nobody authorised destroying, which is exactly the
          // failure mode the guard exists to prevent.
          await db.db.unsafeSimpleExecute(
            'UPDATE "$_chainSchema"."human_decision" SET "signatureJson" = '
            '\'{"algorithm":"ed25519","signature":"a-later-signature"}\'::text '
            'WHERE "decisionId" = \'${_approved.decisionId}\'',
          );
          final itemsBefore = <String, Map<String, Object?>>{
            for (final t in _targets)
              t.workItemId: await _row(
                db,
                'work_item',
                'workItemId',
                t.workItemId,
              ),
          };
          final decisionsBefore = <String, Map<String, Object?>>{
            for (final t in _targets)
              t.decisionId: await _row(
                db,
                'human_decision',
                'decisionId',
                t.decisionId,
              ),
          };

          final failure = await applyAndCatch();

          expect(failure, isNotNull, reason: 'the migration must abort');
          expect(
            failure,
            allOf(
              contains(_approved.decisionId),
              contains('the decision itself moved'),
              contains('VOIDED HUMAN APPROVAL'),
              contains('Nothing was changed'),
            ),
            reason:
                'a refusal that does not name WHICH decision moved, and does '
                'not flag that it is an approval, is not one an operator can '
                'act on before they deploy',
          );

          for (final t in _targets) {
            expect(
              await _row(db, 'work_item', 'workItemId', t.workItemId),
              itemsBefore[t.workItemId],
              reason:
                  '${t.workItemId}: the transaction rolled back, so no target '
                  'moved -- including the four that were perfectly repairable. '
                  'A partial repair is invisible and leaves a mix of repaired '
                  'and unrepaired items with nothing distinguishing them.',
            );
            expect(
              await _row(db, 'human_decision', 'decisionId', t.decisionId),
              decisionsBefore[t.decisionId],
              reason:
                  '${t.decisionId}: not even the four that were perfectly '
                  'repairable may be voided by a run that refuses. Voiding four '
                  'of five and reporting the fifth as "moved" is the worst '
                  'outcome available: the operator is told the repair ran, and '
                  'four items are now queued for a re-review the ledger does '
                  'not fully describe.',
            );
          }
          expect(await _auditRows(db), isEmpty);
        },
      );

      test(
        '(f) it REFUSES when an approved decision is re-resolved to a '
        'different choice',
        () async {
          await _seedFixture(db);
          await db.db.unsafeSimpleExecute(
            'UPDATE "$_chainSchema"."human_decision" '
            "SET \"choice\" = 'reject' WHERE "
            '"decisionId" = \'${_approved.decisionId}\'',
          );
          final failure = await applyAndCatch();
          expect(failure, isNotNull);
          expect(failure, contains(_approved.decisionId));
          expect(failure, contains('choice reject'));
          expect(await _auditRows(db), isEmpty);
        },
      );

      test(
        '(f) it REFUSES when an enumerated work item has moved since the list '
        'was written',
        () async {
          await _seedFixture(db);
          final t = _targets.first;
          await db.db.unsafeSimpleExecute(
            'UPDATE "$_chainSchema"."work_item" '
            "SET \"state\" = 'implementation_ready', "
            '"blockingHumanDecisionId" = NULL '
            'WHERE "workItemId" = \'${t.workItemId}\'',
          );
          final failure = await applyAndCatch();
          expect(failure, isNotNull);
          expect(
            failure,
            allOf(
              contains(t.decisionId),
              contains('work item'),
              contains('moved'),
            ),
          );
          expect(await _auditRows(db), isEmpty);
        },
      );

      test(
        '(f) it REFUSES when an enumerated decision has moved -- even if its '
        'work item has not',
        () async {
          await _seedFixture(db);
          // The subtle one: a re-pointed review that never became a resolution.
          // Status is unchanged, so an arm that tested only `status` would pass
          // it and void a decision that is now about a different reviewer.
          final t = _targets.first;
          await db.db.unsafeSimpleExecute(
            'UPDATE "$_chainSchema"."human_decision" SET "metadataJson" = '
            '\'{"reviewVerdict":"approved"}\'::text '
            'WHERE "decisionId" = \'${t.decisionId}\'',
          );
          final failure = await applyAndCatch();
          expect(failure, isNotNull);
          expect(
            failure,
            allOf(
              contains(t.decisionId),
              contains('metadata changed'),
            ),
            reason:
                'the digest exists to catch a decision whose CLAIM was '
                'rewritten while its status stayed `pending`, which is exactly '
                'the shape a guard testing only `status` would wave through',
          );
          expect(await _auditRows(db), isEmpty);
        },
      );

      test(
        '(f) it REFUSES when a decision has lost its work item',
        () async {
          await _seedFixture(db);
          final t = _targets.first;
          // A live decision whose work item is gone. Nothing in this codebase
          // deletes either row, so that shape means something OUTSIDE this
          // migration touched it, and re-deciding what to do about the orphaned
          // question from here would be guessing.
          await db.db.unsafeSimpleExecute(
            'DELETE FROM "$_chainSchema"."work_item" '
            'WHERE "workItemId" = \'${t.workItemId}\'',
          );
          final failure = await applyAndCatch();
          expect(failure, isNotNull);
          expect(
            failure,
            allOf(
              contains(t.decisionId),
              contains('work item is gone'),
              contains('one half of the pair is gone'),
              contains('Nothing was changed'),
            ),
          );
          expect(await _auditRows(db), isEmpty);
        },
      );

      test(
        '(f) it SKIPS a target with no decision to void — which is the shape '
        "this repository's own chain replays produce",
        () async {
          // The three sibling chain-replay harnesses seed the twelve work items
          // that `20261014130500000` repoints and seed NO `human_decision` rows,
          // so during a full chain replay all five of this migration's work
          // items exist and none of its decisions do. Refusing there aborts
          // three unrelated tests over rows that were never there.
          await _seedFixture(db);
          await db.db.unsafeSimpleExecute(
            'DELETE FROM "$_chainSchema"."human_decision"',
          );

          expect(
            await applyAndCatch(),
            isNull,
            reason:
                'with no decision there is nothing to void. A work item sitting '
                'at waiting_for_human_decision with no decision is a different '
                'defect, one the operator was not asked about.',
          );
          expect(
            await _auditRows(db),
            isEmpty,
            reason:
                'and the five work items are left exactly where they were, '
                'because this migration does not own them',
          );
        },
      );

      test(
        '(f) it is a silent no-op against an empty schema',
        () async {
          // A staging environment, or a chain replay built from `migration.sql`
          // on an empty schema. Five absent targets are five databases this
          // migration has no business in, and saying so for all five at once
          // is the correct answer for all five.
          await db.db.unsafeSimpleExecute(
            'TRUNCATE "$_chainSchema"."work_item", "$_chainSchema"."human_decision"',
          );

          expect(await applyAndCatch(), isNull);
          expect(await _auditRows(db), isEmpty);
        },
      );

      test(
        'it REFUSES when a target\'s metadata cannot be merged',
        () async {
          await _seedFixture(db);
          final t = _targets.first;
          // The EMPTY STRING: the one value in this repository that makes a
          // bare `::jsonb` cast raise.
          await db.db.unsafeSimpleExecute(
            'UPDATE "$_chainSchema"."human_decision" SET "metadataJson" = \'\' '
            'WHERE "decisionId" = \'${t.decisionId}\'',
          );
          final failure = await applyAndCatch();
          expect(failure, isNotNull);
          expect(failure, contains('not parseable JSON'));
          expect(await _auditRows(db), isEmpty);
        },
      );

      test('(g) it is idempotent on re-run', () async {
        await _seedFixture(db);
        await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

        final itemsAfterFirst = <String, Map<String, Object?>>{
          for (final t in _targets)
            t.workItemId: await _row(
              db,
              'work_item',
              'workItemId',
              t.workItemId,
            ),
        };
        final decisionsAfterFirst = <String, Map<String, Object?>>{
          for (final t in _targets)
            t.decisionId: await _row(
              db,
              'human_decision',
              'decisionId',
              t.decisionId,
            ),
        };
        final auditAfterFirst = await _auditRows(db);

        await db.db.unsafeSimpleExecute(_applyRepairScript(repair));
        await db.db.unsafeSimpleExecute(_applyRepairScript(repair));

        for (final t in _targets) {
          expect(
            await _row(db, 'work_item', 'workItemId', t.workItemId),
            itemsAfterFirst[t.workItemId],
            reason:
                '${t.workItemId}: a second application must write nothing. The '
                'arithmetic is greatest(marker, jobFloor) + 1, so an unguarded '
                'replay would advance the marker on every run and queue a new '
                'review each time.',
          );
        }
        for (final t in _targets) {
          expect(
            await _row(db, 'human_decision', 'decisionId', t.decisionId),
            decisionsAfterFirst[t.decisionId],
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
        '(g) it is idempotent even after the items have MOVED ON, because the '
        'already-applied arm is checked before the pins',
        () async {
          // The forced-replay shape a deploy actually produces: the migration
          // ran, the scheduler then did its work, and the migration file is
          // re-applied. Every pin is now stale -- and none of that is drift.
          await _seedFixture(db);
          await db.db.unsafeSimpleExecute(_applyRepairScript(repair));
          await db.db.unsafeSimpleExecute(
            'UPDATE "$_chainSchema"."work_item" SET "state" = '
            '\'review_in_progress\', "version" = "version" + 4 '
            'WHERE "workItemId" IN '
            '(${_targets.map((t) => '\'${t.workItemId}\'').join(', ')})',
          );

          expect(
            await applyAndCatch(),
            isNull,
            reason:
                'a replay against items the scheduler has since moved on must '
                'be a silent no-op. If it refused, every re-apply of this file '
                'would fail on any database where the repair has done its job',
          );
          expect(await _auditRows(db), hasLength(5));
        },
      );

      test(
        '(h) its DOWN restores every prior value, reading the before-image off '
        'the audit row rather than recomputing it',
        () async {
          await _seedFixture(db);

          // HONEST SCOPE. No enumerated target had an ABSENT marker at
          // dispatch, so the `absent` branch of the restore cannot be exercised
          // by replaying this migration: it would need a target whose marker
          // was missing, and fabricating one outside the enumeration would
          // assert against a set the migration does not act on. It is pinned as
          // text below instead, and the limit is stated rather than papered
          // over -- the same discipline 20261014093000000's DOWN uses where it
          // records what it cannot restore.
          final before = <String, Map<String, Object?>>{
            for (final t in _targets)
              t.workItemId: await _row(
                db,
                'work_item',
                'workItemId',
                t.workItemId,
              ),
          };
          final decisionsBefore = <String, Map<String, Object?>>{
            for (final t in _targets)
              t.decisionId: await _row(
                db,
                'human_decision',
                'decisionId',
                t.decisionId,
              ),
          };

          await db.db.unsafeSimpleExecute(_applyRepairScript(repair));
          await db.db.unsafeSimpleExecute(_downScript(repair));

          for (final t in _targets) {
            final after = await _row(
              db,
              'work_item',
              'workItemId',
              t.workItemId,
            );
            final original = before[t.workItemId]!;
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
                    '${t.workItemId}.$column must be restored byte-for-byte by '
                    'the rollback, read off this migration\'s own audit row '
                    'rather than recomputed',
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
                  '${t.workItemId}.metadataJson must be restored key for key '
                  'and value for value -- so no key is added or lost, and '
                  '`triageAttempt` is back where it was',
            );
          }
          for (final t in _targets) {
            final after = await _row(
              db,
              'human_decision',
              'decisionId',
              t.decisionId,
            );
            final original = decisionsBefore[t.decisionId]!;
            expect(
              after['status'],
              original['status'],
              reason:
                  '${t.decisionId} must go back to ${t.status}. For the '
                  'approved one that means `resolved` again -- a rollback that '
                  'left it cancelled would have erased the approval rather '
                  'than undone the void.',
            );
            expect(
              after['metadataJson'],
              original['metadataJson'],
              reason:
                  '${t.decisionId}: the decision\'s prior metadata is restored '
                  'as the EXACT text it was, so the keys this migration added '
                  'are removed rather than merged over',
            );
            // The approval was never written, so the rollback must not write it
            // either -- and must not have needed to.
            for (final column in const [
              'decider',
              'choice',
              'rationale',
              'signatureJson',
              'resolvedOptionId',
              'timestamp',
            ]) {
              expect(after[column], original[column], reason: column);
            }
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
        // path builds from definition.sql and never replays this file. This is
        // also why a green `make test-integration` says nothing about this
        // migration -- see the banner.
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
