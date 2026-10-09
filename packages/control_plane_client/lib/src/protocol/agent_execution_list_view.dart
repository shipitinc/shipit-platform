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
import 'agent_execution_record_view.dart' as _i2;
import 'package:control_plane_client/src/protocol/protocol.dart' as _i3;

/// `executionEndpoints.list` returned a raw map. Typed.
abstract class AgentExecutionListView implements _i1.SerializableModel {
  AgentExecutionListView._({required this.executions});

  factory AgentExecutionListView({
    required List<_i2.AgentExecutionRecordView> executions,
  }) = _AgentExecutionListViewImpl;

  factory AgentExecutionListView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return AgentExecutionListView(
      executions: _i3.Protocol()
          .deserialize<List<_i2.AgentExecutionRecordView>>(
            jsonSerialization['executions'],
          ),
    );
  }

  List<_i2.AgentExecutionRecordView> executions;

  /// Returns a shallow copy of this [AgentExecutionListView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  AgentExecutionListView copyWith({
    List<_i2.AgentExecutionRecordView>? executions,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentExecutionListView',
      'executions': executions.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _AgentExecutionListViewImpl extends AgentExecutionListView {
  _AgentExecutionListViewImpl({
    required List<_i2.AgentExecutionRecordView> executions,
  }) : super._(executions: executions);

  /// Returns a shallow copy of this [AgentExecutionListView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  AgentExecutionListView copyWith({
    List<_i2.AgentExecutionRecordView>? executions,
  }) {
    return AgentExecutionListView(
      executions:
          executions ?? this.executions.map((e0) => e0.copyWith()).toList(),
    );
  }
}
