import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/scheduler_event_type.dart';

part 'scheduler_event_record.g.dart';

/// Normalized scheduler lifecycle event, persisted with the job queue so the
/// WorkItem -> Job -> Worker -> Agent traceability chain is fully
/// reconstructible from durable records alone.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class SchedulerEventRecord extends Equatable {
  const SchedulerEventRecord({
    required this.eventId,
    required this.jobId,
    required this.workItemId,
    required this.sequence,
    required this.type,
    required this.occurredAt,
    this.payload,
  });

  final String eventId;
  final String jobId;
  final String workItemId;
  final int sequence;
  @JsonKey(
    fromJson: _schedulerEventTypeFromJson,
    toJson: _schedulerEventTypeToJson,
  )
  final SchedulerEventType type;
  final DateTime occurredAt;
  final Map<String, dynamic>? payload;

  factory SchedulerEventRecord.fromJson(Map<String, dynamic> json) =>
      _$SchedulerEventRecordFromJson(json);

  Map<String, dynamic> toJson() => _$SchedulerEventRecordToJson(this);

  @override
  List<Object?> get props => [
    eventId,
    jobId,
    workItemId,
    sequence,
    type,
    occurredAt,
    payload,
  ];
}

SchedulerEventType _schedulerEventTypeFromJson(String value) =>
    SchedulerEventType.fromWire(value);

String _schedulerEventTypeToJson(SchedulerEventType value) => value.wire;
