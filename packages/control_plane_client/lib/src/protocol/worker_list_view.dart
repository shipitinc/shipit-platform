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
import 'worker_registration_view.dart' as _i2;
import 'package:control_plane_client/src/protocol/protocol.dart' as _i3;

/// `workerEndpoints.listWorkers` returned a raw map. Typed.
abstract class WorkerListView implements _i1.SerializableModel {
  WorkerListView._({required this.workers});

  factory WorkerListView({required List<_i2.WorkerRegistrationView> workers}) =
      _WorkerListViewImpl;

  factory WorkerListView.fromJson(Map<String, dynamic> jsonSerialization) {
    return WorkerListView(
      workers: _i3.Protocol().deserialize<List<_i2.WorkerRegistrationView>>(
        jsonSerialization['workers'],
      ),
    );
  }

  List<_i2.WorkerRegistrationView> workers;

  /// Returns a shallow copy of this [WorkerListView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WorkerListView copyWith({List<_i2.WorkerRegistrationView>? workers});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkerListView',
      'workers': workers.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _WorkerListViewImpl extends WorkerListView {
  _WorkerListViewImpl({required List<_i2.WorkerRegistrationView> workers})
    : super._(workers: workers);

  /// Returns a shallow copy of this [WorkerListView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WorkerListView copyWith({List<_i2.WorkerRegistrationView>? workers}) {
    return WorkerListView(
      workers: workers ?? this.workers.map((e0) => e0.copyWith()).toList(),
    );
  }
}
