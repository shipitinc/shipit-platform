import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';

import 'support/controlled_dispatcher.dart';
import 'support/file_host.dart';

void main() {
  late Directory dir;
  final t0 = DateTime.utc(2026, 1, 1, 12);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('scheduler_cas_test');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  /// Two scheduler replicas wired to the SAME durable store (the shape a
  /// control plane uses: replicas share one store, never private copies) and
  /// the same worker pool.
  ({Scheduler a, Scheduler b, FileRestartHarness shared}) twins() {
    final shared = FileRestartHarness(dir, clock: () => t0);
    final a = Scheduler(
      schedulerId: 'sched-a',
      workflowStore: shared.workflowStore,
      jobStore: shared.jobStore,
      workerStore: shared.workerStore,
      dispatch: shared.dispatch,
      definition: defaultImplementFeatureDefinition,
      workload: SchedulerWorkload(
        repositoryPath: '${dir.path}/repo',
        startingRevision: 'deadbeef',
        timeoutSeconds: 60,
        runtimeTypeId: 'fake-runtime',
      ),
      clock: () => t0,
    );
    final b = Scheduler(
      schedulerId: 'sched-b',
      workflowStore: shared.workflowStore,
      jobStore: shared.jobStore,
      workerStore: shared.workerStore,
      dispatch: shared.dispatch,
      definition: defaultImplementFeatureDefinition,
      workload: SchedulerWorkload(
        repositoryPath: '${dir.path}/repo',
        startingRevision: 'deadbeef',
        timeoutSeconds: 60,
        runtimeTypeId: 'fake-runtime',
      ),
      clock: () => t0,
    );
    return (a: a, b: b, shared: shared);
  }

  test(
    'two scheduler replicas racing the same job: only one claim CAS wins and '
    'the job is executed exactly once',
    () async {
      final tw = twins();
      await tw.shared.itemRunnable();
      // Enqueue happens once, non-concurrently; the claim CAS is the gate.
      await tw.shared.enqueueJob();

      await Future.wait([tw.a.tick(), tw.b.tick()]);

      final jobs = await tw.shared.jobStore.listJobs();
      expect(jobs, hasLength(1));
      final job = jobs.single;
      expect(job.state, JobState.succeeded);

      final runs = (tw.shared.dispatch as ControlledDispatcher).runs;
      expect(runs, hasLength(1));

      // Exactly one scheduler emitted the claim; the loser attempted the CAS
      // against a job that was no longer claimable and stayed silent.
      final events = await tw.shared.jobStore.readEvents(job.jobId);
      expect(
        events.where((e) => e.type == SchedulerEventType.jobClaimed),
        hasLength(1),
      );
      expect(
        events.where((e) => e.type == SchedulerEventType.jobDispatched),
        hasLength(1),
      );
    },
  );

  test(
    'orderEligible: priority, then availableAt, then createdAt, then id',
    () {
      Job job(
        String id, {
        JobPriority priority = JobPriority.normal,
        DateTime? availableAt,
        DateTime? createdAt,
      }) {
        return Job(
          jobId: id,
          workItemId: 'wi-1',
          jobType: JobType.implementFeature,
          requiredRole: AgentRole.implementer,
          requiredCapabilities: const {WorkerCapability.linux},
          priority: priority,
          state: JobState.queued,
          dedupeKey: 'k',
          createdAt: createdAt ?? t0,
          instruction: 'x',
          attempt: 1,
          maxAttempts: 2,
          version: 1,
        );
      }

      // Priority dominates createdAt.
      final late = JobQueue.orderEligible(
        job(
          'jb-late',
          priority: JobPriority.critical,
          createdAt: t0.add(const Duration(minutes: 5)),
        ),
        job('jb-early', priority: JobPriority.normal, createdAt: t0),
      );
      expect(late, lessThan(0));

      // availableAt breaks priority ties.
      final olderAvailable = JobQueue.orderEligible(
        job('jb-a', availableAt: t0),
        job('jb-b', availableAt: t0.add(const Duration(minutes: 1))),
      );
      expect(olderAvailable, lessThan(0));

      // createdAt breaks availableAt ties.
      final olderCreated = JobQueue.orderEligible(
        job('jb-a', createdAt: t0),
        job('jb-b', createdAt: t0.add(const Duration(minutes: 1))),
      );
      expect(olderCreated, lessThan(0));

      // Stable job id breaks every other tie.
      expect(JobQueue.orderEligible(job('jb-a'), job('jb-b')), lessThan(0));
      expect(JobQueue.orderEligible(job('jb-b'), job('jb-a')), greaterThan(0));
    },
  );

  test('the scheduler dispatches higher-priority work before lower-priority '
      'work regardless of creation order', () async {
    final shared = FileRestartHarness(dir, clock: () => t0);
    await shared.itemRunnable();
    // Second item (wi-2) so the two jobs have distinct dedupe keys; wi-1 is
    // already runnable (planning -> planned -> designNotRequired).
    await shared.workflowEngine.createWorkItem(
      workItemId: 'wi-2',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Second',
      description: 'Second work item seed for scheduler CAS tests',
      qaContractId: 'qa-2',
      featureRef: 'feature/two',
    );
    await shared.workflowEngine.transition(
      workItemId: 'wi-2',
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
    );
    await shared.workflowEngine.transition(
      workItemId: 'wi-2',
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      context: const {'featureRef': 'feature/x'},
    );
    await shared.workflowEngine.transition(
      workItemId: 'wi-2',
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );

    // wi-1: normal, created first. wi-2: high priority.
    final normal = (await shared.scheduler.queue.enqueueIfAbsent(
      workItemId: 'wi-1',
      definition: defaultImplementFeatureDefinition,
      dedupeKey: 'wi-1:design_not_required:implement_feature:IMPLEMENTER',
      instruction: 'normal',
      now: t0,
    )).job;
    final high = (await shared.scheduler.queue.enqueueIfAbsent(
      workItemId: 'wi-2',
      definition: const JobDefinition(
        jobType: JobType.implementFeature,
        requiredRole: AgentRole.implementer,
        requiredCapabilities: {WorkerCapability.linux},
        entryStates: {
          WorkItemState.designNotRequired,
          WorkItemState.designApproved,
        },
        priority: JobPriority.high,
        maxAttempts: 2,
      ),
      dedupeKey: 'wi-2:design_not_required:implement_feature:IMPLEMENTER',
      instruction: 'high',
      now: t0,
    )).job;

    await shared.scheduler.tick();

    final runs = (shared.dispatch as ControlledDispatcher).runs;
    expect(runs, hasLength(2));
    expect(runs.first.workerExecutionId, 'wx-${high.jobId}');
    expect(runs.last.workerExecutionId, 'wx-${normal.jobId}');
    expect(
      (await shared.jobStore.readJob(high.jobId))!.state,
      JobState.succeeded,
    );
    expect(
      (await shared.jobStore.readJob(normal.jobId))!.state,
      JobState.succeeded,
    );
  });

  test('a job whose worker emits a lease-failure outcome is returned to the '
      'queue without a terminal failure', () async {
    final shared = FileRestartHarness(dir, clock: () => t0);
    await shared.itemRunnable();
    final dispatch = shared.dispatch as ControlledDispatcher;
    dispatch.failRun = true;

    await shared.scheduler.tick();

    final job = (await shared.jobStore.listJobs()).single;
    expect(job.state, JobState.queued);
    expect(job.failure, isNull);
    expect(dispatch.runs, isEmpty);
    expect(await shared.jobStore.readClaimForJob(job.jobId), isNull);
    final events = await shared.jobStore.readEvents(job.jobId);
    expect(events.last.type, SchedulerEventType.jobDeferred);
  });
}
