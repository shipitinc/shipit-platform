import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';

import 'support/git_repo_fixture.dart';
import 'support/scheduler_host.dart';

/// End-to-end proof that a supersession survives the crossing and is acted on.
///
/// Everything below the scheduler is REAL here: the real `ExecutionCoordinator`
/// raises the real `WorkItemSupersededException`, the real `LocalWorker` catches
/// it as a plain `Object` and flattens it into a generic `executedFail` /
/// `agentFailed` detail, and the real scheduler adopts it. That flattening is
/// the reason this suite exists at all — the classifier reaches the scheduler
/// ONLY as a string, so the thing worth testing is that the string survives
/// and is still recognised after every layer it passes through.
///
/// The scripted-dispatcher suite (`supersession_requeue_test.dart`) covers the
/// (a)/(b) judgement exhaustively. It cannot prove the crossing, because it
/// injects the failure detail directly and so assumes the very thing at risk.
///
/// ## How the supersession is staged now that no definition mis-declares a
/// route
///
/// It used to be staged with a definition whose entry state had no path to
/// execution — a contradiction this platform no longer allows itself to
/// express, and one `EntryHopper` now refuses to dispatch into rather than
/// reproducing (see `entry_hop_drift_guard_test.dart`). What is left, and is
/// what production actually has, is the RACE: `LocalWorker` prepares the
/// workspace at local_worker.dart:152 and only calls the coordinator at :186, so
/// a work item can legitimately move underneath a job that was already claimed
/// and dispatched. The hook this suite installs runs in exactly that window and
/// lets the OPERATOR move the item — a cancellation, which any non-terminal
/// state may take — so the coordinator's refusal is real, deterministic, and
/// caused by nothing but the move.
void main() {
  late Directory temp;
  late GitRepoFixture repo;
  late SchedulerHost host;

  /// The operator's move, run inside the worker's real prepare window.
  late Future<void> Function() moveTheItemUnderTheJob;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('supersession_e2e_test');
    repo = GitRepoFixture.create('${temp.path}/repo');
    host = SchedulerHost(
      repo: repo,
      workspaceRoot: '${temp.path}/workspaces',
      jobStore: InMemoryJobStore(),
      definition: triageDefectDefinition,
      workerCapabilities: const {WorkerCapability.linux, WorkerCapability.git},
      onWorkspacePrepared: (workItemId) => moveTheItemUnderTheJob(),
    );
  });

  tearDown(() {
    repo.dispose();
    temp.deleteSync(recursive: true);
  });

  /// Parks the item at `designNotRequired`, where a triage job is dispatched
  /// from, and arranges for the operator to cancel it mid-prepare.
  Future<void> itemCancelledMidPrepare() async {
    await host.itemRunnable();
    moveTheItemUnderTheJob = () async {
      await host.workflowEngine.transition(
        workItemId: 'wi-1',
        to: WorkItemState.cancelled,
        trigger: TransitionTrigger.systemEvent,
      );
    };
  }

  test('a superseded execution is CANCELLED as superseded, consumes no '
      'attempt, and moved no work item of its own', () async {
    await itemCancelledMidPrepare();
    // The coordinator will refuse this dispatch, so no agent is started and
    // releasing the gate up front keeps the tick from parking on it.
    host.session.release();

    final tick = await host.scheduler.tick();

    expect(tick.enqueued, hasLength(1), reason: 'the item is probeable');
    final job = (await host.jobStore.listJobs()).single;
    expect(tick.dispatched, [job.jobId]);

    // The verdict. The item left every entry state this definition serves, so
    // this is branch (b): the job is not wanted any more.
    final retired = (await host.jobStore.readJob(job.jobId))!;
    expect(retired.state, JobState.cancelled);
    expect(retired.failure, isNull);
    expect(retired.attempt, 1, reason: 'no execution started, so no budget');
    expect(retired.maxAttempts, triageDefectDefinition.maxAttempts);

    // The reason is readable and is about the MOVE, not about an agent.
    final events = await host.jobStore.readEvents(job.jobId);
    expect(
      events.map((e) => e.type),
      contains(SchedulerEventType.jobCancelled),
    );
    final reason = (await host.jobStore.readJob(job.jobId))!.cancelReason!;
    expect(reason, contains('superseded'));
    expect(reason, contains('cancelled'));
    expect(
      events.map((e) => e.type),
      isNot(contains(SchedulerEventType.jobFailed)),
      reason: 'nothing about this run says the agent failed',
    );
  });

  test(
    'nothing ran: the worker execution record shows the supersession and '
    'there is no agent execution row, no session, and no live session',
    () async {
      await itemCancelledMidPrepare();
      host.session.release();
      await host.scheduler.tick();
      final job = (await host.jobStore.listJobs()).single;

      // The worker row is durable evidence that the marker really crossed.
      final execution = await host.workerStore.readWorkerExecution(
        'wx-${job.jobId}',
      );
      expect(execution!.status, WorkerExecutionStatus.executedFail);
      expect(
        execution.reason,
        startsWith(supersededExecutionMarker),
        reason:
            'this is the string the coordinator threw, flattened by the worker. '
            'If it stopped matching here, the scheduler would be back to failing '
            'these terminally and nothing would say so',
      );
      expect(execution.reason, contains('cancelled'));
      expect(
        execution.agentExecutionId,
        isNotNull,
        reason:
            'the worker mints this id BEFORE it calls the coordinator, so '
            'its presence proves nothing and must not be read as a run',
      );

      // And the thing that actually ran: nothing.
      expect(
        await host.executionStore.readExecutionOrNull('agx-wx-${job.jobId}'),
        isNull,
        reason:
            'no execution row — the refusal happened before one was written',
      );
      expect(
        await host.executionStore.readEvents('agx-wx-${job.jobId}'),
        isEmpty,
      );
      expect(host.coordinator.liveSessionCount, 0);
      expect(host.session.wasStarted, isFalse);
      expect(
        (await host.workflowStore.readWorkItem('wi-1')).state,
        WorkItemState.cancelled,
        reason:
            'the scheduler never moved this item — it belongs to whoever moved '
            'it, which here is the operator who cancelled the work',
      );
    },
  );

  test(
    'and the real git worktree this dispatch burned is still cleaned up',
    () async {
      await itemCancelledMidPrepare();
      host.session.release();
      await host.scheduler.tick();
      final job = (await host.jobStore.listJobs()).single;

      final execution = await host.workerStore.readWorkerExecution(
        'wx-${job.jobId}',
      );
      expect(
        execution!.cleanupStatus,
        WorkerCleanupStatus.removed,
        reason:
            'the worktree was really prepared before the coordinator refused, so '
            'this is the path that leaks a workspace per refused attempt',
      );
      expect(
        Directory('${temp.path}/workspaces').listSync().whereType<Directory>(),
        isEmpty,
        reason: 'and nothing is left on disk behind it',
      );
    },
  );

  test('a later tick does NOT dispatch it again: the item moved, so the job is '
      'not wanted and nothing re-arms it', () async {
    await itemCancelledMidPrepare();
    host.session.release();
    await host.scheduler.tick();
    final job = (await host.jobStore.listJobs()).single;

    final second = await host.scheduler.tick();
    expect(second.enqueued, isEmpty);
    expect(second.dispatched, isEmpty);
    expect(await host.jobStore.listJobs(), hasLength(1));
    expect((await host.jobStore.readJob(job.jobId))!.state, JobState.cancelled);
  });
}
