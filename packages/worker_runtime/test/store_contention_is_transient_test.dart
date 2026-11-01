import 'dart:io';

import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'support/git_repo_fixture.dart';
import 'support/host.dart';

/// `LocalWorker._drive` is where a store compare-and-swap loss was flattened
/// into an ordinary `executedFail` — which `RetryPolicy.classify` in
/// `packages/scheduler` then mapped to `JobFailureKind.permanent`, so six QA
/// jobs died terminally on races they had already lost correctly (F-241,
/// `Concurrent modification of <item|execution>` under F-237 detached
/// dispatch).
///
/// A CAS loss means ANOTHER writer already advanced the durable row: it is
/// transient by nature and the job must retry. This file pins the two halves
/// the worker owns:
///
///  1. a CAS loss on the WORK ITEM or AGENT EXECUTION rows settles
///     `executedFail` carrying [storeContentionMarker] — the typed signal
///     `RetryPolicy` reads — instead of an unmarked agent failure; and
///  2. a CAS loss on the WORKER EXECUTION row itself writes nothing at all,
///     because the row already carries the winning verdict and every write
///     the settle path could make would contradict it.
///
/// The negative control matters as much: an ordinary thrown error must still
/// produce an unmarked `executedFail`, or this change would make every real
/// failure retryable — the "retry forever" regression in the other
/// direction.

/// An [ExecutionStore] that loses exactly one compare-and-swap — the first
/// `saveExecution` that supplies `expectedVersion`, which on a real run is
/// the coordinator's `starting -> running` write. The exception thrown is
/// the REAL type the store raises in production, so the worker's typed
/// catch is exercised rather than approximated.
class _CasLosingExecutionStore extends InMemoryExecutionStore {
  var armed = true;

  @override
  Future<void> saveExecution(
    AgentExecution execution, {
    int? expectedVersion,
  }) async {
    if (armed && expectedVersion != null) {
      armed = false;
      throw ConcurrentExecutionModificationException(
        executionId: execution.executionId,
        expectedVersion: expectedVersion,
        actualVersion: expectedVersion + 1,
      );
    }
    return super.saveExecution(execution, expectedVersion: expectedVersion);
  }
}

/// Same device for the work-item CAS: the first `saveWorkItem` carrying
/// `expectedVersion` after the fixture's setup is the coordinator's entry
/// transition (`designNotRequired -> agentExecuting`) — exactly the write
/// `Concurrent modification of <item>` was observed on.
class _CasLosingWorkflowStore extends InMemoryWorkflowStore {
  var armed = false;

  @override
  Future<void> saveWorkItem(WorkItem item, {int? expectedVersion}) async {
    if (armed && expectedVersion != null) {
      armed = false;
      throw ConcurrentModificationException(
        entityId: item.workItemId,
        expectedVersion: expectedVersion,
        actualVersion: expectedVersion + 1,
      );
    }
    return super.saveWorkItem(item, expectedVersion: expectedVersion);
  }
}

/// A driver whose `execute` throws a scripted error — used where the thrown
/// value must be chosen directly rather than produced by a store race (the
/// worker-row CAS, and the non-contention negative control).
class _ThrowingDriver implements AgentExecutionDriver {
  _ThrowingDriver(this.error);

  final Object error;

  @override
  Future<AgentExecution> execute(AgentExecutionRequest request) =>
      Future.error(error);

  @override
  Future<AgentExecution> cancel(String executionId, String reason) =>
      throw UnimplementedError('not reached: execute throws first');

  @override
  Future<List<PlatformVerification>> verificationsFor(String executionId) =>
      Future.value(const []);
}

void main() {
  late Directory temp;
  late GitRepoFixture repo;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('worker_contention_');
    repo = GitRepoFixture.create(temp.path);
  });

  tearDown(() {
    try {
      repo.dispose();
    } on Object {
      // cleanup may already have removed worktrees; root removal is best-effort
    }
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<WorkerExecutionResult> run({
    WorkflowStore? workflowStore,
    ExecutionStore? executionStore,
    AgentExecutionDriver? executionDriver,
  }) async {
    final host = WorkerHost(
      repo: repo,
      workspaceRoot: '${temp.path}/workspaces',
      workflowStore: workflowStore,
      executionStore: executionStore,
      executionDriver: executionDriver,
    );
    await host.workItemReady();
    if (workflowStore is _CasLosingWorkflowStore) {
      // Armed only after the fixture's own createWorkItem/transitions have
      // written, so the loss lands on the coordinator's entry transition.
      workflowStore.armed = true;
    }
    return host.dispatcher.run(
      host.request(
        repositoryPath: repo.root.path,
        startingRevision: repo.startingRevision,
        timeoutSeconds: 60,
      ),
    );
  }

  group('a CAS loss on a row the run does not own is marked TRANSIENT', () {
    test(
      'losing the agent_execution CAS settles executedFail with the marker',
      () async {
        final result = await run(executionStore: _CasLosingExecutionStore());

        expect(result.status, WorkerExecutionStatus.executedFail);
        expect(
          result.failureDetail,
          startsWith(storeContentionMarker),
          reason:
              'the marker is what RetryPolicy.classify reads as TRANSIENT. '
              'An unmarked detail here was the F-241 defect: executedFail '
              'with plain CAS prose classified permanent and the job died '
              'having spent no attempt.',
        );
        expect(result.failureDetail, contains('Concurrent modification'));
      },
    );

    test(
      'losing the work_item CAS settles executedFail with the marker',
      () async {
        final result = await run(workflowStore: _CasLosingWorkflowStore());

        expect(result.status, WorkerExecutionStatus.executedFail);
        expect(result.failureDetail, startsWith(storeContentionMarker));
        expect(
          result.failureDetail,
          contains('Concurrent modification of wi-1'),
        );
      },
    );

    test(
      'a NON-contention failure keeps the unmarked permanent classification',
      () async {
        final result = await run(
          executionDriver: _ThrowingDriver(StateError('the runtime broke')),
        );

        expect(result.status, WorkerExecutionStatus.executedFail);
        expect(
          result.failureDetail,
          isNot(startsWith(storeContentionMarker)),
          reason:
              'only a store compare-and-swap loss may carry the marker. A '
              'plain error must still classify permanent, or every real '
              'failure becomes retryable — the regression in the opposite '
              'direction.',
        );
      },
    );
  });

  group('a CAS loss on the worker_execution row itself writes nothing', () {
    test('the drive rethrows and the winning verdict on the row is not '
        'overwritten', () async {
      final contention = ConcurrentWorkerModificationException(
        workerExecutionId: 'wx-1',
        expectedVersion: 2,
        actualVersion: 3,
      );
      final host = WorkerHost(
        repo: repo,
        workspaceRoot: '${temp.path}/workspaces',
        executionDriver: _ThrowingDriver(contention),
      );
      await host.workItemReady();
      await expectLater(
        host.dispatcher.run(
          host.request(
            repositoryPath: repo.root.path,
            startingRevision: repo.startingRevision,
            timeoutSeconds: 60,
          ),
        ),
        throwsA(isA<ConcurrentWorkerModificationException>()),
        reason:
            'the drive must not settle a row it lost — `_settleDetachedRun` '
            'catches the rethrow upstream and drops the claim so reconcile '
            'adopts the row that already won',
      );

      final row = await host.workerStore.readWorkerExecution('wx-1');
      expect(
        row!.status,
        isNot(WorkerExecutionStatus.executedFail),
        reason:
            'writing `executedFail` over a row a concurrent writer already '
            'advanced would replace the winning verdict with a second, '
            'false one. The row must be left to whoever won the '
            'compare-and-swap.',
      );
      expect(
        await host.workerStore.readResult('wx-1'),
        isNull,
        reason:
            'no result may be persisted for a settle this drive lost — the '
            'durable record belongs to the writer that won.',
      );
    });
  });

  group('the contention family is enumerable by type, not by prose', () {
    test('isStoreContentionError knows every store CAS exception', () {
      expect(
        isStoreContentionError(
          ConcurrentWorkerModificationException(
            workerExecutionId: 'wx-1',
            expectedVersion: 1,
            actualVersion: 2,
          ),
        ),
        isTrue,
      );
      expect(
        isStoreContentionError(
          ConcurrentExecutionModificationException(
            executionId: 'agx-1',
            expectedVersion: 1,
            actualVersion: 2,
          ),
        ),
        isTrue,
      );
      expect(
        isStoreContentionError(
          ConcurrentModificationException(
            entityId: 'wi-1',
            expectedVersion: 1,
            actualVersion: 2,
          ),
        ),
        isTrue,
      );
      expect(isStoreContentionError(StateError('x')), isFalse);
      expect(isStoreContentionError(const WorkerBusyException('w-1')), isFalse);
    });
  });
}
