// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repository_credential.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RepositoryCredential _$RepositoryCredentialFromJson(
  Map<String, dynamic> json,
) => RepositoryCredential(
  credentialId: json['credentialId'] as String,
  productId: json['productId'] as String,
  repositoryId: json['repositoryId'] as String,
  referenceName: json['referenceName'] as String,
  publicKey: json['publicKey'] as String,
  fingerprint: json['fingerprint'] as String,
  algorithm: json['algorithm'] as String? ?? 'ed25519',
  status: json['status'] == null
      ? CredentialStatus.generated
      : _statusFromWire(json['status'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  lastVerifiedAt: json['lastVerifiedAt'] == null
      ? null
      : DateTime.parse(json['lastVerifiedAt'] as String),
  lastVerifiedBy: json['lastVerifiedBy'] as String?,
  lastFailureReason: json['lastFailureReason'] as String?,
  hostKeyStatus: json['hostKeyStatus'] == null
      ? HostKeyStatus.unknown
      : _hostFromWire(json['hostKeyStatus'] as String),
  host: json['host'] as String?,
  hostKeyFingerprint: json['hostKeyFingerprint'] as String?,
  hostConfirmedAt: json['hostConfirmedAt'] == null
      ? null
      : DateTime.parse(json['hostConfirmedAt'] as String),
  hostConfirmedBy: json['hostConfirmedBy'] as String?,
  revokedAt: json['revokedAt'] == null
      ? null
      : DateTime.parse(json['revokedAt'] as String),
  revokedReason: json['revokedReason'] as String?,
  supersedesCredentialId: json['supersedesCredentialId'] as String?,
  version: (json['version'] as num?)?.toInt() ?? 1,
);

Map<String, dynamic> _$RepositoryCredentialToJson(
  RepositoryCredential instance,
) => <String, dynamic>{
  'credentialId': instance.credentialId,
  'productId': instance.productId,
  'repositoryId': instance.repositoryId,
  'referenceName': instance.referenceName,
  'publicKey': instance.publicKey,
  'fingerprint': instance.fingerprint,
  'algorithm': instance.algorithm,
  'status': _statusToWire(instance.status),
  'createdAt': instance.createdAt.toIso8601String(),
  'lastVerifiedAt': ?instance.lastVerifiedAt?.toIso8601String(),
  'lastVerifiedBy': ?instance.lastVerifiedBy,
  'lastFailureReason': ?instance.lastFailureReason,
  'hostKeyStatus': _hostToWire(instance.hostKeyStatus),
  'host': ?instance.host,
  'hostKeyFingerprint': ?instance.hostKeyFingerprint,
  'hostConfirmedAt': ?instance.hostConfirmedAt?.toIso8601String(),
  'hostConfirmedBy': ?instance.hostConfirmedBy,
  'revokedAt': ?instance.revokedAt?.toIso8601String(),
  'revokedReason': ?instance.revokedReason,
  'supersedesCredentialId': ?instance.supersedesCredentialId,
  'version': instance.version,
};
