import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';
import 'package:workflow_store/workflow_store.dart';

import 'package:control_plane_server/src/qa/qa_workspace_retention.dart';

/// A workspace manager that records the releases it was asked for, so the
/// test can assert the RULES without a git repository.
class _FakeRetentionManager implements EvaluationRetainingWorkspaceManager {
  _FakeRetentionManager(List<WorkspaceDescriptor> descriptors)
    : _descriptors = {for (final d in descriptors) d.workspaceId: d};

  final Map<String, WorkspaceDescriptor> _descriptors;
  final List<String> released = [];

  @override
  Future<WorkerCleanupStatus> release(WorkspaceDescriptor descriptor) async {
    released.add(descriptor.workspaceId);
    _descriptors.remove(descriptor.workspaceId);
    return WorkerCleanupStatus.removed;
  }

  @override
  Future<List<WorkspaceDescriptor>> discoverAll() async =>
      _descriptors.values.toList();

  @override
  Future<WorkspaceDescriptor> prepare(
    WorkerExecutionRequest request, {
    String workerId = '',
  }) async => throw UnimplementedError();

  @override
  Future<WorkerCleanupStatus> cleanup(WorkspaceDescriptor descriptor) async =>
      WorkerCleanupStatus.pending;
}

/// A store whose reads fail for a reason that is NOT "the item is gone".
class _UnreadableWorkflowStore extends InMemoryWorkflowStore {
  @override
  Future<WorkItem> readWorkItem(String workItemId) async =>
      throw StateError('the store is unavailable');
}

void main() {
  final now = DateTime.utc(2026, 10, 21, 12);

  WorkspaceDescriptor descriptorFor(String workerExecutionId) =>
      WorkspaceDescriptor(
        workspaceId: 'ws-$workerExecutionId',
        workerExecutionId: workerExecutionId,
        workerId: 'w-impl-local',
        repositoryPath: '/repo',
        startingRevision: 'abc123',
        worktreePath: '/workspaces/ws-$workerExecutionId',
        detached: true,
        createdAt: now.subtract(const Duration(hours: 2)),
      );

  WorkerExecution executionFor(
    String workerExecutionId, {
    String workItemId = 'wi-1',
    WorkerCleanupStatus? cleanupStatus = WorkerCleanupStatus.pending,
    String? workspaceId,
    bool terminal = true,
  }) => WorkerExecution(
    workerExecutionId: workerExecutionId,
    workItemId: workItemId,
    repositoryPath: '/repo',
    requestedStartingRevision: 'abc123',
    requiredCapabilities: const {WorkerCapability.linux},
    status: terminal
        ? WorkerExecutionStatus.executedPass
        : WorkerExecutionStatus.agentExecuting,
    cleanupPolicy: WorkerCleanupPolicy.removeAlways,
    workerId: 'w-impl-local',
    workspaceId: workspaceId ?? 'ws-$workerExecutionId',
    cleanupStatus: cleanupStatus,
    createdAt: now.subtract(const Duration(hours: 3)),
    endedAt: now.subtract(const Duration(hours: 2)),
  );

  WorkItem itemFor(
    String workItemId, {
    required WorkItemState state,
    Map<String, dynamic>? metadata,
    DateTime? updatedAt,
  }) => WorkItem(
    workItemId: workItemId,
    productId: 'prod-1',
    category: WorkItemCategory.feature,
    title: 'work item $workItemId',
    state: state,
    metadata: metadata,
    createdAt: now.subtract(const Duration(days: 1)),
    updatedAt: updatedAt ?? now.subtract(const Duration(minutes: 5)),
  );

  Future<
    (
      QaWorkspaceRetentionReport report,
      _FakeRetentionManager manager,
      InMemoryWorkerStore workerStore,
    )
  >
  reclaim({
    required WorkItem? item,
    WorkerExecution? execution,
    WorkflowStore? workflowStore,
    bool workspaceOnDisk = true,
  }) async {
    final workerStore = InMemoryWorkerStore();
    final exec = execution ?? executionFor('wx-1');
    await workerStore.saveWorkerExecution(exec);
    final manager = _FakeRetentionManager(
      workspaceOnDisk ? [descriptorFor(exec.workerExecutionId)] : const [],
    );
    final store = workflowStore ?? InMemoryWorkflowStore();
    if (item != null) {
      await store.saveWorkItem(item);
    }
    final retention = QaWorkspaceRetention(
      workerStore: workerStore,
      workflowStore: store,
      workspaceManager: manager,
      clock: () => now,
    );
    final report = await retention.reclaim();
    return (report, manager, workerStore);
  }

  test(
    'the workspace is released once the evaluation that read it is over',
    () async {
      final (report, manager, workerStore) = await reclaim(
        item: itemFor(
          'wi-1',
          state: WorkItemState.qaPassed,
          metadata: {
            'qaEvaluation': {
              'outcomeKind': 'pass',
              'qaContractId': 'qa-1',
            },
          },
        ),
      );

      expect(report.released, 1);
      expect(manager.released, ['ws-wx-1']);
      final execution = await workerStore.readWorkerExecution('wx-1');
      expect(
        execution?.cleanupStatus,
        WorkerCleanupStatus.removed,
        reason: 'the row must stop claiming that a removal is outstanding',
      );
    },
  );

  test('a workspace whose item left the QA path is released', () async {
    final (report, manager, _) = await reclaim(
      item: itemFor('wi-1', state: WorkItemState.implementationReady),
    );

    expect(report.released, 1);
    expect(manager.released, ['ws-wx-1']);
  });

  test('a workspace whose item can still be evaluated is kept', () async {
    final (report, manager, _) = await reclaim(
      item: itemFor('wi-1', state: WorkItemState.reviewApproved),
    );

    expect(report.released, 0);
    expect(report.kept, 1);
    expect(manager.released, isEmpty);
  });

  test('a workspace waiting on a human is kept even when the item has not '
      'moved for weeks, because a slow human is not a leak', () async {
    final (report, manager, _) = await reclaim(
      item: itemFor(
        'wi-1',
        state: WorkItemState.waitingForHumanDecision,
        updatedAt: now.subtract(const Duration(days: 40)),
      ),
    );

    expect(report.released, 0);
    expect(report.kept, 1);
    expect(manager.released, isEmpty);
  });

  test(
    'a workspace whose item is stuck in a machine-paced QA state is '
    'reclaimed, so an abandoned item does not keep a worktree for ever',
    () async {
      final (report, manager, _) = await reclaim(
        item: itemFor(
          'wi-1',
          state: WorkItemState.qaInProgress,
          updatedAt: now.subtract(const Duration(days: 8)),
        ),
      );

      expect(report.released, 1);
      expect(manager.released, ['ws-wx-1']);
    },
  );

  test('a workspace whose item no longer exists is released', () async {
    final (report, manager, _) = await reclaim(item: null);

    expect(report.released, 1);
    expect(manager.released, ['ws-wx-1']);
  });

  test('a workspace whose item cannot be read is kept, because an unreadable '
      'store is not a verdict', () async {
    final (report, manager, _) = await reclaim(
      item: itemFor('wi-1', state: WorkItemState.reviewApproved),
      workflowStore: _UnreadableWorkflowStore(),
    );

    expect(report.released, 0);
    expect(report.kept, 1);
    expect(manager.released, isEmpty);
  });

  test(
    'an execution whose removal is not outstanding is not touched',
    () async {
      final (report, manager, _) = await reclaim(
        item: itemFor('wi-1', state: WorkItemState.implementationReady),
        execution: executionFor(
          'wx-1',
          cleanupStatus: WorkerCleanupStatus.removed,
        ),
      );

      expect(report.released, 0);
      expect(manager.released, isEmpty);
    },
  );

  test('an execution that is still running is not touched: its workspace is '
      'not a retention', () async {
    final (report, manager, _) = await reclaim(
      item: itemFor('wi-1', state: WorkItemState.implementationReady),
      execution: executionFor('wx-1', terminal: false),
    );

    expect(report.released, 0);
    expect(manager.released, isEmpty);
  });

  test(
    'a retained workspace that is no longer on disk stops the row claiming an '
    'outstanding removal',
    () async {
      // The workspace can be gone while its row still says `pending` — for
      // instance when the removal happened and the row write was lost. There is
      // then nothing to remove, and the row must stop claiming otherwise: a
      // row that says "a removal is outstanding" for a workspace that is not
      // there makes the item's durable record lie about its own cleanup, and
      // keeps the sweep re-deciding about nothing.
      final (report, manager, workerStore) = await reclaim(
        item: itemFor('wi-1', state: WorkItemState.implementationReady),
        workspaceOnDisk: false,
      );

      expect(report.released, 0);
      expect(report.kept, 0);
      expect(report.failed, 0);
      expect(manager.released, isEmpty);

      final execution = await workerStore.readWorkerExecution('wx-1');
      expect(
        execution?.cleanupStatus,
        WorkerCleanupStatus.removed,
        reason: 'the row must not keep claiming a removal that cannot happen',
      );
    },
  );

  // ---- THE JOIN KEY. ----
  //
  // The execution row's own `workspaceId` column is NOT a usable join key,
  // because the worker layer never populates it: `LocalWorker._finish` writes
  // `workspaceId: current.workspaceId ?? ''` and nothing ever sets
  // `current.workspaceId`, so a finished execution carries an EMPTY string
  // there. A sweep that joined on it would match no workspace, decide every
  // retained workspace had vanished, mark the row `removed` — and leave the
  // worktree on disk for ever.
  //
  // This test pins the PRODUCTION shape of the row, not a convenient one.
  test('the workspace is found even though the execution row carries no '
      'workspace id, which is what the worker layer actually writes', () async {
    final (report, manager, workerStore) = await reclaim(
      item: itemFor('wi-1', state: WorkItemState.qaPassed),
      execution: executionFor('wx-1', workspaceId: ''),
    );

    expect(
      report.released,
      1,
      reason:
          'the workspace is on disk and its evaluation is over, so it must be '
          'removed — the empty `workspaceId` on the row must not hide it',
    );
    expect(manager.released, ['ws-wx-1']);
    final execution = await workerStore.readWorkerExecution('wx-1');
    expect(execution?.cleanupStatus, WorkerCleanupStatus.removed);
  });

  // ---- THE INTERRUPT PATH. ----
  //
  // A run whose PROCESS died mid-flight never reached its cleanup stage, so
  // its row says nothing about a cleanup at all. The scheduler's zombie
  // reclaim marks that row terminal and deliberately leaves the cleanup
  // status alone. This sweep is what finishes the job — otherwise the
  // worktree of a killed run is on disk for ever.
  test('a run whose process died mid-flight has its workspace released once '
      'the row is terminal', () async {
    final (report, manager, workerStore) = await reclaim(
      item: itemFor('wi-1', state: WorkItemState.implementationReady),
      execution: executionFor(
        'wx-1',
        cleanupStatus: null,
      ),
    );

    expect(
      report.released,
      1,
      reason:
          'a terminal row whose removal is still outstanding is exactly what '
          'this sweep exists to finish, whether the run deferred the removal '
          'or never got as far as making one',
    );
    expect(manager.released, ['ws-wx-1']);
    final execution = await workerStore.readWorkerExecution('wx-1');
    expect(execution?.cleanupStatus, WorkerCleanupStatus.removed);
  });

  test('a run that never got a workspace stops claiming one, and says so '
      'honestly rather than claiming a removal that never happened', () async {
    final (report, _, workerStore) = await reclaim(
      item: itemFor('wi-1', state: WorkItemState.implementationReady),
      execution: executionFor('wx-1', cleanupStatus: null),
      workspaceOnDisk: false,
    );

    expect(report.released, 0);
    final execution = await workerStore.readWorkerExecution('wx-1');
    expect(
      execution?.cleanupStatus,
      WorkerCleanupStatus.notApplicable,
      reason:
          'there was never a workspace to remove, so the row says the cleanup '
          'did not apply — not that a removal happened',
    );
  });

  // ---- IDEMPOTENCE. ----
  //
  // The sweep runs on every tick, and a release that was interrupted has to
  // be re-decided by the next one. A sweep that counted the same workspace
  // twice, or failed the second time because the workspace was already gone,
  // would turn a retry into a red tick.
  test('a second sweep over the same state releases nothing and fails '
      'nothing', () async {
    final workerStore = InMemoryWorkerStore();
    await workerStore.saveWorkerExecution(executionFor('wx-1'));
    final manager = _FakeRetentionManager([descriptorFor('wx-1')]);
    final store = InMemoryWorkflowStore();
    await store.saveWorkItem(
      itemFor('wi-1', state: WorkItemState.implementationReady),
    );
    final retention = QaWorkspaceRetention(
      workerStore: workerStore,
      workflowStore: store,
      workspaceManager: manager,
      clock: () => now,
    );

    final first = await retention.reclaim();
    expect(first.released, 1);
    expect(first.failed, 0);

    final second = await retention.reclaim();
    expect(second.released, 0, reason: 'the workspace is already gone');
    expect(second.failed, 0, reason: 'an absent workspace is not a failure');
    expect(second.kept, 0);
  });

  // ---- A FAULTED EVALUATION. ----
  //
  // The decision retains the workspace "until gate evaluation completes". A
  // faulted evaluation never completed, so the workspace is still owed to it.
  // A SETTLED failure carries the durable `qaEvaluation` record and releases
  // immediately; a faulted one carries no such record and keeps the workspace
  // until the stall window reclaims it.
  test('a settled QA failure releases its workspace, because the evaluation '
      'that read it is over whatever its verdict was', () async {
    final (report, manager, _) = await reclaim(
      item: itemFor(
        'wi-1',
        state: WorkItemState.qaFailed,
        metadata: {
          'qaEvaluation': {
            'outcomeKind': 'fail',
            'qaContractId': 'qa-1',
          },
        },
      ),
    );

    expect(report.released, 1);
    expect(manager.released, ['ws-wx-1']);
  });

  test('a FAULTED evaluation keeps its workspace, because an evaluation that '
      'never completed is still owed one', () async {
    final (report, manager, _) = await reclaim(
      item: itemFor('wi-1', state: WorkItemState.qaFailed),
    );

    expect(
      report.released,
      0,
      reason:
          'the drain could not settle the item and recorded no evaluation, so '
          'the evaluation is not over and the workspace is still owed to it',
    );
    expect(report.kept, 1);
    expect(manager.released, isEmpty);
  });

  test('a faulted evaluation is still bounded: the stall window reclaims the '
      'workspace of an item that never moves again', () async {
    final (report, manager, _) = await reclaim(
      item: itemFor(
        'wi-1',
        state: WorkItemState.qaFailed,
        updatedAt: now.subtract(const Duration(days: 8)),
      ),
    );

    expect(report.released, 1);
    expect(manager.released, ['ws-wx-1']);
  });
}
