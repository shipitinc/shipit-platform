import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

/// AC-14a-e, AC-10, AC-13, AC-19c, AC-37 — the `operator_action` audit ledger.
///
/// A retry spends real model credits, so "who pressed it and why" has to be
/// durable, and it has to be the SAME COMMIT as the state change that spends
/// them. Every test here is written to fail if that pairing is ever broken:
///// a lost compare-and-swap must leave NOTHING behind, not a row describing a
/// move that never happened.
///
/// Three doubles carry the weight:
///
///  * [TransactionScopeProbe] hands `inTransaction` a store handle that is NOT
///    `this`, so an audit row written outside the transaction is
///    distinguishable from one written inside it. The real Postgres store
///    passes `this`, so without this probe the property would be untested.
///  * [CasLosingStore] makes the work-item compare-and-swap lose, once, and
///    optionally records a COMPETING operator action in the same breath — the
///    exact race the brief describes.
///  * [RollbackStore] snapshots and restores on throw, which is what a real
///    database transaction does and what neither in-memory store models.
void main() {
  const requestedBy = 'hum@shipit.platform';
  const reason = 'Model credits approved by the on-call engineer';

  group('AC-14a a successful retry writes exactly one row per intent', () {
    test('through the real engine and the real in-memory store', () async {
      final store = InMemoryWorkflowStore();
      final engine = DurableWorkflowEngine(store: store);
      final id = await _seedFailedDefect(engine);

      await engine.operatorRetry(
        workItemId: id,
        requestedBy: requestedBy,
        reason: reason,
        requestId: 'req-1',
      );

      final rows = await store.readOperatorActionsForWorkItem(id);
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.action, 'retry');
      expect(row.requestedBy, requestedBy);
      expect(row.reason, reason);
      expect(row.fromState, WorkItemState.agentFailed.wire);
      expect(row.toState, WorkItemState.designNotRequired.wire);
      expect(row.requestId, 'req-1');
      expect(row.attemptNumber, 1);
      // A retry arms a job, so `jobId` is the column that answers "which durable
      // action armed this job?"; it is stamped when the job is known.
      expect(row.jobId, isNull);
    });

    test(
      'through a store whose transaction handle is a distinct instance',
      () async {
        // Proves the write is on `tx`, not on the engine's own store reference.
        final inner = InMemoryWorkflowStore();
        final id = await _seedFailedDefect(DurableWorkflowEngine(store: inner));
        final probe = TransactionScopeProbe(inner);
        final engine = DurableWorkflowEngine(store: probe);

        await engine.operatorRetry(
          workItemId: id,
          requestedBy: requestedBy,
          reason: reason,
          requestId: 'req-1',
        );

        expect(probe.operatorActionsOnTx, 1);
        expect(
          probe.operatorActionsOutsideTransaction,
          0,
          reason:
              'there must be no code path that writes an audit row outside '
              'the transition transaction',
        );
        expect(await inner.readOperatorActionsForWorkItem(id), hasLength(1));
      },
    );
  });

  group('AC-14b the audit row and the state change commit or roll back '
      'together', () {
    test('a lost compare-and-swap leaves ZERO audit rows', () async {
      final inner = InMemoryWorkflowStore();
      final id = await _seedFailedDefect(DurableWorkflowEngine(store: inner));
      final lossy = CasLosingStore(inner);
      final engine = DurableWorkflowEngine(store: lossy);
      lossy.transitionsBeforeRetry = (await inner.readTransitionHistory(
        id,
      )).length;

      await expectLater(
        engine.operatorRetry(
          workItemId: id,
          requestedBy: requestedBy,
          reason: reason,
          requestId: 'req-1',
          maxCompareAndSwapAttempts: 1,
        ),
        throwsA(isA<ConcurrentModificationException>()),
      );

      expect(
        await inner.readOperatorActionsForWorkItem(id),
        isEmpty,
        reason:
            'no audit row without the move — a refused write describes '
            'credits that were never spent',
      );
      expect((await inner.readWorkItem(id)).state, WorkItemState.agentFailed);
      expect((await inner.readWorkItem(id)).metadata?['triageAttempt'], isNull);

      // The transition record is written after the CAS too, so the history is
      // exactly what it was before the attempt — no new row describing a move
      // that never happened.
      final history = await inner.readTransitionHistory(id);
      expect(history, hasLength(lossy.transitionsBeforeRetry));
      expect(
        history.where(
          (r) =>
              r.fromState == WorkItemState.agentFailed &&
              r.toState == WorkItemState.designNotRequired,
        ),
        isEmpty,
      );
    });

    test('a transaction that throws rolls the work item back too', () async {
      final inner = InMemoryWorkflowStore();
      final id = await _seedFailedDefect(DurableWorkflowEngine(store: inner));
      final rollback = RollbackStore(inner);
      final engine = DurableWorkflowEngine(store: rollback);

      // The transition-record write fails AFTER the item has been saved. If
      // the audit row were written before the item, or outside the
      // transaction, it would survive; it must not.
      rollback.failTransitionRecordAppends = true;
      await expectLater(
        engine.operatorRetry(
          workItemId: id,
          requestedBy: requestedBy,
          reason: reason,
          requestId: 'req-1',
        ),
        throwsA(isA<StateError>()),
      );

      expect(await inner.readOperatorActionsForWorkItem(id), isEmpty);
      expect(
        (await inner.readWorkItem(id)).state,
        WorkItemState.agentFailed,
        reason: 'the rollback must undo the move as well as the audit row',
      );
    });

    test('a refused retry writes NO audit row at all', () async {
      final store = InMemoryWorkflowStore();
      final engine = DurableWorkflowEngine(store: store);
      final id = await _seedFailedDefect(engine);

      // First retry succeeds and the item moves to designNotRequired.
      await engine.operatorRetry(
        workItemId: id,
        requestedBy: requestedBy,
        reason: reason,
        requestId: 'req-1',
      );

      // A SECOND operator presses retry while the item is already back in the
      // retry's own target state. `designNotRequired -> designNotRequired` is
      // a self-transition: absent from the table, and `_isGenericEscape`
      // returns false for `to == from`. So the attempt is REFUSED — and must
      // leave nothing behind, because nothing was taken.
      await expectLater(
        engine.operatorRetry(
          workItemId: id,
          requestedBy: requestedBy,
          reason: reason,
          requestId: 'req-2',
        ),
        throwsA(isA<WorkflowTransitionRejectedException>()),
      );

      final rows = await store.readOperatorActionsForWorkItem(id);
      expect(rows, hasLength(1), reason: 'the refused attempt left no row');
      expect(rows.single.requestId, 'req-1');
      expect(await engine.operatorRetryCount(id), 1);

      final rejected = (await store.readTransitionHistory(
        id,
      )).where((r) => r.outcome == TransitionOutcome.rejected);
      expect(
        rejected,
        isNotEmpty,
        reason:
            'a refused attempt is still recorded as an attempt, by the '
            'rejected transition record',
      );
    });
  });

  group('AC-14c the audit row names the transition it authorised', () {
    test(
      'transitionId equals the accepted transition, and it is the latest',
      () async {
        final store = InMemoryWorkflowStore();
        final engine = DurableWorkflowEngine(store: store);
        final id = await _seedFailedDefect(engine);

        await engine.operatorRetry(
          workItemId: id,
          requestedBy: requestedBy,
          reason: reason,
          requestId: 'req-1',
        );

        final row = (await store.readOperatorActionsForWorkItem(id)).single;
        final history = await store.readTransitionHistory(id);
        final accepted = history
            .where((r) => r.outcome == TransitionOutcome.accepted)
            .toList();

        expect(row.transitionId, isNotNull);
        expect(accepted.map((r) => r.transitionId), contains(row.transitionId));
        expect(
          accepted.map((r) => r.transitionId).toList().last,
          row.transitionId,
          reason:
              'the audit row must name the item\'s LATEST transition at the '
              'moment of dispatch, not any older one',
        );
      },
    );
  });

  group('AC-13 / AC-10 one durable transaction, replay-safe', () {
    test('a committed retry leaves item, marker and ledger together', () async {
      final store = InMemoryWorkflowStore();
      final engine = DurableWorkflowEngine(store: store);
      final id = await _seedFailedDefect(engine);

      final updated = await engine.operatorRetry(
        workItemId: id,
        requestedBy: requestedBy,
        reason: reason,
        requestId: 'req-1',
        idempotencyKey: 'operator-retry:req-1',
      );

      expect(updated.state, WorkItemState.designNotRequired);
      expect(updated.metadata?['triageAttempt'], 1);

      final accepted = (await store.readTransitionHistory(
        id,
      )).where((r) => r.outcome == TransitionOutcome.accepted).last;
      expect(accepted.reason, reason);
      expect(accepted.actorType, ActorType.orchestrator);
      expect(
        accepted.outcome,
        TransitionOutcome.accepted,
        reason:
            'an operator reason must not relabel an accepted transition '
            'as rejected',
      );
      expect(accepted.idempotencyKey, 'operator-retry:req-1');
    });

    test('a replay of the same requestId returns the same item and writes '
        'nothing', () async {
      final store = InMemoryWorkflowStore();
      final engine = DurableWorkflowEngine(store: store);
      final id = await _seedFailedDefect(engine);

      final first = await engine.operatorRetry(
        workItemId: id,
        requestedBy: requestedBy,
        reason: reason,
        requestId: 'req-1',
      );
      final transitionsAfterFirst = (await store.readTransitionHistory(
        id,
      )).length;

      final second = await engine.operatorRetry(
        workItemId: id,
        requestedBy: requestedBy,
        reason: reason,
        requestId: 'req-1',
      );

      expect(second.state, first.state);
      expect(second.version, first.version);
      expect(await store.readOperatorActionsForWorkItem(id), hasLength(1));
      expect(
        (await store.readTransitionHistory(id)).length,
        transitionsAfterFirst,
        reason: 'a network retry must not produce a second write',
      );
    });

    test(
      'the durable replay guard holds even with NO idempotency key',
      () async {
        // The audit row is the authoritative idempotency record; the
        // transition's idempotency key is only a second, independent witness.
        // A caller that omits the key must still not spend twice.
        final store = InMemoryWorkflowStore();
        final engine = DurableWorkflowEngine(store: store);
        final id = await _seedFailedDefect(engine);

        await engine.operatorRetry(
          workItemId: id,
          requestedBy: requestedBy,
          reason: reason,
          requestId: 'req-1',
        );
        await engine.operatorRetry(
          workItemId: id,
          requestedBy: requestedBy,
          reason: reason,
          requestId: 'req-1',
        );

        expect(await store.readOperatorActionsForWorkItem(id), hasLength(1));
        expect(
          (await store.readWorkItem(id)).metadata?['triageAttempt'],
          1,
          reason:
              'a replay must not mint a second attempt marker, or the '
              'second job would never be created at all',
        );
      },
    );

    test(
      'a second, deliberate retry gets its OWN row and attempt number',
      () async {
        final store = InMemoryWorkflowStore();
        final engine = DurableWorkflowEngine(store: store);
        final id = await _seedFailedDefect(engine);

        await engine.operatorRetry(
          workItemId: id,
          requestedBy: requestedBy,
          reason: reason,
          requestId: 'req-1',
        );
        // The retry's own execution fails and the item returns to agentFailed.
        await _failAgain(engine, id);
        await engine.operatorRetry(
          workItemId: id,
          requestedBy: requestedBy,
          reason: reason,
          requestId: 'req-2',
        );

        final rows = await store.readOperatorActionsForWorkItem(id);
        expect(rows.map((r) => r.requestId), ['req-1', 'req-2']);
        expect(rows.map((r) => r.attemptNumber), [1, 2]);
        expect(
          rows.map((r) => r.transitionId).toSet(),
          hasLength(2),
          reason:
              'each attempt names its own transition; the first row is a '
              'record of the past, not a standing licence',
        );
        expect((await store.readWorkItem(id)).metadata?['triageAttempt'], 2);
      },
    );
  });

  group('AC-37 metadataMerge MERGES, it never replaces', () {
    test('all eight defect-payload keys survive byte-identical', () async {
      final store = InMemoryWorkflowStore();
      final engine = DurableWorkflowEngine(store: store);
      final id = await _seedFailedDefect(engine);

      final before = (await store.readWorkItem(id)).metadata!;
      expect(before.keys, containsAll(_defectPayloadKeys));

      await engine.operatorRetry(
        workItemId: id,
        requestedBy: requestedBy,
        reason: reason,
        requestId: 'req-1',
      );

      final after = (await store.readWorkItem(id)).metadata!;
      for (final key in _defectPayloadKeys) {
        expect(
          after[key],
          before[key],
          reason:
              '$key must survive a retry unchanged. A REPLACE would wipe '
              'the payload the triage instruction reads, and the retried job '
              'would classify nothing while looking healthy.',
        );
      }
      expect(after['triageAttempt'], 1);
      expect(after.length, before.length + 1);
    });

    test('an existing triageAttempt is OVERWRITTEN by the newer one', () async {
      // Merge, not append: the newest attempt number must win, or the dedupe
      // key would never change and a second retry would reuse a consumed key.
      final store = InMemoryWorkflowStore();
      final engine = DurableWorkflowEngine(store: store);
      final id = await _seedFailedDefect(engine);

      // A stale marker from some earlier path must not win: the attempt number
      // is counted from the durable ledger, and merge means the newest value
      // REPLACES the old one rather than the two being combined or kept.
      await engine.transition(
        workItemId: id,
        to: WorkItemState.designNotRequired,
        trigger: TransitionTrigger.systemEvent,
        metadataMerge: const {'triageAttempt': 7},
      );
      expect((await store.readWorkItem(id)).metadata?['triageAttempt'], 7);

      await _failAgain(engine, id);
      await engine.operatorRetry(
        workItemId: id,
        requestedBy: requestedBy,
        reason: reason,
        requestId: 'req-9',
      );
      final after = (await store.readWorkItem(id)).metadata!;
      expect(
        after['triageAttempt'],
        1,
        reason:
            'the ledger says this is the first recorded retry, and the '
            'marker must say so too — a kept 7 would make the dedupe key '
            'collide with nothing and enqueue nothing',
      );
      expect(
        after['defectId'],
        before0[id]!['defectId'],
        reason: 'the defect payload is untouched by the overwrite',
      );
    });
  });

  group('AC-19c the attempt number is counted from the ledger', () {
    test(
      'a lost compare-and-swap RE-COUNTS and mints the next attempt',
      () async {
        final inner = InMemoryWorkflowStore();
        final id = await _seedFailedDefect(DurableWorkflowEngine(store: inner));
        final lossy = CasLosingStore(inner, competingRequestId: 'req-other');
        final engine = DurableWorkflowEngine(store: lossy);

        // Pass 1 computes n = 1 (no rows yet), loses the CAS, and by then a
        // competing operator action has committed. Pass 2 must RE-COUNT.
        await engine.operatorRetry(
          workItemId: id,
          requestedBy: requestedBy,
          reason: reason,
          requestId: 'req-mine',
        );

        final rows = await inner.readOperatorActionsForWorkItem(id);
        expect(rows, hasLength(2));
        expect(rows.map((r) => r.requestId).toSet(), {'req-other', 'req-mine'});
        expect(rows.map((r) => r.attemptNumber).toList()..sort(), [1, 2]);
        expect(
          (await inner.readWorkItem(id)).metadata?['triageAttempt'],
          2,
          reason:
              'two deliberate operator actions are two attempts, and the '
              'dedupe key must differ so the second retry really enqueues',
        );
      },
    );

    test('a lost CAS with no competitor keeps n = 1', () async {
      // The opposite case, and it matters: losing the CAS is not itself a
      // second operator action, so the attempt number must NOT advance.
      final inner = InMemoryWorkflowStore();
      final id = await _seedFailedDefect(DurableWorkflowEngine(store: inner));
      final lossy = CasLosingStore(inner);
      final engine = DurableWorkflowEngine(store: lossy);

      await engine.operatorRetry(
        workItemId: id,
        requestedBy: requestedBy,
        reason: reason,
        requestId: 'req-1',
      );

      expect(await inner.readOperatorActionsForWorkItem(id), hasLength(1));
      expect((await inner.readWorkItem(id)).metadata?['triageAttempt'], 1);
    });

    test('the bound is real: a permanently losing store gives up', () async {
      final inner = InMemoryWorkflowStore();
      final id = await _seedFailedDefect(DurableWorkflowEngine(store: inner));
      final lossy = CasLosingStore(inner, alwaysLose: true);
      final engine = DurableWorkflowEngine(store: lossy);

      await expectLater(
        engine.operatorRetry(
          workItemId: id,
          requestedBy: requestedBy,
          reason: reason,
          requestId: 'req-1',
          maxCompareAndSwapAttempts: 3,
        ),
        throwsA(isA<ConcurrentModificationException>()),
      );
      expect(await inner.readOperatorActionsForWorkItem(id), isEmpty);
      expect(lossy.saveAttempts, 3, reason: 'bounded, never unbounded');
    });
  });

  group('operatorRetryCount reads the durable ledger', () {
    test('counts only retry rows', () async {
      final store = InMemoryWorkflowStore();
      final engine = DurableWorkflowEngine(store: store);
      final id = await _seedFailedDefect(engine);

      expect(await engine.operatorRetryCount(id), 0);
      expect(await engine.nextOperatorRetryAttempt(id), 1);

      await store.appendOperatorAction(
        OperatorActionRecord(
          actionId: 'oa-stop',
          workItemId: id,
          action: 'stop',
          fromState: WorkItemState.agentFailed.wire,
          toState: WorkItemState.cancelled.wire,
          requestedBy: requestedBy,
          reason: 'stopping',
          requestId: 'req-stop',
          createdAt: DateTime.utc(2026, 6, 1),
        ),
      );
      expect(await engine.operatorRetryCount(id), 0);
      expect(await engine.nextOperatorRetryAttempt(id), 1);
    });

    test('rows are returned OLDEST FIRST', () async {
      final store = InMemoryWorkflowStore();
      final engine = DurableWorkflowEngine(store: store);
      final id = await _seedFailedDefect(engine);

      for (final requestId in ['req-1', 'req-2']) {
        await engine.operatorRetry(
          workItemId: id,
          requestedBy: requestedBy,
          reason: reason,
          requestId: requestId,
        );
        await _failAgain(engine, id);
      }

      expect(
        (await store.readOperatorActionsForWorkItem(
          id,
        )).map((r) => r.requestId),
        ['req-1', 'req-2'],
      );
    });
  });

  group('the stores keep operator actions across a restart', () {
    test('FileJsonWorkflowStore reloads the ledger', () async {
      final dir = await Directory.systemTemp.createTemp('op-action-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/workflow.json');

      final first = FileJsonWorkflowStore(file);
      final engine = DurableWorkflowEngine(store: first);
      final id = await _seedFailedDefect(engine);
      await engine.operatorRetry(
        workItemId: id,
        requestedBy: requestedBy,
        reason: reason,
        requestId: 'req-1',
      );

      final reloaded = FileJsonWorkflowStore(file);
      final rows = await reloaded.readOperatorActionsForWorkItem(id);
      expect(rows, hasLength(1));
      expect(rows.single.requestedBy, requestedBy);
      expect(rows.single.transitionId, isNotNull);
      expect((await reloaded.readWorkItem(id)).metadata?['triageAttempt'], 1);
    });
  });

  group('OperatorActionRecord round-trips and refuses a duplicate intent', () {
    test('json round-trip preserves every field', () {
      final record = OperatorActionRecord(
        actionId: 'oa-1',
        workItemId: 'wi-1',
        action: 'retry',
        fromState: 'agent_failed',
        toState: 'design_not_required',
        requestedBy: 'hum@shipit.platform',
        reason: 'because',
        requestId: 'req-1',
        transitionId: 'tr-1',
        attemptNumber: 2,
        jobId: 'jb-1',
        createdAt: DateTime.utc(2026, 6, 1, 12, 30),
      );
      expect(OperatorActionRecord.fromJson(record.toJson()), record);
    });

    test(
      'a duplicate (workItemId, requestId) is refused, not appended',
      () async {
        // Models `operator_action_request_unique`, so the invariant is checked
        // by every store rather than only by the database that has the index.
        for (final store in <WorkflowStore>[
          InMemoryWorkflowStore(),
          FileJsonWorkflowStore(
            File(
              '${(await Directory.systemTemp.createTemp('op-dup-')).path}/w.json',
            ),
          ),
        ]) {
          final record = OperatorActionRecord(
            actionId: 'oa-1',
            workItemId: 'wi-1',
            action: 'retry',
            fromState: 'agent_failed',
            toState: 'design_not_required',
            requestedBy: 'hum@shipit.platform',
            reason: 'because',
            requestId: 'req-1',
            createdAt: DateTime.utc(2026, 6, 1),
          );
          await store.appendOperatorAction(record);
          await expectLater(
            store.appendOperatorAction(
              OperatorActionRecord(
                actionId: 'oa-2',
                workItemId: 'wi-1',
                action: 'retry',
                fromState: 'agent_failed',
                toState: 'design_not_required',
                requestedBy: 'hum@shipit.platform',
                reason: 'because again',
                requestId: 'req-1',
                createdAt: DateTime.utc(2026, 6, 2),
              ),
            ),
            throwsA(isA<OperatorActionConflictException>()),
          );
          expect(
            await store.readOperatorActionsForWorkItem('wi-1'),
            hasLength(1),
          );
        }
      },
    );
  });

  group('additive parameters behave exactly as before when omitted', () {
    test(
      'a transition with all three null is byte-identical to today',
      () async {
        final store = InMemoryWorkflowStore();
        final engine = DurableWorkflowEngine(store: store);
        final id = await _seedFailedDefect(engine);

        await engine.transition(
          workItemId: id,
          to: WorkItemState.designNotRequired,
          trigger: TransitionTrigger.systemEvent,
        );

        final item = await store.readWorkItem(id);
        // No marker, no ledger entry, and the accepted record keeps the reason
        // it always had on an accepted transition: null.
        expect(item.metadata?['triageAttempt'], isNull);
        expect(item.metadata!.keys, containsAll(_defectPayloadKeys));
        expect(await store.readOperatorActionsForWorkItem(id), isEmpty);
        final accepted = (await store.readTransitionHistory(
          id,
        )).where((r) => r.outcome == TransitionOutcome.accepted).last;
        expect(accepted.reason, isNull);
        expect(accepted.outcome, TransitionOutcome.accepted);
      },
    );
  });
}

/// The eight keys `triageDefectInstruction` reads off `WorkItem.metadata` to
/// build the agent prompt. Seven are read directly and `defectReporter` is
/// carried alongside them; a REPLACE would wipe them all.
const _defectPayloadKeys = <String>[
  'defectId',
  'defectTitle',
  'defectEvidence',
  'defectReporter',
  'defectSeverity',
  'defectDescription',
  'defectExpectedBehavior',
  'defectReproductionSteps',
];

final before0 = <String, Map<String, dynamic>>{};

/// A defect work item carrying the full payload, parked at [state].
Future<String> _seedItemAt(
  DurableWorkflowEngine engine,
  WorkItemState state, {
  String id = 'defect-1',
}) async {
  final metadata = <String, dynamic>{
    'defectId': 'DEF-1791686704991884',
    'defectTitle': 'Checkout total is wrong for multi-item carts',
    'defectEvidence': '[{"evidenceId":"ev-1","url":"https://x/1.png"}]',
    'defectReporter': 'customer@example.com',
    'defectSeverity': 'high',
    'defectDescription':
        'The checkout total ignores the second item in the cart.',
    'defectExpectedBehavior':
        'The total must include every line item in the cart.',
    'defectReproductionSteps': '1. Add two items\n2. Open checkout',
  };
  before0[id] = metadata;

  await engine.createWorkItem(
    workItemId: id,
    productId: 'prod-1',
    category: WorkItemCategory.bugfix,
    title: 'Triage reported defect DEF-1791686704991884',
    description:
        'A customer reported that the checkout total is wrong when a cart '
        'holds more than one item. Triage it and classify the defect.',
    metadata: metadata,
  );

  if (state == WorkItemState.draft) return id;

  await engine.transition(
    workItemId: id,
    to: WorkItemState.planning,
    trigger: TransitionTrigger.systemEvent,
  );
  if (state == WorkItemState.planning) return id;

  await engine.transition(
    workItemId: id,
    to: WorkItemState.planned,
    trigger: TransitionTrigger.systemEvent,
    context: const {'featureRef': 'feature/triage-queue'},
  );
  if (state == WorkItemState.planned) return id;

  await engine.transition(
    workItemId: id,
    to: WorkItemState.designNotRequired,
    trigger: TransitionTrigger.systemEvent,
  );
  if (state == WorkItemState.designNotRequired) return id;

  await engine.transition(
    workItemId: id,
    to: WorkItemState.agentExecuting,
    trigger: TransitionTrigger.systemEvent,
    context: const {'agentAvailable': true, 'capabilitiesMatch': true},
  );
  if (state == WorkItemState.agentExecuting) return id;

  await engine.transition(
    workItemId: id,
    to: WorkItemState.agentFailed,
    trigger: TransitionTrigger.systemEvent,
  );
  return id;
}

/// A defect item parked where an operator would find it: `agentFailed`.
Future<String> _seedFailedDefect(
  DurableWorkflowEngine engine, {
  String id = 'defect-1',
}) => _seedItemAt(engine, WorkItemState.agentFailed, id: id);

/// The retried run fails again and the item returns to `agentFailed`, which is
/// what makes a SECOND retry a distinct operator action rather than a replay.
Future<void> _failAgain(DurableWorkflowEngine engine, String id) async {
  await engine.transition(
    workItemId: id,
    to: WorkItemState.agentExecuting,
    trigger: TransitionTrigger.systemEvent,
    context: const {'agentAvailable': true, 'capabilitiesMatch': true},
  );
  await engine.transition(
    workItemId: id,
    to: WorkItemState.agentFailed,
    trigger: TransitionTrigger.systemEvent,
  );
}

/// Hands `inTransaction` a handle that is NOT `this`, so a write made outside
/// the transaction is distinguishable from one made inside it.
class TransactionScopeProbe implements WorkflowStore {
  TransactionScopeProbe(this._inner);

  final WorkflowStore _inner;
  late final _tx = _TxHandle(_inner);

  int operatorActionsOnTx = 0;
  int operatorActionsOutsideTransaction = 0;

  @override
  Future<void> appendOperatorAction(OperatorActionRecord record) {
    operatorActionsOutsideTransaction++;
    return _inner.appendOperatorAction(record);
  }

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(WorkflowStore store) body,
  ) async {
    _tx.operatorActions = 0;
    try {
      return await _inner.inTransaction<T>((_) => body(_tx));
    } finally {
      operatorActionsOnTx += _tx.operatorActions;
    }
  }

  @override
  Future<WorkItem> readWorkItem(String workItemId) =>
      _inner.readWorkItem(workItemId);

  @override
  Future<List<WorkItem>> readAllWorkItems() => _inner.readAllWorkItems();

  @override
  Future<void> saveWorkItem(WorkItem item, {int? expectedVersion}) =>
      _inner.saveWorkItem(item, expectedVersion: expectedVersion);

  @override
  Future<HumanDecision> readHumanDecision(String decisionId) =>
      _inner.readHumanDecision(decisionId);

  @override
  Future<List<HumanDecision>> readHumanDecisionsForWorkItem(
    String workItemId,
  ) => _inner.readHumanDecisionsForWorkItem(workItemId);

  @override
  Future<void> saveHumanDecision(HumanDecision decision) =>
      _inner.saveHumanDecision(decision);

  @override
  Future<List<WorkflowTransitionRecord>> readTransitionHistory(
    String workItemId,
  ) => _inner.readTransitionHistory(workItemId);

  @override
  Future<WorkflowTransitionRecord?> findTransitionByIdempotencyKey(
    String workItemId,
    String idempotencyKey,
  ) => _inner.findTransitionByIdempotencyKey(workItemId, idempotencyKey);

  @override
  Future<void> appendTransitionRecord(WorkflowTransitionRecord record) =>
      _inner.appendTransitionRecord(record);

  @override
  Future<List<OperatorActionRecord>> readOperatorActionsForWorkItem(
    String workItemId,
  ) => _inner.readOperatorActionsForWorkItem(workItemId);
}

class _TxHandle implements WorkflowStore {
  _TxHandle(this._inner);

  final WorkflowStore _inner;
  int operatorActions = 0;

  @override
  Future<void> appendOperatorAction(OperatorActionRecord record) {
    operatorActions++;
    return _inner.appendOperatorAction(record);
  }

  @override
  Future<WorkItem> readWorkItem(String workItemId) =>
      _inner.readWorkItem(workItemId);

  @override
  Future<List<WorkItem>> readAllWorkItems() => _inner.readAllWorkItems();

  @override
  Future<void> saveWorkItem(WorkItem item, {int? expectedVersion}) =>
      _inner.saveWorkItem(item, expectedVersion: expectedVersion);

  @override
  Future<HumanDecision> readHumanDecision(String decisionId) =>
      _inner.readHumanDecision(decisionId);

  @override
  Future<List<HumanDecision>> readHumanDecisionsForWorkItem(
    String workItemId,
  ) => _inner.readHumanDecisionsForWorkItem(workItemId);

  @override
  Future<void> saveHumanDecision(HumanDecision decision) =>
      _inner.saveHumanDecision(decision);

  @override
  Future<List<WorkflowTransitionRecord>> readTransitionHistory(
    String workItemId,
  ) => _inner.readTransitionHistory(workItemId);

  @override
  Future<WorkflowTransitionRecord?> findTransitionByIdempotencyKey(
    String workItemId,
    String idempotencyKey,
  ) => _inner.findTransitionByIdempotencyKey(workItemId, idempotencyKey);

  @override
  Future<void> appendTransitionRecord(WorkflowTransitionRecord record) =>
      _inner.appendTransitionRecord(record);

  @override
  Future<List<OperatorActionRecord>> readOperatorActionsForWorkItem(
    String workItemId,
  ) => _inner.readOperatorActionsForWorkItem(workItemId);

  @override
  Future<T> inTransaction<T>(Future<T> Function(WorkflowStore store) body) =>
      body(this);
}

/// Makes the work-item compare-and-swap lose, and optionally commits a
/// COMPETING operator action in the same instant — the race the retry's bounded
/// re-count exists for.
class CasLosingStore implements WorkflowStore {
  CasLosingStore(
    this._inner, {
    this.competingRequestId,
    this.alwaysLose = false,
  });

  final WorkflowStore _inner;
  final String? competingRequestId;
  final bool alwaysLose;

  int saveAttempts = 0;
  bool _fired = false;

  /// How many transition rows the item had before the retry attempt, captured
  /// by the test so "nothing new was written" is a real comparison rather than
  /// an absolute that the seeding history would break.
  int transitionsBeforeRetry = -1;

  @override
  Future<void> saveWorkItem(WorkItem item, {int? expectedVersion}) async {
    if (expectedVersion == null) return _inner.saveWorkItem(item);
    saveAttempts++;
    if (alwaysLose || !_fired) {
      _fired = true;
      final current = await _inner.readWorkItem(item.workItemId);
      await _inner.saveWorkItem(
        current.copyWith(
          updatedAt: DateTime.utc(2026, 6, 1),
          version: current.version + 1,
        ),
        expectedVersion: current.version,
      );
      final competitor = competingRequestId;
      if (competitor != null) {
        await _inner.appendOperatorAction(
          OperatorActionRecord(
            actionId: 'oa-competing',
            workItemId: item.workItemId,
            action: 'retry',
            fromState: current.state.wire,
            toState: WorkItemState.designNotRequired.wire,
            requestedBy: 'other@shipit.platform',
            reason: 'a competing operator won the same item',
            requestId: competitor,
            attemptNumber: 1,
            createdAt: DateTime.utc(2026, 6, 1),
          ),
        );
      }
    }
    return _inner.saveWorkItem(item, expectedVersion: expectedVersion);
  }

  @override
  Future<T> inTransaction<T>(Future<T> Function(WorkflowStore store) body) =>
      body(this);

  @override
  Future<WorkItem> readWorkItem(String workItemId) =>
      _inner.readWorkItem(workItemId);

  @override
  Future<List<WorkItem>> readAllWorkItems() => _inner.readAllWorkItems();

  @override
  Future<HumanDecision> readHumanDecision(String decisionId) =>
      _inner.readHumanDecision(decisionId);

  @override
  Future<List<HumanDecision>> readHumanDecisionsForWorkItem(
    String workItemId,
  ) => _inner.readHumanDecisionsForWorkItem(workItemId);

  @override
  Future<void> saveHumanDecision(HumanDecision decision) =>
      _inner.saveHumanDecision(decision);

  @override
  Future<List<WorkflowTransitionRecord>> readTransitionHistory(
    String workItemId,
  ) => _inner.readTransitionHistory(workItemId);

  @override
  Future<WorkflowTransitionRecord?> findTransitionByIdempotencyKey(
    String workItemId,
    String idempotencyKey,
  ) => _inner.findTransitionByIdempotencyKey(workItemId, idempotencyKey);

  @override
  Future<void> appendTransitionRecord(WorkflowTransitionRecord record) =>
      _inner.appendTransitionRecord(record);

  @override
  Future<void> appendOperatorAction(OperatorActionRecord record) =>
      _inner.appendOperatorAction(record);

  @override
  Future<List<OperatorActionRecord>> readOperatorActionsForWorkItem(
    String workItemId,
  ) => _inner.readOperatorActionsForWorkItem(workItemId);
}

/// Snapshots and restores on throw, which is what a database transaction does
/// and what neither in-memory store models.
class RollbackStore implements WorkflowStore {
  RollbackStore(this._inner);

  final WorkflowStore _inner;

  bool failTransitionRecordAppends = false;

  late List<WorkItem> _itemSnapshot;
  late List<WorkflowTransitionRecord> _recordSnapshot;
  late List<OperatorActionRecord> _actionSnapshot;

  @override
  Future<T> inTransaction<T>(
    Future<T> Function(WorkflowStore store) body,
  ) async {
    _itemSnapshot = await _inner.readAllWorkItems();
    _recordSnapshot = await _records();
    _actionSnapshot = await _actions();
    try {
      return await body(this);
    } catch (_) {
      for (final item in _itemSnapshot) {
        await _inner.saveWorkItem(item);
      }
      for (final record in _recordSnapshot) {
        await _inner.appendTransitionRecord(record);
      }
      for (final action in _actionSnapshot) {
        await _inner.appendOperatorAction(action);
      }
      rethrow;
    }
  }

  Future<List<WorkflowTransitionRecord>> _records() async {
    final all = <WorkflowTransitionRecord>[];
    for (final item in _itemSnapshot) {
      all.addAll(await _inner.readTransitionHistory(item.workItemId));
    }
    return all;
  }

  Future<List<OperatorActionRecord>> _actions() async {
    final all = <OperatorActionRecord>[];
    for (final item in _itemSnapshot) {
      all.addAll(await _inner.readOperatorActionsForWorkItem(item.workItemId));
    }
    return all;
  }

  @override
  Future<void> appendTransitionRecord(WorkflowTransitionRecord record) {
    if (failTransitionRecordAppends) {
      throw StateError('durable store unavailable during transition record');
    }
    return _inner.appendTransitionRecord(record);
  }

  @override
  Future<WorkItem> readWorkItem(String workItemId) =>
      _inner.readWorkItem(workItemId);

  @override
  Future<List<WorkItem>> readAllWorkItems() => _inner.readAllWorkItems();

  @override
  Future<void> saveWorkItem(WorkItem item, {int? expectedVersion}) =>
      _inner.saveWorkItem(item, expectedVersion: expectedVersion);

  @override
  Future<HumanDecision> readHumanDecision(String decisionId) =>
      _inner.readHumanDecision(decisionId);

  @override
  Future<List<HumanDecision>> readHumanDecisionsForWorkItem(
    String workItemId,
  ) => _inner.readHumanDecisionsForWorkItem(workItemId);

  @override
  Future<void> saveHumanDecision(HumanDecision decision) =>
      _inner.saveHumanDecision(decision);

  @override
  Future<List<WorkflowTransitionRecord>> readTransitionHistory(
    String workItemId,
  ) => _inner.readTransitionHistory(workItemId);

  @override
  Future<WorkflowTransitionRecord?> findTransitionByIdempotencyKey(
    String workItemId,
    String idempotencyKey,
  ) => _inner.findTransitionByIdempotencyKey(workItemId, idempotencyKey);

  @override
  Future<void> appendOperatorAction(OperatorActionRecord record) =>
      _inner.appendOperatorAction(record);

  @override
  Future<List<OperatorActionRecord>> readOperatorActionsForWorkItem(
    String workItemId,
  ) => _inner.readOperatorActionsForWorkItem(workItemId);
}
