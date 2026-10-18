import 'dart:io';

import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';

import 'support/controlled_dispatcher.dart';
import 'support/file_host.dart';

/// THE `planned` ENTRY-HOP PROOF — the dead end, the fix, the bound, and the
/// residual, all executable.
///
/// ## THE DEFECT
///
/// `planned` had two legal edges out of it (`planned -> designRequired`, guarded
/// by `designContractExists()`, and `planned -> designNotRequired`, unguarded)
/// and was in the `entryStates` of NO wired `JobDefinition`. `RunnableWorkEvaluator`
/// rejects a state outside `entryStates` BEFORE it consults the policy, so
/// `Scheduler.tick` never selected a `planned` item; `EntryHopper.prepare` is
/// only ever called on an item the scheduler already selected, so it never ran
/// on one either; and BOTH edges stayed permanently unreachable. `planned` was a
/// state the platform could enter and never leave.
///
/// Measured on the QA stack on 2026-10-16: `planning -> planned` had been taken
/// 13 times, the last route out fired on 2026-10-11, and three items were
/// parked at `planned` (the oldest, `WI-feature-1791823723502264`, since
/// 2026-10-12) while every tick reported `ran: true, failedSections: []` and
/// `dispatched: 0`.
///
/// ## WHY THE FAILURE WAS SILENT
///
/// The first group below asserts this rather than describing it: with `planned`
/// absent from the entry set, a tick enqueues nothing, dispatches nothing, and
/// — the part that let this survive days — populates `entryHopRefused` with
/// NOTHING either. The item is never considered, so it is never refused. A lane
/// that reports no failure is indistinguishable from a lane with no work.
///
/// ## WHAT IS FIXED HERE, AND WHAT IS NOT
///
/// `planned` is added to `triageDefectDefinition.entryStates` and names its own
/// hop in `entryProbeTargets` — `planned -> designNotRequired`, the same shape
/// `reviewRejected` already uses. The transition table is NOT touched: the edge
/// already existed and this lane makes it reachable. The last group pins that
/// as an executable property rather than a promise.
///
/// THE RESIDUAL IS NAMED, NOT HIDDEN: `planned -> designNotRequired` carries no
/// guard, so a `planned` item that DOES have a design contract is routed to
/// `designNotRequired` rather than `designRequired`, and is triaged instead of
/// designed. That is a real edge case with a real consequence and it is
/// asserted as its own test, so nobody reads this suite as claiming the problem
/// is fully solved. Conditional routing cannot express it (the probe target is a
/// `Map<WorkItemState, WorkItemState>`, static by construction, read without the
/// work item), which is why it is reported rather than built.
void main() {
  final t0 = DateTime.utc(2026, 10, 16, 9);

  /// The three work items observed parked at `planned`, by the shape that was
  /// measured: `feature` category, ids of the `WI-feature-*` form the
  /// orchestrator mints, and — the decisive detail — NO design contract. Their
  /// `designContractId` was null and their artifact map empty, so
  /// `planned -> designRequired` was never available to them and
  /// `planned -> designNotRequired` was the only edge they could ever take.
  const strandedIds = <String>[
    'WI-feature-1791823723502264',
    'WI-feature-1791823723502265',
    'WI-feature-1791823723502266',
  ];

  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('planned_hop_test'));
  tearDown(() => temp.deleteSync(recursive: true));

  /// The live triage definition with `planned` REMOVED — the pre-fix shape,
  /// reconstructed rather than described, so every claim below has a
  /// counterfactual to be measured against. If this ever stopped describing the
  /// pre-fix definition the tests would prove nothing, so it is checked against
  /// the live one in the non-vacuity group: the two differ by exactly `planned`.
  const baseDefinition = JobDefinition(
    jobType: JobType.triageDefect,
    requiredRole: AgentRole.triageDefect,
    requiredCapabilities: {WorkerCapability.linux, WorkerCapability.git},
    entryStates: {
      WorkItemState.designNotRequired,
      WorkItemState.designApproved,
      WorkItemState.reviewRejected,
    },
    entryProbeTargets: {
      WorkItemState.reviewRejected: WorkItemState.designNotRequired,
    },
    priority: JobPriority.high,
    maxAttempts: 2,
  );

  /// Walks an item to `planned` the way production does: created at `draft`,
  /// planned, evidence supplied. Deliberately NO `designContractId` — that is
  /// the property of all three stranded items.
  Future<void> plantPlanned(
    DurableWorkflowEngine engine,
    String workItemId,
  ) async {
    await engine.createWorkItem(
      workItemId: workItemId,
      productId: 'prod-1',
      category: WorkItemCategory.feature,
      title: 'Stranded feature $workItemId',
      description: 'A work item parked at planned with no design contract.',
      featureRef: 'feature/stranded',
    );
    await engine.transition(
      workItemId: workItemId,
      to: WorkItemState.planning,
      trigger: TransitionTrigger.systemEvent,
    );
    await engine.transition(
      workItemId: workItemId,
      to: WorkItemState.planned,
      trigger: TransitionTrigger.systemEvent,
      context: const {'featureRef': 'feature/stranded'},
    );
  }

  FileRestartHarness hostWith(
    JobDefinition definition, {
    ControlledDispatcher? dispatch,
  }) => FileRestartHarness(
    temp,
    clock: () => t0,
    definition: definition,
    dispatch: dispatch ?? ControlledDispatcher(),
  );

  /// A dispatcher with no acquirable worker, so a tick ENQUEUES but never
  /// dispatches. Used wherever the claim under test is about the state the hop
  /// leaves the item in, which a real dispatch would move on past.
  ControlledDispatcher noCapacity() => ControlledDispatcher()..capacity = 0;

  /// A scripted worker standing in for the execution coordinator: it moves its
  /// item to `agentExecuting` and reports success, which is what the real
  /// coordinator does and what a bare [ControlledDispatcher] does not — it
  /// fabricates a result without ever attempting the execution edge.
  ///
  /// The durable move is produced HERE, separately from the scheduler, so a
  /// test can tell the two halves apart: a test that moved the item from inside
  /// the scheduler could not tell which was under test.
  Future<WorkerExecutionResult> Function(WorkerExecutionRequest) settling(
    DurableWorkflowEngine engine,
  ) {
    return (request) async {
      await engine.transition(
        workItemId: request.workItemId,
        to: WorkItemState.agentExecuting,
        trigger: TransitionTrigger.systemEvent,
        // The coordinator's identity, not the scheduler's: the two write the
        // same durable rows through the same edge, and the attribution is what
        // the history assertions below read.
        actor: const WorkflowActor(
          actorId: 'coordinator',
          actorType: ActorType.orchestrator,
        ),
        // `agentExecuting` asserts an agent is starting RIGHT NOW and its edge
        // carries `agentAvailable()`. The real coordinator supplies exactly
        // this context, so a stand-in that did not would be testing an edge
        // nobody takes.
        context: const {'agentAvailable': true, 'capabilitiesMatch': true},
      );
      return WorkerExecutionResult(
        workerExecutionId: request.workerExecutionId,
        workItemId: request.workItemId,
        status: WorkerExecutionStatus.executedPass,
        workerId: 'w-scripted-1',
        workspaceId: 'ws-${request.workerExecutionId}',
        startingRevision: request.startingRevision,
        startedAt: t0,
        endedAt: t0,
        cleanupStatus: WorkerCleanupStatus.removed,
        failureCode: WorkerFailureCode.none,
        failureDetail: null,
      );
    };
  }

  group('THE DEAD END, executed as the counterfactual', () {
    test('with `planned` absent from the entry set, a tick does nothing at all — '
        'and reports nothing at all', () async {
      final host = hostWith(baseDefinition);
      for (final id in strandedIds) {
        await plantPlanned(host.workflowEngine, id);
      }

      final evaluator = RunnableWorkEvaluator(policy: const WorkflowEngine());
      for (final id in strandedIds) {
        final item = await host.workflowStore.readWorkItem(id);
        expect(
          evaluator.evaluate(item, baseDefinition),
          RunnableWorkStatus.noAction,
          reason: '$id is at planned, which this definition does not list',
        );
      }

      final tick = await host.scheduler.tick();

      // This is the whole defect in three counts: nothing enqueued, nothing
      // dispatched, nothing moved. And — the reason it survived days —
      // NOTHING REFUSED. `entryHopRefused` is the channel that would have
      // named the state, and an item the scheduler never selects cannot reach
      // it.
      expect(tick.enqueued, isEmpty);
      expect(tick.dispatched, isEmpty);
      expect(
        tick.entryHopRefused,
        isEmpty,
        reason:
            'the silent failure mode: a state no definition dispatches from is '
            'never considered, so it is never refused and never reported. A '
            'tick with empty failures and empty refusals looks like an idle '
            'lane, which is exactly how this hid.',
      );
      for (final id in strandedIds) {
        expect(
          (await host.workflowStore.readWorkItem(id)).state,
          WorkItemState.planned,
          reason: '$id is still parked, for ever',
        );
      }
    });

    test('the pre-fix definition is the live one minus exactly `planned`', () {
      expect(
        {...baseDefinition.entryStates, WorkItemState.planned},
        triageDefectDefinition.entryStates,
        reason:
            'the counterfactual must differ from production by `planned` alone, '
            'or every comparison drawn against it is measuring something else',
      );
      expect({
        ...baseDefinition.entryProbeTargets,
        WorkItemState.planned: WorkItemState.designNotRequired,
      }, triageDefectDefinition.entryProbeTargets);
    });
  });

  group('THE `sh`-LEVEL PROOF: each stranded item is routed and dispatched', () {
    test('every stranded item is hop-routed to designNotRequired', () async {
      // No dispatch: `capacity: 0` means the pool is busy, so the item is
      // provably left AT the hop's destination. That is the literal claim under
      // test — `planned -> designNotRequired` — stated as an observed state
      // rather than inferred from a downstream dispatch.
      final host = hostWith(triageDefectDefinition, dispatch: noCapacity());
      for (final id in strandedIds) {
        await plantPlanned(host.workflowEngine, id);
      }

      final tick = await host.scheduler.tick();

      expect(tick.entryHopRefused, isEmpty);
      expect(
        tick.enqueued,
        hasLength(strandedIds.length),
        reason: 'one triage job per stranded item, all on the same tick',
      );

      for (final id in strandedIds) {
        expect(
          (await host.workflowStore.readWorkItem(id)).state,
          WorkItemState.designNotRequired,
          reason: '$id took the hop',
        );
      }
    });

    test(
      'the hop is durable, attributed to the scheduler, and recorded once',
      () async {
        final host = hostWith(triageDefectDefinition);
        for (final id in strandedIds) {
          await plantPlanned(host.workflowEngine, id);
        }

        await host.scheduler.tick();

        for (final id in strandedIds) {
          final hops = (await host.workflowStore.readTransitionHistory(id))
              .where(
                (r) =>
                    r.fromState == WorkItemState.planned &&
                    r.toState == WorkItemState.designNotRequired,
              )
              .toList();
          expect(
            hops,
            hasLength(1),
            reason:
                'exactly one hop for $id. A hop repeated per tick would be the '
                'unbounded cycle wearing a different hat.',
          );
          expect(hops.single.outcome, TransitionOutcome.accepted);
          expect(
            hops.single.actorId,
            schedulerOrchestratorActor.actorId,
            reason:
                'the scheduler acted as the orchestrator, its only identity',
          );
        }
      },
    );

    test(
      'each item goes on to a REAL execution: hop first, execution second',
      () async {
        final dispatch = ControlledDispatcher();
        final host = hostWith(triageDefectDefinition, dispatch: dispatch);
        dispatch.resultBuilder = settling(host.workflowEngine);
        for (final id in strandedIds) {
          await plantPlanned(host.workflowEngine, id);
        }

        final tick = await host.scheduler.tick();

        expect(
          tick.dispatched,
          hasLength(strandedIds.length),
          reason:
              'this is the assertion the reviewed head could not make: an item '
              'at planned used to be incapable of dispatching anything, ever',
        );
        expect(
          dispatch.runs,
          hasLength(strandedIds.length),
          reason: 'one worker execution per stranded item, for real',
        );

        for (final id in strandedIds) {
          final history = await host.workflowStore.readTransitionHistory(id);
          final hop = history.indexWhere(
            (r) =>
                r.fromState == WorkItemState.planned &&
                r.toState == WorkItemState.designNotRequired,
          );
          final execution = history.indexWhere(
            (r) => r.toState == WorkItemState.agentExecuting,
          );
          expect(hop, isNot(-1), reason: '$id hopped');
          expect(execution, isNot(-1), reason: '$id began a real execution');
          expect(
            hop,
            lessThan(execution),
            reason:
                'hop first, execution second — never the other way round. An '
                'execution from `planned` would mean the hop was skipped and the '
                'coordinator was asked for an edge that does not exist.',
          );
        }
      },
    );
  });

  group('NON-VACUITY: removing `planned` turns these tests red', () {
    test('the entry set differs by exactly one state, and the verdict flips', () {
      const engine = WorkflowEngine();
      final evaluator = RunnableWorkEvaluator(policy: engine);

      final item = WorkItem(
        workItemId: strandedIds.first,
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'A stranded item used only to ask the evaluator about a state',
        description: 'The evaluator reads the state and nothing else.',
        state: WorkItemState.planned,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      expect(
        triageDefectDefinition.entryStates.length -
            baseDefinition.entryStates.length,
        1,
        reason:
            'the widening is exactly one state wide. A second addition would '
            'mean something else had changed and the comparison below would be '
            'measuring more than `planned`.',
      );
      expect(
        evaluator.evaluate(item, triageDefectDefinition),
        RunnableWorkStatus.runnable,
        reason: 'with the fix, all three stranded items are dispatchable',
      );
      expect(
        evaluator.evaluate(item, baseDefinition),
        RunnableWorkStatus.noAction,
        reason: 'without it, all three are inert',
      );

      // The count the Manager asked for, stated as a number rather than a
      // feeling: of the states triage dispatches from, `planned` moves the
      // runnable verdict from 0 to 1 for every stranded item.
      for (final id in strandedIds) {
        expect(
          evaluator.evaluate(
            WorkItem(
              workItemId: id,
              productId: 'prod-1',
              category: WorkItemCategory.feature,
              title: id,
              description: 'counterfactual fixture',
              state: WorkItemState.planned,
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
            baseDefinition,
          ),
          isNot(RunnableWorkStatus.runnable),
          reason: '$id is stranded without the fix',
        );
      }
    });

    test('the dispatch count is 0 without the fix and 3 with it', () async {
      // The same three items, both definitions, one tick each, counted. This is
      // the mutation proof the acceptance criteria ask for: the two runs differ
      // only in whether `planned` is listed.
      final stranded = hostWith(baseDefinition);
      for (final id in strandedIds) {
        await plantPlanned(stranded.workflowEngine, id);
      }
      final before = await stranded.scheduler.tick();

      final fixed = hostWith(triageDefectDefinition, dispatch: noCapacity());
      for (final id in strandedIds) {
        await plantPlanned(fixed.workflowEngine, id);
      }
      final after = await fixed.scheduler.tick();

      expect(
        before.enqueued,
        isEmpty,
        reason: '0 of 3 enqueued without the fix',
      );
      expect(
        after.enqueued,
        hasLength(3),
        reason: '3 of 3 enqueued with it, on the same tick shape',
      );
      expect(
        before.enqueued.length,
        lessThan(after.enqueued.length),
        reason: 'the fix is load-bearing: it is the only difference',
      );
    });
  });

  group('THE BOUND: the hop cannot cycle', () {
    /// Successors that are not the generic `cancelled`/`terminated` escapes.
    ///
    /// The escapes are excluded because they TERMINATE: an item that takes one
    /// is done, so it cannot return to `planned`. Excluding them therefore
    /// strengthens the claim rather than weakening it.
    List<WorkItemState> successorsOf(WorkItemState from) =>
        WorkItemWorkflowState(
          from,
        ).allowedTransitions.map((s) => s.value).where((s) {
          return s != WorkItemState.cancelled && s != WorkItemState.terminated;
        }).toList();

    test(
      '`planned` has exactly one predecessor, and reaching it needs a HUMAN',
      () {
        final predecessors = <WorkItemState>[];
        for (final state in WorkItemState.values) {
          if (state == WorkItemState.planned) continue;
          if (WorkItemTransitions.isLegalTransition(
            state,
            WorkItemState.planned,
          )) {
            predecessors.add(state);
          }
        }

        expect(
          predecessors,
          [WorkItemState.planning],
          reason:
              'the ONLY edge into `planned` is `planning -> planned`, so `planned` '
              'can never be re-reached from any state at or after it. The item '
              'leaves `planned` exactly once and nothing puts it back.',
        );
        expect(
          successorsOf(WorkItemState.planned),
          containsAll(<WorkItemState>[
            WorkItemState.designRequired,
            WorkItemState.designNotRequired,
          ]),
        );
      },
    );

    test('the ONE path back to `planned` is a HUMAN escalation, not an automatic '
        'cycle', () {
      // The honest bound, stated precisely because the crude version of it is
      // FALSE: `planned` IS reachable from where the hop delivers the item —
      // `designNotRequired -> ... -> waitingForHumanDecision -> planning ->
      // planned` is a real path in the live table. What makes the hop bounded
      // is not that the path is absent but that no unattended actor may take
      // it.
      //
      // So the bound is asserted as the GUARD SET on the two edges that would
      // have to be crossed, read from the live table rather than described.
      final gate = WorkItemTransitions.getGuards(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.planning,
      );
      final guardNames = gate.map((g) => g.name).toList();

      expect(
        guardNames,
        contains('blocking_human_decision_resolved'),
        reason:
            '`waitingForHumanDecision -> planning` is reachable only by a '
            'RESOLVED escalation decision. An item cannot resolve its own '
            'gate, so this edge is not the machine\'s to take.',
      );
      expect(
        guardNames,
        contains('decision_actor_is_human'),
        reason:
            'and the resolution must be signed by a human. Even a resolved '
            'decision is refused if a machine signed it — which is the reason '
            'this edge, not merely its absence, is the bound.',
      );
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.waitingForHumanDecision,
          WorkItemState.planning,
        ),
        isTrue,
        reason:
            'the edge exists — the bound is the guard on it, not its absence. '
            'Asserting the edge is absent instead would make this suite '
            'pass for the wrong reason.',
      );
    });

    test('the hop cannot loop on any AUTOMATIC path out of its destination', () {
      // The automatic half of the bound, as a graph walk over the LIVE table:
      // ignoring guards, is `planned` reachable from `designNotRequired`? Yes —
      // through the human escalation above. So the walk is done the other way
      // round, which is the question that has a hard answer: from `planned`, how
      // many times can the machine reach `planned` again? Once, by construction,
      // because `planned` is the only state with a predecessor and the walk below
      // confirms the graph has no second edge into it.
      final predecessorsOfPlanned = <WorkItemState>[];
      for (final state in WorkItemState.values) {
        if (state == WorkItemState.planned) continue;
        if (WorkItemTransitions.isLegalTransition(
          state,
          WorkItemState.planned,
        )) {
          predecessorsOfPlanned.add(state);
        }
      }
      expect(predecessorsOfPlanned, hasLength(1));
      expect(predecessorsOfPlanned.single, WorkItemState.planning);

      // `planning` in turn has exactly two predecessors: the start of a
      // lifecycle, and the human gate. Nothing in the execution half of the
      // graph feeds either.
      final predecessorsOfPlanning = <WorkItemState>[];
      for (final state in WorkItemState.values) {
        if (state == WorkItemState.planning) continue;
        if (WorkItemTransitions.isLegalTransition(
          state,
          WorkItemState.planning,
        )) {
          predecessorsOfPlanning.add(state);
        }
      }
      expect(predecessorsOfPlanning.toSet(), {
        WorkItemState.draft,
        WorkItemState.waitingForHumanDecision,
      });
      expect(
        predecessorsOfPlanning,
        isNot(contains(WorkItemState.agentExecuting)),
        reason:
            'an execution cannot re-enter planning, so it cannot re-enter '
            'planned either',
      );
    });

    test(
      'twenty-five ticks produce three hops and three jobs, never more',
      () async {
        // Well above any honest duration of the work. The failure mode being
        // bounded against is a hop (or a dispatch) PER TICK.
        final dispatch = ControlledDispatcher();
        final host = hostWith(triageDefectDefinition, dispatch: dispatch);
        dispatch.resultBuilder = settling(host.workflowEngine);
        for (final id in strandedIds) {
          await plantPlanned(host.workflowEngine, id);
        }

        for (var i = 0; i < 25; i++) {
          await host.scheduler.tick();
        }

        expect(
          await host.jobStore.listJobs(),
          hasLength(3),
          reason: 'one triage job per stranded item, and no re-mints',
        );
        expect(
          dispatch.runs,
          hasLength(3),
          reason:
              'one worker execution per item across twenty-five ticks — the '
              'shape the review measured on `reviewRejected`, which produced one '
              'per tick before it was fixed',
        );
        for (final id in strandedIds) {
          final hops = (await host.workflowStore.readTransitionHistory(id))
              .where(
                (r) =>
                    r.fromState == WorkItemState.planned &&
                    r.toState == WorkItemState.designNotRequired,
              );
          expect(hops, hasLength(1), reason: '$id hopped exactly once, ever');
        }
      },
    );
  });

  group('THE TRANSITION TABLE DID NOT CHANGE', () {
    test('`planned -> designNotRequired` already existed and is unguarded', () {
      // The acceptance criterion, as an executable property: this lane made the
      // edge REACHABLE and did not declare it. The guard set is asserted in
      // full, so a future change that quietly added a guard would be visible
      // here rather than silently narrowing the route this fix depends on.
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.planned,
          WorkItemState.designNotRequired,
        ),
        isTrue,
      );

      final transition = const WorkflowEngine().evaluateWorkItemTransition(
        from: WorkItemState.planned,
        to: WorkItemState.designNotRequired,
        trigger: TransitionTrigger.systemEvent,
        actor: schedulerOrchestratorActor,
        context: const {'agentAvailable': true, 'capabilitiesMatch': true},
      );
      expect(transition.isValid, isTrue);
      expect(
        transition.guardResults.map((g) => g.name),
        ['actor_allowed'],
        reason:
            'exactly one guard, `actorAllowed([orchestrator])` — the table\'s '
            'own convention for an edge into an entry state that asserts no '
            'execution is starting. This suite relies on it being UNguarded: '
            'that is what makes it available to a contract-less item, and what '
            'makes the contract-carrying case below the residual it is.',
      );
    });

    test('no new edge was introduced out of `planned`', () {
      final out = <WorkItemState>[];
      for (final state in WorkItemState.values) {
        if (state == WorkItemState.planned) continue;
        if (WorkItemTransitions.isLegalTransition(
          WorkItemState.planned,
          state,
        )) {
          out.add(state);
        }
      }
      expect(
        out,
        containsAll(<WorkItemState>[
          WorkItemState.designRequired,
          WorkItemState.designNotRequired,
          WorkItemState.cancelled,
          WorkItemState.terminated,
        ]),
      );
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.planned,
          WorkItemState.agentExecuting,
        ),
        isFalse,
        reason:
            '`planned -> agentExecuting` must stay absent. `agentExecuting` is '
            'in the entryStates of no wired definition, so an edge to it would '
            'recreate this exact dead end one state further along — and it is '
            'why the definition needs a probe target rather than a direct edge.',
      );
    });

    test('every hop this lane names lands on an entry state it already had', () {
      // The shape of the fix: a hop onto a state this definition ALREADY
      // dispatches from, not a widening that requires a new destination.
      expect(
        triageDefectDefinition.entryProbeTargets.values.toSet(),
        {WorkItemState.designNotRequired},
        reason:
            'both hops land on `designNotRequired`, which was already an entry '
            'state before this change. No new dispatchable destination was '
            'introduced.',
      );
      for (final entry in triageDefectDefinition.entryProbeTargets.entries) {
        expect(
          triageDefectDefinition.entryStates,
          contains(entry.value),
          reason: '${entry.key.wire} hops onto a state this lane already runs',
        );
      }
    });
  });

  group('THE RESIDUAL, named rather than passed off as solved', () {
    test('a `planned` item WITH a design contract is still routed to '
        'designNotRequired — triaged, not designed', () async {
      // The boundary this lane was told not to cross silently. Asserted here
      // so it is a recorded behaviour with a named consequence, not an
      // oversight a later reader has to rediscover. `planned ->
      // designNotRequired` carries no guard, so the contract is not consulted.
      final host = hostWith(triageDefectDefinition, dispatch: noCapacity());
      const id = 'WI-feature-with-contract';
      await host.workflowEngine.createWorkItem(
        workItemId: id,
        productId: 'prod-1',
        category: WorkItemCategory.feature,
        title: 'A planned item that does carry a design contract',
        description: 'The case the unguarded hop does not ask about.',
        designContractId: 'dc-1',
        featureRef: 'feature/with-contract',
      );
      await host.workflowEngine.transition(
        workItemId: id,
        to: WorkItemState.planning,
        trigger: TransitionTrigger.systemEvent,
      );
      await host.workflowEngine.transition(
        workItemId: id,
        to: WorkItemState.planned,
        trigger: TransitionTrigger.systemEvent,
        context: const {'featureRef': 'feature/with-contract'},
      );

      expect(
        const WorkflowEngine()
            .evaluateWorkItemTransition(
              from: WorkItemState.planned,
              to: WorkItemState.designRequired,
              trigger: TransitionTrigger.systemEvent,
              actor: schedulerOrchestratorActor,
              context: const {
                'agentAvailable': true,
                'capabilitiesMatch': true,
                // The edge is legal when a contract CONFIRMED AGAINST THE
                // STORE backs it. It used to assert legality with a bare
                // `'designContractId': 'dc-1'` in context, which was the defect
                // itself: the guard read that string, the durable engine
                // discarded it, and an item was persisted at `designRequired`
                // with a NULL column behind it. A pure policy engine has no
                // work item and no store, so the strongest claim it can make
                // here is "legal given a confirmed contract" — and that is what
                // this now says.
                designContractResolutionContextKey: DesignContractResolution(
                  contractId: 'dc-1',
                  storeConfirmed: true,
                ),
              },
            )
            .isValid,
        isTrue,
        reason:
            'the design lane is NOT unreachable in principle — the edge is '
            'legal when a contract is supplied AND confirmed. It is simply not '
            'the hop this definition declares, which is the whole of the '
            'residual.',
      );

      // …and it is equally NOT legal on a string, which is the half that used
      // to be the whole of it.
      expect(
        const WorkflowEngine()
            .evaluateWorkItemTransition(
              from: WorkItemState.planned,
              to: WorkItemState.designRequired,
              trigger: TransitionTrigger.systemEvent,
              actor: schedulerOrchestratorActor,
              context: const {
                'agentAvailable': true,
                'capabilitiesMatch': true,
                'designContractId': 'dc-1',
              },
            )
            .isValid,
        isFalse,
        reason:
            'a caller-supplied id is not a contract. This assertion used to be '
            'the `isTrue` above, and it is the falsifier '
            '`design-revision.md` §4.3 names.',
      );

      await host.scheduler.tick();

      expect(
        (await host.workflowStore.readWorkItem(id)).state,
        WorkItemState.designNotRequired,
        reason:
            'the residual, stated as an observed outcome: this item skips the '
            'design lane. Accepted deliberately for this lane (every item '
            'observed at planned had no contract, and the alternative edge was '
            'unavailable to them), and NOT fixed here — conditional routing is '
            'not expressible in a static Map<WorkItemState, WorkItemState>. '
            'Reported as a discovery for an architecture decision.',
      );
    });
  });
}
