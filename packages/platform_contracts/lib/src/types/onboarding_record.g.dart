// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OnboardingRecord _$OnboardingRecordFromJson(Map<String, dynamic> json) =>
    OnboardingRecord(
      onboardingId: json['onboardingId'] as String,
      productId: json['productId'] as String,
      currentBaselineRevision:
          (json['currentBaselineRevision'] as num?)?.toInt() ?? 0,
      pendingClarifications:
          (json['pendingClarifications'] as num?)?.toInt() ?? 0,
      completed: json['completed'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      version: (json['version'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$OnboardingRecordToJson(OnboardingRecord instance) =>
    <String, dynamic>{
      'onboardingId': instance.onboardingId,
      'productId': instance.productId,
      'currentBaselineRevision': instance.currentBaselineRevision,
      'pendingClarifications': instance.pendingClarifications,
      'completed': instance.completed,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'version': instance.version,
    };
