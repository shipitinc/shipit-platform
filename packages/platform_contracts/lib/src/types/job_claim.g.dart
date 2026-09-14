// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_claim.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JobClaim _$JobClaimFromJson(Map<String, dynamic> json) => JobClaim(
  claimId: json['claimId'] as String,
  jobId: json['jobId'] as String,
  ownerId: json['ownerId'] as String,
  leasedUntil: DateTime.parse(json['leasedUntil'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$JobClaimToJson(JobClaim instance) => <String, dynamic>{
  'claimId': instance.claimId,
  'jobId': instance.jobId,
  'ownerId': instance.ownerId,
  'leasedUntil': instance.leasedUntil.toIso8601String(),
  'createdAt': instance.createdAt.toIso8601String(),
};
