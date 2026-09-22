// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'defect.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Defect _$DefectFromJson(Map<String, dynamic> json) => Defect(
  defectId: json['defectId'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  expectedBehavior: json['expectedBehavior'] as String?,
  reproductionSteps: json['reproductionSteps'] as String?,
  severity: json['severity'] as String,
  status: _defectStatusFromJson(json['status'] as String),
  classification: _defectClassificationFromJson(
    json['classification'] as String?,
  ),
  reporter: json['reporter'] as String,
  affectedWorkItemId: json['affectedWorkItemId'] as String?,
  affectedRunId: json['affectedRunId'] as String?,
  remediationWorkItemId: json['remediationWorkItemId'] as String?,
  duplicateOfDefectId: json['duplicateOfDefectId'] as String?,
  currentTriageJobId: json['currentTriageJobId'] as String?,
  clientContextJson: json['clientContextJson'] as String?,
  metadataJson: json['metadataJson'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  resolvedAt: json['resolvedAt'] == null
      ? null
      : DateTime.parse(json['resolvedAt'] as String),
  closedAt: json['closedAt'] == null
      ? null
      : DateTime.parse(json['closedAt'] as String),
  version: (json['version'] as num).toInt(),
);

Map<String, dynamic> _$DefectToJson(Defect instance) => <String, dynamic>{
  'defectId': instance.defectId,
  'title': instance.title,
  'description': instance.description,
  'expectedBehavior': ?instance.expectedBehavior,
  'reproductionSteps': ?instance.reproductionSteps,
  'severity': instance.severity,
  'status': _defectStatusToJson(instance.status),
  'classification': ?_defectClassificationToJson(instance.classification),
  'reporter': instance.reporter,
  'affectedWorkItemId': ?instance.affectedWorkItemId,
  'affectedRunId': ?instance.affectedRunId,
  'remediationWorkItemId': ?instance.remediationWorkItemId,
  'duplicateOfDefectId': ?instance.duplicateOfDefectId,
  'currentTriageJobId': ?instance.currentTriageJobId,
  'clientContextJson': ?instance.clientContextJson,
  'metadataJson': ?instance.metadataJson,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'resolvedAt': ?instance.resolvedAt?.toIso8601String(),
  'closedAt': ?instance.closedAt?.toIso8601String(),
  'version': instance.version,
};
