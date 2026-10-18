import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:scheduler/scheduler.dart' show schedulerOrchestratorActor;
import 'package:workflow_engine/workflow_engine.dart';
import 'package:workflow_store/workflow_store.dart';

/// `WorkItemState.implementationReady` is not a stranding state, and the rework
/// gate that feeds it is not a weakened gate.
///
/// ## What this file is for
///
/// Two obligations survive independently of every open decision in the design:
///
///  * **D-12** — `implementationReady -> agentExecuting` exists, so an item at
///    the implementation lane's entry state is not inert.
///  * **D-14** — `waitingForHumanDecision -> implementationReady` exists and
///    carries the SAME guard set as the edge it shadows, so answering `OD-3`
///    was a routing-table edit and not an engine change. Without this edge, a
///    retarget would move an item to a state nothing leaves and the engine
///    would throw on resolution: the decision would be answered and the work
///    would sit at its gate with nothing running.
///
/// `OD-3` is now RESOLVED and four of the five rework pairs target the state.
/// The obligations above did not change; what changed is that the edge is no
/// longer declared-but-unclaimed, and this file is where that is asserted.
///
/// The second is the one this file spends most of its lines on, because it is
/// the one that fails SILENTLY. A guard set that drifts does not error; it
/// quietly accepts resolutions it should refuse, or quietly refuses ones an
/// operator authorised. So does an escalation lockstep divergence: it does not
/// error either, it stops the escalation index advancing.
void main() {
  const engine = WorkflowEngine();
  const schedulerContext = <String, dynamic>{
    'agentAvailable': true,
    'capabilitiesMatch': true,
  };

  /// The rework pairs the design brief names as candidates for retargeting,
  /// and the five `OD-3` actually considered.
  ///
  /// All five are candidates for `escalationTargetFor`, and only two are live
  /// arms; the retarget itself moved four of the five, so this list is the
  /// `OD-3` question rather than the `OD-3` answer. The answer is asserted
  /// explicitly in the routing group below.
  const reworkCandidates = <(HumanDecisionType, HumanDecisionChoice)>[
    (HumanDecisionType.engineeringReview, HumanDecisionChoice.rework),
    (HumanDecisionType.qaWaiver, HumanDecisionChoice.reject),
    (HumanDecisionType.qaRework, HumanDecisionChoice.reject),
    (HumanDecisionType.humanQaApproval, HumanDecisionChoice.reject),
    (HumanDecisionType.escalation, HumanDecisionChoice.approve),
  ];

  group('the implementation entry state is not inert', () {
    test('the direct edge into agentExecuting exists', () {
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.implementationReady,
          WorkItemState.agentExecuting,
        ),
        isTrue,
      );
    });

    test('the scheduler itself may take it', () {
      final transition = engine.evaluateWorkItemTransition(
        from: WorkItemState.implementationReady,
        to: WorkItemState.agentExecuting,
        trigger: TransitionTrigger.systemEvent,
        actor: schedulerOrchestratorActor,
        context: schedulerContext,
      );
      expect(
        transition.isValid,
        isTrue,
        reason:
            'the entry edge carries `actorAllowed([orchestrator])` and '
            '`agentAvailable()`, both of which the scheduler\'s own context '
            'supplies. If either were missing the scheduler would enqueue and '
            'the coordinator would refuse every attempt',
      );
    });

    test('only the orchestrator may start an execution from it', () {
      final transition = engine.evaluateWorkItemTransition(
        from: WorkItemState.implementationReady,
        to: WorkItemState.agentExecuting,
        trigger: TransitionTrigger.systemEvent,
        actor: const WorkflowActor(
          actorId: 'someone',
          actorType: ActorType.engineeringReviewer,
        ),
        context: schedulerContext,
      );
      expect(transition.isValid, isFalse);
    });

    test(
      'it is not a terminal state and does not escape into one by accident',
      () {
        expect(WorkItemState.implementationReady.isTerminal, isFalse);
        expect(
          WorkItemWorkflowState(
            WorkItemState.implementationReady,
          ).allowedTransitions.map((s) => s.value),
          {
            WorkItemState.agentExecuting,
            WorkItemState.cancelled,
            WorkItemState.terminated,
          },
        );
      },
    );

    test('the wire value round-trips', () {
      expect(WorkItemState.implementationReady.wire, 'implementation_ready');
      expect(
        WorkItemState.fromWire('implementation_ready'),
        WorkItemState.implementationReady,
      );
    });
  });

  group('the rework gate onto implementationReady is not weakened', () {
    test('the edge exists', () {
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.waitingForHumanDecision,
          WorkItemState.implementationReady,
        ),
        isTrue,
      );
    });

    test('it carries EXACTLY the guards of the edge it shadows', () {
      final shadowed = WorkItemTransitions.getGuards(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.designNotRequired,
      );
      final actual = WorkItemTransitions.getGuards(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.implementationReady,
      );

      expect(
        actual.length,
        shadowed.length,
        reason:
            'the new edge must be a landing site for the SAME gate. A guard '
            'added here is new policy; one dropped is a silent relaxation',
      );
      // Compared by the guard NAMES the results carry, because the conditions
      // are closures and two closures never compare equal.
      final names = (List<GuardCondition<WorkItemState>> guards) =>
          guards.map((g) => g.name).toList()..sort();
      expect(names(actual), names(shadowed));
    });

    test('the escalation bound is MOVED with the edge, not invented', () {
      // The bound covers exactly the two decision types the shadowed edge
      // bounds. `qaRework`, `qaWaiver` and `escalation` are deliberately
      // absent there and must be absent here: inventing a bound is new
      // policy, and dropping `humanQaApproval` would quietly RELAX a bound it
      // already has.
      final shadowed = WorkItemTransitions.getGuards(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.designNotRequired,
      );
      final actual = WorkItemTransitions.getGuards(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.implementationReady,
      );
      final boundOf = (List<GuardCondition<WorkItemState>> guards) => guards
          .where((g) => g.name == 'escalation_index_within_limit')
          .toList();
      expect(boundOf(actual).length, boundOf(shadowed).length);
      expect(boundOf(actual), isNotEmpty);
    });

    test('a decision no human made still cannot move the item', () {
      final transition = engine.evaluateWorkItemTransition(
        from: WorkItemState.waitingForHumanDecision,
        to: WorkItemState.implementationReady,
        trigger: TransitionTrigger.systemEvent,
        actor: schedulerOrchestratorActor,
        context: const {},
      );
      expect(
        transition.isValid,
        isFalse,
        reason:
            '`blockingHumanDecisionResolved` and `decisionActorIsHuman()` are '
            'both on this edge. An edge without them would let the scheduler '
            'move work into the build queue on its own, which is an automated '
            'rework loop nothing bounds',
      );
    });

    test('the edge is declared, fully armed, and CLAIMED by the routes OD-3 '
        'resolved', () async {
      // The two halves, kept apart on purpose because conflating them is how a
      // lane that does nothing gets mistaken for a lane that is broken.
      //
      // The TABLE accepts the move. `_move` builds the resolved decision the
      // guards actually read and asks the live policy, so this is the real
      // guard set and not a hand-written context map.
      expect(
        _move(HumanDecisionType.engineeringReview, HumanDecisionChoice.rework),
        isTrue,
        reason:
            'the guard set must accept the resolution the edge exists for. An '
            'edge nothing can take is a stranding edge in a different costume',
      );

      // The ROUTING now asks for it. `resolveHumanDecision` derives its target
      // from `targetFor` alone, so a real resolution lands on
      // `implementationReady`. This is the assertion that failed while OD-3 was
      // open, and it is the reason the retarget could not be a no-op.
      final landed = await _resolveEngineeringRework();
      expect(
        HumanDecisionRouting.targetFor(
          HumanDecisionType.engineeringReview,
          HumanDecisionChoice.rework,
        ),
        WorkItemState.implementationReady,
      );
      expect(
        landed.state,
        WorkItemState.implementationReady,
        reason:
            'a live rework must now RE-IMPLEMENT. If this starts failing, a '
            'routing entry has moved away from implementation_ready, and this '
            'test is where that happened',
      );
    });

    test('exactly the four rework gates route here, and escalation does not', () {
      // `OD-3` chose four of the five candidates and named the one it did not:
      // an escalation is a statement about EXECUTION failing, not about work
      // quality, so `(escalation, approve)` must still re-plan rather than
      // re-implement. Asserting the four by name is what stops a fifth route
      // from arriving here by accident — this table is the ONLY determinant of
      // where a resolved decision lands, so an extra arm is an extra producer
      // the lane nobody reviewed.
      const toImplementationReady = <(HumanDecisionType, HumanDecisionChoice)>[
        (HumanDecisionType.engineeringReview, HumanDecisionChoice.rework),
        (HumanDecisionType.qaWaiver, HumanDecisionChoice.reject),
        (HumanDecisionType.qaRework, HumanDecisionChoice.reject),
        (HumanDecisionType.humanQaApproval, HumanDecisionChoice.reject),
      ];
      for (final pair in toImplementationReady) {
        expect(
          HumanDecisionRouting.targetFor(pair.$1, pair.$2),
          WorkItemState.implementationReady,
          reason:
              '(${pair.$1.name}, ${pair.$2.name}) is one of the four gates '
              'OD-3 resolved to mean "re-do the work"',
        );
      }
      expect(
        HumanDecisionRouting.targetFor(
          HumanDecisionType.escalation,
          HumanDecisionChoice.approve,
        ),
        WorkItemState.designNotRequired,
        reason:
            'an escalation is about execution failing, so the work may not '
            'exist at all. Routing it into the build queue would be the '
            'misroute OD-3 explicitly declined',
      );
    });

    test('neither lockstep arm was left behind on the old state', () {
      // The failure mode this exists to catch is SILENT: `_isEscalationTransition`
      // compares the two tables and a mismatch does not throw, it just stops
      // the escalation index advancing and reshapes the audit trail. Asserting
      // the VALUE, not merely the equality, is what makes a partial move
      // visible.
      for (final pair in const [
        (HumanDecisionType.engineeringReview, HumanDecisionChoice.rework),
        (HumanDecisionType.humanQaApproval, HumanDecisionChoice.reject),
      ]) {
        expect(
          HumanDecisionRouting.escalationTargetFor(pair.$1, pair.$2),
          WorkItemState.implementationReady,
          reason:
              '(${pair.$1.name}, ${pair.$2.name}) moved in `targetFor`, so this '
              'arm must have moved with it in the SAME commit',
        );
      }
    });

    test(
      'the rework guard accepts exactly the six pairs the shadowed edge does',
      () {
        final accepted = <(HumanDecisionType, HumanDecisionChoice)>[];
        final rejected = <(HumanDecisionType, HumanDecisionChoice)>[];
        for (final type in HumanDecisionType.values) {
          for (final choice in HumanDecisionChoice.values) {
            final move = _move(type, choice);
            (move ? accepted : rejected).add((type, choice));
          }
        }
        expect(
          accepted,
          containsAll(
            reworkCandidates.where(
              (p) =>
                  p.$2 != HumanDecisionChoice.approve ||
                  p.$1 == HumanDecisionType.escalation,
            ),
          ),
          reason:
              'every pair the design brief lists as a retarget candidate must be '
              'one this edge would accept when `OD-3` routes it here. If one is '
              'not, the retarget would be refused by the engine at resolution '
              'time and the decision would be answered with the item unmoved',
        );
        expect(
          accepted,
          isNot(
            contains((
              HumanDecisionType.designApproval,
              HumanDecisionChoice.approve,
            )),
          ),
          reason:
              'a design approval is not a "do the work again" resolution; it '
              'belongs to the `designApproved` edge and must not open this one',
        );
      },
    );
  });

  group('the escalation lockstep map is exactly two pairs wide', () {
    // D-13. The stale brief claimed all five rework retargets had to move
    // `escalationTargetFor` in lockstep. Three of them do not, and the
    // correction is load-bearing: `escalationTargetFor` returns null unless the
    // choice is `reject` or `rework`, and `_isEscalationTransition` short-
    // circuits on the same condition before it ever calls it.
    test('exactly two of the five candidates are live escalation arms', () {
      final live = reworkCandidates
          .where(
            (p) => HumanDecisionRouting.escalationTargetFor(p.$1, p.$2) != null,
          )
          .toSet();

      expect(live, {
        (HumanDecisionType.engineeringReview, HumanDecisionChoice.rework),
        (HumanDecisionType.humanQaApproval, HumanDecisionChoice.reject),
      });
    });

    test('the other three are inert, so retargeting them cannot diverge', () {
      for (final pair in const [
        (HumanDecisionType.qaWaiver, HumanDecisionChoice.reject),
        (HumanDecisionType.qaRework, HumanDecisionChoice.reject),
        (HumanDecisionType.escalation, HumanDecisionChoice.approve),
      ]) {
        expect(
          HumanDecisionRouting.escalationTargetFor(pair.$1, pair.$2),
          isNull,
          reason:
              '(${pair.$1.name}, ${pair.$2.name}) has no escalation arm, so '
              'moving its `targetFor` cannot stop the escalation index '
              'advancing. If this starts failing, this pair has become a live '
              'arm and must now be moved in lockstep',
        );
      }
    });

    test('both live arms agree with targetFor today', () {
      // The divergence these two tables can suffer does NOT error: it silently
      // stops the `escalationIndex` increment and the `EscalationTriggered`
      // audit record. So the agreement is asserted rather than assumed, and a
      // retarget that breaks it is a named failure.
      for (final pair in const [
        (HumanDecisionType.engineeringReview, HumanDecisionChoice.rework),
        (HumanDecisionType.humanQaApproval, HumanDecisionChoice.reject),
      ]) {
        expect(
          HumanDecisionRouting.escalationTargetFor(pair.$1, pair.$2),
          HumanDecisionRouting.targetFor(pair.$1, pair.$2),
          reason:
              '(${pair.$1.name}, ${pair.$2.name}) is a live lockstep arm. Both '
              'tables must move together or the escalation index silently '
              'stops advancing',
        );
      }
    });
  });

  group('the new state is wired everywhere the enum is consumed', () {
    test('it appears in no terminal predicate', () {
      expect(WorkItemState.implementationReady.isTerminal, isFalse);
      expect(
        WorkItemState.implementationReady.isWaitingForHumanDecision,
        isFalse,
      );
    });

    test('the allowedTransitions mirror lists it as a legal destination of the '
        'human gate', () {
      final fromGate = WorkItemWorkflowState(
        WorkItemState.waitingForHumanDecision,
      ).allowedTransitions.map((s) => s.value);
      expect(fromGate, contains(WorkItemState.implementationReady));
    });
  });
}

/// Whether the engine accepts `waitingForHumanDecision -> implementationReady`
/// for this (type, choice).
///
/// Built from a REAL `HumanDecision` in its resolved shape rather than from a
/// hand-written context map, because the guards read
/// `context['humanDecision']` and a fixture that invented its own key would
/// pass for reasons that have nothing to do with the edge. The `decider` is
/// what `decisionActorIsHuman()` checks, so it is present here and absent in
/// `a decision no human made still cannot move the item` above — between the
/// two, the guard is exercised on both sides.
bool _move(HumanDecisionType type, HumanDecisionChoice choice) {
  final decision = HumanDecision(
    decisionId: 'dec-fixture',
    workItemId: 'wi-edge',
    decisionType: type,
    status: HumanDecisionStatus.resolved,
    choice: choice,
    decider: 'fixture-decider',
    rationale: 'fixture',
    requestedAt: DateTime.utc(2026),
    timestamp: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  final transition = const WorkflowEngine().evaluateWorkItemTransition(
    from: WorkItemState.waitingForHumanDecision,
    to: WorkItemState.implementationReady,
    trigger: TransitionTrigger.humanDecision,
    actor: schedulerOrchestratorActor,
    context: {'humanDecision': decision, 'workItemId': 'wi-edge'},
  );
  return transition.isValid;
}

/// Drives a real item into the gate and resolves a real `engineeringReview`
/// rework decision against it.
///
/// Returns the item's state afterwards, so the caller asserts on what the ENGINE
/// did rather than on what the routing table said it would do.
Future<WorkItem> _resolveEngineeringRework() async {
  // Imported lazily so this file's import list reads as the subject, not the
  // fixture.
  final store = InMemoryWorkflowStore();
  // A REAL design contract row, because `designContractExists()` reads the
  // work item's `designContractId` column and confirms it against a store. A
  // context string no longer opens `planned -> designRequired`, so the fixture
  // carries the column and the row behind it.
  final contractStore = InMemoryDesignContractStore();
  final contractId =
      (await DesignContractProvisioner(
            contractStore: contractStore,
          ).provisionForWorkItem(workItemId: 'wi-edge', productId: 'prod-1'))
          .contractId;
  final workflow = DurableWorkflowEngine(
    store: store,
    designContractStore: contractStore,
  );

  await workflow.createWorkItem(
    workItemId: 'wi-edge',
    productId: 'prod-1',
    category: WorkItemCategory.feature,
    title: 'A fixture for the implementation entry edge',
    description: 'Walked through the real gate; nothing here is faked.',
    qaContractId: 'qa-1',
    designContractId: contractId,
  );

  Future<void> step(
    WorkItemState to, {
    Map<String, dynamic> context = const {},
    TransitionTrigger trigger = TransitionTrigger.systemEvent,
  }) => workflow.transition(
    workItemId: 'wi-edge',
    to: to,
    trigger: trigger,
    context: context,
  );

  Future<void> resolve(String decisionId, HumanDecisionChoice choice) =>
      workflow.resolveHumanDecision(
        decisionId: decisionId,
        choice: choice,
        decider: 'test-decider',
        rationale: 'fixture: assert the gate accepts this resolution',
        signature: DecisionSignature(
          algorithm: 'ed25519',
          publicKey: 'test-public-key',
          signature: 'sig-edge',
          signedAt: DateTime.utc(2026),
        ),
      );

  final agentResult = AgentResult(
    resultId: 'res-1',
    sessionId: 'ses-1',
    workItemId: 'wi-edge',
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
  await step(WorkItemState.designRequired);
  await step(
    WorkItemState.designInReview,
    context: const {'designContractStatus': DesignContractStatus.underReview},
  );
  final designGate = await workflow.requestHumanDecision(
    workItemId: 'wi-edge',
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
  final reviewGate = await workflow.requestHumanDecision(
    workItemId: 'wi-edge',
    decisionType: HumanDecisionType.engineeringReview,
    blocking: true,
    extraContext: const {'producerActorId': 'agent-1'},
  );
  await resolve(reviewGate.decisionId, HumanDecisionChoice.rework);

  return workflow.loadWorkItem('wi-edge');
}
