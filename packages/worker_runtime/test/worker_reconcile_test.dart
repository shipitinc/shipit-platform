import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'support/git_repo_fixture.dart';

void main() {
  late Directory temp;
  late GitRepoFixture repo;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('reconcile_');
    repo = GitRepoFixture.create(temp.path);
  });

  tearDown(() {
    try {
      repo.dispose();
    } on Object {}
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('reconcile cleans only platform-owned workspaces of STRANDED executions '
      'and is idempotent across brand-new instances', () async {
    final root = '${temp.path}/workspaces';
    final manager1 = GitWorktreeWorkspaceManager(workspaceRoot: root);

    // A stranded execution: prepared a workspace, then the process died.
    final request = WorkerExecutionRequest(
      workerExecutionId: 'wx-orphan',
      workItemId: 'wi-1',
      repositoryPath: repo.root.path,
      startingRevision: repo.startingRevision,
      requiredCapabilities: const {WorkerCapability.linux},
      role: AgentRole.implementer,
      instruction: 'x',
      timeoutSeconds: 60,
      runtimeTypeId: 'fake-runtime',
    );
    final descriptor = await manager1.prepare(request, workerId: 'w-linux');
    expect(Directory(descriptor.worktreePath).existsSync(), isTrue);

    // Simulate the pre-crash state on disk with a NON-terminal record.
    final storeFile = File('${temp.path}/worker_store.json');
    final store1 = FileJsonWorkerStore(storeFile);
    await store1.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: 'wx-orphan',
        workItemId: 'wi-1',
        repositoryPath: repo.root.path,
        requestedStartingRevision: repo.startingRevision,
        requiredCapabilities: const {WorkerCapability.linux},
        status: WorkerExecutionStatus.agentExecuting,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
        workerId: 'w-linux',
        workspaceId: descriptor.workspaceId,
        startedAt: DateTime.now().toUtc(),
      ),
    );

    // A DIFFERENT, brand-new manager + store instance observes the orphan.
    final manager2 = GitWorktreeWorkspaceManager(workspaceRoot: root);
    final store2 = FileJsonWorkerStore(storeFile);
    final reconciler = WorkerReconciler(
      workerStore: store2,
      workspaceManager: manager2,
    );

    final orphans = await reconciler.reconcileOrphans();

    expect(orphans, hasLength(1));
    final orphan = orphans.single;
    expect(orphan.status, WorkerExecutionStatus.orphaned);
    expect(orphan.cleanupStatus, WorkerCleanupStatus.removed);
    expect(Directory(descriptor.worktreePath).existsSync(), isFalse);

    // Second reconcile pass: nothing to do (idempotent).
    final again = await reconciler.reconcileOrphans();
    expect(again, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'reconcile never touches workspaces with no ownership metadata',
    () async {
      final storeFile = File('${temp.path}/worker_store.json');
      final store = FileJsonWorkerStore(storeFile);
      await store.saveWorkerExecution(
        WorkerExecution(
          workerExecutionId: 'wx-ghost',
          workItemId: 'wi-1',
          repositoryPath: repo.root.path,
          requestedStartingRevision: repo.startingRevision,
          requiredCapabilities: const {WorkerCapability.linux},
          status: WorkerExecutionStatus.agentExecuting,
          cleanupPolicy: WorkerCleanupPolicy.removeAlways,
        ),
      );
      // An UNKNOWN directory that happens to live in the workspace root.
      Directory('${temp.path}/workspaces/not-ours').createSync(recursive: true);

      final reconciler = WorkerReconciler(
        workerStore: store,
        workspaceManager: GitWorktreeWorkspaceManager(
          workspaceRoot: '${temp.path}/workspaces',
        ),
      );
      final orphans = await reconciler.reconcileOrphans();

      expect(orphans, hasLength(1));
      expect(orphans.single.cleanupStatus, WorkerCleanupStatus.notApplicable);
      // The unknown directory is untouched.
      expect(
        Directory('${temp.path}/workspaces/not-ours').existsSync(),
        isTrue,
      );
    },
  );

  test('cleanup is safe to call twice for the same descriptor', () async {
    final manager = GitWorktreeWorkspaceManager(
      workspaceRoot: '${temp.path}/workspaces',
    );
    final request = WorkerExecutionRequest(
      workerExecutionId: 'wx-1',
      workItemId: 'wi-1',
      repositoryPath: repo.root.path,
      startingRevision: repo.startingRevision,
      requiredCapabilities: const {WorkerCapability.linux},
      role: AgentRole.implementer,
      instruction: 'x',
      timeoutSeconds: 60,
      runtimeTypeId: 'fake-runtime',
    );
    final descriptor = await manager.prepare(request);

    final first = await manager.cleanup(descriptor);
    expect(first, WorkerCleanupStatus.removed);
    expect((await manager.discoverAll()), isEmpty);

    final second = await manager.cleanup(descriptor);
    expect(second, WorkerCleanupStatus.removed);
  });

  test('discoverAll ignores malformed metadata instead of guessing', () async {
    final root = '${temp.path}/workspaces';
    GitWorktreeWorkspaceManager(workspaceRoot: root);
    File('$root/other.json').writeAsStringSync('{not json');
    Directory('$root/other').createSync(recursive: true);

    final manager = GitWorktreeWorkspaceManager(workspaceRoot: root);
    expect(await manager.discoverAll(), isEmpty);
  });
}
