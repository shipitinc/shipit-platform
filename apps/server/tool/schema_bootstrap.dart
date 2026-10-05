// Applies and verifies the hand-maintained schema bootstrap.
//
//   dart run tool/schema_bootstrap.dart            apply + verify (normal path)
//   dart run tool/schema_bootstrap.dart --verify   verify only, apply nothing
//
// WHY THIS TOOL EXISTS. Serverpod applies exactly one artifact to a database
// with no recorded migration version: the LATEST `definition.sql`
// (serverpod-3.4.13/lib/src/database/migrations/migration_manager.dart
// `_loadMigrationSQL`, lines 194-205). A chain-migrated database replays
// `migration.sql` instead and therefore receives every hand-written object ever
// placed in one. Anything the model-driven generator cannot render — the
// design-revision immutability trigger, the design-review independence trigger,
// the partial unique index enforcing one approved revision per work item —
// exists only in `migrations/20260920232118956/migration.sql`, so it is absent
// from every fresh database, CI included.
//
// It cannot be fixed by editing a generated `definition.sql`: the generator
// rewrites that file verbatim from the Dart models on every
// `serverpod create-migration`
// (serverpod_cli-3.4.13/lib/src/migrations/generator.dart:543-581). So the SQL
// lives in `tool/schema_bootstrap.sql`, outside `migrations/`, where
// regeneration cannot reach it, and this tool applies it after Serverpod's own
// migration step.
//
// FAIL LOUDLY. Applying is not success. This tool then asserts, in the live
// database, that every object in `_requiredObjects` exists AND that the three
// mutations the schema exists to prevent are each rejected by the database. A
// bootstrap that did not take effect exits 1, so a caller cannot mistake it for
// a clean run.
//
// The probes run inside a transaction that is always rolled back, so they
// leave no rows behind and cannot interfere with a test suite sharing the
// database.
//
// WIRING (both required; a missing site is the drift this guards against):
//   * CI    — `.github/workflows/integration.yaml`, step "Apply schema
//              bootstrap", immediately before "Run server integration tests".
//   * local — `make test-integration` in the repository Makefile.
//
// Both must run AFTER Serverpod's own migration step. That is why this tool
// passes `--apply-migrations` to Serverpod itself rather than assuming the
// schema already exists: on a fresh database that call is what creates it from
// the latest `definition.sql` — the same artifact the test harness would have
// used — so the bootstrap never runs against a half-built schema.

import 'dart:io';

import 'package:control_plane_server/src/generated/endpoints.dart';
import 'package:control_plane_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

/// Path of the hand-maintained SQL asset, relative to `apps/server`.
const _bootstrapSqlPath = 'tool/schema_bootstrap.sql';

/// Objects that must exist in the database once the bootstrap has been applied.
///
/// Each entry is `(kind, name)` with kind one of `index`, `trigger`, `function`.
/// The applier asserts every one of them is present, so a future edit to
/// `schema_bootstrap.sql` that silently fails to take effect — a typo in a
/// name, a `CREATE` Postgres accepted as a no-op, an object attached to the
/// wrong table — fails the run instead of passing quietly.
const _requiredObjects = <(String, String)>[
  ('function', 'enforce_design_revision_immutability'),
  ('trigger', 'trigger_design_revision_immutability'),
  ('function', 'enforce_design_review_independence'),
  ('trigger', 'trigger_design_review_independence'),
  ('index', 'design_revision_approved_unique_per_work_item'),
];

/// Raised when the bootstrap could not be applied or did not take effect.
class BootstrapFailure implements Exception {
  /// Human-readable explanation.
  final String message;

  /// Creates a [BootstrapFailure].
  BootstrapFailure(this.message);

  @override
  String toString() => message;
}

Future<void> main(List<String> argv) async {
  var status = 0;
  try {
    await _run(argv.contains('--verify'));
  } on BootstrapFailure catch (failure) {
    stderr.writeln('SCHEMA BOOTSTRAP FAILED');
    stderr.writeln(failure.message);
    status = 1;
  }

  // `pod.shutdown` leaves timers behind, so without this the process prints
  // its verdict and then hangs until the CI job's timeout — a bootstrap that
  // reported failure would still burn the whole budget.
  exit(status);
}

Future<void> _run(bool verifyOnly) async {
  final sql = File(_bootstrapSqlPath);
  if (!sql.existsSync()) {
    throw BootstrapFailure(
      'schema bootstrap asset not found at $_bootstrapSqlPath.\n'
      'It must be run from apps/server: `dart run tool/schema_bootstrap.dart`.',
    );
  }

  // `-m test` reads apps/server/config/test.yaml, the configuration the
  // integration suites use. That keeps the bootstrap pointed at whatever
  // SERVERPOD_DATABASE_* overrides the caller set, so one command works in CI
  // and locally without editing a committed config file.
  final pod = Serverpod(
    ['-m', 'test', if (!verifyOnly) '--apply-migrations'],
    Protocol(),
    Endpoints(),
  );

  await pod.start();

  try {
    final session = await Serverpod.instance.createSession(
      enableLogging: false,
    );

    if (verifyOnly) {
      stdout.writeln('Verify only: not applying $_bootstrapSqlPath.');
    } else {
      stdout.writeln('Applying $_bootstrapSqlPath ...');
      try {
        await session.db.unsafeSimpleExecute(sql.readAsStringSync());
      } catch (error, stackTrace) {
        throw BootstrapFailure(
          'Failed to apply $_bootstrapSqlPath: $error\n'
          'The asset must stay idempotent (IF NOT EXISTS / CREATE OR REPLACE) '
          'and must run against an already-migrated schema, because Serverpod '
          'only applies the latest definition.sql to a fresh database.\n'
          '$stackTrace',
        );
      }
      stdout.writeln('Applied.');
    }

    await _verifyObjectsExist(session);
    await _verifyEnforcement(session);
  } finally {
    await pod.shutdown(exitProcess: false);
  }

  stdout.writeln(
    'Schema bootstrap OK: ${_requiredObjects.length} objects present, '
    '3 enforcement probes rejected as required.',
  );
}

/// Asserts every object in `_requiredObjects` exists in the live database.
Future<void> _verifyObjectsExist(Session session) async {
  final missing = <String>[];

  for (final (kind, name) in _requiredObjects) {
    final found = switch (kind) {
      'trigger' => await _count(
        session,
        'SELECT count(*)::int AS n FROM pg_trigger WHERE NOT tgisinternal '
        "AND tgname = '$name'",
      ),
      'index' => await _count(
        session,
        "SELECT count(*)::int AS n FROM pg_class c "
        'JOIN pg_namespace ns ON ns.oid = c.relnamespace '
        "WHERE c.relkind = 'i' AND c.relname = '$name'",
      ),
      'function' => await _count(
        session,
        'SELECT count(*)::int AS n FROM pg_proc p '
        'JOIN pg_namespace ns ON ns.oid = p.pronamespace '
        "WHERE p.proname = '$name'",
      ),
      _ => throw BootstrapFailure('unknown object kind "$kind"'),
    };

    if (found == 0) {
      missing.add('$kind $name');
    } else {
      stdout.writeln('  present: $kind $name');
    }
  }

  if (missing.isNotEmpty) {
    throw BootstrapFailure(
      'schema bootstrap did not take effect. Missing from the database:\n'
      '  ${missing.join('\n  ')}\n'
      'Either $_bootstrapSqlPath was truncated, or Serverpod\'s migration step '
      'did not create the tables these objects attach to. A failed migration is '
      'not fatal outside development run mode (serverpod-3.4.13 serverpod.dart '
      '`_applyMigrations` only throws ExitException when runMode == '
      'development), so this check is the only thing between a green run and an '
      'unenforced schema.',
    );
  }
}

/// Prefix on every row the probes create, so cleanup can find them without
/// touching anything a test suite owns.
const _probeIdPrefix = 'schema-bootstrap-probe';

/// Probes that the database rejects each mutation the schema exists to prevent.
///
/// Each probe commits its own fixture, then runs the mutation in a separate
/// transaction. Separating them matters twice over: a fixture that fails to
/// insert is then an unambiguous failure rather than indistinguishable from a
/// rejected mutation, and the mutation's transaction is rolled back by the
/// driver when Postgres refuses it, so a rejected probe leaves the committed
/// fixture intact for the next one.
///
/// Probe rows are deleted both before and after, so a previous run that was
/// killed mid-probe cannot make this one fail on a duplicate key. Every row is
/// removed in a `finally`.
Future<void> _verifyEnforcement(Session session) async {
  await _deleteProbeRows(session);

  final approved = _insertRevisionSql(
    revisionId: '$_probeIdPrefix-approved',
    workItemId: '$_probeIdPrefix-work-item',
    designerExecutionId: '$_probeIdPrefix-designer',
    status: 'approved',
  );
  final secondApproved = _insertRevisionSql(
    revisionId: '$_probeIdPrefix-approved-2',
    workItemId: '$_probeIdPrefix-work-item',
    designerExecutionId: '$_probeIdPrefix-designer-2',
    status: 'approved',
  );
  final selfReview =
      """
    INSERT INTO "design_review_result" (
      "reviewResultId", "revisionId", "reviewExecutionId", "verdict",
      "findingsJson", "assessedDimensionsJson", "createdAt", "version"
    ) VALUES (
      '$_probeIdPrefix-review', '$_probeIdPrefix-approved',
      '$_probeIdPrefix-designer', 'approved', '[]', '[]', now(), 1
    );
    """;

  try {
    await _expectRejected(
      session,
      fixture: approved,
      mutation:
          'UPDATE "design_revision" SET "revisionId" = \'TAMPERED\' '
          'WHERE "revisionId" = \'$_probeIdPrefix-approved\';',
      onAccepted:
          'UPDATE of an approved design_revision was ACCEPTED. '
          'trigger_design_revision_immutability is not enforcing, so an approved '
          'design can be edited after approval.',
    );

    await _expectRejected(
      session,
      fixture: approved,
      mutation: secondApproved,
      onAccepted:
          'A second approved design_revision for one work item was ACCEPTED. '
          'design_revision_approved_unique_per_work_item is not enforcing, so '
          'approval exclusivity is not protected under concurrency.',
    );

    await _expectRejected(
      session,
      fixture: approved,
      mutation: selfReview,
      onAccepted:
          'INSERT of a self-review was ACCEPTED. '
          'trigger_design_review_independence is not enforcing, so a design '
          'execution can approve its own revision.',
    );
  } finally {
    await _deleteProbeRows(session, quietly: true);
  }
}

/// Commits [fixture], then asserts Postgres refuses [mutation].
///
/// Probe rows are removed first, so each probe starts from a clean slate and
/// this tool is safe to re-run against a database a previous probe left rows
/// on.
///
/// Throws [BootstrapFailure] when the mutation succeeds — the constraint or
/// trigger is then missing or inert — or when the fixture cannot be committed,
/// which would make the probe meaningless.
Future<void> _expectRejected(
  Session session, {
  required String fixture,
  required String mutation,
  required String onAccepted,
}) async {
  await _deleteProbeRows(session);

  try {
    await session.db.unsafeSimpleExecute(fixture);
  } catch (error, stackTrace) {
    throw BootstrapFailure(
      'enforcement probe fixture could not be committed, so the probe is '
      'meaningless: $error\n$stackTrace',
    );
  }

  try {
    await session.db.transaction((transaction) async {
      await session.db.unsafeSimpleExecute(mutation, transaction: transaction);
    });
  } on BootstrapFailure {
    rethrow;
  } catch (_) {
    // Postgres refused the mutation: the behaviour under test.
    stdout.writeln('  rejected by the database: ${_firstLine(mutation)}');
    return;
  }

  throw BootstrapFailure(onAccepted);
}

/// Removes every row the probes created. Child tables first.
///
/// Cleanup must never mask the failure that triggered it, so when [quietly] is
/// set a failing delete is reported on stderr and swallowed: the caller is
/// already throwing something more useful.
Future<void> _deleteProbeRows(Session session, {bool quietly = false}) async {
  try {
    await session.db.unsafeSimpleExecute(
      'DELETE FROM "design_revision_event" WHERE "designRevisionId" LIKE '
      "'$_probeIdPrefix%'; "
      'DELETE FROM "design_finding" WHERE "revisionId" LIKE '
      "'$_probeIdPrefix%'; "
      'DELETE FROM "design_review_result" WHERE "revisionId" LIKE '
      "'$_probeIdPrefix%'; "
      'DELETE FROM "design_revision" WHERE "revisionId" LIKE '
      "'$_probeIdPrefix%';",
    );
  } catch (error) {
    if (!quietly) rethrow;
    stderr.writeln(
      'WARNING: could not remove $_probeIdPrefix% rows: $error\n'
      '         Remove them before sharing this database with a test suite.',
    );
  }
}

/// Builds the `design_revision` INSERT used by the probes.
String _insertRevisionSql({
  required String revisionId,
  required String workItemId,
  required String designerExecutionId,
  required String status,
}) =>
    """
  INSERT INTO "design_revision" (
    "revisionId", "workItemId", "productId", "designSystemRevision",
    "providerType", "boardIdsJson", "responsiveTargetsJson",
    "statesRepresentedJson", "artifactRefsJson", "designerExecutionId",
    "reviewExecutionIdsJson", "status", "riskTier", "createdAt", "updatedAt",
    "approvedAt", "version"
  ) VALUES (
    '$revisionId', '$workItemId', '$_probeIdPrefix-product', 'dsr', 'penpot',
    '[]', '[]', '[]', '[]', '$designerExecutionId', '[]', '$status', 'low',
    now(), now(), ${status == 'approved' ? 'now()' : 'NULL'}, 1
  );
""";

/// First line of [sql], for one-line probe reporting.
String _firstLine(String sql) {
  final line = sql.trim().split('\n').first.trim();
  return line.length <= 90 ? line : '${line.substring(0, 87)}...';
}

/// Runs a single-row `SELECT count(*)::int AS n ...` and returns the count.
Future<int> _count(Session session, String sql) async {
  final result = await session.db.unsafeSimpleQuery(sql);
  return result.first.first as int;
}
