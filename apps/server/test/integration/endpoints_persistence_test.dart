import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:control_plane_server/src/persistence/postgres_workflow_store.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';

import 'test_tools/serverpod_test_tools.dart';

const _orch = WorkflowActor(
  actorId: 'orchestrator-1',
  actorType: ActorType.orchestrator,
);

/// Endpoint-layer proof that the control plane API is a pure read/observation
/// surface for durable Postgres state, with exactly one legal request-side
/// write (resolving a human decision through the durable engine). No endpoint
/// sets [WorkItem.state]; the endpoint responses are typed protocol models,
/// built from the same store reads the processes would make after a restart.
void main() {
  final openSessions = <Session>[];

  Future<PersistenceDatabase> newDb() async {
    final session = await Serverpod.instance.createSession(
      enableLogging: false,
    );
    openSessions.add(session);
    return PersistenceDatabase(session.db);
  }

  Future<void> truncateDomainTables() async {
    final db = await newDb();
    await db.queryNoTransaction('''
      TRUNCATE TABLE
        "work_item",
        "human_decision",
        "work_item_transition",
        "job",
        "job_claim",
        "scheduler_event",
        "worker_execution",
        "worker_result",
        "worker_event",
        "worker_registration",
        "agent_execution_request",
        "agent_execution",
        "agent_event",
        "agent_result",
        "platform_verification"
      RESTART IDENTITY CASCADE
    ''');
  }

  Future<DurableWorkflowEngine> newEngine([String? workItemId]) async {
    final engine = DurableWorkflowEngine(
      store: PostgresWorkflowStore(await newDb()),
    );
    await engine.createWorkItem(
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Endpoint seeded feature',
      description: 'Seeded feature for endpoint persistence tests',
      workItemId: workItemId,
    );
    return engine;
  }

  /// Drives a fresh work item through the legal chain to the human-decision
  /// gate so `requestHumanDecision` is a valid transition.
  Future<String> pushToHumanGate(
    DurableWorkflowEngine engine, {
    required String workItemId,
  }) async {
    await engine.transition(
      workItemId: workItemId,
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
      actor: _orch,
    );
    await engine.transition(
      workItemId: workItemId,
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      actor: _orch,
      context: const {'featureRef': 'FEAT-001'},
    );
    await engine.transition(
      workItemId: workItemId,
      to: WorkItemState.designRequired,
      trigger: TransitionTrigger.systemEvent,
      actor: _orch,
      context: const {'designContractId': 'dc-1'},
    );
    await engine.transition(
      workItemId: workItemId,
      to: WorkItemState.designInReview,
      trigger: TransitionTrigger.systemEvent,
      actor: _orch,
      context: const {'designContractStatus': DesignContractStatus.underReview},
    );
    final decision = await engine.requestHumanDecision(
      workItemId: workItemId,
      decisionType: HumanDecisionType.designApproval,
      question: 'Approve the design?',
      actor: _orch,
    );
    return decision.decisionId;
  }

  withServerpod(
    'control-plane endpoints observe durable state and never set it',
    (sessionBuilder, endpoints) {
      setUp(truncateDomainTables);
      tearDown(() async {
        for (final session in List.of(openSessions)) {
          await session.close();
        }
        openSessions.clear();
      });

      test(
        'workflow.inspect returns a work item seeded through the engine',
        () async {
          final engine = await newEngine('wi-inspect-1');
          await pushToHumanGate(engine, workItemId: 'wi-inspect-1');

          final response = await endpoints.workflowEndpoints.inspect(
            sessionBuilder,
            workItemId: 'wi-inspect-1',
          );

          expect(response.workItem.workItemId, 'wi-inspect-1');
          expect(
            response.workItem.state,
            WorkItemState.waitingForHumanDecision.wire,
          );

          final history = response.transitionHistory;
          expect(
            history,
            isNotEmpty,
            reason: 'every accepted transition is appended to the history',
          );
          expect(
            history.map((h) => h.toState).last,
            WorkItemState.waitingForHumanDecision.wire,
          );
        },
      );

      test(
        'workflow.listDecisions surfaces a decision persisted durably',
        () async {
          final engine = await newEngine('wi-decisions-1');
          final decisionId = await pushToHumanGate(
            engine,
            workItemId: 'wi-decisions-1',
          );

          final response = await endpoints.workflowEndpoints.listDecisions(
            sessionBuilder,
            workItemId: 'wi-decisions-1',
          );

          expect(response, hasLength(1));
          expect(response.first.decisionId, decisionId);
          expect(response.first.status, HumanDecisionStatus.pending.wire);
          expect(response.first.workItemId, 'wi-decisions-1');
        },
      );

      test('workflow.resolveDecision unlocks the gate via the engine and '
          'replays idempotently', () async {
        final engine = await newEngine('wi-resolve-1');
        final decisionId = await pushToHumanGate(
          engine,
          workItemId: 'wi-resolve-1',
        );

        final response = await endpoints.workflowEndpoints.resolveDecision(
          sessionBuilder,
          decisionId: decisionId,
          choice: 'approve',
          decider: 'alice@example.com',
          rationale: 'Design looks good',
          algorithm: 'Ed25519',
          publicKey: 'key-alice',
          signature: 'sig-approve-1',
          signedAt: DateTime.utc(2026, 1, 1),
        );

        expect(
          response.workItem.state,
          WorkItemState.designApproved.wire,
          reason: 'a resolved designApproval unlocks to designApproved',
        );
        final decisionWire = response.decision;
        expect(decisionWire, isNotNull);
        expect(decisionWire!.status, HumanDecisionStatus.resolved.wire);
        expect(decisionWire.choice, 'approve');
        expect(decisionWire.signature, isNotEmpty);

        // Idempotent replay: the exact same endpoint call cannot double-apply.
        final replay = await endpoints.workflowEndpoints.resolveDecision(
          sessionBuilder,
          decisionId: decisionId,
          choice: 'approve',
          decider: 'alice@example.com',
          rationale: 'Replayed after network retry',
          algorithm: 'Ed25519',
          publicKey: 'key-alice',
          signature: 'sig-approve-2',
          signedAt: DateTime.utc(2026, 1, 1),
        );
        expect(
          replay.workItem.state,
          WorkItemState.designApproved.wire,
          reason:
              'a duplicate resolution is an idempotent replay, '
              'never a second transition',
        );
      });

      test(
        'endpoints report durable Postgres state without mutating it',
        () async {
          final engine = await newEngine('wi-observe-1');
          await pushToHumanGate(engine, workItemId: 'wi-observe-1');

          final inspect1 = await endpoints.workflowEndpoints.inspect(
            sessionBuilder,
            workItemId: 'wi-observe-1',
          );
          final stateViaEndpoint = inspect1.workItem.state;

          final store = PostgresWorkflowStore(await newDb());
          final rawFromStore = await store.readWorkItem('wi-observe-1');
          expect(
            stateViaEndpoint,
            rawFromStore.state.wire,
            reason: 'the endpoint reports exactly what the store holds',
          );

          final inspect2 = await endpoints.workflowEndpoints.inspect(
            sessionBuilder,
            workItemId: 'wi-observe-1',
          );
          expect(
            inspect2.workItem.state,
            stateViaEndpoint,
            reason: 'a read-only endpoint cannot move workflow state',
          );
        },
      );

      test('endpoints round-trip timestamps in ISO-8601 UTC', () async {
        final engine = await newEngine('wi-ts-1');
        await engine.transition(
          workItemId: 'wi-ts-1',
          to: WorkItemState.planning,
          trigger: TransitionTrigger.systemEvent,
          actor: _orch,
        );

        final response = await endpoints.workflowEndpoints.inspect(
          sessionBuilder,
          workItemId: 'wi-ts-1',
        );
        expect(response.workItem.createdAt, isA<DateTime>());
        expect(
          response.workItem.createdAt.isUtc,
          isTrue,
          reason: 'timestamps persist as UTC wall-clock',
        );
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}
