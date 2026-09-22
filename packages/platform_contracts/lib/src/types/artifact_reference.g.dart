// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'artifact_reference.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ArtifactReference _$ArtifactReferenceFromJson(Map<String, dynamic> json) =>
    ArtifactReference(
      artifactId: json['artifactId'] as String,
      artifactType: _artifactTypeFromJson(json['artifactType'] as String),
      uri: json['uri'] as String,
      provider: json['provider'] as String?,
      contentHash: json['contentHash'] as String?,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$ArtifactReferenceToJson(ArtifactReference instance) =>
    <String, dynamic>{
      'artifactId': instance.artifactId,
      'artifactType': _artifactTypeToJson(instance.artifactType),
      'uri': instance.uri,
      'provider': ?instance.provider,
      'contentHash': ?instance.contentHash,
      'description': ?instance.description,
      'createdAt': instance.createdAt.toIso8601String(),
    };
