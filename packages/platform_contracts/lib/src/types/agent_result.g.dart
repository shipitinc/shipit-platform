// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentResult _$AgentResultFromJson(Map<String, dynamic> json) => AgentResult(
  resultId: json['resultId'] as String,
  sessionId: json['sessionId'] as String,
  workItemId: json['workItemId'] as String,
  status: _agentResultStatusFromJson(json['status'] as String),
  artifacts: (json['artifacts'] as List<dynamic>)
      .map((e) => AgentArtifact.fromJson(e as Map<String, dynamic>))
      .toList(),
  diagnostics: AgentDiagnostics.fromJson(
    json['diagnostics'] as Map<String, dynamic>,
  ),
  structuredResult: json['structuredResult'] as Map<String, dynamic>,
  executionId: json['executionId'] as String?,
  role: _agentRoleFromJson(json['role'] as String?),
  changedFiles: (json['changedFiles'] as List<dynamic>?)
      ?.map((e) => ChangedFile.fromJson(e as Map<String, dynamic>))
      .toList(),
  claimedChecks: (json['claimedChecks'] as List<dynamic>?)
      ?.map((e) => AgentClaimedCheck.fromJson(e as Map<String, dynamic>))
      .toList(),
  summary: json['summary'] as String?,
  completedAt: DateTime.parse(json['completedAt'] as String),
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$AgentResultToJson(
  AgentResult instance,
) => <String, dynamic>{
  'resultId': instance.resultId,
  'sessionId': instance.sessionId,
  'workItemId': instance.workItemId,
  'status': _agentResultStatusToJson(instance.status),
  'artifacts': instance.artifacts.map((e) => e.toJson()).toList(),
  'diagnostics': instance.diagnostics.toJson(),
  'structuredResult': instance.structuredResult,
  if (instance.executionId case final value?) 'executionId': value,
  if (_agentRoleToJson(instance.role) case final value?) 'role': value,
  if (instance.changedFiles?.map((e) => e.toJson()).toList() case final value?)
    'changedFiles': value,
  if (instance.claimedChecks?.map((e) => e.toJson()).toList() case final value?)
    'claimedChecks': value,
  if (instance.summary case final value?) 'summary': value,
  'completedAt': instance.completedAt.toIso8601String(),
  if (instance.metadata case final value?) 'metadata': value,
};

ChangedFile _$ChangedFileFromJson(Map<String, dynamic> json) => ChangedFile(
  path: json['path'] as String,
  operation: _operationFromJson(json['operation'] as String),
  beforeSha: json['beforeSha'] as String?,
  afterSha: json['afterSha'] as String?,
);

Map<String, dynamic> _$ChangedFileToJson(ChangedFile instance) =>
    <String, dynamic>{
      'path': instance.path,
      'operation': _operationToJson(instance.operation),
      if (instance.beforeSha case final value?) 'beforeSha': value,
      if (instance.afterSha case final value?) 'afterSha': value,
    };

AgentClaimedCheck _$AgentClaimedCheckFromJson(Map<String, dynamic> json) =>
    AgentClaimedCheck(
      checkName: json['checkName'] as String,
      status: _claimStatusFromJson(json['status'] as String),
      evidenceKind: json['evidenceKind'] == null
          ? EvidenceKind.agentClaimedEvidence
          : _evidenceKindFromJson(json['evidenceKind'] as String),
      command: json['command'] as String?,
      detail: json['detail'] as String?,
    );

Map<String, dynamic> _$AgentClaimedCheckToJson(AgentClaimedCheck instance) =>
    <String, dynamic>{
      'checkName': instance.checkName,
      'status': _claimStatusToJson(instance.status),
      'evidenceKind': _evidenceKindToJson(instance.evidenceKind),
      if (instance.command case final value?) 'command': value,
      if (instance.detail case final value?) 'detail': value,
    };

AgentArtifact _$AgentArtifactFromJson(Map<String, dynamic> json) =>
    AgentArtifact(
      artifactId: json['artifactId'] as String,
      type: json['type'] as String,
      path: json['path'] as String,
      sha256: json['sha256'] as String,
      sizeBytes: (json['sizeBytes'] as num).toInt(),
      mediaType: json['mediaType'] as String,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$AgentArtifactToJson(AgentArtifact instance) =>
    <String, dynamic>{
      'artifactId': instance.artifactId,
      'type': instance.type,
      'path': instance.path,
      'sha256': instance.sha256,
      'sizeBytes': instance.sizeBytes,
      'mediaType': instance.mediaType,
      if (instance.description case final value?) 'description': value,
    };

AgentDiagnostics _$AgentDiagnosticsFromJson(Map<String, dynamic> json) =>
    AgentDiagnostics(
      exitCode: (json['exitCode'] as num).toInt(),
      durationMs: (json['durationMs'] as num).toInt(),
      toolCalls: (json['toolCalls'] as num).toInt(),
      errors: (json['errors'] as List<dynamic>)
          .map((e) => DiagnosticEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      warnings: (json['warnings'] as List<dynamic>)
          .map((e) => DiagnosticEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      resourceUsage: json['resourceUsage'] == null
          ? null
          : ResourceUsage.fromJson(
              json['resourceUsage'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$AgentDiagnosticsToJson(AgentDiagnostics instance) =>
    <String, dynamic>{
      'exitCode': instance.exitCode,
      'durationMs': instance.durationMs,
      'toolCalls': instance.toolCalls,
      'errors': instance.errors.map((e) => e.toJson()).toList(),
      'warnings': instance.warnings.map((e) => e.toJson()).toList(),
      if (instance.resourceUsage?.toJson() case final value?)
        'resourceUsage': value,
    };

DiagnosticEntry _$DiagnosticEntryFromJson(Map<String, dynamic> json) =>
    DiagnosticEntry(
      code: json['code'] as String,
      message: json['message'] as String,
      severity: json['severity'] as String,
      location: json['location'] as String?,
      suggestion: json['suggestion'] as String?,
    );

Map<String, dynamic> _$DiagnosticEntryToJson(DiagnosticEntry instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'severity': instance.severity,
      if (instance.location case final value?) 'location': value,
      if (instance.suggestion case final value?) 'suggestion': value,
    };

ResourceUsage _$ResourceUsageFromJson(Map<String, dynamic> json) =>
    ResourceUsage(
      peakMemoryMb: (json['peakMemoryMb'] as num?)?.toInt(),
      cpuSeconds: (json['cpuSeconds'] as num?)?.toDouble(),
      networkBytes: (json['networkBytes'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ResourceUsageToJson(ResourceUsage instance) =>
    <String, dynamic>{
      if (instance.peakMemoryMb case final value?) 'peakMemoryMb': value,
      if (instance.cpuSeconds case final value?) 'cpuSeconds': value,
      if (instance.networkBytes case final value?) 'networkBytes': value,
    };
