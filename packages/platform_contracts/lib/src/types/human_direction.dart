import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/human_direction.dart';

part 'human_direction.g.dart';

/// A durable human direction to agents.
///
/// A direction is created in [HumanDirectionStatus.created] and progresses
/// through [HumanDirectionStatus.acked], [HumanDirectionStatus.working] to
/// a terminal state: [HumanDirectionStatus.completed], [HumanDirectionStatus.rejected],
/// or [HumanDirectionStatus.superseded].
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class HumanDirection extends Equatable {
  const HumanDirection({
    required this.directionId,
    required this.directionType,
    required this.target,
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
    this.metadata,
  });

  final String directionId;

  @JsonKey(
    fromJson: _humanDirectionTypeFromJson,
    toJson: _humanDirectionTypeToJson,
  )
  final HumanDirectionType directionType;

  final HumanDirectionTarget target;

  @JsonKey(
    fromJson: _humanDirectionStatusFromJson,
    toJson: _humanDirectionStatusToJson,
    defaultValue: HumanDirectionStatus.created,
  )
  final HumanDirectionStatus status;

  final HumanDirectionPayload payload;

  final String? createdBy;
  final String? assignedTo;

  final DateTime? ackedAt;
  final String? ackedBy;

  final DateTime? startedAt;
  final String? startedBy;

  final DateTime? completedAt;
  final String? completedBy;
  final String? completionSummary;

  final DateTime? rejectedAt;
  final String? rejectedBy;
  final String? rejectionReason;

  final DateTime? supersededAt;
  final String? supersededByDirectionId;

  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  factory HumanDirection.fromJson(Map<String, dynamic> json) =>
      _$HumanDirectionFromJson(json);

  Map<String, dynamic> toJson() => _$HumanDirectionToJson(this);

  bool get isTerminal => status.isTerminal;
  bool get isActive => status.isActive;

  @override
  List<Object?> get props => [
    directionId,
    directionType,
    target,
    status,
    payload,
    createdBy,
    assignedTo,
    ackedAt,
    ackedBy,
    startedAt,
    startedBy,
    completedAt,
    completedBy,
    completionSummary,
    rejectedAt,
    rejectedBy,
    rejectionReason,
    supersededAt,
    supersededByDirectionId,
    createdAt,
    updatedAt,
    metadata,
  ];
}

HumanDirectionType _humanDirectionTypeFromJson(String value) =>
    HumanDirectionType.fromWire(value);

String _humanDirectionTypeToJson(HumanDirectionType value) => value.wire;

HumanDirectionTargetType _humanDirectionTargetTypeFromJson(String value) =>
    HumanDirectionTargetType.fromWire(value);

String _humanDirectionTargetTypeToJson(HumanDirectionTargetType value) =>
    value.wire;

HumanDirectionStatus _humanDirectionStatusFromJson(String value) =>
    HumanDirectionStatus.fromWire(value);

String _humanDirectionStatusToJson(HumanDirectionStatus value) => value.wire;

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class HumanDirectionTarget extends Equatable {
  const HumanDirectionTarget({required this.targetType, this.targetId});

  @JsonKey(
    fromJson: _humanDirectionTargetTypeFromJson,
    toJson: _humanDirectionTargetTypeToJson,
  )
  final HumanDirectionTargetType targetType;

  final String? targetId;

  factory HumanDirectionTarget.fromJson(Map<String, dynamic> json) =>
      _$HumanDirectionTargetFromJson(json);

  Map<String, dynamic> toJson() => _$HumanDirectionTargetToJson(this);

  @override
  List<Object?> get props => [targetType, targetId];

  bool get hasTargetId => targetId != null && targetId!.isNotEmpty;

  bool get isNoneTarget => targetType == HumanDirectionTargetType.none;
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class HumanDirectionPayload extends Equatable {
  const HumanDirectionPayload({
    required this.title,
    required this.description,
    this.contextJson,
    this.attachments,
  });

  final String title;
  final String description;
  final String? contextJson;
  final List<HumanDirectionAttachment>? attachments;

  factory HumanDirectionPayload.fromJson(Map<String, dynamic> json) =>
      _$HumanDirectionPayloadFromJson(json);

  Map<String, dynamic> toJson() => _$HumanDirectionPayloadToJson(this);

  @override
  List<Object?> get props => [title, description, contextJson, attachments];
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class HumanDirectionAttachment extends Equatable {
  const HumanDirectionAttachment({
    required this.artifactId,
    required this.artifactType,
    this.description,
  });

  final String artifactId;
  final String artifactType;
  final String? description;

  factory HumanDirectionAttachment.fromJson(Map<String, dynamic> json) =>
      _$HumanDirectionAttachmentFromJson(json);

  Map<String, dynamic> toJson() => _$HumanDirectionAttachmentToJson(this);

  @override
  List<Object?> get props => [artifactId, artifactType, description];
}
