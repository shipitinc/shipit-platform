import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'job_execution_reference.g.dart';

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

  @override
  List<Object?> get props => [
    workerExecutionId,
    agentExecutionId,
    resultId,
    createdAt,
  ];
}
