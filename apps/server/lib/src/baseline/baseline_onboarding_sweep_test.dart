import 'package:control_plane_server/src/baseline/baseline_onboarding_sweep.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:workflow_engine/workflow_engine.dart' show ProductGuard;
// The dedupe key is the one contract this sweep shares with the operator-requested
// trigger, and neither the barrel nor the key function is reachable from
// `test/` without the `implementation_imports` escape this file documents.
// ignore: implementation_imports
import 'package:scheduler/src/baseline_product.dart';
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
      'is the exact literal the operator-requested trigger already writes',
      () {
        // THE DRIFT HAZARD, PINNED. `ControlPlaneService.triggerOnboarding`
        // builds this string inline and that file is outside this change's
        // ownership, so the two must stay in lockstep by hand. If either side is
        // edited, this fails instead of the sweep and the operator quietly
        // enqueueing two jobs for one derivation.
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
