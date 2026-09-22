import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/database.dart';

import 'persistence_database.dart';
import 'util/db_row_util.dart';

/// PostgreSQL implementation of [ExecutionStore].
class PostgresExecutionStore implements ExecutionStore {
  PostgresExecutionStore(this._db);

  final PersistenceDatabase _db;

  @override
  Future<T> inTransaction<T>(Future<T> Function(ExecutionStore store) body) {
    return _db.inTransaction<T>(() => body(this));
  }

  @override
  Future<void> saveRequest(AgentExecutionRequest request) async {
    final json = request.toJson();
    await _db.execute(
      '''INSERT INTO "agent_execution_request" (
             "executionId", "workItemId", "role", "runtimeTypeId",
             "workspaceJson", "instruction", "timeoutSeconds",
             "permittedScope", "expectedResultJson", "expectedArtifactsJson",
             "runtimeConfigJson", "environmentJson", "createdAt"
           ) VALUES (
             @executionId, @workItemId, @role, @runtimeTypeId,
             @workspaceJson, @instruction, @timeoutSeconds,
             @permittedScope, @expectedResultJson, @expectedArtifactsJson,
             @runtimeConfigJson, @environmentJson, @createdAt
           )
           ON CONFLICT ("executionId") DO UPDATE SET
             "workItemId" = EXCLUDED."workItemId",
             "role" = EXCLUDED."role",
             "runtimeTypeId" = EXCLUDED."runtimeTypeId",
             "workspaceJson" = EXCLUDED."workspaceJson",
             "instruction" = EXCLUDED."instruction",
             "timeoutSeconds" = EXCLUDED."timeoutSeconds",
             "permittedScope" = EXCLUDED."permittedScope",
             "expectedResultJson" = EXCLUDED."expectedResultJson",
             "expectedArtifactsJson" = EXCLUDED."expectedArtifactsJson",
             "runtimeConfigJson" = EXCLUDED."runtimeConfigJson",
             "environmentJson" = EXCLUDED."environmentJson",
             "createdAt" = EXCLUDED."createdAt"''',
      parameters: QueryParameters.named({
        'executionId': json['executionId'],
        'workItemId': json['workItemId'],
        'role': json['role'],
        'runtimeTypeId': json['runtimeTypeId'],
        'workspaceJson': PersistenceDatabase.encodeJson(json['workspace']),
        'instruction': json['instruction'],
        'timeoutSeconds': json['timeoutSeconds'],
        'permittedScope': json['permittedScope'],
        'expectedResultJson': PersistenceDatabase.encodeJson(
          json['expectedResult'],
        ),
        'expectedArtifactsJson': PersistenceDatabase.encodeJson(
          json['expectedArtifacts'],
        ),
        'runtimeConfigJson': PersistenceDatabase.encodeJson(
          json['runtimeConfig'],
        ),
        'environmentJson': PersistenceDatabase.encodeJson(json['environment']),
        'createdAt': PersistenceDatabase.toUtc(
          urlParseDateTime(json['createdAt']),
        ),
      }),
    );
  }

  @override
  Future<AgentExecutionRequest?> readRequest(String executionId) async {
    final result = await _db.query(
      '''SELECT * FROM "agent_execution_request"
         WHERE "executionId" = @executionId''',
      parameters: QueryParameters.named({'executionId': executionId}),
    );
    if (result.isEmpty) return null;
    return _requestFromRow(result[0]);
  }

  @override
  Future<void> saveExecution(
    AgentExecution execution, {
    int? expectedVersion,
  }) async {
    if (expectedVersion != null) {
      final affected = await _db.execute(
        '''UPDATE "agent_execution" SET
             "workItemId" = @workItemId,
             "requestId" = @requestId,
             "runtimeTypeId" = @runtimeTypeId,
             "role" = @role,
             "status" = @status,
             "workspaceJson" = @workspaceJson,
             "sessionId" = @sessionId,
             "resultId" = @resultId,
             "startedAt" = @startedAt,
             "completedAt" = @completedAt,
             "reason" = @reason,
             "metadataJson" = @metadataJson,
             "version" = @version
           WHERE "executionId" = @executionId AND "version" = @expected''',
        parameters: QueryParameters.named({
          ..._executionToParams(execution),
          'version': execution.version,
          'expected': expectedVersion,
        }),
      );
      if (affected == 0) {
        final current = await readExecutionOrNull(execution.executionId);
        throw ConcurrentExecutionModificationException(
          executionId: execution.executionId,
          expectedVersion: expectedVersion,
          actualVersion: current?.version ?? 0,
        );
      }
      return;
    }

    await _db.execute(
      '''INSERT INTO "agent_execution" (
             "executionId", "workItemId", "requestId", "runtimeTypeId",
             "role", "status", "workspaceJson", "sessionId", "resultId",
             "startedAt", "completedAt", "reason", "metadataJson", "version"
           ) VALUES (
             @executionId, @workItemId, @requestId, @runtimeTypeId,
             @role, @status, @workspaceJson, @sessionId, @resultId,
             @startedAt, @completedAt, @reason, @metadataJson, @version
           )
           ON CONFLICT ("executionId") DO UPDATE SET
             "workItemId" = EXCLUDED."workItemId",
             "requestId" = EXCLUDED."requestId",
             "runtimeTypeId" = EXCLUDED."runtimeTypeId",
             "role" = EXCLUDED."role",
             "status" = EXCLUDED."status",
             "workspaceJson" = EXCLUDED."workspaceJson",
             "sessionId" = EXCLUDED."sessionId",
             "resultId" = EXCLUDED."resultId",
             "startedAt" = EXCLUDED."startedAt",
             "completedAt" = EXCLUDED."completedAt",
             "reason" = EXCLUDED."reason",
             "metadataJson" = EXCLUDED."metadataJson",
             "version" = EXCLUDED."version"''',
      parameters: QueryParameters.named(_executionToParams(execution)),
    );
  }

  @override
  Future<AgentExecution> readExecution(String executionId) async {
    final execution = await readExecutionOrNull(executionId);
    if (execution == null) {
      throw ExecutionNotFoundException(executionId);
    }
    return execution;
  }

  @override
  Future<AgentExecution?> readExecutionOrNull(String executionId) async {
    final result = await _db.query(
      '''SELECT * FROM "agent_execution"
         WHERE "executionId" = @executionId''',
      parameters: QueryParameters.named({'executionId': executionId}),
    );
    if (result.isEmpty) return null;
    return _executionFromRow(result[0]);
  }

  @override
  Future<List<AgentExecution>> listExecutions({String? workItemId}) async {
    final result = await _db.query(
      workItemId == null
          ? '''SELECT * FROM "agent_execution"
              ORDER BY "startedAt" DESC NULLS LAST, "id" DESC'''
          : '''SELECT * FROM "agent_execution" WHERE "workItemId" = @workItemId
              ORDER BY "startedAt" DESC NULLS LAST, "id" DESC''',
      parameters: workItemId == null
          ? null
          : QueryParameters.named({'workItemId': workItemId}),
    );
    return result.map(_executionFromRow).toList();
  }

  @override
  Future<AgentExecution?> latestExecutionForWorkItem(String workItemId) async {
    final result = await _db.query(
      '''SELECT * FROM "agent_execution" WHERE "workItemId" = @workItemId
         ORDER BY "startedAt" DESC NULLS LAST, "id" DESC
         LIMIT 1''',
      parameters: QueryParameters.named({'workItemId': workItemId}),
    );
    if (result.isEmpty) return null;
    return _executionFromRow(result[0]);
  }

  @override
  Future<void> appendEvent(AgentEventRecord event) async {
    final json = event.toJson();
    await _db.execute(
      '''INSERT INTO "agent_event" (
             "eventId", "executionId", "workItemId", "sequence", "type",
             "occurredAt", "payloadJson"
           ) VALUES (
             @eventId, @executionId, @workItemId, @sequence, @type,
             @occurredAt, @payloadJson
           )''',
      parameters: QueryParameters.named({
        'eventId': json['eventId'],
        'executionId': json['executionId'],
        'workItemId': json['workItemId'],
        'sequence': json['sequence'],
        'type': json['type'],
        'occurredAt': PersistenceDatabase.toUtc(event.occurredAt),
        'payloadJson': PersistenceDatabase.encodeJson(json['payload']),
      }),
    );
  }

  @override
  Future<List<AgentEventRecord>> readEvents(String executionId) async {
    final result = await _db.query(
      '''SELECT * FROM "agent_event" WHERE "executionId" = @executionId
         ORDER BY "sequence" ASC''',
      parameters: QueryParameters.named({'executionId': executionId}),
    );
    return result.map(_eventFromRow).toList();
  }

  @override
  Future<void> saveResult(String executionId, AgentResult result) async {
    await _db.execute(
      '''INSERT INTO "agent_result" (
             "resultId", "sessionId", "workItemId", "status",
             "artifactsJson", "diagnosticsJson", "structuredResultJson",
             "executionId", "role", "changedFilesJson", "claimedChecksJson",
             "summary", "completedAt", "metadataJson"
           ) VALUES (
             @resultId, @sessionId, @workItemId, @status,
             @artifactsJson, @diagnosticsJson, @structuredResultJson,
             @executionId, @role, @changedFilesJson, @claimedChecksJson,
             @summary, @completedAt, @metadataJson
           )
           ON CONFLICT ("executionId") DO UPDATE SET
             "resultId" = EXCLUDED."resultId",
             "sessionId" = EXCLUDED."sessionId",
             "workItemId" = EXCLUDED."workItemId",
             "status" = EXCLUDED."status",
             "artifactsJson" = EXCLUDED."artifactsJson",
             "diagnosticsJson" = EXCLUDED."diagnosticsJson",
             "structuredResultJson" = EXCLUDED."structuredResultJson",
             "role" = EXCLUDED."role",
             "changedFilesJson" = EXCLUDED."changedFilesJson",
             "claimedChecksJson" = EXCLUDED."claimedChecksJson",
             "summary" = EXCLUDED."summary",
             "completedAt" = EXCLUDED."completedAt",
             "metadataJson" = EXCLUDED."metadataJson"''',
      parameters: QueryParameters.named(_resultToParams(result)),
    );
  }

  @override
  Future<AgentResult?> readResult(String executionId) async {
    final result = await _db.query(
      '''SELECT * FROM "agent_result" WHERE "executionId" = @executionId''',
      parameters: QueryParameters.named({'executionId': executionId}),
    );
    if (result.isEmpty) return null;
    return _resultFromRow(result[0]);
  }

  @override
  Future<void> saveVerification(PlatformVerification verification) async {
    await _db.execute(
      '''INSERT INTO "platform_verification" (
             "verificationId", "executionId", "workItemId", "checkName",
             "status", "mechanism", "command", "capturedAt", "evidenceKind",
             "outputRef", "detail", "resultPath"
           ) VALUES (
             @verificationId, @executionId, @workItemId, @checkName,
             @status, @mechanism, @command, @capturedAt, @evidenceKind,
             @outputRef, @detail, @resultPath
           )
           ON CONFLICT ("verificationId") DO UPDATE SET
             "executionId" = EXCLUDED."executionId",
             "workItemId" = EXCLUDED."workItemId",
             "checkName" = EXCLUDED."checkName",
             "status" = EXCLUDED."status",
             "mechanism" = EXCLUDED."mechanism",
             "command" = EXCLUDED."command",
             "capturedAt" = EXCLUDED."capturedAt",
             "evidenceKind" = EXCLUDED."evidenceKind",
             "outputRef" = EXCLUDED."outputRef",
             "detail" = EXCLUDED."detail",
             "resultPath" = EXCLUDED."resultPath"''',
      parameters: QueryParameters.named(_verificationToParams(verification)),
    );
  }

  @override
  Future<List<PlatformVerification>> readVerifications(
    String executionId,
  ) async {
    final result = await _db.query(
      '''SELECT * FROM "platform_verification"
         WHERE "executionId" = @executionId
         ORDER BY "capturedAt" ASC''',
      parameters: QueryParameters.named({'executionId': executionId}),
    );
    return result.map(_verificationFromRow).toList();
  }

  static DateTime? urlParseDateTime(Object? value) =>
      value is String ? DateTime.parse(value) : value as DateTime?;

  AgentExecutionRequest _requestFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return AgentExecutionRequest.fromJson({
      'executionId': m['executionId'],
      'workItemId': m['workItemId'],
      'role': m['role'],
      'runtimeTypeId': m['runtimeTypeId'],
      'workspace': decodeJsonMap(m['workspaceJson'] as String?),
      'instruction': m['instruction'],
      'timeoutSeconds': m['timeoutSeconds'],
      'permittedScope': m['permittedScope'],
      'expectedResult': decodeJsonMap(m['expectedResultJson'] as String?),
      'expectedArtifacts': decodeJsonArray(
        m['expectedArtifactsJson'] as String?,
      ),
      'runtimeConfig': decodeJsonMap(m['runtimeConfigJson'] as String?),
      'environment': decodeJsonMap(m['environmentJson'] as String?),
      'createdAt': _toIsoStringOrNull(m['createdAt']),
    });
  }

  AgentExecution _executionFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return AgentExecution.fromJson({
      'executionId': m['executionId'],
      'workItemId': m['workItemId'],
      'requestId': m['requestId'],
      'runtimeTypeId': m['runtimeTypeId'],
      'role': m['role'],
      'status': m['status'],
      'workspace': decodeJsonMap(m['workspaceJson'] as String?),
      'sessionId': m['sessionId'],
      'resultId': m['resultId'],
      'startedAt': _toIsoStringOrNull(m['startedAt']),
      'completedAt': _toIsoStringOrNull(m['completedAt']),
      'reason': m['reason'],
      'metadata': decodeJsonMap(m['metadataJson'] as String?),
      'version': m['version'],
    });
  }

  AgentResult _resultFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return AgentResult.fromJson({
      'resultId': m['resultId'],
      'sessionId': m['sessionId'],
      'workItemId': m['workItemId'],
      'status': m['status'],
      'artifacts': decodeJsonArray(m['artifactsJson'] as String?),
      'diagnostics': decodeJsonMap(m['diagnosticsJson'] as String?),
      'structuredResult': decodeJsonMap(m['structuredResultJson'] as String?),
      'executionId': m['executionId'],
      'role': m['role'],
      'changedFiles': decodeJsonArray(m['changedFilesJson'] as String?),
      'claimedChecks': decodeJsonArray(m['claimedChecksJson'] as String?),
      'summary': m['summary'],
      'completedAt': decodeUtc(m['completedAt'])!.toIso8601String(),
      'metadata': decodeJsonMap(m['metadataJson'] as String?),
    });
  }

  AgentEventRecord _eventFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return AgentEventRecord.fromJson({
      'eventId': m['eventId'],
      'executionId': m['executionId'],
      'workItemId': m['workItemId'],
      'sequence': m['sequence'],
      'type': m['type'],
      'occurredAt': decodeUtc(m['occurredAt'])!.toIso8601String(),
      'payload': decodeJsonMap(m['payloadJson'] as String?),
    });
  }

  PlatformVerification _verificationFromRow(DatabaseResultRow row) {
    final m = row.toColumnMap();
    return PlatformVerification.fromJson({
      'verificationId': m['verificationId'],
      'executionId': m['executionId'],
      'workItemId': m['workItemId'],
      'checkName': m['checkName'],
      'status': m['status'],
      'mechanism': m['mechanism'],
      'command': m['command'],
      'capturedAt': decodeUtc(m['capturedAt'])!.toIso8601String(),
      'evidenceKind': m['evidenceKind'],
      'outputRef': m['outputRef'],
      'detail': m['detail'],
      'resultPath': m['resultPath'],
    });
  }

  static Object? _toIsoStringOrNull(Object? value) =>
      decodeUtc(value)?.toIso8601String();

  Map<String, Object?> _executionToParams(AgentExecution execution) {
    final json = execution.toJson();
    return {
      'executionId': json['executionId'],
      'workItemId': json['workItemId'],
      'requestId': json['requestId'],
      'runtimeTypeId': json['runtimeTypeId'],
      'role': json['role'],
      'status': json['status'],
      'workspaceJson': PersistenceDatabase.encodeJson(json['workspace']),
      'sessionId': json['sessionId'],
      'resultId': json['resultId'],
      'startedAt': PersistenceDatabase.toUtc(
        urlParseDateTime(json['startedAt']),
      ),
      'completedAt': PersistenceDatabase.toUtc(
        urlParseDateTime(json['completedAt']),
      ),
      'reason': json['reason'],
      'metadataJson': PersistenceDatabase.encodeJson(json['metadata']),
      'version': json['version'],
    };
  }

  Map<String, Object?> _resultToParams(AgentResult result) {
    final json = result.toJson();
    return {
      'resultId': json['resultId'],
      'sessionId': json['sessionId'],
      'workItemId': json['workItemId'],
      'status': json['status'],
      'artifactsJson': PersistenceDatabase.encodeJson(json['artifacts']),
      'diagnosticsJson': PersistenceDatabase.encodeJson(json['diagnostics']),
      'structuredResultJson': PersistenceDatabase.encodeJson(
        json['structuredResult'],
      ),
      'executionId': json['executionId'],
      'role': json['role'],
      'changedFilesJson': PersistenceDatabase.encodeJson(json['changedFiles']),
      'claimedChecksJson': PersistenceDatabase.encodeJson(
        json['claimedChecks'],
      ),
      'summary': json['summary'],
      'completedAt': PersistenceDatabase.toUtc(
        DateTime.parse(json['completedAt'] as String),
      ),
      'metadataJson': PersistenceDatabase.encodeJson(json['metadata']),
    };
  }

  Map<String, Object?> _verificationToParams(
    PlatformVerification verification,
  ) {
    final json = verification.toJson();
    return {
      'verificationId': json['verificationId'],
      'executionId': json['executionId'],
      'workItemId': json['workItemId'],
      'checkName': json['checkName'],
      'status': json['status'],
      'mechanism': json['mechanism'],
      'command': json['command'],
      'capturedAt': PersistenceDatabase.toUtc(
        DateTime.parse(json['capturedAt'] as String),
      ),
      'evidenceKind': json['evidenceKind'],
      'outputRef': json['outputRef'],
      'detail': json['detail'],
      'resultPath': json['resultPath'],
    };
  }
}
