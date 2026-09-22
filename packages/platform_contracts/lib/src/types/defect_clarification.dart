import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'defect_clarification.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class DefectClarification extends Equatable {
  const DefectClarification({
    required this.clarificationId,
    required this.defectId,
    required this.question,
    required this.reason,
    required this.status,
    this.answer,
    this.humanDecisionId,
    this.requestedByTriageJobId,
    required this.requestedAt,
    this.answeredAt,
    required this.createdAt,
  });

  final String clarificationId;
  final String defectId;
  final String question;
  final String reason;
  final String status; // 'pending' or 'answered'
  final String? answer;
  final String? humanDecisionId;
  final String? requestedByTriageJobId;
  final DateTime requestedAt;
  final DateTime? answeredAt;
  final DateTime createdAt;

  factory DefectClarification.fromJson(Map<String, dynamic> json) =>
      _$DefectClarificationFromJson(json);

  Map<String, dynamic> toJson() => _$DefectClarificationToJson(this);

  @override
  List<Object?> get props => [
        clarificationId,
        defectId,
        question,
        reason,
        status,
        answer,
        humanDecisionId,
        requestedByTriageJobId,
        requestedAt,
        answeredAt,
        createdAt,
      ];
}