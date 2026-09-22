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

/// One row of the Products list.
///
/// Richer than `ProductView` so the list does not need an N+1 call per
/// product. Every field is read from durable state — nothing here is derived
/// for display only.
abstract class ProductSummaryView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  ProductSummaryView._({
    required this.productId,
    required this.name,
    required this.state,
    required this.allowsDispatch,
    this.activeBaselineId,
    this.activeBaselineRevision,
    this.pendingBaselineId,
    this.pendingBaselineRevision,
    required this.pendingBaselineVerified,
    required this.baselineFactCount,
    required this.openClarifications,
    required this.repositoryCount,
    required this.reachableRepositoryCount,
    required this.updatedAt,
  });

  factory ProductSummaryView({
    required String productId,
    required String name,
    required String state,
    required bool allowsDispatch,
    String? activeBaselineId,
    int? activeBaselineRevision,
    String? pendingBaselineId,
    int? pendingBaselineRevision,
    required bool pendingBaselineVerified,
    required int baselineFactCount,
    required int openClarifications,
    required int repositoryCount,
    required int reachableRepositoryCount,
    required DateTime updatedAt,
  }) = _ProductSummaryViewImpl;

  factory ProductSummaryView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ProductSummaryView(
      productId: jsonSerialization['productId'] as String,
      name: jsonSerialization['name'] as String,
      state: jsonSerialization['state'] as String,
      allowsDispatch: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['allowsDispatch'],
      ),
      activeBaselineId: jsonSerialization['activeBaselineId'] as String?,
      activeBaselineRevision:
          jsonSerialization['activeBaselineRevision'] as int?,
      pendingBaselineId: jsonSerialization['pendingBaselineId'] as String?,
      pendingBaselineRevision:
          jsonSerialization['pendingBaselineRevision'] as int?,
      pendingBaselineVerified: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['pendingBaselineVerified'],
      ),
      baselineFactCount: jsonSerialization['baselineFactCount'] as int,
      openClarifications: jsonSerialization['openClarifications'] as int,
      repositoryCount: jsonSerialization['repositoryCount'] as int,
      reachableRepositoryCount:
          jsonSerialization['reachableRepositoryCount'] as int,
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  String productId;

  String name;

  /// registered | baseline_pending | baseline_blocked | baseline_review |
  /// governed | paused | archived
  String state;

  /// True only for `governed`. Mirrors ProductState.allowsDispatch so the UI
  /// never re-implements the rule.
  bool allowsDispatch;

  /// Accepted baseline, when one exists. A product without one is not governed.
  String? activeBaselineId;

  int? activeBaselineRevision;

  /// The candidate awaiting a human, when the product is in baseline_review.
  String? pendingBaselineId;

  int? pendingBaselineRevision;

  /// Whether the pending candidate has been verified by a worker (AGENTS.md
  /// §12). The approval gate refuses to open without it.
  bool pendingBaselineVerified;

  /// Number of baseline facts on the active (else latest) revision. This is a
  /// count of recorded claims, NOT a file count — the registry does not track
  /// file counts.
  int baselineFactCount;

  int openClarifications;

  /// Repositories attributed to this product, and how many of them currently
  /// have a credential that can actually reach them.
  int repositoryCount;

  int reachableRepositoryCount;

  DateTime updatedAt;

  /// Returns a shallow copy of this [ProductSummaryView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ProductSummaryView copyWith({
    String? productId,
    String? name,
    String? state,
    bool? allowsDispatch,
    String? activeBaselineId,
    int? activeBaselineRevision,
    String? pendingBaselineId,
    int? pendingBaselineRevision,
    bool? pendingBaselineVerified,
    int? baselineFactCount,
    int? openClarifications,
    int? repositoryCount,
    int? reachableRepositoryCount,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ProductSummaryView',
      'productId': productId,
      'name': name,
      'state': state,
      'allowsDispatch': allowsDispatch,
      if (activeBaselineId != null) 'activeBaselineId': activeBaselineId,
      if (activeBaselineRevision != null)
        'activeBaselineRevision': activeBaselineRevision,
      if (pendingBaselineId != null) 'pendingBaselineId': pendingBaselineId,
      if (pendingBaselineRevision != null)
        'pendingBaselineRevision': pendingBaselineRevision,
      'pendingBaselineVerified': pendingBaselineVerified,
      'baselineFactCount': baselineFactCount,
      'openClarifications': openClarifications,
      'repositoryCount': repositoryCount,
      'reachableRepositoryCount': reachableRepositoryCount,
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ProductSummaryView',
      'productId': productId,
      'name': name,
      'state': state,
      'allowsDispatch': allowsDispatch,
      if (activeBaselineId != null) 'activeBaselineId': activeBaselineId,
      if (activeBaselineRevision != null)
        'activeBaselineRevision': activeBaselineRevision,
      if (pendingBaselineId != null) 'pendingBaselineId': pendingBaselineId,
      if (pendingBaselineRevision != null)
        'pendingBaselineRevision': pendingBaselineRevision,
      'pendingBaselineVerified': pendingBaselineVerified,
      'baselineFactCount': baselineFactCount,
      'openClarifications': openClarifications,
      'repositoryCount': repositoryCount,
      'reachableRepositoryCount': reachableRepositoryCount,
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ProductSummaryViewImpl extends ProductSummaryView {
  _ProductSummaryViewImpl({
    required String productId,
    required String name,
    required String state,
    required bool allowsDispatch,
    String? activeBaselineId,
    int? activeBaselineRevision,
    String? pendingBaselineId,
    int? pendingBaselineRevision,
    required bool pendingBaselineVerified,
    required int baselineFactCount,
    required int openClarifications,
    required int repositoryCount,
    required int reachableRepositoryCount,
    required DateTime updatedAt,
  }) : super._(
         productId: productId,
         name: name,
         state: state,
         allowsDispatch: allowsDispatch,
         activeBaselineId: activeBaselineId,
         activeBaselineRevision: activeBaselineRevision,
         pendingBaselineId: pendingBaselineId,
         pendingBaselineRevision: pendingBaselineRevision,
         pendingBaselineVerified: pendingBaselineVerified,
         baselineFactCount: baselineFactCount,
         openClarifications: openClarifications,
         repositoryCount: repositoryCount,
         reachableRepositoryCount: reachableRepositoryCount,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [ProductSummaryView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ProductSummaryView copyWith({
    String? productId,
    String? name,
    String? state,
    bool? allowsDispatch,
    Object? activeBaselineId = _Undefined,
    Object? activeBaselineRevision = _Undefined,
    Object? pendingBaselineId = _Undefined,
    Object? pendingBaselineRevision = _Undefined,
    bool? pendingBaselineVerified,
    int? baselineFactCount,
    int? openClarifications,
    int? repositoryCount,
    int? reachableRepositoryCount,
    DateTime? updatedAt,
  }) {
    return ProductSummaryView(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      state: state ?? this.state,
      allowsDispatch: allowsDispatch ?? this.allowsDispatch,
      activeBaselineId: activeBaselineId is String?
          ? activeBaselineId
          : this.activeBaselineId,
      activeBaselineRevision: activeBaselineRevision is int?
          ? activeBaselineRevision
          : this.activeBaselineRevision,
      pendingBaselineId: pendingBaselineId is String?
          ? pendingBaselineId
          : this.pendingBaselineId,
      pendingBaselineRevision: pendingBaselineRevision is int?
          ? pendingBaselineRevision
          : this.pendingBaselineRevision,
      pendingBaselineVerified:
          pendingBaselineVerified ?? this.pendingBaselineVerified,
      baselineFactCount: baselineFactCount ?? this.baselineFactCount,
      openClarifications: openClarifications ?? this.openClarifications,
      repositoryCount: repositoryCount ?? this.repositoryCount,
      reachableRepositoryCount:
          reachableRepositoryCount ?? this.reachableRepositoryCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
