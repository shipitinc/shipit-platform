import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';

/// AC-35 / AC-7 — the operator-retry edge `agentFailed -> designNotRequired`.
///
/// The failure mode this file exists to prevent is an edge that is ASSERTED to
/// work. Three successive specifications of a scheduler dispatch seam were
/// invisible to the negative tests assigned to them, two of them because a
/// self-transition `(agentExecuting, agentExecuting)` is absent from
/// `_legalTransitions` while `_isGenericEscape` returns false for `to == from`,
/// which made an always-false branch look like a passing one. So every claim
/// here is made against the real engine, and the negative control comes FIRST
/// in intent: if `(agentExecuting, agentExecuting)` ever becomes legal again,
/// the suite fails loudly instead of silently accepting a broken retry.
void main() {
  /// The actor the retry path uses. `ActorType.orchestrator` is the only type
  /// the edge permits; the human is recorded as data on the audit row instead.
  const operatorRetry = WorkflowActor(
    actorId: 'operator-retry',
    actorType: ActorType.orchestrator,
  );

  group('AC-35 agentFailed -> designNotRequired is legal through the engine', () {
    test('validate() accepts the edge for the operator actor', () {
      final result = WorkItemTransitions.validate(
        WorkItemState.agentFailed,
        WorkItemState.designNotRequired,
        TransitionTrigger.systemEvent,
        operatorRetry,
        const {},
      );

      expect(
        result.isValid,
        isTrue,
        reason:
            'the retry edge must be legal; guard results were '
            '${result.guardResults.map((g) => '${g.name}=${g.passed}').toList()}',
      );
      expect(result.rejectionReason, isNull);
    });

    test('NEGATIVE CONTROL: (agentExecuting, agentExecuting) is ILLEGAL', () {
      final result = WorkItemTransitions.validate(
        WorkItemState.agentExecuting,
        WorkItemState.agentExecuting,
        TransitionTrigger.systemEvent,
        operatorRetry,
        const {},
      );

      expect(
        result.isValid,
        isFalse,
        reason:
            'a self-transition is absent from _legalTransitions and '
            '_isGenericEscape returns false when to == from. If this ever '
            'passes, the 1.2.0 always-false-branch defect can return '
            'undetected.',
      );
      expect(
        result.guardResults.map((g) => g.name),
        contains('legal_transition'),
      );
    });

    test('isLegalTransition agrees with validate for both edges', () {
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.agentFailed,
          WorkItemState.designNotRequired,
        ),
        isTrue,
      );
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.agentExecuting,
          WorkItemState.agentExecuting,
        ),
        isFalse,
      );
    });

    test('agentFailed has exactly TWO explicit outgoing edges, neither a '
        'self-transition', () {
      // Enumerated from the PUBLIC API rather than by reading the private
      // map: every state the table considers legal from `agentFailed`, minus
      // the two generic escapes (`cancelled`, `terminated`), which every
      // non-terminal state gets from `_isGenericEscape` and which are not
      // edges into a runnable entry state.
      const genericEscapeTargets = {
        WorkItemState.cancelled,
        WorkItemState.terminated,
      };

      final explicit = WorkItemState.values
          .where(
            (to) => WorkItemTransitions.isLegalTransition(
              WorkItemState.agentFailed,
              to,
            ),
          )
          .where((to) => !genericEscapeTargets.contains(to))
          .toList();

      expect(
        explicit,
        containsAll(<WorkItemState>[
          WorkItemState.agentExecuting,
          WorkItemState.designNotRequired,
        ]),
      );
      expect(
        explicit.where((to) => to == WorkItemState.agentFailed),
        isEmpty,
        reason: 'no outgoing edge from agentFailed may be a self-transition',
      );
      expect(
        explicit.length,
        2,
        reason: 'agentFailed must gain exactly ONE new edge, not more',
      );
    });

    test('the retry target is a triage entry state', () {
      // The reason this edge is dispatched at all. `triageDefectDefinition`
      // lives in the scheduler, which this package must not depend on, so the
      // state the edge targets is asserted directly and the entry-state fact
      // is asserted in packages/scheduler against the real definition.
      expect(
        WorkItemState.designNotRequired,
        isNot(WorkItemState.agentExecuting),
        reason:
            'landing in agentExecuting asserts an execution is ALREADY '
            'RUNNING, which is why three dispatch seams failed',
      );
    });
  });

  group('AC-7 the guard set matches the table convention for this target', () {
    test('exactly one guard: actorAllowed, and NOT agentAvailable', () {
      final guards = WorkItemTransitions.getGuards(
        WorkItemState.agentFailed,
        WorkItemState.designNotRequired,
      );

      expect(guards, hasLength(1));
      // The only other edge into designNotRequired is
      // `planned -> designNotRequired`, which carries
      // actorAllowed([orchestrator]) and nothing else. Two guards here would
      // mean an evidence requirement nobody asked for; agentAvailable()
      // would assert an agent is starting NOW, which this edge does not claim.
      final result = WorkItemTransitions.validate(
        WorkItemState.agentFailed,
        WorkItemState.designNotRequired,
        TransitionTrigger.systemEvent,
        operatorRetry,
        const {},
      );
      final names = result.guardResults.map((g) => g.name).toList();
      expect(names, hasLength(1));
      expect(names.single, isNot(contains('agent')));
      expect(names.single, isNot('agentAvailable'));
    });

    test('the same convention holds on planned -> designNotRequired, the only '
        'precedent for this target', () {
      final precedent = WorkItemTransitions.validate(
        WorkItemState.planned,
        WorkItemState.designNotRequired,
        TransitionTrigger.systemEvent,
        operatorRetry,
        const {},
      );
      final retry = WorkItemTransitions.validate(
        WorkItemState.agentFailed,
        WorkItemState.designNotRequired,
        TransitionTrigger.systemEvent,
        operatorRetry,
        const {},
      );

      expect(
        retry.guardResults.map((g) => g.name).toList(),
        precedent.guardResults.map((g) => g.name).toList(),
      );
    });

    test('a NON-orchestrator actor is refused', () {
      final result = WorkItemTransitions.validate(
        WorkItemState.agentFailed,
        WorkItemState.designNotRequired,
        TransitionTrigger.systemEvent,
        const WorkflowActor(
          actorId: 'human',
          actorType: ActorType.implementationAgent,
        ),
        const {},
      );
      expect(result.isValid, isFalse);
    });
  });

  group('AC-19b a failed item is never re-dispatched without the edge', () {
    test('agentExecuting remains the only agent target reachable from '
        'agentFailed, so nothing else re-arms a failed item', () {
      // The retry is legal ONLY because the new edge exists. A fabricated
      // state string cannot get an item out of `agentFailed` into a runnable
      // entry state, because runnability is answered by the same table.
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.agentFailed,
          WorkItemState.waitingForHumanDecision,
        ),
        isFalse,
        reason:
            'escalation from agentFailed still does not exist, before '
            'or after this change',
      );
      expect(
        WorkItemTransitions.isLegalTransition(
          WorkItemState.agentFailed,
          WorkItemState.reviewInProgress,
        ),
        isFalse,
      );
    });
  });
}
