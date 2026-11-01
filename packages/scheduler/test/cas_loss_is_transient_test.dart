import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'support/controlled_dispatcher.dart';
import 'support/file_host.dart';

/// F-241: six QA jobs failed `Concurrent modification of <item|execution>
/// (expected version N, actual N+1)` and settled `executionFailed`
/// PERMANENT. A compare-and-swap loss means another writer already advanced
/// the durable row — transient by nature — so the job must retry, not fail
/// terminally. Under F-237 detached dispatch the detached continuation, the
/// tick and the reconcile pass write the same entities concurrently, which
/// is where the races came from.
///
/// The worker side marks such a detail with [storeContentionMarker] (the
/// exception type cannot cross the package boundary); `RetryPolicy.classify`
/// is the scheduler half and is what this file pins: the marked outcome must
/// classify `transient`/`executionInterrupted` and land the job in
/// `retryWaiting`, while an UNMARKED `executedFail` must stay `permanent` —
/// the classification of a genuine coding-result failure is not up for
/// trade.
void main() {
  late Directory dir;
  final t0 = DateTime.utc(2026, 1, 1, 12);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cas_loss_is_transient_');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  WorkerExecutionResult casLossResult(
    WorkerExecutionRequest request, {
    required String detail,
  }) => WorkerExecutionResult(
    workerExecutionId: request.workerExecutionId,
    workItemId: request.workItemId,
    status: WorkerExecutionStatus.executedFail,
    workerId: 'w-scripted-1',
    workspaceId: 'ws-${request.workerExecutionId}',
    startingRevision: request.startingRevision,
    startedAt: t0,
    endedAt: t0,
    cleanupStatus: WorkerCleanupStatus.removed,
    failureCode: WorkerFailureCode.agentFailed,
    failureDetail: detail,
  );

  group('RetryPolicy.classify', () {
    test('a marked store-contention detail classifies transient', () {
      const policy = RetryPolicy();
      final failure = policy.classify(
        WorkerExecutionStatus.executedFail,
        '$storeContentionMarker Concurrent modification of wi-1 '
        '(expected version 3, actual 4)',
      );

      expect(failure, isNotNull);
      expect(failure!.kind, JobFailureKind.transient);
      expect(failure.code, JobFailureCode.executionInterrupted);
    });

    test('an unmarked executedFail still classifies permanent', () {
      const policy = RetryPolicy();
      final failure = policy.classify(
        WorkerExecutionStatus.executedFail,
        'agent session failed',
      );

      expect(failure, isNotNull);
      expect(failure!.kind, JobFailureKind.permanent);
      expect(failure.code, JobFailureCode.executionFailed);
    });
  });

  group('a job whose settle hit a CAS loss is requeued, not failed', () {
    test(
      'executedFail carrying the contention marker lands retryWaiting',
      () async {
        var now = t0;
        final host = FileRestartHarness(dir, clock: () => now);
        (host.dispatch as ControlledDispatcher).resultBuilder = (request) =>
            casLossResult(
              request,
              detail:
                  '$storeContentionMarker Concurrent modification of wi-1 '
                  '(expected version 3, actual 4)',
            );
        await host.itemRunnable();

        await host.scheduler.tick();
        await host.settle();

        final job = (await host.jobStore.listJobs()).single;
        expect(
          job.state,
          JobState.retryWaiting,
          reason:
              'a lost compare-and-swap is an infrastructure race, not a '
              'coding result — the job is owed a bounded retry. `failed` '
              'here is the exact F-241 defect.',
        );
        expect(job.attempt, 2);
        expect(job.failure!.kind, JobFailureKind.transient);
        expect(job.failure!.code, JobFailureCode.executionInterrupted);
        final events = await host.jobStore.readEvents(job.jobId);
        expect(events.last.type, SchedulerEventType.jobRetryScheduled);
      },
    );

    test('the retry it earns is real: it redispatches and can settle '
        'successfully', () async {
      var now = t0;
      final first = FileRestartHarness(dir, clock: () => now);
      final dispatch = first.dispatch as ControlledDispatcher;
      var runs = 0;
      dispatch.resultBuilder = (request) {
        runs++;
        if (runs == 1) {
          return casLossResult(
            request,
            detail:
                '$storeContentionMarker Concurrent modification of '
                'execution agx-wx-1 (expected version 2, actual 3)',
          );
        }
        return WorkerExecutionResult(
          workerExecutionId: request.workerExecutionId,
          workItemId: request.workItemId,
          status: WorkerExecutionStatus.executedPass,
          workerId: 'w-scripted-1',
          workspaceId: 'ws-${request.workerExecutionId}',
          startingRevision: request.startingRevision,
          startedAt: t0,
          endedAt: t0,
          cleanupStatus: WorkerCleanupStatus.removed,
          failureCode: WorkerFailureCode.none,
        );
      };
      await first.itemRunnable();
      await first.scheduler.tick();
      await first.settle();

      var job = (await first.jobStore.listJobs()).single;
      expect(job.state, JobState.retryWaiting);

      now = t0.add(const Duration(minutes: 2));
      final resumed = FileRestartHarness(
        dir,
        clock: () => now,
        dispatch: dispatch,
      );
      await resumed.scheduler.tick();
      await resumed.settle();

      job = (await resumed.jobStore.listJobs()).single;
      expect(job.state, JobState.succeeded);
      expect(runs, 2);
    });

    test(
      'an unmarked executedFail for the same shape stays terminal',
      () async {
        final host = FileRestartHarness(dir, clock: () => t0);
        (host.dispatch as ControlledDispatcher).resultBuilder = (request) =>
            casLossResult(request, detail: 'agent session failed');
        await host.itemRunnable();

        await host.scheduler.tick();
        await host.settle();

        final job = (await host.jobStore.listJobs()).single;
        expect(job.state, JobState.failed);
        expect(job.attempt, 1);
        expect(job.failure!.kind, JobFailureKind.permanent);
        expect(job.failure!.code, JobFailureCode.executionFailed);
      },
    );
  });
}
