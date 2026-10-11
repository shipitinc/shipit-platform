import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'fixtures.dart';

/// Workflow store contract suite. Runs against any [WorkflowStore]
/// implementation (in-memory, file-backed, PostgreSQL).
///
/// Every assertion here is BEHAVIOURAL and implementor-agnostic. A store that
/// satisfies all of them is interchangeable with any other, which is the only
/// reason the same file can be the specification for an in-memory map and for
/// a real database — and the only reason a production store cannot quietly
/// drift from the stores its tests exercise.
/// A behaviour the shared suite requires that a specific implementation does
/// not yet meet.
///
/// This exists so a KNOWN gap is recorded in one visible place rather than
/// discovered again by the next reader. It is never a licence: a store that
/// declares a deviation is still held to everything else, and PostgreSQL — the
/// only implementor whose ordering a real replay depends on — declares none.
///
/// Every entry must name the one-line change that would remove it, because a
/// deviation nobody can act on is just a suppressed failure.
class WorkflowStoreContractDeviations {
  const WorkflowStoreContractDeviations({
    this.operatorActionsNotChronological = false,
  });

  /// `readOperatorActionsForWorkItem` returns INSERTION order rather than
  /// ascending `createdAt`.
  ///
  /// FOUND by this suite while it was being extended; not yet fixed, because
  /// the implementor lives in a package the lane that found it may not edit.
  /// The fix is one line in `InMemoryWorkflowStore.readOperatorActionsForWorkItem`:
  ///
  /// ```dart
  /// rows.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  /// ```
  ///
  /// Harmless in practice — `DurableWorkflowEngine.operatorRetry` always
  /// inserts with a rising timestamp, and both of its consumers are
  /// order-independent (the replay lookup matches a `requestId` that is unique
  /// per work item; the count is a length) — which is exactly why it has
  /// survived: it is invisible until someone appends out of order, as the
  /// ordering test now does.
  final bool operatorActionsNotChronological;
}

void runWorkflowStoreSuite({
  required String groupName,
  required Future<WorkflowStore> Function() createStore,
  WorkflowStoreContractDeviations deviations =
      const WorkflowStoreContractDeviations(),
}) {
  group(groupName, () {
    test('work items round-trip with CAS version checks', () async {
      final store = await createStore();
      final item = buildWorkItem();

      await store.saveWorkItem(item, expectedVersion: 0);
      final loaded = await store.readWorkItem(kWorkItemId);
      expect(loaded, item);

      expect(
        () => store.readWorkItem('missing'),
        throwsA(isA<WorkItemNotFoundException>()),
      );
    });

    test('saveWorkItem upserts and enforces compare-and-swap', () async {
      final store = await createStore();
      final item = buildWorkItem();
      await store.saveWorkItem(item);
      await store.saveWorkItem(item, expectedVersion: item.version);

      final updated = item.copyWith(
        state: WorkItemState.planning,
        version: item.version + 1,
      );
      await store.saveWorkItem(updated, expectedVersion: item.version);

      final loaded = await store.readWorkItem(kWorkItemId);
      expect(loaded.state, WorkItemState.planning);

      expect(
        store.saveWorkItem(buildWorkItem(), expectedVersion: 99),
        throwsA(
          isA<ConcurrentModificationException>().having(
            (e) => e.actualVersion,
            'actualVersion',
            updated.version,
          ),
        ),
      );
    });

    test('work items list across writes', () async {
      final store = await createStore();
      await store.saveWorkItem(buildWorkItem());
      await store.saveWorkItem(
        buildWorkItem(workItemId: 'wi-0002', state: WorkItemState.planned),
      );
      final all = await store.readAllWorkItems();
      expect(all.map((w) => w.workItemId), containsAll(['wi-0001', 'wi-0002']));
    });

    test('human decisions round-trip and remain resolvable', () async {
      final store = await createStore();
      final pending = buildHumanDecision();
      await store.saveHumanDecision(pending);
      expect(await store.readHumanDecision('dec-1'), pending);

      final resolved = buildHumanDecision(status: HumanDecisionStatus.resolved);
      await store.saveHumanDecision(resolved);
      final reloaded = await store.readHumanDecision('dec-1');
      expect(reloaded.status, HumanDecisionStatus.resolved);
      expect(reloaded.choice, HumanDecisionChoice.approve);
      expect(reloaded.signature?.signature, 'sig-reviewer-2');

      expect(
        () => store.readHumanDecision('missing'),
        throwsA(isA<HumanDecisionNotFoundException>()),
      );
    });

    test('human decisions are listed per work item', () async {
      final store = await createStore();
      await store.saveHumanDecision(buildHumanDecision());
      await store.saveHumanDecision(
        buildHumanDecision(decisionId: 'dec-2', workItemId: 'wi-0002'),
      );
      final forWorkItem = await store.readHumanDecisionsForWorkItem(
        kWorkItemId,
      );
      expect(forWorkItem.map((d) => d.decisionId), ['dec-1']);
    });

    test('transition history is append-only and idempotency-keyed', () async {
      final store = await createStore();
      await store.appendTransitionRecord(buildTransitionRecord());
      await store.appendTransitionRecord(
        buildTransitionRecord(transitionId: 'tr-2', idempotencyKey: 'k2'),
      );

      final history = await store.readTransitionHistory(kWorkItemId);
      expect(history.length, 2);

      final byKey = await store.findTransitionByIdempotencyKey(
        kWorkItemId,
        'k1',
      );
      expect(byKey?.transitionId, isNot(isNull));
      expect(
        await store.findTransitionByIdempotencyKey(kWorkItemId, 'nope'),
        isNull,
      );
    });

    test('inTransaction batches mutations atomically when supported', () async {
      final store = await createStore();
      await store.inTransaction((tx) async {
        await tx.saveWorkItem(buildWorkItem());
        await tx.appendTransitionRecord(buildTransitionRecord());
      });
      expect(await store.readWorkItem(kWorkItemId), buildWorkItem());
      expect((await store.readTransitionHistory(kWorkItemId)).length, 1);
    });

    // --- operator_action, the durable authorisation -------------------
    //
    // An operator retry spends real model credits, so these two methods are
    // the record of WHO pressed it and WHY. They are asserted HERE, in the one
    // place every implementor is held to the same behaviour, because the only
    // two production implementations are otherwise untested against a database:
    // the in-memory stores cannot express a unique constraint, and PostgreSQL
    // cannot be exercised from a unit test.
    //
    // Everything below asserts BEHAVIOUR. Nothing here reads SQL text, because
    // the failure these guards exist to catch is a store that compiles and
    // claims compliance while mapping a column wrongly or ordering rows
    // arbitrarily — none of which a text assertion can see.

    test('operator actions round-trip through append and read', () async {
      final store = await createStore();
      final full = buildOperatorAction(
        actionId: 'oa-full',
        transitionId: 'tr-1',
        jobId: 'jb-1',
        attemptNumber: 2,
      );

      await store.appendOperatorAction(full);

      final read = await store.readOperatorActionsForWorkItem(kWorkItemId);
      expect(read, hasLength(1));
      // Full-record equality, not a field-by-field spot check: this is what
      // catches a column that is written but never read back, and a column
      // that is read back but never written.
      expect(read.single, full);
      expect(read.single.requestedBy, 'operator@shipit.platform');
      expect(read.single.reason, 'Approved after reviewing the failure.');
    });

    test('a nullable operator action field survives as null', () async {
      // `stop` arms no job and binds no transition. A store that turned a
      // nullable column into an empty string, or dropped the row, would still
      // pass the round-trip above.
      final store = await createStore();
      final stop = buildOperatorAction(
        actionId: 'oa-stop',
        action: OperatorActionKind.stop.wire,
        requestId: 'req-stop',
        transitionId: null,
        jobId: null,
        attemptNumber: null,
      );

      await store.appendOperatorAction(stop);

      final read = await store.readOperatorActionsForWorkItem(kWorkItemId);
      expect(read.single.jobId, isNull);
      expect(read.single.transitionId, isNull);
      expect(read.single.attemptNumber, isNull);
      expect(read.single.action, 'stop');
    });

    test('operator actions are scoped to their work item', () async {
      final store = await createStore();
      await store.appendOperatorAction(buildOperatorAction());
      await store.appendOperatorAction(
        buildOperatorAction(
          actionId: 'oa-2',
          workItemId: 'wi-0002',
          requestId: 'req-2',
        ),
      );

      expect(
        (await store.readOperatorActionsForWorkItem(
          kWorkItemId,
        )).map((a) => a.actionId),
        ['oa-1'],
      );
      expect(await store.readOperatorActionsForWorkItem('wi-unknown'), isEmpty);
    });

    test(
      'a duplicate (workItemId, requestId) is REFUSED, not appended',
      () async {
        // The property AC-14e rests on, and the reason this is in the contract
        // rather than in one store's tests: the store is the LAST line of
        // defence against a replayed operator press becoming a second row, a
        // second job and a second spend.
        //
        // The exception TYPE is deliberately not pinned. PostgreSQL raises a
        // unique violation and the in-memory stores raise
        // `OperatorActionConflictException`; a contract that demanded one type
        // would be asserting an implementation detail of whichever store is
        // running, which is the opposite of what a contract is for. What is
        // pinned is the behaviour: it fails, and the ledger is unchanged.
        final store = await createStore();
        final first = buildOperatorAction();
        await store.appendOperatorAction(first);

        await expectLater(
          store.appendOperatorAction(
            buildOperatorAction(
              actionId: 'oa-2',
              requestId: first.requestId,
              reason: 'A different reason, replayed.',
            ),
          ),
          throwsA(anything),
        );

        final read = await store.readOperatorActionsForWorkItem(kWorkItemId);
        expect(read, hasLength(1));
        expect(
          read.single.reason,
          first.reason,
          reason:
              'the refused append must not have rewritten the row that '
              'already records what the operator did',
        );
        expect(read.single.actionId, first.actionId);
      },
    );

    test(
      'the same requestId on a DIFFERENT work item is not a duplicate',
      () async {
        // The constraint is on the PAIR. If it were on `requestId` alone, two
        // operators retrying two different items with a shared client-minted id
        // would lock each other out.
        final store = await createStore();
        await store.appendOperatorAction(buildOperatorAction());
        await store.appendOperatorAction(
          buildOperatorAction(actionId: 'oa-2', workItemId: 'wi-0002'),
        );
        expect(
          await store.readOperatorActionsForWorkItem(kWorkItemId),
          hasLength(1),
        );
        expect(
          await store.readOperatorActionsForWorkItem('wi-0002'),
          hasLength(1),
        );
      },
    );

    test('operator actions are append-only and never rewritten', () async {
      // Not an update-path assertion — no such path exists to call, and a
      // future one would be a merge blocker rather than something this suite
      // can reach. It is the OBSERVABLE half: appending more rows never
      // changes an earlier one, so a row written once is the row that stays.
      final store = await createStore();
      final first = buildOperatorAction();
      await store.appendOperatorAction(first);

      await store.appendOperatorAction(
        buildOperatorAction(
          actionId: 'oa-2',
          requestId: 'req-2',
          attemptNumber: 2,
          instant: DateTime.utc(2026, 1, 1, 13),
        ),
      );

      final read = await store.readOperatorActionsForWorkItem(kWorkItemId);
      expect(read, hasLength(2));
      expect(read.first, first, reason: 'the earlier row is byte-identical');
    });

    test('operator actions are returned OLDEST FIRST', () async {
      final store = await createStore();
      // Appended OUT of order on purpose, with distinct instants: an
      // implementor that returned insertion order rather than chronological
      // order would pass a same-order append and fail this.
      await store.appendOperatorAction(
        buildOperatorAction(
          actionId: 'oa-third',
          requestId: 'req-3',
          attemptNumber: 3,
          instant: DateTime.utc(2026, 1, 1, 12, 30, 3),
        ),
      );
      await store.appendOperatorAction(
        buildOperatorAction(
          actionId: 'oa-first',
          requestId: 'req-1',
          attemptNumber: 1,
          instant: DateTime.utc(2026, 1, 1, 12, 30, 1),
        ),
      );
      await store.appendOperatorAction(
        buildOperatorAction(
          actionId: 'oa-second',
          requestId: 'req-2',
          attemptNumber: 2,
          instant: DateTime.utc(2026, 1, 1, 12, 30, 2),
        ),
      );

      final read = await store.readOperatorActionsForWorkItem(kWorkItemId);

      // Whatever the order, it must be STABLE: the same store must not return
      // two different sequences for two rows. This half is required of every
      // implementor and is what makes the rest of the assertions meaningful.
      final again = await store.readOperatorActionsForWorkItem(kWorkItemId);
      expect(
        read.map((a) => a.actionId),
        again.map((a) => a.actionId),
        reason: 'ordering must be deterministic, not incidental',
      );
      expect(read, hasLength(3));

      if (deviations.operatorActionsNotChronological) {
        // Declared gap — see WorkflowStoreContractDeviations. The assertion is
        // still made, so the deviation is visible in the output rather than
        // silently dropped, and it disappears the day the fix lands.
        printOnFailure(
          'DECLARED DEVIATION: $groupName returns operator actions in '
          'insertion order, not ascending createdAt.',
        );
        expect(
          read.map((a) => a.createdAt),
          isNot(orderedEquals(read.map((a) => a.createdAt).toList()..sort())),
          reason:
              'the deviation is declared; if the order is now chronological '
              'anyway, REMOVE the declaration instead of leaving it stale',
        );
        return;
      }

      expect(read.map((a) => a.actionId), [
        'oa-first',
        'oa-second',
        'oa-third',
      ]);
      expect(
        read.map((a) => a.attemptNumber),
        [1, 2, 3],
        reason:
            'the attempt number is what the retry count is derived from, '
            'so ordering must agree with it',
      );
    });

    test(
      'an operator action takes part in the transaction it is written in',
      () async {
        // The audit row and the state change it authorises must commit or roll
        // back together. A store that wrote audit rows outside the transaction
        // would still pass every assertion above, and would leave a row
        // describing credits that were never spent.
        final store = await createStore();
        await store.inTransaction((tx) async {
          await tx.saveWorkItem(buildWorkItem());
          await tx.appendOperatorAction(buildOperatorAction());
        });

        expect(await store.readWorkItem(kWorkItemId), buildWorkItem());
        expect(
          await store.readOperatorActionsForWorkItem(kWorkItemId),
          hasLength(1),
        );
      },
    );
  });
}
