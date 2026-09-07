import 'package:platform_contracts/platform_contracts.dart';

import '../states/workflow_state.dart';
import '../validation/guard_conditions.dart';
import '../validation/transition_validator.dart';

class WorkItemTransitions {
  static final Map<
    (WorkItemState, WorkItemState),
    List<GuardCondition<WorkItemState>>
  >
  _legalTransitions = {
    (WorkItemState.draft, WorkItemState.designInReview): [
      GuardConditions.designContractExists(),
    ],
    (WorkItemState.designInReview, WorkItemState.designApproved): [
      GuardConditions.humanDecisionApproved(),
    ],
    (WorkItemState.designInReview, WorkItemState.designRejected): [
      GuardConditions.humanDecisionRejected(),
    ],
    (WorkItemState.designRejected, WorkItemState.draft): [],
    (WorkItemState.designApproved, WorkItemState.agentExecuting): [
      GuardConditions.agentAvailable(),
    ],
    (WorkItemState.agentExecuting, WorkItemState.agentCompleted): [
      GuardConditions.agentResultValid(),
    ],
    (WorkItemState.agentExecuting, WorkItemState.agentFailed): [],
    (WorkItemState.agentCompleted, WorkItemState.qaInProgress): [
      GuardConditions.qaContractExists(),
    ],
    (WorkItemState.agentFailed, WorkItemState.agentExecuting): [],
    (WorkItemState.agentFailed, WorkItemState.designInReview): [],
    (WorkItemState.qaInProgress, WorkItemState.qaPassed): [
      GuardConditions.allRequiredGatesPassed(),
    ],
    (WorkItemState.qaInProgress, WorkItemState.qaFailed): [],
    (WorkItemState.qaFailed, WorkItemState.agentExecuting): [
      GuardConditions.rejectDecisionExists(),
    ],
    (WorkItemState.qaFailed, WorkItemState.designInReview): [
      GuardConditions.reworkDecisionExists(),
    ],
    (WorkItemState.qaFailed, WorkItemState.qaPassed): [
      GuardConditions.waiverDecisionExists(),
    ],
    (WorkItemState.qaPassed, WorkItemState.deploying): [
      GuardConditions.artifactBuilt(),
    ],
    (WorkItemState.deploying, WorkItemState.deployed): [
      GuardConditions.humanApprovalForProduction(),
    ],
    (WorkItemState.deploying, WorkItemState.deploymentFailed): [],
    (WorkItemState.deploymentFailed, WorkItemState.deploying): [],
    (WorkItemState.deployed, WorkItemState.done): [],
  };

  static bool isLegalTransition(WorkItemState from, WorkItemState to) {
    return _legalTransitions.containsKey((from, to));
  }

  static List<GuardCondition<WorkItemState>> getGuards(
    WorkItemState from,
    WorkItemState to,
  ) {
    return _legalTransitions[(from, to)] ?? [];
  }

  static Transition<WorkItemState> validate(
    WorkItemState from,
    WorkItemState to,
    TransitionTrigger trigger,
    Map<String, dynamic> context, {
    TransitionValidator? validator,
  }) {
    if (!isLegalTransition(from, to)) {
      throw InvalidTransitionException(
        Transition(
          from: WorkItemWorkflowState(from),
          to: WorkItemWorkflowState(to),
          trigger: trigger,
          guardResults: [
            GuardResult.fail(
              'legal_transition',
              'Transition from $from to $to is not allowed',
            ),
          ],
        ),
      );
    }

    final guards = getGuards(from, to);
    final v = validator ?? TransitionValidator();
    return v.validate(
      WorkItemWorkflowState(from),
      WorkItemWorkflowState(to),
      trigger,
      guards: guards,
      metadata: context,
    );
  }
}
