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
import 'work_item_action_view.dart' as _i2;
import 'work_item_failure_view.dart' as _i3;
import 'execution_capacity_view.dart' as _i4;
import 'operator_action_summary_view.dart' as _i5;
import 'package:control_plane_client/src/protocol/protocol.dart' as _i6;

/// Everything the operator screen needs to decide what, if anything, it may
/// offer for a work item parked in a failure state.
///
/// WIRE VALUES ONLY. There is no UI copy on this contract: every string the
/// client renders is a wire value it maps, exactly as `UiViewMappers
/// .workItemView` returns `state.wire` and the client maps it through
/// `PlainLanguage.statusFor`. `actions` is SERVER-COMPUTED from
/// `WorkItemTransitions` — the client renders what it is given and renders
/// nothing for an action id it does not recognise.
///
/// See design-brief.md §6.2.
abstract class WorkItemActionContextView implements _i1.SerializableModel {
  WorkItemActionContextView._({
    required this.workItemId,
    required this.state,
    required this.actions,
    this.failure,
    required this.capacity,
    required this.retryLimitResolved,
    this.retryLimitDiagnostic,
    required this.priorActions,
  });

  factory WorkItemActionContextView({
    required String workItemId,
    required String state,
    required List<_i2.WorkItemActionView> actions,
    _i3.WorkItemFailureView? failure,
    required _i4.ExecutionCapacityView capacity,
    required bool retryLimitResolved,
    String? retryLimitDiagnostic,
    required List<_i5.OperatorActionSummaryView> priorActions,
  }) = _WorkItemActionContextViewImpl;

  factory WorkItemActionContextView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return WorkItemActionContextView(
      workItemId: jsonSerialization['workItemId'] as String,
      state: jsonSerialization['state'] as String,
      actions: _i6.Protocol().deserialize<List<_i2.WorkItemActionView>>(
        jsonSerialization['actions'],
      ),
      failure: jsonSerialization['failure'] == null
          ? null
          : _i6.Protocol().deserialize<_i3.WorkItemFailureView>(
              jsonSerialization['failure'],
            ),
      capacity: _i6.Protocol().deserialize<_i4.ExecutionCapacityView>(
        jsonSerialization['capacity'],
      ),
      retryLimitResolved: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['retryLimitResolved'],
      ),
      retryLimitDiagnostic:
          jsonSerialization['retryLimitDiagnostic'] as String?,
      priorActions: _i6.Protocol()
          .deserialize<List<_i5.OperatorActionSummaryView>>(
            jsonSerialization['priorActions'],
          ),
    );
  }

  String workItemId;

  /// Durable `WorkItemState` wire value.
  String state;

  /// Server-computed from `WorkItemTransitions.isLegalTransition`. Empty when
  /// no action is legal, which is the whole signal the page uses to decide
  /// between the action panel and today's existing right-column text.
  List<_i2.WorkItemActionView> actions;

  /// null when no failure is recorded. Carries raw durable facts; the
  /// plain-language sentence is the client's to derive (§5.6).
  _i3.WorkItemFailureView? failure;

  _i4.ExecutionCapacityView capacity;

  /// HD-3 (5d9a1f62): the unset-means-unavailable case is a REPORTED state,
  /// not an absent one. Never a fallback value; never blank. When false the
  /// retry action is not offered and `retryLimitDiagnostic` names the variable
  /// and what was wrong with it.
  bool retryLimitResolved;

  /// Never null when [retryLimitResolved] is false. Says which, rather than
  /// silently omitting the action (§6.6.1 obligation 1).
  String? retryLimitDiagnostic;

  /// Append-only audit ledger for this item, oldest first — OQ-1: an audit
  /// table no operator-facing surface reads is half of what the decision bought.
  List<_i5.OperatorActionSummaryView> priorActions;

  /// Returns a shallow copy of this [WorkItemActionContextView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WorkItemActionContextView copyWith({
    String? workItemId,
    String? state,
    List<_i2.WorkItemActionView>? actions,
    _i3.WorkItemFailureView? failure,
    _i4.ExecutionCapacityView? capacity,
    bool? retryLimitResolved,
    String? retryLimitDiagnostic,
    List<_i5.OperatorActionSummaryView>? priorActions,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkItemActionContextView',
      'workItemId': workItemId,
      'state': state,
      'actions': actions.toJson(valueToJson: (v) => v.toJson()),
      if (failure != null) 'failure': failure?.toJson(),
      'capacity': capacity.toJson(),
      'retryLimitResolved': retryLimitResolved,
      if (retryLimitDiagnostic != null)
        'retryLimitDiagnostic': retryLimitDiagnostic,
      'priorActions': priorActions.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WorkItemActionContextViewImpl extends WorkItemActionContextView {
  _WorkItemActionContextViewImpl({
    required String workItemId,
    required String state,
    required List<_i2.WorkItemActionView> actions,
    _i3.WorkItemFailureView? failure,
    required _i4.ExecutionCapacityView capacity,
    required bool retryLimitResolved,
    String? retryLimitDiagnostic,
    required List<_i5.OperatorActionSummaryView> priorActions,
  }) : super._(
         workItemId: workItemId,
         state: state,
         actions: actions,
         failure: failure,
         capacity: capacity,
         retryLimitResolved: retryLimitResolved,
         retryLimitDiagnostic: retryLimitDiagnostic,
         priorActions: priorActions,
       );

  /// Returns a shallow copy of this [WorkItemActionContextView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WorkItemActionContextView copyWith({
    String? workItemId,
    String? state,
    List<_i2.WorkItemActionView>? actions,
    Object? failure = _Undefined,
    _i4.ExecutionCapacityView? capacity,
    bool? retryLimitResolved,
    Object? retryLimitDiagnostic = _Undefined,
    List<_i5.OperatorActionSummaryView>? priorActions,
  }) {
    return WorkItemActionContextView(
      workItemId: workItemId ?? this.workItemId,
      state: state ?? this.state,
      actions: actions ?? this.actions.map((e0) => e0.copyWith()).toList(),
      failure: failure is _i3.WorkItemFailureView?
          ? failure
          : this.failure?.copyWith(),
      capacity: capacity ?? this.capacity.copyWith(),
      retryLimitResolved: retryLimitResolved ?? this.retryLimitResolved,
      retryLimitDiagnostic: retryLimitDiagnostic is String?
          ? retryLimitDiagnostic
          : this.retryLimitDiagnostic,
      priorActions:
          priorActions ?? this.priorActions.map((e0) => e0.copyWith()).toList(),
    );
  }
}
