// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_execution_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentWorkspace _$AgentWorkspaceFromJson(Map<String, dynamic> json) =>
    AgentWorkspace(
      workspaceId: json['workspaceId'] as String,
      path: json['path'] as String,
      startingRevision: json['startingRevision'] as String?,
      allowedPaths: (json['allowedPaths'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$AgentWorkspaceToJson(
  AgentWorkspace instance,
) => <String, dynamic>{
  'workspaceId': instance.workspaceId,
  'path': instance.path,
  if (instance.startingRevision case final value?) 'startingRevision': value,
  if (instance.allowedPaths case final value?) 'allowedPaths': value,
};

ExpectedArtifact _$ExpectedArtifactFromJson(Map<String, dynamic> json) =>
    ExpectedArtifact(
      description: json['description'] as String,
      pathPattern: json['pathPattern'] as String?,
      required: json['required'] as bool? ?? false,
    );

Map<String, dynamic> _$ExpectedArtifactToJson(ExpectedArtifact instance) =>
    <String, dynamic>{
      'description': instance.description,
      if (instance.pathPattern case final value?) 'pathPattern': value,
      'required': instance.required,
    };

AgentExecutionRequest _$AgentExecutionRequestFromJson(
  Map<String, dynamic> json,
) => AgentExecutionRequest(
  executionId: json['executionId'] as String,
  workItemId: json['workItemId'] as String,
  role: _agentRoleFromJson(json['role'] as String),
  runtimeTypeId: json['runtimeTypeId'] as String,
  workspace: AgentWorkspace.fromJson(json['workspace'] as Map<String, dynamic>),
  instruction: json['instruction'] as String,
  timeoutSeconds: (json['timeoutSeconds'] as num).toInt(),
  permittedScope: json['permittedScope'] as String?,
  expectedResult: json['expectedResult'] as Map<String, dynamic>?,
  expectedArtifacts:
      (json['expectedArtifacts'] as List<dynamic>?)
          ?.map((e) => ExpectedArtifact.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  runtimeConfig: (json['runtimeConfig'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  environment: (json['environment'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$AgentExecutionRequestToJson(
  AgentExecutionRequest instance,
) => <String, dynamic>{
  'executionId': instance.executionId,
  'workItemId': instance.workItemId,
  'role': _agentRoleToJson(instance.role),
  'runtimeTypeId': instance.runtimeTypeId,
  'workspace': instance.workspace.toJson(),
  'instruction': instance.instruction,
  'timeoutSeconds': instance.timeoutSeconds,
  if (instance.permittedScope case final value?) 'permittedScope': value,
  if (instance.expectedResult case final value?) 'expectedResult': value,
  'expectedArtifacts': instance.expectedArtifacts
      .map((e) => e.toJson())
      .toList(),
  if (instance.runtimeConfig case final value?) 'runtimeConfig': value,
  if (instance.environment case final value?) 'environment': value,
  if (instance.createdAt?.toIso8601String() case final value?)
    'createdAt': value,
};
