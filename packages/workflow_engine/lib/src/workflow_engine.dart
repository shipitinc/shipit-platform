import 'package:platform_contracts/platform_contracts.dart';

import 'states/workflow_state.dart';
import 'transitions/deployment_transitions.dart';
import 'transitions/design_transitions.dart';
import 'transitions/human_decision_routing.dart';
import 'transitions/qa_transitions.dart';
import 'transitions/work_item_transitions.dart';
import 'validation/transition_validator.dart';

/// Pure policy engine. It validates transition legality and guard
/// conditions but never persists state; persistence lives in
/// `workflow_store`. Policy rejections are returned as invalid
/// [Transition] results, never thrown.
class WorkflowEngine {
  const WorkflowEngine({TransitionValidator? validator})
    : _validator = validator ?? const TransitionValidator();

  final TransitionValidator _validator;

  Transition<WorkItemState> evaluateWorkItemTransition({
    required WorkItemState from,
    required WorkItemState to,
    required TransitionTrigger trigger,
    required WorkflowActor actor,
    Map<String, dynamic> context = const {},
    String? decisionId,
  }) {
    return WorkItemTransitions.validate(
      from,
      to,
      trigger,
      actor,
      context,
      validator: _validator,
      decisionId: decisionId,
    );
  }

  Transition<DesignContractStatus> transitionDesignContract(
    DesignContractStatus from,
    DesignContractStatus to,
    TransitionTrigger trigger,
    WorkflowActor actor,
    Map<String, dynamic> context,
  ) {
    if (!DesignTransitions.isLegalTransition(from, to)) {
      return Transition<DesignContractStatus>(
        from: DesignContractState(from),
        to: DesignContractState(to),
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
    return _validator.validate(
      DesignContractState(from),
      DesignContractState(to),
      trigger,
      actor,
      guards: DesignTransitions.getGuards(from, to),
      metadata: context,
    );
  }

  Transition<QAStatus> transitionQA(
    QAStatus from,
    QAStatus to,
    TransitionTrigger trigger,
    WorkflowActor actor,
    Map<String, dynamic> context,
  ) {
    if (!QATransitions.isLegalTransition(from, to)) {
      return Transition<QAStatus>(
        from: QAState(from),
        to: QAState(to),
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
    return _validator.validate(
      QAState(from),
      QAState(to),
      trigger,
      actor,
      guards: QATransitions.getGuards(from, to),
      metadata: context,
    );
  }

  Transition<DeploymentPhase> transitionDeployment(
    DeploymentPhase from,
    DeploymentPhase to,
    TransitionTrigger trigger,
    WorkflowActor actor,
    Map<String, dynamic> context,
  ) {
    if (!DeploymentTransitions.isLegalTransition(from, to)) {
      return Transition<DeploymentPhase>(
        from: DeploymentState(from),
        to: DeploymentState(to),
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
    return _validator.validate(
      DeploymentState(from),
      DeploymentState(to),
      trigger,
      actor,
      guards: DeploymentTransitions.getGuards(from, to),
      metadata: context,
    );
  }

  /// Target work item state unlocked by a resolved (type, choice) pair.
  WorkItemState? resolveHumanDecisionTarget(
    HumanDecisionType decisionType,
    HumanDecisionChoice choice,
  ) {
    return HumanDecisionRouting.targetFor(decisionType, choice);
  }
}
