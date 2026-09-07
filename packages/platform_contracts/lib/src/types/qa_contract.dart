import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/work_item_category.dart';
import '../enums/worker_capability.dart';
import 'qa_pass_criteria.dart';

part 'qa_contract.g.dart';

@JsonSerializable(explicitToJson: true)
@immutable
class QAContract extends Equatable {
  const QAContract({
    required this.contractId,
    required this.workItemCategory,
    required this.gates,
    required this.version,
    this.passCriteria,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  final String contractId;
  @JsonKey(fromJson: _workItemCategoryFromJson, toJson: _workItemCategoryToJson)
  final WorkItemCategory workItemCategory;
  final List<QAGateDefinition> gates;
  final String version;
  @JsonKey(includeIfNull: false)
  final QAPassCriteria? passCriteria;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  factory QAContract.fromJson(Map<String, dynamic> json) =>
      _$QAContractFromJson(json);

  Map<String, dynamic> toJson() => _$QAContractToJson(this);

  @override
  List<Object?> get props => [
    contractId,
    workItemCategory,
    gates,
    version,
    passCriteria,
    createdAt,
    updatedAt,
    metadata,
  ];
}

WorkItemCategory _workItemCategoryFromJson(String value) =>
    WorkItemCategory.values.byName(value);

String _workItemCategoryToJson(WorkItemCategory value) => value.name;

@JsonSerializable(explicitToJson: true)
@immutable
class QAGateDefinition extends Equatable {
  const QAGateDefinition({
    required this.gateId,
    required this.type,
    required this.required,
    required this.config,
    required this.evidenceTypes,
    this.workerCapabilities,
  });

  final String gateId;
  final String type;
  final bool required;
  final Map<String, dynamic> config;
  final List<String> evidenceTypes;
  @JsonKey(
    fromJson: _workerCapabilitiesFromJson,
    toJson: _workerCapabilitiesToJson,
    includeIfNull: false,
  )
  final List<WorkerCapability>? workerCapabilities;

  factory QAGateDefinition.fromJson(Map<String, dynamic> json) =>
      _$QAGateDefinitionFromJson(json);

  Map<String, dynamic> toJson() => _$QAGateDefinitionToJson(this);

  @override
  List<Object?> get props => [
    gateId,
    type,
    required,
    config,
    evidenceTypes,
    workerCapabilities,
  ];
}

List<WorkerCapability>? _workerCapabilitiesFromJson(List<dynamic>? values) =>
    values?.map((v) => WorkerCapability.values.byName(v as String)).toList();

List<String>? _workerCapabilitiesToJson(List<WorkerCapability>? values) =>
    values?.map((v) => v.name).toList();
