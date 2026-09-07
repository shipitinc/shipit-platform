import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'deployment_contract.g.dart';

@JsonSerializable(explicitToJson: true)
@immutable
class DeploymentContract extends Equatable {
  const DeploymentContract({
    required this.contractId,
    required this.workItemId,
    required this.promotionPath,
    required this.approvalGates,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  final String contractId;
  final String workItemId;
  final List<String> promotionPath;
  final List<DeploymentApprovalGate> approvalGates;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  factory DeploymentContract.fromJson(Map<String, dynamic> json) =>
      _$DeploymentContractFromJson(json);

  Map<String, dynamic> toJson() => _$DeploymentContractToJson(this);

  @override
  List<Object?> get props => [
    contractId,
    workItemId,
    promotionPath,
    approvalGates,
    createdAt,
    updatedAt,
    metadata,
  ];
}

@JsonSerializable(explicitToJson: true)
@immutable
class DeploymentApprovalGate extends Equatable {
  const DeploymentApprovalGate({
    required this.environment,
    required this.approvers,
    required this.threshold,
  });

  final String environment;
  final List<String> approvers;
  final int threshold;

  factory DeploymentApprovalGate.fromJson(Map<String, dynamic> json) =>
      _$DeploymentApprovalGateFromJson(json);

  Map<String, dynamic> toJson() => _$DeploymentApprovalGateToJson(this);

  @override
  List<Object?> get props => [environment, approvers, threshold];
}
