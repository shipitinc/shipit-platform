import 'package:platform_contracts/platform_contracts.dart';

import 'states/workflow_state.dart';
import 'transitions/deployment_transitions.dart';
import 'transitions/design_transitions.dart';
import 'transitions/qa_transitions.dart';
import 'transitions/work_item_transitions.dart';
import 'validation/transition_validator.dart';

class WorkflowEngine {
  const WorkflowEngine({TransitionValidator? validator})
    : _validator = validator ?? const TransitionValidator();

  final TransitionValidator _validator;

  Transition<WorkItemState> transitionWorkItem(
    WorkItemState from,
    WorkItemState to,
    TransitionTrigger trigger,
    Map<String, dynamic> context,
  ) {
    return WorkItemTransitions.validate(
      from,
      to,
      trigger,
      context,
      validator: _validator,
    );
  }

  Transition<DesignContractStatus> transitionDesignContract(
    DesignContractStatus from,
    DesignContractStatus to,
    TransitionTrigger trigger,
    Map<String, dynamic> context,
  ) {
    if (!DesignTransitions.isLegalTransition(from, to)) {
      throw InvalidTransitionException(
        Transition(
          from: DesignContractState(from),
          to: DesignContractState(to),
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
    return _validator.validate(
      DesignContractState(from),
      DesignContractState(to),
      trigger,
      guards: DesignTransitions.getGuards(from, to),
      metadata: context,
    );
  }

  Transition<QAStatus> transitionQA(
    QAStatus from,
    QAStatus to,
    TransitionTrigger trigger,
    Map<String, dynamic> context,
  ) {
    if (!QATransitions.isLegalTransition(from, to)) {
      throw InvalidTransitionException(
        Transition(
          from: QAState(from),
          to: QAState(to),
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
    return _validator.validate(
      QAState(from),
      QAState(to),
      trigger,
      guards: QATransitions.getGuards(from, to),
      metadata: context,
    );
  }

  Transition<DeploymentPhase> transitionDeployment(
    DeploymentPhase from,
    DeploymentPhase to,
    TransitionTrigger trigger,
    Map<String, dynamic> context,
  ) {
    if (!DeploymentTransitions.isLegalTransition(from, to)) {
      throw InvalidTransitionException(
        Transition(
          from: DeploymentState(from),
          to: DeploymentState(to),
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
    return _validator.validate(
      DeploymentState(from),
      DeploymentState(to),
      trigger,
      guards: DeploymentTransitions.getGuards(from, to),
      metadata: context,
    );
  }
}
