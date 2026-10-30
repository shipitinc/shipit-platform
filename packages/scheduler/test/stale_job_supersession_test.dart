import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';

import 'support/git_repo_fixture.dart';
import 'support/scheduler_host.dart';

/// A queued job whose work item has left its [JobDefinition]'s entry states.
///
/// Before this suite the scheduler simply skipped such a job forever: it stayed
/// `queued`, was never dispatched, was never retired, and kept its dedupe key
/// consumed with nothing able to explain it. The dispatch pass re-checked
/// legality at claim time and `continue`d past it — a correct guard that, being
/// the only thing acting on the condition, also made it permanent.
void main() {
  late Directory temp;
  late GitRepoFixture repo;
  late SchedulerHost host;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('stale_job_supersession_test');
    repo = GitRepoFixture.create('${temp.path}/repo');
    host = SchedulerHost(
      repo: repo,
      workspaceRoot: '${temp.path}/workspaces',
      jobStore: InMemoryJobStore(),
    );
  });

  tearDown(() {
    repo.dispose();
    temp.deleteSync(recursive: true);
  });

  /// Enqueues directly rather than via `tick`, so the job is left `queued` and
  /// is genuinely never dispatched — the state a superseded job is found in.
  Future<Job> queueOne() async {
    final enqueued = await host.scheduler.queue.enqueueIfAbsent(
      workItemId: 'wi-1',
      definition: defaultImplementFeatureDefinition,
      dedupeKey: 'wi-1:design_not_required:implement_feature:IMPLEMENTER',
      instruction: 'Implement the feature.',
    );
    return enqueued.job;
  }

  Future<void> moveItemTo(WorkItemState state) async {
    await host.workflowEngine.transition(
      workItemId: 'wi-1',
      to: state,
      trigger: TransitionTrigger.systemEvent,
      // The same context the coordinator supplies on an execution entry edge.
      context: const {'agentAvailable': true, 'capabilitiesMatch': true},
    );
  }

  test(
    'a queued job whose item left the entry states is retired in the same '
    'tick, with a durable readable reason and no execution ever starting',
    () async {
      await host.itemRunnable();
      final job = await queueOne();
      expect(job.state, JobState.queued);

      // The item moves on while the job is still queued — the operator, the
      // gate, or a repair. `agentExecuting` is not an entry state for this
      // definition, so the job is superseded.
      await moveItemTo(WorkItemState.agentExecuting);

      final tick = await host.scheduler.tick();

      expect(
        tick.cancelledQueued,
        [job.jobId],
        reason:
            'a superseded job must be retired by the tick that observes it, '
            'not left queued for a tick that never comes',
      );
      expect(tick.dispatched, isEmpty);

      final retired = (await host.jobStore.readJob(job.jobId))!;
      expect(retired.state, JobState.cancelled);
      expect(retired.cancelReason, contains('superseded'));
      // The reason must say WHICH state superseded it, or it is not readable by
      // whoever finds the row later.
      expect(retired.cancelReason, contains('agent_executing'));
      expect(retired.cancelReason, contains('implement_feature'));

      // The audit trail carries it too, not just the row.
      final events = await host.jobStore.readEvents(job.jobId);
      expect(
        events.map((e) => e.type),
        contains(SchedulerEventType.jobCancelled),
      );

      // Nothing ran: retiring a job must not have started an execution.
      expect(await host.workerStore.listWorkerExecutions(), isEmpty);
    },
  );

  test(
    'a retry-waiting job is retired too, not left in back-off limbo',
    () async {
      await host.itemRunnable();
      final job = await queueOne();

      // Drive it into `retryWaiting`: an in-flight attempt recorded, waiting out
      // a back-off window it will never need, because its item moved on.
      await host.scheduler.queue.scheduleRetry(
        job: job,
        failure: JobFailure(
          code: JobFailureCode.executionInterrupted,
          kind: JobFailureKind.transient,
          reason: 'transport reset',
        ),
        now: DateTime.now().toUtc(),
      );
      expect(
        (await host.jobStore.readJob(job.jobId))!.state,
        JobState.retryWaiting,
      );

      await moveItemTo(WorkItemState.agentExecuting);
      final tick = await host.scheduler.tick();

      expect(tick.cancelledQueued, [job.jobId]);
      expect(
        (await host.jobStore.readJob(job.jobId))!.state,
        JobState.cancelled,
      );
    },
  );

  test(
    'a BLOCKED item keeps its queued job: a pending human gate is a pause the '
    'work comes back from, not a supersession',
    () async {
      // `host.itemBlocked` parks the item at `waitingForHumanDecision`.
      await host.itemBlocked(workItemId: 'wi-1');
      final job = await queueOne();

      final tick = await host.scheduler.tick();

      expect(
        tick.cancelledQueued,
        isEmpty,
        reason:
            'cancelling here would destroy legitimate queued work: the item '
            'is expected to resolve back into an entry state',
      );
      final kept = (await host.jobStore.readJob(job.jobId))!;
      expect(kept.state, JobState.queued);
      expect(kept.cancelReason, isNull);
      expect(tick.dispatched, isEmpty);
    },
  );

  test(
    'a retired job yields its dedupe key, so an item that legitimately returns '
    'to an entry state is enqueued a FRESH job — never a duplicate',
    () async {
      await host.itemRunnable();
      final superseded = await queueOne();

      await moveItemTo(WorkItemState.agentExecuting);
      expect((await host.scheduler.tick()).cancelledQueued, [superseded.jobId]);

      // The operator sends it back for rework: agentExecuting -> agentFailed
      // -> designNotRequired, which IS an entry state again. The platform is
      // genuinely due another run, and the retired job must not answer for it.
      await moveItemTo(WorkItemState.agentFailed);
      await moveItemTo(WorkItemState.designNotRequired);

      // The re-enqueued job really is dispatched, so release the worker's gate
      // before awaiting the tick or it would park there forever.
      host.session.release();
      final tick = await host.scheduler.tick();
      // Detached dispatch (F-237): the fresh run settles through
      // reconcile-adoption on the tick after its claim is released.
      await host.settle();
      expect(tick.enqueued, hasLength(1));
      expect(
        tick.enqueued.single,
        isNot(superseded.jobId),
        reason: 'the retired job is not re-adopted; a new one is minted',
      );

      final all = await host.jobStore.listJobs();
      expect(
        all,
        hasLength(2),
        reason: 'one retired, one fresh — never two live',
      );
      expect(all.first.state, JobState.cancelled);
      expect(
        all.last.state,
        JobState.succeeded,
        reason: 'the fresh job is a real run, not a resurrected stale row',
      );
      // The superseded row stays readable and untouched by the re-run.
      expect(
        (await host.jobStore.readJob(superseded.jobId))!.cancelReason,
        contains('superseded'),
      );
    },
  );

  test(
    'a FAILED job keeps holding its dedupe key: it consumed an attempt, and '
    're-enqueueing against it would be an unbounded automatic re-run',
    () async {
      await host.itemRunnable();
      final job = await queueOne();

      // The run is attempted and genuinely fails. The work item is STILL in an
      // entry state, so the scheduler wants work — but this key records an
      // attempt, and a failed coding result routes through the correction gate,
      // never through an automatic LLM retry loop.
      await host.scheduler.queue.complete(
        job: job,
        terminal: JobState.failed,
        failure: JobFailure(
          code: JobFailureCode.executionFailed,
          kind: JobFailureKind.permanent,
          reason: 'the agent produced a refuted result',
        ),
      );

      for (var i = 0; i < 3; i++) {
        final tick = await host.scheduler.tick();
        expect(
          tick.enqueued,
          isEmpty,
          reason:
              'tick $i must not mint a second job against a recorded attempt',
        );
        expect(tick.cancelledQueued, isEmpty);
      }
      expect(await host.jobStore.listJobs(), hasLength(1));
    },
  );

  test(
    'retirement does not touch a job that is already running: that one is still '
    'landing a result and must converge through adoption',
    () async {
      await host.itemRunnable();
      final tick = host.scheduler.tick();
      await host.session.awaitingGate;

      // The dispatch moved the item to `agentExecuting`, which is NOT an entry
      // state for this definition — so this job IS superseded, and it is
      // `running`, and it still owns a live execution.
      final running = (await host.jobStore.listJobsForWorkItem('wi-1')).single;
      expect(running.state, JobState.running);
      expect(
        (await host.workflowStore.readWorkItem('wi-1')).state,
        WorkItemState.agentExecuting,
      );

      final retired = (await host.scheduler.tick()).cancelledQueued;

      expect(retired, isEmpty, reason: 'a running job owns a live execution');
      expect(
        (await host.jobStore.readJob(running.jobId))!.state,
        JobState.running,
      );

      host.session.release();
      await tick;
    },
  );
}
