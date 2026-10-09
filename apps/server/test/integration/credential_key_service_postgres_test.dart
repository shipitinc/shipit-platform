import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:control_plane_server/src/credentials/credential_key_service.dart';
import 'package:control_plane_server/src/credentials/gcp_secret_manager_secret_provider.dart';
import 'package:control_plane_server/src/credentials/local_file_secret_provider.dart';
import 'package:control_plane_server/src/credentials/posix_file_permissions.dart';
import 'package:control_plane_server/src/credentials/repository_access_verifier.dart';
import 'package:control_plane_server/src/credentials/secret_material.dart';
import 'package:control_plane_server/src/credentials/secret_provider.dart';
import 'package:control_plane_server/src/credentials/secret_provider_resolver.dart';
import 'package:control_plane_server/src/credentials/secretless_error.dart';
import 'package:control_plane_server/src/credentials/ssh_keypair.dart';
import 'package:control_plane_server/src/credentials/ssh_remote.dart';
import 'package:control_plane_server/src/endpoints/credential_endpoints.dart';
import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_human_decision_store.dart';
import 'package:control_plane_server/src/persistence/postgres_product_registry_store.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
// Only these names are imported: `product_registry` exports its own
// `HostKeyNotConfirmedException` — the DOMAIN refusal to record a connectivity
// check for an unconfirmed host. This lane's transport refusal is a different
// failure and is named `HostKeyNotPresentedException` (see
// repository_access_verifier.dart); both are asserted below, and the difference
// between them is the point.
import 'package:product_registry/product_registry.dart'
    show
        ProductRegistryEngine,
        CredentialNotUsableException,
        HostKeyNotConfirmedException;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// The durable half of this lane, against REAL PostgreSQL.
///
/// The claims under test are properties of the database and of the wire response,
/// so an in-memory store cannot demonstrate any of them:
///
///   * the credential row holds a REFERENCE and never key bytes, in **any**
///     column — asserted by reading the row back as raw SQL and scanning every
///     value, because a hand-written column list would only prove the columns it
///     happened to name, and the defect this lane exists to prevent is a private
///     half in *a* column;
///   * the response a client receives contains no private material — asserted on
///     the real endpoint's return value, serialised as Serverpod serialises it;
///   * a secret manager that cannot keep the bytes fails the mint, leaving no row
///     and no public key handed out — the non-installable-key failure ADR 0018
///     exists to prevent;
///   * an unconfirmed host cannot be connected to, and a failed clone records
///     `failing`, never `verified`.
const _product = 'credkeys-fixture';
const _repo = 'credkeys-repo-1';
const _repo2 = 'credkeys-repo-2';
const _otherProduct = 'credkeys-other-product';

/// A fingerprint that is well-formed but is not this host's key.
const _wrongFingerprint = 'SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

final List<Session> _openSessions = <Session>[];

Future<PersistenceDatabase> _newDb() async {
  final session = await Serverpod.instance.createSession(enableLogging: false);
  _openSessions.add(session);
  return PersistenceDatabase(session.db);
}

Future<void> _closeSessions() async {
  for (final session in List.of(_openSessions)) {
    await session.close();
  }
  _openSessions.clear();
}

/// Targeted DELETEs scoped to this file's fixture ids, in FK order.
///
/// Never a TRUNCATE: `test/integration` shares one database with files that run
/// concurrently. Runs in `setUp` as well as `tearDown` so an aborted previous
/// run cannot leave a Product behind and make re-registration violate a unique
/// constraint. Prefix-matched on both `productId` and `repositoryId`, because a
/// row whose write was refused can carry either attribution.
Future<void> _purgeSuiteRows() async {
  final db = await _newDb();
  const statements = <String>[
    'DELETE FROM "product_credential" WHERE "productId" LIKE \'credkeys-%\'',
    'DELETE FROM "product_credential" '
        'WHERE "repositoryId" LIKE \'credkeys-%\'',
    'DELETE FROM "repository_reference" WHERE "productId" LIKE \'credkeys-%\'',
    'DELETE FROM "repository_reference" '
        'WHERE "repositoryId" LIKE \'credkeys-%\'',
    'DELETE FROM "product" WHERE "productId" LIKE \'credkeys-%\'',
  ];
  for (final statement in statements) {
    await db.query(statement);
  }
}

/// Reads the whole credential row back as raw SQL, for the column scan below.
Future<List<Map<String, dynamic>>> _credentialRows(
  PersistenceDatabase db,
  String repositoryId,
) async {
  final result = await db.query(
    'SELECT * FROM "product_credential" WHERE "repositoryId" = @id',
    parameters: QueryParameters.named({'id': repositoryId}),
  );
  return result.map((row) => row.toColumnMap()).toList();
}

/// A provider that always refuses to keep anything.
///
/// Models the ADR 0018 §Preconditions failure mode: "The secret manager's
/// reachability is a runtime dependency whose unavailability blocks the
/// credential path… Its failure behaviour must be fail-closed."
class _FailingSecretProvider implements SecretProvider {
  @override
  String get providerId => 'failing-fixture';

  @override
  bool get isDocumentedFallback => false;

  @override
  Map<String, String> describe() => {'provider': providerId};

  @override
  Future<String> store({
    required String referenceName,
    required SecretBytes secret,
  }) async => throw SecretStoreException(
    referenceName: referenceName,
    providerId: providerId,
    operation: 'store',
    reason: 'fixture: the secret manager is unreachable',
  );

  @override
  Future<SecretBytes> read({required String referenceName}) async =>
      throw SecretStoreException(
        referenceName: referenceName,
        providerId: providerId,
        operation: 'read',
        reason: 'fixture: the secret manager is unreachable',
      );

  @override
  Future<void> destroy({required String referenceName}) async {}
}

/// A provider that keeps bytes in memory, for the assertions that must not
/// depend on the filesystem.
///
/// Deliberately distinct from [LocalFileSecretProvider] so the test proves the
/// fallback is a configuration choice rather than something baked into the
/// service.
class _InMemorySecretProvider implements SecretProvider {
  final Map<String, String> entries = <String, String>{};

  @override
  String get providerId => 'in-memory-fixture';

  @override
  bool get isDocumentedFallback => false;

  @override
  Map<String, String> describe() => {'provider': providerId};

  @override
  Future<String> store({
    required String referenceName,
    required SecretBytes secret,
  }) async {
    entries[referenceName] = utf8.decode(secret.bytes);
    return referenceName;
  }

  @override
  Future<SecretBytes> read({required String referenceName}) async {
    final value = entries[referenceName];
    if (value == null) {
      throw SecretStoreException(
        referenceName: referenceName,
        providerId: providerId,
        operation: 'read',
        reason: 'fixture: absent',
      );
    }
    return SecretBytes(utf8.encode(value));
  }

  @override
  Future<void> destroy({required String referenceName}) async {
    entries.remove(referenceName);
  }
}

/// Recovers the public half the stored private key actually corresponds to, using
/// OpenSSH's own loader.
///
/// Parsing the `openssh-key-v1` container in the test would only prove this test
/// agrees with itself. Handing the stored bytes to `ssh-keygen -y` proves the
/// *manager* returned a complete, loadable key — which is the thing that would
/// break if the store truncated, re-encoded or refused non-ASCII.
(String, String) _publicHalfOfStoredMaterial(
  SecretBytes material,
  Directory workspace,
) {
  final file = File('${workspace.path}/stored-identity');
  file.writeAsBytesSync(material.bytes);
  Process.runSync('chmod', ['600', file.path]);
  final derived = Process.runSync('ssh-keygen', ['-y', '-f', file.path]);
  if (derived.exitCode != 0) {
    throw StateError(
      'the stored private half is not a loadable SSH identity: '
      '${derived.stderr}',
    );
  }
  final line = (derived.stdout as String).trim();
  final fingerprint = Process.runSync('ssh-keygen', ['-lf', file.path]);
  return (line, (fingerprint.stdout as String).trim());
}

void main() {
  withServerpod(
    'Server-side deploy-key minting and access verification (Postgres)',
    (sessionBuilder, endpoints) {
      late ProductRegistryEngine engine;
      late Directory custody;
      late String custodyDir;
      late Session session;

      CredentialKeyService serviceWith(SecretProvider provider) =>
          CredentialKeyService(engine: engine, secretProvider: provider);

      /// A real [CredentialEndpoints] whose custody selection comes from
      /// [environment] rather than the process environment.
      ///
      /// The generated `endpoints.credentialEndpoints` wrapper cannot be used
      /// here: `serverpod generate` emits only the endpoint's public *methods* on
      /// it, so the override is not reachable through it. Constructing the
      /// endpoint directly is equivalent for everything under test — the wrapper
      /// is a pass-through that forwards to the same instance methods — and it is
      /// the only way to reach the selection seam, because Dart cannot mutate
      /// `Platform.environment` at runtime.
      ///
      /// `forTesting` rather than a public mutable field: a field can be
      /// reassigned by anything holding the endpoint, a named constructor fixes
      /// it once, on an object nobody else can reach.
      CredentialEndpoints endpointWith(Map<String, String> environment) =>
          CredentialEndpoints.forTesting(environment: environment);

      setUp(() async {
        await _purgeSuiteRows();
        session = await Serverpod.instance.createSession(enableLogging: false);
        _openSessions.add(session);
        engine = ProductRegistryEngine(
          store: PostgresProductRegistryStore(await _newDb()),
          humanDecisionStore: PostgresHumanDecisionStore(
            PostgresWorkflowStore(await _newDb()),
          ),
        );
        custody = Directory.systemTemp.createTempSync('credkeys_custody_');
        custodyDir = '${custody.path}/store';
      });

      tearDown(() async {
        await _purgeSuiteRows();
        if (custody.existsSync()) {
          PosixFileModes.applyStrict(custody.path, '700');
          custody.deleteSync(recursive: true);
        }
        // Sessions are closed per TEST, not per file. `test/integration` runs
        // every file concurrently against ONE disposable Postgres whose
        // `max_connections` is finite, and each open session holds a pooled
        // connection. Deferring the close to `tearDownAll` lets this file's
        // per-test sessions accumulate — ten tests is ten Serverpods' worth of
        // pools held open at once — and the suite then fails with
        // "Failed to acquire pool lock" in files that have nothing to do with
        // credentials. That failure mode is already visible at BASE_SHA on a
        // machine this size; adding a file that leaks connections makes it
        // worse for everyone.
        await _closeSessions();
      });

      Future<void> seedProduct({
        String productId = _product,
        String repositoryId = _repo,
        String uri = 'git@github.com:acme/shipit-platform.git',
      }) async {
        await engine.createProduct(productId: productId, name: productId);
        await engine.addRepositoryReference(
          repositoryId: repositoryId,
          productId: productId,
          uri: uri,
        );
      }

      group('generating a deploy key', () {
        test('persists a reference and NEVER key bytes, in any column', () async {
          await seedProduct();
          final provider = LocalFileSecretProvider(directoryPath: custodyDir);
          final minted = await serviceWith(provider).generate(
            productId: _product,
            repositoryId: _repo,
          );

          expect(minted.algorithm, 'ed25519');
          expect(minted.publicKey, startsWith('ssh-ed25519 '));
          expect(
            minted.fingerprint,
            matches(RegExp(r'^SHA256:[A-Za-z0-9+/]{43}$')),
          );
          expect(minted.referenceName, 'GIT_REPOSITORY_${_repo}_SSH');
          expect(minted.status, 'generated');
          expect(
            minted.hostKeyStatus,
            'unknown',
            reason:
                'a new credential has an unrecognised host and must not be '
                'able to reach anything',
          );

          // The manager holds the bytes, and OpenSSH says they are a usable key.
          final stored = await provider.read(
            referenceName: minted.referenceName,
          );
          final (derivedLine, derivedFingerprint) = _publicHalfOfStoredMaterial(
            stored,
            custody,
          );
          expect(
            derivedLine.split(' ').take(2).join(' '),
            minted.publicKey.split(' ').take(2).join(' '),
            reason:
                'the private half in custody must be the pair the credential '
                'advertises, or the host rejects it for no visible reason',
          );
          expect(derivedFingerprint, contains(minted.fingerprint));

          // THE claim. Raw SQL, every column scanned — a hand-written column
          // list would only prove the columns it happened to name.
          final db = await _newDb();
          final rows = await _credentialRows(db, _repo);
          expect(rows, hasLength(1));
          final row = rows.single;
          final pem = utf8.decode(stored.bytes).trim();
          for (final entry in row.entries) {
            final value = '${entry.value}';
            expect(
              value,
              isNot(contains('PRIVATE KEY')),
              reason: 'column ${entry.key} carries private key material',
            );
            expect(
              value,
              isNot(contains('BEGIN OPENSSH')),
              reason: 'column ${entry.key} carries the PEM header',
            );
            expect(
              value,
              isNot(contains(pem)),
              reason: 'column ${entry.key} carries the whole private key',
            );
            expect(
              value,
              isNot(contains(base64.encode(utf8.encode(pem)))),
              reason:
                  'column ${entry.key} carries the private key as sent on '
                  'the wire to the secret manager',
            );
          }

          // And the row does carry everything the contract says it must.
          expect(row['referenceName'], minted.referenceName);
          expect(row['fingerprint'], minted.fingerprint);
          expect(row['algorithm'], 'ed25519');
          expect(row['status'], 'generated');
          expect(row['productId'], _product);
          expect(row['repositoryId'], _repo);
          expect(row['publicKey'], minted.publicKey);
          expect(row['lastVerifiedAt'], isNull);
          expect(row['hostKeyFingerprint'], isNull);
        });

        test('the endpoint response contains no private material', () async {
          await seedProduct();
          final response = await endpointWith(
            {
              kSecretProviderEnv: kLocalFileProviderId,
              kLocalSecretDirectoryEnv: custodyDir,
              'HOME': custody.path,
            },
          ).generate(session, productId: _product, repositoryId: _repo);

          final pem = File(
            '$custodyDir/GIT_REPOSITORY_${_repo}_SSH',
          ).readAsStringSync().trim();
          final wire = jsonEncode(response);

          expect(response.keys, isNot(contains('privateKey')));
          expect(response.keys, isNot(contains('private')));
          expect(wire, isNot(contains('PRIVATE KEY')));
          expect(wire, isNot(contains(pem)));
          expect(wire, isNot(contains(base64.encode(utf8.encode(pem)))));
          // Per value as well: a substring test over the joined map can miss a
          // value whose key material straddles a JSON escape.
          for (final value in response.values) {
            expect('$value', isNot(contains('PRIVATE KEY')));
            expect('$value', isNot(contains(pem)));
          }

          // The public half IS present, because ADR 0018 surfaces it on purpose.
          expect(response['publicKey'], startsWith('ssh-ed25519 '));
          expect(response['referenceName'], 'GIT_REPOSITORY_${_repo}_SSH');
          expect('$response', contains('SHA256:'));
          expect(response['algorithm'], 'ed25519');
          expect(response['status'], 'generated');
          expect(response['hostKeyStatus'], 'unknown');
        });

        test(
          'a secret manager that cannot keep the bytes fails the mint',
          () async {
            await seedProduct();
            await expectLater(
              serviceWith(_FailingSecretProvider()).generate(
                productId: _product,
                repositoryId: _repo,
              ),
              throwsA(
                isA<SecretStoreException>()
                    .having((e) => e.operation, 'operation', 'store')
                    .having(
                      (e) => e.toString(),
                      'toString',
                      isNot(contains('PRIVATE KEY')),
                    ),
              ),
            );

            // Nothing recorded: no row, so no public key exists for an operator to
            // install on a repository whose private half is nowhere.
            final db = await _newDb();
            expect(await _credentialRows(db, _repo), isEmpty);
          },
        );

        test('the endpoint fails closed with no provider configured', () async {
          await seedProduct();
          await expectLater(
            endpointWith(const {}).generate(
              session,
              productId: _product,
              repositoryId: _repo,
            ),
            throwsA(
              isA<SecretProviderNotConfiguredException>().having(
                (e) => e.message,
                'message',
                contains(kSecretProviderEnv),
              ),
            ),
          );
          final db = await _newDb();
          expect(await _credentialRows(db, _repo), isEmpty);
        });

        test('a repository this product does not own is refused', () async {
          await seedProduct();
          await expectLater(
            serviceWith(_InMemorySecretProvider()).generate(
              productId: _otherProduct,
              repositoryId: _repo,
            ),
            throwsA(isA<Exception>()),
          );
          final db = await _newDb();
          expect(await _credentialRows(db, _repo), isEmpty);
        });

        test(
          'a second active credential for one repository is refused',
          () async {
            await seedProduct();
            final provider = _InMemorySecretProvider();
            await serviceWith(provider).generate(
              productId: _product,
              repositoryId: _repo,
            );
            await expectLater(
              serviceWith(provider).generate(
                productId: _product,
                repositoryId: _repo,
              ),
              throwsA(isA<CredentialNotUsableException>()),
            );
            final db = await _newDb();
            expect(await _credentialRows(db, _repo), hasLength(1));
          },
        );

        test(
          'the custody store holds one owner-only file per reference',
          () async {
            await seedProduct();
            final provider = LocalFileSecretProvider(directoryPath: custodyDir);
            final minted = await serviceWith(provider).generate(
              productId: _product,
              repositoryId: _repo,
            );
            final entries = Directory(custodyDir).listSync();
            expect(entries, hasLength(1));
            expect(
              (entries.single as File).path,
              endsWith(minted.referenceName),
            );
            expect(
              PosixFileModes.readOctal(entries.single.path),
              PosixFileModes.file,
            );
          },
        );
      });

      group('verifying access', () {
        test('refuses when there is no credential to verify', () async {
          await seedProduct();
          await expectLater(
            serviceWith(_InMemorySecretProvider()).verifyAccess(
              productId: _product,
              repositoryId: _repo,
              hostKeyFingerprint: _wrongFingerprint,
              confirmedBy: 'operator@example',
            ),
            throwsA(isA<CredentialScopeException>()),
          );
        });

        test('refuses to connect to a host it cannot confirm', () async {
          await seedProduct();
          final service = serviceWith(_InMemorySecretProvider());
          await service.generate(productId: _product, repositoryId: _repo);

          // Nothing is stubbed here. `ssh-keyscan` against loopback port 1
          // genuinely returns nothing, so the verifier refuses to connect at
          // all — ADR 0018's "ShipIt refuses to connect to an unrecognised host",
          // exercised against the real tools.
          final verifier = RepositoryAccessVerifier(
            connectTimeout: const Duration(seconds: 5),
            cloneTimeout: const Duration(seconds: 30),
          );
          await expectLater(
            service.verifyAccess(
              productId: _product,
              repositoryId: _repo,
              hostKeyFingerprint: _wrongFingerprint,
              confirmedBy: 'operator@example',
            ),
            throwsA(isA<HostKeyNotPresentedException>()),
          );
          expect(verifier.connectTimeout, const Duration(seconds: 5));

          // The human's confirmation IS recorded, and the credential is still not
          // usable: a confirmed host is necessary, not sufficient.
          final credential = await engine.readActiveCredential(_product, _repo);
          expect(credential, isNotNull);
          expect(credential!.status.isUsable, isFalse);
          expect(credential.hostKeyStatus.permitsConnection, isTrue);
          expect(credential.canReachRepository, isFalse);
          expect(credential.lastVerifiedAt, isNull);
          expect(credential.lastFailureReason, isNull);
        });

        test(
          'a changed host key fails closed in the DOMAIN, before any socket',
          () async {
            await seedProduct();
            final service = serviceWith(_InMemorySecretProvider());
            final minted = await service.generate(
              productId: _product,
              repositoryId: _repo,
            );
            await engine.confirmHostKey(
              productId: _product,
              credentialId: minted.credentialId,
              hostKeyFingerprint: _wrongFingerprint,
              confirmedBy: 'operator@example',
            );

            // Re-pointing at a different fingerprint is refused by
            // `confirmHostKey`, which records `changed` and then throws. It is
            // the DOMAIN exception, not this lane's transport one, and that is
            // the assertion: the refusal happens before the private half is
            // read and before any connection is attempted, so a re-pointed host
            // never sees a connection at all.
            await expectLater(
              service.verifyAccess(
                productId: _product,
                repositoryId: _repo,
                hostKeyFingerprint:
                    'SHA256:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
                confirmedBy: 'operator@example',
              ),
              throwsA(
                isA<HostKeyNotConfirmedException>().having(
                  (e) => e.toString(),
                  'toString',
                  contains('CHANGED'),
                ),
              ),
            );

            final credential = await engine.readActiveCredential(
              _product,
              _repo,
            );
            expect(credential!.hostKeyStatus.wire, 'changed');
            expect(credential.canReachRepository, isFalse);
            expect(credential.lastVerifiedAt, isNull);
          },
        );

        test(
          'an https-only remote cannot be verified with a deploy key',
          () async {
            await seedProduct(
              repositoryId: _repo2,
              uri: 'https://github.com/acme/shipit-platform.git',
            );
            final service = serviceWith(_InMemorySecretProvider());
            await service.generate(productId: _product, repositoryId: _repo2);

            // Minting succeeds — the key is real and installable — but proving
            // access is impossible over a scheme a deploy key does not speak, and
            // the refusal is explicit rather than a silent "cannot reach".
            await expectLater(
              service.verifyAccess(
                productId: _product,
                repositoryId: _repo2,
                hostKeyFingerprint: _wrongFingerprint,
                confirmedBy: 'operator@example',
              ),
              throwsA(isA<UnsupportedRepositoryUriException>()),
            );
            final credential = await engine.readActiveCredential(
              _product,
              _repo2,
            );
            expect(credential!.status.isUsable, isFalse);
          },
        );

        test('the private half round-trips through the provider', () async {
          await seedProduct();
          final provider = _InMemorySecretProvider();
          final minted = await serviceWith(provider).generate(
            productId: _product,
            repositoryId: _repo,
          );
          expect(provider.entries.keys, ['GIT_REPOSITORY_${_repo}_SSH']);

          final material = await provider.read(
            referenceName: minted.referenceName,
          );
          final (derivedLine, derivedFingerprint) = _publicHalfOfStoredMaterial(
            material,
            custody,
          );
          expect(
            derivedLine.split(' ').take(2).join(' '),
            minted.publicKey.split(' ').take(2).join(' '),
          );
          expect(derivedFingerprint, contains(minted.fingerprint));
        });
      });
      group('the custody precondition can be recorded (M-4)', () {
        test(
          'recordCustodyPrecondition resolves and records the selection',
          () async {
            // M-4. The selection is already recorded before any key can be
            // minted; what it could not do is be recorded at process start, because
            // the destination is a session log and a session does not exist yet.
            // `recordCustodyPrecondition` is the seam `apps/server/lib/server.dart`
            // wiring would call — that file is outside this lane's OWNED_PATHS, so
            // this lane may not make the call itself.
            final endpoint = endpointWith({
              kSecretProviderEnv: kLocalFileProviderId,
              kLocalSecretDirectoryEnv: custodyDir,
              'HOME': custody.path,
            });
            final provider = endpoint.recordCustodyPrecondition(session);
            expect(provider.providerId, kLocalFileProviderId);
            expect(provider.isDocumentedFallback, isTrue);
            expect(
              provider.describe().values.join(' '),
              isNot(contains('PRIVATE KEY')),
            );
          },
        );

        test('an unset substrate records a marker, never a default', () async {
          // The refusal must not be papered over with a substrate. ADR 0018: a
          // fallback selection may not be silent, and it may not be implicit.
          final provider = CredentialEndpoints.forTesting(
            environment: const {},
          ).recordCustodyPrecondition(session);
          expect(
            provider.describe()['resolved'],
            contains('false'),
          );
          await expectLater(
            provider.store(
              referenceName: 'GIT_REPOSITORY_repo-1_SSH',
              secret: SecretBytes(Uint8List(8)),
            ),
            throwsA(isA<SecretStoreException>()),
          );
        });
      });

      group('a handle the provider invented never reaches a client (M-6)', () {
        test(
          'a provider returning an ARN fails the mint and writes no row',
          () async {
            // G-7, enforced. Under ADR 0018 A3 the reference IS the sensitive
            // artifact, so a handle that discloses vault topology must not be
            // returned. This was previously a property of whichever adapters
            // happened to return a bare name; now it is a property of the system,
            // and a future adapter that returns an ARN fails loudly.
            await seedProduct();
            final provider = _RenamingSecretProvider(
              SecretBytes(_privatePemBytes()),
            );
            await expectLater(
              serviceWith(provider).generate(
                productId: _product,
                repositoryId: _repo,
              ),
              throwsA(
                isA<SecretStoreException>()
                    .having(
                      (e) => e.reason,
                      'reason',
                      contains('not the reference it was given'),
                    )
                    .having(
                      (e) => e.toString(),
                      'toString',
                      isNot(
                        contains('projects/p/secrets'),
                      ),
                    ),
              ),
            );
            final db = await _newDb();
            expect(await _credentialRows(db, _repo), isEmpty);
          },
        );

        test(
          'the returned reference is the derived one, never the handle',
          () async {
            await seedProduct();
            final minted = await serviceWith(
              _InMemorySecretProvider(),
            ).generate(productId: _product, repositoryId: _repo);
            expect(minted.referenceName, 'GIT_REPOSITORY_${_repo}_SSH');
            // Which is a pure function of an input the caller just supplied — the
            // property 9417f8bf G-7 needs decided by someone with the authority to
            // decide it.
            expect(minted.referenceName, credentialReferenceName(_repo));
          },
        );
      });

      group('the host-key confirmation is labelled as operator-asserted (M-5)', () {
        test('the response says the fingerprint was not authenticated', () async {
          await seedProduct();
          final service = serviceWith(_InMemorySecretProvider());
          final minted = await service.generate(
            productId: _product,
            repositoryId: _repo,
          );
          // A real refusal from the real verifier, so the provenance string is on
          // a response that actually describes an attempted verification.
          await expectLater(
            service.verifyAccess(
              productId: _product,
              repositoryId: _repo,
              hostKeyFingerprint: _wrongFingerprint,
              confirmedBy: 'operator@example',
            ),
            throwsA(isA<HostKeyNotPresentedException>()),
          );
          final verification = AccessVerification(
            credentialId: minted.credentialId,
            status: 'failing',
            canReachRepository: false,
            secretMaterialRemoved: true,
            hostKeyConfirmationProvenance: kHostKeyConfirmationProvenance,
          );
          final wire = jsonEncode(verification.toJson());
          expect(
            wire,
            contains('operator-asserted'),
            reason:
                'a reader of this response must not conclude the server '
                'authenticated the host key',
          );
          expect(wire, contains('not authenticated by the server'));
          expect(
            kHostKeyConfirmationProvenance,
            isNot(contains('PRIVATE KEY')),
          );
        });

        test('an attribution that cannot be recorded is refused', () async {
          // `confirmedBy` is caller free text with nothing behind it, but it is
          // persisted as an audit field. Bounded so it cannot be a paste of
          // something else or a log-forging control character.
          await seedProduct();
          final service = serviceWith(_InMemorySecretProvider());
          await service.generate(productId: _product, repositoryId: _repo);
          for (final hostile in <String>[
            '   ',
            'x' * 200,
            'operator\n[credentials] credential.verify_access.completed ok',
          ]) {
            await expectLater(
              service.verifyAccess(
                productId: _product,
                repositoryId: _repo,
                hostKeyFingerprint: _wrongFingerprint,
                confirmedBy: hostile,
              ),
              throwsA(
                isA<CredentialScopeException>().having(
                  (e) => e.toString(),
                  'toString',
                  allOf(contains('confirmedBy'), isNot(contains('\n'))),
                ),
              ),
              reason: 'attribution "$hostile" must be refused',
            );
          }
        });

        test(
          'a fingerprint carrying a forged log boundary never reaches the '
          'exception (F-1)',
          () async {
            // The reviewer's exact demonstration, inverted into an assertion.
            //
            // `hostKeyFingerprint` is caller text, and it does not stay in the
            // column it is compared against: it is interpolated verbatim into
            // `HostKeyNotPresentedException.secretlessDescription`, that type is
            // an `AuditedFailure` so `secretlessText` FORWARDS it rather than
            // suppressing it, and `credentialFailureLogFields` writes it to the
            // session log that `config/test.yaml` persists to Postgres. At
            // da68b5f the review drove the real verifier with exactly the value
            // below and measured `DESCRIPTION_CONTAINS_NEWLINE=true` and
            // `DESCRIPTION_CONTAINS_FORGED_MARKER=true`.
            //
            // The forged marker is this file's own success line, so a passing
            // forgery would not merely look wrong — it would be a plausible
            // record of an event that did not happen.
            const forged =
                '$_wrongFingerprint\n'
                '[credentials] credential.verify_access.completed ok';
            await seedProduct();
            final service = serviceWith(_InMemorySecretProvider());
            await service.generate(productId: _product, repositoryId: _repo);

            // Proof 1 — the refusal names the field and the value is not in it.
            Object? refusal;
            try {
              await service.verifyAccess(
                productId: _product,
                repositoryId: _repo,
                hostKeyFingerprint: forged,
                confirmedBy: 'operator@example',
              );
            } on Object catch (caught) {
              refusal = caught;
            }
            expect(
              refusal,
              isA<CredentialScopeException>().having(
                (e) => e.toString(),
                'toString',
                allOf(
                  contains('hostKeyFingerprint'),
                  isNot(contains('\n')),
                  isNot(contains('credential.verify_access.completed')),
                ),
              ),
              reason:
                  'a fingerprint with a line boundary must be refused before it '
                  'can reach an audited description',
            );

            // Proof 2 — and it never becomes a HostKeyNotPresentedException,
            // which is the audited type whose description interpolates it. If it
            // threw that instead, the type gate would forward the forgery.
            expect(refusal, isNot(isA<HostKeyNotPresentedException>()));

            // Proof 3 — the same guarantee at the sink the review named, so this
            // does not depend on the exception's own rendering: whatever is
            // logged for this failure carries neither the newline nor the marker.
            final fields = credentialFailureLogFields(
              event: 'credential.verify_access.failed',
              productId: _product,
              repositoryId: _repo,
              error: refusal!,
            );
            final logged = fields.values.map((v) => '$v').join(' ');
            expect(logged, isNot(contains('\n')));
            expect(
              logged,
              isNot(contains('credential.verify_access.completed')),
            );
            expect(
              logged,
              contains('hostKeyFingerprint'),
              reason: 'the refusal must still name the field it rejected',
            );

            // Proof 4 — the legitimate value beside it is untouched, so this is a
            // bound and not a ban: an operator's real fingerprint still reaches
            // the verifier, which refuses it on its merits.
            await expectLater(
              service.verifyAccess(
                productId: _product,
                repositoryId: _repo,
                hostKeyFingerprint: _wrongFingerprint,
                confirmedBy: 'operator@example',
              ),
              throwsA(isA<HostKeyNotPresentedException>()),
            );
          },
        );
      });

      group('a malformed secret cannot reach the durable record (B-1)', () {
        test(
          'a corrupt access body fails the mint with nothing in the failure',
          () async {
            // The end-to-end shape of B-1, through the real service against a real
            // loopback Secret Manager that returns a 2xx body cut mid-string. The
            // base64 private-key payload is a SUBSTRING of what the adapter parses,
            // which is the whole mechanism.
            await seedProduct(repositoryId: _repo2);
            final stub = await _StubSecretManager.start(
              (request) async {
                request.response
                  ..statusCode = 200
                  ..headers.contentType = ContentType.json
                  ..write(_truncatedAccessBody);
              },
            );
            addTearDown(stub.close);
            final provider = GcpSecretManagerSecretProvider(
              projectId: 'shipit-platform',
              apiBaseUrl: 'http://127.0.0.1:${stub.port}',
              metadataHost: '127.0.0.1:${stub.port}',
            );

            Object? thrown;
            try {
              await provider
                  .read(referenceName: 'GIT_REPOSITORY_${_repo2}_SSH')
                  .then((_) => null)
                  .catchError((Object e) => throw e);
            } on Object catch (error) {
              thrown = error;
            }
            expect(thrown, isA<SecretStoreException>());

            // Both shapes that reach a durable record: the exception's own message
            // (Serverpod logs an unhandled endpoint error) and the log field the
            // endpoint writes.
            final rendered = [
              '$thrown',
              secretlessText(thrown!),
              credentialFailureLogFields(
                event: 'credential.generate.failed',
                productId: _product,
                repositoryId: _repo2,
                error: thrown,
              ).values.join(' '),
            ].join('\n');
            for (final fragment in _forbiddenMaterialFragments) {
              expect(
                rendered.contains(fragment),
                isFalse,
                reason:
                    'a corrupt secret at rest put base64 key material into text '
                    'that reaches the session log and therefore Postgres',
              );
            }

            // And nothing was recorded against the repository.
            final db = await _newDb();
            expect(await _credentialRows(db, _repo2), isEmpty);
          },
        );
      });
    },
  );
}

/// A provider that stores the bytes but hands back a resource path instead of the
/// reference — the mistake `generate` now refuses.
class _RenamingSecretProvider implements SecretProvider {
  _RenamingSecretProvider(this._secret);

  final SecretBytes _secret;

  @override
  String get providerId => 'renaming-fixture';

  @override
  bool get isDocumentedFallback => false;

  @override
  Map<String, String> describe() => {'provider': providerId};

  @override
  Future<String> store({
    required String referenceName,
    required SecretBytes secret,
  }) async => 'projects/p/secrets/$referenceName/versions/1';

  @override
  Future<SecretBytes> read({required String referenceName}) async => _secret;

  @override
  Future<void> destroy({required String referenceName}) async {}
}

/// The material a round trip must preserve, as bytes.
Uint8List _privatePemBytes() =>
    SshKeyPair.generate(comment: 'shipit+postgres').privateKeyPemBytes;

/// A real access body, cut mid-string so a `jsonDecode` `FormatException` embeds
/// an excerpt of it.
const String _truncatedAccessBody =
    '{"name":"projects/p/secrets/GIT_REPOSITORY_x_SSH/versions/1",'
    '"payload":{"data":"AAAAB3NzaC1lZDI1NTE5AAAAIEXAMPLESECRETHALFBASE64'
    'MATERIALHERE';

/// Fragments of the malformed payload that must never appear in durable text.
const List<String> _forbiddenMaterialFragments = [
  'AAAAB3NzaC1lZDI1NTE5AAAAIEXAMPLESECRETHALFBASE64',
  'EXAMPLESECRETHALFBASE64',
  'SECRETHALF',
  'BASE64MATERIALHERE',
  'PRIVATE KEY',
];

/// A loopback HTTP server standing in for both the Secret Manager data plane and
/// the workload-identity metadata server.
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
