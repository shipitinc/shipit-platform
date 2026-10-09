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

/// One entry of a worker execution's event history.
abstract class WorkerEventView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  WorkerEventView._({
    required this.eventId,
    required this.workerExecutionId,
    required this.workItemId,
    required this.sequence,
    required this.type,
    required this.occurredAt,
    this.payloadJson,
  });

  factory WorkerEventView({
    required String eventId,
    required String workerExecutionId,
    required String workItemId,
    required int sequence,
    required String type,
    required DateTime occurredAt,
    String? payloadJson,
  }) = _WorkerEventViewImpl;

  factory WorkerEventView.fromJson(Map<String, dynamic> jsonSerialization) {
    return WorkerEventView(
      eventId: jsonSerialization['eventId'] as String,
      workerExecutionId: jsonSerialization['workerExecutionId'] as String,
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

  String workerExecutionId;

  String workItemId;

  int sequence;

  /// Durable `WorkerEventType` wire value.
  String type;

  DateTime occurredAt;

  /// Free-form event payload, carried as JSON TEXT. See
  /// `DefectDetailView.clientContextJson` for why.
  String? payloadJson;

  /// Returns a shallow copy of this [WorkerEventView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WorkerEventView copyWith({
    String? eventId,
    String? workerExecutionId,
    String? workItemId,
    int? sequence,
    String? type,
    DateTime? occurredAt,
    String? payloadJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkerEventView',
      'eventId': eventId,
      'workerExecutionId': workerExecutionId,
      'workItemId': workItemId,
      'sequence': sequence,
      'type': type,
      'occurredAt': occurredAt.toJson(),
      if (payloadJson != null) 'payloadJson': payloadJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WorkerEventView',
      'eventId': eventId,
      'workerExecutionId': workerExecutionId,
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

class _WorkerEventViewImpl extends WorkerEventView {
  _WorkerEventViewImpl({
    required String eventId,
    required String workerExecutionId,
    required String workItemId,
    required int sequence,
    required String type,
    required DateTime occurredAt,
    String? payloadJson,
  }) : super._(
         eventId: eventId,
         workerExecutionId: workerExecutionId,
         workItemId: workItemId,
         sequence: sequence,
         type: type,
         occurredAt: occurredAt,
         payloadJson: payloadJson,
       );

  /// Returns a shallow copy of this [WorkerEventView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WorkerEventView copyWith({
    String? eventId,
    String? workerExecutionId,
    String? workItemId,
    int? sequence,
    String? type,
    DateTime? occurredAt,
    Object? payloadJson = _Undefined,
  }) {
    return WorkerEventView(
      eventId: eventId ?? this.eventId,
      workerExecutionId: workerExecutionId ?? this.workerExecutionId,
      workItemId: workItemId ?? this.workItemId,
      sequence: sequence ?? this.sequence,
      type: type ?? this.type,
      occurredAt: occurredAt ?? this.occurredAt,
      payloadJson: payloadJson is String? ? payloadJson : this.payloadJson,
    );
  }
}
