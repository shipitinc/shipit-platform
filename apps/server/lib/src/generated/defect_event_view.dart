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

/// One entry of a defect's lifecycle history.
abstract class DefectEventView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  DefectEventView._({
    required this.eventId,
    required this.defectId,
    required this.sequence,
    required this.type,
    this.fromStatus,
    this.toStatus,
    required this.actorType,
    this.actorId,
    this.payloadJson,
    required this.occurredAt,
  });

  factory DefectEventView({
    required String eventId,
    required String defectId,
    required int sequence,
    required String type,
    String? fromStatus,
    String? toStatus,
    required String actorType,
    String? actorId,
    String? payloadJson,
    required DateTime occurredAt,
  }) = _DefectEventViewImpl;

  factory DefectEventView.fromJson(Map<String, dynamic> jsonSerialization) {
    return DefectEventView(
      eventId: jsonSerialization['eventId'] as String,
      defectId: jsonSerialization['defectId'] as String,
      sequence: jsonSerialization['sequence'] as int,
      type: jsonSerialization['type'] as String,
      fromStatus: jsonSerialization['fromStatus'] as String?,
      toStatus: jsonSerialization['toStatus'] as String?,
      actorType: jsonSerialization['actorType'] as String,
      actorId: jsonSerialization['actorId'] as String?,
      payloadJson: jsonSerialization['payloadJson'] as String?,
      occurredAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['occurredAt'],
      ),
    );
  }

  String eventId;

  String defectId;

  int sequence;

  /// Durable `DefectEvent` type wire value.
  String type;

  String? fromStatus;

  String? toStatus;

  /// Durable actor-type wire value.
  String actorType;

  String? actorId;

  /// Free-form event payload, carried as JSON TEXT. See
  /// `DefectDetailView.clientContextJson` for why.
  String? payloadJson;

  DateTime occurredAt;

  /// Returns a shallow copy of this [DefectEventView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DefectEventView copyWith({
    String? eventId,
    String? defectId,
    int? sequence,
    String? type,
    String? fromStatus,
    String? toStatus,
    String? actorType,
    String? actorId,
    String? payloadJson,
    DateTime? occurredAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DefectEventView',
      'eventId': eventId,
      'defectId': defectId,
      'sequence': sequence,
      'type': type,
      if (fromStatus != null) 'fromStatus': fromStatus,
      if (toStatus != null) 'toStatus': toStatus,
      'actorType': actorType,
      if (actorId != null) 'actorId': actorId,
      if (payloadJson != null) 'payloadJson': payloadJson,
      'occurredAt': occurredAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DefectEventView',
      'eventId': eventId,
      'defectId': defectId,
      'sequence': sequence,
      'type': type,
      if (fromStatus != null) 'fromStatus': fromStatus,
      if (toStatus != null) 'toStatus': toStatus,
      'actorType': actorType,
      if (actorId != null) 'actorId': actorId,
      if (payloadJson != null) 'payloadJson': payloadJson,
      'occurredAt': occurredAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DefectEventViewImpl extends DefectEventView {
  _DefectEventViewImpl({
    required String eventId,
    required String defectId,
    required int sequence,
    required String type,
    String? fromStatus,
    String? toStatus,
    required String actorType,
    String? actorId,
    String? payloadJson,
    required DateTime occurredAt,
  }) : super._(
         eventId: eventId,
         defectId: defectId,
         sequence: sequence,
         type: type,
         fromStatus: fromStatus,
         toStatus: toStatus,
         actorType: actorType,
         actorId: actorId,
         payloadJson: payloadJson,
         occurredAt: occurredAt,
       );

  /// Returns a shallow copy of this [DefectEventView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DefectEventView copyWith({
    String? eventId,
    String? defectId,
    int? sequence,
    String? type,
    Object? fromStatus = _Undefined,
    Object? toStatus = _Undefined,
    String? actorType,
    Object? actorId = _Undefined,
    Object? payloadJson = _Undefined,
    DateTime? occurredAt,
  }) {
    return DefectEventView(
      eventId: eventId ?? this.eventId,
      defectId: defectId ?? this.defectId,
      sequence: sequence ?? this.sequence,
      type: type ?? this.type,
      fromStatus: fromStatus is String? ? fromStatus : this.fromStatus,
      toStatus: toStatus is String? ? toStatus : this.toStatus,
      actorType: actorType ?? this.actorType,
      actorId: actorId is String? ? actorId : this.actorId,
      payloadJson: payloadJson is String? ? payloadJson : this.payloadJson,
      occurredAt: occurredAt ?? this.occurredAt,
    );
  }
}
