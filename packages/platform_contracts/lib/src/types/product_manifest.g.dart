// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_manifest.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductManifest _$ProductManifestFromJson(Map<String, dynamic> json) =>
    ProductManifest(
      productId: json['productId'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      description: json['description'] as String?,
      capabilities: (json['capabilities'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      environments: (json['environments'] as List<dynamic>)
          .map((e) => EnvironmentConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      contracts: ProductContracts.fromJson(
        json['contracts'] as Map<String, dynamic>,
      ),
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$ProductManifestToJson(ProductManifest instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'name': instance.name,
      'version': instance.version,
      'description': instance.description,
      'capabilities': instance.capabilities,
      'environments': instance.environments.map((e) => e.toJson()).toList(),
      'contracts': instance.contracts.toJson(),
      'metadata': instance.metadata,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

EnvironmentConfig _$EnvironmentConfigFromJson(Map<String, dynamic> json) =>
    EnvironmentConfig(
      name: json['name'] as String,
      type: json['type'] as String,
      config: json['config'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$EnvironmentConfigToJson(EnvironmentConfig instance) =>
    <String, dynamic>{
      'name': instance.name,
      'type': instance.type,
      'config': instance.config,
    };

ProductContracts _$ProductContractsFromJson(Map<String, dynamic> json) =>
    ProductContracts(
      workItemCategories: (json['workItemCategories'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      designContract: DesignContractSpec.fromJson(
        json['designContract'] as Map<String, dynamic>,
      ),
      qaContract: QAContractSpec.fromJson(
        json['qaContract'] as Map<String, dynamic>,
      ),
      deploymentContract: DeploymentContractSpec.fromJson(
        json['deploymentContract'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$ProductContractsToJson(ProductContracts instance) =>
    <String, dynamic>{
      'workItemCategories': instance.workItemCategories,
      'designContract': instance.designContract.toJson(),
      'qaContract': instance.qaContract.toJson(),
      'deploymentContract': instance.deploymentContract.toJson(),
    };

DesignContractSpec _$DesignContractSpecFromJson(Map<String, dynamic> json) =>
    DesignContractSpec(
      requiredArtifacts: (json['requiredArtifacts'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      reviewers: (json['reviewers'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      approvalThreshold: (json['approvalThreshold'] as num).toInt(),
    );

Map<String, dynamic> _$DesignContractSpecToJson(DesignContractSpec instance) =>
    <String, dynamic>{
      'requiredArtifacts': instance.requiredArtifacts,
      'reviewers': instance.reviewers,
      'approvalThreshold': instance.approvalThreshold,
    };

QAContractSpec _$QAContractSpecFromJson(Map<String, dynamic> json) =>
    QAContractSpec(
      gates: (json['gates'] as List<dynamic>)
          .map((e) => QAGateSpec.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$QAContractSpecToJson(QAContractSpec instance) =>
    <String, dynamic>{'gates': instance.gates.map((e) => e.toJson()).toList()};

QAGateSpec _$QAGateSpecFromJson(Map<String, dynamic> json) => QAGateSpec(
  gateId: json['gateId'] as String,
  type: json['type'] as String,
  required: json['required'] as bool,
  config: json['config'] as Map<String, dynamic>,
);

Map<String, dynamic> _$QAGateSpecToJson(QAGateSpec instance) =>
    <String, dynamic>{
      'gateId': instance.gateId,
      'type': instance.type,
      'required': instance.required,
      'config': instance.config,
    };

DeploymentContractSpec _$DeploymentContractSpecFromJson(
  Map<String, dynamic> json,
) => DeploymentContractSpec(
  promotionPath: (json['promotionPath'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  approvalGates: (json['approvalGates'] as List<dynamic>)
      .map((e) => ApprovalGateSpec.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$DeploymentContractSpecToJson(
  DeploymentContractSpec instance,
) => <String, dynamic>{
  'promotionPath': instance.promotionPath,
  'approvalGates': instance.approvalGates.map((e) => e.toJson()).toList(),
};

ApprovalGateSpec _$ApprovalGateSpecFromJson(Map<String, dynamic> json) =>
    ApprovalGateSpec(
      environment: json['environment'] as String,
      approvers: (json['approvers'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      threshold: (json['threshold'] as num).toInt(),
    );

Map<String, dynamic> _$ApprovalGateSpecToJson(ApprovalGateSpec instance) =>
    <String, dynamic>{
      'environment': instance.environment,
      'approvers': instance.approvers,
      'threshold': instance.threshold,
    };
