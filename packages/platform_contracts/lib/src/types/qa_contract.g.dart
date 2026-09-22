// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qa_contract.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QAContract _$QAContractFromJson(Map<String, dynamic> json) => QAContract(
  contractId: json['contractId'] as String,
  workItemCategory: _workItemCategoryFromJson(
    json['workItemCategory'] as String,
  ),
  gates: (json['gates'] as List<dynamic>)
      .map((e) => QAGateDefinition.fromJson(e as Map<String, dynamic>))
      .toList(),
  version: json['version'] as String,
  passCriteria: json['passCriteria'] == null
      ? null
      : QAPassCriteria.fromJson(json['passCriteria'] as Map<String, dynamic>),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  evidenceRows: (json['evidenceRows'] as List<dynamic>?)
      ?.map((e) => QAEvidenceRow.fromJson(e as Map<String, dynamic>))
      .toList(),
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$QAContractToJson(QAContract instance) =>
    <String, dynamic>{
      'contractId': instance.contractId,
      'workItemCategory': _workItemCategoryToJson(instance.workItemCategory),
      'gates': instance.gates.map((e) => e.toJson()).toList(),
      'version': instance.version,
      'passCriteria': ?instance.passCriteria?.toJson(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'evidenceRows': ?instance.evidenceRows?.map((e) => e.toJson()).toList(),
      'metadata': ?instance.metadata,
    };

QAGateDefinition _$QAGateDefinitionFromJson(Map<String, dynamic> json) =>
    QAGateDefinition(
      gateId: json['gateId'] as String,
      type: json['type'] as String,
      required: json['required'] as bool,
      config: json['config'] as Map<String, dynamic>,
      evidenceTypes: (json['evidenceTypes'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      workerCapabilities: _workerCapabilitiesFromJson(
        json['workerCapabilities'] as List?,
      ),
    );

Map<String, dynamic> _$QAGateDefinitionToJson(
  QAGateDefinition instance,
) => <String, dynamic>{
  'gateId': instance.gateId,
  'type': instance.type,
  'required': instance.required,
  'config': instance.config,
  'evidenceTypes': instance.evidenceTypes,
  'workerCapabilities': ?_workerCapabilitiesToJson(instance.workerCapabilities),
};

QAEvidenceRow _$QAEvidenceRowFromJson(Map<String, dynamic> json) =>
    QAEvidenceRow(
      evidenceId: json['evidenceId'] as String,
      requirement: _evidenceRowRequirementFromJson(
        json['requirement'] as String,
      ),
      testMethod: _testMethodFromJson(json['testMethod'] as String),
      contractDetermination: _contractDeterminationFromJson(
        json['contractDetermination'] as String,
      ),
      title: json['title'] as String?,
      scope: json['scope'] as String?,
      artifactRef: json['artifactRef'] as String?,
      params: json['params'] as String?,
      prerequisites: json['prerequisites'] as String?,
      traceabilityRefs:
          (json['traceabilityRefs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      determinationReasons: json['determinationReasons'] as String?,
    );

Map<String, dynamic> _$QAEvidenceRowToJson(QAEvidenceRow instance) =>
    <String, dynamic>{
      'evidenceId': instance.evidenceId,
      'title': ?instance.title,
      'scope': ?instance.scope,
      'requirement': _evidenceRowRequirementToJson(instance.requirement),
      'testMethod': _testMethodToJson(instance.testMethod),
      'artifactRef': ?instance.artifactRef,
      'params': ?instance.params,
      'prerequisites': ?instance.prerequisites,
      'traceabilityRefs': instance.traceabilityRefs,
      'contractDetermination': _contractDeterminationToJson(
        instance.contractDetermination,
      ),
      'determinationReasons': ?instance.determinationReasons,
    };
