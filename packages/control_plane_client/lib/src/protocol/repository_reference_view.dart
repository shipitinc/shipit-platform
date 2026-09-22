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

/// A repository belonging to exactly one Product (S-1 DIRECT scope).
abstract class RepositoryReferenceView implements _i1.SerializableModel {
  RepositoryReferenceView._({
    required this.repositoryId,
    required this.productId,
    required this.kind,
    required this.uri,
    required this.provider,
    required this.addedAt,
    required this.version,
  });

  factory RepositoryReferenceView({
    required String repositoryId,
    required String productId,
    required String kind,
    required String uri,
    required String provider,
    required DateTime addedAt,
    required int version,
  }) = _RepositoryReferenceViewImpl;

  factory RepositoryReferenceView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return RepositoryReferenceView(
      repositoryId: jsonSerialization['repositoryId'] as String,
      productId: jsonSerialization['productId'] as String,
      kind: jsonSerialization['kind'] as String,
      uri: jsonSerialization['uri'] as String,
      provider: jsonSerialization['provider'] as String,
      addedAt: _i1.DateTimeJsonExtension.fromJson(jsonSerialization['addedAt']),
      version: jsonSerialization['version'] as int,
    );
  }

  String repositoryId;

  String productId;

  /// frontend | backend | infra | monorepo | app | ...
  String kind;

  String uri;

  String provider;

  DateTime addedAt;

  int version;

  /// Returns a shallow copy of this [RepositoryReferenceView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  RepositoryReferenceView copyWith({
    String? repositoryId,
    String? productId,
    String? kind,
    String? uri,
    String? provider,
    DateTime? addedAt,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RepositoryReferenceView',
      'repositoryId': repositoryId,
      'productId': productId,
      'kind': kind,
      'uri': uri,
      'provider': provider,
      'addedAt': addedAt.toJson(),
      'version': version,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _RepositoryReferenceViewImpl extends RepositoryReferenceView {
  _RepositoryReferenceViewImpl({
    required String repositoryId,
    required String productId,
    required String kind,
    required String uri,
    required String provider,
    required DateTime addedAt,
    required int version,
  }) : super._(
         repositoryId: repositoryId,
         productId: productId,
         kind: kind,
         uri: uri,
         provider: provider,
         addedAt: addedAt,
         version: version,
       );

  /// Returns a shallow copy of this [RepositoryReferenceView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  RepositoryReferenceView copyWith({
    String? repositoryId,
    String? productId,
    String? kind,
    String? uri,
    String? provider,
    DateTime? addedAt,
    int? version,
  }) {
    return RepositoryReferenceView(
      repositoryId: repositoryId ?? this.repositoryId,
      productId: productId ?? this.productId,
      kind: kind ?? this.kind,
      uri: uri ?? this.uri,
      provider: provider ?? this.provider,
      addedAt: addedAt ?? this.addedAt,
      version: version ?? this.version,
    );
  }
}
