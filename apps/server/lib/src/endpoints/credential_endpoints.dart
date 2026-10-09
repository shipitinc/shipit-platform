import 'package:control_plane_server/src/credentials/credential_key_service.dart';
import 'package:control_plane_server/src/credentials/secret_material.dart';
import 'package:control_plane_server/src/credentials/secret_provider.dart';
import 'package:control_plane_server/src/credentials/secret_provider_resolver.dart';
import 'package:control_plane_server/src/credentials/secretless_error.dart';
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
///
/// THE FAILURE PATH IS THE ONE THAT MATTERS, and it is built so that no exception
/// message can reach a durable record. `StructuredLogger` writes to the Serverpod
/// session log, and `apps/server/config/test.yaml` sets
/// `sessionLogs.persistentEnabled: true` — so a line logged here is a row in
/// Postgres. This class therefore never formats `error.toString()`; it formats
/// [secretlessText], which renders only the fields of an explicitly audited
/// failure type and **suppresses the message of anything else**. See
/// `credentials/secretless_error.dart` for why `SecretBytes` was not enough on
/// its own.
class CredentialEndpoints extends Endpoint {
  @override
  bool get logSessions => true;

  CredentialEndpoints() : _environmentOverride = null;

  /// Builds an endpoint whose custody selection comes from [environment]
  /// instead of the process environment.
  ///
  /// Test-only, and a named constructor rather than a public mutable field
  /// because that is a narrower seam: a field can be reassigned at any point by
  /// anything holding the endpoint, whereas this fixes the override once, at
  /// construction, on an object nobody else can reach. Dart cannot mutate
  /// `Platform.environment` at runtime, and without this the only reachable path
  /// through this endpoint under `dart test` is the fail-closed refusal — which is
  /// worth asserting but proves nothing about the successful call.
  CredentialEndpoints.forTesting({required Map<String, String> environment})
    : _environmentOverride = Map<String, String>.unmodifiable(environment);

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

  /// Null in production, where selection comes from the process environment and
  /// is therefore whatever the deployment set.
  final Map<String, String>? _environmentOverride;

  SecretProvider _provider(Session session) =>
      _secretProvider ??= resolveSecretProvider(
        environment: _environmentOverride,
        log: (event, fields) => _record(session, event, fields),
      ).provider;

  /// Records the ADR 0018 §A1/A4 custody selection in [session].
  ///
  /// EXISTS SO THE PRECONDITION CAN BE RECORDED AT PROCESS START (M-4). ADR 0018
  /// requires fallback selection to be "a recorded precondition, not a silent
  /// default", and the selection here *is* recorded before any key can be minted —
  /// but it is recorded on the first **credential call**, so a deployment that
  /// never mints a credential records nothing, and an operator cannot answer
  /// "is QA running on the fallback?" from the log at all.
  ///
  /// Why it cannot simply be moved: the destination is a Serverpod session log, so
  /// the write needs a [Session], and a session does not exist at process start.
  /// The startup log is `stdout`, reached from `apps/server/lib/server.dart` —
  /// which is **outside this lane's `OWNED_PATHS`**, so this lane may not wire it.
  /// Hence this method: startup wiring calls it with any session, or simply
  /// constructs the endpoint and lets the first request flush it. The exact
  /// outstanding change is one call in `run()` and is recorded in this lane's
  /// report as an `AUTOMATION_OPPORTUNITY` for the `server.dart` owner.
  ///
  /// Returns the substrate so a caller can also read what was selected, and so a
  /// test can assert on it without a session.
  ///
  /// WHY `@doNotGenerate` AND NOT SOMETHING ELSE (a deliberate choice, recorded so
  /// the next reader does not "simplify" it away). Serverpod discovers endpoints by
  /// the *shape* of a public method on an `Endpoint` subclass — in
  /// `serverpod_cli`'s `EndpointMethodAnalyzer.isEndpointMethod`, a method is an
  /// endpoint when it is public, not `@doNotGenerate`, not one of the framework's
  /// own excluded names, and its first required parameter is a `Session`. This
  /// method matches that shape and is not an endpoint, so without the annotation
  /// `serverpod generate` fails outright: `Return type must be a Future or a
  /// Stream.` The annotation is the framework's own first-class mechanism for a
  /// public method that is deliberately not on the wire — serverpod documents it
  /// as "Single method: `@doNotGenerate` on the method" and uses it itself in
  /// `package:serverpod`'s own `CloudStoragePublicEndpoint`.
  ///
  /// The alternatives were rejected for concrete reasons, not taste:
  ///
  /// - **`private`** (`_recordCustodyPrecondition`) would satisfy the analyzer,
  ///   because `isEndpointMethod` returns `false` for a private method — but it
  ///   deletes the seam. This method must stay publicly callable from *outside
  ///   this library*: the integration test calls it from
  ///   `credential_key_service_postgres_test.dart`, and the whole point of it is
  ///   that the `server.dart` owner will call it from `run()`. Making it private
  ///   turns both into unreachable code and quietly reopens M-4.
  /// - **`static`** does not work at all. In `serverpod_cli` 3.4.13 — the version
  ///   this server pins — `isEndpointMethod` has no `isStatic` check (4.x added
  ///   one), so a static method with `Session` first is still discovered and still
  ///   fails. It would also lose the per-process `_secretProvider` cache and the
  ///   `_record` logger this method exists to prime.
  /// - **moving it to a non-endpoint collaborator** would duplicate the
  ///   process-singleton `_secretProvider` cache into a second home, while its
  ///   only intended caller (`run()`) holds no endpoint instance to reach a
  ///   collaborator through. That is a larger design change than this blocker
  ///   warrants.
  ///
  /// WHAT IT DELIBERATELY DOES NOT DO: change the return type. `SecretProvider` is
  /// what this actually is — a synchronous, process-scope fact. `Future` would be
  /// a lie about asynchrony, and `void` would break the documented contract that
  /// a caller can read what was selected and a test can assert on it.
  @doNotGenerate
  SecretProvider recordCustodyPrecondition(Session session) {
    try {
      return _provider(session);
    } on Object {
      // A refused selection is recorded by the endpoint that owns the refusal,
      // with the reason. Swallowing here would hide a deployment whose custody
      // substrate is unset, which is exactly the state ADR 0018 wants surfaced.
      return _UnresolvedProvider(kGcpSecretManagerProviderId);
    }
  }

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
      logger.error(
        'credential.generate.failed',
        credentialFailureLogFields(
          event: 'credential.generate.failed',
          productId: productId,
          repositoryId: repositoryId,
          error: error,
        ),
      );
      Error.throwWithStackTrace(redactUnauditedFailure(error), stackTrace);
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
  /// IT IS ALSO, PLAINLY, CLIENT-SUPPLIED AND UNAUTHENTICATED (M-5). The server
  /// independently obtains the host key and refuses to clone unless the
  /// fingerprint it computes equals the value supplied here — a real enforcer over
  /// an input the server did not produce. [confirmedBy] is free text from the same
  /// unauthenticated caller. The response carries
  /// [kHostKeyConfirmationProvenance] so no consumer of it can mistake either for
  /// something the server verified. Binding the confirmation to something the
  /// server obtained is a product decision and is not made here.
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
        'hostKeyConfirmationProvenance': kHostKeyConfirmationProvenance,
        if (verification.failureReason != null)
          'failureReason': verification.failureReason,
      });
      return verification.toJson();
    } catch (error, stackTrace) {
      logger.error(
        'credential.verify_access.failed',
        credentialFailureLogFields(
          event: 'credential.verify_access.failed',
          productId: productId,
          repositoryId: repositoryId,
          error: error,
        ),
      );
      Error.throwWithStackTrace(redactUnauditedFailure(error), stackTrace);
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
  /// assumed. See [recordCustodyPrecondition] for why this is not yet at process
  /// start.
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

/// The fields both `catch` blocks log.
///
/// A named function rather than two inline maps so that "the failure log line
/// cannot carry an exception message" is a property with a single implementation
/// and a test that can name it, instead of a convention repeated twice. The one
/// rule it encodes is that [error] is rendered by [secretlessText] and never by
/// `error.toString()`.
Map<String, Object?> credentialFailureLogFields({
  required String event,
  required String productId,
  required String repositoryId,
  required Object error,
}) => {
  'event': event,
  'productId': productId,
  'repositoryId': repositoryId,
  'error': secretlessText(error),
};

/// What [CredentialEndpoints.recordCustodyPrecondition] hands back when the
/// selection is refused.
///
/// Not a provider: there is no substrate, and inventing one would be the "silent
/// default" ADR 0018 forbids. A marker that throws on any use, so a caller that
/// ignores the refusal cannot proceed as if a provider existed.
class _UnresolvedProvider implements SecretProvider {
  const _UnresolvedProvider(this.providerId);

  @override
  final String providerId;

  @override
  bool get isDocumentedFallback => false;

  @override
  Map<String, String> describe() => {
    'provider': providerId,
    'resolved': 'false (no custody substrate is configured)',
  };

  @override
  Future<String> store({
    required String referenceName,
    required SecretBytes secret,
  }) async => throw SecretStoreException(
    referenceName: referenceName,
    providerId: providerId,
    operation: 'store',
    reason: 'no custody substrate is configured for this deployment',
  );

  @override
  Future<SecretBytes> read({required String referenceName}) async =>
      throw SecretStoreException(
        referenceName: referenceName,
        providerId: providerId,
        operation: 'read',
        reason: 'no custody substrate is configured for this deployment',
      );

  @override
  Future<void> destroy({required String referenceName}) async {}
}
