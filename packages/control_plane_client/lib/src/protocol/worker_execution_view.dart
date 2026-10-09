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
import 'package:control_plane_client/src/protocol/protocol.dart' as _i2;

/// One durable worker execution.
abstract class WorkerExecutionView implements _i1.SerializableModel {
  WorkerExecutionView._({
    required this.workerExecutionId,
    required this.workItemId,
    required this.repositoryPath,
    required this.requestedStartingRevision,
    required this.requiredCapabilities,
    required this.status,
    required this.cleanupPolicy,
    this.workerId,
    this.workspaceId,
    this.agentExecutionId,
    this.resultId,
    this.endingRevision,
    this.cleanupStatus,
    this.failureCode,
    this.createdAt,
    this.startedAt,
    this.endedAt,
    this.reason,
    required this.version,
  });

  factory WorkerExecutionView({
    required String workerExecutionId,
    required String workItemId,
    required String repositoryPath,
    required String requestedStartingRevision,
    required List<String> requiredCapabilities,
    required String status,
    required String cleanupPolicy,
    String? workerId,
    String? workspaceId,
    String? agentExecutionId,
    String? resultId,
    String? endingRevision,
    String? cleanupStatus,
    String? failureCode,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    String? reason,
    required int version,
  }) = _WorkerExecutionViewImpl;

  factory WorkerExecutionView.fromJson(Map<String, dynamic> jsonSerialization) {
    return WorkerExecutionView(
      workerExecutionId: jsonSerialization['workerExecutionId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      repositoryPath: jsonSerialization['repositoryPath'] as String,
      requestedStartingRevision:
          jsonSerialization['requestedStartingRevision'] as String,
      requiredCapabilities: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['requiredCapabilities'],
      ),
      status: jsonSerialization['status'] as String,
      cleanupPolicy: jsonSerialization['cleanupPolicy'] as String,
      workerId: jsonSerialization['workerId'] as String?,
      workspaceId: jsonSerialization['workspaceId'] as String?,
      agentExecutionId: jsonSerialization['agentExecutionId'] as String?,
      resultId: jsonSerialization['resultId'] as String?,
      endingRevision: jsonSerialization['endingRevision'] as String?,
      cleanupStatus: jsonSerialization['cleanupStatus'] as String?,
      failureCode: jsonSerialization['failureCode'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      startedAt: jsonSerialization['startedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['startedAt']),
      endedAt: jsonSerialization['endedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['endedAt']),
      reason: jsonSerialization['reason'] as String?,
      version: jsonSerialization['version'] as int,
    );
  }

  String workerExecutionId;

  String workItemId;

  String repositoryPath;

  String requestedStartingRevision;

  /// Durable `WorkerCapability` wire values.
  List<String> requiredCapabilities;

  /// Durable `WorkerExecutionStatus` wire value.
  String status;

  /// Durable `WorkerCleanupPolicy` wire value.
  String cleanupPolicy;

  String? workerId;

  String? workspaceId;

  String? agentExecutionId;

  String? resultId;

  String? endingRevision;

  /// Durable `WorkerCleanupStatus` wire value.
  String? cleanupStatus;

  /// Durable `WorkerFailureCode` wire value.
  String? failureCode;

  DateTime? createdAt;

  DateTime? startedAt;

  DateTime? endedAt;

  String? reason;

  int version;

  /// Returns a shallow copy of this [WorkerExecutionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WorkerExecutionView copyWith({
    String? workerExecutionId,
    String? workItemId,
    String? repositoryPath,
    String? requestedStartingRevision,
    List<String>? requiredCapabilities,
    String? status,
    String? cleanupPolicy,
    String? workerId,
    String? workspaceId,
    String? agentExecutionId,
    String? resultId,
    String? endingRevision,
    String? cleanupStatus,
    String? failureCode,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    String? reason,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkerExecutionView',
      'workerExecutionId': workerExecutionId,
      'workItemId': workItemId,
      'repositoryPath': repositoryPath,
      'requestedStartingRevision': requestedStartingRevision,
      'requiredCapabilities': requiredCapabilities.toJson(),
      'status': status,
      'cleanupPolicy': cleanupPolicy,
      if (workerId != null) 'workerId': workerId,
      if (workspaceId != null) 'workspaceId': workspaceId,
      if (agentExecutionId != null) 'agentExecutionId': agentExecutionId,
      if (resultId != null) 'resultId': resultId,
      if (endingRevision != null) 'endingRevision': endingRevision,
      if (cleanupStatus != null) 'cleanupStatus': cleanupStatus,
      if (failureCode != null) 'failureCode': failureCode,
      if (createdAt != null) 'createdAt': createdAt?.toJson(),
      if (startedAt != null) 'startedAt': startedAt?.toJson(),
      if (endedAt != null) 'endedAt': endedAt?.toJson(),
      if (reason != null) 'reason': reason,
      'version': version,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WorkerExecutionViewImpl extends WorkerExecutionView {
  _WorkerExecutionViewImpl({
    required String workerExecutionId,
    required String workItemId,
    required String repositoryPath,
    required String requestedStartingRevision,
    required List<String> requiredCapabilities,
    required String status,
    required String cleanupPolicy,
    String? workerId,
    String? workspaceId,
    String? agentExecutionId,
    String? resultId,
    String? endingRevision,
    String? cleanupStatus,
    String? failureCode,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    String? reason,
    required int version,
  }) : super._(
         workerExecutionId: workerExecutionId,
         workItemId: workItemId,
         repositoryPath: repositoryPath,
         requestedStartingRevision: requestedStartingRevision,
         requiredCapabilities: requiredCapabilities,
         status: status,
         cleanupPolicy: cleanupPolicy,
         workerId: workerId,
         workspaceId: workspaceId,
         agentExecutionId: agentExecutionId,
         resultId: resultId,
         endingRevision: endingRevision,
         cleanupStatus: cleanupStatus,
         failureCode: failureCode,
         createdAt: createdAt,
         startedAt: startedAt,
         endedAt: endedAt,
         reason: reason,
         version: version,
       );

  /// Returns a shallow copy of this [WorkerExecutionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WorkerExecutionView copyWith({
    String? workerExecutionId,
    String? workItemId,
    String? repositoryPath,
    String? requestedStartingRevision,
    List<String>? requiredCapabilities,
    String? status,
    String? cleanupPolicy,
    Object? workerId = _Undefined,
    Object? workspaceId = _Undefined,
    Object? agentExecutionId = _Undefined,
    Object? resultId = _Undefined,
    Object? endingRevision = _Undefined,
    Object? cleanupStatus = _Undefined,
    Object? failureCode = _Undefined,
    Object? createdAt = _Undefined,
    Object? startedAt = _Undefined,
    Object? endedAt = _Undefined,
    Object? reason = _Undefined,
    int? version,
  }) {
    return WorkerExecutionView(
      workerExecutionId: workerExecutionId ?? this.workerExecutionId,
      workItemId: workItemId ?? this.workItemId,
      repositoryPath: repositoryPath ?? this.repositoryPath,
      requestedStartingRevision:
          requestedStartingRevision ?? this.requestedStartingRevision,
      requiredCapabilities:
          requiredCapabilities ??
          this.requiredCapabilities.map((e0) => e0).toList(),
      status: status ?? this.status,
      cleanupPolicy: cleanupPolicy ?? this.cleanupPolicy,
      workerId: workerId is String? ? workerId : this.workerId,
      workspaceId: workspaceId is String? ? workspaceId : this.workspaceId,
      agentExecutionId: agentExecutionId is String?
          ? agentExecutionId
          : this.agentExecutionId,
      resultId: resultId is String? ? resultId : this.resultId,
      endingRevision: endingRevision is String?
          ? endingRevision
          : this.endingRevision,
      cleanupStatus: cleanupStatus is String?
          ? cleanupStatus
          : this.cleanupStatus,
      failureCode: failureCode is String? ? failureCode : this.failureCode,
      createdAt: createdAt is DateTime? ? createdAt : this.createdAt,
      startedAt: startedAt is DateTime? ? startedAt : this.startedAt,
      endedAt: endedAt is DateTime? ? endedAt : this.endedAt,
      reason: reason is String? ? reason : this.reason,
      version: version ?? this.version,
    );
  }
}
