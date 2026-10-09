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

/// What one deploy-key mint produced, and the COMPLETE set of fields that may
/// leave the process for it (ADR 0018 §Decision, §A3).
///
/// **Carries no private material and has no field that could.** There is no
/// `SecretBytes`, no `ByteData`, no `Uint8List` here, and the type is the reason
/// rather than the consequence: `credentialEndpoints.generate` returns exactly
/// this class, so the shape of a leak is decided by the return type instead of
/// by which keys the caller remembered to omit.
///
/// WHY THIS IS A TYPED MODEL AND NOT A `Map<String, dynamic>`. The map return
/// type was the blocker behind "No deserialization found for type dynamic": the
/// generated client emits `callServerEndpoint<Map<String, dynamic>>`, and
/// `Protocol.deserialize<Map<String, dynamic>>` recurses into
/// `deserialize<dynamic>(v)`, for which the framework has no entry — so the
/// client threw before it could read a single field. Every working endpoint in
/// this server returns a typed model for exactly this reason.
///
/// WHY IT LIVES HERE AND NOT IN `lib/src/credentials/`. That directory is the
/// custody boundary and holds only Dart; Serverpod discovers a plain `.yaml`
/// model only under `lib/src/models/` or `lib/src/protocol/`
/// (`serverpod_cli` 3.4.13, `util/model_helper.dart` `isModelFile` /
/// `_modelRootSuffixes`), and every one of the server's 24 existing non-table
/// models is here. A schema file placed anywhere else would be silently ignored
/// by the generator.
abstract class MintedCredentialView
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  MintedCredentialView._({
    required this.credentialId,
    required this.productId,
    required this.repositoryId,
    required this.publicKey,
    required this.fingerprint,
    required this.algorithm,
    required this.referenceName,
    required this.status,
    required this.hostKeyStatus,
    this.host,
  });

  factory MintedCredentialView({
    required String credentialId,
    required String productId,
    required String repositoryId,
    required String publicKey,
    required String fingerprint,
    required String algorithm,
    required String referenceName,
    required String status,
    required String hostKeyStatus,
    String? host,
  }) = _MintedCredentialViewImpl;

  factory MintedCredentialView.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return MintedCredentialView(
      credentialId: jsonSerialization['credentialId'] as String,
      productId: jsonSerialization['productId'] as String,
      repositoryId: jsonSerialization['repositoryId'] as String,
      publicKey: jsonSerialization['publicKey'] as String,
      fingerprint: jsonSerialization['fingerprint'] as String,
      algorithm: jsonSerialization['algorithm'] as String,
      referenceName: jsonSerialization['referenceName'] as String,
      status: jsonSerialization['status'] as String,
      hostKeyStatus: jsonSerialization['hostKeyStatus'] as String,
      host: jsonSerialization['host'] as String?,
    );
  }

  String credentialId;

  String productId;

  String repositoryId;

  /// `ssh-ed25519 AAAA… shipit+<repositoryId>` — the authorized-keys line the
  /// operator installs on the repository. Public by definition, and the reason
  /// this call exists.
  String publicKey;

  /// `SHA256:…` over the public blob.
  String fingerprint;

  /// `ed25519`.
  String algorithm;

  /// The name the private half is held under by the secret manager.
  ///
  /// G-7 (open, product decision): under ADR 0018 §A3 this reference IS the
  /// sensitive artifact, and 9417f8bf records exposing it to a client as gap
  /// **G-7**, upgradeable to "required rather than optional". It is carried here
  /// because the client already reads it and narrowing the contract is that
  /// decision's job, not this correction's. `CredentialKeyService.generate`
  /// re-derives the reference and refuses a mint whose provider returned
  /// anything else, so this value is provably
  /// `GIT_REPOSITORY_<sanitised repositoryId>_SSH` — never a vault path or ARN.
  String referenceName;

  /// `generated` at mint. Never `verified`; see [verifyAccess] for the call
  /// that can change it.
  String status;

  /// `unknown` at mint: a new credential has an unrecognised host and cannot
  /// reach anything until a human confirms it.
  String hostKeyStatus;

  /// The repository remote. Public.
  String? host;

  /// Returns a shallow copy of this [MintedCredentialView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  MintedCredentialView copyWith({
    String? credentialId,
    String? productId,
    String? repositoryId,
    String? publicKey,
    String? fingerprint,
    String? algorithm,
    String? referenceName,
    String? status,
    String? hostKeyStatus,
    String? host,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'MintedCredentialView',
      'credentialId': credentialId,
      'productId': productId,
      'repositoryId': repositoryId,
      'publicKey': publicKey,
      'fingerprint': fingerprint,
      'algorithm': algorithm,
      'referenceName': referenceName,
      'status': status,
      'hostKeyStatus': hostKeyStatus,
      if (host != null) 'host': host,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'MintedCredentialView',
      'credentialId': credentialId,
      'productId': productId,
      'repositoryId': repositoryId,
      'publicKey': publicKey,
      'fingerprint': fingerprint,
      'algorithm': algorithm,
      'referenceName': referenceName,
      'status': status,
      'hostKeyStatus': hostKeyStatus,
      if (host != null) 'host': host,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _MintedCredentialViewImpl extends MintedCredentialView {
  _MintedCredentialViewImpl({
    required String credentialId,
    required String productId,
    required String repositoryId,
    required String publicKey,
    required String fingerprint,
    required String algorithm,
    required String referenceName,
    required String status,
    required String hostKeyStatus,
    String? host,
  }) : super._(
         credentialId: credentialId,
         productId: productId,
         repositoryId: repositoryId,
         publicKey: publicKey,
         fingerprint: fingerprint,
         algorithm: algorithm,
         referenceName: referenceName,
         status: status,
         hostKeyStatus: hostKeyStatus,
         host: host,
       );

  /// Returns a shallow copy of this [MintedCredentialView]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  MintedCredentialView copyWith({
    String? credentialId,
    String? productId,
    String? repositoryId,
    String? publicKey,
    String? fingerprint,
    String? algorithm,
    String? referenceName,
    String? status,
    String? hostKeyStatus,
    Object? host = _Undefined,
  }) {
    return MintedCredentialView(
      credentialId: credentialId ?? this.credentialId,
      productId: productId ?? this.productId,
      repositoryId: repositoryId ?? this.repositoryId,
      publicKey: publicKey ?? this.publicKey,
      fingerprint: fingerprint ?? this.fingerprint,
      algorithm: algorithm ?? this.algorithm,
      referenceName: referenceName ?? this.referenceName,
      status: status ?? this.status,
      hostKeyStatus: hostKeyStatus ?? this.hostKeyStatus,
      host: host is String? ? host : this.host,
    );
  }
}
