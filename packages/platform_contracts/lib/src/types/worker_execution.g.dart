// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_execution.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkerExecution _$WorkerExecutionFromJson(Map<String, dynamic> json) =>
    WorkerExecution(
      workerExecutionId: json['workerExecutionId'] as String,
      workItemId: json['workItemId'] as String,
      repositoryPath: json['repositoryPath'] as String,
      requestedStartingRevision: json['requestedStartingRevision'] as String,
      requiredCapabilities: _workerCapabilitiesFromJson(
        json['requiredCapabilities'] as List?,
      ),
      status: $enumDecode(_$WorkerExecutionStatusEnumMap, json['status']),
      cleanupPolicy: $enumDecode(
        _$WorkerCleanupPolicyEnumMap,
        json['cleanupPolicy'],
      ),
      workerId: json['workerId'] as String?,
      workspaceId: json['workspaceId'] as String?,
      agentExecutionId: json['agentExecutionId'] as String?,
      resultId: json['resultId'] as String?,
      endingRevision: json['endingRevision'] as String?,
      cleanupStatus: $enumDecodeNullable(
        _$WorkerCleanupStatusEnumMap,
        json['cleanupStatus'],
      ),
      failureCode: _workerFailureCodeFromJson(json['failureCode'] as String?),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String),
      reason: json['reason'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$WorkerExecutionToJson(WorkerExecution instance) =>
    <String, dynamic>{
      'workerExecutionId': instance.workerExecutionId,
      'workItemId': instance.workItemId,
      'repositoryPath': instance.repositoryPath,
      'requestedStartingRevision': instance.requestedStartingRevision,
      'requiredCapabilities': ?_workerCapabilitiesToJson(
        instance.requiredCapabilities,
      ),
      'status': _$WorkerExecutionStatusEnumMap[instance.status]!,
      'cleanupPolicy': _$WorkerCleanupPolicyEnumMap[instance.cleanupPolicy]!,
      'workerId': ?instance.workerId,
      'workspaceId': ?instance.workspaceId,
      'agentExecutionId': ?instance.agentExecutionId,
      'resultId': ?instance.resultId,
      'endingRevision': ?instance.endingRevision,
      'cleanupStatus': ?_$WorkerCleanupStatusEnumMap[instance.cleanupStatus],
      'failureCode': ?_workerFailureCodeToJson(instance.failureCode),
      'createdAt': ?instance.createdAt?.toIso8601String(),
      'startedAt': ?instance.startedAt?.toIso8601String(),
      'endedAt': ?instance.endedAt?.toIso8601String(),
      'reason': ?instance.reason,
      'version': instance.version,
    };

const _$WorkerExecutionStatusEnumMap = {
  WorkerExecutionStatus.acquiring: 'acquiring',
  WorkerExecutionStatus.workspacePreparing: 'workspacePreparing',
  WorkerExecutionStatus.agentExecuting: 'agentExecuting',
  WorkerExecutionStatus.finalizing: 'finalizing',
  WorkerExecutionStatus.executedPass: 'executedPass',
  WorkerExecutionStatus.executedFail: 'executedFail',
  WorkerExecutionStatus.prepareFailed: 'prepareFailed',
  WorkerExecutionStatus.cancelled: 'cancelled',
  WorkerExecutionStatus.timedOut: 'timedOut',
  WorkerExecutionStatus.orphaned: 'orphaned',
};

const _$WorkerCleanupPolicyEnumMap = {
  WorkerCleanupPolicy.removeAlways: 'removeAlways',
  WorkerCleanupPolicy.preserveOnFailure: 'preserveOnFailure',
};

const _$WorkerCleanupStatusEnumMap = {
  WorkerCleanupStatus.notApplicable: 'notApplicable',
  WorkerCleanupStatus.pending: 'pending',
  WorkerCleanupStatus.removed: 'removed',
  WorkerCleanupStatus.preservedPerPolicy: 'preservedPerPolicy',
  WorkerCleanupStatus.cleanupFailed: 'cleanupFailed',
};
