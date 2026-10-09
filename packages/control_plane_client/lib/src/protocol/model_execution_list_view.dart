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
import 'model_execution_record_view.dart' as _i2;
import 'package:control_plane_client/src/protocol/protocol.dart' as _i3;

/// `providerHealthEndpoints.listModelExecutions` returned a raw map. Typed.
abstract class ModelExecutionListView implements _i1.SerializableModel {
  ModelExecutionListView._({
    required this.executions,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory ModelExecutionListView({
    required List<_i2.ModelExecutionRecordView> executions,
    required int total,
    required int limit,
    required int offset,
  }) = _ModelExecutionListViewImpl;

  factory ModelExecutionListView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return ModelExecutionListView(
      executions: _i3.Protocol()
          .deserialize<List<_i2.ModelExecutionRecordView>>(
            jsonSerialization['executions'],
          ),
      total: jsonSerialization['total'] as int,
      limit: jsonSerialization['limit'] as int,
      offset: jsonSerialization['offset'] as int,
    );
  }

  List<_i2.ModelExecutionRecordView> executions;

  /// Rows matching the filters BEFORE `limit`/`offset` were applied.
  int total;

  int limit;

  int offset;

  /// Returns a shallow copy of this [ModelExecutionListView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ModelExecutionListView copyWith({
    List<_i2.ModelExecutionRecordView>? executions,
    int? total,
    int? limit,
    int? offset,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ModelExecutionListView',
      'executions': executions.toJson(valueToJson: (v) => v.toJson()),
      'total': total,
      'limit': limit,
      'offset': offset,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _ModelExecutionListViewImpl extends ModelExecutionListView {
  _ModelExecutionListViewImpl({
    required List<_i2.ModelExecutionRecordView> executions,
    required int total,
    required int limit,
    required int offset,
  }) : super._(
         executions: executions,
         total: total,
         limit: limit,
         offset: offset,
       );

  /// Returns a shallow copy of this [ModelExecutionListView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ModelExecutionListView copyWith({
    List<_i2.ModelExecutionRecordView>? executions,
    int? total,
    int? limit,
    int? offset,
  }) {
    return ModelExecutionListView(
      executions:
          executions ?? this.executions.map((e0) => e0.copyWith()).toList(),
      total: total ?? this.total,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }
}
