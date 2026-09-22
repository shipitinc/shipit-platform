// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'design_revision_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DesignRevisionEvent _$DesignRevisionEventFromJson(Map<String, dynamic> json) =>
    DesignRevisionEvent(
      eventId: json['eventId'] as String,
      designRevisionId: json['designRevisionId'] as String,
      eventType: json['eventType'] as String,
      payloadJson: json['payloadJson'] as String,
      sequence: (json['sequence'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$DesignRevisionEventToJson(
  DesignRevisionEvent instance,
) => <String, dynamic>{
  'eventId': instance.eventId,
  'designRevisionId': instance.designRevisionId,
  'eventType': instance.eventType,
  'payloadJson': instance.payloadJson,
  'sequence': instance.sequence,
  'createdAt': instance.createdAt.toIso8601String(),
};
