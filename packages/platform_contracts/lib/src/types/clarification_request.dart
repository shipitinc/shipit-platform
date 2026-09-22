import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/clarification_status.dart';
import '../enums/baseline_section_key.dart';

part 'clarification_request.g.dart';

/// Durable clarification: onboarding stopped because material information is
/// unknown. The stop survives process restart; a new execution resumes the
/// same Product/onboarding/baseline lineage after the human answers
/// (checkpoint 006 §uncertainty/clarification).
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class ClarificationRequest extends Equatable {
  const ClarificationRequest({
    required this.clarificationId,
    required this.productId,
    required this.onboardingId,
    required this.section,
    required this.question,
    this.status = ClarificationStatus.needsAnswer,
    this.answer,
    required this.createdAt,
    this.answeredAt,
    this.answeredBy,
  });

  final String clarificationId;
  final String productId;
  final String onboardingId;

  /// Baseline section the clarification targets (provenance gap).
  @JsonKey(fromJson: _sectionFromWire, toJson: _sectionToWire)
  final BaselineSectionKey section;

  final String question;
  @JsonKey(fromJson: _statusFromWire, toJson: _statusToWire)
  final ClarificationStatus status;

  /// Human answer; once set the onboarding may resume.
  final String? answer;

  final DateTime createdAt;
  final DateTime? answeredAt;
  final String? answeredBy;

  ClarificationRequest copyWith({
    ClarificationStatus? status,
    String? answer,
    DateTime? answeredAt,
    String? answeredBy,
  }) => ClarificationRequest(
    clarificationId: clarificationId,
    productId: productId,
    onboardingId: onboardingId,
    section: section,
    question: question,
    status: status ?? this.status,
    answer: answer ?? this.answer,
    createdAt: createdAt,
    answeredAt: answeredAt ?? this.answeredAt,
    answeredBy: answeredBy ?? this.answeredBy,
  );

  factory ClarificationRequest.fromJson(Map<String, dynamic> json) =>
      _$ClarificationRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ClarificationRequestToJson(this);

  @override
  List<Object?> get props => [
    clarificationId,
    productId,
    onboardingId,
    section,
    question,
    status,
    answer,
    createdAt,
    answeredAt,
    answeredBy,
  ];
}

BaselineSectionKey _sectionFromWire(String value) =>
    BaselineSectionKey.fromWire(value);

String _sectionToWire(BaselineSectionKey value) => value.wire;

ClarificationStatus _statusFromWire(String value) =>
    ClarificationStatus.fromWire(value);

String _statusToWire(ClarificationStatus value) => value.wire;
