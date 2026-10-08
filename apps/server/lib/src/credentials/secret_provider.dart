import 'secret_material.dart';

/// Raised when no secret provider is selected, or the selection is not one this
/// build knows how to construct.
///
/// THIS IS THE FAIL-CLOSED PATH, and its existence is the enforcement of
/// ADR 0018 §Decision:
///
/// > The local secret store (A1) and host keychain (A4) remain the documented
/// > **fallback** when no secret manager is reachable in the target topology.
/// > **Fallback selection is a recorded precondition, not a silent default.**
///
/// A resolver that picked the local store when `SHIPIT_SECRET_PROVIDER` was
/// unset would make the fallback the default — exactly what that clause
/// forbids — and the QA stack would quietly run with a weaker custody guarantee
/// than the ADR describes, with nothing in the logs to say so. So the resolver
/// has no default branch at all: unset, blank and unrecognised all throw here.
class SecretProviderNotConfiguredException implements Exception {
  SecretProviderNotConfiguredException(this.message);

  /// Explains what is missing and what the accepted values are.
  ///
  /// Names configuration variables and provider ids only. Never a secret, and
  /// never a secret's value: this string is safe to log and is expected to
  /// appear in startup failures.
  final String message;

  @override
  String toString() => 'SecretProviderNotConfiguredException: $message';
}

/// Raised when a provider cannot store or return material.
///
/// Carries the [referenceName] and the provider's own account of the failure —
/// never the material itself. Every adapter in this directory constructs these
/// messages by hand for that reason; a generic `catch (e) => SecretStoreException('$e')`
/// over a `byte[]`-bearing exception would put key bytes in an operator-visible
/// string, which is the durable-record prohibition by another route.
class SecretStoreException implements Exception {
  SecretStoreException({
    required this.referenceName,
    required this.providerId,
    required this.operation,
    required this.reason,
  });

  /// The reference being acted on — the name, per ADR 0018 §13a.
  final String referenceName;

  /// Which adapter failed.
  final String providerId;

  /// `store`, `read` or `destroy`.
  final String operation;

  /// Human-readable cause, with any material redacted by the adapter.
  final String reason;

  @override
  String toString() =>
      'SecretStoreException(provider: $providerId, operation: $operation, '
      'reference: $referenceName, reason: $reason)';
}

/// Custody of the private half. SHIP IT stores a reference; the bytes live here
/// (ADR 0018 §A3).
///
/// The interface is deliberately shaped so that the two halves cannot be
/// confused: [store] is the only method that takes material and [read] is the
/// only method that returns it, neither ever appears in a result type that is
/// serialised, and every method names a `referenceName` rather than a value.
abstract interface class SecretProvider {
  /// Stable identifier recorded in logs and in the credential's
  /// [referenceName] conventions. One of [kGcpSecretManagerProviderId],
  /// [kLocalFileProviderId].
  String get providerId;

  /// Whether this adapter is one of the ADR's documented FALLBACK substrates.
  ///
  /// Read by the resolver's startup log. When true, the selection is logged as
  /// a precondition being met rather than as a normal configuration, because
  /// selecting it changes what ADR 0018's custody guarantee means for the
  /// deployment.
  bool get isDocumentedFallback;

  /// A description of the substrate that is safe to log: no credentials, no
  /// tokens, no paths that would disclose a filesystem layout beyond what the
  /// operator configured.
  Map<String, String> describe();

  /// Places [secret] under [referenceName] and returns the handle to read it
  /// back by.
  ///
  /// [referenceName] is validated as a bare identifier — no separators, no
  /// traversal — because it becomes a path (local adapter) or a secret id (GCP
  /// adapter). A reference that escaped its namespace would be a reference to
  /// somebody else's secret.
  ///
  /// Implementations MUST NOT log [secret] or interpolate it into [reason]
  /// fields of any exception they throw.
  Future<String> store({
    required String referenceName,
    required SecretBytes secret,
  });

  /// Returns the material for [referenceName].
  ///
  /// Called at transport time and nowhere else (ADR 0018 §A3: "asks the manager
  /// for the material at transport time"). The caller owns the returned value
  /// and is responsible for wiping it when the transport is done — see
  /// [SecretBytes.wipe].
  Future<SecretBytes> read({required String referenceName});

  /// Destroys the manager's handle for [referenceName].
  ///
  /// ADR 0018 §A2 makes revocation two-sided: removing the deploy key at the
  /// host is the operator's act and is not sufficient on its own, because
  /// SHIP IT is a participant in custody. Destroying the handle releases the
  /// material at revocation rather than leaving it reachable until someone
  /// remembers to uninstall it at the host.
  ///
  /// Idempotent: destroying an absent reference succeeds.
  Future<void> destroy({required String referenceName});
}

/// Provider id for the GCP Secret Manager adapter (production/staging).
const String kGcpSecretManagerProviderId = 'gcp_secret_manager';

/// Provider id for the local file-store fallback (ADR 0018 §A1 / §A4).
const String kLocalFileProviderId = 'local_file';

/// Every provider id this build can construct. Used in the fail-closed message
/// so an operator is told what to set rather than left guessing.
const List<String> kKnownProviderIds = [
  kGcpSecretManagerProviderId,
  kLocalFileProviderId,
];

/// Rejects a reference name that is not a bare identifier.
///
/// The rules are `[A-Za-z0-9._-]` only, no leading dot, and a length bound.
/// That admits ADR 0018's own example shape (`GIT_PRODUCT_<ref>_<repo>_SSH`)
/// while making it impossible for a reference to contain `/`, `\`, `..`, or a
/// NUL — so the same validator is correct for the local adapter's filename and
/// the GCP adapter's secret id without either one re-implementing the check.
///
/// Called by every adapter rather than by the resolver, because the resolver
/// does not own the storage: a future adapter with different constraints still
/// gets this check for free.
void validateReferenceName(String referenceName) {
  if (referenceName.isEmpty) {
    throw ArgumentError.value(referenceName, 'referenceName', 'is empty');
  }
  if (referenceName.length > 255) {
    throw ArgumentError.value(
      referenceName,
      'referenceName',
      'is longer than 255 characters',
    );
  }
  final allowed = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');
  if (!allowed.hasMatch(referenceName)) {
    throw ArgumentError.value(
      referenceName,
      'referenceName',
      'must match $allowed — a reference is a bare name, never a path',
    );
  }
}

/// The reference name ADR 0018 §A1 prescribes for one repository's deploy key.
///
/// A1 moved scope from the product to the repository, so the name is built from
/// the repository alone; `productId` is kept in the row for the ownership check
/// and is deliberately NOT part of the name, because a credential's identity is
/// its repository's.
///
/// The repository id is sanitised rather than rejected, so an id that already
/// contains a `/` or `:` still produces a valid reference instead of failing
/// the mint — and the substitution is visible in the persisted value, so the
/// mapping is auditable rather than lossy.
String credentialReferenceName(String repositoryId) {
  final sanitised = repositoryId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final name = 'GIT_REPOSITORY_${sanitised}_SSH';
  validateReferenceName(name);
  return name;
}
