import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';

/// `OD-10`'s discriminator, mutation-tested.
///
/// ## The rule under test
///
/// A producer that left an implementation artifact routes to review. A producer
/// that left none routes to the implementation lane. The failure that matters
/// is the second case being wrong in the FIRST direction: sending real work to
/// a second implementer manufactures a duplicate commit, and two commits of the
/// same change into a governed repository is not a recoverable state.
///
/// So this file is built backwards from that. It does not assert that the
/// no-artifact case routes correctly — that is the easy half. It asserts that
/// **every shape of "yes, there is a commit" routes to review**, and it builds
/// each shape as real durable rows rather than as a mock's return value.
///
/// ## Why the producer is built out of REAL `WorkerExecution` rows
///
/// `producedCommitFor` answers a question about durable state: the coordinator
/// stamps `producerActorId` on the work item, `LocalWorker` records that id as
/// `agentExecutionId` on the execution, and `ArtifactCommitter` sets
/// `endingRevision` when it commits. Asserting against a stubbed reader would
/// prove that the function switches on a boolean someone handed it. These
/// tests assemble the three records the way production assembles them, so a
/// change to any one of the three rules breaks them.
const _produced = 'federated-feed-routing';
const _startRevision = '0f9a1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b';

WorkItem _completed({
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
  String requestedStartingRevision = _startRevision,
  String repositoryPath = '/durable/clone',
  Set<WorkerCapability> capabilities = const {
    WorkerCapability.linux,
    WorkerCapability.git,
  },
}) => WorkerExecution(
  workerExecutionId: workerExecutionId,
  workItemId: workItemId,
  repositoryPath: repositoryPath,
  requestedStartingRevision: requestedStartingRevision,
  requiredCapabilities: capabilities,
  agentExecutionId: agentExecutionId,
  endingRevision: endingRevision,
  status: WorkerExecutionStatus.executedPass,
  cleanupPolicy: WorkerCleanupPolicy.removeAlways,
);

Future<WorkerStore> _storeWith(List<WorkerExecution> executions) async {
  final store = InMemoryWorkerStore();
  for (final execution in executions) {
    await store.saveWorkerExecution(execution);
  }
  return store;
}

/// A tick handler that reports "no compatible worker", so the scheduler builds
/// the request — proving what it WOULD have dispatched — and never runs one.
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

/// The implementation lane's scheduler over real in-memory stores, with the
/// dispatch spy and the job store handed back.
///
/// Built here rather than repeated per test because the group below sweeps the
/// SAME setup across several `triageAttempt` markers, and a test that rebuilds
/// the lane inline at each marker is a test where a typo in the fixture only
/// shows up for one of them.
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

/// Re-stamps `producerActorId`, which is what `ExecutionCoordinator
/// ._completeSuccess` writes after every successful run and what makes the
/// discriminator read the run that finished LAST rather than the last one in the
/// list.
///
/// Written directly because the coordinator is not reachable from this package.
/// It is a fixture, not a shortcut: it replaces one metadata key and touches no
/// state, so the routing under test still has to be derived from the
/// `WorkerExecution` rows the test also wrote.
Future<void> _restampProducer(
  InMemoryWorkflowStore store,
  String agentExecutionId,
) async {
  final item = await store.readWorkItem('wi-1');
  await store.saveWorkItem(
    item.copyWith(
      metadata: {...?item.metadata, 'producerActorId': agentExecutionId},
    ),
  );
}

/// Walks `wi-1` through one real implementer run and back to `agentCompleted`,
/// the edge the inflow's own cycle runs on: `implementationReady ->
/// agentExecuting -> agentCompleted`.
///
/// Through the engine rather than by writing the state, because those two edges
/// are the guarded ones — `agentExecuting -> agentCompleted` carries
/// `qaContractExists()` AND `agentResultValid()` — and a loop test that skipped
/// them would be exercising a path no production run takes.
Future<void> _completeAnImplementationRun(InMemoryWorkflowStore store) async {
  final engine = DurableWorkflowEngine(store: store);
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
}

void main() {
  group('the discriminator reads the producer, not the clock', () {
    test(
      'a commit that differs from the starting revision IS produced',
      () async {
        final store = await _storeWith([
          _execution(
            workerExecutionId: 'wx-1',
            agentExecutionId: 'agx-exec-impl-1',
            endingRevision: _produced,
          ),
        ]);

        final verdict = await producedCommitFor(store, _completed());

        expect(verdict, isA<CommitProduced>());
        expect((verdict as CommitProduced).commit, _produced);
        expect(verdict.isProduced, isTrue);
      },
    );

    test('no commit at all is NOT produced, and says why', () async {
      final store = await _storeWith([
        _execution(
          workerExecutionId: 'wx-1',
          agentExecutionId: 'agx-exec-impl-1',
          endingRevision: null,
        ),
      ]);

      final verdict = await producedCommitFor(store, _completed());

      expect(verdict, isA<NoCommitProduced>());
      expect(
        (verdict as NoCommitProduced).cause,
        NoProducedCommitReason.noCommitProduced,
      );
    });

    test('an execution that ended where it started committed nothing', () async {
      // Distinct from the null case and for a different reason: the agent ran,
      // wrote files, and `ArtifactCommitter` found no net change. Both are "no
      // commit"; only one of them is "no artifact because nothing was written".
      final store = await _storeWith([
        _execution(
          workerExecutionId: 'wx-1',
          agentExecutionId: 'agx-exec-impl-1',
          endingRevision: _startRevision,
        ),
      ]);

      expect(
        await producedCommitFor(store, _completed()),
        isA<NoCommitProduced>(),
      );
    });

    test(
      'a LATER run that committed nothing cannot mask the implementer',
      () async {
        // Why recency would be wrong, stated as an assertion. `LocalWorker`
        // commits for every non-reviewer role, so a triage run after an
        // implementer is exactly as much a candidate. Anchoring on
        // `producerActorId` is what keeps the triage commit from being read as
        // the implementation under review.
        final store = await _storeWith([
          _execution(
            workerExecutionId: 'wx-impl',
            agentExecutionId: 'agx-exec-impl-1',
            endingRevision: _produced,
          ),
          _execution(
            workerExecutionId: 'wx-triage',
            agentExecutionId: 'agx-exec-triage-2',
            endingRevision: 'a-triage-report',
          ),
        ]);

        final verdict = await producedCommitFor(store, _completed());

        expect((verdict as CommitProduced).commit, _produced);
        expect(verdict.commit, isNot('a-triage-report'));
      },
    );

    test('every ambiguity fails closed, and names itself', () async {
      final noAnchor = await producedCommitFor(
        await _storeWith([
          _execution(
            workerExecutionId: 'wx-1',
            agentExecutionId: 'agx-exec-impl-1',
            endingRevision: _produced,
          ),
        ]),
        _completed(producerActorId: null),
      );
      expect(
        (noAnchor as NoCommitProduced).cause,
        NoProducedCommitReason.producerNotIdentified,
      );

      final noExecution = await producedCommitFor(
        await _storeWith([]),
        _completed(),
      );
      expect(
        (noExecution as NoCommitProduced).cause,
        NoProducedCommitReason.producerExecutionMissing,
      );

      final ambiguous = await producedCommitFor(
        await _storeWith([
          _execution(
            workerExecutionId: 'wx-1',
            agentExecutionId: 'agx-exec-impl-1',
            endingRevision: _produced,
          ),
          _execution(
            workerExecutionId: 'wx-2',
            agentExecutionId: 'agx-exec-impl-1',
            endingRevision: _produced,
          ),
        ]),
        _completed(),
      );
      expect(
        (ambiguous as NoCommitProduced).cause,
        NoProducedCommitReason.producerExecutionAmbiguous,
        reason:
            'two executions cannot be told apart from durable state. Picking '
            'one would dispatch a reviewer — or an implementer — at a revision '
            'nobody vouched for',
      );
    });

    test('the routing is the discriminator and nothing else', () {
      // The unit under test that the mutation proof needs: a broken
      // discriminator must be breakable HERE, at a value, rather than only
      // end to end.
      expect(
        completionRouteFor(
          const CommitProduced(repositoryPath: '/p', commit: _produced),
        ),
        WorkItemState.reviewInProgress,
      );
      expect(
        completionRouteFor(
          const NoCommitProduced(
            NoProducedCommitReason.noCommitProduced,
            'nothing was committed',
          ),
        ),
        WorkItemState.implementationReady,
      );
    });
  });

  group('the two routes, end to end through a real tick', () {
    test('a producer that committed NOTHING lands in implementationReady and '
        'is then dispatched', () async {
      final workflowStore = InMemoryWorkflowStore();
      await workflowStore.saveWorkItem(
        _completed(metadata: {'defectId': 'DEF-1'}),
      );
      final workerStore = await _storeWith([
        // The triage shape: the coordinator stamped `producerActorId`, the run
        // completed, and nothing was committed because no file was written.
        _execution(
          workerExecutionId: 'wx-triage',
          agentExecutionId: 'agx-exec-impl-1',
          endingRevision: null,
        ),
      ]);
      final jobStore = InMemoryJobStore();
      final dispatch = _CapturingDispatch();

      final scheduler = Scheduler(
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
      );

      final result = await scheduler.tick();

      expect(
        (await workflowStore.readWorkItem('wi-1')).state,
        WorkItemState.implementationReady,
      );
      expect(result.completionInflow, hasLength(1));
      expect(result.completionInflow.single.moved, isTrue);
      expect(
        result.completionInflow.single.to,
        WorkItemState.implementationReady,
      );

      // AND the routed item is genuinely dispatchable in the SAME tick. A
      // route that only becomes dispatchable next tick is a one-tick stall
      // repeated for ever on an item that loops.
      expect(result.enqueued, hasLength(1));
      expect(dispatch.requests, hasLength(1));
      expect(result.completionInflow.single.reason, contains('no code'));
    });

    test('a producer that DID commit is left exactly where it is — this is the '
        'case a broken discriminator destroys', () async {
      final workflowStore = InMemoryWorkflowStore();
      await workflowStore.saveWorkItem(_completed());
      final workerStore = await _storeWith([
        _execution(
          workerExecutionId: 'wx-impl',
          agentExecutionId: 'agx-exec-impl-1',
          endingRevision: _produced,
        ),
      ]);
      final jobStore = InMemoryJobStore();
      final dispatch = _CapturingDispatch();
      final scheduler = Scheduler(
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
      );

      final result = await scheduler.tick();

      // NOT moved. A commit exists; engineering review owns this item and is
      // already dispatching it. Routing it to implementation would run a
      // second implementer over code that was already written and committed.
      expect(
        (await workflowStore.readWorkItem('wi-1')).state,
        WorkItemState.agentCompleted,
        reason:
            'a real artifact must never be sent to the build queue. The '
            'consequence of getting this wrong is a duplicate commit of '
            'work that already exists',
      );
      expect(result.completionInflow.single.moved, isFalse);
      expect(result.completionInflow.single.to, isNull);

      // AND, symmetrically: no implementation job is minted for it. The item
      // is not in this lane's `entryStates` while it is at
      // `agentCompleted`, so nothing is enqueued.
      expect(result.enqueued, isEmpty);
      expect(dispatch.requests, isEmpty);
    });

    test('the inflow cannot run twice for the same producer', () async {
      // The idempotency key is per PRODUCER, so a replay after a partial write
      // returns the accepted outcome instead of moving a second time and
      // burning a second attempt.
      final workflowStore = InMemoryWorkflowStore();
      await workflowStore.saveWorkItem(_completed());
      final workerStore = await _storeWith([
        _execution(
          workerExecutionId: 'wx-triage',
          agentExecutionId: 'agx-exec-impl-1',
          endingRevision: null,
        ),
      ]);
      final jobStore = InMemoryJobStore();
      final scheduler = Scheduler(
        schedulerId: 'sched-impl',
        workflowStore: workflowStore,
        jobStore: jobStore,
        workerStore: workerStore,
        dispatch: _CapturingDispatch(),
        definition: implementFeatureDefinition,
        workload: _workload,
        dedupeKeyBuilder: implementFeatureDedupeKey,
        instructionBuilder: implementFeatureInstruction,
        requestBuilder: implementFeatureRequest,
        workloadResolver: (job, item) async => _workload,
        clock: () => DateTime.utc(2026, 1, 1),
      );

      await scheduler.tick();
      final attemptsAfterFirst = (await workflowStore.readWorkItem(
        'wi-1',
      )).metadata?['triageAttempt'];

      // Put the item back where the inflow looks for it, with the SAME producer
      // identity — the state a crash between the move and the retry would leave.
      //
      // The cycle is `agentCompleted -> implementationReady -> agentExecuting
      // -> agentCompleted`, NOT a direct hop back: `agentExecuting` is the only
      // edge into `agentCompleted` and it carries `qaContractExists()` and
      // `agentResultValid()`. Walking it is what makes this the same shape as a
      // real implementer run that produced nothing, and it is what proves the
      // bound below is reached through the actual cycle rather than a
      // hand-written state.
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

      await scheduler.tick();

      expect(
        (await workflowStore.readWorkItem('wi-1')).metadata?['triageAttempt'],
        attemptsAfterFirst,
        reason:
            'the replay of the same producer must not advance the attempt '
            'counter again, or one producer costs the item two of its three '
            'budgeted attempts',
      );
    });

    test('the automatic route is BOUNDED, and the bound hands the item to a '
        'human rather than dropping it', () async {
      final workflowStore = InMemoryWorkflowStore();
      // THE LITERAL, not the constant. A test that seeds
      // `maxImplementationInflows` validates the mechanism against itself and
      // says nothing at all about the value: setting the constant to 99 left
      // every test in this file green. The value is pinned separately, in the
      // "the bound IS three" test below.
      await workflowStore.saveWorkItem(
        _completed(metadata: const {'triageAttempt': 3}),
      );
      final workerStore = await _storeWith([
        _execution(
          workerExecutionId: 'wx-triage',
          agentExecutionId: 'agx-exec-impl-1',
          endingRevision: null,
        ),
      ]);
      final jobStore = InMemoryJobStore();
      final dispatch = _CapturingDispatch();

      final scheduler = Scheduler(
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
      );

      final result = await scheduler.tick();

      expect(
        (await workflowStore.readWorkItem('wi-1')).state,
        WorkItemState.agentCompleted,
        reason:
            'an item that cannot be implemented after its re-work budget is '
            'spent belongs in front of a person. Leaving it at agent_completed '
            'is what lets the review lane\'s fail-closed handler raise a '
            'blocking decision for it — and that handler STANDS DOWN while the '
            'budget lasts, so the two check the same number',
      );
      expect(result.completionInflow.single.moved, isFalse);
      expect(
        result.completionInflow.single.reason,
        contains('re-work discriminator'),
      );
      expect(result.enqueued, isEmpty);
      expect(dispatch.requests, isEmpty);
    });

    test(
      'an unreadable worker store leaves the item alone and is reported',
      () async {
        final workflowStore = InMemoryWorkflowStore();
        await workflowStore.saveWorkItem(_completed());

        final jobStore = InMemoryJobStore();
        final scheduler = Scheduler(
          schedulerId: 'sched-impl',
          workflowStore: workflowStore,
          jobStore: jobStore,
          workerStore: _ThrowingWorkerStore(),
          dispatch: _CapturingDispatch(),
          definition: implementFeatureDefinition,
          workload: _workload,
          dedupeKeyBuilder: implementFeatureDedupeKey,
          instructionBuilder: implementFeatureInstruction,
          requestBuilder: implementFeatureRequest,
          workloadResolver: (job, item) async => _workload,
          clock: () => DateTime.utc(2026, 1, 1),
        );

        final result = await scheduler.tick();

        expect(
          (await workflowStore.readWorkItem('wi-1')).state,
          WorkItemState.agentCompleted,
          reason: 'an unknown answer is not a licence to move the item',
        );
        expect(result.completionInflow.single.moved, isFalse);
        expect(
          result.completionInflow.single.reason,
          contains('could not be read'),
          reason:
              'the whole point of the channel is that "the lane looked and moved '
              'nothing" is distinguishable from "the lane never looked"',
        );
      },
    );

    test(
      'an UNREADABLE DISCRIMINATOR on one item does not abort the lane\'s tick',
      () async {
        // `DurableWorkflowEngine.readTriageAttempt` throws `FormatException` BY
        // DESIGN on a marker that is present and not an int/whole-double/
        // numeric-String — falling back would rebuild a dedupe key a terminal
        // job already holds. That is the right call inside the ENGINE.
        //
        // It was also, for one revision, a lane-wide outage: the read sat
        // outside the per-item guard, so one corrupt byte on one work item
        // propagated out of `_runCompletionInflow`, out of `tick`, and into the
        // composition root's `implementation.tick.failed` — which loses the
        // whole `SchedulerTickResult` and with it every UNRELATED runnable
        // `implementationReady` item that same tick could have dispatched.
        //
        // Two items, one corrupt. `wi-bad` cannot be routed; `wi-good` must
        // still be.
        final workflowStore = InMemoryWorkflowStore();
        await workflowStore.saveWorkItem(
          _completed(
            workItemId: 'wi-bad',
            metadata: {
              'triageAttempt': {'not': 'a number'},
            },
          ),
        );
        await workflowStore.saveWorkItem(
          _completed(workItemId: 'wi-good', producerActorId: 'agx-exec-impl-2'),
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
        final jobStore = InMemoryJobStore();
        final dispatch = _CapturingDispatch();
        final scheduler = Scheduler(
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
        );

        // The whole point: this RETURNS. It did not before.
        final SchedulerTickResult result;
        try {
          result = await scheduler.tick();
        } on Object catch (error) {
          fail(
            'a corrupt discriminator on one work item took the whole lane\'s '
            'tick with it: $error. Per-item isolation is only true if every '
            'per-item read is inside the per-item guard.',
          );
        }

        // Reported, not swallowed: the operator can tell which item and why.
        final bad = result.completionInflow.singleWhere(
          (m) => m.workItemId == 'wi-bad',
        );
        expect(bad.to, isNull);
        expect(bad.reason, contains('could not be read'));
        expect(
          (await workflowStore.readWorkItem('wi-bad')).state,
          WorkItemState.agentCompleted,
          reason: 'the item whose discriminator was illegible is left alone',
        );

        // AND the unrelated item still moved, in the same tick. This is the
        // half that was lost: the blast radius was the lane, not the inflow.
        expect(
          (await workflowStore.readWorkItem('wi-good')).state,
          WorkItemState.implementationReady,
          reason:
              'one item\'s corrupt metadata must not cost every other item '
              'its route. That is the difference between a guard and a comment',
        );
        expect(dispatch.requests, hasLength(1));
      },
    );

    test(
      'a lane that declares NO inflow never reads the worker store at all',
      () async {
        final workflowStore = InMemoryWorkflowStore();
        await workflowStore.saveWorkItem(_completed());
        final jobStore = InMemoryJobStore();
        var readCalls = 0;

        final scheduler = Scheduler(
          schedulerId: 'sched-triage',
          workflowStore: workflowStore,
          jobStore: jobStore,
          workerStore: _CountingWorkerStore(() => readCalls++),
          dispatch: _CapturingDispatch(),
          definition: triageDefectDefinition,
          workload: _workload,
          dedupeKeyBuilder: triageDefectDedupeKey,
          instructionBuilder: triageDefectInstruction,
          requestBuilder: triageDefectRequest,
          clock: () => DateTime.utc(2026, 1, 1),
        );

        final result = await scheduler.tick();

        expect(readCalls, 0);
        expect(result.completionInflow, isEmpty);
        expect(
          (await workflowStore.readWorkItem('wi-1')).state,
          WorkItemState.agentCompleted,
        );
      },
    );
  });

  group('the two routes cannot disagree with each other', () {
    test('EVERY refusal routes to implementation, and only a commit does not', () async {
      // The half of the non-divergence argument this package can see.
      //
      // What used to stand here derived the review side from the verdict under
      // test (`reviewDispatches = verdict is CommitProduced`) and then asserted
      // the two were disjoint. That re-spelled `completionRouteFor`'s own switch
      // — it could not detect divergence from the real resolver, because the
      // real resolver was never called. A test that can only fail when the thing
      // it is testing is copied into it is documentation.
      //
      // The real resolver lives in `apps/server`, which depends on THIS package,
      // so the executing comparison is
      // `apps/server/test/inflow_vs_review_route_test.dart` and it calls
      // `producedCommitFor` — the very function this file exercises, not a copy.
      // What remains here is the property that only this package can state: all
      // four refusals take the same route, so there is exactly one input class
      // on which the two lanes could ever contend.
      const refusals = <NoProducedCommitReason>[
        NoProducedCommitReason.producerNotIdentified,
        NoProducedCommitReason.producerExecutionMissing,
        NoProducedCommitReason.producerExecutionAmbiguous,
        NoProducedCommitReason.noCommitProduced,
      ];

      for (final cause in refusals) {
        expect(
          completionRouteFor(NoCommitProduced(cause, 'refused: $cause')),
          WorkItemState.implementationReady,
          reason:
              'a refusal is a defect attempt, never a wrong review. Diverging '
              'here would route a real commit to a second implementer',
        );
      }
      expect(
        completionRouteFor(
          const CommitProduced(repositoryPath: '/p', commit: 'c'),
        ),
        WorkItemState.reviewInProgress,
      );
      expect(
        NoProducedCommitReason.values,
        refusals,
        reason:
            'the list of causes is operator-facing, and a cause no input can '
            'reach is a diagnosis nobody can act on. Adding one without a row '
            'that produces it is how `producerExecutionIsReviewer` survived a '
            'review: the candidate loop skipped reviewer executions, so its '
            'branch below the skip was unreachable and it was still advertised',
      );
    });

    test('the bound is THREE, stated here rather than read from the constant', () async {
      // Why the value is three, and why it is pinned with a literal.
      //
      // Three, because the inflow buys an unattended IMPLEMENTATION attempt and
      // each one costs a real implementer execution against a product's durable
      // clone. Two covers the normal shape (an implementer that commits nothing
      // once, then succeeds); a third covers the run that failed for a reason
      // that fixed itself. The next step is a human, because the alternative is
      // an unattended machine spending real executions on an item that cannot
      // be implemented — the defect this lane exists to end, re-created with a
      // different shape.
      //
      // Pinned with a literal on purpose: every other test in this file that
      // touches the bound seeds the CONSTANT, which makes the constant validate
      // itself. Changing 3 to 99 left all sixteen tests green.
      expect(
        maxImplementationInflows,
        3,
        reason:
            'the automatic-entry budget. If this value is genuinely wrong, change '
            'it HERE with the reasoning updated, not silently in the constant',
      );

      // And behaviourally: two still routes, three does not. Both literals, so
      // the off-by-one in the comparison is caught rather than inherited.
      Future<WorkItemState> routeAt(Object marker) async {
        final workflowStore = InMemoryWorkflowStore();
        await workflowStore.saveWorkItem(
          _completed(metadata: {'triageAttempt': marker}),
        );
        final scheduler = Scheduler(
          schedulerId: 'sched-impl',
          workflowStore: workflowStore,
          jobStore: InMemoryJobStore(),
          workerStore: await _storeWith([
            _execution(
              workerExecutionId: 'wx-1',
              agentExecutionId: 'agx-exec-impl-1',
              endingRevision: null,
            ),
          ]),
          dispatch: _CapturingDispatch(),
          definition: implementFeatureDefinition,
          workload: _workload,
          dedupeKeyBuilder: implementFeatureDedupeKey,
          instructionBuilder: implementFeatureInstruction,
          requestBuilder: implementFeatureRequest,
          workloadResolver: (job, item) async => _workload,
          clock: () => DateTime.utc(2026, 1, 1),
        );
        await scheduler.tick();
        return (await workflowStore.readWorkItem('wi-1')).state;
      }

      expect(await routeAt(2), WorkItemState.implementationReady);
      expect(await routeAt(3), WorkItemState.agentCompleted);
    });

    test('the bound message names the counter it actually read', () async {
      // An item that entered the implementation lane ZERO times can carry a
      // high `triageAttempt`: the operator retry and resolved rework/reject
      // decisions advance the same marker. A refusal that said "already been put
      // into the implementation lane 2 time(s)" would be a false statement in
      // the one sentence an operator actually reads.
      final workflowStore = InMemoryWorkflowStore();
      await workflowStore.saveWorkItem(
        _completed(metadata: const {'triageAttempt': 2}),
      );
      final scheduler = Scheduler(
        schedulerId: 'sched-impl',
        workflowStore: workflowStore,
        jobStore: InMemoryJobStore(),
        workerStore: await _storeWith([
          _execution(
            workerExecutionId: 'wx-1',
            agentExecutionId: 'agx-exec-impl-1',
            endingRevision: null,
          ),
        ]),
        dispatch: _CapturingDispatch(),
        definition: implementFeatureDefinition,
        workload: _workload,
        dedupeKeyBuilder: implementFeatureDedupeKey,
        instructionBuilder: implementFeatureInstruction,
        requestBuilder: implementFeatureRequest,
        workloadResolver: (job, item) async => _workload,
        clock: () => DateTime.utc(2026, 1, 1),
      );

      // Two prior operator retries and no lane entry: the route is still taken
      // (2 < 3), and the item's marker is advanced by the ENGINE's own rule.
      final result = await scheduler.tick();
      expect(
        (await workflowStore.readWorkItem('wi-1')).metadata?['triageAttempt'],
        3,
        reason:
            'the inflow writes through `DurableWorkflowEngine.nextTriageAttempt`, '
            'not an inline `attempt + 1`, so the number the dedupe key builder '
            'reads back cannot be derived by a second rule',
      );
      expect(result.completionInflow.single.moved, isTrue);

      // And at the bound, the words are the ones an operator can act on.
      final bounded = InMemoryWorkflowStore();
      await bounded.saveWorkItem(
        _completed(metadata: const {'triageAttempt': 3}),
      );
      final boundedScheduler = Scheduler(
        schedulerId: 'sched-impl',
        workflowStore: bounded,
        jobStore: InMemoryJobStore(),
        workerStore: await _storeWith([
          _execution(
            workerExecutionId: 'wx-1',
            agentExecutionId: 'agx-exec-impl-1',
            endingRevision: null,
          ),
        ]),
        dispatch: _CapturingDispatch(),
        definition: implementFeatureDefinition,
        workload: _workload,
        dedupeKeyBuilder: implementFeatureDedupeKey,
        instructionBuilder: implementFeatureInstruction,
        requestBuilder: implementFeatureRequest,
        workloadResolver: (job, item) async => _workload,
        clock: () => DateTime.utc(2026, 1, 1),
      );
      final boundedResult = await boundedScheduler.tick();
      final reason = boundedResult.completionInflow.single.reason;
      expect(reason, contains('re-work discriminator'));
      expect(
        reason,
        contains('operator retry'),
        reason:
            'the counter is shared with human-driven re-work, so the operator '
            'has to be told that — otherwise a high number reads as "the lane '
            'failed three times" for an item the lane never ran on',
      );
      expect(
        reason,
        isNot(contains('implementation lane 3 time')),
        reason: 'the false reading this message used to give',
      );
    });

    test('the inflow is declared on the implementation lane only', () {
      expect(implementFeatureDefinition.completionInflowFrom, {
        WorkItemState.agentCompleted,
      });
      for (final definition in const <JobDefinition>[
        triageDefectDefinition,
        engineeringReviewDefinition,
        designRevisionDefinition,
        designReviewDefinition,
      ]) {
        expect(
          definition.completionInflowFrom,
          isNull,
          reason:
              '${definition.jobType.wire} declares no inflow. A second '
              'definition routing the same items would be two lanes deciding '
              'who owns one work item in the same tick',
        );
      }
    });

    test('declaring the inflow did not widen entryStates', () {
      // Invariant D-10. `agentCompleted` is `engineeringReviewDefinition`'s
      // entry state; listing it here as well would put both definitions on one
      // item in the same tick and destroy the disjointness that makes the
      // collision structurally impossible.
      expect(implementFeatureDefinition.entryStates, {
        WorkItemState.implementationReady,
      });
    });

    test('the edge the route takes exists, with the honest actor guard', () {
      const engine = WorkflowEngine();
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.agentCompleted,
          WorkItemState.implementationReady,
        ),
        isTrue,
      );
      final ok = engine.evaluateWorkItemTransition(
        from: WorkItemState.agentCompleted,
        to: WorkItemState.implementationReady,
        trigger: TransitionTrigger.systemEvent,
        actor: schedulerOrchestratorActor,
        context: const {},
      );
      expect(ok.isValid, isTrue);

      final refused = engine.evaluateWorkItemTransition(
        from: WorkItemState.agentCompleted,
        to: WorkItemState.implementationReady,
        trigger: TransitionTrigger.systemEvent,
        actor: const WorkflowActor(
          actorId: 'someone',
          actorType: ActorType.engineeringReviewer,
        ),
        context: const {},
      );
      expect(
        refused.isValid,
        isFalse,
        reason:
            'the only guard is `actorAllowed([orchestrator])`, so the actor '
            'check is the whole of it and must actually reject a non-orchestrator',
      );
    });
  });

  group('the bound governs THIS lane, and only this lane', () {
    // THE DEFECT THIS GROUP EXISTS FOR.
    //
    // `maxImplementationInflows` bounds automatic entries into the IMPLEMENTATION
    // lane. The check used to run for BOTH answers `completionRouteFor` can give,
    // so it also refused a producer that left a commit — whose route is
    // `reviewInProgress`, the review lane's state and not an entry into this one
    // at all. A counter about this lane's entries has no standing to refuse a
    // route into another lane.
    //
    // The markers are the values measured on the live QA data by
    // `RESEARCH-AGENT-COMPLETED-INFLOW`: the one item that routed out of
    // `agentCompleted` read 2, and the four that stalled read 3, 4, 3 and 4. 9 is
    // past anything observed, so none of these can pass on a coincidence about
    // the size of the numbers.
    const aboveTheBound = <int>[3, 4, 9];

    test('a producer that DID commit is not refused by this lane\'s bound', () async {
      for (final marker in aboveTheBound) {
        final workflowStore = InMemoryWorkflowStore();
        await workflowStore.saveWorkItem(
          _completed(metadata: {'triageAttempt': marker}),
        );
        final lane = _implLane(
          workflowStore,
          await _storeWith([
            _execution(
              workerExecutionId: 'wx-impl',
              agentExecutionId: 'agx-exec-impl-1',
              endingRevision: _produced,
            ),
          ]),
        );

        final result = await lane.scheduler.tick();

        expect(
          result.completionInflow.single.reason,
          isNot(contains('re-work discriminator')),
          reason:
              'the discriminator reads $marker, but the route this item took is '
              '${WorkItemState.reviewInProgress.wire} — not an entry into this '
              'lane. The refusal it used to be given also told an operator the '
              'review lane would park the item for a human, and that is false '
              'here: the review workload resolver resolves an item holding a '
              'reviewable commit, so no blockedArtifactMissing job is ever '
              'created and the park handler never runs for it',
        );
      }
    });

    test(
      'a route that leaves this lane spends none of this lane\'s budget',
      () async {
        for (final marker in aboveTheBound) {
          final workflowStore = InMemoryWorkflowStore();
          await workflowStore.saveWorkItem(
            _completed(metadata: {'triageAttempt': marker}),
          );
          final lane = _implLane(
            workflowStore,
            await _storeWith([
              _execution(
                workerExecutionId: 'wx-impl',
                agentExecutionId: 'agx-exec-impl-1',
                endingRevision: _produced,
              ),
            ]),
          );

          await lane.scheduler.tick();

          // THE RUNAWAY THIS BOUND EXISTS TO STOP, at a counter far past anything
          // the platform should reach. The item stays where it is, no implementer
          // job is minted, and nothing is dispatched — so scoping the bound away
          // from the commit route cannot have handed a real commit to a second
          // implementer, which is the one outcome that is not recoverable.
          expect(
            (await workflowStore.readWorkItem('wi-1')).state,
            WorkItemState.agentCompleted,
          );
          expect(
            (await workflowStore.readWorkItem(
              'wi-1',
            )).metadata?['triageAttempt'],
            marker,
            reason:
                'a route into the review lane must not consume the shared '
                'implementation budget, or the two would starve each other',
          );
          expect(await lane.jobStore.listJobsForWorkItem('wi-1'), isEmpty);
          expect(lane.dispatch.requests, isEmpty);
        }
      },
    );

    test('the bound is AT OR ABOVE the limit, not exactly at it', () async {
      // `the bound is THREE` pins the literal and its immediate neighbours, and
      // the live data carries items at 4 — so a comparison that had become `==`
      // would let exactly those through.
      for (final marker in const [4, 9]) {
        final workflowStore = InMemoryWorkflowStore();
        await workflowStore.saveWorkItem(
          _completed(metadata: {'triageAttempt': marker}),
        );
        final lane = _implLane(
          workflowStore,
          await _storeWith([
            _execution(
              workerExecutionId: 'wx-triage',
              agentExecutionId: 'agx-exec-impl-1',
              endingRevision: null,
            ),
          ]),
        );

        final result = await lane.scheduler.tick();

        expect(
          (await workflowStore.readWorkItem('wi-1')).state,
          WorkItemState.agentCompleted,
        );
        expect(
          result.completionInflow.single.reason,
          contains('re-work discriminator'),
          reason:
              'marker $marker is past the bound, so this item is one the '
              'implementation lane has spent its budget on — the exact case '
              'that must reach a human rather than run for ever',
        );
        expect(lane.dispatch.requests, isEmpty);
      }
    });

    test('the cycle still terminates: the commit route spends nothing, and the '
        'bound closes the loop', () async {
      // THE REGRESSION THIS FIX IS NOT ALLOWED TO BUY.
      //
      // Scoping the bound away from the review route must not open the
      // runaway. It cannot, and this is the executable argument rather than
      // the prose one: the commit route spends no counter, so every pass of
      // the cycle that returns to `agentCompleted` spends the budget on the
      // IMPLEMENTATION route, where the bound still applies. The loop below
      // walks the real cycle — commit, reviewer completes, then implementers
      // that commit nothing — and asserts exactly three entries and then the
      // refusal, with the refusal terminal.
      final workflowStore = InMemoryWorkflowStore();
      await workflowStore.saveWorkItem(
        _completed(producerActorId: 'agx-impl-1'),
      );
      final workerStore = InMemoryWorkerStore();
      final lane = _implLane(workflowStore, workerStore);

      // PASS 1 — the implementer committed, so the route leaves this lane.
      await workerStore.saveWorkerExecution(
        _execution(
          workerExecutionId: 'wx-impl-1',
          agentExecutionId: 'agx-impl-1',
          endingRevision: _produced,
        ),
      );
      await lane.scheduler.tick();

      expect(
        (await workflowStore.readWorkItem('wi-1')).state,
        WorkItemState.agentCompleted,
        reason:
            'a commit belongs to the review lane and this one does not move '
            'it — which is the existing invariant, asserted here at the start '
            'of a loop rather than only in isolation',
      );
      expect(
        (await workflowStore.readWorkItem('wi-1')).metadata?['triageAttempt'],
        isNull,
        reason: 'the pass that leaves this lane must spend no budget',
      );

      // The reviewer runs to completion. Its execution carries
      // `engineeringReview`, which is exactly what `producedCommitFor`'s
      // candidate loop skips — so once the producer stamp names it, the
      // discriminator cannot attribute an artifact and the route comes back
      // INTO this lane. That hand-back is what makes the loop real: it is the
      // step where the budget starts being spent.
      await workerStore.saveWorkerExecution(
        _execution(
          workerExecutionId: 'wx-review-1',
          agentExecutionId: 'agx-review-1',
          endingRevision: 'c-review',
          capabilities: const {
            WorkerCapability.linux,
            WorkerCapability.git,
            WorkerCapability.engineeringReview,
          },
        ),
      );
      await _restampProducer(workflowStore, 'agx-review-1');

      // Passes 2..5. Pass 2 is that hand-back; each later pass is a fresh
      // implementer execution that committed nothing.
      final entered = <int>[];
      for (var pass = 2; pass <= 5; pass++) {
        if (pass > 2) {
          await _completeAnImplementationRun(workflowStore);
          await workerStore.saveWorkerExecution(
            _execution(
              workerExecutionId: 'wx-impl-$pass',
              agentExecutionId: 'agx-impl-$pass',
              endingRevision: null,
            ),
          );
          await _restampProducer(workflowStore, 'agx-impl-$pass');
        }

        final dispatchedBefore = lane.dispatch.requests.length;
        final result = await lane.scheduler.tick();
        final dispatchedThisPass =
            lane.dispatch.requests.length - dispatchedBefore;
        final item = await workflowStore.readWorkItem('wi-1');
        final move = result.completionInflow.singleWhere(
          (m) => m.workItemId == 'wi-1',
        );

        if (move.moved) {
          entered.add(pass);
          expect(
            item.metadata?['triageAttempt'],
            entered.length,
            reason:
                'every ACCEPTED entry into this lane spends the shared '
                'counter exactly once, which is what makes the bound a bound',
          );
          expect(item.state, WorkItemState.implementationReady);
          expect(
            dispatchedThisPass,
            greaterThan(0),
            reason:
                'each automatic entry spends a REAL implementer execution, '
                'and it is spent in the same tick as the route. That is what '
                'makes the bound worth having, so the runaway has to be '
                'counted in executions and not only in state changes',
          );
        } else {
          expect(
            move.reason,
            contains('re-work discriminator'),
            reason:
                'the first refused pass must be the bound. Anything else '
                'means the loop stopped for a reason that has nothing to do '
                'with the budget, and this test would be proving the wrong '
                'thing',
          );
          expect(item.state, WorkItemState.agentCompleted);
          expect(
            dispatchedThisPass,
            0,
            reason:
                'the refused pass is where the spend stops. One more '
                'dispatch here and the bound is not bounding anything',
          );
        }
      }

      expect(
        entered,
        [2, 3, 4],
        reason:
            'three automatic entries and no fourth: the review round-trip '
            'brought the item back into this lane, and from there the bound '
            '— not the route — is what stopped it. `maxImplementationInflows` '
            'is 3 and an item may enter at most that many times unattended',
      );
      // NOT a total over `lane.dispatch.requests`. Nothing here consumes a
      // dispatched job the way the coordinator consumes a real one, so the
      // jobs minted by earlier passes stay queued and are offered again on
      // every later pass — a total would measure that fixture artefact rather
      // than the spend. The per-pass delta above is the real quantity.

      // AND TERMINAL: one more tick on the refused item must not start a
      // fifth pass. The item is now at `agentCompleted` again with a producer
      // that committed nothing, so a bound that had been narrowed instead of
      // scoped would move it here.
      final finalTick = await lane.scheduler.tick();
      expect(
        finalTick.completionInflow
            .singleWhere((m) => m.workItemId == 'wi-1')
            .moved,
        isFalse,
      );
      expect(
        (await workflowStore.readWorkItem('wi-1')).state,
        WorkItemState.agentCompleted,
        reason:
            'the bound has nothing left to spend, so the item waits for the '
            'review lane\'s fail-closed handler to raise the blocking human '
            'decision that this is the human gate for',
      );
    });

    test('the route this lane cannot dispatch is the route it does not bound', () {
      // The predicate the bound is scoped by, stated as the property that makes
      // it correct: the no-artifact route is inside this lane and the commit
      // route is outside it. If a future change put `reviewInProgress` into
      // `entryStates`, this lane would genuinely dispatch it and the bound would
      // correctly start applying again — and this assertion is what would say
      // so before anyone relied on it.
      expect(implementFeatureDefinition.entryStates, {
        WorkItemState.implementationReady,
      });
      expect(
        implementFeatureDefinition.entryStates,
        isNot(contains(WorkItemState.reviewInProgress)),
        reason:
            'a bound on entries into this lane cannot reach a state this lane '
            'does not dispatch from. This is the whole scoping rule, and it is '
            'a declaration rather than a hardcoded list so the two cannot drift',
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

/// A worker store that faults on the one read the discriminator makes.
class _ThrowingWorkerStore extends InMemoryWorkerStore {
  @override
  Future<List<WorkerExecution>> listWorkerExecutions() async =>
      throw StateError('the worker store is down');
}

class _CountingWorkerStore extends InMemoryWorkerStore {
  _CountingWorkerStore(this.onRead);

  final void Function() onRead;

  @override
  Future<List<WorkerExecution>> listWorkerExecutions() async {
    onRead();
    return const [];
  }
}
