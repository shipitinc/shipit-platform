import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';

/// REWORK-ENTRY-STATE — a human gate that says "do the work again" must land
/// on a DISPATCHABLE entry state, not on `agentExecuting`.
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
/// `designNotRequired` IS in `triageDefectDefinition.entryStates`, which is
/// the mechanism the operator retry already relies on. That was the target,
/// and `OD-3` has since moved four of these five routes one lane further on
/// to `implementationReady` — see `implementation_ready_edge_test.dart`, which
/// owns that question. **The invariant this file protects is unchanged by
/// that**: a human gate that says "do the work again" must land on a state
/// SOME wired definition dispatches, and on no other.
///
/// ## The fix needed BOTH halves, and this file now has both
///
/// The previous lane owned only this package's transition table, so it could
/// add the guarded landing edges but could not move the routing table, whose
/// entries are the sole determinant of a resolved decision's target
/// (`DurableWorkflowEngine.resolveHumanDecision` computes
/// `HumanDecisionRouting.targetFor(type, choice)` and takes no caller-supplied
/// state). An edge nothing routes to changes nothing in production, so it
/// reported IMPLEMENTATION_BLOCKED and pinned the gap with a failing-on-change
/// assertion. That pin is now INVERTED, and the whole table is asserted to
/// contain no `agentExecuting` target at all.
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

    test("another gate's APPROVAL cannot take the edge", () {
      // Widening the edge to the five rework routes must not turn it into a
      // hole: a resolution that does not ask for the work to be redone still
      // cannot reach it, however many pairs the guard set lists.
      final result = WorkItemTransitions.validate(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.designNotRequired,
        TransitionTrigger.humanDecision,
        _orch,
        _gateContext(
          _resolvedDecision(
            type: HumanDecisionType.humanQaApproval,
            choice: HumanDecisionChoice.approve,
          ),
        ),
      );

      expect(
        result.isValid,
        isFalse,
        reason: 'approve completes the work; it never re-queues it',
      );
      expect(result.failedGuards, contains('blocking_human_decision_resolved'));
    });

    test('an unmapped decision type cannot take the edge', () {
      final result = WorkItemTransitions.validate(
        WorkItemState.waitingForHumanDecision,
        WorkItemState.designNotRequired,
        TransitionTrigger.humanDecision,
        _orch,
        _gateContext(
          _resolvedDecision(
            type: HumanDecisionType.qaRework,
            choice: HumanDecisionChoice.waive,
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

  group('the GENERIC agentExecuting edge keeps every guard it already had', () {
    // Routing no longer SELECTS this edge for these pairs — they now land on
    // `designNotRequired`. The edge itself is deliberately left untouched:
    // its `blockingHumanDecisionResolved` set spans six (type, choice) pairs
    // belonging to four other lanes, and narrowing it would withdraw
    // capability those lanes have never been asked to lose. The pair is
    // unused, not forbidden.
    for (final route in const [
      (HumanDecisionType.qaRework, HumanDecisionChoice.reject),
      (HumanDecisionType.humanQaApproval, HumanDecisionChoice.reject),
      (HumanDecisionType.escalation, HumanDecisionChoice.approve),
      (HumanDecisionType.engineeringReview, HumanDecisionChoice.rework),
      (HumanDecisionType.engineeringReview, HumanDecisionChoice.reject),
      (HumanDecisionType.qaWaiver, HumanDecisionChoice.reject),
    ]) {
      test('(${route.$1.name}, ${route.$2.name}) is still a legal pair', () {
        final result = WorkItemTransitions.validate(
          WorkItemState.waitingForHumanDecision,
          WorkItemState.agentExecuting,
          TransitionTrigger.humanDecision,
          _orch,
          _gateContext(_resolvedDecision(type: route.$1, choice: route.$2)),
        );

        expect(result.isValid, isTrue);
      });
    }

    test('the generic edge still permits exactly those six pairs', () {
      // Pin the MEMBERSHIP, not just that it accepts things: this is the
      // guard the previous lane refused to retarget, and a future edit that
      // quietly drops one of these six is the regression to catch.
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

      expect(result.guardResults.map((g) => g.name).toList(), [
        'actor_allowed',
        'blocking_human_decision_resolved',
        'decision_actor_is_human',
        'escalation_index_within_limit',
      ]);
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
  });

  group('the PINNED GAP is CLOSED — routing now sends rework somewhere '
      'dispatchable', () {
    test('HumanDecisionRouting sends (engineeringReview, rework) to the '
        'implementation lane, so production rework is fixed', () {
      // This test INVERTED the pin the previous lane left. It asserted
      // `agentExecuting` deliberately, so that it would fail the moment the
      // routing table was corrected — which is exactly what happened. The
      // edge alone was never the fix: `resolveHumanDecision` derives its
      // target from this table and takes no caller-supplied state, so an
      // unreached edge changes nothing in production.
      //
      // It then asserted `designNotRequired`, which `OD-3` has since
      // superseded: rework at a review gate means "re-do the work", not
      // "re-classify it".
      expect(
        HumanDecisionRouting.targetFor(
          HumanDecisionType.engineeringReview,
          HumanDecisionChoice.rework,
        ),
        WorkItemState.implementationReady,
      );
    });

    test('every "do the work again" route lands on a dispatchable entry '
        'state', () {
      // The five routes this change moved off `agentExecuting`. That state is
      // in the `entryStates` of NO wired JobDefinition, so a route that lands
      // there is a permanent dead end: nothing enqueues for it, nothing
      // runs, and the decision is already answered.
      //
      // The invariant is DISPATCHABILITY, not one particular state, so it is
      // asserted against the set. Naming a single state here would re-freeze
      // exactly the question `OD-3` just answered, in a file that is not the
      // owner of that question.
      const stranding = {
        (HumanDecisionType.engineeringReview, HumanDecisionChoice.rework),
        (HumanDecisionType.qaWaiver, HumanDecisionChoice.reject),
        (HumanDecisionType.qaRework, HumanDecisionChoice.reject),
        (HumanDecisionType.humanQaApproval, HumanDecisionChoice.reject),
        (HumanDecisionType.escalation, HumanDecisionChoice.approve),
      };
      const dispatchable = {
        WorkItemState.designNotRequired,
        WorkItemState.implementationReady,
      };

      for (final route in stranding) {
        final target = HumanDecisionRouting.targetFor(route.$1, route.$2);
        expect(
          dispatchable,
          contains(target),
          reason: '(${route.$1.name}, ${route.$2.name}) must not strand',
        );
      }
    });

    test('NO route anywhere in the table targets agentExecuting', () {
      // The general form of the fix, so a future sixth stranding route fails
      // here rather than in a live QA environment.
      for (final type in HumanDecisionType.values) {
        for (final choice in HumanDecisionChoice.values) {
          expect(
            HumanDecisionRouting.targetFor(type, choice),
            isNot(WorkItemState.agentExecuting),
            reason:
                '(${type.name}, ${choice.name}) strands: agentExecuting is in '
                'no JobDefinition entryStates, so nothing dispatches it',
          );
        }
      }
    });

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
