import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/agent_role.dart';

part 'model_execution_record.g.dart';

@JsonSerializable(explicitToJson: true)
@immutable
class ModelExecutionRecord extends Equatable {
  const ModelExecutionRecord({
    required this.workItemId,
    required this.jobId,
    required this.agentExecutionId,
    required this.role,
    required this.modelId,
    required this.provider,
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
    required this.cachedReadTokens,
    required this.costUsd,
    required this.currency,
    required this.startedAt,
    required this.finishedAt,
    required this.success,
    required this.error,
    required this.escalationIndex,
    required this.taskType,
  });

  final String workItemId;
  final String jobId;
  final String agentExecutionId;
  @JsonKey(fromJson: _agentRoleFromJson, toJson: _agentRoleToJson)
  final AgentRole role;
  final String modelId;
  final String provider;
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;
  final int cachedReadTokens;
  final double costUsd;
  final String currency;
  final DateTime startedAt;
  final DateTime finishedAt;
  final bool success;
  final String? error;
  final int escalationIndex;
  final String taskType;

  factory ModelExecutionRecord.fromJson(Map<String, dynamic> json) =>
      _$ModelExecutionRecordFromJson(json);
  Map<String, dynamic> toJson() => _$ModelExecutionRecordToJson(this);

  @override
  List<Object?> get props => [
    workItemId,
    jobId,
    agentExecutionId,
    role,
    modelId,
    provider,
    inputTokens,
    outputTokens,
    totalTokens,
    cachedReadTokens,
    costUsd,
    currency,
    startedAt,
    finishedAt,
    success,
    error,
    escalationIndex,
    taskType,
  ];
}

AgentRole _agentRoleFromJson(String value) => AgentRole.fromWire(value);
String _agentRoleToJson(AgentRole value) => value.wire;
