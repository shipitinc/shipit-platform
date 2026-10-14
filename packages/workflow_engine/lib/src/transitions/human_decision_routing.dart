import 'package:platform_contracts/platform_contracts.dart';

/// Maps a resolved human decision to the work item state it unlocks.
///
/// All human-gated transitions resolve from
/// [WorkItemState.waitingForHumanDecision]. The routing table is the only
/// place a (decisionType, choice) is translated into a target state. The
/// same mapping is mirrored structurally by guard conditions in
/// `work_item_transitions.dart`, so an unmapped or unexpected resolution
/// cannot move the work item.
///
/// ## NO ROUTE MAY TARGET `agentExecuting`
///
/// `DurableWorkflowEngine.resolveHumanDecision` derives its target from
/// [targetFor] alone and takes no caller-supplied state, so this table — not
/// the transition table — decides where a resolved human decision lands.
/// Landing on `agentExecuting` is therefore always a defect, for two
/// independent reasons:
///
/// 1. **It strands the item.** `agentExecuting` is in the `entryStates` of NO
///    wired `JobDefinition` (triage_defect, implement_feature,
///    design_revision, design_review, engineering_review, baseline_product
///    list `{designNotRequired, designApproved}`, `{designRequired,
///    designRejected}`, `{designInReview}` and `{agentCompleted}` between
///    them). Nothing ever enqueues for it, so the item sits at its gate with
///    the decision already answered and no job to run. This was observed live
///    on work item `defect-DEF-1791684804452198` on 2026-10-12.
/// 2. **It asserts something untrue.** `agentExecuting` means an execution is
///    ALREADY RUNNING. Resolving a decision does not start one, so the
///    scheduler is right to refuse to dispatch an item claiming that.
///
/// ## WHAT "REWORK" MEANS — `OD-3`, RESOLVED
///
/// Five routes used to point at [WorkItemState.designNotRequired], which
/// re-triages. Whether that means "re-classify" or "re-do the work" is a
/// product decision about what rework MEANS, and `OD-3` answered it: **four of
/// the five mean re-do the work**, so they now target the implementation lane's
/// own entry state, [WorkItemState.implementationReady].
///
/// | Pair | Target | Why |
/// |---|---|---|
/// | `(engineeringReview, rework)` | `implementationReady` | a reviewer asked for changes to work that exists |
/// | `(humanQaApproval, reject)` | `implementationReady` | human QA judged the delivered result |
/// | `(qaRework, reject)` | `implementationReady` | QA asked for rework rather than a waiver |
/// | `(qaWaiver, reject)` | `implementationReady` | a waiver was refused; the result was judged |
/// | `(escalation, approve)` | **`designNotRequired`** | an escalation is a statement about EXECUTION failure, not about work quality — re-planning it is safe |
///
/// The four gates that move exist only for items that already produced work, so
/// "redo" on them means re-implement. `(escalation, approve)` is the one that
/// does not, which is exactly why it stays: an escalation raised by a provider
/// failure on an item that never implemented must not be mistaken for a verdict
/// on work, and moving it would route such an item into the build queue.
///
/// [WorkItemState.designNotRequired] remains the target for `(escalation,
/// approve)` and is still in `triageDefectDefinition`'s `entryStates`, so that
/// route dispatches exactly as it did before.
///
/// ## WHY THE `implementationReady` EDGE EXISTED BEFORE ANY ROUTE NAMED IT
///
/// [targetFor] is the only thing that decides where a resolved decision lands,
/// so a retarget with no matching edge would move an item into a state nothing
/// leaves and the engine would throw on resolution. The edge was declared ahead
/// of the decision precisely so that answering `OD-3` would be a routing-table
/// edit and not an engine change. This table is the answer.
///
/// ## WHICH RETARGETS NEED `escalationTargetFor` MOVED WITH THEM
///
/// [escalationTargetFor] short-circuits to `null` for any choice that is not
/// `reject` or `rework`, and `DurableWorkflowEngine._isEscalationTransition`
/// short-circuits on the same condition before it ever calls it. So of the five
/// pairs, exactly TWO are lockstep arms and three are not:
///
/// | Pair | Needs `escalationTargetFor` moved? |
/// |---|---|
/// | `(engineeringReview, rework)` | **YES** — a live arm below |
/// | `(humanQaApproval, reject)` | **YES** — a live arm below |
/// | `(qaWaiver, reject)` | no — no arm; the short-circuit makes it inert |
/// | `(qaRework, reject)` | no — no arm; `_ => null` |
/// | `(escalation, approve)` | no — `approve`, so the short-circuit returns `null` first |
///
/// The two live arms are asserted by name in
/// `test/implementation_ready_edge_test.dart`, because a divergence between the
/// two tables does not error: it silently stops the escalation index
/// advancing and changes the shape of the audit trail.
class HumanDecisionRouting {
  const HumanDecisionRouting._();

  static WorkItemState? targetFor(
    HumanDecisionType decisionType,
    HumanDecisionChoice choice,
  ) {
    return switch ((decisionType, choice)) {
      (HumanDecisionType.designApproval, HumanDecisionChoice.approve) =>
        WorkItemState.designApproved,
      (HumanDecisionType.designApproval, HumanDecisionChoice.reject) =>
        WorkItemState.designRejected,
      (HumanDecisionType.designApproval, HumanDecisionChoice.rework) =>
        WorkItemState.designInReview,
      (HumanDecisionType.engineeringReview, HumanDecisionChoice.approve) =>
        WorkItemState.reviewApproved,
      (HumanDecisionType.engineeringReview, HumanDecisionChoice.reject) =>
        WorkItemState.reviewRejected,
      (HumanDecisionType.engineeringReview, HumanDecisionChoice.rework) =>
        WorkItemState.implementationReady,
      (HumanDecisionType.qaWaiver, HumanDecisionChoice.waive) =>
        WorkItemState.qaPassed,
      (HumanDecisionType.qaWaiver, HumanDecisionChoice.reject) =>
        WorkItemState.implementationReady,
      (HumanDecisionType.qaRework, HumanDecisionChoice.reject) =>
        WorkItemState.implementationReady,
      (HumanDecisionType.qaRework, HumanDecisionChoice.rework) =>
        WorkItemState.designInReview,
      (HumanDecisionType.deploymentApproval, HumanDecisionChoice.approve) =>
        WorkItemState.deployed,
      (HumanDecisionType.deploymentApproval, HumanDecisionChoice.reject) =>
        WorkItemState.deploymentFailed,
      (HumanDecisionType.humanQaApproval, HumanDecisionChoice.approve) =>
        WorkItemState.completed,
      (HumanDecisionType.humanQaApproval, HumanDecisionChoice.reject) =>
        WorkItemState.implementationReady,
      (_, HumanDecisionChoice.cancel) => WorkItemState.cancelled,
      // An escalation is a failure handed to a human: the operator either
      // puts the work back in flight or sends it back to be re-planned.
      // (`cancel` is already covered by the catch-all above.) Without these
      // routes a resolved escalation leaves the item parked at its gate with
      // the decision already answered.
      //
      // `approve` stays at `designNotRequired`, DELIBERATELY and alone among
      // the five "do the work again" resolutions: an escalation is a statement
      // about EXECUTION failing, not a judgement on the work, so the work may
      // not have been produced at all. See the class comment.
      (HumanDecisionType.escalation, HumanDecisionChoice.approve) =>
        WorkItemState.designNotRequired,
      (HumanDecisionType.escalation, HumanDecisionChoice.rework) =>
        WorkItemState.planning,
      _ => null,
    };
  }

  /// Returns the target state for a review gate rejection/rework that
  /// includes an escalation index increment.
  ///
  /// This is used for transitions that should increment the escalation index
  /// and return to the production state:
  /// - engineeringReview rework -> implementationReady
  /// - engineeringReview reject -> agentExecuting (see BELOW)
  /// - designApproval reject/rework -> designInReview
  /// - humanQaApproval reject -> implementationReady
  /// - humanQaApproval rework -> agentExecuting
  ///
  /// ## WHY THIS MUST NOT DIVERGE FROM [targetFor]
  ///
  /// `DurableWorkflowEngine._isEscalationTransition`
  /// (packages/workflow_store/.../durable_workflow_engine.dart:979) computes
  /// escalation as `escalationTargetFor(type, choice) == target`, where
  /// `target` is the value [targetFor] just returned. The comparison is the
  /// ONLY thing this method does at runtime: it gates the
  /// `metadata['escalationIndex']` increment and the `EscalationTriggered`
  /// audit record. So a value here that disagrees with [targetFor] does not
  /// error — it silently stops the escalation index advancing and changes the
  /// shape of the audit trail. Every route that [targetFor] moves must move
  /// here in the same commit.
  ///
  /// ## KNOWN PRE-EXISTING DIVERGENCE — NOT INTRODUCED HERE
  ///
  /// Before this change this method was keyed on decision TYPE alone, while
  /// [targetFor] is keyed on the PAIR. The two already disagreed, and they
  /// still do, on two pairs this change was told to leave alone:
  /// `engineeringReview/reject` routes to `reviewRejected` and
  /// `designApproval/reject` to `designRejected`, and neither answer below
  /// names those states. Both therefore classify as "not an escalation": a
  /// rejected engineering review and a rejected design do NOT increment the
  /// escalation index. That is the behaviour at `cc6290d`, preserved here
  /// verbatim, because changing it would start incrementing the index — and
  /// appending an `EscalationTriggered` record — on two routes outside this
  /// change. It is a real incoherence in the escalation accounting and it is
  /// reported, not silently repaired.
  ///
  /// `humanQaApproval/rework` is a third unreachable answer, but a different
  /// kind: [targetFor] has no entry for it at all, so the pair never reaches
  /// this comparison and the value is inert either way. It is left alone
  /// because adding a route for it would be a new decision, not a lockstep
  /// move.
  ///
  /// ## THE TWO LOCKSTEP ARMS MOVED WITH `OD-3`
  ///
  /// `(engineeringReview, rework)` and `(humanQaApproval, reject)` both
  /// retargeted to `implementationReady`, so both arms below did. They are the
  /// only two: `(qaWaiver, reject)` and `(qaRework, reject)` have no arm at all,
  /// and `(escalation, approve)` is not classified as an escalation in the first
  /// place. See the class comment for the full table.
  static WorkItemState? escalationTargetFor(
    HumanDecisionType decisionType,
    HumanDecisionChoice choice,
  ) {
    if (choice != HumanDecisionChoice.reject &&
        choice != HumanDecisionChoice.rework) {
      return null;
    }
    return switch ((decisionType, choice)) {
      // Lockstep with targetFor: both moved to the implementation lane's entry
      // state when OD-3 was resolved.
      (HumanDecisionType.engineeringReview, HumanDecisionChoice.rework) =>
        WorkItemState.implementationReady,
      (HumanDecisionType.humanQaApproval, HumanDecisionChoice.reject) =>
        WorkItemState.implementationReady,
      // Unreachable answers, preserved so the escalation classification of
      // these pairs does not change. See KNOWN PRE-EXISTING DIVERGENCE above.
      (HumanDecisionType.engineeringReview, HumanDecisionChoice.reject) =>
        WorkItemState.agentExecuting,
      (HumanDecisionType.humanQaApproval, HumanDecisionChoice.rework) =>
        WorkItemState.agentExecuting,
      (HumanDecisionType.designApproval, _) => WorkItemState.designInReview,
      _ => null,
    };
  }

  /// True when [target] is the state this (type, choice) routing unlocks.
  static bool routesTo(
    HumanDecisionType decisionType,
    HumanDecisionChoice choice,
    WorkItemState target,
  ) {
    return targetFor(decisionType, choice) == target;
  }

  /// True when [target] is the escalation target state for the (type, choice).
  static bool routesToEscalation(
    HumanDecisionType decisionType,
    HumanDecisionChoice choice,
    WorkItemState target,
  ) {
    return escalationTargetFor(decisionType, choice) == target;
  }
}
