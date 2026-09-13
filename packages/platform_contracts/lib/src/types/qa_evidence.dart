import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/qa_gate_status.dart';
import '../enums/qa_semantics.dart';

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
    this.evidenceDeterminations,
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
  final List<QAEvidenceDetermination>? evidenceDeterminations;
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
    evidenceDeterminations,
    metadata,
  ];
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class QAEvidenceDetermination extends Equatable {
  const QAEvidenceDetermination({
    required this.evidenceId,
    required this.determination,
    this.artifactRef,
    this.params,
    this.prerequisites,
    this.reasons,
    this.authorityRef,
    this.evidenceRefs = const [],
  });

  final String evidenceId;
  @JsonKey(
    fromJson: _evidenceDeterminationFromJson,
    toJson: _evidenceDeterminationToJson,
  )
  final EvidenceDetermination determination;
  final String? artifactRef;
  final String? params;
  final String? prerequisites;
  final String? reasons;
  final String? authorityRef;
  final List<String> evidenceRefs;

  factory QAEvidenceDetermination.fromJson(Map<String, dynamic> json) =>
      _$QAEvidenceDeterminationFromJson(json);

  Map<String, dynamic> toJson() => _$QAEvidenceDeterminationToJson(this);

  @override
  List<Object?> get props => [
    evidenceId,
    determination,
    artifactRef,
    params,
    prerequisites,
    reasons,
    authorityRef,
    evidenceRefs,
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

QAGateStatus _qaGateStatusFromJson(String value) => switch (value) {
  'not_executed' => QAGateStatus.notExecuted,
  'not_applicable' => QAGateStatus.notApplicable,
  _ => QAGateStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => throw FormatException('Unknown QA gate status: $value'),
  ),
};

String _qaGateStatusToJson(QAGateStatus value) => switch (value) {
  QAGateStatus.notExecuted => 'not_executed',
  QAGateStatus.notApplicable => 'not_applicable',
  _ => value.name,
};

EvidenceDetermination _evidenceDeterminationFromJson(String value) =>
    switch (value) {
      'ready_not_executed' => EvidenceDetermination.readyNotExecuted,
      _ => EvidenceDetermination.values.firstWhere(
        (d) => d.name == value,
        orElse: () =>
            throw FormatException('Unknown evidence determination: $value'),
      ),
    };

String _evidenceDeterminationToJson(EvidenceDetermination value) =>
    switch (value) {
      EvidenceDetermination.readyNotExecuted => 'ready_not_executed',
      _ => value.name,
    };
