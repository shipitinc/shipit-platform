import 'package:platform_contracts/platform_contracts.dart';

import '../validation/transition_validator.dart';

class DeploymentTransitions {
  static const Map<
    (DeploymentPhase, DeploymentPhase),
    List<GuardCondition<DeploymentPhase>>
  >
  _legalTransitions = {
    (DeploymentPhase.building, DeploymentPhase.promoting): [],
    (DeploymentPhase.promoting, DeploymentPhase.deploying): [],
    (DeploymentPhase.deploying, DeploymentPhase.validating): [],
    (DeploymentPhase.validating, DeploymentPhase.completed): [],
    (DeploymentPhase.validating, DeploymentPhase.failed): [],
    (DeploymentPhase.failed, DeploymentPhase.rolledBack): [],
    (DeploymentPhase.failed, DeploymentPhase.deploying): [],
    (DeploymentPhase.rolledBack, DeploymentPhase.deploying): [],
  };

  static bool isLegalTransition(DeploymentPhase from, DeploymentPhase to) {
    return _legalTransitions.containsKey((from, to));
  }

  static List<GuardCondition<DeploymentPhase>> getGuards(
    DeploymentPhase from,
    DeploymentPhase to,
  ) {
    return _legalTransitions[(from, to)] ?? [];
  }
}
