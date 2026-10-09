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

/// One piece of evidence attached to a defect.
abstract class DefectEvidenceView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  DefectEvidenceView._({
    required this.evidenceId,
    required this.defectId,
    required this.kind,
    this.artifactId,
    this.contentHash,
    this.description,
    this.sourceRef,
    required this.capturedAt,
    required this.createdAt,
  });

  factory DefectEvidenceView({
    required String evidenceId,
    required String defectId,
    required String kind,
    String? artifactId,
    String? contentHash,
    String? description,
    String? sourceRef,
    required DateTime capturedAt,
    required DateTime createdAt,
  }) = _DefectEvidenceViewImpl;

  factory DefectEvidenceView.fromJson(Map<String, dynamic> jsonSerialization) {
    return DefectEvidenceView(
      evidenceId: jsonSerialization['evidenceId'] as String,
      defectId: jsonSerialization['defectId'] as String,
      kind: jsonSerialization['kind'] as String,
      artifactId: jsonSerialization['artifactId'] as String?,
      contentHash: jsonSerialization['contentHash'] as String?,
      description: jsonSerialization['description'] as String?,
      sourceRef: jsonSerialization['sourceRef'] as String?,
      capturedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['capturedAt'],
      ),
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  String evidenceId;

  String defectId;

  /// Durable `EvidenceIntakeKind` wire value.
  String kind;

  String? artifactId;

  String? contentHash;

  String? description;

  String? sourceRef;

  DateTime capturedAt;

  DateTime createdAt;

  /// Returns a shallow copy of this [DefectEvidenceView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DefectEvidenceView copyWith({
    String? evidenceId,
    String? defectId,
    String? kind,
    String? artifactId,
    String? contentHash,
    String? description,
    String? sourceRef,
    DateTime? capturedAt,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DefectEvidenceView',
      'evidenceId': evidenceId,
      'defectId': defectId,
      'kind': kind,
      if (artifactId != null) 'artifactId': artifactId,
      if (contentHash != null) 'contentHash': contentHash,
      if (description != null) 'description': description,
      if (sourceRef != null) 'sourceRef': sourceRef,
      'capturedAt': capturedAt.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DefectEvidenceView',
      'evidenceId': evidenceId,
      'defectId': defectId,
      'kind': kind,
      if (artifactId != null) 'artifactId': artifactId,
      if (contentHash != null) 'contentHash': contentHash,
      if (description != null) 'description': description,
      if (sourceRef != null) 'sourceRef': sourceRef,
      'capturedAt': capturedAt.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DefectEvidenceViewImpl extends DefectEvidenceView {
  _DefectEvidenceViewImpl({
    required String evidenceId,
    required String defectId,
    required String kind,
    String? artifactId,
    String? contentHash,
    String? description,
    String? sourceRef,
    required DateTime capturedAt,
    required DateTime createdAt,
  }) : super._(
         evidenceId: evidenceId,
         defectId: defectId,
         kind: kind,
         artifactId: artifactId,
         contentHash: contentHash,
         description: description,
         sourceRef: sourceRef,
         capturedAt: capturedAt,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [DefectEvidenceView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DefectEvidenceView copyWith({
    String? evidenceId,
    String? defectId,
    String? kind,
    Object? artifactId = _Undefined,
    Object? contentHash = _Undefined,
    Object? description = _Undefined,
    Object? sourceRef = _Undefined,
    DateTime? capturedAt,
    DateTime? createdAt,
  }) {
    return DefectEvidenceView(
      evidenceId: evidenceId ?? this.evidenceId,
      defectId: defectId ?? this.defectId,
      kind: kind ?? this.kind,
      artifactId: artifactId is String? ? artifactId : this.artifactId,
      contentHash: contentHash is String? ? contentHash : this.contentHash,
      description: description is String? ? description : this.description,
      sourceRef: sourceRef is String? ? sourceRef : this.sourceRef,
      capturedAt: capturedAt ?? this.capturedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
