import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/qa_semantics.dart';
import '../enums/work_item_category.dart';
import '../enums/worker_capability.dart';
import 'qa_pass_criteria.dart';

part 'qa_contract.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
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
    this.evidenceRows,
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
  @JsonKey(includeIfNull: false)
  final List<QAEvidenceRow>? evidenceRows;
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
    evidenceRows,
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

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class QAEvidenceRow extends Equatable {
  const QAEvidenceRow({
    required this.evidenceId,
    required this.requirement,
    required this.testMethod,
    required this.contractDetermination,
    this.title,
    this.scope,
    this.artifactRef,
    this.params,
    this.prerequisites,
    this.traceabilityRefs = const [],
    this.determinationReasons,
  });

  final String evidenceId;
  final String? title;
  final String? scope;
  @JsonKey(
    fromJson: _evidenceRowRequirementFromJson,
    toJson: _evidenceRowRequirementToJson,
  )
  final EvidenceRowRequirement requirement;
  @JsonKey(fromJson: _testMethodFromJson, toJson: _testMethodToJson)
  final TestMethod testMethod;
  final String? artifactRef;
  final String? params;
  final String? prerequisites;
  final List<String> traceabilityRefs;
  @JsonKey(
    fromJson: _contractDeterminationFromJson,
    toJson: _contractDeterminationToJson,
  )
  final ContractDetermination contractDetermination;
  final String? determinationReasons;

  factory QAEvidenceRow.fromJson(Map<String, dynamic> json) =>
      _$QAEvidenceRowFromJson(json);

  Map<String, dynamic> toJson() => _$QAEvidenceRowToJson(this);

  @override
  List<Object?> get props => [
    evidenceId,
    title,
    scope,
    requirement,
    testMethod,
    artifactRef,
    params,
    prerequisites,
    traceabilityRefs,
    contractDetermination,
    determinationReasons,
  ];
}

List<WorkerCapability>? _workerCapabilitiesFromJson(List<dynamic>? values) =>
    values?.map((v) => WorkerCapability.values.byName(v as String)).toList();

List<String>? _workerCapabilitiesToJson(List<WorkerCapability>? values) =>
    values?.map((v) => v.name).toList();

EvidenceRowRequirement _evidenceRowRequirementFromJson(String value) =>
    switch (value) {
      'not_applicable' => EvidenceRowRequirement.notApplicable,
      _ => EvidenceRowRequirement.values.firstWhere(
        (r) => r.name == value,
        orElse: () =>
            throw FormatException('Unknown evidence row requirement: $value'),
      ),
    };

String _evidenceRowRequirementToJson(EvidenceRowRequirement value) =>
    switch (value) {
      EvidenceRowRequirement.notApplicable => 'not_applicable',
      _ => value.name,
    };

TestMethod _testMethodFromJson(String value) => TestMethod.values.firstWhere(
  (m) => m.name == value,
  orElse: () => throw FormatException('Unknown test method: $value'),
);

String _testMethodToJson(TestMethod value) => value.name;

ContractDetermination _contractDeterminationFromJson(String value) =>
    switch (value) {
      'expected_to_execute' => ContractDetermination.expectedToExecute,
      'skipped_by_contract' => ContractDetermination.skippedByContract,
      _ => ContractDetermination.values.firstWhere(
        (d) => d.name == value,
        orElse: () =>
            throw FormatException('Unknown contract determination: $value'),
      ),
    };

String _contractDeterminationToJson(ContractDetermination value) =>
    switch (value) {
      ContractDetermination.expectedToExecute => 'expected_to_execute',
      ContractDetermination.skippedByContract => 'skipped_by_contract',
      _ => value.name,
    };
