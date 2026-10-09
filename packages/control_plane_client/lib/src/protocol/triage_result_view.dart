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
import 'defect_clarification_request_view.dart' as _i2;
import 'package:control_plane_client/src/protocol/protocol.dart' as _i3;

/// What triage concluded about a defect.
abstract class TriageResultView implements _i1.SerializableModel {
  TriageResultView._({
    required this.resultId,
    required this.defectId,
    required this.recommendedStatus,
    required this.recommendedClassification,
    required this.confidence,
    required this.suspectedCategory,
    required this.suspectedComponents,
    required this.reproductionSupported,
    required this.evidenceUsed,
    required this.clarificationRequired,
    required this.recommendedNextAction,
    this.possibleDuplicateDefectId,
    this.recommendedWorkItemCategory,
    required this.summary,
    this.jobId,
    this.executionId,
    required this.createdAt,
    this.completedAt,
    required this.version,
  });

  factory TriageResultView({
    required String resultId,
    required String defectId,
    required String recommendedStatus,
    required String recommendedClassification,
    required double confidence,
    required String suspectedCategory,
    required List<String> suspectedComponents,
    required bool reproductionSupported,
    required List<String> evidenceUsed,
    required List<_i2.DefectClarificationRequestView> clarificationRequired,
    required String recommendedNextAction,
    String? possibleDuplicateDefectId,
    String? recommendedWorkItemCategory,
    required String summary,
    String? jobId,
    String? executionId,
    required DateTime createdAt,
    DateTime? completedAt,
    required int version,
  }) = _TriageResultViewImpl;

  factory TriageResultView.fromJson(Map<String, dynamic> jsonSerialization) {
    return TriageResultView(
      resultId: jsonSerialization['resultId'] as String,
      defectId: jsonSerialization['defectId'] as String,
      recommendedStatus: jsonSerialization['recommendedStatus'] as String,
      recommendedClassification:
          jsonSerialization['recommendedClassification'] as String,
      confidence: (jsonSerialization['confidence'] as num).toDouble(),
      suspectedCategory: jsonSerialization['suspectedCategory'] as String,
      suspectedComponents: _i3.Protocol().deserialize<List<String>>(
        jsonSerialization['suspectedComponents'],
      ),
      reproductionSupported: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['reproductionSupported'],
      ),
      evidenceUsed: _i3.Protocol().deserialize<List<String>>(
        jsonSerialization['evidenceUsed'],
      ),
      clarificationRequired: _i3.Protocol()
          .deserialize<List<_i2.DefectClarificationRequestView>>(
            jsonSerialization['clarificationRequired'],
          ),
      recommendedNextAction:
          jsonSerialization['recommendedNextAction'] as String,
      possibleDuplicateDefectId:
          jsonSerialization['possibleDuplicateDefectId'] as String?,
      recommendedWorkItemCategory:
          jsonSerialization['recommendedWorkItemCategory'] as String?,
      summary: jsonSerialization['summary'] as String,
      jobId: jsonSerialization['jobId'] as String?,
      executionId: jsonSerialization['executionId'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      completedAt: jsonSerialization['completedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['completedAt'],
            ),
      version: jsonSerialization['version'] as int,
    );
  }

  String resultId;

  String defectId;

  /// Recommended durable `DefectStatus` wire value.
  String recommendedStatus;

  /// Recommended durable `DefectClassification` wire value.
  String recommendedClassification;

  double confidence;

  String suspectedCategory;

  List<String> suspectedComponents;

  bool reproductionSupported;

  List<String> evidenceUsed;

  List<_i2.DefectClarificationRequestView> clarificationRequired;

  String recommendedNextAction;

  String? possibleDuplicateDefectId;

  String? recommendedWorkItemCategory;

  String summary;

  String? jobId;

  String? executionId;

  DateTime createdAt;

  DateTime? completedAt;

  int version;

  /// Returns a shallow copy of this [TriageResultView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  TriageResultView copyWith({
    String? resultId,
    String? defectId,
    String? recommendedStatus,
    String? recommendedClassification,
    double? confidence,
    String? suspectedCategory,
    List<String>? suspectedComponents,
    bool? reproductionSupported,
    List<String>? evidenceUsed,
    List<_i2.DefectClarificationRequestView>? clarificationRequired,
    String? recommendedNextAction,
    String? possibleDuplicateDefectId,
    String? recommendedWorkItemCategory,
    String? summary,
    String? jobId,
    String? executionId,
    DateTime? createdAt,
    DateTime? completedAt,
    int? version,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'TriageResultView',
      'resultId': resultId,
      'defectId': defectId,
      'recommendedStatus': recommendedStatus,
      'recommendedClassification': recommendedClassification,
      'confidence': confidence,
      'suspectedCategory': suspectedCategory,
      'suspectedComponents': suspectedComponents.toJson(),
      'reproductionSupported': reproductionSupported,
      'evidenceUsed': evidenceUsed.toJson(),
      'clarificationRequired': clarificationRequired.toJson(
        valueToJson: (v) => v.toJson(),
      ),
      'recommendedNextAction': recommendedNextAction,
      if (possibleDuplicateDefectId != null)
        'possibleDuplicateDefectId': possibleDuplicateDefectId,
      if (recommendedWorkItemCategory != null)
        'recommendedWorkItemCategory': recommendedWorkItemCategory,
      'summary': summary,
      if (jobId != null) 'jobId': jobId,
      if (executionId != null) 'executionId': executionId,
      'createdAt': createdAt.toJson(),
      if (completedAt != null) 'completedAt': completedAt?.toJson(),
      'version': version,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _TriageResultViewImpl extends TriageResultView {
  _TriageResultViewImpl({
    required String resultId,
    required String defectId,
    required String recommendedStatus,
    required String recommendedClassification,
    required double confidence,
    required String suspectedCategory,
    required List<String> suspectedComponents,
    required bool reproductionSupported,
    required List<String> evidenceUsed,
    required List<_i2.DefectClarificationRequestView> clarificationRequired,
    required String recommendedNextAction,
    String? possibleDuplicateDefectId,
    String? recommendedWorkItemCategory,
    required String summary,
    String? jobId,
    String? executionId,
    required DateTime createdAt,
    DateTime? completedAt,
    required int version,
  }) : super._(
         resultId: resultId,
         defectId: defectId,
         recommendedStatus: recommendedStatus,
         recommendedClassification: recommendedClassification,
         confidence: confidence,
         suspectedCategory: suspectedCategory,
         suspectedComponents: suspectedComponents,
         reproductionSupported: reproductionSupported,
         evidenceUsed: evidenceUsed,
         clarificationRequired: clarificationRequired,
         recommendedNextAction: recommendedNextAction,
         possibleDuplicateDefectId: possibleDuplicateDefectId,
         recommendedWorkItemCategory: recommendedWorkItemCategory,
         summary: summary,
         jobId: jobId,
         executionId: executionId,
         createdAt: createdAt,
         completedAt: completedAt,
         version: version,
       );

  /// Returns a shallow copy of this [TriageResultView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  TriageResultView copyWith({
    String? resultId,
    String? defectId,
    String? recommendedStatus,
    String? recommendedClassification,
    double? confidence,
    String? suspectedCategory,
    List<String>? suspectedComponents,
    bool? reproductionSupported,
    List<String>? evidenceUsed,
    List<_i2.DefectClarificationRequestView>? clarificationRequired,
    String? recommendedNextAction,
    Object? possibleDuplicateDefectId = _Undefined,
    Object? recommendedWorkItemCategory = _Undefined,
    String? summary,
    Object? jobId = _Undefined,
    Object? executionId = _Undefined,
    DateTime? createdAt,
    Object? completedAt = _Undefined,
    int? version,
  }) {
    return TriageResultView(
      resultId: resultId ?? this.resultId,
      defectId: defectId ?? this.defectId,
      recommendedStatus: recommendedStatus ?? this.recommendedStatus,
      recommendedClassification:
          recommendedClassification ?? this.recommendedClassification,
      confidence: confidence ?? this.confidence,
      suspectedCategory: suspectedCategory ?? this.suspectedCategory,
      suspectedComponents:
          suspectedComponents ??
          this.suspectedComponents.map((e0) => e0).toList(),
      reproductionSupported:
          reproductionSupported ?? this.reproductionSupported,
      evidenceUsed: evidenceUsed ?? this.evidenceUsed.map((e0) => e0).toList(),
      clarificationRequired:
          clarificationRequired ??
          this.clarificationRequired.map((e0) => e0.copyWith()).toList(),
      recommendedNextAction:
          recommendedNextAction ?? this.recommendedNextAction,
      possibleDuplicateDefectId: possibleDuplicateDefectId is String?
          ? possibleDuplicateDefectId
          : this.possibleDuplicateDefectId,
      recommendedWorkItemCategory: recommendedWorkItemCategory is String?
          ? recommendedWorkItemCategory
          : this.recommendedWorkItemCategory,
      summary: summary ?? this.summary,
      jobId: jobId is String? ? jobId : this.jobId,
      executionId: executionId is String? ? executionId : this.executionId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt is DateTime? ? completedAt : this.completedAt,
      version: version ?? this.version,
    );
  }
}
