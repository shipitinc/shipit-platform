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

/// One row of a work item's transition history — and a row is NOT a move.
///
/// `work_item_transition` is an ATTEMPT log. `DurableWorkflowEngine.transition`
/// appends a row and changes nothing when the policy refuses the edge, so
/// `outcome` distinguishes "this item moved here" from "the platform tried to
/// move it here and was refused". Without it, a client cannot tell the two apart
/// and renders both as the move.
///
/// That is not cosmetic. On QA one work item carried 236 `outcome = 'rejected'`
/// rows for `agent_completed -> review_in_progress` — a refused attempt caused
/// by a role-blind producer lookup — and the timeline rendered all of them as
/// "Independent review started". The screen asserted a transition that never
/// happened, 236 times, to an operator reading it. See
/// `docs/engineering/learning/236-transition-rows-that-moved-nothing.md` §7.
///
/// NULLABLE deliberately, not defaulted. A client MUST NOT treat a missing
/// `outcome` as "accepted": that is the inference that produced the false state.
/// See `plainTransitionMessage` and `transition_copy.dart`.
abstract class TransitionView implements _i1.SerializableModel {
  TransitionView._({
    required this.transitionId,
    required this.workItemId,
    required this.fromState,
    required this.toState,
    required this.transitionedAt,
    this.reason,
    this.outcome,
  });

  factory TransitionView({
    required String transitionId,
    required String workItemId,
    required String fromState,
    required String toState,
    required DateTime transitionedAt,
    String? reason,
    String? outcome,
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
      outcome: jsonSerialization['outcome'] as String?,
    );
  }

  String transitionId;

  String workItemId;

  String fromState;

  String toState;

  DateTime transitionedAt;

  String? reason;

  /// Durable `TransitionOutcome` wire value: 'accepted' | 'rejected'.
  ///
  /// Null when the source could not report one. The UI renders such a row as
  /// an attempt it cannot classify, never as a move — an unknown outcome is
  /// not evidence that the item moved.
  String? outcome;

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
    String? outcome,
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
      if (outcome != null) 'outcome': outcome,
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
    String? outcome,
  }) : super._(
         transitionId: transitionId,
         workItemId: workItemId,
         fromState: fromState,
         toState: toState,
         transitionedAt: transitionedAt,
         reason: reason,
         outcome: outcome,
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
    Object? outcome = _Undefined,
  }) {
    return TransitionView(
      transitionId: transitionId ?? this.transitionId,
      workItemId: workItemId ?? this.workItemId,
      fromState: fromState ?? this.fromState,
      toState: toState ?? this.toState,
      transitionedAt: transitionedAt ?? this.transitionedAt,
      reason: reason is String? ? reason : this.reason,
      outcome: outcome is String? ? outcome : this.outcome,
    );
  }
}
