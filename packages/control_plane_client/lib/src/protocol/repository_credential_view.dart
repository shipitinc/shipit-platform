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

/// The SSH credential for exactly one repository (ADR 0018 A1).
///
/// Carries NO key material. The private half lives in the operator's local
/// secret store and is named only by `referenceName`; the public half and
/// fingerprint are safe to display.
abstract class RepositoryCredentialView implements _i1.SerializableModel {
  RepositoryCredentialView._({
    required this.credentialId,
    required this.repositoryId,
    required this.referenceName,
    required this.fingerprint,
    required this.algorithm,
    required this.status,
    required this.hostKeyStatus,
    this.host,
    required this.canReachRepository,
    this.lastVerifiedAt,
    this.lastVerifiedBy,
    this.lastFailureReason,
    this.hostConfirmedAt,
    this.hostConfirmedBy,
  });

  factory RepositoryCredentialView({
    required String credentialId,
    required String repositoryId,
    required String referenceName,
    required String fingerprint,
    required String algorithm,
    required String status,
    required String hostKeyStatus,
    String? host,
    required bool canReachRepository,
    DateTime? lastVerifiedAt,
    String? lastVerifiedBy,
    String? lastFailureReason,
    DateTime? hostConfirmedAt,
    String? hostConfirmedBy,
  }) = _RepositoryCredentialViewImpl;

  factory RepositoryCredentialView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return RepositoryCredentialView(
      credentialId: jsonSerialization['credentialId'] as String,
      repositoryId: jsonSerialization['repositoryId'] as String,
      referenceName: jsonSerialization['referenceName'] as String,
      fingerprint: jsonSerialization['fingerprint'] as String,
      algorithm: jsonSerialization['algorithm'] as String,
      status: jsonSerialization['status'] as String,
      hostKeyStatus: jsonSerialization['hostKeyStatus'] as String,
      host: jsonSerialization['host'] as String?,
      canReachRepository: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['canReachRepository'],
      ),
      lastVerifiedAt: jsonSerialization['lastVerifiedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastVerifiedAt'],
            ),
      lastVerifiedBy: jsonSerialization['lastVerifiedBy'] as String?,
      lastFailureReason: jsonSerialization['lastFailureReason'] as String?,
      hostConfirmedAt: jsonSerialization['hostConfirmedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['hostConfirmedAt'],
            ),
      hostConfirmedBy: jsonSerialization['hostConfirmedBy'] as String?,
    );
  }

  String credentialId;

  String repositoryId;

  /// Name under which the private half is held locally. Never the value.
  String referenceName;

  String fingerprint;

  String algorithm;

  /// generated | verified | failing | revoked. There is no "assumed working".
  String status;

  /// unknown | confirmed | changed. `changed` fails closed.
  String hostKeyStatus;

  String? host;

  /// True only when the host is confirmed AND a real connection succeeded.
  bool canReachRepository;

  DateTime? lastVerifiedAt;

  String? lastVerifiedBy;

  String? lastFailureReason;

  DateTime? hostConfirmedAt;

  String? hostConfirmedBy;

  /// Returns a shallow copy of this [RepositoryCredentialView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  RepositoryCredentialView copyWith({
    String? credentialId,
    String? repositoryId,
    String? referenceName,
    String? fingerprint,
    String? algorithm,
    String? status,
    String? hostKeyStatus,
    String? host,
    bool? canReachRepository,
    DateTime? lastVerifiedAt,
    String? lastVerifiedBy,
    String? lastFailureReason,
    DateTime? hostConfirmedAt,
    String? hostConfirmedBy,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RepositoryCredentialView',
      'credentialId': credentialId,
      'repositoryId': repositoryId,
      'referenceName': referenceName,
      'fingerprint': fingerprint,
      'algorithm': algorithm,
      'status': status,
      'hostKeyStatus': hostKeyStatus,
      if (host != null) 'host': host,
      'canReachRepository': canReachRepository,
      if (lastVerifiedAt != null) 'lastVerifiedAt': lastVerifiedAt?.toJson(),
      if (lastVerifiedBy != null) 'lastVerifiedBy': lastVerifiedBy,
      if (lastFailureReason != null) 'lastFailureReason': lastFailureReason,
      if (hostConfirmedAt != null) 'hostConfirmedAt': hostConfirmedAt?.toJson(),
      if (hostConfirmedBy != null) 'hostConfirmedBy': hostConfirmedBy,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _RepositoryCredentialViewImpl extends RepositoryCredentialView {
  _RepositoryCredentialViewImpl({
    required String credentialId,
    required String repositoryId,
    required String referenceName,
    required String fingerprint,
    required String algorithm,
    required String status,
    required String hostKeyStatus,
    String? host,
    required bool canReachRepository,
    DateTime? lastVerifiedAt,
    String? lastVerifiedBy,
    String? lastFailureReason,
    DateTime? hostConfirmedAt,
    String? hostConfirmedBy,
  }) : super._(
         credentialId: credentialId,
         repositoryId: repositoryId,
         referenceName: referenceName,
         fingerprint: fingerprint,
         algorithm: algorithm,
         status: status,
         hostKeyStatus: hostKeyStatus,
         host: host,
         canReachRepository: canReachRepository,
         lastVerifiedAt: lastVerifiedAt,
         lastVerifiedBy: lastVerifiedBy,
         lastFailureReason: lastFailureReason,
         hostConfirmedAt: hostConfirmedAt,
         hostConfirmedBy: hostConfirmedBy,
       );

  /// Returns a shallow copy of this [RepositoryCredentialView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  RepositoryCredentialView copyWith({
    String? credentialId,
    String? repositoryId,
    String? referenceName,
    String? fingerprint,
    String? algorithm,
    String? status,
    String? hostKeyStatus,
    Object? host = _Undefined,
    bool? canReachRepository,
    Object? lastVerifiedAt = _Undefined,
    Object? lastVerifiedBy = _Undefined,
    Object? lastFailureReason = _Undefined,
    Object? hostConfirmedAt = _Undefined,
    Object? hostConfirmedBy = _Undefined,
  }) {
    return RepositoryCredentialView(
      credentialId: credentialId ?? this.credentialId,
      repositoryId: repositoryId ?? this.repositoryId,
      referenceName: referenceName ?? this.referenceName,
      fingerprint: fingerprint ?? this.fingerprint,
      algorithm: algorithm ?? this.algorithm,
      status: status ?? this.status,
      hostKeyStatus: hostKeyStatus ?? this.hostKeyStatus,
      host: host is String? ? host : this.host,
      canReachRepository: canReachRepository ?? this.canReachRepository,
      lastVerifiedAt: lastVerifiedAt is DateTime?
          ? lastVerifiedAt
          : this.lastVerifiedAt,
      lastVerifiedBy: lastVerifiedBy is String?
          ? lastVerifiedBy
          : this.lastVerifiedBy,
      lastFailureReason: lastFailureReason is String?
          ? lastFailureReason
          : this.lastFailureReason,
      hostConfirmedAt: hostConfirmedAt is DateTime?
          ? hostConfirmedAt
          : this.hostConfirmedAt,
      hostConfirmedBy: hostConfirmedBy is String?
          ? hostConfirmedBy
          : this.hostConfirmedBy,
    );
  }
}
