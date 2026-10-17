import 'package:platform_contracts/platform_contracts.dart';
import 'package:test/test.dart';
import 'package:workflow_engine/workflow_engine.dart';

/// THE ONE WAY OUT OF THE FEATURE PARK — F-75, MEDIUM, from the independent
/// review of slice 1 (`7029424`).
///
/// ## THE EDGE
///
/// `featureIntakeParked -> waitingForHumanDecision`. It is the whole of the
/// park's way out that is not cancellation or termination, and the table's own
/// comment beside it is emphatic:
///
/// > DELIBERATELY NO EDGE BACK TO `planned`. … Recovery is via the human gate,
/// > which is slower and deliberately so.
///
/// There is no edge back to `planned` either — `planned` has exactly one
/// predecessor, pinned in
/// `packages/scheduler/test/planned_entry_state_hop_test.dart:468` — so this is
/// not one way out among several. It is THE way out.
/// `featureIntakeParked` is in the `entryStates` of no wired `JobDefinition`
/// (asserted in `transition_consistency_test.dart:206`), so nothing dispatches
/// an item out of it. Delete this edge and a parked feature intake request can
/// only be cancelled or terminated.
///
/// ## HOW IT LOST ITS GUARD
///
/// Two independent causes, both invisible at the time, which is why the edge
/// needed a guard of its own rather than one more assertion in a file that
/// already had some.
///
/// **1. A mandatory format fix silently shrank a drift guard.** Slice 1
/// (`84460a2`) ran `dart format`, which reflowed this pair from one line into
/// the three-line form because it is the longest key in the table:
///
/// ```diff
/// -    (WorkItemState.featureIntakeParked, WorkItemState.waitingForHumanDecision): [
/// +    (
/// +      WorkItemState.featureIntakeParked,
/// +      WorkItemState.waitingForHumanDecision,
/// +    ): [
/// ```
///
/// `apps/control_plane/test/shared/transition_copy_test.dart:44` enumerates the
/// table with
/// `RegExp(r'\(WorkItemState\.(\w+), WorkItemState\.(\w+)\):\s*\[')` — single
/// line only, and exactly one space after each comma. Replaying that regex
/// over the table gives **53 pairs before slice 1 and 52 after**, and the lost
/// pair is exactly this one. The guard did not fail: the pair it lost was a
/// pair whose plain copy already existed, so it had nothing to complain about.
/// It simply stopped watching — a mandatory gate that can silently reduce the
/// coverage of the gate beside it.
///
/// **2. Nothing named the edge as load-bearing.** The reviewer's claim was
/// that deleting the edge "would now fail nothing at all", on the grounds that
/// `featureIntakeParked` appears in tests only at
/// `transition_consistency_test.dart:206-212` (that the state is NOT
/// dispatchable), `design_review_park_surface_test.dart:609` (a different
/// probe) and `work_entry_test.dart` (state assertions) — none of which asks
/// whether there is a way out.
///
/// **THAT CLAIM IS ALSO PARTLY WRONG, and the correction matters.** Measured
/// here by mutation, deleting the edge does fail one thing:
/// `transition_consistency_test.dart:54` ("allowedTransitions mirrors the
/// accepted-pair table"). But it fails for the wrong reason and in the wrong
/// direction:
///
///  * it is not a "the park has a way out" guard. It is a MIRROR guard: it
///    compares live `isLegalTransition` against a hand-written
///    `WorkItemWorkflowState.allowedTransitions`. The edge is caught only
///    because that mirror still lists it, and the failure message talks about
///    the mirror drifting — never about a parked feature intake request
///    becoming a terminal state nobody can leave.
///  * it is removable by exactly the wrong edit. Anyone "cleaning up" the
///    mirror to agree with a deliberately-removed edge turns it green again
///    while the park is stranded. The two guards fail in opposite directions on
///    the same change, so satisfying one does not satisfy the other.
///
/// So the edge had no guard that said what it was FOR. That is the gap this
/// file closes, and the reason the accidental coverage above is worth naming
/// rather than relying on.
///
/// ## WHAT THIS FILE IS
///
/// The subject, asserted directly against `WorkItemTransitions`, named as the
/// park's only way out, plus its non-vacuity proof by mutation. The broader
/// regex defect is REPORTED below rather than repaired —
/// `transition_copy_test.dart` is outside this correction's granted paths, and
/// the Manager rules on it.
void main() {
  test('featureIntakeParked -> waitingForHumanDecision is legal', () {
    // `isLegalTransition` also answers `true` for the generic escapes
    // (`cancelled`, `terminated`), so an `isTrue` here could in principle be
    // satisfied by the fallback rather than by the edge. It cannot be:
    // `waitingForHumanDecision` is neither terminal target, so `true` is
    // reachable only through `_legalTransitions[(from, to)]`. That is what
    // makes this assertion about the edge and not about the fallback — and it
    // is why deleting the edge turns it red (verified by mutation, not assumed).
    expect(
      WorkItemTransitions.isLegalTransition(
        WorkItemState.featureIntakeParked,
        WorkItemState.waitingForHumanDecision,
      ),
      isTrue,
      reason:
          'THIS IS THE PARK\'S ONLY WAY OUT. `featureIntakeParked` is in no '
          'JobDefinition\'s entryStates, so nothing dispatches from it; '
          '`cancelled` and `terminated` are generic escapes that END the item '
          'rather than advance it; and `planned` has exactly one predecessor, '
          'so there is no edge back into it. Remove this one and a parked '
          'feature intake request can never be picked up again — a terminal '
          'state nobody can leave, which is the same class of defect the park '
          'state was created to end.',
    );
  });
}

/// THE WIDER DEFECT, REPORTED RATHER THAN FIXED HERE.
///
/// `apps/control_plane/test/shared/transition_copy_test.dart:44` derives its
/// whole pair set from a single-line regex that is not whitespace-tolerant, so
/// `dart format` — a MANDATORY gate — can silently reduce what the guard
/// watches, and the reduction is invisible because a pair that drops out is a
/// pair whose copy already exists. Two properties would close it:
///
///  * make the regex whitespace-tolerant (`\s*` after each comma and around
///    the `.`), so a reflow cannot lose a pair; and
///  * pin the pair COUNT, so a shrinking enumeration fails loudly instead of
///    quietly checking less — the same non-vacuity technique used in this file
///    and already applied to the `hasLength(10)` enum count in the scheduler
///    drift guard.
///
/// **Neither is inside this correction's granted paths.** That file is under
/// `apps/control_plane/test/shared/`, which is not granted. This correction
/// deliberately did not edit it; the assertion above covers the one edge whose
/// loss actually mattered, and the regex defect itself is routed to the Manager
/// for a ruling.
///
/// Note also why the fix cannot simply move here: `control_plane` cannot depend
/// on `workflow_engine` — it is a Flutter app and the engine is a pure Dart
/// package below it — which is exactly why that file parses the source as text
/// instead of calling `WorkItemTransitions.isLegalTransition`. The regex is
/// the weak link precisely because the dependency edge is not available to it.
