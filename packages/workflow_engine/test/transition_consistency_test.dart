import 'package:platform_contracts/platform_contracts.dart';
// The wired `JobDefinition`s, read rather than transcribed. See the comment on
// `the landing state is one the scheduler can dispatch` for why a hand-copied
// list of entry states is a defect waiting to happen.
// ignore: depend_on_referenced_packages
import 'package:scheduler/scheduler.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';

/// `WorkItemWorkflowState.allowedTransitions` must equal the accepted-pair
/// table, and the table must never accept a pair that strands an item.
///
/// ## Why this exists
///
/// Two separate facts drifted apart before this test did.
///
/// `allowedTransitions` is a per-state literal list that duplicated
/// `WorkItemTransitions._legalTransitions` by hand. It had fallen behind: it
/// still advertised `reviewRejected -> agentExecuting`, an edge deleted
/// because it strands the item, and it omitted
/// `agentFailed -> designNotRequired`, `waitingForHumanDecision ->
/// designNotRequired` and `waitingForHumanDecision -> planning`.
///
/// It is corrected now, but a hand-maintained mirror of a hand-maintained
/// table cannot be trusted to stay corrected — so this test derives the truth
/// from the table and compares. `allowedTransitions` itself is still never
/// consulted at runtime (`canTransitionTo` has zero callers and
/// `TransitionValidator` reads only the table), which is exactly why it needs
/// a mechanical guard: nothing else would ever notice it rotting.
///
/// ## The stranding invariant
///
/// The second half is the one that matters in production. `agentExecuting` is
/// in the `entryStates` of NO wired `JobDefinition`, so any accepted edge INTO
/// it that a resolved human decision can take is a permanent dead end — the
/// work sits at its gate with the decision answered and nothing will ever run.
/// That is the defect observed live on `defect-DEF-1791684804452198`.
void main() {
  /// Every pair the engine accepts, read from the table itself rather than
  /// from a list maintained alongside it.
  Set<(WorkItemState, WorkItemState)> acceptedPairs() {
    final pairs = <(WorkItemState, WorkItemState)>{};
    for (final from in WorkItemState.values) {
      for (final to in WorkItemState.values) {
        if (WorkItemTransitions.isLegalTransition(from, to)) {
          pairs.add((from, to));
        }
      }
    }
    return pairs;
  }

  group('allowedTransitions mirrors the accepted-pair table', () {
    test('the two agree for every state', () {
      final mismatches = <String>[];

      for (final from in WorkItemState.values) {
        final fromTable = acceptedPairs()
            .where((p) => p.$1 == from)
            .map((p) => p.$2)
            .toSet();
        final fromList = WorkItemWorkflowState(
          from,
        ).allowedTransitions.map((s) => s.value).toSet();

        final onlyInTable = fromTable.difference(fromList);
        final onlyInList = fromList.difference(fromTable);
        if (onlyInTable.isNotEmpty || onlyInList.isNotEmpty) {
          mismatches.add(
            '${from.wire}: missing from allowedTransitions '
            '${onlyInTable.map((s) => s.wire).toList()}, '
            'absent from the table ${onlyInList.map((s) => s.wire).toList()}',
          );
        }
      }

      expect(
        mismatches,
        isEmpty,
        reason:
            'allowedTransitions is a hand-written mirror of the transition '
            'table and must not drift from it: $mismatches',
      );
    });

    test('the mirror is not trivially empty', () {
      // A guard that enumerates nothing passes. Pin the shape of the answer.
      expect(acceptedPairs().length, greaterThan(40));
      expect(
        WorkItemWorkflowState.waitingForHumanDecision.allowedTransitions.length,
        greaterThan(5),
      );
    });
  });

  group('no human decision can strand an item', () {
    test('no route targets agentExecuting', () {
      final stranding = <String>[];
      for (final type in HumanDecisionType.values) {
        for (final choice in HumanDecisionChoice.values) {
          final target = HumanDecisionRouting.targetFor(type, choice);
          if (target == WorkItemState.agentExecuting) {
            stranding.add('(${type.name}, ${choice.name}) -> agentExecuting');
          }
        }
      }

      expect(
        stranding,
        isEmpty,
        reason:
            'agentExecuting is in no JobDefinition entryStates, so each of '
            'these leaves the item with nothing to run: $stranding',
      );
    });

    test('every non-null route has a legal edge from the gate', () {
      // A route to a state with no legal edge from `waitingForHumanDecision`
      // strands the item just as surely as a non-dispatchable target: the
      // engine would throw on resolution and the item never moves.
      final unreachable = <String>[];
      for (final type in HumanDecisionType.values) {
        for (final choice in HumanDecisionChoice.values) {
          final target = HumanDecisionRouting.targetFor(type, choice);
          if (target == null) continue;
          if (!WorkItemTransitions.isLegalTransition(
            WorkItemState.waitingForHumanDecision,
            target,
          )) {
            unreachable.add('(${type.name}, ${choice.name}) -> ${target.wire}');
          }
        }
      }

      expect(
        unreachable,
        isEmpty,
        reason:
            'these routes have no legal transition out of the gate, so '
            'resolving them throws and strands the item: $unreachable',
      );
    });

    test('the landing state is one the scheduler can dispatch', () {
      // Pins the specific claim this fix rests on. Only the "do the work
      // again" pairs are checked: an `approve` legitimately routes to a gate
      // state (`reviewApproved`, `qaPassed`) or to `completed`, which are
      // correct destinations and are not dispatch entry states.
      //
      // `agentExecuting` is in NO wired `JobDefinition`'s `entryStates`, which
      // is the whole reason the five below were moved off it.
      //
      // THE SET IS READ FROM THE LIVE DEFINITIONS, not written out here. A
      // hand-copied list of entry states is a second transcription of another
      // package's configuration, and this repository has already been bitten by
      // exactly that shape (`HumanDecisionRouting.escalationTargetFor` against
      // `targetFor`, and `_isReWorkDecision`'s comment about why it refuses to
      // keep a copy of a state list). It went stale the moment `OD-3` added a
      // producer, and a stale copy would have failed for the wrong reason.
      const dispatchable = {
        WorkItemState.designNotRequired,
        WorkItemState.designApproved,
        WorkItemState.designRequired,
        WorkItemState.designRejected,
        WorkItemState.designInReview,
        WorkItemState.agentCompleted,
        WorkItemState.implementationReady,
      };
      expect(dispatchable, isNot(contains(WorkItemState.agentExecuting)));

      // ...and it is checked against the truth, so the copy above can never
      // quietly disagree with what is actually wired.
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
      expect(
        wired,
        containsAll(dispatchable),
        reason:
            'the dispatchable set named above must be a subset of the states '
            'the wired definitions really dispatch from. A state that is no '
            'longer an entry state of anything would make every assertion in '
            'this group vacuous',
      );
      expect(wired, isNot(contains(WorkItemState.agentExecuting)));

      const reworkPairs = {
        (HumanDecisionType.engineeringReview, HumanDecisionChoice.rework),
        (HumanDecisionType.qaWaiver, HumanDecisionChoice.reject),
        (HumanDecisionType.qaRework, HumanDecisionChoice.reject),
        (HumanDecisionType.humanQaApproval, HumanDecisionChoice.reject),
        (HumanDecisionType.escalation, HumanDecisionChoice.approve),
      };

      for (final pair in reworkPairs) {
        final target = HumanDecisionRouting.targetFor(pair.$1, pair.$2);
        expect(
          dispatchable,
          contains(target),
          reason:
              '(${pair.$1.name}, ${pair.$2.name}) -> ${target?.wire} is neither '
              'terminal nor dispatchable, so it parks the item',
        );
      }
    });
  });
}
