import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'support/git_repo_fixture.dart';

/// A minimal scripted [AgentExecutionDriver] that writes into the execution's
/// worktree and reports a completed session. No real coordinator: the test
/// owns the produced artifact and the workspace.
class _WritingDriver implements AgentExecutionDriver {
  @override
  Future<AgentExecution> execute(AgentExecutionRequest request) async {
    final file = File('${request.workspace.path}/lib/calculator.dart');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('int add(int a, int b) => a + b;\n');
    final now = DateTime.now().toUtc();
    return AgentExecution(
      executionId: request.executionId,
      workItemId: request.workItemId,
      requestId: request.executionId,
      runtimeTypeId: request.runtimeTypeId,
      role: request.role,
      status: AgentSessionStatus.completed,
      workspace: request.workspace,
      startedAt: now,
      completedAt: now,
    );
  }

  @override
  Future<AgentExecution> cancel(String executionId, String reason) async =>
      throw UnimplementedError();

  @override
  Future<List<PlatformVerification>> verificationsFor(
    String executionId,
  ) async => const [];
}

/// A scripted [AgentExecutionDriver] whose session FAILS, so the run takes
/// the worker's failure path instead of its happy path.
class _FailingDriver implements AgentExecutionDriver {
  @override
  Future<AgentExecution> execute(AgentExecutionRequest request) async {
    final now = DateTime.now().toUtc();
    return AgentExecution(
      executionId: request.executionId,
      workItemId: request.workItemId,
      requestId: request.executionId,
      runtimeTypeId: request.runtimeTypeId,
      role: request.role,
      status: AgentSessionStatus.failed,
      workspace: request.workspace,
      startedAt: now,
      completedAt: now,
    );
  }

  @override
  Future<AgentExecution> cancel(String executionId, String reason) async =>
      throw UnimplementedError();

  @override
  Future<List<PlatformVerification>> verificationsFor(
    String executionId,
  ) async => const [];
}

/// A scripted [AgentExecutionDriver] whose session is INTERRUPTED — the shape
/// a budget expiry settles as, and the one the decision's "on interrupt
/// alike" condition is about.
///
/// Deliberately distinct from [_FailingDriver]: the two must never settle as
/// the same worker status, because only one of them is retryable (see
/// `test/interrupted_is_a_timeout_test.dart`).
class _InterruptedDriver implements AgentExecutionDriver {
  @override
  Future<AgentExecution> execute(AgentExecutionRequest request) async {
    final now = DateTime.now().toUtc();
    return AgentExecution(
      executionId: request.executionId,
      workItemId: request.workItemId,
      requestId: request.executionId,
      runtimeTypeId: request.runtimeTypeId,
      role: request.role,
      status: AgentSessionStatus.interrupted,
      workspace: request.workspace,
      startedAt: now,
      completedAt: now,
    );
  }

  @override
  Future<AgentExecution> cancel(String executionId, String reason) async =>
      throw UnimplementedError();

  @override
  Future<List<PlatformVerification>> verificationsFor(
    String executionId,
  ) async => const [];
}

void main() {
  late Directory temp;
  late GitRepoFixture repo;
  late String workspaceRoot;
  late InMemoryWorkerStore workerStore;
  late RetainingWorkspaceManager manager;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('evaluation_retention_test');
    repo = GitRepoFixture.create(temp.path);
    workspaceRoot = '${temp.path}/workspaces';
    workerStore = InMemoryWorkerStore();
    manager = RetainingWorkspaceManager(
      GitWorktreeWorkspaceManager(workspaceRoot: workspaceRoot),
    );
  });

  tearDown(() {
    repo.dispose();
    temp.deleteSync(recursive: true);
  });

  String worktreePathFor(String workerExecutionId) =>
      '$workspaceRoot/ws-$workerExecutionId';

  Future<WorkerExecutionResult> runWorker({
    String id = 'wx-retained',
    AgentExecutionDriver? driver,
  }) async {
    final worker = LocalWorker(
      workerId: 'w-test',
      poolId: 'test-pool',
      capabilities: const {WorkerCapability.linux},
      workspaceManager: manager,
      executionDriver: driver ?? _WritingDriver(),
      workerStore: workerStore,
      platform: 'test',
    );
    return worker.run(
      WorkerExecutionRequest(
        workerExecutionId: id,
        workItemId: 'wi-retained',
        repositoryPath: repo.root.path,
        startingRevision: repo.startingRevision,
        requiredCapabilities: const {WorkerCapability.linux},
        role: AgentRole.implementer,
        instruction: 'implement add(2,3)==5',
        timeoutSeconds: 60,
        runtimeTypeId: 'test-runtime',
      ),
    );
  }

  test('a deferred cleanup leaves the worktree in place, because the gate that '
      're-reads it has not read it yet', () async {
    await runWorker();

    expect(
      Directory(worktreePathFor('wx-retained')).existsSync(),
      isTrue,
      reason: 'the workspace the QA gates re-read must still be there',
    );
  });

  test('the deferred removal is recorded as pending, which is the platform\'s '
      'own word for "this workspace is still on disk"', () async {
    final result = await runWorker();

    expect(result.cleanupStatus, WorkerCleanupStatus.pending);
    final execution = await workerStore.readWorkerExecution('wx-retained');
    expect(execution?.cleanupStatus, WorkerCleanupStatus.pending);
    expect(
      execution?.cleanupMissing,
      isTrue,
      reason:
          'an outstanding removal must be visible to whoever owns '
          'workspaces',
    );
  });

  test('the audit trail does not claim the workspace was cleaned when it was '
      'not', () async {
    await runWorker();

    final events = await workerStore.readEvents('wx-retained');
    expect(
      events.where((e) => e.type == WorkerEventType.workspaceCleaned),
      isEmpty,
      reason:
          'an event that says the workspace was cleaned must never be '
          'emitted for a workspace that is still on disk',
    );
    expect(
      events.where((e) => e.type == WorkerEventType.workerReleased),
      isNotEmpty,
      reason: 'the worker WAS released; only the removal was deferred',
    );
  });

  test(
    'releasing the retained workspace removes it and marks it cleaned',
    () async {
      await runWorker();

      final descriptors = await manager.discoverAll();
      expect(descriptors, hasLength(1));
      final descriptor = descriptors.single;

      final status = await manager.release(descriptor);

      expect(status, WorkerCleanupStatus.removed);
      expect(
        Directory(worktreePathFor('wx-retained')).existsSync(),
        isFalse,
        reason:
            'the removal the deferral owed must actually remove the worktree',
      );
      final after = await manager.discoverAll();
      expect(after, isEmpty, reason: 'a cleaned workspace is not a live one');
    },
  );

  test('releasing twice is safe: the second release reports the workspace as '
      'already removed', () async {
    await runWorker();

    final descriptor = (await manager.discoverAll()).single;
    expect(await manager.release(descriptor), WorkerCleanupStatus.removed);

    final status = await manager.release(
      descriptor.markCleaned(DateTime.now().toUtc()),
    );
    expect(status, WorkerCleanupStatus.removed);
  });

  test('the failure path still says workerReleased for a workspace that WAS '
      'removed: the retention changed nothing else', () async {
    // The retention changed ONE thing about this event: a DEFERRED removal
    // must not claim the workspace was cleaned, because it is still on disk.
    // It changed nothing else, and this test is what holds it to that.
    //
    // A failed run whose workspace really WAS removed has always reported
    // `workerReleased`. If it reported `workspaceCleaned` instead, the
    // retention would have silently become a change to what the audit trail
    // MEANS — and it would have moved a lane that never signed up for it.
    final baseManager = GitWorktreeWorkspaceManager(
      workspaceRoot: workspaceRoot,
    );
    final worker = LocalWorker(
      workerId: 'w-test',
      poolId: 'test-pool',
      capabilities: const {WorkerCapability.linux},
      workspaceManager: baseManager,
      executionDriver: _FailingDriver(),
      workerStore: workerStore,
      platform: 'test',
    );

    final result = await worker.run(
      WorkerExecutionRequest(
        workerExecutionId: 'wx-failed',
        workItemId: 'wi-failed',
        repositoryPath: repo.root.path,
        startingRevision: repo.startingRevision,
        requiredCapabilities: const {WorkerCapability.linux},
        role: AgentRole.implementer,
        instruction: 'fail on purpose',
        timeoutSeconds: 60,
        runtimeTypeId: 'test-runtime',
      ),
    );

    expect(result.status, WorkerExecutionStatus.executedFail);
    expect(result.cleanupStatus, WorkerCleanupStatus.removed);
    expect(
      Directory(worktreePathFor('wx-failed')).existsSync(),
      isFalse,
      reason: 'the failure path really did remove the workspace',
    );

    final events = await workerStore.readEvents('wx-failed');
    expect(
      events.where((e) => e.type == WorkerEventType.workspaceCleaned),
      isEmpty,
      reason:
          'a failed run reports workerReleased, not workspaceCleaned, and the '
          'retention must not change that',
    );
    expect(
      events.where((e) => e.type == WorkerEventType.workerReleased),
      isNotEmpty,
    );
  });

  // ---- THE INTERRUPT PATH. ----
  //
  // Decision `9b7e4c31` attaches a condition to the retention: the workspace
  // is removed "on success, on failure and on interrupt alike". Deferring the
  // removal must not turn into CANCELLING it for the outcome where the
  // platform is least likely to look again — so this is the case that has to
  // be proved rather than asserted.
  test('an interrupted run defers the removal like any other run, and the '
      'deferred removal still happens', () async {
    final result = await runWorker(
      id: 'wx-interrupted',
      driver: _InterruptedDriver(),
    );

    expect(
      result.status,
      WorkerExecutionStatus.timedOut,
      reason:
          'an interrupted session settles as a timeout, and only one of the '
          'two interrupted shapes is retryable — see '
          'interrupted_is_a_timeout_test.dart',
    );
    expect(
      result.cleanupStatus,
      WorkerCleanupStatus.pending,
      reason:
          'the interrupt defers the removal exactly as a pass does; it does '
          'not cancel it',
    );
    expect(
      Directory(worktreePathFor('wx-interrupted')).existsSync(),
      isTrue,
      reason: 'the deferred workspace is still on disk',
    );

    final events = await workerStore.readEvents('wx-interrupted');
    expect(
      events.where((e) => e.type == WorkerEventType.workspaceCleaned),
      isEmpty,
      reason:
          'the workspace was NOT cleaned — it is still on disk — so the audit '
          'trail must not say it was',
    );

    // And the removal the deferral owed DOES happen.
    final descriptor = (await manager.discoverAll()).singleWhere(
      (d) => d.workerExecutionId == 'wx-interrupted',
    );
    expect(await manager.release(descriptor), WorkerCleanupStatus.removed);
    expect(
      Directory(worktreePathFor('wx-interrupted')).existsSync(),
      isFalse,
      reason:
          'removal is unconditional on interrupt: the release removes the '
          'workspace the interrupted run left behind',
    );
  });

  // ---- THE RESTART PATH. ----
  //
  // A retained workspace has to survive the death of the process that
  // created it, because the QA evaluation that reads it happens in a LATER
  // process. That makes the deferral's durability a filesystem property, not
  // an in-memory one: a fresh manager over the same workspace root must find
  // the workspace and must be able to release it.
  test('a retained workspace outlives the process that created it: a fresh '
      'manager over the same root finds it and releases it', () async {
    await runWorker(id: 'wx-restart');

    expect(Directory(worktreePathFor('wx-restart')).existsSync(), isTrue);

    // A NEW process: a new manager, no shared state with the one above.
    final afterRestart = RetainingWorkspaceManager(
      GitWorktreeWorkspaceManager(workspaceRoot: workspaceRoot),
    );
    final descriptors = await afterRestart.discoverAll();
    expect(
      descriptors,
      hasLength(1),
      reason:
          'the deferral is durable on DISK — the ownership metadata is what '
          'the next process reads, so the next process can find the workspace '
          'it has to release',
    );
    final descriptor = descriptors.single;
    expect(descriptor.workerExecutionId, 'wx-restart');

    expect(await afterRestart.release(descriptor), WorkerCleanupStatus.removed);
    expect(
      Directory(worktreePathFor('wx-restart')).existsSync(),
      isFalse,
      reason:
          'the next process is able to perform the removal the first process '
          'deferred — which is what makes the deferral a deferral and not a '
          'leak',
    );
  });
}
