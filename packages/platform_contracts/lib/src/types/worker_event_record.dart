import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/worker_event_type.dart';

part 'worker_event_record.g.dart';

/// A normalized, durable worker-layer event. Kept deliberately sparser than
/// the agent event stream: worker events exist only for worker concerns.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class WorkerEventRecord extends Equatable {
  const WorkerEventRecord({
    required this.eventId,
    required this.workerExecutionId,
    required this.workItemId,
    required this.sequence,
    required this.type,
    required this.occurredAt,
    this.payload,
  });

  final String eventId;
  final String workerExecutionId;
  final String workItemId;
  final int sequence;
  @JsonKey(fromJson: _workerEventTypeFromJson, toJson: _workerEventTypeToJson)
  final WorkerEventType type;
  final DateTime occurredAt;
  final Map<String, dynamic>? payload;

  factory WorkerEventRecord.fromJson(Map<String, dynamic> json) =>
      _$WorkerEventRecordFromJson(json);

  Map<String, dynamic> toJson() => _$WorkerEventRecordToJson(this);

  @override
  List<Object?> get props => [
    eventId,
    workerExecutionId,
    workItemId,
    sequence,
    type,
    occurredAt,
    payload,
  ];
}

WorkerEventType _workerEventTypeFromJson(String value) =>
    WorkerEventType.fromWire(value);

String _workerEventTypeToJson(WorkerEventType value) => value.wire;
