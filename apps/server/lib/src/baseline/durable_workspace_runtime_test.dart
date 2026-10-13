import 'package:control_plane_server/src/baseline/baseline_test_fixtures.dart';
import 'package:control_plane_server/src/baseline/durable_workspace_materializer.dart';
import 'package:control_plane_server/src/baseline/durable_workspace_runtime.dart';
import 'package:control_plane_server/src/credentials/secret_material.dart';
import 'package:control_plane_server/src/credentials/secret_provider.dart';
import 'package:control_plane_server/src/credentials/ssh_remote.dart';
import 'package:platform_contracts/platform_contracts.dart'
    show
        BaselineFact,
        BaselineMaturity,
        BaselineSectionKey,
        DurableWorkspaceDescriptor,
        OnboardingRecord,
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

  group(
    'R-9 — the private half is gone from memory before the clone\'s fate is decided',
    () {
      // Bytes 1..32. NOT ONE OF THEM IS ZERO, on purpose: `everyElement(0)` after
      // the wipe must be satisfiable only by a wipe, never by the fixture. A
      // material whose bytes were already zero would let this whole group pass
      // against a provisioner that never wiped anything.
      final material = List<int>.generate(32, (i) => i + 1);

      test(
        'provision() zeroes the SecretBytes it read, and the decision point saw '
        'them ALREADY zero',
        () async {
          // ## What this is, and why it had to be written
          //
          // R-9's last clause — "the private half is gone from memory before the
          // clone's fate is decided" — was the one obligation of §6.4 with no
          // assertion anywhere. Obligations 3–5 (files on disk, clone config) are
          // covered by `durable_workspace_materializer_test.dart`; the in-memory
          // one was not, and deleting `material.wipe()` from
          // `DurableWorkspaceProvisioner.provision` left every other test in the
          // repository green. That is the same blind spot the materialiser's own
          // doc names: the obligation is invisible on every success path.
          //
          // `SecretBytes.wipe()` zero-fills `_bytes` behind a public `bytes`
          // getter, so the wipe is directly observable to a caller that RETAINS
          // the object. That is what the fake below does — not by inspecting
          // production state, but by holding the reference it was already handed.
          final registry = RegistryFixture();
          await registry.registerProduct(
            productId: 'p-1',
            repositoryId: 'repo-1',
          );
          final custody = _RetainingSecretProvider(material);
          final durableMaterializer = _RetainingDurableMaterializer();

          // The decision point itself, observed rather than inferred.
          // `recordWorkspace` IS "the clone's fate is decided" — it is the one
          // durable write, and the one that decides the recorded path. The
          // witness extends the real engine and overrides only that call, so
          // the trust chain above it runs untouched and the sample is taken at
          // the exact instant R-9 talks about.
          //
          // A `finally` placed AFTER `recordWorkspace` satisfies "the bytes are
          // zero when provision() returns" perfectly and still breaks the
          // obligation. Only a sample taken here can tell those two apart.
          final witness =
              _WorkspaceWriteWitnessEngine(
                  store: registry.store,
                  humanDecisionStore: registry.decisions,
                )
                ..sample = () => custody.handouts
                    .map((secret) => List<int>.from(secret.bytes))
                    .toList();

          await seedCredential(
            witness,
            productId: 'p-1',
            repositoryId: 'repo-1',
          );

          final runtime = DurableWorkspaceRuntime.resolve(
            engine: witness,
            durableWorkspaceRoot: '/tmp/durable-workspace-r9-root',
            log: log,
            custodyProvider: custody,
            accessVerifier: ScriptedAccessVerifier(
              committedRevision: kTestRevision,
            ),
            materializer: durableMaterializer,
          );

          final descriptor = await runtime.provision(
            productId: 'p-1',
            repositoryId: 'repo-1',
            pinnedRevision: kTestRevision,
          );

          // ---- The success path really ran. ----
          //
          // Without this, a provisioner that refused before reading any secret
          // would satisfy every assertion below vacuously: no bytes were ever
          // handed out, so there were none to find un-wiped.
          expect(
            durableMaterializer.materializations,
            1,
            reason:
                'the materialiser was never reached, so nothing below can say '
                'anything about a secret that was in memory',
          );
          expect(descriptor.startingRevision, kTestRevision);
          expect(custody.handouts, isNotEmpty);
          final record = await registry.store.readOnboardingForProduct('p-1');
          expect(record, isNotNull);
          expect(record!.workspace!.requireDurable().workspaceId, 'dws-p-1');

          // ---- Non-vacuity: the key WAS there, and it was needed. ----
          //
          // The clone had to be made from real material, so the zeros asserted
          // below are a wipe rather than a fixture that started out empty.
          expect(
            durableMaterializer.bytesAsHandedOver,
            material,
            reason:
                'the materialiser was handed something other than the fixture '
                'material, so a zeroed buffer afterwards would prove nothing',
          );
          expect(
            durableMaterializer.bytesAsHandedOver,
            isNot(everyElement(0)),
            reason:
                'the fixture material contains no zero byte, so this can only '
                'fail if the buffer was already zero when the clone was made',
          );

          // ---- THE ASSERTION: the private half is gone from memory. ----
          for (final secret in custody.handouts) {
            expect(
              secret.bytes,
              everyElement(0),
              reason:
                  'a SecretBytes this provisioning read still holds key material '
                  'after provision() returned. §6.4 obligation 6 / R-9: the '
                  'private half does not outlive the call.',
            );
          }
          // And the exact object the CLONE was made from — not merely "some read
          // on this call" — so a future refactor cannot satisfy this by wiping a
          // different instance than the one the materialiser received.
          expect(
            durableMaterializer.received!.bytes,
            everyElement(0),
            reason:
                'the SecretBytes handed to the materialiser still holds key '
                'material after provision() returned',
          );

          // ---- The ORDERING: gone BEFORE the clone's fate was decided. ----
          //
          // Sampled INSIDE `recordWorkspace`, which is the decision point and
          // not a proxy for it. This is the assertion the end state cannot
          // make: a `finally` moved to after the durable write leaves the
          // buffer zeroed on return and still breaks R-9, and this fails.
          expect(
            witness.workspaceWrites,
            1,
            reason: 'the durable write never happened, so nothing was observed',
          );
          expect(
            witness.bytesAtDecisionPoint,
            isNotNull,
            reason: 'the witness never sampled the retained secret',
          );
          expect(witness.bytesAtDecisionPoint, isNotEmpty);
          for (final bytes in witness.bytesAtDecisionPoint!) {
            expect(
              bytes,
              everyElement(0),
              reason:
                  'the private half was still in memory at the instant '
                  'recordWorkspace decided the clone\'s fate. R-9 requires it '
                  'gone BEFORE, not merely before the method returns.',
            );
          }
        },
      );
    },
  );

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

/// A [ProductRegistryEngine] that samples the private half at the exact instant
/// the clone's fate is decided.
///
/// ## Why the engine and not the log
///
/// R-9's obligation is an ORDERING one — "gone from memory **before** the
/// clone's fate is decided" — and `recordWorkspace` is the decision: it is the
/// one durable write and it chooses the recorded path. Sampling anywhere else
/// cannot distinguish a correct `finally` from one moved a few lines too late,
/// because both leave the buffer zeroed by the time the caller holds the
/// descriptor.
///
/// It EXTENDS the real engine and overrides only this call, then delegates, for
/// the same reason `ScriptedAccessVerifier` extends the real verifier: the trust
/// chain above it must be the production one, or the sample is taken in a
/// system nobody runs.
class _WorkspaceWriteWitnessEngine extends ProductRegistryEngine {
  _WorkspaceWriteWitnessEngine({
    required super.store,
    required super.humanDecisionStore,
  });

  /// Set by the test to read whatever it is holding, at sample time.
  List<List<int>> Function()? sample;

  /// How many times a workspace was recorded through this engine.
  int workspaceWrites = 0;

  /// The sample taken on the most recent [recordWorkspace] call, or `null`.
  List<List<int>>? bytesAtDecisionPoint;

  @override
  Future<OnboardingRecord> recordWorkspace({
    required String productId,
    DurableWorkspaceDescriptor? workspace,
    String? pinnedRevision,
    DateTime? now,
  }) {
    workspaceWrites++;
    bytesAtDecisionPoint = sample?.call();
    return super.recordWorkspace(
      productId: productId,
      workspace: workspace,
      pinnedRevision: pinnedRevision,
      now: now,
    );
  }
}

/// A custody substrate that RETAINS every [SecretBytes] it hands out, by
/// reference.
///
/// ## Why retaining is the whole trick
///
/// `SecretBytes.wipe()` zero-fills the buffer behind a public `bytes` getter,
/// so a caller that kept the object can read the wipe directly — no production
/// state is inspected, no instrumentation is added, and nothing the provisioner
/// does can change what this provider is able to observe. It was handed the
/// object; holding it is not a probe.
///
/// This is what makes §6.4 obligation 6 testable at all. Without a retained
/// reference the only evidence the private half ever existed is the material on
/// disk, which a different test already covers; the in-memory half was
/// invisible to the whole suite.
class _RetainingSecretProvider implements SecretProvider {
  _RetainingSecretProvider(this.material);

  /// Copied into a fresh [SecretBytes] per read, exactly as a real provider
  /// would. Never stored: this provider stores nothing and mints nothing.
  final List<int> material;

  /// Every [SecretBytes] handed out, held by reference.
  final List<SecretBytes> handouts = [];

  @override
  String get providerId => 'retaining-test-provider';

  @override
  bool get isDocumentedFallback => false;

  @override
  Map<String, String> describe() => const {
    'providerId': 'retaining-test-provider',
  };

  @override
  Future<void> destroy({required String referenceName}) async {}

  @override
  Future<SecretBytes> read({required String referenceName}) async {
    final secret = SecretBytes(material);
    handouts.add(secret);
    return secret;
  }

  @override
  Future<String> store({
    required String referenceName,
    required SecretBytes secret,
  }) async => throw StateError('this provider never stores key material');
}

/// A materialiser that keeps the [SecretBytes] it was handed, and a COPY of its
/// bytes as they stood at hand-over.
///
/// The copy is the negative control: it is what proves the buffer really did
/// contain key material when the clone was made, so the post-call all-zero
/// assertion is a wipe and not an empty fixture.
class _RetainingDurableMaterializer implements DurableWorkspaceMaterializer {
  /// How many times a clone was requested.
  int materializations = 0;

  /// The exact object the provisioner handed to `materialize`, retained.
  SecretBytes? received;

  /// A copy of [received]'s bytes at the moment of hand-over.
  List<int>? bytesAsHandedOver;

  @override
  Future<DurableWorkspaceClone> materialize({
    required String productId,
    required String repositoryId,
    required SshRemote remote,
    required SecretBytes privateKeyPem,
    required String confirmedHostKeyFingerprint,
    required String pinnedRevision,
    required String productRoot,
  }) async {
    materializations++;
    received = privateKeyPem;
    bytesAsHandedOver = List<int>.from(privateKeyPem.bytes);
    return DurableWorkspaceClone(
      productId: productId,
      repositoryId: repositoryId,
      repositoryPath: '$productRoot/checkout',
      revision: pinnedRevision,
      sourceRef: remote.toSshUrl(),
      materializedAt: DateTime.utc(2026, 10, 13, 10),
    );
  }
}
