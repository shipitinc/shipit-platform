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
import 'package:control_plane_server/server.dart';

/// Runs a read-only git command in [repoPath] under the fixture's hermetic
/// environment (no global/system git config), returning trimmed stdout.
///
/// Only ever called with plumbing that cannot mutate the repository, so the
/// assertions below inspect the real object database instead of re-deriving it
/// from in-memory fixtures.
String gitOut(String repoPath, List<String> args) {
  final result = Process.runSync(
    'git',
    ['-C', repoPath, ...args],
    environment: {
      ...Platform.environment,
      'GIT_CONFIG_GLOBAL': '/dev/null',
      'GIT_CONFIG_SYSTEM': '/dev/null',
    },
  );
  if (result.exitCode != 0) {
    throw StateError(
      'git ${args.join(' ')} failed (${result.exitCode}): ${result.stderr}',
    );
  }
  return result.stdout.toString().trim();
}

/// In-memory end-to-end host for the automated engineering-review chain:
/// implementation -> `agentCompleted` -> engineering review -> human gate ->
/// `qaInProgress`. Real workflow engine, real store, real coordinator and real
/// workers; the agents are gated fakes so the test is deterministic.
class EngineeringReviewE2EHost {
  /// [resolveReviewWorkload] defaults to TRUE because that is what production
  /// does: the composition root always wires the real
  /// `engineeringReviewWorkloadResolver`, so a reviewer never sees the
  /// construction-time workload. The inert workload is a test-only deviation,
  /// and a deviation that must be spelled out at the call site can never be
  /// what a test gets by forgetting an argument — which is exactly how the
  /// success path ended up running the resolver only on the failure path.
  EngineeringReviewE2EHost({
    required GitRepoFixture repo,
    required String workspaceRoot,
    bool writeImplementerArtifact = true,
    bool resolveReviewWorkload = true,
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
    reviewSession = DesignGateAgentSession(
      executionId: 'agx-eng-review',
      // THE REVIEWER ANSWERS. This session used to emit `{}` — no structured
      // result at all — and the gate read the absence through a
      // `changes_required` default and raised a decision saying the review had
      // found problems. The chain then approved it, so the fabrication was
      // invisible here: this test passed while the operator-facing wording was a
      // lie. The reviewer now says what it found, and step 3 below asserts that
      // verdict is the one that reaches the decision.
      structuredResult: {'verdict': ReviewVerdict.approved.wire},
    );
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
              // The one production budget, named so the resolver holds no literal of
              // its own. See `AgentExecutionBudgets` — PROVISIONAL.
              timeoutSeconds: AgentExecutionBudgets.engineeringReviewSeconds,
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

  /// Every durable [WorkerExecution] the real [LocalWorker] recorded for
  /// [workItemId] — read back from the store, not reconstructed by the test.
  Future<List<WorkerExecution>> workerExecutionsFor(String workItemId) async =>
      (await workerStore.listWorkerExecutions())
          .where((e) => e.workItemId == workItemId)
          .toList();
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
      // The REAL resolver is wired in (stated explicitly here, not inherited
      // from a default): this is the success path, and the whole point of the
      // resolver is that a reviewer is dispatched against the revision the
      // IMPLEMENTER produced. Steps 1-3 below assert that end to end.
      final host = EngineeringReviewE2EHost(
        repo: repo,
        workspaceRoot: '${temp.path}/workspaces',
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

      // 1. The implementer runs to completion -> agentCompleted, and its
      //    execution id is recorded as the producer identity (M2).
      await host.runImplementer();

      final afterImpl = await host.workflowEngine.loadWorkItem('wi-er');
      expect(afterImpl.state, WorkItemState.agentCompleted);

      // 1a. THE IDENTITY JOIN, proven against a real ExecutionCoordinator +
      //     LocalWorker round trip rather than hand-built fixtures. The
      //     coordinator stamped `producerActorId` from the execution it settled,
      //     and LocalWorker recorded that same id on the worker execution as
      //     `agentExecutionId` (itself `'agx-$workerExecutionId'`). The
      //     resolver anchors on exactly this equality, so if any one of the
      //     three sides disagreed the reviewer below could not be resolved.
      final producerActorId = afterImpl.metadata?['producerActorId'];
      expect(producerActorId, isA<String>());
      expect((producerActorId as String).isNotEmpty, isTrue);

      final implExecutions = (await host.workerExecutionsFor(
        'wi-er',
      )).where((e) => e.agentExecutionId == producerActorId).toList();
      expect(
        implExecutions,
        hasLength(1),
        reason:
            'exactly one worker execution must carry producerActorId '
            '$producerActorId, else the resolver refuses to dispatch',
      );

      final implExecution = implExecutions.single;
      expect(
        implExecution.agentExecutionId,
        'agx-${implExecution.workerExecutionId}',
        reason:
            'LocalWorker derives the agent execution id from the worker '
            'execution id; the resolver depends on that exact form',
      );
      expect(
        implExecution.requiredCapabilities,
        isNot(contains(WorkerCapability.engineeringReview)),
        reason:
            'the resolver filters reviewer-role executions out of the '
            'producer candidates',
      );
      expect(implExecution.status, WorkerExecutionStatus.executedPass);

      // 1b. The implementer really produced an artifact, so there IS something
      //     for the resolver to resolve. Asserted rather than assumed.
      final produced = implExecution.endingRevision;
      expect(
        produced,
        isNotNull,
        reason:
            'the implementer wrote lib/calculator.dart and LocalWorker '
            'commits it before cleanup removes the worktree',
      );
      expect(
        produced,
        isNot(repo.startingRevision),
        reason:
            'a commit equal to the requested starting revision means '
            'nothing was produced and the resolver fails closed',
      );
      expect(implExecution.requestedStartingRevision, repo.startingRevision);

      // 1c. The produced revision is DURABLE and carries the implemented code:
      //     reachable on shipit/impl/wi-er, with the implemented calculator in
      //     its tree rather than the fixture's UnimplementedError baseline.
      expect(
        gitOut(repo.root.path, ['rev-parse', 'shipit/impl/wi-er']),
        produced,
      );
      expect(
        gitOut(repo.root.path, ['show', '$produced:lib/calculator.dart']),
        'int add(int a, int b) => a + b;',
      );

      // 2. The review scheduler enqueues and runs the reviewer, moving the item
      //    to reviewInProgress (B1 + B2).
      final reviewTick = await host.runEngineeringReview();

      // 2a. The resolver RESOLVED. Had it returned null the job would have been
      //     reported as blocked and nothing would have been dispatched at all.
      expect(
        reviewTick.blockedArtifactMissing,
        isEmpty,
        reason:
            'the real resolver refused to dispatch; the reviewer would '
            'have run against a revision it could not vouch for',
      );
      expect(reviewTick.dispatched, isNotEmpty);

      // 2b. The reviewer was dispatched against the IMPLEMENTER's commit, not
      //     the construction-time workload. Its execution carries the resolved
      //     revision as its requested starting revision, and that revision is
      //     demonstrably NOT the repository's construction-time revision.
      final reviewExecutions = (await host.workerExecutionsFor('wi-er'))
          .where(
            (e) => e.requiredCapabilities.contains(
              WorkerCapability.engineeringReview,
            ),
          )
          .toList();
      expect(reviewExecutions, hasLength(1));

      final reviewExecution = reviewExecutions.single;
      expect(reviewExecution.requestedStartingRevision, produced);
      expect(
        reviewExecution.requestedStartingRevision,
        isNot(repo.startingRevision),
      );
      expect(
        reviewExecution.agentExecutionId,
        isNot(producerActorId),
        reason:
            'the reviewer must be a distinct execution from the producer, '
            'or actorIsNotSelf() would be vacuous',
      );
      expect(reviewExecution.status, WorkerExecutionStatus.executedPass);

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
      expect(
        decision.recommendation,
        'APPROVE',
        reason:
            'and it is APPROVE because the reviewer said APPROVE. Before the '
            'reviewer had a verdict at all this recommendation was '
            'CHANGES_REQUIRED with the opposite meaning, produced by a default '
            'rather than by a reviewer.',
      );
      expect(decision.metadata?['reviewVerdict'], 'approved');

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
    'fails closed: a review job with no resolvable artifact is not dispatched, '
    'and review STANDS DOWN so the implementation inflow can route it',
    () async {
      // The implementer completes WITHOUT producing a change, so no artifact
      // commit exists (`endingRevision == startingRevision`). The review
      // scheduler uses the REAL resolver, so it must refuse to dispatch.
      //
      // And because `producedCommitFor` — the same function that resolver
      // calls — says nothing was committed, `engineeringReviewMissingArtifact`
      // must NOT park the item. There is nothing to review, so a human gate is
      // the wrong place for it: the decision's only answers are rework and
      // reject, and the implementation lane can simply do the work.
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

      await engineeringReviewMissingArtifact(
        workflowEngine: host.workflowEngine,
        executionStore: host.executionStore,
        workerStore: host.workerStore,
        job: job,
        logger: (_, __) {},
      );

      final stoodDown = await host.workflowEngine.loadWorkItem('wi-er');
      expect(
        stoodDown.state,
        WorkItemState.agentCompleted,
        reason:
            'the implementation lane\'s completion inflow owns this item. '
            'Parking it here used to pre-empt that inflow purely by `await` '
            'order, and the item then sat at a human gate whose only answers '
            'are the wrong ones.',
      );
      expect(stoodDown.blockingHumanDecisionId, isNull);

      // Idempotent in the other direction too: handling the same blocked job
      // again is still a no-op, and still raises nothing.
      await engineeringReviewMissingArtifact(
        workflowEngine: host.workflowEngine,
        executionStore: host.executionStore,
        workerStore: host.workerStore,
        job: job,
        logger: (_, __) {},
      );
      expect(
        (await host.workflowEngine.loadWorkItem(
          'wi-er',
        )).blockingHumanDecisionId,
        isNull,
      );
    },
  );

  test(
    'a re-work marker at its RETIRED bound does not raise a decision either — '
    'it stands down like any other no-artifact item',
    () async {
      // THIS USED TO ASSERT THE OPPOSITE.
      //
      // It was `'fails closed: once the re-work budget is spent, the missing
      // artifact DOES raise a blocking engineeringReview decision'`, and it
      // seeded `triageAttempt: maxImplementationInflows` and required
      // `waitingForHumanDecision` plus a blocking `engineeringReview` decision
      // with `missingArtifact: true`.
      //
      // Decision `92d567e3-da03-4c43-99f4-e3726472f0ab` (ARCHITECTURE,
      // RESOLVED) answered `RETRY_LIMIT -> REMOVE`. There is no budget to be
      // spent any more, so the premise of this test no longer exists, and the
      // expectation encoded a strand: it required a human question about an
      // item the implementation lane routes on its own, unbounded. The decision
      // it would raise still offers only `rework` and `reject`, and neither
      // reaches an implementer.
      //
      // The seed is kept, as a literal, because the point is precisely that the
      // number no longer decides anything.
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
      for (final state in const [
        WorkItemState.planning,
        WorkItemState.planned,
        WorkItemState.designNotRequired,
      ]) {
        await host.workflowEngine.transition(
          workItemId: 'wi-er',
          to: state,
          trigger: TransitionTrigger.systemEvent,
          context: const {'featureRef': 'feature/calc'},
        );
      }

      await host.runImplementer();

      // The value `maxImplementationInflows` used to hold. The constant is gone;
      // the number is data, and nothing in this gate compares against it.
      final item = await host.workflowStore.readWorkItem('wi-er');
      await host.workflowStore.saveWorkItem(
        item.copyWith(
          metadata: {
            ...?item.metadata,
            DurableWorkflowEngine.triageAttemptMetadataKey: 3,
          },
        ),
      );

      final tick = await host.reviewScheduler.tick();
      expect(tick.blockedArtifactMissing, hasLength(1));
      final job = await host.jobStore.readJob(
        tick.blockedArtifactMissing.single,
      );
      expect(job, isNotNull);

      // Captured, because "nothing was raised" and "the handler never ran" are
      // different claims and only one of them is what the decision asked for.
      final logs = <String>[];
      await engineeringReviewMissingArtifact(
        workflowEngine: host.workflowEngine,
        executionStore: host.executionStore,
        workerStore: host.workerStore,
        job: job!,
        logger: (message, _) => logs.add(message),
      );

      expect(
        logs,
        contains('engineering-review-missing-artifact-stands-down'),
        reason:
            'the marker is the number the bound used to hold, and the answer is '
            'the same as for any other no-artifact producer: stand down',
      );
      expect(
        logs,
        isNot(contains('engineering-review-missing-artifact-parking')),
        reason:
            'and it did not park. `parking` is the log line that put the four QA '
            'defects of 2026-10-16 in front of an operator whose only answers '
            'were rework and reject',
      );

      final stoodDown = await host.workflowEngine.loadWorkItem('wi-er');
      expect(
        stoodDown.blockingHumanDecisionId,
        isNull,
        reason:
            'no `engineeringReview` decision exists, so nothing is waiting on a '
            'person for an item the platform can still route itself',
      );
      expect(
        stoodDown.state,
        isNot(WorkItemState.waitingForHumanDecision),
        reason: 'and the item was never moved into the parking state either',
      );

      // Idempotent: handling the same blocked job again is still a no-op, and
      // still raises nothing. Before this change the idempotency assertion was
      // that the SAME parked decision stayed in place; now it is that no
      // decision appears at all, which is the stronger statement of the same
      // property.
      await engineeringReviewMissingArtifact(
        workflowEngine: host.workflowEngine,
        executionStore: host.executionStore,
        workerStore: host.workerStore,
        job: job,
        logger: (message, _) => logs.add(message),
      );
      final stoodDownAgain = await host.workflowEngine.loadWorkItem('wi-er');
      expect(stoodDownAgain.blockingHumanDecisionId, isNull);
    },
  );
}
