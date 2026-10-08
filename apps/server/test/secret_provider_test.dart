import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:control_plane_server/src/credentials/gcp_secret_manager_secret_provider.dart';
import 'package:control_plane_server/src/credentials/local_file_secret_provider.dart';
import 'package:control_plane_server/src/credentials/posix_file_permissions.dart';
import 'package:control_plane_server/src/credentials/secret_material.dart';
import 'package:control_plane_server/src/credentials/secret_provider.dart';
import 'package:control_plane_server/src/credentials/secret_provider_resolver.dart';
import 'package:control_plane_server/src/credentials/secretless_error.dart';
import 'package:control_plane_server/src/credentials/ssh_keypair.dart';
import 'package:test/test.dart';

/// The material a round trip must preserve, as bytes.
///
/// A real PEM rather than a marker string, so a store that truncated, re-encoded
/// or refused non-ASCII would be caught by the equality assertion rather than by
/// a length check — and **as bytes**, because the type no longer offers a `String`
/// of the private half and a test that decoded one would hand it straight back to
/// every matcher that prints its operands.
Uint8List _privatePemBytes() =>
    SshKeyPair.generate(comment: 'shipit+roundtrip').privateKeyPemBytes;

/// Byte equality as a BOOLEAN, so a failing assertion prints `false` and not the
/// two operands.
///
/// A test that fails while including key material is itself a defect: the matcher
/// prints whatever it was handed, so `expect(read.bytes, expected)` would put a
/// deploy key into the test output — the same durable-record prohibition reached
/// through a failing assertion. Through this, the failure message names only the
/// pair being compared.
bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void main() {
  late Directory scratch;
  late String homeDir;

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('shipit_secret_test_');
    homeDir = '${scratch.path}/home';
    Directory(homeDir).createSync(recursive: true);
  });

  tearDown(() {
    if (scratch.existsSync()) {
      PosixFileModes.applyStrict(scratch.path, '700');
      scratch.deleteSync(recursive: true);
    }
  });

  group('selection fails closed', () {
    test('an unset SHIPIT_SECRET_PROVIDER is refused, not defaulted', () {
      // The clause under test, verbatim: "Fallback selection is a recorded
      // precondition, not a silent default." A default here would be the defect.
      expect(
        () => resolveSecretProvider(environment: {'HOME': homeDir}),
        throwsA(
          isA<SecretProviderNotConfiguredException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains(kSecretProviderEnv),
              contains(kLocalFileProviderId),
              contains(kGcpSecretManagerProviderId),
            ),
          ),
        ),
      );
    });

    test('a blank value is refused', () {
      expect(
        () => resolveSecretProvider(
          environment: {kSecretProviderEnv: '   ', 'HOME': homeDir},
        ),
        throwsA(isA<SecretProviderNotConfiguredException>()),
      );
    });

    test('an unknown value is refused and names the accepted ones', () {
      expect(
        () => resolveSecretProvider(
          environment: {kSecretProviderEnv: 'vault', 'HOME': homeDir},
        ),
        throwsA(
          isA<SecretProviderNotConfiguredException>().having(
            (e) => e.message,
            'message',
            allOf(contains('vault'), contains(kGcpSecretManagerProviderId)),
          ),
        ),
      );
    });

    test('a refused selection creates no directory on disk', () {
      expect(
        () => resolveSecretProvider(environment: {'HOME': homeDir}),
        throwsA(isA<SecretProviderNotConfiguredException>()),
      );
      expect(
        Directory('$homeDir/.config').existsSync(),
        isFalse,
        reason: 'refusing must not have side effects',
      );
    });

    test('the GCP adapter is refused without a project', () {
      expect(
        () => resolveSecretProvider(
          environment: {kSecretProviderEnv: kGcpSecretManagerProviderId},
        ),
        throwsA(
          isA<SecretProviderNotConfiguredException>().having(
            (e) => e.message,
            'message',
            contains(GcpSecretManagerSecretProvider.projectIdEnv),
          ),
        ),
      );
    });
  });

  group('selection is explicit and recorded', () {
    test('the fallback is logged as a precondition, at its own event', () {
      final events = <String, Map<String, String>>{};
      final selection = resolveSecretProvider(
        environment: {
          kSecretProviderEnv: kLocalFileProviderId,
          'HOME': homeDir,
        },
        log: (event, fields) => events[event] = fields,
      );

      expect(selection.provider.providerId, kLocalFileProviderId);
      expect(selection.provider.isDocumentedFallback, isTrue);
      expect(
        events.keys,
        ['credential.secret_provider.fallback_selected'],
        reason:
            'the fallback must be distinguishable from an ordinary '
            'selection in the log, not merely present in it',
      );
      final fields = events.values.single;
      expect(fields['provider'], kLocalFileProviderId);
      expect(fields['isDocumentedFallback'], 'true');
      expect(fields['selection'], contains(kLocalFileProviderId));
      expect(fields['adr'], contains('fallback'));
    });

    test('a defaulted fallback directory is recorded as defaulted', () {
      final fields = <String, String>{};
      resolveSecretProvider(
        environment: {
          kSecretProviderEnv: kLocalFileProviderId,
          'HOME': homeDir,
        },
        log: (_, f) => fields.addAll(f),
      );
      expect(fields['directory'], '$homeDir/$kDefaultLocalSecretDirectory');
      expect(fields['directorySource'], contains('defaulted'));

      final configured = <String, String>{};
      resolveSecretProvider(
        environment: {
          kSecretProviderEnv: kLocalFileProviderId,
          'HOME': homeDir,
          kLocalSecretDirectoryEnv: '${scratch.path}/explicit',
        },
        log: (_, f) => configured.addAll(f),
      );
      expect(configured['directory'], '${scratch.path}/explicit');
      expect(
        configured.containsKey('directorySource'),
        isFalse,
        reason:
            'a configured directory is not a defaulted one, and saying so '
            'either way keeps the log honest',
      );
    });

    test('the GCP selection logs no token', () {
      final fields = <String, String>{};
      final selection = resolveSecretProvider(
        environment: {
          kSecretProviderEnv: kGcpSecretManagerProviderId,
          GcpSecretManagerSecretProvider.projectIdEnv: 'shipit-platform-prod',
          GcpSecretManagerSecretProvider.accessTokenEnv: 'ya29.super-secret',
          GcpSecretManagerSecretProvider.namePrefixEnv: 'shipit',
        },
        log: (_, f) => fields.addAll(f),
      );
      expect(selection.provider.providerId, kGcpSecretManagerProviderId);
      expect(selection.provider.isDocumentedFallback, isFalse);
      expect(fields['projectId'], 'shipit-platform-prod');
      expect(fields['namePrefix'], 'shipit');
      expect(fields['runtimeVerified'], contains('false'));
      expect(
        fields.values.join(' '),
        isNot(contains('ya29')),
        reason: 'the access token must never reach a log field',
      );
      expect(
        fields.values.join(' '),
        isNot(contains('super-secret')),
      );
      expect(
        selection.provider.describe().values.join(' '),
        isNot(contains('ya29')),
      );
    });

    // Terraform convention, from infrastructure/modules/secrets/main.tf.
    test('GCP secret ids follow the Terraform name_prefix + thing shape', () {
      final provider = GcpSecretManagerSecretProvider.fromEnvironment({
        GcpSecretManagerSecretProvider.projectIdEnv: 'p',
        GcpSecretManagerSecretProvider.namePrefixEnv: 'shipit-platform',
      });
      expect(
        provider.secretIdFor('GIT_REPOSITORY_repo-1_SSH'),
        'shipit-platform-GIT_REPOSITORY_repo-1_SSH',
      );
      expect(
        GcpSecretManagerSecretProvider.fromEnvironment({
          GcpSecretManagerSecretProvider.projectIdEnv: 'p',
        }).secretIdFor('GIT_REPOSITORY_repo-1_SSH'),
        'GIT_REPOSITORY_repo-1_SSH',
      );
    });
  });

  group('reference names are bare identifiers', () {
    test('are built per repository, per ADR 0018 A1', () {
      expect(
        credentialReferenceName('repo-1'),
        'GIT_REPOSITORY_repo-1_SSH',
      );
      // A1 moved scope from the product to the repository, so a product id must
      // not leak into the name: two repositories of one product need two keys.
      expect(
        credentialReferenceName('repo-2'),
        isNot(contains('repo-1')),
      );
    });

    test('sanitise rather than reject an id that is not a bare name', () {
      expect(
        credentialReferenceName('acme/shipit:platform'),
        'GIT_REPOSITORY_acme_shipit_platform_SSH',
      );
    });

    test('reject traversal, separators and a leading dot', () {
      for (final hostile in <String>[
        '../escape',
        'a/b',
        r'a\b',
        '.hidden',
        '',
        'has space',
        'nul byte',
        'x' * 256,
      ]) {
        expect(
          () => validateReferenceName(hostile),
          throwsArgumentError,
          reason: 'reference "$hostile" must be refused',
        );
      }
    });

    test('accept the ADR shapes', () {
      for (final good in <String>[
        'GIT_REPOSITORY_repo-1_SSH',
        'GIT_PRODUCT_acme_docs_SSH',
        'a',
        'A.b-c_d9',
      ]) {
        expect(() => validateReferenceName(good), returnsNormally);
      }
    });
  });

  group('the local fallback round-trips the private half', () {
    test('store then read returns the identical bytes', () async {
      final provider = LocalFileSecretProvider(
        directoryPath: '${scratch.path}/s',
      );
      final pem = _privatePemBytes();

      final handle = await provider.store(
        referenceName: 'GIT_REPOSITORY_repo-1_SSH',
        secret: SecretBytes(pem),
      );
      expect(handle, 'GIT_REPOSITORY_repo-1_SSH');

      final read = await provider.read(referenceName: handle);
      // Booleans, not operands: see [_sameBytes].
      expect(_sameBytes(read.bytes, pem), isTrue);
      // And the bytes are a loadable SSH identity, not just equal bytes.
      expect(
        utf8
            .decode(read.bytes)
            .startsWith('-----BEGIN OPENSSH PRIVATE KEY-----'),
        isTrue,
      );
    });

    test(
      'writes owner-only and verifies the mode rather than assuming it',
      () async {
        final dir = '${scratch.path}/secretstore';
        final provider = LocalFileSecretProvider(directoryPath: dir);
        await provider.store(
          referenceName: 'GIT_REPOSITORY_repo-1_SSH',
          secret: SecretBytes(_privatePemBytes()),
        );
        expect(PosixFileModes.readOctal(dir), PosixFileModes.directory);
        expect(
          PosixFileModes.readOctal('$dir/GIT_REPOSITORY_repo-1_SSH'),
          PosixFileModes.file,
          reason: '0644 here would be every local account reading a deploy key',
        );
        // No umask was set to anything unusual by this process, so if the code were
        // relying on the umask rather than chmod this would read 644 or 664.
        expect(
          PosixFileModes.readOctal('$dir/GIT_REPOSITORY_repo-1_SSH'),
          '600',
        );
      },
    );

    test('never leaves the temp file it writes through', () async {
      final dir = '${scratch.path}/secretstore';
      final provider = LocalFileSecretProvider(directoryPath: dir);
      await provider.store(
        referenceName: 'GIT_REPOSITORY_repo-1_SSH',
        secret: SecretBytes(_privatePemBytes()),
      );
      expect(
        Directory(dir).listSync().whereType<File>().map((f) => f.path).toList(),
        ['$dir/GIT_REPOSITORY_repo-1_SSH'],
      );
    });

    test('reading an absent reference is a typed, secretless error', () async {
      final provider = LocalFileSecretProvider(
        directoryPath: '${scratch.path}/s',
      );
      await expectLater(
        provider.read(referenceName: 'GIT_REPOSITORY_absent_SSH'),
        throwsA(
          isA<SecretStoreException>()
              .having((e) => e.operation, 'operation', 'read')
              .having(
                (e) => e.toString(),
                'toString',
                allOf(
                  contains('GIT_REPOSITORY_absent_SSH'),
                  isNot(contains('PRIVATE KEY')),
                ),
              ),
        ),
      );
    });

    test('destroy removes the material and is idempotent', () async {
      final dir = '${scratch.path}/secretstore';
      final provider = LocalFileSecretProvider(directoryPath: dir);
      await provider.store(
        referenceName: 'GIT_REPOSITORY_repo-1_SSH',
        secret: SecretBytes(_privatePemBytes()),
      );
      await provider.destroy(referenceName: 'GIT_REPOSITORY_repo-1_SSH');
      expect(File('$dir/GIT_REPOSITORY_repo-1_SSH').existsSync(), isFalse);
      // ADR 0018 A2: revocation destroys the handle. A retry after a partial
      // failure has to be able to complete.
      await provider.destroy(referenceName: 'GIT_REPOSITORY_repo-1_SSH');
      await provider.destroy(referenceName: 'GIT_REPOSITORY_never_existed_SSH');
    });

    test('a store failure is reported without the material', () async {
      // A directory where the secret file must go: `writeAsBytesSync` fails and
      // the caller must still get a usable diagnostic.
      final dir = '${scratch.path}/occupied';
      Directory(dir).createSync(recursive: true);
      Directory('$dir/GIT_REPOSITORY_repo-1_SSH').createSync(recursive: true);
      final provider = LocalFileSecretProvider(directoryPath: dir);
      await expectLater(
        provider.store(
          referenceName: 'GIT_REPOSITORY_repo-1_SSH',
          secret: SecretBytes(_privatePemBytes()),
        ),
        throwsA(
          isA<SecretStoreException>()
              .having((e) => e.operation, 'operation', 'store')
              .having(
                (e) => e.toString(),
                'toString',
                isNot(contains('BEGIN')),
              ),
        ),
      );
    });
  });

  group('a malformed secret at rest cannot reach a log line (B-1)', () {
    // B-1, and why this group exists at all.
    //
    // The body of a Secret Manager `versions/latest:access` response is
    // `{"name":…,"payload":{"data":"<base64 PEM>"}}` — the key is a SUBSTRING of
    // the text being parsed — and both `dart:convert` decoders embed an excerpt of
    // their input in the `FormatException` they throw. Unguarded, a malformed 2xx
    // body turned a malformed secret **at rest** into base64 private-key material
    // in an exception message, which the endpoint wrote to the Serverpod session
    // log, which is persisted to Postgres (ADR 0018 §A2 forbids exactly that).
    //
    // `SecretBytes` could not prevent it: it protects values this code holds, and
    // that was a value a third-party exception had captured on its behalf.
    //
    // Each test below drives the REAL adapter against a REAL loopback HTTP server
    // serving a specific malformation, and asserts that neither the exception's own
    // `toString()` nor `secretlessText(...)` of it — the two shapes that reach a
    // durable record — contains the material.
    //
    // WHY THE ASSERTIONS LOOK LIKE THIS. Every check is `contains(needle) == false`
    // with a *label* in the reason, never the needle itself, and every forbidden
    // value is a substring of the material rather than the whole thing: a decoder
    // embeds only an excerpt, so a whole-value containment test would pass on the
    // precise defect it exists to catch.
    GcpSecretManagerSecretProvider providerFor(
      _StubSecretManager stub,
    ) => GcpSecretManagerSecretProvider(
      projectId: 'shipit-platform',
      // Both the data plane and the metadata server on one loopback port: the
      // adapter authenticates out of band, and a stub that serves both paths
      // means this needs no production test seam.
      apiBaseUrl: 'http://127.0.0.1:${stub.port}',
      metadataHost: '127.0.0.1:${stub.port}',
    );

    test('a truncated access body yields a typed, silent failure', () async {
      // The body of a real 2xx, cut mid-string. `jsonDecode` throws here, and its
      // message contains the excerpt shown below.
      final stub = await _StubSecretManager.start((request) async {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(_truncatedAccessBody);
      });

      final error = await _captureFailure(
        () => providerFor(stub).read(
          referenceName: 'GIT_REPOSITORY_repo-1_SSH',
        ),
      );

      expect(error, isA<SecretStoreException>());
      expect((error as SecretStoreException).operation, 'read');
      expect(error.referenceName, 'GIT_REPOSITORY_repo-1_SSH');
      expect(error.reason, contains('not JSON'));
      _expectCarriesNoMaterial(error.toString(), 'truncated access body');
      _expectCarriesNoMaterial(secretlessText(error), 'truncated access body');
    });

    test('an undecodable payload yields a typed, silent failure', () async {
      // Valid JSON, valid base64 alphabet for its first 57 characters, then a
      // character base64 does not allow. `base64.decode` throws here and its
      // message is the offending string.
      final stub = await _StubSecretManager.start((request) async {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(_badBase64AccessBody);
      });

      final error = await _captureFailure(
        () => providerFor(stub).read(
          referenceName: 'GIT_REPOSITORY_repo-1_SSH',
        ),
      );

      expect(error, isA<SecretStoreException>());
      expect((error as SecretStoreException).reason, contains('base64'));
      _expectCarriesNoMaterial(error.toString(), 'undecodable payload');
      _expectCarriesNoMaterial(secretlessText(error), 'undecodable payload');
    });

    test('a non-object access body yields a typed, silent failure', () async {
      // The shape check, which used to be a raw cast and therefore a `TypeError`.
      final stub = await _StubSecretManager.start((request) async {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('[1,2,3]');
      });

      final error = await _captureFailure(
        () => providerFor(stub).read(
          referenceName: 'GIT_REPOSITORY_repo-1_SSH',
        ),
      );
      expect(error, isA<SecretStoreException>());
      expect((error as SecretStoreException).reason, contains('JSON object'));
      _expectCarriesNoMaterial(error.toString(), 'non-object access body');
    });

    test(
      'a payload of the wrong type yields a typed, silent failure',
      () async {
        final stub = await _StubSecretManager.start((request) async {
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write('{"payload":{"data":{"not":"a string"}}}');
        });

        final error = await _captureFailure(
          () => providerFor(stub).read(
            referenceName: 'GIT_REPOSITORY_repo-1_SSH',
          ),
        );
        expect(error, isA<SecretStoreException>());
        expect(
          (error as SecretStoreException).reason,
          contains('payload.data'),
        );
        _expectCarriesNoMaterial(error.toString(), 'wrong payload type');
      },
    );

    test(
      'a service that echoes our own request body cannot get it into a message',
      () async {
        // The adversarial case, and the reason `_send` takes
        // `carriesSecretMaterial`. This request body DOES carry a real deploy
        // key, and the stub reads it back out and returns it inside Google's
        // `error.message` — the one place a third party's free text reaches this
        // adapter's exception. The refusal must therefore carry the status and
        // nothing else.
        final pem = _privatePemBytes();
        String? echoed;
        final stub = await _StubSecretManager.start((request) async {
          if (!request.uri.path.endsWith(':addVersion')) {
            // `create` carries no key bytes and must succeed, so the failure under
            // test is the one on the request that DOES carry them.
            request.response.statusCode = 200;
            return;
          }
          final body = await utf8.decoder.bind(request).join();
          echoed = RegExp(
            r'"data"\s*:\s*"([^"]*)"',
          ).firstMatch(body)?.group(1);
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'error': {
                  'message': 'invalid payload: $echoed',
                },
              }),
            );
        });

        final error = await _captureFailure(
          () => providerFor(stub).store(
            referenceName: 'GIT_REPOSITORY_repo-1_SSH',
            secret: SecretBytes(pem),
          ),
        );

        // The stub really did receive the material, so this is the echoing case
        // and not a request that never carried one.
        expect(echoed, isNotNull);
        expect(echoed!.length, greaterThan(40));
        expect(error, isA<SecretStoreException>());
        final reason = (error as SecretStoreException).reason;
        expect(reason, contains('HTTP 400'));
        expect(reason, contains('withheld'));
        _expectCarriesNoMaterial(error.toString(), 'echoed addVersion body');
        _expectCarriesNoMaterial(
          secretlessText(error),
          'echoed addVersion body',
        );
      },
    );

    test(
      'a service message is still reported when no material was sent',
      () async {
        // The other side of the same rule, so this is not "never report Google's
        // message": `create` carries no key bytes, so its diagnostic survives.
        final stub = await _StubSecretManager.start((request) async {
          request.response
            ..statusCode = 403
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'error': {
                  'message': 'permission denied on project shipit-platform',
                },
              }),
            );
        });

        final error = await _captureFailure(
          () => providerFor(stub).store(
            referenceName: 'GIT_REPOSITORY_repo-1_SSH',
            secret: SecretBytes(_privatePemBytes()),
          ),
        );
        expect(
          (error as SecretStoreException).reason,
          contains('permission denied on project shipit-platform'),
        );
        expect(error.operation, 'POST');
        _expectCarriesNoMaterial(
          error.toString(),
          'create refusal carrying no material',
        );
      },
    );
  });
}

/// Runs [body] and returns the failure it throws.
///
/// Typed as `Object` on purpose: B-1 is about an exception escaping this layer at
/// all, so the assertion must be "what came out", not "what was expected".
Future<Object> _captureFailure(
  Future<Object?> Function() body, {
  String? referenceName,
}) async {
  try {
    await body();
  } on Object catch (error) {
    return error;
  }
  throw StateError(
    'expected a failure${referenceName == null ? '' : ' for $referenceName'} '
    'and the call returned normally',
  );
}

/// The base64 payload of a real Secret Manager access response, cut mid-string.
///
/// Synthetic, and shaped so that the excerpt a `FormatException` embeds lands
/// *inside* it — which is the whole mechanism B-1 was about.
const String _truncatedAccessBody =
    '{"name":"projects/p/secrets/GIT_REPOSITORY_repo-1_SSH/versions/1",'
    '"payload":{"data":"AAAAB3NzaC1lZDI1NTE5AAAAIEXAMPLESECRETHALFBASE64'
    'MATERIALHERE';

/// Valid JSON whose `payload.data` is not valid base64.
const String _badBase64AccessBody =
    '{"payload":{"data":"AAAAB3NzaC1lZDI1NTE5AAAAIEXAMPLESECRETHALFBASE64'
    'MATERIAL!!!"}}';

/// Values that must never appear in an exception message, a log field, or a
/// durable column on any of the malformed-material paths.
///
/// Substrings of the synthetic payload rather than the payload itself: a decoder
/// embeds an excerpt, so a whole-value test would pass on the defect.
const List<String> _forbiddenMaterialFragments = [
  'AAAAB3NzaC1lZDI1NTE5AAAAIEXAMPLESECRETHALFBASE64',
  'EXAMPLESECRETHALFBASE64',
  'SECRETHALF',
  'BASE64MATERIALHERE',
  'BASE64MATERIAL!!!',
  'PRIVATE KEY',
];

/// Asserts [text] carries no fragment of the material the stub served.
///
/// [label] names the case in the failure reason. The reason never quotes a
/// forbidden value, so even a failure here prints no material.
void _expectCarriesNoMaterial(String text, String label) {
  for (final fragment in _forbiddenMaterialFragments) {
    expect(
      text.contains(fragment),
      isFalse,
      reason:
          'the $label put a fragment of the secret into an exception '
          'message, which reaches the session log and therefore Postgres',
    );
  }
}

/// A loopback HTTP server standing in for both the Secret Manager data plane and
/// the workload-identity metadata server.
///
/// Two jobs, one socket, because the adapter's auth path needs an endpoint and
/// the point of these tests is the adapter's *decode* paths. Serving the metadata
/// token here is what lets the tests run without adding a production-only
/// injection seam for a token.
class _StubSecretManager {
  _StubSecretManager._(this._server);

  final HttpServer _server;

  int get port => _server.port;

  static Future<_StubSecretManager> start(
    Future<void> Function(HttpRequest request) handler,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final stub = _StubSecretManager._(server);
    unawaited(
      server.forEach((request) async {
        try {
          if (request.uri.path.contains('/computeMetadata/')) {
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType.json
              ..write(
                jsonEncode({
                  'access_token': 'stub-workload-identity-token',
                  'expires_in': 3600,
                }),
              );
          } else {
            await handler(request);
          }
        } finally {
          await request.response.close();
        }
      }),
    );
    return stub;
  }

  Future<void> close() => _server.close(force: true);
}
