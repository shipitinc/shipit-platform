import 'fixtures.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';

/// Worker store contract suite. Runs against any [WorkerStore]
/// implementation.
void runWorkerStoreSuite({
  required String groupName,
  required Future<WorkerStore> Function() createStore,
}) {
  group(groupName, () {
    test('worker executions round-trip with CAS version checks', () async {
      final store = await createStore();
      await store.saveWorkerExecution(buildWorkerExecution());
      expect(await store.readWorkerExecution('we-1'), buildWorkerExecution());
    });

    test('saveWorkerExecution enforces compare-and-swap on version', () async {
      final store = await createStore();
      final execution = buildWorkerExecution();
      await store.saveWorkerExecution(execution);

      expect(
        store.saveWorkerExecution(execution, expectedVersion: 99),
        throwsA(
          isA<ConcurrentWorkerModificationException>().having(
            (e) => e.actualVersion,
            'actualVersion',
            execution.version,
          ),
        ),
      );

      await store.saveWorkerExecution(execution, expectedVersion: 1);
      expect(await store.readWorkerExecution('we-1'), buildWorkerExecution());
    });

    test('worker executions are listed', () async {
      final store = await createStore();
      await store.saveWorkerExecution(buildWorkerExecution());
      await store.saveWorkerExecution(
        buildWorkerExecution(
          workerExecutionId: 'we-2',
          status: WorkerExecutionStatus.executedFail,
        ),
      );
      final all = await store.listWorkerExecutions();
      expect(
        all.map((e) => e.workerExecutionId),
        containsAll(['we-1', 'we-2']),
      );
    });

    test('results round-trip and are replaced per execution', () async {
      final store = await createStore();
      await store.saveWorkerExecution(buildWorkerExecution());
      await store.saveResult(buildWorkerResult());
      final loaded = (await store.readResult('we-1'))!;
      expect(loaded.status, WorkerExecutionStatus.executedPass);
      expect(loaded.changedFiles.first.path, 'lib/landing.dart');
    });

    test('worker events round-trip in stable sequence order', () async {
      final store = await createStore();
      await store.appendEvent(buildWorkerEvent(sequence: 1));
      await store.appendEvent(buildWorkerEvent(sequence: 2));
      final events = await store.readEvents('we-1');
      expect(events.map((e) => e.sequence), [1, 2]);
      expect(events.first.type, WorkerEventType.workspaceReady);
      expect(events.first.payload, {'revision': 'abc1234'});
    });

    test('inTransaction batches mutations when supported', () async {
      final store = await createStore();
      await store.inTransaction((tx) async {
        await tx.saveWorkerExecution(buildWorkerExecution());
        await tx.appendEvent(buildWorkerEvent());
      });
      expect(await store.readWorkerExecution('we-1'), buildWorkerExecution());
      expect((await store.readEvents('we-1')).length, 1);
    });
  });
}
