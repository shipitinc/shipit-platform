import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/agent_role.dart';

part 'agent_execution_request.g.dart';

/// Explicit, typed execution scope for a single agent run.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class AgentWorkspace extends Equatable {
  const AgentWorkspace({
    required this.workspaceId,
    required this.path,
    this.startingRevision,
    this.allowedPaths,
  });

  final String workspaceId;
  final String path;
  final String? startingRevision;

  /// Absolute path prefixes the agent may operate on. A null value means the
  /// workspace root itself is the only permitted scope.
  final List<String>? allowedPaths;

  factory AgentWorkspace.fromJson(Map<String, dynamic> json) =>
      _$AgentWorkspaceFromJson(json);

  Map<String, dynamic> toJson() => _$AgentWorkspaceToJson(this);

  @override
  List<Object?> get props => [
    workspaceId,
    path,
    startingRevision,
    allowedPaths,
  ];
}

/// A typed artifact the execution is expected to produce.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class ExpectedArtifact extends Equatable {
  const ExpectedArtifact({
    required this.description,
    this.pathPattern,
    this.required = false,
  });

  final String description;
  final String? pathPattern;
  final bool required;

  factory ExpectedArtifact.fromJson(Map<String, dynamic> json) =>
      _$ExpectedArtifactFromJson(json);

  Map<String, dynamic> toJson() => _$ExpectedArtifactToJson(this);

  @override
  List<Object?> get props => [description, pathPattern, required];
}

/// Structured input to one agent execution. Provider/model selection is
/// carried in [runtimeConfig], never in workflow contracts.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class AgentExecutionRequest extends Equatable {
  const AgentExecutionRequest({
    required this.executionId,
    required this.workItemId,
    required this.role,
    required this.runtimeTypeId,
    required this.workspace,
    required this.instruction,
    required this.timeoutSeconds,
    this.permittedScope,
    this.expectedResult,
    this.expectedArtifacts = const [],
    this.runtimeConfig,
    this.environment,
    this.createdAt,
  });

  final String executionId;
  final String workItemId;
  @JsonKey(fromJson: _agentRoleFromJson, toJson: _agentRoleToJson)
  final AgentRole role;

  /// Provider-neutral runtime identifier (e.g. 'opencode').
  final String runtimeTypeId;
  final AgentWorkspace workspace;
  final String instruction;
  final int timeoutSeconds;

  /// Free-text description of the bounded task scope.
  final String? permittedScope;

  /// Expected structured result contract (e.g. AEF result_type/status).
  final Map<String, dynamic>? expectedResult;
  final List<ExpectedArtifact> expectedArtifacts;

  /// Runtime configuration, e.g. {'model': <provider-model>}, {'executable':
  /// <path>}. Values are opaque to the workflow layer.
  final Map<String, String>? runtimeConfig;

  /// Explicit runtime variables (never production secrets) the worker layer
  /// derived from its environment policy. Recorded for traceability.
  final Map<String, String>? environment;
  final DateTime? createdAt;

  factory AgentExecutionRequest.fromJson(Map<String, dynamic> json) =>
      _$AgentExecutionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$AgentExecutionRequestToJson(this);

  @override
  List<Object?> get props => [
    executionId,
    workItemId,
    role,
    runtimeTypeId,
    workspace,
    instruction,
    timeoutSeconds,
    permittedScope,
    expectedResult,
    expectedArtifacts,
    runtimeConfig,
    environment,
    createdAt,
  ];
}

AgentRole _agentRoleFromJson(String value) => AgentRole.fromWire(value);

String _agentRoleToJson(AgentRole value) => value.wire;
