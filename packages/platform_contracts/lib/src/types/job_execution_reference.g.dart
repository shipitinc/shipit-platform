// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_execution_reference.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JobExecutionReference _$JobExecutionReferenceFromJson(
  Map<String, dynamic> json,
) => JobExecutionReference(
  workerExecutionId: json['workerExecutionId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  agentExecutionId: json['agentExecutionId'] as String?,
  resultId: json['resultId'] as String?,
);

Map<String, dynamic> _$JobExecutionReferenceToJson(
  JobExecutionReference instance,
) => <String, dynamic>{
  'workerExecutionId': instance.workerExecutionId,
  if (instance.agentExecutionId case final value?) 'agentExecutionId': value,
  if (instance.resultId case final value?) 'resultId': value,
  'createdAt': instance.createdAt.toIso8601String(),
};
