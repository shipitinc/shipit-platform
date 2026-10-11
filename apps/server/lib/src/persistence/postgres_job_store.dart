import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
// L1 owns `packages/scheduler/**` and has not exported the capacity API from
// its barrel. Adding that export means editing a file this lane is not
// permitted to modify, and it is under concurrent review — so the import is
// explicit, narrow, and expected to be deleted when L1's barrel gains the
// export. See the same note in `server.dart`.
// ignore: implementation_imports
import 'package:scheduler/src/capacity/capacity_lockable_store.dart';
import 'package:serverpod/database.dart';

import 'persistence_database.dart';
import 'util/db_row_util.dart';

/// PostgreSQL implementation of [JobStore].
///
/// Job, claim and event rows are stored in relational tables. The active-state
/// deduplication constraint (`job_active_dedupe_unique`) is a unique index on
/// the derived `job.activeDedupeKey` column, which is non-null exactly while
/// the job is not terminal; a concurrent double-enqueue surfaces as
/// [DuplicateActiveJobException].
///
/// The derivation is deliberately inlined into [saveJob] rather than left to
/// callers: it is the only production write path to `job`, so keeping it here
/// makes it impossible to write a row whose stored dedupe key disagrees with
/// its state.
///
/// ## It is also the store that can enforce a global execution cap
///
/// [CapacityLockingJobStore] is implemented here — and only here — because
/// PostgreSQL is the only backend in this repository that can make
/// "count the in-flight executions" and "claim one" atomic across processes.
/// See [inCapacityLockedTransaction].
class PostgresJobStore implements JobStore, CapacityLockingJobStore {
  PostgresJobStore(this._db);

  final PersistenceDatabase _db;

  @override
  Future<T> inTransaction<T>(Future<T> Function(JobStore store) body) {
    return _db.inTransaction<T>(() => body(this));
  }

  /// Runs [body] inside a transaction holding the cluster-wide exclusive
  /// advisory lock for [lockKey].
  ///
  /// ## Why this method exists at all
  ///
  /// `JobCapacityGuard` counts in-flight executions and then claims a job. That
  /// pair has to be indivisible, or two replicas both read `inFlight = C-1`, both
  /// admit, and the cap is exceeded by exactly one PER REPLICA — silently, on
  /// every tick, under exactly the burst load the cap exists to stop. A job
  /// claim's own CAS cannot supply that exclusion, because each replica contends
  /// for a DIFFERENT job while counting the same global budget.
  ///
  /// `pg_advisory_xact_lock` is the exclusion that can. It is scoped to the
  /// DATABASE and shared by every connection, so it serialises two schedulers in
  /// one process exactly as it serialises two replicas across machines.
  ///
  /// ## Why `xact_lock` and not `pg_advisory_lock`
  ///
  /// A session-scoped `pg_advisory_lock` survives the statement that took it and
  /// is released only by an explicit unlock or by the connection dying. One
  /// thrown error between "lock taken" and "connection closed" would then hold
  /// the budget forever, and every later tick would queue behind a lock no
  /// process is using — a wedge with no error and no log line. The `_xact_`
  /// variant is released by COMMIT, by ROLLBACK and by connection loss alike, so
  /// there is no exit path that can strand it and nothing to release by hand.
  /// `PersistenceDatabase.inTransaction` commits or rolls back on every path, so
  /// the release is a property of the transaction rather than of a `finally`
  /// somebody has to remember.
  ///
  /// ## Ordering, which is the whole point
  ///
  /// The lock is taken INSIDE the transaction and BEFORE [body] is called. Taken
  /// outside it, the lock would be released at the end of the implicit
  /// single-statement transaction — before the count and the claim had even
  /// happened. Taken after the count, it would serialise the claim but not the
  /// count, which is the overshoot. Issued through `_db.execute` rather than
  /// `_db.query` so the row is never decoded: `pg_advisory_xact_lock` returns
  /// `void`, and reading a `void` column back is a needless way to fail.
  ///
  /// `_db.execute` attaches to the transaction opened one line above, so the
  /// lock is taken on the SAME connection the body will use. A lock taken on a
  /// different connection would be released by that connection's next commit,
  /// not by this transaction's.
  @override
  Future<T> inCapacityLockedTransaction<T>(
    int lockKey,
    Future<T> Function(JobStore store) body,
  ) {
    return _db.inTransaction<T>(() async {
      await _db.execute(
        'SELECT pg_advisory_xact_lock(@lockKey::bigint)',
        parameters: QueryParameters.named({'lockKey': lockKey}),
      );
      // `this` is the handle bound to the open transaction: every call it makes
      // routes through `_db`, which is now carrying `_activeTransaction`, so the
      // count and the claim commit or roll back together. Exactly the handle
      // `inTransaction` passes, for exactly the same reason.
      return body(this);
    });
  }

  @override
  Future<void> saveJob(Job job, {int? expectedVersion}) async {
    if (expectedVersion != null) {
      int affected;
      try {
        affected = await _db.execute(
          '''UPDATE "job" SET
               "workItemId" = @workItemId,
               "jobType" = @jobType,
               "requiredRole" = @requiredRole,
               "requiredCapabilitiesJson" = @requiredCapabilitiesJson,
               "priority" = @priority,
               "state" = @state,
               "dedupeKey" = @dedupeKey,
               "activeDedupeKey" = @activeDedupeKey,
               "createdAt" = @createdAt,
               "availableAt" = @availableAt,
               "instruction" = @instruction,
               "attempt" = @attempt,
               "maxAttempts" = @maxAttempts,
               "startedAt" = @startedAt,
               "completedAt" = @completedAt,
               "executionReferenceJson" = @executionReferenceJson,
               "workerId" = @workerId,
               "failureJson" = @failureJson,
               "cancelReason" = @cancelReason,
               "version" = @version
             WHERE "jobId" = @jobId AND "version" = @expected''',
          parameters: QueryParameters.named({
            ..._jobToParams(job),
            'version': job.version,
            'expected': expectedVersion,
          }),
        );
      } on Exception catch (e) {
        if (_isDedupeViolation(e)) {
          throw DuplicateActiveJobException(
            jobId: job.jobId,
            dedupeKey: job.dedupeKey,
          );
        }
        rethrow;
      }
      if (affected == 0) {
        final current = await readJob(job.jobId);
        throw ConcurrentJobModificationException(
          jobId: job.jobId,
          expectedVersion: expectedVersion,
          actualVersion: current?.version ?? 0,
        );
      }
      return;
    }

    try {
      await _db.execute(
        '''INSERT INTO "job" (
               "jobId", "workItemId", "jobType", "requiredRole",
               "requiredCapabilitiesJson", "priority", "state", "dedupeKey",
               "activeDedupeKey", "createdAt", "availableAt", "instruction",
               "attempt", "maxAttempts", "startedAt", "completedAt",
               "executionReferenceJson", "workerId", "failureJson",
               "cancelReason", "version"
             ) VALUES (
               @jobId, @workItemId, @jobType, @requiredRole,
               @requiredCapabilitiesJson, @priority, @state, @dedupeKey,
               @activeDedupeKey, @createdAt, @availableAt, @instruction,
               @attempt, @maxAttempts, @startedAt, @completedAt,
               @executionReferenceJson, @workerId, @failureJson,
               @cancelReason, @version
             )
             ON CONFLICT ("jobId") DO UPDATE SET
               "workItemId" = EXCLUDED."workItemId",
               "jobType" = EXCLUDED."jobType",
               "requiredRole" = EXCLUDED."requiredRole",
               "requiredCapabilitiesJson" = EXCLUDED."requiredCapabilitiesJson",
               "priority" = EXCLUDED."priority",
               "state" = EXCLUDED."state",
               "dedupeKey" = EXCLUDED."dedupeKey",
               "activeDedupeKey" = EXCLUDED."activeDedupeKey",
               "createdAt" = EXCLUDED."createdAt",
               "availableAt" = EXCLUDED."availableAt",
               "instruction" = EXCLUDED."instruction",
               "attempt" = EXCLUDED."attempt",
               "maxAttempts" = EXCLUDED."maxAttempts",
               "startedAt" = EXCLUDED."startedAt",
               "completedAt" = EXCLUDED."completedAt",
               "executionReferenceJson" = EXCLUDED."executionReferenceJson",
               "workerId" = EXCLUDED."workerId",
               "failureJson" = EXCLUDED."failureJson",
               "cancelReason" = EXCLUDED."cancelReason",
               "version" = EXCLUDED."version"''',
        parameters: QueryParameters.named(_jobToParams(job)),
      );
    } on Exception catch (e) {
      if (_isDedupeViolation(e)) {
        throw DuplicateActiveJobException(
          jobId: job.jobId,
          dedupeKey: job.dedupeKey,
        );
      }
      rethrow;
    }
  }

  bool _isDedupeViolation(Object error) {
    final message = error.toString();
    return message.contains('job_active_dedupe_unique') &&
        message.contains('duplicate key');
  }

  @override
  Future<Job?> readJob(String jobId) async {
    final result = await _db.query(
      '''SELECT * FROM "job" WHERE "jobId" = @jobId''',
      parameters: QueryParameters.named({'jobId': jobId}),
    );
    if (result.isEmpty) return null;
    return _jobFromRow(result[0]);
  }

  @override
  Future<List<Job>> listJobs() async {
    final result = await _db.query(
      '''SELECT * FROM "job" ORDER BY "createdAt" ASC''',
    );
    return result.map(_jobFromRow).toList();
  }

  @override
  Future<List<Job>> listJobsForWorkItem(String workItemId) async {
    final result = await _db.query(
      '''SELECT * FROM "job"
         WHERE "workItemId" = @workItemId
         ORDER BY "createdAt" ASC''',
      parameters: QueryParameters.named({'workItemId': workItemId}),
    );
    return result.map(_jobFromRow).toList();
  }

  @override
  Future<Job?> findLatestByDedupeKey(String dedupeKey) async {
    final result = await _db.query(
      '''SELECT * FROM "job"
         WHERE "dedupeKey" = @dedupeKey
         ORDER BY "createdAt" DESC, "jobId" DESC
         LIMIT 1''',
      parameters: QueryParameters.named({'dedupeKey': dedupeKey}),
    );
    if (result.isEmpty) return null;
    return _jobFromRow(result[0]);
  }

  @override
  Future<void> saveClaim(JobClaim claim) async {
    await _db.execute(
      '''INSERT INTO "job_claim" (
             "claimId", "jobId", "ownerId", "leasedUntil", "createdAt"
           ) VALUES (
             @claimId, @jobId, @ownerId, @leasedUntil, @createdAt
           )
           ON CONFLICT ("jobId") DO UPDATE SET
             "claimId" = EXCLUDED."claimId",
             "ownerId" = EXCLUDED."ownerId",
             "leasedUntil" = EXCLUDED."leasedUntil",
             "createdAt" = EXCLUDED."createdAt"''',
      parameters: QueryParameters.named(_claimToParams(claim)),
    );
  }

  @override
  Future<JobClaim?> readClaimForJob(String jobId) async {
    final result = await _db.query(
      '''SELECT * FROM "job_claim" WHERE "jobId" = @jobId''',
      parameters: QueryParameters.named({'jobId': jobId}),
    );
    if (result.isEmpty) return null;
    return _claimFromRow(result[0]);
  }

  @override
  Future<List<JobClaim>> listClaims() async {
    final result = await _db.query('SELECT * FROM "job_claim"');
    return result.map(_claimFromRow).toList();
  }

  @override
  Future<void> deleteClaim(String jobId) async {
    await _db.execute(
      '''DELETE FROM "job_claim" WHERE "jobId" = @jobId''',
      parameters: QueryParameters.named({'jobId': jobId}),
    );
  }

  @override
  Future<void> appendEvent(SchedulerEventRecord event) async {
    await _db.execute(
      '''INSERT INTO "scheduler_event" (
             "eventId", "jobId", "workItemId", "sequence", "type",
             "occurredAt", "payloadJson"
           ) VALUES (
             @eventId, @jobId, @workItemId, @sequence, @type,
             @occurredAt, @payloadJson
           )''',
      parameters: QueryParameters.named(_eventToParams(event)),
    );
  }

  @override
  Future<List<SchedulerEventRecord>> readEvents(String jobId) async {
    final result = await _db.query(
      '''SELECT * FROM "scheduler_event"
         WHERE "jobId" = @jobId
         ORDER BY "sequence" ASC''',
      parameters: QueryParameters.named({'jobId': jobId}),
    );
    return result.map(_eventFromRow).toList();
  }

  Job _jobFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return Job.fromJson({
      'jobId': m['jobId'],
      'workItemId': m['workItemId'],
      'jobType': m['jobType'],
      'requiredRole': m['requiredRole'],
      'requiredCapabilities': decodeJsonArray(
        m['requiredCapabilitiesJson'] as String?,
      ),
      'priority': m['priority'],
      'state': m['state'],
      'dedupeKey': m['dedupeKey'],
      'createdAt': decodeUtc(m['createdAt'])?.toIso8601String(),
      'availableAt': decodeUtc(m['availableAt'])?.toIso8601String(),
      'instruction': m['instruction'],
      'attempt': m['attempt'],
      'maxAttempts': m['maxAttempts'],
      'startedAt': decodeUtc(m['startedAt'])?.toIso8601String(),
      'completedAt': decodeUtc(m['completedAt'])?.toIso8601String(),
      'executionReference': decodeJsonMap(
        m['executionReferenceJson'] as String?,
      ),
      'workerId': m['workerId'],
      'failure': decodeJsonMap(m['failureJson'] as String?),
      'cancelReason': m['cancelReason'],
      'version': m['version'],
    });
  }

  JobClaim _claimFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return JobClaim.fromJson({
      'claimId': m['claimId'],
      'jobId': m['jobId'],
      'ownerId': m['ownerId'],
      'leasedUntil': decodeUtc(m['leasedUntil'])?.toIso8601String(),
      'createdAt': decodeUtc(m['createdAt'])?.toIso8601String(),
    });
  }

  SchedulerEventRecord _eventFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return SchedulerEventRecord.fromJson({
      'eventId': m['eventId'],
      'jobId': m['jobId'],
      'workItemId': m['workItemId'],
      'sequence': m['sequence'],
      'type': m['type'],
      'occurredAt': decodeUtc(m['occurredAt'])?.toIso8601String(),
      'payload': decodeJsonMap(m['payloadJson'] as String?),
    });
  }

  Map<String, Object?> _jobToParams(Job job) {
    final json = job.toJson();
    return {
      'jobId': json['jobId'],
      'workItemId': json['workItemId'],
      'jobType': json['jobType'],
      'requiredRole': json['requiredRole'],
      'requiredCapabilitiesJson': PersistenceDatabase.encodeJson(
        json['requiredCapabilities'],
      ),
      'priority': json['priority'],
      'state': json['state'],
      'dedupeKey': json['dedupeKey'],
      'activeDedupeKey': job.isTerminal ? null : json['dedupeKey'],
      'createdAt': decodeUtc(json['createdAt']),
      'availableAt': decodeUtc(json['availableAt']),
      'instruction': json['instruction'],
      'attempt': json['attempt'],
      'maxAttempts': json['maxAttempts'],
      'startedAt': decodeUtc(json['startedAt']),
      'completedAt': decodeUtc(json['completedAt']),
      'executionReferenceJson': PersistenceDatabase.encodeJson(
        json['executionReference'],
      ),
      'workerId': json['workerId'],
      'failureJson': PersistenceDatabase.encodeJson(json['failure']),
      'cancelReason': json['cancelReason'],
      'version': json['version'],
    };
  }

  Map<String, Object?> _claimToParams(JobClaim claim) {
    return {
      'claimId': claim.claimId,
      'jobId': claim.jobId,
      'ownerId': claim.ownerId,
      'leasedUntil': PersistenceDatabase.toUtc(claim.leasedUntil),
      'createdAt': PersistenceDatabase.toUtc(claim.createdAt),
    };
  }

  Map<String, Object?> _eventToParams(SchedulerEventRecord event) {
    final json = event.toJson();
    return {
      'eventId': json['eventId'],
      'jobId': json['jobId'],
      'workItemId': json['workItemId'],
      'sequence': json['sequence'],
      'type': json['type'],
      'occurredAt': PersistenceDatabase.toUtc(event.occurredAt),
      'payloadJson': PersistenceDatabase.encodeJson(json['payload']),
    };
  }
}
