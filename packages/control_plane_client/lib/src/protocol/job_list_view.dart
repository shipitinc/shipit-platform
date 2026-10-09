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
import 'job_record_view.dart' as _i2;
import 'package:control_plane_client/src/protocol/protocol.dart' as _i3;

/// `schedulerEndpoints.listJobs` returned a raw map. Typed.
abstract class JobListView implements _i1.SerializableModel {
  JobListView._({required this.jobs});

  factory JobListView({required List<_i2.JobRecordView> jobs}) =
      _JobListViewImpl;

  factory JobListView.fromJson(Map<String, dynamic> jsonSerialization) {
    return JobListView(
      jobs: _i3.Protocol().deserialize<List<_i2.JobRecordView>>(
        jsonSerialization['jobs'],
      ),
    );
  }

  List<_i2.JobRecordView> jobs;

  /// Returns a shallow copy of this [JobListView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  JobListView copyWith({List<_i2.JobRecordView>? jobs});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'JobListView',
      'jobs': jobs.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _JobListViewImpl extends JobListView {
  _JobListViewImpl({required List<_i2.JobRecordView> jobs})
    : super._(jobs: jobs);

  /// Returns a shallow copy of this [JobListView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  JobListView copyWith({List<_i2.JobRecordView>? jobs}) {
    return JobListView(
      jobs: jobs ?? this.jobs.map((e0) => e0.copyWith()).toList(),
    );
  }
}
