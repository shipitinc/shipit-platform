// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deployment_artifact.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeploymentArtifact _$DeploymentArtifactFromJson(Map<String, dynamic> json) =>
    DeploymentArtifact(
      artifactId: json['artifactId'] as String,
      contentHash: json['contentHash'] as String,
      manifest: ArtifactManifest.fromJson(
        json['manifest'] as Map<String, dynamic>,
      ),
      builtAt: DateTime.parse(json['builtAt'] as String),
      builtBy: json['builtBy'] as String,
      labels: (json['labels'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
    );

Map<String, dynamic> _$DeploymentArtifactToJson(DeploymentArtifact instance) =>
    <String, dynamic>{
      'artifactId': instance.artifactId,
      'contentHash': instance.contentHash,
      'manifest': instance.manifest.toJson(),
      'builtAt': instance.builtAt.toIso8601String(),
      'builtBy': instance.builtBy,
      'labels': ?instance.labels,
    };

ArtifactManifest _$ArtifactManifestFromJson(Map<String, dynamic> json) =>
    ArtifactManifest(
      name: json['name'] as String,
      version: json['version'] as String,
      gitCommit: json['gitCommit'] as String,
      files: (json['files'] as List<dynamic>)
          .map((e) => ArtifactFile.fromJson(e as Map<String, dynamic>))
          .toList(),
      sbom: SoftwareBillOfMaterials.fromJson(
        json['sbom'] as Map<String, dynamic>,
      ),
      metadata: (json['metadata'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
    );

Map<String, dynamic> _$ArtifactManifestToJson(ArtifactManifest instance) =>
    <String, dynamic>{
      'name': instance.name,
      'version': instance.version,
      'gitCommit': instance.gitCommit,
      'files': instance.files.map((e) => e.toJson()).toList(),
      'sbom': instance.sbom.toJson(),
      'metadata': ?instance.metadata,
    };

ArtifactFile _$ArtifactFileFromJson(Map<String, dynamic> json) => ArtifactFile(
  path: json['path'] as String,
  sha256: json['sha256'] as String,
  sizeBytes: (json['sizeBytes'] as num).toInt(),
  mediaType: json['mediaType'] as String,
);

Map<String, dynamic> _$ArtifactFileToJson(ArtifactFile instance) =>
    <String, dynamic>{
      'path': instance.path,
      'sha256': instance.sha256,
      'sizeBytes': instance.sizeBytes,
      'mediaType': instance.mediaType,
    };

SoftwareBillOfMaterials _$SoftwareBillOfMaterialsFromJson(
  Map<String, dynamic> json,
) => SoftwareBillOfMaterials(
  format: json['format'] as String,
  version: json['version'] as String,
  components: (json['components'] as List<dynamic>)
      .map((e) => SBOMComponent.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SoftwareBillOfMaterialsToJson(
  SoftwareBillOfMaterials instance,
) => <String, dynamic>{
  'format': instance.format,
  'version': instance.version,
  'components': instance.components.map((e) => e.toJson()).toList(),
};

SBOMComponent _$SBOMComponentFromJson(Map<String, dynamic> json) =>
    SBOMComponent(
      name: json['name'] as String,
      version: json['version'] as String,
      type: json['type'] as String,
      purl: json['purl'] as String?,
      hashes: (json['hashes'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      licenses: (json['licenses'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$SBOMComponentToJson(SBOMComponent instance) =>
    <String, dynamic>{
      'name': instance.name,
      'version': instance.version,
      'type': instance.type,
      'purl': ?instance.purl,
      'hashes': ?instance.hashes,
      'licenses': ?instance.licenses,
    };
