import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'job_execution_reference.g.dart';

const Object _unset = Object();

/// Reference from a scheduled [Job] to the underlying, durably-recorded worker
/// execution. The chain is WorkItem -> Job -> WorkerExecution -> AgentExecution
/// -> AgentResult -> PlatformVerification -> artifacts. References never
/// duplicate the record they point at: a screwdriver follows the id.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class JobExecutionReference extends Equatable {
  const JobExecutionReference({
    required this.workerExecutionId,
    required this.createdAt,
    this.agentExecutionId,
    this.resultId,
  });

  final String workerExecutionId;
  final String? agentExecutionId;
  final String? resultId;
  final DateTime createdAt;

  factory JobExecutionReference.fromJson(Map<String, dynamic> json) =>
      _$JobExecutionReferenceFromJson(json);

  Map<String, dynamic> toJson() => _$JobExecutionReferenceToJson(this);

  /// The chain is filled in progressively: the scheduler stamps
  /// [workerExecutionId] when it dispatches (before the worker runs), then
  /// stamps [agentExecutionId] when it adopts the terminal outcome. Nullable
  /// links use the same explicit-`null` sentinel as [Job.copyWith], so a link
  /// that becomes unknown can be cleared rather than silently retained.
  JobExecutionReference copyWith({
    String? workerExecutionId,
    DateTime? createdAt,
    Object? agentExecutionId = _unset,
    Object? resultId = _unset,
  }) {
    return JobExecutionReference(
      workerExecutionId: workerExecutionId ?? this.workerExecutionId,
      createdAt: createdAt ?? this.createdAt,
      agentExecutionId: identical(agentExecutionId, _unset)
          ? this.agentExecutionId
          : agentExecutionId as String?,
      resultId: identical(resultId, _unset)
          ? this.resultId
          : resultId as String?,
    );
  }

  @override
  List<Object?> get props => [
    workerExecutionId,
    agentExecutionId,
    resultId,
    createdAt,
  ];
}
