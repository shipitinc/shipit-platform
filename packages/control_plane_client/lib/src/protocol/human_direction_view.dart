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
import 'human_direction_payload_view.dart' as _i2;
import 'package:control_plane_client/src/protocol/protocol.dart' as _i3;

abstract class HumanDirectionView implements _i1.SerializableModel {
  HumanDirectionView._({
    required this.directionId,
    required this.directionType,
    required this.targetType,
    this.targetId,
    required this.status,
    required this.payload,
    this.createdBy,
    this.assignedTo,
    this.ackedAt,
    this.ackedBy,
    this.startedAt,
    this.startedBy,
    this.completedAt,
    this.completedBy,
    this.completionSummary,
    this.rejectedAt,
    this.rejectedBy,
    this.rejectionReason,
    this.supersededAt,
    this.supersededByDirectionId,
    required this.createdAt,
    required this.updatedAt,
    this.metadataJson,
  });

  factory HumanDirectionView({
    required String directionId,
    required String directionType,
    required String targetType,
    String? targetId,
    required String status,
    required _i2.HumanDirectionPayloadView payload,
    String? createdBy,
    String? assignedTo,
    DateTime? ackedAt,
    String? ackedBy,
    DateTime? startedAt,
    String? startedBy,
    DateTime? completedAt,
    String? completedBy,
    String? completionSummary,
    DateTime? rejectedAt,
    String? rejectedBy,
    String? rejectionReason,
    DateTime? supersededAt,
    String? supersededByDirectionId,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? metadataJson,
  }) = _HumanDirectionViewImpl;

  factory HumanDirectionView.fromJson(Map<String, dynamic> jsonSerialization) {
    return HumanDirectionView(
      directionId: jsonSerialization['directionId'] as String,
      directionType: jsonSerialization['directionType'] as String,
      targetType: jsonSerialization['targetType'] as String,
      targetId: jsonSerialization['targetId'] as String?,
      status: jsonSerialization['status'] as String,
      payload: _i3.Protocol().deserialize<_i2.HumanDirectionPayloadView>(
        jsonSerialization['payload'],
      ),
      createdBy: jsonSerialization['createdBy'] as String?,
      assignedTo: jsonSerialization['assignedTo'] as String?,
      ackedAt: jsonSerialization['ackedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['ackedAt']),
      ackedBy: jsonSerialization['ackedBy'] as String?,
      startedAt: jsonSerialization['startedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['startedAt']),
      startedBy: jsonSerialization['startedBy'] as String?,
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
      completedBy: jsonSerialization['completedBy'] as String?,
      completionSummary: jsonSerialization['completionSummary'] as String?,
      rejectedAt: jsonSerialization['rejectedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['rejectedAt']),
      rejectedBy: jsonSerialization['rejectedBy'] as String?,
      rejectionReason: jsonSerialization['rejectionReason'] as String?,
      supersededAt: jsonSerialization['supersededAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['supersededAt'],
            ),
      supersededByDirectionId:
          jsonSerialization['supersededByDirectionId'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      metadataJson: jsonSerialization['metadataJson'] as String?,
    );
  }

  String directionId;

  String directionType;

  String targetType;

  String? targetId;

  String status;

  _i2.HumanDirectionPayloadView payload;

  String? createdBy;

  String? assignedTo;

  DateTime? ackedAt;

  String? ackedBy;

  DateTime? startedAt;

  String? startedBy;

  DateTime? completedAt;

  String? completedBy;

  String? completionSummary;

  DateTime? rejectedAt;

  String? rejectedBy;

  String? rejectionReason;

  DateTime? supersededAt;

  String? supersededByDirectionId;

  DateTime createdAt;

  DateTime updatedAt;

  String? metadataJson;

  /// Returns a shallow copy of this [HumanDirectionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  HumanDirectionView copyWith({
    String? directionId,
    String? directionType,
    String? targetType,
    String? targetId,
    String? status,
    _i2.HumanDirectionPayloadView? payload,
    String? createdBy,
    String? assignedTo,
    DateTime? ackedAt,
    String? ackedBy,
    DateTime? startedAt,
    String? startedBy,
    DateTime? completedAt,
    String? completedBy,
    String? completionSummary,
    DateTime? rejectedAt,
    String? rejectedBy,
    String? rejectionReason,
    DateTime? supersededAt,
    String? supersededByDirectionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? metadataJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'HumanDirectionView',
      'directionId': directionId,
      'directionType': directionType,
      'targetType': targetType,
      if (targetId != null) 'targetId': targetId,
      'status': status,
      'payload': payload.toJson(),
      if (createdBy != null) 'createdBy': createdBy,
      if (assignedTo != null) 'assignedTo': assignedTo,
      if (ackedAt != null) 'ackedAt': ackedAt?.toJson(),
      if (ackedBy != null) 'ackedBy': ackedBy,
      if (startedAt != null) 'startedAt': startedAt?.toJson(),
      if (startedBy != null) 'startedBy': startedBy,
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      if (completedBy != null) 'completedBy': completedBy,
      if (completionSummary != null) 'completionSummary': completionSummary,
      if (rejectedAt != null) 'rejectedAt': rejectedAt?.toJson(),
      if (rejectedBy != null) 'rejectedBy': rejectedBy,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (supersededAt != null) 'supersededAt': supersededAt?.toJson(),
      if (supersededByDirectionId != null)
        'supersededByDirectionId': supersededByDirectionId,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (metadataJson != null) 'metadataJson': metadataJson,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _HumanDirectionViewImpl extends HumanDirectionView {
  _HumanDirectionViewImpl({
    required String directionId,
    required String directionType,
    required String targetType,
    String? targetId,
    required String status,
    required _i2.HumanDirectionPayloadView payload,
    String? createdBy,
    String? assignedTo,
    DateTime? ackedAt,
    String? ackedBy,
    DateTime? startedAt,
    String? startedBy,
    DateTime? completedAt,
    String? completedBy,
    String? completionSummary,
    DateTime? rejectedAt,
    String? rejectedBy,
    String? rejectionReason,
    DateTime? supersededAt,
    String? supersededByDirectionId,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? metadataJson,
  }) : super._(
         directionId: directionId,
         directionType: directionType,
         targetType: targetType,
         targetId: targetId,
         status: status,
         payload: payload,
         createdBy: createdBy,
         assignedTo: assignedTo,
         ackedAt: ackedAt,
         ackedBy: ackedBy,
         startedAt: startedAt,
         startedBy: startedBy,
         completedAt: completedAt,
         completedBy: completedBy,
         completionSummary: completionSummary,
         rejectedAt: rejectedAt,
         rejectedBy: rejectedBy,
         rejectionReason: rejectionReason,
         supersededAt: supersededAt,
         supersededByDirectionId: supersededByDirectionId,
         createdAt: createdAt,
         updatedAt: updatedAt,
         metadataJson: metadataJson,
       );

  /// Returns a shallow copy of this [HumanDirectionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  HumanDirectionView copyWith({
    String? directionId,
    String? directionType,
    String? targetType,
    Object? targetId = _Undefined,
    String? status,
    _i2.HumanDirectionPayloadView? payload,
    Object? createdBy = _Undefined,
    Object? assignedTo = _Undefined,
    Object? ackedAt = _Undefined,
    Object? ackedBy = _Undefined,
    Object? startedAt = _Undefined,
    Object? startedBy = _Undefined,
    Object? completedAt = _Undefined,
    Object? completedBy = _Undefined,
    Object? completionSummary = _Undefined,
    Object? rejectedAt = _Undefined,
    Object? rejectedBy = _Undefined,
    Object? rejectionReason = _Undefined,
    Object? supersededAt = _Undefined,
    Object? supersededByDirectionId = _Undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? metadataJson = _Undefined,
  }) {
    return HumanDirectionView(
      directionId: directionId ?? this.directionId,
      directionType: directionType ?? this.directionType,
      targetType: targetType ?? this.targetType,
      targetId: targetId is String? ? targetId : this.targetId,
      status: status ?? this.status,
      payload: payload ?? this.payload.copyWith(),
      createdBy: createdBy is String? ? createdBy : this.createdBy,
      assignedTo: assignedTo is String? ? assignedTo : this.assignedTo,
      ackedAt: ackedAt is DateTime? ? ackedAt : this.ackedAt,
      ackedBy: ackedBy is String? ? ackedBy : this.ackedBy,
      startedAt: startedAt is DateTime? ? startedAt : this.startedAt,
      startedBy: startedBy is String? ? startedBy : this.startedBy,
      completedAt: completedAt is DateTime? ? completedAt : this.completedAt,
      completedBy: completedBy is String? ? completedBy : this.completedBy,
      completionSummary: completionSummary is String?
          ? completionSummary
          : this.completionSummary,
      rejectedAt: rejectedAt is DateTime? ? rejectedAt : this.rejectedAt,
      rejectedBy: rejectedBy is String? ? rejectedBy : this.rejectedBy,
      rejectionReason: rejectionReason is String?
          ? rejectionReason
          : this.rejectionReason,
      supersededAt: supersededAt is DateTime?
          ? supersededAt
          : this.supersededAt,
      supersededByDirectionId: supersededByDirectionId is String?
          ? supersededByDirectionId
          : this.supersededByDirectionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadataJson: metadataJson is String? ? metadataJson : this.metadataJson,
    );
  }
}
