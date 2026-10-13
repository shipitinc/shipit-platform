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
    // THE IMPLEMENTATION LANE'S ENTRY EDGE.
    //
    // The guards are copied from `designNotRequired -> agentExecuting` below,
    // which is this table's own convention for an edge INTO `agentExecuting`:
    // such an edge asserts that an agent is starting RIGHT NOW, and capacity is
    // enforced at claim time by `JobCapacityGuard`, not by a guard here.
    //
    // `qaContractExists()` is deliberately ABSENT, and its absence is load-
    // bearing rather than an oversight. That guard belongs on the EXIT edge
    // (`agentExecuting -> agentCompleted`), where the work item carries a
    // `qaContractId`. Putting it here would make this edge unreachable from the
    // scheduler, which has no `AgentResult` and no `qaContractId` to supply —
    // the scheduler would enqueue and the coordinator would refuse every
    // attempt at the cost of a real worker execution. Whether an item MAY be
    // dispatched without a QA contract is `OD-5`; this edge does not decide it,
    // it only refuses to lie about an execution already happening.
    (WorkItemState.implementationReady, WorkItemState.agentExecuting): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.agentAvailable(),
    ],
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
    // REWORK FROM ANY HUMAN GATE — the dispatchable landing state.
    //
    // THIS EDGE IS NOW THE PRODUCTION TARGET, NOT A DEAD BRANCH.
    //
    // It was added by the previous lane as the "landing half" only, because
    // `HumanDecisionRouting.targetFor` — the sole determinant of a resolved
    // decision's target, since `resolveHumanDecision` takes no caller-supplied
    // state — still sent these five routes to `agentExecuting`. The routing
    // table now sends all five here, so this edge is what they actually take.
    // The five, and why each belongs to a "do the work again" gate:
    //
    //   (engineeringReview, rework)  reviewer asked for changes
    //   (qaWaiver,        reject)    QA results refused; work must be redone
    //   (qaRework,        reject)    QA asked for rework, not waiver
    //   (humanQaApproval, reject)    human QA said the result is not good
    //   (escalation,      approve)   a human chose to resume a failure
    //
    // WHY `designNotRequired` AND NOT `agentExecuting`.
    //
    // `agentExecuting` is in the `entryStates` of NO wired `JobDefinition`
    // (triage_defect, implement_feature, design_revision, design_review,
    // engineering_review, baseline_product — none of them lists it), so an item
    // parked there is never dispatched again and nothing will ever run. It also
    // asserts something false: that an execution is ALREADY RUNNING. Landing in
    // it without a dispatch is the same class of defect as `be75ba1`, and it
    // was observed live on `defect-DEF-1791684804452198` on 2026-10-12.
    // `designNotRequired` IS in `triageDefectDefinition.entryStates`, which is
    // the mechanism the operator retry already relies on (commit be75ba1,
    // `agentFailed -> designNotRequired` below). The scheduler therefore
    // re-enqueues with no change to its dispatch path at all.
    //
    // NO GUARD IS RELAXED BY THE WIDENING. `actorAllowed([orchestrator])` and
    // `decisionActorIsHuman()` were already here and still are; the
    // `blockingHumanDecisionResolved` set below is a MEMBERSHIP list, not a
    // permission to skip the other two guards, and it now names exactly the
    // five pairs that route here — so the edge accepts precisely the
    // resolutions it did before plus the three that moved onto it. The
    // generic `waitingForHumanDecision -> agentExecuting` edge above keeps its
    // full six-pair set untouched, so nothing it permitted was withdrawn.
    //
    // CYCLE SAFETY. `designNotRequired -> agentExecuting -> agentCompleted ->
    // reviewInProgress -> waitingForHumanDecision -> designNotRequired` is a
    // cycle, and every traversal of it requires a RESOLVED decision signed by a
    // human decider, bounded by `escalationIndexWithinLimitForDecisionTypes`
    // below. Nothing in it is automatic, so no unattended rework loop is
    // created.
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
        (type: HumanDecisionType.qaWaiver, choice: HumanDecisionChoice.reject),
        (type: HumanDecisionType.qaRework, choice: HumanDecisionChoice.reject),
        (
          type: HumanDecisionType.humanQaApproval,
          choice: HumanDecisionChoice.reject,
        ),
        (
          type: HumanDecisionType.escalation,
          choice: HumanDecisionChoice.approve,
        ),
      }),
      GuardConditions.decisionActorIsHuman(),
      // Mirrors the escalation bound on the generic edge above EXACTLY, for
      // the two decision types that edge bounds among the ones which can now
      // reach here. `humanQaApproval` is added because its rejection moved
      // onto this edge from `agentExecuting` and dropping it would quietly
      // RELAX the bound it already had. `qaRework`, `qaWaiver` and `escalation`
      // are deliberately not added: the generic edge does not bound them
      // either, and inventing a bound here would be new policy rather than a
      // lockstep move.
      GuardConditions.escalationIndexWithinLimitForDecisionTypes(
        escalationDecisionTypes: {
          HumanDecisionType.engineeringReview,
          HumanDecisionType.humanQaApproval,
        },
      ),
    ],
    // THE SAME REWORK GATE, LANDING IN THE IMPLEMENTATION LANE.
    //
    // Design brief §7.5 Obligation A / D-14. `HumanDecisionRouting.targetFor`
    // is the SOLE determinant of where a resolved human decision lands
    // (`DurableWorkflowEngine.resolveHumanDecision` takes no caller-supplied
    // state), so retargeting any of the five "do the work again" pairs to
    // `implementationReady` REQUIRES this edge to exist. Without it the routing
    // table would move a work item to a state nothing leaves, and the engine
    // would throw on resolution — the decision would be answered and the item
    // would sit at its gate with nothing running.
    //
    // The guard set is DELIBERATELY IDENTICAL to
    // `waitingForHumanDecision -> designNotRequired` above: the same
    // `actorAllowed([orchestrator])`, the same six-pair
    // `blockingHumanDecisionResolved` membership list, the same
    // `decisionActorIsHuman()`, and the same `escalationIndexWithinLimitFor
    // DecisionTypes` bound for exactly the two types the other edge bounds.
    // Nothing is relaxed and nothing is added. That is the point: this edge is
    // the landing site a routing retarget will use, so it must already carry
    // the gate that retarget would have to carry — and
    // `implementation_ready_edge_test.dart` fails by name if it ever drifts
    // from the edge it shadows.
    //
    // `agentAvailable()` is absent for the same reason it is absent on every
    // edge that is not `-> agentExecuting`: this edge asserts no execution is
    // starting, only that a resolved human decision may put the item back in
    // the queue. Capacity is `JobCapacityGuard`'s job.
    //
    // WHAT THIS EDGE DOES NOT DO: no `HumanDecisionRouting` entry targets
    // `implementationReady` yet. WHICH of the five pairs move here is `OD-3`,
    // an open product decision, so this lane declares the route and
    // deliberately leaves it unclaimed rather than guessing which rejections
    // mean "re-classify" and which mean "re-do the work".
    (WorkItemState.waitingForHumanDecision, WorkItemState.implementationReady): [
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
        (type: HumanDecisionType.qaWaiver, choice: HumanDecisionChoice.reject),
        (type: HumanDecisionType.qaRework, choice: HumanDecisionChoice.reject),
        (
          type: HumanDecisionType.humanQaApproval,
          choice: HumanDecisionChoice.reject,
        ),
        (
          type: HumanDecisionType.escalation,
          choice: HumanDecisionChoice.approve,
        ),
      }),
      GuardConditions.decisionActorIsHuman(),
      // The same bound, MOVED with the edge rather than invented for it.
      // `qaRework`, `qaWaiver` and `escalation` are deliberately NOT added: the
      // edge this one shadows does not bound them either, and inventing a bound
      // here would be new policy rather than a lockstep move. Dropping
      // `humanQaApproval` would be a silent RELAXATION of a bound it has.
      GuardConditions.escalationIndexWithinLimitForDecisionTypes(
        escalationDecisionTypes: {
          HumanDecisionType.engineeringReview,
          HumanDecisionType.humanQaApproval,
        },
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
