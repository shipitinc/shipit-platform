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
    temp = Directory.systemTemp.createTempSync('scheduler_cancel_test');
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

  test(
    'a queued job is cancelled durably without any execution starting',
    () async {
      await host.itemRunnable();
      final enqueued = await host.scheduler.queue.enqueueIfAbsent(
        workItemId: 'wi-1',
        definition: defaultImplementFeatureDefinition,
        dedupeKey: 'wi-1:design_not_required:implement_feature:IMPLEMENTER',
        instruction: 'Implement the feature.',
      );

      final job = await host.scheduler.cancelJob(
        enqueued.job.jobId,
        'product owner cancelled',
      );

      expect(job.state, JobState.cancelled);
      expect(job.cancelReason, 'product owner cancelled');
      expect(await host.workerStore.listWorkerExecutions(), hasLength(0));
      final events = await host.jobStore.readEvents(job.jobId);
      expect(events.map((e) => e.type), [
        SchedulerEventType.jobQueued,
        SchedulerEventType.jobCancelled,
      ]);
    },
  );

  test(
    'a running job is cancelled through the worker, the execution is torn '
    'down, the worker slot is released, and the job converges to cancelled',
    () async {
      await host.itemRunnable();
      final tick = host.scheduler.tick();
      await host.session.awaitingGate;

      final running = (await host.jobStore.listJobsForWorkItem('wi-1')).single;
      expect(running.state, JobState.running);
      expect(host.worker.isAcquirable, isFalse);

      await host.scheduler.cancelJob(
        running.jobId,
        'cancelled by product decision',
      );
      await tick;

      expect(host.session.wasCancelled, isTrue);
      expect(host.worker.isAcquirable, isTrue);

      final job = (await host.jobStore.readJob(running.jobId))!;
      expect(job.state, JobState.cancelled);
      expect(job.failure!.code, JobFailureCode.cancelled);
      expect(job.failure!.kind, JobFailureKind.cancelled);

      // The worker layer recorded the cancellation as its own terminal fact:
      // a cancelled execution is never treated as workflow approval.
      final executions = await host.workerStore.listWorkerExecutions();
      expect(executions, hasLength(1));
      expect(executions.single.status, WorkerExecutionStatus.cancelled);
    },
  );
}
