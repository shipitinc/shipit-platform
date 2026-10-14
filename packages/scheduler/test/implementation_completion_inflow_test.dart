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
