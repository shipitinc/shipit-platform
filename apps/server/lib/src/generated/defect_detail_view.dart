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

/// The defect register row plus the human report body. Serverpod models do not
/// inherit, so the summary fields are repeated here deliberately rather than
/// flattened away.
abstract class DefectDetailView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  DefectDetailView._({
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
    required this.description,
    this.expectedBehavior,
    this.reproductionSteps,
    this.clientContextJson,
    this.metadataJson,
    this.resolvedAt,
    this.closedAt,
    required this.version,
  });

  factory DefectDetailView({
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
    required String description,
    String? expectedBehavior,
    String? reproductionSteps,
    String? clientContextJson,
    String? metadataJson,
    DateTime? resolvedAt,
    DateTime? closedAt,
    required int version,
  }) = _DefectDetailViewImpl;

  factory DefectDetailView.fromJson(Map<String, dynamic> jsonSerialization) {
    return DefectDetailView(
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
      description: jsonSerialization['description'] as String,
      expectedBehavior: jsonSerialization['expectedBehavior'] as String?,
      reproductionSteps: jsonSerialization['reproductionSteps'] as String?,
      clientContextJson: jsonSerialization['clientContextJson'] as String?,
      metadataJson: jsonSerialization['metadataJson'] as String?,
      resolvedAt: jsonSerialization['resolvedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['resolvedAt']),
      closedAt: jsonSerialization['closedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['closedAt']),
      version: jsonSerialization['version'] as int,
    );
  }

  String defectId;

  String title;

  String severity;

  /// Durable `DefectStatus` wire value.
  String status;

  String? classification;

  String reporter;

  /// Nullable on the domain type. See `DefectSummaryView`.
  String? productId;

  String? productName;

  DateTime createdAt;

  DateTime updatedAt;

  String? affectedWorkItemId;

  String? affectedRunId;

  String? remediationWorkItemId;

  String description;

  String? expectedBehavior;

  String? reproductionSteps;

  /// Free-form operator context, carried as JSON TEXT.
  ///
  /// This is the house convention for an open-ended blob on this wire and not a
  /// new one: `DefectDetailView.metadataJson` and `DefectEventView.payloadJson`
  /// below already do it, because Serverpod 3.4.13 refuses `dynamic` in a model
  /// schema outright ("The datatype \"dynamic\" is not supported in models")
  /// and so has no type that can hold arbitrary JSON. `jsonDecode` recovers the
  /// original value exactly.
  String? clientContextJson;

  /// Free-form durable metadata, carried as JSON TEXT. See `clientContextJson`.
  String? metadataJson;

  DateTime? resolvedAt;

  DateTime? closedAt;

  int version;

  /// Returns a shallow copy of this [DefectDetailView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DefectDetailView copyWith({
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
    String? description,
    String? expectedBehavior,
    String? reproductionSteps,
    String? clientContextJson,
    String? metadataJson,
    DateTime? resolvedAt,
    DateTime? closedAt,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DefectDetailView',
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
      'description': description,
      if (expectedBehavior != null) 'expectedBehavior': expectedBehavior,
      if (reproductionSteps != null) 'reproductionSteps': reproductionSteps,
      if (clientContextJson != null) 'clientContextJson': clientContextJson,
      if (metadataJson != null) 'metadataJson': metadataJson,
      if (resolvedAt != null) 'resolvedAt': resolvedAt?.toJson(),
      if (closedAt != null) 'closedAt': closedAt?.toJson(),
      'version': version,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DefectDetailView',
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
      'description': description,
      if (expectedBehavior != null) 'expectedBehavior': expectedBehavior,
      if (reproductionSteps != null) 'reproductionSteps': reproductionSteps,
      if (clientContextJson != null) 'clientContextJson': clientContextJson,
      if (metadataJson != null) 'metadataJson': metadataJson,
      if (resolvedAt != null) 'resolvedAt': resolvedAt?.toJson(),
      if (closedAt != null) 'closedAt': closedAt?.toJson(),
      'version': version,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DefectDetailViewImpl extends DefectDetailView {
  _DefectDetailViewImpl({
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
    required String description,
    String? expectedBehavior,
    String? reproductionSteps,
    String? clientContextJson,
    String? metadataJson,
    DateTime? resolvedAt,
    DateTime? closedAt,
    required int version,
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
         description: description,
         expectedBehavior: expectedBehavior,
         reproductionSteps: reproductionSteps,
         clientContextJson: clientContextJson,
         metadataJson: metadataJson,
         resolvedAt: resolvedAt,
         closedAt: closedAt,
         version: version,
       );

  /// Returns a shallow copy of this [DefectDetailView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DefectDetailView copyWith({
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
    String? description,
    Object? expectedBehavior = _Undefined,
    Object? reproductionSteps = _Undefined,
    Object? clientContextJson = _Undefined,
    Object? metadataJson = _Undefined,
    Object? resolvedAt = _Undefined,
    Object? closedAt = _Undefined,
    int? version,
  }) {
    return DefectDetailView(
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
      description: description ?? this.description,
      expectedBehavior: expectedBehavior is String?
          ? expectedBehavior
          : this.expectedBehavior,
      reproductionSteps: reproductionSteps is String?
          ? reproductionSteps
          : this.reproductionSteps,
      clientContextJson: clientContextJson is String?
          ? clientContextJson
          : this.clientContextJson,
      metadataJson: metadataJson is String? ? metadataJson : this.metadataJson,
      resolvedAt: resolvedAt is DateTime? ? resolvedAt : this.resolvedAt,
      closedAt: closedAt is DateTime? ? closedAt : this.closedAt,
      version: version ?? this.version,
    );
  }
}
