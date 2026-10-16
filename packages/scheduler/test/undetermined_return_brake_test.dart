import 'dart:io';

import 'package:agent_runtime/agent_runtime.dart';
import 'package:execution_coordinator/execution_coordinator.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/gate_fake_agent.dart';

/// Finding H1: the completion cycle runs for ever when the platform cannot
/// establish whether a run produced anything, and nothing stops it.
///
/// ## THE LOOP, AS PRODUCTION WALKS IT
///
/// ```text
///   agentCompleted -> implementationReady -> agentExecuting -> agentCompleted
///        ^                                                            |
///        |  producedCommitFor says NoCommitProduced (endingRevision null)|
///        +------------------------------------------------------------+
///
/// ```
///
/// `maxImplementationInflows` used to stop that. It was removed on purpose
/// (human decision `92d567e3-da03-4c43-99f4-e3726472f0ab`, `RETRY_LIMIT =
/// REMOVE`) because the coordinator now fails a no-output implementation
/// PERMANENTLY, so that cycle has no implementer step to walk. What it did not
/// consider is the run whose artifact could not be ESTABLISHED: `RoleAware
/// SuccessArtifacts` answers `UNDETERMINED` rather than `MISSING` when git is
/// missing, the filesystem is wedged or the probe's 30s timeout expires — a
/// tooling fault is not an agent that did nothing. That run is NOT failed, so
/// it still reaches `agentCompleted`, still leaves no commit, and is still
/// routed here. `maxAttempts: 2` is a JOB budget and each pass mints a fresh
/// job, so it bounds nothing.
///
/// ## WHY EVERY KEY BELOW IS A STRING LITERAL
///
/// So this file compiles and runs against the UNREVIEWED tree, where it fails.
/// A test written against exported constants could only be run on a tree that
/// already has them, which makes "it fails before the fix" impossible to
/// demonstrate and leaves the wire keys unverified by construction.
/// `undetermined_brake_contract_test.dart` pins the exported constants to these
/// same literals, so the two halves cannot drift apart: the behavioural half
/// proves the platform reads these exact keys, the contract half proves the
/// named constants spell them.
const String undeterminedFlagKey = 'successArtifactUndetermined';
const String undeterminedStreakKey = 'successArtifactUndeterminedStreak';

const _startRevision = '0f9a1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b';
const _produced = 'federated-feed-routing';

/// How many undetermined returns the platform has ALREADY spent an automatic
/// route on, as recorded on the work item.
///
/// The value the brake refuses at. This is a literal rather than
/// `maxConsecutiveUndeterminedReturns - 1` so that the two tests in this file
/// cannot agree by construction: a test seeded from the constant validates the
/// constant against itself. `undetermined_brake_contract_test.dart` pins the
/// constant's own value.
const _streakAtTheCeiling = 2;
const _streakBelowTheCeiling = 1;

WorkItem _atAgentCompleted({
  String workItemId = 'wi-1',
  Object? producerActorId = 'agx-exec-impl-1',
  Map<String, dynamic>? metadata,
}) => WorkItem(
  workItemId: workItemId,
  productId: 'prod-1',
  category: WorkItemCategory.bugfix,
  title: 'Route the federated feed',
  description: 'A producer finished and left whatever it left.',
  state: WorkItemState.agentCompleted,
  metadata: {
    if (producerActorId != null) 'producerActorId': producerActorId,
    ...?metadata,
  },
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

/// One worker execution, shaped the way `LocalWorker._finish` records it.
WorkerExecution _execution({
  required String workerExecutionId,
  String workItemId = 'wi-1',
  required String? agentExecutionId,
  required String? endingRevision,
}) => WorkerExecution(
  workerExecutionId: workerExecutionId,
  workItemId: workItemId,
  repositoryPath: '/durable/clone',
  requestedStartingRevision: _startRevision,
  requiredCapabilities: const {WorkerCapability.linux, WorkerCapability.git},
  agentExecutionId: agentExecutionId,
  endingRevision: endingRevision,
  status: WorkerExecutionStatus.executedPass,
  cleanupPolicy: WorkerCleanupPolicy.removeAlways,
);

/// A dispatch that reports "no compatible worker", so the scheduler builds the
/// request — proving what it WOULD have spent — and never runs one.
class _CapturingDispatch implements WorkerDispatch {
  final List<WorkerExecutionRequest> requests = [];

  @override
  WorkerSelection select(WorkerExecutionRequest request) {
    requests.add(request);
    return WorkerSelection.noCompatibleWorker();
  }

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) =>
      throw StateError('no execution may run in this file');

  @override
  Future<void> cancel(String workerId, String reason) async {}
}

const _workload = SchedulerWorkload(
  repositoryPath: '/durable/clone',
  startingRevision: _startRevision,
  timeoutSeconds: 1800,
  runtimeTypeId: 'rt-product',
);

({Scheduler scheduler, InMemoryJobStore jobStore, _CapturingDispatch dispatch})
_implLane(InMemoryWorkflowStore workflowStore, WorkerStore workerStore) {
  final dispatch = _CapturingDispatch();
  final jobStore = InMemoryJobStore();
  return (
    scheduler: Scheduler(
      schedulerId: 'sched-impl',
      workflowStore: workflowStore,
      jobStore: jobStore,
      workerStore: workerStore,
      dispatch: dispatch,
      definition: implementFeatureDefinition,
      workload: _workload,
      dedupeKeyBuilder: implementFeatureDedupeKey,
      instructionBuilder: implementFeatureInstruction,
      requestBuilder: implementFeatureRequest,
      workloadResolver: (job, item) async => _workload,
      clock: () => DateTime.utc(2026, 1, 1),
    ),
    jobStore: jobStore,
    dispatch: dispatch,
  );
}

Future<WorkerStore> _storeWith(List<WorkerExecution> executions) async {
  final store = InMemoryWorkerStore();
  for (final execution in executions) {
    await store.saveWorkerExecution(execution);
  }
  return store;
}

void main() {
  group('the brake stops the automatic route', () {
    test('at the ceiling the item is NOT routed, NOT dispatched, and a stall is '
        'raised for a human', () async {
      final workflowStore = InMemoryWorkflowStore();
      await workflowStore.saveWorkItem(
        _atAgentCompleted(
          metadata: const {
            undeterminedFlagKey: true,
            undeterminedStreakKey: _streakAtTheCeiling,
          },
        ),
      );
      final lane = _implLane(
        workflowStore,
        await _storeWith([
          _execution(
            workerExecutionId: 'wx-1',
            agentExecutionId: 'agx-exec-impl-1',
            endingRevision: null,
          ),
        ]),
      );

      final result = await lane.scheduler.tick();
      final item = await workflowStore.readWorkItem('wi-1');

      expect(
        result.completionInflow.single.moved,
        isFalse,
        reason:
            'the Nth consecutive undetermined return is refused, not routed',
      );
      expect(
        item.state,
        WorkItemState.agentCompleted,
        reason:
            'nothing may be moved: `agentCompleted` has no edge to a human '
            'state this lane may take. What stops the spend is that no job is '
            'minted and nothing is dispatched',
      );
      expect(
        lane.dispatch.requests,
        isEmpty,
        reason:
            'THE POINT OF THE BRAKE. A refusal that still dispatched would spend '
            'the execution it just declined to authorise',
      );
      expect(await lane.jobStore.listJobsForWorkItem('wi-1'), isEmpty);
      expect(
        item.metadata?[undeterminedStreakKey],
        _streakAtTheCeiling,
        reason:
            'a refused route spends nothing, exactly as the commit route does',
      );

      // A human is engaged through the ONE channel the composition root already
      // drains: `SchedulerStall` -> `raiseStallDecisions` -> a blocking
      // `HumanDecision` the control-plane decision screen renders.
      final stall = result.stalled.singleWhere((s) => s.workItemId == 'wi-1');
      expect(stall.jobType, JobType.implementFeature);
      expect(
        stall.deferrals,
        _streakAtTheCeiling,
        reason:
            'the executions actually BURNED, which is the recorded streak and '
            'NOT the return count: the return that tripped the brake is the one '
            'that was refused, so nothing was spent on it',
      );
      expect(stall.reason, contains('could not'));
      expect(
        result.completionInflow.single.reason,
        contains('undetermined'),
        reason:
            'the sentence an operator reads has to name the cause. A refusal '
            'that says only "budget spent" on an item whose budget is not spent '
            'is the false-reading class this file\'s neighbours were written to '
            'prevent',
      );
    });

    test('BELOW the ceiling the route is taken and the streak advances, so the '
        'counter is not merely a refusal', () async {
      final workflowStore = InMemoryWorkflowStore();
      await workflowStore.saveWorkItem(
        _atAgentCompleted(
          metadata: const {
            undeterminedFlagKey: true,
            undeterminedStreakKey: _streakBelowTheCeiling,
          },
        ),
      );
      final lane = _implLane(
        workflowStore,
        await _storeWith([
          _execution(
            workerExecutionId: 'wx-1',
            agentExecutionId: 'agx-exec-impl-1',
            endingRevision: null,
          ),
        ]),
      );

      final result = await lane.scheduler.tick();
      final item = await workflowStore.readWorkItem('wi-1');

      expect(result.completionInflow.single.moved, isTrue);
      expect(item.state, WorkItemState.implementationReady);
      expect(lane.dispatch.requests, hasLength(1));
      expect(
        item.metadata?[undeterminedStreakKey],
        _streakBelowTheCeiling + 1,
        reason:
            'the streak this route spends is written DURABLY, so the next '
            'return is counted against the same number even across a restart',
      );
    });

    test('a DETERMINED completion resets the streak to zero — the counter means '
        'consecutive', () async {
      final workflowStore = InMemoryWorkflowStore();
      await workflowStore.saveWorkItem(
        _atAgentCompleted(
          metadata: const {
            undeterminedFlagKey: false,
            undeterminedStreakKey: 2,
          },
        ),
      );
      final lane = _implLane(
        workflowStore,
        await _storeWith([
          _execution(
            workerExecutionId: 'wx-1',
            agentExecutionId: 'agx-exec-impl-1',
            endingRevision: null,
          ),
        ]),
      );

      await lane.scheduler.tick();

      expect(
        (await workflowStore.readWorkItem(
          'wi-1',
        )).metadata?[undeterminedStreakKey],
        0,
        reason:
            'the platform could read this run\'s workspace, so whatever came '
            'before is not consecutive with it. Leaving 2 in place would turn a '
            'recovery into a permanent stall on a later, unrelated fault',
      );
    });

    test('the counter survives a process restart, because it is durable state '
        'and not a field on the scheduler', () async {
      final workflowStore = InMemoryWorkflowStore();
      final workerStore = await _storeWith([
        _execution(
          workerExecutionId: 'wx-1',
          agentExecutionId: 'agx-exec-impl-1',
          endingRevision: null,
        ),
      ]);
      await workflowStore.saveWorkItem(
        _atAgentCompleted(
          metadata: const {
            undeterminedFlagKey: true,
            undeterminedStreakKey: _streakBelowTheCeiling,
          },
        ),
      );

      // Tick one spends the last entry and takes the item to implementationReady.
      await _implLane(workflowStore, workerStore).scheduler.tick();

      // A REDEPLOY: a brand new Scheduler over the same durable stores, and the
      // cycle walked one more lap — `implementationReady -> agentExecuting ->
      // agentCompleted` — which is exactly what the previous lap's
      // implementer run would have done.
      final engine = DurableWorkflowEngine(store: workflowStore);
      await engine.transition(
        workItemId: 'wi-1',
        to: WorkItemState.agentExecuting,
        trigger: TransitionTrigger.systemEvent,
        actor: schedulerOrchestratorActor,
        context: const {'agentAvailable': true, 'capabilitiesMatch': true},
      );
      await engine.transition(
        workItemId: 'wi-1',
        to: WorkItemState.agentCompleted,
        trigger: TransitionTrigger.agentResult,
        actor: schedulerOrchestratorActor,
        context: {'qaContractId': 'qa-1', 'agentResult': _completedResult()},
      );
      final returned = await workflowStore.readWorkItem('wi-1');
      await workflowStore.saveWorkItem(
        returned.copyWith(
          metadata: {
            ...?returned.metadata,
            'producerActorId': 'agx-exec-impl-2',
          },
        ),
      );
      await workerStore.saveWorkerExecution(
        _execution(
          workerExecutionId: 'wx-2',
          agentExecutionId: 'agx-exec-impl-2',
          endingRevision: null,
        ),
      );

      final restarted = _implLane(workflowStore, workerStore);
      final result = await restarted.scheduler.tick();

      expect(
        result.completionInflow.single.moved,
        isFalse,
        reason:
            'the streak read 3 in the store, and a NEW Scheduler object read it '
            'back. A counter held on the instance would have started at 0 here '
            'and handed the platform a fresh budget on every redeploy — which is '
            'exactly what happens when a fleet starts looping',
      );
      expect(restarted.dispatch.requests, isEmpty);
      expect(result.stalled, hasLength(1));
    });

    test('the brake never withholds a REAL commit, at any streak', () async {
      // The direction that must not regress. `completionRouteFor` sends a
      // producer that committed to `reviewInProgress`, which is the REVIEW
      // lane's entry state and not an entry into this one; a counter about this
      // lane's entries has no standing to refuse a route into another lane, and
      // withholding a real commit from review is not recoverable.
      for (final streak in const [0, 3, 40]) {
        final workflowStore = InMemoryWorkflowStore();
        await workflowStore.saveWorkItem(
          _atAgentCompleted(
            metadata: {
              undeterminedFlagKey: true,
              undeterminedStreakKey: streak,
            },
          ),
        );
        final lane = _implLane(
          workflowStore,
          await _storeWith([
            _execution(
              workerExecutionId: 'wx-1',
              agentExecutionId: 'agx-exec-impl-1',
              endingRevision: _produced,
            ),
          ]),
        );

        final result = await lane.scheduler.tick();

        expect(
          result.stalled,
          isEmpty,
          reason:
              'at streak $streak the route is `reviewInProgress`. This lane '
              'does not take it — the transitions table refuses it — and it '
              'must not claim a stall over a route it never had',
        );
        expect(
          (await workflowStore.readWorkItem('wi-1')).state,
          WorkItemState.agentCompleted,
        );
      }
    });

    test('an UNREADABLE streak isolates one item and does not abort the lane\'s '
        'tick', () async {
      // The same argument `readTriageAttempt` makes, for the second marker.
      // Coercing a bad byte to 0 would RESET a spent brake; coercing it to the
      // ceiling would park work on a byte nobody wrote deliberately. Neither is
      // available, so the read throws — INSIDE the per-item guard, or one
      // corrupt work item costs the whole lane its pass.
      final workflowStore = InMemoryWorkflowStore();
      await workflowStore.saveWorkItem(
        _atAgentCompleted(
          workItemId: 'wi-bad',
          metadata: const {
            undeterminedFlagKey: true,
            undeterminedStreakKey: 'nope',
          },
        ),
      );
      await workflowStore.saveWorkItem(
        _atAgentCompleted(
          workItemId: 'wi-good',
          producerActorId: 'agx-exec-impl-2',
        ),
      );
      final workerStore = await _storeWith([
        _execution(
          workerExecutionId: 'wx-1',
          workItemId: 'wi-bad',
          agentExecutionId: 'agx-exec-impl-1',
          endingRevision: null,
        ),
        _execution(
          workerExecutionId: 'wx-2',
          workItemId: 'wi-good',
          agentExecutionId: 'agx-exec-impl-2',
          endingRevision: null,
        ),
      ]);
      final lane = _implLane(workflowStore, workerStore);

      final SchedulerTickResult result;
      try {
        result = await lane.scheduler.tick();
      } on Object catch (error) {
        fail(
          'a corrupt undetermined streak on one work item took the whole lane\'s '
          'tick with it: $error',
        );
      }

      expect(
        result.completionInflow.singleWhere((m) => m.workItemId == 'wi-bad').to,
        isNull,
        reason: 'an unknown count is not a licence to move the item',
      );
      expect(
        (await workflowStore.readWorkItem('wi-good')).state,
        WorkItemState.implementationReady,
        reason:
            'one item\'s corrupt bytes must not cost every other item its '
            'route. That is the difference between a guard and a comment',
      );
      expect(lane.dispatch.requests, hasLength(1));
    });
  });

  group('the cycle terminates — on the COMBINED tree, through the undetermined '
      'path', () {
    test('repeated UNDETERMINED returns stop being routed after a bounded '
        'number of passes', () async {
      // THE PROPERTY THIS ENTIRE CHANGE RESTS ON, and the executable statement
      // of it. `the automatic route is UNBOUNDED` in
      // `implementation_completion_inflow_test.dart` asserts the NEW behaviour
      // rather than the safety, and the only test that used to assert the
      // safety — `the cycle still terminates: the commit route spends nothing,
      // and the bound closes the loop` — was deleted with the bound it named.
      //
      // It is written here rather than in that file because the cycle spans two
      // packages: `ExecutionCoordinator` settles the return and stamps the
      // verdict, and `Scheduler` reads that verdict and spends the next pass.
      // Neither suite can see the other half, and a test that drives only the
      // scheduler half would be asserting against a marker no production code
      // writes.
      //
      // Every participant is production code over real in-memory stores. The
      // ONE seam is the `WorkerExecution` row, written below in the shape
      // `LocalWorker._finish` records it — the same seam
      // `implementation_completion_inflow_test.dart` has always used, and one
      // `worker_runtime`'s own suite covers on the write side.
      //
      // The bound below is a LITERAL, not the constant: the property under test
      // is "bounded", and the constant's own value is pinned in
      // `undetermined_brake_contract_test.dart`. Writing the number here twice
      // is what stops the constant validating itself.
      const maxPasses = 6;

      final temp = Directory.systemTemp.createTempSync('undetermined_cycle_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });

      final workflowStore = InMemoryWorkflowStore();
      final workflowEngine = DurableWorkflowEngine(store: workflowStore);
      final executionStore = InMemoryExecutionStore();
      final workerStore = InMemoryWorkerStore();

      // The cause: the platform's own probe cannot be run. The REAL
      // `GitWorkspaceDeltaProbe`, pointed at a git that does not exist — not a
      // stubbed verdict, so `UNDETERMINED` is reached the way production
      // reaches it.
      const artifacts = RoleAwareSuccessArtifacts(
        probe: GitWorkspaceDeltaProbe(git: '/no/such/git-binary'),
      );
      final session = GateFakeAgentSession(
        executionId: 'agx-0',
        workItemId: 'wi-1',
      );
      final coordinator = ExecutionCoordinator(
        store: executionStore,
        workflowEngine: workflowEngine,
        runtime: AgentRuntime(
          registry: AgentAdapterRegistry()
            ..register(GateFakeAgentAdapter(session)),
        ),
        successArtifacts: artifacts,
      );

      await workflowEngine.createWorkItem(
        workItemId: 'wi-1',
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'Route the federated feed',
        description: 'Every run comes back undetermined',
        qaContractId: 'qa-1',
        featureRef: 'feature/federated-feed',
      );
      for (final to in const [
        WorkItemState.planning,
        WorkItemState.planned,
        WorkItemState.designNotRequired,
      ]) {
        await workflowEngine.transition(
          workItemId: 'wi-1',
          to: to,
          trigger: TransitionTrigger.systemEvent,
          actor: schedulerOrchestratorActor,
          context: const {'featureRef': 'feature/federated-feed'},
        );
      }

      final lane = _implLane(workflowStore, workerStore);
      final acceptedRoutes = <int>[];
      int? stoppedAt;

      for (var pass = 1; pass <= maxPasses; pass++) {
        // The scripted session parks on a release gate on its FIRST execution;
        // opening it before the run keeps every pass deterministic with no
        // timers. After the first it passes straight through.
        session.release();
        // A REAL implementation run. It finishes cleanly, produces nothing this
        // platform can see, and its verdict is UNDETERMINED — so it is not
        // failed and it DOES reach `agentCompleted` with the flag stamped.
        final executionId = 'agx-pass-$pass';
        await coordinator.execute(
          AgentExecutionRequest(
            executionId: executionId,
            workItemId: 'wi-1',
            role: AgentRole.implementer,
            runtimeTypeId: 'fake-runtime',
            workspace: AgentWorkspace(
              workspaceId: 'ws-$pass',
              path: temp.path,
              startingRevision: _startRevision,
            ),
            instruction: 'implement the feature',
            timeoutSeconds: 60,
          ),
        );
        expect(
          await workflowStore
              .readWorkItem('wi-1')
              .then((i) => i.metadata?[undeterminedFlagKey]),
          isTrue,
          reason:
              'pass $pass came back undetermined. If this ever reads false the '
              'loop below is being exercised for the wrong reason and the '
              'termination it proves would be the missing-artifact rule\'s, '
              'not the brake\'s',
        );
        // What `LocalWorker._finish` records for that run: the agent execution
        // id the coordinator stamped, and no ending revision, because nothing
        // was committed that git could report.
        await workerStore.saveWorkerExecution(
          _execution(
            workerExecutionId: 'wx-pass-$pass',
            agentExecutionId: executionId,
            endingRevision: null,
          ),
        );

        final dispatchedBefore = lane.dispatch.requests.length;
        final result = await lane.scheduler.tick();
        final move = result.completionInflow.singleWhere(
          (m) => m.workItemId == 'wi-1',
        );

        if (!move.moved) {
          stoppedAt = pass;
          expect(
            lane.dispatch.requests.length,
            dispatchedBefore,
            reason:
                'the pass that is refused must spend nothing. One dispatch '
                'here and the brake is not bounding anything',
          );
          break;
        }
        acceptedRoutes.add(pass);
        expect(
          (await workflowStore.readWorkItem('wi-1')).state,
          WorkItemState.implementationReady,
        );
      }

      expect(
        stoppedAt,
        isNotNull,
        reason:
            'the loop ran $maxPasses passes of UNDETERMINED returns and was '
            'still routing every one of them. That is the unbounded loop finding '
            'H1 describes, reproduced in full: agentCompleted -> '
            'implementationReady -> agentExecuting -> agentCompleted, one real '
            'implementer execution per lap, unattended, for ever',
      );
      expect(
        stoppedAt,
        _streakAtTheCeiling + 1,
        reason:
            'the refusal lands on the return AFTER the ceiling, not merely '
            'somewhere inside the window. A brake that fired early would starve '
            'an item whose tooling recovered on its own, and one that fired late '
            'would buy extra executions; both are wrong and only the exact pass '
            'distinguishes them',
      );
      expect(
        acceptedRoutes.length,
        _streakAtTheCeiling,
        reason:
            'the accepted routes are the executions the platform spent on its '
            'own broken tooling. Fewer than the window is the whole property, '
            'and this is how many fewer',
      );

      // AND TERMINAL. More ticks must not start another pass: the item is back
      // at `agentCompleted` with a producer that committed nothing, which is
      // the exact shape the brake has to keep refusing.
      final stalledOnce = (await lane.scheduler.tick()).stalled.length;
      final dispatchAfterStop = lane.dispatch.requests.length;
      for (var extra = 0; extra < 3; extra++) {
        await lane.scheduler.tick();
      }
      expect(
        lane.dispatch.requests.length,
        dispatchAfterStop,
        reason:
            'the refused item is still at `agentCompleted` with a no-commit '
            'producer. A brake that holds for one tick and then forgets has not '
            'stopped anything — it has paused something, and the platform ticks '
            'every 30 seconds',
      );
      expect(
        (await workflowStore.readWorkItem('wi-1')).state,
        WorkItemState.agentCompleted,
        reason: 'nothing may move it: no edge out of here leads to a human',
      );
      expect(
        stalledOnce,
        1,
        reason:
            'and every tick still reports the stall, which is what the '
            'composition root drains into `raiseStallDecisions`. A conclusion '
            'the platform stops reporting is a conclusion it has discarded',
      );
    });
  });
}

AgentResult _completedResult() => AgentResult(
  resultId: 'res-1',
  sessionId: 'ses-1',
  workItemId: 'wi-1',
  status: AgentResultStatus.completed,
  artifacts: const [],
  diagnostics: AgentDiagnostics(
    exitCode: 0,
    durationMs: 1,
    toolCalls: 1,
    errors: const [],
    warnings: const [],
  ),
  structuredResult: const {},
  summary: 'fixture',
  completedAt: DateTime.utc(2026, 1, 1),
);
