// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'human_decision.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HumanDecision _$HumanDecisionFromJson(Map<String, dynamic> json) =>
    HumanDecision(
      decisionId: json['decisionId'] as String,
      workItemId: json['workItemId'] as String,
      decisionType: _humanDecisionTypeFromJson(json['decisionType'] as String),
      status: json['status'] == null
          ? HumanDecisionStatus.pending
          : _humanDecisionStatusFromJson(json['status'] as String),
      question: json['question'] as String?,
      context: json['context'] == null
          ? null
          : DecisionContext.fromJson(json['context'] as Map<String, dynamic>),
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => HumanDecisionOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      recommendation: json['recommendation'] as String?,
      blocking: json['blocking'] as bool? ?? true,
      requestedAt: json['requestedAt'] == null
          ? null
          : DateTime.parse(json['requestedAt'] as String),
      expiration: json['expiration'] == null
          ? null
          : DateTime.parse(json['expiration'] as String),
      decider: json['decider'] as String?,
      choice: _humanDecisionChoiceFromJson(json['choice'] as String?),
      rationale: json['rationale'] as String?,
      timestamp: json['timestamp'] == null
          ? null
          : DateTime.parse(json['timestamp'] as String),
      signature: json['signature'] == null
          ? null
          : DecisionSignature.fromJson(
              json['signature'] as Map<String, dynamic>,
            ),
      resolvedOptionId: json['resolvedOptionId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$HumanDecisionToJson(
  HumanDecision instance,
) => <String, dynamic>{
  'decisionId': instance.decisionId,
  'workItemId': instance.workItemId,
  'decisionType': _humanDecisionTypeToJson(instance.decisionType),
  'status': _humanDecisionStatusToJson(instance.status),
  if (instance.question case final value?) 'question': value,
  if (instance.context?.toJson() case final value?) 'context': value,
  if (instance.options?.map((e) => e.toJson()).toList() case final value?)
    'options': value,
  if (instance.recommendation case final value?) 'recommendation': value,
  if (instance.blocking case final value?) 'blocking': value,
  if (instance.requestedAt?.toIso8601String() case final value?)
    'requestedAt': value,
  if (instance.expiration?.toIso8601String() case final value?)
    'expiration': value,
  if (instance.decider case final value?) 'decider': value,
  if (_humanDecisionChoiceToJson(instance.choice) case final value?)
    'choice': value,
  if (instance.rationale case final value?) 'rationale': value,
  if (instance.timestamp?.toIso8601String() case final value?)
    'timestamp': value,
  if (instance.signature?.toJson() case final value?) 'signature': value,
  if (instance.resolvedOptionId case final value?) 'resolvedOptionId': value,
  if (instance.metadata case final value?) 'metadata': value,
  'updatedAt': instance.updatedAt.toIso8601String(),
};

HumanDecisionOption _$HumanDecisionOptionFromJson(Map<String, dynamic> json) =>
    HumanDecisionOption(
      optionId: json['optionId'] as String,
      label: json['label'] as String,
      description: json['description'] as String?,
      recommended: json['recommended'] as bool? ?? false,
    );

Map<String, dynamic> _$HumanDecisionOptionToJson(
  HumanDecisionOption instance,
) => <String, dynamic>{
  'optionId': instance.optionId,
  'label': instance.label,
  if (instance.description case final value?) 'description': value,
  if (instance.recommended case final value?) 'recommended': value,
};

DecisionSignature _$DecisionSignatureFromJson(Map<String, dynamic> json) =>
    DecisionSignature(
      algorithm: json['algorithm'] as String,
      publicKey: json['publicKey'] as String,
      signature: json['signature'] as String,
      signedAt: DateTime.parse(json['signedAt'] as String),
    );

Map<String, dynamic> _$DecisionSignatureToJson(DecisionSignature instance) =>
    <String, dynamic>{
      'algorithm': instance.algorithm,
      'publicKey': instance.publicKey,
      'signature': instance.signature,
      'signedAt': instance.signedAt.toIso8601String(),
    };

DecisionContext _$DecisionContextFromJson(Map<String, dynamic> json) =>
    DecisionContext(
      workflowState: json['workflowState'] as String,
      availableOptions: (json['availableOptions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      relatedDecisions: (json['relatedDecisions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$DecisionContextToJson(
  DecisionContext instance,
) => <String, dynamic>{
  'workflowState': instance.workflowState,
  'availableOptions': instance.availableOptions,
  if (instance.relatedDecisions case final value?) 'relatedDecisions': value,
};
