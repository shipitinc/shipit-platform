import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:serverpod/database.dart';

import 'persistence_database.dart';
import 'util/db_row_util.dart';

/// PostgreSQL implementation of [JobStore].
///
/// Job, claim and event rows are stored in relational tables. The active-state
/// deduplication constraint (`job_active_dedupe_unique`) is enforced by a
/// partial unique index on `job.dedupeKey`; a concurrent double-enqueue
/// surfaces as [DuplicateActiveJobException].
class PostgresJobStore implements JobStore {
  PostgresJobStore(this._db);

  final PersistenceDatabase _db;

  @override
  Future<T> inTransaction<T>(Future<T> Function(JobStore store) body) {
    return _db.inTransaction<T>(() => body(this));
  }

  @override
  Future<void> saveJob(Job job, {int? expectedVersion}) async {
    if (expectedVersion != null) {
      final affected = await _db.execute(
        '''UPDATE "job" SET
             "workItemId" = @workItemId,
             "jobType" = @jobType,
             "requiredRole" = @requiredRole,
             "requiredCapabilitiesJson" = @requiredCapabilitiesJson,
             "priority" = @priority,
             "state" = @state,
             "dedupeKey" = @dedupeKey,
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
               "createdAt", "availableAt", "instruction", "attempt",
               "maxAttempts", "startedAt", "completedAt",
               "executionReferenceJson", "workerId", "failureJson",
               "cancelReason", "version"
             ) VALUES (
               @jobId, @workItemId, @jobType, @requiredRole,
               @requiredCapabilitiesJson, @priority, @state, @dedupeKey,
               @createdAt, @availableAt, @instruction, @attempt,
               @maxAttempts, @startedAt, @completedAt,
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
