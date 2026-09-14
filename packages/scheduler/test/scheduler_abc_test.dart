import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';

import 'support/git_repo_fixture.dart';
import 'support/scheduler_host.dart';

void main() {
  late Directory temp;
  late GitRepoFixture repo;
  late SchedulerHost host;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('scheduler_abc_test');
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

  test('blocked item consumes zero capacity while runnable items execute one '
      'at a time on the single worker', () async {
    final a = await host.itemBlocked(workItemId: 'wi-a');
    final b = await host.itemRunnable(workItemId: 'wi-b');
    final c = await host.itemRunnable(workItemId: 'wi-c');
    expect(a.state, WorkItemState.waitingForHumanDecision);
    expect(b.state, WorkItemState.designNotRequired);
    expect(c.state, WorkItemState.designNotRequired);

    final tick = host.scheduler.tick();
    await host.session.awaitingGate;

    // A is durably blocked: NO job at all, no capacity reserved, no poll.
    final jobsA = await host.jobStore.listJobsForWorkItem('wi-a');
    expect(jobsA, isEmpty);

    // Exactly ONE runnable job is in flight on the only worker slot while the
    // other runnable job parks in the queue. (Which of the two runs first is
    // decided by the deterministic priority/createdAt/jobId order; the
    // invariant below is order-independent and proves capacity-1
    // serialization.)
    final allJobs = await host.jobStore.listJobs();
    expect(allJobs.where((j) => j.state == JobState.running), hasLength(1));
    expect(allJobs.where((j) => j.state == JobState.queued), hasLength(1));
    final running = allJobs.firstWhere((j) => j.state == JobState.running);
    expect(running.workerId, 'w-linux-1');
    expect(running.executionReference, isNotNull);
    expect(host.worker.isAcquirable, isFalse);

    host.session.release();
    await tick;

    // Both runnable jobs converged; the worker slot was released each time.
    final jobB = (await host.jobStore.listJobsForWorkItem('wi-b')).single;
    final jobC = (await host.jobStore.listJobsForWorkItem('wi-c')).single;
    expect(jobB.state, JobState.succeeded);
    expect(jobB.failure, isNull);
    expect(jobC.state, JobState.succeeded);
    expect(jobC.failure, isNull);
    expect(host.worker.isAcquirable, isTrue);
    expect(await host.workerStore.listWorkerExecutions(), hasLength(2));

    // Full audit trail: queued -> claimed -> dispatched -> completed, once per
    // runnable job, and A never emitted anything.
    for (final job in [jobB, jobC]) {
      final events = await host.jobStore.readEvents(job.jobId);
      expect(events.map((e) => e.type), [
        SchedulerEventType.jobQueued,
        SchedulerEventType.jobClaimed,
        SchedulerEventType.jobDispatched,
        SchedulerEventType.jobCompleted,
      ]);
    }
  });

  test('a duplicate tick never re-enqueues and never re-executes', () async {
    await host.itemRunnable(workItemId: 'wi-b');
    await host.itemRunnable(workItemId: 'wi-c');

    final firstTick = host.scheduler.tick();
    await host.session.awaitingGate;
    host.session.release();
    await firstTick;
    final jobIds = (await host.jobStore.listJobs()).map((j) => j.jobId).toList()
      ..sort();
    expect(await host.workerStore.listWorkerExecutions(), hasLength(2));

    final secondTick = await host.scheduler.tick();
    expect(secondTick.enqueued, isEmpty);
    expect(secondTick.dispatched, isEmpty);

    final after = (await host.jobStore.listJobs()).map((j) => j.jobId).toList()
      ..sort();
    expect(after, jobIds);
    expect(await host.workerStore.listWorkerExecutions(), hasLength(2));
    for (final job in await host.jobStore.listJobs()) {
      final events = await host.jobStore.readEvents(job.jobId);
      // No duplicate jobQueued, no retry-loop: one clean lifecycle per job.
      expect(
        events.where((e) => e.type == SchedulerEventType.jobQueued),
        hasLength(1),
      );
      expect(
        events.where((e) => e.type == SchedulerEventType.jobDispatched),
        hasLength(1),
      );
      expect(events.last.type, SchedulerEventType.jobCompleted);
    }
  });
}
