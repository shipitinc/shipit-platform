// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workflow_actor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkflowActor _$WorkflowActorFromJson(Map<String, dynamic> json) =>
    WorkflowActor(
      actorId: json['actorId'] as String,
      actorType: _actorTypeFromJson(json['actorType'] as String),
      displayName: json['displayName'] as String?,
    );

Map<String, dynamic> _$WorkflowActorToJson(WorkflowActor instance) =>
    <String, dynamic>{
      'actorId': instance.actorId,
      'actorType': _actorTypeToJson(instance.actorType),
      if (instance.displayName case final value?) 'displayName': value,
    };
