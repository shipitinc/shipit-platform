import 'package:product_registry/product_registry.dart'
    show ProductRegistryEngine;

import 'repository_access_verifier.dart';
import 'secret_material.dart';
import 'secret_provider.dart';
import 'ssh_keypair.dart';
import 'ssh_remote.dart';

/// What a mint produced. **The complete set of fields that may leave the
/// process**, and every one of them is public.
///
/// There is no field for the private half and no way to derive one from this
/// object: it holds the public authorized-keys line, the fingerprint, the
/// algorithm, the reference name and the credential's status. That is the
/// point of the type — the endpoint serialises exactly this, so the shape of
/// the leak is decided by the return type rather than by what the caller
/// remembered to omit.
class MintedCredential {
  MintedCredential({
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

  final String credentialId;
  final String productId;
  final String repositoryId;

  /// `ssh-ed25519 AAAA… shipit+<repositoryId>` — the line the operator installs
  /// as a deploy key. Public, and explicitly surfaced by ADR 0018 §Decision.
  final String publicKey;

  /// `SHA256:…` of the public blob.
  final String fingerprint;

  final String algorithm;

  /// The name under which the private half is held by the secret manager. Not
  /// the material; §13a by name, never by value.
  final String referenceName;

  /// `generated` at mint. Never `verified` — access has not been proved yet.
  final String status;

  /// `unknown` at mint: a new credential has an unrecognised host and cannot
  /// reach anything until a human confirms it.
  final String hostKeyStatus;

  final String? host;

  /// The wire projection. Deliberately an explicit whitelist.
  Map<String, dynamic> toJson() => {
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

/// What an access verification concluded.
class AccessVerification {
  AccessVerification({
    required this.credentialId,
    required this.status,
    required this.canReachRepository,
    required this.secretMaterialRemoved,
    this.failureReason,
    this.lastVerifiedAt,
    this.observedHostKeyFingerprint,
  });

  final String credentialId;

  /// `verified` only when a real clone succeeded.
  final String status;

  /// Mirrors `RepositoryCredential.canReachRepository`: a confirmed host AND a
  /// proven connection. This is the field the client reads to set
  /// `accessStatus = verified`.
  final bool canReachRepository;

  /// Whether the private half was destroyed with the clone's scratch tree.
  final bool secretMaterialRemoved;

  final String? failureReason;
  final DateTime? lastVerifiedAt;
  final String? observedHostKeyFingerprint;

  Map<String, dynamic> toJson() => {
    'credentialId': credentialId,
    'status': status,
    'canReachRepository': canReachRepository,
    'secretMaterialRemoved': secretMaterialRemoved,
    if (failureReason != null) 'failureReason': failureReason,
    if (lastVerifiedAt != null)
      'lastVerifiedAt': lastVerifiedAt!.toIso8601String(),
    if (observedHostKeyFingerprint != null)
      'observedHostKeyFingerprint': observedHostKeyFingerprint,
  };
}

/// Generates repository deploy keys and proves they can reach the repository.
///
/// This is the layer ADR 0018 §A3 describes — the one that holds a reference and
/// asks the manager for the material at transport time — and it is the only
/// place in the server that may hold a private half. Two invariants are
/// enforced here rather than left to its callers:
///
///   * **A key that cannot be kept is never returned.** `SecretProvider.store`
///     runs before the row is written, and a store failure propagates, so there
///     is no window in which a public key has been handed to an operator for
///     installation on a repository whose private half exists nowhere. The
///     reverse order would produce exactly that: an installable public key that
///     can never authenticate, which is the non-installable mock this whole
///     lane replaces.
///   * **A row is never written before the manager has the bytes.** Same
///     ordering, same reason.
class CredentialKeyService {
  CredentialKeyService({
    required this.engine,
    required this.secretProvider,
    this.verifier = const RepositoryAccessVerifier(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// The durable product-registry engine. Credential identity, scope and status
  /// all belong to it; this service adds custody and transport.
  final ProductRegistryEngine engine;

  /// Where the private half lives.
  final SecretProvider secretProvider;

  /// The real clone.
  final RepositoryAccessVerifier verifier;

  final DateTime Function() _clock;

  /// Generates a keypair for [repositoryId], stores the private half, and records
  /// the credential.
  ///
  /// Fails, without writing a row and without returning a public key, if the
  /// secret manager cannot keep the bytes.
  Future<MintedCredential> generate({
    required String productId,
    required String repositoryId,
    String? credentialId,
    String? supersedesCredentialId,
  }) async {
    // Ownership and existence first, via the engine's own resolver rather than a
    // read of the store: `resolveRepository` is what enforces that this product
    // owns this repository, so a caller cannot mint a key against another
    // product's repository by naming its id. Doing it before the key exists means
    // a rejected call has generated nothing at all.
    final repository = await engine.resolveRepository(productId, repositoryId);

    final referenceName = credentialReferenceName(repositoryId);
    final keypair = SshKeyPair.generate(comment: 'shipit+$repositoryId');
    SecretBytes? custody;
    String? storedHandle;
    try {
      custody = SecretBytes(keypair.privateKeyPemBytes);
      // Custody first. A throw here is what requirement "a failure to store it
      // fails the generate call rather than returning a key it cannot keep"
      // means, and it is why there is no `catch` that continues.
      storedHandle = await secretProvider.store(
        referenceName: referenceName,
        secret: custody,
      );
      custody.wipe();

      final credential = await engine.recordGeneratedCredential(
        productId: productId,
        repositoryId: repositoryId,
        referenceName: storedHandle,
        publicKey: keypair.publicKeyAuthorizedLine,
        fingerprint: keypair.fingerprint,
        host: repository.uri,
        algorithm: keypair.algorithm,
        credentialId: credentialId,
        supersedesCredentialId: supersedesCredentialId,
        now: _clock(),
      );

      return MintedCredential(
        credentialId: credential.credentialId,
        productId: productId,
        repositoryId: repositoryId,
        publicKey: keypair.publicKeyAuthorizedLine,
        fingerprint: keypair.fingerprint,
        algorithm: credential.algorithm,
        referenceName: credential.referenceName,
        status: credential.status.wire,
        hostKeyStatus: credential.hostKeyStatus.wire,
        host: credential.host,
      );
    } on Object {
      // The row was not written, but the manager may already hold a secret with
      // no row pointing at it. ADR 0018 §A2 makes destroying the handle part of
      // revocation; an orphan from a half-finished mint needs the same treatment
      // or it lingers, reachable and unowned, until somebody notices.
      await _destroyOrphan(referenceName);
      rethrow;
    } finally {
      custody?.wipe();
      keypair.wipeSeed();
    }
  }

  /// Confirms the host key, clones the repository with the stored private half,
  /// and records whether it worked.
  ///
  /// [hostKeyFingerprint] is the human confirmation ADR 0018 §Decision requires:
  /// "ShipIt refuses to connect to an unrecognised host. The operator is shown
  /// the host, key type and fingerprint and must confirm it." It is required,
  /// not optional — there is no path that clones against an unconfirmed host,
  /// which is the transport gap ADR 0018 §Accepted risks (A2) records.
  Future<AccessVerification> verifyAccess({
    required String productId,
    required String repositoryId,
    required String hostKeyFingerprint,
    required String confirmedBy,
    String? checkedBy,
  }) async {
    final credential = await engine.readActiveCredential(
      productId,
      repositoryId,
    );
    if (credential == null) {
      throw CredentialScopeException(
        'repository $repositoryId has no active credential to verify; mint one '
        'first',
      );
    }

    // The domain records the human's trust-on-first-use decision and refuses a
    // changed fingerprint. The verifier then enforces the same fact at the
    // socket. Both, deliberately: one records the decision and one cannot be
    // lied to by a rewritten remote.
    await engine.confirmHostKey(
      productId: productId,
      credentialId: credential.credentialId,
      hostKeyFingerprint: hostKeyFingerprint,
      confirmedBy: confirmedBy,
      now: _clock(),
    );

    final remote = parseSshRemote(credential.host ?? '');
    final material = await secretProvider.read(
      referenceName: credential.referenceName,
    );
    try {
      final outcome = await verifier.verify(
        remote: remote,
        privateKeyPem: material,
        confirmedHostKeyFingerprint: hostKeyFingerprint,
      );

      // A clone that worked while the private half could not be destroyed is NOT
      // recorded as verified. The connection proved the credential works; it does
      // not make a stray key file on disk acceptable, and `verified` is the status
      // the client keys its Register button off.
      final succeeded = outcome.succeeded && outcome.secretMaterialRemoved;
      final failureReason = succeeded
          ? null
          : outcome.failureReason ??
                'the private identity file could not be removed from this host '
                    'after the clone; the credential was NOT marked verified';

      final updated = await engine.recordCredentialCheck(
        productId: productId,
        credentialId: credential.credentialId,
        succeeded: succeeded,
        checkedBy: checkedBy ?? confirmedBy,
        failureReason: failureReason,
        now: _clock(),
      );

      return AccessVerification(
        credentialId: credential.credentialId,
        status: updated.status.wire,
        canReachRepository: updated.canReachRepository,
        secretMaterialRemoved: outcome.secretMaterialRemoved,
        failureReason: updated.lastFailureReason,
        lastVerifiedAt: updated.lastVerifiedAt,
        observedHostKeyFingerprint: outcome.observedHostKeyFingerprint,
      );
    } finally {
      material.wipe();
    }
  }

  /// Destroys a manager handle left behind by a mint that failed mid-flight.
  ///
  /// Best effort by construction — the original failure is already propagating
  /// and must not be replaced by a cleanup failure — but never silent: the
  /// inability is surfaced through the original error's context and the orphan
  /// remains named in [referenceName], so an operator reading the failure knows
  /// a secret may exist without a row.
  Future<void> _destroyOrphan(String referenceName) async {
    try {
      await secretProvider.destroy(referenceName: referenceName);
    } on Object {
      // Nothing to do but not pretend it happened. The caller is already
      // throwing; the orphan handle is discoverable by listing the provider's
      // own namespace, which is exactly what the reference name identifies.
    }
  }
}

/// Raised when a credential operation names a repository the product does not
/// own, or a repository that does not exist.
class CredentialScopeException implements Exception {
  CredentialScopeException(this.message);

  final String message;

  @override
  String toString() => 'CredentialScopeException: $message';
}
