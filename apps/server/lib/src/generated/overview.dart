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
import 'job_summary_view.dart' as _i2;
import 'package:control_plane_server/src/generated/protocol.dart' as _i3;

/// Summary counts and supporting detail for the operator Overview screen.
///
/// Shape is driven by the Penpot board `BP · Home` (light/dark): three metric
/// columns, a live freshness stamp, and the "Machines and next steps" strip.
abstract class Overview
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  Overview._({
    required this.running,
    required this.waitingOnYou,
    required this.recentlyFinished,
    required this.finishedPassed,
    required this.finishedFailed,
    required this.generatedAt,
    required this.jobs,
    required this.machinesBusy,
    required this.machinesTotal,
  });

  factory Overview({
    required int running,
    required int waitingOnYou,
    required int recentlyFinished,
    required int finishedPassed,
    required int finishedFailed,
    required DateTime generatedAt,
    required List<_i2.JobSummaryView> jobs,
    required int machinesBusy,
    required int machinesTotal,
  }) = _OverviewImpl;

  factory Overview.fromJson(Map<String, dynamic> jsonSerialization) {
    return Overview(
      running: jsonSerialization['running'] as int,
      waitingOnYou: jsonSerialization['waitingOnYou'] as int,
      recentlyFinished: jsonSerialization['recentlyFinished'] as int,
      finishedPassed: jsonSerialization['finishedPassed'] as int,
      finishedFailed: jsonSerialization['finishedFailed'] as int,
      generatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['generatedAt'],
      ),
      jobs: _i3.Protocol().deserialize<List<_i2.JobSummaryView>>(
        jsonSerialization['jobs'],
      ),
      machinesBusy: jsonSerialization['machinesBusy'] as int,
      machinesTotal: jsonSerialization['machinesTotal'] as int,
    );
  }

  /// Work in flight: non-terminal and not blocked on a human.
  int running;

  /// Blocked on this operator.
  int waitingOnYou;

  /// Terminal in the last 24h.
  int recentlyFinished;

  /// Of [recentlyFinished], how many reached a successful terminal state.
  /// Renders as "in the last day · N passed, M failed".
  int finishedPassed;

  /// Of [recentlyFinished], how many ended in cancellation or termination.
  int finishedFailed;

  /// Server clock at the moment this snapshot was assembled. Drives the
  /// "LIVE / updated N seconds ago" stamp; the client measures freshness
  /// against this rather than trusting its own wall clock.
  DateTime generatedAt;

  /// Jobs that are queued or running, newest first. Powers the
  /// "Machines and next steps" strip.
  List<_i2.JobSummaryView> jobs;

  /// Workers currently executing.
  int machinesBusy;

  /// Workers registered and considered available.
  int machinesTotal;

  /// Returns a shallow copy of this [Overview]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Overview copyWith({
    int? running,
    int? waitingOnYou,
    int? recentlyFinished,
    int? finishedPassed,
    int? finishedFailed,
    DateTime? generatedAt,
    List<_i2.JobSummaryView>? jobs,
    int? machinesBusy,
    int? machinesTotal,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Overview',
      'running': running,
      'waitingOnYou': waitingOnYou,
      'recentlyFinished': recentlyFinished,
      'finishedPassed': finishedPassed,
      'finishedFailed': finishedFailed,
      'generatedAt': generatedAt.toJson(),
      'jobs': jobs.toJson(valueToJson: (v) => v.toJson()),
      'machinesBusy': machinesBusy,
      'machinesTotal': machinesTotal,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Overview',
      'running': running,
      'waitingOnYou': waitingOnYou,
      'recentlyFinished': recentlyFinished,
      'finishedPassed': finishedPassed,
      'finishedFailed': finishedFailed,
      'generatedAt': generatedAt.toJson(),
      'jobs': jobs.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'machinesBusy': machinesBusy,
      'machinesTotal': machinesTotal,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _OverviewImpl extends Overview {
  _OverviewImpl({
    required int running,
    required int waitingOnYou,
    required int recentlyFinished,
    required int finishedPassed,
    required int finishedFailed,
    required DateTime generatedAt,
    required List<_i2.JobSummaryView> jobs,
    required int machinesBusy,
    required int machinesTotal,
  }) : super._(
         running: running,
         waitingOnYou: waitingOnYou,
         recentlyFinished: recentlyFinished,
         finishedPassed: finishedPassed,
         finishedFailed: finishedFailed,
         generatedAt: generatedAt,
         jobs: jobs,
         machinesBusy: machinesBusy,
         machinesTotal: machinesTotal,
       );

  /// Returns a shallow copy of this [Overview]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Overview copyWith({
    int? running,
    int? waitingOnYou,
    int? recentlyFinished,
    int? finishedPassed,
    int? finishedFailed,
    DateTime? generatedAt,
    List<_i2.JobSummaryView>? jobs,
    int? machinesBusy,
    int? machinesTotal,
  }) {
    return Overview(
      running: running ?? this.running,
      waitingOnYou: waitingOnYou ?? this.waitingOnYou,
      recentlyFinished: recentlyFinished ?? this.recentlyFinished,
      finishedPassed: finishedPassed ?? this.finishedPassed,
      finishedFailed: finishedFailed ?? this.finishedFailed,
      generatedAt: generatedAt ?? this.generatedAt,
      jobs: jobs ?? this.jobs.map((e0) => e0.copyWith()).toList(),
      machinesBusy: machinesBusy ?? this.machinesBusy,
      machinesTotal: machinesTotal ?? this.machinesTotal,
    );
  }
}
