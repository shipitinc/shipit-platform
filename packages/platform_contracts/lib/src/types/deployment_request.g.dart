// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deployment_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeploymentRequest _$DeploymentRequestFromJson(Map<String, dynamic> json) =>
    DeploymentRequest(
      requestId: json['requestId'] as String,
      workItemId: json['workItemId'] as String,
      artifactId: json['artifactId'] as String,
      targetEnvironment: json['targetEnvironment'] as String,
      promotionPath: (json['promotionPath'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      requestedBy: json['requestedBy'] as String,
      humanDecisionId: json['humanDecisionId'] as String?,
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      config: json['config'] as Map<String, dynamic>?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$DeploymentRequestToJson(DeploymentRequest instance) =>
    <String, dynamic>{
      'requestId': instance.requestId,
      'workItemId': instance.workItemId,
      'artifactId': instance.artifactId,
      'targetEnvironment': instance.targetEnvironment,
      'promotionPath': instance.promotionPath,
      'requestedBy': instance.requestedBy,
      'humanDecisionId': instance.humanDecisionId,
      'requestedAt': instance.requestedAt.toIso8601String(),
      'config': instance.config,
      'metadata': instance.metadata,
    };
