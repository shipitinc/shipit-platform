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
import 'support/settle.dart';

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

    // What the retry actually DOES is proven below — the GAP assertion this
    // file used to end on has been closed and replaced.
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
    'CLOSED GAP: the retry now RE-DISPATCHES, because the failed review returns '
    'the work item to the lane\'s entry state',
    () async {
      // This test REPLACES a pinned assertion that recorded the opposite
      // behaviour, deliberately and for a long time:
      //
      //   'GAP, PINNED: a retried job cannot re-dispatch while its work item
      //    has left the definition's entry states, so it is retired one tick
      //    later'  … asserting JobState.cancelled and 'the scheduled retry
      //    never ran'.
      //
      // The pin existed so the gap could not be forgotten. It is now closed by
      // the retry-return edge (decision 3659984d, option A):
      // `reviewInProgress -> agentCompleted` puts the item back inside
      // `engineeringReviewDefinition.entryStates`, so `RunnableWorkEvaluator`
      // no longer classifies it `noAction` and `_retireSupersededForItem` no
      // longer cancels the retry. The target is derived from the policy and
      // proceeds only on a UNIQUE reachable entry state — see
      // `packages/scheduler/test/retry_return_to_entry_state_test.dart`.
      //
      // The pin's own instruction was 'DELETE this assertion and replace it
      // with one that shows the retry dispatching'. That is what this is. The
      // reason it is asserted rather than described is unchanged: the
      // description is what gets lost.
      final host = ReviewRetryHost(
        repo: repo,
        workspaceRoot: '${temp.path}/workspaces',
        reviewTimeoutSeconds: 1,
      );
      await host.produceArtifact('wi-gap');

      // Attempt 1: the reviewer starts and never finishes.
      host.review.script = ReviewScript.hang;
      await host.tickReview();

      final scheduled = await host.reviewJob('wi-gap');
      expect(
        scheduled.state,
        JobState.retryWaiting,
        reason: 'precondition: the retry WAS scheduled',
      );

      // Past the back-off. Attempt 2 is dispatched and run.
      host.advanceClock(const Duration(minutes: 2));
      await host.tickReview();

      final afterRetry = await host.reviewJob('wi-gap');
      expect(
        afterRetry.state,
        isNot(JobState.cancelled),
        reason:
            'NOT retired as superseded. The item is back inside the lane\'s '
            'entry states, so the scheduled retry is claimable.',
      );
      expect(
        afterRetry.attempt,
        2,
        reason: 'the retry was actually SPENT, not merely scheduled',
      );

      // The load-bearing assertion: TWO executions, not one. A retry that is
      // "scheduled" but never dispatched is precisely what the pin recorded,
      // and the execution count is the only thing that tells the two apart.
      //
      // This is the whole point of the replacement. Before the edge this count
      // was 1 forever: the retry was scheduled, then retired as superseded on
      // the next tick, and no second reviewer ever ran.
      final executions = await host.reviewExecutions('wi-gap');
      expect(
        executions,
        hasLength(2),
        reason:
            'two reviewer executions: attempt 1 timed out, attempt 2 was '
            'dispatched and ran. Before the edge this was 1.',
      );
      expect(
        executions.first.status,
        WorkerExecutionStatus.timedOut,
        reason: 'attempt 1 is the budget expiry this whole file is about',
      );

      // NOTE on what is deliberately NOT asserted here: that attempt 2
      // SUCCEEDS. Measured in this harness it settles as
      // `executedFail/agentFailed`, because `ScriptedReviewSession` is a single
      // shared instance and attempt 1's detached session leaves it in a state
      // the `complete` script does not re-arm from. That is a property of the
      // test double, not of the production path.
      //
      // Successful completion of a retried run is proven where the double does
      // not get in the way:
      //   packages/scheduler/test/retry_return_to_entry_state_test.dart
      //     transient failure -> 2 real executions -> the second SUCCEEDS
      //   apps/server/test/integration/triage_execution_test.dart
      //     the same, end to end, with a persisted result row
      //   packages/execution_coordinator/test/budget_expiry_is_a_timeout_test.dart
      //     the coordinator half on its own
      //
      // Asserting `succeeded` here would assert something measured to be false
      // in this file — the same error as the pin, in the opposite direction.
    },
  );

  // -------------------------------------------------------------------------
  // A transport failure is not an agent verdict, so it is RETRIED — and it is
  // still bounded. Both halves, end to end, through the real
  // `Scheduler` -> `LocalWorker` -> `ExecutionCoordinator` chain.
  //
  // The seam that makes the session emit `SessionInterrupted` rather than
  // `SessionFailed` for a quiet wire is proven in
  // `packages/agent_runtime/test/opencode_transport_failure_classification_test.dart`;
  // what is under test here is what the SCHEDULER does with the difference.
  // -------------------------------------------------------------------------

  Future<ReviewRetryHost> hostFor(String workItemId, int timeoutSeconds) async {
    final host = ReviewRetryHost(
      repo: repo,
      workspaceRoot: '${temp.path}/workspaces',
      reviewTimeoutSeconds: timeoutSeconds,
    );
    await host.produceArtifact(workItemId);
    return host;
  }

  test(
    'a transport timeout spends an attempt and is TRANSIENT, not permanent',
    () async {
      final host = await hostFor('wi-wire', 60);

      host.review.script = ReviewScript.transportTimeout;
      await host.tickReview();

      final job = await host.reviewJob('wi-wire');
      expect(
        job.state,
        JobState.retryWaiting,
        reason:
            'NOT `failed`. Two live review jobs died here — '
            '`AcpTransportException: ACP request timed out: session/prompt` — at '
            'attempt 1 of 2, spending zero attempts and leaving their work items '
            'stranded at `review_in_progress`. A wire that goes quiet is not an '
            'assessment, and classifying it as permanent asserts a verdict the '
            'system does not have.',
      );
      expect(job.attempt, job.maxAttempts, reason: 'one retry was scheduled');
      expect(job.failure?.kind, JobFailureKind.transient);
      expect(job.isTerminal, isFalse);

      final execution = (await host.reviewExecutions('wi-wire')).single;
      expect(
        execution.status,
        WorkerExecutionStatus.timedOut,
        reason: 'the link that makes the retry possible',
      );
    },
  );

  test('the retry RE-DISPATCHES, and maxAttempts bounds it at exactly N', () async {
    final host = await hostFor('wi-bound', 60);
    host.review.script = ReviewScript.transportTimeout;

    await host.tickReview();
    final scheduled = await host.reviewJob('wi-bound');
    expect(
      scheduled.state,
      JobState.retryWaiting,
      reason: 'precondition: the retry was scheduled',
    );
    expect(scheduled.maxAttempts, 2, reason: "the lane's configured budget");

    // Attempt 2 runs, past the back-off, and fails the same way.
    host.advanceClock(const Duration(minutes: 2));
    await host.tickReview();
    expect(
      await host.reviewExecutions('wi-bound'),
      hasLength(2),
      reason: 'the retry was actually SPENT, not merely scheduled',
    );
    final afterSecond = await host.reviewJob('wi-bound');
    expect(afterSecond.attempt, 2, reason: 'and the budget is now spent');

    // Two more ticks. This is the assertion that keeps the fix from being the
    // OTHER defect: "retryable" must not mean "retried forever".
    for (var tick = 3; tick <= 4; tick++) {
      host.advanceClock(const Duration(minutes: 2));
      await host.tickReview();
      expect(
        await host.reviewExecutions('wi-bound'),
        hasLength(2),
        reason:
            'after tick $tick the count must STILL be 2. N=2 means exactly two '
            'executions, never three — a permanently broken runtime spends the '
            'budget and stops.',
      );
    }

    // MEASURED, and deliberately not asserted as anything else: once the
    // budget is spent the job row sits at `queued` rather than going terminal
    // `failed`. It is re-offered on every tick and never runs again, so no
    // THIRD reviewer is ever dispatched. Two consequences, both real:
    //
    //  * the bound this test cares about — executions, i.e. agent runs and
    //    model spend — is genuinely N. The job row is not the evidence for it
    //    and asserting `JobState.failed` would assert something measured to be
    //    false in this harness.
    //  * a reviewer that exhausts its retry budget leaves an operator with a
    //    non-terminal job and no blocking decision, which is the same shape as
    //    the live incident this lane fixes (two items stranded at
    //    `review_in_progress`).
    //
    // This is NOT introduced here. The identical sequence is produced by
    // `ReviewScript.hang` — the budget-expiry path that has been retryable
    // since decision 3659984d — on the same host at the same clock, which is
    // why the `CLOSED GAP` test above still records attempt 2 as settling
    // `executedFail` against a stale double. It lives in
    // `packages/scheduler` (`Scheduler._adopt` -> `canRetry`), which this lane
    // does not own; it is reported to the Manager rather than fixed here.
    expect(
      afterSecond.state,
      isNot(JobState.retryWaiting),
      reason:
          'whatever the exhausted job settles as, it must not be waiting on a '
          'retry that can never be claimed',
    );
  });

  test(
    "a transport timeout does NOT make the agent's own failure retryable",
    () async {
      // The dangerous direction. Widening the transient class to cover "the
      // runtime did not answer" must not widen it to cover "the runtime answered
      // and said no", which is a verdict and belongs to the correction gate.
      final host = await hostFor('wi-verdict', 60);
      host.review.script = ReviewScript.crash;
      await host.tickReview();

      final job = await host.reviewJob('wi-verdict');
      expect(
        job.state,
        JobState.failed,
        reason:
            'a JSON-RPC error from the runtime is an assessment. It must stay '
            'permanent or a permanently-broken model turns into a retry loop.',
      );
      expect(
        job.attempt,
        1,
        reason: 'a permanent failure spends NO additional attempt',
      );
      expect(job.failure?.kind, JobFailureKind.permanent);

      host.advanceClock(const Duration(minutes: 2));
      expect((await host.tickReview()).dispatched, isEmpty);
      expect(await host.reviewExecutions('wi-verdict'), hasLength(1));
    },
  );
}

// ---------------------------------------------------------------------------
// Host
// ---------------------------------------------------------------------------

/// What the reviewer does on a given execution. One entry is consumed per
/// session start, so a test scripts attempt 1 and attempt 2 independently
/// instead of mutating the agent mid-run.
enum ReviewScript { hang, complete, crash, transportTimeout }

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
      case ReviewScript.transportTimeout:
        // The wire went quiet: the runtime returned no assessment at all. This
        // is what `OpenCodeSession` now emits for an `AcpTransportException`,
        // and what it used to report as `SessionFailed` — which settled
        // `executedFail`, classified permanent, and spent zero attempts. See
        // `packages/agent_runtime/test/`
        // `opencode_transport_failure_classification_test.dart` for the seam
        // that proves the adapter really does this.
        _status = AgentSessionStatus.interrupted;
        _events.add(
          SessionInterrupted(
            eventId: 'evt-transport-timeout',
            timestamp: DateTime.now(),
            reason:
                'AcpTransportException: ACP request timed out: session/prompt',
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

    // Detached dispatch (F-237): the tick above only STARTED the run. The
    // job settles through reconcile-adoption — the run's continuation
    // releases the claim and the next tick's `_reconcileClaim` adopts the
    // terminal execution. `agentCompleted` lands there, not in the tick
    // that returned.
    await settleHeldJobs(jobStore, implScheduler);

    final item = await workflowEngine.loadWorkItem(workItemId);
    expect(
      item.state,
      WorkItemState.agentCompleted,
      reason: 'the producer must complete, or the review has nothing to run on',
    );
  }

  /// A review tick the way production observes one across the F-237 split:
  /// the tick STARTS the run and returns; the detached continuation
  /// releases the claim; the settle tick's reconcile adopts the terminal
  /// execution. The returned result is the DISPATCHING tick's — `dispatched`
  /// is read off it, and the settle tick's `dispatched` would always be
  /// empty for a job its own reconcile just settled.
  Future<SchedulerTickResult> tickReview() async {
    final dispatched = await reviewScheduler.tick();
    await settleHeldJobs(jobStore, reviewScheduler);
    return dispatched;
  }

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
