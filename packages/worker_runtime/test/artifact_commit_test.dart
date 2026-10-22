import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'support/git_repo_fixture.dart';

/// A minimal scripted [AgentExecutionDriver]: optionally writes the calculator
/// implementation into the execution's worktree, then reports a completed
/// session. No real coordinator, so the test owns the produced artifact.
class _WritingDriver implements AgentExecutionDriver {
  _WritingDriver({required this.write});

  final bool write;

  @override
  Future<AgentExecution> execute(AgentExecutionRequest request) async {
    if (write) {
      final file = File('${request.workspace.path}/lib/calculator.dart');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('int add(int a, int b) => a + b;\n');
    }
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

/// A committer that always fails, to prove a commit failure is surfaced as an
/// event rather than silently swallowed.
class _FailingCommitter extends ArtifactCommitter {
  const _FailingCommitter();

  @override
  Future<ArtifactCommitOutcome> commit({
    required String worktreePath,
    required String workItemId,
    required String startingRevision,
    required String message,
    String branchPrefix = 'shipit/impl',
  }) async => ArtifactCommitOutcome.failed('scripted commit failure');
}

void main() {
  late Directory temp;
  late GitRepoFixture repo;
  late String workspaceRoot;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('artifact_commit_test');
    repo = GitRepoFixture.create(temp.path);
    workspaceRoot = '${temp.path}/workspaces';
  });

  tearDown(() {
    repo.dispose();
    temp.deleteSync(recursive: true);
  });

  Future<WorkerExecutionResult> runWorker({
    required bool write,
    ArtifactCommitter? committer,
    String workItemId = 'wi-artifact',
    AgentRole role = AgentRole.implementer,
  }) async {
    final worker = LocalWorker(
      workerId: 'w-test',
      poolId: 'test-pool',
      capabilities: const {WorkerCapability.linux},
      workspaceManager: GitWorktreeWorkspaceManager(
        workspaceRoot: workspaceRoot,
      ),
      executionDriver: _WritingDriver(write: write),
      workerStore: InMemoryWorkerStore(),
      artifactCommitter: committer ?? const ArtifactCommitter(),
      platform: 'test',
    );
    return worker.run(
      WorkerExecutionRequest(
        workerExecutionId: 'wx-$workItemId',
        workItemId: workItemId,
        repositoryPath: repo.root.path,
        startingRevision: repo.startingRevision,
        requiredCapabilities: const {WorkerCapability.linux},
        role: role,
        instruction: 'implement add(2,3)==5',
        timeoutSeconds: 60,
        runtimeTypeId: 'test-runtime',
      ),
    );
  }

  ProcessResult git(List<String> args) => Process.runSync(
    'git',
    args,
    workingDirectory: repo.root.path,
    environment: {
      ...Platform.environment,
      'GIT_CONFIG_GLOBAL': '/dev/null',
      'GIT_CONFIG_SYSTEM': '/dev/null',
    },
  );

  test('a produced change is committed onto shipit/impl/<workItemId> and the '
      'result endingRevision is that commit SHA', () async {
    final result = await runWorker(write: true);

    expect(result.endingRevision, isNotNull);
    expect(result.endingRevision, isNot(equals(repo.startingRevision)));

    final branch = git([
      'rev-parse',
      '--verify',
      'refs/heads/shipit/impl/wi-artifact',
    ]);
    expect(branch.exitCode, 0, reason: branch.stderr.toString());
    expect(
      branch.stdout.toString().trim(),
      equals(result.endingRevision),
      reason: 'the durable branch tip must be the produced revision',
    );

    // The commit is reachable from the branch and its tree contains the
    // produced implementation, not the baseline stub.
    final committed = git([
      'show',
      'shipit/impl/wi-artifact:lib/calculator.dart',
    ]);
    expect(committed.exitCode, 0, reason: committed.stderr.toString());
    expect(committed.stdout.toString(), contains('a + b'));
  });

  test('an execution that produces no change creates no branch and leaves '
      'endingRevision exactly at the starting revision', () async {
    final result = await runWorker(write: false);

    expect(result.endingRevision, equals(repo.startingRevision));

    final branch = git([
      'rev-parse',
      '--verify',
      '--quiet',
      'refs/heads/shipit/impl/wi-artifact',
    ]);
    expect(
      branch.exitCode,
      isNot(0),
      reason: 'no artifact means no branch is created',
    );
  });

  test(
    'a commit failure is surfaced as an event and does not abort the run',
    () async {
      final store = InMemoryWorkerStore();
      final events = <WorkerEventRecord>[];
      final worker = LocalWorker(
        workerId: 'w-test',
        poolId: 'test-pool',
        capabilities: const {WorkerCapability.linux},
        workspaceManager: GitWorktreeWorkspaceManager(
          workspaceRoot: workspaceRoot,
        ),
        executionDriver: _WritingDriver(write: true),
        workerStore: store,
        artifactCommitter: const _FailingCommitter(),
        platform: 'test',
        eventSink: events.add,
      );

      final result = await worker.run(
        WorkerExecutionRequest(
          workerExecutionId: 'wx-wi-fail',
          workItemId: 'wi-fail',
          repositoryPath: repo.root.path,
          startingRevision: repo.startingRevision,
          requiredCapabilities: const {WorkerCapability.linux},
          role: AgentRole.implementer,
          instruction: 'implement add(2,3)==5',
          timeoutSeconds: 60,
          runtimeTypeId: 'test-runtime',
        ),
      );

      // The run still completes; the failure detail is visible via the event.
      expect(result.endingRevision, equals(repo.startingRevision));
      final failureEvents = events.where(
        (e) =>
            e.type == WorkerEventType.finalizing &&
            e.payload?['artifactCommitFailed'] == true,
      );
      expect(failureEvents, hasLength(1));
      expect(
        failureEvents.single.payload?['detail'],
        contains('scripted commit failure'),
      );
    },
  );

  test('a DESIGN reviewer never commits, even if it changed files', () async {
    final result = await runWorker(write: true, role: AgentRole.designReviewer);

    expect(
      result.endingRevision,
      repo.startingRevision,
      reason:
          'a reviewer inspects a produced artifact; it must never create one. '
          'The worktree HEAD stays at the requested revision and no durable '
          'branch is created',
    );
    final branch = git([
      'rev-parse',
      '--verify',
      'refs/heads/shipit/impl/wi-artifact',
    ]);
    expect(
      branch.exitCode,
      isNot(0),
      reason: 'no reviewer commit branch may exist',
    );
  });
}
