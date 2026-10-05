import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';

/// Owner-package tests for the dispatch -> adopt execution-reference chain.
///
/// A job's `JobExecutionReference` is the link in the durable chain
/// WorkItem -> Job -> WorkerExecution -> AgentExecution. `JobQueue.markRunning`
/// stamps the worker-execution half BEFORE dispatch; the scheduler's adoption
/// of the terminal outcome stamps the agent-execution half. These tests assert
/// both halves directly in the owning package instead of relying on an
/// apps/server integration suite to observe them.
///
/// Everything this file needs is defined here: `test/support/` belongs to other
/// lanes, so no support file is added or modified.
void main() {
  late Directory dir;
  final t0 = DateTime.utc(2026, 1, 1, 12);

  setUp(() => dir = Directory.systemTemp.createTempSync('lane_j_exec_ref'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('agentExecutionId reaches the terminal job', () {
    test(
      'a dispatched job carries the reported agent execution id through '
      'adoption onto the succeeded job, and it is durable across a restart',
      () async {
        final dispatch = _ReportingDispatcher(
          agentExecutionIdSeries: const ['agx-1'],
        );
        final host = _Host(dir, clock: () => t0, dispatch: dispatch);
        await host.itemRunnable();

        final tick = await host.scheduler.tick();
        expect(tick.dispatched, hasLength(1));

        final job = (await host.jobStore.listJobs()).single;
        expect(job.state, JobState.succeeded);

        // The worker-execution half was stamped at dispatch, before the worker
        // ran; the agent-execution half was stamped by adoption of the outcome.
        final ref = job.executionReference;
        expect(ref, isNotNull);
        expect(ref!.workerExecutionId, 'wx-${job.jobId}');
        expect(ref.agentExecutionId, 'agx-1');
        expect(ref.resultId, isNull);
        expect(ref.createdAt, t0);

        // The same execution the request named is the one that reported the
        // outcome, so both halves of the chain agree.
        expect(dispatch.runs.single.workerExecutionId, ref.workerExecutionId);

        // Durable, not in-memory: a fresh process over the same store reads it.
        final resumed = _Host(dir, clock: () => t0);
        final reloaded = (await resumed.jobStore.readJob(job.jobId))!;
        expect(reloaded.executionReference, ref);
        expect(reloaded.executionReference!.agentExecutionId, 'agx-1');
      },
    );

    test('a permanently failed job still records the agent execution id of '
        'the run that failed it', () async {
      final host = _Host(
        dir,
        clock: () => t0,
        dispatch: _ReportingDispatcher(
          statusSeries: const [WorkerExecutionStatus.executedFail],
          agentExecutionIdSeries: const ['agx-permanent'],
        ),
      );
      await host.itemRunnable();

      await host.scheduler.tick();

      final job = (await host.jobStore.listJobs()).single;
      expect(job.state, JobState.failed);
      expect(job.failure!.kind, JobFailureKind.permanent);
      expect(job.executionReference!.agentExecutionId, 'agx-permanent');
      expect(job.executionReference!.workerExecutionId, 'wx-${job.jobId}');
    });

    test('a cancelled outcome records the agent execution id', () async {
      final host = _Host(
        dir,
        clock: () => t0,
        dispatch: _ReportingDispatcher(
          statusSeries: const [WorkerExecutionStatus.cancelled],
          agentExecutionIdSeries: const ['agx-cancelled'],
        ),
      );
      await host.itemRunnable();

      await host.scheduler.tick();

      final job = (await host.jobStore.listJobs()).single;
      expect(job.state, JobState.cancelled);
      expect(job.executionReference!.agentExecutionId, 'agx-cancelled');
    });
  });

  group('the queue preserves the dispatch-time reference', () {
    test('complete() persists the reference recorded at dispatch when the '
        'caller supplies none', () async {
      final host = _Host(dir, clock: () => t0);
      await host.itemRunnable();
      final queued = await host.enqueueJob();
      final running = await host.markRunning(queued);

      final dispatchRef = running.executionReference!;
      expect(dispatchRef.workerExecutionId, 'wx-${queued.jobId}');
      expect(dispatchRef.agentExecutionId, isNull);

      // No `executionReference:` argument: the dispatch-time reference must
      // survive the terminal transition untouched.
      final terminal = await host.scheduler.queue.complete(
        job: running,
        terminal: JobState.succeeded,
        now: t0,
      );

      expect(terminal.state, JobState.succeeded);
      expect(terminal.executionReference, dispatchRef);
      expect(
        (await host.jobStore.readJob(queued.jobId))!.executionReference,
        dispatchRef,
      );
    });

    test(
      'scheduleRetry() preserves the reference of the attempt that failed',
      () async {
        final host = _Host(dir, clock: () => t0);
        await host.itemRunnable();
        final queued = await host.enqueueJob();
        final dispatchRef = (await host.markRunning(
          queued,
        )).executionReference!;

        final retrying = await host.scheduler.queue.scheduleRetry(
          job: (await host.jobStore.readJob(queued.jobId))!,
          failure: JobFailure(
            code: JobFailureCode.executionInterrupted,
            kind: JobFailureKind.transient,
            reason: 'lease lost',
          ),
          now: t0,
          retryDelay: Duration.zero,
        );

        expect(retrying.state, JobState.retryWaiting);
        expect(retrying.attempt, 2);
        expect(retrying.executionReference, dispatchRef);
      },
    );

    test('the two requeue paths CLEAR the reference rather than carrying a '
        'dead one forward', () async {
      final host = _Host(dir, clock: () => t0);
      await host.itemRunnable();

      final reverted = await host.markRunning(await host.enqueueJob());
      expect(reverted.executionReference, isNotNull);
      expect(
        (await host.scheduler.queue.revertToQueued(
          job: reverted,
          reason: 'placement failed',
        )).executionReference,
        isNull,
      );

      final stale = await host.markRunning(
        await host.enqueueJob(dedupeSuffix: '-stale'),
      );
      expect(stale.executionReference, isNotNull);
      expect(
        (await host.scheduler.queue.requeueFromStaleClaim(
          job: stale,
          reason: 'lease expired',
        )).executionReference,
        isNull,
      );
    });
  });

  group('the workerExecutionId is never empty', () {
    test('losing the markRunning CAS adopts the reported worker execution id '
        'instead of writing an empty reference', () async {
      final dispatch = _ReportingDispatcher(
        agentExecutionIdSeries: const ['agx-1'],
      );
      final losing = _CasLosingJobStore();
      final host = _Host(
        dir,
        clock: () => t0,
        dispatch: dispatch,
        store: losing,
      );
      await host.itemRunnable();

      await host.scheduler.tick();

      expect(losing.lostMarkRunningWrites, 1);
      final job = (await host.jobStore.listJobs()).single;
      expect(job.state, JobState.succeeded);

      // The lost CAS left no reference behind. The correct value on a lost CAS
      // is the worker execution that produced the adopted outcome - the same
      // execution the dispatch request named - never the empty string.
      final ref = job.executionReference;
      expect(ref, isNotNull, reason: 'adoption must restore the reference');
      expect(ref!.workerExecutionId, isNotEmpty);
      expect(ref.workerExecutionId, 'wx-${job.jobId}');
      expect(ref.workerExecutionId, dispatch.runs.single.workerExecutionId);
      expect(ref.agentExecutionId, 'agx-1');
    });

    test('losing the markRunning CAS with an unnamed outcome fabricates NO '
        'reference at all rather than a dangling one', () async {
      final losing = _CasLosingJobStore();
      final host = _Host(
        dir,
        clock: () => t0,
        // A dispatch layer that cannot name the execution it ran.
        dispatch: _ReportingDispatcher(
          agentExecutionIdSeries: const ['agx-1'],
          reportWorkerExecutionId: '',
        ),
        store: losing,
      );
      await host.itemRunnable();

      await host.scheduler.tick();

      expect(losing.lostMarkRunningWrites, 1);
      final job = (await host.jobStore.listJobs()).single;
      expect(job.state, JobState.succeeded);
      // No reference beats a reference pointing at nothing: a reader follows
      // the chain, and an empty id is not a worker execution.
      expect(job.executionReference, isNull);
    });

    test(
      'a lost markRunning CAS with no reported agent execution id leaves the '
      'job without a fabricated reference',
      () async {
        final losing = _CasLosingJobStore();
        final host = _Host(dir, clock: () => t0, store: losing);
        await host.itemRunnable();

        await host.scheduler.tick();

        final job = (await host.jobStore.listJobs()).single;
        expect(job.state, JobState.succeeded);
        expect(job.executionReference, isNull);
      },
    );

    test('the normal path is unchanged by adoption: the dispatch-time worker '
        'execution id always wins over the reported one', () async {
      final dispatch = _ReportingDispatcher(
        agentExecutionIdSeries: const ['agx-1'],
        // A misreporting layer must not rewrite the durable worker reference.
        reportWorkerExecutionId: 'wx-somewhere-else',
      );
      final host = _Host(dir, clock: () => t0, dispatch: dispatch);
      await host.itemRunnable();

      await host.scheduler.tick();

      final job = (await host.jobStore.listJobs()).single;
      expect(job.executionReference!.workerExecutionId, 'wx-${job.jobId}');
      expect(job.executionReference!.agentExecutionId, 'agx-1');
    });
  });

  group(
    'retry, duplicate enqueue and max attempts never corrupt the reference',
    () {
      test(
        'a retried attempt records ITS OWN agent execution id, not the failed '
        "attempt's",
        () async {
          var now = t0;
          final dispatch = _ReportingDispatcher(
            statusSeries: const [
              WorkerExecutionStatus.timedOut,
              WorkerExecutionStatus.executedPass,
            ],
            agentExecutionIdSeries: const ['agx-1', 'agx-2'],
          );
          final first = _Host(dir, clock: () => now, dispatch: dispatch);
          await first.itemRunnable();
          await first.scheduler.tick();

          final retrying = (await first.jobStore.listJobs()).single;
          expect(retrying.state, JobState.retryWaiting);
          expect(retrying.attempt, 2);
          // The failed attempt's agent execution is retained with that attempt.
          expect(retrying.executionReference!.agentExecutionId, 'agx-1');
          expect(
            retrying.executionReference!.workerExecutionId,
            'wx-${retrying.jobId}',
          );

          now = t0.add(const Duration(minutes: 2));
          final resumed = _Host(dir, clock: () => now, dispatch: dispatch);
          await resumed.scheduler.tick();

          final done = (await resumed.jobStore.listJobs()).single;
          expect(done.state, JobState.succeeded);
          expect(dispatch.runs, hasLength(2));
          // The second attempt re-stamped the reference: the id is the one that
          // actually produced the adopted outcome, never an accumulation.
          expect(done.executionReference!.agentExecutionId, 'agx-2');
          expect(
            done.executionReference!.workerExecutionId,
            'wx-${done.jobId}',
          );
          expect(done.executionReference!.resultId, isNull);
        },
      );

      test('a duplicate tick neither re-enqueues nor re-dispatches, and leaves '
          'the terminal reference intact', () async {
        final dispatch = _ReportingDispatcher(
          agentExecutionIdSeries: const ['agx-1'],
        );
        final host = _Host(dir, clock: () => t0, dispatch: dispatch);
        await host.itemRunnable();

        await host.scheduler.tick();
        final afterFirst = (await host.jobStore.listJobs()).single;

        await host.scheduler.tick();
        await host.scheduler.tick();
        final afterMore = await host.jobStore.listJobs();

        expect(afterMore, hasLength(1), reason: 'idempotent enqueue');
        expect(afterMore.single.jobId, afterFirst.jobId);
        expect(dispatch.runs, hasLength(1), reason: 'no re-execution');
        expect(
          afterMore.single.executionReference,
          afterFirst.executionReference,
        );
        expect(afterMore.single.executionReference!.agentExecutionId, 'agx-1');
      });

      test(
        'a duplicate enqueue for the same dedupe key returns the existing job '
        'and its reference unchanged',
        () async {
          final host = _Host(
            dir,
            clock: () => t0,
            dispatch: _ReportingDispatcher(
              agentExecutionIdSeries: const ['agx-1'],
            ),
          );
          await host.itemRunnable();
          await host.scheduler.tick();
          final terminal = (await host.jobStore.listJobs()).single;

          final again = await host.scheduler.queue.enqueueIfAbsent(
            workItemId: 'wi-1',
            definition: defaultImplementFeatureDefinition,
            dedupeKey: host.dedupeKey,
            instruction: 'Implement the feature.',
            now: t0,
          );

          expect(again.created, isFalse);
          expect(again.job.jobId, terminal.jobId);
          expect(again.job.executionReference, terminal.executionReference);
        },
      );

      test('exhausting maxAttempts terminates as failed with the last attempt '
          'intact', () async {
        final host = _Host(
          dir,
          clock: () => t0,
          dispatch: _ReportingDispatcher(
            statusSeries: const [WorkerExecutionStatus.timedOut],
            agentExecutionIdSeries: const ['agx-exhausted'],
          ),
          definition: const JobDefinition(
            jobType: JobType.implementFeature,
            requiredRole: AgentRole.implementer,
            requiredCapabilities: {WorkerCapability.linux},
            entryStates: {WorkItemState.designNotRequired},
            priority: JobPriority.normal,
            maxAttempts: 1,
          ),
        );
        await host.itemRunnable();

        await host.scheduler.tick();

        final job = (await host.jobStore.listJobs()).single;
        expect(job.state, JobState.failed);
        expect(job.attempt, 1);
        expect(job.failure!.kind, JobFailureKind.transient);
        expect(job.executionReference!.agentExecutionId, 'agx-exhausted');
        expect(job.executionReference!.workerExecutionId, 'wx-${job.jobId}');
        expect(job.executionReference!.workerExecutionId, isNotEmpty);
      });

      test('cancelling a queued job never invents a reference', () async {
        final host = _Host(
          dir,
          clock: () => t0,
          dispatch: _ReportingDispatcher(
            agentExecutionIdSeries: const ['agx-1'],
          ),
        );
        await host.itemRunnable();
        final queued = await host.enqueueJob();
        expect(queued.executionReference, isNull);

        final cancelled = await host.scheduler.cancelJob(
          queued.jobId,
          'no longer needed',
        );

        expect(cancelled.state, JobState.cancelled);
        expect(cancelled.executionReference, isNull);
      });
    },
  );

  group('the reference type itself', () {
    test(
      'copyWith replaces one link in the chain and leaves the others alone',
      () {
        final base = JobExecutionReference(
          workerExecutionId: 'wx-1',
          createdAt: t0,
          resultId: 'res-1',
        );

        final linked = base.copyWith(agentExecutionId: 'agx-1');

        expect(linked.workerExecutionId, 'wx-1');
        expect(linked.createdAt, t0);
        expect(linked.resultId, 'res-1');
        expect(linked.agentExecutionId, 'agx-1');
        expect(base.agentExecutionId, isNull, reason: 'base is not mutated');
        expect(linked, isNot(base));
      },
    );

    test('copyWith can explicitly clear a nullable link, unlike a ?? copy', () {
      final base = JobExecutionReference(
        workerExecutionId: 'wx-1',
        createdAt: t0,
        agentExecutionId: 'agx-1',
      );

      expect(base.copyWith(agentExecutionId: null).agentExecutionId, isNull);
      expect(base.copyWith().agentExecutionId, 'agx-1');
    });
  });
}

/// File-backed scheduler host for one test, with the job store injectable so a
/// test can decorate it. A second instance over the same [Directory] is a fresh
/// process resuming from persisted state alone.
class _Host {
  _Host(
    this.dir, {
    required DateTime Function() clock,
    JobStore? store,
    WorkerDispatch? dispatch,
    JobDefinition definition = defaultImplementFeatureDefinition,
  }) {
    workflowStore = FileJsonWorkflowStore(File('${dir.path}/workflow.json'));
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    jobStore = store ?? FileJsonJobStore(File('${dir.path}/jobs.json'));
    workerStore = FileJsonWorkerStore(File('${dir.path}/workers.json'));
    this.dispatch = dispatch ?? _ReportingDispatcher();
    final modelPolicyStore = InMemoryModelPolicyStore();
    final modelSelection = ModelSelectionService(modelPolicyStore);
    scheduler = Scheduler(
      schedulerId: 'sched-lane-j',
      workflowStore: workflowStore,
      jobStore: jobStore,
      workerStore: workerStore,
      dispatch: this.dispatch,
      definition: definition,
      workload: SchedulerWorkload(
        repositoryPath: '${dir.path}/repo',
        startingRevision: 'deadbeef',
        timeoutSeconds: 60,
        runtimeTypeId: 'fake-runtime',
      ),
      clock: clock,
      modelSelection: modelSelection,
    );
  }

  final Directory dir;

  late FileJsonWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late JobStore jobStore;
  late FileJsonWorkerStore workerStore;
  late WorkerDispatch dispatch;
  late Scheduler scheduler;

  String get dedupeKey =>
      'wi-1:design_not_required:implement_feature:IMPLEMENTER';

  /// Parks a work item at `designNotRequired`: RUNNABLE.
  Future<WorkItem> itemRunnable() async {
    await workflowEngine.createWorkItem(
      workItemId: 'wi-1',
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Implement calculator add',
      description: 'Lane J execution-reference fixture',
      qaContractId: 'qa-1',
      featureRef: 'feature/calc',
    );
    await workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
    );
    await workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      context: const {'featureRef': 'feature/calc'},
    );
    return workflowEngine.transition(
      workItemId: 'wi-1',
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );
  }

  Future<Job> enqueueJob({String dedupeSuffix = ''}) async {
    return (await scheduler.queue.enqueueIfAbsent(
      workItemId: 'wi-1',
      definition: defaultImplementFeatureDefinition,
      dedupeKey: '$dedupeKey$dedupeSuffix',
      instruction: 'Implement the feature.',
      now: DateTime.utc(2026, 1, 1),
    )).job;
  }

  /// Claims and dispatches a queued job, the two steps a tick performs before
  /// the worker runs.
  Future<Job> markRunning(Job queued) async {
    final claim = await scheduler.queue.claim(
      job: queued,
      ownerId: scheduler.schedulerId,
      now: DateTime.utc(2026, 1, 1, 12),
      lease: const Duration(minutes: 10),
    );
    expect(claim, isNotNull, reason: 'the claim CAS must be won');
    return scheduler.queue.markRunning(
      job: (await jobStore.readJob(queued.jobId))!,
      now: DateTime.utc(2026, 1, 1, 12),
      workerId: 'w-lane-j',
      workerExecutionId: 'wx-${queued.jobId}',
    );
  }
}

/// A [WorkerDispatch] that reports a scripted terminal outcome, optionally
/// carrying the `agentExecutionId` the execution layer recorded. Scripting the
/// id per attempt is what lets the retry test prove the reference names the
/// attempt that produced the adopted outcome.
class _ReportingDispatcher implements WorkerDispatch {
  _ReportingDispatcher({
    this.statusSeries = const [WorkerExecutionStatus.executedPass],
    this.agentExecutionIdSeries = const [null],
    this.reportWorkerExecutionId,
  }) : assert(
         statusSeries.length == agentExecutionIdSeries.length,
         'each scripted attempt needs a status and an agent execution id',
       );

  final List<WorkerExecutionStatus> statusSeries;
  final List<String?> agentExecutionIdSeries;

  /// Overrides the worker execution id stamped on the reported outcome. Used to
  /// model a dispatch layer that misreports or cannot name its execution.
  final String? reportWorkerExecutionId;

  final _runs = <WorkerExecutionRequest>[];

  List<WorkerExecutionRequest> get runs => List.unmodifiable(_runs);

  @override
  WorkerSelection select(WorkerExecutionRequest request) =>
      WorkerSelection.dispatched(
        WorkerRegistration(
          workerId: 'w-lane-j',
          poolId: 'lane-j-pool',
          capabilities: {
            for (final c in request.requiredCapabilities)
              c: CapabilitySpec(capability: c, version: '1'),
          },
          status: WorkerStatus.idle,
          currentLoad: 0,
          maxConcurrency: 1,
          lastHeartbeat: DateTime.utc(2026, 1, 1, 12),
        ),
      );

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) async {
    final attempt = _runs.length;
    _runs.add(request);
    return WorkerExecutionResult(
      workerExecutionId: reportWorkerExecutionId ?? request.workerExecutionId,
      workItemId: request.workItemId,
      status: statusSeries[attempt % statusSeries.length],
      workerId: 'w-lane-j',
      workspaceId: 'ws-${request.workerExecutionId}',
      startingRevision: request.startingRevision,
      startedAt: DateTime.utc(2026, 1, 1, 12),
      endedAt: DateTime.utc(2026, 1, 1, 12),
      cleanupStatus: WorkerCleanupStatus.removed,
      failureCode: WorkerFailureCode.none,
      agentExecutionId:
          agentExecutionIdSeries[attempt % agentExecutionIdSeries.length],
    );
  }

  @override
  Future<void> cancel(String workerId, String reason) async {}
}

/// A [JobStore] decorator that loses exactly the one CAS the reviewer named:
/// the write `JobQueue.markRunning` attempts when it persists the
/// dispatch-time execution reference. Models a concurrent writer bumping the
/// row between the queue's read and its write, which leaves the job holding NO
/// reference while its worker execution is already running.
class _CasLosingJobStore implements JobStore {
  final JobStore inner = InMemoryJobStore();

  var lostMarkRunningWrites = 0;
  var _armed = true;

  @override
  Future<void> saveJob(Job job, {int? expectedVersion}) async {
    if (_armed && job.state == JobState.running) {
      _armed = false;
      lostMarkRunningWrites++;
      final current = await inner.readJob(job.jobId);
      throw ConcurrentJobModificationException(
        jobId: job.jobId,
        expectedVersion: expectedVersion ?? 0,
        actualVersion: (current?.version ?? 0) + 1,
      );
    }
    return inner.saveJob(job, expectedVersion: expectedVersion);
  }

  @override
  Future<Job?> readJob(String jobId) => inner.readJob(jobId);

  @override
  Future<List<Job>> listJobs() => inner.listJobs();

  @override
  Future<List<Job>> listJobsForWorkItem(String workItemId) =>
      inner.listJobsForWorkItem(workItemId);

  @override
  Future<Job?> findLatestByDedupeKey(String dedupeKey) =>
      inner.findLatestByDedupeKey(dedupeKey);

  @override
  Future<void> saveClaim(JobClaim claim) => inner.saveClaim(claim);

  @override
  Future<JobClaim?> readClaimForJob(String jobId) =>
      inner.readClaimForJob(jobId);

  @override
  Future<List<JobClaim>> listClaims() => inner.listClaims();

  @override
  Future<void> deleteClaim(String jobId) => inner.deleteClaim(jobId);

  @override
  Future<void> appendEvent(SchedulerEventRecord event) =>
      inner.appendEvent(event);

  @override
  Future<List<SchedulerEventRecord>> readEvents(String jobId) =>
      inner.readEvents(jobId);

  @override
  Future<T> inTransaction<T>(Future<T> Function(JobStore store) body) =>
      inner.inTransaction((_) => body(this));
}
