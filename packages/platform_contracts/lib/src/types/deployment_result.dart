import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/deployment_status.dart';

part 'deployment_result.g.dart';

@JsonSerializable(explicitToJson: true)
@immutable
class DeploymentResult extends Equatable {
  const DeploymentResult({
    required this.resultId,
    required this.requestId,
    required this.deploymentId,
    required this.artifactId,
    required this.targetId,
    required this.environment,
    required this.status,
    required this.deployedAt,
    this.completedAt,
    required this.healthChecks,
    this.urls,
    this.version,
    this.rollbackOf,
    this.metrics,
    this.error,
    this.metadata,
  });

  final String resultId;
  final String requestId;
  final String deploymentId;
  final String artifactId;
  final String targetId;
  final String environment;
  @JsonKey(fromJson: _deploymentStatusFromJson, toJson: _deploymentStatusToJson)
  final DeploymentStatus status;
  final DateTime deployedAt;
  final DateTime? completedAt;
  final List<HealthCheckResult> healthChecks;
  final List<DeploymentUrl>? urls;
  final String? version;
  final String? rollbackOf;
  final DeploymentMetrics? metrics;
  final DeploymentError? error;
  final Map<String, dynamic>? metadata;

  factory DeploymentResult.fromJson(Map<String, dynamic> json) =>
      _$DeploymentResultFromJson(json);

  Map<String, dynamic> toJson() => _$DeploymentResultToJson(this);

  @override
  List<Object?> get props => [
    resultId,
    requestId,
    deploymentId,
    artifactId,
    targetId,
    environment,
    status,
    deployedAt,
    completedAt,
    healthChecks,
    urls,
    version,
    rollbackOf,
    metrics,
    error,
    metadata,
  ];
}

@JsonSerializable(explicitToJson: true)
@immutable
class HealthCheckResult extends Equatable {
  const HealthCheckResult({
    required this.name,
    required this.status,
    required this.checkedAt,
    this.details,
    this.url,
  });

  final String name;
  final String status;
  final DateTime checkedAt;
  final Map<String, dynamic>? details;
  final String? url;

  factory HealthCheckResult.fromJson(Map<String, dynamic> json) =>
      _$HealthCheckResultFromJson(json);

  Map<String, dynamic> toJson() => _$HealthCheckResultToJson(this);

  @override
  List<Object?> get props => [name, status, checkedAt, details, url];
}

@JsonSerializable(explicitToJson: true)
@immutable
class DeploymentUrl extends Equatable {
  const DeploymentUrl({required this.name, required this.url, this.type});

  final String name;
  final String url;
  final String? type;

  factory DeploymentUrl.fromJson(Map<String, dynamic> json) =>
      _$DeploymentUrlFromJson(json);

  Map<String, dynamic> toJson() => _$DeploymentUrlToJson(this);

  @override
  List<Object?> get props => [name, url, type];
}

@JsonSerializable(explicitToJson: true)
@immutable
class DeploymentMetrics extends Equatable {
  const DeploymentMetrics({
    this.deploymentDurationMs,
    this.healthCheckDurationMs,
    this.resourceUsage,
  });

  final int? deploymentDurationMs;
  final int? healthCheckDurationMs;
  final ResourceUsageMetrics? resourceUsage;

  factory DeploymentMetrics.fromJson(Map<String, dynamic> json) =>
      _$DeploymentMetricsFromJson(json);

  Map<String, dynamic> toJson() => _$DeploymentMetricsToJson(this);

  @override
  List<Object?> get props => [
    deploymentDurationMs,
    healthCheckDurationMs,
    resourceUsage,
  ];
}

@JsonSerializable(explicitToJson: true)
@immutable
class ResourceUsageMetrics extends Equatable {
  const ResourceUsageMetrics({
    this.cpuPercent,
    this.memoryMb,
    this.requestsPerSecond,
  });

  final double? cpuPercent;
  final int? memoryMb;
  final double? requestsPerSecond;

  factory ResourceUsageMetrics.fromJson(Map<String, dynamic> json) =>
      _$ResourceUsageMetricsFromJson(json);

  Map<String, dynamic> toJson() => _$ResourceUsageMetricsToJson(this);

  @override
  List<Object?> get props => [cpuPercent, memoryMb, requestsPerSecond];
}

@JsonSerializable(explicitToJson: true)
@immutable
class DeploymentError extends Equatable {
  const DeploymentError({
    required this.code,
    required this.message,
    this.details,
    this.recoverable,
  });

  final String code;
  final String message;
  final Map<String, dynamic>? details;
  final bool? recoverable;

  factory DeploymentError.fromJson(Map<String, dynamic> json) =>
      _$DeploymentErrorFromJson(json);

  Map<String, dynamic> toJson() => _$DeploymentErrorToJson(this);

  @override
  List<Object?> get props => [code, message, details, recoverable];
}

DeploymentStatus _deploymentStatusFromJson(String value) =>
    value == 'rolled_back'
    ? DeploymentStatus.rolledBack
    : DeploymentStatus.values.byName(value);

String _deploymentStatusToJson(DeploymentStatus value) =>
    value == DeploymentStatus.rolledBack ? 'rolled_back' : value.name;
