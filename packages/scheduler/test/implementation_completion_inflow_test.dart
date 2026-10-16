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
      // real implementer run that produced nothing — and it is what proved the
      // removed bound was reachable through the actual cycle rather than a
      // hand-written state.
      //
      // It also still has a job after the bound is gone: the route is
      // UNBOUNDED now, so "the inflow cannot run twice for the same producer"
      // is the only thing standing between one producer and two automatic
      // entries into the lane. Idempotency, not a counter.
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
            'counter again. With the automatic route unbounded, idempotency per '
            'producer is the ONLY thing preventing one producer from buying two '
            'automatic entries into this lane',
      );
    });

    test('the automatic route is UNBOUNDED — a marker far above the removed '
        'bound still routes', () async {
      // THE INVERSE OF THE TEST THAT WAS HERE, and the only assertion in this
      // file that would have failed before this change.
      //
      // It used to read `the automatic route is BOUNDED, and the bound hands the
      // item to a human rather than dropping it`, seeded `triageAttempt: 3` and
      // asserted the item stayed at `agentCompleted`, `moved` was false and the
      // reason named the bound. Human decision
      // `92d567e3-da03-4c43-99f4-e3726472f0ab` (option `RETRY_LIMIT` =
      // `REMOVE`) reverses exactly that, so the old assertions are the bug and
      // the ones below are the contract.
      //
      // The markers are the values MEASURED on live QA by
      // `RESEARCH-AGENT-COMPLETED-INFLOW`: the four defects this unblocks read 3,
      // 4, 3 and 4. 9 and 12 are past anything observed, so none of these can
      // pass on a coincidence about the size of the numbers. They are LITERALS,
      // not the removed constant — a test that seeded the constant would have
      // validated the mechanism against itself and said nothing about the value,
      // which is why the bound's value was pinned with a separate literal until
      // there was no value left to pin.
      //
      // WHY THE ROUTE IS SAFE WITHOUT THE BRAKE, in one line: the cycle this
      // used to bound has an implementer step in it only while an implementer
      // that produced nothing can reach `agentCompleted`, and
      // `packages/execution_coordinator` now makes that run a PERMANENT
      // failure. This lane is deliberately merged AFTER that one.
      const markers = <int>[3, 4, 9, 12];
      for (final marker in markers) {
        final workflowStore = InMemoryWorkflowStore();
        await workflowStore.saveWorkItem(
          _completed(metadata: {'triageAttempt': marker}),
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
          WorkItemState.implementationReady,
          reason:
              'the re-work discriminator reads $marker and nothing reads it '
              'any more. The operator retry and resolved rework/reject '
              'decisions advance that same marker, so an item can reach a high '
              'value having entered this lane ZERO times — and the operator '
              'asking for work is the one case that must never be refused',
        );
        expect(result.completionInflow.single.moved, isTrue);
        expect(
          result.completionInflow.single.to,
          WorkItemState.implementationReady,
        );
        // Dispatched, not merely moved. A route that parks the item in a
        // dispatchable state that this lane will not pick up would look identical
        // to progress on a state read alone, and it is the shape the 870-job
        // churn class had.
        expect(result.enqueued, hasLength(1));
        expect(dispatch.requests, hasLength(1));
        // The marker still advances by exactly one, through the engine's own
        // rule. The bound is gone; the discriminator that builds
        // `implementFeatureDedupeKey` is not, and an unfrozen marker that no
        // longer moved would hand every later pass the same consumed key.
        expect(
          (await workflowStore.readWorkItem('wi-1')).metadata?['triageAttempt'],
          marker + 1,
          reason:
              'the inflow writes through `DurableWorkflowEngine'
              '.nextTriageAttempt`, not an inline `attempt + 1`, so the number '
              'the dedupe key builder reads back cannot be derived by a second '
              'rule',
        );
      }
    });

    test('the operator\'s chosen path — re-triage, then implement — repeats for '
        'as many passes as asked, and each pass is dispatched under a FRESH '
        'dedupe key', () async {
      // THE PROPERTY THAT MAKES "UNBOUNDED" TRUE RATHER THAN NOMINAL, and the
      // one the deleted cycle test used to stand in for.
      //
      // The operator chose "re-triage first, then implementation" over "straight
      // back to implementation", so the path that has to work for ever is
      // `designNotRequired -> [triage] -> agentCompleted -> implementationReady`.
      // This lane's half of it is the second arrow.
      //
      // An unbounded route that stopped minting jobs would be worse than the
      // bound it replaced. `JobQueue.enqueueIfAbsent` refuses a dedupe key ANY
      // job already holds, and the implementation key is
      // `'<id>:implement_feature:a<marker>'` — so if the marker froze, pass two
      // would ask for a key pass one already burned, the enqueue would return
      // `created: false`, and the item would sit in a dispatchable state with
      // nothing running. That is the inert item, and it is exactly what the
      // marker exists to prevent. This walks the real cycle four times and
      // asserts a DISTINCT key each pass.
      final workflowStore = InMemoryWorkflowStore();
      await workflowStore.saveWorkItem(
        _completed(producerActorId: 'agx-triage-0'),
      );
      final workerStore = InMemoryWorkerStore();
      // The triage shape each pass ends in: a run that completed, wrote a
      // classification, and committed nothing because no file was touched.
      await workerStore.saveWorkerExecution(
        _execution(
          workerExecutionId: 'wx-triage-0',
          agentExecutionId: 'agx-triage-0',
          endingRevision: null,
        ),
      );
      final lane = _implLane(workflowStore, workerStore);

      final keys = <String>{};
      for (var pass = 1; pass <= 4; pass++) {
        if (pass > 1) {
          // The implementer for the previous pass ran and produced nothing, so
          // the coordinator would have failed it permanently and this item would
          // never have come back. Walking the cycle by hand is the only way to
          // reach a second pass here, and it is exactly the state that rule
          // exists to make unreachable in production.
          await _completeAnImplementationRun(workflowStore);
          await workerStore.saveWorkerExecution(
            _execution(
              workerExecutionId: 'wx-triage-$pass',
              agentExecutionId: 'agx-triage-$pass',
              endingRevision: null,
            ),
          );
          await _restampProducer(workflowStore, 'agx-triage-$pass');
        }

        final dispatchedBefore = lane.dispatch.requests.length;
        final result = await lane.scheduler.tick();
        final dispatchedThisPass =
            lane.dispatch.requests.length - dispatchedBefore;
        final item = await workflowStore.readWorkItem('wi-1');

        expect(
          result.completionInflow
              .singleWhere((m) => m.workItemId == 'wi-1')
              .moved,
          isTrue,
          reason:
              'pass $pass of the re-triage path must be routed, not refused',
        );
        expect(
          item.state,
          WorkItemState.implementationReady,
          reason:
              'the operator chose re-triage-then-implement, so pass $pass has to '
              'reach the lane that does the work rather than terminate',
        );
        expect(
          item.metadata?['triageAttempt'],
          pass,
          reason:
              'every accepted route spends the shared discriminator exactly '
              'once, so the next pass builds a new key',
        );
        // A PER-PASS DELTA, never a total over `lane.dispatch.requests`. Nothing
        // in this file consumes a dispatched job the way the coordinator consumes
        // a real one, so the jobs minted by earlier passes stay queued and are
        // offered again on every later pass; a total would measure that fixture
        // artefact rather than the spend. What has to be true is that THIS pass
        // reached a worker at all.
        expect(
          dispatchedThisPass,
          greaterThan(0),
          reason:
              'and it must actually reach a worker request, not merely move a '
              'state — a route that looks like progress while nothing is '
              'dispatched is the shape this has to rule out',
        );
        keys.addAll(
          (await lane.jobStore.listJobsForWorkItem(
            'wi-1',
          )).map((j) => j.dedupeKey),
        );
        expect(
          keys,
          hasLength(pass),
          reason:
              'a fresh dedupe key per pass. A frozen marker would re-ask for a '
              'consumed key, the enqueue would refuse it, and "unbounded" would '
              'mean an item that loops on nothing',
        );
      }

      expect(
        keys,
        equals({
          'wi-1:implement_feature:a1',
          'wi-1:implement_feature:a2',
          'wi-1:implement_feature:a3',
          'wi-1:implement_feature:a4',
        }),
        reason:
            'spelled out rather than computed, so a change to the key builder or '
            'to which marker it reads fails here instead of passing by '
            'coincidence. Note the FIRST pass is already suffixed `a1`, not the '
            'historical unsuffixed key: the route and the enqueue happen in one '
            'tick and the enqueue reads the marker the route just wrote, so the '
            'key is fresh from the very first dispatch. That is why this is the '
            'property that makes an unbounded route actually run',
      );
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

    test('the discriminator is advanced by the ENGINE\'s rule, not an inline '
        'attempt + 1', () async {
      // THE HALF OF THIS TEST THAT SURVIVED THE BOUND'S REMOVAL, kept for its
      // own subject.
      //
      // The test used to be called `the bound message names the counter it
      // actually read` and had two halves. The second half asserted the wording
      // of the REFUSAL — that it names the shared re-work discriminator rather
      // than "already put into the implementation lane 2 time(s)". There is no
      // refusal any more, so that half is deleted rather than re-pointed: an
      // assertion about a message no code emits can only be trivially true.
      //
      // The first half is untouched by the decision and is the reason this test
      // still exists: the marker this write stamps is what
      // `implementFeatureDedupeKey` reads back to build the key the job will be
      // dispatched under, so the number the inflow writes and the number the
      // builder asks for must come from ONE function. `nextTriageAttempt` is
      // that function; an inline `attempt + 1` is the "two writers, two rules,
      // one counter" hazard the marker documents, and it was in this file once.
      //
      // The marker still moves at marker 2, which is not remarkable. What is
      // load-bearing after the bound is gone is that it moves AT ALL: nothing
      // reads it as a ceiling any more, so an inflow that stopped advancing it
      // would build the same key on every later pass and be refused by
      // `enqueueIfAbsent` for ever.
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

      // Two prior operator retries and no lane entry: the route is taken, and
      // the item's marker is advanced by the ENGINE's own rule.
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

  group('the commit route is not this lane\'s to take', () {
    // THE DEFECT THIS GROUP EXISTED FOR, and what survives it.
    //
    // It used to be called `the bound governs THIS lane, and only this lane`, and
    // every test in it was about SCOPING `maxImplementationInflows`: the check
    // used to run for BOTH answers `completionRouteFor` can give, so it also
    // refused a producer that left a commit — whose route is `reviewInProgress`,
    // the review lane's state and not an entry into this one at all. A counter
    // about this lane\'s entries had no standing to refuse a route into another
    // lane. Human decision `92d567e3-da03-4c43-99f4-e3726472f0ab` removed the
    // bound outright, which deletes the scoping question and leaves the property
    // the scoping was defending.
    //
    // What remains is stronger and does not mention a bound: a producer that
    // committed is never moved by this lane, never consumes the shared
    // discriminator, and never mints an implementer job. A real artifact sent to
    // the build queue is a duplicate commit of work that already exists, and that
    // is the one outcome in this file that is not recoverable.
    //
    // THREE tests were removed from this group. Two asserted the bound itself,
    // which the decision reverses — `a producer that DID commit is not refused by
    // this lane\'s bound` (its assertion became unfalsifiable: nothing emits that
    // string any more) and `the bound is AT OR ABOVE the limit, not exactly at
    // it`. The third, `the cycle still terminates … and the bound closes the
    // loop`, was the only executable statement that this lane\'s cycle
    // terminates; its inverted form would assert an unattended runaway as correct
    // behaviour, which is only true once the rule that prevents it exists, and
    // that rule is in `packages/execution_coordinator`. The gap is deliberate
    // and it is the reason for the merge order.
    //
    // The markers are the values measured on the live QA data by
    // `RESEARCH-AGENT-COMPLETED-INFLOW`: the one item that routed out of
    // `agentCompleted` read 2, and the four that stalled read 3, 4, 3 and 4. 9 is
    // past anything observed, so none of these can pass on a coincidence about
    // the size of the numbers.
    const aboveTheRemovedBound = <int>[3, 4, 9];

    test('a producer that DID commit is left in place and spends nothing, at '
        'any marker', () async {
      for (final marker in aboveTheRemovedBound) {
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

        // The commit route is `reviewInProgress`, a state this lane does not
        // declare, so the write it attempts is refused by the TRANSITIONS TABLE:
        // the edge carries `GuardConditions.agentResultValid()` and the
        // scheduler has no execution of its own to supply the producer's
        // `AgentResult` under `context['agentResult']`. That guard belongs to the
        // review route, not to this lane, and nothing here weakens it — the same
        // unsatisfiable probe `engineeringReviewDefinition
        // .skipWorkflowPolicyCheck` exists to skip, recorded as design decision
        // F-04 and owned by the coordinator.
        expect(
          (await workflowStore.readWorkItem('wi-1')).state,
          WorkItemState.agentCompleted,
          reason:
              'the item holds a reviewable commit, so engineering review owns '
              'it. This lane must not move it, and with the bound gone there is '
              'no longer any counter here that could refuse it either — the '
              'refusal has to come from the transition policy, and it does',
        );
        expect(
          (await workflowStore.readWorkItem('wi-1')).metadata?['triageAttempt'],
          marker,
          reason:
              'a refused write must consume nothing. A route this lane cannot '
              'take may not advance the shared discriminator, or the next pass '
              'would be dispatched under a key this one already burned',
        );
        expect(
          await lane.jobStore.listJobsForWorkItem('wi-1'),
          isEmpty,
          reason: 'no implementer job for an item that already has a commit',
        );
        expect(lane.dispatch.requests, isEmpty);
      }
    });

    test('the route this lane cannot dispatch is a state it never declares', () {
      // Assertions KEPT, subject retargeted.
      //
      // It used to be `the route this lane cannot dispatch is the route it does
      // not bound`, and existed to state the predicate the bound was scoped by.
      // The bound is gone (`92d567e3-da03-4c43-99f4-e3726472f0ab`), but the
      // declaration it was reading is load-bearing on its own and for a reason
      // that did not change with it:
      //
      // Invariant D-10. `agentCompleted` is `engineeringReviewDefinition`'s
      // ENTRY state. Listing it here as well would put both definitions on one
      // item in the same tick and destroy the disjointness that makes the
      // collision structurally impossible. `implementFeatureDefinition.entryStates`
      // is one element wide, `reviewInProgress` is not in it, and the commit route
      // is therefore not dispatchable here — which is also why no state read
      // here can be `reviewInProgress` after a tick.
      expect(implementFeatureDefinition.entryStates, {
        WorkItemState.implementationReady,
      });
      expect(
        implementFeatureDefinition.entryStates,
        isNot(contains(WorkItemState.reviewInProgress)),
        reason:
            'this lane must not be able to dispatch the review lane\'s state. '
            'A declaration rather than a hardcoded list, so the two lanes cannot '
            'drift into contending for one item in one tick',
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
