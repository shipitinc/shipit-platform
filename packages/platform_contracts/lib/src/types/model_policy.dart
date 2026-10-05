import 'package:meta/meta.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/agent_role.dart';

part 'model_policy.g.dart';

@JsonSerializable(explicitToJson: true)
@immutable
class ModelPolicy extends Equatable {
  const ModelPolicy({
    required this.role,
    required this.chain,
    required this.version,
    required this.updatedAt,
    required this.updatedByDecisionId,
  });

  @JsonKey(fromJson: _agentRoleFromJson, toJson: _agentRoleToJson)
  final AgentRole role;
  final List<ModelStep> chain;
  final int version;
  final DateTime updatedAt;
  final String updatedByDecisionId;

  factory ModelPolicy.fromJson(Map<String, dynamic> json) =>
      _$ModelPolicyFromJson(json);
  Map<String, dynamic> toJson() => _$ModelPolicyToJson(this);

  @override
  List<Object?> get props => [
    role,
    chain,
    version,
    updatedAt,
    updatedByDecisionId,
  ];
}

@JsonSerializable(explicitToJson: true)
@immutable
class ModelStep extends Equatable {
  const ModelStep({required this.modelId, required this.provider});

  final String modelId;
  final String provider;

  factory ModelStep.fromJson(Map<String, dynamic> json) =>
      _$ModelStepFromJson(json);
  Map<String, dynamic> toJson() => _$ModelStepToJson(this);

  @override
  List<Object?> get props => [modelId, provider];
}

AgentRole _agentRoleFromJson(String value) => AgentRole.fromWire(value);
String _agentRoleToJson(AgentRole value) => value.wire;
