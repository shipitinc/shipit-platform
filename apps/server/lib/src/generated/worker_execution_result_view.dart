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
import 'changed_file_view.dart' as _i2;
import 'package:control_plane_server/src/generated/protocol.dart' as _i3;

/// What one worker execution produced.
abstract class WorkerExecutionResultView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  WorkerExecutionResultView._({
    required this.workerExecutionId,
    required this.workItemId,
    required this.status,
    required this.workerId,
    required this.workspaceId,
    required this.startingRevision,
    this.endingRevision,
    this.agentExecutionId,
    this.agentResultStatus,
    this.verificationId,
    this.verificationPassed,
    required this.changedFiles,
    this.diffSummary,
    this.diffRef,
    required this.cleanupStatus,
    required this.failureCode,
    this.failureDetail,
    required this.startedAt,
    required this.endedAt,
  });

  factory WorkerExecutionResultView({
    required String workerExecutionId,
    required String workItemId,
    required String status,
    required String workerId,
    required String workspaceId,
    required String startingRevision,
    String? endingRevision,
    String? agentExecutionId,
    String? agentResultStatus,
    String? verificationId,
    bool? verificationPassed,
    required List<_i2.ChangedFileView> changedFiles,
    String? diffSummary,
    String? diffRef,
    required String cleanupStatus,
    required String failureCode,
    String? failureDetail,
    required DateTime startedAt,
    required DateTime endedAt,
  }) = _WorkerExecutionResultViewImpl;

  factory WorkerExecutionResultView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return WorkerExecutionResultView(
      workerExecutionId: jsonSerialization['workerExecutionId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      status: jsonSerialization['status'] as String,
      workerId: jsonSerialization['workerId'] as String,
      workspaceId: jsonSerialization['workspaceId'] as String,
      startingRevision: jsonSerialization['startingRevision'] as String,
      endingRevision: jsonSerialization['endingRevision'] as String?,
      agentExecutionId: jsonSerialization['agentExecutionId'] as String?,
      agentResultStatus: jsonSerialization['agentResultStatus'] as String?,
      verificationId: jsonSerialization['verificationId'] as String?,
      verificationPassed: jsonSerialization['verificationPassed'] == null
          ? null
          : _i1.BoolJsonExtension.fromJson(
              jsonSerialization['verificationPassed'],
            ),
      changedFiles: _i3.Protocol().deserialize<List<_i2.ChangedFileView>>(
        jsonSerialization['changedFiles'],
      ),
      diffSummary: jsonSerialization['diffSummary'] as String?,
      diffRef: jsonSerialization['diffRef'] as String?,
      cleanupStatus: jsonSerialization['cleanupStatus'] as String,
      failureCode: jsonSerialization['failureCode'] as String,
      failureDetail: jsonSerialization['failureDetail'] as String?,
      startedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['startedAt'],
      ),
      endedAt: _i1.DateTimeJsonExtension.fromJson(jsonSerialization['endedAt']),
    );
  }

  String workerExecutionId;

  String workItemId;

  /// Durable `WorkerExecutionStatus` wire value.
  String status;

  String workerId;

  String workspaceId;

  String startingRevision;

  String? endingRevision;

  String? agentExecutionId;

  /// Durable `AgentResultStatus` wire value.
  String? agentResultStatus;

  String? verificationId;

  bool? verificationPassed;

  List<_i2.ChangedFileView> changedFiles;

  String? diffSummary;

  String? diffRef;

  /// Durable `WorkerCleanupStatus` wire value.
  String cleanupStatus;

  /// Durable `WorkerFailureCode` wire value.
  String failureCode;

  String? failureDetail;

  DateTime startedAt;

  DateTime endedAt;

  /// Returns a shallow copy of this [WorkerExecutionResultView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WorkerExecutionResultView copyWith({
    String? workerExecutionId,
    String? workItemId,
    String? status,
    String? workerId,
    String? workspaceId,
    String? startingRevision,
    String? endingRevision,
    String? agentExecutionId,
    String? agentResultStatus,
    String? verificationId,
    bool? verificationPassed,
    List<_i2.ChangedFileView>? changedFiles,
    String? diffSummary,
    String? diffRef,
    String? cleanupStatus,
    String? failureCode,
    String? failureDetail,
    DateTime? startedAt,
    DateTime? endedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkerExecutionResultView',
      'workerExecutionId': workerExecutionId,
      'workItemId': workItemId,
      'status': status,
      'workerId': workerId,
      'workspaceId': workspaceId,
      'startingRevision': startingRevision,
      if (endingRevision != null) 'endingRevision': endingRevision,
      if (agentExecutionId != null) 'agentExecutionId': agentExecutionId,
      if (agentResultStatus != null) 'agentResultStatus': agentResultStatus,
      if (verificationId != null) 'verificationId': verificationId,
      if (verificationPassed != null) 'verificationPassed': verificationPassed,
      'changedFiles': changedFiles.toJson(valueToJson: (v) => v.toJson()),
      if (diffSummary != null) 'diffSummary': diffSummary,
      if (diffRef != null) 'diffRef': diffRef,
      'cleanupStatus': cleanupStatus,
      'failureCode': failureCode,
      if (failureDetail != null) 'failureDetail': failureDetail,
      'startedAt': startedAt.toJson(),
      'endedAt': endedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WorkerExecutionResultView',
      'workerExecutionId': workerExecutionId,
      'workItemId': workItemId,
      'status': status,
      'workerId': workerId,
      'workspaceId': workspaceId,
      'startingRevision': startingRevision,
      if (endingRevision != null) 'endingRevision': endingRevision,
      if (agentExecutionId != null) 'agentExecutionId': agentExecutionId,
      if (agentResultStatus != null) 'agentResultStatus': agentResultStatus,
      if (verificationId != null) 'verificationId': verificationId,
      if (verificationPassed != null) 'verificationPassed': verificationPassed,
      'changedFiles': changedFiles.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
      if (diffSummary != null) 'diffSummary': diffSummary,
      if (diffRef != null) 'diffRef': diffRef,
      'cleanupStatus': cleanupStatus,
      'failureCode': failureCode,
      if (failureDetail != null) 'failureDetail': failureDetail,
      'startedAt': startedAt.toJson(),
      'endedAt': endedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WorkerExecutionResultViewImpl extends WorkerExecutionResultView {
  _WorkerExecutionResultViewImpl({
    required String workerExecutionId,
    required String workItemId,
    required String status,
    required String workerId,
    required String workspaceId,
    required String startingRevision,
    String? endingRevision,
    String? agentExecutionId,
    String? agentResultStatus,
    String? verificationId,
    bool? verificationPassed,
    required List<_i2.ChangedFileView> changedFiles,
    String? diffSummary,
    String? diffRef,
    required String cleanupStatus,
    required String failureCode,
    String? failureDetail,
    required DateTime startedAt,
    required DateTime endedAt,
  }) : super._(
         workerExecutionId: workerExecutionId,
         workItemId: workItemId,
         status: status,
         workerId: workerId,
         workspaceId: workspaceId,
         startingRevision: startingRevision,
         endingRevision: endingRevision,
         agentExecutionId: agentExecutionId,
         agentResultStatus: agentResultStatus,
         verificationId: verificationId,
         verificationPassed: verificationPassed,
         changedFiles: changedFiles,
         diffSummary: diffSummary,
         diffRef: diffRef,
         cleanupStatus: cleanupStatus,
         failureCode: failureCode,
         failureDetail: failureDetail,
         startedAt: startedAt,
         endedAt: endedAt,
       );

  /// Returns a shallow copy of this [WorkerExecutionResultView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WorkerExecutionResultView copyWith({
    String? workerExecutionId,
    String? workItemId,
    String? status,
    String? workerId,
    String? workspaceId,
    String? startingRevision,
    Object? endingRevision = _Undefined,
    Object? agentExecutionId = _Undefined,
    Object? agentResultStatus = _Undefined,
    Object? verificationId = _Undefined,
    Object? verificationPassed = _Undefined,
    List<_i2.ChangedFileView>? changedFiles,
    Object? diffSummary = _Undefined,
    Object? diffRef = _Undefined,
    String? cleanupStatus,
    String? failureCode,
    Object? failureDetail = _Undefined,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return WorkerExecutionResultView(
      workerExecutionId: workerExecutionId ?? this.workerExecutionId,
      workItemId: workItemId ?? this.workItemId,
      status: status ?? this.status,
      workerId: workerId ?? this.workerId,
      workspaceId: workspaceId ?? this.workspaceId,
      startingRevision: startingRevision ?? this.startingRevision,
      endingRevision: endingRevision is String?
          ? endingRevision
          : this.endingRevision,
      agentExecutionId: agentExecutionId is String?
          ? agentExecutionId
          : this.agentExecutionId,
      agentResultStatus: agentResultStatus is String?
          ? agentResultStatus
          : this.agentResultStatus,
      verificationId: verificationId is String?
          ? verificationId
          : this.verificationId,
      verificationPassed: verificationPassed is bool?
          ? verificationPassed
          : this.verificationPassed,
      changedFiles:
          changedFiles ?? this.changedFiles.map((e0) => e0.copyWith()).toList(),
      diffSummary: diffSummary is String? ? diffSummary : this.diffSummary,
      diffRef: diffRef is String? ? diffRef : this.diffRef,
      cleanupStatus: cleanupStatus ?? this.cleanupStatus,
      failureCode: failureCode ?? this.failureCode,
      failureDetail: failureDetail is String?
          ? failureDetail
          : this.failureDetail,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}
