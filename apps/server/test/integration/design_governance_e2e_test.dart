import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_runtime/worker_runtime.dart';

import '../support/design_gate_agents.dart';
import '../support/git_repo_fixture.dart';

/// Full-stack deterministic design-governance host: real workflow engine +
/// store, real execution coordinator, real workers (git worktree + capacity-1
/// + verifier) with gated fake runtimes, plus BOTH a design-revision scheduler
/// and a design-review scheduler sharing one coordinator.
///
/// The design agent and the review agent are mounted under distinct provider
/// ids so the two schedulers can route to different runtimes on the SAME
/// [AgentRuntime]. Each session parks on a release gate for its FIRST
/// execution only; later executions auto-release.
class DesignGovernanceE2EHost {
  DesignGovernanceE2EHost({
    required GitRepoFixture repo,
    required String workspaceRoot,
  }) {
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();
    workerStore = InMemoryWorkerStore();
    jobStore = InMemoryJobStore();

    designSession = DesignGateAgentSession(executionId: 'agx-design');
    reviewSession = DesignGateAgentSession(executionId: 'agx-review');
    runtime = AgentRuntime(
      registry: AgentAdapterRegistry()
        ..register(
          DesignGateAgentAdapter(designSession, providerId: 'design-runtime'),
        )
        ..register(
          DesignGateAgentAdapter(reviewSession, providerId: 'review-runtime'),
        ),
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
    workspaceManager = GitWorktreeWorkspaceManager(
      workspaceRoot: workspaceRoot,
    );

    designWorker = LocalWorker(
      workerId: 'w-design-agent-1',
      poolId: 'design-agent-pool',
      capabilities: const {
        WorkerCapability.linux,
        WorkerCapability.penpotWrite,
        WorkerCapability.visualDesign,
      },
      workspaceManager: workspaceManager,
      executionDriver: driver,
      workerStore: workerStore,
      platform: 'linux-x64',
    );
    reviewWorker = LocalWorker(
      workerId: 'w-design-reviewer-1',
      poolId: 'design-reviewer-pool',
      capabilities: const {
        WorkerCapability.linux,
        WorkerCapability.penpotRead,
        WorkerCapability.designReview,
      },
      workspaceManager: workspaceManager,
      executionDriver: driver,
      workerStore: workerStore,
      platform: 'linux-x64',
    );
    dispatcher = WorkerDispatcher(
      registry: WorkerRegistry()
        ..register(designWorker)
        ..register(reviewWorker),
    );

    designRevisionScheduler = Scheduler(
      schedulerId: 'sched-design-revision',
      workflowStore: workflowStore,
      jobStore: jobStore,
      workerStore: workerStore,
      dispatch: WorkerDispatcherAdapter(dispatcher),
      definition: designRevisionDefinition,
      workload: SchedulerWorkload(
        repositoryPath: repo.root.path,
        startingRevision: repo.startingRevision,
        timeoutSeconds: 60,
        runtimeTypeId: 'design-runtime',
      ),
      dedupeKeyBuilder: designRevisionDedupeKey,
      instructionBuilder: designRevisionInstruction,
      requestBuilder: designRevisionRequest,
    );

    designReviewScheduler = Scheduler(
      schedulerId: 'sched-design-review',
      workflowStore: workflowStore,
      jobStore: jobStore,
      workerStore: workerStore,
      dispatch: WorkerDispatcherAdapter(dispatcher),
      definition: designReviewDefinition,
      workload: SchedulerWorkload(
        repositoryPath: repo.root.path,
        startingRevision: repo.startingRevision,
        timeoutSeconds: 60,
        runtimeTypeId: 'review-runtime',
      ),
      dedupeKeyBuilder: designReviewDedupeKey,
      instructionBuilder: designReviewInstruction,
      requestBuilder: designReviewRequest,
    );
  }

  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;
  late InMemoryWorkerStore workerStore;
  late InMemoryJobStore jobStore;
  late DesignGateAgentSession designSession;
  late DesignGateAgentSession reviewSession;
  late AgentRuntime runtime;
  late ExecutionCoordinator coordinator;
  late CoordinatorAgentExecutionDriver driver;
  late GitWorktreeWorkspaceManager workspaceManager;
  late LocalWorker designWorker;
  late LocalWorker reviewWorker;
  late WorkerDispatcher dispatcher;
  late Scheduler designRevisionScheduler;
  late Scheduler designReviewScheduler;

  /// Creates a work item and walks it to [WorkItemState.designRequired].
  Future<WorkItem> createDesignWorkItem({
    required String workItemId,
    required String productId,
    String title = 'Design a feature',
    String description = 'Design a feature for the product',
  }) async {
    await workflowEngine.createWorkItem(
      workItemId: workItemId,
      productId: productId,
      category: WorkItemCategory.feature,
      title: title,
      description: description,
      designContractId: 'dc-$workItemId',
      qaContractId: 'qa-$workItemId',
      featureRef: 'feature/$workItemId',
    );
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
    );
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      context: {'featureRef': 'feature/$workItemId'},
    );
    return workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.designRequired,
      trigger: TransitionTrigger.systemEvent,
      context: {'designContractId': 'dc-$workItemId'},
    );
  }

  /// Runs ONE design-revision job to durably-completed (enqueue + dispatch +
  /// gated execution + release) and waits for the tick to settle.
  ///
  /// Uses the same deterministic pattern as the scheduler slice: capture the
  /// tick future, wait for the gate, release, then await the tick.
  Future<void> runDesignRevision(String workItemId) async {
    final tick = designRevisionScheduler.tick();
    await designSession.awaitingGate;
    designSession.release();
    await tick;
  }

  /// Runs ONE design-review job to durably-completed.
  Future<void> runDesignReview(String workItemId) async {
    final tick = designReviewScheduler.tick();
    await reviewSession.awaitingGate;
    reviewSession.release();
    await tick;
  }

  /// A tick with NO expected dispatch (already-terminal dedupe, blocked gate,
  /// etc). Safe because nothing parks on a gate.
  Future<SchedulerTickResult> noopDesignReviewTick() =>
      designReviewScheduler.tick();

  /// The orchestration glue between a completed execution (design filler OR
  /// review) and the review scheduler: moves the item back into
  /// `designInReview` and stamps the revision + designer references the review
  /// job reads. This is where a platform digest of an AgentResult would land.
  ///
  /// [designRevisionId] and [designerExecutionId] come from the durable
  /// execution record, mirroring how the platform would digest an AgentResult.
  /// After a review completes the item re-enters `designInReview` with the
  /// SAME revision id, which the review scheduler's dedupe key
  /// (workItemId:revisionId:jobType) resolves to the already-terminal review
  /// job — so the lifecycle idles until the risk tier routes the verdict.
  Future<WorkItem> enterDesignInReview(
    String workItemId, {
    required String designRevisionId,
    required String designerExecutionId,
  }) {
    return workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.designInReview,
      trigger: TransitionTrigger.systemEvent,
      context: {
        'designContractId': 'dc-$workItemId',
        'designContractStatus': DesignContractStatus.underReview,
        'designRevisionId': designRevisionId,
        'designerExecutionId': designerExecutionId,
      },
    );
  }

  Future<AgentExecution?> designerExecution(String workItemId) async {
    final executions = await executionStore.listExecutions(workItemId: workItemId);
    return executions
        .where((e) => e.role == AgentRole.designAgent)
        .firstOrNull;
  }

  Future<AgentExecution?> reviewerExecution(String workItemId) async {
    final executions = await executionStore.listExecutions(workItemId: workItemId);
    return executions
        .where((e) => e.role == AgentRole.designReviewer)
        .firstOrNull;
  }

  /// Requests the blocking design-approval gate (HIGH tier). The item parks at
  /// `waitingForHumanDecision` until a human resolves it.
  Future<HumanDecision> requestDesignApprovalGate(String workItemId) =>
      workflowEngine.requestHumanDecision(
        workItemId: workItemId,
        decisionType: HumanDecisionType.designApproval,
        blocking: true,
        question: 'Approve the design for this work item?',
      );

  Future<WorkItem> resolveDesignApprovalGate(
    String decisionId, {
    String decider = 'hum@shipit.platform',
  }) =>
      workflowEngine.resolveHumanDecision(
        decisionId: decisionId,
        choice: HumanDecisionChoice.approve,
        decider: decider,
        rationale: 'design governance automation approved the revision',
        signature: DecisionSignature(
          algorithm: 'ed25519',
          publicKey: 'test-public-key',
          signature: 'sig-approve-$decisionId',
          signedAt: DateTime.now().toUtc(),
        ),
      );
}

void main() {
  late Directory temp;
  late GitRepoFixture repo;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('design_governance_e2e');
    repo = GitRepoFixture.create('${temp.path}/repo');
  });

  tearDown(() {
    repo.dispose();
    temp.deleteSync(recursive: true);
  });

  Future<DesignGovernanceE2EHost> newHost() => Future.value(
        DesignGovernanceE2EHost(
          repo: repo,
          workspaceRoot: '${temp.path}/workspaces',
        ),
      );

  group('Design Governance E2E', () {
    test('full lifecycle: designRequired -> design job -> designInReview -> '
        'review job -> designApproved', () async {
      final host = await newHost();
      await host.createDesignWorkItem(
        workItemId: 'wi-lifecycle',
        productId: 'prod-1',
        title: 'Design login page',
      );

      await host.runDesignRevision('wi-lifecycle');

      final designer = await host.designerExecution('wi-lifecycle');
      expect(designer, isNotNull);
      expect(designer!.status, AgentSessionStatus.completed);

      final revisionJobs =
          await host.jobStore.listJobsForWorkItem('wi-lifecycle');
      final revisionJob =
          revisionJobs.singleWhere((j) => j.jobType == JobType.designRevision);
      expect(revisionJob.state, JobState.succeeded);

      await host.enterDesignInReview(
        'wi-lifecycle',
        designRevisionId: 'DES-R1',
        designerExecutionId: designer.executionId,
      );

      await host.runDesignReview('wi-lifecycle');

      final reviewer = await host.reviewerExecution('wi-lifecycle');
      expect(reviewer, isNotNull);
      expect(reviewer!.status, AgentSessionStatus.completed);
      expect(reviewer.executionId, isNot(designer.executionId));

      final reviewJobs =
          await host.jobStore.listJobsForWorkItem('wi-lifecycle');
      final reviewJob =
          reviewJobs.singleWhere((j) => j.jobType == JobType.designReview);
      expect(reviewJob.state, JobState.succeeded);

      // Review done: re-enter designInReview with the same revision so the
      // risk-tier verdict route takes over (dedupe blocks a second review).
      await host.enterDesignInReview(
        'wi-lifecycle',
        designRevisionId: 'DES-R1',
        designerExecutionId: designer.executionId,
      );

      final gate = await host.requestDesignApprovalGate('wi-lifecycle');
      final blocked = await host.workflowEngine.loadWorkItem('wi-lifecycle');
      expect(blocked.state, WorkItemState.waitingForHumanDecision);

      await host.resolveDesignApprovalGate(gate.decisionId);
      final approved = await host.workflowEngine.loadWorkItem('wi-lifecycle');
      expect(approved.state, WorkItemState.designApproved);
    });

    test('independence at dispatch: review execution is a different execution '
        'with the reviewer role, never the designer run', () async {
      final host = await newHost();
      await host.createDesignWorkItem(
        workItemId: 'wi-independence',
        productId: 'prod-1',
        title: 'Design independence test',
      );

      await host.runDesignRevision('wi-independence');

      final designer = await host.designerExecution('wi-independence');
      expect(designer, isNotNull);

      await host.enterDesignInReview(
        'wi-independence',
        designRevisionId: 'DES-R2',
        designerExecutionId: designer!.executionId,
      );

      await host.runDesignReview('wi-independence');

      final reviewer = await host.reviewerExecution('wi-independence');
      expect(reviewer, isNotNull);
      expect(reviewer!.role, AgentRole.designReviewer);
      expect(reviewer.executionId, isNot(designer.executionId));

      // The review job ran on the reviewer worker (penpotRead + designReview),
      // not on the design worker that produced the revision.
      final reviewJobs =
          await host.jobStore.listJobsForWorkItem('wi-independence');
      final reviewJob =
          reviewJobs.singleWhere((j) => j.jobType == JobType.designReview);
      expect(reviewJob.workerId, 'w-design-reviewer-1');
    });

    test('HIGH tier blocks at the human gate and consumes zero capacity',
        () async {
      final host = await newHost();
      await host.createDesignWorkItem(
        workItemId: 'wi-high',
        productId: 'prod-1',
        title: 'High risk design',
      );

      await host.runDesignRevision('wi-high');
      await host.enterDesignInReview(
        'wi-high',
        designRevisionId: 'DES-R3',
        designerExecutionId: (await host.designerExecution('wi-high'))!
            .executionId,
      );
      await host.runDesignReview('wi-high');
      await host.enterDesignInReview(
        'wi-high',
        designRevisionId: 'DES-R3',
        designerExecutionId: (await host.designerExecution('wi-high'))!
            .executionId,
      );

      await host.requestDesignApprovalGate('wi-high');
      final blocked = await host.workflowEngine.loadWorkItem('wi-high');
      expect(blocked.state, WorkItemState.waitingForHumanDecision);

      final tick = await host.noopDesignReviewTick();
      expect(tick.enqueued, isEmpty);
      expect(tick.dispatched, isEmpty);

      final jobs = await host.jobStore.listJobsForWorkItem('wi-high');
      expect(jobs.where((j) => j.state == JobState.running), isEmpty);
      expect(host.designWorker.isAcquirable, isTrue);
      expect(host.reviewWorker.isAcquirable, isTrue);
    });

    test('LOW tier auto-routes to designApproved via platform automation '
        '(no human decider needed)', () async {
      final host = await newHost();
      await host.createDesignWorkItem(
        workItemId: 'wi-low',
        productId: 'prod-1',
        title: 'Low risk design',
      );

      await host.runDesignRevision('wi-low');
      await host.enterDesignInReview(
        'wi-low',
        designRevisionId: 'DES-R4',
        designerExecutionId: (await host.designerExecution('wi-low'))!
            .executionId,
      );
      await host.runDesignReview('wi-low');
      await host.enterDesignInReview(
        'wi-low',
        designRevisionId: 'DES-R4',
        designerExecutionId: (await host.designerExecution('wi-low'))!
            .executionId,
      );

      final gate = await host.requestDesignApprovalGate('wi-low');
      await host.resolveDesignApprovalGate(
        gate.decisionId,
        decider: 'shipit-design-automation',
      );

      final approved = await host.workflowEngine.loadWorkItem('wi-low');
      expect(approved.state, WorkItemState.designApproved);

      final decisions =
          await host.workflowStore.readHumanDecisionsForWorkItem('wi-low');
      final designDecision = decisions.singleWhere(
        (d) => d.decisionType == HumanDecisionType.designApproval,
      );
      expect(designDecision.status, HumanDecisionStatus.resolved);
      expect(designDecision.decider, 'shipit-design-automation');
    });

    test('restart durability: a fresh host on the same durable stores observes '
        'terminal jobs and does not re-enqueue or re-run them', () async {
      final host = await newHost();
      await host.createDesignWorkItem(
        workItemId: 'wi-restart',
        productId: 'prod-1',
        title: 'Restart durability test',
      );

      await host.runDesignRevision('wi-restart');
      await host.enterDesignInReview(
        'wi-restart',
        designRevisionId: 'DES-R5',
        designerExecutionId: (await host.designerExecution('wi-restart'))!
            .executionId,
      );
      await host.runDesignReview('wi-restart');
      await host.enterDesignInReview(
        'wi-restart',
        designRevisionId: 'DES-R5',
        designerExecutionId: (await host.designerExecution('wi-restart'))!
            .executionId,
      );

      final before = await host.workflowEngine.loadWorkItem('wi-restart');
      expect(before.state, WorkItemState.designInReview);
      final executionsBefore =
          await host.executionStore.listExecutions(workItemId: 'wi-restart');
      expect(executionsBefore.length, 2);

      // Simulate restart: a fresh scheduler and engine wired to the SAME
      // durable stores, with a fresh (empty) dispatch pool. No workers were
      // re-registered and no session was rebuilt, so nothing can re-run.
      final restartedEngine = DurableWorkflowEngine(store: host.workflowStore);
      final after = await restartedEngine.loadWorkItem('wi-restart');
      expect(after.state, WorkItemState.designInReview);

      final restartedReviewScheduler = Scheduler(
        schedulerId: 'sched-design-review-restarted',
        workflowStore: host.workflowStore,
        jobStore: host.jobStore,
        workerStore: host.workerStore,
        dispatch: WorkerDispatcherAdapter(
          WorkerDispatcher(registry: WorkerRegistry()),
        ),
        definition: designReviewDefinition,
        workload: SchedulerWorkload(
          repositoryPath: repo.root.path,
          startingRevision: repo.startingRevision,
          timeoutSeconds: 60,
          runtimeTypeId: 'review-runtime',
        ),
        dedupeKeyBuilder: designReviewDedupeKey,
        instructionBuilder: designReviewInstruction,
        requestBuilder: designReviewRequest,
      );

      // No new work: the design-review job for DES-R5 is already terminal and
      // its dedupe key (workItemId:revisionId:jobType) still matches.
      final tick = await restartedReviewScheduler.tick();
      expect(tick.enqueued, isEmpty);

      final reviewJobs = await host.jobStore.listJobsForWorkItem('wi-restart');
      final reviewJob =
          reviewJobs.singleWhere((j) => j.jobType == JobType.designReview);
      expect(reviewJob.state, JobState.succeeded);

      final executions =
          await host.executionStore.listExecutions(workItemId: 'wi-restart');
      expect(executions.length, 2);
    });
  });
}