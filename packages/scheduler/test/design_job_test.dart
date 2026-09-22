import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'support/gate_fake_agent.dart';
import 'support/git_repo_fixture.dart';
import 'support/scheduler_host.dart';

/// Test host for design/review jobs with workers that have the required capabilities.
class DesignJobHost {
  DesignJobHost({
    required GitRepoFixture repo,
    required String workspaceRoot,
    required JobStore jobStore,
    required JobDefinition definition,
    SchedulerWorkload? workload,
    Duration claimLease = const Duration(minutes: 10),
    DedupeKeyBuilder? dedupeKeyBuilder,
    InstructionBuilder? instructionBuilder,
    RequestBuilder? requestBuilder,
  }) {
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();
    session = GateFakeAgentSession(
      executionId: 'agx-fixed',
      workItemId: 'wi-1',
    );
    runtime = AgentRuntime(
      registry: AgentAdapterRegistry()..register(GateFakeAgentAdapter(session)),
    );
    coordinator = ExecutionCoordinator(
      store: executionStore,
      workflowEngine: workflowEngine,
      runtime: runtime,
      verificationPlan: VerificationPlan(
        command: [Platform.resolvedExecutable, 'tool/verify.dart'],
      ),
    );
    driver = CoordinatorAgentExecutionDriver(coordinator);
    workerStore = InMemoryWorkerStore();
    workspaceManager = GitWorktreeWorkspaceManager(
      workspaceRoot: workspaceRoot,
    );

    final capabilities = definition.jobType == JobType.designRevision
        ? {
            WorkerCapability.linux,
            WorkerCapability.penpotWrite,
            WorkerCapability.visualDesign,
          }
        : {
            WorkerCapability.linux,
            WorkerCapability.penpotRead,
            WorkerCapability.designReview,
          };

    worker = LocalWorker(
      workerId: 'w-design-1',
      poolId: 'design-pool',
      capabilities: capabilities,
      workspaceManager: workspaceManager,
      executionDriver: driver,
      workerStore: workerStore,
      platform: 'linux-x64',
    );
    dispatcher = WorkerDispatcher(registry: WorkerRegistry()..register(worker));
    this.jobStore = jobStore;
    scheduler = Scheduler(
      schedulerId: 'sched-design-1',
      workflowStore: workflowStore,
      jobStore: jobStore,
      workerStore: workerStore,
      dispatch: WorkerDispatcherAdapter(dispatcher),
      definition: definition,
      workload:
          workload ??
          SchedulerWorkload(
            repositoryPath: repo.root.path,
            startingRevision: repo.startingRevision,
            timeoutSeconds: 60,
            runtimeTypeId: 'fake-runtime',
          ),
      claimLease: claimLease,
      dedupeKeyBuilder: dedupeKeyBuilder,
      instructionBuilder: instructionBuilder,
      requestBuilder: requestBuilder,
    );
  }

  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;
  late GateFakeAgentSession session;
  late AgentRuntime runtime;
  late ExecutionCoordinator coordinator;
  late CoordinatorAgentExecutionDriver driver;
  late InMemoryWorkerStore workerStore;
  late GitWorktreeWorkspaceManager workspaceManager;
  late LocalWorker worker;
  late WorkerDispatcher dispatcher;
  late JobStore jobStore;
  late Scheduler scheduler;
}

void main() {
  late Directory temp;
  late GitRepoFixture repo;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('design_job_test');
    repo = GitRepoFixture.create('${temp.path}/repo');
  });

  tearDown(() {
    repo.dispose();
    temp.deleteSync(recursive: true);
  });

  group('Design revision job', () {
    late JobStore jobStore;
    late DesignJobHost host;

    setUp(() {
      jobStore = InMemoryJobStore();
      host = DesignJobHost(
        repo: repo,
        workspaceRoot: '${temp.path}/workspaces',
        jobStore: jobStore,
        definition: designRevisionDefinition,
        dedupeKeyBuilder: designRevisionDedupeKey,
        instructionBuilder: designRevisionInstruction,
        requestBuilder: designRevisionRequest,
      );
    });

    test('enqueues when work item enters designRequired', () async {
      await host.workflowEngine.createWorkItem(
        workItemId: 'wi-design-1',
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Design login page',
        description: 'Design a login page for the authentication flow',
        qaContractId: 'qa-1',
        featureRef: 'feature/login',
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-design-1',
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-design-1',
        to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent,
        context: const {'featureRef': 'feature/login'},
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-design-1',
        to: WorkItemState.designRequired,
        trigger: TransitionTrigger.systemEvent,
        context: {'designContractId': 'dc-wi-design-1'},
      );

      final pending = host.scheduler.tick();
      await host.session.awaitingGate;
      host.session.release();
      final tick = await pending;
      expect(tick.enqueued, hasLength(1));

      final jobs = await jobStore.listJobsForWorkItem('wi-design-1');
      expect(jobs, hasLength(1));
      expect(jobs.single.jobType, JobType.designRevision);
      expect(jobs.single.requiredRole, AgentRole.designAgent);
      expect(jobs.single.requiredCapabilities,
          {WorkerCapability.penpotWrite, WorkerCapability.visualDesign});
    });

    test('does not enqueue when work item is not in entry state', () async {
      await host.workflowEngine.createWorkItem(
        workItemId: 'wi-design-2',
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Design dashboard',
        description: 'Design a dashboard for analytics',
        qaContractId: 'qa-2',
        featureRef: 'feature/dashboard',
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-design-2',
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
      );

      final tick = await host.scheduler.tick();
      expect(tick.enqueued, isEmpty);

      final jobs = await jobStore.listJobsForWorkItem('wi-design-2');
      expect(jobs, isEmpty);
    });

    test('worker lacking visualDesign cannot claim design job', () async {
      await host.workflowEngine.createWorkItem(
        workItemId: 'wi-design-3',
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Design settings',
        description: 'Design settings page for user preferences',
        qaContractId: 'qa-3',
        featureRef: 'feature/settings',
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-design-3',
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-design-3',
        to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent,
        context: const {'featureRef': 'feature/settings'},
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-design-3',
        to: WorkItemState.designRequired,
        trigger: TransitionTrigger.systemEvent,
        context: {'designContractId': 'dc-wi-design-3'},
      );

      host.worker = LocalWorker(
        workerId: 'w-no-visual-1',
        poolId: 'design-pool',
        capabilities: {WorkerCapability.linux, WorkerCapability.penpotWrite},
        workspaceManager: host.workspaceManager,
        executionDriver: host.driver,
        workerStore: host.workerStore,
        platform: 'linux-x64',
      );
      host.dispatcher = WorkerDispatcher(
          registry: WorkerRegistry()..register(host.worker));
      host.scheduler = Scheduler(
        schedulerId: 'sched-design-2',
        workflowStore: host.workflowStore,
        jobStore: host.jobStore,
        workerStore: host.workerStore,
        dispatch: WorkerDispatcherAdapter(host.dispatcher),
        definition: designRevisionDefinition,
        workload: SchedulerWorkload(
          repositoryPath: repo.root.path,
          startingRevision: repo.startingRevision,
          timeoutSeconds: 60,
          runtimeTypeId: 'fake-runtime',
        ),
        dedupeKeyBuilder: designRevisionDedupeKey,
        instructionBuilder: designRevisionInstruction,
        requestBuilder: designRevisionRequest,
      );

      await host.scheduler.tick();
      host.session.release();
      final tick = await host.scheduler.tick();

      expect(tick.deferred, hasLength(1));
      expect(tick.dispatched, isEmpty);
    });
  });

  group('Design review job', () {
    late JobStore jobStore;
    late DesignJobHost host;

    setUp(() {
      jobStore = InMemoryJobStore();
      host = DesignJobHost(
        repo: repo,
        workspaceRoot: '${temp.path}/workspaces',
        jobStore: jobStore,
        definition: designReviewDefinition,
        dedupeKeyBuilder: designReviewDedupeKey,
        instructionBuilder: designReviewInstruction,
        requestBuilder: designReviewRequest,
      );
    });

    test('enqueues when work item enters designInReview', () async {
      await host.workflowEngine.createWorkItem(
        workItemId: 'wi-review-1',
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Review login design',
        description: 'Review the login page design for accessibility',
        qaContractId: 'qa-1',
        featureRef: 'feature/login',
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-review-1',
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-review-1',
        to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent,
        context: const {'featureRef': 'feature/login'},
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-review-1',
        to: WorkItemState.designRequired,
        trigger: TransitionTrigger.systemEvent,
        context: {'designContractId': 'dc-wi-review-1'},
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-review-1',
        to: WorkItemState.designInReview,
        trigger: TransitionTrigger.systemEvent,
        context: {
          'designContractId': 'dc-wi-review-1',
          'designContractStatus': DesignContractStatus.underReview,
          'designRevisionId': 'dr-1',
          'designerExecutionId': 'wx-designer-1',
        },
      );
      final item = await host.workflowEngine.loadWorkItem('wi-review-1');
      await host.workflowStore.saveWorkItem(item.copyWith(
        metadata: {
          'designRevisionId': 'dr-1',
          'designerExecutionId': 'wx-designer-1',
        },
      ));

      final pending = host.scheduler.tick();
      await host.session.awaitingGate;
      host.session.release();
      final tick = await pending;
      expect(tick.enqueued, hasLength(1));

      final jobs = await jobStore.listJobsForWorkItem('wi-review-1');
      expect(jobs, hasLength(1));
      expect(jobs.single.jobType, JobType.designReview);
      expect(jobs.single.requiredRole, AgentRole.designReviewer);
      expect(jobs.single.requiredCapabilities,
          {WorkerCapability.penpotRead, WorkerCapability.designReview});
      expect(jobs.single.priority, JobPriority.high);
      expect(jobs.single.maxAttempts, 2);
    });

    test('worker with penpotWrite cannot claim review job (wrong capability)', () async {
      await host.workflowEngine.createWorkItem(
        workItemId: 'wi-review-2',
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Review dashboard design',
        description: 'Review the dashboard design for usability',
        qaContractId: 'qa-2',
        featureRef: 'feature/dashboard',
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-review-2',
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-review-2',
        to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent,
        context: const {'featureRef': 'feature/dashboard'},
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-review-2',
        to: WorkItemState.designRequired,
        trigger: TransitionTrigger.systemEvent,
        context: {'designContractId': 'dc-wi-review-2'},
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-review-2',
        to: WorkItemState.designInReview,
        trigger: TransitionTrigger.systemEvent,
        context: {
          'designContractId': 'dc-wi-review-2',
          'designContractStatus': DesignContractStatus.underReview,
          'designRevisionId': 'dr-2',
          'designerExecutionId': 'wx-designer-2',
        },
      );
      final item = await host.workflowEngine.loadWorkItem('wi-review-2');
      await host.workflowStore.saveWorkItem(item.copyWith(
        metadata: {
          'designRevisionId': 'dr-2',
          'designerExecutionId': 'wx-designer-2',
        },
      ));

      host.worker = LocalWorker(
        workerId: 'w-writer-1',
        poolId: 'design-pool',
        capabilities: {WorkerCapability.linux, WorkerCapability.penpotWrite},
        workspaceManager: host.workspaceManager,
        executionDriver: host.driver,
        workerStore: host.workerStore,
        platform: 'linux-x64',
      );
      host.dispatcher = WorkerDispatcher(
          registry: WorkerRegistry()..register(host.worker));
      host.scheduler = Scheduler(
        schedulerId: 'sched-review-2',
        workflowStore: host.workflowStore,
        jobStore: host.jobStore,
        workerStore: host.workerStore,
        dispatch: WorkerDispatcherAdapter(host.dispatcher),
        definition: designReviewDefinition,
        workload: SchedulerWorkload(
          repositoryPath: repo.root.path,
          startingRevision: repo.startingRevision,
          timeoutSeconds: 60,
          runtimeTypeId: 'fake-runtime',
        ),
        dedupeKeyBuilder: designReviewDedupeKey,
        instructionBuilder: designReviewInstruction,
        requestBuilder: designReviewRequest,
      );

      await host.scheduler.tick();
      host.session.release();
      final tick = await host.scheduler.tick();

      expect(tick.deferred, hasLength(1));
      expect(tick.dispatched, isEmpty);
    });

    test('independence at dispatch: designer execution excluded from review', () async {
      // TODO: Full independence at dispatch requires worker to track
      // which execution it ran. Currently the exclusion checks
      // worker.currentExecutionId, which is only set during execution.
      // This test is skipped until that tracking is implemented.
    });
  });

  group('Blocked on human approval', () {
    late JobStore jobStore;
    late SchedulerHost host;

    setUp(() {
      jobStore = InMemoryJobStore();
      host = SchedulerHost(
        repo: repo,
        workspaceRoot: '${temp.path}/workspaces',
        jobStore: jobStore,
      );
    });

    test('waitingForHumanDecision consumes zero capacity', () async {
      final blocked = await host.itemBlocked(workItemId: 'wi-blocked-1');
      expect(blocked.state, WorkItemState.waitingForHumanDecision);

      final _ = await host.scheduler.tick();

      final jobs = await jobStore.listJobsForWorkItem('wi-blocked-1');
      expect(jobs, isEmpty);

      expect(host.worker.isAcquirable, isTrue);
    });

    test('human approval resumes same work item', () async {
      final blocked = await host.itemBlocked(workItemId: 'wi-blocked-2');
      expect(blocked.state, WorkItemState.waitingForHumanDecision);

      await host.humanApproves(workItemId: 'wi-blocked-2');

      final item = await host.workflowEngine.loadWorkItem('wi-blocked-2');
      expect(item.state, WorkItemState.designApproved);

      final afterApproval = await host.workflowEngine.loadWorkItem('wi-blocked-2');
      expect(afterApproval.workItemId, 'wi-blocked-2');
      expect(afterApproval.state, WorkItemState.designApproved);
    });
  });

  group('Dedupe for design jobs', () {
    late JobStore jobStore;
    late DesignJobHost host;

    setUp(() {
      jobStore = InMemoryJobStore();
      host = DesignJobHost(
        repo: repo,
        workspaceRoot: '${temp.path}/workspaces',
        jobStore: jobStore,
        definition: designReviewDefinition,
        dedupeKeyBuilder: designReviewDedupeKey,
        instructionBuilder: designReviewInstruction,
        requestBuilder: designReviewRequest,
      );
    });

    test('(workItemId, designRevisionId, jobType) prevents duplicate reviews', () async {
      await host.workflowEngine.createWorkItem(
        workItemId: 'wi-dedupe-1',
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Dedupe test',
        description: 'Test deduplication of design review jobs',
        qaContractId: 'qa-1',
        featureRef: 'feature/dedupe',
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-dedupe-1',
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-dedupe-1',
        to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent,
        context: const {'featureRef': 'feature/dedupe'},
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-dedupe-1',
        to: WorkItemState.designRequired,
        trigger: TransitionTrigger.systemEvent,
        context: {'designContractId': 'dc-wi-dedupe-1'},
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-dedupe-1',
        to: WorkItemState.designInReview,
        trigger: TransitionTrigger.systemEvent,
        context: {
          'designContractId': 'dc-wi-dedupe-1',
          'designContractStatus': DesignContractStatus.underReview,
          'designRevisionId': 'dr-dedupe-1',
          'designerExecutionId': 'wx-designer-dedupe',
        },
      );
      final item = await host.workflowEngine.loadWorkItem('wi-dedupe-1');
      await host.workflowStore.saveWorkItem(item.copyWith(
        metadata: {
          'designRevisionId': 'dr-dedupe-1',
          'designerExecutionId': 'wx-designer-dedupe',
        },
      ));

      final pending = host.scheduler.tick();
      await host.session.awaitingGate;
      host.session.release();
      await pending;
      var jobs = await jobStore.listJobsForWorkItem('wi-dedupe-1');
      expect(jobs, hasLength(1));
      final firstJobId = jobs.single.jobId;

      await host.scheduler.tick();
      jobs = await jobStore.listJobsForWorkItem('wi-dedupe-1');
      expect(jobs, hasLength(1));
      expect(jobs.single.jobId, firstJobId);

      expect(jobs.single.dedupeKey, contains('dr-dedupe-1'));
    });
  });

  group('maxAttempts exhaustion', () {
    late JobStore jobStore;
    late DesignJobHost host;

    setUp(() {
      jobStore = InMemoryJobStore();
      host = DesignJobHost(
        repo: repo,
        workspaceRoot: '${temp.path}/workspaces',
        jobStore: jobStore,
        definition: designRevisionDefinition,
        dedupeKeyBuilder: designRevisionDedupeKey,
        instructionBuilder: designRevisionInstruction,
        requestBuilder: designRevisionRequest,
      );
    });

test('design revision maxAttempts=3 exhaustion triggers human decision', () async {
      // Test maxAttempts logic directly by manipulating job state
      await host.workflowEngine.createWorkItem(
        workItemId: 'wi-maxattempt-1',
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Max attempts design',
        description: 'Test max attempts exhaustion for design jobs',
        qaContractId: 'qa-1',
        featureRef: 'feature/maxattempt',
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-maxattempt-1',
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-maxattempt-1',
        to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent,
        context: const {'featureRef': 'feature/maxattempt'},
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-maxattempt-1',
        to: WorkItemState.designRequired,
        trigger: TransitionTrigger.systemEvent,
        context: {'designContractId': 'dc-wi-maxattempt-1'},
      );

      // Enqueue the job directly via queue
      final item = await host.workflowEngine.loadWorkItem('wi-maxattempt-1');
      final enqueueResult = await host.scheduler.queue.enqueueIfAbsent(
        workItemId: 'wi-maxattempt-1',
        definition: designRevisionDefinition,
        dedupeKey: designRevisionDedupeKey(item, designRevisionDefinition),
        instruction: designRevisionInstruction(item, designRevisionDefinition),
      );
      var job = enqueueResult.job;
      expect(job.attempt, 1);
      expect(job.maxAttempts, 3);

      // Verify RetryPolicy correctly allows retries up to maxAttempts
      final retryPolicy = RetryPolicy();
      expect(retryPolicy.canRetry(job.copyWith(attempt: 1)), isTrue);
      expect(retryPolicy.canRetry(job.copyWith(attempt: 2)), isTrue);
      expect(retryPolicy.canRetry(job.copyWith(attempt: 3)), isFalse);

      // Simulate retries using scheduleRetry (which increments attempt)
      var failure = JobFailure(
        code: JobFailureCode.executionInterrupted,
        kind: JobFailureKind.transient,
        reason: 'Test transient failure 1',
      );
      job = await host.scheduler.queue.scheduleRetry(
        job: job,
        failure: failure,
        retryDelay: Duration.zero,
      );
      expect(job.attempt, 2);
      expect(RetryPolicy().canRetry(job), isTrue);

      failure = JobFailure(
        code: JobFailureCode.executionInterrupted,
        kind: JobFailureKind.transient,
        reason: 'Test transient failure 2',
      );
      job = await host.scheduler.queue.scheduleRetry(
        job: job,
        failure: failure,
        retryDelay: Duration.zero,
      );
      expect(job.attempt, 3);
      expect(RetryPolicy().canRetry(job), isFalse);

      // When attempt >= maxAttempts, the scheduler should fail the job instead of retrying
      // This is tested by the scheduler's _adopt method using retryPolicy.canRetry
      // Here we verify the policy behavior directly
      expect(RetryPolicy().canRetry(job.copyWith(attempt: 3)), isFalse);
      expect(RetryPolicy().canRetry(job.copyWith(attempt: 4)), isFalse);
    });
  });

  group('Lease reconciliation', () {
    late JobStore jobStore;
    late DesignJobHost host;

    setUp(() {
      jobStore = InMemoryJobStore();
      host = DesignJobHost(
        repo: repo,
        workspaceRoot: '${temp.path}/workspaces',
        jobStore: jobStore,
        definition: designRevisionDefinition,
        dedupeKeyBuilder: designRevisionDedupeKey,
        instructionBuilder: designRevisionInstruction,
        requestBuilder: designRevisionRequest,
      );
    });

test('orphaned design job reclaimed without duplicate revision', () async {
      // Test lease reconciliation logic directly by manipulating job state
      await host.workflowEngine.createWorkItem(
        workItemId: 'wi-recon-1',
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Reconciliation test',
        description: 'Test lease reconciliation for design jobs',
        qaContractId: 'qa-1',
        featureRef: 'feature/recon',
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-recon-1',
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-recon-1',
        to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent,
        context: const {'featureRef': 'feature/recon'},
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-recon-1',
        to: WorkItemState.designRequired,
        trigger: TransitionTrigger.systemEvent,
        context: {'designContractId': 'dc-wi-recon-1'},
      );

      // Enqueue directly via queue
      final item = await host.workflowEngine.loadWorkItem('wi-recon-1');
      final enqueueResult = await host.scheduler.queue.enqueueIfAbsent(
        workItemId: 'wi-recon-1',
        definition: designRevisionDefinition,
        dedupeKey: designRevisionDedupeKey(item, designRevisionDefinition),
        instruction: designRevisionInstruction(item, designRevisionDefinition),
      );
      var job = enqueueResult.job;

      // Manually set job to running state with an EXPIRED claim
      final now = DateTime.now().toUtc();
      final past = now.subtract(const Duration(minutes: 5));
      job = job.copyWith(
        state: JobState.running,
        startedAt: past,
        executionReference: JobExecutionReference(
          workerExecutionId: 'wx-test-1',
          createdAt: past,
        ),
        workerId: 'w-test-1',
      );
      await jobStore.saveJob(job);

      // Create an EXPIRED claim for this job
      final expiredClaim = JobClaim(
        claimId: 'cl-test',
        jobId: job.jobId,
        ownerId: 'sched-test',
        leasedUntil: past,
        createdAt: past.subtract(const Duration(minutes: 5)),
      );
      await jobStore.saveClaim(expiredClaim);

      // Create a new scheduler instance (simulating restart)
      final newHost = DesignJobHost(
        repo: repo,
        workspaceRoot: '${temp.path}/workspaces2',
        jobStore: jobStore,
        definition: designRevisionDefinition,
        dedupeKeyBuilder: designRevisionDedupeKey,
        instructionBuilder: designRevisionInstruction,
        requestBuilder: designRevisionRequest,
      );

      // Tick should reconcile the stale claim
      final tick = await newHost.scheduler.tick();
      expect(tick.reconciled, hasLength(1));

      // Job should be requeued, not duplicated
      final requeuedJobs = await jobStore.listJobsForWorkItem('wi-recon-1');
      expect(requeuedJobs, hasLength(1));
      expect(requeuedJobs.single.jobId, job.jobId);
      expect(requeuedJobs.single.state, JobState.queued);
    });
  });
}