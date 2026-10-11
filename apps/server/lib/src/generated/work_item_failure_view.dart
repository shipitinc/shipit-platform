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

/// The durable record of why a work item stopped, as facts.
///
/// RAW AND UNTRANSLATED. Every field here is verbatim durable state: the
/// `work_item_transition.reason` column, the terminal job's failure code and
/// reason, and the job's failure JSON. The plain-language sentence the operator
/// reads is derived on the client by the closed-set classifier of
/// design-brief.md §5.6, which recognises only causes this repository itself
/// emits and never guesses (N8). The raw record stays verbatim in the page's
/// existing "Show technical details" disclosure (AC-22).
abstract class WorkItemFailureView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  WorkItemFailureView._({
    this.transitionId,
    this.at,
    this.reason,
    this.actorType,
    this.jobId,
    this.jobState,
    this.jobFailureCode,
    this.jobFailureReason,
    this.jobFailureJson,
  });

  factory WorkItemFailureView({
    String? transitionId,
    DateTime? at,
    String? reason,
    String? actorType,
    String? jobId,
    String? jobState,
    String? jobFailureCode,
    String? jobFailureReason,
    String? jobFailureJson,
  }) = _WorkItemFailureViewImpl;

  factory WorkItemFailureView.fromJson(Map<String, dynamic> jsonSerialization) {
    return WorkItemFailureView(
      transitionId: jsonSerialization['transitionId'] as String?,
      at: jsonSerialization['at'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['at']),
      reason: jsonSerialization['reason'] as String?,
      actorType: jsonSerialization['actorType'] as String?,
      jobId: jsonSerialization['jobId'] as String?,
      jobState: jsonSerialization['jobState'] as String?,
      jobFailureCode: jsonSerialization['jobFailureCode'] as String?,
      jobFailureReason: jsonSerialization['jobFailureReason'] as String?,
      jobFailureJson: jsonSerialization['jobFailureJson'] as String?,
    );
  }

  String? transitionId;

  DateTime? at;

  /// `work_item_transition.reason` of the transition that ENTERED the failure
  /// state. Verbatim, untranslated, and null when the system recorded none —
  /// which the panel reports as missing rather than rendering blank (AC-21).
  String? reason;

  String? actorType;

  String? jobId;

  String? jobState;

  /// `JobFailureCode.name` of the terminal job, e.g. `executionInterrupted`.
  String? jobFailureCode;

  String? jobFailureReason;

  /// The job's failure JSON exactly as stored, for the technical disclosure.
  String? jobFailureJson;

  /// Returns a shallow copy of this [WorkItemFailureView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  WorkItemFailureView copyWith({
    String? transitionId,
    DateTime? at,
    String? reason,
    String? actorType,
    String? jobId,
    String? jobState,
    String? jobFailureCode,
    String? jobFailureReason,
    String? jobFailureJson,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WorkItemFailureView',
      if (transitionId != null) 'transitionId': transitionId,
      if (at != null) 'at': at?.toJson(),
      if (reason != null) 'reason': reason,
      if (actorType != null) 'actorType': actorType,
      if (jobId != null) 'jobId': jobId,
      if (jobState != null) 'jobState': jobState,
      if (jobFailureCode != null) 'jobFailureCode': jobFailureCode,
      if (jobFailureReason != null) 'jobFailureReason': jobFailureReason,
      if (jobFailureJson != null) 'jobFailureJson': jobFailureJson,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'WorkItemFailureView',
      if (transitionId != null) 'transitionId': transitionId,
      if (at != null) 'at': at?.toJson(),
      if (reason != null) 'reason': reason,
      if (actorType != null) 'actorType': actorType,
      if (jobId != null) 'jobId': jobId,
      if (jobState != null) 'jobState': jobState,
      if (jobFailureCode != null) 'jobFailureCode': jobFailureCode,
      if (jobFailureReason != null) 'jobFailureReason': jobFailureReason,
      if (jobFailureJson != null) 'jobFailureJson': jobFailureJson,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WorkItemFailureViewImpl extends WorkItemFailureView {
  _WorkItemFailureViewImpl({
    String? transitionId,
    DateTime? at,
    String? reason,
    String? actorType,
    String? jobId,
    String? jobState,
    String? jobFailureCode,
    String? jobFailureReason,
    String? jobFailureJson,
  }) : super._(
         transitionId: transitionId,
         at: at,
         reason: reason,
         actorType: actorType,
         jobId: jobId,
         jobState: jobState,
         jobFailureCode: jobFailureCode,
         jobFailureReason: jobFailureReason,
         jobFailureJson: jobFailureJson,
       );

  /// Returns a shallow copy of this [WorkItemFailureView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  WorkItemFailureView copyWith({
    Object? transitionId = _Undefined,
    Object? at = _Undefined,
    Object? reason = _Undefined,
    Object? actorType = _Undefined,
    Object? jobId = _Undefined,
    Object? jobState = _Undefined,
    Object? jobFailureCode = _Undefined,
    Object? jobFailureReason = _Undefined,
    Object? jobFailureJson = _Undefined,
  }) {
    return WorkItemFailureView(
      transitionId: transitionId is String? ? transitionId : this.transitionId,
      at: at is DateTime? ? at : this.at,
      reason: reason is String? ? reason : this.reason,
      actorType: actorType is String? ? actorType : this.actorType,
      jobId: jobId is String? ? jobId : this.jobId,
      jobState: jobState is String? ? jobState : this.jobState,
      jobFailureCode: jobFailureCode is String?
          ? jobFailureCode
          : this.jobFailureCode,
      jobFailureReason: jobFailureReason is String?
          ? jobFailureReason
          : this.jobFailureReason,
      jobFailureJson: jobFailureJson is String?
          ? jobFailureJson
          : this.jobFailureJson,
    );
  }
}
