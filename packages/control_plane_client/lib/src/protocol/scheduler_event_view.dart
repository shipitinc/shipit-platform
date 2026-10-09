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

/// One entry of a job's scheduler event history.
abstract class SchedulerEventView implements _i1.SerializableModel {
  SchedulerEventView._({
    required this.eventId,
    required this.jobId,
    required this.workItemId,
    required this.sequence,
    required this.type,
    required this.occurredAt,
    this.payloadJson,
  });

  factory SchedulerEventView({
    required String eventId,
    required String jobId,
    required String workItemId,
    required int sequence,
    required String type,
    required DateTime occurredAt,
    String? payloadJson,
  }) = _SchedulerEventViewImpl;

  factory SchedulerEventView.fromJson(Map<String, dynamic> jsonSerialization) {
    return SchedulerEventView(
      eventId: jsonSerialization['eventId'] as String,
      jobId: jsonSerialization['jobId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      sequence: jsonSerialization['sequence'] as int,
      type: jsonSerialization['type'] as String,
      occurredAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['occurredAt'],
      ),
      payloadJson: jsonSerialization['payloadJson'] as String?,
    );
  }

  String eventId;

  String jobId;

  String workItemId;

  int sequence;

  /// Durable `SchedulerEventType` wire value.
  String type;

  DateTime occurredAt;

  /// Free-form event payload, carried as JSON TEXT. See
  /// `DefectDetailView.clientContextJson` for why Serverpod 3.4.13 has no
  /// field type that could hold it any other way.
  String? payloadJson;

  /// Returns a shallow copy of this [SchedulerEventView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  SchedulerEventView copyWith({
    String? eventId,
    String? jobId,
    String? workItemId,
    int? sequence,
    String? type,
    DateTime? occurredAt,
    String? payloadJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SchedulerEventView',
      'eventId': eventId,
      'jobId': jobId,
      'workItemId': workItemId,
      'sequence': sequence,
      'type': type,
      'occurredAt': occurredAt.toJson(),
      if (payloadJson != null) 'payloadJson': payloadJson,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SchedulerEventViewImpl extends SchedulerEventView {
  _SchedulerEventViewImpl({
    required String eventId,
    required String jobId,
    required String workItemId,
    required int sequence,
    required String type,
    required DateTime occurredAt,
    String? payloadJson,
  }) : super._(
         eventId: eventId,
         jobId: jobId,
         workItemId: workItemId,
         sequence: sequence,
         type: type,
         occurredAt: occurredAt,
         payloadJson: payloadJson,
       );

  /// Returns a shallow copy of this [SchedulerEventView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  SchedulerEventView copyWith({
    String? eventId,
    String? jobId,
    String? workItemId,
    int? sequence,
    String? type,
    DateTime? occurredAt,
    Object? payloadJson = _Undefined,
  }) {
    return SchedulerEventView(
      eventId: eventId ?? this.eventId,
      jobId: jobId ?? this.jobId,
      workItemId: workItemId ?? this.workItemId,
      sequence: sequence ?? this.sequence,
      type: type ?? this.type,
      occurredAt: occurredAt ?? this.occurredAt,
      payloadJson: payloadJson is String? ? payloadJson : this.payloadJson,
    );
  }
}
