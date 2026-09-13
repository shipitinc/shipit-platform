import 'package:platform_contracts/platform_contracts.dart';

/// Maps a resolved human decision to the work item state it unlocks.
///
/// All human-gated transitions resolve from
/// [WorkItemState.waitingForHumanDecision]. The routing table is the only
/// place a (decisionType, choice) is translated into a target state. The
/// same mapping is mirrored structurally by guard conditions in
/// `work_item_transitions.dart`, so an unmapped or unexpected resolution
/// cannot move the work item.
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
        WorkItemState.agentExecuting,
      (HumanDecisionType.qaWaiver, HumanDecisionChoice.waive) =>
        WorkItemState.qaPassed,
      (HumanDecisionType.qaWaiver, HumanDecisionChoice.reject) =>
        WorkItemState.agentExecuting,
      (HumanDecisionType.qaRework, HumanDecisionChoice.reject) =>
        WorkItemState.agentExecuting,
      (HumanDecisionType.qaRework, HumanDecisionChoice.rework) =>
        WorkItemState.designInReview,
      (HumanDecisionType.deploymentApproval, HumanDecisionChoice.approve) =>
        WorkItemState.deployed,
      (HumanDecisionType.deploymentApproval, HumanDecisionChoice.reject) =>
        WorkItemState.deploymentFailed,
      (HumanDecisionType.humanQaApproval, HumanDecisionChoice.approve) =>
        WorkItemState.completed,
      (HumanDecisionType.humanQaApproval, HumanDecisionChoice.reject) =>
        WorkItemState.agentExecuting,
      (_, HumanDecisionChoice.cancel) => WorkItemState.cancelled,
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
}
