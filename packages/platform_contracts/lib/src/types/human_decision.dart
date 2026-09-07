import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/human_decision.dart';

part 'human_decision.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class HumanDecision extends Equatable {
  const HumanDecision({
    required this.decisionId,
    required this.workflowId,
    required this.decisionType,
    required this.decider,
    required this.choice,
    required this.rationale,
    required this.timestamp,
    required this.signature,
    this.context,
    this.expiration,
    this.metadata,
  });

  final String decisionId;
  final String workflowId;
  @JsonKey(
    fromJson: _humanDecisionTypeFromJson,
    toJson: _humanDecisionTypeToJson,
  )
  final HumanDecisionType decisionType;
  final String decider;
  @JsonKey(
    fromJson: _humanDecisionChoiceFromJson,
    toJson: _humanDecisionChoiceToJson,
  )
  final HumanDecisionChoice choice;
  final String rationale;
  final DateTime timestamp;
  final DecisionSignature signature;
  final DecisionContext? context;
  final DateTime? expiration;
  final Map<String, dynamic>? metadata;

  factory HumanDecision.fromJson(Map<String, dynamic> json) =>
      _$HumanDecisionFromJson(json);

  Map<String, dynamic> toJson() => _$HumanDecisionToJson(this);

  @override
  List<Object?> get props => [
    decisionId,
    workflowId,
    decisionType,
    decider,
    choice,
    rationale,
    timestamp,
    signature,
    context,
    expiration,
    metadata,
  ];
}

HumanDecisionType _humanDecisionTypeFromJson(String value) =>
    HumanDecisionType.fromWire(value);

String _humanDecisionTypeToJson(HumanDecisionType value) => value.wire;

HumanDecisionChoice _humanDecisionChoiceFromJson(String value) =>
    HumanDecisionChoice.fromWire(value);

String _humanDecisionChoiceToJson(HumanDecisionChoice value) => value.wire;

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class DecisionSignature extends Equatable {
  const DecisionSignature({
    required this.algorithm,
    required this.publicKey,
    required this.signature,
    required this.signedAt,
  });

  final String algorithm;
  final String publicKey;
  final String signature;
  final DateTime signedAt;

  factory DecisionSignature.fromJson(Map<String, dynamic> json) =>
      _$DecisionSignatureFromJson(json);

  Map<String, dynamic> toJson() => _$DecisionSignatureToJson(this);

  @override
  List<Object?> get props => [algorithm, publicKey, signature, signedAt];
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class DecisionContext extends Equatable {
  const DecisionContext({
    required this.workflowState,
    required this.availableOptions,
    this.relatedDecisions,
  });

  final String workflowState;
  final List<String> availableOptions;
  final List<String>? relatedDecisions;

  factory DecisionContext.fromJson(Map<String, dynamic> json) =>
      _$DecisionContextFromJson(json);

  Map<String, dynamic> toJson() => _$DecisionContextToJson(this);

  @override
  List<Object?> get props => [
    workflowState,
    availableOptions,
    relatedDecisions,
  ];
}
