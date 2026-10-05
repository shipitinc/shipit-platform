// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_policy.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ModelPolicy _$ModelPolicyFromJson(Map<String, dynamic> json) => ModelPolicy(
  role: _agentRoleFromJson(json['role'] as String),
  chain: (json['chain'] as List<dynamic>)
      .map((e) => ModelStep.fromJson(e as Map<String, dynamic>))
      .toList(),
  version: (json['version'] as num).toInt(),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  updatedByDecisionId: json['updatedByDecisionId'] as String,
);

Map<String, dynamic> _$ModelPolicyToJson(ModelPolicy instance) =>
    <String, dynamic>{
      'role': _agentRoleToJson(instance.role),
      'chain': instance.chain.map((e) => e.toJson()).toList(),
      'version': instance.version,
      'updatedAt': instance.updatedAt.toIso8601String(),
      'updatedByDecisionId': instance.updatedByDecisionId,
    };

ModelStep _$ModelStepFromJson(Map<String, dynamic> json) => ModelStep(
  modelId: json['modelId'] as String,
  provider: json['provider'] as String,
);

Map<String, dynamic> _$ModelStepToJson(ModelStep instance) => <String, dynamic>{
  'modelId': instance.modelId,
  'provider': instance.provider,
};
