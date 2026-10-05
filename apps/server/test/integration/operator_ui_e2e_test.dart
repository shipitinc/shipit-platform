import 'package:control_plane_server/src/persistence/persistence_database.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// E2E proof that the Flutter control-plane operator UI's data path is real.
///
/// Seeds deterministic state directly into PostgreSQL, then exercises every
/// endpoint the Flutter app calls. Table names are snake_case; column names
/// are camelCase (Serverpod convention). Endpoint results are the typed
/// Serverpod protocol models, so assertions use field access, not map keys.
void main() {
  final openSessions = <Session>[];

  Future<PersistenceDatabase> newDb() async {
    final session = await Serverpod.instance.createSession(
      enableLogging: false,
    );
    openSessions.add(session);
    return PersistenceDatabase(session.db);
  }

  /// Removes only this suite's rows, in an order that satisfies foreign keys.
  ///
  /// Targeted DELETEs, never a TRUNCATE: `test/integration` shares one database
  /// with files that run concurrently, and truncating `work_item` out from
  /// under them breaks their assertions — this file's own endpoint reads are
  /// assertions of other files' rows too. Every marker is namespaced `ui-*` to
  /// this file. Runs in `setUp` as well as `tearDown`, because a previous run
  /// that aborted mid-test leaves rows behind and re-inserting them would then
  /// violate a unique constraint.
  Future<void> purgeSuiteRows() async {
    final db = await newDb();
    const workItem = 'ui-%';
    const statements = <String>[
      'DELETE FROM "human_decision"       WHERE "workItemId" LIKE \'$workItem\'',
      'DELETE FROM "work_item_transition" WHERE "workItemId" LIKE \'$workItem\'',
      'DELETE FROM "work_item"            WHERE "workItemId" LIKE \'$workItem\'',
    ];
    for (final statement in statements) {
      await db.query(statement);
    }
  }

  withServerpod(
    'control-plane operator UI E2E: real PostgreSQL data flows to Flutter endpoints',
    (sessionBuilder, endpoints) {
      setUp(purgeSuiteRows);

      tearDown(() async {
        await purgeSuiteRows();
        for (final session in List.of(openSessions)) {
          await session.close();
        }
        openSessions.clear();
      });

      test('homeEndpoints.overview returns authoritative counts', () async {
        final db = await newDb();
        final now = DateTime.now().toUtc();
        final ts = now.toIso8601String();
        // ui-h1: agent_executing, no blocking → "running"
        await db.queryNoTransaction('''
          INSERT INTO work_item ("workItemId", "productId", "category", "title",
            "state", "createdAt", "updatedAt", "completedAt", "blockingHumanDecisionId", "version")
          VALUES ('ui-h1', 'p', 'feature', 'Running', 'agent_executing', '$ts', '$ts', NULL, NULL, 1)
        ''');
        // ui-h2: waiting_for_human_decision + blocking → "waitingOnYou"
        await db.queryNoTransaction('''
          INSERT INTO work_item ("workItemId", "productId", "category", "title",
            "state", "createdAt", "updatedAt", "completedAt", "blockingHumanDecisionId", "version")
          VALUES ('ui-h2', 'p', 'feature', 'Blocked', 'waiting_for_human_decision', '$ts', '$ts', NULL, 'dec-ui-ny', 1)
        ''');
        // ui-h3: completed + completedAt recent → "recentlyFinished"
        await db.queryNoTransaction('''
          INSERT INTO work_item ("workItemId", "productId", "category", "title",
            "state", "createdAt", "updatedAt", "completedAt", "blockingHumanDecisionId", "version")
          VALUES ('ui-h3', 'p', 'feature', 'Done', 'completed', '$ts', '$ts', '$ts', NULL, 1)
        ''');
        final overview = await endpoints.homeEndpoints.overview(sessionBuilder);
        expect(overview.running, greaterThanOrEqualTo(1));
        expect(overview.waitingOnYou, greaterThanOrEqualTo(1));
        expect(overview.recentlyFinished, greaterThanOrEqualTo(1));
      });

      test(
        'homeEndpoints.listWorkItems returns persisted work items',
        () async {
          final db = await newDb();
          final now = DateTime.now().toUtc();
          final ts = now.toIso8601String();
          await db.queryNoTransaction('''
          INSERT INTO work_item ("workItemId", "productId", "category", "title",
            "state", "createdAt", "updatedAt", "version")
          VALUES
            ('ui-l1', 'p', 'feature', 'First', 'agent_executing', '$ts', '$ts', 1),
            ('ui-l2', 'p', 'feature', 'Second', 'planning', '$ts', '$ts', 1)
        ''');
          final result = await endpoints.homeEndpoints.listWorkItems(
            sessionBuilder,
            limit: 10,
          );
          final ids = result.map((item) => item.workItemId).toList();
          expect(ids, contains('ui-l1'));
          expect(ids, contains('ui-l2'));
        },
      );

      test('homeEndpoints.listWorkItems filters by state', () async {
        final db = await newDb();
        final now = DateTime.now().toUtc();
        final ts = now.toIso8601String();
        await db.queryNoTransaction('''
          INSERT INTO work_item ("workItemId", "productId", "category", "title",
            "state", "createdAt", "updatedAt", "version")
          VALUES
            ('ui-f1', 'p', 'feature', 'A', 'agent_executing', '$ts', '$ts', 1),
            ('ui-f2', 'p', 'feature', 'B', 'planning', '$ts', '$ts', 1)
        ''');
        final result = await endpoints.homeEndpoints.listWorkItems(
          sessionBuilder,
          state: 'agent_executing',
        );
        expect(result, isNotEmpty, reason: 'at least one matching row');
        for (final item in result) {
          expect(item.state, 'agent_executing');
        }
      });

      test(
        'homeEndpoints.pendingDecisions surfaces blocking decisions',
        () async {
          final db = await newDb();
          final now = DateTime.now().toUtc();
          final ts = now.toIso8601String();
          await db.queryNoTransaction('''
          INSERT INTO work_item ("workItemId", "productId", "category", "title",
            "state", "blockingHumanDecisionId", "createdAt", "updatedAt", "version")
          VALUES ('ui-ny', 'p', 'feature', 'Waiting', 'waiting_for_human_decision', 'dec-ui-ny', '$ts', '$ts', 1)
        ''');
          await db.queryNoTransaction('''
          INSERT INTO human_decision ("decisionId", "workItemId", "decisionType",
            "status", "question", "blocking", "requestedAt", "updatedAt")
          VALUES ('dec-ui-ny', 'ui-ny', 'design_approval', 'pending', 'Approve?', true, '$ts', '$ts')
        ''');
          final result = await endpoints.homeEndpoints.pendingDecisions(
            sessionBuilder,
          );
          expect(result, isNotEmpty);
          final first = result.first;
          expect(first.decisionId, 'dec-ui-ny');
          expect(first.workItemId, 'ui-ny');
          expect(first.workItemTitle, 'Waiting');
          expect(first.question, 'Approve?');
          expect(first.blocking, true);
        },
      );

      test('workflow.inspect returns transition history', () async {
        final db = await newDb();
        final now = DateTime.now().toUtc();
        final ts = now.toIso8601String();
        await db.queryNoTransaction('''
          INSERT INTO work_item ("workItemId", "productId", "category", "title",
            "state", "createdAt", "updatedAt", "version")
          VALUES ('ui-rv', 'p', 'feature', 'Run Visibility', 'agent_executing', '$ts', '$ts', 1)
        ''');
        await db.queryNoTransaction('''
          INSERT INTO work_item_transition ("transitionId", "workItemId", "fromState",
            "toState", "trigger", "actorType", "outcome", "occurredAt")
          VALUES
            ('ui-t1', 'ui-rv', 'draft', 'planning', 'system_event', 'orchestrator', 'accepted', '$ts'),
            ('ui-t2', 'ui-rv', 'planning', 'planned', 'system_event', 'orchestrator', 'accepted', '$ts'),
            ('ui-t3', 'ui-rv', 'planned', 'agent_executing', 'system_event', 'orchestrator', 'accepted', '$ts')
        ''');
        final result = await endpoints.workflowEndpoints.inspect(
          sessionBuilder,
          workItemId: 'ui-rv',
        );
        expect(result.workItem.workItemId, 'ui-rv');
        expect(result.workItem.title, 'Run Visibility');
        expect(result.workItem.state, 'agent_executing');
        expect(result.transitionHistory, hasLength(3));
        final toStates = result.transitionHistory
            .map((h) => h.toState)
            .toList();
        expect(toStates, ['planning', 'planned', 'agent_executing']);
      });

      test('workflow.listDecisions surfaces decisions', () async {
        final db = await newDb();
        final now = DateTime.now().toUtc();
        final ts = now.toIso8601String();
        await db.queryNoTransaction('''
          INSERT INTO work_item ("workItemId", "productId", "category", "title",
            "state", "createdAt", "updatedAt", "version")
          VALUES ('ui-dc', 'p', 'feature', 'Decision Item', 'waiting_for_human_decision', '$ts', '$ts', 1)
        ''');
        await db.queryNoTransaction('''
          INSERT INTO human_decision ("decisionId", "workItemId", "decisionType",
            "status", "question", "blocking", "requestedAt", "updatedAt")
          VALUES ('dec-ui-dc', 'ui-dc', 'design_approval', 'pending', 'Approve migration?', true, '$ts', '$ts')
        ''');
        final result = await endpoints.workflowEndpoints.listDecisions(
          sessionBuilder,
          workItemId: 'ui-dc',
        );
        expect(result, hasLength(1));
        expect(result.first.decisionId, 'dec-ui-dc');
        expect(result.first.question, 'Approve migration?');
      });

      test('SAME WorkItem ID preserved through resolution', () async {
        final db = await newDb();
        final now = DateTime.now().toUtc();
        final ts = now.toIso8601String();
        await db.queryNoTransaction('''
          INSERT INTO work_item ("workItemId", "productId", "category", "title",
            "state", "blockingHumanDecisionId", "createdAt", "updatedAt", "version")
          VALUES ('ui-same', 'p', 'feature', 'Resume Test', 'waiting_for_human_decision', 'dec-ui-same', '$ts', '$ts', 1)
        ''');
        await db.queryNoTransaction('''
          INSERT INTO human_decision ("decisionId", "workItemId", "decisionType",
            "status", "question", "blocking", "requestedAt", "updatedAt")
          VALUES ('dec-ui-same', 'ui-same', 'design_approval', 'pending', 'Approve?', true, '$ts', '$ts')
        ''');

        final before = await endpoints.workflowEndpoints.inspect(
          sessionBuilder,
          workItemId: 'ui-same',
        );
        final originalId = before.workItem.workItemId;
        expect(originalId, 'ui-same');

        final resolution = await endpoints.workflowEndpoints.resolveDecision(
          sessionBuilder,
          decisionId: 'dec-ui-same',
          choice: 'approve',
          decider: 'operator',
          rationale: 'Looks good',
          algorithm: 'Ed25519',
          publicKey: 'key-operator',
          signature: 'sig-1',
          signedAt: DateTime.utc(2026, 9, 15),
        );

        final resolvedWorkItem = resolution.workItem;
        expect(
          resolvedWorkItem.workItemId,
          originalId,
          reason: 'SAME WorkItem ID must be preserved',
        );
        expect(resolvedWorkItem.workItemId, 'ui-same');
        final decision = resolution.decision;
        expect(decision, isNotNull);
        expect(decision!.status, 'resolved');
        expect(decision.choice, 'approve');
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}
