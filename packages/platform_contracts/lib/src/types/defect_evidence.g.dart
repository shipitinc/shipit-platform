// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'defect_evidence.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DefectEvidence _$DefectEvidenceFromJson(Map<String, dynamic> json) =>
    DefectEvidence(
      evidenceId: json['evidenceId'] as String,
      defectId: json['defectId'] as String,
      kind: _evidenceIntakeKindFromJson(json['kind'] as String),
      artifactId: json['artifactId'] as String?,
      contentHash: json['contentHash'] as String?,
      description: json['description'] as String?,
      sourceRef: json['sourceRef'] as String?,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$DefectEvidenceToJson(DefectEvidence instance) =>
    <String, dynamic>{
      'evidenceId': instance.evidenceId,
      'defectId': instance.defectId,
      'kind': _evidenceIntakeKindToJson(instance.kind),
      'artifactId': ?instance.artifactId,
      'contentHash': ?instance.contentHash,
      'description': ?instance.description,
      'sourceRef': ?instance.sourceRef,
      'capturedAt': instance.capturedAt.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
    };
