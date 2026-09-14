// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduler_event_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SchedulerEventRecord _$SchedulerEventRecordFromJson(
  Map<String, dynamic> json,
) => SchedulerEventRecord(
  eventId: json['eventId'] as String,
  jobId: json['jobId'] as String,
  workItemId: json['workItemId'] as String,
  sequence: (json['sequence'] as num).toInt(),
  type: _schedulerEventTypeFromJson(json['type'] as String),
  occurredAt: DateTime.parse(json['occurredAt'] as String),
  payload: json['payload'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$SchedulerEventRecordToJson(
  SchedulerEventRecord instance,
) => <String, dynamic>{
  'eventId': instance.eventId,
  'jobId': instance.jobId,
  'workItemId': instance.workItemId,
  'sequence': instance.sequence,
  'type': _schedulerEventTypeToJson(instance.type),
  'occurredAt': instance.occurredAt.toIso8601String(),
  if (instance.payload case final value?) 'payload': value,
};
