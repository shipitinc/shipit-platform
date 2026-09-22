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

/// A durable request for human input on a material unknown. Survives
/// restart and resumes the same Product/onboarding lineage.
abstract class ClarificationView implements _i1.SerializableModel {
  ClarificationView._({
    required this.clarificationId,
    required this.productId,
    required this.onboardingId,
    required this.section,
    required this.question,
    required this.status,
    this.answer,
    required this.createdAt,
    this.answeredAt,
    this.answeredBy,
  });

  factory ClarificationView({
    required String clarificationId,
    required String productId,
    required String onboardingId,
    required String section,
    required String question,
    required String status,
    String? answer,
    required DateTime createdAt,
    DateTime? answeredAt,
    String? answeredBy,
  }) = _ClarificationViewImpl;

  factory ClarificationView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ClarificationView(
      clarificationId: jsonSerialization['clarificationId'] as String,
      productId: jsonSerialization['productId'] as String,
      onboardingId: jsonSerialization['onboardingId'] as String,
      section: jsonSerialization['section'] as String,
      question: jsonSerialization['question'] as String,
      status: jsonSerialization['status'] as String,
      answer: jsonSerialization['answer'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      answeredAt: jsonSerialization['answeredAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['answeredAt']),
      answeredBy: jsonSerialization['answeredBy'] as String?,
    );
  }

  String clarificationId;

  String productId;

  String onboardingId;

  String section;

  String question;

  /// needs_answer | answered | withdrawn
  String status;

  String? answer;

  DateTime createdAt;

  DateTime? answeredAt;

  String? answeredBy;

  /// Returns a shallow copy of this [ClarificationView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ClarificationView copyWith({
    String? clarificationId,
    String? productId,
    String? onboardingId,
    String? section,
    String? question,
    String? status,
    String? answer,
    DateTime? createdAt,
    DateTime? answeredAt,
    String? answeredBy,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ClarificationView',
      'clarificationId': clarificationId,
      'productId': productId,
      'onboardingId': onboardingId,
      'section': section,
      'question': question,
      'status': status,
      if (answer != null) 'answer': answer,
      'createdAt': createdAt.toJson(),
      if (answeredAt != null) 'answeredAt': answeredAt?.toJson(),
      if (answeredBy != null) 'answeredBy': answeredBy,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ClarificationViewImpl extends ClarificationView {
  _ClarificationViewImpl({
    required String clarificationId,
    required String productId,
    required String onboardingId,
    required String section,
    required String question,
    required String status,
    String? answer,
    required DateTime createdAt,
    DateTime? answeredAt,
    String? answeredBy,
  }) : super._(
         clarificationId: clarificationId,
         productId: productId,
         onboardingId: onboardingId,
         section: section,
         question: question,
         status: status,
         answer: answer,
         createdAt: createdAt,
         answeredAt: answeredAt,
         answeredBy: answeredBy,
       );

  /// Returns a shallow copy of this [ClarificationView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ClarificationView copyWith({
    String? clarificationId,
    String? productId,
    String? onboardingId,
    String? section,
    String? question,
    String? status,
    Object? answer = _Undefined,
    DateTime? createdAt,
    Object? answeredAt = _Undefined,
    Object? answeredBy = _Undefined,
  }) {
    return ClarificationView(
      clarificationId: clarificationId ?? this.clarificationId,
      productId: productId ?? this.productId,
      onboardingId: onboardingId ?? this.onboardingId,
      section: section ?? this.section,
      question: question ?? this.question,
      status: status ?? this.status,
      answer: answer is String? ? answer : this.answer,
      createdAt: createdAt ?? this.createdAt,
      answeredAt: answeredAt is DateTime? ? answeredAt : this.answeredAt,
      answeredBy: answeredBy is String? ? answeredBy : this.answeredBy,
    );
  }
}
