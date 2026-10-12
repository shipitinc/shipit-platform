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
        (
          type: HumanDecisionType.designApproval,
          choice: HumanDecisionChoice.reject,
        ),
      }),
      GuardConditions.decisionActorIsHuman(),
      GuardConditions.escalationIndexWithinLimitForDecisionTypes(
        escalationDecisionTypes: {HumanDecisionType.designApproval},
      ),
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
    // RETRY. An operator returns a failed agent run to `designNotRequired`,
    // which `triageDefectDefinition.entryStates` already lists
    // (packages/scheduler/lib/src/triage_defect.dart), so the EXISTING
    // scheduler dispatch path enqueues and claims it with no change to that
    // path at all. Landing in `agentExecuting` instead would assert that an
    // execution is ALREADY RUNNING, and the scheduler correctly refuses to
    // dispatch an item that claims that.
    //
    // The guard is derived from this table's own convention for an edge into
    // an entry state, not invented: `planned -> designNotRequired` (:28) is
    // the only other edge into this state and carries
    // `actorAllowed([ActorType.orchestrator])` and nothing else. NO evidence
    // guard either, because `designNotRequired` asserts that NO design is
    // required, so there is nothing to prove. `agentAvailable()` appears only
    // on `-> agentExecuting` edges, where the transition asserts "an agent is
    // starting right now"; this edge asserts no such thing, and capacity is
    // enforced at claim time by `JobCapacityGuard` exactly as it is for every
    // other job.
    (WorkItemState.agentFailed, WorkItemState.designNotRequired): [
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
        (
          type: HumanDecisionType.engineeringReview,
          choice: HumanDecisionChoice.reject,
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
      GuardConditions.escalationIndexWithinLimitForDecisionTypes(
        escalationDecisionTypes: {
          HumanDecisionType.engineeringReview,
          HumanDecisionType.humanQaApproval,
        },
      ),
    ],
    // REWORK FROM AN ENGINEERING REVIEW — the dispatchable landing state.
    //
    // WHY THIS EDGE IS NARROW AND DOES NOT REPLACE THE ONE ABOVE.
    //
    // `(waitingForHumanDecision, agentExecuting)` above is a GENERIC edge: its
    // `blockingHumanDecisionResolved` set spans six (type, choice) pairs, and
    // five of them belong to lanes that are not engineering review —
    // `qaRework/reject`, `qaWaiver/reject`, `humanQaApproval/reject`, and
    // `escalation/approve` ("a human chose to resume after a failure was
    // escalated to them"). Retargeting it to `designNotRequired` wholesale
    // would silently move every QA rejection and every escalation resume onto
    // the triage entry state, which is a product decision about four other
    // gates and is NOT this lane's to make. So the narrower edge is added
    // instead and the generic one is left exactly as it was.
    //
    // WHY `designNotRequired` AND NOT `agentExecuting`.
    //
    // `agentExecuting` is in the `entryStates` of NO wired `JobDefinition`
    // (triage_defect, implement_feature, design_revision, design_review,
    // engineering_review, baseline_product — none of them lists it), so an item
    // parked there is never dispatched again and nothing will ever run. It also
    // asserts something false: that an execution is ALREADY RUNNING. Landing in
    // it without a dispatch is the same class of defect as `be75ba1`.
    // `designNotRequired` IS in `triageDefectDefinition.entryStates`, which is
    // the mechanism the operator retry already relies on (commit be75ba1,
    // `agentFailed -> designNotRequired` below). The scheduler therefore
    // re-enqueues with no change to its dispatch path at all.
    //
    // NOT YET REACHABLE FROM PRODUCTION, AND THIS LANE CANNOT FIX THAT.
    //
    // `DurableWorkflowEngine.resolveHumanDecision` does not take a caller-
    // supplied target: it computes `target = HumanDecisionRouting.targetFor(
    // decisionType, choice)` (packages/workflow_store/.../durable_workflow_
    // engine.dart:612) and then validates the edge to that target. The routing
    // table — `packages/workflow_engine/lib/src/transitions/
    // human_decision_routing.dart` — is NOT owned by this lane, and it still
    // maps `(engineeringReview, rework) -> agentExecuting`. No edit to this
    // file can change which target a resolved decision selects. So this edge
    // is the guarded landing half; the routing entry is the other half and is
    // reported as a blocker rather than guessed at.
    //
    // CYCLE SAFETY. `designNotRequired -> agentExecuting -> agentCompleted ->
    // reviewInProgress -> waitingForHumanDecision -> designNotRequired` is a
    // cycle, and every traversal of it requires a RESOLVED engineering-review
    // decision signed by a human decider, bounded by
    // `escalationIndexWithinLimitForDecisionTypes` below. Nothing in it is
    // automatic, so no unattended rework loop is created.
    //
    // `agentAvailable()` is deliberately ABSENT, exactly as on
    // `agentFailed -> designNotRequired` below: that guard belongs on
    // `-> agentExecuting` edges, which assert an agent is starting NOW. This
    // edge asserts no such thing, and capacity is enforced at claim time by
    // `JobCapacityGuard`.
    (WorkItemState.waitingForHumanDecision, WorkItemState.designNotRequired): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.blockingHumanDecisionResolved({
        (
          type: HumanDecisionType.engineeringReview,
          choice: HumanDecisionChoice.rework,
        ),
        (
          type: HumanDecisionType.engineeringReview,
          choice: HumanDecisionChoice.reject,
        ),
      }),
      GuardConditions.decisionActorIsHuman(),
      // Keeps the escalation bound the generic edge above applies to
      // engineering review. Only `engineeringReview` can route here, so the
      // `humanQaApproval` member of the set above is dropped rather than
      // copied — widening this guard to types that can never reach it would be
      // noise, and dropping the bound entirely would be an unbounded loop.
      GuardConditions.escalationIndexWithinLimitForDecisionTypes(
        escalationDecisionTypes: {HumanDecisionType.engineeringReview},
      ),
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
    // REJECTED ENGINEERING REVIEW — retargeted from `agentExecuting` to the
    // dispatchable `designNotRequired`.
    //
    // This edge WAS reachable and WAS a stranding edge. `reviewRejected` is
    // entered by `waitingForHumanDecision -> reviewRejected` (guards:
    // `actorAllowed([orchestrator])` +
    // `blockingHumanDecisionResolved({(engineeringReview, reject)})` +
    // `decisionActorIsHuman()`), and `HumanDecisionRouting.targetFor` maps
    // `(engineeringReview, reject)` to `reviewRejected`. From there
    // `-> agentExecuting` led to a state no `JobDefinition` lists in
    // `entryStates`, so a rejected review was unrecoverable by machine exactly
    // like a rejected review's `-> designInReview` sibling. Unlike the rework
    // case, the whole chain lives in files this lane owns, so this half is
    // fixed here and now.
    //
    // The guard is UNCHANGED: the old edge carried exactly one guard,
    // `actorAllowed([ActorType.orchestrator])`, and it is preserved verbatim.
    // `reviewRejected` asserts that a review was rejected — it carries no
    // evidence of its own to prove — so there is nothing for a second guard to
    // check, and this matches the table's own convention for the other two
    // edges into `designNotRequired` that the orchestrator alone may take
    // (`planned -> designNotRequired`, and `agentFailed -> designNotRequired`,
    // the operator retry of be75ba1). `agentAvailable()` is absent for the
    // reason given on the rework edge above.
    //
    // The `-> agentExecuting` target is REMOVED rather than supplemented: two
    // legal targets from one state, both dispatchable, is an ambiguity for a
    // caller to resolve, and the stranding one is the one being deleted.
    (WorkItemState.reviewRejected, WorkItemState.designNotRequired): [
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
