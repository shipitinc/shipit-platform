import 'package:platform_contracts/platform_contracts.dart';

import '../states/workflow_state.dart';
import 'transition_validator.dart';

class GuardConditions {
  static GuardCondition<WorkItemState> actorAllowed(
    Iterable<ActorType> allowed,
  ) => _ActorAllowedGuard(allowed.toSet());

  static GuardCondition<WorkItemState> actorIsNotSelf() =>
      _ActorIsNotSelfGuard();

  static GuardCondition<WorkItemState> designContractExists() =>
      _DesignContractExistsGuard();

  static GuardCondition<WorkItemState> designContractUnderReview() =>
      _DesignContractUnderReviewGuard();

  static GuardCondition<WorkItemState> planningEvidenceProvided() =>
      _PlanningEvidenceProvidedGuard();

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

  /// The work item must reference a pending/in-progress blocking human
  /// decision of one of [types] with the matching workItemId.
  static GuardCondition<WorkItemState> blockingHumanDecisionPendingOfType(
    Iterable<HumanDecisionType> types,
  ) => _BlockingHumanDecisionPendingGuard(types.toSet());

  /// The blocking human decision must be resolved with one of the exact
  /// (decisionType, choice) pairs in [allowed] and must target the same work
  /// item being transitioned.
  static GuardCondition<WorkItemState> blockingHumanDecisionResolved(
    Set<({HumanDecisionType type, HumanDecisionChoice choice})> allowed,
  ) => _BlockingHumanDecisionResolvedGuard(allowed);

  static GuardCondition<WorkItemState> decisionActorIsHuman() =>
      _DecisionActorIsHumanGuard();
}

WorkflowActor? _actorOf(Map<String, dynamic>? context) =>
    context?['actor'] as WorkflowActor?;

HumanDecision? _decisionOf(Map<String, dynamic>? context) =>
    context?['humanDecision'] as HumanDecision?;

class _ActorAllowedGuard extends GuardCondition<WorkItemState> {
  _ActorAllowedGuard(this.allowed);

  final Set<ActorType> allowed;

  @override
  String get name => 'actor_allowed';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final actor = _actorOf(context);
    if (actor == null || !allowed.contains(actor.actorType)) {
      final seen = actor?.actorType.name ?? 'none';
      return GuardResult.fail(
        name,
        'Actor $seen is not authorized for ${from.value} -> ${to.value}',
      );
    }
    return GuardResult.pass(name);
  }
}

class _ActorIsNotSelfGuard extends GuardCondition<WorkItemState> {
  @override
  String get name => 'actor_not_self';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final actor = _actorOf(context);
    final producer = context?['producerActorId'] as String?;
    if (producer == null) {
      return GuardResult.fail(
        name,
        'Producer identity required to enforce no-self-approval',
      );
    }
    if (actor != null && actor.actorId == producer) {
      return GuardResult.fail(
        name,
        'Actor $producer cannot review or approve their own work',
      );
    }
    return GuardResult.pass(name);
  }
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
            'Design contract must exist before design work is routed',
          );
  }
}

class _DesignContractUnderReviewGuard extends GuardCondition<WorkItemState> {
  @override
  String get name => 'design_contract_under_review';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final status = context?['designContractStatus'] as DesignContractStatus?;
    return status == DesignContractStatus.underReview
        ? GuardResult.pass(name)
        : GuardResult.fail(
            name,
            'Design contract must be under review before design review starts',
          );
  }
}

class _PlanningEvidenceProvidedGuard extends GuardCondition<WorkItemState> {
  @override
  String get name => 'planning_evidence_provided';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final hasEvidence =
        context?['featureRef'] != null || context?['requirementRef'] != null;
    return hasEvidence
        ? GuardResult.pass(name)
        : GuardResult.fail(
            name,
            'Planning requires featureRef or requirementRef traceability',
          );
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
            'QA contract must exist before implementation completes',
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

    final decision = _decisionOf(context);
    final approved =
        decision?.choice == HumanDecisionChoice.approve &&
        decision?.decisionType == HumanDecisionType.deploymentApproval;
    return approved
        ? GuardResult.pass(name)
        : GuardResult.fail(
            name,
            'Production deployment requires human approval via the '
            'waiting_for_human_decision gate',
          );
  }
}

class _BlockingHumanDecisionPendingGuard extends GuardCondition<WorkItemState> {
  _BlockingHumanDecisionPendingGuard(this.allowedTypes);

  final Set<HumanDecisionType> allowedTypes;

  @override
  String get name => 'blocking_human_decision_pending';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final decision = _decisionOf(context);
    final workItemId = context?['workItemId'] as String?;

    final matches =
        decision != null &&
        !decision.status.isResolved &&
        decision.blocking != false &&
        allowedTypes.contains(decision.decisionType) &&
        (workItemId == null || decision.workItemId == workItemId);
    return matches
        ? GuardResult.pass(name)
        : GuardResult.fail(
            name,
            'A pending blocking human decision of an allowed type for this '
            'work item is required before entering the human decision gate',
          );
  }
}

class _BlockingHumanDecisionResolvedGuard
    extends GuardCondition<WorkItemState> {
  _BlockingHumanDecisionResolvedGuard(this.allowed);

  final Set<({HumanDecisionType type, HumanDecisionChoice choice})> allowed;

  @override
  String get name => 'blocking_human_decision_resolved';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final decision = _decisionOf(context);
    final workItemId = context?['workItemId'] as String?;

    final matchesResolution =
        decision != null &&
        decision.status.isResolved &&
        (workItemId == null || decision.workItemId == workItemId) &&
        decision.choice != null &&
        allowed.contains((
          type: decision.decisionType,
          choice: decision.choice!,
        ));

    if (!matchesResolution) {
      return GuardResult.fail(
        name,
        'Blocking human decision must be resolved with an allowed '
        '(type, choice) pairing for the same work item',
      );
    }
    return GuardResult.pass(name);
  }
}

class _DecisionActorIsHumanGuard extends GuardCondition<WorkItemState> {
  @override
  String get name => 'decision_actor_is_human';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final decision = _decisionOf(context);
    return (decision?.decider != null)
        ? GuardResult.pass(name)
        : GuardResult.fail(
            name,
            'A resolved decision must be signed by a human decider',
          );
  }
}
