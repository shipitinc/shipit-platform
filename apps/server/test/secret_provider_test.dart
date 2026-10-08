import 'dart:convert';
import 'dart:io';

import 'package:control_plane_server/src/credentials/gcp_secret_manager_secret_provider.dart';
import 'package:control_plane_server/src/credentials/local_file_secret_provider.dart';
import 'package:control_plane_server/src/credentials/posix_file_permissions.dart';
import 'package:control_plane_server/src/credentials/secret_material.dart';
import 'package:control_plane_server/src/credentials/secret_provider.dart';
import 'package:control_plane_server/src/credentials/secret_provider_resolver.dart';
import 'package:control_plane_server/src/credentials/ssh_keypair.dart';
import 'package:test/test.dart';

/// The material a round trip must preserve. A realistic PEM rather than a
/// marker string, so a store that truncated, re-encoded or refused non-ASCII
/// would be caught by the equality assertion rather than by a length check.
String _privatePem() =>
    SshKeyPair.generate(comment: 'shipit+roundtrip').privateKeyPem;

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
      final pem = _privatePem();

      final handle = await provider.store(
        referenceName: 'GIT_REPOSITORY_repo-1_SSH',
        secret: SecretBytes(utf8.encode(pem)),
      );
      expect(handle, 'GIT_REPOSITORY_repo-1_SSH');

      final read = await provider.read(referenceName: handle);
      expect(utf8.decode(read.bytes), pem);
      // And the bytes are a loadable SSH identity, not just equal bytes.
      expect(
        utf8.decode(read.bytes),
        startsWith('-----BEGIN OPENSSH PRIVATE KEY-----'),
      );
    });

    test(
      'writes owner-only and verifies the mode rather than assuming it',
      () async {
        final dir = '${scratch.path}/secretstore';
        final provider = LocalFileSecretProvider(directoryPath: dir);
        await provider.store(
          referenceName: 'GIT_REPOSITORY_repo-1_SSH',
          secret: SecretBytes(utf8.encode(_privatePem())),
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
        secret: SecretBytes(utf8.encode(_privatePem())),
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
        secret: SecretBytes(utf8.encode(_privatePem())),
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
          secret: SecretBytes(utf8.encode(_privatePem())),
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
}
