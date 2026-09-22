// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'design_finding.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DesignFinding _$DesignFindingFromJson(Map<String, dynamic> json) =>
    DesignFinding(
      findingId: json['findingId'] as String,
      revisionId: json['revisionId'] as String,
      reviewExecutionId: json['reviewExecutionId'] as String,
      category: _$designFindingCategoryFromJson(json['category'] as String),
      severity: _$designFindingSeverityFromJson(json['severity'] as String),
      dimension: json['dimension'] as String,
      evidence: json['evidence'] as String,
      requiredCorrection: json['requiredCorrection'] as String,
      affectedSurface: json['affectedSurface'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      resolvedByRevisionId: json['resolvedByRevisionId'] as String?,
      version: (json['version'] as num).toInt(),
    );

Map<String, dynamic> _$DesignFindingToJson(DesignFinding instance) =>
    <String, dynamic>{
      'findingId': instance.findingId,
      'revisionId': instance.revisionId,
      'reviewExecutionId': instance.reviewExecutionId,
      'category': _$designFindingCategoryToJson(instance.category),
      'severity': _$designFindingSeverityToJson(instance.severity),
      'dimension': instance.dimension,
      'evidence': instance.evidence,
      'requiredCorrection': instance.requiredCorrection,
      'affectedSurface': instance.affectedSurface,
      'createdAt': instance.createdAt.toIso8601String(),
      'resolvedByRevisionId': ?instance.resolvedByRevisionId,
      'version': instance.version,
    };
