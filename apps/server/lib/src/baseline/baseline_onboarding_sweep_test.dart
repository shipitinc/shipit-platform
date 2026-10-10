import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:control_plane_server/src/baseline/baseline_onboarding_sweep.dart';
import 'package:control_plane_server/src/credentials/credential_key_service.dart';
import 'package:control_plane_server/src/credentials/repository_snapshot_acquirer.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart'
    show ConcurrentModificationException;
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
  _ScriptedResolver(this.revisions, {Map<String, Object>? failures})
    : failures = failures ?? const {};

  /// repositoryId -> revision, or absent to mean "unresolvable".
  final Map<String, String> revisions;

  /// repositoryId -> something to RAISE instead of answering, for a product
  /// whose evaluation genuinely fails.
  ///
  /// The live failure this whole file exists for was a
  /// `ConcurrentModificationException` raised out of the acquisition, so a test
  /// that drove the incident path with a different exception would be testing a
  /// shape production has never produced.
  final Map<String, Object> failures;

  /// Every repository this resolver was asked about, in order.
  ///
  /// [asked] is the ACQUISITION COUNT. One entry is one `resolve()` call, and in
  /// production one `resolve()` call is a real SSH clone plus two credential
  /// writes — so "the second pass asked for nothing" is the fact that has to be
  /// asserted, not merely "the second pass enqueued nothing".
  final List<String> asked = [];

  int get acquisitions => asked.length;

  @override
  Future<String?> resolve({
    required String productId,
    required String repositoryId,
  }) async {
    asked.add(repositoryId);
    final failure = failures[repositoryId];
    if (failure != null) throw failure;
    return revisions[repositoryId];
  }
}

/// A resolver that parks inside [resolve] until the test releases it.
///
/// So a pass can be held OPEN — the production shape, where a real clone takes
/// about a minute against a thirty-second tick — and a second pass started
/// against it deterministically, rather than by racing two futures and hoping.
class _ParkingResolver implements PinnedRevisionResolver {
  _ParkingResolver(this.revision);

  final String revision;

  /// Completes once this resolver has been ENTERED.
  ///
  /// Awaiting this, rather than the pass itself, is what proves the first pass
  /// is mid-acquisition and not merely started — which is the only state in
  /// which an overlapping pass is the interesting one.
  final Completer<void> entered = Completer<void>();

  /// The test's release.
  final Completer<void> release = Completer<void>();

  /// Every acquisition. See [_ScriptedResolver.asked].
  int acquisitions = 0;

  @override
  Future<String?> resolve({
    required String productId,
    required String repositoryId,
  }) async {
    acquisitions++;
    if (!entered.isCompleted) entered.complete();
    await release.future;
    return revision;
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

    test('the operator trigger CALLS the shared JOB builder, not a second shape', () async {
      // `ControlPlaneService.triggerOnboarding` needs a `Session` and a database
      // to call, so this asserts on the SOURCE — which is what actually has to
      // hold, and what the literal pin above structurally cannot see. That pin is
      // satisfied by `onboardingDedupeKey`'s own OUTPUT, so it would have stayed
      // green if the service went back to interpolating the key itself, which is
      // precisely the drift this assertion exists to catch: two spellings of one
      // key let the sweep and the operator each enqueue a derivation the key
      // exists to make unique.
      //
      // CHANGED to assert `onboardingJob`, not `onboardingDedupeKey`. Both
      // triggers now build their job through ONE factory, and the service no
      // longer names the key function at all — it is reached only through that
      // factory. That is one level STRONGER than what this asserted before: the
      // key was the single-sourced half, while `maxAttempts` (`1` here against
      // the definition's `2`) and the instruction text were a second, private
      // shape for the same job type, and dedupe is by key rather than by shape,
      // so the store admitted both as distinct work.
      final source = await _controlPlaneServiceSource();

      expect(
        source,
        contains('onboardingJob('),
        reason:
            'triggerOnboarding must build its job with the shared factory the '
            'sweep uses, so the key, the instruction, the attempts bound and the '
            'work-item id have exactly one definition',
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
      expect(
        source,
        isNot(contains('onboardingDedupeKey(')),
        reason:
            'the factory owns the key format; a caller naming the key function '
            'itself is a caller that could start building part of the job again',
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

    test(
      'resolving HEAD returns the COMMITTED revision the tree reports',
      () async {
        // THE WIRING DEFECT THIS FOUND. The resolver asks for `HEAD`, and a
        // real clone reports a commit id rather than the four letters it was
        // asked for. The acquirer's equality check therefore rejected its own
        // HEAD acquisition, the resolver caught `PinnedRevisionNotAcquired`
        // as "host unreachable", and every product was skipped on every pass
        // with `PINNED_REVISION_UNRESOLVABLE` — a whole trigger that reads
        // correct and can never fire.
        //
        // It is only visible through the real acquirer with a materializer
        // that reports a commit, which is why this sits here rather than in a
        // unit test of either half.
        final registry = RegistryFixture();
        await registry.registerProduct(productId: 'product-a');
        await seedCredential(
          registry.engine,
          productId: 'product-a',
          repositoryId: 'repo',
        );
        final materializer = ScriptedSnapshotMaterializer();
        final resolver = SnapshotPinnedRevisionResolver(
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
        );

        expect(
          await resolver.resolve(productId: 'product-a', repositoryId: 'repo'),
          kTestRevision,
          reason:
              'the sweep pins jobs to the commit the remote is AT, never to the '
              'string "HEAD"',
        );
        expect(
          materializer.created.every((d) => !d.existsSync()),
          isTrue,
          reason: 'the resolver releases the tree it resolved',
        );
      },
    );

    test(
      'a real PIN is still enforced against a tree at some other commit',
      () async {
        // The counterpart, so the carve-out above cannot be satisfied by
        // dropping the check entirely. Only `HEAD` resolves; every other
        // revision must be the revision the tree reports.
        final registry = RegistryFixture();
        await registry.registerProduct(productId: 'product-a');
        await seedCredential(
          registry.engine,
          productId: 'product-a',
          repositoryId: 'repo',
        );
        final acquirer = RepositorySnapshotAcquirer(
          engine: registry.engine,
          credentialKeyService: CredentialKeyService(
            engine: registry.engine,
            secretProvider: RecordingSecretProvider(),
            verifier: ScriptedAccessVerifier(committedRevision: kTestRevision),
          ),
          materializer: ScriptedSnapshotMaterializer(),
        );

        await expectLater(
          acquirer.acquire(
            productId: 'product-a',
            repositoryId: 'repo',
            pinnedRevision: 'a-different-commit',
          ),
          throwsA(isA<PinnedRevisionNotAcquiredException>()),
          reason:
              'a lane deriving from a pin the tree is not at is a baseline of '
              'drift, which is what this exception exists to prevent',
        );
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
      // THE ONE SKIP CODE THIS CHANGE MOVES, and why.
      //
      // It used to be `DEDUPE_KEY_ALREADY_ACTIVE`. That code was honest when
      // the sweep reached the dedupe-key lookup, because it HAD resolved a
      // revision and built the key that was already taken. It no longer is: the
      // sweep now decides there is nothing to enqueue from the durable job set,
      // BEFORE resolving a revision, so it never held a dedupe key to compare.
      // Reporting the key-scoped code for a decision that never had one would
      // tell an operator the revision was read — and reading it is the ~60s
      // clone and the two credential writes this change exists to avoid.
      //
      // `DEDUPE_KEY_ALREADY_ACTIVE` is still reachable, on the two paths where a
      // key really is built: a concurrent enqueue that races the store's
      // active-state constraint, and the exact-key guard that runs after the
      // acquisition.
      expect(
        second.skipped.single.code,
        BaselineSweepSkipped.activeJobForProductCode,
      );
      expect(await jobStore.listJobs(), hasLength(1));
      // And the reason names the job an operator would go and look at, rather
      // than a key that was never built.
      expect(second.skipped.single.reason, contains('jb-baseline-product-a-'));
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

  // The tests below are the livelock. The lane was deployed to QA and ran
  // 41 passes: 22 incidents, 19 skips, zero enqueued, zero baselines, and a
  // credential that climbed from version 1 to 59 without the product state ever
  // moving. Nearly every pass failed with `Concurrent modification of cred-…`
  // raised out of the acquisition — the pass conflicting with the pass before
  // it, over a credential it had written itself.
  group('the sweep cannot livelock against itself', () {
    /// Every event the sweeps under test emit, in order, so "visible" is
    /// asserted on the log an operator greps rather than on a return value a
    /// caller may never print.
    final logger = <(String, Map<String, dynamic>)>[];

    setUp(() => logger.clear());

    BaselineOnboardingSweep sweepOver(PinnedRevisionResolver resolver) =>
        BaselineOnboardingSweep(
          engine: registry.engine,
          jobStore: jobStore,
          revisionResolver: resolver,
          clock: () => DateTime.utc(2026, 3, 1),
          log: (event, data) => logger.add((event, data)),
        );

    test('an overlapping pass does not run, and says so', () async {
      // CAUSE 1. `Timer.periodic` does not await its callback, so pass N+1
      // started while pass N was still inside its ~60s clone. Held open here
      // rather than raced, so the overlap is a fact rather than a hope.
      await registry.registerProduct(productId: 'product-a');
      await seedCredential(
        registry.engine,
        productId: 'product-a',
        repositoryId: 'repo',
      );
      final parking = _ParkingResolver(kTestRevision);
      final subject = sweepOver(parking);

      final first = subject.run();
      await parking.entered.future;

      final dropped = await subject.run();

      expect(parking.acquisitions, 1, reason: 'the dropped pass must not acquire');
      expect(dropped.overlappedPasses, 1);
      expect(dropped.considered, 0);
      expect(dropped.enqueued, isEmpty);
      expect(dropped.skipped, isEmpty);
      expect(
        dropped.incidents,
        isEmpty,
        reason:
            'a dropped tick is not a product failure. Filing it as one would '
            'invent an incident about a product nobody looked at.',
      );

      // VISIBLE, in the event an operator actually greps.
      final completed = logger
          .where((e) => e.$1 == 'baseline.sweep.completed')
          .toList();
      expect(completed, hasLength(1));
      expect(completed.single.$2['overlappedPasses'], 1);
      expect(completed.single.$2['code'], 'SWEEP_PASS_OVERLAPPED');
      expect(
        completed.single.$2['action'],
        contains('already in flight'),
        reason:
            'a dropped tick that only says "considered 0" is indistinguishable '
            'from a tick that found nothing to do — which is the shape of "the '
            'sweep is not running"',
      );

      parking.release.complete();
      final completedPass = await first;

      expect(completedPass.enqueued, hasLength(1));
      expect(completedPass.overlappedPasses, 0);
      expect(await jobStore.listJobs(), hasLength(1));

      // The guard is RELEASED. A guard taken and not given back would wedge the
      // sweep shut after the first pass, and every later tick would be
      // "overlapping" against a pass that ended long ago.
      final after = await subject.run();
      expect(
        after.overlappedPasses,
        0,
        reason: 'the guard is released when the pass ends',
      );
      expect(
        after.skipped.single.code,
        BaselineSweepSkipped.activeJobForProductCode,
      );
    },
      // A SHORT timeout, and deliberately so. Without the re-entrancy guard the
      // second `run()` above would enter the pass, reach the parking resolver and
      // await a release this test never completes — so the failure mode of a
      // missing guard is a deadlock, and this is what turns that back into a
      // reported failure in ten seconds rather than the default thirty. The body
      // is pure in-memory async with no I/O, so ten seconds is a margin and not
      // a deadline.
      timeout: Timeout(Duration(seconds: 10)),
    );

    test('a pass acquires NOTHING when the product is already queued', () async {
      // CAUSE 2. `resolve()` runs before the dedupe-key lookup, so every pass
      // paid a full clone for a product that already had a job — and paid it
      // through `verifyAccess`, which WRITES the credential row twice and bumps
      // its version, which is what made the next pass's CAS fail.
      await registry.registerProduct(productId: 'product-a');
      await seedCredential(
        registry.engine,
        productId: 'product-a',
        repositoryId: 'repo',
      );

      expect((await sweep.run()).enqueued, hasLength(1));
      expect(
        resolver.acquisitions,
        1,
        reason: 'the first pass is the one that had to acquire',
      );

      final second = await sweep.run();

      expect(
        resolver.acquisitions,
        1,
        reason:
            'ZERO acquisitions on the second pass. Not "no new job" — the '
            'acquisition count itself, because the acquisition is what costs a '
            'clone, what writes the credential, and what made the next pass '
            'conflict with this one.',
      );
      expect(second.enqueued, isEmpty);
      expect(
        second.skipped.single.code,
        BaselineSweepSkipped.activeJobForProductCode,
      );

      // And a third, and a fourth: the skip is a steady state, not a race that
      // happened to resolve favourably once.
      await sweep.run();
      expect(resolver.acquisitions, 1);
      expect(await jobStore.listJobs(), hasLength(1));
    });

    test(
      'the credential row does not move on a pass that has nothing to acquire',
      () async {
        // THE OBSERVED SYMPTOM, asserted directly on the thing that moved.
        // Over the 41 live passes the credential went from version 1 to 59
        // while the product state never advanced — every bump caused by the
        // sweep writing to a row purely to learn a revision string. Driven here
        // through the REAL acquirer, so this is the credential row the
        // acquisition would actually have written, and the clone count is the
        // real materializer's.
        await registry.registerProduct(productId: 'product-a');
        await seedCredential(
          registry.engine,
          productId: 'product-a',
          repositoryId: 'repo',
        );
        final materializer = ScriptedSnapshotMaterializer();
        final subject = BaselineOnboardingSweep(
          engine: registry.engine,
          jobStore: jobStore,
          revisionResolver: SnapshotPinnedRevisionResolver(
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
          clock: () => DateTime.utc(2026, 3, 1),
        );

        await subject.run();
        final afterFirst =
            await registry.engine.readActiveCredential('product-a', 'repo');
        expect(materializer.materializations, greaterThan(0));

        for (var pass = 0; pass < 3; pass++) {
          await subject.run();
        }

        final afterRest =
            await registry.engine.readActiveCredential('product-a', 'repo');
        expect(
          afterRest!.version,
          afterFirst!.version,
          reason:
              'a pass with nothing to acquire must not write to the credential. '
              'Every version bump here is one a later pass reads as stale and '
              'fails its compare-and-swap on.',
        );
        expect(
          materializer.materializations,
          1,
          reason: 'the clone happens when a job would actually be enqueued',
        );
        expect(await jobStore.listJobs(), hasLength(1));
      },
    );

    test(
      'the invariant holds: a revision is resolved, a stable key is enqueued, '
      'and unchanged HEAD does not mint a second job',
      () async {
        // The half that must NOT regress. Skipping cheaply is only correct if
        // the first pass still does the work, and still does it under the same
        // key — a key rebuilt from whatever HEAD is now would be a new job on
        // every pass, which is what the PINNED_REVISION_UNRESOLVABLE reason
        // exists to prevent.
        await registry.registerProduct(productId: 'product-a');
        await seedCredential(
          registry.engine,
          productId: 'product-a',
          repositoryId: 'repo',
        );

        final first = await sweep.run();

        expect(first.enqueued, hasLength(1));
        final enqueued = first.enqueued.single;
        expect(
          enqueued.dedupeKey,
          onboardingDedupeKey(
            productId: 'product-a',
            repositoryId: 'repo',
            startingRevision: kTestRevision,
          ),
          reason: 'the key is built by the one shared builder, not spelled here',
        );
        expect(enqueued.dedupeKey, 'onboarding:product-a:repo:$kTestRevision');

        // HEAD has not moved. Several passes, none of them enqueues, and only
        // the FIRST one ever resolved a revision.
        final second = await sweep.run();
        final third = await sweep.run();

        expect(second.enqueued, isEmpty);
        expect(third.enqueued, isEmpty);
        expect(resolver.acquisitions, 1);
        expect(await jobStore.listJobs(), hasLength(1));
        expect(
          second.skipped.single.reason,
          contains('jb-baseline-product-a-'),
          reason: 'the reason names the job an operator would go and look at',
        );
        expect(
          second.skipped.single.reason,
          isNot(contains(kTestRevision)),
          reason:
              'and quotes no revision at all: this pass did not resolve one, so '
              'it cannot have one to put in a key',
        );
      },
    );

    test('incidents stay LOUD — one failing product does not quiet the pass', () async {
      // The guard that is working as designed, pinned. The live sweep produced
      // 22 incidents that were correct: a product the pass could not decide
      // about was recorded, named and logged, and the pass carried on. A fix
      // that made these quiet would be worse than the livelock, so the
      // accounting identity and the log line are both asserted here.
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

      final failing = _ScriptedResolver(
        {'repo-b': kTestRevision},
        // The exception production actually raised, from the acquisition, on a
        // credential the sweep had written itself.
        failures: {
          'repo-a': ConcurrentModificationException(
            entityId: 'cred-some-credential',
            expectedVersion: 41,
            actualVersion: 42,
          ),
        },
      );
      final subject = sweepOver(failing);

      final result = await subject.run();

      expect(result.considered, 2);
      expect(
        result.incidents,
        hasLength(1),
        reason: 'a genuine failure is an incident, not a skip',
      );
      expect(result.incidents.single.productId, 'product-a');
      expect(
        result.incidents.single.code,
        BaselineSweepIncidentCodes.evaluationFailed,
      );
      expect(
        result.incidents.single.reason,
        contains('expected version 41, actual 42'),
        reason: 'the record says what actually happened',
      );
      expect(
        result.skipped.where((s) => s.productId == 'product-a'),
        isEmpty,
        reason: 'an incident must not be laundered into a routine skip',
      );
      expect(
        result.accountedFor,
        result.considered,
        reason: 'every product the pass looked at is accounted for',
      );

      // ...and the rest of the pass carried on.
      expect(result.enqueued, hasLength(1));
      expect(result.enqueued.single.productId, 'product-b');
      expect(await jobStore.listJobs(), hasLength(1));

      // ...and it was said out loud, with the action an operator needs.
      final incidents = logger
          .where((e) => e.$1 == 'baseline.sweep.product_incident')
          .toList();
      expect(incidents, hasLength(1));
      expect(incidents.single.$2['productId'], 'product-a');
      expect(incidents.single.$2['code'], 'SWEEP_PRODUCT_EVALUATION_FAILED');
      expect(
        incidents.single.$2['action'],
        contains('the rest of the pass continued'),
      );
      expect(incidents.single.$2['stack'], isNotNull);
    });
  });
}
