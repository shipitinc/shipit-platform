import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'fixtures.dart';

/// Design contract store contract suite. Runs against any [DesignContractStore]
/// implementation (in-memory, PostgreSQL).
///
/// ## Why a store contract needs a shared suite at all
///
/// Every method on [DesignContractStore] is satisfiable by a value returned
/// straight back to the caller, so an implementation that stores nothing passes
/// a test written against that implementation. That is not hypothetical: the
/// `design_contract` table shipped with no implementation that wrote it, which
/// is why `design-revision.md` §9 lists step 1 as delivering "a **durable**
/// design contract" and a review recorded step 1 as a contracted partial. The
/// assertions below are what a second implementation has to satisfy, and they
/// say nothing about which implementation is being run.
///
/// ## What this suite does NOT establish
///
/// It does not establish DURABILITY. Run against an in-memory store it proves
/// the contract; only the PostgreSQL instantiation proves a row survives a
/// restart.
///
/// It does not, by itself, prove the guard change either. `designContractExists()`
/// reading the durable column and confirming it against a store is design
/// `design-revision.md` §4.3, and what proves IT is the falsifier: an item whose
/// `designContractId` column is NULL, or names an id this store does not hold,
/// must be REFUSED `planned -> designRequired` however much context a caller
/// supplies. That is asserted where the engine lives
/// (`packages/workflow_store/test/durable_workflow_engine_test.dart`), because it
/// is a claim about a transition and this suite is a claim about a store.
void runDesignContractStoreSuite({
  required String groupName,
  required Future<DesignContractStore> Function() createStore,
}) {
  group(groupName, () {
    test('a contract round-trips through the store unchanged', () async {
      final store = await createStore();
      final contract = buildDesignContract();

      await store.saveDesignContract(contract);
      final loaded = await store.readDesignContract(kDesignContractId);

      expect(loaded, contract);
      expect(
        loaded!.status,
        DesignContractStatus.draft,
        reason:
            'a round trip that lost a field would still "succeed" for every '
            'assertion that reads only contractId',
      );
    });

    test(
      'the null columns stay NULL rather than becoming empty documents',
      () async {
        // The builder produces a DRAFT with `submittedArtifacts`, `decisions`,
        // `expiresAt` all null — `null` says "has not come up yet", `[]` says
        // "there is none". A store that conflates them reports a draft contract as
        // one whose submission was considered and rejected.
        final store = await createStore();
        await store.saveDesignContract(
          DesignContract(
            contractId: kDesignContractId,
            workItemId: kWorkItemId,
            requiredArtifacts: const [],
            reviewers: const [],
            approvalThreshold: 1,
            status: DesignContractStatus.draft,
            createdAt: DateTime.utc(2026, 1, 1, 12),
            updatedAt: DateTime.utc(2026, 1, 1, 12),
          ),
        );

        final loaded = await store.readDesignContract(kDesignContractId);
        expect(loaded, isNotNull);
        expect(loaded!.submittedArtifacts, isNull);
        expect(loaded.decisions, isNull);
        expect(loaded.expiresAt, isNull);
        expect(loaded.metadata, isNull);
      },
    );

    test('the status column survives its own wire form', () async {
      // `underReview` is the ONE status whose wire token differs from its Dart
      // name. Every other status would pass a suite that stored `.name`, so this
      // test is the only thing that holds the status vocabulary to the codec
      // `platform_contracts` owns.
      final store = await createStore();
      await store.saveDesignContract(
        buildDesignContract(status: DesignContractStatus.underReview),
      );

      final loaded = await store.readDesignContract(kDesignContractId);
      expect(
        loaded?.status,
        DesignContractStatus.underReview,
        reason:
            'a column holding `underReview` decodes as an unknown status, or one '
            'stored through a hand-written mapping here drifts from the private '
            'codec in platform_contracts with nothing to notice',
      );
    });

    test(
      'an unwritten id reads back null — the honest answer, not an error',
      () async {
        final store = await createStore();
        expect(
          await store.readDesignContract('design-contract-never-written'),
          isNull,
        );
        expect(
          await store.hasDesignContract('design-contract-never-written'),
          isFalse,
        );
      },
    );

    test('hasDesignContract agrees with readDesignContract', () async {
      final store = await createStore();
      await store.saveDesignContract(buildDesignContract());

      expect(await store.hasDesignContract(kDesignContractId), isTrue);
      expect(
        await store.hasDesignContract('design-contract-never-written'),
        isFalse,
      );
      // Both directions, because a store that answers `true` for an id it cannot
      // read is worse than one that answers `false` for an id it holds: the
      // first is a fabrication, the second is a miss.
      expect(await store.readDesignContract(kDesignContractId), isNotNull);
    });

    test('provision returns the row the store HOLDS, not the argument', () async {
      final store = await createStore();
      final contract = buildDesignContract();

      final provisioned = await store.provisionDesignContract(contract);

      expect(provisioned.contractId, contract.contractId);
      expect(
        provisioned,
        contract,
        reason:
            'the read-back is what gets stamped on a work item. A store that '
            'returned its argument would make every "the id resolves" assertion '
            'downstream pass without the id ever resolving',
      );
    });

    test('saving the same contract id twice converges on ONE row', () async {
      // `designContractIdForWorkItem` is a pure function of the work item id, so
      // a replay of a crashed provisioning step re-addresses the same primary
      // key. Two rows here would mean one work item governed by two contracts
      // with no way to tell which one the reader meant.
      final store = await createStore();
      final contract = buildDesignContract();
      final updated = DesignContract(
        contractId: contract.contractId,
        workItemId: contract.workItemId,
        requiredArtifacts: contract.requiredArtifacts,
        reviewers: contract.reviewers,
        approvalThreshold: contract.approvalThreshold,
        status: DesignContractStatus.underReview,
        createdAt: contract.createdAt,
        updatedAt: DateTime.utc(2026, 1, 2, 12),
      );

      await store.saveDesignContract(contract);
      await store.saveDesignContract(updated);

      expect(
        await store.listDesignContractsForWorkItem(kWorkItemId),
        hasLength(1),
      );
      final loaded = await store.readDesignContract(kDesignContractId);
      expect(loaded?.status, DesignContractStatus.underReview);
      expect(loaded?.createdAt, contract.createdAt);
      expect(
        loaded?.updatedAt,
        updated.updatedAt,
        reason:
            'the last write wins, and `updatedAt` is the caller\'s assertion of '
            'when that happened. An upsert that moved `createdAt` would rewrite '
            'the history the oldest-first ordering is derived from',
      );
    });

    test('it reports one item\'s contracts and not another\'s', () async {
      final store = await createStore();
      await store.saveDesignContract(buildDesignContract());
      await store.saveDesignContract(
        buildDesignContract(
          contractId: 'design-contract-wi-0002',
          workItemId: 'wi-0002',
        ),
      );

      final forFirst = await store.listDesignContractsForWorkItem(kWorkItemId);
      expect(forFirst, hasLength(1));
      expect(forFirst.single.workItemId, kWorkItemId);

      expect(
        await store.listDesignContractsForWorkItem('wi-0003'),
        isEmpty,
        reason:
            'an item with no contract must read as none, not as someone '
            "else's",
      );
    });

    test('two contracts for one item come back OLDEST FIRST, whatever the '
        'write order', () async {
      // MEASURED, not assumed — see the mutation note below.
      //
      // The write order here is the REVERSE of the chronological order, which
      // is the whole point: an implementation that returns whatever its storage
      // produced (a Dart `Map`'s insertion order, an unordered SQL result set)
      // answers `[newer, older]` here and passes every other assertion in this
      // suite. F-146 is exactly that implementation, and the divergence was
      // constructible and pinned by no test.
      final store = await createStore();
      final older = buildDesignContract(
        contractId: 'design-contract-wi-0001',
        workItemId: kWorkItemId,
        instant: DateTime.utc(2026, 1, 1, 12),
      );
      final newer = buildDesignContract(
        contractId: 'design-contract-wi-0001b',
        workItemId: kWorkItemId,
        instant: DateTime.utc(2026, 1, 2, 12),
      );

      // Newer written FIRST.
      await store.saveDesignContract(newer);
      await store.saveDesignContract(older);

      expect(
        (await store.listDesignContractsForWorkItem(
          kWorkItemId,
        )).map((c) => c.contractId),
        [older.contractId, newer.contractId],
      );
    });

    test('two contracts sharing an instant come back in a TOTAL order', () async {
      // `createdAt` is the CALLER's assertion, so two contracts built in the same
      // tick is a normal state rather than a malformed row. An `ORDER BY
      // createdAt` alone leaves that tie to the storage engine, which means the
      // same store answers differently on different runs — and a durable store
      // disagreeing with an in-memory one is the failure F-146 names.
      final store = await createStore();
      final sameInstant = DateTime.utc(2026, 1, 1, 12);
      // Named so the ASCENDING `contractId` order is `first`, `second`, and
      // written so the INSERTION order is `second`, `first` — the two disagree,
      // which is what makes this a test rather than a restatement.
      final first = buildDesignContract(
        contractId: 'design-contract-wi-0001a',
        workItemId: kWorkItemId,
        instant: sameInstant,
      );
      final second = buildDesignContract(
        contractId: 'design-contract-wi-0001b',
        workItemId: kWorkItemId,
        instant: sameInstant,
      );

      await store.saveDesignContract(second);
      await store.saveDesignContract(first);

      expect(
        (await store.listDesignContractsForWorkItem(
          kWorkItemId,
        )).map((c) => c.contractId),
        [first.contractId, second.contractId],
        reason: 'ascending contractId breaks the tie, so the order is total',
      );
    });
  });
}
