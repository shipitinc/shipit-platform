import 'package:control_plane_client/control_plane_client.dart' as realclient;
import 'package:control_plane_server/src/generated/endpoints.dart';
import 'package:control_plane_server/src/generated/protocol.dart';
import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

/// REAL full-stack proof for the Flutter operator UI data path.
///
/// [operator_ui_e2e_test.dart] drives the endpoints over an in-process
/// session. This suite goes one layer further: it starts the REAL Serverpod
/// HTTP server (test mode, real PostgreSQL on :9090), connects with the REAL
/// generated `control_plane_client.Client` that the Flutter app itself uses,
/// and runs the needs-you flow (block -> Needs You -> resolve -> same WorkItem
/// advances) plus Overview / All Work / Run Detail wire reads over HTTP through
/// real serialization, real Serverpod dispatch, and real PostgreSQL.
///
/// NOTE: endpoint results are the typed Serverpod protocol models. These tests
/// are the regression canary for canonical generation: every result serializes
/// and deserializes through the generated typed models with NO hand-edits to
/// the generated client, so `serverpod generate` restores pristine output.
void main() {
  final openSessions = <Session>[];
  Serverpod? pod;

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
        "work_item", "human_decision", "work_item_transition",
        "job", "job_claim", "scheduler_event",
        "worker_execution", "worker_result", "worker_event", "worker_registration",
        "agent_execution_request", "agent_execution", "agent_event",
        "agent_result", "platform_verification"
      RESTART IDENTITY CASCADE
    ''');
  }

  late realclient.Client client;

  setUpAll(() async {
    pod = Serverpod(
      ['--mode', 'test', '--apply-migrations'],
      Protocol(),
      Endpoints(),
    );
    await pod!.start();
    client = realclient.Client('http://127.0.0.1:${pod!.server.port}/');
  });

  tearDownAll(() async {
    for (final session in List.of(openSessions)) {
      await session.close();
    }
    openSessions.clear();
    await pod?.shutdown(exitProcess: false);
  });

  group(
    'real generated client -> Serverpod -> PostgreSQL',
    () {
      setUp(truncateDomainTables);

      test(
        'homeEndpoints.overview + listWorkItems return real rows over HTTP',
        () async {
          final db = await newDb();
          final now = DateTime.now().toUtc();
          final ts = now.toIso8601String();
          await db.queryNoTransaction('''
          INSERT INTO work_item ("workItemId", "productId", "category", "title",
            "state", "createdAt", "updatedAt", "completedAt", "blockingHumanDecisionId", "version")
          VALUES
            ('rew-h1', 'p', 'feature', 'Running over HTTP', 'agent_executing', '$ts', '$ts', NULL, NULL, 1),
            ('rew-h2', 'p', 'feature', 'Finished over HTTP', 'completed', '$ts', '$ts', '$ts', NULL, 1)
        ''');

          final overview = await client.homeEndpoints.overview();
          expect(overview.running, greaterThanOrEqualTo(1));
          expect(overview.recentlyFinished, greaterThanOrEqualTo(1));

          final list = await client.homeEndpoints.listWorkItems(limit: 20);
          final ids = list.map((item) => item.workItemId).toList();
          expect(ids, contains('rew-h1'));
          expect(ids, contains('rew-h2'));
        },
      );

      test(
        'workflow.inspect returns real transition history over HTTP',
        () async {
          final db = await newDb();
          final now = DateTime.now().toUtc();
          final ts = now.toIso8601String();
          await db.queryNoTransaction('''
          INSERT INTO work_item ("workItemId", "productId", "category", "title",
            "state", "createdAt", "updatedAt", "version")
          VALUES ('rew-iv', 'p', 'feature', 'Timeline over HTTP', 'agent_executing', '$ts', '$ts', 1)
        ''');
          await db.queryNoTransaction('''
          INSERT INTO work_item_transition ("transitionId", "workItemId", "fromState",
            "toState", "trigger", "actorType", "outcome", "occurredAt")
          VALUES
            ('rt1', 'rew-iv', 'draft', 'planning', 'system_event', 'orchestrator', 'accepted', '$ts'),
            ('rt2', 'rew-iv', 'planning', 'planned', 'system_event', 'orchestrator', 'accepted', '$ts'),
            ('rt3', 'rew-iv', 'planned', 'design_not_required', 'system_event', 'orchestrator', 'accepted', '$ts'),
            ('rt4', 'rew-iv', 'design_not_required', 'agent_executing', 'system_event', 'orchestrator', 'accepted', '$ts')
        ''');

          final result = await client.workflowEndpoints.inspect(
            workItemId: 'rew-iv',
          );
          expect(result.workItem.workItemId, 'rew-iv');
          expect(result.workItem.state, 'agent_executing');
          final toStates = result.transitionHistory
              .map((h) => h.toState)
              .toList();
          expect(
            toStates,
            ['planning', 'planned', 'design_not_required', 'agent_executing'],
          );
        },
      );

      test(
        'SAME WorkItem ID round-trips through resolve over HTTP, decision '
        'leaves pending, state advances',
        () async {
          final db = await newDb();
          final now = DateTime.now().toUtc();
          final ts = now.toIso8601String();
          await db.queryNoTransaction('''
          INSERT INTO work_item ("workItemId", "productId", "category", "title",
            "state", "blockingHumanDecisionId", "createdAt", "updatedAt", "version")
          VALUES ('rew-same', 'p', 'feature', 'Resume over HTTP', 'waiting_for_human_decision', 'dec-rew', '$ts', '$ts', 1)
        ''');
          await db.queryNoTransaction('''
          INSERT INTO human_decision ("decisionId", "workItemId", "decisionType",
            "status", "question", "blocking", "requestedAt", "updatedAt")
          VALUES ('dec-rew', 'rew-same', 'design_approval', 'pending', 'Approve the design?', true, '$ts', '$ts')
        ''');

          final pending = await client.homeEndpoints.pendingDecisions();
          expect(
            pending.map((d) => d.decisionId),
            contains('dec-rew'),
            reason: 'decision must surface via real HTTP before resolution',
          );

          final resolution = await client.workflowEndpoints.resolveDecision(
            decisionId: 'dec-rew',
            choice: 'approve',
            decider: 'operator',
            rationale: 'Looks good over real HTTP',
            algorithm: 'Ed25519',
            publicKey: 'key-operator',
            signature: 'sig-rew',
            signedAt: DateTime.utc(2026, 9, 15),
          );
          expect(
            resolution.workItem.workItemId,
            'rew-same',
            reason: 'SAME WorkItem ID must be preserved over real HTTP',
          );

          final after = await client.workflowEndpoints.inspect(
            workItemId: 'rew-same',
          );
          expect(
            after.workItem.state,
            'design_approved',
            reason: 'design_approval + approve must advance workflow state',
          );
          final lastPair = after.transitionHistory.last;
          expect(lastPair.fromState, 'waiting_for_human_decision');
          expect(lastPair.toState, 'design_approved');

          final pendingAfter = await client.homeEndpoints.pendingDecisions();
          expect(
            pendingAfter.map((d) => d.decisionId),
            isNot(contains('dec-rew')),
            reason: 'resolved decision must leave the Needs You stream',
          );
        },
      );
    },
  );
}
