// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_baseline.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductBaseline _$ProductBaselineFromJson(Map<String, dynamic> json) =>
    ProductBaseline(
      baselineId: json['baselineId'] as String,
      productId: json['productId'] as String,
      revision: (json['revision'] as num).toInt(),
      status: json['status'] == null
          ? ProductBaselineStatus.proposed
          : _statusFromWire(json['status'] as String),
      facts: (json['facts'] as List<dynamic>)
          .map((e) => BaselineFact.fromJson(e as Map<String, dynamic>))
          .toList(),
      contentHash: json['contentHash'] as String,
      supersedesBaselineId: json['supersedesBaselineId'] as String?,
      proposedAt: json['proposedAt'] == null
          ? null
          : DateTime.parse(json['proposedAt'] as String),
      reviewedAt: json['reviewedAt'] == null
          ? null
          : DateTime.parse(json['reviewedAt'] as String),
      acceptedAt: json['acceptedAt'] == null
          ? null
          : DateTime.parse(json['acceptedAt'] as String),
      acceptedBy: json['acceptedBy'] as String?,
      acceptedDecisionId: json['acceptedDecisionId'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      version: (json['version'] as num?)?.toInt() ?? 1,
      contentHashVersion: (json['contentHashVersion'] as num?)?.toInt() ?? 1,
      verifiedAt: json['verifiedAt'] == null
          ? null
          : DateTime.parse(json['verifiedAt'] as String),
      verifiedBy: json['verifiedBy'] as String?,
      verificationKind: _kindFromWireOrNull(
        json['verificationKind'] as String?,
      ),
    );

Map<String, dynamic> _$ProductBaselineToJson(ProductBaseline instance) =>
    <String, dynamic>{
      'baselineId': instance.baselineId,
      'productId': instance.productId,
      'revision': instance.revision,
      'status': _statusToWire(instance.status),
      'facts': instance.facts.map((e) => e.toJson()).toList(),
      'contentHash': instance.contentHash,
      'supersedesBaselineId': ?instance.supersedesBaselineId,
      'proposedAt': ?instance.proposedAt?.toIso8601String(),
      'reviewedAt': ?instance.reviewedAt?.toIso8601String(),
      'acceptedAt': ?instance.acceptedAt?.toIso8601String(),
      'acceptedBy': ?instance.acceptedBy,
      'acceptedDecisionId': ?instance.acceptedDecisionId,
      'contentHashVersion': instance.contentHashVersion,
      'createdAt': ?instance.createdAt?.toIso8601String(),
      'updatedAt': ?instance.updatedAt?.toIso8601String(),
      'version': instance.version,
      'verifiedAt': ?instance.verifiedAt?.toIso8601String(),
      'verifiedBy': ?instance.verifiedBy,
      'verificationKind': ?_kindToWireOrNull(instance.verificationKind),
    };
