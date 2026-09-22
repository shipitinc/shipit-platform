import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

import '../enums/product_state.dart';

part 'product.g.dart';

/// A registered Product — the canonical, durable, independently governed
/// software unit (checkpoint 006 §0A/§3).
///
/// This is the **registry / identity record** only. Distinction per checkpoint
/// 006 §ProductManifest:
/// - [Product] is the durable identity row (stable [productId], name,
///   [state] lifecycle, timestamps).
/// - [ProductManifest] is the definition/configuration payload (capabilities,
///   environments, governance contracts), referenced by [manifestVersion].
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class Product extends Equatable {
  const Product({
    required this.productId,
    required this.name,
    this.description,
    this.manifestVersion,
    this.state = ProductState.registered,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  });

  /// durable, canonical product identity — NOT the working directory, repo
  /// URL, repo path, chat/session, or an agent execution.
  final String productId;

  final String name;

  final String? description;

  /// Version of the associated [ProductManifest] definition payload, if one
  /// has been registered. Distinct from the registry record version.
  final String? manifestVersion;

  /// Per-product lifecycle. Serialised via its wire string, not `.name`, so
  /// `baseline_pending` never round-trips as `baselinePending`.
  @JsonKey(fromJson: _stateFromWire, toJson: _stateToWire)
  final ProductState state;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Optimistic-concurrency version for CAS writes.
  final int version;

  Product copyWith({
    String? name,
    String? description,
    String? manifestVersion,
    ProductState? state,
    DateTime? updatedAt,
    int? version,
  }) => Product(
    productId: productId,
    name: name ?? this.name,
    description: description ?? this.description,
    manifestVersion: manifestVersion ?? this.manifestVersion,
    state: state ?? this.state,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
  );

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);

  Map<String, dynamic> toJson() => _$ProductToJson(this);

  @override
  List<Object?> get props => [
    productId,
    name,
    description,
    manifestVersion,
    state,
    createdAt,
    updatedAt,
    version,
  ];
}

ProductState _stateFromWire(String value) => ProductState.fromWire(value);

String _stateToWire(ProductState state) => state.wire;
