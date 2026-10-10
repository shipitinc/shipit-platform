import 'dart:io';
import 'dart:isolate';

import 'package:control_plane_server/src/baseline/baseline_onboarding_sweep.dart';
import 'package:control_plane_server/src/credentials/credential_key_service.dart';
import 'package:control_plane_server/src/credentials/repository_snapshot_acquirer.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:workflow_engine/workflow_engine.dart' show ProductGuard;
// `test` is a dev_dependency of `control_plane_server`; it is unresolved as a
// `lib/` import, which is a known cost of co-locating tests here.
// ignore: depend_on_referenced_packages
import 'package:test/test.dart';

import 'baseline_test_fixtures.dart';

/// A resolver that answers from a script, so the sweep's decision is what is
/// under test rather than a network round trip.
class _ScriptedResolver implements PinnedRevisionResolver {
  _ScriptedResolver(this.revisions);

  /// repositoryId -> revision, or absent to mean "unresolvable".
  final Map<String, String> revisions;

  final List<String> asked = [];

  @override
  Future<String?> resolve({
    required String productId,
    required String repositoryId,
  }) async {
    asked.add(repositoryId);
    return revisions[repositoryId];
  }
}

/// The text of `control_plane_service.dart`, located through package resolution
/// rather than through the working directory.
///
/// A gate that passes because it read the wrong file is worse than no gate, and
/// `dart test` may be invoked from anywhere in the workspace — so if this
/// library's own URI cannot be resolved, it refuses rather than guessing.
Future<String> _controlPlaneServiceSource() async {
  final resolved = await Isolate.resolvePackageUri(
    Uri.parse(
      'package:control_plane_server/src/services/control_plane_service.dart',
    ),
  );
  if (resolved == null) {
    throw StateError(
      'could not resolve control_plane_service.dart; refusing to assert against '
      'an unknown file',
    );
  }
  return File.fromUri(resolved).readAsString();
}

void main() {
  late RegistryFixture registry;
  late InMemoryJobStore jobStore;
  late _ScriptedResolver resolver;
  late BaselineOnboardingSweep sweep;

  setUp(() {
    registry = RegistryFixture();
    jobStore = InMemoryJobStore();
    resolver = _ScriptedResolver({'repo': kTestRevision});
    sweep = BaselineOnboardingSweep(
      engine: registry.engine,
      jobStore: jobStore,
      revisionResolver: resolver,
      clock: () => DateTime.utc(2026, 3, 1),
    );
  });

  group('onboarding dedupe key contract', () {
    test(
      'is the exact literal every already-persisted onboarding job carries',
      () {
        // THE FORMAT, PINNED. Both triggers now CALL this function —
        // `ControlPlaneService.triggerOnboarding` included — so the two cannot
        // produce two spellings of one key any more. What a change to the
        // FORMAT still risks is different and just as real: every
        // already-persisted `job.dedupeKey` was written in the old spelling, so
        // changing it here silently orphans every historical onboarding job from
        // its own dedupe lookup. This fails instead.
        expect(
          onboardingDedupeKey(
            productId: 'p',
            repositoryId: 'r',
            startingRevision: 'v',
          ),
          'onboarding:p:r:v',
        );
      },
    );

    test('the operator trigger CALLS the shared builder, not a second literal', () async {
      // `ControlPlaneService.triggerOnboarding` needs a `Session` and a database
      // to call, so this asserts on the SOURCE — which is what actually has to
      // hold, and what the literal pin above structurally cannot see. That pin is
      // satisfied by `onboardingDedupeKey`'s own OUTPUT, so it would have stayed
      // green if the service went back to interpolating the key itself, which is
      // precisely the drift this assertion exists to catch: two spellings of one
      // key let the sweep and the operator each enqueue a derivation the key
      // exists to make unique.
      final source = await _controlPlaneServiceSource();

      expect(
        source,
        contains('onboardingDedupeKey('),
        reason:
            'triggerOnboarding must build its key with the shared function the '
            'sweep uses',
      );
      expect(
        source,
        isNot(
          contains(r"'onboarding:$productId:$repositoryId:$startingRevision'"),
        ),
        reason:
            'a second, hand-written spelling of the dedupe key is the exact '
            'defect this assertion exists to prevent',
      );
    });

    test('refuses a blank identity or a blank revision', () {
      expect(
        () => onboardingDedupeKey(
          productId: '  ',
          repositoryId: 'r',
          startingRevision: 'v',
        ),
        throwsArgumentError,
      );
      expect(
        () => onboardingDedupeKey(
          productId: 'p',
          repositoryId: 'r',
          startingRevision: '',
        ),
        throwsArgumentError,
        reason: 'an empty revision would silently mean "whatever HEAD is now"',
      );
    });

    test(
      'the definition reuses the existing JobType rather than adding one',
      () {
        expect(onboardProductDefinition.jobType, JobType.onboardProduct);
        expect(onboardProductDefinition.jobType.wire, 'onboard_product');
        expect(
          JobType.values,
          contains(JobType.onboardProduct),
          reason:
              'the enum member predates this change; nothing here added one',
        );
      },
    );

    test('the job factory and the key agree with each other', () {
      final job = onboardingJob(
        jobId: 'jb-1',
        productId: 'p',
        repositoryId: 'r',
        startingRevision: 'v',
        now: DateTime.utc(2026, 3, 1),
      );
      expect(job.jobType, JobType.onboardProduct);
      expect(job.state, JobState.queued);
      expect(
        job.dedupeKey,
        onboardingDedupeKey(
          productId: 'p',
          repositoryId: 'r',
          startingRevision: 'v',
        ),
      );
      expect(job.workItemId, 'onboarding-p');
      expect(
        job.instruction,
        isNot(contains('shipit')),
        reason: 'the instruction must not name a product',
      );
    });
  });

  group('SnapshotPinnedRevisionResolver', () {
    /// A resolver over the REAL acquirer, so each refusal is raised by the
    /// component that owns it rather than handed to the resolver directly.
    Future<
      ({
        SnapshotPinnedRevisionResolver resolver,
        RefusingSnapshotMaterializer materializer,
      })
    >
    resolverOver({
      required RegistryFixture registry,
      required Object failure,
    }) async {
      await registry.registerProduct(productId: 'product-a');
      await seedCredential(
        registry.engine,
        productId: 'product-a',
        repositoryId: 'repo',
      );
      final materializer = RefusingSnapshotMaterializer(failure);
      return (
        resolver: SnapshotPinnedRevisionResolver(
          RepositorySnapshotAcquirer(
            engine: registry.engine,
            credentialKeyService: CredentialKeyService(
              engine: registry.engine,
              secretProvider: RecordingSecretProvider(),
              verifier: ScriptedAccessVerifier(
                committedRevision: kTestRevision,
              ),
            ),
            materializer: materializer,
          ),
        ),
        materializer: materializer,
      );
    }

    test(
      'a snapshot tree this process could not remove is an INCIDENT, not a skip',
      () async {
        // THE N-2 REGRESSION. `SshPinnedSnapshotMaterializer` raises
        // `BaselineSnapshotCleanupException` when the scratch tree holding the
        // deploy key's identity file cannot be deleted, and its own contract
        // says that tree is an incident and never a result. The resolver caught
        // it under a blanket `on Object` and returned `null`, which the sweep
        // records as `PINNED_REVISION_UNRESOLVABLE` — a skip it deliberately
        // declines to log loudly. A leaked /tmp tree containing a private deploy
        // key therefore laundered itself into an ordinary "this repository has
        // no readable head yet", every pass, for ever.
        final registry = RegistryFixture();
        final over = await resolverOver(
          registry: registry,
          failure: const BaselineSnapshotCleanupException(
            '/tmp/baseline_snapshot_x',
          ),
        );

        await expectLater(
          over.resolver.resolve(
            productId: 'product-a',
            repositoryId: 'repo',
          ),
          throwsA(isA<BaselineSnapshotCleanupException>()),
          reason:
              'an operator has to be able to see this. A silent skip is the one '
              'outcome that makes a leaked private key unfindable.',
        );

        // The refusal came from the SNAPSHOT stage — the stage that writes the
        // deploy key's identity file into the scratch tree, and does so only
        // after the confirmed host key matched. An incident raised before that
        // point would not be a leaked key, so this pins which failure it is.
        expect(over.materializer.demandedHostKeyFingerprints, [
          kTestHostKeyFingerprint,
        ]);
      },
    );

    test(
      'the availability refusals ARE routine: they resolve to "unresolvable"',
      () async {
        // The counterpart, so the test above cannot be satisfied by refusing
        // everything. An unresolvable repository is an ordinary answer to the
        // sweep's question and must stay one.
        for (final failure in <Object>[
          const BaselineSourceUnavailableException(
            productId: 'product-a',
            repositoryId: 'repo',
            reason: 'no credential has been minted for this repository',
          ),
          const HostKeyNotIndependentlyConfirmedException(
            productId: 'product-a',
            repositoryId: 'repo',
            reason: 'no host key fingerprint has been confirmed',
          ),
          const PinnedRevisionNotAcquiredException(
            productId: 'product-a',
            repositoryId: 'repo',
            pinnedRevision: kTestRevision,
            observedRevision: 'other',
          ),
          const BaselineSnapshotMaterializationException(
            repositoryId: 'repo',
            command: 'git fetch',
            detail: 'the host refused the connection',
          ),
        ]) {
          final registry = RegistryFixture();
          final over = await resolverOver(
            registry: registry,
            failure: failure,
          );

          expect(
            await over.resolver.resolve(
              productId: 'product-a',
              repositoryId: 'repo',
            ),
            isNull,
            reason: '${failure.runtimeType} is an availability refusal',
          );
        }
      },
    );
  });

  group('BaselineOnboardingSweep', () {
    test(
      'enqueues for a product with a usable, confirmed credential',
      () async {
        await registry.registerProduct(productId: 'product-a');
        await seedCredential(
          registry.engine,
          productId: 'product-a',
          repositoryId: 'repo',
        );

        final result = await sweep.run();

        expect(result.enqueued, hasLength(1));
        final enqueued = result.enqueued.single;
        expect(enqueued.productId, 'product-a');
        expect(enqueued.repositoryId, 'repo');
        expect(enqueued.revision, kTestRevision);
        expect(enqueued.dedupeKey, 'onboarding:product-a:repo:$kTestRevision');

        final stored = await jobStore.readJob(enqueued.jobId);
        expect(stored, isNotNull);
        expect(stored!.jobType, JobType.onboardProduct);
      },
    );

    test('re-running enqueues NOTHING — idempotent', () async {
      await registry.registerProduct(productId: 'product-a');
      await seedCredential(
        registry.engine,
        productId: 'product-a',
        repositoryId: 'repo',
      );

      await sweep.run();
      final second = await sweep.run();

      expect(second.enqueued, isEmpty);
      expect(
        second.skipped.single.code,
        BaselineSweepSkipped.alreadyQueuedCode,
      );
      expect(await jobStore.listJobs(), hasLength(1));
    });

    test('does not enqueue without a credential', () async {
      await registry.registerProduct(productId: 'product-a');

      final result = await sweep.run();

      expect(result.enqueued, isEmpty);
      expect(
        result.skipped.single.code,
        BaselineSweepSkipped.noUsableCredentialCode,
      );
      expect(
        resolver.asked,
        isEmpty,
        reason: 'a product with no source must not be resolved against one',
      );
    });

    test('does not enqueue on a half-confirmed credential', () async {
      await registry.registerProduct(productId: 'product-a');
      // Confirmed host, but the credential has never proven it can connect.
      await seedCredential(
        registry.engine,
        productId: 'product-a',
        repositoryId: 'repo',
        usable: false,
      );

      final result = await sweep.run();
      expect(
        result.skipped.single.code,
        BaselineSweepSkipped.noUsableCredentialCode,
      );
    });

    test('does not enqueue once a baseline of any status exists', () async {
      await registry.registerProduct(productId: 'product-a');
      await seedCredential(
        registry.engine,
        productId: 'product-a',
        repositoryId: 'repo',
      );
      await registry.engine.proposeBaseline(
        productId: 'product-a',
        facts: const [
          BaselineFact(
            factId: 'discovery-0',
            section: BaselineSectionKey.design,
            claim: 'Already baselined.',
            provenance: Provenance.observed,
            maturity: BaselineMaturity.implemented,
          ),
        ],
      );

      final result = await sweep.run();
      expect(result.skipped.single.code, BaselineSweepSkipped.hasBaselineCode);
      expect(result.enqueued, isEmpty);
    });

    test(
      'enqueues for a BLOCKED product, so the absence stays observable',
      () async {
        await registry.registerProduct(productId: 'product-a');
        await seedCredential(
          registry.engine,
          productId: 'product-a',
          repositoryId: 'repo',
        );
        await registry.engine.transitionProduct(
          'product-a',
          to: ProductState.baselinePending,
          now: DateTime.utc(2026, 1, 4),
        );
        await registry.engine.transitionProduct(
          'product-a',
          to: ProductState.baselineBlocked,
          satisfiedGuards: const {ProductGuard.clarificationOpen},
          now: DateTime.utc(2026, 1, 5),
        );

        final result = await sweep.run();

        // The sweep DOES enqueue. The LANE is what refuses, and that refusal
        // lands on the job. Dropping baselineBlocked here would hide the gap
        // permanently — nothing would ever record that this product has no
        // baseline.
        expect(result.enqueued, hasLength(1));
        expect(
          BaselineOnboardingSweep.sweepStates,
          contains(ProductState.baselineBlocked),
        );
      },
    );

    test('reads a legacy `draft` row as what it means', () async {
      // `ProductState.draft` is parse-only and reads as `registered`. A product
      // persisted before the rename still needs a baseline, so it must be in
      // scope — otherwise the migration silently strands every such row.
      await registry.registerProduct(productId: 'product-a');
      await seedCredential(
        registry.engine,
        productId: 'product-a',
        repositoryId: 'repo',
      );
      final stored = await registry.store.readProduct('product-a');
      await registry.store.saveProduct(
        // ignore: deprecated_member_use
        stored.copyWith(state: ProductState.draft),
        expectedVersion: stored.version,
      );

      final result = await sweep.run();
      expect(result.enqueued, hasLength(1));
    });

    test('does not even CONSIDER a governed product', () async {
      await registry.registerProduct(productId: 'product-a');
      await seedCredential(
        registry.engine,
        productId: 'product-a',
        repositoryId: 'repo',
      );
      expect((await sweep.run()).enqueued, hasLength(1));

      // A governed product already has what this produces. The row is written
      // directly because `registered -> governed` is not a legal edge, and the
      // point of the test is the sweep's state filter, not the transition graph.
      final stored = await registry.store.readProduct('product-a');
      await registry.store.saveProduct(
        stored.copyWith(state: ProductState.governed),
        expectedVersion: stored.version,
      );

      final next = await sweep.run();
      expect(
        next.considered,
        0,
        reason:
            'a governed product is out of scope before any conjunct is '
            'evaluated',
      );
      expect(next.enqueued, isEmpty);
      expect(
        resolver.asked,
        hasLength(1),
        reason: 'the second pass must not have resolved a revision',
      );
    });

    test('does not enqueue when no revision can be pinned', () async {
      await registry.registerProduct(productId: 'product-a');
      await seedCredential(
        registry.engine,
        productId: 'product-a',
        repositoryId: 'repo',
      );
      resolver.revisions.clear();

      final result = await sweep.run();
      expect(
        result.skipped.single.code,
        BaselineSweepSkipped.unresolvableRevisionCode,
      );
      expect(result.enqueued, isEmpty);
    });

    test(
      'two products, two repositories, two jobs — no shared identity',
      () async {
        await registry.registerProduct(
          productId: 'product-a',
          repositoryId: 'repo-a',
        );
        await registry.registerProduct(
          productId: 'product-b',
          repositoryId: 'repo-b',
        );
        await seedCredential(
          registry.engine,
          productId: 'product-a',
          repositoryId: 'repo-a',
        );
        await seedCredential(
          registry.engine,
          productId: 'product-b',
          repositoryId: 'repo-b',
        );
        resolver.revisions['repo-a'] = kTestRevision;
        resolver.revisions['repo-b'] = 'b' * 40;

        final result = await sweep.run();

        expect(result.enqueued, hasLength(2));
        expect(
          result.enqueued.map((e) => e.dedupeKey).toSet(),
          {
            'onboarding:product-a:repo-a:$kTestRevision',
            'onboarding:product-b:repo-b:${'b' * 40}',
          },
        );
      },
    );

    test(
      'a terminal job with the same key does not block a fresh attempt',
      () async {
        await registry.registerProduct(productId: 'product-a');
        await seedCredential(
          registry.engine,
          productId: 'product-a',
          repositoryId: 'repo',
        );
        // A clock that advances, so the second attempt gets its own id rather
        // than overwriting the first — the store replaces by id, and a test that
        // could not tell the two rows apart would prove nothing.
        var tick = 0;
        final advancing = BaselineOnboardingSweep(
          engine: registry.engine,
          jobStore: jobStore,
          revisionResolver: resolver,
          clock: () => DateTime.utc(2026, 3, 1).add(Duration(seconds: tick++)),
        );

        final first = await advancing.run();
        final job = (await jobStore.readJob(first.enqueued.single.jobId))!;
        await jobStore.saveJob(job.copyWith(state: JobState.failed));

        final second = await advancing.run();
        expect(
          second.enqueued,
          hasLength(1),
          reason:
              'a terminal job has nothing left to do; the same derivation '
              'may be attempted again',
        );
        expect(
          second.enqueued.single.jobId,
          isNot(first.enqueued.single.jobId),
        );
        expect(
          second.enqueued.single.dedupeKey,
          first.enqueued.single.dedupeKey,
          reason:
              'same derivation, same key — which is what makes the terminal '
              'check necessary rather than incidental',
        );
        expect(await jobStore.listJobs(), hasLength(2));
      },
    );
  });
}
