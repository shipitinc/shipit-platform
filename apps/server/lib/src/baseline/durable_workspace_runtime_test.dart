import 'package:control_plane_server/src/baseline/durable_workspace_runtime.dart';
import 'package:control_plane_server/src/credentials/secret_material.dart';
import 'package:control_plane_server/src/credentials/secret_provider.dart';
import 'package:platform_contracts/platform_contracts.dart'
    show
        BaselineFact,
        BaselineMaturity,
        BaselineSectionKey,
        DurableWorkspaceDescriptor,
        ProductBaselineStatus,
        Provenance,
        RepositoryKind;
import 'package:product_registry/product_registry.dart';
// `test` is a dev_dependency of `control_plane_server`; it is unresolved as a
// `lib/` import, which is a known cost of co-locating tests here.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

/// The composition root's contract with [DurableWorkspaceRuntime].
///
/// ## What is actually under test
///
/// Not the clone — `durable_workspace_materializer_test.dart` owns that, down to
/// the files left on disk. This is the seam the composition root writes against,
/// and the failure mode it exists to prevent is a runtime that silently invents
/// somewhere to write.
///
/// ## The two refusals that matter most
///
/// Both are the same posture the baseline runtime established: a deployment that
/// has not configured something gets an explicitly UNAVAILABLE runtime whose
/// every call names the reason. Neither gets a working runtime with a guessed
/// root, because a guessed root is container-local state that is silently lost
/// on the next rebuild — which is precisely the outcome the host bind in
/// `docker/compose.qa.yaml` exists to prevent, arriving by a different route.
void main() {
  const productId = 'p-1';
  const root = '/tmp/durable-workspace-test-root';

  late InMemoryProductRegistryStore store;
  late ProductRegistryEngine engine;
  late List<Map<String, dynamic>> logged;

  void log(String event, Map<String, dynamic> data) =>
      logged.add(<String, dynamic>{'event': event, ...data});

  setUp(() async {
    store = InMemoryProductRegistryStore();
    engine = ProductRegistryEngine(
      store: store,
      humanDecisionStore: InMemoryHumanDecisionStore(),
    );
    await engine.createProduct(productId: productId, name: 'Product One');
    logged = <Map<String, dynamic>>[];
  });

  DurableWorkspaceRuntime resolve({
    String workspaceRoot = root,
    SecretProvider? custody,
    Map<String, String>? environment,
  }) => DurableWorkspaceRuntime.resolve(
    engine: engine,
    durableWorkspaceRoot: workspaceRoot,
    log: log,
    custodyProvider: custody,
    environment: environment,
  );

  group('the pinned factory signature', () {
    test(
      'resolves a configured runtime from a root and a custody substrate '
      'alone',
      () {
        // The shape `server.dart` writes against. If this stops compiling, A2's
        // composition pass stops compiling with it — which is the point of
        // pinning it here rather than in a comment.
        final runtime = resolve(
          custody: _StubCustody(),
          environment: const <String, String>{},
        );

        expect(runtime.isAvailable, isTrue);
        expect(runtime.custodyRuntimeState, 'configured');
        expect(runtime.availableReason, isNull);
        expect(runtime.workspaceRoot, root);
        expect(runtime.provisioner, isNotNull);
        expect(
          runtime.describe()['workspaceRoot'],
          root,
          reason:
              'the startup banner is where an operator reads where clones '
              'land',
        );
      },
    );

    test(
      'the startup banner states that NOTHING reclaims a clone',
      () {
        // OD-7.2 (how long a clone lives) and OD-7.3 (who deletes it) are both
        // open. A banner that said only "configured" would let a reader assume
        // a reclamation policy exists. It says so in words instead.
        final runtime = resolve(
          custody: _StubCustody(),
          environment: const <String, String>{},
        );
        final described = runtime.describe();
        expect(
          described['reclamationPolicy'],
          contains('OD-7.2'),
        );
        expect(described['reclamationPolicy'], contains('none'));
      },
    );
  });

  group('an unresolved workspace root refuses rather than guessing one', () {
    test('a blank root yields an explicitly unavailable runtime', () {
      final runtime = resolve(
        workspaceRoot: '   ',
        custody: _StubCustody(),
        environment: const <String, String>{},
      );

      expect(runtime.isAvailable, isFalse);
      expect(runtime.custodyRuntimeState, durableWorkspaceRootUnavailable);
      expect(runtime.availableReason, isNotNull);
      expect(runtime.workspaceRoot, isNull);
      expect(
        runtime.describe()['unavailableReason'],
        runtime.availableReason,
      );
      // And it says so, rather than quietly proceeding.
      expect(
        logged.map((entry) => entry['event']),
        contains('durable_workspace.root.unavailable'),
      );
    });

    test(
      'provisioning on an unavailable runtime is refused with a NAMED reason, '
      'never attempted',
      () async {
        final runtime = resolve(
          workspaceRoot: '',
          custody: _StubCustody(),
          environment: const <String, String>{},
        );
        await expectLater(
          runtime.provision(
            productId: productId,
            repositoryId: 'repo-1',
            pinnedRevision: 'f0f3494957bb90df0a1c15a9fb4734ca6e49634d',
          ),
          throwsA(isA<DurableWorkspaceRuntimeUnavailableException>()),
        );
      },
    );

    test(
      'no clone was created and no onboarding record was written by the '
      'refusal',
      () async {
        // The whole point of refusing. A product whose clone could not be made
        // has no answer to record, and a record naming a checkout that does not
        // exist is the manufactured-artifact failure this lane exists to
        // prevent.
        final runtime = resolve(
          workspaceRoot: '',
          custody: _StubCustody(),
          environment: const <String, String>{},
        );
        await expectLater(
          runtime.provision(
            productId: productId,
            repositoryId: 'repo-1',
            pinnedRevision: 'f0f3494957bb90df0a1c15a9fb4734ca6e49634d',
          ),
          throwsA(isA<Object>()),
        );
        expect(await store.readOnboardingForProduct(productId), isNull);
      },
    );
  });

  group('an unselected custody substrate is a configuration fact', () {
    test(
      'with nothing selected, the runtime is unavailable and names the '
      'variable to set',
      () {
        // `environment: {}` is what "the operator configured nothing" looks
        // like. The resolver fails closed by design; the runtime must record
        // that rather than fall back to somewhere writable.
        final runtime = resolve(environment: const <String, String>{});

        expect(runtime.isAvailable, isFalse);
        expect(runtime.custodyRuntimeState, durableWorkspaceRootUnavailable);
        expect(runtime.availableReason, contains('SHIPIT_SECRET_PROVIDER'));
        // The root is still reported, so an operator can tell "configured root,
        // no custody" from "no root at all".
        expect(runtime.workspaceRoot, root);
        expect(
          logged.map((entry) => entry['event']),
          contains('durable_workspace.custody.unavailable'),
        );
      },
    );

    test(
      'an unavailable-for-custody runtime and an unavailable-for-root runtime '
      'say DIFFERENT things',
      () {
        // Two configuration facts collapsed into one message would let an
        // operator read "this product's host key is unconfirmed" when the truth
        // is "no custody substrate is selected anywhere in this deployment".
        final noCustody = resolve(environment: const <String, String>{});
        final noRoot = resolve(
          workspaceRoot: '',
          custody: _StubCustody(),
          environment: const <String, String>{},
        );

        expect(noCustody.availableReason, isNot(noRoot.availableReason));
        expect(noCustody.workspaceRoot, isNotNull);
        expect(noRoot.workspaceRoot, isNull);
      },
    );

    test('an unknown provider id is refused, not guessed at', () {
      final runtime = resolve(
        environment: const <String, String>{
          'SHIPIT_SECRET_PROVIDER': 'not-a-real-provider',
        },
      );
      expect(runtime.isAvailable, isFalse);
    });
  });

  group('the provisioner refuses before it touches a repository', () {
    late DurableWorkspaceRuntime runtime;

    setUp(() {
      runtime = resolve(
        custody: _StubCustody(),
        environment: const <String, String>{},
      );
    });

    test('an unpinned revision is refused', () async {
      await expectLater(
        runtime.provision(
          productId: productId,
          repositoryId: 'repo-1',
          pinnedRevision: '  ',
        ),
        throwsArgumentError,
      );
    });

    test(
      'a product with a repository but no credential is refused with a NAMED '
      'reason, and writes nothing',
      () async {
        // The repository exists, so the refusal is about the CREDENTIAL rather
        // than about the repository — the distinction the reason text has to
        // make correctly, because a caller reads it to decide what to fix.
        await engine.addRepositoryReference(
          productId: productId,
          repositoryId: 'repo-1',
          kind: RepositoryKind.monorepo,
          uri: 'ssh://git@remote.test:22/org/repo.git',
        );
        await expectLater(
          runtime.provision(
            productId: productId,
            repositoryId: 'repo-1',
            pinnedRevision: 'f0f3494957bb90df0a1c15a9fb4734ca6e49634d',
          ),
          throwsA(isA<DurableWorkspaceUnavailableException>()),
        );
        expect(await store.readOnboardingForProduct(productId), isNull);
      },
    );

    test(
      'a refusal reason that looks like key material is refused to CONSTRUCT',
      () {
        // These reasons are logged and persisted. A check that the message is
        // safe to show at construction time is structural — there is exactly
        // one place to be right, and it cannot be forgotten by a future caller
        // that assembles its own reason.
        expect(
          () => DurableWorkspaceUnavailableException(
            'the host offered -----BEGIN OPENSSH PRIVATE KEY-----',
          ),
          throwsStateError,
        );
        expect(
          () => DurableWorkspaceUnavailableException(
            'the host offered ssh-ed25519 AAAA',
          ),
          throwsStateError,
        );
        expect(
          () => DurableWorkspaceUnavailableException(
            'no credential has been minted for repository repo-1',
          ),
          returnsNormally,
        );
      },
    );
  });

  group('the completion path waits for a human', () {
    test(
      'completing against a baseline that was never accepted is refused, and '
      'the record is not completed',
      () async {
        // §6.6's prohibition, made mechanical. `completeOnboarding` takes the
        // caller's word for the baseline; a durable-workspace lane is not the
        // human-acceptance path and must not be able to pre-empt it.
        final baseline = await engine.proposeBaseline(
          productId: productId,
          facts: [
            BaselineFact(
              factId: 'f-1',
              section: BaselineSectionKey.repository,
              claim: 'the monorepo is tracked in this repository',
              provenance: Provenance.observed,
              maturity: BaselineMaturity.implemented,
            ),
          ],
        );
        expect(baseline.status, ProductBaselineStatus.proposed);

        final runtime = resolve(
          custody: _StubCustody(),
          environment: const <String, String>{},
        );
        final provisioner = runtime.provisioner!;

        // Seed the record through the engine's own path, then attempt the
        // completion against the still-PROPOSED baseline.
        await engine.recordWorkspace(
          productId: productId,
          pinnedRevision: 'f0f3494957bb90df0a1c15a9fb4734ca6e49634d',
        );

        await expectLater(
          provisioner.completeOnboarding(
            productId: productId,
            pinnedRevision: 'f0f3494957bb90df0a1c15a9fb4734ca6e49634d',
            workspace: _durableDescriptor(),
            completedBaselineId: baseline.baselineId,
          ),
          throwsA(isA<DurableWorkspaceUnavailableException>()),
        );
        expect(
          (await store.readOnboardingForProduct(productId))!.completed,
          isFalse,
          reason: 'a refused completion must leave the record uncompleted',
        );
      },
    );

    test(
      'completing against a baseline that does not exist is refused',
      () async {
        final runtime = resolve(
          custody: _StubCustody(),
          environment: const <String, String>{},
        );
        await expectLater(
          runtime.provisioner!.completeOnboarding(
            productId: productId,
            pinnedRevision: 'f0f3494957bb90df0a1c15a9fb4734ca6e49634d',
            workspace: _durableDescriptor(),
            completedBaselineId: 'no-such-baseline',
          ),
          throwsA(isA<DurableWorkspaceUnavailableException>()),
        );
      },
    );
  });
}

const String _productId = 'p-1';
const String _root = '/tmp/durable-workspace-test-root';
const String _sha = 'f0f3494957bb90df0a1c15a9fb4734ca6e49634d';

/// A custody substrate that stores nothing and returns nothing.
///
/// Used only to reach the composed-runtime states; every assertion in this
/// suite either refuses before a secret is read or never gets that far.
class _StubCustody implements SecretProvider {
  @override
  String get providerId => 'test-stub';

  @override
  bool get isDocumentedFallback => false;

  @override
  Map<String, String> describe() => const {'providerId': 'test-stub'};

  @override
  Future<void> destroy({required String referenceName}) async {}

  @override
  Future<SecretBytes> read({required String referenceName}) async =>
      throw StateError('this stub never hands out key material');

  @override
  Future<String> store({
    required String referenceName,
    required SecretBytes secret,
  }) async => throw StateError('this stub never stores key material');
}

DurableWorkspaceDescriptor _durableDescriptor() => DurableWorkspaceDescriptor(
  workspaceId: 'dws-$_productId',
  productId: _productId,
  repositoryPath: '$_root/$_productId/checkout',
  startingRevision: _sha,
  createdAt: DateTime.utc(2026, 10, 13, 9),
);
