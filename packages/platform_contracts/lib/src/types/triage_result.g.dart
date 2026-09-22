// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'triage_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DefectClarificationRequest _$DefectClarificationRequestFromJson(
  Map<String, dynamic> json,
) => DefectClarificationRequest(
  question: json['question'] as String,
  reason: json['reason'] as String,
);

Map<String, dynamic> _$DefectClarificationRequestToJson(
  DefectClarificationRequest instance,
) => <String, dynamic>{
  'question': instance.question,
  'reason': instance.reason,
};

TriageResult _$TriageResultFromJson(Map<String, dynamic> json) => TriageResult(
  recommendedStatus: _defectStatusFromJson(json['recommendedStatus'] as String),
  recommendedClassification: _defectClassificationFromJson(
    json['recommendedClassification'] as String,
  ),
  confidence: (json['confidence'] as num).toDouble(),
  suspectedCategory: json['suspectedCategory'] as String,
  suspectedComponents: (json['suspectedComponents'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  reproductionSupported: json['reproductionSupported'] as bool,
  evidenceUsed: (json['evidenceUsed'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  clarificationRequired: (json['clarificationRequired'] as List<dynamic>)
      .map(
        (e) => DefectClarificationRequest.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
  recommendedNextAction: json['recommendedNextAction'] as String,
  possibleDuplicateDefectId: json['possibleDuplicateDefectId'] as String?,
  recommendedWorkItemCategory: json['recommendedWorkItemCategory'] as String?,
  summary: json['summary'] as String,
);

Map<String, dynamic> _$TriageResultToJson(TriageResult instance) =>
    <String, dynamic>{
      'recommendedStatus': _defectStatusToJson(instance.recommendedStatus),
      'recommendedClassification': _defectClassificationToJson(
        instance.recommendedClassification,
      ),
      'confidence': instance.confidence,
      'suspectedCategory': instance.suspectedCategory,
      'suspectedComponents': instance.suspectedComponents,
      'reproductionSupported': instance.reproductionSupported,
      'evidenceUsed': instance.evidenceUsed,
      'clarificationRequired': instance.clarificationRequired
          .map((e) => e.toJson())
          .toList(),
      'recommendedNextAction': instance.recommendedNextAction,
      'possibleDuplicateDefectId': ?instance.possibleDuplicateDefectId,
      'recommendedWorkItemCategory': ?instance.recommendedWorkItemCategory,
      'summary': instance.summary,
    };
