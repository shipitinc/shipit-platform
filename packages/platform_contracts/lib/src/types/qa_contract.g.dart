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

Map<String, dynamic> _$QAContractToJson(
  QAContract instance,
) => <String, dynamic>{
  'contractId': instance.contractId,
  'workItemCategory': _workItemCategoryToJson(instance.workItemCategory),
  'gates': instance.gates.map((e) => e.toJson()).toList(),
  'version': instance.version,
  if (instance.passCriteria?.toJson() case final value?) 'passCriteria': value,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  if (instance.evidenceRows?.map((e) => e.toJson()).toList() case final value?)
    'evidenceRows': value,
  if (instance.metadata case final value?) 'metadata': value,
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
  if (_workerCapabilitiesToJson(instance.workerCapabilities) case final value?)
    'workerCapabilities': value,
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
      if (instance.title case final value?) 'title': value,
      if (instance.scope case final value?) 'scope': value,
      'requirement': _evidenceRowRequirementToJson(instance.requirement),
      'testMethod': _testMethodToJson(instance.testMethod),
      if (instance.artifactRef case final value?) 'artifactRef': value,
      if (instance.params case final value?) 'params': value,
      if (instance.prerequisites case final value?) 'prerequisites': value,
      'traceabilityRefs': instance.traceabilityRefs,
      'contractDetermination': _contractDeterminationToJson(
        instance.contractDetermination,
      ),
      if (instance.determinationReasons case final value?)
        'determinationReasons': value,
    };
