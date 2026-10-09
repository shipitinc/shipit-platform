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

/// What an access verification concluded (ADR 0018 §A3, §Accepted risks A2).
///
/// **Carries no private material and has no field that could.** Same reasoning
/// as `MintedCredentialView`: the return type is the whitelist.
abstract class CredentialAccessVerificationView
    implements _i1.SerializableModel {
  CredentialAccessVerificationView._({
    required this.credentialId,
    required this.status,
    required this.canReachRepository,
    required this.secretMaterialRemoved,
    required this.hostKeyConfirmationProvenance,
    this.failureReason,
    this.lastVerifiedAt,
    this.observedHostKeyFingerprint,
  });

  factory CredentialAccessVerificationView({
    required String credentialId,
    required String status,
    required bool canReachRepository,
    required bool secretMaterialRemoved,
    required String hostKeyConfirmationProvenance,
    String? failureReason,
    DateTime? lastVerifiedAt,
    String? observedHostKeyFingerprint,
  }) = _CredentialAccessVerificationViewImpl;

  factory CredentialAccessVerificationView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return CredentialAccessVerificationView(
      credentialId: jsonSerialization['credentialId'] as String,
      status: jsonSerialization['status'] as String,
      canReachRepository: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['canReachRepository'],
      ),
      secretMaterialRemoved: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['secretMaterialRemoved'],
      ),
      hostKeyConfirmationProvenance:
          jsonSerialization['hostKeyConfirmationProvenance'] as String,
      failureReason: jsonSerialization['failureReason'] as String?,
      lastVerifiedAt: jsonSerialization['lastVerifiedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastVerifiedAt'],
            ),
      observedHostKeyFingerprint:
          jsonSerialization['observedHostKeyFingerprint'] as String?,
    );
  }

  String credentialId;

  /// `verified` only when a real `git clone` actually completed and the private
  /// identity file was destroyed with the scratch tree.
  String status;

  /// True only when the host key is confirmed AND the connection succeeded.
  /// This is the field the client reads to set `accessStatus = verified`.
  bool canReachRepository;

  /// Whether the private half was destroyed with the clone's scratch tree.
  bool secretMaterialRemoved;

  /// Always `operator-asserted: …`. Present so no client and no reader of a
  /// stored response can mistake the host-key confirmation for something the
  /// server authenticated (M-5, narrowed not closed — the fingerprint is caller
  /// text and the server only enforces that it matches the host key the server
  /// itself obtained).
  String hostKeyConfirmationProvenance;

  /// Present only when verification failed. A failure reason is a `String` from
  /// an audited failure type; it never carries key material.
  String? failureReason;

  /// Server clock at the successful check. Nullable because it is absent on a
  /// failure.
  DateTime? lastVerifiedAt;

  /// The host-key fingerprint the transport actually observed and enforced,
  /// when there was one.
  String? observedHostKeyFingerprint;

  /// Returns a shallow copy of this [CredentialAccessVerificationView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  CredentialAccessVerificationView copyWith({
    String? credentialId,
    String? status,
    bool? canReachRepository,
    bool? secretMaterialRemoved,
    String? hostKeyConfirmationProvenance,
    String? failureReason,
    DateTime? lastVerifiedAt,
    String? observedHostKeyFingerprint,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CredentialAccessVerificationView',
      'credentialId': credentialId,
      'status': status,
      'canReachRepository': canReachRepository,
      'secretMaterialRemoved': secretMaterialRemoved,
      'hostKeyConfirmationProvenance': hostKeyConfirmationProvenance,
      if (failureReason != null) 'failureReason': failureReason,
      if (lastVerifiedAt != null) 'lastVerifiedAt': lastVerifiedAt?.toJson(),
      if (observedHostKeyFingerprint != null)
        'observedHostKeyFingerprint': observedHostKeyFingerprint,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CredentialAccessVerificationViewImpl
    extends CredentialAccessVerificationView {
  _CredentialAccessVerificationViewImpl({
    required String credentialId,
    required String status,
    required bool canReachRepository,
    required bool secretMaterialRemoved,
    required String hostKeyConfirmationProvenance,
    String? failureReason,
    DateTime? lastVerifiedAt,
    String? observedHostKeyFingerprint,
  }) : super._(
         credentialId: credentialId,
         status: status,
         canReachRepository: canReachRepository,
         secretMaterialRemoved: secretMaterialRemoved,
         hostKeyConfirmationProvenance: hostKeyConfirmationProvenance,
         failureReason: failureReason,
         lastVerifiedAt: lastVerifiedAt,
         observedHostKeyFingerprint: observedHostKeyFingerprint,
       );

  /// Returns a shallow copy of this [CredentialAccessVerificationView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  CredentialAccessVerificationView copyWith({
    String? credentialId,
    String? status,
    bool? canReachRepository,
    bool? secretMaterialRemoved,
    String? hostKeyConfirmationProvenance,
    Object? failureReason = _Undefined,
    Object? lastVerifiedAt = _Undefined,
    Object? observedHostKeyFingerprint = _Undefined,
  }) {
    return CredentialAccessVerificationView(
      credentialId: credentialId ?? this.credentialId,
      status: status ?? this.status,
      canReachRepository: canReachRepository ?? this.canReachRepository,
      secretMaterialRemoved:
          secretMaterialRemoved ?? this.secretMaterialRemoved,
      hostKeyConfirmationProvenance:
          hostKeyConfirmationProvenance ?? this.hostKeyConfirmationProvenance,
      failureReason: failureReason is String?
          ? failureReason
          : this.failureReason,
      lastVerifiedAt: lastVerifiedAt is DateTime?
          ? lastVerifiedAt
          : this.lastVerifiedAt,
      observedHostKeyFingerprint: observedHostKeyFingerprint is String?
          ? observedHostKeyFingerprint
          : this.observedHostKeyFingerprint,
    );
  }
}
