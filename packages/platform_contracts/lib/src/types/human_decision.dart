import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/human_decision.dart';

part 'human_decision.g.dart';

/// A durable, auditable human decision.
///
/// A decision is created in [HumanDecisionStatus.pending] and resolved later
/// by a human. While [status] is not [HumanDecisionStatus.resolved] no
/// resolution fields ([HumanDecision.decider], [HumanDecision.choice],
/// [HumanDecision.rationale], [HumanDecision.timestamp],
/// [HumanDecision.signature]) are present.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class HumanDecision extends Equatable {
  const HumanDecision({
    required this.decisionId,
    required this.workItemId,
    required this.decisionType,
    required this.status,
    this.question,
    this.context,
    this.options,
    this.recommendation,
    this.blocking = true,
    this.requestedAt,
    this.expiration,
    this.decider,
    this.choice,
    this.rationale,
    this.timestamp,
    this.signature,
    this.resolvedOptionId,
    this.metadata,
    required this.updatedAt,
  });

  final String decisionId;
  final String workItemId;
  @JsonKey(
    fromJson: _humanDecisionTypeFromJson,
    toJson: _humanDecisionTypeToJson,
  )
  final HumanDecisionType decisionType;
  @JsonKey(
    fromJson: _humanDecisionStatusFromJson,
    toJson: _humanDecisionStatusToJson,
    defaultValue: HumanDecisionStatus.pending,
  )
  final HumanDecisionStatus status;
  final String? question;
  final DecisionContext? context;
  final List<HumanDecisionOption>? options;
  final String? recommendation;
  final bool? blocking;
  final DateTime? requestedAt;
  final DateTime? expiration;
  final String? decider;
  @JsonKey(
    fromJson: _humanDecisionChoiceFromJson,
    toJson: _humanDecisionChoiceToJson,
  )
  final HumanDecisionChoice? choice;
  final String? rationale;
  final DateTime? timestamp;
  final DecisionSignature? signature;
  final String? resolvedOptionId;
  final Map<String, dynamic>? metadata;
  final DateTime updatedAt;

  factory HumanDecision.fromJson(Map<String, dynamic> json) =>
      _$HumanDecisionFromJson(json);

  Map<String, dynamic> toJson() => _$HumanDecisionToJson(this);

  bool get isResolved => status.isResolved;

  @override
  List<Object?> get props => [
    decisionId,
    workItemId,
    decisionType,
    status,
    question,
    context,
    options,
    recommendation,
    blocking,
    requestedAt,
    expiration,
    decider,
    choice,
    rationale,
    timestamp,
    signature,
    resolvedOptionId,
    metadata,
    updatedAt,
  ];
}

HumanDecisionType _humanDecisionTypeFromJson(String value) =>
    HumanDecisionType.fromWire(value);

String _humanDecisionTypeToJson(HumanDecisionType value) => value.wire;

HumanDecisionChoice? _humanDecisionChoiceFromJson(String? value) =>
    value == null ? null : HumanDecisionChoice.fromWire(value);

String? _humanDecisionChoiceToJson(HumanDecisionChoice? value) => value?.wire;

HumanDecisionStatus _humanDecisionStatusFromJson(String value) =>
    HumanDecisionStatus.fromWire(value);

String _humanDecisionStatusToJson(HumanDecisionStatus value) => value.wire;

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class HumanDecisionOption extends Equatable {
  const HumanDecisionOption({
    required this.optionId,
    required this.label,
    this.description,
    this.recommended = false,
  });

  final String optionId;
  final String label;
  final String? description;
  final bool? recommended;

  factory HumanDecisionOption.fromJson(Map<String, dynamic> json) =>
      _$HumanDecisionOptionFromJson(json);

  Map<String, dynamic> toJson() => _$HumanDecisionOptionToJson(this);

  @override
  List<Object?> get props => [optionId, label, description, recommended];
}

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
