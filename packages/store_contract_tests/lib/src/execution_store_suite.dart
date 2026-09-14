import 'fixtures.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

import 'package:execution_coordinator/execution_coordinator.dart';

/// Execution store contract suite. Runs against any [ExecutionStore]
/// implementation.
void runExecutionStoreSuite({
  required String groupName,
  required Future<ExecutionStore> Function() createStore,
}) {
  group(groupName, () {
    test('requests round-trip', () async {
      final store = await createStore();
      await store.saveRequest(buildAgentRequest());
      expect(await store.readRequest('ae-1'), buildAgentRequest());
      expect(await store.readRequest('missing'), isNull);
    });

    test('executions round-trip with CAS version checks', () async {
      final store = await createStore();
      await store.saveExecution(buildAgentExecution());
      expect(await store.readExecution('ae-1'), buildAgentExecution());

      expect(
        store.saveExecution(
          buildAgentExecution(version: 2),
          expectedVersion: 1,
        ),
        completes,
      );

      expect(
        store.saveExecution(buildAgentExecution(), expectedVersion: 99),
        throwsA(
          isA<ConcurrentExecutionModificationException>().having(
            (e) => e.actualVersion,
            'actualVersion',
            2,
          ),
        ),
      );

      expect(
        () => store.readExecution('missing'),
        throwsA(isA<ExecutionNotFoundException>()),
      );
    });

    test('executions list and resolve latest per work item', () async {
      final store = await createStore();
      await store.saveExecution(
        buildAgentExecution(executionId: 'ae-1', version: 1),
      );
      await store.saveExecution(
        buildAgentExecution(
          executionId: 'ae-2',
          status: AgentSessionStatus.completed,
          version: 1,
          startedAt: DateTime.utc(2026, 1, 1, 12, 10),
        ),
      );
      final all = await store.listExecutions();
      expect(all.map((e) => e.executionId), containsAll(['ae-1', 'ae-2']));
      final latest = await store.latestExecutionForWorkItem(kWorkItemId);
      expect(latest?.executionId, 'ae-2');
    });

    test('agent events round-trip in stable sequence order', () async {
      final store = await createStore();
      await store.appendEvent(buildAgentEvent(sequence: 1));
      await store.appendEvent(buildAgentEvent(sequence: 2));
      final events = await store.readEvents('ae-1');
      expect(events.map((e) => e.sequence), [1, 2]);
      expect(events.first.type, AgentEventType.toolCompleted);
    });

    test('agent results round-trip', () async {
      final store = await createStore();
      await store.saveResult('ae-1', buildAgentResult());
      final loaded = await store.readResult('ae-1');
      expect(loaded?.resultId, 'res-1');
      expect(loaded?.status, AgentResultStatus.completed);
      expect(loaded?.artifacts.first.sha256, 'a' * 64);
      expect(loaded?.changedFiles?.first.operation, ChangedFileOperation.added);
      expect(loaded?.claimedChecks?.first.status, AgentClaimStatus.passed);
    });

    test('platform verifications round-trip per execution', () async {
      final store = await createStore();
      await store.saveVerification(buildVerification());
      final verifications = await store.readVerifications('ae-1');
      expect(verifications.length, 1);
      expect(
        verifications.first.evidenceKind,
        EvidenceKind.platformVerifiedEvidence,
      );
      expect(verifications.first.mechanism, 'process_dart_analyze');
    });

    test('inTransaction batches mutations when supported', () async {
      final store = await createStore();
      await store.inTransaction((tx) async {
        await tx.saveRequest(buildAgentRequest());
        await tx.saveExecution(buildAgentExecution());
        await tx.appendEvent(buildAgentEvent());
      });
      expect(await store.readExecution('ae-1'), buildAgentExecution());
      expect((await store.readEvents('ae-1')).length, 1);
    });
  });
}
