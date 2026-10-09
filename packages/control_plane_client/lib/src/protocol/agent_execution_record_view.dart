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

import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'agent_workspace_view.dart' as _i2;
import 'package:control_plane_client/src/protocol/protocol.dart' as _i3;

/// One durable agent execution.
abstract class AgentExecutionRecordView implements _i1.SerializableModel {
  AgentExecutionRecordView._({
    required this.executionId,
    required this.workItemId,
    required this.requestId,
    required this.runtimeTypeId,
    required this.role,
    required this.status,
    required this.workspace,
    this.sessionId,
    this.resultId,
    this.startedAt,
    this.completedAt,
    this.reason,
    this.metadataJson,
    required this.version,
  });

  factory AgentExecutionRecordView({
    required String executionId,
    required String workItemId,
    required String requestId,
    required String runtimeTypeId,
    required String role,
    required String status,
    required _i2.AgentWorkspaceView workspace,
    String? sessionId,
    String? resultId,
    DateTime? startedAt,
    DateTime? completedAt,
    String? reason,
    String? metadataJson,
    required int version,
  }) = _AgentExecutionRecordViewImpl;

  factory AgentExecutionRecordView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return AgentExecutionRecordView(
      executionId: jsonSerialization['executionId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      requestId: jsonSerialization['requestId'] as String,
      runtimeTypeId: jsonSerialization['runtimeTypeId'] as String,
      role: jsonSerialization['role'] as String,
      status: jsonSerialization['status'] as String,
      workspace: _i3.Protocol().deserialize<_i2.AgentWorkspaceView>(
        jsonSerialization['workspace'],
      ),
      sessionId: jsonSerialization['sessionId'] as String?,
      resultId: jsonSerialization['resultId'] as String?,
      startedAt: jsonSerialization['startedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['startedAt']),
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
      reason: jsonSerialization['reason'] as String?,
      metadataJson: jsonSerialization['metadataJson'] as String?,
      version: jsonSerialization['version'] as int,
    );
  }

  String executionId;

  String workItemId;

  String requestId;

  String runtimeTypeId;

  /// Durable `AgentRole` wire value.
  String role;

  /// Durable `AgentSessionStatus` wire value.
  String status;

  _i2.AgentWorkspaceView workspace;

  String? sessionId;

  String? resultId;

  DateTime? startedAt;

  DateTime? completedAt;

  String? reason;

  /// Free-form execution metadata, carried as JSON TEXT. See
  /// `DefectDetailView.clientContextJson` for why.
  String? metadataJson;

  int version;

  /// Returns a shallow copy of this [AgentExecutionRecordView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AgentExecutionRecordView copyWith({
    String? executionId,
    String? workItemId,
    String? requestId,
    String? runtimeTypeId,
    String? role,
    String? status,
    _i2.AgentWorkspaceView? workspace,
    String? sessionId,
    String? resultId,
    DateTime? startedAt,
    DateTime? completedAt,
    String? reason,
    String? metadataJson,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentExecutionRecordView',
      'executionId': executionId,
      'workItemId': workItemId,
      'requestId': requestId,
      'runtimeTypeId': runtimeTypeId,
      'role': role,
      'status': status,
      'workspace': workspace.toJson(),
      if (sessionId != null) 'sessionId': sessionId,
      if (resultId != null) 'resultId': resultId,
      if (startedAt != null) 'startedAt': startedAt?.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      if (reason != null) 'reason': reason,
      if (metadataJson != null) 'metadataJson': metadataJson,
      'version': version,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AgentExecutionRecordViewImpl extends AgentExecutionRecordView {
  _AgentExecutionRecordViewImpl({
    required String executionId,
    required String workItemId,
    required String requestId,
    required String runtimeTypeId,
    required String role,
    required String status,
    required _i2.AgentWorkspaceView workspace,
    String? sessionId,
    String? resultId,
    DateTime? startedAt,
    DateTime? completedAt,
    String? reason,
    String? metadataJson,
    required int version,
  }) : super._(
         executionId: executionId,
         workItemId: workItemId,
         requestId: requestId,
         runtimeTypeId: runtimeTypeId,
         role: role,
         status: status,
         workspace: workspace,
         sessionId: sessionId,
         resultId: resultId,
         startedAt: startedAt,
         completedAt: completedAt,
         reason: reason,
         metadataJson: metadataJson,
         version: version,
       );

  /// Returns a shallow copy of this [AgentExecutionRecordView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AgentExecutionRecordView copyWith({
    String? executionId,
    String? workItemId,
    String? requestId,
    String? runtimeTypeId,
    String? role,
    String? status,
    _i2.AgentWorkspaceView? workspace,
    Object? sessionId = _Undefined,
    Object? resultId = _Undefined,
    Object? startedAt = _Undefined,
    Object? completedAt = _Undefined,
    Object? reason = _Undefined,
    Object? metadataJson = _Undefined,
    int? version,
  }) {
    return AgentExecutionRecordView(
      executionId: executionId ?? this.executionId,
      workItemId: workItemId ?? this.workItemId,
      requestId: requestId ?? this.requestId,
      runtimeTypeId: runtimeTypeId ?? this.runtimeTypeId,
      role: role ?? this.role,
      status: status ?? this.status,
      workspace: workspace ?? this.workspace.copyWith(),
      sessionId: sessionId is String? ? sessionId : this.sessionId,
      resultId: resultId is String? ? resultId : this.resultId,
      startedAt: startedAt is DateTime? ? startedAt : this.startedAt,
      completedAt: completedAt is DateTime? ? completedAt : this.completedAt,
      reason: reason is String? ? reason : this.reason,
      metadataJson: metadataJson is String? ? metadataJson : this.metadataJson,
      version: version ?? this.version,
    );
  }
}
