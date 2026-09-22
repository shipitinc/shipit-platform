// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'standing_policy.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StandingPolicy _$StandingPolicyFromJson(Map<String, dynamic> json) =>
    StandingPolicy(
      policyId: json['policyId'] as String,
      productId: json['productId'] as String,
      actions: _actionsFromWire(json['actions'] as List),
      authorisingDecisionId: json['authorisingDecisionId'] as String,
      authorisedBy: json['authorisedBy'] as String,
      rationale: json['rationale'] as String,
      authorisedAt: DateTime.parse(json['authorisedAt'] as String),
      revokedAt: json['revokedAt'] == null
          ? null
          : DateTime.parse(json['revokedAt'] as String),
      revokedBy: json['revokedBy'] as String?,
      revocationDecisionId: json['revocationDecisionId'] as String?,
      revocationReason: _reasonFromWireOrNull(
        json['revocationReason'] as String?,
      ),
      version: (json['version'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$StandingPolicyToJson(StandingPolicy instance) =>
    <String, dynamic>{
      'policyId': instance.policyId,
      'productId': instance.productId,
      'actions': _actionsToWire(instance.actions),
      'authorisingDecisionId': instance.authorisingDecisionId,
      'authorisedBy': instance.authorisedBy,
      'rationale': instance.rationale,
      'authorisedAt': instance.authorisedAt.toIso8601String(),
      'revokedAt': ?instance.revokedAt?.toIso8601String(),
      'revokedBy': ?instance.revokedBy,
      'revocationDecisionId': ?instance.revocationDecisionId,
      'revocationReason': ?_reasonToWireOrNull(instance.revocationReason),
      'version': instance.version,
    };
