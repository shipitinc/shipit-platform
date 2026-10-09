/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:serverpod_client/serverpod_client.dart' as _i1;

/// One artifact an agent produced.
abstract class AgentArtifactView implements _i1.SerializableModel {
  AgentArtifactView._({
    required this.artifactId,
    required this.type,
    required this.path,
    required this.sha256,
    required this.sizeBytes,
    required this.mediaType,
    this.description,
  });

  factory AgentArtifactView({
    required String artifactId,
    required String type,
    required String path,
    required String sha256,
    required int sizeBytes,
    required String mediaType,
    String? description,
  }) = _AgentArtifactViewImpl;

  factory AgentArtifactView.fromJson(Map<String, dynamic> jsonSerialization) {
    return AgentArtifactView(
      artifactId: jsonSerialization['artifactId'] as String,
      type: jsonSerialization['type'] as String,
      path: jsonSerialization['path'] as String,
      sha256: jsonSerialization['sha256'] as String,
      sizeBytes: jsonSerialization['sizeBytes'] as int,
      mediaType: jsonSerialization['mediaType'] as String,
      description: jsonSerialization['description'] as String?,
    );
  }

  String artifactId;

  String type;

  String path;

  String sha256;

  int sizeBytes;

  String mediaType;

  String? description;

  /// Returns a shallow copy of this [AgentArtifactView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AgentArtifactView copyWith({
    String? artifactId,
    String? type,
    String? path,
    String? sha256,
    int? sizeBytes,
    String? mediaType,
    String? description,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentArtifactView',
      'artifactId': artifactId,
      'type': type,
      'path': path,
      'sha256': sha256,
      'sizeBytes': sizeBytes,
      'mediaType': mediaType,
      if (description != null) 'description': description,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AgentArtifactViewImpl extends AgentArtifactView {
  _AgentArtifactViewImpl({
    required String artifactId,
    required String type,
    required String path,
    required String sha256,
    required int sizeBytes,
    required String mediaType,
    String? description,
  }) : super._(
         artifactId: artifactId,
         type: type,
         path: path,
         sha256: sha256,
         sizeBytes: sizeBytes,
         mediaType: mediaType,
         description: description,
       );

  /// Returns a shallow copy of this [AgentArtifactView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AgentArtifactView copyWith({
    String? artifactId,
    String? type,
    String? path,
    String? sha256,
    int? sizeBytes,
    String? mediaType,
    Object? description = _Undefined,
  }) {
    return AgentArtifactView(
      artifactId: artifactId ?? this.artifactId,
      type: type ?? this.type,
      path: path ?? this.path,
      sha256: sha256 ?? this.sha256,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mediaType: mediaType ?? this.mediaType,
      description: description is String? ? description : this.description,
    );
  }
}
