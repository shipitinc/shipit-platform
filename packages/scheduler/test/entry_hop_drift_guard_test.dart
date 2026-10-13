import 'package:platform_contracts/platform_contracts.dart';
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';

/// No production [JobDefinition] may declare an entry state the coordinator
/// cannot act on.
///
/// ## The invariant, stated once
///
/// For every definition `D` and every entry state `S` of `D`, an item at `S`
/// may be dispatched only if one of these holds:
///
///  1. **direct** — an edge `S -> D.targetState` exists, so
///     `ExecutionCoordinator.execute` can attempt it and succeed. `D.targetState`
///     is what the coordinator attempts: `agentExecuting` for every role except
///     the engineering reviewer, which is exactly what
///     `engineeringReviewDefinition` declares as its `targetState`.
///  2. **hopped** — `D` declares `entryProbeTargets[S] = T`, the policy accepts
///     `S -> T` in the scheduler's own context, `T` is itself an entry state of
///     `D`, and `T` satisfies (1). `EntryHopper` performs the hop, so the
///     coordinator is only ever asked to attempt an edge that exists.
///
/// Neither the probe nor the hop may be bypassed to make a third case legal,
/// which is why `skipWorkflowPolicyCheck` is checked explicitly rather than
/// assumed away: a definition that skips the probe can silently declare (2)
/// without (1), which is precisely how `designRevisionDefinition` reached
/// `designRejected` and burned five worker executions on one item.
///
/// ## Why this is a test and not a comment
///
/// A comment is read once and then drifts silently; this reads the LIVE
/// transition table through the policy engine on every run. Adding an entry
/// state to a definition, removing an edge, or re-introducing a probe bypass
/// fails here with the definition and state named. That is the property the
/// reviewed head lacked: nothing anywhere asserted that a definition's entry
/// states and the transition table agreed, so they could stop agreeing without
/// anything noticing until a work item was stranded.
void main() {
  const engine = WorkflowEngine();
  const schedulerContext = <String, dynamic>{
    'agentAvailable': true,
    'capabilitiesMatch': true,
  };

  /// Every [JobDefinition] this package ships. A definition added to production
  /// and NOT listed here is itself the defect this test exists to prevent: it
  /// would be unconstrained.
  const productionDefinitions = <JobDefinition>[
    defaultImplementFeatureDefinition,
    implementFeatureDefinition,
    triageDefectDefinition,
    designRevisionDefinition,
    designReviewDefinition,
    engineeringReviewDefinition,
  ];

  /// Whether ANY edge `<from> -> <to>` exists, guards ignored.
  ///
  /// Guards are excluded on purpose. The engineering-review entry edge carries
  /// `agentResultValid()`, which needs the implementer's completed result — the
  /// scheduler cannot supply it and the coordinator supplies it for itself, so
  /// asking about that edge's GUARDS here would report a working route as
  /// absent. Whether an edge EXISTS is the question this guard is about.
  bool edgeExists(WorkItemState from, WorkItemState to) {
    final transition = engine.evaluateWorkItemTransition(
      from: from,
      to: to,
      trigger: TransitionTrigger.systemEvent,
      actor: schedulerOrchestratorActor,
      context: schedulerContext,
    );
    return !transition.failedGuards.contains('legal_transition');
  }

  /// Whether the scheduler itself may take `<from> -> <to>`, guards included —
  /// because the scheduler is the actor that would perform the write.
  bool schedulerCanTake(WorkItemState from, WorkItemState to) {
    return engine
        .evaluateWorkItemTransition(
          from: from,
          to: to,
          trigger: TransitionTrigger.systemEvent,
          actor: schedulerOrchestratorActor,
          context: schedulerContext,
        )
        .isValid;
  }

  /// A minimal item carrying nothing but the state under test, which is all
  /// [RunnableWorkEvaluator] reads.
  WorkItem itemAt(WorkItemState state) => WorkItem(
    workItemId: 'wi-probe',
    productId: 'prod-1',
    category: WorkItemCategory.feature,
    title: 'A work item used only to ask the evaluator about a state',
    description:
        'A drift-guard fixture: the evaluator reads the state and nothing '
        'else, so this item exists only to carry that state.',
    state: state,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  group('every production definition is dispatchable at every entry state', () {
    for (final definition in productionDefinitions) {
      for (final entry in definition.entryStates) {
        test('${definition.jobType.wire} at ${entry.wire}', () {
          // A named entry state is allowed to be UNREACHABLE — a declared
          // route waiting for its edge — but only when the probe is LIVE, so
          // the unreachability is what the scheduler acts on rather than
          // something it cannot see. `designRevisionDefinition` names
          // `designRejected` for exactly this reason. The probe bypass is the
          // case that turns a named state into a dispatch, and that is
          // forbidden separately, below.
          final direct = edgeExists(entry, definition.targetState);
          final declared = definition.entryProbeTargets[entry];
          final probedDeadly = !definition.skipWorkflowPolicyCheck;
          expect(
            direct || declared != null || probedDeadly,
            isTrue,
            reason:
                'no ${entry.wire} -> ${definition.targetState.wire} edge and no '
                'intermediate hop is declared, so nothing could ever dispatch '
                'this item — while the definition names it as a place it runs. '
                'Either add the edge in workflow_engine, declare the hop in '
                'entryProbeTargets, or drop ${entry.wire} from entryStates.',
          );

          if (direct || declared != null) return;

          // The remaining shape: a NAMED state with no route, kept alive by the
          // live probe. That is only safe while the probe actually refuses it,
          // so assert the refusal rather than trusting it.
          expect(
            RunnableWorkEvaluator(
              policy: engine,
            ).evaluate(itemAt(entry), definition),
            isNot(RunnableWorkStatus.runnable),
            reason:
                '${definition.jobType.wire} names ${entry.wire}, which has no '
                'route to ${definition.targetState.wire} and no declared hop. '
                'The live probe refuses it, which is what makes naming it safe. '
                'If this is runnable, the scheduler will dispatch it and the '
                'coordinator will refuse every attempt at the cost of a real '
                'worker execution — the defect this whole mechanism closes',
          );
        });
      }
    }
  });

  group('a declared hop is legal and lands somewhere the job can still run', () {
    for (final definition in productionDefinitions) {
      for (final entry in definition.entryProbeTargets.keys) {
        final hopTarget = definition.entryProbeTargets[entry]!;

        test('${definition.jobType.wire}: ${entry.wire} -> ${hopTarget.wire}', () {
          expect(
            definition.entryStates.contains(entry),
            isTrue,
            reason:
                'a hop declared for ${entry.wire} is dead weight unless that '
                'state is an entry state: nothing ever reaches the declaration',
          );
          expect(
            schedulerCanTake(entry, hopTarget),
            isTrue,
            reason:
                'the policy refuses ${entry.wire} -> ${hopTarget.wire} in the '
                'scheduler\'s own context, so EntryHopper would refuse every '
                'attempt. The declaration is a route the scheduler cannot take',
          );
          expect(
            definition.entryStates.contains(hopTarget),
            isTrue,
            reason:
                '${hopTarget.wire} is not an entry state for '
                '${definition.jobType.wire}, so taking the hop would strand the '
                'item somewhere nothing dispatches it. This is the trap the '
                'design-revision route would have fallen into',
          );
          expect(
            edgeExists(hopTarget, definition.targetState),
            isTrue,
            reason:
                'the hop must COMPLETE the route: there is no '
                '${hopTarget.wire} -> ${definition.targetState.wire} edge, so '
                'the coordinator would refuse the very state the hop delivered',
          );
        });
      }
    }
  });

  group('the probe is not bypassed where a bypass would hide a dead route', () {
    test('a definition that skips the policy check has no entry state the '
        'coordinator cannot act on', () {
      // The bypass is a legitimate tool — `engineeringReviewDefinition` needs
      // it because the scheduler cannot supply the implementer's result — so
      // this does not ban it. What it bans is the COMBINATION: a bypassed
      // probe means `RunnableWorkEvaluator` answers "runnable" without asking,
      // so a dead entry state is invisible to the probe and reaches the
      // coordinator. That combination is the defect, and it is what
      // `designRevisionDefinition` shipped until this suite existed.
      for (final definition in productionDefinitions) {
        if (!definition.skipWorkflowPolicyCheck) continue;
        for (final entry in definition.entryStates) {
          expect(
            edgeExists(entry, definition.targetState) ||
                definition.entryProbeTargets.containsKey(entry),
            isTrue,
            reason:
                '${definition.jobType.wire} skips the workflow policy check '
                'and declares ${entry.wire}, whose '
                '${entry.wire} -> ${definition.targetState.wire} edge does '
                'not exist. The probe calls it runnable regardless, so every '
                'dispatch is refused by the coordinator at the cost of a real '
                'worker execution. Remove the bypass, or declare the hop',
          );
        }
      }
    });
  });

  group('the evaluator agrees with the coordinator about what is runnable', () {
    // The end-to-end form of the same invariant: build a real item in every
    // production entry state and ask the real evaluator. Anything it calls
    // `runnable` must be somewhere EntryHopper can make startable.
    for (final definition in productionDefinitions) {
      for (final entry in definition.entryStates) {
        test('${definition.jobType.wire} at ${entry.wire}', () async {
          final store = InMemoryWorkflowStore();
          final workflow = DurableWorkflowEngine(store: store);
          await workflow.createWorkItem(
            workItemId: 'wi-1',
            productId: 'prod-1',
            category: WorkItemCategory.feature,
            title: 'Design the calculator add function',
            description:
                'A drift-guard fixture: a work item is walked to a production '
                'entry state so the live evaluator and the live transition '
                'table can be asked about it.',
            qaContractId: 'qa-1',
          );
          final item = await placeIn(workflow, entry);

          final evaluator = RunnableWorkEvaluator(policy: engine);
          if (evaluator.evaluate(item, definition) !=
              RunnableWorkStatus.runnable) {
            return; // Not dispatchable, so there is nothing to make startable.
          }

          final hop = await EntryHopper(
            policy: engine,
            engine: workflow,
            definition: definition,
          ).prepare(item);

          expect(
            hop.dispatchable,
            isTrue,
            reason:
                'the evaluator calls ${entry.wire} runnable for '
                '${definition.jobType.wire}, but EntryHopper cannot make it '
                'startable (${hop.status}'
                '${hop.reason == null ? '' : ': ${hop.reason}'}). '
                'A runnable-but-unstartable item is the defect this whole '
                'mechanism exists to remove, and it must never be reachable',
          );
        });
      }
    }
  });
}

/// Drives a real item to [state] through legal transitions only.
///
/// One item, one walk, branched by the state under test: a guard that fakes a
/// state would be checking its own fixture rather than the table.
Future<WorkItem> placeIn(
  DurableWorkflowEngine workflow,
  WorkItemState state,
) async {
  Future<void> step(
    WorkItemState to, {
    Map<String, dynamic> context = const {},
    TransitionTrigger trigger = TransitionTrigger.systemEvent,
  }) => workflow.transition(
    workItemId: 'wi-1',
    to: to,
    trigger: trigger,
    context: context,
  );

  const designContract = {'designContractId': 'dc-1'};
  const underReview = {
    'designContractId': 'dc-1',
    'designContractStatus': DesignContractStatus.underReview,
  };
  const executing = {'agentAvailable': true, 'capabilitiesMatch': true};
  final agentResult = AgentResult(
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
    summary: 'implemented the calculator in the worktree',
    completedAt: DateTime.utc(2026),
  );

  await step(WorkItemState.planning);
  await step(WorkItemState.planned, context: const {'featureRef': 'f-1'});

  switch (state) {
    case WorkItemState.designNotRequired:
      await step(WorkItemState.designNotRequired);
    // The implementation lane's own entry state. Reached the way production
    // reaches it — through the `waitingForHumanDecision ->
    // implementationReady` edge a resolved human decision takes — rather than
    // faked by writing the state onto the row. A guard that fakes a state would
    // be checking its own fixture instead of the table, which is the one thing
    // this file exists to prevent.
    //
    // It has to walk the full gate because the item starts at `draft`: the
    // transition into it carries `blockingHumanDecisionResolved` and
    // `decisionActorIsHuman()`, so a walk that skipped the gate would be
    // asserting against a transition the engine would refuse.
    case WorkItemState.implementationReady:
      await step(WorkItemState.designRequired, context: designContract);
      await step(WorkItemState.designInReview, context: underReview);
      await _resolveDesign(workflow, HumanDecisionChoice.approve);
      await step(WorkItemState.agentExecuting, context: executing);
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
      final review = await workflow.requestHumanDecision(
        workItemId: 'wi-1',
        decisionType: HumanDecisionType.engineeringReview,
        actor: const WorkflowActor(
          actorId: 'reviewer-2',
          actorType: ActorType.engineeringReviewer,
        ),
        extraContext: const {'producerActorId': 'agent-1'},
      );
      await _resolveDecision(
        workflow,
        review.decisionId,
        HumanDecisionChoice.rework,
      );
    case WorkItemState.agentFailed:
      await step(WorkItemState.designNotRequired);
      await step(WorkItemState.agentExecuting, context: executing);
      await step(WorkItemState.agentFailed);
    case WorkItemState.designRequired:
      await step(WorkItemState.designRequired, context: designContract);
    case WorkItemState.designInReview:
    case WorkItemState.designRejected:
      await step(WorkItemState.designRequired, context: designContract);
      await step(WorkItemState.designInReview, context: underReview);
      if (state == WorkItemState.designRejected) {
        await _resolveDesign(workflow, HumanDecisionChoice.reject);
      }
    case WorkItemState.designApproved:
      await step(WorkItemState.designRequired, context: designContract);
      await step(WorkItemState.designInReview, context: underReview);
      await _resolveDesign(workflow, HumanDecisionChoice.approve);
    case WorkItemState.agentCompleted:
    case WorkItemState.reviewRejected:
      await step(WorkItemState.designRequired, context: designContract);
      await step(WorkItemState.designInReview, context: underReview);
      await _resolveDesign(workflow, HumanDecisionChoice.approve);
      await step(WorkItemState.agentExecuting, context: executing);
      await step(
        WorkItemState.agentCompleted,
        trigger: TransitionTrigger.agentResult,
        context: {'qaContractId': 'qa-1', 'agentResult': agentResult},
      );
      if (state == WorkItemState.reviewRejected) {
        await step(
          WorkItemState.reviewInProgress,
          trigger: TransitionTrigger.agentResult,
          context: {'agentResult': agentResult},
        );
        final review = await workflow.requestHumanDecision(
          workItemId: 'wi-1',
          decisionType: HumanDecisionType.engineeringReview,
          actor: const WorkflowActor(
            actorId: 'reviewer-2',
            actorType: ActorType.engineeringReviewer,
          ),
          extraContext: const {'producerActorId': 'agent-1'},
        );
        await _resolveDecision(
          workflow,
          review.decisionId,
          HumanDecisionChoice.reject,
        );
      }
    default:
      fail(
        'no walk to ${state.wire} — add one, or this guard silently stops '
        'covering that entry state',
      );
  }
  return workflow.loadWorkItem('wi-1');
}

Future<void> _resolveDesign(
  DurableWorkflowEngine workflow,
  HumanDecisionChoice choice,
) async {
  final decision = await workflow.requestHumanDecision(
    workItemId: 'wi-1',
    decisionType: HumanDecisionType.designApproval,
    blocking: true,
  );
  await _resolveDecision(workflow, decision.decisionId, choice);
}

Future<void> _resolveDecision(
  DurableWorkflowEngine workflow,
  String decisionId,
  HumanDecisionChoice choice,
) async {
  await workflow.resolveHumanDecision(
    decisionId: decisionId,
    choice: choice,
    decider: 'hum@shipit.platform',
    rationale: 'drift-guard fixture decision',
    signature: DecisionSignature(
      algorithm: 'ed25519',
      publicKey: 'test-public-key',
      signature: 'sig-guard',
      signedAt: DateTime.utc(2026),
    ),
  );
}
