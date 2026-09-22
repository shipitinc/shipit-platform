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

abstract class TransitionView implements _i1.SerializableModel {
  TransitionView._({
    required this.transitionId,
    required this.workItemId,
    required this.fromState,
    required this.toState,
    required this.transitionedAt,
    this.reason,
  });

  factory TransitionView({
    required String transitionId,
    required String workItemId,
    required String fromState,
    required String toState,
    required DateTime transitionedAt,
    String? reason,
  }) = _TransitionViewImpl;

  factory TransitionView.fromJson(Map<String, dynamic> jsonSerialization) {
    return TransitionView(
      transitionId: jsonSerialization['transitionId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      fromState: jsonSerialization['fromState'] as String,
      toState: jsonSerialization['toState'] as String,
      transitionedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['transitionedAt'],
      ),
      reason: jsonSerialization['reason'] as String?,
    );
  }

  String transitionId;

  String workItemId;

  String fromState;

  String toState;

  DateTime transitionedAt;

  String? reason;

  /// Returns a shallow copy of this [TransitionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  TransitionView copyWith({
    String? transitionId,
    String? workItemId,
    String? fromState,
    String? toState,
    DateTime? transitionedAt,
    String? reason,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'TransitionView',
      'transitionId': transitionId,
      'workItemId': workItemId,
      'fromState': fromState,
      'toState': toState,
      'transitionedAt': transitionedAt.toJson(),
      if (reason != null) 'reason': reason,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _TransitionViewImpl extends TransitionView {
  _TransitionViewImpl({
    required String transitionId,
    required String workItemId,
    required String fromState,
    required String toState,
    required DateTime transitionedAt,
    String? reason,
  }) : super._(
         transitionId: transitionId,
         workItemId: workItemId,
         fromState: fromState,
         toState: toState,
         transitionedAt: transitionedAt,
         reason: reason,
       );

  /// Returns a shallow copy of this [TransitionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  TransitionView copyWith({
    String? transitionId,
    String? workItemId,
    String? fromState,
    String? toState,
    DateTime? transitionedAt,
    Object? reason = _Undefined,
  }) {
    return TransitionView(
      transitionId: transitionId ?? this.transitionId,
      workItemId: workItemId ?? this.workItemId,
      fromState: fromState ?? this.fromState,
      toState: toState ?? this.toState,
      transitionedAt: transitionedAt ?? this.transitionedAt,
      reason: reason is String? ? reason : this.reason,
    );
  }
}
