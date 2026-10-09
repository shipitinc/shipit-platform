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

/// One diagnostic an agent run emitted.
abstract class DiagnosticEntryView implements _i1.SerializableModel {
  DiagnosticEntryView._({
    required this.code,
    required this.message,
    required this.severity,
    this.location,
    this.suggestion,
  });

  factory DiagnosticEntryView({
    required String code,
    required String message,
    required String severity,
    String? location,
    String? suggestion,
  }) = _DiagnosticEntryViewImpl;

  factory DiagnosticEntryView.fromJson(Map<String, dynamic> jsonSerialization) {
    return DiagnosticEntryView(
      code: jsonSerialization['code'] as String,
      message: jsonSerialization['message'] as String,
      severity: jsonSerialization['severity'] as String,
      location: jsonSerialization['location'] as String?,
      suggestion: jsonSerialization['suggestion'] as String?,
    );
  }

  String code;

  String message;

  String severity;

  String? location;

  String? suggestion;

  /// Returns a shallow copy of this [DiagnosticEntryView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  DiagnosticEntryView copyWith({
    String? code,
    String? message,
    String? severity,
    String? location,
    String? suggestion,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DiagnosticEntryView',
      'code': code,
      'message': message,
      'severity': severity,
      if (location != null) 'location': location,
      if (suggestion != null) 'suggestion': suggestion,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DiagnosticEntryViewImpl extends DiagnosticEntryView {
  _DiagnosticEntryViewImpl({
    required String code,
    required String message,
    required String severity,
    String? location,
    String? suggestion,
  }) : super._(
         code: code,
         message: message,
         severity: severity,
         location: location,
         suggestion: suggestion,
       );

  /// Returns a shallow copy of this [DiagnosticEntryView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  DiagnosticEntryView copyWith({
    String? code,
    String? message,
    String? severity,
    Object? location = _Undefined,
    Object? suggestion = _Undefined,
  }) {
    return DiagnosticEntryView(
      code: code ?? this.code,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      location: location is String? ? location : this.location,
      suggestion: suggestion is String? ? suggestion : this.suggestion,
    );
  }
}
