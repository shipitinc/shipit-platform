import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/evidence_kind.dart';

part 'platform_verification.g.dart';

/// Platform-internal evidence of an independent validation run (e.g. `dart
/// test` executed by the harness). This is never produced by the agent; it is
/// the platform's own counter-evidence for an agent's claimed checks.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class PlatformVerification extends Equatable {
  const PlatformVerification({
    required this.verificationId,
    required this.executionId,
    required this.workItemId,
    required this.checkName,
    required this.status,
    required this.mechanism,
    required this.command,
    required this.capturedAt,
    this.evidenceKind = EvidenceKind.platformVerifiedEvidence,
    this.outputRef,
    this.detail,
    this.resultPath,
  });

  final String verificationId;
  final String executionId;
  final String workItemId;
  final String checkName;
  @JsonKey(fromJson: _agentClaimStatusFromJson, toJson: _agentClaimStatusToJson)
  final AgentClaimStatus status;

  /// How the platform validated (e.g. 'process_dart_test').
  final String mechanism;
  final String command;
  final DateTime capturedAt;
  @JsonKey(fromJson: _evidenceKindFromJson, toJson: _evidenceKindToJson)
  final EvidenceKind evidenceKind;

  /// Reference to persisted validation output (e.g. a log file path).
  final String? outputRef;
  final String? detail;

  /// Directory the validation ran in.
  final String? resultPath;

  factory PlatformVerification.fromJson(Map<String, dynamic> json) =>
      _$PlatformVerificationFromJson(json);

  Map<String, dynamic> toJson() => _$PlatformVerificationToJson(this);

  @override
  List<Object?> get props => [
    verificationId,
    executionId,
    workItemId,
    checkName,
    status,
    mechanism,
    command,
    capturedAt,
    evidenceKind,
    outputRef,
    detail,
    resultPath,
  ];
}

AgentClaimStatus _agentClaimStatusFromJson(String value) =>
    AgentClaimStatus.fromWire(value);

String _agentClaimStatusToJson(AgentClaimStatus value) => value.wire;

EvidenceKind _evidenceKindFromJson(String value) =>
    EvidenceKind.fromWire(value);

String _evidenceKindToJson(EvidenceKind value) => value.wire;
