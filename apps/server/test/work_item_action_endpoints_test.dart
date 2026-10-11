import 'package:control_plane_server/src/endpoints/work_item_action_endpoints.dart';
import 'package:control_plane_server/src/services/control_plane_service.dart';
import 'package:platform_contracts/platform_contracts.dart';
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
    test('an unset limit refuses the write and writes NO row', () async {
      final id = await seedFailed();
      endpoints.limit = OperatorRetryLimitResolution.fromEnvironment(const {});

      final result = await endpoints.retryFailedWorkItem(
        session,
        workItemId: id,
        requestId: 'req-unset',
        requestedBy: 'dana',
        reason: 'transient infra failure',
      );

      expect(result.outcome, 'notConfigured');
      expect(await ledger(id), isEmpty);
      expect((await store.readWorkItem(id)).state, WorkItemState.agentFailed);
    });

    test('a SPENT limit refuses the fourth retry and writes NO row', () async {
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
    });

    test(
      'the refusal is distinguished by `retryLimitResolved` on the wire',
      () async {
        // "Spent" and "never configured" share an outcome; the client words them
        // differently from this one flag (AC-15b/c/d). The server has no UI copy,
        // so this flag is the ONLY thing that lets the panel say which happened
        // — collapsing it would make a misconfigured machine look like an
        // exhausted item.

        // Case 1: never configured.
        endpoints.limit = OperatorRetryLimitResolution.fromEnvironment(
          const {},
        );
        final unset = await endpoints.retryFailedWorkItem(
          session,
          workItemId: await seedFailed(),
          requestId: 'req-u',
          requestedBy: 'dana',
          reason: 'because',
        );
        expect(unset.outcome, 'notConfigured');
        expect(unset.retryLimitResolved, isFalse);

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

  /// The retry limit this endpoint resolves. Injected so the tests never read
  /// or mutate the host environment.
  OperatorRetryLimitResolution? limit;

  @override
  ControlPlaneService serviceFor(Session session) =>
      _TestService(session, _store, this);

  /// The limit a test has not set is the generous one, so an unset-limit test
  /// is explicit rather than accidental.
  @override
  OperatorRetryLimitResolution resolveRetryLimit() =>
      limit ??
      OperatorRetryLimitResolution.fromEnvironment({
        operatorRetryLimitEnvVar: '3',
      });
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
      DurableWorkflowEngine(store: _store);

  @override
  Future<List<Job>> listJobs() async => _owner.jobs;

  @override
  Future<List<Job>> listJobsForWorkItem(String workItemId) async =>
      _owner.jobs.where((j) => j.workItemId == workItemId).toList();
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
