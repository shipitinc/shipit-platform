import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'support/git_repo_fixture.dart';

/// Opt-in real-runtime smoke test: the FULL worker stack (dispatcher → worker
/// → isolated git worktree → ExecutionCoordinator → real `opencode` ACP) runs
/// against a genuine model. Skipped unless explicitly enabled:
///
///   SHIPIT_REAL_OPENCODE=true dart test test/real_opencode_smoke_test.dart
///
/// Everything else is proven deterministically by the unit tests with a fake
/// writing runtime. This is the end-of-slice proof that one worker execution
/// really does pin a revision, isolate the source checkout, run one real
/// runtime, verify the change from git/processes, and clean up.
void main() {
  final runReal = Platform.environment['SHIPIT_REAL_OPENCODE'] == 'true';
  if (!runReal) {
    test(
      'real OpenCode worker smoke tests are opt-in',
      () => print(
        'Skipping real OpenCode worker smoke tests. '
        'Set SHIPIT_REAL_OPENCODE=true to run against a live opencode binary.',
      ),
      skip: 'opt-in via SHIPIT_REAL_OPENCODE=true',
    );
    return;
  }

  late Directory temp;
  late GitRepoFixture repo;
  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;
  late ExecutionCoordinator coordinator;
  late GitWorktreeWorkspaceManager workspaceManager;
  late LocalWorker worker;
  late WorkerDispatcher dispatcher;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('real_worker_');
    repo = GitRepoFixture.create(temp.path);
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();
    coordinator = ExecutionCoordinator(
      store: executionStore,
      workflowEngine: workflowEngine,
      runtime: AgentRuntime(
        registry: AgentAdapterRegistry()..register(OpencodeAdapter()),
      ),
      verificationPlan: VerificationPlan(
        command: [Platform.resolvedExecutable, 'tool/verify.dart'],
      ),
    );
    workspaceManager = GitWorktreeWorkspaceManager(
      workspaceRoot: '${temp.path}/workspaces',
    );
    worker = LocalWorker(
      workerId: 'w-real-1',
      poolId: 'real-pool',
      capabilities: const {
        WorkerCapability.linux,
        WorkerCapability.docker,
        WorkerCapability.flutter,
      },
      workspaceManager: workspaceManager,
      executionDriver: CoordinatorAgentExecutionDriver(coordinator),
      workerStore: InMemoryWorkerStore(),
    );
    dispatcher = WorkerDispatcher(registry: WorkerRegistry()..register(worker));
  });

  tearDown(() {
    try {
      repo.dispose();
    } on Object {}
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<void> parkWorkItem() async {
    await workflowEngine.createWorkItem(
      workItemId: 'wi-real',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Implement calculator add',
      qaContractId: 'qa-1',
      featureRef: 'feature/calc',
    );
    await workflowEngine.transition(
      workItemId: 'wi-real',
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
    );
    await workflowEngine.transition(
      workItemId: 'wi-real',
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      context: const {'featureRef': 'feature/calc'},
    );
    await workflowEngine.transition(
      workItemId: 'wi-real',
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );
  }

  test('happy path: one real worker execution pins the revision, runs a real '
      'opencode session in the worktree, verifies the change from git, and '
      'cleans the worktree without touching the source checkout', () async {
    await parkWorkItem();
    repo.dirtySource();

    final result = await dispatcher.run(
      WorkerExecutionRequest(
        workerExecutionId: 'wx-real-1',
        workItemId: 'wi-real',
        repositoryPath: repo.root.path,
        startingRevision: repo.startingRevision,
        requiredCapabilities: const {WorkerCapability.linux},
        role: AgentRole.implementer,
        instruction:
            'Implement the add function in lib/calculator.dart so that '
            'add(2, 3) returns 5. Write the body; do not touch tool/verify.dart '
            'or any other file. Do not add dependencies.',
        timeoutSeconds: 300,
        runtimeTypeId: 'opencode',
        runtimeConfig: const {'pure': 'true'},
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
      ),
    );

    expect(
      result.status,
      WorkerExecutionStatus.executedPass,
      reason:
          'worker execution must end executedPass\n'
          'failureCode=${result.failureCode}\n'
          'failureDetail=${result.failureDetail}\n'
          'diffSummary=${result.diffSummary}\n'
          'NOTE: a timed-out initialize/session/new typically means the '
          'machine could not cold-start `opencode acp` in time (network/'
          'catalog fetch). Retry on a healthy connection.',
    );
    expect(result.verificationPassed, isTrue);
    expect(result.endingRevision, repo.startingRevision);

    // The platform's git-observed view of what changed in the worktree.
    expect(
      result.changedFiles.any(
        (f) =>
            f.path == 'lib/calculator.dart' &&
            f.operation == ChangedFileOperation.modified,
      ),
      isTrue,
    );

    // Cleaned up: no live workspace remains.
    expect(await workspaceManager.discoverAll(), isEmpty);
    // The source checkout (dirtied by an operator) is untouched by the run.
    expect(
      File('${repo.root.path}/lib/calculator.dart').readAsStringSync(),
      contains('dirty'),
    );
    final worktrees = Process.runSync('git', [
      '-C',
      repo.root.path,
      'worktree',
      'list',
    ]);
    expect(worktrees.stdout.toString().trim().split('\n'), hasLength(1));

    // The durable work item landed on agentCompleted with platform evidence.
    final item = await workflowEngine.loadWorkItem('wi-real');
    expect(item.state, WorkItemState.agentCompleted);
    final verification = await executionStore.readVerifications(
      'agx-wx-real-1',
    );
    expect(
      verification.where((v) => v.status == AgentClaimStatus.passed),
      isNotEmpty,
    );
  }, timeout: const Timeout(Duration(minutes: 20)));
}
