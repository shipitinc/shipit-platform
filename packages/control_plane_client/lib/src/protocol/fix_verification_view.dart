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

/// `defectEndpoints.verifyFix` returned a raw map. Typed.
abstract class FixVerificationView implements _i1.SerializableModel {
  FixVerificationView._({
    required this.success,
    required this.newStatus,
    required this.message,
  });

  factory FixVerificationView({
    required bool success,
    required String newStatus,
    required String message,
  }) = _FixVerificationViewImpl;

  factory FixVerificationView.fromJson(Map<String, dynamic> jsonSerialization) {
    return FixVerificationView(
      success: _i1.BoolJsonExtension.fromJson(jsonSerialization['success']),
      newStatus: jsonSerialization['newStatus'] as String,
      message: jsonSerialization['message'] as String,
    );
  }

  bool success;

  /// The defect's status after the decision was recorded.
  String newStatus;

  String message;

  /// Returns a shallow copy of this [FixVerificationView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  FixVerificationView copyWith({
    bool? success,
    String? newStatus,
    String? message,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FixVerificationView',
      'success': success,
      'newStatus': newStatus,
      'message': message,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _FixVerificationViewImpl extends FixVerificationView {
  _FixVerificationViewImpl({
    required bool success,
    required String newStatus,
    required String message,
  }) : super._(
         success: success,
         newStatus: newStatus,
         message: message,
       );

  /// Returns a shallow copy of this [FixVerificationView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  FixVerificationView copyWith({
    bool? success,
    String? newStatus,
    String? message,
  }) {
    return FixVerificationView(
      success: success ?? this.success,
      newStatus: newStatus ?? this.newStatus,
      message: message ?? this.message,
    );
  }
}
