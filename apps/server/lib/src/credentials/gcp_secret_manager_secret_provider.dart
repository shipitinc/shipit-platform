import 'dart:convert';
import 'dart:io';

import 'secret_material.dart';
import 'secret_provider.dart';

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
    );
    return referenceName;
  }

  @override
  Future<SecretBytes> read({required String referenceName}) async {
    final secretId = secretIdFor(referenceName);
    final response = await _send(
      'GET',
      '/v1/projects/$projectId/secrets/$secretId/versions/latest:access',
      null,
    );
    final decoded = jsonDecode(response) as Map<String, dynamic>;
    final payload = decoded['payload'] as Map<String, dynamic>?;
    final data = payload?['data'];
    if (data is! String) {
      throw SecretStoreException(
        referenceName: referenceName,
        providerId: providerId,
        operation: 'read',
        reason: 'the access response carried no payload.data',
      );
    }
    return SecretBytes(base64.decode(data));
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
  Future<String> _send(
    String method,
    String path,
    Map<String, dynamic>? body, {
    bool tolerateAlreadyExists = false,
    bool tolerateNotFound = false,
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
      reason: 'HTTP $code ${_googleMessage(text)}',
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
