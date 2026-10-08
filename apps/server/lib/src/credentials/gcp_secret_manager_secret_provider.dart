import 'dart:convert';
import 'dart:io';

import 'secret_material.dart';
import 'secret_provider.dart';
import 'secretless_error.dart';

/// GCP Secret Manager custody — the ADR 0018 §A3 substrate.
///
/// WHAT THIS IS NOT. ADR 0018 §Accepted risks (A4) records, against `43d328b`,
/// that the external secret manager's reachability **has never been
/// runtime-probed** and that `9417f8bf` records confidence **LOW**. That is
/// still true of this adapter: it was written against the published REST API and
/// the project's own Terraform, and **it has never been executed against a real
/// GCP project.** It is not claimed to work, and no test here pretends to. The
/// runtime probe that `9417f8bf` follow-up action 4 requires is what would close
/// A4, and it needs a project this lane has no authority to touch. The same
/// honesty is why the adapter raises a typed [SecretStoreException] on every
/// failure path rather than returning a best-effort result: an unprobed
/// dependency that fails quietly is the worst of both.
///
/// THE PROJECT / REGION CONVENTIONS, read from
/// `infrastructure/modules/secrets/main.tf` rather than guessed:
///
///   * Secrets are `google_secret_manager_secret` resources named
///     `"${var.name_prefix}-<thing>"`, so a platform-wide prefix belongs in
///     [namePrefix] and must be supplied by the deployment. That is the
///     repository's convention and this adapter follows it instead of inventing
///     a second naming scheme.
///   * `replication { automatic = true }` on every secret. That is why there is
///     no regional endpoint and no `var.region` here: with automatic
///     replication the data plane is the single global
///     `secretmanager.googleapis.com`, and threading a region variable through
///     would imply a scoping that does not exist.
///
/// AUTHENTICATION, by name only. [accessTokenEnv] carries a bearer token the
/// deployment supplies out of band; failing that, the token is fetched from the
/// GCE/GKE metadata server using the `Metadata-Flavor: Google` header. Neither
/// path writes a token anywhere, and no credential value appears in
/// [describe] — which is what makes this class safe to log at startup.
///
/// AN ACCEPTED BOUND: a re-mint ADDS A VERSION, and the previous one stays
/// readable. `store` creates the secret tolerating a 409 and then calls
/// `addVersion`, deliberately — destroying first would delete the private half of
/// a credential that is live and installed on a repository. The consequence is a
/// rotation window in which both the old and the new private half are readable
/// from the manager, which is *not* the same as two-sided revocation being
/// broken: [destroy] deletes the secret and therefore every version, so an actual
/// revocation is still complete. What is accepted here is a rotation without a
/// revocation, and it is accepted until the rotate path exists to own the
/// `destroy`-before-re-mint decision. Recorded because it is a bound on ADR 0018
/// §A2, not because it is comfortable.
class GcpSecretManagerSecretProvider implements SecretProvider {
  GcpSecretManagerSecretProvider({
    required this.projectId,
    this.namePrefix = '',
    this.apiBaseUrl = kDefaultApiBaseUrl,
    HttpClient? httpClient,
    this.metadataHost = kDefaultMetadataHost,
  }) : _httpClient = httpClient ?? HttpClient();

  /// The default Secret Manager data-plane endpoint. See the class note: with
  /// `replication { automatic = true }` there is no regional variant.
  static const String kDefaultApiBaseUrl =
      'https://secretmanager.googleapis.com';

  /// GCE/GKE metadata server. Loopback-adjacent by specification: the link-local
  /// address is not routable off-host.
  static const String kDefaultMetadataHost = '169.254.169.254';

  /// Environment variable naming the GCP project. Required.
  static const String projectIdEnv = 'SHIPIT_GCP_PROJECT_ID';

  /// Environment variable carrying a Secret Manager access token.
  static const String accessTokenEnv = 'SHIPIT_GCP_SECRET_MANAGER_ACCESS_TOKEN';

  /// Environment variable naming the Terraform `name_prefix` this deployment
  /// used. Optional; empty means the bare reference name is the secret id.
  static const String namePrefixEnv = 'SHIPIT_GCP_SECRET_PREFIX';

  /// Token lifetime assumed when the metadata server reports one. Deliberately
  /// conservative: re-fetching a token costs one HTTP round trip, and using a
  /// stale one costs a failed mint.
  static const Duration _metadataTokenTtl = Duration(minutes: 30);

  /// GCP project the secrets live in.
  final String projectId;

  /// Terraform `name_prefix`, matching `"${var.name_prefix}-<thing>"`.
  final String namePrefix;

  /// Data-plane base URL. Overridable so a test can point it at a local stub.
  final String apiBaseUrl;

  /// Metadata server host for workload-identity token minting.
  final String metadataHost;

  final HttpClient _httpClient;

  String? _cachedToken;
  DateTime _cachedTokenExpiry = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  String get providerId => kGcpSecretManagerProviderId;

  @override
  bool get isDocumentedFallback => false;

  @override
  Map<String, String> describe() => {
    'provider': providerId,
    'projectId': projectId,
    'namePrefix': namePrefix,
    'apiBaseUrl': apiBaseUrl,
    // Deliberately absent: the access token, and whether one was found. Naming
    // the token's *source* would be useful and is deliberately not done, because
    // "the token came from the metadata server" is exactly the kind of fact an
    // operator would expect in a log and a reader would not expect to be there.
    'adr': 'ADR 0018 A3 (external secret manager)',
    'runtimeVerified': 'false (ADR 0018 accepted risk A4: never probed)',
  };

  /// Maps a logical credential reference to the GCP secret id.
  ///
  /// Deterministic and one-to-one, so a reference in the database is enough to
  /// find the material again with no second column: the same rule the local
  /// adapter uses to find its file. Mirrors the Terraform convention of
  /// `"${var.name_prefix}-<thing>"`.
  String secretIdFor(String referenceName) {
    validateReferenceName(referenceName);
    return namePrefix.isEmpty ? referenceName : '$namePrefix-$referenceName';
  }

  @override
  Future<String> store({
    required String referenceName,
    required SecretBytes secret,
  }) async {
    final secretId = secretIdFor(referenceName);
    // Secret Manager's payload is base64 over the wire, so this is the one place
    // key bytes legitimately become a String. It exists only inside this request
    // body and is never stored, logged, or returned.
    final payload = base64.encode(secret.bytes);
    await _send(
      'POST',
      '/v1/projects/$projectId/secrets',
      {
        'secretId': secretId,
        'replication': {'automatic': true},
      },
      // A 409 means the secret already exists, which is not a failure for
      // `store`: the next call adds a version to it. Distinguishing it here is
      // what keeps a re-mint from destroying a live credential's handle.
      tolerateAlreadyExists: true,
    );
    await _send(
      'POST',
      '/v1/projects/$projectId/secrets/$secretId:addVersion',
      {
        'payload': {'data': payload},
      },
      // The ONLY request in this adapter whose body carries key bytes. See
      // `_send`'s `carriesSecretMaterial` for why that changes the refusal text.
      carriesSecretMaterial: true,
    );
    return referenceName;
  }

  @override
  Future<SecretBytes> read({required String referenceName}) async {
    final secretId = secretIdFor(referenceName);

    /// Every refusal below is a literal, and every one of them names what could
    /// not be parsed rather than what was parsed.
    ///
    /// This is the method B-1 was about, so the reasoning is written down rather
    /// than implied. The body of a `versions/latest:access` response is
    /// `{"name":…,"payload":{"data":"<base64 PEM>"}}` — i.e. the key is a
    /// *substring of the text being parsed*, and both `dart:convert` decoders
    /// embed an excerpt of their input in `FormatException.toString()`. Unguarded,
    /// a malformed 2xx body therefore turns a malformed secret **at rest** into
    /// base64 private-key material in an exception message, which
    /// `credential_endpoints.dart` writes to the Serverpod session log, which is
    /// persisted to Postgres. `SecretBytes` cannot prevent that: it protects
    /// values this code holds, and this is a value a third-party exception
    /// captured on its behalf.
    ///
    /// So the three failure shapes are named explicitly and none of them is
    /// allowed to escape:
    Future<SecretBytes> fail(String reason) => throw SecretStoreException(
      referenceName: referenceName,
      providerId: providerId,
      operation: 'read',
      reason: reason,
    );

    final response = await _send(
      'GET',
      '/v1/projects/$projectId/secrets/$secretId/versions/latest:access',
      null,
    );

    // Decode, not cast. `jsonDecode(response) as Map<String, dynamic>` throws two
    // different exception types depending on what came back, and while neither
    // carries the response body, an untyped `TypeError` in a custody path is a
    // poor trade for one line. `is` produces a boolean and the typed failure.
    Object? parsed;
    try {
      parsed = jsonDecode(response);
    } on Object {
      return fail(
        'the access response was not JSON at all; $kNoMaterialEchoed',
      );
    }
    if (parsed is! Map<String, dynamic>) {
      return fail(
        'the access response was not a JSON object; $kNoMaterialEchoed',
      );
    }

    // `is` rather than `as`, for the same reason: a raw cast failure is an
    // exception whose text this method does not control.
    final payload = parsed['payload'];
    final data = payload is Map<String, dynamic> ? payload['data'] : null;
    if (data is! String) {
      return fail('the access response carried no payload.data string');
    }

    // THE site B-1 named. `data` is base64 private-key material in a `String`,
    // and `base64.decode` puts its input in the `FormatException` it throws, so
    // the decode is wrapped and the failure is re-typed before it can leave.
    final List<int> material;
    try {
      material = base64.decode(data);
    } on Object {
      return fail(
        'the access response payload was not decodable as base64; '
        '$kNoMaterialEchoed',
      );
    }
    return SecretBytes(material);
  }

  @override
  Future<void> destroy({required String referenceName}) async {
    final secretId = secretIdFor(referenceName);
    await _send(
      'DELETE',
      '/v1/projects/$projectId/secrets/$secretId',
      null,
      tolerateNotFound: true,
    );
  }

  /// Issues one request and returns the decoded body.
  ///
  /// Every failure becomes a [SecretStoreException] naming the reference, the
  /// operation and the HTTP status. The response body is reduced to that status
  /// and Google's `error.message` — which describes the API call, never the
  /// payload — rather than interpolated wholesale, because an echoed request
  /// body would put base64 key material into a log line.
  ///
  /// [carriesSecretMaterial] is the rule that makes that reduction safe rather
  /// than merely intended. Google's `error.message` is a **third party's free
  /// text**, and on the one request that carries key material
  /// (`addVersion`) a third party in a position to echo it could put the payload
  /// into our exception message. So: on a request that carried material, the
  /// message is not included at all — the HTTP status and the reason the message
  /// was withheld are, which is what an operator actually acts on. On every other
  /// request — nothing in it is secret — the message is included, because it is
  /// the diagnostic that makes a GCP failure actionable.
  Future<String> _send(
    String method,
    String path,
    Map<String, dynamic>? body, {
    bool tolerateAlreadyExists = false,
    bool tolerateNotFound = false,
    bool carriesSecretMaterial = false,
  }) async {
    final uri = Uri.parse('$apiBaseUrl$path');
    final request = await _httpClient.openUrl(method, uri);
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${await _token()}',
    );
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    final code = response.statusCode;

    if (code >= 200 && code < 300) return text;
    if (tolerateAlreadyExists && code == 409) return text;
    if (tolerateNotFound && code == 404) return text;

    throw SecretStoreException(
      referenceName: path,
      providerId: providerId,
      operation: method,
      reason: carriesSecretMaterial
          ? 'HTTP $code (the service message was withheld because this request '
                'carried key material)'
          : 'HTTP $code ${_googleMessage(text)}',
    );
  }

  /// Reduces a Google error body to its `error.message`, discarding the rest.
  String _googleMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String) return message;
        }
      }
    } on Object {
      // Not JSON, or not the shape expected. The status code is still the useful
      // fact, and echoing an unparseable body risks carrying a payload echo.
    }
    return '(no parsable error message)';
  }

  /// Returns a bearer token, from the environment or the metadata server.
  Future<String> _token() async {
    final injected = _injectedToken;
    if (injected != null && injected.isNotEmpty) return injected;
    final now = DateTime.now();
    if (_cachedToken != null && now.isBefore(_cachedTokenExpiry)) {
      return _cachedToken!;
    }
    final metadata = await _fetchMetadataToken();
    if (metadata == null) {
      throw SecretStoreException(
        referenceName: '<token>',
        providerId: providerId,
        operation: 'authenticate',
        reason:
            'no $accessTokenEnv in the environment and the metadata server at '
            '$metadataHost did not issue a token. Supply $accessTokenEnv or run '
            'with a workload identity bound to $projectId.',
      );
    }
    _cachedToken = metadata.$1;
    _cachedTokenExpiry = now.add(_metadataTokenTtl);
    return _cachedToken!;
  }

  Future<(String, int)?> _fetchMetadataToken() async {
    final uri = Uri.parse(
      'http://$metadataHost/computeMetadata/v1/instance/service-accounts/'
      'default/token',
    );
    try {
      final request = await _httpClient.getUrl(uri);
      request.headers.set('Metadata-Flavor', 'Google');
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final text = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return null;
      final token = decoded['access_token'];
      if (token is! String || token.isEmpty) return null;
      final ttl = decoded['expires_in'];
      return (token, ttl is int ? ttl : 3600);
    } on Object {
      // No metadata server (a laptop, a CI runner): an ordinary condition, and
      // the caller turns it into the actionable message above.
      return null;
    }
  }

  /// Token supplied directly at construction, if any.
  ///
  /// Set by [GcpSecretManagerSecretProvider.fromEnvironment]. Kept separate from
  /// [describe] so it cannot reach a log through that path.
  String? _injectedToken;

  /// Builds a provider from the environment, reading [projectIdEnv],
  /// [namePrefixEnv] and [accessTokenEnv].
  ///
  /// Throws [SecretProviderNotConfiguredException] when the project id is
  /// missing — the same fail-closed rule the provider selection itself follows.
  /// A Secret Manager client with no project cannot be constructed, and
  /// defaulting the project to anything would be a guess with key custody
  /// attached.
  factory GcpSecretManagerSecretProvider.fromEnvironment(
    Map<String, String> environment, {
    String? metadataHost,
    HttpClient? httpClient,
  }) {
    final projectId = environment[projectIdEnv]?.trim();
    if (projectId == null || projectId.isEmpty) {
      throw SecretProviderNotConfiguredException(
        '$projectIdEnv is not set. The GCP Secret Manager adapter cannot be '
        'constructed without a project; set $projectIdEnv to the project that '
        'holds the platform secrets.',
      );
    }
    return GcpSecretManagerSecretProvider(
      projectId: projectId,
      namePrefix: environment[namePrefixEnv]?.trim() ?? '',
      metadataHost: metadataHost ?? kDefaultMetadataHost,
      httpClient: httpClient,
    ).._injectedToken = environment[accessTokenEnv]?.trim();
  }
}
