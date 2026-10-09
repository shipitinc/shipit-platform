import 'runtime_config_stub.dart'
    if (dart.library.js_interop) 'runtime_config_web.dart'
    as runtime_config;

/// The operator's trust-on-first-use confirmation of a repository host key.
///
/// WHY THIS EXISTS. `CredentialEndpoints.verifyAccess` requires two values the
/// server cannot produce for itself:
///   * `hostKeyFingerprint` — ADR 0018 §Decision's "the operator is shown the
///     host, key type and fingerprint and must confirm it", and
///   * `confirmedBy` — who did that confirming.
///
/// Both are **operator-asserted and unauthenticated** (finding M-5, open). The
/// server does independently obtain the host key and refuses to clone unless the
/// fingerprint it computes equals the value supplied here — so the value is
/// enforced by the transport — but its *provenance* is this configuration, not
/// the server. Nothing here may be described as proof of host identity.
///
/// THEREFORE: never hardcoded. Both come from deployment configuration, read at
/// the same two seams this app already uses for `CONTROL_PLANE_API`:
///
///   1. `window.SHIPIT_CONFIG` at runtime, published by
///      `docker/config.js.template`. **That file enumerates the keys it
///      publishes and is outside this lane's ownership**, so on a deployment that
///      has not been updated the runtime lookup returns null and the build-time
///      value below is used instead.
///   2. `--dart-define`, which works today with no change to any file this lane
///      does not own:
///      `--dart-define=SHIPIT_HOST_KEY_FINGERPRINT=SHA256:…`
///      `--dart-define=SHIPIT_OPERATOR_NAME="<the operator's name>"`
///
/// A deployment with neither leaves [isComplete] false, and the Add Product flow
/// will mint a deploy key but stop short of proving access — it will not invent a
/// fingerprint to get past the check, because a fingerprint the deployment never
/// supplied is exactly the silent default ADR 0018 refuses.
///
/// [hostKeyFingerprint] is not validated for shape here. The server bounds it
/// (`CredentialKeyService._validatedFingerprint`) and refuses anything with
/// whitespace, a control character, or more than 128 characters; duplicating that
/// check client-side would give two answers to one question, and the server's is
/// the one that can refuse.
class OperatorAttestation {
  const OperatorAttestation({this.hostKeyFingerprint, this.confirmedBy});

  /// Resolves both values from configuration, in the order described above.
  ///
  /// Blank and whitespace-only values are normalised to null so a deployment that
  /// sets `SHIPIT_OPERATOR_NAME=""` is treated as unset rather than as an
  /// operator whose name is the empty string — which the server would reject
  /// anyway, but with a much less useful message.
  factory OperatorAttestation.fromRuntime() => OperatorAttestation(
    hostKeyFingerprint: _configured(
      'HOST_KEY_FINGERPRINT',
      const String.fromEnvironment('SHIPIT_HOST_KEY_FINGERPRINT'),
    ),
    confirmedBy: _configured(
      'OPERATOR_NAME',
      const String.fromEnvironment('SHIPIT_OPERATOR_NAME'),
    ),
  );

  /// `SHA256:…` of the repository host's public key, as the operator read it off
  /// the provider's published fingerprints. Null when unconfigured.
  final String? hostKeyFingerprint;

  /// The operator who confirmed that fingerprint. Free text; a person's name.
  /// Null when unconfigured.
  final String? confirmedBy;

  /// Whether [CredentialEndpoints.verifyAccess] can be called at all.
  ///
  /// Both are required there, so a half-configured deployment cannot proceed and
  /// is told which half is missing rather than failing at the call.
  bool get isComplete => hostKeyFingerprint != null && confirmedBy != null;

  static String? _configured(String runtimeKey, String buildTimeValue) {
    for (final candidate in [
      runtime_config.readRuntimeConfigValue(runtimeKey),
      buildTimeValue,
    ]) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
}
