import 'package:control_plane_server/src/endpoints/home_endpoints.dart';
import 'package:control_plane_server/src/services/control_plane_service.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart' show WorkerRegistration;
import 'package:workflow_store/workflow_store.dart'
    show InMemoryWorkflowStore, WorkflowStore;

/// Regression: a VOIDED blocking decision must never win the "Needs your
/// approval" card over the live one.
///
/// ## THE LIVE DEFECT THIS GUARDS
///
/// Work item `defect-DEF-1791685264570406` (`waiting_for_human_decision`)
/// carried TWO blocking decisions: a `cancelled` one voided by migration
/// `20261014210000000`, and a `pending` one that the item's own
/// `blockingHumanDecisionId` named. `pendingDecisions` picked the first
/// `!isResolved && blocking` row — `cancelled` is not `resolved`, so the
/// voided decision counted as pending — and `firstOrNull` over the store's
/// `updatedAt ASC` order served the OLDEST match. The card linked to the
/// voided id; the detail page refused it.
///
/// The fix has two halves and both are asserted here:
///
///  * `pendingDecisions` resolves the decision the item NAMES
///    (`blockingHumanDecisionId`) and only while `status.isOpen` — so
///    ordering can never promote a voided row, and a voided row can never
///    satisfy "awaiting an answer".
///  * `HumanDecisionStatus.isTerminal`/`isOpen` is the central statement
///    that `cancelled` is terminal WITHOUT being resolved; `isResolved`
///    itself is deliberately untouched, because "resolved" means answered
///    and the 'Already decided' ledger must not admit decisions nobody
///    answered.
///
/// ## HOW IT DRIVES THE ENDPOINT WITHOUT A DATABASE
///
/// Same seam as `work_item_action_endpoints_test.dart`: [HomeEndpoints]
/// builds its service through `serviceFor`, overridden here to hand back the
/// REAL endpoint logic over [InMemoryWorkflowStore]. Only the persistence
/// substrate is substituted.
void main() {
  late InMemoryWorkflowStore store;
  late _TestHomeEndpoints endpoints;
  late Session session;

  setUp(() {
    store = InMemoryWorkflowStore();
    endpoints = _TestHomeEndpoints(store);
    session = _FakeSession();
  });

  WorkItem blockedItem({
    required String workItemId,
    required String blockingDecisionId,
  }) => WorkItem(
    workItemId: workItemId,
    productId: 'shipit',
    category: WorkItemCategory.bugfix,
    title: 'Sign-in is rejected after a password reset',
    description: 'Operators cannot sign in after a password reset',
    state: WorkItemState.waitingForHumanDecision,
    blockingHumanDecisionId: blockingDecisionId,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    version: 1,
  );

  HumanDecision decision({
    required String decisionId,
    required String workItemId,
    required HumanDecisionStatus status,
    required DateTime updatedAt,
    HumanDecisionChoice? choice,
  }) => HumanDecision(
    decisionId: decisionId,
    workItemId: workItemId,
    decisionType: HumanDecisionType.defectClarification,
    status: status,
    question: 'Can you confirm the reproduction?',
    blocking: true,
    requestedAt: DateTime.utc(2026),
    choice: choice,
    updatedAt: updatedAt,
  );

  group('pendingDecisions — the voided decision never wins', () {
    test(
      'a CANCELLED blocking decision older than the pending one is not '
      'served — the item\'s own pointer is',
      () async {
        // The live shape: the voided row sorts FIRST (`updatedAt ASC`,
        // insertion order in the in-memory store), so the old
        // `firstOrNull` would have picked it.
        const workItemId = 'defect-DEF-1';
        await store.saveWorkItem(
          blockedItem(
            workItemId: workItemId,
            blockingDecisionId: 'dec-pending',
          ),
        );
        await store.saveHumanDecision(
          decision(
            decisionId: 'dec-cancelled',
            workItemId: workItemId,
            status: HumanDecisionStatus.cancelled,
            updatedAt: DateTime.utc(2026, 10, 14),
          ),
        );
        await store.saveHumanDecision(
          decision(
            decisionId: 'dec-pending',
            workItemId: workItemId,
            status: HumanDecisionStatus.pending,
            updatedAt: DateTime.utc(2026, 10, 15),
          ),
        );

        final views = await endpoints.pendingDecisions(session);

        expect(
          views.map((v) => v.decisionId),
          ['dec-pending'],
          reason:
              'the card must link to the decision the item is actually '
              'blocked on, never the voided one that sorts first',
        );
      },
    );

    test(
      'a CANCELLED blocking decision NEWER than the pending one is still '
      'not served — ordering is no longer the mechanism',
      () async {
        // The ordering hazard cut both ways: matching by id rather than by
        // "first unresolved" makes the outcome independent of which row
        // happens to sort first. Given the service now returns newest-first,
        // this case puts the voided row in front.
        const workItemId = 'defect-DEF-2';
        await store.saveWorkItem(
          blockedItem(
            workItemId: workItemId,
            blockingDecisionId: 'dec-pending',
          ),
        );
        await store.saveHumanDecision(
          decision(
            decisionId: 'dec-pending',
            workItemId: workItemId,
            status: HumanDecisionStatus.pending,
            updatedAt: DateTime.utc(2026, 10, 14),
          ),
        );
        await store.saveHumanDecision(
          decision(
            decisionId: 'dec-cancelled',
            workItemId: workItemId,
            status: HumanDecisionStatus.cancelled,
            updatedAt: DateTime.utc(2026, 10, 15),
          ),
        );

        final views = await endpoints.pendingDecisions(session);

        expect(views.map((v) => v.decisionId), ['dec-pending']);
      },
    );

    test(
      'a pointer naming a TERMINAL decision surfaces NOTHING — a stale '
      'pointer is not a card',
      () async {
        // The pointer asserts the item is blocked, but the named decision
        // is voided: nothing is awaiting an answer, so nothing may be shown
        // as needing one. Inventing a different row would be the same guess
        // that caused the defect.
        const workItemId = 'defect-DEF-3';
        await store.saveWorkItem(
          blockedItem(
            workItemId: workItemId,
            blockingDecisionId: 'dec-cancelled',
          ),
        );
        await store.saveHumanDecision(
          decision(
            decisionId: 'dec-cancelled',
            workItemId: workItemId,
            status: HumanDecisionStatus.cancelled,
            updatedAt: DateTime.utc(2026, 10, 14),
          ),
        );

        expect(await endpoints.pendingDecisions(session), isEmpty);
      },
    );

    test(
      'a pointer naming a RESOLVED decision surfaces NOTHING either',
      () async {
        const workItemId = 'defect-DEF-4';
        await store.saveWorkItem(
          blockedItem(
            workItemId: workItemId,
            blockingDecisionId: 'dec-resolved',
          ),
        );
        await store.saveHumanDecision(
          decision(
            decisionId: 'dec-resolved',
            workItemId: workItemId,
            status: HumanDecisionStatus.resolved,
            choice: HumanDecisionChoice.approve,
            updatedAt: DateTime.utc(2026, 10, 14),
          ),
        );

        expect(await endpoints.pendingDecisions(session), isEmpty);
      },
    );

    test(
      'a non-blocking pending decision that is NOT the named blocker is '
      'not surfaced either',
      () async {
        const workItemId = 'defect-DEF-5';
        await store.saveWorkItem(
          blockedItem(
            workItemId: workItemId,
            blockingDecisionId: 'dec-pending',
          ),
        );
        await store.saveHumanDecision(
          decision(
            decisionId: 'dec-other',
            workItemId: workItemId,
            status: HumanDecisionStatus.pending,
            updatedAt: DateTime.utc(2026, 10, 14),
          ),
        );
        await store.saveHumanDecision(
          decision(
            decisionId: 'dec-pending',
            workItemId: workItemId,
            status: HumanDecisionStatus.pending,
            updatedAt: DateTime.utc(2026, 10, 15),
          ),
        );

        final views = await endpoints.pendingDecisions(session);
        expect(views.map((v) => v.decisionId), ['dec-pending']);
      },
    );
  });

  group('overview — "Waiting on you" counts the same thing the card shows', () {
    test(
      'an item blocked on a CANCELLED decision does not count, one on a '
      'pending decision does',
      () async {
        await store.saveWorkItem(
          blockedItem(
            workItemId: 'wi-voided',
            blockingDecisionId: 'dec-voided',
          ),
        );
        await store.saveWorkItem(
          blockedItem(
            workItemId: 'wi-live',
            blockingDecisionId: 'dec-live',
          ),
        );
        await store.saveHumanDecision(
          decision(
            decisionId: 'dec-voided',
            workItemId: 'wi-voided',
            status: HumanDecisionStatus.cancelled,
            updatedAt: DateTime.utc(2026, 10, 14),
          ),
        );
        await store.saveHumanDecision(
          decision(
            decisionId: 'dec-live',
            workItemId: 'wi-live',
            status: HumanDecisionStatus.pending,
            updatedAt: DateTime.utc(2026, 10, 15),
          ),
        );

        final overview = await endpoints.overview(session);

        expect(
          overview.waitingOnYou,
          1,
          reason:
              'the badge and the card strip must agree: a voided blocker '
              'asks for no answer, so it cannot inflate the count',
        );
      },
    );
  });

  group(
    'readDecisionsForWorkItem — newest first, as its consumers require',
    () {
      test(
        'returns decisions in descending updatedAt order',
        () async {
          const workItemId = 'defect-DEF-6';
          await store.saveHumanDecision(
            decision(
              decisionId: 'dec-oldest',
              workItemId: workItemId,
              status: HumanDecisionStatus.cancelled,
              updatedAt: DateTime.utc(2026, 10, 13),
            ),
          );
          await store.saveHumanDecision(
            decision(
              decisionId: 'dec-newest',
              workItemId: workItemId,
              status: HumanDecisionStatus.pending,
              updatedAt: DateTime.utc(2026, 10, 15),
            ),
          );
          await store.saveHumanDecision(
            decision(
              decisionId: 'dec-middle',
              workItemId: workItemId,
              status: HumanDecisionStatus.resolved,
              updatedAt: DateTime.utc(2026, 10, 14),
            ),
          );

          // The store is the only read this method performs, so the test can
          // substitute it through the same seam the endpoint uses.
          final decisions = await _TestService(
            session,
            store,
          ).readDecisionsForWorkItem(workItemId);

          expect(decisions.map((d) => d.decisionId), [
            'dec-newest',
            'dec-middle',
            'dec-oldest',
          ]);
        },
      );
    },
  );
}

/// Drives the REAL endpoint methods over an in-memory store.
///
/// Overrides [HomeEndpoints.serviceFor] only — the store is substituted,
/// never the selection logic under test.
class _TestHomeEndpoints extends HomeEndpoints {
  _TestHomeEndpoints(this._store);

  final WorkflowStore _store;

  @override
  ControlPlaneService serviceFor(Session session) =>
      _TestService(session, _store);
}

/// The real service, with its Postgres-backed store replaced by an in-memory
/// one and the overview's scheduler/worker reads answered empty.
///
/// `ControlPlaneService._db` is `late final` and is never touched here,
/// because every accessor this surface uses is overridden below.
class _TestService extends ControlPlaneService {
  _TestService(super.session, this._store);

  final WorkflowStore _store;

  @override
  WorkflowStore get workflowStore => _store;

  @override
  Future<List<Job>> listJobs() async => const [];

  @override
  Future<List<WorkerRegistration>> listWorkers() async => const [];

  @override
  Future<List<WorkerExecution>> listWorkerExecutions() async => const [];
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
