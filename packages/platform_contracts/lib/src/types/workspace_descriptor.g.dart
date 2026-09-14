// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_descriptor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkspaceDescriptor _$WorkspaceDescriptorFromJson(Map<String, dynamic> json) =>
    WorkspaceDescriptor(
      workspaceId: json['workspaceId'] as String,
      workerExecutionId: json['workerExecutionId'] as String,
      workerId: json['workerId'] as String,
      repositoryPath: json['repositoryPath'] as String,
      startingRevision: json['startingRevision'] as String,
      worktreePath: json['worktreePath'] as String,
      branch: json['branch'] as String?,
      detached: json['detached'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      cleanedAt: json['cleanedAt'] == null
          ? null
          : DateTime.parse(json['cleanedAt'] as String),
    );

Map<String, dynamic> _$WorkspaceDescriptorToJson(
  WorkspaceDescriptor instance,
) => <String, dynamic>{
  'workspaceId': instance.workspaceId,
  'workerExecutionId': instance.workerExecutionId,
  'workerId': instance.workerId,
  'repositoryPath': instance.repositoryPath,
  'startingRevision': instance.startingRevision,
  'worktreePath': instance.worktreePath,
  if (instance.branch case final value?) 'branch': value,
  'detached': instance.detached,
  'createdAt': instance.createdAt.toIso8601String(),
  if (instance.cleanedAt?.toIso8601String() case final value?)
    'cleanedAt': value,
};
