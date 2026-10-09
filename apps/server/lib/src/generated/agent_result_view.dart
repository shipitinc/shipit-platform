/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:serverpod/serverpod.dart' as _i1;
import 'agent_artifact_view.dart' as _i2;
import 'agent_diagnostics_view.dart' as _i3;
import 'changed_file_view.dart' as _i4;
import 'agent_claimed_check_view.dart' as _i5;
import 'package:control_plane_server/src/generated/protocol.dart' as _i6;

/// What an agent run produced.
abstract class AgentResultView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  AgentResultView._({
    required this.resultId,
    required this.sessionId,
    required this.workItemId,
    required this.status,
    required this.artifacts,
    required this.diagnostics,
    required this.structuredResultJson,
    this.executionId,
    this.role,
    this.changedFiles,
    this.claimedChecks,
    this.summary,
    required this.completedAt,
    this.metadataJson,
  });

  factory AgentResultView({
    required String resultId,
    required String sessionId,
    required String workItemId,
    required String status,
    required List<_i2.AgentArtifactView> artifacts,
    required _i3.AgentDiagnosticsView diagnostics,
    required String structuredResultJson,
    String? executionId,
    String? role,
    List<_i4.ChangedFileView>? changedFiles,
    List<_i5.AgentClaimedCheckView>? claimedChecks,
    String? summary,
    required DateTime completedAt,
    String? metadataJson,
  }) = _AgentResultViewImpl;

  factory AgentResultView.fromJson(Map<String, dynamic> jsonSerialization) {
    return AgentResultView(
      resultId: jsonSerialization['resultId'] as String,
      sessionId: jsonSerialization['sessionId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      status: jsonSerialization['status'] as String,
      artifacts: _i6.Protocol().deserialize<List<_i2.AgentArtifactView>>(
        jsonSerialization['artifacts'],
      ),
      diagnostics: _i6.Protocol().deserialize<_i3.AgentDiagnosticsView>(
        jsonSerialization['diagnostics'],
      ),
      structuredResultJson: jsonSerialization['structuredResultJson'] as String,
      executionId: jsonSerialization['executionId'] as String?,
      role: jsonSerialization['role'] as String?,
      changedFiles: jsonSerialization['changedFiles'] == null
          ? null
          : _i6.Protocol().deserialize<List<_i4.ChangedFileView>>(
              jsonSerialization['changedFiles'],
            ),
      claimedChecks: jsonSerialization['claimedChecks'] == null
          ? null
          : _i6.Protocol().deserialize<List<_i5.AgentClaimedCheckView>>(
              jsonSerialization['claimedChecks'],
            ),
      summary: jsonSerialization['summary'] as String?,
      completedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['completedAt'],
      ),
      metadataJson: jsonSerialization['metadataJson'] as String?,
    );
  }

  String resultId;

  String sessionId;

  String workItemId;

  /// Durable `AgentResultStatus` wire value.
  String status;

  List<_i2.AgentArtifactView> artifacts;

  _i3.AgentDiagnosticsView diagnostics;

  /// The run's structured output, carried as JSON TEXT. See
  /// `DefectDetailView.clientContextJson` for why Serverpod 3.4.13 has no field
  /// type that could hold arbitrary JSON. `jsonDecode` recovers it exactly.
  String structuredResultJson;

  String? executionId;

  /// Durable `AgentRole` wire value.
  String? role;

  List<_i4.ChangedFileView>? changedFiles;

  List<_i5.AgentClaimedCheckView>? claimedChecks;

  String? summary;

  DateTime completedAt;

  /// Free-form result metadata, carried as JSON TEXT. See above.
  String? metadataJson;

  /// Returns a shallow copy of this [AgentResultView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AgentResultView copyWith({
    String? resultId,
    String? sessionId,
    String? workItemId,
    String? status,
    List<_i2.AgentArtifactView>? artifacts,
    _i3.AgentDiagnosticsView? diagnostics,
    String? structuredResultJson,
    String? executionId,
    String? role,
    List<_i4.ChangedFileView>? changedFiles,
    List<_i5.AgentClaimedCheckView>? claimedChecks,
    String? summary,
    DateTime? completedAt,
    String? metadataJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentResultView',
      'resultId': resultId,
      'sessionId': sessionId,
      'workItemId': workItemId,
      'status': status,
      'artifacts': artifacts.toJson(valueToJson: (v) => v.toJson()),
      'diagnostics': diagnostics.toJson(),
      'structuredResultJson': structuredResultJson,
      if (executionId != null) 'executionId': executionId,
      if (role != null) 'role': role,
      if (changedFiles != null)
        'changedFiles': changedFiles?.toJson(valueToJson: (v) => v.toJson()),
      if (claimedChecks != null)
        'claimedChecks': claimedChecks?.toJson(valueToJson: (v) => v.toJson()),
      if (summary != null) 'summary': summary,
      'completedAt': completedAt.toJson(),
      if (metadataJson != null) 'metadataJson': metadataJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AgentResultView',
      'resultId': resultId,
      'sessionId': sessionId,
      'workItemId': workItemId,
      'status': status,
      'artifacts': artifacts.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'diagnostics': diagnostics.toJsonForProtocol(),
      'structuredResultJson': structuredResultJson,
      if (executionId != null) 'executionId': executionId,
      if (role != null) 'role': role,
      if (changedFiles != null)
        'changedFiles': changedFiles?.toJson(
          valueToJson: (v) => v.toJsonForProtocol(),
        ),
      if (claimedChecks != null)
        'claimedChecks': claimedChecks?.toJson(
          valueToJson: (v) => v.toJsonForProtocol(),
        ),
      if (summary != null) 'summary': summary,
      'completedAt': completedAt.toJson(),
      if (metadataJson != null) 'metadataJson': metadataJson,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AgentResultViewImpl extends AgentResultView {
  _AgentResultViewImpl({
    required String resultId,
    required String sessionId,
    required String workItemId,
    required String status,
    required List<_i2.AgentArtifactView> artifacts,
    required _i3.AgentDiagnosticsView diagnostics,
    required String structuredResultJson,
    String? executionId,
    String? role,
    List<_i4.ChangedFileView>? changedFiles,
    List<_i5.AgentClaimedCheckView>? claimedChecks,
    String? summary,
    required DateTime completedAt,
    String? metadataJson,
  }) : super._(
         resultId: resultId,
         sessionId: sessionId,
         workItemId: workItemId,
         status: status,
         artifacts: artifacts,
         diagnostics: diagnostics,
         structuredResultJson: structuredResultJson,
         executionId: executionId,
         role: role,
         changedFiles: changedFiles,
         claimedChecks: claimedChecks,
         summary: summary,
         completedAt: completedAt,
         metadataJson: metadataJson,
       );

  /// Returns a shallow copy of this [AgentResultView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AgentResultView copyWith({
    String? resultId,
    String? sessionId,
    String? workItemId,
    String? status,
    List<_i2.AgentArtifactView>? artifacts,
    _i3.AgentDiagnosticsView? diagnostics,
    String? structuredResultJson,
    Object? executionId = _Undefined,
    Object? role = _Undefined,
    Object? changedFiles = _Undefined,
    Object? claimedChecks = _Undefined,
    Object? summary = _Undefined,
    DateTime? completedAt,
    Object? metadataJson = _Undefined,
  }) {
    return AgentResultView(
      resultId: resultId ?? this.resultId,
      sessionId: sessionId ?? this.sessionId,
      workItemId: workItemId ?? this.workItemId,
      status: status ?? this.status,
      artifacts:
          artifacts ?? this.artifacts.map((e0) => e0.copyWith()).toList(),
      diagnostics: diagnostics ?? this.diagnostics.copyWith(),
      structuredResultJson: structuredResultJson ?? this.structuredResultJson,
      executionId: executionId is String? ? executionId : this.executionId,
      role: role is String? ? role : this.role,
      changedFiles: changedFiles is List<_i4.ChangedFileView>?
          ? changedFiles
          : this.changedFiles?.map((e0) => e0.copyWith()).toList(),
      claimedChecks: claimedChecks is List<_i5.AgentClaimedCheckView>?
          ? claimedChecks
          : this.claimedChecks?.map((e0) => e0.copyWith()).toList(),
      summary: summary is String? ? summary : this.summary,
      completedAt: completedAt ?? this.completedAt,
      metadataJson: metadataJson is String? ? metadataJson : this.metadataJson,
    );
  }
}
