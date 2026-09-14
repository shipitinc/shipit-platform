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

Map<String, dynamic> _$WorkerExecutionToJson(
  WorkerExecution instance,
) => <String, dynamic>{
  'workerExecutionId': instance.workerExecutionId,
  'workItemId': instance.workItemId,
  'repositoryPath': instance.repositoryPath,
  'requestedStartingRevision': instance.requestedStartingRevision,
  if (_workerCapabilitiesToJson(instance.requiredCapabilities)
      case final value?)
    'requiredCapabilities': value,
  'status': _$WorkerExecutionStatusEnumMap[instance.status]!,
  'cleanupPolicy': _$WorkerCleanupPolicyEnumMap[instance.cleanupPolicy]!,
  if (instance.workerId case final value?) 'workerId': value,
  if (instance.workspaceId case final value?) 'workspaceId': value,
  if (instance.agentExecutionId case final value?) 'agentExecutionId': value,
  if (instance.resultId case final value?) 'resultId': value,
  if (instance.endingRevision case final value?) 'endingRevision': value,
  if (_$WorkerCleanupStatusEnumMap[instance.cleanupStatus] case final value?)
    'cleanupStatus': value,
  if (_workerFailureCodeToJson(instance.failureCode) case final value?)
    'failureCode': value,
  if (instance.createdAt?.toIso8601String() case final value?)
    'createdAt': value,
  if (instance.startedAt?.toIso8601String() case final value?)
    'startedAt': value,
  if (instance.endedAt?.toIso8601String() case final value?) 'endedAt': value,
  if (instance.reason case final value?) 'reason': value,
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
