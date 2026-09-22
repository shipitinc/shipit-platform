import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/defect_status.dart';
import '../enums/defect_classification.dart';

part 'defect.g.dart';

const Object _unset = Object();

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class Defect extends Equatable {
  const Defect({
    required this.defectId,
    required this.title,
    required this.description,
    this.expectedBehavior,
    this.reproductionSteps,
    required this.severity,
    required this.status,
    this.classification,
    required this.reporter,
    this.affectedWorkItemId,
    this.affectedRunId,
    this.remediationWorkItemId,
    this.duplicateOfDefectId,
    this.currentTriageJobId,
    this.clientContextJson,
    this.metadataJson,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.closedAt,
    required this.version,
  });

  final String defectId;
  final String title;
  final String description;
  final String? expectedBehavior;
  final String? reproductionSteps;
  final String severity;
  @JsonKey(fromJson: _defectStatusFromJson, toJson: _defectStatusToJson)
  final DefectStatus status;
  @JsonKey(
    fromJson: _defectClassificationFromJson,
    toJson: _defectClassificationToJson,
  )
  final DefectClassification? classification;
  final String reporter;
  final String? affectedWorkItemId;
  final String? affectedRunId;
  final String? remediationWorkItemId;
  final String? duplicateOfDefectId;
  final String? currentTriageJobId;
  final String? clientContextJson;
  final String? metadataJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final int version;

  factory Defect.fromJson(Map<String, dynamic> json) => _$DefectFromJson(json);

  Map<String, dynamic> toJson() => _$DefectToJson(this);

  Defect copyWith({
    String? defectId,
    String? title,
    String? description,
    Object? expectedBehavior = _unset,
    Object? reproductionSteps = _unset,
    String? severity,
    DefectStatus? status,
    Object? classification = _unset,
    String? reporter,
    Object? affectedWorkItemId = _unset,
    Object? affectedRunId = _unset,
    Object? remediationWorkItemId = _unset,
    Object? duplicateOfDefectId = _unset,
    Object? currentTriageJobId = _unset,
    Object? clientContextJson = _unset,
    Object? metadataJson = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? resolvedAt = _unset,
    Object? closedAt = _unset,
    int? version,
  }) {
    return Defect(
      defectId: defectId ?? this.defectId,
      title: title ?? this.title,
      description: description ?? this.description,
      expectedBehavior: identical(expectedBehavior, _unset)
          ? this.expectedBehavior
          : expectedBehavior as String?,
      reproductionSteps: identical(reproductionSteps, _unset)
          ? this.reproductionSteps
          : reproductionSteps as String?,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      classification: identical(classification, _unset)
          ? this.classification
          : classification as DefectClassification?,
      reporter: reporter ?? this.reporter,
      affectedWorkItemId: identical(affectedWorkItemId, _unset)
          ? this.affectedWorkItemId
          : affectedWorkItemId as String?,
      affectedRunId: identical(affectedRunId, _unset)
          ? this.affectedRunId
          : affectedRunId as String?,
      remediationWorkItemId: identical(remediationWorkItemId, _unset)
          ? this.remediationWorkItemId
          : remediationWorkItemId as String?,
      duplicateOfDefectId: identical(duplicateOfDefectId, _unset)
          ? this.duplicateOfDefectId
          : duplicateOfDefectId as String?,
      currentTriageJobId: identical(currentTriageJobId, _unset)
          ? this.currentTriageJobId
          : currentTriageJobId as String?,
      clientContextJson: identical(clientContextJson, _unset)
          ? this.clientContextJson
          : clientContextJson as String?,
      metadataJson: identical(metadataJson, _unset)
          ? this.metadataJson
          : metadataJson as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: identical(resolvedAt, _unset)
          ? this.resolvedAt
          : resolvedAt as DateTime?,
      closedAt: identical(closedAt, _unset)
          ? this.closedAt
          : closedAt as DateTime?,
      version: version ?? this.version,
    );
  }

  @override
  List<Object?> get props => [
        defectId,
        title,
        description,
        expectedBehavior,
        reproductionSteps,
        severity,
        status,
        classification,
        reporter,
        affectedWorkItemId,
        affectedRunId,
        remediationWorkItemId,
        duplicateOfDefectId,
        currentTriageJobId,
        clientContextJson,
        metadataJson,
        createdAt,
        updatedAt,
        resolvedAt,
        closedAt,
        version,
      ];
}

DefectStatus _defectStatusFromJson(String value) => DefectStatus.fromWire(value);

String _defectStatusToJson(DefectStatus value) => value.wire;

DefectClassification? _defectClassificationFromJson(String? value) =>
    value == null ? null : DefectClassification.fromWire(value);

String? _defectClassificationToJson(DefectClassification? value) => value?.wire;