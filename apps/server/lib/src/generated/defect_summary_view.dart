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

/// One row of the defect register list. The list shape, without the
/// human-report body — `DefectDetailView` adds that.
abstract class DefectSummaryView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  DefectSummaryView._({
    required this.defectId,
    required this.title,
    required this.severity,
    required this.status,
    this.classification,
    required this.reporter,
    this.productId,
    this.productName,
    required this.createdAt,
    required this.updatedAt,
    this.affectedWorkItemId,
    this.affectedRunId,
    this.remediationWorkItemId,
  });

  factory DefectSummaryView({
    required String defectId,
    required String title,
    required String severity,
    required String status,
    String? classification,
    required String reporter,
    String? productId,
    String? productName,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? affectedWorkItemId,
    String? affectedRunId,
    String? remediationWorkItemId,
  }) = _DefectSummaryViewImpl;

  factory DefectSummaryView.fromJson(Map<String, dynamic> jsonSerialization) {
    return DefectSummaryView(
      defectId: jsonSerialization['defectId'] as String,
      title: jsonSerialization['title'] as String,
      severity: jsonSerialization['severity'] as String,
      status: jsonSerialization['status'] as String,
      classification: jsonSerialization['classification'] as String?,
      reporter: jsonSerialization['reporter'] as String,
      productId: jsonSerialization['productId'] as String?,
      productName: jsonSerialization['productName'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      affectedWorkItemId: jsonSerialization['affectedWorkItemId'] as String?,
      affectedRunId: jsonSerialization['affectedRunId'] as String?,
      remediationWorkItemId:
          jsonSerialization['remediationWorkItemId'] as String?,
    );
  }

  String defectId;

  String title;

  String severity;

  /// Durable `DefectStatus` wire value.
  String status;

  String? classification;

  String reporter;

  /// Nullable on the domain type: a defect can be filed before its product
  /// row exists.
  String? productId;

  String? productName;

  DateTime createdAt;

  DateTime updatedAt;

  String? affectedWorkItemId;

  String? affectedRunId;

  String? remediationWorkItemId;

  /// Returns a shallow copy of this [DefectSummaryView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DefectSummaryView copyWith({
    String? defectId,
    String? title,
    String? severity,
    String? status,
    String? classification,
    String? reporter,
    String? productId,
    String? productName,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? affectedWorkItemId,
    String? affectedRunId,
    String? remediationWorkItemId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DefectSummaryView',
      'defectId': defectId,
      'title': title,
      'severity': severity,
      'status': status,
      if (classification != null) 'classification': classification,
      'reporter': reporter,
      if (productId != null) 'productId': productId,
      if (productName != null) 'productName': productName,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (affectedWorkItemId != null) 'affectedWorkItemId': affectedWorkItemId,
      if (affectedRunId != null) 'affectedRunId': affectedRunId,
      if (remediationWorkItemId != null)
        'remediationWorkItemId': remediationWorkItemId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DefectSummaryView',
      'defectId': defectId,
      'title': title,
      'severity': severity,
      'status': status,
      if (classification != null) 'classification': classification,
      'reporter': reporter,
      if (productId != null) 'productId': productId,
      if (productName != null) 'productName': productName,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (affectedWorkItemId != null) 'affectedWorkItemId': affectedWorkItemId,
      if (affectedRunId != null) 'affectedRunId': affectedRunId,
      if (remediationWorkItemId != null)
        'remediationWorkItemId': remediationWorkItemId,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DefectSummaryViewImpl extends DefectSummaryView {
  _DefectSummaryViewImpl({
    required String defectId,
    required String title,
    required String severity,
    required String status,
    String? classification,
    required String reporter,
    String? productId,
    String? productName,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? affectedWorkItemId,
    String? affectedRunId,
    String? remediationWorkItemId,
  }) : super._(
         defectId: defectId,
         title: title,
         severity: severity,
         status: status,
         classification: classification,
         reporter: reporter,
         productId: productId,
         productName: productName,
         createdAt: createdAt,
         updatedAt: updatedAt,
         affectedWorkItemId: affectedWorkItemId,
         affectedRunId: affectedRunId,
         remediationWorkItemId: remediationWorkItemId,
       );

  /// Returns a shallow copy of this [DefectSummaryView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DefectSummaryView copyWith({
    String? defectId,
    String? title,
    String? severity,
    String? status,
    Object? classification = _Undefined,
    String? reporter,
    Object? productId = _Undefined,
    Object? productName = _Undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? affectedWorkItemId = _Undefined,
    Object? affectedRunId = _Undefined,
    Object? remediationWorkItemId = _Undefined,
  }) {
    return DefectSummaryView(
      defectId: defectId ?? this.defectId,
      title: title ?? this.title,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      classification: classification is String?
          ? classification
          : this.classification,
      reporter: reporter ?? this.reporter,
      productId: productId is String? ? productId : this.productId,
      productName: productName is String? ? productName : this.productName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      affectedWorkItemId: affectedWorkItemId is String?
          ? affectedWorkItemId
          : this.affectedWorkItemId,
      affectedRunId: affectedRunId is String?
          ? affectedRunId
          : this.affectedRunId,
      remediationWorkItemId: remediationWorkItemId is String?
          ? remediationWorkItemId
          : this.remediationWorkItemId,
    );
  }
}
