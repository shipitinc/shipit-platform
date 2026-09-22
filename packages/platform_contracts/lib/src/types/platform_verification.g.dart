// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_verification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlatformVerification _$PlatformVerificationFromJson(
  Map<String, dynamic> json,
) => PlatformVerification(
  verificationId: json['verificationId'] as String,
  executionId: json['executionId'] as String,
  workItemId: json['workItemId'] as String,
  checkName: json['checkName'] as String,
  status: _agentClaimStatusFromJson(json['status'] as String),
  mechanism: json['mechanism'] as String,
  command: json['command'] as String,
  capturedAt: DateTime.parse(json['capturedAt'] as String),
  evidenceKind: json['evidenceKind'] == null
      ? EvidenceKind.platformVerifiedEvidence
      : _evidenceKindFromJson(json['evidenceKind'] as String),
  outputRef: json['outputRef'] as String?,
  detail: json['detail'] as String?,
  resultPath: json['resultPath'] as String?,
);

Map<String, dynamic> _$PlatformVerificationToJson(
  PlatformVerification instance,
) => <String, dynamic>{
  'verificationId': instance.verificationId,
  'executionId': instance.executionId,
  'workItemId': instance.workItemId,
  'checkName': instance.checkName,
  'status': _agentClaimStatusToJson(instance.status),
  'mechanism': instance.mechanism,
  'command': instance.command,
  'capturedAt': instance.capturedAt.toIso8601String(),
  'evidenceKind': _evidenceKindToJson(instance.evidenceKind),
  'outputRef': ?instance.outputRef,
  'detail': ?instance.detail,
  'resultPath': ?instance.resultPath,
};
