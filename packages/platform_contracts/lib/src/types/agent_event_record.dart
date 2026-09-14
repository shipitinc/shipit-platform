import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/agent_event_type.dart';

part 'agent_event_record.g.dart';

/// A normalized, durable execution event. Raw provider events may additionally
/// be preserved for diagnostics, but the platform persists these records.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class AgentEventRecord extends Equatable {
  const AgentEventRecord({
    required this.eventId,
    required this.executionId,
    required this.workItemId,
    required this.sequence,
    required this.type,
    required this.occurredAt,
    this.payload,
  });

  final String eventId;
  final String executionId;
  final String workItemId;
  final int sequence;
  @JsonKey(fromJson: _agentEventTypeFromJson, toJson: _agentEventTypeToJson)
  final AgentEventType type;
  final DateTime occurredAt;
  final Map<String, dynamic>? payload;

  factory AgentEventRecord.fromJson(Map<String, dynamic> json) =>
      _$AgentEventRecordFromJson(json);

  Map<String, dynamic> toJson() => _$AgentEventRecordToJson(this);

  @override
  List<Object?> get props => [
    eventId,
    executionId,
    workItemId,
    sequence,
    type,
    occurredAt,
    payload,
  ];
}

AgentEventType _agentEventTypeFromJson(String value) =>
    AgentEventType.fromWire(value);

String _agentEventTypeToJson(AgentEventType value) => value.wire;
