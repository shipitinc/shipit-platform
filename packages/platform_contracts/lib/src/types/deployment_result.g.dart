// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deployment_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeploymentResult _$DeploymentResultFromJson(Map<String, dynamic> json) =>
    DeploymentResult(
      resultId: json['resultId'] as String,
      requestId: json['requestId'] as String,
      deploymentId: json['deploymentId'] as String,
      artifactId: json['artifactId'] as String,
      targetId: json['targetId'] as String,
      environment: json['environment'] as String,
      status: _deploymentStatusFromJson(json['status'] as String),
      deployedAt: DateTime.parse(json['deployedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      healthChecks: (json['healthChecks'] as List<dynamic>)
          .map((e) => HealthCheckResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      urls: (json['urls'] as List<dynamic>?)
          ?.map((e) => DeploymentUrl.fromJson(e as Map<String, dynamic>))
          .toList(),
      version: json['version'] as String?,
      rollbackOf: json['rollbackOf'] as String?,
      metrics: json['metrics'] == null
          ? null
          : DeploymentMetrics.fromJson(json['metrics'] as Map<String, dynamic>),
      error: json['error'] == null
          ? null
          : DeploymentError.fromJson(json['error'] as Map<String, dynamic>),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$DeploymentResultToJson(DeploymentResult instance) =>
    <String, dynamic>{
      'resultId': instance.resultId,
      'requestId': instance.requestId,
      'deploymentId': instance.deploymentId,
      'artifactId': instance.artifactId,
      'targetId': instance.targetId,
      'environment': instance.environment,
      'status': _deploymentStatusToJson(instance.status),
      'deployedAt': instance.deployedAt.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'healthChecks': instance.healthChecks.map((e) => e.toJson()).toList(),
      'urls': instance.urls?.map((e) => e.toJson()).toList(),
      'version': instance.version,
      'rollbackOf': instance.rollbackOf,
      'metrics': instance.metrics?.toJson(),
      'error': instance.error?.toJson(),
      'metadata': instance.metadata,
    };

HealthCheckResult _$HealthCheckResultFromJson(Map<String, dynamic> json) =>
    HealthCheckResult(
      name: json['name'] as String,
      status: json['status'] as String,
      checkedAt: DateTime.parse(json['checkedAt'] as String),
      details: json['details'] as Map<String, dynamic>?,
      url: json['url'] as String?,
    );

Map<String, dynamic> _$HealthCheckResultToJson(HealthCheckResult instance) =>
    <String, dynamic>{
      'name': instance.name,
      'status': instance.status,
      'checkedAt': instance.checkedAt.toIso8601String(),
      'details': instance.details,
      'url': instance.url,
    };

DeploymentUrl _$DeploymentUrlFromJson(Map<String, dynamic> json) =>
    DeploymentUrl(
      name: json['name'] as String,
      url: json['url'] as String,
      type: json['type'] as String?,
    );

Map<String, dynamic> _$DeploymentUrlToJson(DeploymentUrl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'url': instance.url,
      'type': instance.type,
    };

DeploymentMetrics _$DeploymentMetricsFromJson(Map<String, dynamic> json) =>
    DeploymentMetrics(
      deploymentDurationMs: (json['deploymentDurationMs'] as num?)?.toInt(),
      healthCheckDurationMs: (json['healthCheckDurationMs'] as num?)?.toInt(),
      resourceUsage: json['resourceUsage'] == null
          ? null
          : ResourceUsageMetrics.fromJson(
              json['resourceUsage'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$DeploymentMetricsToJson(DeploymentMetrics instance) =>
    <String, dynamic>{
      'deploymentDurationMs': instance.deploymentDurationMs,
      'healthCheckDurationMs': instance.healthCheckDurationMs,
      'resourceUsage': instance.resourceUsage?.toJson(),
    };

ResourceUsageMetrics _$ResourceUsageMetricsFromJson(
  Map<String, dynamic> json,
) => ResourceUsageMetrics(
  cpuPercent: (json['cpuPercent'] as num?)?.toDouble(),
  memoryMb: (json['memoryMb'] as num?)?.toInt(),
  requestsPerSecond: (json['requestsPerSecond'] as num?)?.toDouble(),
);

Map<String, dynamic> _$ResourceUsageMetricsToJson(
  ResourceUsageMetrics instance,
) => <String, dynamic>{
  'cpuPercent': instance.cpuPercent,
  'memoryMb': instance.memoryMb,
  'requestsPerSecond': instance.requestsPerSecond,
};

DeploymentError _$DeploymentErrorFromJson(Map<String, dynamic> json) =>
    DeploymentError(
      code: json['code'] as String,
      message: json['message'] as String,
      details: json['details'] as Map<String, dynamic>?,
      recoverable: json['recoverable'] as bool?,
    );

Map<String, dynamic> _$DeploymentErrorToJson(DeploymentError instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'details': instance.details,
      'recoverable': instance.recoverable,
    };
