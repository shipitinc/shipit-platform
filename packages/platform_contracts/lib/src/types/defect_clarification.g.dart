// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'defect_clarification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DefectClarification _$DefectClarificationFromJson(Map<String, dynamic> json) =>
    DefectClarification(
      clarificationId: json['clarificationId'] as String,
      defectId: json['defectId'] as String,
      question: json['question'] as String,
      reason: json['reason'] as String,
      status: json['status'] as String,
      answer: json['answer'] as String?,
      humanDecisionId: json['humanDecisionId'] as String?,
      requestedByTriageJobId: json['requestedByTriageJobId'] as String?,
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      answeredAt: json['answeredAt'] == null
          ? null
          : DateTime.parse(json['answeredAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$DefectClarificationToJson(
  DefectClarification instance,
) => <String, dynamic>{
  'clarificationId': instance.clarificationId,
  'defectId': instance.defectId,
  'question': instance.question,
  'reason': instance.reason,
  'status': instance.status,
  'answer': ?instance.answer,
  'humanDecisionId': ?instance.humanDecisionId,
  'requestedByTriageJobId': ?instance.requestedByTriageJobId,
  'requestedAt': instance.requestedAt.toIso8601String(),
  'answeredAt': ?instance.answeredAt?.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
};
