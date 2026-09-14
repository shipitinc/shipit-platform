import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/agent_role.dart';
import '../enums/agent_session_status.dart';
import 'agent_execution_request.dart';

part 'agent_execution.g.dart';

const Object _unset = Object();

/// Durable record of one agent execution, distinct from the WorkItem and from
/// any runtime session. The runtime/session identifier lives here, never on
/// the WorkItem.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class AgentExecution extends Equatable {
  const AgentExecution({
    required this.executionId,
    required this.workItemId,
    required this.requestId,
    required this.runtimeTypeId,
    required this.role,
    required this.status,
    required this.workspace,
    this.sessionId,
    this.resultId,
    this.startedAt,
    this.completedAt,
    this.reason,
    this.metadata,
    this.version = 1,
  });

  final String executionId;
  final String workItemId;
  final String requestId;
  final String runtimeTypeId;
  @JsonKey(fromJson: _agentRoleFromJson, toJson: _agentRoleToJson)
  final AgentRole role;
  final AgentSessionStatus status;
  final AgentWorkspace workspace;
  final String? sessionId;
  final String? resultId;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? reason;
  final Map<String, dynamic>? metadata;
  @JsonKey(defaultValue: 1)
  final int version;

  bool get isTerminal =>
      status == AgentSessionStatus.completed ||
      status == AgentSessionStatus.failed ||
      status == AgentSessionStatus.cancelled ||
      status == AgentSessionStatus.interrupted ||
      status == AgentSessionStatus.orphaned;

  factory AgentExecution.fromJson(Map<String, dynamic> json) =>
      _$AgentExecutionFromJson(json);

  Map<String, dynamic> toJson() => _$AgentExecutionToJson(this);

  AgentExecution copyWith({
    String? executionId,
    String? workItemId,
    String? requestId,
    String? runtimeTypeId,
    AgentRole? role,
    AgentSessionStatus? status,
    AgentWorkspace? workspace,
    Object? sessionId = _unset,
    Object? resultId = _unset,
    DateTime? startedAt,
    DateTime? completedAt,
    Object? reason = _unset,
    Map<String, dynamic>? metadata,
    int? version,
  }) {
    return AgentExecution(
      executionId: executionId ?? this.executionId,
      workItemId: workItemId ?? this.workItemId,
      requestId: requestId ?? this.requestId,
      runtimeTypeId: runtimeTypeId ?? this.runtimeTypeId,
      role: role ?? this.role,
      status: status ?? this.status,
      workspace: workspace ?? this.workspace,
      sessionId: identical(sessionId, _unset)
          ? this.sessionId
          : sessionId as String?,
      resultId: identical(resultId, _unset)
          ? this.resultId
          : resultId as String?,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      reason: identical(reason, _unset) ? this.reason : reason as String?,
      metadata: metadata ?? this.metadata,
      version: version ?? this.version,
    );
  }

  @override
  List<Object?> get props => [
    executionId,
    workItemId,
    requestId,
    runtimeTypeId,
    role,
    status,
    workspace,
    sessionId,
    resultId,
    startedAt,
    completedAt,
    reason,
    metadata,
    version,
  ];
}

AgentRole _agentRoleFromJson(String value) => AgentRole.fromWire(value);

String _agentRoleToJson(AgentRole value) => value.wire;
