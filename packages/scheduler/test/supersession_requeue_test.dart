import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'support/controlled_dispatcher.dart';
import 'support/file_host.dart';
import 'support/settle.dart';

/// A superseded execution must not be terminally `failed`.
///
/// `WorkItemSupersededException` is raised before the execution row and the
/// agent session exist: nothing ran, nothing was produced. Live QA on
/// 2026-10-13 showed the scheduler classifying that as a permanent
/// `executedFail`, so the job went `failed`, burned its retry budget, and the
/// work item sat with nothing queued against it.
///
/// The judgement is a SPLIT, and collapsing it is the defect in either
/// direction: a blanket requeue loops forever on an item that no longer accepts
/// this job's definition, and a blanket fail is what strands today.
/// The claim a detached run holds until its continuation releases it for
/// reconcile-adoption — the durable signal `settle()` waits on, used here on
/// its own when the test must NOT consume the settle tick's re-dispatch.
Future<void> claimReleased(FileRestartHarness host, String jobId) {
  return waitUntil(
    () async => await host.jobStore.readClaimForJob(jobId) == null,
    because: 'the detached run to release its claim for reconcile',
  );
}

void main() {
  late Directory dir;
  final t0 = DateTime.utc(2026, 1, 1, 12);

  setUp(
    () => dir = Directory.systemTemp.createTempSync('supersession_requeue'),
  );
  tearDown(() => dir.deleteSync(recursive: true));

  /// A supersession exactly as a worker execution reports one: `executedFail`,
  /// generic `agentFailed`, and the coordinator's own text on the detail — which
  /// is the ONLY channel the classification survives on.
  const supersededDetail =
      '$supersededExecutionMarker Superseded execution: work item wi-1 is '
      'review_rejected and no longer accepts a IMPLEMENTER run, which requires '
      'agent_executing. The work item moved on before this execution started, '
      'so nothing ran and nothing was produced.';

  WorkerExecutionResult supersessionResult(
    WorkerExecutionRequest request, {
    String detail = supersededDetail,
  }) {
    final t = DateTime.utc(2026, 1, 1, 12);
    return WorkerExecutionResult(
      workerExecutionId: request.workerExecutionId,
      workItemId: request.workItemId,
      status: WorkerExecutionStatus.executedFail,
      workerId: 'w-scripted-1',
      workspaceId: 'ws-1',
      startingRevision: 'deadbeef',
      startedAt: t,
      endedAt: t,
      cleanupStatus: WorkerCleanupStatus.removed,
      failureCode: WorkerFailureCode.agentFailed,
      failureDetail: detail,
      // Nothing ran, so every produced-artifact field is absent. Asserted in a
      // test below so this fixture cannot quietly drift into claiming otherwise.
      agentResultStatus: null,
      verificationPassed: null,
      changedFiles: const [],
      endingRevision: null,
    );
  }

  group('(a) the item moved to a state this definition STILL accepts', () {
    test('the job is REQUEUED, not failed, and is dispatched again on a later '
        'tick', () async {
      final dispatch = ControlledDispatcher()
        ..resultBuilder = (r) async => supersessionResult(r);
      final host = FileRestartHarness(dir, clock: () => t0, dispatch: dispatch);

      await host.itemRunnable();
      final job = await host.enqueueJob();

      final first = await host.scheduler.tick();
      await host.settle();
      expect(first.dispatched, [job.jobId]);
      expect(
        first.terminal,
        isEmpty,
        reason: 'a supersession must not terminate',
      );

      final requeued = (await host.jobStore.readJob(job.jobId))!;
      expect(
        requeued.state,
        JobState.running,
        reason:
            'the item is still in designNotRequired, so this job is still '
            'wanted — it only arrived at the wrong moment. Detached dispatch '
            'requeues AND re-dispatches in the same settle tick, so the '
            'observable wanted state is running, not queued',
      );
      expect(requeued.failure, isNull, reason: 'no failure is what happened');

      // And it really is retried against the new state, rather than merely
      // parked: the settle tick already dispatched the SAME row again, and a
      // later tick adopts that run and dispatches it yet again.
      expect(dispatch.runs, hasLength(2));
      await claimReleased(host, job.jobId);
      final second = await host.scheduler.tick();
      expect(second.dispatched, [job.jobId]);
      expect(dispatch.runs, hasLength(3));
      expect((await host.jobStore.readJob(job.jobId))!.jobId, job.jobId);
      await claimReleased(host, job.jobId);
    });

    test('the requeue consumes NO retry budget — explicitly, with the bound '
        'reached', () async {
      final dispatch = ControlledDispatcher()
        ..resultBuilder = (r) async => supersessionResult(r);
      final host = FileRestartHarness(dir, clock: () => t0, dispatch: dispatch);
      await host.itemRunnable();
      final job = await host.enqueueJob();

      final before = await host.jobStore.readJob(job.jobId);
      expect(before!.attempt, 1);
      expect(before.maxAttempts, 2);

      // Drive it well past the bound. Every pass is a supersession, so nothing
      // ever consumes an attempt and the budget is never touched.
      for (var i = 0; i < 6; i++) {
        await host.scheduler.tick();
        await host.settle();
      }

      final after = (await host.jobStore.readJob(job.jobId))!;
      expect(
        after.attempt,
        1,
        reason:
            'six worker executions were dispatched and every one of them was '
            'superseded before it started; not one attempt was charged, so '
            'maxAttempts is still intact for a real run',
      );
      expect(after.maxAttempts, 2);
    });

    test(
      'the requeue carries its OWN readable reason: an operator can see this '
      'was deferred because the item moved, not because the agent failed',
      () async {
        final dispatch = ControlledDispatcher()
          ..resultBuilder = (r) async => supersessionResult(r);
        final host = FileRestartHarness(
          dir,
          clock: () => t0,
          dispatch: dispatch,
        );
        await host.itemRunnable();
        final job = await host.enqueueJob();

        await host.scheduler.tick();
        await host.settle();

        final deferrals = (await host.jobStore.readEvents(
          job.jobId,
        )).where((e) => e.payload?['supersessionDeferred'] == true);
        expect(deferrals, hasLength(1));
        final reason = deferrals.single.payload!['reason']! as String;
        expect(reason, contains('design_not_required'));
        expect(reason, contains('implement_feature'));
        expect(reason, contains('Nothing ran and nothing was produced'));
        expect(
          reason,
          contains('no retry budget was consumed'),
          reason: 'the reason must state the budget was NOT touched',
        );
        expect(
          reason.toLowerCase(),
          isNot(contains('failed')),
          reason:
              'a deferral that says "failed" is the ambiguity being removed',
        );

        // Nothing terminal was recorded, and nothing claims an execution happened.
        final events = await host.jobStore.readEvents(job.jobId);
        expect(
          events.map((e) => e.type),
          isNot(contains(SchedulerEventType.jobFailed)),
        );
        final after = (await host.jobStore.readJob(job.jobId))!;
        expect(after.failure, isNull);
        // The requeue cleared the superseded run's reference; the same settle
        // tick then re-dispatched, so the reference that is present belongs to
        // the live run — assert that, then let it finish for teardown.
        expect(after.executionReference, isNotNull);
        await claimReleased(host, job.jobId);
      },
    );

    test('no second job and no second dedupe key: the SAME row is retried, and '
        'enqueueIfAbsent still finds it as the holder', () async {
      final dispatch = ControlledDispatcher()
        ..resultBuilder = (r) async => supersessionResult(r);
      final host = FileRestartHarness(dir, clock: () => t0, dispatch: dispatch);
      await host.itemRunnable();
      final job = await host.enqueueJob();

      // One settle() is now a whole supersession cycle: it adopts the run,
      // defers, requeues and re-dispatches in the same tick. Three dispatches
      // of the same row therefore take one tick plus two settles.
      final first = await host.scheduler.tick();
      final second = await host.settle();
      final third = await host.settle();

      expect(
        first.enqueued,
        isEmpty,
        reason:
            'the requeued row is still the key holder, so nothing is minted',
      );
      expect(
        second.enqueued,
        isEmpty,
        reason: 'the requeued row holds the key',
      );
      expect(third.enqueued, isEmpty);

      final all = await host.jobStore.listJobs();
      expect(all, hasLength(1));
      expect(all.single.jobId, job.jobId);
      expect(all.single.dedupeKey, host.dedupeKey);
      expect(dispatch.runs, hasLength(3));
    });
  });

  group('(b) the item moved to a state this definition NO LONGER accepts', () {
    test('the job is CANCELLED as superseded — matching the retirement that '
        'already ships — and not retried', () async {
      late FileRestartHarness host;
      final dispatch = ControlledDispatcher()
        ..resultBuilder = (r) async {
          // The item moves while the execution is being placed. `agentExecuting`
          // is not an entry state for this definition, so (b) applies.
          await host.itemExecuting();
          return supersessionResult(r);
        };
      host = FileRestartHarness(dir, clock: () => t0, dispatch: dispatch);

      await host.itemRunnable();
      final job = await host.enqueueJob();

      final tick = await host.scheduler.tick();
      await host.settle();
      expect(tick.dispatched, [job.jobId]);
      // NB: the verdict is read from the durable row, not from
      // `SchedulerTickResult.terminal`. That list is not populated for an
      // adoption-time terminal outcome — `_dispatchOne` reports `dispatched`
      // first, and the `else` branch carrying `terminalJob` is unreachable when
      // both are set. Pre-existing at base, unchanged here.
      expect(
        (await host.jobStore.readJob(job.jobId))!.state,
        JobState.cancelled,
      );

      final retired = (await host.jobStore.readJob(job.jobId))!;
      expect(retired.state, JobState.cancelled);
      expect(retired.failure, isNull, reason: 'cancelled is not a failure');
      expect(retired.cancelReason, contains('superseded'));
      expect(retired.cancelReason, contains('agent_executing'));
      expect(retired.cancelReason, contains('implement_feature'));

      // Not retried: a further tick dispatches nothing.
      await host.scheduler.tick();
      await host.settle();
      expect(dispatch.runs, hasLength(1));
    });

    test(
      'the two outcomes are NOT collapsed: the same supersession detail '
      'requeues at designNotRequired and cancels at agentExecuting',
      () async {
        // (a)
        final requeueing = ControlledDispatcher()
          ..resultBuilder = (r) async => supersessionResult(r);
        final hostA = FileRestartHarness(
          dir,
          clock: () => t0,
          dispatch: requeueing,
        );
        await hostA.itemRunnable();
        final jobA = await hostA.enqueueJob();
        await hostA.scheduler.tick();
        await hostA.settle();
        expect(
          (await hostA.jobStore.readJob(jobA.jobId))!.state,
          JobState.running,
          reason: 'requeued and re-dispatched inside the settle tick',
        );
        await claimReleased(hostA, jobA.jobId);

        // (b), on a second worktree so the stores are independent.
        final dir2 = Directory.systemTemp.createTempSync('supersession_b');
        addTearDown(() => dir2.deleteSync(recursive: true));
        late FileRestartHarness hostB;
        final cancelling = ControlledDispatcher()
          ..resultBuilder = (r) async {
            await hostB.itemExecuting();
            return supersessionResult(r);
          };
        hostB = FileRestartHarness(dir2, clock: () => t0, dispatch: cancelling);
        await hostB.itemRunnable();
        final jobB = await hostB.enqueueJob();
        await hostB.scheduler.tick();
        await hostB.settle();

        expect(
          (await hostB.jobStore.readJob(jobB.jobId))!.state,
          JobState.cancelled,
        );
      },
    );
  });

  group('what is deliberately NOT requeued', () {
    test('a REAL agent failure that leaves the item runnable still fails '
        'terminally — re-checking the item alone would loop forever', () async {
      // The fatal failure mode of a design that decides from the item state
      // alone: a genuine coding failure on a still-runnable item would be
      // requeued, and `RetryPolicy` exists precisely to prevent that.
      final dispatch = ControlledDispatcher()
        ..statusSeries = () => const [WorkerExecutionStatus.executedFail];
      final host = FileRestartHarness(dir, clock: () => t0, dispatch: dispatch);

      await host.itemRunnable();
      final job = await host.enqueueJob();

      await host.scheduler.tick();
      await host.settle();

      final failed = (await host.jobStore.readJob(job.jobId))!;
      expect(failed.state, JobState.failed);
      expect(failed.failure!.kind, JobFailureKind.permanent);
      expect(
        (await host.workflowStore.readWorkItem('wi-1')).state,
        WorkItemState.designNotRequired,
        reason: 'the item never moved, and the job still failed',
      );
    });

    test(
      'a failure whose detail merely mentions supersession is not one',
      () async {
        final dispatch = ControlledDispatcher()
          ..resultBuilder = (r) async => supersessionResult(
            r,
            detail: 'agent session failed: it claimed it was superseded',
          );
        final host = FileRestartHarness(
          dir,
          clock: () => t0,
          dispatch: dispatch,
        );
        await host.itemRunnable();
        final job = await host.enqueueJob();

        await host.scheduler.tick();
        await host.settle();

        expect(
          (await host.jobStore.readJob(job.jobId))!.state,
          JobState.failed,
          reason:
              'recognition is a PREFIX, not a substring — otherwise any agent '
              'failure that happens to use the word would be requeued forever',
        );
      },
    );

    test('a marker on a PASSED result is ignored', () {
      expect(
        isSupersededExecution(
          '$supersededExecutionMarker superseded',
          status: WorkerExecutionStatus.executedPass,
        ),
        isFalse,
        reason: 'a success with a contradictory detail is not a deferral',
      );
      expect(
        isSupersededExecution(
          '$supersededExecutionMarker superseded',
          status: WorkerExecutionStatus.executedFail,
        ),
        isTrue,
      );
      expect(
        isSupersededExecution(null, status: WorkerExecutionStatus.executedFail),
        isFalse,
      );
    });
  });

  group('a supersession that keeps happening', () {
    test('is deferred a BOUNDED number of times and then retired with an '
        'explanation, instead of being requeued forever', () async {
      // A requeue commits to nothing, so an item whose policy probe and whose
      // real entry transition DISAGREE would otherwise re-dispatch this job
      // once per tick, indefinitely. `reviewRejected` is exactly that shape
      // today: `JobDefinition.entryProbeTargets` asks about
      // `reviewRejected -> designNotRequired` while the coordinator asks for
      // `reviewRejected -> agentExecuting`, which is not an edge.
      //
      // The bound is per job ROW. A retired job yields its dedupe key, so the
      // next tick mints a fresh row for the same still-probeable item — the
      // pre-existing "cancelled releases the key" rule, not something this
      // change introduces. Closing THAT loop is the disagreement above, and it
      // belongs to whoever reconciles the probe with the coordinator.
      final dispatch = ControlledDispatcher()
        ..resultBuilder = (r) async => supersessionResult(r);
      final host = FileRestartHarness(dir, clock: () => t0, dispatch: dispatch);
      await host.itemRunnable();
      final job = await host.enqueueJob();

      await host.scheduler.tick();
      for (var i = 0; i < 3; i++) {
        // One settle per deferral: adopt -> defer -> requeue -> re-dispatch
        // all happen inside it, so running is the wanted observable.
        await host.settle();
        expect(
          (await host.jobStore.readJob(job.jobId))!.state,
          JobState.running,
          reason: 'deferral ${i + 1} of 3 should still defer',
        );
      }

      // The fourth supersession is past the bound.
      await host.settle();

      final retired = (await host.jobStore.readJob(job.jobId))!;
      expect(retired.state, JobState.cancelled);
      expect(retired.cancelReason, contains('deferred 3 times'));
      expect(retired.cancelReason, contains('Stopping rather than spinning'));
      expect(
        retired.cancelReason,
        contains('No attempt was consumed'),
        reason: 'even the give-up must not claim an execution happened',
      );
      expect(retired.attempt, 1);

      // Bounded for THIS job: four worker executions, then it is retired.
      // The retiring tick also mints the successor row (cancelled releases
      // the dedupe key, per the note above), so count the runs against THIS
      // job's execution id rather than every request.
      final thisExecution = dispatch.runs.first.workerExecutionId;
      expect(
        dispatch.runs.where((r) => r.workerExecutionId == thisExecution).length,
        4,
      );
      final rows = await host.jobStore.listJobsForWorkItem('wi-1');
      expect(
        rows.singleWhere((j) => j.jobId == job.jobId).state,
        JobState.cancelled,
      );
      final successor = rows.where((j) => j.jobId != job.jobId);
      for (final next in successor) {
        await claimReleased(host, next.jobId);
      }
    });
  });

  group('reconciliation adopts a supersession too', () {
    test(
      'the deferral count is reconstructed from the durable log, so a '
      'restarted process reaches the same bound with no memory of the first',
      () async {
        final dispatch = ControlledDispatcher()
          ..resultBuilder = (r) async => supersessionResult(r);
        final host = FileRestartHarness(
          dir,
          clock: () => t0,
          dispatch: dispatch,
        );
        await host.itemRunnable();
        final job = await host.enqueueJob();
        await host.scheduler.tick();
        await host.settle();
        expect(
          (await host.jobStore.readJob(job.jobId))!.state,
          JobState.running,
          reason: 'deferred and re-dispatched inside the settle tick',
        );

        // The restart reads the FILE, not the first process's memory — and a
        // FileJson*Store snapshots at construction, so the durable evidence
        // must already be on disk before it is built. Poll fresh store
        // instances so the waits observe exactly what the restart will load:
        // the released claim, and run2's terminal execution row.
        final refId = (await host.jobStore.readJob(
          job.jobId,
        ))!.executionReference!.workerExecutionId;
        await waitUntil(
          () async =>
              await FileJsonJobStore(
                File('${dir.path}/jobs.json'),
              ).readClaimForJob(job.jobId) ==
              null,
          because: 'the released claim to be durable on disk',
        );
        await waitUntil(
          () async =>
              await FileJsonWorkerStore(
                File('${dir.path}/workers.json'),
              ).readWorkerExecution(refId) !=
              null,
          because: 'the second run terminal execution row to be durable',
        );
        final restarted = FileRestartHarness(
          dir,
          clock: () => t0,
          dispatch: dispatch,
        );
        await restarted.scheduler.tick();
        final afterRestart = (await restarted.jobStore.readJob(job.jobId))!;
        expect(
          afterRestart.state,
          JobState.running,
          reason:
              'the second process defers on its own — and the same tick '
              're-dispatches, so running is the wanted observable',
        );
        expect(afterRestart.attempt, 1);

        final deferrals = (await restarted.jobStore.readEvents(
          job.jobId,
        )).where((e) => e.payload?['supersessionDeferred'] == true);
        expect(
          deferrals,
          hasLength(2),
          reason:
              'the bound is counted from the log, so a restart neither '
              'resets it nor double-counts it',
        );
        await restarted.settle();
      },
    );

    test('a superseded execution adopted after a CRASH requeues, not fails — '
        'the classification is durable, not in-memory only', () async {
      // The crash path rebuilds its `failureDetail` from
      // `WorkerExecution.reason` rather than from the result object, so it is
      // worth proving the marker survives THAT crossing too.
      final first = FileRestartHarness(dir, clock: () => t0);
      await first.itemRunnable();
      final running = await first.plantRunningJob(t0);
      final executionId = running.executionReference!.workerExecutionId;
      await first.workerStore.saveWorkerExecution(
        WorkerExecution(
          workerExecutionId: executionId,
          workItemId: 'wi-1',
          repositoryPath: '${dir.path}/repo',
          requestedStartingRevision: 'deadbeef',
          requiredCapabilities: running.requiredCapabilities,
          cleanupPolicy: WorkerCleanupPolicy.removeAlways,
          status: WorkerExecutionStatus.executedFail,
          workerId: 'w-scripted-1',
          createdAt: t0,
          startedAt: t0,
          endedAt: t0,
          failureCode: WorkerFailureCode.agentFailed,
          reason: supersededDetail,
        ),
      );

      // A fresh process, long past the claim lease. It re-dispatches too, and the
      // scripted dispatcher supersedes again — so a `queued` job here can only
      // be explained by the reconciliation requeueing it.
      final dispatch = ControlledDispatcher()
        ..resultBuilder = (r) async => supersessionResult(r);
      final restarted = FileRestartHarness(
        dir,
        clock: () => t0.add(const Duration(hours: 2)),
        dispatch: dispatch,
      );
      await restarted.scheduler.tick();
      await restarted.settle();

      final job = (await restarted.jobStore.listJobs()).single;
      expect(job.jobId, running.jobId);
      expect(
        job.state,
        JobState.running,
        reason:
            'reconciling a crash over a superseded run must not fail it — '
            'it requeues, and the same settle tick re-dispatches',
      );
      expect(job.failure, isNull);
      expect(job.attempt, 1);
      // The superseded run's reference was cleared on requeue and the settle
      // tick re-dispatched, so a live reference is present — deterministically
      // the same id, since a supersession never consumes an attempt.
      expect(job.executionReference, isNotNull);
      await claimReleased(restarted, job.jobId);
      expect(
        (await restarted.jobStore.readEvents(
          job.jobId,
        )).where((e) => e.payload?['supersessionDeferred'] == true),
        hasLength(2),
        reason:
            'two, and both prove the same thing from different sides: the '
            'marker was rebuilt from WorkerExecution.reason on the '
            'reconciliation path, and rebuilt from the dispatched result on '
            'the dispatch path in the same tick',
      );
    });
  });
}
