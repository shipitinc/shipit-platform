import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/defect_status.dart';
import '../enums/defect_classification.dart';

part 'triage_result.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class DefectClarificationRequest extends Equatable {
  const DefectClarificationRequest({
    required this.question,
    required this.reason,
  });

  final String question;
  final String reason;

  factory DefectClarificationRequest.fromJson(Map<String, dynamic> json) =>
      _$DefectClarificationRequestFromJson(json);

  Map<String, dynamic> toJson() => _$DefectClarificationRequestToJson(this);

  @override
  List<Object?> get props => [question, reason];
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class TriageResult extends Equatable {
  const TriageResult({
    required this.recommendedStatus,
    required this.recommendedClassification,
    required this.confidence,
    required this.suspectedCategory,
    required this.suspectedComponents,
    required this.reproductionSupported,
    required this.evidenceUsed,
    required this.clarificationRequired,
    required this.recommendedNextAction,
    this.possibleDuplicateDefectId,
    this.recommendedWorkItemCategory,
    required this.summary,
  });

  @JsonKey(fromJson: _defectStatusFromJson, toJson: _defectStatusToJson)
  final DefectStatus recommendedStatus;
  @JsonKey(
    fromJson: _defectClassificationFromJson,
    toJson: _defectClassificationToJson,
  )
  final DefectClassification recommendedClassification;
  final double confidence;
  final String suspectedCategory;
  final List<String> suspectedComponents;
  final bool reproductionSupported;
  final List<String> evidenceUsed;
  final List<DefectClarificationRequest> clarificationRequired;
  final String recommendedNextAction;
  final String? possibleDuplicateDefectId;
  final String? recommendedWorkItemCategory;
  final String summary;

  factory TriageResult.fromJson(Map<String, dynamic> json) =>
      _$TriageResultFromJson(json);

  Map<String, dynamic> toJson() => _$TriageResultToJson(this);

  @override
  List<Object?> get props => [
        recommendedStatus,
        recommendedClassification,
        confidence,
        suspectedCategory,
        suspectedComponents,
        reproductionSupported,
        evidenceUsed,
        clarificationRequired,
        recommendedNextAction,
        possibleDuplicateDefectId,
        recommendedWorkItemCategory,
        summary,
      ];
}

DefectStatus _defectStatusFromJson(String value) => DefectStatus.fromWire(value);

String _defectStatusToJson(DefectStatus value) => value.wire;

DefectClassification _defectClassificationFromJson(String value) =>
    DefectClassification.fromWire(value);

String _defectClassificationToJson(DefectClassification value) => value.wire;