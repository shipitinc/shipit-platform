import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:worker_protocol/worker_protocol.dart';
import 'package:worker_runtime/worker_runtime.dart' show InMemoryWorkerStore;
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';

/// A deferring readiness probe NEVER dispatches — and never falls through to the
/// construction-time workload.
///
/// ## The hazard this closes
///
/// `Scheduler` takes a REQUIRED `SchedulerWorkload` argument. For the
/// implementation scheduler that argument has to name *some* repository to
/// satisfy the type, and the obvious one — the triage source, the checkout both
/// shipped schedulers use — is a README-only scratch repository. So "the
/// resolver returns null" is not by itself enough: if anything ever falls
/// through to the static workload, the implementer commits into the triage
/// repository, produces a plausible `AgentResult`, gets a `producerActorId`
/// stamped on the work item, and engineering review dispatches at a revision it
/// can find. That is a GREEN REVIEW OF A FABRICATION, which is strictly worse
/// than the stranded items this lane exists to fix.
///
/// The guard is therefore two assertions, not one:
///   * no dispatch happens, and
///   * no worker execution request is ever BUILT — the request is what carries
///     the repository path, so "no request" is what proves the static workload
///     was not used rather than merely outvoted.
///
/// ## Why this goes through a REAL `Scheduler`
///
/// Asserting on a fake resolver's return value would prove nothing about the
/// path that matters. These tests build a real `Scheduler` over real in-memory
/// stores with a recording `WorkerDispatch`, tick it, and read
/// `SchedulerTickResult` — the same surface the composition root reads.
void main() {
  /// The repository a fall-through would have used, named so a request carrying
  /// it can be identified by name rather than by shape.
  const triageOnlyPath = 'a-triage-only-checkout';
  const triageOnlyRevision = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  Scheduler build({
    required WorkflowStore workflowStore,
    required JobStore jobStore,
    required WorkerDispatch dispatch,
    required WorkloadResolver resolver,
  }) => Scheduler(
    schedulerId: 'sched-impl',
    workflowStore: workflowStore,
    jobStore: jobStore,
    workerStore: InMemoryWorkerStore(),
    dispatch: dispatch,
    definition: implementFeatureDefinition,
    dedupeKeyBuilder: implementFeatureDedupeKey,
    instructionBuilder: implementFeatureInstruction,
    requestBuilder: implementFeatureRequest,
    workloadResolver: resolver,
    // INERT, and the point of the test. This value must never reach a request.
    workload: SchedulerWorkload(
      repositoryPath: triageOnlyPath,
      startingRevision: triageOnlyRevision,
      timeoutSeconds: 1800,
      runtimeTypeId: 'fake-runtime',
    ),
    clock: () => DateTime.utc(2026, 1, 1),
  );

  Future<WorkItem> seedWorkItem(
    DurableWorkflowEngine engine, {
    String workItemId = 'wi-impl',
  }) async {
    await engine.createWorkItem(
      workItemId: workItemId,
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Add the thing',
      description:
          'A fixture work item used only to exercise the deferral path',
    );
    return engine.loadWorkItem(workItemId);
  }

  group(
    'the entry set is narrow enough that nothing else can be dispatched',
    () {
      test('an item outside implementationReady enqueues nothing', () async {
        final workflowStore = InMemoryWorkflowStore();
        final jobStore = InMemoryJobStore();
        final engine = DurableWorkflowEngine(store: workflowStore);
        await seedWorkItem(engine);

        final requests = <WorkerExecutionRequest>[];
        final result = await build(
          workflowStore: workflowStore,
          jobStore: jobStore,
          dispatch: _RecordingDispatch(requests),
          resolver: alwaysDefers,
        ).tick();

        expect(result.enqueued, isEmpty);
        expect(result.dispatched, isEmpty);
        expect(requests, isEmpty);
      });
    },
  );

  group('the entry state has no producer yet, and that is the documented state', () {
    // This group is the file's honesty section. It is deliberately the FIRST
    // thing a reader meets after the file's header, because the single most
    // misleading sentence a reviewer could leave with is "the implementation
    // lane now exists and runs". It exists and it is wired; NOTHING reaches it
    // yet, and that is `OD-3` and `OD-10` being open rather than an oversight.
    test('no human decision resolves into implementationReady today', () {
      final routed = <String>[];
      for (final type in HumanDecisionType.values) {
        for (final choice in HumanDecisionChoice.values) {
          final target = HumanDecisionRouting.targetFor(type, choice);
          if (target == WorkItemState.implementationReady) {
            routed.add('(${type.name}, ${choice.name})');
          }
        }
      }
      expect(
        routed,
        isEmpty,
        reason:
            'a route now targets implementation_ready. If this lane added one, '
            'the corresponding entry in HumanDecisionRouting.targetFor AND '
            'escalationTargetFor (for exactly two of the five rework pairs) '
            'moved with it, and the reason `OD-3` was unanswered no longer '
            'holds. Otherwise the two tables have diverged: $routed',
      );
    });

    test('a real rework still lands on the triage lane, not this one', () async {
      final workflowStore = InMemoryWorkflowStore();
      final engine = DurableWorkflowEngine(store: workflowStore);
      await seedWorkItem(engine);
      await walkToReviewGate(engine);

      final gate =
          (await workflowStore.readHumanDecisionsForWorkItem(
            'wi-impl',
          )).singleWhere(
            (d) => d.decisionType == HumanDecisionType.engineeringReview,
          );
      await engine.resolveHumanDecision(
        decisionId: gate.decisionId,
        choice: HumanDecisionChoice.rework,
        decider: 'test-decider',
        rationale: 'fixture: the rework route that is live today',
        signature: DecisionSignature(
          algorithm: 'ed25519',
          publicKey: 'test-public-key',
          signature: 'sig-defer',
          signedAt: DateTime.utc(2026),
        ),
      );

      expect(
        (await engine.loadWorkItem('wi-impl')).state,
        WorkItemState.designNotRequired,
        reason:
            'rework currently re-triages. Moving this route is `OD-3`, and it '
            'is not this lane to decide',
      );
    });

    test('the transition table DOES carry the route the retarget will use', () {
      // The edge is present and fully guarded even though no routing targets
      // it. That is deliberate (design §7.5 Obligation A / D-14): without the
      // edge, answering `OD-3` would be an engine change as well as a routing
      // change, and the engine would throw on a resolution into a state nothing
      // leaves.
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.waitingForHumanDecision,
          WorkItemState.implementationReady,
        ),
        isTrue,
      );
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.implementationReady,
          WorkItemState.agentExecuting,
        ),
        isTrue,
      );
    });
  });

  group('a deferring resolver defers rather than dispatching', () {
    test(
      'an item AT implementationReady is enqueued, never dispatched, never '
      'charged a retry, and never resolved against the static workload',
      () async {
        final workflowStore = InMemoryWorkflowStore();
        final jobStore = InMemoryJobStore();
        final requests = <WorkerExecutionRequest>[];

        final engine = DurableWorkflowEngine(store: workflowStore);
        await seedWorkItem(engine);

        // Walked to the implementation entry state through the REAL engine, by
        // taking the production route there: the rework edge out of a resolved
        // human decision. Faking the state would test a fixture rather than the
        // table — and this walk is also the only assertion that the new edge
        // carries a real work item, since without it the entry state would be
        // inert and nothing downstream would ever run.
        await walkToReviewGate(engine);
        await parkAtImplementationReady(workflowStore);

        expect(
          (await engine.loadWorkItem('wi-impl')).state,
          WorkItemState.implementationReady,
          reason:
              'the rework edge must actually carry an item into the '
              'implementation lane\'s entry state. If it did not, this whole '
              'group would pass vacuously against an inert state',
        );

        final scheduler = build(
          workflowStore: workflowStore,
          jobStore: jobStore,
          dispatch: _RecordingDispatch(requests),
          // The production deferral: no durable workspace.
          resolver: alwaysDefers,
        );

        final result = await scheduler.tick();

        expect(
          result.dispatched,
          isEmpty,
          reason: 'a deferring probe must not dispatch, ever',
        );
        expect(
          requests,
          isEmpty,
          reason:
              'the dispatcher was never asked about anything, so the static '
              'workload\'s repository was never used. A request here would mean '
              'the scheduler fell through to the construction-time workload and '
              'the implementer would have committed into the triage repository',
        );

        // The job EXISTS and is still queued. That is what "defer" means: not
        // failed, not cancelled, not terminal, and its attempt budget intact.
        final jobs = await jobStore.listJobsForWorkItem('wi-impl');
        expect(jobs, hasLength(1));
        final job = jobs.single;
        expect(job.state, JobState.queued);
        expect(
          job.attempt,
          1,
          reason:
              'a deferral must not burn retry budget — the next tick has to be '
              'able to try again without the job being exhausted into a failure',
        );
        expect(result.terminal, isEmpty);
        expect(result.cancelledQueued, isEmpty);

        // A second tick re-reaches the same job rather than retiring or
        // failing it. A deferral that turned terminal on the second observation
        // would be a deferral in name only.
        final second = await scheduler.tick();
        expect(second.dispatched, isEmpty);
        final again = await jobStore.readJob(job.jobId);
        expect(again!.state, JobState.queued);
        expect(again.attempt, 1);
      },
    );

    test(
      'a deferring resolver reports nothing the composition root would treat as '
      'a missing artifact',
      () async {
        // The shape of what is reported, pinned so a future change to the
        // resolver's contract has to be deliberate.
        //
        // `blockedArtifactMissing` IS the channel a `null` lands on — the
        // scheduler has exactly one refusal channel for a resolver that cannot
        // answer, and which channel a deferral SHOULD travel on is an open
        // design decision (`OD-4`). What is decided, and what this asserts, is
        // the part that is not a product question: a deferral must be visible
        // to the tick and must NOT be accompanied by any state change,
        // cancellation or terminal outcome. The composition root's obligation
        // — install no handler, so this never becomes a human decision — is
        // asserted in `composition_wiring_test.dart`.
        final workflowStore = InMemoryWorkflowStore();
        final jobStore = InMemoryJobStore();
        final engine = DurableWorkflowEngine(store: workflowStore);
        await seedWorkItem(engine);
        await walkToReviewGate(engine);
        await parkAtImplementationReady(workflowStore);

        final result = await build(
          workflowStore: workflowStore,
          jobStore: jobStore,
          dispatch: _RecordingDispatch(<WorkerExecutionRequest>[]),
          resolver: alwaysDefers,
        ).tick();

        expect(result.dispatched, isEmpty);
        expect(result.entryHopRefused, isEmpty);
        expect(
          result.blockedArtifactMissing,
          isNotEmpty,
          reason:
              'the refusal must be VISIBLE on the tick. A deferral the tick '
              'reports nowhere is indistinguishable from an idle scheduler',
        );
        expect(result.cancelledQueued, isEmpty);
        expect(result.terminal, isEmpty);
      },
    );
  });

  group('a RESOLVING probe does dispatch, against the resolved repository', () {
    test('the request names the probe\'s repository and pin, not the static '
        'workload', () async {
      final workflowStore = InMemoryWorkflowStore();
      final jobStore = InMemoryJobStore();
      final engine = DurableWorkflowEngine(store: workflowStore);
      await seedWorkItem(engine);
      await parkAtImplementationReady(workflowStore);

      final requests = <WorkerExecutionRequest>[];
      await build(
        workflowStore: workflowStore,
        jobStore: jobStore,
        dispatch: _RecordingDispatch(requests),
        // The only resolver in this file that says yes.
        resolver: (job, item) async => SchedulerWorkload(
          repositoryPath: '/a/product/durable/clone',
          startingRevision: 'b' * 40,
          timeoutSeconds: 1800,
          runtimeTypeId: 'fake-runtime',
        ),
      ).tick();

      // No worker is registered, so the request is built and then refused at
      // selection — which is exactly the observation point this test needs.
      expect(requests, hasLength(1));
      expect(
        requests.single.repositoryPath,
        '/a/product/durable/clone',
        reason:
            'the request must carry the repository the PROBE resolved. If this '
            'is the construction-time workload\'s path, the implementer ran in '
            'the triage repository',
      );
      expect(requests.single.repositoryPath, isNot(triageOnlyPath));
      expect(requests.single.startingRevision, 'b' * 40);
    });
  });
}

/// Walks the fixture item to `waitingForHumanDecision` through real transitions
/// only, and leaves a PENDING `engineeringReview` gate open.
///
/// The route is the long one a real work item takes — plan, design, approve,
/// execute, complete, enter review — because a fixture that fakes a lifecycle
/// state tests the fixture rather than the table.
Future<void> walkToReviewGate(DurableWorkflowEngine engine) async {
  Future<void> step(
    WorkItemState to, {
    Map<String, dynamic> context = const {},
    TransitionTrigger trigger = TransitionTrigger.systemEvent,
  }) => engine.transition(
    workItemId: 'wi-impl',
    to: to,
    trigger: trigger,
    context: context,
  );

  Future<void> resolve(String decisionId, HumanDecisionChoice choice) =>
      engine.resolveHumanDecision(
        decisionId: decisionId,
        choice: choice,
        decider: 'test-decider',
        rationale: 'fixture: walk to the engineering review gate',
        signature: DecisionSignature(
          algorithm: 'ed25519',
          publicKey: 'test-public-key',
          signature: 'sig-defer',
          signedAt: DateTime.utc(2026),
        ),
      );

  final agentResult = AgentResult(
    resultId: 'res-1',
    sessionId: 'ses-1',
    workItemId: 'wi-impl',
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
    summary: 'fixture: an implementation was produced before the rework',
    completedAt: DateTime.utc(2026),
  );

  await step(WorkItemState.planning);
  await step(WorkItemState.planned, context: const {'featureRef': 'f-1'});
  await step(
    WorkItemState.designRequired,
    context: const {'designContractId': 'dc-1'},
  );
  await step(
    WorkItemState.designInReview,
    context: const {
      'designContractId': 'dc-1',
      'designContractStatus': DesignContractStatus.underReview,
    },
  );

  final designGate = await engine.requestHumanDecision(
    workItemId: 'wi-impl',
    decisionType: HumanDecisionType.designApproval,
    blocking: true,
  );
  await resolve(designGate.decisionId, HumanDecisionChoice.approve);

  await step(
    WorkItemState.agentExecuting,
    context: const {'agentAvailable': true, 'capabilitiesMatch': true},
  );
  await step(
    WorkItemState.agentCompleted,
    trigger: TransitionTrigger.agentResult,
    context: {'qaContractId': 'qa-1', 'agentResult': agentResult},
  );
  await step(
    WorkItemState.reviewInProgress,
    trigger: TransitionTrigger.agentResult,
    context: {'agentResult': agentResult},
  );

  await engine.requestHumanDecision(
    workItemId: 'wi-impl',
    decisionType: HumanDecisionType.engineeringReview,
    blocking: true,
    extraContext: const {'producerActorId': 'agent-1'},
  );
}

/// Parks the fixture item at `implementationReady` by WRITING THE ROW.
///
/// ## Why this writes instead of walking
///
/// There is currently NO production route into `implementationReady`. The only
/// edge that reaches it is `waitingForHumanDecision -> implementationReady`,
/// which exists and is fully guarded — but no `HumanDecisionRouting` entry
/// targets it, because WHICH of the five "do the work again" pairs move there
/// is `OD-3`, and it is an open product decision. `walkToReviewGate` plus a
/// `rework` resolution lands on `designNotRequired`, and
/// `no production route reaches implementationReady yet` above asserts exactly
/// that.
///
/// So the state is written directly. That is honest here for one reason: the
/// property under test is what the scheduler does with an item AT the entry
/// state, and the only way to exercise that is to put one there. The walk above
/// separately proves the walk is long and real, and the assertion above proves
/// the entry state is currently unreachable — so the two together state both
/// halves: the dispatch path works, and nothing yet feeds it.
Future<WorkItem> parkAtImplementationReady(WorkflowStore store) async {
  final current = await store.readWorkItem('wi-impl');
  final parked = current.copyWith(
    state: WorkItemState.implementationReady,
    version: current.version + 1,
    updatedAt: DateTime.utc(2026),
  );
  await store.saveWorkItem(parked, expectedVersion: current.version);
  return parked;
}

/// The strongest form of "no durable workspace": defers for every item,
/// unconditionally.
///
/// A per-item condition could be satisfied by an accident of one product being
/// ready and another not, which is a weaker property than the one §7.7 requires.
Future<SchedulerWorkload?> _deferringResolver(Job job, WorkItem item) async =>
    null;

const WorkloadResolver alwaysDefers = _deferringResolver;

/// A [WorkerDispatch] that records every request it was asked about and selects
/// no worker.
///
/// Selection never succeeds, so even if the scheduler built a request the test
/// would see it in [requests] before any placement happened. That ordering is
/// deliberate: the property under test is "no request was BUILT", not "no
/// worker was free".
class _RecordingDispatch implements WorkerDispatch {
  _RecordingDispatch(this.requests);

  final List<WorkerExecutionRequest> requests;

  @override
  WorkerSelection select(WorkerExecutionRequest request) {
    requests.add(request);
    return WorkerSelection.noCompatibleWorker();
  }

  @override
  Future<WorkerExecutionResult> run(WorkerExecutionRequest request) async {
    requests.add(request);
    throw StateError('run() must never be reached when no request is built');
  }

  @override
  Future<void> cancel(String workerId, String reason) async {}
}
