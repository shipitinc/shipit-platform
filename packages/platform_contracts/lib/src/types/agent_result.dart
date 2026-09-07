import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/agent_result_status.dart';

part 'agent_result.g.dart';

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
  final String? summary;
  final DateTime completedAt;
  final Map<String, dynamic>? metadata;

  factory AgentResult.fromJson(Map<String, dynamic> json) =>
      _$AgentResultFromJson(json);

  Map<String, dynamic> toJson() => _$AgentResultToJson(this);

  @override
  List<Object?> get props => [
    resultId,
    sessionId,
    workItemId,
    status,
    artifacts,
    diagnostics,
    structuredResult,
    summary,
    completedAt,
    metadata,
  ];
}

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
