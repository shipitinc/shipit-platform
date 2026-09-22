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

abstract class ArtifactReferenceView implements _i1.SerializableModel {
  ArtifactReferenceView._({
    required this.artifactId,
    required this.artifactType,
    required this.uri,
    this.provider,
    this.contentHash,
    this.description,
    this.createdAt,
  });

  factory ArtifactReferenceView({
    required String artifactId,
    required String artifactType,
    required String uri,
    String? provider,
    String? contentHash,
    String? description,
    DateTime? createdAt,
  }) = _ArtifactReferenceViewImpl;

  factory ArtifactReferenceView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return ArtifactReferenceView(
      artifactId: jsonSerialization['artifactId'] as String,
      artifactType: jsonSerialization['artifactType'] as String,
      uri: jsonSerialization['uri'] as String,
      provider: jsonSerialization['provider'] as String?,
      contentHash: jsonSerialization['contentHash'] as String?,
      description: jsonSerialization['description'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  String artifactId;

  String artifactType;

  String uri;

  String? provider;

  String? contentHash;

  String? description;

  DateTime? createdAt;

  /// Returns a shallow copy of this [ArtifactReferenceView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ArtifactReferenceView copyWith({
    String? artifactId,
    String? artifactType,
    String? uri,
    String? provider,
    String? contentHash,
    String? description,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ArtifactReferenceView',
      'artifactId': artifactId,
      'artifactType': artifactType,
      'uri': uri,
      if (provider != null) 'provider': provider,
      if (contentHash != null) 'contentHash': contentHash,
      if (description != null) 'description': description,
      if (createdAt != null) 'createdAt': createdAt?.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ArtifactReferenceViewImpl extends ArtifactReferenceView {
  _ArtifactReferenceViewImpl({
    required String artifactId,
    required String artifactType,
    required String uri,
    String? provider,
    String? contentHash,
    String? description,
    DateTime? createdAt,
  }) : super._(
         artifactId: artifactId,
         artifactType: artifactType,
         uri: uri,
         provider: provider,
         contentHash: contentHash,
         description: description,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [ArtifactReferenceView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ArtifactReferenceView copyWith({
    String? artifactId,
    String? artifactType,
    String? uri,
    Object? provider = _Undefined,
    Object? contentHash = _Undefined,
    Object? description = _Undefined,
    Object? createdAt = _Undefined,
  }) {
    return ArtifactReferenceView(
      artifactId: artifactId ?? this.artifactId,
      artifactType: artifactType ?? this.artifactType,
      uri: uri ?? this.uri,
      provider: provider is String? ? provider : this.provider,
      contentHash: contentHash is String? ? contentHash : this.contentHash,
      description: description is String? ? description : this.description,
      createdAt: createdAt is DateTime? ? createdAt : this.createdAt,
    );
  }
}
