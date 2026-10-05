// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'human_direction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HumanDirection _$HumanDirectionFromJson(
  Map<String, dynamic> json,
) => HumanDirection(
  directionId: json['directionId'] as String,
  directionType: _humanDirectionTypeFromJson(json['directionType'] as String),
  target: HumanDirectionTarget.fromJson(json['target'] as Map<String, dynamic>),
  status: json['status'] == null
      ? HumanDirectionStatus.created
      : _humanDirectionStatusFromJson(json['status'] as String),
  payload: HumanDirectionPayload.fromJson(
    json['payload'] as Map<String, dynamic>,
  ),
  createdBy: json['createdBy'] as String?,
  assignedTo: json['assignedTo'] as String?,
  ackedAt: json['ackedAt'] == null
      ? null
      : DateTime.parse(json['ackedAt'] as String),
  ackedBy: json['ackedBy'] as String?,
  startedAt: json['startedAt'] == null
      ? null
      : DateTime.parse(json['startedAt'] as String),
  startedBy: json['startedBy'] as String?,
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
  completedBy: json['completedBy'] as String?,
  completionSummary: json['completionSummary'] as String?,
  rejectedAt: json['rejectedAt'] == null
      ? null
      : DateTime.parse(json['rejectedAt'] as String),
  rejectedBy: json['rejectedBy'] as String?,
  rejectionReason: json['rejectionReason'] as String?,
  supersededAt: json['supersededAt'] == null
      ? null
      : DateTime.parse(json['supersededAt'] as String),
  supersededByDirectionId: json['supersededByDirectionId'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$HumanDirectionToJson(HumanDirection instance) =>
    <String, dynamic>{
      'directionId': instance.directionId,
      'directionType': _humanDirectionTypeToJson(instance.directionType),
      'target': instance.target.toJson(),
      'status': _humanDirectionStatusToJson(instance.status),
      'payload': instance.payload.toJson(),
      'createdBy': ?instance.createdBy,
      'assignedTo': ?instance.assignedTo,
      'ackedAt': ?instance.ackedAt?.toIso8601String(),
      'ackedBy': ?instance.ackedBy,
      'startedAt': ?instance.startedAt?.toIso8601String(),
      'startedBy': ?instance.startedBy,
      'completedAt': ?instance.completedAt?.toIso8601String(),
      'completedBy': ?instance.completedBy,
      'completionSummary': ?instance.completionSummary,
      'rejectedAt': ?instance.rejectedAt?.toIso8601String(),
      'rejectedBy': ?instance.rejectedBy,
      'rejectionReason': ?instance.rejectionReason,
      'supersededAt': ?instance.supersededAt?.toIso8601String(),
      'supersededByDirectionId': ?instance.supersededByDirectionId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'metadata': ?instance.metadata,
    };

HumanDirectionTarget _$HumanDirectionTargetFromJson(
  Map<String, dynamic> json,
) => HumanDirectionTarget(
  targetType: _humanDirectionTargetTypeFromJson(json['targetType'] as String),
  targetId: json['targetId'] as String?,
);

Map<String, dynamic> _$HumanDirectionTargetToJson(
  HumanDirectionTarget instance,
) => <String, dynamic>{
  'targetType': _humanDirectionTargetTypeToJson(instance.targetType),
  'targetId': ?instance.targetId,
};

HumanDirectionPayload _$HumanDirectionPayloadFromJson(
  Map<String, dynamic> json,
) => HumanDirectionPayload(
  title: json['title'] as String,
  description: json['description'] as String,
  contextJson: json['contextJson'] as String?,
  attachments: (json['attachments'] as List<dynamic>?)
      ?.map((e) => HumanDirectionAttachment.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$HumanDirectionPayloadToJson(
  HumanDirectionPayload instance,
) => <String, dynamic>{
  'title': instance.title,
  'description': instance.description,
  'contextJson': ?instance.contextJson,
  'attachments': ?instance.attachments?.map((e) => e.toJson()).toList(),
};

HumanDirectionAttachment _$HumanDirectionAttachmentFromJson(
  Map<String, dynamic> json,
) => HumanDirectionAttachment(
  artifactId: json['artifactId'] as String,
  artifactType: json['artifactType'] as String,
  description: json['description'] as String?,
);

Map<String, dynamic> _$HumanDirectionAttachmentToJson(
  HumanDirectionAttachment instance,
) => <String, dynamic>{
  'artifactId': instance.artifactId,
  'artifactType': instance.artifactType,
  'description': ?instance.description,
};
