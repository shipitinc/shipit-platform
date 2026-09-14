import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('worker_store_');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test(
    'FileJsonWorkerStore survives a full run and a fresh instance',
    () async {
      final file = File('${temp.path}/store.json');
      final runStarted = DateTime.now().toUtc();

      final store1 = FileJsonWorkerStore(file);
      await store1.saveWorkerExecution(
        WorkerExecution(
          workerExecutionId: 'wx-1',
          workItemId: 'wi-1',
          repositoryPath: '/repo',
          requestedStartingRevision: 'abc123',
          requiredCapabilities: const {WorkerCapability.linux},
          status: WorkerExecutionStatus.agentExecuting,
          cleanupPolicy: WorkerCleanupPolicy.removeAlways,
          workerId: 'w-linux',
          version: 3,
        ),
      );
      await store1.appendEvent(
        WorkerEventRecord(
          eventId: 'we-evt',
          workerExecutionId: 'wx-1',
          workItemId: 'wi-1',
          sequence: 1,
          type: WorkerEventType.workerAcquired,
          occurredAt: runStarted,
        ),
      );

      final store2 = FileJsonWorkerStore(file);
      final execution = (await store2.readWorkerExecution('wx-1'))!;
      expect(execution.status, WorkerExecutionStatus.agentExecuting);
      expect(execution.version, 3);
      expect(execution.workerId, 'w-linux');
      expect(
        (await store2.readEvents('wx-1')).single.type,
        WorkerEventType.workerAcquired,
      );
      expect(await store2.listWorkerExecutions(), hasLength(1));
    },
  );

  test('FileJsonWorkerStore enforces compare-and-swap on version', () async {
    final file = File('${temp.path}/store.json');
    final store = FileJsonWorkerStore(file);
    await store.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: 'wx-1',
        workItemId: 'wi-1',
        repositoryPath: '/repo',
        requestedStartingRevision: 'abc123',
        requiredCapabilities: const {WorkerCapability.linux},
        status: WorkerExecutionStatus.acquiring,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
      ),
    );

    expect(
      () => store.saveWorkerExecution(
        WorkerExecution(
          workerExecutionId: 'wx-1',
          workItemId: 'wi-1',
          repositoryPath: '/repo',
          requestedStartingRevision: 'abc123',
          requiredCapabilities: const {WorkerCapability.linux},
          status: WorkerExecutionStatus.workspacePreparing,
          cleanupPolicy: WorkerCleanupPolicy.removeAlways,
        ),
        expectedVersion: 9,
      ),
      throwsA(isA<ConcurrentWorkerModificationException>()),
    );
  });
}
