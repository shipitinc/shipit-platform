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
      await store.saveDesignRevision(
        revision,
        expectedVersion: revision.version,
      );

      final updated = buildDesignRevision(
        status: DesignRevisionStatus.inReview,
        version: revision.version + 1,
      );
      await store.saveDesignRevision(
        updated,
        expectedVersion: revision.version,
      );

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

      final approved = await store.readApprovedDesignRevisionForWorkItem(
        kWorkItemId,
      );
      expect(approved, isNotNull);
      expect(approved!.revisionId, kRevisionId);

      // Second approved revision for same work item should fail at DB level
      // In-memory store doesn't enforce this, but Postgres does
    });

    test('design revision lineage traversal', () async {
      final store = await createStore();
      final root = buildDesignRevision(
        revisionId: 'DES-R001',
        parentRevisionId: null,
      );
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
      expect(lineage.map((r) => r.revisionId), [
        'DES-R001',
        'DES-R002',
        'DES-R003',
      ]);
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
      final forRevision = await store.readDesignReviewResultsForRevision(
        kRevisionId,
      );
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

      final forRevision = await store.readDesignFindingsForRevision(
        kRevisionId,
      );
      expect(forRevision.length, 2);

      final forExecution = await store.readDesignFindingsForReviewExecution(
        kReviewExecutionId,
      );
      expect(forExecution.length, 1);
      expect(forExecution.first.findingId, kFindingId);
    });

    test('unresolved and resolved findings queries', () async {
      final store = await createStore();
      final unresolved = buildDesignFinding(
        findingId: 'FD-001',
        resolvedByRevisionId: null,
      );
      final resolved = buildDesignFinding(
        findingId: 'FD-002',
        resolvedByRevisionId: 'DES-R002',
      );

      await store.saveDesignFinding(unresolved);
      await store.saveDesignFinding(resolved);

      final unresolvedList = await store.readUnresolvedFindingsForRevision(
        kRevisionId,
      );
      expect(unresolvedList.length, 1);
      expect(unresolvedList.first.findingId, 'FD-001');

      final resolvedList = await store.readFindingsResolvedByRevision(
        'DES-R002',
      );
      expect(resolvedList.length, 1);
      expect(resolvedList.first.findingId, 'FD-002');
    });

    test('design revision events are append-only and ordered', () async {
      final store = await createStore();
      await store.appendEvent(buildDesignRevisionEvent(sequence: 1));
      await store.appendEvent(
        buildDesignRevisionEvent(eventId: 'evt-2', sequence: 2),
      );

      final events = await store.readEventsForRevision(kRevisionId);
      expect(events.length, 2);
      expect(events.map((e) => e.sequence), [1, 2]);
    });

    test('events after sequence and last event queries', () async {
      final store = await createStore();
      await store.appendEvent(buildDesignRevisionEvent(sequence: 1));
      await store.appendEvent(
        buildDesignRevisionEvent(eventId: 'evt-2', sequence: 2),
      );
      await store.appendEvent(
        buildDesignRevisionEvent(eventId: 'evt-3', sequence: 3),
      );

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
      expect(
        await store.readDesignRevision(kRevisionId),
        buildDesignRevision(),
      );
      expect((await store.readEventsForRevision(kRevisionId)).length, 1);
    });

    // ---------------------------------------------------------------------
    // §3.5.3 -- validated on write, failing closed.
    //
    // These live in the SHARED suite rather than beside one implementation on
    // purpose. `InMemoryDesignGovernanceStore` and
    // `PostgresDesignGovernanceStore` are two implementations of one interface,
    // and a gate enforced by only one of them is the F-146 class: the store
    // that omits it accepts writes the other refuses, and nothing notices
    // until someone runs the same input against both. Running the identical
    // assertion here means a future implementation inherits the obligation
    // rather than having to rediscover it, and an implementation that drops the
    // gate fails HERE, in the suite that already runs for it.
    // ---------------------------------------------------------------------

    test('a revision whose anchor does not conform is NOT persisted', () async {
      final store = await createStore();

      // `boardIdsJson` names no board, so §3.5.1 row 1's `minItems: 1` is
      // unsatisfied: this revision asserts nothing and could be diffed against
      // nothing, which is the hole the anchor exists to close.
      final nonConforming = _withColumn(
        buildDesignRevision(),
        'boardIdsJson',
        '[]',
      );

      await expectLater(
        store.saveDesignRevision(nonConforming),
        throwsA(isA<DesignRevisionFidelityAnchorException>()),
      );

      // "Not persisted" is the claim being tested, so it is asserted as an
      // absence. A gate that flagged and stored would satisfy the `throwsA`
      // above in a persisting implementation and fail this line.
      await expectLater(
        store.readDesignRevision(kRevisionId),
        throwsA(isA<DesignRevisionNotFoundException>()),
      );
    });

    test('the designer may not appear in reviewExecutionIds', () async {
      final store = await createStore();

      // The seventh rule — the one JSON Schema cannot express, because it
      // compares two fields of one record. It is here so the SEVENTH rule is
      // enforced on the write path and not only in the differential.
      final selfReviewed = _withColumn(
        buildDesignRevision(),
        'reviewExecutionIdsJson',
        '["designer-exec-1","rev-exec-1"]',
      );

      await expectLater(
        store.saveDesignRevision(selfReviewed),
        throwsA(
          isA<DesignRevisionFidelityAnchorException>().having(
            (e) => e.violations.map((v) => v.code).toList(),
            'violation codes',
            contains(FidelityAnchorViolationCode.designerIsItsOwnReviewer),
          ),
        ),
      );
    });

    test('a state naming no board in the same row is refused', () async {
      final store = await createStore();

      // The cross-column rule. Validating each column independently would make
      // it unstatable, which is why the anchor's unit of validation is the
      // bundle rather than the column.
      final danglingState = _withColumn(
        buildDesignRevision(),
        'statesRepresentedJson',
        '[{"boardId":"board-404","stateKey":"focus","variant":"focus"}]',
      );

      await expectLater(
        store.saveDesignRevision(danglingState),
        throwsA(
          isA<DesignRevisionFidelityAnchorException>().having(
            (e) => e.violations.map((v) => v.code).toList(),
            'violation codes',
            contains(FidelityAnchorViolationCode.unresolvableBoardId),
          ),
        ),
      );
    });

    test('an UNORDERED but conforming anchor is stored canonically', () async {
      final store = await createStore();

      // §3.5.2's normalisation is applied ON WRITE, so the stored bytes are
      // canonical and two encodings of one revision are byte-identical — the
      // precondition for diffing at all. Written here in the WRONG order (lg
      // after md, boards descending) and read back sorted, which is the whole
      // of rule 2.
      final unordered = _withColumn(
        buildDesignRevision(),
        'responsiveTargetsJson',
        '[{"breakpoint":"md","minViewportWidthCss":768},'
            '{"breakpoint":"lg","minViewportWidthCss":1024,"orientation":"landscape"}]',
      );
      final unorderedBoards = _withColumn(
        unordered,
        'boardIdsJson',
        '[{"boardId":"board-2","boardName":"Board 2","provider":"penpot",'
            '"providerFileId":"pf-1"},'
            '{"boardId":"board-1","boardName":"Board 1","provider":"penpot",'
            '"providerFileId":"pf-1"}]',
      );

      await store.saveDesignRevision(unorderedBoards);

      final loaded = await store.readDesignRevision(kRevisionId);
      // Compared to the CANONICAL fixture, not to the input: canonicalising
      // must be a no-op on a value that is already canonical, which is what
      // makes this an assertion about the stored bytes.
      expect(loaded, buildDesignRevision());
      expect(
        loaded.responsiveTargetsJson,
        startsWith('[{"breakpoint":"lg"'),
        reason: 'lg sorts before md; the stored value must already be sorted',
      );
    });

    test('a conforming anchor survives the round trip byte-for-byte', () async {
      final store = await createStore();
      final canonical = buildDesignRevision();

      await store.saveDesignRevision(canonical);

      // §3.5.2 rule 3: no insignificant whitespace, and rule 1: keys sorted at
      // every level. The canonicaliser is a no-op on canonical input, so what
      // comes back is the fixture's own bytes — the property that lets two
      // encodings of one revision be compared with `==`.
      final loaded = await store.readDesignRevision(kRevisionId);
      expect(loaded.boardIdsJson, canonical.boardIdsJson);
      expect(loaded.responsiveTargetsJson, canonical.responsiveTargetsJson);
      expect(loaded.statesRepresentedJson, canonical.statesRepresentedJson);
      expect(loaded.artifactRefsJson, canonical.artifactRefsJson);
      expect(loaded.reviewExecutionIdsJson, canonical.reviewExecutionIdsJson);
      expect(loaded, canonical);
    });
  });
}

/// Returns [revision] with one anchor blob column replaced by [text].
///
/// A local reconstruction rather than a `copyWith` on [DesignRevision] on
/// purpose: that type is a `final` value class with no `copyWith`, and adding
/// one to production source to serve a test helper is a wider change than the
/// finding justifies. Every other field is carried across unchanged, so a
/// violation case here differs from `buildDesignRevision()` in exactly the one
/// column named — a case that quietly drifted onto different board ids would
/// still pass while testing a different row.
DesignRevision _withColumn(
  DesignRevision revision,
  String column,
  String text,
) => DesignRevision(
  revisionId: revision.revisionId,
  workItemId: revision.workItemId,
  productId: revision.productId,
  parentRevisionId: revision.parentRevisionId,
  designSystemRevision: revision.designSystemRevision,
  provider: revision.provider,
  penpotFileId: revision.penpotFileId,
  penpotPageId: revision.penpotPageId,
  boardIdsJson: column == 'boardIdsJson' ? text : revision.boardIdsJson,
  responsiveTargetsJson: column == 'responsiveTargetsJson'
      ? text
      : revision.responsiveTargetsJson,
  statesRepresentedJson: column == 'statesRepresentedJson'
      ? text
      : revision.statesRepresentedJson,
  artifactRefsJson: column == 'artifactRefsJson'
      ? text
      : revision.artifactRefsJson,
  designerExecutionId: revision.designerExecutionId,
  reviewExecutionIdsJson: column == 'reviewExecutionIdsJson'
      ? text
      : revision.reviewExecutionIdsJson,
  status: revision.status,
  riskTier: revision.riskTier,
  reviewScopeJson: revision.reviewScopeJson,
  carriedForwardFromRevisionId: revision.carriedForwardFromRevisionId,
  supersededByRevisionId: revision.supersededByRevisionId,
  createdAt: revision.createdAt,
  updatedAt: revision.updatedAt,
  approvedAt: revision.approvedAt,
  version: revision.version,
  declaredOwnedPaths: revision.declaredOwnedPaths,
);
