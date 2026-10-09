import 'dart:io' show Platform;

import 'gcp_secret_manager_secret_provider.dart';
import 'local_file_secret_provider.dart';
import 'secret_provider.dart';

/// Environment variable that selects the custody substrate.
///
/// REQUIRED, with no default. See [resolveSecretProvider] for why.
const String kSecretProviderEnv = 'SHIPIT_SECRET_PROVIDER';

/// Signature of the startup log a resolver emits.
///
/// `void Function(String event, Map<String, String> fields)`. Kept as a plain
/// function rather than a `StructuredLogger` so this layer does not need a
/// Serverpod `Session` — the selection is a process-level fact and must be
/// answerable at startup, before any session exists.
typedef SecretProviderLogSink =
    void Function(String event, Map<String, String> fields);

/// The outcome of a successful selection, with everything an operator needs to
/// know about it in a form that is safe to log.
class SecretProviderSelection {
  SecretProviderSelection({required this.provider, required this.loggedFields});

  /// The constructed adapter.
  final SecretProvider provider;

  /// Exactly what was logged. Exposed so a test can assert on the recorded
  /// precondition rather than on a captured stdout stream.
  final Map<String, String> loggedFields;
}

/// Selects and constructs the custody substrate, failing closed.
///
/// THE RULE THIS ENFORCES. ADR 0018 §Decision:
///
/// > The local secret store (A1) and host keychain (A4) remain the documented
/// > **fallback** when no secret manager is reachable in the target topology.
/// > Fallback selection is a recorded precondition, not a silent default.
///
/// and §Preconditions:
///
/// > **A1/A4 fallback selection is a precondition.** Choosing the local secret
/// > store or host keychain because no manager is reachable must be an explicit
/// > recorded decision, since it changes what this ADR's custody guarantee
/// > means.
///
/// The whole of "explicit recorded decision" lands on this function. There is no
/// default branch and no `?? local_file`: a resolver that defaulted would make
/// the fallback the default, which is the exact outcome the clause forbids, and
/// the QA stack would run with the weaker custody posture ADR 0018 §A3 describes
/// while every log line looked like a normal startup.
///
/// So: unset, blank, and unrecognised all throw
/// [SecretProviderNotConfiguredException], naming the variable and the accepted
/// values. And every accepted selection is logged — the fallback one at a level
/// and wording that says plainly that a precondition has been met rather than
/// that a preference was applied.
///
/// WHAT THE DISPATCH ASKED FOR. "Explicitly selected by configuration, and its
/// selection logged at startup" — both are here. The logging happens when the
/// resolver is called, which the endpoint does on first use; wiring
/// `resolveSecretProvider()` into `run()` in `apps/server/lib/server.dart` would
/// move it to process start, and that file is outside this lane's declared
/// ownership. The precondition is therefore recorded before any credential can be
/// minted, which is the property the clause cares about, but the one-line
/// wiring that would put it in the process-start banner is outstanding and is
/// reported as such.
SecretProviderSelection resolveSecretProvider({
  Map<String, String>? environment,
  SecretProviderLogSink? log,
}) {
  final env = environment ?? Platform.environment;
  final selected = env[kSecretProviderEnv]?.trim();
  if (selected == null || selected.isEmpty) {
    throw SecretProviderNotConfiguredException(
      '$kSecretProviderEnv is not set. Custody of a repository deploy key\'s '
      'private half has no default (ADR 0018: "Fallback selection is a recorded '
      'precondition, not a silent default"). Set $kSecretProviderEnv to one of '
      '${kKnownProviderIds.join(', ')} — "$kLocalFileProviderId" being the '
      'documented fallback for a host with no reachable secret manager.',
    );
  }

  final SecretProvider provider;
  switch (selected) {
    case kGcpSecretManagerProviderId:
      provider = GcpSecretManagerSecretProvider.fromEnvironment(env);
    case kLocalFileProviderId:
      provider = LocalFileSecretProvider(
        directoryPath: resolveLocalSecretDirectory(env),
      );
    default:
      throw SecretProviderNotConfiguredException(
        '$kSecretProviderEnv=$selected is not a known provider. Accepted values '
        'are ${kKnownProviderIds.join(', ')}.',
      );
  }

  final fields = <String, String>{
    ...provider.describe(),
    // Recorded whether or not it is the fallback, because an operator reading a
    // startup log later needs to be able to tell "configured" from "defaulted",
    // and for the fallback the ADR specifically does not want that distinction
    // left implicit.
    'selection': 'explicit ($kSecretProviderEnv=$selected)',
    'isDocumentedFallback': '${provider.isDocumentedFallback}',
  };
  // Whether the directory was configured or fell back to the ADR 0018 §A1 path.
  // Selecting the FALLBACK is the precondition; where it points is a detail, but
  // an operator reading this line later needs to tell the two apart.
  if (env[kLocalSecretDirectoryEnv] == null &&
      provider is LocalFileSecretProvider) {
    fields['directorySource'] =
        'defaulted to ~/.config/$kDefaultLocalSecretDirectory '
        '(ADR 0018 A1 path) because $kLocalSecretDirectoryEnv is unset';
  }
  log?.call(
    provider.isDocumentedFallback
        ? 'credential.secret_provider.fallback_selected'
        : 'credential.secret_provider.selected',
    fields,
  );
  return SecretProviderSelection(provider: provider, loggedFields: fields);
}
