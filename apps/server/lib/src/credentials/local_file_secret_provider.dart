import 'dart:io';

import 'posix_file_permissions.dart';
import 'secret_material.dart';
import 'secret_provider.dart';

/// The ADR 0018 §A1 / §A4 fallback substrate: one owner-only file per reference
/// under a configured directory.
///
/// WHY THIS EXISTS AND WHY IT IS NOT THE DEFAULT. ADR 0018 §Decision is explicit:
///
/// > The local secret store (A1) and host keychain (A4) remain the documented
/// > **fallback** when no secret manager is reachable in the target topology.
/// > Fallback selection is a recorded precondition, not a silent default.
///
/// This adapter is the local secret store. It is what lets the QA stack — which
/// has no GCP credentials — exercise the whole credential path end to end. It
/// is reachable **only** by naming it in configuration
/// (`SHIPIT_SECRET_PROVIDER=local_file`), because [SecretProviderResolver] has
/// no default branch, and choosing it emits a startup log line that says the
/// custody guarantee in ADR 0018 §A3 is being held locally rather than by an
/// external manager. That is the whole of the "recorded precondition".
///
/// WHAT IT DOES AND DOES NOT GIVE UP. §A3's guarantee is "SHIP IT holds a
/// reference, never key bytes". This adapter holds both — the reference AND the
/// bytes, on the same host as the database. That is a strictly weaker custody
/// position than the external manager, which is exactly why it is a fallback
/// rather than the design, and why its selection is recorded rather than
/// assumed. It is appropriate for a single-machine QA stack behind the
/// local-only posture ADR 0018 §Accepted risks (A3) already accepts; it is not
/// appropriate for any topology wider than one machine.
class LocalFileSecretProvider implements SecretProvider {
  /// Creates a provider writing under [directoryPath].
  ///
  /// The directory is created owner-only on first write, not here, so that
  /// constructing a provider — which the resolver does at startup for every
  /// deployment — does not litter a filesystem on a host that may never mint a
  /// credential.
  LocalFileSecretProvider({required this.directoryPath});

  /// Where the owner-only files live, e.g. `~/.config/shipit/platform`.
  final String directoryPath;

  @override
  String get providerId => kLocalFileProviderId;

  @override
  bool get isDocumentedFallback => true;

  @override
  Map<String, String> describe() => {
    'provider': providerId,
    'directory': directoryPath,
    'mode': PosixFileModes.file,
    'adr': 'ADR 0018 A1/A4 fallback (local secret store)',
  };

  @override
  Future<String> store({
    required String referenceName,
    required SecretBytes secret,
  }) async {
    validateReferenceName(referenceName);
    final path = _pathFor(referenceName);
    try {
      PosixFileModes.createOwnerOnlyDirectory(directoryPath);
      // The PEM bytes, verbatim and unencoded. NOT `secret.toString()` — that is
      // the redacted projection and storing it would silently persist
      // "<secret redacted, N bytes>" as the credential, which then fails at
      // verification with an unreadable identity rather than at mint. This is
      // the one place `.bytes` is correct, and it is a documented call site.
      PosixFileModes.writeOwnerOnlyFile(path, secret.bytes);
      return referenceName;
    } on Object catch (error) {
      throw SecretStoreException(
        referenceName: referenceName,
        providerId: providerId,
        operation: 'store',
        // `error` here is a StateError from PosixFileModes or an OS error, both
        // of which carry a path and a mode — never key bytes. `secret` is not
        // interpolated, and its own toString is redacted regardless.
        reason: '$error',
      );
    }
  }

  @override
  Future<SecretBytes> read({required String referenceName}) async {
    validateReferenceName(referenceName);
    final file = File(_pathFor(referenceName));
    if (!file.existsSync()) {
      throw SecretStoreException(
        referenceName: referenceName,
        providerId: providerId,
        operation: 'read',
        reason:
            'no local secret store entry for this reference; '
            'the private half is not present on this host',
      );
    }
    try {
      return SecretBytes(file.readAsBytesSync());
    } on Object catch (error) {
      throw SecretStoreException(
        referenceName: referenceName,
        providerId: providerId,
        operation: 'read',
        reason: '$error',
      );
    }
  }

  @override
  Future<void> destroy({required String referenceName}) async {
    validateReferenceName(referenceName);
    final file = File(_pathFor(referenceName));
    // Idempotent by contract: ADR 0018 §A2 makes revocation two-sided and
    // destroying an already-absent handle must not be an error, or a retry
    // after a partial failure could never complete.
    if (!file.existsSync()) return;
    try {
      file.deleteSync();
    } on Object catch (error) {
      throw SecretStoreException(
        referenceName: referenceName,
        providerId: providerId,
        operation: 'destroy',
        reason: '$error',
      );
    }
  }

  String _pathFor(String referenceName) =>
      '$directoryPath${Platform.pathSeparator}$referenceName';
}

/// Environment variable naming the fallback substrate's directory.
///
/// Has a default — `~/.config/shipit/platform`, the exact path ADR 0018 §A1
/// names — because the ADR's requirement is that *selecting the fallback* is
/// explicit, not that its location is. The resolver logs when the default was
/// used, so a reader of the startup log can tell a configured directory from the
/// conventional one.
const String kLocalSecretDirectoryEnv = 'SHIPIT_LOCAL_SECRET_DIR';

/// The conventional fallback directory, per ADR 0018 §A1.
const String kDefaultLocalSecretDirectory = '.config/shipit/platform';

/// Resolves the fallback directory, falling back to the ADR's documented path.
///
/// Resolved against `HOME` rather than `Directory.systemTemp`: the file must
/// outlive the process for the QA stack to keep a usable credential between
/// restarts, and `/tmp` on macOS is periodically cleared.
String resolveLocalSecretDirectory(Map<String, String> environment) {
  final configured = environment[kLocalSecretDirectoryEnv]?.trim();
  if (configured != null && configured.isNotEmpty) {
    return _absolute(configured);
  }
  final home = environment['HOME']?.trim();
  if (home == null || home.isEmpty) {
    throw SecretProviderNotConfiguredException(
      '$kLocalSecretDirectoryEnv is not set and HOME is empty, so the ADR 0018 '
      'A1 fallback directory cannot be resolved. Set $kLocalSecretDirectoryEnv '
      'to an absolute path.',
    );
  }
  return '$home${Platform.pathSeparator}$kDefaultLocalSecretDirectory';
}

String _absolute(String path) =>
    path.startsWith('/') ? path : '${Directory.current.path}$path';
