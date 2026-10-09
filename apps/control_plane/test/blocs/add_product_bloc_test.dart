import 'dart:io';

import 'package:control_plane/data/control_plane_repository.dart';
import 'package:control_plane/data/operator_attestation.dart';
import 'package:control_plane/features/products/add_product_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/unimplemented_repository_apis.dart';

/// Tokens whose presence anywhere under `apps/control_plane/lib` means the
/// client is generating key material itself, which it must never do.
///
/// Executable rather than a reviewer's memory: the mock that made this lane
/// necessary formatted 32 random bytes as `ssh-ed25519 <base64>`, which SSH
/// would have rejected, and existed only to satisfy a non-null check. `dart:math`
/// is included because its only use in this app was `Random.secure()` for that
/// mock, and `dart:math` has no other reason to be here.
const _forbiddenKeyGenerationTokens = <String>[
  '_generateMockKeyPair',
  '_computeFingerprint',
  'Random.secure',
  'ssh-ed25519 \$base64',
  'ed25519_edwards',
  'PointedData',
  "import 'dart:math'",
];

/// A host key fingerprint in the shape `CredentialKeyService._validatedFingerprint`
/// accepts. A real one, because the point of these tests is that the value is
/// carried end to end without being invented anywhere along the way.
const kGitHubEd25519Fingerprint =
    'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU';
const kOperatorName = 'Dana Okafor';

/// The one credential id this fake ever mints, so a test can assert that the row
/// Register leaves behind is the row the mint produced rather than a second one.
const kCredentialId = 'cred-shipit-platform-1700000000000';

/// A real ed25519 authorized-keys line shape. `generateDeployKey` never validates
/// it — the server mints it — so these tests are free to assert that whatever the
/// server returned is what the UI shows, unchanged and unmangled.
const kServerMintedPublicKey =
    'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleMintedBlobShipItPlatform '
    'shipit+shipit-platform';

/// Everything the fake repository was asked to write or read.
///
/// Recorded rather than asserted on one call at a time, because the property
/// under test — "no key material leaves the client" — is a statement about the
/// WHOLE conversation, not about one return value. A single unchecked call is
/// exactly where key material would hide.
class _CallLog {
  final List<String> calls = [];
  final List<Object?> arguments = [];

  void record(String call, [Object? argument]) {
    calls.add(call);
    arguments.add(argument);
  }

  bool get containsKeyMaterial {
    const markers = <String>[
      'PRIVATE KEY',
      'BEGIN OPENSSH',
      'privateKey',
      'private_key',
    ];
    for (final argument in arguments) {
      if (argument == null) continue;
      final rendered = argument.toString();
      for (final marker in markers) {
        if (rendered.contains(marker)) return true;
      }
    }
    return false;
  }
}

/// Stands in for the control plane with the parts the Add Product flow touches.
///
/// Models the two server facts that shape the client, because a fake that
/// ignores them would let a client regress without any test noticing:
///
///   * `generate` requires the product and its repository reference to exist —
///     `CredentialKeyService.generate` resolves the repository first — and
///     refuses otherwise. [generateDeployKey] throws in that case, as the server
///     does.
///   * `recordGeneratedCredential` is insert-only: a repository that already has
///     an active credential refuses a second mint unless it supersedes the first.
///     A second [generateDeployKey] without a supersede throws, as the engine
///     does, which is what makes "Check again must not re-mint" observable.
class _FakeRepository
    with UnimplementedRepositoryApis
    implements ControlPlaneRepository {
  _FakeRepository();

  final _CallLog log = _CallLog();

  /// Present because `implements ControlPlaneRepository` requires it, and
  /// because the repository under test bumps it on every durable write. Nothing
  /// here asserts on it — the Add Product flow has no listeners to notify.
  @override
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Durably-created products, by id.
  final Map<String, String> products = {};

  /// Durably-attached repository references, by repository id.
  final Map<String, String> repositoryUris = {};

  /// Durably-recorded credentials, by product id.
  final Map<String, List<CredentialResponse>> credentials = {};

  /// Set by a test to make the next `generate` throw, as a refused custody
  /// substrate or an unresolved repository would.
  Object? generateFailure;

  /// Set by a test to make the next `verifyAccess` throw — a host-key mismatch,
  /// or an attribution the server refuses to record.
  Object? verifyFailure;

  /// Set by a test to make the next `verifyAccess` succeed.
  bool verificationSucceeds = true;

  /// What the next successful `verifyAccess` reports.
  String verificationStatus = 'verified';

  @override
  Future<ProductDetailResponse> createProduct({
    required String productId,
    required String name,
    String? description,
    required String manifestJson,
    String? manifestVersion,
  }) async {
    log.record('createProduct', productId);
    products[productId] = name;
    return _detail(productId, name);
  }

  @override
  Future<void> addRepositoryReference({
    required String productId,
    required String repositoryId,
    required String uri,
    required String kind,
    required String provider,
  }) async {
    log.record('addRepositoryReference', uri);
    if (!products.containsKey(productId)) {
      throw StateError('repository $repositoryId does not exist');
    }
    repositoryUris[repositoryId] = uri;
  }

  @override
  Future<MintedDeployKey> generateDeployKey({
    required String productId,
    required String repositoryId,
  }) async {
    log.record('generateDeployKey', repositoryId);
    final failure = generateFailure;
    if (failure != null) throw failure;
    if (!products.containsKey(productId)) {
      throw StateError('product $productId does not exist');
    }
    if (!repositoryUris.containsKey(repositoryId)) {
      throw StateError(
        'repository $repositoryId does not exist for product $productId',
      );
    }
    final existing = credentials[productId] ?? const <CredentialResponse>[];
    if (existing.isNotEmpty) {
      throw StateError(
        'repository $repositoryId already has an active credential; rotate it '
        'instead of issuing a second one',
      );
    }
    credentials[productId] = [
      CredentialResponse(
        credentialId: kCredentialId,
        repositoryId: repositoryId,
        // Deliberately a plausible secret-manager reference. The client never
        // reads it — `getProductDetail` is the only thing that carries it — and
        // the G-7 test asserts that.
        referenceName: 'GIT_REPOSITORY_${repositoryId}_SSH',
        fingerprint: 'SHA256:0mJ0FakeFingerprintOfThePublicBlob',
        algorithm: 'ed25519',
        status: 'generated',
        hostKeyStatus: 'unknown',
        host: repositoryUris[repositoryId],
        canReachRepository: false,
      ),
    ];
    return const MintedDeployKey(
      credentialId: kCredentialId,
      publicKey: kServerMintedPublicKey,
      fingerprint: 'SHA256:0mJ0FakeFingerprintOfThePublicBlob',
      algorithm: 'ed25519',
      status: 'generated',
      hostKeyStatus: 'unknown',
    );
  }

  @override
  Future<DeployKeyAccessVerification> verifyDeployKeyAccess({
    required String productId,
    required String repositoryId,
    required String hostKeyFingerprint,
    required String confirmedBy,
    String? checkedBy,
  }) async {
    // The fingerprint and the confirmer are recorded by name so a test can prove
    // they reached the server from configuration. Both are plain text — neither
    // is key material, and neither may be invented by the client.
    log.record('verifyDeployKeyAccess', '$hostKeyFingerprint | $confirmedBy');
    final failure = verifyFailure;
    if (failure != null) throw failure;
    final rows = credentials[productId] ?? const <CredentialResponse>[];
    if (rows.isEmpty) {
      throw StateError(
        'repository $repositoryId has no active credential to verify',
      );
    }
    final verified = verificationSucceeds;
    credentials[productId] = [
      CredentialResponse(
        credentialId: rows.first.credentialId,
        repositoryId: repositoryId,
        referenceName: rows.first.referenceName,
        fingerprint: rows.first.fingerprint,
        algorithm: rows.first.algorithm,
        status: verificationStatus,
        hostKeyStatus: 'confirmed',
        host: rows.first.host,
        canReachRepository: verified,
        lastFailureReason: verified
            ? null
            : 'git@github.com: Permission denied (publickey).',
      ),
    ];
    return DeployKeyAccessVerification(
      credentialId: rows.first.credentialId,
      status: verificationStatus,
      canReachRepository: verified,
      secretMaterialRemoved: verified,
      hostKeyConfirmationProvenance:
          'operator-asserted: the fingerprint was supplied by the caller',
      failureReason: verified
          ? null
          : 'git@github.com: Permission denied (publickey).',
    );
  }

  @override
  Future<ProductDetailResponse> getProductDetail(String productId) async {
    log.record('getProductDetail', productId);
    return _detail(productId, products[productId] ?? productId);
  }

  /// Rewrites a persisted credential's status behind the flow's back.
  ///
  /// Models the state Register's own check exists for: the client believes
  /// access was verified, and the durable record disagrees.
  void setPersistedStatus(String productId, String status) {
    final rows = credentials[productId];
    if (rows == null || rows.isEmpty) {
      throw StateError('no credential persisted for $productId');
    }
    credentials[productId] = [
      CredentialResponse(
        credentialId: rows.first.credentialId,
        repositoryId: rows.first.repositoryId,
        referenceName: rows.first.referenceName,
        fingerprint: rows.first.fingerprint,
        algorithm: rows.first.algorithm,
        status: status,
        hostKeyStatus: rows.first.hostKeyStatus,
        host: rows.first.host,
        canReachRepository: false,
      ),
    ];
  }

  ProductDetailResponse _detail(String productId, String name) =>
      ProductDetailResponse(
        productId: productId,
        name: name,
        state: 'registered',
        allowsDispatch: false,
        updatedAt: DateTime.utc(2026, 1, 1),
        repositories: repositoryUris.entries
            .map(
              (e) => ProductRepositoryResponse(
                repositoryId: e.key,
                uri: e.value,
                kind: 'monorepo',
                provider: 'github',
              ),
            )
            .toList(),
        credentials: credentials[productId] ?? const <CredentialResponse>[],
        activeBaselineFactCount: 0,
        pendingBaselineVerified: false,
        openClarifications: const [],
        policies: const [],
      );

  // Everything the Add Product flow does not touch. Present only to satisfy
  // `implements ControlPlaneRepository`; each throws so that a test which
  // accidentally reaches one fails loudly rather than receiving a plausible
  // empty answer.
  @override
  Future<OverviewResponse> getOverview() async => throw UnimplementedError();

  @override
  Future<List<ProductSummaryResponse>> listProductSummaries() async =>
      throw UnimplementedError();

  @override
  Future<List<WorkItemResponse>> listWorkItems({
    String? state,
    String? productId,
    int? limit,
  }) async => throw UnimplementedError();

  @override
  Future<List<DecisionResponse>> pendingDecisions({int? limit}) async =>
      throw UnimplementedError();

  @override
  Future<List<DecisionResponse>> recentDecisions({
    int? limit,
    int? offset,
  }) async => throw UnimplementedError();

  @override
  Future<WorkItemDetailResponse> inspectWorkItem(String workItemId) async =>
      throw UnimplementedError();

  @override
  Future<DecisionDetailResponse> inspectDecision(String workItemId) async =>
      throw UnimplementedError();

  @override
  Future<List<JobSummaryResponse>> jobsForWorkItem(String workItemId) async =>
      throw UnimplementedError();

  @override
  Future<DecisionResponse> requestLifecycleDecision({
    required String productId,
    required String action,
    bool drainInFlight = true,
  }) async => throw UnimplementedError();

  @override
  Future<DecisionResponse> resolveLifecycleDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
    bool noWorkInFlight = false,
  }) async => throw UnimplementedError();

  @override
  Future<DecisionResponse> requestPolicyAuthorisation({
    required String productId,
    required List<String> actions,
  }) async => throw UnimplementedError();

  @override
  Future<PolicyResponse> resolvePolicyAuthorisation({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
  }) async => throw UnimplementedError();

  @override
  Future<void> revokeStandingPolicy({
    required String productId,
    required String policyId,
    required String revokedBy,
  }) async => throw UnimplementedError();

  @override
  Future<void> resolveDecision({
    required String decisionId,
    required String choice,
    required String decider,
    required String rationale,
  }) async => throw UnimplementedError();
}

void main() {
  late _FakeRepository repository;
  late AddProductBloc bloc;

  const attestation = OperatorAttestation(
    hostKeyFingerprint: kGitHubEd25519Fingerprint,
    confirmedBy: kOperatorName,
  );

  AddProductBloc newBloc({OperatorAttestation? withAttestation}) =>
      AddProductBloc(
        repository: repository,
        attestation: withAttestation ?? attestation,
      );

  /// Drives the form to the point where the access check is meaningful.
  Future<void> fillForm() async {
    bloc.add(const ProductNameChanged('SHIP IT Platform'));
    bloc.add(
      const RepositoryChanged('git@github.com:shipit/shipit-platform.git'),
    );
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    repository = _FakeRepository();
    bloc = newBloc();
  });

  tearDown(() => bloc.close());

  group('canRegister — the gate that was permanently closed', () {
    test('is false before anything has been minted', () async {
      expect(bloc.state.canRegister, isFalse);
      expect(bloc.state.deployKey, isNull);
      expect(bloc.state.accessStatus, AccessStatus.notGenerated);
    });

    test('is false after a mint while access is still unproven — the regression '
        'guard for AccessStatus.verified never being written', () async {
      // Minting does not prove anything. This is the middle case the bug lived
      // in: before this lane `verified` was written nowhere, so a key existed
      // and the gate stayed shut forever, with nothing the operator could do
      // to change it.
      final unconfigured = newBloc(
        withAttestation: const OperatorAttestation(),
      );
      addTearDown(unconfigured.close);
      unconfigured.add(const ProductNameChanged('SHIP IT Platform'));
      unconfigured.add(
        const RepositoryChanged('git@github.com:shipit/shipit-platform.git'),
      );
      await Future<void>.delayed(Duration.zero);
      unconfigured.add(const CheckAccessRequested());
      await unconfigured.stream.firstWhere((s) => !s.isCheckingAccess);

      expect(unconfigured.state.deployKey, isNotNull);
      expect(unconfigured.state.accessStatus, AccessStatus.notChecked);
      expect(unconfigured.state.accessStatus, isNot(AccessStatus.verified));
      expect(unconfigured.state.canRegister, isFalse);
    });

    test('is false while a verification is in flight', () async {
      await fillForm();
      bloc.add(const CheckAccessRequested());

      final inFlight = await bloc.stream.firstWhere((s) => s.isCheckingAccess);
      expect(inFlight.accessStatus, AccessStatus.checking);
      expect(inFlight.canGenerateKey, isFalse);
      expect(inFlight.canRegister, isFalse);

      await bloc.stream.firstWhere((s) => !s.isCheckingAccess);
    });

    test('is true once verifyAccess has succeeded', () async {
      await fillForm();
      bloc.add(const CheckAccessRequested());
      await bloc.stream.firstWhere((s) => !s.isCheckingAccess);

      expect(bloc.state.accessStatus, AccessStatus.verified);
      expect(bloc.state.deployKey, isNotNull);
      expect(bloc.state.canRegister, isTrue);
    });

    test(
      'stays false when the deployment supplied no host-key confirmation',
      () async {
        // Minting does not need an attestation, so the operator still gets an
        // installable key; verifying does, so the gate must stay shut.
        final unconfigured = newBloc(
          withAttestation: const OperatorAttestation(),
        );
        addTearDown(unconfigured.close);
        unconfigured.add(const ProductNameChanged('SHIP IT Platform'));
        unconfigured.add(
          const RepositoryChanged('git@github.com:shipit/shipit-platform.git'),
        );
        await Future<void>.delayed(Duration.zero);
        unconfigured.add(const CheckAccessRequested());
        await unconfigured.stream.firstWhere((s) => !s.isCheckingAccess);

        expect(unconfigured.state.deployKey, isNotNull);
        expect(unconfigured.state.accessStatus, AccessStatus.notChecked);
        expect(
          unconfigured.state.canCheckAccess,
          isFalse,
          reason: 'with no fingerprint supplied, the check must not be offered',
        );
        expect(unconfigured.state.canRegister, isFalse);
        expect(
          repository.log.calls,
          isNot(contains('verifyDeployKeyAccess')),
          reason:
              'nothing may be asserted to the server that was not configured',
        );
      },
    );
  });

  group('Check access', () {
    test(
      'calls generate, then verifyAccess, and the successful verification is '
      'what writes AccessStatus.verified',
      () async {
        await fillForm();
        bloc.add(const CheckAccessRequested());
        await bloc.stream.firstWhere((s) => !s.isCheckingAccess);

        expect(
          repository.log.calls,
          containsAllInOrder([
            'createProduct',
            'addRepositoryReference',
            'generateDeployKey',
            'verifyDeployKeyAccess',
          ]),
        );
        expect(bloc.state.accessStatus, AccessStatus.verified);
        expect(bloc.state.canRegister, isTrue);
      },
    );

    test(
      'sends the host-key fingerprint and confirmer from configuration, not a '
      'constant in the app',
      () async {
        await fillForm();
        bloc.add(const CheckAccessRequested());
        await bloc.stream.firstWhere((s) => !s.isCheckingAccess);

        final sent =
            repository.log.arguments[repository.log.calls.indexOf(
                  'verifyDeployKeyAccess',
                )]!
                as String;
        expect(sent, contains(kGitHubEd25519Fingerprint));
        expect(sent, contains(kOperatorName));
      },
    );

    test('stores the server-minted public half verbatim', () async {
      await fillForm();
      bloc.add(const CheckAccessRequested());
      await bloc.stream.firstWhere((s) => !s.isCheckingAccess);

      expect(bloc.state.deployKey!.publicKey, kServerMintedPublicKey);
      expect(bloc.state.deployKey!.credentialId, kCredentialId);
    });

    test(
      '"Check again" re-verifies without minting a second credential',
      () async {
        await fillForm();
        bloc.add(const CheckAccessRequested());
        await bloc.stream.firstWhere((s) => !s.isCheckingAccess);

        // The engine's recordGeneratedCredential is insert-only and refuses a
        // second active credential, so a re-mint would fail server-side. "Check
        // again" must therefore skip it.
        repository.verificationSucceeds = false;
        bloc.add(const CheckAccessRequested());
        await bloc.stream.firstWhere((s) => !s.isCheckingAccess);

        expect(
          repository.log.calls.where((c) => c == 'generateDeployKey').length,
          1,
        );
        expect(bloc.state.accessStatus, AccessStatus.failed);
        expect(bloc.state.canRegister, isFalse);
      },
    );

    test(
      'a failed verification leaves canRegister false and surfaces the reason',
      () async {
        repository.verificationSucceeds = false;
        await fillForm();
        bloc.add(const CheckAccessRequested());
        await bloc.stream.firstWhere((s) => !s.isCheckingAccess);

        expect(bloc.state.accessStatus, AccessStatus.failed);
        expect(bloc.state.canRegister, isFalse);
        expect(
          bloc.state.accessFailureReason,
          contains('Permission denied (publickey)'),
        );
        // The page-level error surface replaces the whole form, so a failure with
        // a key on screen must be reported beside the key instead.
        expect(bloc.state.errorMessage, isNull);
      },
    );

    test(
      'a verification the server refuses leaves canRegister false and names the '
      'failure',
      () async {
        repository.verifyFailure = Exception(
          'HostKeyNotPresented: host github.com presented a fingerprint that '
          'does not match the confirmation',
        );
        await fillForm();
        bloc.add(const CheckAccessRequested());
        await bloc.stream.firstWhere((s) => !s.isCheckingAccess);

        expect(bloc.state.accessStatus, AccessStatus.failed);
        expect(bloc.state.canRegister, isFalse);
        expect(bloc.state.accessFailureReason, contains('HostKeyNotPresented'));
      },
    );

    test(
      'a mint that fails before any key exists reports on the page-level error '
      'surface, where the operator can actually see it',
      () async {
        repository.generateFailure = Exception(
          'no custody substrate is configured for this deployment',
        );
        await fillForm();
        bloc.add(const CheckAccessRequested());
        await bloc.stream.firstWhere((s) => !s.isCheckingAccess);

        expect(bloc.state.deployKey, isNull);
        expect(bloc.state.accessStatus, AccessStatus.failed);
        expect(bloc.state.canRegister, isFalse);
        expect(
          bloc.state.errorMessage,
          contains('no custody substrate is configured'),
        );
      },
    );
  });

  group('Register', () {
    test('leaves a credential row attached to the credential it verified, and '
        'creates no product without one', () async {
      await fillForm();
      bloc.add(const CheckAccessRequested());
      await bloc.stream.firstWhere((s) => !s.isCheckingAccess);
      bloc.add(const RegisterProductRequested());
      await bloc.stream.firstWhere((s) => !s.isRegistering);

      expect(bloc.state.productCreated, isNotNull);
      expect(bloc.state.productCreated!.productId, 'ship-it-platform');

      final attached = repository.credentials['ship-it-platform'];
      expect(attached, isNotNull, reason: 'no credential row was persisted');
      expect(attached!.length, 1);
      expect(
        attached.single.credentialId,
        bloc.state.deployKey!.credentialId,
        reason: 'the row must be the one the mint produced, not a new one',
      );
      expect(attached.single.status, 'verified');
    });

    test(
      'refuses to register when the verified credential is not attached',
      () async {
        await fillForm();
        bloc.add(const CheckAccessRequested());
        await bloc.stream.firstWhere((s) => !s.isCheckingAccess);

        // Simulate the product losing its credential between check and register
        // — the exact state Register used to leave behind.
        repository.credentials.clear();
        bloc.add(const RegisterProductRequested());
        await bloc.stream.firstWhere((s) => !s.isRegistering);

        expect(bloc.state.productCreated, isNull);
        expect(bloc.state.errorMessage, contains('not attached'));
      },
    );

    test(
      'refuses to register a credential the durable record says is not verified',
      () async {
        await fillForm();
        bloc.add(const CheckAccessRequested());
        await bloc.stream.firstWhere((s) => !s.isCheckingAccess);
        expect(bloc.state.canRegister, isTrue);

        // The client believes access was verified; the record disagrees. Only
        // Register's own read-back can catch this — `canRegister` cannot.
        repository.setPersistedStatus('ship-it-platform', 'failing');
        bloc.add(const RegisterProductRequested());
        await bloc.stream.firstWhere((s) => !s.isRegistering);

        expect(bloc.state.productCreated, isNull);
        expect(bloc.state.errorMessage, contains('not "verified"'));
      },
    );

    test('does nothing when the gate is shut', () async {
      bloc.add(const RegisterProductRequested());
      await Future<void>.delayed(Duration.zero);
      expect(repository.log.calls, isEmpty);
      expect(bloc.state.productCreated, isNull);
    });
  });

  group('no key material reaches the client', () {
    test('across the whole Check-access and Register conversation', () async {
      await fillForm();
      bloc.add(const CheckAccessRequested());
      await bloc.stream.firstWhere((s) => !s.isCheckingAccess);
      bloc.add(const RegisterProductRequested());
      await bloc.stream.firstWhere((s) => !s.isRegistering);

      expect(
        repository.log.containsKeyMaterial,
        isFalse,
        reason:
            'nothing sent to the server may carry key material: '
            '${repository.log.arguments}',
      );
      // And nothing in the rendered state holds any either. `toString` over the
      // state is the closest thing to "everything the client is holding".
      expect(bloc.state.toString(), isNot(contains('PRIVATE KEY')));
    });

    test('the client never reads the secret-manager reference (G-7)', () async {
      // `9417f8bf` gap G-7 records that the reference is itself the sensitive
      // artifact under ADR 0018 A3 and should not reach a client. The field is
      // still on the wire and still on `CredentialResponse` — removing either
      // is not this lane's decision — but `MintedDeployKey`, which is what the
      // Add Product flow reads, must not carry it.
      expect(
        const MintedDeployKey(
          credentialId: '',
          publicKey: '',
          fingerprint: '',
          algorithm: '',
          status: '',
          hostKeyStatus: '',
        ).toString(),
        isNot(contains('GIT_REPOSITORY')),
      );

      await fillForm();
      bloc.add(const CheckAccessRequested());
      await bloc.stream.firstWhere((s) => !s.isCheckingAccess);

      expect(
        bloc.state.deployKey!.toString(),
        isNot(contains('GIT_REPOSITORY')),
        reason:
            'the mint response is mapped field by field, so a reference '
            'the server sent has no path into the client state',
      );
    });
  });

  group('no client-side key generation exists', () {
    // The mock that made this lane necessary formatted 32 random bytes as
    // `ssh-ed25519 <base64>`. SSH would have rejected it, and it existed only to
    // satisfy a non-null check. Asserting its absence as an executable check is
    // stronger than a reviewer's memory of the diff.
    test('the mock generator and its helpers are gone from lib/', () {
      final lib = Directory('lib');
      expect(lib.existsSync(), isTrue, reason: 'run from apps/control_plane');

      final offenders = <String>[];
      for (final file in lib.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        for (final token in _forbiddenKeyGenerationTokens) {
          if (source.contains(token)) {
            offenders.add('${file.path}: $token');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'a deploy key is minted by the server and only the server; the '
            'client must contain no key generation at all',
      );
    });

    test('the client imports no key-generation library', () {
      final imports = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync())
          .join('\n');

      expect(imports, isNot(contains("import 'package:ed25519")));
      expect(
        imports,
        isNot(contains('Ed25519')),
        reason:
            'the client names no key algorithm to construct, only the string '
            'the server sends back as an already-minted authorized-keys line',
      );
    });
  });
}
