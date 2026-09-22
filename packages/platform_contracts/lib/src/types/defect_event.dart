import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/defect_event_type.dart';
import '../enums/defect_status.dart';
import '../enums/workflow_actor.dart';

part 'defect_event.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class DefectEvent extends Equatable {
  const DefectEvent({
    required this.eventId,
    required this.defectId,
    required this.sequence,
    required this.type,
    this.fromStatus,
    this.toStatus,
    required this.actorType,
    this.actorId,
    this.payloadJson,
    required this.occurredAt,
  });

  final String eventId;
  final String defectId;
  final int sequence;
  @JsonKey(fromJson: _defectEventTypeFromJson, toJson: _defectEventTypeToJson)
  final DefectEventType type;
  @JsonKey(
    fromJson: _defectStatusFromJson,
    toJson: _defectStatusToJson,
  )
  final DefectStatus? fromStatus;
  @JsonKey(
    fromJson: _defectStatusFromJson,
    toJson: _defectStatusToJson,
  )
  final DefectStatus? toStatus;
  @JsonKey(fromJson: _actorTypeFromJson, toJson: _actorTypeToJson)
  final ActorType actorType;
  final String? actorId;
  final String? payloadJson;
  final DateTime occurredAt;

  factory DefectEvent.fromJson(Map<String, dynamic> json) =>
      _$DefectEventFromJson(json);

  Map<String, dynamic> toJson() => _$DefectEventToJson(this);

  @override
  List<Object?> get props => [
        eventId,
        defectId,
        sequence,
        type,
        fromStatus,
        toStatus,
        actorType,
        actorId,
        payloadJson,
        occurredAt,
      ];
}

DefectEventType _defectEventTypeFromJson(String value) =>
    DefectEventType.fromWire(value);

String _defectEventTypeToJson(DefectEventType value) => value.wire;

DefectStatus? _defectStatusFromJson(String? value) =>
    value == null ? null : DefectStatus.fromWire(value);

String? _defectStatusToJson(DefectStatus? value) => value?.wire;

ActorType _actorTypeFromJson(String value) => ActorType.fromWire(value);

String _actorTypeToJson(ActorType value) => value.wire;