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
import 'package:control_plane_server/src/generated/protocol.dart' as _i3;

/// The result of one operator action. Every call terminates in exactly one of
/// the outcomes named by `outcome`; there is no error outcome for "capacity
/// full", because a denial is a normal outcome with a defined meaning and
/// rendering it as an error would teach operators that the system is broken
/// when it is correctly bounded (design-brief.md §6.3, §7.1).
///
/// `outcome` is a WIRE VALUE. The operator-facing sentence for each one is the
/// client's to word, from the vocabulary in design-brief.md §5.4/§8.2 — this
/// model carries no copy.
abstract class WorkItemActionResult
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  WorkItemActionResult._({
    required this.outcome,
    required this.workItem,
    this.jobId,
    this.jobState,
    required this.attemptNumber,
    this.inFlight,
    this.cap,
    required this.retryLimitResolved,
    required this.attemptLimit,
  });

  factory WorkItemActionResult({
    required String outcome,
    required _i2.WorkItemView workItem,
    String? jobId,
    String? jobState,
    required int attemptNumber,
    int? inFlight,
    int? cap,
    required bool retryLimitResolved,
    required int attemptLimit,
  }) = _WorkItemActionResultImpl;

  factory WorkItemActionResult.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return WorkItemActionResult(
      outcome: jsonSerialization['outcome'] as String,
      workItem: _i3.Protocol().deserialize<_i2.WorkItemView>(
        jsonSerialization['workItem'],
      ),
      jobId: jsonSerialization['jobId'] as String?,
      jobState: jsonSerialization['jobState'] as String?,
      attemptNumber: jsonSerialization['attemptNumber'] as int,
      inFlight: jsonSerialization['inFlight'] as int?,
      cap: jsonSerialization['cap'] as int?,
      retryLimitResolved: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['retryLimitResolved'],
      ),
      attemptLimit: jsonSerialization['attemptLimit'] as int,
    );
  }

  /// 'accepted' | 'alreadyRunning' | 'alreadyStopped' | 'notApplicable' |
  /// 'notConfigured' | 'invalidRequest'.
  String outcome;

  _i2.WorkItemView workItem;

  /// The job this action armed, when one exists. A retry arms none directly —
  /// the scheduler enqueues from the item's durable `triageAttempt` marker on
  /// its ordinary tick — so this is null for a freshly accepted retry.
  String? jobId;

  String? jobState;

  /// 1-based attempt number this action consumed. 0 when it consumed none.
  int attemptNumber;

  int? inFlight;

  int? cap;

  /// The resolved per-work-item retry maximum, and whether it resolved at all.
  /// Carried on the RESULT as well as on the context because `notConfigured`
  /// covers two genuinely different situations — the limit is reached, or the
  /// limit was never configured — and the client must word them differently
  /// without the server authoring copy (AC-15b/AC-15c/AC-15d, §6.6.1).
  bool retryLimitResolved;

  int attemptLimit;

  /// Returns a shallow copy of this [WorkItemActionResult]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WorkItemActionResult copyWith({
    String? outcome,
    _i2.WorkItemView? workItem,
    String? jobId,
    String? jobState,
    int? attemptNumber,
    int? inFlight,
    int? cap,
    bool? retryLimitResolved,
    int? attemptLimit,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkItemActionResult',
      'outcome': outcome,
      'workItem': workItem.toJson(),
      if (jobId != null) 'jobId': jobId,
      if (jobState != null) 'jobState': jobState,
      'attemptNumber': attemptNumber,
      if (inFlight != null) 'inFlight': inFlight,
      if (cap != null) 'cap': cap,
      'retryLimitResolved': retryLimitResolved,
      'attemptLimit': attemptLimit,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WorkItemActionResult',
      'outcome': outcome,
      'workItem': workItem.toJsonForProtocol(),
      if (jobId != null) 'jobId': jobId,
      if (jobState != null) 'jobState': jobState,
      'attemptNumber': attemptNumber,
      if (inFlight != null) 'inFlight': inFlight,
      if (cap != null) 'cap': cap,
      'retryLimitResolved': retryLimitResolved,
      'attemptLimit': attemptLimit,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WorkItemActionResultImpl extends WorkItemActionResult {
  _WorkItemActionResultImpl({
    required String outcome,
    required _i2.WorkItemView workItem,
    String? jobId,
    String? jobState,
    required int attemptNumber,
    int? inFlight,
    int? cap,
    required bool retryLimitResolved,
    required int attemptLimit,
  }) : super._(
         outcome: outcome,
         workItem: workItem,
         jobId: jobId,
         jobState: jobState,
         attemptNumber: attemptNumber,
         inFlight: inFlight,
         cap: cap,
         retryLimitResolved: retryLimitResolved,
         attemptLimit: attemptLimit,
       );

  /// Returns a shallow copy of this [WorkItemActionResult]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WorkItemActionResult copyWith({
    String? outcome,
    _i2.WorkItemView? workItem,
    Object? jobId = _Undefined,
    Object? jobState = _Undefined,
    int? attemptNumber,
    Object? inFlight = _Undefined,
    Object? cap = _Undefined,
    bool? retryLimitResolved,
    int? attemptLimit,
  }) {
    return WorkItemActionResult(
      outcome: outcome ?? this.outcome,
      workItem: workItem ?? this.workItem.copyWith(),
      jobId: jobId is String? ? jobId : this.jobId,
      jobState: jobState is String? ? jobState : this.jobState,
      attemptNumber: attemptNumber ?? this.attemptNumber,
      inFlight: inFlight is int? ? inFlight : this.inFlight,
      cap: cap is int? ? cap : this.cap,
      retryLimitResolved: retryLimitResolved ?? this.retryLimitResolved,
      attemptLimit: attemptLimit ?? this.attemptLimit,
    );
  }
}
