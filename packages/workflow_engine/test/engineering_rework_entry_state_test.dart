import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';

/// REWORK-ENTRY-STATE — engineering-review rework must land on a DISPATCHABLE
/// entry state, not on `agentExecuting`.
///
/// ## The defect
///
/// Live QA, work item `defect-DEF-1791684804452198`, 2026-10-12:
///
/// ```
/// 16:43:11  waiting_for_human_decision -> agent_executing  (humanDecision)
/// now       state = agent_executing, no job enqueued, nothing will ever run
/// ```
///
/// `agentExecuting` is in the `entryStates` of NO wired `JobDefinition`. Every
/// definition lists either `{designNotRequired, designApproved}`,
/// `{designRequired, designRejected}`, `{designInReview}` or `{agentCompleted}`.
/// So an item parked at `agentExecuting` cannot be dispatched again, and it also
/// asserts something untrue — that an execution is ALREADY RUNNING. It is the
/// same class of defect as `be75ba1` (`agentFailed` reachable but with no work
/// to start), reached here through a human decision instead.
///
/// `designNotRequired` IS in `triageDefectDefinition.entryStates`, which is the
/// mechanism the operator retry already relies on. That is the target.
///
/// ## What this file does NOT claim
///
/// The `rework` half of the fix is NOT complete on this branch. The target of a
/// resolved decision is chosen by `HumanDecisionRouting.targetFor`, which is not
/// owned by this lane, and it still maps `(engineeringReview, rework) ->
/// agentExecuting`. The edge this file pins is the guarded LANDING half; a test
/// that called `HumanDecisionRouting.targetFor(engineeringReview, rework)` and
/// asserted `designNotRequired` would be asserting a change that was not made.
/// The routing half is asserted below in its CURRENT state so the gap is pinned
/// visibly rather than silently.
const _workItemId = '123e4567-e89b-12d3-a456-426614174001';

const _orch = WorkflowActor(
  actorId: 'orch-1',
  actorType: ActorType.orchestrator,
);

HumanDecision _pendingDecision({
  required HumanDecisionType type,
  String workItemId = _workItemId,
}) => HumanDecision(
  decisionId: 'dec-pending-1',
  workItemId: workItemId,
  decisionType: type,
  status: HumanDecisionStatus.pending,
  question: 'Approve?',
  requestedAt: DateTime.parse('2024-01-01T10:00:00Z'),
  updatedAt: DateTime.parse('2024-01-01T10:00:00Z'),
);

HumanDecision _resolvedDecision({
  required HumanDecisionType type,
  required HumanDecisionChoice choice,
  String workItemId = _workItemId,
  String? decider = 'alice@example.com',
}) {
  final at = DateTime.parse('2024-01-02T12:00:00Z');
  return HumanDecision(
    decisionId: 'dec-resolved-1',
    workItemId: workItemId,
    decisionType: type,
    status: HumanDecisionStatus.resolved,
    question: 'Approve?',
    decider: decider,
    choice: choice,
    rationale: 'because',
    timestamp: at,
    signature: DecisionSignature(
      algorithm: 'Ed25519',
      publicKey: 'key',
      signature: 'sig',
      signedAt: at,
    ),
    context: DecisionContext(
      workflowState: 'waiting_for_human_decision',
      availableOptions: const [],
    ),
    requestedAt: DateTime.parse('2024-01-01T10:00:00Z'),
    updatedAt: at,
  );
}

/// The context `DurableWorkflowEngine.resolveHumanDecision` actually builds:
/// the resolved decision, the work item it is attached to, and the escalation
/// pair. `_getMaxEscalationForDecisionType` returns -1, which reads as
/// "unlimited", so the escalation guard passes — same as production.
Map<String, dynamic> _gateContext(HumanDecision decision) => {
  'workItemId': _workItemId,
  'humanDecision': decision,
  'escalationIndex': 0,
  'maxEscalation': -1,
};

void main() {
  group('engineering-review rework lands on the dispatchable entry state', () {
    for (final choice in [
      HumanDecisionChoice.rework,
      HumanDecisionChoice.reject,
    ]) {
      test('(engineeringReview, $choice) -> designNotRequired is legal', () {
        final result = WorkItemTransitions.validate(
          WorkItemState.waitingForHumanDecision,
          WorkItemState.designNotRequired,
          TransitionTrigger.humanDecision,
          _orch,
          _gateContext(
            _resolvedDecision(
              type: HumanDecisionType.engineeringReview,
              choice: choice,
            ),
          ),
        );

        expect(
          result.isValid,
          isTrue,
          reason:
              'the rework edge must be legal; guards were '
              '${result.guardResults.map((g) => '${g.name}=${g.passed}').toList()}',
        );
        expect(result.rejectionReason, isNull);
      });
    }

    test('the target is a triage entry state, not agentExecuting', () {
      // The whole point of the edge. `agentExecuting` is in no JobDefinition's
      // entryStates; `designNotRequired` is in triageDefect's, and is the state
      // the proven operator-retry path (be75ba1) returns to.
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.waitingForHumanDecision,
          WorkItemState.designNotRequired,
        ),
        isTrue,
      );
    });
  });

  group('the rework edge is refused when the decision is unresolved', () {
    test('a PENDING engineering review cannot take the edge', () {
      final result = WorkItemTransitions.validate(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.designNotRequired,
        TransitionTrigger.humanDecision,
        _orch,
        _gateContext(
          _pendingDecision(type: HumanDecisionType.engineeringReview),
        ),
      );

      expect(result.isValid, isFalse);
      expect(result.failedGuards, contains('blocking_human_decision_resolved'));
    });

    test('no decision at all cannot take the edge', () {
      final result = WorkItemTransitions.validate(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.designNotRequired,
        TransitionTrigger.humanDecision,
        _orch,
        const {'workItemId': _workItemId},
      );

      expect(result.isValid, isFalse);
      expect(result.failedGuards, contains('blocking_human_decision_resolved'));
    });

    test('a resolved engineering review APPROVAL cannot take the edge', () {
      final result = WorkItemTransitions.validate(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.designNotRequired,
        TransitionTrigger.humanDecision,
        _orch,
        _gateContext(
          _resolvedDecision(
            type: HumanDecisionType.engineeringReview,
            choice: HumanDecisionChoice.approve,
          ),
        ),
      );

      expect(
        result.isValid,
        isFalse,
        reason: 'approve unlocks reviewApproved, never a rework',
      );
    });

    test("another gate's resolution cannot take the edge", () {
      // The edge is scoped to engineering review on purpose; a QA rejection is
      // routed by its own table entry and must not inherit this target.
      final result = WorkItemTransitions.validate(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.designNotRequired,
        TransitionTrigger.humanDecision,
        _orch,
        _gateContext(
          _resolvedDecision(
            type: HumanDecisionType.humanQaApproval,
            choice: HumanDecisionChoice.reject,
          ),
        ),
      );

      expect(result.isValid, isFalse);
      expect(result.failedGuards, contains('blocking_human_decision_resolved'));
    });

    test('an unsigned decision cannot take the edge', () {
      final result = WorkItemTransitions.validate(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.designNotRequired,
        TransitionTrigger.humanDecision,
        _orch,
        _gateContext(
          _resolvedDecision(
            type: HumanDecisionType.engineeringReview,
            choice: HumanDecisionChoice.rework,
            decider: null,
          ),
        ),
      );

      expect(
        result.isValid,
        isFalse,
        reason: 'decisionActorIsHuman must not be traded away for a target',
      );
      expect(result.failedGuards, contains('decision_actor_is_human'));
    });
  });

  group('the rework edge is refused for a non-orchestrator actor', () {
    for (final actor in const [
      WorkflowActor(
        actorId: 'agent-1',
        actorType: ActorType.implementationAgent,
      ),
      WorkflowActor(actorId: 'rev-1', actorType: ActorType.engineeringReviewer),
      WorkflowActor(actorId: 'qa-1', actorType: ActorType.qaExecutor),
      WorkflowActor(actorId: 'sys-1', actorType: ActorType.system),
    ]) {
      test('${actor.actorType.name} is refused', () {
        final result = WorkItemTransitions.validate(
          WorkItemState.waitingForHumanDecision,
          WorkItemState.designNotRequired,
          TransitionTrigger.humanDecision,
          actor,
          _gateContext(
            _resolvedDecision(
              type: HumanDecisionType.engineeringReview,
              choice: HumanDecisionChoice.rework,
            ),
          ),
        );

        expect(result.isValid, isFalse);
        expect(result.failedGuards, contains('actor_allowed'));
      });
    }
  });

  group('every guard the old generic edge carried is still present', () {
    test('guard names are exactly the expected four, in order', () {
      final result = WorkItemTransitions.validate(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.designNotRequired,
        TransitionTrigger.humanDecision,
        _orch,
        _gateContext(
          _resolvedDecision(
            type: HumanDecisionType.engineeringReview,
            choice: HumanDecisionChoice.rework,
          ),
        ),
      );

      expect(result.guardResults.map((g) => g.name).toList(), [
        'actor_allowed',
        'blocking_human_decision_resolved',
        'decision_actor_is_human',
        'escalation_index_within_limit',
      ]);
    });

    test('the escalation bound still refuses an exhausted rework loop', () {
      // Proves the guard is LIVE and not merely listed: the same decision with
      // an index already past the limit is refused. Every traversal of the
      // designNotRequired -> ... -> designNotRequired cycle increments it, so a
      // bounded human can still be stopped rather than looping for ever.
      final decision = _resolvedDecision(
        type: HumanDecisionType.engineeringReview,
        choice: HumanDecisionChoice.rework,
      );
      final result = WorkItemTransitions.validate(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.designNotRequired,
        TransitionTrigger.humanDecision,
        _orch,
        {
          'workItemId': _workItemId,
          'humanDecision': decision,
          'escalationIndex': 3,
          'maxEscalation': 3,
        },
      );

      expect(result.isValid, isFalse);
      expect(result.failedGuards, contains('escalation_index_within_limit'));
    });

    test('agentAvailable is NOT required — no agent is starting NOW', () {
      final result = WorkItemTransitions.validate(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.designNotRequired,
        TransitionTrigger.humanDecision,
        _orch,
        _gateContext(
          _resolvedDecision(
            type: HumanDecisionType.engineeringReview,
            choice: HumanDecisionChoice.rework,
          ),
        ),
      );

      expect(
        result.guardResults.map((g) => g.name),
        isNot(contains('agent_available')),
      );
    });
  });

  group('the ordinary dispatch path is UNCHANGED', () {
    test('designNotRequired -> agentExecuting still reaches execution', () {
      final result = WorkItemTransitions.validate(
        WorkItemState.designNotRequired,
        WorkItemState.agentExecuting,
        TransitionTrigger.systemEvent,
        _orch,
        const {'agentAvailable': true, 'capabilitiesMatch': true},
      );

      expect(result.isValid, isTrue);
      expect(result.rejectionReason, isNull);
    });

    test('agentCompleted -> reviewInProgress still starts a review', () {
      final result = WorkItemTransitions.validate(
        WorkItemState.agentCompleted,
        WorkItemState.reviewInProgress,
        TransitionTrigger.agentResult,
        _orch,
        {'agentResult': _completedResult()},
      );

      expect(result.isValid, isTrue);
    });

    test('a mid-execution item is NOT diverted to designNotRequired', () {
      // An item that is genuinely mid-execution must still be able to reach
      // agentExecuting; this change is about where a REWORK lands, not about
      // removing the execution target.
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.designNotRequired,
          WorkItemState.agentExecuting,
        ),
        isTrue,
      );
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.designApproved,
          WorkItemState.agentExecuting,
        ),
        isTrue,
      );
    });
  });

  group('reviewRejected is retargeted the same way', () {
    test('reviewRejected -> designNotRequired is legal', () {
      final result = WorkItemTransitions.validate(
        WorkItemState.reviewRejected,
        WorkItemState.designNotRequired,
        TransitionTrigger.systemEvent,
        _orch,
        const {},
      );

      expect(
        result.isValid,
        isTrue,
        reason:
            'guards were '
            '${result.guardResults.map((g) => '${g.name}=${g.passed}').toList()}',
      );
    });

    test('reviewRejected -> agentExecuting is now ILLEGAL', () {
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.reviewRejected,
          WorkItemState.agentExecuting,
        ),
        isFalse,
        reason:
            'this was the second stranding edge. Observed live: '
            '(engineeringReview, reject) routes to reviewRejected, and from '
            'there agentExecuting is in no JobDefinition entryStates.',
      );
    });

    test('the single original guard is preserved verbatim', () {
      final result = WorkItemTransitions.validate(
        WorkItemState.reviewRejected,
        WorkItemState.designNotRequired,
        TransitionTrigger.systemEvent,
        _orch,
        const {},
      );

      expect(result.guardResults.map((g) => g.name).toList(), [
        'actor_allowed',
      ]);
    });

    test('a non-orchestrator actor is still refused', () {
      final result = WorkItemTransitions.validate(
        WorkItemState.reviewRejected,
        WorkItemState.designNotRequired,
        TransitionTrigger.systemEvent,
        const WorkflowActor(
          actorId: 'human',
          actorType: ActorType.implementationAgent,
        ),
        const {},
      );

      expect(result.isValid, isFalse);
      expect(result.failedGuards, contains('actor_allowed'));
    });

    test('the reject half of the chain is fully fixed in this lane', () {
      // waitingForHumanDecision -> reviewRejected (engineeringReview/reject),
      // then reviewRejected -> designNotRequired. Every edge here is owned by
      // this lane, which is why the reject half lands while the rework half is
      // reported as a blocker.
      final toRejected = WorkItemTransitions.validate(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.reviewRejected,
        TransitionTrigger.humanDecision,
        _orch,
        _gateContext(
          _resolvedDecision(
            type: HumanDecisionType.engineeringReview,
            choice: HumanDecisionChoice.reject,
          ),
        ),
      );
      expect(toRejected.isValid, isTrue);

      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.reviewRejected,
          WorkItemState.designNotRequired,
        ),
        isTrue,
      );
    });
  });

  group(
    'the GENERIC agentExecuting edge is left load-bearing for other lanes',
    () {
      test('qaRework/reject still routes to agentExecuting', () {
        final result = WorkItemTransitions.validate(
          WorkItemState.waitingForHumanDecision,
          WorkItemState.agentExecuting,
          TransitionTrigger.humanDecision,
          _orch,
          _gateContext(
            _resolvedDecision(
              type: HumanDecisionType.qaRework,
              choice: HumanDecisionChoice.reject,
            ),
          ),
        );

        expect(
          result.isValid,
          isTrue,
          reason:
              'retargeting the generic edge wholesale would have silently moved '
              'QA rejection off its own route — that is why a narrower edge was '
              'added instead',
        );
      });

      test('humanQaApproval/reject still routes to agentExecuting', () {
        final result = WorkItemTransitions.validate(
          WorkItemState.waitingForHumanDecision,
          WorkItemState.agentExecuting,
          TransitionTrigger.humanDecision,
          _orch,
          _gateContext(
            _resolvedDecision(
              type: HumanDecisionType.humanQaApproval,
              choice: HumanDecisionChoice.reject,
            ),
          ),
        );

        expect(result.isValid, isTrue);
      });

      test('escalation/approve still resumes into agentExecuting', () {
        final result = WorkItemTransitions.validate(
          WorkItemState.waitingForHumanDecision,
          WorkItemState.agentExecuting,
          TransitionTrigger.humanDecision,
          _orch,
          _gateContext(
            _resolvedDecision(
              type: HumanDecisionType.escalation,
              choice: HumanDecisionChoice.approve,
            ),
          ),
        );

        expect(result.isValid, isTrue);
      });

      test('the generic edge kept its exact guard membership', () {
        final names = WorkItemTransitions.getGuards(
          WorkItemState.waitingForHumanDecision,
          WorkItemState.agentExecuting,
        ).map((g) => g.name).toList();

        expect(names, [
          'actor_allowed',
          'blocking_human_decision_resolved',
          'decision_actor_is_human',
          'escalation_index_within_limit',
        ]);
      });
    },
  );

  group('PINNED GAP — the rework half still needs the routing table', () {
    test(
      'HumanDecisionRouting still sends (engineeringReview, rework) to '
      'agentExecuting, so production rework is NOT yet fixed by this branch',
      () {
        // This is the blocker, asserted so it cannot be forgotten. It FAILS the
        // moment `human_decision_routing.dart` is changed to designNotRequired
        // — at which point this expectation is inverted and the comment in
        // work_item_transitions.dart updated.
        expect(
          HumanDecisionRouting.targetFor(
            HumanDecisionType.engineeringReview,
            HumanDecisionChoice.rework,
          ),
          WorkItemState.agentExecuting,
          reason:
              'resolveHumanDecision derives its target from this table and '
              'takes no caller-supplied state, so no edit to the transition '
              'table can redirect a resolved rework. The edge this lane added '
              'is the landing half only.',
        );
      },
    );

    test(
      'the reject half needs no routing change and is already dispatchable',
      () {
        expect(
          HumanDecisionRouting.targetFor(
            HumanDecisionType.engineeringReview,
            HumanDecisionChoice.reject,
          ),
          WorkItemState.reviewRejected,
        );
        expect(
          WorkItemTransitions.isLegalTransition(
            WorkItemState.reviewRejected,
            WorkItemState.designNotRequired,
          ),
          isTrue,
        );
      },
    );
  });
}

/// A minimal valid agent result for the `agentCompleted -> reviewInProgress`
/// dispatch-path check.
AgentResult _completedResult() => AgentResult(
  resultId: 'res-1',
  sessionId: 'ses-1',
  workItemId: _workItemId,
  status: AgentResultStatus.completed,
  artifacts: const [],
  diagnostics: AgentDiagnostics(
    exitCode: 0,
    durationMs: 100,
    toolCalls: 1,
    errors: const [],
    warnings: const [],
  ),
  structuredResult: const {},
  completedAt: DateTime.parse('2024-01-01T09:30:00Z'),
);
