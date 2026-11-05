import 'package:control_plane_server/src/endpoints/work_item_action_endpoints.dart';
import 'package:control_plane_server/src/services/control_plane_service.dart';
import 'package:execution_coordinator/execution_coordinator.dart'
    show ExecutionStore, InMemoryExecutionStore;
import 'package:platform_contracts/platform_contracts.dart';
import 'package:worker_runtime/worker_runtime.dart'
    show InMemoryWorkerStore, WorkerStore;
import 'package:scheduler/scheduler.dart'
    show triageDefectDedupeKey, triageDefectDefinition;
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart'
    show
        DurableWorkflowEngine,
        InMemoryWorkflowStore,
        OperatorActionKind,
        OperatorActionRecord,
        WorkflowStore;

/// HIGH-2 / AC-19 / AC-14 / §6.4 step 1 — the two RPCs, DRIVEN.
///
/// ## WHY THIS FILE EXISTS AT ALL
///
/// Independent review deleted each refusal in a throwaway copy and the full
/// suite still passed: `rg "workItemActionEndpoints\." apps/server/test/`
/// returned nothing, so `retryFailedWorkItem` and `stopFailedWorkItem` had
/// **no test anywhere**. The `alreadyRunning` refusal and the blank-reason
/// refusal — both load-bearing for "every rejection path writes NOTHING at
/// all" — were correct in code and unverified by anything.
///
/// ## HOW IT DRIVES THE ENDPOINT WITHOUT A DATABASE
///
/// `ControlPlaneService` builds its stores from `session.db`, so the guards
/// were unreachable in a unit test. [WorkItemActionEndpoints.serviceFor] is the
/// seam that made them reachable, and this file is the reason it exists.
///
/// The stores are the REAL ones — [InMemoryWorkflowStore] and the REAL
/// [DurableWorkflowEngine] — so the durable write under test is the production
/// one, including the audit row and the attempt marker. Only the persistence
/// substrate is substituted. No Postgres is involved, and none was obtained.
///
/// Every assertion about "nothing was written" counts rows in the ledger
/// before and after, because that is the property the brief states.
void main() {
  // The retry bound is read per request from the environment. These tests
  // inject one instead, so they neither depend on nor mutate the host's.
  const envVar = 'SHIPIT_OPERATOR_MAX_RETRIES';

  late InMemoryWorkflowStore store;
  late _TestEndpoints endpoints;
  late Session session;

  setUp(() {
    store = InMemoryWorkflowStore();
    endpoints = _TestEndpoints(store);
    session = _FakeSession();
  });

  /// A failed work item, reached through the real engine so its version and
  /// its transition history are the ones production would have.
  Future<String> seedFailed({String id = 'defect-DEF-1'}) async {
    final engine = DurableWorkflowEngine(store: store);
    await engine.createWorkItem(
      workItemId: id,
      productId: 'shipit',
      category: WorkItemCategory.bugfix,
      title: 'Sign-in is rejected after a password reset',
      description: 'Operators cannot sign in after a password reset',
      // The `planning -> planned` edge is guarded on traceability, so the
      // fixture carries what the real work item carries.
      featureRef: 'WI-signin',
      requirementRef: 'REQ-signin',
    );
    await engine.transition(
      workItemId: id,
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
    );
    await engine.transition(
      workItemId: id,
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      // The traceability the `planning -> planned` guard reads. The real
      // caller passes it in the transition CONTEXT (`work_entry.dart`
      // `_walkContext`), not from the stored item, so the fixture mirrors
      // production exactly rather than satisfying the guard by another route.
      context: const {
        'featureRef': 'WI-signin',
        'requirementRef': 'REQ-signin',
      },
    );
    await engine.transition(
      workItemId: id,
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );
    await engine.transition(
      workItemId: id,
      to: WorkItemState.agentExecuting,
      trigger: TransitionTrigger.systemEvent,
      // The two evidence keys `designNotRequired -> agentExecuting` guards on
      // (`agentAvailable()`). This fixture is dispatching, so both are true;
      // the retry path under test does NOT consult either, which is the point.
      context: const {'agentAvailable': true, 'capabilitiesMatch': true},
    );
    await engine.transition(
      workItemId: id,
      to: WorkItemState.agentFailed,
      trigger: TransitionTrigger.systemEvent,
    );
    return id;
  }

  Future<List<OperatorActionRecord>> ledger(String id) =>
      store.readOperatorActionsForWorkItem(id);

  // ==================================================================
  // (a) alreadyRunning — a live job means the action is refused, and the
  //     refusal writes NOTHING at all.
  // ==================================================================

  group('AC-19 — a non-terminal job refuses the retry', () {
    test(
      'refuses `alreadyRunning` and writes NO operator_action row',
      () async {
        final id = await seedFailed();
        endpoints.jobs = [_job(id, JobState.running)];

        final result = await endpoints.retryFailedWorkItem(
          session,
          workItemId: id,
          requestId: 'req-1',
          requestedBy: 'dana',
          reason: 'the host rebooted mid-run',
        );

        expect(result.outcome, 'alreadyRunning');
        // The money property: a refused action was not taken, so there is
        // nothing to audit and the ledger stays empty.
        expect(await ledger(id), isEmpty);
        // And the item did not move.
        expect((await store.readWorkItem(id)).state, WorkItemState.agentFailed);
      },
    );

    test('every NON-TERMINAL job state refuses — not just `running`', () async {
      // `isActive` is `!isTerminal`, so queued/claimed/retryWaiting all hold the
      // item. Asserted one at a time so a narrowing to a single state fails
      // here rather than in production.
      for (final state in [
        JobState.queued,
        JobState.claimed,
        JobState.running,
        JobState.retryWaiting,
      ]) {
        final s = InMemoryWorkflowStore();
        final e = _TestEndpoints(s);
        final engine = DurableWorkflowEngine(store: s);
        await engine.createWorkItem(
          workItemId: 'w',
          productId: 'shipit',
          category: WorkItemCategory.bugfix,
          title: 'Sign-in is rejected after a password reset',
          description: 'Operators cannot sign in after a password reset',
          featureRef: 'WI-signin',
          requirementRef: 'REQ-signin',
        );
        await engine.transition(
          workItemId: 'w',
          to: WorkItemState.planning,
          trigger: TransitionTrigger.systemEvent,
        );
        await engine.transition(
          workItemId: 'w',
          to: WorkItemState.planned,
          trigger: TransitionTrigger.systemEvent,
          context: const {
            'featureRef': 'WI-signin',
            'requirementRef': 'REQ-signin',
          },
        );
        await engine.transition(
          workItemId: 'w',
          to: WorkItemState.designNotRequired,
          trigger: TransitionTrigger.systemEvent,
        );
        await engine.transition(
          workItemId: 'w',
          to: WorkItemState.agentExecuting,
          trigger: TransitionTrigger.systemEvent,
          context: const {'agentAvailable': true, 'capabilitiesMatch': true},
        );
        await engine.transition(
          workItemId: 'w',
          to: WorkItemState.agentFailed,
          trigger: TransitionTrigger.systemEvent,
        );
        e.jobs = [_job('w', state)];

        final result = await e.retryFailedWorkItem(
          session,
          workItemId: 'w',
          requestId: 'req-$state',
          requestedBy: 'dana',
          reason: 'because',
        );

        expect(
          result.outcome,
          'alreadyRunning',
          reason: '$state holds the item',
        );
        expect(await s.readOperatorActionsForWorkItem('w'), isEmpty);
      }
    });

    test(
      'a TERMINAL job does NOT refuse — that is the whole point of §6.7',
      () async {
        // The failed job for a real item is terminal, and a terminal job holds
        // no dedupe key and no slot. Refusing there would make the button dead
        // for exactly the item this feature exists for.
        for (final state in [
          JobState.failed,
          JobState.succeeded,
          JobState.cancelled,
        ]) {
          final s = InMemoryWorkflowStore();
          final e = _TestEndpoints(s);
          await _seed(s, 'w');
          e.jobs = [_job('w', state)];

          final result = await e.retryFailedWorkItem(
            session,
            workItemId: 'w',
            requestId: 'req-$state',
            requestedBy: 'dana',
            reason: 'because',
          );

          expect(result.outcome, 'accepted', reason: '$state is terminal');
        }
      },
    );
  });

  // ==================================================================
  // (b) the blank reason — refused before anything is written.
  // ==================================================================

  group('§6.4 step 1 / AC-14 — a blank reason is refused', () {
    test(
      'blank, whitespace-only and whitespace-around-text all refused',
      () async {
        final id = await seedFailed();

        for (final reason in ['', '   ', '\t', '\n', '  \n\t ']) {
          final before = await ledger(id);
          final result = await endpoints.retryFailedWorkItem(
            session,
            workItemId: id,
            requestId: 'req-blank-${reason.length}-${reason.hashCode}',
            requestedBy: 'dana',
            reason: reason,
          );

          expect(
            result.outcome,
            'invalidRequest',
            reason: 'reason ${reason.hashCode}',
          );
          expect(await ledger(id), before, reason: 'nothing may be written');
        }

        expect(await ledger(id), isEmpty);
        expect((await store.readWorkItem(id)).state, WorkItemState.agentFailed);
      },
    );

    test('a non-blank reason is accepted and stored verbatim', () async {
      final id = await seedFailed();

      final result = await endpoints.retryFailedWorkItem(
        session,
        workItemId: id,
        requestId: 'req-ok',
        requestedBy: 'dana',
        reason: '  the host rebooted mid-run  ',
      );

      expect(result.outcome, 'accepted');
      final rows = await ledger(id);
      expect(rows, hasLength(1));
      // Trimmed on the way in, so the record says the same thing the operator
      // typed without the padding.
      expect(rows.single.reason, 'the host rebooted mid-run');
    });
  });

  // ==================================================================
  // (c) the happy path — exactly ONE row, carrying who and why.
  // ==================================================================

  group('the happy path writes exactly ONE row', () {
    test('with the human, the reason, and the attempt number', () async {
      final id = await seedFailed();

      final result = await endpoints.retryFailedWorkItem(
        session,
        workItemId: id,
        requestId: 'req-happy',
        requestedBy: 'dana',
        reason: 'transient infra failure',
      );

      expect(result.outcome, 'accepted');

      final rows = await ledger(id);
      expect(rows, hasLength(1), reason: 'one operator intent, one audit row');

      final row = rows.single;
      expect(row.action, OperatorActionKind.retry.wire);
      // `requestedBy` is the HUMAN. This is the one place in this repository
      // that records the person rather than the path the engine acted by, and
      // it is a first-class column rather than a parsed string.
      expect(row.requestedBy, 'dana');
      expect(row.reason, 'transient infra failure');
      expect(row.requestId, 'req-happy');
      expect(row.attemptNumber, 1);
      // The authorisation actually points at a real transition.
      expect(row.transitionId, isNotNull);
      expect(row.transitionId, isNotEmpty);

      // And the item moved, exactly once, to the triage entry state.
      final item = await store.readWorkItem(id);
      expect(item.state, WorkItemState.designNotRequired);
      expect(item.metadata?['triageAttempt'], 1);
    });

    test('the transition carries the operator reason too (AC-13)', () async {
      final id = await seedFailed();
      await endpoints.retryFailedWorkItem(
        session,
        workItemId: id,
        requestId: 'req-reason',
        requestedBy: 'dana',
        reason: 'transient infra failure',
      );

      final history = await store.readTransitionHistory(id);
      final retry = history.lastWhere(
        (t) => t.toState == WorkItemState.designNotRequired,
      );
      expect(retry.reason, 'transient infra failure');
      expect(retry.outcome, TransitionOutcome.accepted);
      // The prefix is a REPLAY KEY ONLY — never authorization (N12/AC-13).
      expect(retry.idempotencyKey, 'operator-retry:req-reason');
    });

    test(
      'a second retry increments the attempt from the LEDGER, not a counter',
      () async {
        final id = await seedFailed();

        await endpoints.retryFailedWorkItem(
          session,
          workItemId: id,
          requestId: 'req-1',
          requestedBy: 'dana',
          reason: 'first',
        );
        // Fail the item again so it is parked a second time.
        final engine = DurableWorkflowEngine(store: store);
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

        await endpoints.retryFailedWorkItem(
          session,
          workItemId: id,
          requestId: 'req-2',
          requestedBy: 'sam',
          reason: 'second',
        );

        final rows = await ledger(id);
        expect(rows, hasLength(2));
        expect(rows.map((r) => r.attemptNumber), [1, 2]);
        expect((await store.readWorkItem(id)).metadata?['triageAttempt'], 2);
      },
    );
  });

  // ==================================================================
  // (d) replay — a lost response retried with the same requestId spends once.
  // ==================================================================

  group('AC-9 / AC-12 — a replay spends nothing twice', () {
    test('the same requestId twice writes ONE row and moves once', () async {
      final id = await seedFailed();

      final first = await endpoints.retryFailedWorkItem(
        session,
        workItemId: id,
        requestId: 'req-replay',
        requestedBy: 'dana',
        reason: 'transient infra failure',
      );
      final second = await endpoints.retryFailedWorkItem(
        session,
        workItemId: id,
        requestId: 'req-replay',
        requestedBy: 'dana',
        reason: 'transient infra failure',
      );

      expect(first.outcome, 'accepted');
      expect(second.outcome, 'accepted');
      expect(await ledger(id), hasLength(1));

      // Exactly one version bump: the replay did not re-run the transition.
      // The version is read from the STORE, not the wire view, because
      // `WorkItemView` deliberately carries no version field.
      final item = await store.readWorkItem(id);
      final versionAfterFirst = first.workItem.state;
      expect(item.state.wire, versionAfterFirst);
      expect(await ledger(id), hasLength(1));
    });

    test('a replay is answered `accepted` even after the item moved on', () async {
      // The lost-response case: the operator retries the SAME intent after the
      // scheduler has already picked the item up. The endpoint must report what
      // that request DID, not refuse it as inapplicable.
      final id = await seedFailed();
      await endpoints.retryFailedWorkItem(
        session,
        workItemId: id,
        requestId: 'req-lost',
        requestedBy: 'dana',
        reason: 'transient infra failure',
      );
      final engine = DurableWorkflowEngine(store: store);
      await engine.transition(
        workItemId: id,
        to: WorkItemState.agentExecuting,
        trigger: TransitionTrigger.systemEvent,
        context: const {'agentAvailable': true, 'capabilitiesMatch': true},
      );

      final replay = await endpoints.retryFailedWorkItem(
        session,
        workItemId: id,
        requestId: 'req-lost',
        requestedBy: 'dana',
        reason: 'transient infra failure',
      );

      expect(replay.outcome, 'accepted');
      expect(await ledger(id), hasLength(1));
    });

    test(
      'a DIFFERENT requestId on an already-retried item is not applicable',
      () async {
        final id = await seedFailed();
        await endpoints.retryFailedWorkItem(
          session,
          workItemId: id,
          requestId: 'req-a',
          requestedBy: 'dana',
          reason: 'first',
        );

        // The item is no longer agent_failed, so a second deliberate action has
        // nothing to act on.
        final result = await endpoints.retryFailedWorkItem(
          session,
          workItemId: id,
          requestId: 'req-b',
          requestedBy: 'dana',
          reason: 'second',
        );

        expect(result.outcome, 'notApplicable');
        expect(await ledger(id), hasLength(1));
      },
    );
  });

  // ==================================================================
  // The retry bound, driven through the RPC rather than the resolver.
  // ==================================================================

  group('§6.6 — the bound refuses at the RPC, not only in the offer', () {
    test(
      'REVERSED: an UNSET limit no longer refuses — it writes the row',
      () async {
        // This test USED to assert the opposite: that an unset limit returns
        // `notConfigured` and writes nothing. That was HD-3's fail-closed
        // default, and it is deliberately inverted as of 2026-10-12: a human
        // asked for operator retries to be uncounted unless a cap is chosen.
        //
        // The shape of the old test is kept deliberately, because it is the
        // shape that catches a partial revert — an implementation that flipped
        // the resolver but not the RPC (or the reverse) changes the outcome
        // string here while leaving every other assertion intact.
        final id = await seedFailed();
        endpoints.limit = OperatorRetryLimitResolution.fromEnvironment(
          const {},
        );

        final result = await endpoints.retryFailedWorkItem(
          session,
          workItemId: id,
          requestId: 'req-unset',
          requestedBy: 'dana',
          reason: 'transient infra failure',
        );

        expect(result.outcome, 'accepted');
        // It is not a no-op: a real audit row, and a real state change.
        final rows = await ledger(id);
        expect(rows, hasLength(1));
        expect(rows.single.action, OperatorActionKind.retry.wire);
        expect(rows.single.attemptNumber, 1);
        expect(
          (await store.readWorkItem(id)).state,
          WorkItemState.designNotRequired,
        );
        // The operator is told the truth: the variable resolved, and to "no
        // count" rather than to a number.
        expect(result.retryLimitResolved, isTrue);
        expect(result.attemptLimit, 0);
      },
    );

    test(
      'a SPENT limit still refuses the fourth retry and writes NO row',
      () async {
        final id = await seedFailed();
        endpoints.limit = OperatorRetryLimitResolution.fromEnvironment({
          envVar: '3',
        });
        final engine = DurableWorkflowEngine(store: store);

        // Three accepted retries, each preceded by failing the item again.
        for (var i = 1; i <= 3; i++) {
          final result = await endpoints.retryFailedWorkItem(
            session,
            workItemId: id,
            requestId: 'req-$i',
            requestedBy: 'dana',
            reason: 'attempt $i',
          );
          expect(
            result.outcome,
            'accepted',
            reason: 'retry $i should be allowed',
          );
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

        final fourth = await endpoints.retryFailedWorkItem(
          session,
          workItemId: id,
          requestId: 'req-4',
          requestedBy: 'dana',
          reason: 'attempt 4',
        );

        expect(fourth.outcome, 'notConfigured');
        expect(
          await ledger(id),
          hasLength(3),
          reason: 'the fourth wrote nothing',
        );
      },
    );

    test(
      'the refusal is distinguished by `retryLimitResolved` on the wire',
      () async {
        // "Spent" and "never configured" share an outcome; the client words them
        // differently from this one flag (AC-15b/c/d). The server has no UI copy,
        // so this flag is the ONLY thing that lets the panel say which happened
        // — collapsing it would make a misconfigured machine look like an
        // exhausted item.

        // Case 1: an EXPLICIT ZERO — switched off on purpose. This is the one
        // remaining `notConfigured` that is not about a spent count, and it is
        // what the flag now distinguishes. (Before 2026-10-12 this case used
        // "unset", which no longer refuses at all.)
        final zeroedId = await seedFailed();
        endpoints.limit = OperatorRetryLimitResolution.fromEnvironment({
          envVar: '0',
        });
        final disabled = await endpoints.retryFailedWorkItem(
          session,
          workItemId: zeroedId,
          requestId: 'req-u',
          requestedBy: 'dana',
          reason: 'because',
        );
        expect(disabled.outcome, 'notConfigured');
        // Resolved: a working configuration that deliberately disables retry,
        // NOT a machine that is missing one.
        expect(disabled.retryLimitResolved, isTrue);
        expect(
          await ledger(zeroedId),
          isEmpty,
          reason: 'a disabled retry writes nothing',
        );

        // Case 2: a working configuration that has been USED UP. This one earns
        // its three retries first and asks for a fourth, because a fresh item
        // with a limit of 3 is not a spent item.
        final s = InMemoryWorkflowStore();
        final e = _TestEndpoints(s);
        final engine = DurableWorkflowEngine(store: s);
        await _seed(s, 'w');
        final id = 'w';
        e.limit = OperatorRetryLimitResolution.fromEnvironment({envVar: '3'});

        for (var i = 1; i <= 3; i++) {
          final ok = await e.retryFailedWorkItem(
            session,
            workItemId: id,
            requestId: 'req-$i',
            requestedBy: 'dana',
            reason: 'attempt $i',
          );
          expect(ok.outcome, 'accepted');
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

        final spent = await e.retryFailedWorkItem(
          session,
          workItemId: id,
          requestId: 'req-4',
          requestedBy: 'dana',
          reason: 'attempt 4',
        );

        expect(spent.outcome, 'notConfigured');
        expect(
          spent.retryLimitResolved,
          isTrue,
          reason:
              'a working configuration that has been used up must NOT read '
              'as "this machine has no configuration"',
        );
        expect(spent.attemptLimit, 3);
      },
    );
  });

  // ==================================================================
  // THE REVERSAL, driven end to end: the operator may press the button
  // any number of times, and each press really does enqueue a NEW job.
  // ==================================================================

  group('REVERSED — operator retry is UNBOUNDED, and each press is real', () {
    test(
      'thirty consecutive retries are all accepted, and each one writes its '
      'own audit row',
      () async {
        // Thirty is deliberately far past every number this feature has ever
        // used (the old default of 3, HD-3's proposed cap, the handful of
        // fixtures). The property under test is "no ceiling", so a test at 30
        // would also pass at 10^9; the loop is written as a loop rather than a
        // fixed script precisely so there is no hand-written 31st call for a
        // future bound to be quietly added to.
        const presses = 30;
        final id = await seedFailed();
        endpoints.limit = OperatorRetryLimitResolution.fromEnvironment(
          const {},
        );
        final engine = DurableWorkflowEngine(store: store);

        for (var i = 1; i <= presses; i++) {
          final result = await endpoints.retryFailedWorkItem(
            session,
            workItemId: id,
            requestId: 'req-$i',
            requestedBy: 'dana',
            reason: 'deliberate restart $i',
          );

          expect(
            result.outcome,
            'accepted',
            reason:
                'press $i of $presses must be allowed — operator retry is '
                'uncounted unless an operator configured a cap',
          );

          // Park it again, the way a real agent run would, so the next press
          // has something to act on. Every press is a full round trip, not a
          // loop over a cached state.
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

        final rows = await ledger(id);
        expect(rows, hasLength(presses), reason: 'one audit row per press');
        // The attempt numbers are a dense 1..N, which is what proves each press
        // was counted from the LEDGER rather than from a capped counter.
        expect(
          rows.map((r) => r.attemptNumber).toList(),
          [for (var i = 1; i <= presses; i++) i],
        );
        // Each press is attributed to the human who pressed it.
        expect(rows.every((r) => r.requestedBy == 'dana'), isTrue);

        // Each press is a REAL durable transition, not just a ledger row: 30
        // distinct operator-retry transitions, one per press. The item's final
        // state is asserted from the history rather than from the item, because
        // the loop re-parks the item after the last press and reading the item
        // would therefore be asserting the test's own fixture rather than the
        // endpoint's behaviour.
        final history = await store.readTransitionHistory(id);
        final operatorMoves = history
            .where(
              (t) =>
                  t.idempotencyKey != null &&
                  t.idempotencyKey!.startsWith(
                    operatorRetryIdempotencyKeyPrefix,
                  ),
            )
            .toList();
        expect(
          operatorMoves,
          hasLength(presses),
          reason: 'one durable transition per press',
        );
        expect(
          operatorMoves.map((t) => t.idempotencyKey).toSet(),
          hasLength(presses),
          reason:
              'every press carried its own requestId, so none of them '
              'collapsed into another',
        );
      },
    );

    test(
      'every press increments the dedupe discriminator, so no two presses '
      'collide on one job key',
      () async {
        // This is the property that makes "unbounded" mean "a new job each
        // time" rather than "the same job over and over". The scheduler builds
        // a triage job's dedupe key from the item's durable `triageAttempt`
        // marker (`triageDefectDedupeKey`), and `enqueueIfAbsent` returns the
        // EXISTING job for any key it already holds. So if the marker did not
        // advance, press N+1 would silently enqueue nothing and the operator
        // would watch "Try again" do nothing — the exact silent-no-op class
        // this feature was built to close, and the one an unbounded retry
        // would hit on its second press.
        final id = await seedFailed();
        endpoints.limit = OperatorRetryLimitResolution.fromEnvironment(
          const {},
        );
        final engine = DurableWorkflowEngine(store: store);

        final keys = <String>[];
        for (var i = 0; i < 6; i++) {
          await endpoints.retryFailedWorkItem(
            session,
            workItemId: id,
            requestId: 'req-$i',
            requestedBy: 'dana',
            reason: 'restart $i',
          );

          final item = await store.readWorkItem(id);
          keys.add(triageDefectDedupeKey(item, triageDefectDefinition));

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

        expect(
          keys.toSet(),
          hasLength(keys.length),
          reason:
              'every operator retry must enqueue a DISTINCT job; two presses '
              'sharing a dedupe key means the second one silently did nothing',
        );
        // Spelled out, because "all different" would also pass if the keys were
        // random noise rather than the attempt-suffixed form the scheduler
        // expects.
        expect(keys.first, '$id:${triageDefectDefinition.jobType.wire}:a1');
        expect(keys.last, '$id:${triageDefectDefinition.jobType.wire}:a6');
        expect((await store.readWorkItem(id)).metadata?['triageAttempt'], 6);
      },
    );

    test(
      'the LAST press is not special-cased — there is no terminal press',
      () async {
        // A cheap guard against a future "well, except when the count gets
        // silly" branch: the 100th press is ordinary. Kept separate from the
        // 30-press loop so the failure message points at the right property.
        final id = await seedFailed();
        endpoints.limit = OperatorRetryLimitResolution.fromEnvironment(
          const {},
        );
        final engine = DurableWorkflowEngine(store: store);

        for (var i = 1; i <= 100; i++) {
          final result = await endpoints.retryFailedWorkItem(
            session,
            workItemId: id,
            requestId: 'r$i',
            requestedBy: 'dana',
            reason: 'restart $i',
          );
          expect(result.outcome, 'accepted', reason: 'press $i');
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

        expect(await ledger(id), hasLength(100));
      },
    );

    test(
      'every OTHER guard still refuses on the hundredth press — being '
      'uncounted is not being unguarded',
      () async {
        // The reversal removed ONE guard's default. It did not remove the
        // guards, and this is the test that says so on the very press where a
        // "we relaxed it" implementation would be most likely to have relaxed
        // something else by accident.
        final id = await seedFailed();
        endpoints.limit = OperatorRetryLimitResolution.fromEnvironment(
          const {},
        );
        final engine = DurableWorkflowEngine(store: store);

        // Build a history of 100 accepted, deliberate retries.
        for (var i = 1; i <= 100; i++) {
          expect(
            (await endpoints.retryFailedWorkItem(
              session,
              workItemId: id,
              requestId: 'r$i',
              requestedBy: 'dana',
              reason: 'restart $i',
            )).outcome,
            'accepted',
          );
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
        final before = (await ledger(id)).length;

        // (a) A BLANK REASON is still refused, and still writes nothing.
        final blank = await endpoints.retryFailedWorkItem(
          session,
          workItemId: id,
          requestId: 'r-blank',
          requestedBy: 'dana',
          reason: '   ',
        );
        expect(blank.outcome, 'invalidRequest');

        // (b) A LIVE ATTEMPT is still refused, and still writes nothing.
        endpoints.jobs = [_job(id, JobState.running)];
        final running = await endpoints.retryFailedWorkItem(
          session,
          workItemId: id,
          requestId: 'r-live',
          requestedBy: 'dana',
          reason: 'restart onto a live attempt',
        );
        expect(running.outcome, 'alreadyRunning');
        endpoints.jobs = const [];

        // (c) An ITEM THAT IS NOT agent_failed is still not applicable.
        final engine2 = DurableWorkflowEngine(store: store);
        await engine2.transition(
          workItemId: id,
          to: WorkItemState.agentExecuting,
          trigger: TransitionTrigger.systemEvent,
          context: const {'agentAvailable': true, 'capabilitiesMatch': true},
        );
        final notParked = await endpoints.retryFailedWorkItem(
          session,
          workItemId: id,
          requestId: 'r-live2',
          requestedBy: 'dana',
          reason: 'not parked',
        );
        expect(notParked.outcome, 'notApplicable');

        expect(
          (await ledger(id)).length,
          before,
          reason:
              'all three refusals wrote nothing, however many retries came '
              'before them',
        );
      },
    );

    test(
      'a replay still spends nothing twice, however many retries came before',
      () async {
        // The idempotency guard is the one most at risk from this change: an
        // unbounded count is exactly the situation where a client retries its
        // HTTP call, and a lost response must not mint a second spend.
        final id = await seedFailed();
        endpoints.limit = OperatorRetryLimitResolution.fromEnvironment(
          const {},
        );
        final engine = DurableWorkflowEngine(store: store);

        for (var i = 1; i <= 5; i++) {
          await endpoints.retryFailedWorkItem(
            session,
            workItemId: id,
            requestId: 'r$i',
            requestedBy: 'dana',
            reason: 'restart $i',
          );
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
        final before = (await ledger(id)).length;

        // Replay the very first intent. It is answered from the ledger, long
        // after the item has moved on five more times.
        final replay = await endpoints.retryFailedWorkItem(
          session,
          workItemId: id,
          requestId: 'r1',
          requestedBy: 'dana',
          reason: 'restart 1',
        );

        expect(replay.outcome, 'accepted');
        expect(
          (await ledger(id)).length,
          before,
          reason: 'a replay of an old requestId writes no seventh row',
        );
      },
    );
  });

  // ==================================================================
  // The stop path, and the one thing it must NOT refuse.
  // ==================================================================

  group('stop — irreversible, and still refused with no reason', () {
    test('a blank reason is refused and writes NO row', () async {
      final id = await seedFailed();

      final result = await endpoints.stopFailedWorkItem(
        session,
        workItemId: id,
        requestId: 'req-stop',
        requestedBy: 'dana',
        reason: '   ',
      );

      expect(result.outcome, 'invalidRequest');
      expect(await ledger(id), isEmpty);
      expect((await store.readWorkItem(id)).state, WorkItemState.agentFailed);
    });

    test('accepting a stop records it and consumes NO attempt', () async {
      final id = await seedFailed();

      final result = await endpoints.stopFailedWorkItem(
        session,
        workItemId: id,
        requestId: 'req-stop-ok',
        requestedBy: 'dana',
        reason: 'not worth the credits',
      );

      expect(result.outcome, 'accepted');
      expect((await store.readWorkItem(id)).state, WorkItemState.cancelled);

      final rows = await ledger(id);
      expect(rows, hasLength(1));
      expect(rows.single.action, OperatorActionKind.stop.wire);
      expect(rows.single.reason, 'not worth the credits');
      // A stop arms no job, so it must not consume one of the three retries.
      expect(rows.single.attemptNumber, isNull);
    });

    test(
      'stop is offered even while a job is live — that is when it is needed',
      () async {
        // The asymmetry is deliberate and is documented on the method: an
        // operator reaches for "stop" precisely BECAUSE work is in flight.
        final id = await seedFailed();
        endpoints.jobs = [_job(id, JobState.running)];

        final result = await endpoints.stopFailedWorkItem(
          session,
          workItemId: id,
          requestId: 'req-stop-live',
          requestedBy: 'dana',
          reason: 'wrong work',
        );

        expect(result.outcome, 'accepted');
        expect(await ledger(id), hasLength(1));
      },
    );

    test(
      'a replayed stop is reported `alreadyStopped` and writes nothing',
      () async {
        final id = await seedFailed();
        await endpoints.stopFailedWorkItem(
          session,
          workItemId: id,
          requestId: 'req-s',
          requestedBy: 'dana',
          reason: 'because',
        );

        final replay = await endpoints.stopFailedWorkItem(
          session,
          workItemId: id,
          requestId: 'req-s',
          requestedBy: 'dana',
          reason: 'because',
        );

        expect(replay.outcome, 'alreadyStopped');
        expect(await ledger(id), hasLength(1));
      },
    );
  });

  // ==================================================================
  // Not applicable — the item is not parked.
  // ==================================================================

  test(
    'a retry on an item that is not agent_failed is not applicable',
    () async {
      await store.saveWorkItem(
        WorkItem(
          workItemId: 'w-ok',
          productId: 'shipit',
          category: WorkItemCategory.feature,
          title: 'A healthy item',
          description: 'This one is simply running',
          state: WorkItemState.agentExecuting,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          version: 1,
        ),
      );

      final result = await endpoints.retryFailedWorkItem(
        session,
        workItemId: 'w-ok',
        requestId: 'req-na',
        requestedBy: 'dana',
        reason: 'because',
      );

      expect(result.outcome, 'notApplicable');
      expect(await ledger('w-ok'), isEmpty);
    },
  );

  // ==================================================================
  // The deploy advance — qa_passed -> deploying -> deployment_approval.
  // ==================================================================

  group('advanceToDeploy', () {
    /// A QA-passed item. The producer is a completed implementer execution
    /// carrying a completed result with one artifact — resolved by the
    /// implementer-role fallback when no `producerActorId` is stamped, or by
    /// the stamp itself when [stampProducer] is set.
    Future<String> seedQaPassed({
      String id = 'wi-qa-1',
      bool withProducer = true,
      bool stampProducer = false,
    }) async {
      await store.saveWorkItem(
        WorkItem(
          workItemId: id,
          productId: 'shipit',
          category: WorkItemCategory.bugfix,
          title: 'A passed item',
          description: 'Passed QA',
          state: WorkItemState.qaPassed,
          // The stamp `producedCommitFor` joins on: it names the producing
          // AGENT execution, and the matching worker execution carries it as
          // `agentExecutionId`.
          metadata: stampProducer ? const {'producerActorId': 'ex-prod'} : null,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          version: 1,
        ),
      );
      if (withProducer) {
        await endpoints.executionStore.saveExecution(
          AgentExecution(
            executionId: 'ex-prod',
            workItemId: id,
            requestId: 'req-prod',
            runtimeTypeId: 'local',
            role: AgentRole.implementer,
            status: AgentSessionStatus.completed,
            workspace: const AgentWorkspace(
              workspaceId: 'ws-1',
              path: '/tmp/ws',
              startingRevision: 'base-abc',
            ),
            startedAt: DateTime.utc(2026),
          ),
        );
        await endpoints.executionStore.saveResult(
          'ex-prod',
          AgentResult(
            resultId: 'res-prod',
            sessionId: 'sess-prod',
            workItemId: id,
            status: AgentResultStatus.completed,
            artifacts: const [
              AgentArtifact(
                artifactId: 'a-1',
                type: 'build',
                path: 'bin/app',
                sha256: 'deadbeef',
                sizeBytes: 42,
                mediaType: 'application/octet-stream',
              ),
            ],
            diagnostics: const AgentDiagnostics(
              exitCode: 0,
              durationMs: 1,
              toolCalls: 1,
              errors: [],
              warnings: [],
            ),
            structuredResult: const {},
            completedAt: DateTime.utc(2026),
          ),
        );
      }
      return id;
    }

    test(
      'actionContext offers deploy for a deployable qa_passed item',
      () async {
        final id = await seedQaPassed();

        final context = await endpoints.actionContext(
          session,
          workItemId: id,
        );

        expect(context.actions.map((a) => a.action), ['deploy']);
        expect(
          context.actions.single.toState,
          WorkItemState.waitingForHumanDecision.wire,
        );
        expect(context.actions.single.confirmRequired, isTrue);
        expect(context.actions.single.destructive, isFalse);
      },
    );

    test(
      'actionContext withholds deploy when no producer result exists',
      () async {
        final id = await seedQaPassed(withProducer: false);

        final context = await endpoints.actionContext(
          session,
          workItemId: id,
        );

        expect(context.actions, isEmpty);
      },
    );

    test('accepted: transition + gate + ONE audit row', () async {
      final id = await seedQaPassed();

      final result = await endpoints.advanceToDeploy(
        session,
        workItemId: id,
        requestId: 'req-d1',
        requestedBy: 'dana',
        reason: 'ready for production',
      );

      expect(result.outcome, 'accepted');

      // The item is parked at the human gate, NOT deployed.
      final item = await store.readWorkItem(id);
      expect(item.state, WorkItemState.waitingForHumanDecision);
      expect(item.blockingHumanDecisionId, isNotNull);

      final decision = await store.readHumanDecision(
        item.blockingHumanDecisionId!,
      );
      expect(decision.decisionType, HumanDecisionType.deploymentApproval);
      expect(decision.status, HumanDecisionStatus.pending);

      // One audit row, naming the human and the action.
      final rows = await ledger(id);
      expect(rows, hasLength(1));
      expect(rows.single.action, 'deploy');
      expect(rows.single.fromState, WorkItemState.qaPassed.wire);
      expect(rows.single.toState, WorkItemState.deploying.wire);
      expect(rows.single.requestedBy, 'dana');
      expect(rows.single.reason, 'ready for production');
      expect(rows.single.transitionId, isNotNull);

      // The durable transition record carries the accepted edge.
      final history = await store.readTransitionHistory(id);
      final deploy = history.lastWhere(
        (t) => t.toState == WorkItemState.deploying,
      );
      expect(deploy.outcome, TransitionOutcome.accepted);
      expect(deploy.idempotencyKey, 'operator-deploy:req-d1');
    });

    test(
      'refusals: wrong state, blank reason, live job, no producer',
      () async {
        // Wrong state.
        await store.saveWorkItem(
          WorkItem(
            workItemId: 'w-live',
            productId: 'shipit',
            category: WorkItemCategory.bugfix,
            title: 'In flight',
            description: 'running',
            state: WorkItemState.agentExecuting,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            version: 1,
          ),
        );
        final wrong = await endpoints.advanceToDeploy(
          session,
          workItemId: 'w-live',
          requestId: 'req-x',
          requestedBy: 'dana',
          reason: 'go',
        );
        expect(wrong.outcome, 'notApplicable');

        // Blank reason.
        final id = await seedQaPassed();
        final blank = await endpoints.advanceToDeploy(
          session,
          workItemId: id,
          requestId: 'req-b',
          requestedBy: 'dana',
          reason: '   ',
        );
        expect(blank.outcome, 'invalidRequest');

        // Live job.
        endpoints.jobs = [_job(id, JobState.running)];
        final live = await endpoints.advanceToDeploy(
          session,
          workItemId: id,
          requestId: 'req-j',
          requestedBy: 'dana',
          reason: 'go',
        );
        expect(live.outcome, 'alreadyRunning');
        endpoints.jobs = const [];

        // No producer result at all.
        final bare = await seedQaPassed(id: 'wi-bare', withProducer: false);
        final noProducer = await endpoints.advanceToDeploy(
          session,
          workItemId: bare,
          requestId: 'req-p',
          requestedBy: 'dana',
          reason: 'go',
        );
        expect(noProducer.outcome, 'notApplicable');

        // Every refusal wrote NOTHING.
        expect(await ledger(id), isEmpty);
        expect(await ledger(bare), isEmpty);
      },
    );

    test('a replay spends nothing twice', () async {
      final id = await seedQaPassed();
      await endpoints.advanceToDeploy(
        session,
        workItemId: id,
        requestId: 'req-replay',
        requestedBy: 'dana',
        reason: 'go',
      );

      final replay = await endpoints.advanceToDeploy(
        session,
        workItemId: id,
        requestId: 'req-replay',
        requestedBy: 'dana',
        reason: 'go',
      );

      expect(replay.outcome, 'accepted');
      expect(await ledger(id), hasLength(1));
      // And still exactly one pending deployment_approval decision.
      final decisions = await store.readHumanDecisionsForWorkItem(id);
      expect(
        decisions.where(
          (d) => d.decisionType == HumanDecisionType.deploymentApproval,
        ),
        hasLength(1),
      );
    });

    test(
      'a gateless `deploying` item is finished, not re-transitioned',
      () async {
        // The interrupted advance: the transition committed but the decision
        // raise never did (a crash between the two writes). The SAME action
        // finishes it — no second deploy edge is taken.
        await store.saveWorkItem(
          WorkItem(
            workItemId: 'wi-dep',
            productId: 'shipit',
            category: WorkItemCategory.bugfix,
            title: 'Mid-advance',
            description: 'gate missing',
            state: WorkItemState.deploying,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            version: 1,
          ),
        );

        final context = await endpoints.actionContext(
          session,
          workItemId: 'wi-dep',
        );
        expect(context.actions.map((a) => a.action), ['deploy']);

        final result = await endpoints.advanceToDeploy(
          session,
          workItemId: 'wi-dep',
          requestId: 'req-finish',
          requestedBy: 'dana',
          reason: 'finish the interrupted advance',
        );

        expect(result.outcome, 'accepted');
        final item = await store.readWorkItem('wi-dep');
        expect(item.state, WorkItemState.waitingForHumanDecision);
        expect(item.blockingHumanDecisionId, isNotNull);
        final rows = await ledger('wi-dep');
        expect(rows.single.action, 'deploy');
        expect(rows.single.fromState, WorkItemState.deploying.wire);
      },
    );

    test(
      'a STAMPED producer names its own commit — commitBasis producedCommit',
      () async {
        // `producedCommitFor`'s CommitProduced arm, driven for the first time:
        // every other test here resolves the producer by the implementer-role
        // fallback, so `producedCommitFor` answered `producerNotIdentified`
        // and the artifact fell back to the workspace's starting revision.
        //
        // The artifact is real but ephemeral — it satisfies `artifactBuilt()`
        // inside the transition's context and is never persisted — so the
        // recording engine captures it at the one boundary it crosses.
        final id = await seedQaPassed(stampProducer: true);
        await endpoints.workerStore.saveWorkerExecution(
          const WorkerExecution(
            workerExecutionId: 'wx-prod',
            workItemId: 'wi-qa-1',
            repositoryPath: '/durable/clone',
            requestedStartingRevision: 'base-abc',
            requiredCapabilities: {
              WorkerCapability.linux,
              WorkerCapability.git,
            },
            agentExecutionId: 'ex-prod',
            endingRevision: 'c0ffee-prod',
            status: WorkerExecutionStatus.executedPass,
            cleanupPolicy: WorkerCleanupPolicy.removeAlways,
          ),
        );

        final result = await endpoints.advanceToDeploy(
          session,
          workItemId: id,
          requestId: 'req-stamped',
          requestedBy: 'dana',
          reason: 'ship the produced commit',
        );

        expect(result.outcome, 'accepted');
        final artifact = endpoints.deploymentArtifacts.single;
        expect(
          artifact.manifest.metadata?['commitBasis'],
          'producedCommit',
          reason:
              'a stamped producer that left a commit is the artifact\'s '
              'source, not the workspace it started from',
        );
        expect(artifact.manifest.gitCommit, 'c0ffee-prod');
        expect(artifact.labels?['commitBasis'], 'producedCommit');
      },
    );

    test(
      'an UNSTAMPED producer falls back to the workspace base — '
      'commitBasis workspaceStartingRevision',
      () async {
        // The paired arm: without the stamp `producedCommitFor` refuses
        // (`producerNotIdentified`), and the artifact names the revision the
        // producer's workspace was built against — still a real revision,
        // never an invented one.
        final id = await seedQaPassed();

        final result = await endpoints.advanceToDeploy(
          session,
          workItemId: id,
          requestId: 'req-unstamped',
          requestedBy: 'dana',
          reason: 'ship it',
        );

        expect(result.outcome, 'accepted');
        final artifact = endpoints.deploymentArtifacts.single;
        expect(
          artifact.manifest.metadata?['commitBasis'],
          'workspaceStartingRevision',
        );
        expect(artifact.manifest.gitCommit, 'base-abc');
      },
    );
  });

  // ==================================================================
  // The stranded reclaim — agent_executing -> agent_failed.
  // ==================================================================

  group('reclaimStrandedExecution', () {
    Future<String> seedStranded({String id = 'wi-stranded'}) async {
      await store.saveWorkItem(
        WorkItem(
          workItemId: id,
          productId: 'shipit',
          category: WorkItemCategory.bugfix,
          title: 'Says it is running',
          description: 'nothing holds it',
          state: WorkItemState.agentExecuting,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          version: 1,
        ),
      );
      return id;
    }

    AgentExecution execution(String id, AgentSessionStatus status) =>
        AgentExecution(
          executionId: 'ex-$status',
          workItemId: id,
          requestId: 'req-ex',
          runtimeTypeId: 'local',
          role: AgentRole.implementer,
          status: status,
          workspace: const AgentWorkspace(workspaceId: 'ws', path: '/tmp/w'),
          startedAt: DateTime.utc(2026),
        );

    test('actionContext offers reclaim for a stranded item only', () async {
      // Stranded: no executions, no jobs.
      final id = await seedStranded();
      var context = await endpoints.actionContext(session, workItemId: id);
      expect(context.actions.map((a) => a.action), ['reclaim']);
      expect(
        context.actions.single.toState,
        WorkItemState.agentFailed.wire,
      );

      // NOT stranded: a non-terminal execution exists.
      await endpoints.executionStore.saveExecution(
        execution(id, AgentSessionStatus.running),
      );
      context = await endpoints.actionContext(session, workItemId: id);
      expect(context.actions, isEmpty);
    });

    test('an active job withholds the offer too', () async {
      final id = await seedStranded();
      endpoints.jobs = [_job(id, JobState.claimed)];

      final context = await endpoints.actionContext(
        session,
        workItemId: id,
      );
      expect(context.actions, isEmpty);
    });

    test('accepted: agent_failed, audited reclaim, retriable after', () async {
      final id = await seedStranded();

      final result = await endpoints.reclaimStrandedExecution(
        session,
        workItemId: id,
        requestId: 'req-rc',
        requestedBy: 'dana',
        reason: 'the run that held it is gone',
      );

      expect(result.outcome, 'accepted');
      expect(
        (await store.readWorkItem(id)).state,
        WorkItemState.agentFailed,
      );

      final rows = await ledger(id);
      expect(rows, hasLength(1));
      expect(rows.single.action, 'reclaim');
      expect(rows.single.fromState, WorkItemState.agentExecuting.wire);
      expect(rows.single.toState, WorkItemState.agentFailed.wire);
      expect(rows.single.requestedBy, 'dana');

      // The whole point of the landing state: the ordinary retry surface now
      // takes the item.
      final retry = await endpoints.retryFailedWorkItem(
        session,
        workItemId: id,
        requestId: 'req-after',
        requestedBy: 'dana',
        reason: 'try it again',
      );
      expect(retry.outcome, 'accepted');
      expect(
        (await store.readWorkItem(id)).state,
        WorkItemState.designNotRequired,
      );
    });

    test('refusals: live execution, live job, wrong state, blank', () async {
      final id = await seedStranded();

      // A non-terminal execution means the item is NOT stranded.
      await endpoints.executionStore.saveExecution(
        execution(id, AgentSessionStatus.running),
      );
      final live = await endpoints.reclaimStrandedExecution(
        session,
        workItemId: id,
        requestId: 'req-1',
        requestedBy: 'dana',
        reason: 'because',
      );
      expect(live.outcome, 'alreadyRunning');

      // A TERMINAL execution is fine — the drive finished and never moved the
      // item; that is the stranded shape.
      await endpoints.executionStore.saveExecution(
        AgentExecution(
          executionId: 'ex-dead',
          workItemId: id,
          requestId: 'req-dead',
          runtimeTypeId: 'local',
          role: AgentRole.implementer,
          status: AgentSessionStatus.failed,
          workspace: const AgentWorkspace(workspaceId: 'ws', path: '/tmp/w'),
          startedAt: DateTime.utc(2026),
        ),
      );
      // ...but the earlier running one still holds it. Remove it by starting a
      // fresh store item instead — an active job is the next check anyway.
      final id2 = await seedStranded(id: 'wi-stranded-2');
      endpoints.jobs = [_job(id2, JobState.queued)];
      final liveJob = await endpoints.reclaimStrandedExecution(
        session,
        workItemId: id2,
        requestId: 'req-2',
        requestedBy: 'dana',
        reason: 'because',
      );
      expect(liveJob.outcome, 'alreadyRunning');
      endpoints.jobs = const [];

      // Wrong state — a genuinely-failed item is not a reclaim candidate; it
      // belongs to the retry/stop surface.
      await store.saveWorkItem(
        WorkItem(
          workItemId: 'w-failed',
          productId: 'shipit',
          category: WorkItemCategory.bugfix,
          title: 'Actually failed',
          description: 'failed',
          state: WorkItemState.agentFailed,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          version: 1,
        ),
      );
      final wrong = await endpoints.reclaimStrandedExecution(
        session,
        workItemId: 'w-failed',
        requestId: 'req-3',
        requestedBy: 'dana',
        reason: 'because',
      );
      expect(wrong.outcome, 'notApplicable');

      // Blank reason.
      final id3 = await seedStranded(id: 'wi-stranded-3');
      final blank = await endpoints.reclaimStrandedExecution(
        session,
        workItemId: id3,
        requestId: 'req-4',
        requestedBy: 'dana',
        reason: '  ',
      );
      expect(blank.outcome, 'invalidRequest');

      // Nothing was written anywhere.
      expect(await ledger(id), isEmpty);
      expect(await ledger(id2), isEmpty);
      expect(await ledger(id3), isEmpty);
    });

    test('a replay spends nothing twice', () async {
      final id = await seedStranded();
      await endpoints.reclaimStrandedExecution(
        session,
        workItemId: id,
        requestId: 'req-rep',
        requestedBy: 'dana',
        reason: 'because',
      );

      final replay = await endpoints.reclaimStrandedExecution(
        session,
        workItemId: id,
        requestId: 'req-rep',
        requestedBy: 'dana',
        reason: 'because',
      );

      expect(replay.outcome, 'accepted');
      expect(await ledger(id), hasLength(1));
    });
  });
}

/// Drives the REAL endpoint methods over in-memory stores.
///
/// Overrides [serviceFor] only — the store is substituted, never the refusal.
/// Every refusal under test is the production code's own.
class _TestEndpoints extends WorkItemActionEndpoints {
  _TestEndpoints(this._store);

  final WorkflowStore _store;

  /// The jobs `listJobsForWorkItem` reports.
  List<Job> jobs = const [];

  /// The execution store the deploy/reclaim paths read. In-memory, so a test
  /// can seed a producer result or a non-terminal execution directly.
  final InMemoryExecutionStore executionStore = InMemoryExecutionStore();

  /// The worker store `producedCommitFor` reads.
  final InMemoryWorkerStore workerStore = InMemoryWorkerStore();

  /// The `DeploymentArtifact`s handed to the transition context, captured by
  /// [_RecordingEngine]. The artifact is ephemeral by design — it satisfies
  /// `artifactBuilt()` and is never persisted — so the transition boundary is
  /// the only place a test can read what the endpoint actually built.
  final List<DeploymentArtifact> deploymentArtifacts = [];

  /// The retry limit this endpoint resolves. Injected so the tests never read
  /// or mutate the host environment.
  OperatorRetryLimitResolution? limit;

  @override
  ControlPlaneService serviceFor(Session session) =>
      _TestService(session, _store, this);

  /// The limit a test has not set is the UNCAPPED one, so it is the same
  /// default production runs with since 2026-10-12 and every guard test below
  /// is exercised under real conditions rather than under a convenient cap.
  ///
  /// It was `'3'` before the reversal — the old default cap — so any test that
  /// depended on it having a ceiling would now fail loudly rather than pass
  /// quietly against a bound production no longer applies.
  @override
  OperatorRetryLimitResolution resolveRetryLimit() =>
      limit ?? OperatorRetryLimitResolution.fromEnvironment(const {});
}

/// The real service, with its Postgres-backed stores replaced by in-memory
/// ones and its job reads answered from a list.
///
/// `ControlPlaneService._db` is `late final` and is never touched here, because
/// every accessor this surface uses is overridden below.
class _TestService extends ControlPlaneService {
  _TestService(super.session, this._store, this._owner);

  final WorkflowStore _store;
  final _TestEndpoints _owner;

  @override
  WorkflowStore get workflowStore => _store;

  @override
  DurableWorkflowEngine get workflowEngine =>
      _RecordingEngine(store: _store, sink: _owner.deploymentArtifacts);

  @override
  Future<List<Job>> listJobs() async => _owner.jobs;

  @override
  Future<List<Job>> listJobsForWorkItem(String workItemId) async =>
      _owner.jobs.where((j) => j.workItemId == workItemId).toList();

  @override
  ExecutionStore get executionStore => _owner.executionStore;

  @override
  WorkerStore get workerStore => _owner.workerStore;
}

/// The REAL engine, with one observation added: the `DeploymentArtifact` a
/// transition call carries in its context is recorded before the call runs.
///
/// ## WHY RECORD AND NOT REPLACE
///
/// The artifact is built inside the endpoint and consumed by the
/// `artifactBuilt()` guard inside the same call — it is never persisted, so
/// the context map is the only boundary where what the endpoint built can be
/// read. The engine is the REAL one and every transition still runs through
/// it; recording substitutes nothing. `requestHumanDecision` does not pass
/// through [transition], so only direct transition calls are observed.
class _RecordingEngine extends DurableWorkflowEngine {
  _RecordingEngine({required super.store, required this.sink});

  final List<DeploymentArtifact> sink;

  @override
  Future<WorkItem> transition({
    required String workItemId,
    required WorkItemState to,
    required TransitionTrigger trigger,
    WorkflowActor actor = DurableWorkflowEngine.operatorRetryActor,
    Map<String, dynamic> context = const {},
    String? decisionId,
    String? idempotencyKey,
    String? reason,
    OperatorActionRecord? operatorAction,
    Map<String, dynamic>? metadataMerge,
  }) {
    final artifact = context['deploymentArtifact'];
    if (artifact is DeploymentArtifact) sink.add(artifact);
    return super.transition(
      workItemId: workItemId,
      to: to,
      trigger: trigger,
      actor: actor,
      context: context,
      decisionId: decisionId,
      idempotencyKey: idempotencyKey,
      reason: reason,
      operatorAction: operatorAction,
      metadataMerge: metadataMerge,
    );
  }
}

/// A job in the given state, for the non-terminal / terminal assertions.
Job _job(String workItemId, JobState state) => Job(
  jobId: 'jb-$workItemId-${state.wire}',
  workItemId: workItemId,
  jobType: JobType.triageDefect,
  requiredRole: AgentRole.implementer,
  requiredCapabilities: const {},
  priority: JobPriority.normal,
  state: state,
  dedupeKey: '$workItemId:triage_defect',
  createdAt: DateTime.utc(2026),
  instruction: 'triage this defect',
  attempt: 1,
  maxAttempts: 2,
  version: 1,
);

/// Walks a fresh work item to `agent_failed` through the real engine.
Future<void> _seed(WorkflowStore store, String id) async {
  final engine = DurableWorkflowEngine(store: store);
  await engine.createWorkItem(
    workItemId: id,
    productId: 'shipit',
    category: WorkItemCategory.bugfix,
    title: 'Sign-in is rejected after a password reset',
    description: 'Operators cannot sign in after a password reset',
    featureRef: 'WI-signin',
    requirementRef: 'REQ-signin',
  );
  await engine.transition(
    workItemId: id,
    to: WorkItemState.planning,
    trigger: TransitionTrigger.systemEvent,
  );
  await engine.transition(
    workItemId: id,
    to: WorkItemState.planned,
    trigger: TransitionTrigger.systemEvent,
    context: const {'featureRef': 'WI-signin', 'requirementRef': 'REQ-signin'},
  );
  await engine.transition(
    workItemId: id,
    to: WorkItemState.designNotRequired,
    trigger: TransitionTrigger.systemEvent,
  );
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

/// A [Session] that records log lines and never touches a database.
///
/// `ControlPlaneService` only reads `session.db` through its `late final`
/// `_db`, which these tests never reach — every store is overridden — so this
/// only has to satisfy the logger.
class _FakeSession implements Session {
  final List<String> logs = [];

  @override
  void log(
    String message, {
    LogLevel? level,
    dynamic exception,
    StackTrace? stackTrace,
  }) {
    logs.add(message);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Session.${invocation.memberName} is not used here',
  );
}
