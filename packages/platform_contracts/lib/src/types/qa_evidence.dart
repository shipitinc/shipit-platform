import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/qa_gate_status.dart';

part 'qa_evidence.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class QAEvidence extends Equatable {
  const QAEvidence({
    required this.evidenceId,
    required this.gateId,
    required this.workItemId,
    required this.evidenceType,
    required this.artifactRef,
    required this.content,
    required this.collectedAt,
    this.validatorId,
    this.metadata,
  });

  final String evidenceId;
  final String gateId;
  final String workItemId;
  final String evidenceType;
  final String artifactRef;
  final Map<String, dynamic> content;
  final DateTime collectedAt;
  final String? validatorId;
  final Map<String, dynamic>? metadata;

  factory QAEvidence.fromJson(Map<String, dynamic> json) =>
      _$QAEvidenceFromJson(json);

  Map<String, dynamic> toJson() => _$QAEvidenceToJson(this);

  @override
  List<Object?> get props => [
    evidenceId,
    gateId,
    workItemId,
    evidenceType,
    artifactRef,
    content,
    collectedAt,
    validatorId,
    metadata,
  ];
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class QAGateResult extends Equatable {
  const QAGateResult({
    required this.gateId,
    required this.workItemId,
    required this.status,
    required this.evidence,
    required this.evaluatedAt,
    this.passedAt,
    this.waiver,
    this.metadata,
  });

  final String gateId;
  final String workItemId;
  @JsonKey(fromJson: _qaGateStatusFromJson, toJson: _qaGateStatusToJson)
  final QAGateStatus status;
  final List<QAEvidence> evidence;
  final DateTime evaluatedAt;
  final DateTime? passedAt;
  final QAWaiver? waiver;
  final Map<String, dynamic>? metadata;

  factory QAGateResult.fromJson(Map<String, dynamic> json) =>
      _$QAGateResultFromJson(json);

  Map<String, dynamic> toJson() => _$QAGateResultToJson(this);

  @override
  List<Object?> get props => [
    gateId,
    workItemId,
    status,
    evidence,
    evaluatedAt,
    passedAt,
    waiver,
    metadata,
  ];
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class QAWaiver extends Equatable {
  const QAWaiver({
    required this.decisionId,
    required this.reason,
    required this.waivedAt,
    required this.waivedBy,
  });

  final String decisionId;
  final String reason;
  final DateTime waivedAt;
  final String waivedBy;

  factory QAWaiver.fromJson(Map<String, dynamic> json) =>
      _$QAWaiverFromJson(json);

  Map<String, dynamic> toJson() => _$QAWaiverToJson(this);

  @override
  List<Object?> get props => [decisionId, reason, waivedAt, waivedBy];
}

QAGateStatus _qaGateStatusFromJson(String value) =>
    QAGateStatus.values.byName(value);

String _qaGateStatusToJson(QAGateStatus value) => value.name;
