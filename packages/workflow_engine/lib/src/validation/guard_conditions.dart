import 'package:platform_contracts/platform_contracts.dart';

import '../states/workflow_state.dart';
import 'design_contract_resolution.dart';
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

  /// Validates that the escalation index is within the allowed maximum.
  ///
  /// The max escalation is derived from the ModelPolicy chain length for the
  /// relevant agent role. If no policy exists or the chain is empty, escalation
  /// is unlimited (falls back to the fallback model).
  static GuardCondition<WorkItemState> escalationIndexWithinLimit({
    required int maxEscalation,
  }) => _EscalationIndexWithinLimitGuard(maxEscalation);

  /// Validates that the escalation index is within the allowed maximum, but
  /// only for specific decision types that trigger escalation.
  ///
  /// This guard reads the decision type from context and only applies the
  /// limit check when the decision type is in [escalationDecisionTypes].
  static GuardCondition<WorkItemState>
  escalationIndexWithinLimitForDecisionTypes({
    required Set<HumanDecisionType> escalationDecisionTypes,
  }) => _ConditionalEscalationIndexGuard(escalationDecisionTypes);
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

/// ## This guard reads a DURABLE, STORE-CONFIRMED answer
///
/// It used to be `context?['designContractId'] != null` — a caller-supplied
/// string. A `designContractId` NAMES a design contract; a string does not
/// prove one exists, and the id this guard used to read was thrown away by
/// `DurableWorkflowEngine.transition` rather than written anywhere. So the
/// guard was satisfiable by any caller that passed a value, which is the
/// behaviour `design-revision.md` §4.3 requires to be unbuildable and whose
/// falsifier it names: `context: {'designContractId': 'anything'}` on an item
/// whose column is NULL, which used to be ACCEPTED and persisted an item at
/// `designRequired` with nothing behind it.
///
/// It now reads [DesignContractResolution] under
/// [designContractResolutionContextKey]: the work item's persisted
/// `designContractId` column AND a `DesignContractStore` lookup that confirmed
/// it. Both halves are required, and the absence of a resolution is itself a
/// refusal — see `DesignContractResolution` for why that is the honest default
/// for the pure-policy path, which has no store and no work item to ask.
///
/// **This guard is shared by `planned -> designRequired` for EVERY category,
/// not design remediation alone.** Closing it removes a fabrication path for
/// all of them and breaks no working one: zero production callers transition
/// TO `designRequired`.
class _DesignContractExistsGuard extends GuardCondition<WorkItemState> {
  @override
  String get name => 'design_contract_exists';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final resolution =
        context?[designContractResolutionContextKey]
            as DesignContractResolution?;

    if (resolution == null) {
      return GuardResult.fail(
        name,
        'No durable design contract resolution was supplied for '
        '${from.value} -> ${to.value}. This guard reads the work item\'s '
        'persisted designContractId column and confirms it against the design '
        'contract store; only DurableWorkflowEngine.transition can supply '
        'that, and a caller-supplied context value is not a substitute for it.',
      );
    }

    if (!resolution.isConfirmed) {
      final contractId = resolution.contractId;
      return GuardResult.fail(
        name,
        contractId == null
            ? 'The work item carries no designContractId, so there is no '
                  'design contract for design work to run against'
            : 'The work item names design contract $contractId, and that id '
                  'was not confirmed against a design contract store: either '
                  'no store is mounted to ask or the id resolves to no row',
      );
    }

    return GuardResult.pass(name);
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

  /// Evaluates the QA contract's **required gates**, not the results handed
  /// to it.
  ///
  /// The invariant is one line: *a required gate with no result is
  /// `not_executed`, not absent.* Iterating `gateResults` and asking "of the
  /// results I was handed, are the required ones satisfied?" cannot express
  /// that — a contract declaring three required gates, given only the one
  /// result that passed, filtered to a single element whose `.every()` is
  /// `true`, and passed while two required gates went unevaluated. The
  /// iteration is inverted here: every required gate the contract declares is
  /// looked up in the results, and a miss fails naming the gate id.
  ///
  /// This is fail-closed by construction: a gate that was never evaluated and
  /// a gate that evaluated and failed now produce the same verdict, which is
  /// the correct one.
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

    // Without the contract there is no declared gate set, so "all required
    // gates passed" has nothing to iterate and would be vacuously true.
    final qaContract = context?['qaContract'] as QAContract?;
    if (qaContract == null) {
      return GuardResult.fail(
        name,
        "QA contract required in context under key 'qaContract'; without it no "
        'required gate can be evaluated, and an empty gate set must not read as '
        'an overall pass',
      );
    }

    for (final gate in qaContract.gates.where((g) => g.required)) {
      // Every result carrying this gate id must satisfy the gate. Duplicates
      // are not collapsed, so a second result cannot mask a failing one.
      final resultsForGate = gateResults.where((r) => r.gateId == gate.gateId);

      if (resultsForGate.isEmpty) {
        return GuardResult.fail(
          name,
          'Required QA gate ${gate.gateId} has no gate result; a required gate '
          'left unevaluated is not_executed and blocks qa_passed',
        );
      }

      if (!resultsForGate.every(_isGateSatisfied)) {
        return GuardResult.fail(
          name,
          'All required QA gates must pass; a required gate left '
          'not_executed or skipped without an authority reference '
          'requires a formal determination rather than a silent pass',
        );
      }
    }

    return GuardResult.pass(name);
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

class _EscalationIndexWithinLimitGuard extends GuardCondition<WorkItemState> {
  _EscalationIndexWithinLimitGuard(this.maxEscalation);

  final int maxEscalation;

  @override
  String get name => 'escalation_index_within_limit';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final currentIndex = context?['escalationIndex'] as int? ?? 0;
    final nextIndex = currentIndex + 1;
    if (maxEscalation >= 0 && nextIndex > maxEscalation) {
      return GuardResult.fail(
        name,
        'Escalation index $nextIndex exceeds maximum allowed $maxEscalation',
      );
    }
    return GuardResult.pass(name);
  }
}

class _ConditionalEscalationIndexGuard extends GuardCondition<WorkItemState> {
  _ConditionalEscalationIndexGuard(this.escalationDecisionTypes);

  final Set<HumanDecisionType> escalationDecisionTypes;

  @override
  String get name => 'escalation_index_within_limit';

  @override
  GuardResult evaluate(
    WorkflowState<WorkItemState> from,
    WorkflowState<WorkItemState> to,
    Map<String, dynamic>? context,
  ) {
    final decision = _decisionOf(context);
    if (decision == null ||
        decision.choice == null ||
        !escalationDecisionTypes.contains(decision.decisionType)) {
      return GuardResult.pass(name);
    }
    final currentIndex = context?['escalationIndex'] as int? ?? 0;
    final maxEscalation = context?['maxEscalation'] as int? ?? -1;
    final nextIndex = currentIndex + 1;
    if (maxEscalation >= 0 && nextIndex > maxEscalation) {
      return GuardResult.fail(
        name,
        'Escalation index $nextIndex exceeds maximum allowed $maxEscalation',
      );
    }
    return GuardResult.pass(name);
  }
}
