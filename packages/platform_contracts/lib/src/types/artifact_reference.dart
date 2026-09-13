import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/artifact_type.dart';

part 'artifact_reference.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class ArtifactReference extends Equatable {
  const ArtifactReference({
    required this.artifactId,
    required this.artifactType,
    required this.uri,
    this.provider,
    this.contentHash,
    this.description,
    required this.createdAt,
  });

  final String artifactId;
  @JsonKey(fromJson: _artifactTypeFromJson, toJson: _artifactTypeToJson)
  final ArtifactType artifactType;
  final String uri;
  final String? provider;
  final String? contentHash;
  final String? description;
  final DateTime createdAt;

  factory ArtifactReference.fromJson(Map<String, dynamic> json) =>
      _$ArtifactReferenceFromJson(json);

  Map<String, dynamic> toJson() => _$ArtifactReferenceToJson(this);

  @override
  List<Object?> get props => [
    artifactId,
    artifactType,
    uri,
    provider,
    contentHash,
    description,
    createdAt,
  ];
}

ArtifactType _artifactTypeFromJson(String value) =>
    ArtifactType.fromWire(value);

String _artifactTypeToJson(ArtifactType value) => value.wire;
