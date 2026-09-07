import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'product_manifest.g.dart';

@JsonSerializable(explicitToJson: true)
@immutable
class ProductManifest extends Equatable {
  const ProductManifest({
    required this.productId,
    required this.name,
    required this.version,
    this.description,
    required this.capabilities,
    required this.environments,
    required this.contracts,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  final String productId;
  final String name;
  final String version;
  final String? description;
  final List<String> capabilities;
  final List<EnvironmentConfig> environments;
  final ProductContracts contracts;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProductManifest.fromJson(Map<String, dynamic> json) =>
      _$ProductManifestFromJson(json);

  Map<String, dynamic> toJson() => _$ProductManifestToJson(this);

  @override
  List<Object?> get props => [
    productId,
    name,
    version,
    description,
    capabilities,
    environments,
    contracts,
    metadata,
    createdAt,
    updatedAt,
  ];
}

@JsonSerializable(explicitToJson: true)
@immutable
class EnvironmentConfig extends Equatable {
  const EnvironmentConfig({
    required this.name,
    required this.type,
    required this.config,
  });

  final String name;
  final String type;
  final Map<String, dynamic> config;

  factory EnvironmentConfig.fromJson(Map<String, dynamic> json) =>
      _$EnvironmentConfigFromJson(json);

  Map<String, dynamic> toJson() => _$EnvironmentConfigToJson(this);

  @override
  List<Object?> get props => [name, type, config];
}

@JsonSerializable(explicitToJson: true)
@immutable
class ProductContracts extends Equatable {
  const ProductContracts({
    required this.workItemCategories,
    required this.designContract,
    required this.qaContract,
    required this.deploymentContract,
  });

  final List<String> workItemCategories;
  final DesignContractSpec designContract;
  final QAContractSpec qaContract;
  final DeploymentContractSpec deploymentContract;

  factory ProductContracts.fromJson(Map<String, dynamic> json) =>
      _$ProductContractsFromJson(json);

  Map<String, dynamic> toJson() => _$ProductContractsToJson(this);

  @override
  List<Object?> get props => [
    workItemCategories,
    designContract,
    qaContract,
    deploymentContract,
  ];
}

@JsonSerializable(explicitToJson: true)
@immutable
class DesignContractSpec extends Equatable {
  const DesignContractSpec({
    required this.requiredArtifacts,
    required this.reviewers,
    required this.approvalThreshold,
  });

  final List<String> requiredArtifacts;
  final List<String> reviewers;
  final int approvalThreshold;

  factory DesignContractSpec.fromJson(Map<String, dynamic> json) =>
      _$DesignContractSpecFromJson(json);

  Map<String, dynamic> toJson() => _$DesignContractSpecToJson(this);

  @override
  List<Object?> get props => [requiredArtifacts, reviewers, approvalThreshold];
}

@JsonSerializable(explicitToJson: true)
@immutable
class QAContractSpec extends Equatable {
  const QAContractSpec({required this.gates});

  final List<QAGateSpec> gates;

  factory QAContractSpec.fromJson(Map<String, dynamic> json) =>
      _$QAContractSpecFromJson(json);

  Map<String, dynamic> toJson() => _$QAContractSpecToJson(this);

  @override
  List<Object?> get props => [gates];
}

@JsonSerializable(explicitToJson: true)
@immutable
class QAGateSpec extends Equatable {
  const QAGateSpec({
    required this.gateId,
    required this.type,
    required this.required,
    required this.config,
  });

  final String gateId;
  final String type;
  final bool required;
  final Map<String, dynamic> config;

  factory QAGateSpec.fromJson(Map<String, dynamic> json) =>
      _$QAGateSpecFromJson(json);

  Map<String, dynamic> toJson() => _$QAGateSpecToJson(this);

  @override
  List<Object?> get props => [gateId, type, required, config];
}

@JsonSerializable(explicitToJson: true)
@immutable
class DeploymentContractSpec extends Equatable {
  const DeploymentContractSpec({
    required this.promotionPath,
    required this.approvalGates,
  });

  final List<String> promotionPath;
  final List<ApprovalGateSpec> approvalGates;

  factory DeploymentContractSpec.fromJson(Map<String, dynamic> json) =>
      _$DeploymentContractSpecFromJson(json);

  Map<String, dynamic> toJson() => _$DeploymentContractSpecToJson(this);

  @override
  List<Object?> get props => [promotionPath, approvalGates];
}

@JsonSerializable(explicitToJson: true)
@immutable
class ApprovalGateSpec extends Equatable {
  const ApprovalGateSpec({
    required this.environment,
    required this.approvers,
    required this.threshold,
  });

  final String environment;
  final List<String> approvers;
  final int threshold;

  factory ApprovalGateSpec.fromJson(Map<String, dynamic> json) =>
      _$ApprovalGateSpecFromJson(json);

  Map<String, dynamic> toJson() => _$ApprovalGateSpecToJson(this);

  @override
  List<Object?> get props => [environment, approvers, threshold];
}
