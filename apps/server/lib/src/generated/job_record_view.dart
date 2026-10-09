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
import 'package:control_plane_server/src/generated/protocol.dart' as _i2;

/// One durable job, as the scheduler publishes it. Every enum travels as its
/// wire text, matching every other view in this directory; `requiredCapabilities`
/// is a `Set` on the domain type and a `List` on the wire, which JSON has no
/// other way to express.
abstract class JobRecordView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  JobRecordView._({
    required this.jobId,
    required this.workItemId,
    required this.jobType,
    required this.requiredRole,
    required this.requiredCapabilities,
    required this.priority,
    required this.state,
    required this.dedupeKey,
    required this.createdAt,
    this.availableAt,
    required this.instruction,
  });

  factory JobRecordView({
    required String jobId,
    required String workItemId,
    required String jobType,
    required String requiredRole,
    required List<String> requiredCapabilities,
    required String priority,
    required String state,
    required String dedupeKey,
    required DateTime createdAt,
    DateTime? availableAt,
    required String instruction,
  }) = _JobRecordViewImpl;

  factory JobRecordView.fromJson(Map<String, dynamic> jsonSerialization) {
    return JobRecordView(
      jobId: jsonSerialization['jobId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      jobType: jsonSerialization['jobType'] as String,
      requiredRole: jsonSerialization['requiredRole'] as String,
      requiredCapabilities: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['requiredCapabilities'],
      ),
      priority: jsonSerialization['priority'] as String,
      state: jsonSerialization['state'] as String,
      dedupeKey: jsonSerialization['dedupeKey'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      availableAt: jsonSerialization['availableAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['availableAt'],
            ),
      instruction: jsonSerialization['instruction'] as String,
    );
  }

  String jobId;

  String workItemId;

  /// Durable `JobType` wire value.
  String jobType;

  /// Durable `AgentRole` wire value.
  String requiredRole;

  /// Durable `WorkerCapability` wire values.
  List<String> requiredCapabilities;

  /// Durable `JobPriority` wire value.
  String priority;

  /// Durable `JobState` wire value.
  String state;

  String dedupeKey;

  DateTime createdAt;

  DateTime? availableAt;

  String instruction;

  /// Returns a shallow copy of this [JobRecordView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  JobRecordView copyWith({
    String? jobId,
    String? workItemId,
    String? jobType,
    String? requiredRole,
    List<String>? requiredCapabilities,
    String? priority,
    String? state,
    String? dedupeKey,
    DateTime? createdAt,
    DateTime? availableAt,
    String? instruction,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'JobRecordView',
      'jobId': jobId,
      'workItemId': workItemId,
      'jobType': jobType,
      'requiredRole': requiredRole,
      'requiredCapabilities': requiredCapabilities.toJson(),
      'priority': priority,
      'state': state,
      'dedupeKey': dedupeKey,
      'createdAt': createdAt.toJson(),
      if (availableAt != null) 'availableAt': availableAt?.toJson(),
      'instruction': instruction,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'JobRecordView',
      'jobId': jobId,
      'workItemId': workItemId,
      'jobType': jobType,
      'requiredRole': requiredRole,
      'requiredCapabilities': requiredCapabilities.toJson(),
      'priority': priority,
      'state': state,
      'dedupeKey': dedupeKey,
      'createdAt': createdAt.toJson(),
      if (availableAt != null) 'availableAt': availableAt?.toJson(),
      'instruction': instruction,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _JobRecordViewImpl extends JobRecordView {
  _JobRecordViewImpl({
    required String jobId,
    required String workItemId,
    required String jobType,
    required String requiredRole,
    required List<String> requiredCapabilities,
    required String priority,
    required String state,
    required String dedupeKey,
    required DateTime createdAt,
    DateTime? availableAt,
    required String instruction,
  }) : super._(
         jobId: jobId,
         workItemId: workItemId,
         jobType: jobType,
         requiredRole: requiredRole,
         requiredCapabilities: requiredCapabilities,
         priority: priority,
         state: state,
         dedupeKey: dedupeKey,
         createdAt: createdAt,
         availableAt: availableAt,
         instruction: instruction,
       );

  /// Returns a shallow copy of this [JobRecordView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  JobRecordView copyWith({
    String? jobId,
    String? workItemId,
    String? jobType,
    String? requiredRole,
    List<String>? requiredCapabilities,
    String? priority,
    String? state,
    String? dedupeKey,
    DateTime? createdAt,
    Object? availableAt = _Undefined,
    String? instruction,
  }) {
    return JobRecordView(
      jobId: jobId ?? this.jobId,
      workItemId: workItemId ?? this.workItemId,
      jobType: jobType ?? this.jobType,
      requiredRole: requiredRole ?? this.requiredRole,
      requiredCapabilities:
          requiredCapabilities ??
          this.requiredCapabilities.map((e0) => e0).toList(),
      priority: priority ?? this.priority,
      state: state ?? this.state,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      createdAt: createdAt ?? this.createdAt,
      availableAt: availableAt is DateTime? ? availableAt : this.availableAt,
      instruction: instruction ?? this.instruction,
    );
  }
}
