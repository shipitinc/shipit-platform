import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'support/git_repo_fixture.dart';
import 'support/fake_agent.dart';
import 'support/host.dart';

void main() {
  late Directory temp;
  late GitRepoFixture repo;
  late WorkerHost host;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('worker_');
    repo = GitRepoFixture.create(temp.path);
    host = WorkerHost(repo: repo, workspaceRoot: '${temp.path}/workspaces');
  });

  tearDown(() {
    try {
      repo.dispose();
    } on Object {
      // cleanup may already have removed worktrees; root removal is best-effort
    }
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<WorkerExecutionRequest> readyRequest({
    required String revision,
    Set<WorkerCapability> capabilities = const {WorkerCapability.linux},
    WorkerCleanupPolicy cleanupPolicy = WorkerCleanupPolicy.removeAlways,
    String workerExecutionId = 'wx-1',
    int timeoutSeconds = 60,
  }) async {
    await host.workItemReady();
    return host.request(
      repositoryPath: repo.root.path,
      startingRevision: revision,
      requiredCapabilities: capabilities,
      cleanupPolicy: cleanupPolicy,
      workerExecutionId: workerExecutionId,
      timeoutSeconds: timeoutSeconds,
    );
  }

  group('WorkerDispatcher end-to-end', () {
    test('runs in an isolated worktree, captures the diff, verifies, cleans up '
        'and leaves the source checkout untouched', () async {
      final request = await readyRequest(revision: repo.startingRevision);
      repo.dirtySource();

      final result = await host.dispatcher.run(request);

      expect(result.status, WorkerExecutionStatus.executedPass);
      expect(result.agentResultStatus, AgentResultStatus.completed);
      expect(result.verificationPassed, isTrue);
      expect(result.failureCode, WorkerFailureCode.none);
      expect(result.cleanupStatus, WorkerCleanupStatus.removed);
      expect(result.endingRevision, repo.startingRevision);

      // The platform's git-observed view, not the agent's claim.
      final changed = result.changedFiles;
      expect(
        changed.any(
          (f) =>
              f.path == 'lib/calculator.dart' &&
              f.operation == ChangedFileOperation.modified,
        ),
        isTrue,
      );

      // Workspace gone after cleanup.
      expect(await host.workspaceManager.discoverAll(), isEmpty);
      // The source checkout was NOT modified by agent execution.
      expect(
        File('${repo.root.path}/lib/calculator.dart').readAsStringSync(),
        contains('dirty'),
      );
      // No worktree created in the source repo.
      final worktrees = Process.runSync('git', [
        '-C',
        repo.root.path,
        'worktree',
        'list',
      ]);
      expect(worktrees.stdout.toString().trim().split('\n'), hasLength(1));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('the worktree is pinned EXACTLY to the requested revision, never to '
        'spawn-time HEAD', () async {
      // Baseline A is the requested revision; commit B exists and is the
      // spawn-time HEAD. The verify script demands the worktree HEAD be A.
      final baseline = repo.startingRevision;
      repo.commitImplementation();
      final newer = repo.startingRevision;
      expect(newer != baseline, isTrue);
      repo.writeVerify(expectingRevision: baseline);

      final request = await readyRequest(
        revision: baseline,
        workerExecutionId: 'wx-pin',
      );

      final result = await host.dispatcher.run(request);

      // The worktree ran at the pinned old revision A, so the pin check
      // passes. Had the platform used spawn-time HEAD (B), verification
      // would have failed and this test would catch the wrong revision.
      expect(result.status, WorkerExecutionStatus.executedPass);
      expect(result.verificationPassed, isTrue);
      expect(result.startingRevision, baseline);
      expect(result.endingRevision, baseline);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('an unknown starting revision never starts the agent', () async {
      final request = await readyRequest(
        revision: 'deadbeef' * 5,
        workerExecutionId: 'wx-unknown',
      );
      final result = await host.dispatcher.run(request);

      expect(result.status, WorkerExecutionStatus.prepareFailed);
      expect(result.failureCode, WorkerFailureCode.prepareFailed);
      expect(host.session.wasStarted, isFalse);
      expect(result.cleanupStatus, WorkerCleanupStatus.notApplicable);
    });

    test('no compatible worker throws without side effects', () async {
      final request = await readyRequest(
        revision: repo.startingRevision,
        capabilities: const {WorkerCapability.gpu},
        workerExecutionId: 'wx-gpu',
      );

      expect(
        () => host.dispatcher.run(request),
        throwsA(
          isA<WorkerDispatchException>().having(
            (e) => e.outcome,
            'outcome',
            WorkerDispatchOutcome.noCompatibleWorker,
          ),
        ),
      );
      expect(host.session.wasStarted, isFalse);
      expect(await host.workerStore.listWorkerExecutions(), isEmpty);
    });

    test('a busy worker is reported as busy, not selected', () async {
      await host.worker.acquire();
      final request = await readyRequest(
        revision: repo.startingRevision,
        workerExecutionId: 'wx-busy',
      );

      expect(
        () => host.dispatcher.run(request),
        throwsA(
          isA<WorkerDispatchException>().having(
            (e) => e.outcome,
            'outcome',
            WorkerDispatchOutcome.workerBusy,
          ),
        ),
      );
      await host.worker.release();
    });

    test('compatible-but-absent-for-capability selection is deterministic', () {
      final selection = host.dispatcher.select(
        host.request(
          repositoryPath: repo.root.path,
          startingRevision: repo.startingRevision,
        ),
      );
      expect(selection.isDispatched, isTrue);
      expect(selection.candidate!.workerId, 'w-linux-1');
      expect(selection.candidate!.platform, 'linux-x64');
    });

    test(
      'cleanup policy preserveOnFailure keeps the worktree for debug',
      () async {
        final failHost = WorkerHost(
          repo: repo,
          workspaceRoot: '${temp.path}/workspaces',
          behavior: WritingBehavior.fail,
        );
        await failHost.workItemReady();
        final request = failHost.request(
          repositoryPath: repo.root.path,
          startingRevision: repo.startingRevision,
          cleanupPolicy: WorkerCleanupPolicy.preserveOnFailure,
          workerExecutionId: 'wx-preserve',
        );

        final result = await failHost.dispatcher.run(request);

        expect(result.status, WorkerExecutionStatus.executedFail);
        expect(result.cleanupStatus, WorkerCleanupStatus.preservedPerPolicy);
        expect(await failHost.workspaceManager.discoverAll(), isNotEmpty);
      },
    );

    test(
      'environment policy does not allow un-inherited host variables',
      () async {
        const policy = EnvironmentPolicy(
          inheritAllowlist: ['SHIPIT_ALLOWED'],
          explicit: {'SHIPIT_FIXED': 'fixed'},
        );
        final resolved = policy.resolve(
          host.request(
            repositoryPath: repo.root.path,
            startingRevision: repo.startingRevision,
            envAllowlist: const ['SHIPIT_ALLOWED'],
            environment: const {'SHIPIT_EXPLICIT': 'from-request'},
          ),
          hostEnv: const {
            'SHIPIT_ALLOWED': 'inherited-ok',
            'SECRET_LEAK': 'must-not-leak',
          },
        );

        expect(resolved, {
          'SHIPIT_ALLOWED': 'inherited-ok',
          'SHIPIT_EXPLICIT': 'from-request',
          'SHIPIT_FIXED': 'fixed',
        });
        expect(resolved.containsKey('SECRET_LEAK'), isFalse);
      },
    );
  });
}
