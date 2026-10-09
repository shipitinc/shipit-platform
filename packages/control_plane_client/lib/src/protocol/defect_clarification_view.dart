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

/// One clarification an agent raised and a human may answer.
abstract class DefectClarificationView implements _i1.SerializableModel {
  DefectClarificationView._({
    required this.clarificationId,
    required this.defectId,
    required this.question,
    required this.reason,
    required this.status,
    this.answer,
    this.humanDecisionId,
    this.requestedByTriageJobId,
    required this.requestedAt,
    this.answeredAt,
    required this.createdAt,
  });

  factory DefectClarificationView({
    required String clarificationId,
    required String defectId,
    required String question,
    required String reason,
    required String status,
    String? answer,
    String? humanDecisionId,
    String? requestedByTriageJobId,
    required DateTime requestedAt,
    DateTime? answeredAt,
    required DateTime createdAt,
  }) = _DefectClarificationViewImpl;

  factory DefectClarificationView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return DefectClarificationView(
      clarificationId: jsonSerialization['clarificationId'] as String,
      defectId: jsonSerialization['defectId'] as String,
      question: jsonSerialization['question'] as String,
      reason: jsonSerialization['reason'] as String,
      status: jsonSerialization['status'] as String,
      answer: jsonSerialization['answer'] as String?,
      humanDecisionId: jsonSerialization['humanDecisionId'] as String?,
      requestedByTriageJobId:
          jsonSerialization['requestedByTriageJobId'] as String?,
      requestedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['requestedAt'],
      ),
      answeredAt: jsonSerialization['answeredAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['answeredAt']),
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  String clarificationId;

  String defectId;

  String question;

  String reason;

  /// Durable clarification status wire value.
  String status;

  String? answer;

  String? humanDecisionId;

  String? requestedByTriageJobId;

  DateTime requestedAt;

  DateTime? answeredAt;

  DateTime createdAt;

  /// Returns a shallow copy of this [DefectClarificationView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DefectClarificationView copyWith({
    String? clarificationId,
    String? defectId,
    String? question,
    String? reason,
    String? status,
    String? answer,
    String? humanDecisionId,
    String? requestedByTriageJobId,
    DateTime? requestedAt,
    DateTime? answeredAt,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DefectClarificationView',
      'clarificationId': clarificationId,
      'defectId': defectId,
      'question': question,
      'reason': reason,
      'status': status,
      if (answer != null) 'answer': answer,
      if (humanDecisionId != null) 'humanDecisionId': humanDecisionId,
      if (requestedByTriageJobId != null)
        'requestedByTriageJobId': requestedByTriageJobId,
      'requestedAt': requestedAt.toJson(),
      if (answeredAt != null) 'answeredAt': answeredAt?.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DefectClarificationViewImpl extends DefectClarificationView {
  _DefectClarificationViewImpl({
    required String clarificationId,
    required String defectId,
    required String question,
    required String reason,
    required String status,
    String? answer,
    String? humanDecisionId,
    String? requestedByTriageJobId,
    required DateTime requestedAt,
    DateTime? answeredAt,
    required DateTime createdAt,
  }) : super._(
         clarificationId: clarificationId,
         defectId: defectId,
         question: question,
         reason: reason,
         status: status,
         answer: answer,
         humanDecisionId: humanDecisionId,
         requestedByTriageJobId: requestedByTriageJobId,
         requestedAt: requestedAt,
         answeredAt: answeredAt,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [DefectClarificationView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DefectClarificationView copyWith({
    String? clarificationId,
    String? defectId,
    String? question,
    String? reason,
    String? status,
    Object? answer = _Undefined,
    Object? humanDecisionId = _Undefined,
    Object? requestedByTriageJobId = _Undefined,
    DateTime? requestedAt,
    Object? answeredAt = _Undefined,
    DateTime? createdAt,
  }) {
    return DefectClarificationView(
      clarificationId: clarificationId ?? this.clarificationId,
      defectId: defectId ?? this.defectId,
      question: question ?? this.question,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      answer: answer is String? ? answer : this.answer,
      humanDecisionId: humanDecisionId is String?
          ? humanDecisionId
          : this.humanDecisionId,
      requestedByTriageJobId: requestedByTriageJobId is String?
          ? requestedByTriageJobId
          : this.requestedByTriageJobId,
      requestedAt: requestedAt ?? this.requestedAt,
      answeredAt: answeredAt is DateTime? ? answeredAt : this.answeredAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
