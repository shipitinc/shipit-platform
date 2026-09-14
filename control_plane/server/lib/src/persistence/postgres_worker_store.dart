import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/database.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'persistence_database.dart';
import 'util/db_row_util.dart';

/// PostgreSQL implementation of [WorkerStore].
class PostgresWorkerStore implements WorkerStore {
  PostgresWorkerStore(this._db);

  final PersistenceDatabase _db;

  @override
  Future<T> inTransaction<T>(Future<T> Function(WorkerStore store) body) {
    return _db.inTransaction<T>(() => body(this));
  }

  @override
  Future<void> saveWorkerExecution(
    WorkerExecution execution, {
    int? expectedVersion,
  }) async {
    if (expectedVersion != null) {
      final affected = await _db.execute(
        '''UPDATE "worker_execution" SET
             "workItemId" = @workItemId,
             "repositoryPath" = @repositoryPath,
             "requestedStartingRevision" = @requestedStartingRevision,
             "requiredCapabilitiesJson" = @requiredCapabilitiesJson,
             "status" = @status,
             "cleanupPolicy" = @cleanupPolicy,
             "workerId" = @workerId,
             "workspaceId" = @workspaceId,
             "agentExecutionId" = @agentExecutionId,
             "resultId" = @resultId,
             "endingRevision" = @endingRevision,
             "cleanupStatus" = @cleanupStatus,
             "failureCode" = @failureCode,
             "createdAt" = @createdAt,
             "startedAt" = @startedAt,
             "endedAt" = @endedAt,
             "reason" = @reason,
             "version" = @version
           WHERE "workerExecutionId" = @workerExecutionId
             AND "version" = @expected''',
        parameters: QueryParameters.named({
          ..._executionToParams(execution),
          'version': execution.version,
          'expected': expectedVersion,
        }),
      );
      if (affected == 0) {
        final current = await readWorkerExecution(execution.workerExecutionId);
        throw ConcurrentWorkerModificationException(
          workerExecutionId: execution.workerExecutionId,
          expectedVersion: expectedVersion,
          actualVersion: current?.version ?? 0,
        );
      }
      return;
    }

    await _db.execute(
      '''INSERT INTO "worker_execution" (
             "workerExecutionId", "workItemId", "repositoryPath",
             "requestedStartingRevision", "requiredCapabilitiesJson", "status",
             "cleanupPolicy", "workerId", "workspaceId", "agentExecutionId",
             "resultId", "endingRevision", "cleanupStatus", "failureCode",
             "createdAt", "startedAt", "endedAt", "reason", "version"
           ) VALUES (
             @workerExecutionId, @workItemId, @repositoryPath,
             @requestedStartingRevision, @requiredCapabilitiesJson, @status,
             @cleanupPolicy, @workerId, @workspaceId, @agentExecutionId,
             @resultId, @endingRevision, @cleanupStatus, @failureCode,
             @createdAt, @startedAt, @endedAt, @reason, @version
           )
           ON CONFLICT ("workerExecutionId") DO UPDATE SET
             "workItemId" = EXCLUDED."workItemId",
             "repositoryPath" = EXCLUDED."repositoryPath",
             "requestedStartingRevision" = EXCLUDED."requestedStartingRevision",
             "requiredCapabilitiesJson" = EXCLUDED."requiredCapabilitiesJson",
             "status" = EXCLUDED."status",
             "cleanupPolicy" = EXCLUDED."cleanupPolicy",
             "workerId" = EXCLUDED."workerId",
             "workspaceId" = EXCLUDED."workspaceId",
             "agentExecutionId" = EXCLUDED."agentExecutionId",
             "resultId" = EXCLUDED."resultId",
             "endingRevision" = EXCLUDED."endingRevision",
             "cleanupStatus" = EXCLUDED."cleanupStatus",
             "failureCode" = EXCLUDED."failureCode",
             "createdAt" = EXCLUDED."createdAt",
             "startedAt" = EXCLUDED."startedAt",
             "endedAt" = EXCLUDED."endedAt",
             "reason" = EXCLUDED."reason",
             "version" = EXCLUDED."version"''',
      parameters: QueryParameters.named(_executionToParams(execution)),
    );
  }

  @override
  Future<WorkerExecution?> readWorkerExecution(String workerExecutionId) async {
    final result = await _db.query(
      '''SELECT * FROM "worker_execution"
         WHERE "workerExecutionId" = @workerExecutionId''',
      parameters: QueryParameters.named({
        'workerExecutionId': workerExecutionId,
      }),
    );
    if (result.isEmpty) return null;
    return _executionFromRow(result[0]);
  }

  @override
  Future<List<WorkerExecution>> listWorkerExecutions() async {
    final result = await _db.query(
      '''SELECT * FROM "worker_execution" ORDER BY "createdAt" ASC''',
    );
    return result.map(_executionFromRow).toList();
  }

  @override
  Future<void> saveResult(WorkerExecutionResult result) async {
    await _db.execute(
      '''INSERT INTO "worker_result" (
             "workerExecutionId", "workItemId", "status", "workerId",
             "workspaceId", "startingRevision", "endingRevision",
             "agentExecutionId", "agentResultStatus", "verificationId",
             "verificationPassed", "changedFilesJson", "diffSummary",
             "diffRef", "cleanupStatus", "failureCode", "failureDetail",
             "startedAt", "endedAt"
           ) VALUES (
             @workerExecutionId, @workItemId, @status, @workerId,
             @workspaceId, @startingRevision, @endingRevision,
             @agentExecutionId, @agentResultStatus, @verificationId,
             @verificationPassed, @changedFilesJson, @diffSummary,
             @diffRef, @cleanupStatus, @failureCode, @failureDetail,
             @startedAt, @endedAt
           )
           ON CONFLICT ("workerExecutionId") DO UPDATE SET
             "workItemId" = EXCLUDED."workItemId",
             "status" = EXCLUDED."status",
             "workerId" = EXCLUDED."workerId",
             "workspaceId" = EXCLUDED."workspaceId",
             "startingRevision" = EXCLUDED."startingRevision",
             "endingRevision" = EXCLUDED."endingRevision",
             "agentExecutionId" = EXCLUDED."agentExecutionId",
             "agentResultStatus" = EXCLUDED."agentResultStatus",
             "verificationId" = EXCLUDED."verificationId",
             "verificationPassed" = EXCLUDED."verificationPassed",
             "changedFilesJson" = EXCLUDED."changedFilesJson",
             "diffSummary" = EXCLUDED."diffSummary",
             "diffRef" = EXCLUDED."diffRef",
             "cleanupStatus" = EXCLUDED."cleanupStatus",
             "failureCode" = EXCLUDED."failureCode",
             "failureDetail" = EXCLUDED."failureDetail",
             "startedAt" = EXCLUDED."startedAt",
             "endedAt" = EXCLUDED."endedAt"''',
      parameters: QueryParameters.named(_resultToParams(result)),
    );
  }

  @override
  Future<WorkerExecutionResult?> readResult(String workerExecutionId) async {
    final result = await _db.query(
      '''SELECT * FROM "worker_result"
         WHERE "workerExecutionId" = @workerExecutionId''',
      parameters: QueryParameters.named({
        'workerExecutionId': workerExecutionId,
      }),
    );
    if (result.isEmpty) return null;
    return _resultFromRow(result[0]);
  }

  @override
  Future<void> appendEvent(WorkerEventRecord event) async {
    await _db.execute(
      '''INSERT INTO "worker_event" (
             "eventId", "workerExecutionId", "workItemId", "sequence", "type",
             "occurredAt", "payloadJson"
           ) VALUES (
             @eventId, @workerExecutionId, @workItemId, @sequence, @type,
             @occurredAt, @payloadJson
           )''',
      parameters: QueryParameters.named(_eventToParams(event)),
    );
  }

  @override
  Future<List<WorkerEventRecord>> readEvents(String workerExecutionId) async {
    final result = await _db.query(
      '''SELECT * FROM "worker_event"
         WHERE "workerExecutionId" = @workerExecutionId
         ORDER BY "sequence" ASC''',
      parameters: QueryParameters.named({
        'workerExecutionId': workerExecutionId,
      }),
    );
    return result.map(_eventFromRow).toList();
  }

  WorkerExecution _executionFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return WorkerExecution.fromJson({
      'workerExecutionId': m['workerExecutionId'],
      'workItemId': m['workItemId'],
      'repositoryPath': m['repositoryPath'],
      'requestedStartingRevision': m['requestedStartingRevision'],
      'requiredCapabilities': decodeJsonArray(
        m['requiredCapabilitiesJson'] as String?,
      ),
      'status': m['status'],
      'cleanupPolicy': m['cleanupPolicy'],
      'workerId': m['workerId'],
      'workspaceId': m['workspaceId'],
      'agentExecutionId': m['agentExecutionId'],
      'resultId': m['resultId'],
      'endingRevision': m['endingRevision'],
      'cleanupStatus': m['cleanupStatus'],
      'failureCode': m['failureCode'],
      'createdAt': decodeUtc(m['createdAt'])?.toIso8601String(),
      'startedAt': decodeUtc(m['startedAt'])?.toIso8601String(),
      'endedAt': decodeUtc(m['endedAt'])?.toIso8601String(),
      'reason': m['reason'],
      'version': m['version'],
    });
  }

  WorkerExecutionResult _resultFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return WorkerExecutionResult.fromJson({
      'workerExecutionId': m['workerExecutionId'],
      'workItemId': m['workItemId'],
      'status': m['status'],
      'workerId': m['workerId'],
      'workspaceId': m['workspaceId'],
      'startingRevision': m['startingRevision'],
      'endingRevision': m['endingRevision'],
      'agentExecutionId': m['agentExecutionId'],
      'agentResultStatus': m['agentResultStatus'],
      'verificationId': m['verificationId'],
      'verificationPassed': m['verificationPassed'],
      'changedFiles': decodeJsonArray(m['changedFilesJson'] as String?),
      'diffSummary': m['diffSummary'],
      'diffRef': m['diffRef'],
      'cleanupStatus': m['cleanupStatus'],
      'failureCode': m['failureCode'],
      'failureDetail': m['failureDetail'],
      'startedAt': decodeUtc(m['startedAt'])?.toIso8601String(),
      'endedAt': decodeUtc(m['endedAt'])?.toIso8601String(),
    });
  }

  WorkerEventRecord _eventFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return WorkerEventRecord.fromJson({
      'eventId': m['eventId'],
      'workerExecutionId': m['workerExecutionId'],
      'workItemId': m['workItemId'],
      'sequence': m['sequence'],
      'type': m['type'],
      'occurredAt': decodeUtc(m['occurredAt'])?.toIso8601String(),
      'payload': decodeJsonMap(m['payloadJson'] as String?),
    });
  }

  Map<String, Object?> _executionToParams(WorkerExecution execution) {
    final json = execution.toJson();
    return {
      'workerExecutionId': json['workerExecutionId'],
      'workItemId': json['workItemId'],
      'repositoryPath': json['repositoryPath'],
      'requestedStartingRevision': json['requestedStartingRevision'],
      'requiredCapabilitiesJson': PersistenceDatabase.encodeJson(
        json['requiredCapabilities'],
      ),
      'status': json['status'],
      'cleanupPolicy': json['cleanupPolicy'],
      'workerId': json['workerId'],
      'workspaceId': json['workspaceId'],
      'agentExecutionId': json['agentExecutionId'],
      'resultId': json['resultId'],
      'endingRevision': json['endingRevision'],
      'cleanupStatus': json['cleanupStatus'],
      'failureCode': json['failureCode'],
      'createdAt': decodeUtc(json['createdAt']),
      'startedAt': decodeUtc(json['startedAt']),
      'endedAt': decodeUtc(json['endedAt']),
      'reason': json['reason'],
      'version': json['version'],
    };
  }

  Map<String, Object?> _resultToParams(WorkerExecutionResult result) {
    final json = result.toJson();
    return {
      'workerExecutionId': json['workerExecutionId'],
      'workItemId': json['workItemId'],
      'status': json['status'],
      'workerId': json['workerId'],
      'workspaceId': json['workspaceId'],
      'startingRevision': json['startingRevision'],
      'endingRevision': json['endingRevision'],
      'agentExecutionId': json['agentExecutionId'],
      'agentResultStatus': json['agentResultStatus'],
      'verificationId': json['verificationId'],
      'verificationPassed': json['verificationPassed'],
      'changedFilesJson': PersistenceDatabase.encodeJson(json['changedFiles']),
      'diffSummary': json['diffSummary'],
      'diffRef': json['diffRef'],
      'cleanupStatus': json['cleanupStatus'],
      'failureCode': json['failureCode'],
      'failureDetail': json['failureDetail'],
      'startedAt': decodeUtc(json['startedAt']),
      'endedAt': decodeUtc(json['endedAt']),
    };
  }

  Map<String, Object?> _eventToParams(WorkerEventRecord event) {
    final json = event.toJson();
    return {
      'eventId': json['eventId'],
      'workerExecutionId': json['workerExecutionId'],
      'workItemId': json['workItemId'],
      'sequence': json['sequence'],
      'type': json['type'],
      'occurredAt': PersistenceDatabase.toUtc(event.occurredAt),
      'payloadJson': PersistenceDatabase.encodeJson(json['payload']),
    };
  }
}
