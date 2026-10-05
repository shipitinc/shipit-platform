// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_execution_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ModelExecutionRecord _$ModelExecutionRecordFromJson(
  Map<String, dynamic> json,
) => ModelExecutionRecord(
  workItemId: json['workItemId'] as String,
  jobId: json['jobId'] as String,
  agentExecutionId: json['agentExecutionId'] as String,
  role: _agentRoleFromJson(json['role'] as String),
  modelId: json['modelId'] as String,
  provider: json['provider'] as String,
  inputTokens: (json['inputTokens'] as num).toInt(),
  outputTokens: (json['outputTokens'] as num).toInt(),
  totalTokens: (json['totalTokens'] as num).toInt(),
  cachedReadTokens: (json['cachedReadTokens'] as num).toInt(),
  costUsd: (json['costUsd'] as num).toDouble(),
  currency: json['currency'] as String,
  startedAt: DateTime.parse(json['startedAt'] as String),
  finishedAt: DateTime.parse(json['finishedAt'] as String),
  success: json['success'] as bool,
  error: json['error'] as String?,
  escalationIndex: (json['escalationIndex'] as num).toInt(),
  taskType: json['taskType'] as String,
);

Map<String, dynamic> _$ModelExecutionRecordToJson(
  ModelExecutionRecord instance,
) => <String, dynamic>{
  'workItemId': instance.workItemId,
  'jobId': instance.jobId,
  'agentExecutionId': instance.agentExecutionId,
  'role': _agentRoleToJson(instance.role),
  'modelId': instance.modelId,
  'provider': instance.provider,
  'inputTokens': instance.inputTokens,
  'outputTokens': instance.outputTokens,
  'totalTokens': instance.totalTokens,
  'cachedReadTokens': instance.cachedReadTokens,
  'costUsd': instance.costUsd,
  'currency': instance.currency,
  'startedAt': instance.startedAt.toIso8601String(),
  'finishedAt': instance.finishedAt.toIso8601String(),
  'success': instance.success,
  'error': instance.error,
  'escalationIndex': instance.escalationIndex,
  'taskType': instance.taskType,
};
