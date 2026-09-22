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
import 'baseline_fact_view.dart' as _i2;
import 'package:control_plane_client/src/protocol/protocol.dart' as _i3;

/// A pinned, per-Product baseline revision. Acceptance binds to the exact
/// `revision` + `contentHash`; an accepted revision is immutable.
abstract class ProductBaselineView implements _i1.SerializableModel {
  ProductBaselineView._({
    required this.baselineId,
    required this.productId,
    required this.revision,
    required this.status,
    required this.facts,
    required this.contentHash,
    required this.contentHashVersion,
    this.supersedesBaselineId,
    this.proposedAt,
    this.reviewedAt,
    this.acceptedAt,
    this.acceptedBy,
    this.acceptedDecisionId,
    this.createdAt,
    this.updatedAt,
    required this.version,
  });

  factory ProductBaselineView({
    required String baselineId,
    required String productId,
    required int revision,
    required String status,
    required List<_i2.BaselineFactView> facts,
    required String contentHash,
    required int contentHashVersion,
    String? supersedesBaselineId,
    DateTime? proposedAt,
    DateTime? reviewedAt,
    DateTime? acceptedAt,
    String? acceptedBy,
    String? acceptedDecisionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    required int version,
  }) = _ProductBaselineViewImpl;

  factory ProductBaselineView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ProductBaselineView(
      baselineId: jsonSerialization['baselineId'] as String,
      productId: jsonSerialization['productId'] as String,
      revision: jsonSerialization['revision'] as int,
      status: jsonSerialization['status'] as String,
      facts: _i3.Protocol().deserialize<List<_i2.BaselineFactView>>(
        jsonSerialization['facts'],
      ),
      contentHash: jsonSerialization['contentHash'] as String,
      contentHashVersion: jsonSerialization['contentHashVersion'] as int,
      supersedesBaselineId:
          jsonSerialization['supersedesBaselineId'] as String?,
      proposedAt: jsonSerialization['proposedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['proposedAt']),
      reviewedAt: jsonSerialization['reviewedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['reviewedAt']),
      acceptedAt: jsonSerialization['acceptedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['acceptedAt']),
      acceptedBy: jsonSerialization['acceptedBy'] as String?,
      acceptedDecisionId: jsonSerialization['acceptedDecisionId'] as String?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      updatedAt: jsonSerialization['updatedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['updatedAt']),
      version: jsonSerialization['version'] as int,
    );
  }

  String baselineId;

  String productId;

  int revision;

  /// proposed | accepted | superseded | rejected
  String status;

  List<_i2.BaselineFactView> facts;

  String contentHash;

  int contentHashVersion;

  String? supersedesBaselineId;

  DateTime? proposedAt;

  DateTime? reviewedAt;

  DateTime? acceptedAt;

  String? acceptedBy;

  String? acceptedDecisionId;

  DateTime? createdAt;

  DateTime? updatedAt;

  int version;

  /// Returns a shallow copy of this [ProductBaselineView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ProductBaselineView copyWith({
    String? baselineId,
    String? productId,
    int? revision,
    String? status,
    List<_i2.BaselineFactView>? facts,
    String? contentHash,
    int? contentHashVersion,
    String? supersedesBaselineId,
    DateTime? proposedAt,
    DateTime? reviewedAt,
    DateTime? acceptedAt,
    String? acceptedBy,
    String? acceptedDecisionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ProductBaselineView',
      'baselineId': baselineId,
      'productId': productId,
      'revision': revision,
      'status': status,
      'facts': facts.toJson(valueToJson: (v) => v.toJson()),
      'contentHash': contentHash,
      'contentHashVersion': contentHashVersion,
      if (supersedesBaselineId != null)
        'supersedesBaselineId': supersedesBaselineId,
      if (proposedAt != null) 'proposedAt': proposedAt?.toJson(),
      if (reviewedAt != null) 'reviewedAt': reviewedAt?.toJson(),
      if (acceptedAt != null) 'acceptedAt': acceptedAt?.toJson(),
      if (acceptedBy != null) 'acceptedBy': acceptedBy,
      if (acceptedDecisionId != null) 'acceptedDecisionId': acceptedDecisionId,
      if (createdAt != null) 'createdAt': createdAt?.toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt?.toJson(),
      'version': version,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ProductBaselineViewImpl extends ProductBaselineView {
  _ProductBaselineViewImpl({
    required String baselineId,
    required String productId,
    required int revision,
    required String status,
    required List<_i2.BaselineFactView> facts,
    required String contentHash,
    required int contentHashVersion,
    String? supersedesBaselineId,
    DateTime? proposedAt,
    DateTime? reviewedAt,
    DateTime? acceptedAt,
    String? acceptedBy,
    String? acceptedDecisionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    required int version,
  }) : super._(
         baselineId: baselineId,
         productId: productId,
         revision: revision,
         status: status,
         facts: facts,
         contentHash: contentHash,
         contentHashVersion: contentHashVersion,
         supersedesBaselineId: supersedesBaselineId,
         proposedAt: proposedAt,
         reviewedAt: reviewedAt,
         acceptedAt: acceptedAt,
         acceptedBy: acceptedBy,
         acceptedDecisionId: acceptedDecisionId,
         createdAt: createdAt,
         updatedAt: updatedAt,
         version: version,
       );

  /// Returns a shallow copy of this [ProductBaselineView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ProductBaselineView copyWith({
    String? baselineId,
    String? productId,
    int? revision,
    String? status,
    List<_i2.BaselineFactView>? facts,
    String? contentHash,
    int? contentHashVersion,
    Object? supersedesBaselineId = _Undefined,
    Object? proposedAt = _Undefined,
    Object? reviewedAt = _Undefined,
    Object? acceptedAt = _Undefined,
    Object? acceptedBy = _Undefined,
    Object? acceptedDecisionId = _Undefined,
    Object? createdAt = _Undefined,
    Object? updatedAt = _Undefined,
    int? version,
  }) {
    return ProductBaselineView(
      baselineId: baselineId ?? this.baselineId,
      productId: productId ?? this.productId,
      revision: revision ?? this.revision,
      status: status ?? this.status,
      facts: facts ?? this.facts.map((e0) => e0.copyWith()).toList(),
      contentHash: contentHash ?? this.contentHash,
      contentHashVersion: contentHashVersion ?? this.contentHashVersion,
      supersedesBaselineId: supersedesBaselineId is String?
          ? supersedesBaselineId
          : this.supersedesBaselineId,
      proposedAt: proposedAt is DateTime? ? proposedAt : this.proposedAt,
      reviewedAt: reviewedAt is DateTime? ? reviewedAt : this.reviewedAt,
      acceptedAt: acceptedAt is DateTime? ? acceptedAt : this.acceptedAt,
      acceptedBy: acceptedBy is String? ? acceptedBy : this.acceptedBy,
      acceptedDecisionId: acceptedDecisionId is String?
          ? acceptedDecisionId
          : this.acceptedDecisionId,
      createdAt: createdAt is DateTime? ? createdAt : this.createdAt,
      updatedAt: updatedAt is DateTime? ? updatedAt : this.updatedAt,
      version: version ?? this.version,
    );
  }
}
