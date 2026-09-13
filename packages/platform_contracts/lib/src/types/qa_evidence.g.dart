// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qa_evidence.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QAEvidence _$QAEvidenceFromJson(Map<String, dynamic> json) => QAEvidence(
  evidenceId: json['evidenceId'] as String,
  gateId: json['gateId'] as String,
  workItemId: json['workItemId'] as String,
  evidenceType: json['evidenceType'] as String,
  artifactRef: json['artifactRef'] as String,
  content: json['content'] as Map<String, dynamic>,
  collectedAt: DateTime.parse(json['collectedAt'] as String),
  validatorId: json['validatorId'] as String?,
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$QAEvidenceToJson(QAEvidence instance) =>
    <String, dynamic>{
      'evidenceId': instance.evidenceId,
      'gateId': instance.gateId,
      'workItemId': instance.workItemId,
      'evidenceType': instance.evidenceType,
      'artifactRef': instance.artifactRef,
      'content': instance.content,
      'collectedAt': instance.collectedAt.toIso8601String(),
      if (instance.validatorId case final value?) 'validatorId': value,
      if (instance.metadata case final value?) 'metadata': value,
    };

QAGateResult _$QAGateResultFromJson(Map<String, dynamic> json) => QAGateResult(
  gateId: json['gateId'] as String,
  workItemId: json['workItemId'] as String,
  status: _qaGateStatusFromJson(json['status'] as String),
  evidence: (json['evidence'] as List<dynamic>)
      .map((e) => QAEvidence.fromJson(e as Map<String, dynamic>))
      .toList(),
  evaluatedAt: DateTime.parse(json['evaluatedAt'] as String),
  passedAt: json['passedAt'] == null
      ? null
      : DateTime.parse(json['passedAt'] as String),
  waiver: json['waiver'] == null
      ? null
      : QAWaiver.fromJson(json['waiver'] as Map<String, dynamic>),
  evidenceDeterminations: (json['evidenceDeterminations'] as List<dynamic>?)
      ?.map((e) => QAEvidenceDetermination.fromJson(e as Map<String, dynamic>))
      .toList(),
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$QAGateResultToJson(
  QAGateResult instance,
) => <String, dynamic>{
  'gateId': instance.gateId,
  'workItemId': instance.workItemId,
  'status': _qaGateStatusToJson(instance.status),
  'evidence': instance.evidence.map((e) => e.toJson()).toList(),
  'evaluatedAt': instance.evaluatedAt.toIso8601String(),
  if (instance.passedAt?.toIso8601String() case final value?) 'passedAt': value,
  if (instance.waiver?.toJson() case final value?) 'waiver': value,
  if (instance.evidenceDeterminations?.map((e) => e.toJson()).toList()
      case final value?)
    'evidenceDeterminations': value,
  if (instance.metadata case final value?) 'metadata': value,
};

QAEvidenceDetermination _$QAEvidenceDeterminationFromJson(
  Map<String, dynamic> json,
) => QAEvidenceDetermination(
  evidenceId: json['evidenceId'] as String,
  determination: _evidenceDeterminationFromJson(
    json['determination'] as String,
  ),
  artifactRef: json['artifactRef'] as String?,
  params: json['params'] as String?,
  prerequisites: json['prerequisites'] as String?,
  reasons: json['reasons'] as String?,
  authorityRef: json['authorityRef'] as String?,
  evidenceRefs:
      (json['evidenceRefs'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$QAEvidenceDeterminationToJson(
  QAEvidenceDetermination instance,
) => <String, dynamic>{
  'evidenceId': instance.evidenceId,
  'determination': _evidenceDeterminationToJson(instance.determination),
  if (instance.artifactRef case final value?) 'artifactRef': value,
  if (instance.params case final value?) 'params': value,
  if (instance.prerequisites case final value?) 'prerequisites': value,
  if (instance.reasons case final value?) 'reasons': value,
  if (instance.authorityRef case final value?) 'authorityRef': value,
  'evidenceRefs': instance.evidenceRefs,
};

QAWaiver _$QAWaiverFromJson(Map<String, dynamic> json) => QAWaiver(
  decisionId: json['decisionId'] as String,
  reason: json['reason'] as String,
  waivedAt: DateTime.parse(json['waivedAt'] as String),
  waivedBy: json['waivedBy'] as String,
);

Map<String, dynamic> _$QAWaiverToJson(QAWaiver instance) => <String, dynamic>{
  'decisionId': instance.decisionId,
  'reason': instance.reason,
  'waivedAt': instance.waivedAt.toIso8601String(),
  'waivedBy': instance.waivedBy,
};
