import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

import 'support/fake_agent.dart';
import 'support/git_repo_fixture.dart';
import 'support/host.dart';

/// `LocalWorker` is the second link in the chain that decides whether a killed
/// agent run is ever tried again, and the link that can silently undo the fix.
///
/// ## Why this file exists
///
/// The coordinator now settles a budget expiry as
/// [AgentSessionStatus.interrupted] rather than
/// [AgentSessionStatus.failed]. That only matters because
/// `LocalWorker._drive` maps the two onto different
/// [WorkerExecutionStatus]es, and `RetryPolicy.classify` in
/// `packages/scheduler` maps THOSE onto `JobFailureKind.transient` and
/// `JobFailureKind.permanent` respectively:
///
/// ```text
/// interrupted -> timedOut     -> transient  -> one attempt spent, retries
/// failed      -> executedFail -> permanent  -> zero attempts spent, dead
/// ```
///
/// So the exactness of this mapping is the whole mechanism. A worker that
/// collapsed `interrupted` into `executedFail` — a one-line change with no
/// visible symptom anywhere — would put the review budget back where it was.
///
/// The second half is the negative control. `failed` must still map to
/// `executedFail`, because the dangerous regression here runs in the opposite
/// direction from the fix: broad enough to make a crash retryable turns a
/// permanently broken runtime into an unbounded retry loop.
void main() {
  late Directory temp;
  late GitRepoFixture repo;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('worker_budget_');
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

  Future<WorkerExecutionResult> runWith({
    required WritingBehavior behavior,
    bool throwOnStart = false,
  }) async {
    final host = WorkerHost(
      repo: repo,
      workspaceRoot: '${temp.path}/workspaces',
      behavior: behavior,
      throwOnStart: throwOnStart,
    );
    await host.workItemReady();
    final result = await host.dispatcher.run(
      host.request(
        repositoryPath: repo.root.path,
        startingRevision: repo.startingRevision,
        timeoutSeconds: 60,
      ),
    );
    return result;
  }

  group('an interrupted session is a TIMEOUT, and stays retryable', () {
    test('interrupted settles timedOut, not executedFail', () async {
      final result = await runWith(behavior: WritingBehavior.interrupt);

      expect(
        result.status,
        WorkerExecutionStatus.timedOut,
        reason:
            'timedOut is what RetryPolicy classifies as TRANSIENT. '
            'executedFail here would classify as permanent and the job would '
            'fail having spent no attempt — the exact defect the coordinator '
            'change was made to fix.',
      );
      expect(result.failureCode, WorkerFailureCode.timedOut);
      expect(result.failureDetail, contains('timed out'));
    });
  });

  group('a CRASH stays a failure, and stays unretryable', () {
    test(
      'a session that reports its own failure settles executedFail',
      () async {
        final result = await runWith(behavior: WritingBehavior.fail);

        expect(
          result.status,
          WorkerExecutionStatus.executedFail,
          reason:
              'the agent reported a failure of its own accord. That is a coding '
              'or model failure and routes through the correction gate, not '
              'through an automatic re-run.',
        );
        expect(result.failureCode, WorkerFailureCode.agentFailed);
      },
    );

    test(
      'a runtime that throws while starting settles executedFail too',
      () async {
        final result = await runWith(
          behavior: WritingBehavior.fail,
          throwOnStart: true,
        );

        expect(
          result.status,
          WorkerExecutionStatus.executedFail,
          reason:
              'a runtime that crashes on every start is permanently broken. '
              'Settling it as timedOut would make it retry until maxAttempts ran '
              'out on every job, which is the "retry forever" regression this '
              'lane must not introduce.',
        );
      },
    );

    test(
      'the two outcomes are different statuses, not the same one twice',
      () async {
        final interrupted = await runWith(behavior: WritingBehavior.interrupt);
        final crashed = await runWith(behavior: WritingBehavior.fail);

        expect(interrupted.status, WorkerExecutionStatus.timedOut);
        expect(crashed.status, WorkerExecutionStatus.executedFail);
        expect(interrupted.status, isNot(crashed.status));
      },
    );
  });
}
