// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'design_revision.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DesignRevision _$DesignRevisionFromJson(Map<String, dynamic> json) =>
    DesignRevision(
      revisionId: json['revisionId'] as String,
      workItemId: json['workItemId'] as String,
      productId: json['productId'] as String,
      parentRevisionId: json['parentRevisionId'] as String?,
      designSystemRevision: json['designSystemRevision'] as String,
      provider: _$designProviderTypeFromJson(json['provider'] as String),
      penpotFileId: json['penpotFileId'] as String?,
      penpotPageId: json['penpotPageId'] as String?,
      boardIdsJson: json['boardIdsJson'] as String,
      responsiveTargetsJson: json['responsiveTargetsJson'] as String,
      statesRepresentedJson: json['statesRepresentedJson'] as String,
      artifactRefsJson: json['artifactRefsJson'] as String,
      designerExecutionId: json['designerExecutionId'] as String,
      reviewExecutionIdsJson: json['reviewExecutionIdsJson'] as String,
      status: _$designRevisionStatusFromJson(json['status'] as String),
      riskTier: _$designRiskTierFromJson(json['riskTier'] as String),
      reviewScopeJson: json['reviewScopeJson'] as Map<String, dynamic>?,
      carriedForwardFromRevisionId:
          json['carriedForwardFromRevisionId'] as String?,
      supersededByRevisionId: json['supersededByRevisionId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      approvedAt: json['approvedAt'] == null
          ? null
          : DateTime.parse(json['approvedAt'] as String),
      version: (json['version'] as num).toInt(),
    );

Map<String, dynamic> _$DesignRevisionToJson(DesignRevision instance) =>
    <String, dynamic>{
      'revisionId': instance.revisionId,
      'workItemId': instance.workItemId,
      'productId': instance.productId,
      'parentRevisionId': instance.parentRevisionId,
      'designSystemRevision': instance.designSystemRevision,
      'provider': _$designProviderTypeToJson(instance.provider),
      'penpotFileId': instance.penpotFileId,
      'penpotPageId': instance.penpotPageId,
      'boardIdsJson': instance.boardIdsJson,
      'responsiveTargetsJson': instance.responsiveTargetsJson,
      'statesRepresentedJson': instance.statesRepresentedJson,
      'artifactRefsJson': instance.artifactRefsJson,
      'designerExecutionId': instance.designerExecutionId,
      'reviewExecutionIdsJson': instance.reviewExecutionIdsJson,
      'status': _$designRevisionStatusToJson(instance.status),
      'riskTier': _$designRiskTierToJson(instance.riskTier),
      'reviewScopeJson': ?instance.reviewScopeJson,
      'carriedForwardFromRevisionId': ?instance.carriedForwardFromRevisionId,
      'supersededByRevisionId': ?instance.supersededByRevisionId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'approvedAt': ?instance.approvedAt?.toIso8601String(),
      'version': instance.version,
    };
