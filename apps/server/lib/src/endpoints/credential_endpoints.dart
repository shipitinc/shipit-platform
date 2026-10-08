import 'package:control_plane_server/src/credentials/credential_key_service.dart';
import 'package:control_plane_server/src/credentials/secret_provider.dart';
import 'package:control_plane_server/src/credentials/secret_provider_resolver.dart';
import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_human_decision_store.dart';
import 'package:control_plane_server/src/persistence/postgres_product_registry_store.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
import 'package:product_registry/product_registry.dart';
import 'package:serverpod/serverpod.dart';

import '../services/structured_logger.dart';

/// Server half of Add Product: mints repository deploy keys and proves they can
/// reach the repository (ADR 0018 §A2 / §A3).
///
/// WHY A SEPARATE ENDPOINT rather than more methods on `ProductRegistryEndpoints`.
/// Custody is a security boundary and it should be auditable as one. The methods
/// here are the only ones in the server that can cause a private key to be
/// fetched, written to disk, or offered to a transport, and keeping them in a
/// single small file means a reviewer checking "can key material leave the
/// process?" reads one file rather than hunting through a 600-line product
/// endpoint. `ProductRegistryEndpoints` keeps the product, baseline and
/// repository-reference surface, none of which touches a key.
///
/// Both methods return a `Map<String, dynamic>` whose keys are an explicit
/// whitelist in [MintedCredential.toJson] / [AccessVerification.toJson].
///
/// Both delegate: the durable engine owns credential identity, scope and status;
/// this endpoint only wires the request to it and shapes the response.
class CredentialEndpoints extends Endpoint {
  @override
  bool get logSessions => true;

  /// The custody substrate, resolved once per process.
  ///
  /// Serverpod constructs the [Endpoint] instance once, in
  /// `Endpoints.initializeEndpoints`, so a lazily-initialised field is a process
  /// singleton. That is what makes the recorded precondition a single startup
  /// fact rather than a line repeated on every mint, and it also stops the GCP
  /// adapter from building a fresh `HttpClient` — and a fresh token cache — per
  /// request. It is lazy rather than initialised in the constructor so that an
  /// unconfigured environment still *starts*: a server that refuses to boot
  /// because a credential substrate is unset would take the triage scheduler down
  /// with it, and the substrate has no bearing on triage. Instead the first
  /// credential call refuses, loudly and with nothing defaulted.
  SecretProvider? _secretProvider;

  /// Overrides the environment the custody substrate is resolved from.
  ///
  /// Null in production, where selection comes from the process environment and
  /// is therefore whatever the deployment set. A test sets this because Dart
  /// cannot mutate `Platform.environment` at runtime, and without it the only
  /// reachable path through this endpoint under `dart test` is the
  /// fail-closed refusal — which is worth asserting but proves nothing about the
  /// successful call.
  ///
  /// It is an instance field rather than a static so it cannot be set for the
  /// whole process: the blast radius of using it wrongly is one Endpoint object.
  Map<String, String>? environmentOverride;

  SecretProvider _provider(Session session) =>
      _secretProvider ??= resolveSecretProvider(
        environment: environmentOverride,
        log: (event, fields) => _record(session, event, fields),
      ).provider;

  /// Drops the memoised substrate so a changed [environmentOverride] takes
  /// effect. Test-only, for the same reason [environmentOverride] exists.
  void resetCustodyForTesting() => _secretProvider = null;

  /// Generates a real ed25519 deploy keypair for one repository.
  ///
  /// The private half is handed to the configured [SecretProvider] and is never
  /// returned, logged, or written to a column. The response carries the public
  /// authorized-keys line for the operator to install, the fingerprint, the
  /// algorithm, and the reference the private half is held under.
  ///
  /// Returns `status: "generated"`, never `verified` — access is not proved
  /// until [verifyAccess] runs a real clone.
  Future<Map<String, dynamic>> generate(
    Session session, {
    required String productId,
    required String repositoryId,
    String? credentialId,
  }) async {
    final logger = StructuredLogger(session, 'credentials');
    try {
      final provider = _provider(session);
      final credential = await _keyService(session, provider).generate(
        productId: productId,
        repositoryId: repositoryId,
        credentialId: credentialId,
      );
      logger.info('credential.generated', {
        'productId': productId,
        'repositoryId': repositoryId,
        'credentialId': credential.credentialId,
        'algorithm': credential.algorithm,
        'fingerprint': credential.fingerprint,
        'referenceName': credential.referenceName,
        'status': credential.status,
        'custodyProvider': provider.providerId,
      });
      return credential.toJson();
    } catch (error, stackTrace) {
      // `error.toString()` is safe here and only because of how the errors in
      // this directory are built: `SecretBytes` is redacted, and every
      // SecretStoreException/StateError message names a reference, a mode or a
      // path. If a future adapter throws an exception carrying a payload echo,
      // this line would put it in the Serverpod session log — which is persisted
      // to Postgres — and that is the review point for adding one.
      logger.error('credential.generate.failed', {
        'productId': productId,
        'repositoryId': repositoryId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Proves the credential reaches the repository, with a real SSH clone.
  ///
  /// [hostKeyFingerprint] is REQUIRED and is the human trust-on-first-use
  /// confirmation ADR 0018 §Decision demands: "ShipIt refuses to connect to an
  /// unrecognised host. The operator is shown the host, key type and fingerprint
  /// and must confirm it." There is deliberately no optional form — an endpoint
  /// that could clone against an unconfirmed host is the transport gap ADR 0018
  /// §Accepted risks (A2) records.
  ///
  /// This is the call that lets the client set `accessStatus = verified`, and it
  /// sets `status: "verified"` only when `git clone` actually completed.
  Future<Map<String, dynamic>> verifyAccess(
    Session session, {
    required String productId,
    required String repositoryId,
    required String hostKeyFingerprint,
    required String confirmedBy,
    String? checkedBy,
  }) async {
    final logger = StructuredLogger(session, 'credentials');
    try {
      final verification = await _keyService(session, _provider(session))
          .verifyAccess(
            productId: productId,
            repositoryId: repositoryId,
            hostKeyFingerprint: hostKeyFingerprint,
            confirmedBy: confirmedBy,
            checkedBy: checkedBy,
          );
      logger.info('credential.verify_access.completed', {
        'productId': productId,
        'repositoryId': repositoryId,
        'credentialId': verification.credentialId,
        'status': verification.status,
        'canReachRepository': verification.canReachRepository,
        'secretMaterialRemoved': verification.secretMaterialRemoved,
        if (verification.failureReason != null)
          'failureReason': verification.failureReason,
      });
      return verification.toJson();
    } catch (error, stackTrace) {
      logger.error('credential.verify_access.failed', {
        'productId': productId,
        'repositoryId': repositoryId,
        'error': error.toString(),
      });
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Builds the key service over this session's database and the selected
  /// custody substrate.
  ///
  /// Composed per call rather than held as a singleton because the store is
  /// built on a `Session`: Serverpod's session pool hands out a different session
  /// per request, and a long-lived store over one of them would pin a connection
  /// and write through a session the caller does not own.
  CredentialKeyService _keyService(Session session, SecretProvider provider) {
    final db = PersistenceDatabase(session.db);
    return CredentialKeyService(
      engine: ProductRegistryEngine(
        store: PostgresProductRegistryStore(db),
        humanDecisionStore: PostgresHumanDecisionStore(
          PostgresWorkflowStore(db),
        ),
      ),
      secretProvider: provider,
    );
  }

  /// Records the selected substrate in the session log.
  ///
  /// Logged at `warning` when the ADR 0018 §A1/A4 fallback was chosen, because
  /// that selection changes what §A3's custody guarantee means for this
  /// deployment and §Preconditions requires it to be recorded rather than
  /// assumed.
  ///
  /// It is recorded on the first credential call rather than in
  /// `apps/server/lib/server.dart`, which is outside this lane's ownership. The
  /// precondition is therefore recorded before any key can be minted; the
  /// one-line wiring that would put it in the process-start banner is
  /// outstanding — see [resolveSecretProvider].
  void _record(Session session, String event, Map<String, String> fields) {
    session.log(
      '[credentials] $event '
      '${fields.entries.map((e) => '${e.key}=${e.value}').join(' ')}',
      level: event.endsWith('fallback_selected')
          ? LogLevel.warning
          : LogLevel.info,
    );
  }
}
