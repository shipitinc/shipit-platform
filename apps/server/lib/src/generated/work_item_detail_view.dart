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

import 'package:serverpod/serverpod.dart' as _i1;
import 'work_item_view.dart' as _i2;
import 'transition_view.dart' as _i3;
import 'package:control_plane_server/src/generated/protocol.dart' as _i4;

abstract class WorkItemDetailView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  WorkItemDetailView._({
    required this.workItem,
    required this.transitionHistory,
  });

  factory WorkItemDetailView({
    required _i2.WorkItemView workItem,
    required List<_i3.TransitionView> transitionHistory,
  }) = _WorkItemDetailViewImpl;

  factory WorkItemDetailView.fromJson(Map<String, dynamic> jsonSerialization) {
    return WorkItemDetailView(
      workItem: _i4.Protocol().deserialize<_i2.WorkItemView>(
        jsonSerialization['workItem'],
      ),
      transitionHistory: _i4.Protocol().deserialize<List<_i3.TransitionView>>(
        jsonSerialization['transitionHistory'],
      ),
    );
  }

  _i2.WorkItemView workItem;

  List<_i3.TransitionView> transitionHistory;

  /// Returns a shallow copy of this [WorkItemDetailView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WorkItemDetailView copyWith({
    _i2.WorkItemView? workItem,
    List<_i3.TransitionView>? transitionHistory,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkItemDetailView',
      'workItem': workItem.toJson(),
      'transitionHistory': transitionHistory.toJson(
        valueToJson: (v) => v.toJson(),
      ),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WorkItemDetailView',
      'workItem': workItem.toJsonForProtocol(),
      'transitionHistory': transitionHistory.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _WorkItemDetailViewImpl extends WorkItemDetailView {
  _WorkItemDetailViewImpl({
    required _i2.WorkItemView workItem,
    required List<_i3.TransitionView> transitionHistory,
  }) : super._(
         workItem: workItem,
         transitionHistory: transitionHistory,
       );

  /// Returns a shallow copy of this [WorkItemDetailView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WorkItemDetailView copyWith({
    _i2.WorkItemView? workItem,
    List<_i3.TransitionView>? transitionHistory,
  }) {
    return WorkItemDetailView(
      workItem: workItem ?? this.workItem.copyWith(),
      transitionHistory:
          transitionHistory ??
          this.transitionHistory.map((e0) => e0.copyWith()).toList(),
    );
  }
}
