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
/// The dispatchable target for "this human wants the work done again" is
/// [WorkItemState.designNotRequired]: it is in `triageDefectDefinition`'s and
/// `implementFeatureDefinition`'s `entryStates`, and it is the state the
/// already-shipped operator retry returns a failed item to (`be75ba1`,
/// `agentFailed -> designNotRequired`).
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
        WorkItemState.designNotRequired,
      (HumanDecisionType.qaWaiver, HumanDecisionChoice.waive) =>
        WorkItemState.qaPassed,
      (HumanDecisionType.qaWaiver, HumanDecisionChoice.reject) =>
        WorkItemState.designNotRequired,
      (HumanDecisionType.qaRework, HumanDecisionChoice.reject) =>
        WorkItemState.designNotRequired,
      (HumanDecisionType.qaRework, HumanDecisionChoice.rework) =>
        WorkItemState.designInReview,
      (HumanDecisionType.deploymentApproval, HumanDecisionChoice.approve) =>
        WorkItemState.deployed,
      (HumanDecisionType.deploymentApproval, HumanDecisionChoice.reject) =>
        WorkItemState.deploymentFailed,
      (HumanDecisionType.humanQaApproval, HumanDecisionChoice.approve) =>
        WorkItemState.completed,
      (HumanDecisionType.humanQaApproval, HumanDecisionChoice.reject) =>
        WorkItemState.designNotRequired,
      (_, HumanDecisionChoice.cancel) => WorkItemState.cancelled,
      // An escalation is a failure handed to a human: the operator either
      // puts the work back in flight or sends it back to be re-planned.
      // (`cancel` is already covered by the catch-all above.) Without these
      // routes a resolved escalation leaves the item parked at its gate with
      // the decision already answered.
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
  /// - engineeringReview rework -> designNotRequired
  /// - engineeringReview reject -> agentExecuting (see BELOW)
  /// - designApproval reject/rework -> designInReview
  /// - humanQaApproval reject -> designNotRequired
  /// - humanQaApproval rework -> agentExecuting
  ///
  /// ## WHY THIS MUST NOT DIVERGE FROM [targetFor]
  ///
  /// `DurableWorkflowEngine._isEscalationTransition`
  /// (packages/workflow_store/.../durable_workflow_engine.dart:761) computes
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
  static WorkItemState? escalationTargetFor(
    HumanDecisionType decisionType,
    HumanDecisionChoice choice,
  ) {
    if (choice != HumanDecisionChoice.reject &&
        choice != HumanDecisionChoice.rework) {
      return null;
    }
    return switch ((decisionType, choice)) {
      // Lockstep with targetFor: both moved to the dispatchable entry state.
      (HumanDecisionType.engineeringReview, HumanDecisionChoice.rework) =>
        WorkItemState.designNotRequired,
      (HumanDecisionType.humanQaApproval, HumanDecisionChoice.reject) =>
        WorkItemState.designNotRequired,
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
