import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_store/workflow_store.dart';
import 'package:worker_runtime/worker_runtime.dart';

import 'package:control_plane_server/src/review/engineering_review_gate.dart';

import 'support/design_gate_agents.dart';
import 'support/git_repo_fixture.dart';

/// In-memory end-to-end host for the automated engineering-review chain:
/// implementation -> `agentCompleted` -> engineering review -> human gate ->
/// `qaInProgress`. Real workflow engine, real store, real coordinator and real
/// workers; the agents are gated fakes so the test is deterministic.
class EngineeringReviewE2EHost {
  EngineeringReviewE2EHost({
    required GitRepoFixture repo,
    required String workspaceRoot,
    bool writeImplementerArtifact = true,
    bool resolveReviewWorkload = false,
  }) {
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();
    workerStore = InMemoryWorkerStore();
    jobStore = InMemoryJobStore();

    implSession = DesignGateAgentSession(
      executionId: 'agx-impl',
      writeArtifact: writeImplementerArtifact,
    );
    reviewSession = DesignGateAgentSession(executionId: 'agx-eng-review');
    runtime = AgentRuntime(
      registry: AgentAdapterRegistry()
        ..register(
          DesignGateAgentAdapter(implSession, providerId: 'impl-runtime'),
        )
        ..register(
          DesignGateAgentAdapter(
            reviewSession,
            providerId: 'eng-review-runtime',
          ),
        ),
    );

    coordinator = ExecutionCoordinator(
      store: executionStore,
      workflowEngine: workflowEngine,
      runtime: runtime,
    );

    implWorker = LocalWorker(
      workerId: 'w-impl',
      poolId: 'impl-pool',
      capabilities: defaultImplementFeatureDefinition.requiredCapabilities,
      workspaceManager: GitWorktreeWorkspaceManager(
        workspaceRoot: workspaceRoot,
      ),
      executionDriver: CoordinatorAgentExecutionDriver(coordinator),
      workerStore: workerStore,
      platform: Platform.operatingSystem,
    );
    reviewWorker = LocalWorker(
      workerId: 'w-eng-review',
      poolId: 'eng-review-pool',
      capabilities: engineeringReviewDefinition.requiredCapabilities,
      workspaceManager: GitWorktreeWorkspaceManager(
        workspaceRoot: workspaceRoot,
      ),
      executionDriver: CoordinatorAgentExecutionDriver(coordinator),
      workerStore: workerStore,
      platform: Platform.operatingSystem,
    );

    final workerRegistry = WorkerRegistry()
      ..register(implWorker)
      ..register(reviewWorker);
    final dispatch = WorkerDispatcherAdapter(
      WorkerDispatcher(registry: workerRegistry),
    );

    implScheduler = Scheduler(
      schedulerId: 'sched-impl',
      workflowStore: workflowStore,
      jobStore: jobStore,
      workerStore: workerStore,
      dispatch: dispatch,
      definition: defaultImplementFeatureDefinition,
      workload: SchedulerWorkload(
        repositoryPath: repo.root.path,
        startingRevision: repo.startingRevision,
        timeoutSeconds: 60,
        runtimeTypeId: 'impl-runtime',
      ),
    );

    reviewScheduler = Scheduler(
      schedulerId: 'sched-eng-review',
      workflowStore: workflowStore,
      jobStore: jobStore,
      workerStore: workerStore,
      dispatch: dispatch,
      definition: engineeringReviewDefinition,
      workloadResolver: resolveReviewWorkload
          ? engineeringReviewWorkloadResolver(
              workerStore: workerStore,
              runtimeTypeId: 'eng-review-runtime',
            )
          : null,
      workload: SchedulerWorkload(
        repositoryPath: repo.root.path,
        startingRevision: repo.startingRevision,
        timeoutSeconds: 60,
        runtimeTypeId: 'eng-review-runtime',
      ),
      dedupeKeyBuilder: engineeringReviewDedupeKey,
      instructionBuilder: engineeringReviewInstruction,
      requestBuilder: engineeringReviewRequest,
    );
  }

  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;
  late InMemoryWorkerStore workerStore;
  late InMemoryJobStore jobStore;
  late DesignGateAgentSession implSession;
  late DesignGateAgentSession reviewSession;
  late AgentRuntime runtime;
  late ExecutionCoordinator coordinator;
  late LocalWorker implWorker;
  late LocalWorker reviewWorker;
  late Scheduler implScheduler;
  late Scheduler reviewScheduler;

  Future<SchedulerTickResult> runImplementer() async {
    final tick = implScheduler.tick();
    await implSession.awaitingGate;
    implSession.release();
    return tick;
  }

  Future<SchedulerTickResult> runEngineeringReview() async {
    final tick = reviewScheduler.tick();
    await reviewSession.awaitingGate;
    reviewSession.release();
    return tick;
  }

  /// The terminal engineering-review job for [workItemId].
  Future<Job> reviewJob(String workItemId) async {
    final jobs = await jobStore.listJobsForWorkItem(workItemId);
    return jobs.singleWhere((j) => j.jobType == JobType.engineeringReview);
  }

  Future<void> drainGate(Job job) => engineeringReviewTickHandler(
    workflowEngine: workflowEngine,
    executionStore: executionStore,
    logger: (_, _) {},
  )(job);
}

void main() {
  late Directory temp;
  late GitRepoFixture repo;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('engineering_review_e2e');
    repo = GitRepoFixture.create(temp.path);
  });

  tearDown(() {
    repo.dispose();
    temp.deleteSync(recursive: true);
  });

  test(
    'engineering review chain: agentCompleted -> reviewInProgress -> human gate '
    '-> approve -> qaInProgress',
    () async {
      final host = EngineeringReviewE2EHost(
        repo: repo,
        workspaceRoot: '${temp.path}/workspaces',
      );

      await host.workflowEngine.createWorkItem(
        workItemId: 'wi-er',
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Implement calculator add',
        description: 'Implement the calculator add function for the contract',
        qaContractId: 'qa-1',
        featureRef: 'feature/calc',
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-er',
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-er',
        to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent,
        context: const {'featureRef': 'feature/calc'},
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-er',
        to: WorkItemState.designNotRequired,
        trigger: TransitionTrigger.systemEvent,
      );

      // 1. The implementer runs to completion -> agentCompleted, and its
      //    execution id is recorded as the producer identity (M2).
      await host.runImplementer();

      final afterImpl = await host.workflowEngine.loadWorkItem('wi-er');
      expect(afterImpl.state, WorkItemState.agentCompleted);
      expect(afterImpl.metadata?['producerActorId'], isNotNull);

      // 2. The review scheduler enqueues and runs the reviewer, moving the item
      //    to reviewInProgress (B1 + B2).
      await host.runEngineeringReview();

      final inReview = await host.workflowEngine.loadWorkItem('wi-er');
      expect(inReview.state, WorkItemState.reviewInProgress);

      final job = await host.reviewJob('wi-er');
      expect(job.state, JobState.succeeded);

      // 3. The gate handler raises the blocking engineeringReview decision.
      await host.drainGate(job);

      final atGate = await host.workflowEngine.loadWorkItem('wi-er');
      expect(atGate.state, WorkItemState.waitingForHumanDecision);
      final decisionId = atGate.blockingHumanDecisionId;
      expect(decisionId, isNotNull);
      final decision = await host.workflowStore.readHumanDecision(decisionId!);
      expect(decision.decisionType, HumanDecisionType.engineeringReview);
      expect(decision.blocking, isTrue);

      // 4. A human approves -> reviewApproved -> qaInProgress.
      final approved = await host.workflowEngine.resolveHumanDecision(
        decisionId: decisionId,
        choice: HumanDecisionChoice.approve,
        decider: 'hum@shipit.platform',
        rationale: 'reviewed and independent',
        signature: DecisionSignature(
          algorithm: 'ed25519',
          publicKey: 'test-public-key',
          signature: 'sig-approve',
          signedAt: DateTime.now().toUtc(),
        ),
      );
      expect(approved.state, WorkItemState.reviewApproved);

      final afterQa = await host.workflowEngine.transition(
        workItemId: 'wi-er',
        to: WorkItemState.qaInProgress,
        trigger: TransitionTrigger.systemEvent,
        context: const {'qaContractId': 'qa-1'},
      );
      expect(afterQa.state, WorkItemState.qaInProgress);
    },
  );

  test(
    'fails closed: when no implementation artifact is resolvable the review '
    'job is not dispatched and a blocking engineeringReview decision is raised',
    () async {
      // The implementer completes WITHOUT producing a change, so no artifact
      // commit exists (`endingRevision == startingRevision`). The review
      // scheduler uses the REAL resolver, so it must refuse to dispatch.
      final host = EngineeringReviewE2EHost(
        repo: repo,
        workspaceRoot: '${temp.path}/workspaces',
        writeImplementerArtifact: false,
        resolveReviewWorkload: true,
      );

      await host.workflowEngine.createWorkItem(
        workItemId: 'wi-er',
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Implement calculator add',
        description: 'Implement the calculator add function for the contract',
        qaContractId: 'qa-1',
        featureRef: 'feature/calc',
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-er',
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-er',
        to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent,
        context: const {'featureRef': 'feature/calc'},
      );
      await host.workflowEngine.transition(
        workItemId: 'wi-er',
        to: WorkItemState.designNotRequired,
        trigger: TransitionTrigger.systemEvent,
      );

      await host.runImplementer();
      final afterImpl = await host.workflowEngine.loadWorkItem('wi-er');
      expect(afterImpl.state, WorkItemState.agentCompleted);

      // The resolver cannot vouch for an artifact, so the reviewer is NEVER
      // dispatched and the job is reported blocked rather than run.
      final tick = await host.reviewScheduler.tick();
      expect(tick.blockedArtifactMissing, hasLength(1));
      expect(tick.dispatched, isEmpty);

      final jobId = tick.blockedArtifactMissing.single;
      final job = await host.jobStore.readJob(jobId);
      expect(job, isNotNull);
      expect(job!.jobType, JobType.engineeringReview);

      // The drain turns the blocked job into a blocking human decision.
      await engineeringReviewMissingArtifact(
        workflowEngine: host.workflowEngine,
        executionStore: host.executionStore,
        job: job,
        logger: (_, __) {},
      );

      final parked = await host.workflowEngine.loadWorkItem('wi-er');
      expect(parked.state, WorkItemState.waitingForHumanDecision);
      final decisionId = parked.blockingHumanDecisionId;
      expect(decisionId, isNotNull);
      final decision = await host.workflowStore.readHumanDecision(decisionId!);
      expect(decision.decisionType, HumanDecisionType.engineeringReview);
      expect(decision.blocking, isTrue);
      expect(decision.metadata?['missingArtifact'], isTrue);

      // Idempotent: handling the same blocked job again is a no-op that leaves
      // the SAME parked decision in place (the handler short-circuits on the
      // already-parked state, so a retry cannot raise a second decision).
      await engineeringReviewMissingArtifact(
        workflowEngine: host.workflowEngine,
        executionStore: host.executionStore,
        job: job,
        logger: (_, __) {},
      );
      final parkedAgain = await host.workflowEngine.loadWorkItem('wi-er');
      expect(parkedAgain.state, WorkItemState.waitingForHumanDecision);
      expect(parkedAgain.blockingHumanDecisionId, decisionId);
    },
  );
}
