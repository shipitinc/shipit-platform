import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/agent_role.dart';
import '../enums/worker_capability.dart';
import '../enums/worker_cleanup_policy.dart';
import 'agent_execution_request.dart';

part 'worker_execution_request.g.dart';

/// A single runnable worker execution request: one repository starting at an
/// explicit committed revision, on a worker capable of the required tasks.
/// The request carries the *requirements*; the worker layer decides placement,
/// environment, and workspace lifecycle.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class WorkerExecutionRequest extends Equatable {
  const WorkerExecutionRequest({
    required this.workerExecutionId,
    required this.workItemId,
    required this.repositoryPath,
    required this.startingRevision,
    required this.requiredCapabilities,
    required this.role,
    required this.instruction,
    required this.timeoutSeconds,
    required this.runtimeTypeId,
    this.expectedArtifacts = const [],
    this.cleanupPolicy = WorkerCleanupPolicy.removeAlways,
    this.envAllowlist,
    this.environment,
    this.runtimeConfig,
    this.createdAt,
    this.excludedExecutionIds = const [],
  });

  final String workerExecutionId;
  final String workItemId;

  /// Path to the source checkout used as the git object/reference source. The
  /// agent never runs here; a worktree pinned to [startingRevision] is created.
  final String repositoryPath;

  /// Explicit committed revision the worktree must start at. Never the default
  /// branch HEAD at spawn time.
  final String startingRevision;

  /// Mandatory capability tokens; a worker lacking any of them cannot accept.
  @JsonKey(
    fromJson: _workerCapabilitiesFromJson,
    toJson: _workerCapabilitiesToJson,
  )
  final Set<WorkerCapability> requiredCapabilities;

  @JsonKey(fromJson: _agentRoleFromJson, toJson: _agentRoleToJson)
  final AgentRole role;

  /// Bounded natural-language task given to the coding agent.
  final String instruction;

  /// Bounded execution window owned by the agent/coordinator layer. See ADR
  /// 0015 for the layering of worker lease vs agent execution timeouts.
  final int timeoutSeconds;

  /// Provider-neutral runtime identifier (e.g. 'opencode').
  final String runtimeTypeId;

  final List<ExpectedArtifact> expectedArtifacts;
  final WorkerCleanupPolicy cleanupPolicy;

  /// Explicit variable names the worker layer may inherit from the host env.
  final List<String>? envAllowlist;

  /// Explicit runtime variables (never secrets) passed into the isolated
  /// execution environment.
  final Map<String, String>? environment;

  /// Opaque runtime configuration, e.g. {'executable': 'opencode', 'pure':
  /// 'true'}. Values are never interpreted by the worker layer.
  final Map<String, String>? runtimeConfig;
  final DateTime? createdAt;

  /// Execution IDs that MUST NOT be assigned this work (independence at
  /// dispatch for design reviews: exclude the designer's execution).
  final List<String> excludedExecutionIds;

  factory WorkerExecutionRequest.fromJson(Map<String, dynamic> json) =>
      _$WorkerExecutionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$WorkerExecutionRequestToJson(this);

  @override
  List<Object?> get props => [
    workerExecutionId,
    workItemId,
    repositoryPath,
    startingRevision,
    requiredCapabilities,
    role,
    instruction,
    timeoutSeconds,
    runtimeTypeId,
    expectedArtifacts,
    cleanupPolicy,
    envAllowlist,
    environment,
    runtimeConfig,
    createdAt,
    excludedExecutionIds,
  ];
}

AgentRole _agentRoleFromJson(String value) => AgentRole.fromWire(value);

String _agentRoleToJson(AgentRole value) => value.wire;

Set<WorkerCapability> _workerCapabilitiesFromJson(List<dynamic>? values) =>
    values == null
    ? const {}
    : values.map((v) => WorkerCapability.values.byName(v as String)).toSet();

List<String>? _workerCapabilitiesToJson(Set<WorkerCapability>? values) =>
    values?.map((v) => v.name).toList();
