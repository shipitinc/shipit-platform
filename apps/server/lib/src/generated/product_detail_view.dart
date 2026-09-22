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
import 'product_view.dart' as _i2;
import 'repository_reference_view.dart' as _i3;
import 'repository_credential_view.dart' as _i4;
import 'product_baseline_view.dart' as _i5;
import 'clarification_view.dart' as _i6;
import 'standing_policy_view.dart' as _i7;
import 'package:control_plane_server/src/generated/protocol.dart' as _i8;

/// Everything the Product Detail screen reads, in one call.
///
/// Composed rather than fetched piecemeal so the screen cannot show a
/// half-loaded product. Every field is durable state.
abstract class ProductDetailView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  ProductDetailView._({
    required this.product,
    required this.allowsDispatch,
    required this.repositories,
    required this.credentials,
    this.activeBaseline,
    this.pendingBaseline,
    required this.pendingBaselineVerified,
    required this.allBaselines,
    required this.openClarifications,
    required this.policies,
  });

  factory ProductDetailView({
    required _i2.ProductView product,
    required bool allowsDispatch,
    required List<_i3.RepositoryReferenceView> repositories,
    required List<_i4.RepositoryCredentialView> credentials,
    _i5.ProductBaselineView? activeBaseline,
    _i5.ProductBaselineView? pendingBaseline,
    required bool pendingBaselineVerified,
    required List<_i5.ProductBaselineView> allBaselines,
    required List<_i6.ClarificationView> openClarifications,
    required List<_i7.StandingPolicyView> policies,
  }) = _ProductDetailViewImpl;

  factory ProductDetailView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ProductDetailView(
      product: _i8.Protocol().deserialize<_i2.ProductView>(
        jsonSerialization['product'],
      ),
      allowsDispatch: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['allowsDispatch'],
      ),
      repositories: _i8.Protocol()
          .deserialize<List<_i3.RepositoryReferenceView>>(
            jsonSerialization['repositories'],
          ),
      credentials: _i8.Protocol()
          .deserialize<List<_i4.RepositoryCredentialView>>(
            jsonSerialization['credentials'],
          ),
      activeBaseline: jsonSerialization['activeBaseline'] == null
          ? null
          : _i8.Protocol().deserialize<_i5.ProductBaselineView>(
              jsonSerialization['activeBaseline'],
            ),
      pendingBaseline: jsonSerialization['pendingBaseline'] == null
          ? null
          : _i8.Protocol().deserialize<_i5.ProductBaselineView>(
              jsonSerialization['pendingBaseline'],
            ),
      pendingBaselineVerified: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['pendingBaselineVerified'],
      ),
      allBaselines: _i8.Protocol().deserialize<List<_i5.ProductBaselineView>>(
        jsonSerialization['allBaselines'],
      ),
      openClarifications: _i8.Protocol()
          .deserialize<List<_i6.ClarificationView>>(
            jsonSerialization['openClarifications'],
          ),
      policies: _i8.Protocol().deserialize<List<_i7.StandingPolicyView>>(
        jsonSerialization['policies'],
      ),
    );
  }

  _i2.ProductView product;

  /// True only for `governed`. Mirrors ProductState.allowsDispatch.
  bool allowsDispatch;

  List<_i3.RepositoryReferenceView> repositories;

  /// One credential per repository; absent where none has been generated.
  List<_i4.RepositoryCredentialView> credentials;

  _i5.ProductBaselineView? activeBaseline;

  /// The candidate awaiting a human, when in baseline_review.
  _i5.ProductBaselineView? pendingBaseline;

  /// Whether that candidate carries a worker attestation (AGENTS.md §12).
  bool pendingBaselineVerified;

  List<_i5.ProductBaselineView> allBaselines;

  List<_i6.ClarificationView> openClarifications;

  /// Active first; revoked ones are retained and still readable.
  List<_i7.StandingPolicyView> policies;

  /// Returns a shallow copy of this [ProductDetailView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ProductDetailView copyWith({
    _i2.ProductView? product,
    bool? allowsDispatch,
    List<_i3.RepositoryReferenceView>? repositories,
    List<_i4.RepositoryCredentialView>? credentials,
    _i5.ProductBaselineView? activeBaseline,
    _i5.ProductBaselineView? pendingBaseline,
    bool? pendingBaselineVerified,
    List<_i5.ProductBaselineView>? allBaselines,
    List<_i6.ClarificationView>? openClarifications,
    List<_i7.StandingPolicyView>? policies,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ProductDetailView',
      'product': product.toJson(),
      'allowsDispatch': allowsDispatch,
      'repositories': repositories.toJson(valueToJson: (v) => v.toJson()),
      'credentials': credentials.toJson(valueToJson: (v) => v.toJson()),
      if (activeBaseline != null) 'activeBaseline': activeBaseline?.toJson(),
      if (pendingBaseline != null) 'pendingBaseline': pendingBaseline?.toJson(),
      'pendingBaselineVerified': pendingBaselineVerified,
      'allBaselines': allBaselines.toJson(valueToJson: (v) => v.toJson()),
      'openClarifications': openClarifications.toJson(
        valueToJson: (v) => v.toJson(),
      ),
      'policies': policies.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ProductDetailView',
      'product': product.toJsonForProtocol(),
      'allowsDispatch': allowsDispatch,
      'repositories': repositories.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
      'credentials': credentials.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
      if (activeBaseline != null)
        'activeBaseline': activeBaseline?.toJsonForProtocol(),
      if (pendingBaseline != null)
        'pendingBaseline': pendingBaseline?.toJsonForProtocol(),
      'pendingBaselineVerified': pendingBaselineVerified,
      'allBaselines': allBaselines.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
      'openClarifications': openClarifications.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
      'policies': policies.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ProductDetailViewImpl extends ProductDetailView {
  _ProductDetailViewImpl({
    required _i2.ProductView product,
    required bool allowsDispatch,
    required List<_i3.RepositoryReferenceView> repositories,
    required List<_i4.RepositoryCredentialView> credentials,
    _i5.ProductBaselineView? activeBaseline,
    _i5.ProductBaselineView? pendingBaseline,
    required bool pendingBaselineVerified,
    required List<_i5.ProductBaselineView> allBaselines,
    required List<_i6.ClarificationView> openClarifications,
    required List<_i7.StandingPolicyView> policies,
  }) : super._(
         product: product,
         allowsDispatch: allowsDispatch,
         repositories: repositories,
         credentials: credentials,
         activeBaseline: activeBaseline,
         pendingBaseline: pendingBaseline,
         pendingBaselineVerified: pendingBaselineVerified,
         allBaselines: allBaselines,
         openClarifications: openClarifications,
         policies: policies,
       );

  /// Returns a shallow copy of this [ProductDetailView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ProductDetailView copyWith({
    _i2.ProductView? product,
    bool? allowsDispatch,
    List<_i3.RepositoryReferenceView>? repositories,
    List<_i4.RepositoryCredentialView>? credentials,
    Object? activeBaseline = _Undefined,
    Object? pendingBaseline = _Undefined,
    bool? pendingBaselineVerified,
    List<_i5.ProductBaselineView>? allBaselines,
    List<_i6.ClarificationView>? openClarifications,
    List<_i7.StandingPolicyView>? policies,
  }) {
    return ProductDetailView(
      product: product ?? this.product.copyWith(),
      allowsDispatch: allowsDispatch ?? this.allowsDispatch,
      repositories:
          repositories ?? this.repositories.map((e0) => e0.copyWith()).toList(),
      credentials:
          credentials ?? this.credentials.map((e0) => e0.copyWith()).toList(),
      activeBaseline: activeBaseline is _i5.ProductBaselineView?
          ? activeBaseline
          : this.activeBaseline?.copyWith(),
      pendingBaseline: pendingBaseline is _i5.ProductBaselineView?
          ? pendingBaseline
          : this.pendingBaseline?.copyWith(),
      pendingBaselineVerified:
          pendingBaselineVerified ?? this.pendingBaselineVerified,
      allBaselines:
          allBaselines ?? this.allBaselines.map((e0) => e0.copyWith()).toList(),
      openClarifications:
          openClarifications ??
          this.openClarifications.map((e0) => e0.copyWith()).toList(),
      policies: policies ?? this.policies.map((e0) => e0.copyWith()).toList(),
    );
  }
}
