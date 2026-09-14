// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Job _$JobFromJson(Map<String, dynamic> json) => Job(
  jobId: json['jobId'] as String,
  workItemId: json['workItemId'] as String,
  jobType: _jobTypeFromJson(json['jobType'] as String),
  requiredRole: _agentRoleFromJson(json['requiredRole'] as String),
  requiredCapabilities: _workerCapabilitiesFromJson(
    json['requiredCapabilities'] as List?,
  ),
  priority: _jobPriorityFromJson(json['priority'] as String),
  state: _jobStateFromJson(json['state'] as String),
  dedupeKey: json['dedupeKey'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  instruction: json['instruction'] as String,
  attempt: (json['attempt'] as num).toInt(),
  maxAttempts: (json['maxAttempts'] as num).toInt(),
  version: (json['version'] as num).toInt(),
  availableAt: json['availableAt'] == null
      ? null
      : DateTime.parse(json['availableAt'] as String),
  startedAt: json['startedAt'] == null
      ? null
      : DateTime.parse(json['startedAt'] as String),
  completedAt: json['completedAt'] == null
      ? null
      : DateTime.parse(json['completedAt'] as String),
  executionReference: json['executionReference'] == null
      ? null
      : JobExecutionReference.fromJson(
          json['executionReference'] as Map<String, dynamic>,
        ),
  workerId: json['workerId'] as String?,
  failure: json['failure'] == null
      ? null
      : JobFailure.fromJson(json['failure'] as Map<String, dynamic>),
  cancelReason: json['cancelReason'] as String?,
);

Map<String, dynamic> _$JobToJson(Job instance) => <String, dynamic>{
  'jobId': instance.jobId,
  'workItemId': instance.workItemId,
  'jobType': _jobTypeToJson(instance.jobType),
  'requiredRole': _agentRoleToJson(instance.requiredRole),
  if (_workerCapabilitiesToJson(instance.requiredCapabilities)
      case final value?)
    'requiredCapabilities': value,
  'priority': _jobPriorityToJson(instance.priority),
  'state': _jobStateToJson(instance.state),
  'dedupeKey': instance.dedupeKey,
  'createdAt': instance.createdAt.toIso8601String(),
  if (instance.availableAt?.toIso8601String() case final value?)
    'availableAt': value,
  'instruction': instance.instruction,
  'attempt': instance.attempt,
  'maxAttempts': instance.maxAttempts,
  if (instance.startedAt?.toIso8601String() case final value?)
    'startedAt': value,
  if (instance.completedAt?.toIso8601String() case final value?)
    'completedAt': value,
  if (instance.executionReference?.toJson() case final value?)
    'executionReference': value,
  if (instance.workerId case final value?) 'workerId': value,
  if (instance.failure?.toJson() case final value?) 'failure': value,
  if (instance.cancelReason case final value?) 'cancelReason': value,
  'version': instance.version,
};

JobFailure _$JobFailureFromJson(Map<String, dynamic> json) => JobFailure(
  code: _jobFailureCodeFromJson(json['code'] as String),
  kind: _jobFailureKindFromJson(json['kind'] as String),
  reason: json['reason'] as String?,
);

Map<String, dynamic> _$JobFailureToJson(JobFailure instance) =>
    <String, dynamic>{
      'code': _jobFailureCodeToJson(instance.code),
      'kind': _jobFailureKindToJson(instance.kind),
      if (instance.reason case final value?) 'reason': value,
    };
