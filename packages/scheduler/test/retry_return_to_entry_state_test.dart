import 'dart:async';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_runtime/worker_runtime.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/controlled_dispatcher.dart';

/// A retryable execution failure returns the work item to the entry state of
/// the lane whose job failed, so the scheduled retry can actually be claimed.
///
/// ## THE DEFECT THESE TESTS CLOSE
///
/// Decision `3659984d-4e2a-4625-81ff-37aa73252375` (option A). Four links, all
/// of which had to hold at once:
///
///  1. a retryable failure moves the item OUT of its lane's `entryStates`
///     (`agentExecuting -> agentFailed`; or `reviewInProgress`, which the
///     coordinator deliberately leaves a reviewer at);
///  2. `RunnableWorkEvaluator.evaluate` rejects any item outside `entryStates`
///     BEFORE consulting anything else;
///  3. the next tick classifies it `noAction`; and
///  4. `Scheduler._retireSupersededForItem` CANCELS the retry just scheduled.
///
/// `cancelledQueued` is not in the drain's `dispatched ∪ terminal ∪ reconciled`
/// union, so no operator signal was raised either. No retry had ever run on any
/// `Scheduler` lane; every `maxAttempts` was unreachable for exactly the
/// failures it exists for.
///
/// ## WHAT IS ASSERTED, AND WHY EACH HALF IS NOT OPTIONAL
///
/// The headline is NOT "a retry was scheduled" — that already worked, and
/// `scheduler_retry_test.dart` proves it on an item that never left its entry
/// states. It is that the second execution ACTUALLY RUNS. Every test below that
/// claims recovery asserts on `ControlledDispatcher.runs.length`, because a
/// job that is merely still `retryWaiting` has proved nothing.
///
/// And the failure classes must stay DISTINCT: a transient failure returns, a
/// permanent one strands for a human. Both halves are asserted, because a return
/// applied unconditionally would delete the distinction the classification work
/// exists to draw.
const _workload = SchedulerWorkload(
  repositoryPath: '/durable/clone',
  startingRevision: '0f9a1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b',
  timeoutSeconds: 300,
  runtimeTypeId: 'rt-product',
);

/// A work item planted directly at [state].
///
/// Planted rather than walked, and that is deliberate: the coordinator's
/// `entry -> running -> failed` chain is what PRODUCES these states, it lives in
/// `execution_coordinator`, and it is already covered end-to-end by
/// `apps/server/test/integration/triage_execution_test.dart`. What is under test
/// here is the scheduler's reaction to a state the coordinator produced. The
/// states planted are real states, reachable by real edges — asserted
/// independently in `packages/workflow_engine/test/retry_return_edges_test.dart`.
WorkItem _item({
  String workItemId = 'wi-1',
  WorkItemState state = WorkItemState.implementationReady,
  Map<String, dynamic>? metadata,
  String? qaContractId = 'qa-1',
}) => WorkItem(
  workItemId: workItemId,
  productId: 'prod-1',
  category: WorkItemCategory.feature,
  title: 'Retry return probe',
  description: 'A work item for the retry-return pass',
  state: state,
  qaContractId: qaContractId,
  metadata: metadata,
  createdAt: DateTime.utc(2026, 3, 1, 12),
  updatedAt: DateTime.utc(2026, 3, 1, 12),
);

class _Host {
  _Host({
    required JobDefinition definition,
    required DateTime Function() clock,
    ControlledDispatcher? dispatch,
  }) : dispatch = dispatch ?? ControlledDispatcher() {
    workflowStore = InMemoryWorkflowStore();
    jobStore = InMemoryJobStore();
    workerStore = InMemoryWorkerStore();
    engine = DurableWorkflowEngine(store: workflowStore);
    scheduler = Scheduler(
      schedulerId: 'sched-1',
      workflowStore: workflowStore,
      jobStore: jobStore,
      workerStore: workerStore,
      dispatch: this.dispatch,
      definition: definition,
      workload: _workload,
      clock: clock,
    );
  }

  late InMemoryWorkflowStore workflowStore;
  late InMemoryJobStore jobStore;
  late InMemoryWorkerStore workerStore;
  late DurableWorkflowEngine engine;
  late Scheduler scheduler;
  final ControlledDispatcher dispatch;

  Future<WorkItem> plant(WorkItem item) async {
    await workflowStore.saveWorkItem(item);
    return item;
  }

  Future<List<Job>> jobs() => jobStore.listJobs();

  Future<Job> job() async => (await jobStore.listJobs()).single;
}

/// The dispatcher hook that stands in for `ExecutionCoordinator`: it settles the
/// work item exactly the way the coordinator does for the given role, then
/// reports the scripted worker outcome.
///
/// This is the ONLY place the failure's effect on the work item is produced, and
/// it is produced separately from the scheduler's reaction to it on purpose. A
/// test that moved the item from inside the scheduler could not tell which of
/// the two halves was under test.
Future<WorkerExecutionResult> Function(WorkerExecutionRequest) _settlingOutcome(
  DurableWorkflowEngine engine, {
  required WorkerExecutionStatus status,
  required List<WorkItemState> settleThrough,
}) {
  return (WorkerExecutionRequest request) async {
    for (final state in settleThrough) {
      await engine.transition(
        workItemId: request.workItemId,
        to: state,
        trigger: TransitionTrigger.systemEvent,
        actor: const WorkflowActor(
          actorId: 'orchestrator',
          actorType: ActorType.orchestrator,
        ),
        // `agentExecuting` asserts an agent is starting RIGHT NOW and its edge
        // carries `agentAvailable()`; the coordinator supplies exactly this
        // context and so does this stand-in.
        context: const {'agentAvailable': true, 'capabilitiesMatch': true},
      );
    }
    return WorkerExecutionResult(
      workerExecutionId: request.workerExecutionId,
      workItemId: request.workItemId,
      status: status,
      workerId: 'w-scripted-1',
      workspaceId: 'ws-${request.workerExecutionId}',
      startingRevision: request.startingRevision,
      startedAt: DateTime.utc(2026, 3, 1, 12),
      endedAt: DateTime.utc(2026, 3, 1, 12, 5),
      cleanupStatus: WorkerCleanupStatus.removed,
      failureCode: switch (status) {
        WorkerExecutionStatus.prepareFailed => WorkerFailureCode.prepareFailed,
        _ => WorkerFailureCode.none,
      },
      failureDetail: switch (status) {
        WorkerExecutionStatus.executedFail =>
          'the agent produced a failing '
              'coding result',
        _ => null,
      },
    );
  };
}

void main() {
  final t0 = DateTime.utc(2026, 3, 1, 12);

  group('a transient failure returns the item and the retry REALLY RUNS', () {
    test('implementation lane: the second execution runs, not merely the second '
        'retry is scheduled', () async {
      var now = t0;
      final dispatch = ControlledDispatcher();
      final host = _Host(
        definition: implementFeatureDefinition,
        clock: () => now,
        dispatch: dispatch,
      );
      await host.plant(_item());

      // ---- attempt 1: the agent session ends interrupted, which
      // `RetryPolicy.classify` maps to `transient`. The coordinator settles
      // the item at `agentFailed`, which is the state that strands it.
      dispatch.resultBuilder = _settlingOutcome(
        host.engine,
        status: WorkerExecutionStatus.timedOut,
        settleThrough: const [
          WorkItemState.agentExecuting,
          WorkItemState.agentFailed,
        ],
      );
      final first = await host.scheduler.tick();

      expect(first.dispatched, hasLength(1));
      expect(dispatch.runs, hasLength(1));

      var job = await host.job();
      expect(
        job.state,
        JobState.retryWaiting,
        reason: 'the transient failure DID park a bounded retry',
      );
      expect(job.failure?.kind, JobFailureKind.transient);
      expect(job.attempt, 2, reason: 'scheduleRetry pre-increments');
      expect(
        job.availableAt,
        DateTime.utc(2026, 3, 1, 12, 1),
        reason:
            'the one-minute back-off, which is the only reason the retry '
            'cannot run yet',
      );
      expect(
        (await host.workflowStore.readWorkItem('wi-1')).state,
        WorkItemState.agentFailed,
        reason:
            'PRECONDITION, and the defect in one line: the item is outside '
            'every implementFeatureDefinition entry state, so nothing can '
            'claim the retry',
      );

      // ---- the next tick. This is the tick that used to cancel the retry.
      final second = await host.scheduler.tick();

      expect(
        second.cancelledQueued,
        isEmpty,
        reason:
            'LINK 4 OF THE DEFECT. `cancelledQueued` empty means the retry '
            'that was just scheduled was NOT retired as superseded. Before '
            'the fix this list held the job id, on every tick, for ever.',
      );
      expect(
        second.retryReturned.where((m) => m.returned).map((m) => m.to),
        [WorkItemState.implementationReady],
        reason:
            'the item went back to the implementation lane\'s OWN entry '
            'state — a RETURN, not a widening',
      );
      expect(
        (await host.workflowStore.readWorkItem('wi-1')).state,
        WorkItemState.implementationReady,
      );
      expect(
        second.dispatched,
        isEmpty,
        reason: 'the back-off has not elapsed, so the retry is not due yet',
      );
      job = await host.job();
      expect(
        job.state,
        JobState.retryWaiting,
        reason: 'the retry is still parked, and now it is CLAIMABLE',
      );
      expect(
        host.scheduler.queue.isEligibleAt(
          job,
          t0.add(const Duration(hours: 1)),
        ),
        isTrue,
      );

      // ---- past the back-off, the retry is actually claimed and RUNS.
      now = t0.add(const Duration(minutes: 2));
      dispatch.resultBuilder = null;
      dispatch.statusSeries = () => const [WorkerExecutionStatus.executedPass];
      final third = await host.scheduler.tick();

      expect(
        third.dispatched,
        hasLength(1),
        reason: 'the scheduled retry was claimed by a scheduler tick',
      );
      expect(
        dispatch.runs,
        hasLength(2),
        reason:
            'THE HEADLINE. Two executions really ran. A job that is merely '
            'still `retryWaiting` proves nothing; this is the second dispatch.',
      );
      final finished = await host.job();
      expect(finished.state, JobState.succeeded);
      expect(
        finished.attempt,
        2,
        reason: 'the second execution was attempt 2 and consumed it',
      );
    });

    test('review lane: a reviewer left at reviewInProgress comes back to '
        'agentCompleted and a reviewer really runs again', () async {
      // The review lane is the WORST case and the reason it needs its own
      // edge: `ExecutionCoordinator._completeFailure` and
      // `_failWithoutSession` both SKIP the `agentFailed` transition for
      // `AgentRole.engineeringReviewer`. So a crashed reviewer left its item
      // AT `reviewInProgress` — neither in an entry state nor in a state a
      // human would read as failed. It simply looked like a review in
      // progress while its job was cancelled as superseded.
      var now = t0;
      final dispatch = ControlledDispatcher();
      final host = _Host(
        definition: engineeringReviewDefinition,
        clock: () => now,
        dispatch: dispatch,
      );
      await host.plant(_item(state: WorkItemState.agentCompleted));

      dispatch.resultBuilder = (request) async {
        // The coordinator's reviewer entry transition. There is no
        // `agentExecuting` step: a reviewer goes straight to
        // `reviewInProgress`.
        await host.engine.transition(
          workItemId: request.workItemId,
          to: WorkItemState.reviewInProgress,
          trigger: TransitionTrigger.systemEvent,
          actor: const WorkflowActor(
            actorId: 'orchestrator',
            actorType: ActorType.orchestrator,
          ),
          // `agentCompleted -> reviewInProgress` carries `agentResultValid()`,
          // which reads the IMPLEMENTER's completed result out of
          // `context['agentResult']`. The coordinator supplies it from the
          // store; this stand-in supplies it directly, because building a
          // whole execution history is not what this test is about.
          context: {
            'agentAvailable': true,
            'capabilitiesMatch': true,
            'agentResult': _producerResult(request.workItemId),
          },
        );
        return _outcome(request, WorkerExecutionStatus.timedOut);
      };

      expect((await host.scheduler.tick()).dispatched, hasLength(1));
      expect(dispatch.runs, hasLength(1));
      expect((await host.job()).state, JobState.retryWaiting);
      expect(
        (await host.workflowStore.readWorkItem('wi-1')).state,
        WorkItemState.reviewInProgress,
        reason: 'PRECONDITION: a crashed reviewer leaves the item HERE',
      );

      final second = await host.scheduler.tick();
      expect(second.cancelledQueued, isEmpty);
      expect(
        second.retryReturned.where((m) => m.returned).map((m) => m.to),
        [WorkItemState.agentCompleted],
        reason:
            'the item goes back to the REVIEW lane\'s own entry state. Not '
            'to `agentFailed` — an unreviewed item must not be filed as a '
            'failed coding result.',
      );
      expect(
        (await host.workflowStore.readWorkItem('wi-1')).state,
        WorkItemState.agentCompleted,
      );

      now = t0.add(const Duration(minutes: 2));
      dispatch.resultBuilder = null;
      final third = await host.scheduler.tick();
      expect(third.dispatched, hasLength(1));
      expect(
        dispatch.runs,
        hasLength(2),
        reason: 'a SECOND REVIEWER really ran',
      );
    });

    test(
      'triage lane: the return resolves to the ONE reachable entry state',
      () async {
        var now = t0;
        final dispatch = ControlledDispatcher();
        final host = _Host(
          definition: triageDefectDefinition,
          clock: () => now,
          dispatch: dispatch,
        );
        await host.plant(_item(state: WorkItemState.designNotRequired));

        dispatch.resultBuilder = _settlingOutcome(
          host.engine,
          status: WorkerExecutionStatus.timedOut,
          settleThrough: const [
            WorkItemState.agentExecuting,
            WorkItemState.agentFailed,
          ],
        );
        await host.scheduler.tick();
        expect(
          (await host.workflowStore.readWorkItem('wi-1')).state,
          WorkItemState.agentFailed,
        );

        final second = await host.scheduler.tick();

        // `triageDefectDefinition.entryStates` holds THREE states. Only
        // `designNotRequired` is reachable from `agentFailed`, and the pass
        // returns to it precisely because the answer is unique.
        expect(second.retryReturned.where((m) => m.returned).map((m) => m.to), [
          WorkItemState.designNotRequired,
        ]);
        expect(
          triageDefectDefinition.entryStates,
          contains(WorkItemState.designNotRequired),
        );
      },
    );
  });

  group('the failure classes stay DISTINCT', () {
    test(
      'a PERMANENT failure does NOT return: the item strands for a human',
      () async {
        var now = t0;
        final dispatch = ControlledDispatcher();
        final host = _Host(
          definition: implementFeatureDefinition,
          clock: () => now,
          dispatch: dispatch,
        );
        await host.plant(_item());

        dispatch.resultBuilder = _settlingOutcome(
          host.engine,
          // `executedFail` is the agent reporting a FAILING CODING RESULT.
          // `RetryPolicy` classifies it `permanent` precisely because re-running
          // an LLM on the same wrong implementation is not a retry.
          status: WorkerExecutionStatus.executedFail,
          settleThrough: const [
            WorkItemState.agentExecuting,
            WorkItemState.agentFailed,
          ],
        );
        await host.scheduler.tick();

        final job = await host.job();
        expect(job.state, JobState.failed, reason: 'terminal, not retryable');
        expect(job.failure?.kind, JobFailureKind.permanent);

        for (var i = 0; i < 3; i++) {
          final tick = await host.scheduler.tick();
          expect(
            tick.retryReturned,
            isEmpty,
            reason:
                'no retry is owed, so there is nothing to return. A permanent '
                'failure must NOT be laundered into an automatic re-run.',
          );
          now = now.add(const Duration(hours: 1));
        }

        expect(
          (await host.workflowStore.readWorkItem('wi-1')).state,
          WorkItemState.agentFailed,
          reason: 'the item is left exactly where the failure put it',
        );
        expect(
          implementFeatureDefinition.entryStates,
          isNot(contains(WorkItemState.agentFailed)),
          reason: 'and nothing dispatches it, which is the point',
        );
        expect(dispatch.runs, hasLength(1), reason: 'exactly one execution');
      },
    );

    test('a CANCELLED failure is not retryable either', () async {
      final dispatch = ControlledDispatcher();
      final host = _Host(
        definition: implementFeatureDefinition,
        clock: () => t0,
        dispatch: dispatch,
      );
      await host.plant(_item());

      dispatch.resultBuilder = _settlingOutcome(
        host.engine,
        status: WorkerExecutionStatus.cancelled,
        settleThrough: const [
          WorkItemState.agentExecuting,
          WorkItemState.agentFailed,
        ],
      );
      await host.scheduler.tick();

      expect((await host.job()).state, JobState.cancelled);
      final tick = await host.scheduler.tick();
      expect(tick.retryReturned, isEmpty);
      expect(
        (await host.workflowStore.readWorkItem('wi-1')).state,
        WorkItemState.agentFailed,
      );
    });
  });

  group('maxAttempts bounds the retries FOR REAL', () {
    test('exactly N executions run, never N+1', () async {
      var now = t0;
      final dispatch = ControlledDispatcher();
      final host = _Host(
        definition: implementFeatureDefinition,
        clock: () => now,
        dispatch: dispatch,
      );
      await host.plant(_item());
      expect(implementFeatureDefinition.maxAttempts, 2);

      // Every execution fails transiently, so every one of them is retryable
      // and the budget is the only thing that can stop the loop.
      dispatch.resultBuilder = _settlingOutcome(
        host.engine,
        status: WorkerExecutionStatus.timedOut,
        settleThrough: const [
          WorkItemState.agentExecuting,
          WorkItemState.agentFailed,
        ],
      );

      // attempt 1
      await host.scheduler.tick();
      expect(dispatch.runs, hasLength(1));
      expect((await host.job()).state, JobState.retryWaiting);

      // attempt 2, after the return and the back-off
      now = t0.add(const Duration(minutes: 2));
      dispatch.resultBuilder = (request) async {
        await host.engine.transition(
          workItemId: request.workItemId,
          to: WorkItemState.agentExecuting,
          trigger: TransitionTrigger.systemEvent,
          actor: const WorkflowActor(
            actorId: 'orchestrator',
            actorType: ActorType.orchestrator,
          ),
          context: const {'agentAvailable': true, 'capabilitiesMatch': true},
        );
        await host.engine.transition(
          workItemId: request.workItemId,
          to: WorkItemState.agentFailed,
          trigger: TransitionTrigger.systemEvent,
          actor: const WorkflowActor(
            actorId: 'orchestrator',
            actorType: ActorType.orchestrator,
          ),
        );
        return _outcome(request, WorkerExecutionStatus.timedOut);
      };
      final second = await host.scheduler.tick();
      expect(second.dispatched, hasLength(1), reason: 'attempt 2 really ran');
      expect(dispatch.runs, hasLength(2));

      final job = await host.job();
      expect(
        job.state,
        JobState.failed,
        reason: '`canRetry` is `attempt < maxAttempts`, and 2 < 2 is false',
      );
      expect(job.attempt, 2);

      // And nothing runs again, however many ticks pass.
      for (var i = 0; i < 4; i++) {
        now = now.add(const Duration(hours: 1));
        final tick = await host.scheduler.tick();
        expect(tick.dispatched, isEmpty);
        expect(
          tick.retryReturned,
          isEmpty,
          reason:
              'the job is terminal, so no retry is owed and nothing returns',
        );
      }
      expect(
        dispatch.runs,
        hasLength(2),
        reason: 'EXACTLY N executions. Never N+1.',
      );
    });
  });

  group('the pass refuses rather than guesses', () {
    test('two reachable entry states is an ambiguity, and is refused', () async {
      // A definition whose entry set is reachable in more than one way. Both
      // `designNotRequired` and `implementationReady` have an edge out of
      // `agentFailed`, so the policy answers "two" and the pass stops rather
      // than picking one.
      //
      // This is the same shape a future edge addition could create for a real
      // lane, which is exactly why `agentFailed -> designApproved` and
      // `agentFailed -> reviewRejected` are deliberately ABSENT from the
      // transition table: adding either would make triage's return ambiguous
      // and silently disable the retry for every lane dispatching from
      // `agentFailed`.
      final ambiguous = JobDefinition(
        jobType: JobType.triageDefect,
        requiredRole: AgentRole.triageDefect,
        requiredCapabilities: const {},
        entryStates: {
          WorkItemState.designNotRequired,
          WorkItemState.implementationReady,
        },
      );
      final host = _Host(definition: ambiguous, clock: () => t0);
      // Planted AT the failure state: the pass only ever considers an item
      // that has LEFT this lane's entry states, so an item still sitting in one
      // of them needs no return and is correctly skipped.
      await host.plant(_item(state: WorkItemState.agentFailed));

      final job = await host.scheduler.queue.enqueueIfAbsent(
        workItemId: 'wi-1',
        definition: ambiguous,
        dedupeKey: 'wi-1:triage_defect',
        instruction: 'triage it',
        now: t0,
      );
      await host.scheduler.queue.scheduleRetry(
        job: job.job,
        failure: const JobFailure(
          code: JobFailureCode.executionInterrupted,
          kind: JobFailureKind.transient,
          reason: 'the agent session ended interrupted',
        ),
        now: t0,
      );

      final tick = await host.scheduler.tick();

      expect(
        tick.retryReturned.where((m) => m.returned),
        isEmpty,
        reason: 'an ambiguous answer must not be guessed at',
      );
      expect(tick.retryReturned, hasLength(1), reason: 'and it is REPORTED');
      expect(tick.retryReturned.single.reason, contains('ambiguous'));
      expect(
        (await host.workflowStore.readWorkItem('wi-1')).state,
        WorkItemState.agentFailed,
        reason: 'the item was never moved',
      );
    });

    test(
      'a work item parked at a blocking human decision is never returned',
      () async {
        // A return here would silently pre-empt a decision nobody has
        // answered. `waitingForHumanDecision` is a PAUSE that consumes no
        // capacity and is expected to resolve back into an entry state.
        final host = _Host(
          definition: implementFeatureDefinition,
          clock: () => t0,
        );
        await host.plant(
          _item(
            state: WorkItemState.waitingForHumanDecision,
            qaContractId: null,
          ),
        );

        final job = await host.scheduler.queue.enqueueIfAbsent(
          workItemId: 'wi-1',
          definition: implementFeatureDefinition,
          dedupeKey: 'wi-1:implement_feature',
          instruction: 'implement it',
          now: t0,
        );
        await host.scheduler.queue.scheduleRetry(
          job: job.job,
          failure: const JobFailure(
            code: JobFailureCode.executionInterrupted,
            kind: JobFailureKind.transient,
          ),
          now: t0,
        );

        final tick = await host.scheduler.tick();

        expect(tick.retryReturned.where((m) => m.returned), isEmpty);
        expect(tick.retryReturned.single.reason, contains('blocking human'));
        expect(
          (await host.workflowStore.readWorkItem('wi-1')).state,
          WorkItemState.waitingForHumanDecision,
        );
        expect(
          tick.cancelledQueued,
          isEmpty,
          reason:
              'and the retry is NOT cancelled either — `blocked` deliberately '
              'leaves every existing job untouched, because the platform still '
              'wants to run it once the gate resolves',
        );
      },
    );
  });

  group('NO entryStates SET WAS WIDENED', () {
    test('every wired definition declares exactly the entry set it declared '
        'before', () {
      // This is the whole safety argument of decision
      // `3659984d-4e2a-4625-81ff-37aa73252375` option A, and it is asserted as
      // EXACT SET EQUALITY against the values read out of the base revision
      // `45e6578`, not against a comment.
      //
      // A RETURN to an existing entry state keeps the triage/implementation
      // dispatch collision structurally unreachable; a WIDENING would put two
      // schedulers on one work item in the same tick. Option B — teach the
      // scheduler to honour a retry for an item outside `entryStates` — was
      // rejected for exactly that reason, and this assertion is what would fail
      // if it had been implemented by the back door instead.
      expect(
        implementFeatureDefinition.entryStates,
        {WorkItemState.implementationReady},
        reason:
            'the implementation lane is the one-element set that makes '
            'the collision unreachable. Widening it by even one state destroys '
            'the property.',
      );
      expect(triageDefectDefinition.entryStates, {
        WorkItemState.designNotRequired,
        WorkItemState.designApproved,
        WorkItemState.reviewRejected,
      });
      expect(engineeringReviewDefinition.entryStates, {
        WorkItemState.agentCompleted,
      });
      expect(designRevisionDefinition.entryStates, {
        WorkItemState.designRequired,
        WorkItemState.designRejected,
      });
      expect(designReviewDefinition.entryStates, {
        WorkItemState.designInReview,
      });
      expect(defaultImplementFeatureDefinition.entryStates, {
        WorkItemState.designNotRequired,
        WorkItemState.designApproved,
      });
      expect(onboardProductDefinition.entryStates, {
        WorkItemState.designNotRequired,
      });
    });

    test('the entry sets are still pairwise disjoint where they must be', () {
      final triage = triageDefectDefinition.entryStates;
      final implementation = implementFeatureDefinition.entryStates;
      final review = engineeringReviewDefinition.entryStates;

      expect(
        triage.intersection(implementation),
        isEmpty,
        reason:
            'DISJOINTNESS IS THE INVARIANT. Two definitions sharing an entry '
            'state can contend for one work item in the same tick, because '
            '`Scheduler.tick` reads EVERY item and enqueues for every runnable '
            'one. This is the property the whole `implementationReady` state '
            'was introduced to establish and this change does not touch it.',
      );
      expect(
        triage.intersection(review),
        isEmpty,
        reason: 'triage and review must not share an entry state either',
      );
      expect(
        implementation.intersection(review),
        isEmpty,
        reason:
            'and implementation and review must not either — which is the '
            'whole reason `OD-10` built the return as an INFLOW rather than '
            'widening the set',
      );
    });

    test('the states a retry returns to are entry states, and no others', () {
      // The property the fix rests on, read off the policy rather than off a
      // list written beside it: every retry-return target is a state a wired
      // definition really dispatches from.
      for (final (definition, failureState) in <(JobDefinition, WorkItemState)>[
        (implementFeatureDefinition, WorkItemState.agentFailed),
        (triageDefectDefinition, WorkItemState.agentFailed),
        (defaultImplementFeatureDefinition, WorkItemState.agentFailed),
        (onboardProductDefinition, WorkItemState.agentFailed),
        (designRevisionDefinition, WorkItemState.agentFailed),
        (designReviewDefinition, WorkItemState.agentFailed),
        (engineeringReviewDefinition, WorkItemState.reviewInProgress),
      ]) {
        final reachable = definition.entryStates.where((entry) {
          return WorkItemTransitions.isLegalTransition(failureState, entry);
        }).toSet();

        expect(
          reachable.length,
          1,
          reason:
              '${definition.jobType.wire} has ${reachable.length} entry states '
              'reachable from ${failureState.wire} '
              '(${definition.entryStates.map((s) => s.wire).toList()}), and the '
              'retry return needs EXACTLY ONE. Zero strands the retry and more '
              'than one is refused.',
        );
        expect(
          reachable,
          definition.entryStates.intersection(reachable),
          reason: 'a return target is BY CONSTRUCTION an entry state',
        );
      }
    });
  });
}

/// The IMPLEMENTER's completed result, which is what
/// `GuardConditions.agentResultValid()` reads out of `context['agentResult']`
/// on the `agentCompleted -> reviewInProgress` edge.
///
/// The coordinator supplies this from the execution store
/// (`_reviewEntryTransitionContext`); a test supplies it directly, because
/// building a whole execution history is not what the retry return is under
/// test.
AgentResult _producerResult(String workItemId) => AgentResult(
  resultId: 'result-impl-$workItemId',
  sessionId: 'ses-impl',
  workItemId: workItemId,
  status: AgentResultStatus.completed,
  artifacts: const [],
  diagnostics: const AgentDiagnostics(
    exitCode: 0,
    durationMs: 1000,
    toolCalls: 1,
    errors: [],
    warnings: [],
  ),
  structuredResult: const {},
  executionId: 'agx-exec-impl-1',
  role: AgentRole.implementer,
  completedAt: DateTime.utc(2026, 3, 1, 11),
);

WorkerExecutionResult _outcome(
  WorkerExecutionRequest request,
  WorkerExecutionStatus status,
) => WorkerExecutionResult(
  workerExecutionId: request.workerExecutionId,
  workItemId: request.workItemId,
  status: status,
  workerId: 'w-scripted-1',
  workspaceId: 'ws-${request.workerExecutionId}',
  startingRevision: request.startingRevision,
  startedAt: DateTime.utc(2026, 3, 1, 12),
  endedAt: DateTime.utc(2026, 3, 1, 12, 5),
  cleanupStatus: WorkerCleanupStatus.removed,
  failureCode: WorkerFailureCode.none,
  failureDetail: null,
);
