import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/transition_trigger.dart';
import '../enums/workflow_actor.dart';
import '../enums/workflow_state.dart';

part 'workflow_transition_record.g.dart';

enum TransitionOutcome {
  accepted('accepted'),
  rejected('rejected');

  const TransitionOutcome(this.wire);

  final String wire;

  static TransitionOutcome fromWire(String value) => values.firstWhere(
    (outcome) => outcome.wire == value,
    orElse: () => throw FormatException('Unknown transition outcome: $value'),
  );
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class TransitionGuardEvaluation extends Equatable {
  const TransitionGuardEvaluation({
    required this.guardName,
    required this.passed,
    this.message,
  });

  final String guardName;
  final bool passed;
  final String? message;

  factory TransitionGuardEvaluation.fromJson(Map<String, dynamic> json) =>
      _$TransitionGuardEvaluationFromJson(json);

  Map<String, dynamic> toJson() => _$TransitionGuardEvaluationToJson(this);

  @override
  List<Object?> get props => [guardName, passed, message];
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class WorkflowTransitionRecord extends Equatable {
  const WorkflowTransitionRecord({
    required this.transitionId,
    required this.workItemId,
    required this.fromState,
    required this.toState,
    required this.trigger,
    required this.actorType,
    required this.outcome,
    required this.occurredAt,
    this.actorId,
    this.decisionId,
    this.reason,
    this.guardEvaluations = const [],
    this.idempotencyKey,
  });

  final String transitionId;
  final String workItemId;
  @JsonKey(fromJson: _workItemStateFromJson, toJson: _workItemStateToJson)
  final WorkItemState fromState;
  @JsonKey(fromJson: _workItemStateFromJson, toJson: _workItemStateToJson)
  final WorkItemState toState;
  @JsonKey(
    fromJson: _transitionTriggerFromJson,
    toJson: _transitionTriggerToJson,
  )
  final TransitionTrigger trigger;
  @JsonKey(fromJson: _actorTypeFromJson, toJson: _actorTypeToJson)
  final ActorType actorType;
  final String? actorId;
  final String? decisionId;
  @JsonKey(
    fromJson: _transitionOutcomeFromJson,
    toJson: _transitionOutcomeToJson,
  )
  final TransitionOutcome outcome;
  final String? reason;
  final List<TransitionGuardEvaluation> guardEvaluations;
  final String? idempotencyKey;
  final DateTime occurredAt;

  factory WorkflowTransitionRecord.fromJson(Map<String, dynamic> json) =>
      _$WorkflowTransitionRecordFromJson(json);

  Map<String, dynamic> toJson() => _$WorkflowTransitionRecordToJson(this);

  @override
  List<Object?> get props => [
    transitionId,
    workItemId,
    fromState,
    toState,
    trigger,
    actorType,
    actorId,
    decisionId,
    outcome,
    reason,
    guardEvaluations,
    idempotencyKey,
    occurredAt,
  ];
}

WorkItemState _workItemStateFromJson(String value) =>
    WorkItemState.fromWire(value);

String _workItemStateToJson(WorkItemState value) => value.wire;

TransitionTrigger _transitionTriggerFromJson(String value) =>
    TransitionTrigger.fromWire(value);

String _transitionTriggerToJson(TransitionTrigger value) => value.wire;

ActorType _actorTypeFromJson(String value) => ActorType.fromWire(value);

String _actorTypeToJson(ActorType value) => value.wire;

TransitionOutcome _transitionOutcomeFromJson(String value) =>
    TransitionOutcome.fromWire(value);

String _transitionOutcomeToJson(TransitionOutcome value) => value.wire;
