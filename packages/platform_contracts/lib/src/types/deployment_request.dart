import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'deployment_request.g.dart';

@JsonSerializable(explicitToJson: true)
@immutable
class DeploymentRequest extends Equatable {
  const DeploymentRequest({
    required this.requestId,
    required this.workItemId,
    required this.artifactId,
    required this.targetEnvironment,
    required this.promotionPath,
    required this.requestedBy,
    this.humanDecisionId,
    required this.requestedAt,
    this.config,
    this.metadata,
  });

  final String requestId;
  final String workItemId;
  final String artifactId;
  final String targetEnvironment;
  final List<String> promotionPath;
  final String requestedBy;
  final String? humanDecisionId;
  final DateTime requestedAt;
  final Map<String, dynamic>? config;
  final Map<String, dynamic>? metadata;

  factory DeploymentRequest.fromJson(Map<String, dynamic> json) =>
      _$DeploymentRequestFromJson(json);

  Map<String, dynamic> toJson() => _$DeploymentRequestToJson(this);

  @override
  List<Object?> get props => [
    requestId,
    workItemId,
    artifactId,
    targetEnvironment,
    promotionPath,
    requestedBy,
    humanDecisionId,
    requestedAt,
    config,
    metadata,
  ];
}
