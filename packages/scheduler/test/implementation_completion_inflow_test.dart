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
  Object? producerActorId = 'agx-exec-impl-1',
  Map<String, dynamic>? metadata,
}) => WorkItem(
  workItemId: 'wi-1',
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
  workItemId: 'wi-1',
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
      await workflowStore.saveWorkItem(
        _completed(metadata: {'triageAttempt': maxImplementationInflows}),
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
            'an item that cannot be implemented after '
            '$maxImplementationInflows attempts belongs in front of a person. '
            'Leaving it at agent_completed is what lets the review lane\'s '
            'existing fail-closed handler raise a blocking decision for it',
      );
      expect(result.completionInflow.single.moved, isFalse);
      expect(result.completionInflow.single.reason, contains('already been'));
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
    test('review dispatches for an item the inflow would NOT route', () async {
      // The concurrency safety argument, as an executable statement of the two
      // components' shared input. Both read `producerActorId`, both read the
      // execution carrying it, both compare `endingRevision` with
      // `requestedStartingRevision`. If this assertion holds, then "the review
      // lane dispatched" implies "the inflow did not move the item", so a
      // reviewer can never be displaced by a route, and a review job never
      // lands on an item the implementation lane has already taken.
      const rows =
          <
            ({String? ending, String start, Set<WorkerCapability> capabilities})
          >[
            (
              ending: 'a-commit',
              start: 'a-commit',
              capabilities: {WorkerCapability.linux},
            ),
            (
              ending: null,
              start: 'a-commit',
              capabilities: {WorkerCapability.linux},
            ),
            (ending: 'b', start: 'a', capabilities: {WorkerCapability.linux}),
            (
              ending: 'b',
              start: 'a',
              capabilities: {WorkerCapability.engineeringReview},
            ),
          ];
      for (final row in rows) {
        final store = await _storeWith([
          _execution(
            workerExecutionId: 'wx-1',
            agentExecutionId: 'agx-exec-impl-1',
            endingRevision: row.ending,
            requestedStartingRevision: row.start,
            capabilities: row.capabilities,
          ),
        ]);
        final verdict = await producedCommitFor(store, _completed());

        // The review resolver's own rule, transcribed: it resolves a workload
        // on exactly the complement of this verdict.
        final reviewDispatches = verdict is CommitProduced;
        final inflowRoutes =
            completionRouteFor(verdict) == WorkItemState.implementationReady;

        expect(
          reviewDispatches && inflowRoutes,
          isFalse,
          reason:
              'a row where review dispatches AND the inflow routes would be '
              'the one input on which the two lanes contend for one item. '
              'Row: $row',
        );
      }
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
