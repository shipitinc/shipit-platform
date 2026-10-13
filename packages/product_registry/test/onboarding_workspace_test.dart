import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:test/test.dart';

import 'support/baseline_approval.dart';

/// The record's round-trip through a store, and the engine paths that write it.
///
/// The database half of the same round-trip is
/// `apps/server/test/integration/onboarding_workspace_postgres_test.dart`, and
/// the type half is `packages/platform_contracts/test/onboarding_record_test.
/// dart`. What is asserted here is the store tier — that a record carrying a
/// pin and a workspace survives a write/read cycle whole, that the validation
/// both tiers share actually fires at the boundary, and that the engine's
/// completion path writes the answer rather than only a counter.
void main() {
  const sha = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4';
  const otherSha = 'f0e1d2c3b4a5968778695a4b3c2d1e0f9a8b7c6d';
  final t = DateTime.utc(2026, 10, 12, 21, 30, 45);

  WorkspaceDescriptor workspace({
    String startingRevision = sha,
    DateTime? cleanedAt,
  }) => WorkspaceDescriptor(
    workspaceId: 'ws-shipit-1',
    workerExecutionId: 'we-shipit-1',
    workerId: 'wk-local-1',
    repositoryPath: '/var/shipit/repos/shipit-platform',
    startingRevision: startingRevision,
    worktreePath: '/var/shipit/workspaces/shipit-platform-ws-shipit-1',
    createdAt: t,
    cleanedAt: cleanedAt,
  );

  BaselineFact _fact() => BaselineFact(
    factId: 'f-1',
    section: BaselineSectionKey.repository,
    claim: 'shipit-platform is the monorepo',
    provenance: Provenance.observed,
    maturity: BaselineMaturity.implemented,
  );

  OnboardingRecord record({
    String? pinnedRevision,
    WorkspaceDescriptor? workspaceOverride,
    String? completedBaselineId,
    bool completed = false,
  }) => OnboardingRecord(
    onboardingId: 'ob-shipit',
    productId: 'shipit',
    currentBaselineRevision: completed ? 1 : 0,
    completed: completed,
    pinnedRevision: pinnedRevision,
    workspace: workspaceOverride,
    completedBaselineId: completedBaselineId,
    createdAt: t,
    updatedAt: t,
  );

  group('store round-trip', () {
    late InMemoryProductRegistryStore store;

    setUp(() => store = InMemoryProductRegistryStore());

    test(
      'a pinned record with a workspace survives the round-trip whole',
      () async {
        final r = record(
          pinnedRevision: sha,
          workspaceOverride: workspace(),
          completedBaselineId: 'bl-shipit-1',
          completed: true,
        );
        await store.saveOnboarding(r);
        final loaded = await store.readOnboardingForProduct('shipit');
        expect(loaded, isNotNull);
        // Whole-object equality, so a dropped or re-encoded field is a failure
        // rather than an omission from the assertion.
        expect(loaded, r);
        expect(loaded!.hasDurableWorkspace, isTrue);
        expect(loaded.hasCompletionEvidence, isTrue);
      },
    );

    test('a record with NO pin still round-trips', () async {
      // The backward-compatibility direction that matters: a product
      // registered before anything was cloned.
      final r = record();
      await store.saveOnboarding(r);
      final loaded = await store.readOnboardingForProduct('shipit');
      expect(loaded, r);
      expect(loaded!.pinnedRevision, isNull);
      expect(loaded.hasDurableWorkspace, isFalse);
    });

    test('a cleaned workspace round-trips its cleanup timestamp', () async {
      final at = t.add(const Duration(days: 1));
      final r = record(
        pinnedRevision: sha,
        workspaceOverride: workspace(cleanedAt: at),
      );
      await store.saveOnboarding(r);
      final loaded = await store.readOnboardingForProduct('shipit');
      expect(loaded!.workspace!.cleanedAt, at);
      expect(loaded.workspace!.isCleaned, isTrue);
      expect(loaded.pinnedRevision, sha);
      expect(loaded.hasLiveWorkspace, isFalse);
    });

    test('re-pinning a product moves the answer to the new commit', () async {
      await store.saveOnboarding(
        record(pinnedRevision: sha, workspaceOverride: workspace()),
      );
      await store.saveOnboarding(
        record(
          pinnedRevision: otherSha,
          workspaceOverride: workspace(startingRevision: otherSha),
        ).copyWith(updatedAt: t.add(const Duration(hours: 1)), version: 2),
      );
      final loaded = await store.readOnboardingForProduct('shipit');
      expect(loaded!.pinnedRevision, otherSha);
      expect(loaded.workspace!.startingRevision, otherSha);
      expect(loaded.version, 2);
    });

    test(
      'a malformed pin is refused and the stored row is UNCHANGED',
      () async {
        await store.saveOnboarding(
          record(pinnedRevision: sha, workspaceOverride: workspace()),
        );
        await expectLater(
          store.saveOnboarding(
            record(
              pinnedRevision: 'HEAD',
              workspaceOverride: workspace(),
            ).copyWith(updatedAt: t.add(const Duration(hours: 1)), version: 2),
          ),
          throwsA(isA<FormatException>()),
        );
        // A refused write must leave the previous answer readable, or a bad
        // input silently unpins a product.
        final loaded = await store.readOnboardingForProduct('shipit');
        expect(loaded!.pinnedRevision, sha);
        expect(loaded.version, 1);
      },
    );

    test(
      'a contradictory pin/workspace pair is refused, row unchanged',
      () async {
        await store.saveOnboarding(
          record(pinnedRevision: sha, workspaceOverride: workspace()),
        );
        await expectLater(
          store.saveOnboarding(
            record(
              pinnedRevision: otherSha,
              workspaceOverride: workspace(startingRevision: sha),
            ),
          ),
          throwsA(isA<FormatException>()),
        );
        final loaded = await store.readOnboardingForProduct('shipit');
        expect(loaded!.pinnedRevision, sha);
        expect(loaded.workspace!.startingRevision, sha);
      },
    );

    test('the record survives a SNAPSHOT/RESTART cycle intact', () async {
      // `restore` replays `toJson()` through `fromJson`, which is the closest
      // in-memory analogue of a process restart. If the embedded descriptor
      // were not encoded, the workspace would be the first thing lost.
      await store.saveOnboarding(
        record(pinnedRevision: sha, workspaceOverride: workspace()),
      );
      final snapshot = store.snapshotOnboardings();
      final restored = InMemoryProductRegistryStore()
        ..restore(onboardings: snapshot);
      final loaded = await restored.readOnboardingForProduct('shipit');
      expect(loaded!.pinnedRevision, sha);
      expect(loaded.workspace, workspace());
      expect(loaded.hasDurableWorkspace, isTrue);
    });
  });

  group('engine: the record is able to carry the answer', () {
    late InMemoryProductRegistryStore store;
    late InMemoryHumanDecisionStore decisions;
    late ProductRegistryEngine engine;

    setUp(() async {
      store = InMemoryProductRegistryStore();
      decisions = InMemoryHumanDecisionStore();
      engine = ProductRegistryEngine(
        store: store,
        humanDecisionStore: decisions,
      );
      await engine.createProduct(productId: 'shipit', name: 'ShipIt');
    });

    test(
      'a clarification creates an UNPINNED record, not a fake pin',
      () async {
        // The record is created before anything has been cloned, so it must say
        // "not pinned" rather than carry `currentBaselineRevision: 0` and let a
        // reader mistake a counter for a commit.
        await engine.requireClarification(
          productId: 'shipit',
          section: BaselineSectionKey.repository,
          question: 'Which remote does this repository track?',
          now: t,
        );
        final r = (await store.readOnboardingForProduct('shipit'))!;
        expect(r.pinnedRevision, isNull);
        expect(r.workspace, isNull);
        expect(r.currentBaselineRevision, 0);
        expect(r.hasDurableWorkspace, isFalse);
      },
    );

    test(
      'recordWorkspace records WHERE and WHICH, without completing',
      () async {
        await engine.requireClarification(
          productId: 'shipit',
          section: BaselineSectionKey.repository,
          question: 'Which remote does this repository track?',
          now: t,
        );
        final r = await engine.recordWorkspace(
          productId: 'shipit',
          workspace: workspace(),
          pinnedRevision: sha,
          now: t.add(const Duration(hours: 1)),
        );
        expect(r.pinnedRevision, sha);
        expect(
          r.workspace!.worktreePath,
          '/var/shipit/workspaces/shipit-platform-ws-shipit-1',
        );
        expect(
          r.completed,
          isFalse,
          reason: 'recording where the code lives is not completing onboarding',
        );
        expect(r.hasDurableWorkspace, isTrue);

        final loaded = (await store.readOnboardingForProduct('shipit'))!;
        expect(loaded.pinnedRevision, sha);
        expect(loaded.hasDurableWorkspace, isTrue);
      },
    );

    test('recordWorkspace creates the record when none exists yet', () async {
      final r = await engine.recordWorkspace(
        productId: 'shipit',
        workspace: workspace(),
        pinnedRevision: sha,
        now: t,
      );
      expect(r.onboardingId, 'ob-shipit');
      expect(
        (await store.readOnboardingForProduct('shipit'))!.pinnedRevision,
        sha,
      );
    });

    test('recordWorkspace with neither argument is refused', () async {
      // It would otherwise burn a version number and an `updatedAt` while
      // recording nothing, which reads downstream as "something happened".
      await expectLater(
        engine.recordWorkspace(productId: 'shipit', now: t),
        throwsA(isA<ArgumentError>()),
      );
      expect(await store.readOnboardingForProduct('shipit'), isNull);
    });

    test(
      'recordWorkspace refuses a pin that contradicts a live workspace',
      () async {
        await engine.recordWorkspace(
          productId: 'shipit',
          workspace: workspace(),
          pinnedRevision: sha,
          now: t,
        );
        // `copyWith` falls back on a null, so a re-pin that passes only the new
        // commit is refused rather than leaving two answers in one record.
        await expectLater(
          engine.recordWorkspace(
            productId: 'shipit',
            pinnedRevision: otherSha,
            now: t.add(const Duration(hours: 1)),
          ),
          throwsA(isA<FormatException>()),
        );
        expect(
          (await store.readOnboardingForProduct('shipit'))!.pinnedRevision,
          sha,
        );
      },
    );

    test('a cleanup is RECORDED, not erased', () async {
      await engine.recordWorkspace(
        productId: 'shipit',
        workspace: workspace(),
        pinnedRevision: sha,
        now: t,
      );
      final at = t.add(const Duration(days: 1));
      final r = await engine.recordWorkspace(
        productId: 'shipit',
        workspace: workspace(cleanedAt: at),
        pinnedRevision: sha,
        now: at,
      );
      expect(r.workspace!.isCleaned, isTrue);
      expect(r.hasLiveWorkspace, isFalse);
      expect(r.hasDurableWorkspace, isFalse);
      expect(r.pinnedRevision, sha);
    });

    test('recordWorkspace is rejected for an unknown product', () async {
      await expectLater(
        engine.recordWorkspace(
          productId: 'not-a-product',
          workspace: workspace(),
          pinnedRevision: sha,
          now: t,
        ),
        throwsA(isA<ProductNotFoundException>()),
      );
    });

    test('completeOnboarding with no record is refused', () async {
      await expectLater(
        engine.completeOnboarding(
          productId: 'shipit',
          pinnedRevision: sha,
          workspace: workspace(),
          completedBaselineId: 'bl-shipit-1',
          now: t,
        ),
        throwsA(isA<ProductLifecycleException>()),
      );
    });

    test(
      'completeOnboarding records the pin, the workspace AND the baseline',
      () async {
        await engine.recordWorkspace(
          productId: 'shipit',
          workspace: workspace(),
          pinnedRevision: sha,
          now: t,
        );
        final r = await engine.completeOnboarding(
          productId: 'shipit',
          pinnedRevision: sha,
          workspace: workspace(),
          completedBaselineId: 'bl-shipit-1',
          now: t.add(const Duration(hours: 2)),
        );
        expect(r.completed, isTrue);
        expect(r.pinnedRevision, sha);
        expect(r.completedBaselineId, 'bl-shipit-1');
        expect(
          r.hasCompletionEvidence,
          isFalse,
          reason: 'no accepted baseline revision is recorded yet',
        );

        final loaded = (await store.readOnboardingForProduct('shipit'))!;
        expect(loaded.completed, isTrue);
        expect(loaded.completedBaselineId, 'bl-shipit-1');
        expect(loaded.hasDurableWorkspace, isTrue);
      },
    );

    test('a COMPLETED record is one whose evidence points at an accepted '
        'baseline', () async {
      // The full chain: a proposed baseline, a human approval, and the
      // completion write. This is what `hasCompletionEvidence` is for — the
      // bare `completed` flag is not what a consumer should read.
      // `approveBaseline` only UPDATES an onboarding record; it never creates
      // one, because approving a baseline is not itself onboarding. The
      // record therefore has to exist first, which is the real order: the
      // onboarding run materialises a workspace and records it, the baseline
      // that run produced is proposed and approved, and only then is
      // onboarding completed.
      await engine.recordWorkspace(
        productId: 'shipit',
        workspace: workspace(),
        pinnedRevision: sha,
        now: t,
      );
      final b = await engine.proposeBaseline(
        productId: 'shipit',
        facts: [_fact()],
        now: t,
      );
      await approveBaseline(
        engine,
        productId: 'shipit',
        baseline: b,
        now: t.add(const Duration(minutes: 10)),
      );

      // `approveBaseline` is the completion path, and it now names the
      // baseline that earned it instead of flipping a bare bool.
      final afterApproval = (await store.readOnboardingForProduct('shipit'))!;
      expect(afterApproval.completed, isTrue);
      expect(afterApproval.completedBaselineId, b.baselineId);
      expect(afterApproval.currentBaselineRevision, b.revision);

      final completed = await engine.completeOnboarding(
        productId: 'shipit',
        pinnedRevision: sha,
        workspace: workspace(),
        completedBaselineId: b.baselineId,
        now: t.add(const Duration(hours: 1)),
      );
      expect(completed.hasCompletionEvidence, isTrue);
      expect(completed.hasDurableWorkspace, isTrue);
    });

    test('approval does NOT invent a pin it does not know', () async {
      // The counter and the pin are different answers and the engine keeps
      // them apart: accepting a baseline knows a REVISION, not a COMMIT, and
      // `approveBaseline` has no workspace to read a commit from.
      //
      // The record exists here because a clarification opened onboarding — the
      // one path that creates a record without knowing where the code lives.
      await engine.requireClarification(
        productId: 'shipit',
        section: BaselineSectionKey.repository,
        question: 'Which remote does this repository track?',
        now: t,
      );
      final b = await engine.proposeBaseline(
        productId: 'shipit',
        facts: [_fact()],
        now: t,
      );
      await approveBaseline(
        engine,
        productId: 'shipit',
        baseline: b,
        now: t.add(const Duration(minutes: 10)),
      );
      final r = (await store.readOnboardingForProduct('shipit'))!;
      expect(r.completed, isTrue);
      expect(r.pinnedRevision, isNull);
      expect(r.workspace, isNull);
      expect(r.hasDurableWorkspace, isFalse);
      // The evidence pointer IS written — that is what approval knows.
      expect(r.completedBaselineId, b.baselineId);
      expect(r.currentBaselineRevision, b.revision);
    });

    test('approval does NOT create an onboarding record by itself', () async {
      // `approveBaseline` guards its write with `if (onboarding != null)`.
      // Approving a baseline is not onboarding, so it must not conjure one;
      // a record created here would read as "onboarding started" for a product
      // that was never materialised anywhere.
      final b = await engine.proposeBaseline(
        productId: 'shipit',
        facts: [_fact()],
        now: t,
      );
      await approveBaseline(
        engine,
        productId: 'shipit',
        baseline: b,
        now: t.add(const Duration(minutes: 10)),
      );
      expect(await store.readOnboardingForProduct('shipit'), isNull);
    });
  });
}
