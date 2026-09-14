import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/agent_result_status.dart';
import '../enums/worker_execution_status.dart';
import '../enums/worker_cleanup_status.dart';
import '../enums/worker_failure_code.dart';
import 'agent_result.dart';

part 'worker_execution_result.g.dart';

/// Typed terminal outcome of a worker execution. Preserves both halves of the
/// verification story: what the agent did ([agentResultStatus]) and what the
/// platform independently found ([verificationPassed]) are carried separately
/// and never conflated.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class WorkerExecutionResult extends Equatable {
  const WorkerExecutionResult({
    required this.workerExecutionId,
    required this.workItemId,
    required this.status,
    required this.startingRevision,
    required this.workerId,
    required this.workspaceId,
    required this.startedAt,
    required this.endedAt,
    required this.cleanupStatus,
    required this.failureCode,
    this.agentExecutionId,
    this.agentResultStatus,
    this.verificationId,
    this.verificationPassed,
    this.endingRevision,
    this.changedFiles = const [],
    this.diffSummary,
    this.diffRef,
    this.failureDetail,
  });

  final String workerExecutionId;
  final String workItemId;
  final WorkerExecutionStatus status;
  final String workerId;
  final String workspaceId;
  final String startingRevision;
  final String? endingRevision;
  final String? agentExecutionId;

  /// Mirrors the durable [AgentResult.status]; never rewritten because the
  /// platform's verification disagreed.
  final AgentResultStatus? agentResultStatus;
  final String? verificationId;
  final bool? verificationPassed;

  /// Git-observed file changes (the platform's view, not the agent's claims).
  final List<ChangedFile> changedFiles;
  final String? diffSummary;
  final String? diffRef;
  final WorkerCleanupStatus cleanupStatus;
  final WorkerFailureCode failureCode;
  final String? failureDetail;
  final DateTime startedAt;
  final DateTime endedAt;

  factory WorkerExecutionResult.fromJson(Map<String, dynamic> json) =>
      _$WorkerExecutionResultFromJson(json);

  Map<String, dynamic> toJson() => _$WorkerExecutionResultToJson(this);

  @override
  List<Object?> get props => [
    workerExecutionId,
    workItemId,
    status,
    workerId,
    workspaceId,
    startingRevision,
    endingRevision,
    agentExecutionId,
    agentResultStatus,
    verificationId,
    verificationPassed,
    changedFiles,
    diffSummary,
    diffRef,
    cleanupStatus,
    failureCode,
    failureDetail,
    startedAt,
    endedAt,
  ];
}
