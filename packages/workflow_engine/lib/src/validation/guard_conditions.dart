import 'package:platform_contracts/platform_contracts.dart';

import '../states/workflow_state.dart';
import 'transition_validator.dart';

class GuardConditions {
  static GuardCondition<WorkItemState> designContractExists() =>
      _DesignContractExistsGuard();

  static GuardCondition<WorkItemState> humanDecisionApproved() =>
      _HumanDecisionApprovedGuard();

  static GuardCondition<WorkItemState> humanDecisionRejected() =>
      _HumanDecisionRejectedGuard();

  static GuardCondition<WorkItemState> agentAvailable() =>
      _AgentAvailableGuard();

  static GuardCondition<WorkItemState> agentResultValid() =>
      _AgentResultValidGuard();

  static GuardCondition<WorkItemState> qaContractExists() =>
      _QAContractExistsGuard();

  static GuardCondition<WorkItemState> allRequiredGatesPassed() =>
      _AllRequiredGatesPassedGuard();

  static GuardCondition<WorkItemState> artifactBuilt() => _ArtifactBuiltGuard();

  static GuardCondition<WorkItemState> humanApprovalForProduction() =>
      _HumanApprovalForProductionGuard();

  static GuardCondition<WorkItemState> waiverDecisionExists() =>
      _WaiverDecisionExistsGuard();

  static GuardCondition<WorkItemState> reworkDecisionExists() =>
      _ReworkDecisionExistsGuard();

  static GuardCondition<WorkItemState> rejectDecisionExists() =>
      _RejectDecisionExistsGuard();
}

class _DesignContractExistsGuard extends GuardCondition<WorkItemState> {
  @override
  String get name => 'design_contract_exists';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final hasContract = context?['designContractId'] != null;
    return hasContract
        ? GuardResult.pass(name)
        : GuardResult.fail(
            name,
            'Design contract must exist before transitioning to design_in_review',
          );
  }
}

class _HumanDecisionApprovedGuard extends GuardCondition<WorkItemState> {
  @override
  String get name => 'human_decision_approved';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final decision = context?['humanDecision'] as HumanDecision?;
    final approved = decision?.choice == HumanDecisionChoice.approve;
    return approved
        ? GuardResult.pass(name)
        : GuardResult.fail(name, 'Human decision must be "approve"');
  }
}

class _HumanDecisionRejectedGuard extends GuardCondition<WorkItemState> {
  @override
  String get name => 'human_decision_rejected';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final decision = context?['humanDecision'] as HumanDecision?;
    final rejected = decision?.choice == HumanDecisionChoice.reject;
    return rejected
        ? GuardResult.pass(name)
        : GuardResult.fail(name, 'Human decision must be "reject"');
  }
}

class _AgentAvailableGuard extends GuardCondition<WorkItemState> {
  @override
  String get name => 'agent_available';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final available = context?['agentAvailable'] as bool? ?? false;
    final capabilitiesMatch = context?['capabilitiesMatch'] as bool? ?? false;
    return (available && capabilitiesMatch)
        ? GuardResult.pass(name)
        : GuardResult.fail(
            name,
            'Agent must be available with matching capabilities',
          );
  }
}

class _AgentResultValidGuard extends GuardCondition<WorkItemState> {
  @override
  String get name => 'agent_result_valid';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final result = context?['agentResult'] as AgentResult?;
    final valid =
        result != null && result.status == AgentResultStatus.completed;
    return valid
        ? GuardResult.pass(name)
        : GuardResult.fail(name, 'Agent result must be valid and completed');
  }
}

class _QAContractExistsGuard extends GuardCondition<WorkItemState> {
  @override
  String get name => 'qa_contract_exists';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final exists = context?['qaContractId'] != null;
    return exists
        ? GuardResult.pass(name)
        : GuardResult.fail(
            name,
            'QA contract must exist for this work item category',
          );
  }
}

class _AllRequiredGatesPassedGuard extends GuardCondition<WorkItemState> {
  @override
  String get name => 'all_required_gates_passed';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final gateResults = context?['gateResults'] as List<QAGateResult>?;
    if (gateResults == null) {
      return GuardResult.fail(name, 'Gate results required for QA evaluation');
    }

    final requiredGates = gateResults.where(
      (g) =>
          context?['qaContract']?.gates.any(
            (gc) => gc.gateId == g.gateId && gc.required,
          ) ??
          false,
    );

    final allSatisfied = requiredGates.every(_isGateSatisfied);
    return allSatisfied
        ? GuardResult.pass(name)
        : GuardResult.fail(
            name,
            'All required QA gates must pass; a required gate left '
            'not_executed or skipped without an authority reference '
            'requires a formal determination rather than a silent pass',
          );
  }

  bool _isGateSatisfied(QAGateResult result) {
    switch (result.status) {
      case QAGateStatus.passed:
      case QAGateStatus.waived:
      case QAGateStatus.notApplicable:
        return true;
      case QAGateStatus.skipped:
        return _hasSkippedAuthority(result);
      case QAGateStatus.pending:
      case QAGateStatus.running:
      case QAGateStatus.failed:
      case QAGateStatus.notExecuted:
        return false;
    }
  }

  bool _hasSkippedAuthority(QAGateResult result) {
    if (result.waiver != null) {
      return true;
    }
    return result.evidenceDeterminations?.any(
          (d) =>
              d.determination == EvidenceDetermination.skipped &&
              d.authorityRef != null,
        ) ??
        false;
  }
}

class _ArtifactBuiltGuard extends GuardCondition<WorkItemState> {
  @override
  String get name => 'artifact_built';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final artifact = context?['deploymentArtifact'] as DeploymentArtifact?;
    return artifact != null
        ? GuardResult.pass(name)
        : GuardResult.fail(
            name,
            'Deployment artifact must be built before deploying',
          );
  }
}

class _HumanApprovalForProductionGuard extends GuardCondition<WorkItemState> {
  @override
  String get name => 'human_approval_for_production';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final targetEnv = context?['targetEnvironment'] as String?;
    if (targetEnv != 'production') {
      return GuardResult.pass(name);
    }

    final decision = context?['humanDecision'] as HumanDecision?;
    final approved =
        decision?.choice == HumanDecisionChoice.approve &&
        decision?.decisionType == HumanDecisionType.deploymentApproval;
    return approved
        ? GuardResult.pass(name)
        : GuardResult.fail(
            name,
            'Production deployment requires human approval',
          );
  }
}

class _WaiverDecisionExistsGuard extends GuardCondition<WorkItemState> {
  @override
  String get name => 'waiver_decision_exists';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final decision = context?['humanDecision'] as HumanDecision?;
    final isWaiver =
        decision?.choice == HumanDecisionChoice.waive &&
        decision?.decisionType == HumanDecisionType.qaWaiver;
    return isWaiver
        ? GuardResult.pass(name)
        : GuardResult.fail(
            name,
            'QA waiver requires human decision with choice "waive"',
          );
  }
}

class _ReworkDecisionExistsGuard extends GuardCondition<WorkItemState> {
  @override
  String get name => 'rework_decision_exists';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final decision = context?['humanDecision'] as HumanDecision?;
    final isRework =
        decision?.choice == HumanDecisionChoice.rework &&
        decision?.decisionType == HumanDecisionType.qaRework;
    return isRework
        ? GuardResult.pass(name)
        : GuardResult.fail(
            name,
            'QA rework requires human decision with choice "rework"',
          );
  }
}

class _RejectDecisionExistsGuard extends GuardCondition<WorkItemState> {
  @override
  String get name => 'reject_decision_exists';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final decision = context?['humanDecision'] as HumanDecision?;
    final isReject =
        decision?.choice == HumanDecisionChoice.reject &&
        decision?.decisionType == HumanDecisionType.qaRework;
    return isReject
        ? GuardResult.pass(name)
        : GuardResult.fail(
            name,
            'QA rework requires human decision with choice "reject"',
          );
  }
}
