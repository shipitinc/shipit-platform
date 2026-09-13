import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/workflow_actor.dart';

part 'workflow_actor.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class WorkflowActor extends Equatable {
  const WorkflowActor({
    required this.actorId,
    required this.actorType,
    this.displayName,
  });

  final String actorId;
  @JsonKey(fromJson: _actorTypeFromJson, toJson: _actorTypeToJson)
  final ActorType actorType;
  final String? displayName;

  factory WorkflowActor.fromJson(Map<String, dynamic> json) =>
      _$WorkflowActorFromJson(json);

  Map<String, dynamic> toJson() => _$WorkflowActorToJson(this);

  @override
  List<Object?> get props => [actorId, actorType, displayName];
}

ActorType _actorTypeFromJson(String value) => ActorType.fromWire(value);

String _actorTypeToJson(ActorType value) => value.wire;
