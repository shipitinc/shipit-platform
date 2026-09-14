import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/worker_capability.dart';
import '../enums/worker_execution_status.dart';
import '../enums/worker_cleanup_policy.dart';
import '../enums/worker_cleanup_status.dart';
import '../enums/worker_failure_code.dart';

part 'worker_execution.g.dart';

const Object _unset = Object();

/// Durable record of one worker execution. Distinct from the [WorkItem], the
/// [AgentExecution], and the runtime session. Persisted by the worker layer
/// for resume/reconciliation and audit.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class WorkerExecution extends Equatable {
  const WorkerExecution({
    required this.workerExecutionId,
    required this.workItemId,
    required this.repositoryPath,
    required this.requestedStartingRevision,
    required this.requiredCapabilities,
    required this.status,
    required this.cleanupPolicy,
    this.workerId,
    this.workspaceId,
    this.agentExecutionId,
    this.resultId,
    this.endingRevision,
    this.cleanupStatus,
    this.failureCode,
    this.createdAt,
    this.startedAt,
    this.endedAt,
    this.reason,
    this.version = 1,
  });

  final String workerExecutionId;
  final String workItemId;
  final String repositoryPath;
  final String requestedStartingRevision;
  @JsonKey(
    fromJson: _workerCapabilitiesFromJson,
    toJson: _workerCapabilitiesToJson,
  )
  final Set<WorkerCapability> requiredCapabilities;
  final WorkerExecutionStatus status;
  final WorkerCleanupPolicy cleanupPolicy;
  final String? workerId;
  final String? workspaceId;
  final String? agentExecutionId;
  final String? resultId;

  /// Revision the execution's worktree reached at the end.
  final String? endingRevision;
  final WorkerCleanupStatus? cleanupStatus;
  @JsonKey(
    fromJson: _workerFailureCodeFromJson,
    toJson: _workerFailureCodeToJson,
  )
  final WorkerFailureCode? failureCode;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? reason;
  @JsonKey(defaultValue: 1)
  final int version;

  bool get isTerminal => status.isTerminal;

  bool get cleanupMissing =>
      status.isTerminal &&
      (cleanupStatus == null || cleanupStatus == WorkerCleanupStatus.pending);

  factory WorkerExecution.fromJson(Map<String, dynamic> json) =>
      _$WorkerExecutionFromJson(json);

  Map<String, dynamic> toJson() => _$WorkerExecutionToJson(this);

  WorkerExecution copyWith({
    String? workerExecutionId,
    String? workItemId,
    String? repositoryPath,
    String? requestedStartingRevision,
    Set<WorkerCapability>? requiredCapabilities,
    WorkerExecutionStatus? status,
    WorkerCleanupPolicy? cleanupPolicy,
    Object? workerId = _unset,
    Object? workspaceId = _unset,
    Object? agentExecutionId = _unset,
    Object? resultId = _unset,
    Object? endingRevision = _unset,
    Object? cleanupStatus = _unset,
    Object? failureCode = _unset,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    Object? reason = _unset,
    int? version,
  }) {
    return WorkerExecution(
      workerExecutionId: workerExecutionId ?? this.workerExecutionId,
      workItemId: workItemId ?? this.workItemId,
      repositoryPath: repositoryPath ?? this.repositoryPath,
      requestedStartingRevision:
          requestedStartingRevision ?? this.requestedStartingRevision,
      requiredCapabilities: requiredCapabilities ?? this.requiredCapabilities,
      status: status ?? this.status,
      cleanupPolicy: cleanupPolicy ?? this.cleanupPolicy,
      workerId: identical(workerId, _unset)
          ? this.workerId
          : workerId as String?,
      workspaceId: identical(workspaceId, _unset)
          ? this.workspaceId
          : workspaceId as String?,
      agentExecutionId: identical(agentExecutionId, _unset)
          ? this.agentExecutionId
          : agentExecutionId as String?,
      resultId: identical(resultId, _unset)
          ? this.resultId
          : resultId as String?,
      endingRevision: identical(endingRevision, _unset)
          ? this.endingRevision
          : endingRevision as String?,
      cleanupStatus: identical(cleanupStatus, _unset)
          ? this.cleanupStatus
          : cleanupStatus as WorkerCleanupStatus?,
      failureCode: identical(failureCode, _unset)
          ? this.failureCode
          : failureCode as WorkerFailureCode?,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      reason: identical(reason, _unset) ? this.reason : reason as String?,
      version: version ?? this.version,
    );
  }

  @override
  List<Object?> get props => [
    workerExecutionId,
    workItemId,
    repositoryPath,
    requestedStartingRevision,
    requiredCapabilities,
    status,
    cleanupPolicy,
    workerId,
    workspaceId,
    agentExecutionId,
    resultId,
    endingRevision,
    cleanupStatus,
    failureCode,
    createdAt,
    startedAt,
    endedAt,
    reason,
    version,
  ];
}

WorkerFailureCode? _workerFailureCodeFromJson(String? value) =>
    value == null ? null : WorkerFailureCode.values.byName(value);

String? _workerFailureCodeToJson(WorkerFailureCode? value) => value?.name;

Set<WorkerCapability> _workerCapabilitiesFromJson(List<dynamic>? values) =>
    values == null
    ? const {}
    : values.map((v) => WorkerCapability.values.byName(v as String)).toSet();

List<String>? _workerCapabilitiesToJson(Set<WorkerCapability>? values) =>
    values?.map((v) => v.name).toList();
