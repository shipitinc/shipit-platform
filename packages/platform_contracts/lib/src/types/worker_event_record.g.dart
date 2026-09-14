// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_event_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkerEventRecord _$WorkerEventRecordFromJson(Map<String, dynamic> json) =>
    WorkerEventRecord(
      eventId: json['eventId'] as String,
      workerExecutionId: json['workerExecutionId'] as String,
      workItemId: json['workItemId'] as String,
      sequence: (json['sequence'] as num).toInt(),
      type: _workerEventTypeFromJson(json['type'] as String),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      payload: json['payload'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$WorkerEventRecordToJson(WorkerEventRecord instance) =>
    <String, dynamic>{
      'eventId': instance.eventId,
      'workerExecutionId': instance.workerExecutionId,
      'workItemId': instance.workItemId,
      'sequence': instance.sequence,
      'type': _workerEventTypeToJson(instance.type),
      'occurredAt': instance.occurredAt.toIso8601String(),
      if (instance.payload case final value?) 'payload': value,
    };
