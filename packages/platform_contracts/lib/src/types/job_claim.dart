import 'package:meta/meta.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'job_claim.g.dart';

/// Durable claim/lease on a [Job]. Claiming is a compare-and-swap on the job's
/// version so two scheduler instances can never both win the same job, and the
/// lease expiry is what makes a crashed scheduler's claim recoverable. The
/// claim is separate from the job so reconciliation can distinguish "claimed
/// but never dispatched" from "dispatched but unfinished".
@JsonSerializable(explicitToJson: true, includeIfNull: false)
@immutable
class JobClaim extends Equatable {
  const JobClaim({
    required this.claimId,
    required this.jobId,
    required this.ownerId,
    required this.leasedUntil,
    required this.createdAt,
  });

  final String claimId;
  final String jobId;

  /// The scheduler instance that won the claim ("lease owner").
  final String ownerId;

  /// After this instant the claim is stale and may be reconciled.
  final DateTime leasedUntil;

  final DateTime createdAt;

  bool isExpiredAt(DateTime now) => leasedUntil.isBefore(now);

  factory JobClaim.fromJson(Map<String, dynamic> json) =>
      _$JobClaimFromJson(json);

  Map<String, dynamic> toJson() => _$JobClaimToJson(this);

  @override
  List<Object?> get props => [claimId, jobId, ownerId, leasedUntil, createdAt];
}
