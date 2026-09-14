// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_execution_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkerExecutionResult _$WorkerExecutionResultFromJson(
  Map<String, dynamic> json,
) => WorkerExecutionResult(
  workerExecutionId: json['workerExecutionId'] as String,
  workItemId: json['workItemId'] as String,
  status: $enumDecode(_$WorkerExecutionStatusEnumMap, json['status']),
  startingRevision: json['startingRevision'] as String,
  workerId: json['workerId'] as String,
  workspaceId: json['workspaceId'] as String,
  startedAt: DateTime.parse(json['startedAt'] as String),
  endedAt: DateTime.parse(json['endedAt'] as String),
  cleanupStatus: $enumDecode(
    _$WorkerCleanupStatusEnumMap,
    json['cleanupStatus'],
  ),
  failureCode: $enumDecode(_$WorkerFailureCodeEnumMap, json['failureCode']),
  agentExecutionId: json['agentExecutionId'] as String?,
  agentResultStatus: $enumDecodeNullable(
    _$AgentResultStatusEnumMap,
    json['agentResultStatus'],
  ),
  verificationId: json['verificationId'] as String?,
  verificationPassed: json['verificationPassed'] as bool?,
  endingRevision: json['endingRevision'] as String?,
  changedFiles:
      (json['changedFiles'] as List<dynamic>?)
          ?.map((e) => ChangedFile.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  diffSummary: json['diffSummary'] as String?,
  diffRef: json['diffRef'] as String?,
  failureDetail: json['failureDetail'] as String?,
);

Map<String, dynamic> _$WorkerExecutionResultToJson(
  WorkerExecutionResult instance,
) => <String, dynamic>{
  'workerExecutionId': instance.workerExecutionId,
  'workItemId': instance.workItemId,
  'status': _$WorkerExecutionStatusEnumMap[instance.status]!,
  'workerId': instance.workerId,
  'workspaceId': instance.workspaceId,
  'startingRevision': instance.startingRevision,
  if (instance.endingRevision case final value?) 'endingRevision': value,
  if (instance.agentExecutionId case final value?) 'agentExecutionId': value,
  if (_$AgentResultStatusEnumMap[instance.agentResultStatus] case final value?)
    'agentResultStatus': value,
  if (instance.verificationId case final value?) 'verificationId': value,
  if (instance.verificationPassed case final value?)
    'verificationPassed': value,
  'changedFiles': instance.changedFiles.map((e) => e.toJson()).toList(),
  if (instance.diffSummary case final value?) 'diffSummary': value,
  if (instance.diffRef case final value?) 'diffRef': value,
  'cleanupStatus': _$WorkerCleanupStatusEnumMap[instance.cleanupStatus]!,
  'failureCode': _$WorkerFailureCodeEnumMap[instance.failureCode]!,
  if (instance.failureDetail case final value?) 'failureDetail': value,
  'startedAt': instance.startedAt.toIso8601String(),
  'endedAt': instance.endedAt.toIso8601String(),
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

const _$WorkerCleanupStatusEnumMap = {
  WorkerCleanupStatus.notApplicable: 'notApplicable',
  WorkerCleanupStatus.pending: 'pending',
  WorkerCleanupStatus.removed: 'removed',
  WorkerCleanupStatus.preservedPerPolicy: 'preservedPerPolicy',
  WorkerCleanupStatus.cleanupFailed: 'cleanupFailed',
};

const _$WorkerFailureCodeEnumMap = {
  WorkerFailureCode.none: 'none',
  WorkerFailureCode.noCompatibleWorker: 'noCompatibleWorker',
  WorkerFailureCode.prepareFailed: 'prepareFailed',
  WorkerFailureCode.agentFailed: 'agentFailed',
  WorkerFailureCode.timedOut: 'timedOut',
  WorkerFailureCode.cancelled: 'cancelled',
  WorkerFailureCode.cleanupFailed: 'cleanupFailed',
};

const _$AgentResultStatusEnumMap = {
  AgentResultStatus.completed: 'completed',
  AgentResultStatus.failed: 'failed',
  AgentResultStatus.cancelled: 'cancelled',
  AgentResultStatus.partial: 'partial',
};
