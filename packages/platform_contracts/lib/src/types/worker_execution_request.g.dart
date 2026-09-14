// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_execution_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkerExecutionRequest _$WorkerExecutionRequestFromJson(
  Map<String, dynamic> json,
) => WorkerExecutionRequest(
  workerExecutionId: json['workerExecutionId'] as String,
  workItemId: json['workItemId'] as String,
  repositoryPath: json['repositoryPath'] as String,
  startingRevision: json['startingRevision'] as String,
  requiredCapabilities: _workerCapabilitiesFromJson(
    json['requiredCapabilities'] as List?,
  ),
  role: _agentRoleFromJson(json['role'] as String),
  instruction: json['instruction'] as String,
  timeoutSeconds: (json['timeoutSeconds'] as num).toInt(),
  runtimeTypeId: json['runtimeTypeId'] as String,
  expectedArtifacts:
      (json['expectedArtifacts'] as List<dynamic>?)
          ?.map((e) => ExpectedArtifact.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  cleanupPolicy:
      $enumDecodeNullable(
        _$WorkerCleanupPolicyEnumMap,
        json['cleanupPolicy'],
      ) ??
      WorkerCleanupPolicy.removeAlways,
  envAllowlist: (json['envAllowlist'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  environment: (json['environment'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  runtimeConfig: (json['runtimeConfig'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$WorkerExecutionRequestToJson(
  WorkerExecutionRequest instance,
) => <String, dynamic>{
  'workerExecutionId': instance.workerExecutionId,
  'workItemId': instance.workItemId,
  'repositoryPath': instance.repositoryPath,
  'startingRevision': instance.startingRevision,
  if (_workerCapabilitiesToJson(instance.requiredCapabilities)
      case final value?)
    'requiredCapabilities': value,
  'role': _agentRoleToJson(instance.role),
  'instruction': instance.instruction,
  'timeoutSeconds': instance.timeoutSeconds,
  'runtimeTypeId': instance.runtimeTypeId,
  'expectedArtifacts': instance.expectedArtifacts
      .map((e) => e.toJson())
      .toList(),
  'cleanupPolicy': _$WorkerCleanupPolicyEnumMap[instance.cleanupPolicy]!,
  if (instance.envAllowlist case final value?) 'envAllowlist': value,
  if (instance.environment case final value?) 'environment': value,
  if (instance.runtimeConfig case final value?) 'runtimeConfig': value,
  if (instance.createdAt?.toIso8601String() case final value?)
    'createdAt': value,
};

const _$WorkerCleanupPolicyEnumMap = {
  WorkerCleanupPolicy.removeAlways: 'removeAlways',
  WorkerCleanupPolicy.preserveOnFailure: 'preserveOnFailure',
};
