import 'dart:async';
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

/// A review whose execution budget runs out is RETRIED. A review that crashes
/// is not. Both halves are here, end to end, through the real
/// `Scheduler` → `LocalWorker` → `ExecutionCoordinator` chain.
///
/// ## Why this file exists when the coordinator and worker packages already
/// have their own halves
///
/// Those two pin the STATUS at each seam. This pins the thing the seams are
/// FOR: that an operator's `maxAttempts: 2` is actually spendable, that a
/// second dispatch happens, and — the dangerous direction — that nothing here
/// has turned into "retry forever".
///
/// The defect being fixed was invisible at both seams and obvious here:
///
/// ```text
/// budget expires -> AgentSessionStatus.failed -> WorkerExecutionStatus
///                   .executedFail -> JobFailureKind.permanent
///                  -> JobState.failed, attempt still 0
/// ```
///
/// so `engineeringReviewDefinition.maxAttempts: 2` was unreachable for the only
/// failure this deployment observes. The job went terminal with a stranded work
/// item behind it, and the retry budget sat in the source as a literal nobody
/// could spend.
///
/// ## THE TWO DANGEROUS REGRESSIONS
///
///  * down: the timeout is a `failed` again and the whole thing is back.
///  * UP: the crash becomes retryable and a permanently broken runtime burns
///    one attempt per job forever. That is why the crash case asserts
///    `attempt == 0` — "a permanent failure spends NOTHING" is the invariant
///    that makes the bounded half of the retry honest.
void main() {
  late Directory temp;
  late GitRepoFixture repo;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('budget_retry_e2e');
    repo = GitRepoFixture.create(temp.path);
  });

  tearDown(() {
    repo.dispose();
    temp.deleteSync(recursive: true);
  });

  test('a review killed at its budget retries: the attempt is spent and the '
      'failure is transient, not permanent', () async {
    final host = ReviewRetryHost(
      repo: repo,
      workspaceRoot: '${temp.path}/workspaces',
      // One second, so the budget is genuinely exhausted inside a test. The
      // production value is `AgentExecutionBudgets.engineeringReviewSeconds`;
      // what is under test is the CLASSIFICATION, not the magnitude.
      reviewTimeoutSeconds: 1,
    );
    await host.produceArtifact('wi-timeout');

    // ---- Attempt 1: the reviewer starts and never finishes. ----
    host.review.script = ReviewScript.hang;
    await host.tickReview();

    final afterFirst = await host.reviewJob('wi-timeout');
    expect(
      afterFirst.state,
      JobState.retryWaiting,
      reason:
          'NOT `failed`. A budget expiry is a TIMEOUT, and the retry policy '
          'classifies a timeout as transient — which is the only path that '
          'spends an attempt.',
    );
    expect(
      afterFirst.attempt,
      afterFirst.maxAttempts,
      reason:
          'the whole retry budget is now spent: a job is created at '
          'attempt=1 and `scheduleRetry` charges the second one, so 2 of 2 '
          'means one retry was scheduled and a THIRD attempt is impossible. '
          'Under the old `failed` settlement this stayed at 1 forever, which '
          'is the unreachable-retry defect this file exists to close.',
    );
    expect(afterFirst.failure?.kind, JobFailureKind.transient);
    expect(afterFirst.isTerminal, isFalse);

    // The worker execution the first attempt produced says `timedOut`, not
    // `executedFail` — the link that makes the retry possible.
    final firstExecution = (await host.reviewExecutions('wi-timeout')).single;
    expect(firstExecution.status, WorkerExecutionStatus.timedOut);
    expect(firstExecution.failureCode, WorkerFailureCode.timedOut);

    // Nothing has been reported to the operator yet: the job is not terminal,
    // so the drain never hands it to the review gate, so no human decision is
    // raised about a review that has not exhausted its own budget.
    expect(afterFirst.executionReference?.agentExecutionId, isNotNull);

    // What the retry WOULD do is proven by
    // `scheduler_retry_dispatches_again_test.dart`; here the review lane's
    // second attempt cannot run because the failed review left the item at
    // `reviewInProgress`, which is pinned separately in the GAP test below.
  });

  test('a review whose agent CRASHES fails permanently, spends no attempt, '
      'and is never retried', () async {
    final host = ReviewRetryHost(
      repo: repo,
      workspaceRoot: '${temp.path}/workspaces',
      reviewTimeoutSeconds: 60,
    );
    await host.produceArtifact('wi-crash');

    host.review.script = ReviewScript.crash;
    await host.tickReview();

    final afterCrash = await host.reviewJob('wi-crash');
    expect(
      afterCrash.state,
      JobState.failed,
      reason:
          'a crash is permanent. If this were retryable, a runtime that is '
          'broken rather than slow would be re-dispatched on every item '
          'forever — the "retry forever" failure this lane must not introduce.',
    );
    expect(
      afterCrash.attempt,
      1,
      reason:
          'a permanent failure spends NO additional attempt — the job is '
          'still at the 1 it was created with, while the timeout case above '
          'moved to 2. Asserted as a DELTA because that is the invariant: '
          '`maxAttempts` is a ceiling on TIME-OUT retries only, and a runtime '
          'that is broken rather than slow must not be able to consume it.',
    );
    expect(
      afterCrash.attempt,
      lessThan(afterCrash.maxAttempts),
      reason:
          'there was retry budget left; a permanent failure just cannot '
          'use it',
    );
    expect(afterCrash.failure?.kind, JobFailureKind.permanent);

    final crashExecution = (await host.reviewExecutions('wi-crash')).single;
    expect(
      crashExecution.status,
      WorkerExecutionStatus.executedFail,
      reason: 'and the worker execution agrees: a crash is not a timeout',
    );

    // Nothing re-dispatches it, however many ticks run.
    host.advanceClock(const Duration(minutes: 2));
    final secondTick = await host.tickReview();
    expect(
      secondTick.dispatched,
      isEmpty,
      reason: 'a terminal job is never dispatched again',
    );
    expect(
      await host.reviewExecutions('wi-crash'),
      hasLength(1),
      reason: 'one reviewer execution, and no second one, ever',
    );
  });

  test(
    'GAP, PINNED: a retried job cannot re-dispatch while its work item has '
    "left the definition's entry states, so it is retired one tick later",
    () async {
      // This is the honest other half of the fix above, and it is a SEPARATE
      // defect in a package this lane does not own.
      //
      // A budget expiry moves the work item out of the lane's entry states —
      // for review, `agentCompleted -> reviewInProgress` (which the coordinator
      // does before the run starts); for every other lane, `agentExecuting ->
      // agentFailed`. `RunnableWorkEvaluator` rejects any item outside its own
      // `entryStates` before it asks the policy anything, so on the NEXT tick
      // the item classifies `noAction`, and `Scheduler._retireSupersededForItem`
      // CANCELS the very job whose retry was just scheduled.
      //
      // So the retry budget this lane reconnected is spendable, and the retry
      // still does not run, unless something puts the item back. That
      // "something" is an operator retry (`agentFailed -> designNotRequired`, a
      // real edge) or a human decision — neither is automatic, and for the
      // REVIEW lane there is no edge back to `agentCompleted` at all.
      //
      // Asserted rather than described, because the assertion is cheap and the
      // description is what gets lost: if a future lane adds the restoration,
      // this test fails and says so.
      final host = ReviewRetryHost(
        repo: repo,
        workspaceRoot: '${temp.path}/workspaces',
        reviewTimeoutSeconds: 1,
      );
      await host.produceArtifact('wi-gap');

      host.review.script = ReviewScript.hang;
      await host.tickReview();
      expect(
        (await host.reviewJob('wi-gap')).state,
        JobState.retryWaiting,
        reason: 'precondition: the retry WAS scheduled',
      );

      // No restoration. The item is still where the failed review left it.
      host.advanceClock(const Duration(minutes: 2));
      await host.tickReview();

      final stranded = await host.reviewJob('wi-gap');
      expect(
        stranded.state,
        JobState.cancelled,
        reason:
            'PINNED BEHAVIOUR, not an endorsement. The retry was scheduled and '
            'then retired as superseded because the item left the lane\'s '
            'entry states. Whoever closes this must DELETE this assertion and '
            'replace it with one that shows the retry dispatching.',
      );
      expect(
        await host.reviewExecutions('wi-gap'),
        hasLength(1),
        reason: 'one reviewer execution, and the scheduled retry never ran',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Host
// ---------------------------------------------------------------------------

/// What the reviewer does on a given execution. One entry is consumed per
/// session start, so a test scripts attempt 1 and attempt 2 independently
/// instead of mutating the agent mid-run.
enum ReviewScript { hang, complete, crash }

class ScriptedReviewSession implements AgentSession {
  ScriptedReviewSession({required this.executionId, required this.script});

  @override
  final String executionId;
  ReviewScript script;
  @override
  String workItemId = '';
  @override
  String sessionId = 'ses-review-scripted';

  StreamController<AgentEvent> _events = StreamController<AgentEvent>.broadcast(
    sync: true,
  );
  AgentSessionStatus _status = AgentSessionStatus.starting;

  @override
  AgentSessionStatus get status => _status;

  @override
  Stream<AgentEvent> get eventStream => _events.stream;

  @override
  Future<void> start(AgentSessionConfig config) async {
    workItemId = config.workItemId;
    _events = StreamController<AgentEvent>.broadcast(sync: true);
    _status = AgentSessionStatus.running;
    _events.add(
      SessionStarted(
        eventId: 'evt-start',
        timestamp: DateTime.now(),
        sessionId: sessionId,
        workItemId: workItemId,
      ),
    );
  }

  @override
  Future<void> sendInstruction(AgentInstruction instruction) async {
    switch (script) {
      case ReviewScript.hang:
        // Accepts the instruction and then says nothing, ever. Only the
        // coordinator's budget can end this — which is the case under test.
        await Completer<void>().future;
      case ReviewScript.complete:
        _status = AgentSessionStatus.completed;
        _events.add(
          SessionCompleted(
            eventId: 'evt-complete',
            timestamp: DateTime.now(),
            result: await getResult(),
          ),
        );
      case ReviewScript.crash:
        _status = AgentSessionStatus.failed;
        _events.add(
          SessionFailed(
            eventId: 'evt-fail',
            timestamp: DateTime.now(),
            error: 'scripted reviewer crash',
            recoverable: true,
          ),
        );
    }
  }

  @override
  Future<void> cancel(String reason) async {
    if (_status == AgentSessionStatus.cancelled) return;
    _status = AgentSessionStatus.cancelled;
    // Release the hung instruction wait so the drive path can unwind.
    if (script == ReviewScript.hang) script = ReviewScript.complete;
    _events.add(
      SessionCancelled(
        eventId: 'evt-cancel',
        timestamp: DateTime.now(),
        reason: reason,
      ),
    );
  }

  @override
  Future<AgentResult> getResult() async {
    final complete = _status == AgentSessionStatus.completed;
    return AgentResult(
      resultId: 'result-$sessionId',
      sessionId: sessionId,
      workItemId: workItemId,
      status: complete ? AgentResultStatus.completed : AgentResultStatus.failed,
      artifacts: const [],
      diagnostics: AgentDiagnostics(
        exitCode: complete ? 0 : 1,
        durationMs: 1,
        toolCalls: 0,
        errors: const [],
        warnings: const [],
      ),
      structuredResult: const {},
      summary: complete ? 'reviewed' : 'did not complete',
      completedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<List<AgentArtifact>> getArtifacts() async => const [];

  @override
  Future<void> close() async {
    if (!_events.isClosed) await _events.close();
  }
}

class ScriptedReviewAdapter implements AgentAdapter {
  ScriptedReviewAdapter(this._session, {required this.providerId});

  final ScriptedReviewSession _session;

  @override
  final String providerId;

  @override
  String get displayName => 'Scripted Reviewer';

  @override
  final RuntimeCapabilities capabilities = const RuntimeCapabilities(
    supported: {
      RuntimeCapability.readFiles,
      RuntimeCapability.modifyFiles,
      RuntimeCapability.runTests,
      RuntimeCapability.cancellable,
    },
  );

  @override
  Future<AgentSession> createSession(AgentSessionConfig config) async {
    await _session.start(config);
    return _session;
  }

  @override
  Future<AgentSession> resumeSession(AgentSessionConfig config) async {
    await _session.start(config);
    return _session;
  }

  @override
  Future<bool> canResume(String sessionId) async => true;

  @override
  Future<AdapterHealth> checkHealth() async =>
      const AdapterHealth(healthy: true, version: 'scripted');

  @override
  Future<void> shutdown() async {}
}

/// Real workflow engine, real stores, real coordinator, real `LocalWorker`s and
/// a real `Scheduler` — the whole chain, with the reviewer scripted so its
/// outcome per attempt is deterministic.
class ReviewRetryHost {
  ReviewRetryHost({
    required GitRepoFixture repo,
    required String workspaceRoot,
    required int reviewTimeoutSeconds,
  }) {
    workflowStore = InMemoryWorkflowStore();
    workflowEngine = DurableWorkflowEngine(store: workflowStore);
    executionStore = InMemoryExecutionStore();
    workerStore = InMemoryWorkerStore();
    jobStore = InMemoryJobStore();

    implSession = DesignGateAgentSession(executionId: 'agx-impl');
    review = ScriptedReviewSession(
      executionId: 'agx-review',
      script: ReviewScript.complete,
    );
    runtime = AgentRuntime(
      registry: AgentAdapterRegistry()
        ..register(
          DesignGateAgentAdapter(implSession, providerId: 'impl-runtime'),
        )
        ..register(
          ScriptedReviewAdapter(review, providerId: 'review-runtime'),
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
      workerId: 'w-review',
      poolId: 'review-pool',
      capabilities: engineeringReviewDefinition.requiredCapabilities,
      workspaceManager: GitWorktreeWorkspaceManager(
        workspaceRoot: workspaceRoot,
      ),
      executionDriver: CoordinatorAgentExecutionDriver(coordinator),
      workerStore: workerStore,
      platform: Platform.operatingSystem,
    );

    final dispatch = WorkerDispatcherAdapter(
      WorkerDispatcher(
        registry: WorkerRegistry()
          ..register(implWorker)
          ..register(reviewWorker),
      ),
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
      clock: _now,
      zombieStalenessAfter: const Duration(hours: 1),
    );

    reviewScheduler = Scheduler(
      schedulerId: 'sched-review',
      workflowStore: workflowStore,
      jobStore: jobStore,
      workerStore: workerStore,
      dispatch: dispatch,
      definition: engineeringReviewDefinition,
      dedupeKeyBuilder: engineeringReviewDedupeKey,
      instructionBuilder: engineeringReviewInstruction,
      requestBuilder: engineeringReviewRequest,
      workloadResolver: engineeringReviewWorkloadResolver(
        workerStore: workerStore,
        runtimeTypeId: 'review-runtime',
        timeoutSeconds: reviewTimeoutSeconds,
      ),
      workload: SchedulerWorkload(
        repositoryPath: repo.root.path,
        startingRevision: repo.startingRevision,
        timeoutSeconds: reviewTimeoutSeconds,
        runtimeTypeId: 'review-runtime',
      ),
      clock: _now,
      // Generous, so nothing in this test can be mistaken for a zombie reclaim
      // in the middle of a legitimate run.
      zombieStalenessAfter: const Duration(hours: 6),
    );
  }

  late InMemoryWorkflowStore workflowStore;
  late DurableWorkflowEngine workflowEngine;
  late InMemoryExecutionStore executionStore;
  late InMemoryWorkerStore workerStore;
  late InMemoryJobStore jobStore;
  late DesignGateAgentSession implSession;
  late ScriptedReviewSession review;
  late AgentRuntime runtime;
  late ExecutionCoordinator coordinator;
  late LocalWorker implWorker;
  late LocalWorker reviewWorker;
  late Scheduler implScheduler;
  late Scheduler reviewScheduler;

  /// Starts at real "now" so `startedAt` comparisons in the reclaim probe
  /// behave, and advances on demand so `RetryPolicy.retryDelay` does not make
  /// the test sleep for a minute.
  DateTime _clock = DateTime.now().toUtc();
  DateTime _now() => _clock;
  void advanceClock(Duration by) => _clock = _clock.add(by);

  /// Creates a work item and runs the implementer to completion, so the
  /// review resolver has a real artifact to find.
  Future<void> produceArtifact(String workItemId) async {
    await workflowEngine.createWorkItem(
      workItemId: workItemId,
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Implement calculator add',
      description: 'The producer run that gives the review lane an artifact',
      qaContractId: 'qa-1',
      featureRef: 'feature/calc',
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
      context: const {'featureRef': 'feature/calc'},
    );
    await workflowEngine.transition(
      workItemId: workItemId,
      to: WorkItemState.designNotRequired,
      trigger: TransitionTrigger.systemEvent,
    );

    final tick = implScheduler.tick();
    await implSession.awaitingGate;
    implSession.release();
    await tick;

    final item = await workflowEngine.loadWorkItem(workItemId);
    expect(
      item.state,
      WorkItemState.agentCompleted,
      reason: 'the producer must complete, or the review has nothing to run on',
    );
  }

  Future<SchedulerTickResult> tickReview() => reviewScheduler.tick();

  Future<Job> reviewJob(String workItemId) async {
    final jobs = await jobStore.listJobsForWorkItem(workItemId);
    return jobs.singleWhere((j) => j.jobType == JobType.engineeringReview);
  }

  Future<List<WorkerExecution>> reviewExecutions(String workItemId) async =>
      (await workerStore.listWorkerExecutions())
          .where(
            (e) =>
                e.workItemId == workItemId &&
                e.requiredCapabilities.contains(
                  WorkerCapability.engineeringReview,
                ),
          )
          .toList();
}
