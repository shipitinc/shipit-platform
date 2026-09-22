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

/// A queued or running job as shown in the Overview "Machines and next steps"
/// strip (Penpot: `Job Id` / `Job State` / `Job Desc`).
///
/// Read-only projection of the durable job record. The operator surface never
/// mutates jobs.
abstract class JobSummaryView implements _i1.SerializableModel {
  JobSummaryView._({
    required this.jobId,
    required this.workItemId,
    required this.state,
    required this.jobType,
    required this.createdAt,
    this.availableAt,
    required this.blockedOnDecision,
    required this.attempt,
    required this.maxAttempts,
  });

  factory JobSummaryView({
    required String jobId,
    required String workItemId,
    required String state,
    required String jobType,
    required DateTime createdAt,
    DateTime? availableAt,
    required bool blockedOnDecision,
    required int attempt,
    required int maxAttempts,
  }) = _JobSummaryViewImpl;

  factory JobSummaryView.fromJson(Map<String, dynamic> jsonSerialization) {
    return JobSummaryView(
      jobId: jsonSerialization['jobId'] as String,
      workItemId: jsonSerialization['workItemId'] as String,
      state: jsonSerialization['state'] as String,
      jobType: jsonSerialization['jobType'] as String,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      availableAt: jsonSerialization['availableAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['availableAt'],
            ),
      blockedOnDecision: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['blockedOnDecision'],
      ),
      attempt: jsonSerialization['attempt'] as int,
      maxAttempts: jsonSerialization['maxAttempts'] as int,
    );
  }

  String jobId;

  String workItemId;

  /// Durable `JobState` wire value. The UI maps this to plain language and
  /// only shows the raw value under "Show technical details".
  String state;

  /// Durable `JobType` wire value.
  String jobType;

  DateTime createdAt;

  /// Set when the job is not yet eligible to run (retry backoff).
  DateTime? availableAt;

  /// True when this job cannot proceed because a human decision is pending on
  /// its work item. Renders as "needs your approval first".
  bool blockedOnDecision;

  int attempt;

  int maxAttempts;

  /// Returns a shallow copy of this [JobSummaryView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  JobSummaryView copyWith({
    String? jobId,
    String? workItemId,
    String? state,
    String? jobType,
    DateTime? createdAt,
    DateTime? availableAt,
    bool? blockedOnDecision,
    int? attempt,
    int? maxAttempts,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'JobSummaryView',
      'jobId': jobId,
      'workItemId': workItemId,
      'state': state,
      'jobType': jobType,
      'createdAt': createdAt.toJson(),
      if (availableAt != null) 'availableAt': availableAt?.toJson(),
      'blockedOnDecision': blockedOnDecision,
      'attempt': attempt,
      'maxAttempts': maxAttempts,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _JobSummaryViewImpl extends JobSummaryView {
  _JobSummaryViewImpl({
    required String jobId,
    required String workItemId,
    required String state,
    required String jobType,
    required DateTime createdAt,
    DateTime? availableAt,
    required bool blockedOnDecision,
    required int attempt,
    required int maxAttempts,
  }) : super._(
         jobId: jobId,
         workItemId: workItemId,
         state: state,
         jobType: jobType,
         createdAt: createdAt,
         availableAt: availableAt,
         blockedOnDecision: blockedOnDecision,
         attempt: attempt,
         maxAttempts: maxAttempts,
       );

  /// Returns a shallow copy of this [JobSummaryView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  JobSummaryView copyWith({
    String? jobId,
    String? workItemId,
    String? state,
    String? jobType,
    DateTime? createdAt,
    Object? availableAt = _Undefined,
    bool? blockedOnDecision,
    int? attempt,
    int? maxAttempts,
  }) {
    return JobSummaryView(
      jobId: jobId ?? this.jobId,
      workItemId: workItemId ?? this.workItemId,
      state: state ?? this.state,
      jobType: jobType ?? this.jobType,
      createdAt: createdAt ?? this.createdAt,
      availableAt: availableAt is DateTime? ? availableAt : this.availableAt,
      blockedOnDecision: blockedOnDecision ?? this.blockedOnDecision,
      attempt: attempt ?? this.attempt,
      maxAttempts: maxAttempts ?? this.maxAttempts,
    );
  }
}
