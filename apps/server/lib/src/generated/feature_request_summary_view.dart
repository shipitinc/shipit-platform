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

/// One row of the Reports screen's `Feature requests` tab.
///
/// A feature request is a WorkItem of category `feature`, so this view is the
/// work item's own durable facts plus the two things the tab needs that the
/// work item does not record — the registry name of the product it was filed
/// against, and who filed it. Both are resolved server-side from the records
/// written in the same transaction as the request.
abstract class FeatureRequestSummaryView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  FeatureRequestSummaryView._({
    required this.workItemId,
    required this.title,
    this.description,
    required this.state,
    required this.productId,
    this.productName,
    this.reporter,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory FeatureRequestSummaryView({
    required String workItemId,
    required String title,
    String? description,
    required String state,
    required String productId,
    String? productName,
    String? reporter,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? completedAt,
  }) = _FeatureRequestSummaryViewImpl;

  factory FeatureRequestSummaryView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return FeatureRequestSummaryView(
      workItemId: jsonSerialization['workItemId'] as String,
      title: jsonSerialization['title'] as String,
      description: jsonSerialization['description'] as String?,
      state: jsonSerialization['state'] as String,
      productId: jsonSerialization['productId'] as String,
      productName: jsonSerialization['productName'] as String?,
      reporter: jsonSerialization['reporter'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
    );
  }

  String workItemId;

  String title;

  /// The reporter's own words — what they want and why.
  String? description;

  /// `WorkflowState` wire value. A request stays `draft` until a human decides.
  String state;

  String productId;

  /// Registry name for `productId`. Absent when no registry row resolves — the
  /// client owns the fallback copy, so an unresolved product is never given an
  /// invented label here.
  String? productName;

  /// Recovered from the intake direction raised with the request. Absent when
  /// that direction cannot be read.
  String? reporter;

  DateTime createdAt;

  DateTime updatedAt;

  DateTime? completedAt;

  /// Returns a shallow copy of this [FeatureRequestSummaryView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  FeatureRequestSummaryView copyWith({
    String? workItemId,
    String? title,
    String? description,
    String? state,
    String? productId,
    String? productName,
    String? reporter,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FeatureRequestSummaryView',
      'workItemId': workItemId,
      'title': title,
      if (description != null) 'description': description,
      'state': state,
      'productId': productId,
      if (productName != null) 'productName': productName,
      if (reporter != null) 'reporter': reporter,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FeatureRequestSummaryView',
      'workItemId': workItemId,
      'title': title,
      if (description != null) 'description': description,
      'state': state,
      'productId': productId,
      if (productName != null) 'productName': productName,
      if (reporter != null) 'reporter': reporter,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FeatureRequestSummaryViewImpl extends FeatureRequestSummaryView {
  _FeatureRequestSummaryViewImpl({
    required String workItemId,
    required String title,
    String? description,
    required String state,
    required String productId,
    String? productName,
    String? reporter,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? completedAt,
  }) : super._(
         workItemId: workItemId,
         title: title,
         description: description,
         state: state,
         productId: productId,
         productName: productName,
         reporter: reporter,
         createdAt: createdAt,
         updatedAt: updatedAt,
         completedAt: completedAt,
       );

  /// Returns a shallow copy of this [FeatureRequestSummaryView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  FeatureRequestSummaryView copyWith({
    String? workItemId,
    String? title,
    Object? description = _Undefined,
    String? state,
    String? productId,
    Object? productName = _Undefined,
    Object? reporter = _Undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? completedAt = _Undefined,
  }) {
    return FeatureRequestSummaryView(
      workItemId: workItemId ?? this.workItemId,
      title: title ?? this.title,
      description: description is String? ? description : this.description,
      state: state ?? this.state,
      productId: productId ?? this.productId,
      productName: productName is String? ? productName : this.productName,
      reporter: reporter is String? ? reporter : this.reporter,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt is DateTime? ? completedAt : this.completedAt,
    );
  }
}
