import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/defect_classification.dart';

part 'design_remediation_request.g.dart';

/// Typed request produced when AI triage yields [DefectClassification.designDefect].
///
/// This request is consumed by [ControlPlaneService.createDesignRemediationWorkItem()]
/// to create a WorkItem in [WorkItemState.designRequired] state, which then triggers
/// the Design Governance lifecycle (JobType.designRevision).
///
/// If Design Governance runtime is not implemented, the WorkItem remains in
/// [WorkItemState.designRequired] and the defect stays in
/// [DefectStatus.remediationPlanned] — reported as
/// EXTERNAL_DESIGN_GOVERNANCE_RUNTIME_DEPENDENCY.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class DesignRemediationRequest extends Equatable {
  const DesignRemediationRequest({
    required this.defectId,
    required this.productId,
    required this.defectTitle,
    required this.triageSummary,
    required this.evidenceRefs,
    required this.designFlawDescription,
    required this.classification,
    required this.triageResultId,
    required this.createdAt,
  });

  final String defectId;
  final String productId;
  final String defectTitle;
  final String triageSummary;
  final List<String> evidenceRefs;
  final String designFlawDescription;

  /// Always [DefectClassification.designDefect] — enforced by producer.
  @JsonKey(
    fromJson: _defectClassificationFromJson,
    toJson: _defectClassificationToJson,
  )
  final DefectClassification classification;

  final String triageResultId;
  final DateTime createdAt;

  factory DesignRemediationRequest.fromJson(Map<String, dynamic> json) =>
      _$DesignRemediationRequestFromJson(json);

  Map<String, dynamic> toJson() => _$DesignRemediationRequestToJson(this);

  @override
  List<Object?> get props => [
    defectId,
    productId,
    defectTitle,
    triageSummary,
    evidenceRefs,
    designFlawDescription,
    classification,
    triageResultId,
    createdAt,
  ];
}

DefectClassification _defectClassificationFromJson(String value) =>
    DefectClassification.fromWire(value);

String _defectClassificationToJson(DefectClassification value) => value.wire;
