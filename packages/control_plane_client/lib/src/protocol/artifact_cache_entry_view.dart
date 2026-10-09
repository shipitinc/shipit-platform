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

/// One cached artifact on a registered worker.
abstract class ArtifactCacheEntryView implements _i1.SerializableModel {
  ArtifactCacheEntryView._({
    required this.artifactHash,
    required this.localPath,
    required this.cachedAt,
    this.sizeBytes,
  });

  factory ArtifactCacheEntryView({
    required String artifactHash,
    required String localPath,
    required DateTime cachedAt,
    int? sizeBytes,
  }) = _ArtifactCacheEntryViewImpl;

  factory ArtifactCacheEntryView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return ArtifactCacheEntryView(
      artifactHash: jsonSerialization['artifactHash'] as String,
      localPath: jsonSerialization['localPath'] as String,
      cachedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['cachedAt'],
      ),
      sizeBytes: jsonSerialization['sizeBytes'] as int?,
    );
  }

  String artifactHash;

  String localPath;

  DateTime cachedAt;

  int? sizeBytes;

  /// Returns a shallow copy of this [ArtifactCacheEntryView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ArtifactCacheEntryView copyWith({
    String? artifactHash,
    String? localPath,
    DateTime? cachedAt,
    int? sizeBytes,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ArtifactCacheEntryView',
      'artifactHash': artifactHash,
      'localPath': localPath,
      'cachedAt': cachedAt.toJson(),
      if (sizeBytes != null) 'sizeBytes': sizeBytes,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ArtifactCacheEntryViewImpl extends ArtifactCacheEntryView {
  _ArtifactCacheEntryViewImpl({
    required String artifactHash,
    required String localPath,
    required DateTime cachedAt,
    int? sizeBytes,
  }) : super._(
         artifactHash: artifactHash,
         localPath: localPath,
         cachedAt: cachedAt,
         sizeBytes: sizeBytes,
       );

  /// Returns a shallow copy of this [ArtifactCacheEntryView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ArtifactCacheEntryView copyWith({
    String? artifactHash,
    String? localPath,
    DateTime? cachedAt,
    Object? sizeBytes = _Undefined,
  }) {
    return ArtifactCacheEntryView(
      artifactHash: artifactHash ?? this.artifactHash,
      localPath: localPath ?? this.localPath,
      cachedAt: cachedAt ?? this.cachedAt,
      sizeBytes: sizeBytes is int? ? sizeBytes : this.sizeBytes,
    );
  }
}
