import 'package:platform_contracts/platform_contracts.dart';
import 'package:product_registry/product_registry.dart';
import 'package:test/test.dart';

/// Product registry store contract suite. Runs against any
/// [ProductRegistryStore] implementation (in-memory, PostgreSQL).
void runProductRegistryStoreSuite({
  required String groupName,
  required Future<ProductRegistryStore> Function() createStore,
}) {
  group(groupName, () {
    test('product round-trips with CAS version checks', () async {
      final store = await createStore();
      final created = DateTime.utc(2026, 9, 16, 12);
      await store.saveProduct(
        Product(
          productId: 'shipit',
          name: 'ShipIt',
          description: 'Product platform',
          state: ProductState.registered,
          createdAt: created,
          updatedAt: created,
          version: 1,
        ),
        expectedVersion: 0,
      );

      final loaded = await store.readProduct('shipit');
      expect(loaded.productId, 'shipit');
      expect(loaded.state, ProductState.registered);

      expect(
        () => store.readProduct('missing'),
        throwsA(isA<ProductNotFoundException>()),
      );
    });

    test('saveProduct upserts and enforces compare-and-swap', () async {
      final store = await createStore();
      final created = DateTime.utc(2026, 9, 16, 12);
      final product = Product(
        productId: 'shipit',
        name: 'ShipIt',
        state: ProductState.registered,
        createdAt: created,
        updatedAt: created,
        version: 1,
      );
      await store.saveProduct(product);
      await store.saveProduct(product, expectedVersion: product.version);

      final activated = product.copyWith(
        state: ProductState.governed,
        updatedAt: created.add(const Duration(hours: 1)),
        version: product.version + 1,
      );
      await store.saveProduct(activated, expectedVersion: product.version);

      final loaded = await store.readProduct('shipit');
      expect(loaded.state, ProductState.governed);

      expect(
        store.saveProduct(product, expectedVersion: 99),
        throwsA(isA<ConcurrentModificationException>()),
      );
    });

    test('repository references round-trip scoped by product', () async {
      final store = await createStore();
      final t = DateTime.utc(2026, 9, 16, 12);
      final ref = RepositoryReference(
        repositoryId: 'repo-shipit',
        productId: 'shipit',
        kind: RepositoryKind.monorepo,
        uri: 'shipit-platform',
        provider: RepositoryProvider.local,
        addedAt: t,
        version: 1,
      );
      await store.saveRepositoryReference(ref);

      expect(await store.readRepositoryReference('repo-shipit'), ref);
      final forProduct = await store.readRepositoriesForProduct('shipit');
      expect(forProduct.single.repositoryId, 'repo-shipit');
      expect(forProduct.single.productId, 'shipit');

      expect(
        () => store.readRepositoryReference('missing'),
        throwsA(isA<RepositoryNotFoundException>()),
      );
    });

    test('baselines round-trip with revision numbering and CAS', () async {
      final store = await createStore();
      final t = DateTime.utc(2026, 9, 16, 12);
      BaselineFact fact(String id) => BaselineFact(
        factId: id,
        section: BaselineSectionKey.repository,
        claim: 'monorepo observed',
        provenance: Provenance.observed,
        maturity: BaselineMaturity.implemented,
        evidenceRefs: const ['pubspec.yaml'],
        redacted: false,
      );

      expect(await store.nextBaselineRevision('shipit'), 1);

      final v1 = ProductBaseline(
        baselineId: 'bl-shipit-1',
        productId: 'shipit',
        revision: 1,
        status: ProductBaselineStatus.proposed,
        facts: [fact('f-1')],
        contentHash: 'hash-1',
        proposedAt: t,
        createdAt: t,
        updatedAt: t,
        version: 1,
      );
      await store.saveBaseline(v1);
      await store.saveBaseline(
        v1.copyWith(
          status: ProductBaselineStatus.accepted,
          acceptedAt: t.add(const Duration(hours: 1)),
          acceptedBy: 'human-gate',
          updatedAt: t.add(const Duration(hours: 1)),
          version: 2,
        ),
        expectedVersion: 1,
      );

      final loaded = await store.readBaseline('bl-shipit-1');
      expect(loaded.status, ProductBaselineStatus.accepted);
      expect(loaded.acceptedBy, 'human-gate');

      final byRevision = await store.readBaselineByRevision('shipit', 1);
      expect(byRevision!.baselineId, 'bl-shipit-1');
      expect(byRevision.facts.single.provenance, Provenance.observed);

      expect(await store.nextBaselineRevision('shipit'), 2);

      final v2 = ProductBaseline(
        baselineId: 'bl-shipit-2',
        productId: 'shipit',
        revision: 2,
        status: ProductBaselineStatus.proposed,
        facts: [fact('f-1')],
        contentHash: 'hash-1',
        supersedesBaselineId: 'bl-shipit-1',
        proposedAt: t,
        createdAt: t,
        updatedAt: t,
        version: 1,
      );
      await store.saveBaseline(v2);
      final all = await store.readBaselinesForProduct('shipit');
      expect(all.map((b) => b.revision), [2, 1]);

      expect(
        store.saveBaseline(v1.copyWith(), expectedVersion: 42),
        throwsA(isA<ConcurrentModificationException>()),
      );
    });

    test('clarifications round-trip and stay scoped', () async {
      final store = await createStore();
      final t = DateTime.utc(2026, 9, 16, 12);
      final request = ClarificationRequest(
        clarificationId: 'clar-1',
        productId: 'shipit',
        onboardingId: 'ob-shipit',
        section: BaselineSectionKey.deployment,
        question: 'Where does ShipIt deploy?',
        status: ClarificationStatus.needsAnswer,
        createdAt: t,
      );
      await store.saveClarification(request);

      expect(await store.readClarification('clar-1'), request);

      await store.saveClarification(
        request.copyWith(
          status: ClarificationStatus.answered,
          answer: 'us-east-1',
          answeredAt: t.add(const Duration(hours: 1)),
          answeredBy: 'anthony',
        ),
      );
      final answered = await store.readClarification('clar-1');
      expect(answered.status, ClarificationStatus.answered);
      expect(answered.answer, 'us-east-1');

      final open = await store.readClarificationsForProduct('shipit');
      expect(open, isEmpty);

      expect(
        () => store.readClarification('missing'),
        throwsA(isA<ClarificationNotFoundException>()),
      );
    });

    test(
      'onboarding records round-trip and is idempotent per product',
      () async {
        final store = await createStore();
        final t = DateTime.utc(2026, 9, 16, 12);
        // A record CARRYING THE PIN is the state this lane exists to produce.
        // It is written here so every store tier is obliged to persist the
        // durable answer, rather than leaving "does the store keep the pin?"
        // to each tier's own package-local tests — which is how a third tier
        // could satisfy ProductRegistryStore without implementing it at all.
        //
        // The pin and `startingRevision` MUST be the same commit: both tiers
        // call `OnboardingRecord.validate()` before writing, and it refuses a
        // record whose two stored revisions disagree.
        final pin = 'f0f3494957bb90df0a1c15a9fb4734ca6e49634d';
        final record = OnboardingRecord(
          onboardingId: 'ob-shipit',
          productId: 'shipit',
          currentBaselineRevision: 1,
          pendingClarifications: 1,
          completed: false,
          pinnedRevision: pin,
          workspace: WorkspaceDescriptor(
            workspaceId: 'ws-shipit',
            workerExecutionId: '123e4567-e89b-12d3-a456-426614174020',
            workerId: 'worker-local-1',
            repositoryPath: '/home/ci/checkouts/shipit-platform',
            startingRevision: pin,
            worktreePath: '/workspaces/ws-shipit',
            detached: true,
            createdAt: t,
          ),
          createdAt: t,
          updatedAt: t,
          version: 1,
        );
        await store.saveOnboarding(record);
        final stored = await store.readOnboardingForProduct('shipit');
        expect(stored, record);

        // Asserted explicitly as well as by the equality above, so a tier that
        // silently drops the pin fails on the pin rather than on a whole-object
        // mismatch nobody can read.
        expect(stored!.pinnedRevision, pin);
        expect(stored.workspace, isNotNull);
        expect(stored.workspace!.kind, 'execution');
        expect(stored.workspace!.requireExecution().workspaceId, 'ws-shipit');
        expect(stored.workspace!.requireExecution().startingRevision, pin);
        expect(
          stored.workspace!.requireExecution().worktreePath,
          '/workspaces/ws-shipit',
        );
        expect(stored.hasDurableWorkspace, isTrue);

        await store.saveOnboarding(
          record.copyWith(
            pendingClarifications: 0,
            completed: true,
            completedBaselineId: 'pb-shipit-1',
            updatedAt: t.add(const Duration(hours: 1)),
            version: 2,
          ),
        );
        final reloaded = await store.readOnboardingForProduct('shipit');
        expect(reloaded!.completed, isTrue);
        expect(reloaded.pendingClarifications, 0);
        // The pin survives the completing update, not just the initial write.
        expect(reloaded.pinnedRevision, pin);
        expect(reloaded.workspace!.requireExecution().workspaceId, 'ws-shipit');
        expect(reloaded.completedBaselineId, 'pb-shipit-1');
        expect(reloaded.hasCompletionEvidence, isTrue);

        expect(await store.readOnboardingForProduct('missing'), isNull);
      },
    );

    test(
      'a DURABLE workspace descriptor round-trips and keeps its own shape',
      () async {
        final store = await createStore();
        final t = DateTime.utc(2026, 9, 16, 12);
        final pin = 'b1c2d3e4f50617283940a1b2c3d4e5f607182930';
        // The second shape the column is allowed to carry. It is in the shared
        // suite rather than a tier's own package because the whole point of
        // `oneOf` on `onboarding_record.schema.json` is that a tier stores
        // whichever shape it is given and comes back with THAT shape — and the
        // only way every tier is obliged to do that is for every tier to run
        // this case.
        //
        // The `kind` discriminator is asserted end to end because it is the one
        // thing that stops a durable clone being resolved as a worker
        // execution's worktree. A tier that dropped it on write, or that read
        // the document back as the per-execution shape, fails here rather than
        // somewhere downstream with no error at all.
        final record = OnboardingRecord(
          onboardingId: 'ob-durable',
          productId: 'durable-product',
          currentBaselineRevision: 1,
          pendingClarifications: 0,
          completed: false,
          pinnedRevision: pin,
          workspace: DurableWorkspaceDescriptor(
            workspaceId: 'dws-durable-product',
            productId: 'durable-product',
            repositoryPath: '/srv/durable-workspaces/durable-product/checkout',
            startingRevision: pin,
            createdAt: t,
          ),
          createdAt: t,
          updatedAt: t,
          version: 1,
        );
        await store.saveOnboarding(record);

        final loaded = await store.readOnboardingForProduct('durable-product');
        expect(loaded, record);
        expect(loaded!.hasDurableWorkspace, isTrue);
        expect(loaded.workspace!.kind, kDurableWorkspaceKind);
        final durable = loaded.workspace!.requireDurable();
        expect(durable.workspaceId, 'dws-durable-product');
        expect(durable.productId, 'durable-product');
        expect(durable.startingRevision, pin);
        expect(
          durable.repositoryPath,
          '/srv/durable-workspaces/durable-product/checkout',
        );

        // And it is NOT quietly interchangeable with the other shape.
        expect(
          () => loaded.workspace!.requireExecution(),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'onboarding records with all three pin fields NULL still load',
      () async {
        final store = await createStore();
        final t = DateTime.utc(2026, 9, 16, 12);
        // The other half of the contract. A Product is registered long before
        // anything pins or completes it, so "not yet pinned" is an ordinary
        // state and every tier must store and return it unchanged rather than
        // rejecting it or inventing a value.
        final record = OnboardingRecord(
          onboardingId: 'ob-unpinned',
          productId: 'shipit-unpinned',
          currentBaselineRevision: 0,
          pendingClarifications: 2,
          completed: false,
          createdAt: t,
          updatedAt: t,
          version: 1,
        );
        await store.saveOnboarding(record);

        final loaded = await store.readOnboardingForProduct('shipit-unpinned');
        expect(loaded, record);
        expect(loaded!.pinnedRevision, isNull);
        expect(loaded.workspace, isNull);
        expect(loaded.completedBaselineId, isNull);
        expect(loaded.hasDurableWorkspace, isFalse);
        expect(loaded.hasCompletionEvidence, isFalse);
      },
    );

    test('transaction exposes a consistent store view', () async {
      final store = await createStore();
      final mutations = await store.inTransaction((scoped) async {
        final t = DateTime.utc(2026, 9, 16, 12);
        await scoped.saveProduct(
          Product(
            productId: 'txn',
            name: 'TxnProduct',
            state: ProductState.registered,
            createdAt: t,
            updatedAt: t,
            version: 1,
          ),
        );
        return await scoped.readProduct('txn');
      });
      expect(mutations.productId, 'txn');
      expect((await store.readProduct('txn')).name, 'TxnProduct');
    });
  });
}
