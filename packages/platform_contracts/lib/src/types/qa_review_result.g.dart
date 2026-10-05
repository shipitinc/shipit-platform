// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qa_review_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QaReviewResult _$QaReviewResultFromJson(Map<String, dynamic> json) =>
    QaReviewResult(
      reviewExecutionId: json['reviewExecutionId'] as String,
      workItemId: json['workItemId'] as String,
      verdict: _reviewVerdictFromJson(json['verdict'] as String),
      findings: (json['findings'] as List<dynamic>)
          .map((e) => DesignFinding.fromJson(e as Map<String, dynamic>))
          .toList(),
      assessedDimensions: (json['assessedDimensions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      reviewScopeJson: json['reviewScopeJson'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      version: (json['version'] as num).toInt(),
      reviewerRole: _agentRoleFromJson(json['reviewerRole'] as String),
    );

Map<String, dynamic> _$QaReviewResultToJson(QaReviewResult instance) =>
    <String, dynamic>{
      'reviewExecutionId': instance.reviewExecutionId,
      'workItemId': instance.workItemId,
      'verdict': _reviewVerdictToJson(instance.verdict),
      'findings': instance.findings.map((e) => e.toJson()).toList(),
      'assessedDimensions': instance.assessedDimensions,
      'reviewScopeJson': ?instance.reviewScopeJson,
      'createdAt': instance.createdAt.toIso8601String(),
      'version': instance.version,
      'reviewerRole': _agentRoleToJson(instance.reviewerRole),
    };
