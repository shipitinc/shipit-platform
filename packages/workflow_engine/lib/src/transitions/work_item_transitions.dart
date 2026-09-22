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
    /*** Planning ***/
    (WorkItemState.draft, WorkItemState.planning): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
    (WorkItemState.planning, WorkItemState.planned): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.planningEvidenceProvided(),
    ],
    (WorkItemState.planning, WorkItemState.cancelled): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
    (WorkItemState.planned, WorkItemState.designRequired): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.designContractExists(),
    ],
    (WorkItemState.planned, WorkItemState.designNotRequired): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
    /*** Design ***/
    (WorkItemState.designRequired, WorkItemState.designInReview): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.designContractUnderReview(),
    ],
    (WorkItemState.designRequired, WorkItemState.agentExecuting): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.agentAvailable(),
    ],
    (WorkItemState.designInReview, WorkItemState.waitingForHumanDecision): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.blockingHumanDecisionPendingOfType([
        HumanDecisionType.designApproval,
      ]),
    ],
    (WorkItemState.designInReview, WorkItemState.agentExecuting): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.agentAvailable(),
    ],
    (WorkItemState.waitingForHumanDecision, WorkItemState.designApproved): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.blockingHumanDecisionResolved({
        (
          type: HumanDecisionType.designApproval,
          choice: HumanDecisionChoice.approve,
        ),
      }),
      GuardConditions.decisionActorIsHuman(),
    ],
    (WorkItemState.waitingForHumanDecision, WorkItemState.designRejected): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.blockingHumanDecisionResolved({
        (
          type: HumanDecisionType.designApproval,
          choice: HumanDecisionChoice.reject,
        ),
      }),
      GuardConditions.decisionActorIsHuman(),
    ],
    (WorkItemState.waitingForHumanDecision, WorkItemState.designInReview): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.blockingHumanDecisionResolved({
        (
          type: HumanDecisionType.designApproval,
          choice: HumanDecisionChoice.rework,
        ),
        (type: HumanDecisionType.qaRework, choice: HumanDecisionChoice.rework),
      }),
      GuardConditions.decisionActorIsHuman(),
    ],
    (WorkItemState.designApproved, WorkItemState.agentExecuting): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.agentAvailable(),
    ],
    (WorkItemState.designRejected, WorkItemState.designInReview): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
    /*** Execution ***/
    (WorkItemState.designNotRequired, WorkItemState.agentExecuting): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.agentAvailable(),
    ],
    (WorkItemState.agentExecuting, WorkItemState.agentCompleted): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.qaContractExists(),
      GuardConditions.agentResultValid(),
    ],
    (WorkItemState.agentExecuting, WorkItemState.agentFailed): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
    (WorkItemState.agentFailed, WorkItemState.agentExecuting): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
    /*** Engineering review ***/
    (WorkItemState.agentCompleted, WorkItemState.reviewInProgress): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.agentResultValid(),
    ],
    (WorkItemState.agentCompleted, WorkItemState.designInReview): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.designContractUnderReview(),
    ],
    (WorkItemState.reviewInProgress, WorkItemState.waitingForHumanDecision): [
      GuardConditions.actorAllowed([
        ActorType.orchestrator,
        ActorType.engineeringReviewer,
      ]),
      GuardConditions.actorIsNotSelf(),
      GuardConditions.blockingHumanDecisionPendingOfType([
        HumanDecisionType.engineeringReview,
      ]),
    ],
    (WorkItemState.waitingForHumanDecision, WorkItemState.reviewApproved): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.blockingHumanDecisionResolved({
        (
          type: HumanDecisionType.engineeringReview,
          choice: HumanDecisionChoice.approve,
        ),
      }),
      GuardConditions.decisionActorIsHuman(),
    ],
    (WorkItemState.waitingForHumanDecision, WorkItemState.reviewRejected): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.blockingHumanDecisionResolved({
        (
          type: HumanDecisionType.engineeringReview,
          choice: HumanDecisionChoice.reject,
        ),
      }),
      GuardConditions.decisionActorIsHuman(),
    ],
    (WorkItemState.waitingForHumanDecision, WorkItemState.agentExecuting): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.blockingHumanDecisionResolved({
        (
          type: HumanDecisionType.engineeringReview,
          choice: HumanDecisionChoice.rework,
        ),
        (type: HumanDecisionType.qaRework, choice: HumanDecisionChoice.reject),
        (type: HumanDecisionType.qaWaiver, choice: HumanDecisionChoice.reject),
        (
          type: HumanDecisionType.humanQaApproval,
          choice: HumanDecisionChoice.reject,
        ),
        // A human chose to resume after a failure was escalated to them.
        (
          type: HumanDecisionType.escalation,
          choice: HumanDecisionChoice.approve,
        ),
      }),
      GuardConditions.decisionActorIsHuman(),
    ],
    // Escalation outcome: send the work back to be re-planned. Resuming is
    // handled by the guard on (waitingForHumanDecision -> agentExecuting),
    // and stopping is already covered by the generic orchestrator escape to
    // `cancelled`, which must not be narrowed here.
    (WorkItemState.waitingForHumanDecision, WorkItemState.planning): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.blockingHumanDecisionResolved({
        (
          type: HumanDecisionType.escalation,
          choice: HumanDecisionChoice.rework,
        ),
      }),
      GuardConditions.decisionActorIsHuman(),
    ],
    (WorkItemState.reviewApproved, WorkItemState.qaInProgress): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.qaContractExists(),
    ],
    (WorkItemState.reviewRejected, WorkItemState.agentExecuting): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
    (WorkItemState.reviewRejected, WorkItemState.designInReview): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
    /*** QA ***/
    (WorkItemState.qaInProgress, WorkItemState.qaPassed): [
      GuardConditions.actorAllowed([
        ActorType.qaExecutor,
        ActorType.orchestrator,
      ]),
      GuardConditions.allRequiredGatesPassed(),
    ],
    (WorkItemState.qaInProgress, WorkItemState.qaFailed): [
      GuardConditions.actorAllowed([
        ActorType.qaExecutor,
        ActorType.orchestrator,
      ]),
    ],
    (WorkItemState.qaPassed, WorkItemState.waitingForHumanDecision): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.blockingHumanDecisionPendingOfType([
        HumanDecisionType.humanQaApproval,
      ]),
    ],
    (WorkItemState.qaFailed, WorkItemState.waitingForHumanDecision): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.blockingHumanDecisionPendingOfType([
        HumanDecisionType.qaWaiver,
        HumanDecisionType.qaRework,
      ]),
    ],
    (WorkItemState.waitingForHumanDecision, WorkItemState.qaPassed): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.blockingHumanDecisionResolved({
        (type: HumanDecisionType.qaWaiver, choice: HumanDecisionChoice.waive),
      }),
      GuardConditions.decisionActorIsHuman(),
    ],
    (WorkItemState.waitingForHumanDecision, WorkItemState.completed): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.blockingHumanDecisionResolved({
        (
          type: HumanDecisionType.humanQaApproval,
          choice: HumanDecisionChoice.approve,
        ),
      }),
      GuardConditions.decisionActorIsHuman(),
    ],
    /*** Deployment ***/
    (WorkItemState.qaPassed, WorkItemState.deploying): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.artifactBuilt(),
    ],
    (WorkItemState.deploying, WorkItemState.waitingForHumanDecision): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.blockingHumanDecisionPendingOfType([
        HumanDecisionType.deploymentApproval,
      ]),
    ],
    (WorkItemState.waitingForHumanDecision, WorkItemState.deployed): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.blockingHumanDecisionResolved({
        (
          type: HumanDecisionType.deploymentApproval,
          choice: HumanDecisionChoice.approve,
        ),
      }),
      GuardConditions.decisionActorIsHuman(),
    ],
    (WorkItemState.waitingForHumanDecision, WorkItemState.deploymentFailed): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.blockingHumanDecisionResolved({
        (
          type: HumanDecisionType.deploymentApproval,
          choice: HumanDecisionChoice.reject,
        ),
      }),
      GuardConditions.decisionActorIsHuman(),
    ],
    (WorkItemState.deploying, WorkItemState.deployed): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.artifactBuilt(),
      GuardConditions.humanApprovalForProduction(),
    ],
    (WorkItemState.deploying, WorkItemState.deploymentFailed): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
    (WorkItemState.deploymentFailed, WorkItemState.deploying): [
      GuardConditions.actorAllowed([
        ActorType.releaseEngineer,
        ActorType.orchestrator,
      ]),
    ],
    (WorkItemState.deployed, WorkItemState.completed): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
  };

  /// Any non-terminal work item may be cancelled or terminated by the
  /// orchestrator/system. This guarantees every reachable state has an
  /// escape hatch, so the machine can never deadlock in an impossible loop.
  static bool _isGenericEscape(WorkItemState from, WorkItemState to) {
    if (from.isTerminal || to == from) {
      return false;
    }
    return to == WorkItemState.cancelled || to == WorkItemState.terminated;
  }

  static bool isLegalTransition(WorkItemState from, WorkItemState to) {
    return _legalTransitions.containsKey((from, to)) ||
        _isGenericEscape(from, to);
  }

  static List<GuardCondition<WorkItemState>> getGuards(
    WorkItemState from,
    WorkItemState to,
  ) {
    final explicit = _legalTransitions[(from, to)];
    if (explicit != null) {
      return explicit;
    }
    if (_isGenericEscape(from, to)) {
      final allowed = to == WorkItemState.terminated
          ? [ActorType.orchestrator, ActorType.system]
          : [ActorType.orchestrator];
      return [GuardConditions.actorAllowed(allowed)];
    }
    return const [];
  }

  static Transition<WorkItemState> validate(
    WorkItemState from,
    WorkItemState to,
    TransitionTrigger trigger,
    WorkflowActor actor,
    Map<String, dynamic> context, {
    TransitionValidator? validator,
    String? decisionId,
  }) {
    if (!isLegalTransition(from, to)) {
      return Transition<WorkItemState>(
        from: WorkItemWorkflowState(from),
        to: WorkItemWorkflowState(to),
        trigger: trigger,
        actor: actor,
        guardResults: [
          GuardResult.fail(
            'legal_transition',
            'Transition from $from to $to is not allowed',
          ),
        ],
      );
    }

    final guards = getGuards(from, to);

    final v = validator ?? const TransitionValidator();
    return v.validate(
      WorkItemWorkflowState(from),
      WorkItemWorkflowState(to),
      trigger,
      actor,
      guards: guards,
      metadata: {if (decisionId != null) 'decisionId': decisionId, ...context},
      decisionId: decisionId,
    );
  }
}
