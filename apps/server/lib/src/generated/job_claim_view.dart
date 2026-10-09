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

/// The lease a worker holds on a job.
abstract class JobClaimView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  JobClaimView._({
    required this.claimId,
    required this.jobId,
    required this.ownerId,
    required this.leasedUntil,
    required this.createdAt,
  });

  factory JobClaimView({
    required String claimId,
    required String jobId,
    required String ownerId,
    required DateTime leasedUntil,
    required DateTime createdAt,
  }) = _JobClaimViewImpl;

  factory JobClaimView.fromJson(Map<String, dynamic> jsonSerialization) {
    return JobClaimView(
      claimId: jsonSerialization['claimId'] as String,
      jobId: jsonSerialization['jobId'] as String,
      ownerId: jsonSerialization['ownerId'] as String,
      leasedUntil: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['leasedUntil'],
      ),
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  String claimId;

  String jobId;

  String ownerId;

  DateTime leasedUntil;

  DateTime createdAt;

  /// Returns a shallow copy of this [JobClaimView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  JobClaimView copyWith({
    String? claimId,
    String? jobId,
    String? ownerId,
    DateTime? leasedUntil,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'JobClaimView',
      'claimId': claimId,
      'jobId': jobId,
      'ownerId': ownerId,
      'leasedUntil': leasedUntil.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'JobClaimView',
      'claimId': claimId,
      'jobId': jobId,
      'ownerId': ownerId,
      'leasedUntil': leasedUntil.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _JobClaimViewImpl extends JobClaimView {
  _JobClaimViewImpl({
    required String claimId,
    required String jobId,
    required String ownerId,
    required DateTime leasedUntil,
    required DateTime createdAt,
  }) : super._(
         claimId: claimId,
         jobId: jobId,
         ownerId: ownerId,
         leasedUntil: leasedUntil,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [JobClaimView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  JobClaimView copyWith({
    String? claimId,
    String? jobId,
    String? ownerId,
    DateTime? leasedUntil,
    DateTime? createdAt,
  }) {
    return JobClaimView(
      claimId: claimId ?? this.claimId,
      jobId: jobId ?? this.jobId,
      ownerId: ownerId ?? this.ownerId,
      leasedUntil: leasedUntil ?? this.leasedUntil,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
