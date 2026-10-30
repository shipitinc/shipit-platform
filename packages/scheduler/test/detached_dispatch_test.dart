import 'dart:async';
import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';

import 'support/controlled_dispatcher.dart';
import 'support/file_host.dart';
import 'support/settle.dart';

/// The F-237 regression pair.
///
/// The defect: `Scheduler._dispatchOne` awaited `_dispatch.run(request)` —
/// the TERMINAL `WorkerExecutionResult` — inside `tick()`'s dispatch loop, so
/// one agent execution held the single `TickSingleFlight` every lane shares.
/// The fix: the tick claims, marks running and STARTS the run, and the job
/// settles through the durable reconcile-adoption path once the execution is
/// terminal.
void main() {
  late Directory dir;
  final t0 = DateTime.utc(2026, 1, 1, 12);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('detached_dispatch_test');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  WorkerExecutionResult terminalResult(WorkerExecutionRequest request) {
    final t = t0;
    return WorkerExecutionResult(
      workerExecutionId: request.workerExecutionId,
      workItemId: request.workItemId,
      status: WorkerExecutionStatus.executedPass,
      workerId: 'w-scripted-1',
      workspaceId: 'ws-${request.workerExecutionId}',
      startingRevision: request.startingRevision,
      startedAt: t,
      endedAt: t,
      cleanupStatus: WorkerCleanupStatus.removed,
      failureCode: WorkerFailureCode.none,
    );
  }

  test('a job dispatched mid-tick settles via reconcile-adoption after its '
      'execution terminates, not via the tick await', () async {
    final host = FileRestartHarness(dir, clock: () => t0);
    await host.itemRunnable();
    final dispatch = host.dispatch as ControlledDispatcher;

    // Park the run so "the tick returned" and "the execution finished" are
    // provably separate events.
    final gate = Completer<WorkerExecutionResult>();
    dispatch.resultBuilder = (_) => gate.future;

    final tick = await host.scheduler.tick();

    // The tick dispatched and RETURNED while the execution was still in
    // flight — under the defect this await could never complete here.
    expect(tick.dispatched, hasLength(1));
    expect(tick.reconciled, isEmpty);
    expect(tick.terminal, isEmpty);
    final job = (await host.jobStore.listJobs()).single;
    expect(job.state, JobState.running);
    expect(job.executionReference?.workerExecutionId, 'wx-${job.jobId}');
    expect(await host.jobStore.readClaimForJob(job.jobId), isNotNull);

    // The execution terminates. The in-process continuation releases the
    // claim — observable as a durable fact, not an in-process one — and the
    // NEXT tick settles the job through `_reconcileClaim` ->
    // `_adoptFromExecution`, landing it in `reconciled` where the outcome
    // drain reads it.
    gate.complete(terminalResult(dispatch.runs.single));
    await waitUntil(
      () async => await host.jobStore.readClaimForJob(job.jobId) == null,
      because: 'the completed run to release its claim for reconcile',
    );

    final settleTick = await host.scheduler.tick();
    expect(settleTick.reconciled, [job.jobId]);

    final settled = (await host.jobStore.listJobs()).single;
    expect(settled.state, JobState.succeeded);
    expect(settled.failure, isNull);
    final events = await host.jobStore.readEvents(job.jobId);
    expect(events.map((e) => e.type), [
      SchedulerEventType.jobQueued,
      SchedulerEventType.jobClaimed,
      SchedulerEventType.jobDispatched,
      SchedulerEventType.jobCompleted,
    ]);
  });

  test('a second queued job dispatches in the SAME tick while the first '
      'execution is still running — the tick no longer serialises', () async {
    final host = FileRestartHarness(dir, clock: () => t0);
    await host.itemRunnable(workItemId: 'wi-1');
    await host.itemRunnable(workItemId: 'wi-2');
    final dispatch = host.dispatch as ControlledDispatcher;

    // Park every accepted run: nothing can reach a terminal state inside the
    // tick, so any further dispatch the same tick makes is made while the
    // first execution is provably still in flight.
    final parked = <Completer<WorkerExecutionResult>>[];
    dispatch.resultBuilder = (request) {
      final gate = Completer<WorkerExecutionResult>();
      parked.add(gate);
      return gate.future;
    };

    final tick = await host.scheduler.tick();

    expect(
      tick.dispatched,
      hasLength(2),
      reason:
          'under the defect the second job could not start until the first '
          'execution was terminal — the tick await serialised every lane',
    );
    expect(dispatch.runs, hasLength(2));
    expect(dispatch.hasRunInFlight, isTrue);
    final jobs = await host.jobStore.listJobs();
    expect(jobs.where((j) => j.state == JobState.running), hasLength(2));

    // And both still settle through the ordinary durable path.
    for (final gate in parked) {
      gate.complete(terminalResult(dispatch.runs[parked.indexOf(gate)]));
    }
    await host.settle();
    final settled = await host.jobStore.listJobs();
    expect(
      settled.map((j) => j.state).toSet(),
      {JobState.succeeded},
      reason: 'every detached run converges through reconcile-adoption',
    );
  });
}
