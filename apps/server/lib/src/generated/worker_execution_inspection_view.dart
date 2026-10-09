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
import 'worker_event_view.dart' as _i3;
import 'worker_execution_result_view.dart' as _i4;
import 'package:control_plane_server/src/generated/protocol.dart' as _i5;

/// `workerEndpoints.inspect` returned a raw map. Typed.
abstract class WorkerExecutionInspectionView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  WorkerExecutionInspectionView._({
    required this.execution,
    required this.events,
    this.result,
  });

  factory WorkerExecutionInspectionView({
    required _i2.WorkerExecutionView execution,
    required List<_i3.WorkerEventView> events,
    _i4.WorkerExecutionResultView? result,
  }) = _WorkerExecutionInspectionViewImpl;

  factory WorkerExecutionInspectionView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return WorkerExecutionInspectionView(
      execution: _i5.Protocol().deserialize<_i2.WorkerExecutionView>(
        jsonSerialization['execution'],
      ),
      events: _i5.Protocol().deserialize<List<_i3.WorkerEventView>>(
        jsonSerialization['events'],
      ),
      result: jsonSerialization['result'] == null
          ? null
          : _i5.Protocol().deserialize<_i4.WorkerExecutionResultView>(
              jsonSerialization['result'],
            ),
    );
  }

  _i2.WorkerExecutionView execution;

  List<_i3.WorkerEventView> events;

  _i4.WorkerExecutionResultView? result;

  /// Returns a shallow copy of this [WorkerExecutionInspectionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WorkerExecutionInspectionView copyWith({
    _i2.WorkerExecutionView? execution,
    List<_i3.WorkerEventView>? events,
    _i4.WorkerExecutionResultView? result,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkerExecutionInspectionView',
      'execution': execution.toJson(),
      'events': events.toJson(valueToJson: (v) => v.toJson()),
      if (result != null) 'result': result?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WorkerExecutionInspectionView',
      'execution': execution.toJsonForProtocol(),
      'events': events.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      if (result != null) 'result': result?.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WorkerExecutionInspectionViewImpl extends WorkerExecutionInspectionView {
  _WorkerExecutionInspectionViewImpl({
    required _i2.WorkerExecutionView execution,
    required List<_i3.WorkerEventView> events,
    _i4.WorkerExecutionResultView? result,
  }) : super._(
         execution: execution,
         events: events,
         result: result,
       );

  /// Returns a shallow copy of this [WorkerExecutionInspectionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WorkerExecutionInspectionView copyWith({
    _i2.WorkerExecutionView? execution,
    List<_i3.WorkerEventView>? events,
    Object? result = _Undefined,
  }) {
    return WorkerExecutionInspectionView(
      execution: execution ?? this.execution.copyWith(),
      events: events ?? this.events.map((e0) => e0.copyWith()).toList(),
      result: result is _i4.WorkerExecutionResultView?
          ? result
          : this.result?.copyWith(),
    );
  }
}
