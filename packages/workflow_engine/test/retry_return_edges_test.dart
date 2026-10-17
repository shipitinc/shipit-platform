import 'package:platform_contracts/platform_contracts.dart';
// The wired `JobDefinition`s, READ rather than transcribed, for the same reason
// `transition_consistency_test.dart` reads them: a hand-copied list of entry
// states is a second transcription of another package's configuration, and it
// goes stale silently.
// ignore: depend_on_referenced_packages
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';

/// The RETRY RETURN edges — decision
/// `3659984d-4e2a-4625-81ff-37aa73252375` (option A).
///
/// ## WHAT THESE ARE
///
/// A retryable execution failure leaves the work item outside its lane's
/// `entryStates`, which is what made every scheduled retry unclaimable. These
/// edges are the RETURN: each one puts a failed item back into a state a wired
/// `JobDefinition` already dispatches from.
///
/// ## WHAT THEY MUST NOT BE
///
/// A WIDENING. The one-element entry sets are exactly what make the
/// triage/implementation dispatch collision STRUCTURALLY UNREACHABLE, and
/// option B of the decision — teach the scheduler to honour a retry for an item
/// outside `entryStates` — was rejected for leaving the item in a state no lane
/// dispatches from. So every assertion here is about the TARGET being an
/// existing entry state, never about a set growing.
///
/// ## WHY THE POLICY CAN ASK THIS WITHOUT A LIST
///
/// The scheduler does not name a return target. It asks this table which of its
/// own entry states is reachable from the state the failure left behind, and
/// proceeds only on a UNIQUE answer. That makes the inventory below exact: one
/// reachable entry state per lane, or the return is refused and reported. The
/// "exactly one" property is asserted for every wired definition at the
/// bottom, and it is what makes the DELIBERATE ABSENCES load-bearing.
const _scheduler = WorkflowActor(
  actorId: 'scheduler',
  actorType: ActorType.orchestrator,
);

void main() {
  group('the retry return edges exist and are legal for the orchestrator', () {
    for (final (from, to, lane) in <(WorkItemState, WorkItemState, String)>[
      (WorkItemState.agentFailed, WorkItemState.designNotRequired, 'triage'),
      (
        WorkItemState.agentFailed,
        WorkItemState.implementationReady,
        'implementation',
      ),
      (WorkItemState.agentFailed, WorkItemState.designRequired, 'design'),
      (
        WorkItemState.agentFailed,
        WorkItemState.designInReview,
        'design review',
      ),
      (
        WorkItemState.reviewInProgress,
        WorkItemState.agentCompleted,
        'engineering review',
      ),
    ]) {
      test('$lane: ${from.wire} -> ${to.wire}', () {
        expect(
          WorkItemTransitions.isLegalTransition(from, to),
          isTrue,
          reason: 'the return edge must exist or the retry strands again',
        );
        final result = WorkItemTransitions.validate(
          from,
          to,
          TransitionTrigger.systemEvent,
          _scheduler,
          const {},
        );
        expect(
          result.isValid,
          isTrue,
          reason:
              'and must be TAKEN with an empty context. The scheduler has no '
              'execution of its own and cannot supply an AgentResult, so a '
              'guard this actor cannot satisfy is a guard that makes the edge '
              'unreachable and the retry dead again — which is exactly why '
              '`agentCompleted -> reviewInProgress` carries '
              '`agentResultValid()` and these do not. Guard results were '
              '${result.guardResults.map((g) => '${g.name}=${g.passed}').toList()}',
        );
      });
    }
  });

  group('the guard set follows this table\'s own convention', () {
    for (final (from, to) in <(WorkItemState, WorkItemState)>[
      (WorkItemState.agentFailed, WorkItemState.implementationReady),
      (WorkItemState.agentFailed, WorkItemState.designRequired),
      (WorkItemState.agentFailed, WorkItemState.designInReview),
      (WorkItemState.reviewInProgress, WorkItemState.agentCompleted),
    ]) {
      test('${from.wire} -> ${to.wire} carries actorAllowed alone', () {
        final guards = WorkItemTransitions.getGuards(from, to);
        expect(
          guards,
          hasLength(1),
          reason:
              'the only precedent for an edge into an entry state that asserts '
              'no execution is starting is `planned -> designNotRequired` and '
              '`agentFailed -> designNotRequired`, and both carry exactly '
              '`actorAllowed([orchestrator])`',
        );
        final names = WorkItemTransitions.validate(
          from,
          to,
          TransitionTrigger.systemEvent,
          _scheduler,
          const {},
        ).guardResults.map((g) => g.name).toList();
        expect(names, hasLength(1));
        expect(
          names.single,
          isNot('agentAvailable'),
          reason:
              '`agentAvailable()` belongs only on `-> agentExecuting` edges, '
              'where the transition asserts an agent is starting RIGHT NOW. A '
              'return asserts no such thing, and capacity is '
              '`JobCapacityGuard`\'s job.',
        );
      });
    }

    test('a NON-orchestrator actor is refused every return edge', () {
      for (final (from, to) in <(WorkItemState, WorkItemState)>[
        (WorkItemState.agentFailed, WorkItemState.implementationReady),
        (WorkItemState.agentFailed, WorkItemState.designRequired),
        (WorkItemState.agentFailed, WorkItemState.designInReview),
        (WorkItemState.reviewInProgress, WorkItemState.agentCompleted),
      ]) {
        expect(
          WorkItemTransitions.isLegalTransition(from, to),
          isTrue,
          reason: 'the EDGE exists; this asserts the actor is still checked',
        );
        expect(
          WorkItemTransitions.validate(
            from,
            to,
            TransitionTrigger.systemEvent,
            const WorkflowActor(
              actorId: 'human',
              actorType: ActorType.implementationAgent,
            ),
            const {},
          ).isValid,
          isFalse,
          reason:
              'an implementation agent must not be able to put a work item '
              'back into an entry state on its own authority: ${from.wire} -> '
              '${to.wire}',
        );
      }
    });
  });

  group('NO entryStates set was WIDENED', () {
    test('every wired definition declares exactly its original entry set', () {
      // Read from the live definitions and compared by EXACT SET EQUALITY
      // against the values in base revision `45e6578`. This is the property
      // the whole decision turns on: the fix is a RETURN to an existing entry
      // state, and a widening — even one element wide — would put two
      // schedulers on one work item in the same tick.
      expect(implementFeatureDefinition.entryStates, {
        WorkItemState.implementationReady,
      });
      expect(triageDefectDefinition.entryStates, {
        WorkItemState.designNotRequired,
        WorkItemState.designApproved,
        WorkItemState.reviewRejected,
        // Added after the retry-return decision by lane `impl-PLANNED-ENTRY-HOP`
        // for an unrelated reason: `planned` had no route out of itself at all,
        // so work items parked there were stranded permanently. Recorded in the
        // pin rather than removed from it. The retry property this file guards
        // is untouched and asserted live in the next test — `planned` is not
        // reachable from `agentFailed` and so adds no second return candidate.
        WorkItemState.planned,
      });
      expect(engineeringReviewDefinition.entryStates, {
        WorkItemState.agentCompleted,
      });
      expect(designRevisionDefinition.entryStates, {
        WorkItemState.designRequired,
        WorkItemState.designRejected,
      });
      expect(designReviewDefinition.entryStates, {
        WorkItemState.designInReview,
      });
      expect(defaultImplementFeatureDefinition.entryStates, {
        WorkItemState.designNotRequired,
        WorkItemState.designApproved,
      });
      expect(onboardProductDefinition.entryStates, {
        WorkItemState.designNotRequired,
      });
    });

    test(
      'every return edge lands on a state some definition dispatches from',
      () {
        final wired = <WorkItemState>{
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

        for (final target in const <WorkItemState>[
          WorkItemState.designNotRequired,
          WorkItemState.implementationReady,
          WorkItemState.designRequired,
          WorkItemState.designInReview,
          WorkItemState.agentCompleted,
        ]) {
          expect(
            wired,
            contains(target),
            reason:
                '${target.wire} is a retry-return target, so it must already be an '
                'entry state of a wired definition. If this fails, either an '
                'entry set was WIDENED or an edge was added to a state nothing '
                'runs — and the second is just as bad as the first.',
          );
        }

        // And the state the edge leaves FROM is in NO entry set, which is the
        // defect stated as a fact: that is precisely why the item needed
        // returning.
        expect(wired, isNot(contains(WorkItemState.agentFailed)));
        expect(wired, isNot(contains(WorkItemState.reviewInProgress)));
      },
    );

    test(
      'EXACTLY ONE entry state is reachable per lane, so the return target is '
      'never ambiguous',
      () {
        // The scheduler derives its return target from the POLICY and refuses
        // on anything other than a unique answer. That is what makes the
        // DELIBERATE ABSENCES below load-bearing: adding
        // `agentFailed -> designApproved` would make triage's return ambiguous
        // and silently disable the retry for every lane dispatching from
        // `agentFailed`.
        for (final (definition, failureState)
            in <(JobDefinition, WorkItemState)>[
              (implementFeatureDefinition, WorkItemState.agentFailed),
              (triageDefectDefinition, WorkItemState.agentFailed),
              (defaultImplementFeatureDefinition, WorkItemState.agentFailed),
              (onboardProductDefinition, WorkItemState.agentFailed),
              (designRevisionDefinition, WorkItemState.agentFailed),
              (designReviewDefinition, WorkItemState.agentFailed),
              (engineeringReviewDefinition, WorkItemState.reviewInProgress),
            ]) {
          final reachable = definition.entryStates
              .where(
                (s) => WorkItemTransitions.isLegalTransition(failureState, s),
              )
              .toList();
          expect(
            reachable,
            hasLength(1),
            reason:
                '${definition.jobType.wire} has ${reachable.length} entry '
                'states reachable from ${failureState.wire} '
                '(${reachable.map((s) => s.wire).toList()}). Exactly one is '
                'required: zero strands every retry on this lane and more than '
                'one is refused as ambiguous.',
          );
        }

        // The deliberate absences, named.
        for (final absent in <(WorkItemState, WorkItemState)>[
          (WorkItemState.agentFailed, WorkItemState.designApproved),
          (WorkItemState.agentFailed, WorkItemState.reviewRejected),
          (WorkItemState.agentFailed, WorkItemState.agentCompleted),
          (WorkItemState.agentFailed, WorkItemState.reviewInProgress),
          (WorkItemState.agentFailed, WorkItemState.waitingForHumanDecision),
          // Deliberately NOT listed here:
          // `reviewInProgress -> waitingForHumanDecision`, which is the review
          // lane's ordinary VERDICT route and must stay legal. It is not a
          // return edge and it is not in any entry set, so it cannot make the
          // derived target ambiguous — which is the whole property this list
          // protects.
          (WorkItemState.reviewInProgress, WorkItemState.agentFailed),
        ]) {
          expect(
            WorkItemTransitions.isLegalTransition(absent.$1, absent.$2),
            isFalse,
            reason:
                '${absent.$1.wire} -> ${absent.$2.wire} must stay ILLEGAL. A '
                'second return target from a failure state would make the '
                'scheduler\'s derived target ambiguous and silently switch the '
                'retry off; and a permanent failure must never be given a way '
                'back out of `agentFailed` at all.',
          );
        }
      },
    );
  });

  group('the review return does not approve anything', () {
    test('returning to agentCompleted lands on a ROUTING state, never on a '
        'gate', () {
      // `reviewInProgress -> agentCompleted` is a RETURN to the reviewer, not a
      // verdict. The question that matters is not "can `reviewApproved` be
      // reached somehow" — it can, through `designInReview`'s own design
      // approval gate — but "what does putting an item back at
      // `agentCompleted` DO to it": it re-routes, it never approves.
      //
      // One hop is the whole claim, and one hop is the strongest form of it.
      // Every edge out of `agentCompleted` is asserted, so adding an edge into
      // a human gate fails here by name.
      final out = WorkItemState.values
          .where(
            (to) => WorkItemTransitions.isLegalTransition(
              WorkItemState.agentCompleted,
              to,
            ),
          )
          .where(
            (to) =>
                to != WorkItemState.cancelled && to != WorkItemState.terminated,
          )
          .toSet();

      expect(
        out,
        {
          // `OD-10`'s inflow: a producer that committed nothing goes to
          // implementation. Its OWN discriminator decides which, so a returned
          // review item is judged on its producer's artifact, not on the fact
          // that it was returned.
          WorkItemState.implementationReady,
          // This lane dispatching again — which is the entire point of the edge.
          WorkItemState.reviewInProgress,
          // The design review lane, which dispatches from `designInReview`.
          WorkItemState.designInReview,
        },
        reason:
            'the exact set of one-hop destinations from `agentCompleted`. An '
            'orchestrator that returns a review item can therefore only re-route '
            'it to a lane that runs; it cannot move it to a decision, and it '
            'cannot reach `reviewApproved` or `completed` from here.',
      );

      // And the two approval states are not one hop away, so a return cannot
      // launder unreviewed work through a gate.
      for (final approval in const [
        WorkItemState.reviewApproved,
        WorkItemState.waitingForHumanDecision,
        WorkItemState.qaPassed,
        WorkItemState.completed,
      ]) {
        expect(
          out,
          isNot(contains(approval)),
          reason:
              '${approval.wire} is a gate or an approval outcome, and must not '
              'be one hop from the state a retry returns to',
        );
      }
    });
  });
}
