// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'design_review_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DesignReviewResult _$DesignReviewResultFromJson(Map<String, dynamic> json) =>
    DesignReviewResult(
      reviewExecutionId: json['reviewExecutionId'] as String,
      revisionId: json['revisionId'] as String,
      verdict: _$designReviewVerdictFromJson(json['verdict'] as String),
      findings: (json['findings'] as List<dynamic>)
          .map((e) => DesignFinding.fromJson(e as Map<String, dynamic>))
          .toList(),
      assessedDimensions: (json['assessedDimensions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      reviewScopeJson: json['reviewScopeJson'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      version: (json['version'] as num).toInt(),
    );

Map<String, dynamic> _$DesignReviewResultToJson(DesignReviewResult instance) =>
    <String, dynamic>{
      'reviewExecutionId': instance.reviewExecutionId,
      'revisionId': instance.revisionId,
      'verdict': _$designReviewVerdictToJson(instance.verdict),
      'findings': instance.findings.map((e) => e.toJson()).toList(),
      'assessedDimensions': instance.assessedDimensions,
      'reviewScopeJson': ?instance.reviewScopeJson,
      'createdAt': instance.createdAt.toIso8601String(),
      'version': instance.version,
    };
