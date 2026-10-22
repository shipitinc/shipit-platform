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
    this.declaredOwnedPaths = const [],
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

  /// The repository-relative path globs the dispatched lane was GRANTED.
  ///
  /// ## WHAT IT IS, AND WHY IT IS NOT THE WORK'S CLAIM
  ///
  /// A grant, made before the work is known: the paths this lane may touch.
  /// It is not what the work item says it will touch — a claim the lane could
  /// make in its own favour is not a confinement, and judging a lane against
  /// its own claim would let a lane that lies in the claim pass its own gate.
  ///
  /// ## WHY IT TRAVELS ON THE REQUEST
  ///
  /// The capture happens at dispatch, and the dispatch request is the one thing
  /// that is in hand at that moment. From here the worker copies it onto the
  /// agent execution request (the worker's own production write path) and the
  /// execution coordinator captures it into the durable execution record, so
  /// the QA gate can read what the lane was dispatched with.
  ///
  /// ## EMPTY IS NOT "OWNS EVERYTHING"
  ///
  /// An empty list means the lane declared nothing, and the gate that judges
  /// the declaration refuses an empty owned set. This field never widens a
  /// gate.
  final List<String> declaredOwnedPaths;

  factory WorkerExecutionRequest.fromJson(Map<String, dynamic> json) =>
      _$WorkerExecutionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$WorkerExecutionRequestToJson(this);

  /// A copy of this request with the named fields replaced.
  ///
  /// ## WHY IT EXISTS
  ///
  /// A caller that must ADD one field to a request somebody else built — the
  /// composition root attaching the lane's path-ownership grant to the
  /// scheduler's request — cannot edit the builder, and rebuilding the request
  /// field by field would be a second, hand-maintained copy of the type: a
  /// field added to this class later would be silently dropped by that copy.
  /// One method, listing every field, is the copy that cannot drift.
  ///
  /// ## THE NULLABLE FIELDS
  ///
  /// A `null` argument means "keep what this request already has", so a
  /// nullable field cannot be CLEARED through `copyWith`. Nothing needs to clear
  /// one — the fields are `envAllowlist`, `environment`, `runtimeConfig` and
  /// `createdAt`, and the request they belong to is built once — and the
  /// alternative (a sentinel object per nullable field) would be four sentinels
  /// to carry for a case that does not occur.
  WorkerExecutionRequest copyWith({
    String? workerExecutionId,
    String? workItemId,
    String? repositoryPath,
    String? startingRevision,
    Set<WorkerCapability>? requiredCapabilities,
    AgentRole? role,
    String? instruction,
    int? timeoutSeconds,
    String? runtimeTypeId,
    List<ExpectedArtifact>? expectedArtifacts,
    WorkerCleanupPolicy? cleanupPolicy,
    List<String>? envAllowlist,
    Map<String, String>? environment,
    Map<String, String>? runtimeConfig,
    DateTime? createdAt,
    List<String>? excludedExecutionIds,
    List<String>? declaredOwnedPaths,
  }) {
    return WorkerExecutionRequest(
      workerExecutionId: workerExecutionId ?? this.workerExecutionId,
      workItemId: workItemId ?? this.workItemId,
      repositoryPath: repositoryPath ?? this.repositoryPath,
      startingRevision: startingRevision ?? this.startingRevision,
      requiredCapabilities: requiredCapabilities ?? this.requiredCapabilities,
      role: role ?? this.role,
      instruction: instruction ?? this.instruction,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      runtimeTypeId: runtimeTypeId ?? this.runtimeTypeId,
      expectedArtifacts: expectedArtifacts ?? this.expectedArtifacts,
      cleanupPolicy: cleanupPolicy ?? this.cleanupPolicy,
      envAllowlist: envAllowlist ?? this.envAllowlist,
      environment: environment ?? this.environment,
      runtimeConfig: runtimeConfig ?? this.runtimeConfig,
      createdAt: createdAt ?? this.createdAt,
      excludedExecutionIds: excludedExecutionIds ?? this.excludedExecutionIds,
      declaredOwnedPaths: declaredOwnedPaths ?? this.declaredOwnedPaths,
    );
  }

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
    declaredOwnedPaths,
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
