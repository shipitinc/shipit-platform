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
import 'worker_execution_view.dart' as _i2;
import 'package:control_plane_server/src/generated/protocol.dart' as _i3;

/// `workerEndpoints.listExecutions` returned a raw map. Typed.
abstract class WorkerExecutionListView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  WorkerExecutionListView._({required this.executions});

  factory WorkerExecutionListView({
    required List<_i2.WorkerExecutionView> executions,
  }) = _WorkerExecutionListViewImpl;

  factory WorkerExecutionListView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return WorkerExecutionListView(
      executions: _i3.Protocol().deserialize<List<_i2.WorkerExecutionView>>(
        jsonSerialization['executions'],
      ),
    );
  }

  List<_i2.WorkerExecutionView> executions;

  /// Returns a shallow copy of this [WorkerExecutionListView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WorkerExecutionListView copyWith({List<_i2.WorkerExecutionView>? executions});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkerExecutionListView',
      'executions': executions.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WorkerExecutionListView',
      'executions': executions.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _WorkerExecutionListViewImpl extends WorkerExecutionListView {
  _WorkerExecutionListViewImpl({
    required List<_i2.WorkerExecutionView> executions,
  }) : super._(executions: executions);

  /// Returns a shallow copy of this [WorkerExecutionListView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WorkerExecutionListView copyWith({
    List<_i2.WorkerExecutionView>? executions,
  }) {
    return WorkerExecutionListView(
      executions:
          executions ?? this.executions.map((e0) => e0.copyWith()).toList(),
    );
  }
}
