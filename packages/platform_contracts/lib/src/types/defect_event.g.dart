// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'defect_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DefectEvent _$DefectEventFromJson(Map<String, dynamic> json) => DefectEvent(
  eventId: json['eventId'] as String,
  defectId: json['defectId'] as String,
  sequence: (json['sequence'] as num).toInt(),
  type: _defectEventTypeFromJson(json['type'] as String),
  fromStatus: _defectStatusFromJson(json['fromStatus'] as String?),
  toStatus: _defectStatusFromJson(json['toStatus'] as String?),
  actorType: _actorTypeFromJson(json['actorType'] as String),
  actorId: json['actorId'] as String?,
  payloadJson: json['payloadJson'] as String?,
  occurredAt: DateTime.parse(json['occurredAt'] as String),
);

Map<String, dynamic> _$DefectEventToJson(DefectEvent instance) =>
    <String, dynamic>{
      'eventId': instance.eventId,
      'defectId': instance.defectId,
      'sequence': instance.sequence,
      'type': _defectEventTypeToJson(instance.type),
      'fromStatus': ?_defectStatusToJson(instance.fromStatus),
      'toStatus': ?_defectStatusToJson(instance.toStatus),
      'actorType': _actorTypeToJson(instance.actorType),
      'actorId': ?instance.actorId,
      'payloadJson': ?instance.payloadJson,
      'occurredAt': instance.occurredAt.toIso8601String(),
    };
