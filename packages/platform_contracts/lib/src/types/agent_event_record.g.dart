// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_event_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentEventRecord _$AgentEventRecordFromJson(Map<String, dynamic> json) =>
    AgentEventRecord(
      eventId: json['eventId'] as String,
      executionId: json['executionId'] as String,
      workItemId: json['workItemId'] as String,
      sequence: (json['sequence'] as num).toInt(),
      type: _agentEventTypeFromJson(json['type'] as String),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      payload: json['payload'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$AgentEventRecordToJson(AgentEventRecord instance) =>
    <String, dynamic>{
      'eventId': instance.eventId,
      'executionId': instance.executionId,
      'workItemId': instance.workItemId,
      'sequence': instance.sequence,
      'type': _agentEventTypeToJson(instance.type),
      'occurredAt': instance.occurredAt.toIso8601String(),
      if (instance.payload case final value?) 'payload': value,
    };
