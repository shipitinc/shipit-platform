import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/agent_role.dart';
import '../enums/job_failure.dart';
import '../enums/job_priority.dart';
import '../enums/job_state.dart';
import '../enums/job_type.dart';
import '../enums/worker_capability.dart';
import 'job_execution_reference.dart';

part 'job.g.dart';

const Object _unset = Object();

/// A single durable, disposable unit of scheduled work.
///
/// The job is the durable realization of "this work item is runnable and its
/// execution is missing". It carries only scheduling-relevant facts (role,
/// capability requirements, priority, idempotency identity, attempt bounds)
/// plus REFERENCES to the underlying worker execution; it never embeds the
/// full [WorkItem] and never carries workflow policy.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class Job extends Equatable {
  const Job({
    required this.jobId,
    required this.workItemId,
    required this.jobType,
    required this.requiredRole,
    required this.requiredCapabilities,
    required this.priority,
    required this.state,
    required this.dedupeKey,
    required this.createdAt,
    required this.instruction,
    required this.attempt,
    required this.maxAttempts,
    required this.version,
    this.availableAt,
    this.startedAt,
    this.completedAt,
    this.executionReference,
    this.workerId,
    this.failure,
    this.cancelReason,
  });

  final String jobId;
  final String workItemId;
  @JsonKey(fromJson: _jobTypeFromJson, toJson: _jobTypeToJson)
  final JobType jobType;
  @JsonKey(fromJson: _agentRoleFromJson, toJson: _agentRoleToJson)
  final AgentRole requiredRole;
  @JsonKey(
    fromJson: _workerCapabilitiesFromJson,
    toJson: _workerCapabilitiesToJson,
  )
  final Set<WorkerCapability> requiredCapabilities;
  @JsonKey(fromJson: _jobPriorityFromJson, toJson: _jobPriorityToJson)
  final JobPriority priority;
  @JsonKey(fromJson: _jobStateFromJson, toJson: _jobStateToJson)
  final JobState state;

  /// Stable identity used to enqueue idempotently: re-evaluating UNCHANGED
  /// workflow state never creates a second job. Encodes the origin
  /// (work item + workflow state + job type + role). Derived from persisted
  /// workflow state, never from volatile agent output.
  final String dedupeKey;

  final DateTime createdAt;

  /// Not eligible to be claimed before this instant (queue scheduling and
  /// bounded retry backoff).
  final DateTime? availableAt;

  /// The natural-language task for the bounded agent execution.
  final String instruction;

  /// Number of times this job has started an execution (1-based on first run).
  final int attempt;

  /// Hard bound on executions per job; only transient failures may consume
  /// retries and never more than this.
  final int maxAttempts;

  final DateTime? startedAt;
  final DateTime? completedAt;

  /// Reference to the underlying worker execution once dispatched.
  final JobExecutionReference? executionReference;
  final String? workerId;
  final JobFailure? failure;
  final String? cancelReason;
  final int version;

  /// Operational lifecycle is exhausted and no further claims may be taken.
  bool get isTerminal => state.isTerminal;

  factory Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);

  Map<String, dynamic> toJson() => _$JobToJson(this);

  Job copyWith({
    String? jobId,
    String? workItemId,
    JobType? jobType,
    AgentRole? requiredRole,
    Set<WorkerCapability>? requiredCapabilities,
    JobPriority? priority,
    JobState? state,
    String? dedupeKey,
    DateTime? createdAt,
    Object? availableAt = _unset,
    String? instruction,
    int? attempt,
    int? maxAttempts,
    Object? startedAt = _unset,
    Object? completedAt = _unset,
    Object? executionReference = _unset,
    Object? workerId = _unset,
    Object? failure = _unset,
    Object? cancelReason = _unset,
    int? version,
  }) {
    return Job(
      jobId: jobId ?? this.jobId,
      workItemId: workItemId ?? this.workItemId,
      jobType: jobType ?? this.jobType,
      requiredRole: requiredRole ?? this.requiredRole,
      requiredCapabilities: requiredCapabilities ?? this.requiredCapabilities,
      priority: priority ?? this.priority,
      state: state ?? this.state,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      createdAt: createdAt ?? this.createdAt,
      availableAt: identical(availableAt, _unset)
          ? this.availableAt
          : availableAt as DateTime?,
      instruction: instruction ?? this.instruction,
      attempt: attempt ?? this.attempt,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      startedAt: identical(startedAt, _unset)
          ? this.startedAt
          : startedAt as DateTime?,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
      executionReference: identical(executionReference, _unset)
          ? this.executionReference
          : executionReference as JobExecutionReference?,
      workerId: identical(workerId, _unset)
          ? this.workerId
          : workerId as String?,
      failure: identical(failure, _unset)
          ? this.failure
          : failure as JobFailure?,
      cancelReason: identical(cancelReason, _unset)
          ? this.cancelReason
          : cancelReason as String?,
      version: version ?? this.version,
    );
  }

  @override
  List<Object?> get props => [
    jobId,
    workItemId,
    jobType,
    requiredRole,
    requiredCapabilities,
    priority,
    state,
    dedupeKey,
    createdAt,
    availableAt,
    instruction,
    attempt,
    maxAttempts,
    startedAt,
    completedAt,
    executionReference,
    workerId,
    failure,
    cancelReason,
    version,
  ];
}

/// Bounded terminal failure detail of a job, kept inside the job record so a
/// screwdriver reads a terminal job without a second lookup.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class JobFailure extends Equatable {
  const JobFailure({required this.code, required this.kind, this.reason});

  @JsonKey(fromJson: _jobFailureCodeFromJson, toJson: _jobFailureCodeToJson)
  final JobFailureCode code;
  @JsonKey(fromJson: _jobFailureKindFromJson, toJson: _jobFailureKindToJson)
  final JobFailureKind kind;
  final String? reason;

  factory JobFailure.fromJson(Map<String, dynamic> json) =>
      _$JobFailureFromJson(json);

  Map<String, dynamic> toJson() => _$JobFailureToJson(this);

  @override
  List<Object?> get props => [code, kind, reason];
}

JobType _jobTypeFromJson(String value) => JobType.fromWire(value);

String _jobTypeToJson(JobType value) => value.wire;

AgentRole _agentRoleFromJson(String value) => AgentRole.fromWire(value);

String _agentRoleToJson(AgentRole value) => value.wire;

JobPriority _jobPriorityFromJson(String value) =>
    JobPriority.values.byName(value);

String _jobPriorityToJson(JobPriority value) => value.name;

JobState _jobStateFromJson(String value) => JobState.fromWire(value);

String _jobStateToJson(JobState value) => value.wire;

JobFailureCode _jobFailureCodeFromJson(String value) =>
    JobFailureCode.values.byName(value);

String _jobFailureCodeToJson(JobFailureCode value) => value.name;

JobFailureKind _jobFailureKindFromJson(String value) =>
    JobFailureKind.values.byName(value);

String _jobFailureKindToJson(JobFailureKind value) => value.name;

Set<WorkerCapability> _workerCapabilitiesFromJson(List<dynamic>? values) =>
    values == null
    ? const {}
    : values.map((v) => WorkerCapability.values.byName(v as String)).toSet();

List<String>? _workerCapabilitiesToJson(Set<WorkerCapability>? values) =>
    values?.map((v) => v.name).toList();
