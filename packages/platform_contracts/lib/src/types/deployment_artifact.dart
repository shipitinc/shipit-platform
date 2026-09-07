import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'deployment_artifact.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class DeploymentArtifact extends Equatable {
  const DeploymentArtifact({
    required this.artifactId,
    required this.contentHash,
    required this.manifest,
    required this.builtAt,
    required this.builtBy,
    this.labels,
  });

  final String artifactId;
  final String contentHash;
  final ArtifactManifest manifest;
  final DateTime builtAt;
  final String builtBy;
  final Map<String, String>? labels;

  factory DeploymentArtifact.fromJson(Map<String, dynamic> json) =>
      _$DeploymentArtifactFromJson(json);

  Map<String, dynamic> toJson() => _$DeploymentArtifactToJson(this);

  @override
  List<Object?> get props => [
    artifactId,
    contentHash,
    manifest,
    builtAt,
    builtBy,
    labels,
  ];
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class ArtifactManifest extends Equatable {
  const ArtifactManifest({
    required this.name,
    required this.version,
    required this.gitCommit,
    required this.files,
    required this.sbom,
    this.metadata,
  });

  final String name;
  final String version;
  final String gitCommit;
  final List<ArtifactFile> files;
  final SoftwareBillOfMaterials sbom;
  final Map<String, String>? metadata;

  factory ArtifactManifest.fromJson(Map<String, dynamic> json) =>
      _$ArtifactManifestFromJson(json);

  Map<String, dynamic> toJson() => _$ArtifactManifestToJson(this);

  @override
  List<Object?> get props => [name, version, gitCommit, files, sbom, metadata];
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class ArtifactFile extends Equatable {
  const ArtifactFile({
    required this.path,
    required this.sha256,
    required this.sizeBytes,
    required this.mediaType,
  });

  final String path;
  final String sha256;
  final int sizeBytes;
  final String mediaType;

  factory ArtifactFile.fromJson(Map<String, dynamic> json) =>
      _$ArtifactFileFromJson(json);

  Map<String, dynamic> toJson() => _$ArtifactFileToJson(this);

  @override
  List<Object?> get props => [path, sha256, sizeBytes, mediaType];
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class SoftwareBillOfMaterials extends Equatable {
  const SoftwareBillOfMaterials({
    required this.format,
    required this.version,
    required this.components,
  });

  final String format;
  final String version;
  final List<SBOMComponent> components;

  factory SoftwareBillOfMaterials.fromJson(Map<String, dynamic> json) =>
      _$SoftwareBillOfMaterialsFromJson(json);

  Map<String, dynamic> toJson() => _$SoftwareBillOfMaterialsToJson(this);

  @override
  List<Object?> get props => [format, version, components];
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class SBOMComponent extends Equatable {
  const SBOMComponent({
    required this.name,
    required this.version,
    required this.type,
    this.purl,
    this.hashes,
    this.licenses,
  });

  final String name;
  final String version;
  final String type;
  final String? purl;
  final Map<String, String>? hashes;
  final List<String>? licenses;

  factory SBOMComponent.fromJson(Map<String, dynamic> json) =>
      _$SBOMComponentFromJson(json);

  Map<String, dynamic> toJson() => _$SBOMComponentToJson(this);

  @override
  List<Object?> get props => [name, version, type, purl, hashes, licenses];
}
