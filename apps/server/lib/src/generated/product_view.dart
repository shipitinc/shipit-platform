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

import 'package:serverpod/serverpod.dart' as _i1;

/// Registry row for one Product. `productId` is the durable identity; it is
/// never the repository URL, path, cwd, or a process-global.
abstract class ProductView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  ProductView._({
    required this.productId,
    required this.name,
    this.description,
    this.manifestVersion,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });

  factory ProductView({
    required String productId,
    required String name,
    String? description,
    String? manifestVersion,
    required String state,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int version,
  }) = _ProductViewImpl;

  factory ProductView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ProductView(
      productId: jsonSerialization['productId'] as String,
      name: jsonSerialization['name'] as String,
      description: jsonSerialization['description'] as String?,
      manifestVersion: jsonSerialization['manifestVersion'] as String?,
      state: jsonSerialization['state'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      version: jsonSerialization['version'] as int,
    );
  }

  String productId;

  String name;

  String? description;

  String? manifestVersion;

  /// registered | baseline_pending | baseline_blocked | baseline_review |
  /// governed | paused | archived.
  /// draft/active/deprecated are legacy parse-only values (ADR 0018).
  String state;

  DateTime createdAt;

  DateTime updatedAt;

  int version;

  /// Returns a shallow copy of this [ProductView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ProductView copyWith({
    String? productId,
    String? name,
    String? description,
    String? manifestVersion,
    String? state,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ProductView',
      'productId': productId,
      'name': name,
      if (description != null) 'description': description,
      if (manifestVersion != null) 'manifestVersion': manifestVersion,
      'state': state,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ProductView',
      'productId': productId,
      'name': name,
      if (description != null) 'description': description,
      if (manifestVersion != null) 'manifestVersion': manifestVersion,
      'state': state,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      'version': version,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ProductViewImpl extends ProductView {
  _ProductViewImpl({
    required String productId,
    required String name,
    String? description,
    String? manifestVersion,
    required String state,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int version,
  }) : super._(
         productId: productId,
         name: name,
         description: description,
         manifestVersion: manifestVersion,
         state: state,
         createdAt: createdAt,
         updatedAt: updatedAt,
         version: version,
       );

  /// Returns a shallow copy of this [ProductView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ProductView copyWith({
    String? productId,
    String? name,
    Object? description = _Undefined,
    Object? manifestVersion = _Undefined,
    String? state,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return ProductView(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      description: description is String? ? description : this.description,
      manifestVersion: manifestVersion is String?
          ? manifestVersion
          : this.manifestVersion,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }
}
