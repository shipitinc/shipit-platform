/// F-227 — a stale `activeDedupeKey` on a TERMINAL job row must not wedge the
/// queue.
///
/// `PostgresJobStore` derives `activeDedupeKey = job.isTerminal ? null :
/// dedupeKey` at write time, so a terminal row written THROUGH the store
/// always releases the key. A terminal row written any other way — manual ops
/// SQL, a repair migration — can hold one for ever, and
/// `job_active_dedupe_unique` then makes `enqueueIfAbsent` collide every tick
/// and answer `created: false`: permanent, silent suppression. Live repro on
/// QA 2026-10-30: cancelled job `jb-hnny3s8b5p` still held
/// `DEF-fresh-test:design_revision`.
///
/// The repair lives at the store's transaction boundary: on a dedupe
/// violation the store clears `activeDedupeKey` on the conflicting row IF AND
/// ONLY IF that row is terminal, then retries the operation once. A live
/// holder clears nothing and the exception propagates — the dedupe-retention
/// policy (`failed`/`succeeded` suppress, only `cancelled` yields) is
/// enforced by `enqueueIfAbsent` on the `dedupeKey` column and is untouched.
///
/// ## What is and is not verified here
///
/// **No PostgreSQL was involved in any test below.** Docker and Compose are
/// out of bounds for this lane; `_JobDatabase` is a statement-level double
/// that simulates the unique-violation error text and the repair UPDATE's
/// affected-row count. What IS verified: the exact statements the production
/// store emits, their order, their parameters, that the repair runs OUTSIDE
/// the aborted transaction, that the retry happens exactly once, and the
/// enqueue/cas outcomes the queue observes. What is NOT verified: that a real
/// PostgreSQL re-evaluates the repair's `WHERE` on the locked row, or that
/// `job_active_dedupe_unique` really does reject the second non-NULL key —
/// those are integration-tier facts for `make test-integration`.
library;

import 'dart:convert';

import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_job_store.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:serverpod/database.dart';
import 'package:test/test.dart';

const _dedupeKey = 'DEF-fresh-test:design_revision';

Job _job(
  String jobId,
  JobState state, {
  String dedupeKey = _dedupeKey,
  DateTime? createdAt,
}) {
  return Job(
    jobId: jobId,
    workItemId: 'wi-fresh-test',
    jobType: JobType.designRevision,
    requiredRole: AgentRole.designAgent,
    requiredCapabilities: const {WorkerCapability.linux},
    priority: JobPriority.normal,
    state: state,
    dedupeKey: dedupeKey,
    createdAt: createdAt ?? DateTime.utc(2026, 10, 30),
    instruction: 'revise the design',
    attempt: 1,
    maxAttempts: 2,
    version: 1,
    completedAt: state.isTerminal ? DateTime.utc(2026, 10, 30, 1) : null,
  );
}

void main() {
  group('PostgresJobStore — stale activeDedupeKey self-heal (F-227)', () {
    test('a cancelled holder with a stale activeDedupeKey is repaired and the '
        'enqueue creates the job', () async {
      // The live defect: an out-of-band write left jb-stale cancelled but
      // still holding the key. `findLatestByDedupeKey` reports it (it is
      // the key's latest row), the queue rightly treats it as yielding,
      // and the INSERT collides with the stale index entry.
      final stale = _job('jb-stale', JobState.cancelled);
      final db = _JobDatabase()
        ..latestByDedupeKey = (() => stale)
        ..insertViolationsRemaining = 1
        ..staleRowsCleared = 1;
      final queue = JobQueue(store: PostgresJobStore(PersistenceDatabase(db)));

      final result = await queue.enqueueIfAbsent(
        workItemId: 'wi-fresh-test',
        definition: designRevisionDefinition,
        dedupeKey: _dedupeKey,
        instruction: 'revise the design',
      );

      expect(
        result.created,
        isTrue,
        reason:
            'before the repair this returned created:false on every tick — '
            'the silent suppression F-227 reports',
      );
      expect(result.job.jobId, isNot('jb-stale'));
      expect(result.job.dedupeKey, _dedupeKey);

      expect(
        db.jobInserts,
        2,
        reason: 'the aborted insert plus exactly one retry after the repair',
      );
      expect(
        db.repairs,
        hasLength(1),
        reason: 'one repair UPDATE per healed violation',
      );
      final repair = db.repairs.single;
      expect(
        repair.parameters?['staleActiveDedupeKey'],
        _dedupeKey,
        reason:
            'the repair is keyed on the INDEXED column, so it clears the '
            'row the constraint actually named — not merely the latest row '
            'for the logical dedupe key',
      );
      expect(
        repair.sql,
        contains('"state" IN'),
        reason:
            'the terminal-state guard is part of the UPDATE: a live holder '
            'must never have its key cleared',
      );
      expect(
        repair.insideTransaction,
        isFalse,
        reason:
            'PostgreSQL aborts a transaction on the first error; the repair '
            'can only run after the rollback, as a standalone statement',
      );
      expect(
        db.eventInserts,
        1,
        reason: 'the retried enqueue emits its jobQueued event exactly once',
      );
    });

    test(
      'a stale key on a FAILED holder is repaired too — the terminal guard is '
      'not cancelled-only',
      () async {
        // Same wedge, different terminal state: a `failed` row left holding
        // the key by an out-of-band write while the LATEST row for the key is
        // cancelled (so the queue proceeds to insert). The repair must clear
        // every terminal holder, not just cancelled ones — `dedupeKey` is
        // what keeps failed rows suppressing, not `activeDedupeKey`.
        final staleFailed = _job(
          'jb-stale',
          JobState.failed,
          createdAt: DateTime.utc(2026, 10, 29),
        );
        final cancelledLatest = _job(
          'jb-later',
          JobState.cancelled,
          createdAt: DateTime.utc(2026, 10, 30),
        );
        final db = _JobDatabase()
          ..latestByDedupeKey = (() => cancelledLatest)
          ..insertViolationsRemaining = 1
          ..staleRowsCleared = 1;
        final queue = JobQueue(
          store: PostgresJobStore(PersistenceDatabase(db)),
        );

        final result = await queue.enqueueIfAbsent(
          workItemId: 'wi-fresh-test',
          definition: designRevisionDefinition,
          dedupeKey: _dedupeKey,
          instruction: 'revise the design',
        );

        expect(result.created, isTrue);
        expect(
          db.jobInserts,
          2,
          reason:
              'the stale holder need not be the latest row: the repair clears '
              'by activeDedupeKey, which is exactly the row the index named '
              '(${staleFailed.jobId} here, invisible to '
              'findLatestByDedupeKey)',
        );
      },
    );

    test('a NON-terminal holder is a real dedupe block — nothing cleared, no '
        'retry, created:false', () async {
      // The concurrent-enqueue race the exception exists for: another
      // replica committed an active job for the key between the read and
      // the insert. The repair's terminal guard matches nothing, the
      // exception propagates, and the catch re-reads the real holder.
      var winnerCommitted = false;
      final winner = _job('jb-winner', JobState.queued);
      final db = _JobDatabase()
        ..latestByDedupeKey = (() => winnerCommitted ? winner : null)
        ..insertViolationsRemaining = 1
        ..staleRowsCleared =
            0 // the holder is live: the repair clears nothing
        ..onViolation = (() => winnerCommitted = true);
      final queue = JobQueue(store: PostgresJobStore(PersistenceDatabase(db)));

      final result = await queue.enqueueIfAbsent(
        workItemId: 'wi-fresh-test',
        definition: designRevisionDefinition,
        dedupeKey: _dedupeKey,
        instruction: 'revise the design',
      );

      expect(result.created, isFalse);
      expect(
        result.job.jobId,
        'jb-winner',
        reason:
            'the caller must see the real holder, unchanged from before the '
            'repair existed',
      );
      expect(
        db.jobInserts,
        1,
        reason:
            'no retry: a repair that cleared nothing proves the holder is '
            'live, and retrying would only collide again',
      );
      expect(
        db.repairs,
        hasLength(1),
        reason:
            'the repair is still ATTEMPTED — the terminal check lives in '
            'its WHERE clause, so a live holder is cleared-count 0, not an '
            'unasked question',
      );
    });

    test(
      'a FAILED latest row still suppresses re-enqueue by policy — no insert, '
      'no repair',
      () async {
        // The dedupe-retention half of F-227's contract: a failed attempt
        // keeps holding the key BY POLICY, through `dedupeKey` — the
        // `findLatestByDedupeKey` early return — not through the index. The
        // insert is never attempted, so no violation ever reaches the store
        // and the repair has nothing to do.
        final failed = _job('jb-failed', JobState.failed);
        final db = _JobDatabase()..latestByDedupeKey = (() => failed);
        final queue = JobQueue(
          store: PostgresJobStore(PersistenceDatabase(db)),
        );

        final result = await queue.enqueueIfAbsent(
          workItemId: 'wi-fresh-test',
          definition: designRevisionDefinition,
          dedupeKey: _dedupeKey,
          instruction: 'revise the design',
        );

        expect(result.created, isFalse);
        expect(result.job.jobId, 'jb-failed');
        expect(
          db.jobInserts,
          0,
          reason:
              'policy suppression happens on the dedupeKey read, before any '
              'write — exactly as before the repair existed',
        );
        expect(db.repairs, isEmpty);
      },
    );

    test(
      'a bare saveJob repairs a stale key too — the onboarding enqueue paths '
      'have no transaction to retry for them',
      () async {
        // `baseline_onboarding_sweep` and the operator-triggered onboarding
        // enqueue call saveJob WITHOUT inTransaction. The same stale key
        // would wedge them identically (a permanent alreadyQueuedCode or a
        // thrown exception per call), so the non-transactional path applies
        // the same repair itself.
        final db = _JobDatabase()
          ..insertViolationsRemaining = 1
          ..staleRowsCleared = 1;
        final store = PostgresJobStore(PersistenceDatabase(db));

        await store.saveJob(_job('jb-new', JobState.queued));

        expect(
          db.jobInserts,
          2,
          reason: 'failed attempt plus exactly one retry after the repair',
        );
        expect(db.repairs, hasLength(1));
        expect(db.repairs.single.insideTransaction, isFalse);
      },
    );

    test(
      'a violation on the CAS write path is repaired inside its transaction — '
      'requeue is not left wedged either',
      () async {
        // Stale keys block more than inserts: any write of a non-terminal
        // state re-derives activeDedupeKey and can collide. `revertToQueued`
        // is the expectedVersion path standing in for claims/requeues.
        final stuck = _job('jb-stuck', JobState.claimed);
        final db = _JobDatabase()
          ..jobById = (() => stuck)
          ..updateViolationsRemaining = 1
          ..staleRowsCleared = 1;
        final queue = JobQueue(
          store: PostgresJobStore(PersistenceDatabase(db)),
        );

        final requeued = await queue.revertToQueued(
          job: stuck,
          reason: 'dispatch failed before execution',
        );

        expect(requeued.state, JobState.queued);
        expect(
          db.jobUpdates,
          2,
          reason:
              'the whole transaction body ran again after the repair — the '
              'rolled-back CAS never happened',
        );
        expect(db.repairs, hasLength(1));
      },
    );
  });
}

// ---------------------------------------------------------------------------
// TEST SUPPORT
// ---------------------------------------------------------------------------

/// A statement as it reached the database driver.
class _Statement {
  const _Statement(this.sql, {this.parameters, this.insideTransaction = false});

  final String sql;
  final Map<String, Object?>? parameters;
  final bool insideTransaction;
}

/// The error text PostgreSQL raises for a `job_active_dedupe_unique`
/// conflict. `PostgresJobStore._isDedupeViolation` matches on the message,
/// which is all this stand-in needs to reproduce.
final class _DuplicateKeyException implements Exception {
  @override
  String toString() =>
      'Severity.error 23505: duplicate key value violates unique '
      'constraint "job_active_dedupe_unique"';
}

/// A [Database] that records statements and answers them from test-supplied
/// state instead of a server.
///
/// Like `_RecordingDatabase` in `tick_single_flight_test.dart`, `Database`
/// has a private constructor so this implements the interface and forwards
/// every unused member to `noSuchMethod`. The behaviours a test arms:
///
///  * [latestByDedupeKey] / [jobById] — rows the SELECTs return;
///  * [insertViolationsRemaining] / [updateViolationsRemaining] — writes that
///    raise the dedupe-violation error before succeeding;
///  * [staleRowsCleared] — what the repair UPDATE reports as its affected
///    count (1 when the simulated holder is terminal, 0 when it is live).
class _JobDatabase implements Database {
  final List<_Statement> statements = <_Statement>[];

  Job? Function()? latestByDedupeKey;
  Job? Function()? jobById;
  int insertViolationsRemaining = 0;
  int updateViolationsRemaining = 0;
  int staleRowsCleared = 0;

  /// Runs when a job write raises the violation — lets a test "commit" a
  /// competing row in the gap between the failed attempt and the re-read.
  void Function()? onViolation;

  int get jobInserts =>
      statements.where((s) => s.sql.contains('INSERT INTO "job" (')).length;

  int get jobUpdates => statements
      .where(
        (s) =>
            s.sql.contains('UPDATE "job" SET') &&
            !s.sql.contains('"activeDedupeKey" = NULL'),
      )
      .length;

  int get eventInserts => statements
      .where((s) => s.sql.contains('INSERT INTO "scheduler_event"'))
      .length;

  List<_Statement> get repairs => statements
      .where((s) => s.sql.contains('"activeDedupeKey" = NULL'))
      .toList();

  void _record(
    String sql,
    QueryParameters? parameters,
    Transaction? transaction,
  ) => statements.add(
    _Statement(
      sql,
      parameters: parameters?.parameters as Map<String, Object?>?,
      insideTransaction: transaction != null,
    ),
  );

  @override
  Future<int> unsafeExecute(
    String query, {
    QueryParameters? parameters,
    int? timeoutInSeconds,
    Transaction? transaction,
  }) async {
    _record(query, parameters, transaction);
    if (query.contains('INSERT INTO "job" (')) {
      if (insertViolationsRemaining > 0) {
        insertViolationsRemaining--;
        onViolation?.call();
        throw _DuplicateKeyException();
      }
      return 1;
    }
    if (query.contains('"activeDedupeKey" = NULL')) {
      return staleRowsCleared;
    }
    if (query.contains('UPDATE "job" SET') && updateViolationsRemaining > 0) {
      updateViolationsRemaining--;
      throw _DuplicateKeyException();
    }
    return 1;
  }

  @override
  Future<DatabaseResult> unsafeQuery(
    String query, {
    QueryParameters? parameters,
    int? timeoutInSeconds,
    Transaction? transaction,
  }) async {
    _record(query, parameters, transaction);
    // `scheduler_event` queries also carry `WHERE "jobId"` — this arm must
    // precede the job-table one or an event read would decode a job row.
    if (query.contains('FROM "scheduler_event"')) {
      return _Rows(const <DatabaseResultRow>[]);
    }
    if (query.contains('WHERE "dedupeKey"')) {
      final job = latestByDedupeKey?.call();
      return _Rows(job == null ? const <DatabaseResultRow>[] : [_jobRow(job)]);
    }
    if (query.contains('WHERE "jobId"')) {
      final job = jobById?.call();
      return _Rows(job == null ? const <DatabaseResultRow>[] : [_jobRow(job)]);
    }
    return _Rows(const <DatabaseResultRow>[]);
  }

  @override
  Future<R> transaction<R>(
    Future<R> Function(Transaction) transactionFn, {
    TransactionSettings? settings,
  }) => transactionFn(_FakeTransaction());

  /// Everything this double does not care about — the typed `find`/`insert`/
  /// `update` helpers no store in this file uses.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Present only so [PersistenceDatabase.inTransaction] has a `Transaction` to
/// attach to. Its identity is what `_Statement.insideTransaction` observes.
class _FakeTransaction implements Transaction {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A `SELECT *`-shaped row: `toColumnMap` is all `PostgresJobStore` reads.
class _Row extends DatabaseResultRow {
  _Row(this._columns) : super(_columns.values.toList());

  final Map<String, Object?> _columns;

  @override
  Map<String, dynamic> toColumnMap() => _columns;
}

class _Rows extends DatabaseResult {
  _Rows(super.rows);

  @override
  int get affectedRowCount => length;

  @override
  DatabaseResultSchema get schema =>
      throw UnimplementedError('the double never parses a row description');
}

/// The column shape `PostgresJobStore._jobFromRow` decodes, derived from
/// `Job.toJson` so the wire values can never drift from the serializer.
Map<String, Object?> _jobColumns(Job job) {
  final json = job.toJson();
  return {
    'jobId': json['jobId'],
    'workItemId': json['workItemId'],
    'jobType': json['jobType'],
    'requiredRole': json['requiredRole'],
    'requiredCapabilitiesJson': jsonEncode(
      json['requiredCapabilities'] ?? const [],
    ),
    'priority': json['priority'],
    'state': json['state'],
    'dedupeKey': json['dedupeKey'],
    // Not decoded by _jobFromRow; present so the row is a faithful image of
    // the table, including the stale key the defect is about.
    'activeDedupeKey': json['dedupeKey'],
    'createdAt': json['createdAt'],
    'availableAt': json['availableAt'],
    'instruction': json['instruction'],
    'attempt': json['attempt'],
    'maxAttempts': json['maxAttempts'],
    'startedAt': json['startedAt'],
    'completedAt': json['completedAt'],
    'executionReferenceJson': json['executionReference'] == null
        ? ''
        : jsonEncode(json['executionReference']),
    'workerId': json['workerId'],
    'failureJson': json['failure'] == null ? '' : jsonEncode(json['failure']),
    'cancelReason': json['cancelReason'],
    'version': json['version'],
  };
}

DatabaseResultRow _jobRow(Job job) => _Row(_jobColumns(job));
