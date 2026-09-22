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
        final record = OnboardingRecord(
          onboardingId: 'ob-shipit',
          productId: 'shipit',
          currentBaselineRevision: 1,
          pendingClarifications: 1,
          completed: false,
          createdAt: t,
          updatedAt: t,
          version: 1,
        );
        await store.saveOnboarding(record);
        expect(await store.readOnboardingForProduct('shipit'), record);

        await store.saveOnboarding(
          record.copyWith(
            pendingClarifications: 0,
            completed: true,
            updatedAt: t.add(const Duration(hours: 1)),
            version: 2,
          ),
        );
        final reloaded = await store.readOnboardingForProduct('shipit');
        expect(reloaded!.completed, isTrue);
        expect(reloaded.pendingClarifications, 0);

        expect(await store.readOnboardingForProduct('missing'), isNull);
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
