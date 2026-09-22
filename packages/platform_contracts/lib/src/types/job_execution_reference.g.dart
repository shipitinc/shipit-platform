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
  'agentExecutionId': ?instance.agentExecutionId,
  'resultId': ?instance.resultId,
  'createdAt': instance.createdAt.toIso8601String(),
};
