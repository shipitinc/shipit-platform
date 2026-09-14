import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'fixtures.dart';

/// Workflow store contract suite. Runs against any [WorkflowStore]
/// implementation (in-memory, file-backed, PostgreSQL).
void runWorkflowStoreSuite({
  required String groupName,
  required Future<WorkflowStore> Function() createStore,
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
  });
}
