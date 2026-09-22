// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clarification_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClarificationRequest _$ClarificationRequestFromJson(
  Map<String, dynamic> json,
) => ClarificationRequest(
  clarificationId: json['clarificationId'] as String,
  productId: json['productId'] as String,
  onboardingId: json['onboardingId'] as String,
  section: _sectionFromWire(json['section'] as String),
  question: json['question'] as String,
  status: json['status'] == null
      ? ClarificationStatus.needsAnswer
      : _statusFromWire(json['status'] as String),
  answer: json['answer'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  answeredAt: json['answeredAt'] == null
      ? null
      : DateTime.parse(json['answeredAt'] as String),
  answeredBy: json['answeredBy'] as String?,
);

Map<String, dynamic> _$ClarificationRequestToJson(
  ClarificationRequest instance,
) => <String, dynamic>{
  'clarificationId': instance.clarificationId,
  'productId': instance.productId,
  'onboardingId': instance.onboardingId,
  'section': _sectionToWire(instance.section),
  'question': instance.question,
  'status': _statusToWire(instance.status),
  'answer': ?instance.answer,
  'createdAt': instance.createdAt.toIso8601String(),
  'answeredAt': ?instance.answeredAt?.toIso8601String(),
  'answeredBy': ?instance.answeredBy,
};
