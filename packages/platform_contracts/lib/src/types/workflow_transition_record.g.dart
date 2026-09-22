// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workflow_transition_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TransitionGuardEvaluation _$TransitionGuardEvaluationFromJson(
  Map<String, dynamic> json,
) => TransitionGuardEvaluation(
  guardName: json['guardName'] as String,
  passed: json['passed'] as bool,
  message: json['message'] as String?,
);

Map<String, dynamic> _$TransitionGuardEvaluationToJson(
  TransitionGuardEvaluation instance,
) => <String, dynamic>{
  'guardName': instance.guardName,
  'passed': instance.passed,
  'message': ?instance.message,
};

WorkflowTransitionRecord _$WorkflowTransitionRecordFromJson(
  Map<String, dynamic> json,
) => WorkflowTransitionRecord(
  transitionId: json['transitionId'] as String,
  workItemId: json['workItemId'] as String,
  fromState: _workItemStateFromJson(json['fromState'] as String),
  toState: _workItemStateFromJson(json['toState'] as String),
  trigger: _transitionTriggerFromJson(json['trigger'] as String),
  actorType: _actorTypeFromJson(json['actorType'] as String),
  outcome: _transitionOutcomeFromJson(json['outcome'] as String),
  occurredAt: DateTime.parse(json['occurredAt'] as String),
  actorId: json['actorId'] as String?,
  decisionId: json['decisionId'] as String?,
  reason: json['reason'] as String?,
  guardEvaluations:
      (json['guardEvaluations'] as List<dynamic>?)
          ?.map(
            (e) =>
                TransitionGuardEvaluation.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
  idempotencyKey: json['idempotencyKey'] as String?,
);

Map<String, dynamic> _$WorkflowTransitionRecordToJson(
  WorkflowTransitionRecord instance,
) => <String, dynamic>{
  'transitionId': instance.transitionId,
  'workItemId': instance.workItemId,
  'fromState': _workItemStateToJson(instance.fromState),
  'toState': _workItemStateToJson(instance.toState),
  'trigger': _transitionTriggerToJson(instance.trigger),
  'actorType': _actorTypeToJson(instance.actorType),
  'actorId': ?instance.actorId,
  'decisionId': ?instance.decisionId,
  'outcome': _transitionOutcomeToJson(instance.outcome),
  'reason': ?instance.reason,
  'guardEvaluations': instance.guardEvaluations.map((e) => e.toJson()).toList(),
  'idempotencyKey': ?instance.idempotencyKey,
  'occurredAt': instance.occurredAt.toIso8601String(),
};
