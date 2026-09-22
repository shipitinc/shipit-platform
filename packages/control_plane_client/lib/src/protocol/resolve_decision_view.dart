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
import 'work_item_view.dart' as _i2;
import 'decision_view.dart' as _i3;
import 'package:control_plane_client/src/protocol/protocol.dart' as _i4;

abstract class ResolveDecisionView implements _i1.SerializableModel {
  ResolveDecisionView._({
    required this.workItem,
    this.decision,
  });

  factory ResolveDecisionView({
    required _i2.WorkItemView workItem,
    _i3.DecisionView? decision,
  }) = _ResolveDecisionViewImpl;

  factory ResolveDecisionView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ResolveDecisionView(
      workItem: _i4.Protocol().deserialize<_i2.WorkItemView>(
        jsonSerialization['workItem'],
      ),
      decision: jsonSerialization['decision'] == null
          ? null
          : _i4.Protocol().deserialize<_i3.DecisionView>(
              jsonSerialization['decision'],
            ),
    );
  }

  _i2.WorkItemView workItem;

  _i3.DecisionView? decision;

  /// Returns a shallow copy of this [ResolveDecisionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ResolveDecisionView copyWith({
    _i2.WorkItemView? workItem,
    _i3.DecisionView? decision,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ResolveDecisionView',
      'workItem': workItem.toJson(),
      if (decision != null) 'decision': decision?.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ResolveDecisionViewImpl extends ResolveDecisionView {
  _ResolveDecisionViewImpl({
    required _i2.WorkItemView workItem,
    _i3.DecisionView? decision,
  }) : super._(
         workItem: workItem,
         decision: decision,
       );

  /// Returns a shallow copy of this [ResolveDecisionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ResolveDecisionView copyWith({
    _i2.WorkItemView? workItem,
    Object? decision = _Undefined,
  }) {
    return ResolveDecisionView(
      workItem: workItem ?? this.workItem.copyWith(),
      decision: decision is _i3.DecisionView?
          ? decision
          : this.decision?.copyWith(),
    );
  }
}
