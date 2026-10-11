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

/// The global agent-execution budget as it stands right now.
///
/// `inFlight` is derived from durable `job.state` rows exactly as
/// `JobCapacityGuard._countInFlight` derives it — the same predicate, over the
/// same rows — so the number on screen and the number the guard uses at claim
/// time are the same number.
///
/// `snapshotOnly` is ALWAYS true and must stay true. This is an observation of
/// a budget at one instant, never a promise: `JobCapacityGuard` has no
/// read-only probe and adding one would be a lie, because the check must be
/// atomic with the reservation or two replicas each read `inFlight = C-1` and
/// the cap is exceeded by one per replica (design-brief.md P-5, §7.2).
/// Nothing on the operator screen may pre-check capacity.
abstract class ExecutionCapacityView implements _i1.SerializableModel {
  ExecutionCapacityView._({
    required this.budget,
    required this.cap,
    required this.inFlight,
    required this.snapshotOnly,
    required this.resolved,
  });

  factory ExecutionCapacityView({
    required String budget,
    required int cap,
    required int inFlight,
    required bool snapshotOnly,
    required bool resolved,
  }) = _ExecutionCapacityViewImpl;

  factory ExecutionCapacityView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return ExecutionCapacityView(
      budget: jsonSerialization['budget'] as String,
      cap: jsonSerialization['cap'] as int,
      inFlight: jsonSerialization['inFlight'] as int,
      snapshotOnly: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['snapshotOnly'],
      ),
      resolved: _i1.BoolJsonExtension.fromJson(jsonSerialization['resolved']),
    );
  }

  String budget;

  int cap;

  int inFlight;

  bool snapshotOnly;

  /// False when `SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS` did not resolve, in
  /// which case [cap] is 0 and MUST NOT be shown as a real budget. The cap is
  /// itself a fail-closed configuration (`execution_capacity.dart`); an
  /// unresolved one is reported rather than papered over with a number.
  bool resolved;

  /// Returns a shallow copy of this [ExecutionCapacityView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ExecutionCapacityView copyWith({
    String? budget,
    int? cap,
    int? inFlight,
    bool? snapshotOnly,
    bool? resolved,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ExecutionCapacityView',
      'budget': budget,
      'cap': cap,
      'inFlight': inFlight,
      'snapshotOnly': snapshotOnly,
      'resolved': resolved,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _ExecutionCapacityViewImpl extends ExecutionCapacityView {
  _ExecutionCapacityViewImpl({
    required String budget,
    required int cap,
    required int inFlight,
    required bool snapshotOnly,
    required bool resolved,
  }) : super._(
         budget: budget,
         cap: cap,
         inFlight: inFlight,
         snapshotOnly: snapshotOnly,
         resolved: resolved,
       );

  /// Returns a shallow copy of this [ExecutionCapacityView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ExecutionCapacityView copyWith({
    String? budget,
    int? cap,
    int? inFlight,
    bool? snapshotOnly,
    bool? resolved,
  }) {
    return ExecutionCapacityView(
      budget: budget ?? this.budget,
      cap: cap ?? this.cap,
      inFlight: inFlight ?? this.inFlight,
      snapshotOnly: snapshotOnly ?? this.snapshotOnly,
      resolved: resolved ?? this.resolved,
    );
  }
}
