// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_execution.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentExecution _$AgentExecutionFromJson(Map<String, dynamic> json) =>
    AgentExecution(
      executionId: json['executionId'] as String,
      workItemId: json['workItemId'] as String,
      requestId: json['requestId'] as String,
      runtimeTypeId: json['runtimeTypeId'] as String,
      role: _agentRoleFromJson(json['role'] as String),
      status: $enumDecode(_$AgentSessionStatusEnumMap, json['status']),
      workspace: AgentWorkspace.fromJson(
        json['workspace'] as Map<String, dynamic>,
      ),
      sessionId: json['sessionId'] as String?,
      resultId: json['resultId'] as String?,
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      reason: json['reason'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      version: (json['version'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$AgentExecutionToJson(AgentExecution instance) =>
    <String, dynamic>{
      'executionId': instance.executionId,
      'workItemId': instance.workItemId,
      'requestId': instance.requestId,
      'runtimeTypeId': instance.runtimeTypeId,
      'role': _agentRoleToJson(instance.role),
      'status': _$AgentSessionStatusEnumMap[instance.status]!,
      'workspace': instance.workspace.toJson(),
      'sessionId': ?instance.sessionId,
      'resultId': ?instance.resultId,
      'startedAt': ?instance.startedAt?.toIso8601String(),
      'completedAt': ?instance.completedAt?.toIso8601String(),
      'reason': ?instance.reason,
      'metadata': ?instance.metadata,
      'version': instance.version,
    };

const _$AgentSessionStatusEnumMap = {
  AgentSessionStatus.starting: 'starting',
  AgentSessionStatus.running: 'running',
  AgentSessionStatus.completed: 'completed',
  AgentSessionStatus.failed: 'failed',
  AgentSessionStatus.cancelled: 'cancelled',
  AgentSessionStatus.interrupted: 'interrupted',
  AgentSessionStatus.orphaned: 'orphaned',
};
