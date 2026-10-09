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

/// A clarification the triage result asks for, before it becomes a durable
/// `DefectClarificationView`.
abstract class DefectClarificationRequestView implements _i1.SerializableModel {
  DefectClarificationRequestView._({
    required this.question,
    required this.reason,
  });

  factory DefectClarificationRequestView({
    required String question,
    required String reason,
  }) = _DefectClarificationRequestViewImpl;

  factory DefectClarificationRequestView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return DefectClarificationRequestView(
      question: jsonSerialization['question'] as String,
      reason: jsonSerialization['reason'] as String,
    );
  }

  String question;

  String reason;

  /// Returns a shallow copy of this [DefectClarificationRequestView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DefectClarificationRequestView copyWith({
    String? question,
    String? reason,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DefectClarificationRequestView',
      'question': question,
      'reason': reason,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _DefectClarificationRequestViewImpl
    extends DefectClarificationRequestView {
  _DefectClarificationRequestViewImpl({
    required String question,
    required String reason,
  }) : super._(
         question: question,
         reason: reason,
       );

  /// Returns a shallow copy of this [DefectClarificationRequestView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DefectClarificationRequestView copyWith({
    String? question,
    String? reason,
  }) {
    return DefectClarificationRequestView(
      question: question ?? this.question,
      reason: reason ?? this.reason,
    );
  }
}
