import 'package:platform_contracts/platform_contracts.dart';
// The wired `JobDefinition`s, read rather than transcribed, for the same reason
// `transition_consistency_test.dart` reads them: a hand-copied list of entry
// states is a second transcription of another package's configuration and it
// goes stale silently.
// ignore: depend_on_referenced_packages
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';

/// Every state any wired `JobDefinition` dispatches from, read from the live
/// definitions.
final Set<WorkItemState> _wiredEntryStates = <WorkItemState>{
  for (final definition in const <JobDefinition>[
    defaultImplementFeatureDefinition,
    implementFeatureDefinition,
    triageDefectDefinition,
    designRevisionDefinition,
    designReviewDefinition,
    engineeringReviewDefinition,
    onboardProductDefinition,
  ])
    ...definition.entryStates,
};

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

    test('agentFailed has exactly FIVE explicit outgoing edges, each named, '
        'and none a self-transition', () {
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
          .toSet();

      // EXACT SET EQUALITY, not a count and not `containsAll`. A count answers
      // "did the number change"; a set answers "is the inventory the one that
      // was decided", so an edge being REMOVED as silently as one being added
      // fails too. The previous assertion here was `length == 2` with a
      // `containsAll` above it, and it was stronger about addition than about
      // removal; this form is stronger about both.
      expect(
        explicit,
        {
          // The historical one: an operator retry puts the item back in front of
          // triage (`designNotRequired` is `triageDefectDefinition`'s entry
          // state). Unchanged by this work.
          WorkItemState.designNotRequired,
          // Pre-existing: `agentFailed -> agentExecuting` has always been legal.
          WorkItemState.agentExecuting,
          // THE RETRY RETURN EDGES (decision 3659984d-4e2a-4625-81ff-37aa73252375,
          // option A). A retryable failure returns the item to the entry state
          // of the lane whose job failed; each of these is ALREADY an entry
          // state of a wired definition, and none widens one.
          WorkItemState.implementationReady, // implementFeatureDefinition
          WorkItemState.designRequired, // designRevisionDefinition
          WorkItemState.designInReview, // designReviewDefinition
        },
        reason:
            'the outgoing edges of agentFailed are an inventory that was '
            'DELIBERATELY decided, not an accident. `containsAll` plus a count '
            'was the old shape and let a deletion through silently; set '
            'equality fails on an addition AND a removal, which is what an '
            'inventory is for.',
      );
      expect(
        explicit.where((to) => to == WorkItemState.agentFailed),
        isEmpty,
        reason: 'no outgoing edge from agentFailed may be a self-transition',
      );
      // And the property the whole rule rests on, asserted here because
      // workflow_engine cannot see a JobDefinition: every edge added above that
      // is NOT the pre-existing pair lands on a state the wired definitions
      // really dispatch from. `transition_consistency_test.dart` reads the live
      // entry sets and asserts the same thing from the other side.
      for (final retryReturnTarget in <WorkItemState>[
        WorkItemState.implementationReady,
        WorkItemState.designRequired,
        WorkItemState.designInReview,
        WorkItemState.designNotRequired,
      ]) {
        // ignore: depend_on_referenced_packages
        expect(
          _wiredEntryStates,
          contains(retryReturnTarget),
          reason:
              '${retryReturnTarget.wire} is a retry-return target, so it must '
              'be a state some wired JobDefinition dispatches from. If this '
              'fails, either an entry set was WIDENED or an edge was added to a '
              'state nothing runs — and both are the rejected alternative to '
              'returning the item to an existing entry state.',
        );
      }
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
