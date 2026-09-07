// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deployment_contract.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeploymentContract _$DeploymentContractFromJson(Map<String, dynamic> json) =>
    DeploymentContract(
      contractId: json['contractId'] as String,
      workItemId: json['workItemId'] as String,
      promotionPath: (json['promotionPath'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      approvalGates: (json['approvalGates'] as List<dynamic>)
          .map(
            (e) => DeploymentApprovalGate.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$DeploymentContractToJson(DeploymentContract instance) =>
    <String, dynamic>{
      'contractId': instance.contractId,
      'workItemId': instance.workItemId,
      'promotionPath': instance.promotionPath,
      'approvalGates': instance.approvalGates.map((e) => e.toJson()).toList(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'metadata': instance.metadata,
    };

DeploymentApprovalGate _$DeploymentApprovalGateFromJson(
  Map<String, dynamic> json,
) => DeploymentApprovalGate(
  environment: json['environment'] as String,
  approvers: (json['approvers'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  threshold: (json['threshold'] as num).toInt(),
);

Map<String, dynamic> _$DeploymentApprovalGateToJson(
  DeploymentApprovalGate instance,
) => <String, dynamic>{
  'environment': instance.environment,
  'approvers': instance.approvers,
  'threshold': instance.threshold,
};
