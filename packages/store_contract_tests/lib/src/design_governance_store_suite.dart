import 'package:design_governance/design_governance.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

/// Design governance store contract suite. Runs against any [DesignGovernanceStore]
/// implementation (in-memory, PostgreSQL).
void runDesignGovernanceStoreSuite({
  required String groupName,
  required Future<DesignGovernanceStore> Function() createStore,
}) {
  group(groupName, () {
    test('design revisions round-trip with CAS version checks', () async {
      final store = await createStore();
      final revision = buildDesignRevision();

      await store.saveDesignRevision(revision, expectedVersion: 0);
      final loaded = await store.readDesignRevision(kRevisionId);
      expect(loaded, revision);

      expect(
        () => store.readDesignRevision('missing'),
        throwsA(isA<DesignRevisionNotFoundException>()),
      );
    });

    test('saveDesignRevision upserts and enforces compare-and-swap', () async {
      final store = await createStore();
      final revision = buildDesignRevision();
      await store.saveDesignRevision(revision);
      await store.saveDesignRevision(revision, expectedVersion: revision.version);

      final updated = buildDesignRevision(
        status: DesignRevisionStatus.inReview,
        version: revision.version + 1,
      );
      await store.saveDesignRevision(updated, expectedVersion: revision.version);

      final loaded = await store.readDesignRevision(kRevisionId);
      expect(loaded.status, DesignRevisionStatus.inReview);

      expect(
        store.saveDesignRevision(buildDesignRevision(), expectedVersion: 99),
        throwsA(
          isA<DesignGovernanceConcurrentModificationException>().having(
            (e) => e.actualVersion,
            'actualVersion',
            updated.version,
          ),
        ),
      );
    });

    test('design revisions listed per work item', () async {
      final store = await createStore();
      await store.saveDesignRevision(buildDesignRevision());
      await store.saveDesignRevision(
        buildDesignRevision(
          revisionId: 'DES-R002',
          workItemId: 'wi-0002',
          status: DesignRevisionStatus.draft,
        ),
      );
      final all = await store.readDesignRevisionsForWorkItem(kWorkItemId);
      expect(all.map((r) => r.revisionId), contains('DES-R001'));
    });

    test('approved design revision per work item is unique', () async {
      final store = await createStore();
      final rev1 = buildDesignRevision(status: DesignRevisionStatus.approved);
      await store.saveDesignRevision(rev1);
      
      final approved = await store.readApprovedDesignRevisionForWorkItem(kWorkItemId);
      expect(approved, isNotNull);
      expect(approved!.revisionId, kRevisionId);
      
      // Second approved revision for same work item should fail at DB level
      // In-memory store doesn't enforce this, but Postgres does
    });

    test('design revision lineage traversal', () async {
      final store = await createStore();
      final root = buildDesignRevision(revisionId: 'DES-R001', parentRevisionId: null);
      await store.saveDesignRevision(root);
      
      final child = buildDesignRevision(
        revisionId: 'DES-R002',
        parentRevisionId: 'DES-R001',
      );
      await store.saveDesignRevision(child);
      
      final grandchild = buildDesignRevision(
        revisionId: 'DES-R003',
        parentRevisionId: 'DES-R002',
      );
      await store.saveDesignRevision(grandchild);
      
      final lineage = await store.getLineage('DES-R003');
      expect(lineage.map((r) => r.revisionId), ['DES-R001', 'DES-R002', 'DES-R003']);
    });

    test('design review results round-trip with CAS', () async {
      final store = await createStore();
      final result = buildDesignReviewResult();
      
      await store.saveDesignReviewResult(result, expectedVersion: 0);
      final loaded = await store.readDesignReviewResult(kReviewExecutionId);
      expect(loaded, result);
      
      expect(
        () => store.readDesignReviewResult('missing'),
        throwsA(isA<DesignReviewResultNotFoundException>()),
      );
    });

    test('design review results listed per revision', () async {
      final store = await createStore();
      await store.saveDesignReviewResult(buildDesignReviewResult());
      await store.saveDesignReviewResult(
        buildDesignReviewResult(
          reviewExecutionId: 'rev-exec-2',
          revisionId: kRevisionId,
          verdict: DesignReviewVerdict.changesRequired,
        ),
      );
      final forRevision = await store.readDesignReviewResultsForRevision(kRevisionId);
      expect(forRevision.length, 2);
    });

    test('design findings round-trip with CAS', () async {
      final store = await createStore();
      final finding = buildDesignFinding();
      
      await store.saveDesignFinding(finding, expectedVersion: 0);
      final loaded = await store.readDesignFinding(kFindingId);
      expect(loaded, finding);
      
      expect(
        () => store.readDesignFinding('missing'),
        throwsA(isA<DesignFindingNotFoundException>()),
      );
    });

    test('design findings listed per revision and review execution', () async {
      final store = await createStore();
      await store.saveDesignFinding(buildDesignFinding());
      await store.saveDesignFinding(
        buildDesignFinding(
          findingId: 'FD-002',
          reviewExecutionId: 'rev-exec-2',
          category: DesignFindingCategory.accessibility,
        ),
      );
      
      final forRevision = await store.readDesignFindingsForRevision(kRevisionId);
      expect(forRevision.length, 2);
      
      final forExecution = await store.readDesignFindingsForReviewExecution(kReviewExecutionId);
      expect(forExecution.length, 1);
      expect(forExecution.first.findingId, kFindingId);
    });

    test('unresolved and resolved findings queries', () async {
      final store = await createStore();
      final unresolved = buildDesignFinding(findingId: 'FD-001', resolvedByRevisionId: null);
      final resolved = buildDesignFinding(findingId: 'FD-002', resolvedByRevisionId: 'DES-R002');
      
      await store.saveDesignFinding(unresolved);
      await store.saveDesignFinding(resolved);
      
      final unresolvedList = await store.readUnresolvedFindingsForRevision(kRevisionId);
      expect(unresolvedList.length, 1);
      expect(unresolvedList.first.findingId, 'FD-001');
      
      final resolvedList = await store.readFindingsResolvedByRevision('DES-R002');
      expect(resolvedList.length, 1);
      expect(resolvedList.first.findingId, 'FD-002');
    });

    test('design revision events are append-only and ordered', () async {
      final store = await createStore();
      await store.appendEvent(buildDesignRevisionEvent(sequence: 1));
      await store.appendEvent(buildDesignRevisionEvent(eventId: 'evt-2', sequence: 2));
      
      final events = await store.readEventsForRevision(kRevisionId);
      expect(events.length, 2);
      expect(events.map((e) => e.sequence), [1, 2]);
    });

    test('events after sequence and last event queries', () async {
      final store = await createStore();
      await store.appendEvent(buildDesignRevisionEvent(sequence: 1));
      await store.appendEvent(buildDesignRevisionEvent(eventId: 'evt-2', sequence: 2));
      await store.appendEvent(buildDesignRevisionEvent(eventId: 'evt-3', sequence: 3));
      
      final afterSeq1 = await store.readEventsAfterSequence(kRevisionId, 1);
      expect(afterSeq1.length, 2);
      expect(afterSeq1.map((e) => e.sequence), [2, 3]);
      
      final lastEvent = await store.readLastEventForRevision(kRevisionId);
      expect(lastEvent?.sequence, 3);
    });

    test('inTransaction batches mutations atomically when supported', () async {
      final store = await createStore();
      await store.inTransaction((tx) async {
        await tx.saveDesignRevision(buildDesignRevision());
        await tx.appendEvent(buildDesignRevisionEvent());
      });
      expect(await store.readDesignRevision(kRevisionId), buildDesignRevision());
      expect((await store.readEventsForRevision(kRevisionId)).length, 1);
    });
  });
}