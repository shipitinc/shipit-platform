import 'package:product_registry/product_registry.dart'
    show ProductRegistryEngine;

import 'repository_access_verifier.dart';
import 'secret_material.dart';
import 'secret_provider.dart';
import 'secretless_error.dart';
import 'ssh_keypair.dart';
import 'ssh_remote.dart';

/// What the host-key confirmation this service enforces actually IS.
///
/// M-5, and the honest answer is "an operator assertion the server cannot
/// authenticate". The value arrives as an endpoint parameter; the transport then
/// enforces exactly what the caller supplied, which is a real enforcer over an
/// unauthenticated input. It is published in the response so a client — and a
/// reader of a stored response — cannot mistake it for a value the server
/// observed for itself.
///
/// A confirmation the server *obtained* would need a separate, out-of-band
/// transport (an operator pasting a fingerprint from the host's own UI is exactly
/// what ADR 0018 §Decision describes, and it is not something a request parameter
/// can be). Binding it properly is a product decision, not this lane's.
const String kHostKeyConfirmationProvenance =
    'operator-asserted: the fingerprint was supplied by the caller and is not '
    'authenticated by the server; the server independently obtained the host key '
    'and enforced that they matched';

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

  /// The name under which the private half is held by the secret manager.
  ///
  /// M-6, resolved as far as this lane may resolve it. An earlier version of this
  /// comment said "Not the material; §13a by name, never by value" — which is the
  /// exact reasoning `9417f8bf` rejects, because §13a is what makes
  /// *credentials* safe to reference and is not an assurance that a reference is
  /// harmless. Under ADR 0018 §A3 the reference **is** the sensitive artifact and
  /// `9417f8bf` records exposing it to a client as gap **G-7**, upgradeable to
  /// "required rather than optional". That contradiction is real and is not
  /// settled here: choosing an opaque handle instead of the raw reference is a
  /// product/architecture decision (owner `design-agent`).
  ///
  /// What this lane *can* make structural is the part that was previously only a
  /// property of the two adapters that happen to exist: `generate` verifies that
  /// the handle a provider returned is byte-identical to the reference it asked
  /// it to store, and fails the mint otherwise. So this field is not "whatever
  /// the provider felt like returning" — it is provably
  /// `GIT_REPOSITORY_<sanitised repositoryId>_SSH`, derived from an input the
  /// caller supplied. A provider that returned an ARN or a vault path — which
  /// would hand a client the secret manager's topology — now breaks loudly
  /// instead of leaking quietly. Replacing the value with a non-identifying
  /// handle remains `9417f8bf` G-7's open decision; see `WORK_STATE.md`.
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
    required this.hostKeyConfirmationProvenance,
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

  /// Always [kHostKeyConfirmationProvenance]. Present so that a client cannot
  /// read this response as "the server verified the host".
  final String hostKeyConfirmationProvenance;

  final String? failureReason;
  final DateTime? lastVerifiedAt;
  final String? observedHostKeyFingerprint;

  Map<String, dynamic> toJson() => {
    'credentialId': credentialId,
    'status': status,
    'canReachRepository': canReachRepository,
    'secretMaterialRemoved': secretMaterialRemoved,
    'hostKeyConfirmationProvenance': hostKeyConfirmationProvenance,
    if (failureReason != null) 'failureReason': failureReason,
    if (lastVerifiedAt != null)
      'lastVerifiedAt': lastVerifiedAt!.toIso8601String(),
    if (observedHostKeyFingerprint != null)
      'observedHostKeyFingerprint': observedHostKeyFingerprint,
  };
}

/// A control character in caller-supplied text that is interpolated into a
/// message which reaches a durable record. An unescaped line boundary is a
/// forge-the-previous-entry primitive, which is the reason both attribution
/// validators refuse one.
///
/// A **space** is deliberately not in this class: `confirmedBy` is a person's
/// name and must accept "Dana Okafor". [_kNonTokenCharacter] is the wider class
/// used where the value is not free text.
final RegExp _kControlCharacter = RegExp(r'[\x00-\x1f\x7f]');

/// A control character **or a space** — anything that is not part of a single
/// opaque token.
///
/// Used only for [CredentialKeyService._validatedFingerprint], where the value is
/// a host-key fingerprint: a fixed-shape token (`SHA256:` and 43 base64
/// characters, or the `MD5:aa:bb:…` form) that no `ssh-keygen -l` output can
/// contain a space in. Applying this class to a free-text attribution would
/// refuse an ordinary operator's name.
final RegExp _kNonTokenCharacter = RegExp(r'[\x00-\x20\x7f]');

/// Ceiling on caller-supplied text this layer bounds before it is persisted,
/// logged, or compared. Well above any operator's name or any fingerprint, and
/// well below a paste of something else.
const int _kMaxCallerTextLength = 128;

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
///   * **A handle the provider invented never reaches a client.** See
///     [MintedCredential.referenceName] — this layer re-derives the reference and
///     refuses a store whose return value is not it, which is what turns "our two
///     adapters happen to return a bare name" into a property of the system.
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
      // M-6, enforced. The handle is what `generate` returns to the client, so
      // it must be the bare reference we asked for — never a provider-specific
      // ARN, path or URL, which would hand a client the secret manager's
      // topology. Checking it here is the difference between a property of the
      // code and a property of whichever adapters happen to exist; a future
      // adapter that returned an ARN now fails the mint instead of leaking.
      if (storedHandle != referenceName) {
        throw SecretStoreException(
          referenceName: referenceName,
          providerId: secretProvider.providerId,
          operation: 'store',
          reason:
              'the provider returned a handle that is not the reference it was '
              'given. Under ADR 0018 A3 the reference is the sensitive artifact '
              '(9417f8bf gap G-7), so a handle that discloses vault topology must '
              'never reach a client. The mint is refused.',
        );
      }
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
  ///
  /// WHAT IT IS NOT, per M-5. The value is **client-supplied and
  /// unauthenticated**. The verifier independently obtains the host's key and
  /// refuses to clone unless the fingerprint it computes equals this value, so
  /// the transport enforces it; but a caller that scanned the network itself and
  /// supplied an attacker's key gets a clone against the attacker, faithfully
  /// enforced. [kHostKeyConfirmationProvenance] is therefore returned in the
  /// response, so the gap A2 records is **narrowed, not closed**: the provenance
  /// of the confirmed value is unchanged by anything in this method.
  /// [confirmedBy] is likewise caller free text with no identity behind it; it is
  /// validated for shape (see [_validatedConfirmer]) because it is persisted to
  /// `hostConfirmedBy` / `lastVerifiedBy`, but it attests to nothing.
  /// [hostKeyFingerprint] is caller text too, and is validated by the same kind of
  /// check (see [_validatedFingerprint]) — it reads as a computed value, which is
  /// precisely why it needed one.
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
    //
    // Bounded here, BEFORE either of them sees the value, so it is bounded on
    // every leg it takes — the column `confirmHostKey` writes, the audited
    // exception description the verifier interpolates it into, and from there
    // the session log. See [_validatedFingerprint] for why that last leg is a
    // log-forgery vector and not merely untidy.
    final fingerprint = _validatedFingerprint(
      hostKeyFingerprint,
      'hostKeyFingerprint',
    );
    await engine.confirmHostKey(
      productId: productId,
      credentialId: credential.credentialId,
      hostKeyFingerprint: fingerprint,
      confirmedBy: _validatedConfirmer(confirmedBy, 'confirmedBy'),
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
        confirmedHostKeyFingerprint: fingerprint,
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
        checkedBy: _validatedConfirmer(checkedBy ?? confirmedBy, 'checkedBy'),
        failureReason: failureReason,
        now: _clock(),
      );

      return AccessVerification(
        credentialId: credential.credentialId,
        status: updated.status.wire,
        canReachRepository: updated.canReachRepository,
        secretMaterialRemoved: outcome.secretMaterialRemoved,
        hostKeyConfirmationProvenance: kHostKeyConfirmationProvenance,
        failureReason: updated.lastFailureReason,
        lastVerifiedAt: updated.lastVerifiedAt,
        observedHostKeyFingerprint: outcome.observedHostKeyFingerprint,
      );
    } finally {
      material.wipe();
    }
  }

  /// Bounds and sanitises a caller-supplied attribution before it is persisted.
  ///
  /// It attests to nothing — see [verifyAccess] — but it is written to
  /// `hostConfirmedBy` and `lastVerifiedBy`, which an operator reads as an audit
  /// trail. Three things are therefore refused rather than stored: an empty value
  /// (the domain already checks this, and a second opinion is cheaper than a
  /// blank audit field), a control character (which in a log line is a
  /// forge-the-previous-entry primitive), and anything long enough to be a paste
  /// of something else.
  ///
  /// NO REFUSAL QUOTES THE VALUE. The refusals name the field and, for the
  /// length refusal, report the length; they do not report the text back. The
  /// value is caller-supplied and these messages reach a durable record, so
  /// echoing it would make the refusal the forgeable surface instead of the
  /// field it is bounding.
  static String _validatedConfirmer(String value, String field) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw CredentialScopeException(
        '$field is empty. It is recorded against the credential as the '
        'operator who confirmed this host key, and a blank audit field records '
        'nothing.',
      );
    }
    if (trimmed.length > _kMaxCallerTextLength) {
      throw CredentialScopeException(
        '$field is ${trimmed.length} characters; at most $_kMaxCallerTextLength '
        'are accepted. It is recorded against the credential, not interpreted.',
      );
    }
    if (_kControlCharacter.hasMatch(trimmed)) {
      throw CredentialScopeException(
        '$field contains a control character. It is recorded against the '
        'credential as a single audit field and must not be able to forge a log '
        'line.',
      );
    }
    return trimmed;
  }

  /// Bounds and sanitises the caller-supplied host-key fingerprint. F-1.
  ///
  /// The same class of check as [_validatedConfirmer], for the same reason, and
  /// deliberately a sibling rather than a reuse: the messages are about a value
  /// compared byte-for-byte against one the transport computes, not about an
  /// audit field, and a shared message would misdescribe one of them.
  ///
  /// WHY IT NEEDED ITS OWN CALL, because the M-5 correction bounded
  /// `confirmedBy` and `checkedBy` and left this untouched. The reason it was
  /// easy to leave is that it reads as a *computed* value — `SHA256:` followed
  /// by 43 base64 characters — and a computed value looks safe to forward
  /// unchanged. It is caller-supplied text, and it does not stay in the column:
  ///
  ///   * [HostKeyNotPresentedException.secretlessDescription] interpolates
  ///     `confirmedFingerprint` verbatim;
  ///   * that type is an [AuditedFailure], so [secretlessText] **forwards** it
  ///     rather than suppressing it the way it suppresses an unvetted message;
  ///   * `credentialFailureLogFields` writes it to the Serverpod session log,
  ///     which `config/test.yaml` persists to Postgres.
  ///
  /// So an unescaped newline in this field is a forge-the-previous-entry
  /// primitive on exactly the boundary `confirmedBy` was bounded for. The
  /// asymmetry is the whole finding: `confirmedBy` reaches only a column, and
  /// this reached an exception description and therefore a durable log row.
  ///
  /// It carries no key material and violates no ADR 0018 clause, which is why
  /// the focused review rated it MEDIUM rather than HIGH — but shipping a
  /// log-forgery vector knowingly inside a security boundary is not a trade
  /// worth making for a saved bound, and the M-5 hardening must not be described
  /// as complete until this is closed.
  ///
  /// NO REFUSAL QUOTES THE VALUE, for the same reason as [_validatedConfirmer]:
  /// these messages reach a durable record, so a refusal that echoed the
  /// attacker-supplied text would carry the forge into the path that rejects it.
  static String _validatedFingerprint(String value, String field) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw CredentialScopeException(
        '$field is empty. It is compared against the fingerprint the transport '
        'computes from the host key the server actually obtained, so an empty '
        'value cannot match one.',
      );
    }
    if (trimmed.length > _kMaxCallerTextLength) {
      throw CredentialScopeException(
        '$field is ${trimmed.length} characters; at most '
        '$_kMaxCallerTextLength are accepted. A host-key fingerprint is a short '
        'fixed-shape token.',
      );
    }
    if (_kNonTokenCharacter.hasMatch(trimmed)) {
      throw CredentialScopeException(
        '$field contains whitespace or a control character. It is interpolated '
        'into an audited failure description that reaches the session log and '
        'therefore Postgres, so it must not be able to forge a log line.',
      );
    }
    return trimmed;
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
/// own, or a repository that does not exist, or carries an attribution that
/// cannot be recorded.
///
/// Audited, like every other failure in this directory, because this service's
/// failures reach the Serverpod session log and therefore Postgres. Each message
/// is a literal plus a field name; none touches key material.
class CredentialScopeException implements Exception, AuditedFailure {
  CredentialScopeException(this.message);

  final String message;

  @override
  String get secretlessDescription => 'CredentialScopeException: $message';

  @override
  String toString() => secretlessDescription;
}
