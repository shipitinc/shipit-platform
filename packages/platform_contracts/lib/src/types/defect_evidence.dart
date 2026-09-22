import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/evidence_intake_kind.dart';

part 'defect_evidence.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class DefectEvidence extends Equatable {
  const DefectEvidence({
    required this.evidenceId,
    required this.defectId,
    required this.kind,
    this.artifactId,
    this.contentHash,
    this.description,
    this.sourceRef,
    required this.capturedAt,
    required this.createdAt,
  });

  final String evidenceId;
  final String defectId;
  @JsonKey(fromJson: _evidenceIntakeKindFromJson, toJson: _evidenceIntakeKindToJson)
  final EvidenceIntakeKind kind;
  final String? artifactId;
  final String? contentHash;
  final String? description;
  final String? sourceRef;
  final DateTime capturedAt;
  final DateTime createdAt;

  factory DefectEvidence.fromJson(Map<String, dynamic> json) =>
      _$DefectEvidenceFromJson(json);

  Map<String, dynamic> toJson() => _$DefectEvidenceToJson(this);

  @override
  List<Object?> get props => [
        evidenceId,
        defectId,
        kind,
        artifactId,
        contentHash,
        description,
        sourceRef,
        capturedAt,
        createdAt,
      ];
}

EvidenceIntakeKind _evidenceIntakeKindFromJson(String value) =>
    EvidenceIntakeKind.fromWire(value);

String _evidenceIntakeKindToJson(EvidenceIntakeKind value) => value.wire;