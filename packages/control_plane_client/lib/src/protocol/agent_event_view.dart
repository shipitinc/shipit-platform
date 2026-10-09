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

/// One entry of an agent execution's event history.
abstract class AgentEventView implements _i1.SerializableModel {
  AgentEventView._({
    required this.eventId,
    required this.executionId,
    required this.workItemId,
    required this.sequence,
    required this.type,
    required this.occurredAt,
    this.payloadJson,
  });

  factory AgentEventView({
    required String eventId,
    required String executionId,
    required String workItemId,
    required int sequence,
    required String type,
    required DateTime occurredAt,
    String? payloadJson,
  }) = _AgentEventViewImpl;

  factory AgentEventView.fromJson(Map<String, dynamic> jsonSerialization) {
    return AgentEventView(
      eventId: jsonSerialization['eventId'] as String,
      executionId: jsonSerialization['executionId'] as String,
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

  String executionId;

  String workItemId;

  int sequence;

  /// Durable `AgentEventType` wire value.
  String type;

  DateTime occurredAt;

  /// Free-form event payload, carried as JSON TEXT. See
  /// `DefectDetailView.clientContextJson` for why.
  String? payloadJson;

  /// Returns a shallow copy of this [AgentEventView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AgentEventView copyWith({
    String? eventId,
    String? executionId,
    String? workItemId,
    int? sequence,
    String? type,
    DateTime? occurredAt,
    String? payloadJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentEventView',
      'eventId': eventId,
      'executionId': executionId,
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

class _AgentEventViewImpl extends AgentEventView {
  _AgentEventViewImpl({
    required String eventId,
    required String executionId,
    required String workItemId,
    required int sequence,
    required String type,
    required DateTime occurredAt,
    String? payloadJson,
  }) : super._(
         eventId: eventId,
         executionId: executionId,
         workItemId: workItemId,
         sequence: sequence,
         type: type,
         occurredAt: occurredAt,
         payloadJson: payloadJson,
       );

  /// Returns a shallow copy of this [AgentEventView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AgentEventView copyWith({
    String? eventId,
    String? executionId,
    String? workItemId,
    int? sequence,
    String? type,
    DateTime? occurredAt,
    Object? payloadJson = _Undefined,
  }) {
    return AgentEventView(
      eventId: eventId ?? this.eventId,
      executionId: executionId ?? this.executionId,
      workItemId: workItemId ?? this.workItemId,
      sequence: sequence ?? this.sequence,
      type: type ?? this.type,
      occurredAt: occurredAt ?? this.occurredAt,
      payloadJson: payloadJson is String? ? payloadJson : this.payloadJson,
    );
  }
}
