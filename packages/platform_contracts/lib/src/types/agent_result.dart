import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/agent_result_status.dart';
import '../enums/agent_role.dart';
import '../enums/evidence_kind.dart';

part 'agent_result.g.dart';

const Object _unset = Object();

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class AgentResult extends Equatable {
  const AgentResult({
    required this.resultId,
    required this.sessionId,
    required this.workItemId,
    required this.status,
    required this.artifacts,
    required this.diagnostics,
    required this.structuredResult,
    this.executionId,
    this.role,
    this.changedFiles,
    this.claimedChecks,
    this.summary,
    required this.completedAt,
    this.metadata,
  });

  final String resultId;
  final String sessionId;
  final String workItemId;
  @JsonKey(
    fromJson: _agentResultStatusFromJson,
    toJson: _agentResultStatusToJson,
  )
  final AgentResultStatus status;
  final List<AgentArtifact> artifacts;
  final AgentDiagnostics diagnostics;
  final Map<String, dynamic> structuredResult;

  /// The [AgentExecutionRequest.executionId] this result belongs to.
  final String? executionId;

  /// The AEF role granted by the execution request. The agent cannot assert a
  /// role; the coordinator stamps it from the request.
  @JsonKey(fromJson: _agentRoleFromJson, toJson: _agentRoleToJson)
  final AgentRole? role;

  /// Files the agent reports changing.
  final List<ChangedFile>? changedFiles;

  /// Validation the AGENT claims. Distinct from platform-verified evidence.
  final List<AgentClaimedCheck>? claimedChecks;

  final String? summary;
  final DateTime completedAt;
  final Map<String, dynamic>? metadata;

  factory AgentResult.fromJson(Map<String, dynamic> json) =>
      _$AgentResultFromJson(json);

  Map<String, dynamic> toJson() => _$AgentResultToJson(this);

  AgentResult copyWith({
    String? resultId,
    String? sessionId,
    String? workItemId,
    AgentResultStatus? status,
    List<AgentArtifact>? artifacts,
    AgentDiagnostics? diagnostics,
    Map<String, dynamic>? structuredResult,
    Object? executionId = _unset,
    Object? role = _unset,
    Object? changedFiles = _unset,
    Object? claimedChecks = _unset,
    Object? summary = _unset,
    DateTime? completedAt,
    Map<String, dynamic>? metadata,
  }) {
    return AgentResult(
      resultId: resultId ?? this.resultId,
      sessionId: sessionId ?? this.sessionId,
      workItemId: workItemId ?? this.workItemId,
      status: status ?? this.status,
      artifacts: artifacts ?? this.artifacts,
      diagnostics: diagnostics ?? this.diagnostics,
      structuredResult: structuredResult ?? this.structuredResult,
      executionId: identical(executionId, _unset)
          ? this.executionId
          : executionId as String?,
      role: identical(role, _unset) ? this.role : role as AgentRole?,
      changedFiles: identical(changedFiles, _unset)
          ? this.changedFiles
          : changedFiles as List<ChangedFile>?,
      claimedChecks: identical(claimedChecks, _unset)
          ? this.claimedChecks
          : claimedChecks as List<AgentClaimedCheck>?,
      summary: identical(summary, _unset) ? this.summary : summary as String?,
      completedAt: completedAt ?? this.completedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
    resultId,
    sessionId,
    workItemId,
    status,
    artifacts,
    diagnostics,
    structuredResult,
    executionId,
    role,
    changedFiles,
    claimedChecks,
    summary,
    completedAt,
    metadata,
  ];
}

/// A file the agent reports touching, with the operation that changed it.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class ChangedFile extends Equatable {
  const ChangedFile({
    required this.path,
    required this.operation,
    this.beforeSha,
    this.afterSha,
  });

  final String path;
  @JsonKey(fromJson: _operationFromJson, toJson: _operationToJson)
  final ChangedFileOperation operation;
  final String? beforeSha;
  final String? afterSha;

  factory ChangedFile.fromJson(Map<String, dynamic> json) =>
      _$ChangedFileFromJson(json);

  Map<String, dynamic> toJson() => _$ChangedFileToJson(this);

  @override
  List<Object?> get props => [path, operation, beforeSha, afterSha];
}

enum ChangedFileOperation {
  modified('modified'),
  added('added'),
  deleted('deleted'),
  renamed('renamed');

  const ChangedFileOperation(this.wire);

  final String wire;

  static ChangedFileOperation fromWire(String value) => values.firstWhere(
    (op) => op.wire == value,
    orElse: () => throw FormatException('Unknown file operation: $value'),
  );
}

ChangedFileOperation _operationFromJson(String value) =>
    ChangedFileOperation.fromWire(value);

String _operationToJson(ChangedFileOperation value) => value.wire;

/// A validation check the agent claims to have performed. Carries its evidence
/// kind explicitly: agent claims are never promoted to platform evidence.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class AgentClaimedCheck extends Equatable {
  const AgentClaimedCheck({
    required this.checkName,
    required this.status,
    this.evidenceKind = EvidenceKind.agentClaimedEvidence,
    this.command,
    this.detail,
  });

  final String checkName;
  @JsonKey(fromJson: _claimStatusFromJson, toJson: _claimStatusToJson)
  final AgentClaimStatus status;

  /// Always 'agent_claimed_evidence'. Kept explicit so platform verification
  /// is never conflated with agent claims.
  @JsonKey(fromJson: _evidenceKindFromJson, toJson: _evidenceKindToJson)
  final EvidenceKind evidenceKind;
  final String? command;
  final String? detail;

  factory AgentClaimedCheck.fromJson(Map<String, dynamic> json) =>
      _$AgentClaimedCheckFromJson(json);

  Map<String, dynamic> toJson() => _$AgentClaimedCheckToJson(this);

  @override
  List<Object?> get props => [checkName, status, evidenceKind, command, detail];
}

AgentRole? _agentRoleFromJson(String? value) =>
    value == null ? null : AgentRole.fromWire(value);

String? _agentRoleToJson(AgentRole? value) => value?.wire;

AgentClaimStatus _claimStatusFromJson(String value) =>
    AgentClaimStatus.fromWire(value);

String _claimStatusToJson(AgentClaimStatus value) => value.wire;

EvidenceKind _evidenceKindFromJson(String value) =>
    EvidenceKind.fromWire(value);

String _evidenceKindToJson(EvidenceKind value) => value.wire;

AgentResultStatus _agentResultStatusFromJson(String value) =>
    AgentResultStatus.fromWire(value);

String _agentResultStatusToJson(AgentResultStatus value) => value.wire;

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class AgentArtifact extends Equatable {
  const AgentArtifact({
    required this.artifactId,
    required this.type,
    required this.path,
    required this.sha256,
    required this.sizeBytes,
    required this.mediaType,
    this.description,
  });

  final String artifactId;
  final String type;
  final String path;
  final String sha256;
  final int sizeBytes;
  final String mediaType;
  final String? description;

  factory AgentArtifact.fromJson(Map<String, dynamic> json) =>
      _$AgentArtifactFromJson(json);

  Map<String, dynamic> toJson() => _$AgentArtifactToJson(this);

  @override
  List<Object?> get props => [
    artifactId,
    type,
    path,
    sha256,
    sizeBytes,
    mediaType,
    description,
  ];
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class AgentDiagnostics extends Equatable {
  const AgentDiagnostics({
    required this.exitCode,
    required this.durationMs,
    required this.toolCalls,
    required this.errors,
    required this.warnings,
    this.resourceUsage,
  });

  final int exitCode;
  final int durationMs;
  final int toolCalls;
  final List<DiagnosticEntry> errors;
  final List<DiagnosticEntry> warnings;
  final ResourceUsage? resourceUsage;

  factory AgentDiagnostics.fromJson(Map<String, dynamic> json) =>
      _$AgentDiagnosticsFromJson(json);

  Map<String, dynamic> toJson() => _$AgentDiagnosticsToJson(this);

  @override
  List<Object?> get props => [
    exitCode,
    durationMs,
    toolCalls,
    errors,
    warnings,
    resourceUsage,
  ];
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class DiagnosticEntry extends Equatable {
  const DiagnosticEntry({
    required this.code,
    required this.message,
    required this.severity,
    this.location,
    this.suggestion,
  });

  final String code;
  final String message;
  final String severity;
  final String? location;
  final String? suggestion;

  factory DiagnosticEntry.fromJson(Map<String, dynamic> json) =>
      _$DiagnosticEntryFromJson(json);

  Map<String, dynamic> toJson() => _$DiagnosticEntryToJson(this);

  @override
  List<Object?> get props => [code, message, severity, location, suggestion];
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class ResourceUsage extends Equatable {
  const ResourceUsage({this.peakMemoryMb, this.cpuSeconds, this.networkBytes});

  final int? peakMemoryMb;
  final double? cpuSeconds;
  final int? networkBytes;

  factory ResourceUsage.fromJson(Map<String, dynamic> json) =>
      _$ResourceUsageFromJson(json);

  Map<String, dynamic> toJson() => _$ResourceUsageToJson(this);

  @override
  List<Object?> get props => [peakMemoryMb, cpuSeconds, networkBytes];
}
