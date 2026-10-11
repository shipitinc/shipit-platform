import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';

import 'support/controlled_dispatcher.dart';
import 'support/file_host.dart';

/// Reconciliation used to answer "is the worker row terminal?" and, when it was
/// not, renew the lease forever. A worker whose process died mid-execution is
/// also not terminal, so it was renewed on every tick and the 10 minute lease
/// could never expire - which is how a zombie outlived it for 4.78 hours.
///
/// These tests pin both directions of the replacement: an execution nothing is
/// running behind is reclaimed to a terminal job state, and an execution that
/// really is alive is still renewed without a duplicate dispatch.
void main() {
  late Directory dir;
  final t0 = DateTime.utc(2026, 1, 1, 12);
  // One lease past `t0`: the claim has expired, so reconciliation runs.
  final t1 = t0.add(const Duration(minutes: 11));

  setUp(() {
    dir = Directory.systemTemp.createTempSync('scheduler_zombie_test');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  /// Plants the incident: a job claimed and marked running against a worker
  /// execution that has been stuck in `agentExecuting` since [startedAt], with
  /// no terminal outcome ever recorded.
  Future<FileRestartHarness> zombieHost({
    required DateTime startedAt,
    ExecutionLivenessProbe? probe,
  }) async {
    final first = FileRestartHarness(dir, clock: () => t0);
    await first.itemRunnable();
    final running = await first.plantRunningJob(t0);
    await first.workerStore.saveWorkerExecution(
      WorkerExecution(
        workerExecutionId: running.executionReference!.workerExecutionId,
        workItemId: 'wi-1',
        repositoryPath: '${dir.path}/repo',
        requestedStartingRevision: 'deadbeef',
        requiredCapabilities: running.requiredCapabilities,
        status: WorkerExecutionStatus.agentExecuting,
        cleanupPolicy: WorkerCleanupPolicy.removeAlways,
        workerId: 'w-1',
        startedAt: startedAt,
      ),
    );
    return FileRestartHarness(dir, clock: () => t1, executionLiveness: probe);
  }

  group('reconciliation reclaims a zombie execution', () {
    test(
      'no live session and an execution far past any plausible runtime: the '
      'job reaches a terminal state instead of being renewed forever',
      () async {
        // 4.78 hours, the shape of the production stall.
        final host = await zombieHost(
          startedAt: t0.subtract(const Duration(hours: 4, minutes: 47)),
        );

        final tick = await host.scheduler.tick();

        expect(tick.reconciled, hasLength(1));
        final job = (await host.jobStore.listJobs()).single;

        // TERMINAL, and not running.
        expect(
          job.isTerminal,
          isTrue,
          reason:
              'a zombie must reach a terminal '
              'job state rather than be renewed forever',
        );
        expect(job.state, JobState.failed);
        expect(job.failure, isNotNull);
        expect(job.failure!.reason, contains('zombie execution reclaimed'));

        // The reason is honest about what was and was not observable.
        expect(
          job.failure!.reason,
          contains('no live execution could be observed'),
        );

        // The lease was NOT renewed, and nothing was re-dispatched.
        expect(await host.jobStore.readClaimForJob(job.jobId), isNull);
        expect((host.dispatch as ControlledDispatcher).runs, isEmpty);
      },
    );

    test('a proven-dead execution is reclaimed even when it is young, because '
        'deadness needs no staleness window', () async {
      final host = await zombieHost(
        startedAt: t0, // only 11 minutes old
        probe: (_, _) async => ExecutionLiveness.dead,
      );

      final tick = await host.scheduler.tick();

      expect(tick.reconciled, hasLength(1));
      final job = (await host.jobStore.listJobs()).single;
      expect(job.state, JobState.failed);
      expect(job.failure!.reason, contains('nothing is running behind it'));
      expect(await host.jobStore.readClaimForJob(job.jobId), isNull);
      expect((host.dispatch as ControlledDispatcher).runs, isEmpty);
    });

    test(
      'a zombie is reclaimed on a REPEATED tick rather than surviving the first '
      'one and being renewed on the next',
      () async {
        final first = await zombieHost(
          startedAt: t0.subtract(const Duration(hours: 4, minutes: 47)),
        );

        // The first tick after the lease expires reclaims it.
        await first.scheduler.tick();
        expect(
          ((await first.jobStore.listJobs()).single).state,
          JobState.failed,
        );

        // Later ticks find nothing held, so nothing is re-dispatched and the
        // job does not drift back to running.
        final second = FileRestartHarness(
          dir,
          clock: () => t1.add(const Duration(hours: 5)),
        );
        await second.scheduler.tick();
        await second.scheduler.tick();

        final job = (await second.jobStore.listJobs()).single;
        expect(job.state, JobState.failed);
        expect((second.dispatch as ControlledDispatcher).runs, isEmpty);
      },
    );
  });

  group('reconciliation still renews a genuinely live worker', () {
    test('an execution observed alive is renewed and never duplicated, however '
        'old it is', () async {
      final host = await zombieHost(
        startedAt: t0.subtract(const Duration(hours: 4, minutes: 47)),
        probe: (_, _) async => ExecutionLiveness.alive,
      );

      final tick = await host.scheduler.tick();

      expect(tick.reconciled, hasLength(1));
      final job = (await host.jobStore.listJobs()).single;

      // NOT duplicated, NOT abandoned.
      expect(job.state, JobState.running);
      expect(job.isTerminal, isFalse);
      expect((host.dispatch as ControlledDispatcher).runs, isEmpty);

      // The lease was renewed, not dropped.
      final renewed = await host.jobStore.readClaimForJob(job.jobId);
      expect(renewed, isNotNull);
      expect(renewed!.leasedUntil, t1.add(const Duration(minutes: 10)));
    });

    test(
      'an execution whose liveness cannot be observed is still renewed inside '
      'the staleness window - failing closed is bounded, not immediate',
      () async {
        // Age at reconcile time is 11 minutes, inside the 14 minute bound.
        final host = await zombieHost(
          startedAt: t0,
          probe: (_, _) async => ExecutionLiveness.unknown,
        );

        await host.scheduler.tick();

        final job = (await host.jobStore.listJobs()).single;
        expect(job.state, JobState.running);
        expect(job.isTerminal, isFalse);
        expect(await host.jobStore.readClaimForJob(job.jobId), isNotNull);
        expect((host.dispatch as ControlledDispatcher).runs, isEmpty);
      },
    );

    test(
      'a probe that throws is treated as unknown, not as dead: an observation '
      'failure is not evidence of death',
      () async {
        final host = await zombieHost(
          startedAt: t0.subtract(const Duration(hours: 4, minutes: 47)),
          probe: (_, _) async => throw StateError('probe unreachable'),
        );

        await host.scheduler.tick();

        final job = (await host.jobStore.listJobs()).single;
        // Stale, so still reclaimed - but by the STALENESS bound, not by
        // mistaking a thrown probe for proof of death.
        expect(
          job.failure!.reason,
          contains('no live execution could be observed'),
        );
        expect(
          job.failure!.reason,
          isNot(contains('nothing is running behind it')),
        );
      },
    );

    test(
      'a young execution survives a throwing probe on the fail-open side',
      () async {
        final host = await zombieHost(
          startedAt: t0,
          probe: (_, _) async => throw StateError('probe unreachable'),
        );

        await host.scheduler.tick();

        final job = (await host.jobStore.listJobs()).single;
        expect(job.state, JobState.running);
        expect((host.dispatch as ControlledDispatcher).runs, isEmpty);
      },
    );
  });

  group('the staleness bound is derived, not guessed', () {
    test(
      'with no configured bound it scales with the agent timeout, and a live '
      'but slow execution inside it is renewed',
      () async {
        // timeoutSeconds 60 -> bound is 4*60 + 600s = 14 minutes.
        final first = FileRestartHarness(dir, clock: () => t0);
        await first.itemRunnable();
        final running = await first.plantRunningJob(t0);
        await first.workerStore.saveWorkerExecution(
          WorkerExecution(
            workerExecutionId: running.executionReference!.workerExecutionId,
            workItemId: 'wi-1',
            repositoryPath: '${dir.path}/repo',
            requestedStartingRevision: 'deadbeef',
            requiredCapabilities: running.requiredCapabilities,
            status: WorkerExecutionStatus.agentExecuting,
            cleanupPolicy: WorkerCleanupPolicy.removeAlways,
            workerId: 'w-1',
            startedAt: t0.subtract(const Duration(minutes: 2)),
          ),
        );

        final host = FileRestartHarness(dir, clock: () => t1);
        expect(
          host.scheduler.zombieStalenessBound,
          const Duration(minutes: 14),
        );

        await host.scheduler.tick();
        final job = (await host.jobStore.listJobs()).single;
        expect(job.state, JobState.running, reason: 'inside the window');
      },
    );

    test('a scheduler that cannot observe liveness says so in its startup '
        'summary instead of failing silently', () {
      final host = FileRestartHarness(dir, clock: () => t0);
      expect(host.scheduler.livenessSummary, contains('NOT observable'));
    });
  });
}
