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
import 'product_view.dart' as _i2;
import 'repository_reference_view.dart' as _i3;
import 'product_baseline_view.dart' as _i4;
import 'clarification_view.dart' as _i5;
import 'package:control_plane_client/src/protocol/protocol.dart' as _i6;

/// The bounded ProductContext(productId) projection: exactly one Product and
/// everything scoped to it. A row whose scope does not match the requested
/// productId is rejected at the boundary, never silently filtered.
abstract class ProductContextView implements _i1.SerializableModel {
  ProductContextView._({
    required this.product,
    required this.repositories,
    this.activeBaseline,
    required this.allBaselines,
    required this.openClarifications,
    this.snapshotId,
  });

  factory ProductContextView({
    required _i2.ProductView product,
    required List<_i3.RepositoryReferenceView> repositories,
    _i4.ProductBaselineView? activeBaseline,
    required List<_i4.ProductBaselineView> allBaselines,
    required List<_i5.ClarificationView> openClarifications,
    String? snapshotId,
  }) = _ProductContextViewImpl;

  factory ProductContextView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ProductContextView(
      product: _i6.Protocol().deserialize<_i2.ProductView>(
        jsonSerialization['product'],
      ),
      repositories: _i6.Protocol()
          .deserialize<List<_i3.RepositoryReferenceView>>(
            jsonSerialization['repositories'],
          ),
      activeBaseline: jsonSerialization['activeBaseline'] == null
          ? null
          : _i6.Protocol().deserialize<_i4.ProductBaselineView>(
              jsonSerialization['activeBaseline'],
            ),
      allBaselines: _i6.Protocol().deserialize<List<_i4.ProductBaselineView>>(
        jsonSerialization['allBaselines'],
      ),
      openClarifications: _i6.Protocol()
          .deserialize<List<_i5.ClarificationView>>(
            jsonSerialization['openClarifications'],
          ),
      snapshotId: jsonSerialization['snapshotId'] as String?,
    );
  }

  _i2.ProductView product;

  List<_i3.RepositoryReferenceView> repositories;

  _i4.ProductBaselineView? activeBaseline;

  List<_i4.ProductBaselineView> allBaselines;

  List<_i5.ClarificationView> openClarifications;

  String? snapshotId;

  /// Returns a shallow copy of this [ProductContextView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ProductContextView copyWith({
    _i2.ProductView? product,
    List<_i3.RepositoryReferenceView>? repositories,
    _i4.ProductBaselineView? activeBaseline,
    List<_i4.ProductBaselineView>? allBaselines,
    List<_i5.ClarificationView>? openClarifications,
    String? snapshotId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ProductContextView',
      'product': product.toJson(),
      'repositories': repositories.toJson(valueToJson: (v) => v.toJson()),
      if (activeBaseline != null) 'activeBaseline': activeBaseline?.toJson(),
      'allBaselines': allBaselines.toJson(valueToJson: (v) => v.toJson()),
      'openClarifications': openClarifications.toJson(
        valueToJson: (v) => v.toJson(),
      ),
      if (snapshotId != null) 'snapshotId': snapshotId,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ProductContextViewImpl extends ProductContextView {
  _ProductContextViewImpl({
    required _i2.ProductView product,
    required List<_i3.RepositoryReferenceView> repositories,
    _i4.ProductBaselineView? activeBaseline,
    required List<_i4.ProductBaselineView> allBaselines,
    required List<_i5.ClarificationView> openClarifications,
    String? snapshotId,
  }) : super._(
         product: product,
         repositories: repositories,
         activeBaseline: activeBaseline,
         allBaselines: allBaselines,
         openClarifications: openClarifications,
         snapshotId: snapshotId,
       );

  /// Returns a shallow copy of this [ProductContextView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ProductContextView copyWith({
    _i2.ProductView? product,
    List<_i3.RepositoryReferenceView>? repositories,
    Object? activeBaseline = _Undefined,
    List<_i4.ProductBaselineView>? allBaselines,
    List<_i5.ClarificationView>? openClarifications,
    Object? snapshotId = _Undefined,
  }) {
    return ProductContextView(
      product: product ?? this.product.copyWith(),
      repositories:
          repositories ?? this.repositories.map((e0) => e0.copyWith()).toList(),
      activeBaseline: activeBaseline is _i4.ProductBaselineView?
          ? activeBaseline
          : this.activeBaseline?.copyWith(),
      allBaselines:
          allBaselines ?? this.allBaselines.map((e0) => e0.copyWith()).toList(),
      openClarifications:
          openClarifications ??
          this.openClarifications.map((e0) => e0.copyWith()).toList(),
      snapshotId: snapshotId is String? ? snapshotId : this.snapshotId,
    );
  }
}
