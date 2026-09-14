import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

import 'support/controlled_dispatcher.dart';
import 'support/file_host.dart';

void main() {
  late Directory dir;
  final t0 = DateTime.utc(2026, 1, 1, 12);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('scheduler_retry_test');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('a transient infrastructure failure retries (bounded) and the retry '
      'passes through retryWaiting to succeed; the coding result failure is '
      'permanent and never auto-retried', () async {
    var now = t0;
    final dispatch = ControlledDispatcher()
      ..statusSeries = () => const [
        WorkerExecutionStatus.timedOut,
        WorkerExecutionStatus.executedPass,
      ];
    final first = FileRestartHarness(dir, clock: () => now, dispatch: dispatch);

    await first.itemRunnable();
    await first.scheduler.tick();

    var job = (await first.jobStore.listJobs()).single;
    expect(job.state, JobState.retryWaiting);
    expect(job.attempt, 2); // incrementing toward the bound
    expect(job.failure!.code, JobFailureCode.executionInterrupted);
    expect(job.failure!.kind, JobFailureKind.transient);
    expect(dispatch.runs, hasLength(1));
    final retryEvents = await first.jobStore.readEvents(job.jobId);
    expect(retryEvents.last.type, SchedulerEventType.jobRetryScheduled);

    // Before availableAt, still parked.
    now = t0.add(const Duration(seconds: 30));
    final midways = FileRestartHarness(
      dir,
      clock: () => now,
      dispatch: dispatch,
    );
    await midways.scheduler.tick();
    expect(
      (await midways.jobStore.listJobs()).single.state,
      JobState.retryWaiting,
    );

    // After the backoff window a fresh process promotes and retries.
    now = t0.add(const Duration(minutes: 2));
    final resumed = FileRestartHarness(
      dir,
      clock: () => now,
      dispatch: dispatch,
    );
    await resumed.scheduler.tick();

    job = (await resumed.jobStore.listJobs()).single;
    expect(job.state, JobState.succeeded);
    expect(dispatch.runs, hasLength(2));
  });

  test('a failed coding result is permanent: no retry happens at all and the '
      'job finishes failed', () async {
    final host = FileRestartHarness(dir, clock: () => t0);
    (host.dispatch as ControlledDispatcher).statusSeries = () => const [
      WorkerExecutionStatus.executedFail,
    ];
    await host.itemRunnable();

    await host.scheduler.tick();

    final job = (await host.jobStore.listJobs()).single;
    expect(job.state, JobState.failed);
    expect(job.attempt, 1);
    expect(job.failure!.code, JobFailureCode.executionFailed);
    expect(job.failure!.kind, JobFailureKind.permanent);
    expect((host.dispatch as ControlledDispatcher).runs, hasLength(1));
    final events = await host.jobStore.readEvents(job.jobId);
    expect(events.last.type, SchedulerEventType.jobFailed);
  });

  test('prepare failures are permanent workspace-class failures, never '
      'auto-retried', () async {
    final host = FileRestartHarness(dir, clock: () => t0);
    (host.dispatch as ControlledDispatcher).statusSeries = () => const [
      WorkerExecutionStatus.prepareFailed,
    ];
    await host.itemRunnable();

    await host.scheduler.tick();

    final job = (await host.jobStore.listJobs()).single;
    expect(job.state, JobState.failed);
    expect(job.failure!.code, JobFailureCode.workspacePrepareFailed);
    expect(job.failure!.kind, JobFailureKind.permanent);
  });
}
