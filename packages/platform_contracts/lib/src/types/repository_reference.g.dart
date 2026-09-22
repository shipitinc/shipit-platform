// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repository_reference.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RepositoryReference _$RepositoryReferenceFromJson(Map<String, dynamic> json) =>
    RepositoryReference(
      repositoryId: json['repositoryId'] as String,
      productId: json['productId'] as String,
      kind:
          $enumDecodeNullable(_$RepositoryKindEnumMap, json['kind']) ??
          RepositoryKind.monorepo,
      uri: json['uri'] as String,
      provider:
          $enumDecodeNullable(_$RepositoryProviderEnumMap, json['provider']) ??
          RepositoryProvider.local,
      addedAt: DateTime.parse(json['addedAt'] as String),
      version: (json['version'] as num?)?.toInt() ?? 1,
    );

Map<String, dynamic> _$RepositoryReferenceToJson(
  RepositoryReference instance,
) => <String, dynamic>{
  'repositoryId': instance.repositoryId,
  'productId': instance.productId,
  'kind': _$RepositoryKindEnumMap[instance.kind]!,
  'uri': instance.uri,
  'provider': _$RepositoryProviderEnumMap[instance.provider]!,
  'addedAt': instance.addedAt.toIso8601String(),
  'version': instance.version,
};

const _$RepositoryKindEnumMap = {
  RepositoryKind.monorepo: 'monorepo',
  RepositoryKind.frontend: 'frontend',
  RepositoryKind.backend: 'backend',
  RepositoryKind.infrastructure: 'infrastructure',
  RepositoryKind.library: 'library',
  RepositoryKind.app: 'app',
};

const _$RepositoryProviderEnumMap = {
  RepositoryProvider.github: 'github',
  RepositoryProvider.gitlab: 'gitlab',
  RepositoryProvider.ssh: 'ssh',
  RepositoryProvider.local: 'local',
};
