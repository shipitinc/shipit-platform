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
import 'job_record_view.dart' as _i2;
import 'scheduler_event_view.dart' as _i3;
import 'job_claim_view.dart' as _i4;
import 'package:control_plane_server/src/generated/protocol.dart' as _i5;

/// `schedulerEndpoints.inspect` returned a raw map. Typed.
abstract class JobInspectionView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  JobInspectionView._({
    required this.job,
    required this.events,
    this.claim,
  });

  factory JobInspectionView({
    required _i2.JobRecordView job,
    required List<_i3.SchedulerEventView> events,
    _i4.JobClaimView? claim,
  }) = _JobInspectionViewImpl;

  factory JobInspectionView.fromJson(Map<String, dynamic> jsonSerialization) {
    return JobInspectionView(
      job: _i5.Protocol().deserialize<_i2.JobRecordView>(
        jsonSerialization['job'],
      ),
      events: _i5.Protocol().deserialize<List<_i3.SchedulerEventView>>(
        jsonSerialization['events'],
      ),
      claim: jsonSerialization['claim'] == null
          ? null
          : _i5.Protocol().deserialize<_i4.JobClaimView>(
              jsonSerialization['claim'],
            ),
    );
  }

  _i2.JobRecordView job;

  List<_i3.SchedulerEventView> events;

  _i4.JobClaimView? claim;

  /// Returns a shallow copy of this [JobInspectionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  JobInspectionView copyWith({
    _i2.JobRecordView? job,
    List<_i3.SchedulerEventView>? events,
    _i4.JobClaimView? claim,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'JobInspectionView',
      'job': job.toJson(),
      'events': events.toJson(valueToJson: (v) => v.toJson()),
      if (claim != null) 'claim': claim?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'JobInspectionView',
      'job': job.toJsonForProtocol(),
      'events': events.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      if (claim != null) 'claim': claim?.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _JobInspectionViewImpl extends JobInspectionView {
  _JobInspectionViewImpl({
    required _i2.JobRecordView job,
    required List<_i3.SchedulerEventView> events,
    _i4.JobClaimView? claim,
  }) : super._(
         job: job,
         events: events,
         claim: claim,
       );

  /// Returns a shallow copy of this [JobInspectionView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  JobInspectionView copyWith({
    _i2.JobRecordView? job,
    List<_i3.SchedulerEventView>? events,
    Object? claim = _Undefined,
  }) {
    return JobInspectionView(
      job: job ?? this.job.copyWith(),
      events: events ?? this.events.map((e0) => e0.copyWith()).toList(),
      claim: claim is _i4.JobClaimView? ? claim : this.claim?.copyWith(),
    );
  }
}
