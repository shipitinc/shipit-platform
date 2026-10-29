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
    (WorkItemState.planned, WorkItemState.featureIntakeParked): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
    // INTO THE DESIGN PARK (R2.2). Deliberately NO evidence guard and no
    // `designContractExists()`: parking is the refusal to proceed, so the
    // absence of a design contract is the POINT rather than a bar. It is
    // asserted by the presence of this edge's successor instead.
    //
    // It adds NO predecessor to `planned` — the edge points away from it — so
    // `planned_entry_state_hop_test`'s sole-predecessor pin (which asserts
    // `planning` and nothing else) is untouched. `planned`'s successor
    // assertion there is `containsAll`, not set equality, so a third successor
    // is not a break.
    (WorkItemState.planned, WorkItemState.designParked): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
    // THE WAY OUT OF THE FEATURE PARK. `featureIntakeParked` is in the
    // entryStates of NO wired JobDefinition, so an item parked here is
    // dispatchable by nobody -- the point of the state. Without an edge out it
    // would be a terminal state nobody can leave, which is the same class of
    // defect this state was created to end.
    //
    // `waitingForHumanDecision` is the operator route: a human can resolve the
    // gate and route the item onward (`evaluate` returns `blocked` there, not
    // `runnable`, so parking at the gate grants no dispatch). `cancelled` and
    // `terminated` come free from `_isGenericEscape`.
    //
    // DELIBERATELY NO EDGE BACK TO `planned`. `planned_entry_state_hop_test`
    // asserts `planning -> planned` is the ONLY edge into `planned`, so the
    // scheduler's `planned -> designNotRequired` hop can never cycle. An edge
    // from here to `planned` would give it a second predecessor and re-open
    // exactly the loop that invariant exists to close. Recovery is via the
    // human gate, which is slower and deliberately so.
    (
      WorkItemState.featureIntakeParked,
      WorkItemState.waitingForHumanDecision,
    ): [
      GuardConditions.actorAllowed([ActorType.human, ActorType.orchestrator]),
    ],
    // THE RELEASE OUT OF THE DESIGN PARK (R2.3) — the edge that stops
    // `designParked` being the terminal-state-nobody-can-leave defect
    // `featureIntakeParked`'s own comment (:34-38) says it exists to end.
    //
    // `designContractExists()` is the SAME guard `planned -> designRequired`
    // (:24-27) carries, and it is load-bearing twice over: it reads the work
    // item's DURABLE `designContractId` column and confirms it against a
    // `DesignContractStore`, so a caller cannot release an item into design
    // work by passing a string in transition context.
    //
    // WHO TAKES IT. Because `designParked` is in no definition's `entryStates`,
    // no scheduler hop can move an item resting here — which is exactly what
    // makes the release safe rather than a race: while the item is parked it is
    // invisible to every scheduler, so there is no competing write and no
    // window. The release is taken by the runtime's readiness reconciler, which
    // reads the durable column and acts when it is non-null.
    (WorkItemState.designParked, WorkItemState.designRequired): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.designContractExists(),
    ],
    // THE OPERATOR ROUTE OUT OF THE DESIGN PARK (R2.4). Mirrors
    // `featureIntakeParked -> waitingForHumanDecision` above (:51-56): a human
    // can resolve the gate and route the item onward, and `evaluate` returns
    // `blocked` at `waitingForHumanDecision` rather than `runnable`, so parking
    // at the gate grants no dispatch.
    //
    // `cancelled`/`terminated` come free from `_isGenericEscape`.
    //
    // DELIBERATELY NO EDGE BACK TO `planned`, for the reason given above the
    // feature park's way-out: `planning -> planned` is the only edge into
    // `planned` and a second predecessor re-opens the loop that invariant
    // exists to close. Recovery is via the human gate, which is slower and
    // deliberately so.
    (WorkItemState.designParked, WorkItemState.waitingForHumanDecision): [
      GuardConditions.actorAllowed([ActorType.human, ActorType.orchestrator]),
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
        // The design-review park's "do the design review". Same target state,
        // and a different question: `designApproval` answers "is this design
        // good", this one asks for one. A NEW TYPE is admitted by no edge until
        // it is added here, so without this pair the park's answer would be
        // saved RESOLVED and the item would not move.
        (
          type: HumanDecisionType.designReviewRequest,
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
    (WorkItemState.designApproved, WorkItemState.implementationReady): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
    (WorkItemState.designApproved, WorkItemState.agentExecuting): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
      GuardConditions.agentAvailable(),
    ],
    (WorkItemState.designRejected, WorkItemState.designInReview): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
    // THE DESIGN REVISION LANE'S RE-ENTRY EDGE.
    //
    // A rejected design is redesign work, and redesign is what a design agent
    // does from `designRequired` — not what a REVIEWER does from
    // `designInReview`. Without this edge a `designRejected` item was inert:
    // `designRevisionDefinition` declares it as an entry state, the probe
    // refused `designRejected -> agentExecuting`, and the state had exactly one
    // out-edge leading to another lane's entry state.
    //
    // This edge and `designRevisionDefinition.entryProbeTargets[designRejected]
    // = designRequired` are a PAIR. The scheduler's probe (`RunnableWorkEvaluator`)
    // runs the pure `WorkflowEngine` with no store and no work item, so it
    // cannot supply a `DesignContractResolution`; `designContractExists()` is
    // therefore deliberately ABSENT here, exactly as it is absent from the
    // `implementationReady -> agentExecuting` edge for the same reason. Adding
    // it would make the probe fail closed and the hop unreachable. The item
    // already carried a confirmed contract to reach `designRequired` in the
    // first place; dispatch-time capacity is `JobCapacityGuard`'s concern.
    //
    // `design-revision.md` §5.4 (a): this guard set is the EXACT set the design
    // names — no extra guard is a silent narrowing of a reviewed decision.
    (WorkItemState.designRejected, WorkItemState.designRequired): [
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
    // THE RECOVERY EDGE for a feature item that took the old bad hop before
    // `featureIntakeParked` existed. `_parkFeature` used to walk a feature to
    // `planned` and leave it there, and `planned` became a `triageDefect`
    // entry state, so the scheduler -- which is category-blind -- dispatched
    // the feature as a defect and advanced it to `agentExecuting`. This edge is
    // the sanctioned way back out. The scheduler cannot originate it:
    // `EntryHopper` may only land a hop on its OWN definition's entry states,
    // and `featureIntakeParked` is in none of them.
    (WorkItemState.agentExecuting, WorkItemState.featureIntakeParked): [
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
    // THE RETRY RETURN EDGES — decision `3659984d-4e2a-4625-81ff-37aa73252375`
    // (option A): a RETRYABLE execution failure returns the work item to the
    // ENTRY STATE OF THE LANE WHOSE JOB FAILED.
    //
    // ## THE DEFECT THESE EXIST TO END
    //
    // A transient execution failure leaves the work item OUTSIDE its lane's
    // `entryStates` — `agentExecuting -> agentFailed` for every ordinary role,
    // and `reviewInProgress` for the engineering reviewer, which the coordinator
    // deliberately leaves alone. Meanwhile `Scheduler._adopt` parks the job at
    // `retryWaiting` with a live `availableAt`.
    //
    // `RunnableWorkEvaluator.evaluate` rejects any item outside `entryStates`
    // BEFORE it consults the policy, so the next tick classified it `noAction`,
    // and `Scheduler._retireSupersededForItem` CANCELLED the very retry that had
    // just been scheduled. `cancelledQueued` is not in the drain's
    // `dispatched ∪ terminal ∪ reconciled` union, so nothing raised an operator
    // signal either. No retry has ever run on any `Scheduler` lane. Every
    // `maxAttempts` in this platform was unreachable for exactly the failures
    // it exists for.
    //
    // ## WHY THE ITEM IS RETURNED RATHER THAN THE SCHEDULER RELEASED
    //
    // The rejected alternative (option B) taught the scheduler to honour a retry
    // for an item OUTSIDE `entryStates`. That leaves the work item in a state no
    // lane dispatches from, which is the invariant itself: the one-element entry
    // sets are exactly what make the triage/implementation dispatch collision
    // STRUCTURALLY UNREACHABLE. Every edge below therefore lands on a state
    // that is ALREADY an entry state of some wired `JobDefinition`. None of them
    // adds a state to any entry set, and
    // `packages/scheduler/test/implement_feature_entry_disjointness_test.dart`
    // plus `retry_return_to_entry_state_test.dart` fail by name if one ever does.
    //
    // ## WHY THE RETURN IS CONDITIONAL AND NOT UNCONDITIONAL
    //
    // The trigger is not "the execution failed". It is "a RETRYABLE failure
    // left a bounded retry owed", which the scheduler decides from durable job
    // state (`JobState.retryWaiting` + `JobFailureKind.transient` +
    // `RetryPolicy.canRetry`). A PERMANENT failure settles the job terminally
    // `failed`, so no return is owed and the item stays at `agentFailed` for a
    // human. A crash and a timeout therefore still behave differently, which is
    // the whole point of the classification work these edges complete.
    //
    // ## WHY EXACTLY ONE EDGE PER ENTRY SET, AND NOT ONE PER ENTRY STATE
    //
    // The scheduler derives its return target from the POLICY, not from a list
    // written here: it asks which of its own `entryStates` is reachable from the
    // state the failure left behind, and moves the item there only when exactly
    // ONE answer comes back (`Scheduler._returnRetryableItemsToEntryStates`).
    // That makes the edges below load-bearing in both directions. A lane needs
    // one reachable entry state or the return is REFUSED and reported; two or
    // more is an ambiguity, and is refused too. So `agentFailed -> designApproved`
    // and `agentFailed -> reviewRejected` are DELIBERATELY ABSENT: adding either
    // would make `triageDefectDefinition`'s return ambiguous and silently disable
    // the retry for every lane that dispatches from `agentFailed`.
    //
    // ## WHY THE GUARD SET IS `actorAllowed([orchestrator])` ALONE
    //
    // Derived from this table's own convention for an edge into an entry state
    // that asserts no execution is starting — `planned -> designNotRequired`
    // (:28) and `agentFailed -> designNotRequired` (:149) both carry exactly
    // that and nothing else. `agentAvailable()` belongs only on `->
    // agentExecuting` edges, where the transition claims an agent is starting
    // RIGHT NOW; a return claims no such thing, and capacity is enforced at
    // claim time by `JobCapacityGuard` exactly as it is for every other job.
    //
    // No evidence guard either, and deliberately: the only evidence these edges
    // could demand is the failed `AgentResult`, and the scheduler has no
    // execution of its own to read it from (which is precisely why
    // `engineeringReviewDefinition.skipWorkflowPolicyCheck` is true). A guard
    // that cannot be satisfied by the actor taking the edge is a guard that
    // makes the edge unreachable and the retry dead again — the same reasoning
    // that put `OD-10`'s `agentCompleted -> implementationReady` edge on
    // `actorAllowed` alone (:209).
    //
    // The orchestrator actor type is also what makes the RETURN separable from a
    // HUMAN decision: every edge below is reachable by any orchestrator, so
    // `Scheduler`'s automatic return and a human-driven rework both use this
    // table, and neither one bypasses it.
    (WorkItemState.agentFailed, WorkItemState.implementationReady): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
    // The design agent's entry state. `designRevisionDefinition` declares
    // `{designRequired, designRejected}`; only `designRequired` is reachable from
    // `agentFailed`, so the scheduler's derivation resolves uniquely.
    //
    // `designRejected` is deliberately NOT given an edge here even though it is
    // in the same set: a rejected design is a HUMAN verdict and re-running the
    // designer would quietly overturn it. One reachable answer per lane is what
    // keeps this unambiguous; see the derivation note above.
    (WorkItemState.agentFailed, WorkItemState.designRequired): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
    // The design reviewer's entry state, for `designReviewDefinition`.
    (WorkItemState.agentFailed, WorkItemState.designInReview): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
    /*** Engineering review ***/
    // THE IMPLEMENTATION LANE'S INFLOW EDGE — `OD-10`.
    //
    // `targetFor` decides where a resolved human decision lands, and it has
    // no say over anything else. An item whose producer has FINISHED and left
    // no commit is not at a decision — it is at `agentCompleted`, which is
    // triage's exit state and `engineeringReviewDefinition.entryStates`, and
    // which the review lane then fails closed on for ever, because there is no
    // artifact to review. This edge is what that item takes instead.
    //
    // ## WHY NOT `designNotRequired -> implementationReady`
    //
    // Because `designNotRequired` is triage's ENTRY state and its only outgoing
    // edge is the dispatch that runs triage. An edge into `implementationReady`
    // from there would compete with that dispatch and could route an item into
    // the build queue WITHOUT TRIAGE EVER RUNNING — an item nobody classified,
    // built. The decision that named this edge (`OD-10`) recorded the operator's
    // intent as "After TRIAGE COMPLETES, the item goes to implementationReady",
    // and triage completing means the item is at `agentCompleted`. So that is
    // where it is.
    //
    // ## WHY NO `agentResultValid()`
    //
    // The sibling edge `(agentCompleted, reviewInProgress)` carries it, because
    // its caller — the execution coordinator, starting a reviewer — can supply
    // the producer's `AgentResult` from the store. The scheduler cannot: it has
    // no execution of its own, which is exactly why
    // `engineeringReviewDefinition.skipWorkflowPolicyCheck` is `true`. A guard
    // that cannot be satisfied here is a guard that makes this edge unreachable,
    // and `RunnableWorkEvaluator` would classify every routed item `noAction`
    // for ever — the inert item, with a worse story than before.
    //
    // Its evidence is not absent, it is already accounted for: the only edge
    // INTO `agentCompleted` is `(agentExecuting, agentCompleted)`, guarded by
    // BOTH `qaContractExists()` AND `agentResultValid()`. Arriving here already
    // asserts that a completed, valid result exists.
    //
    // ## WHY THE GUARD IS `actorAllowed([orchestrator])` ALONE
    //
    // This is this table's own convention for an edge into an entry state that
    // asserts no execution is starting: `planned -> designNotRequired` and
    // `agentFailed -> designNotRequired` both carry exactly that, and neither
    // carries `agentAvailable()`. That guard belongs on `-> agentExecuting`
    // edges, where the transition asserts an agent is starting RIGHT NOW. This
    // edge asserts no such thing, and capacity is enforced at claim time by
    // `JobCapacityGuard` exactly as it is for every other job.
    //
    // ## WHAT IS DELIBERATELY NOT GUARDED HERE
    //
    // The artifact question — "did the producer leave a commit?" — is NOT a
    // guard, and cannot be: guards read `context`, so encoding it as one would
    // move the decision to whoever builds the context map rather than settle
    // it, and two call sites would then answer it differently. It is one named
    // function, `producedCommitFor` (`packages/scheduler`), which reads the
    // same durable rows under the same rules as the review gate's workload
    // resolver. The caller must supply that answer; the table's job here is to
    // make the destination legal and the actor honest, and nothing more.
    (WorkItemState.agentCompleted, WorkItemState.implementationReady): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
    ],
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
    // THE REVIEW LANE'S RETRY RETURN — decision
    // `3659984d-4e2a-4625-81ff-37aa73252375` (option A).
    //
    // ## WHY THIS EDGE AND NOT `reviewInProgress -> agentFailed`
    //
    // The engineering reviewer is the ONE role the coordinator settles
    // differently: `ExecutionCoordinator._completeFailure` and `_failWithoutSession`
    // both skip the `agentFailed` transition for `AgentRole.engineeringReviewer`,
    // so a reviewer that crashes leaves its work item AT `reviewInProgress`
    // rather than moving it. That is the correct call — an unreviewed item must
    // not be filed as a failed coding result — and it is exactly what made this
    // lane the worst case of the retry defect: the item was neither back in
    // `engineeringReviewDefinition.entryStates` (`{agentCompleted}`) nor in a
    // state a human would recognise as failed. It simply sat at
    // `reviewInProgress`, looking like a review in progress, with its job
    // cancelled as superseded one tick later and nobody told.
    //
    // `agentCompleted` IS the review lane's entry state, so returning there is
    // the option-A shape: a RETURN to an existing entry state, never a widening.
    // The next tick classifies the item `runnable` and the scheduled retry is
    // claimed for real.
    //
    // ## THIS EDGE DOES NOT APPROVE ANYTHING
    //
    // It is not the review verdict and it must never be mistaken for one. The
    // verdict is raised as a blocking `engineeringReview` `HumanDecision` through
    // the edge above, and the only routes OUT of `agentCompleted` are
    // `-> implementationReady` (`OD-10`'s inflow), `-> reviewInProgress`
    // (this lane dispatching again) and `-> designInReview`. None of them
    // reaches `reviewApproved`, so no orchestrator can use this edge to push
    // unreviewed work through the approval gate: returning the item puts it
    // back in front of a reviewer, which is the entire intent.
    //
    // ## WHY NO `agentResultValid()`
    //
    // The sibling entry edge `agentCompleted -> reviewInProgress` (:212) carries
    // it, because its caller — the coordinator starting a reviewer — can supply
    // the IMPLEMENTER's completed `AgentResult` from the store. The scheduler
    // cannot, for exactly the reason
    // `engineeringReviewDefinition.skipWorkflowPolicyCheck` is true, and adding
    // the guard here would make this edge unreachable from the only actor that
    // needs it and the review lane's retry dead again. The evidence is not
    // absent, either: the only edge INTO `agentCompleted` is
    // `(agentExecuting, agentCompleted)`, guarded by BOTH `qaContractExists()`
    // AND `agentResultValid()`. Arriving there already asserted a completed,
    // valid result exists, and nothing on the way out of it needs it again.
    //
    // ## WHY `actorAllowed([orchestrator])` ALONE
    //
    // This table's own convention for an edge into an entry state that asserts
    // no execution is starting: `planned -> designNotRequired` (:28),
    // `agentFailed -> designNotRequired` and `agentCompleted ->
    // implementationReady` (:209) all carry exactly that.
    //
    // `actorIsNotSelf()` is deliberately NOT carried across from the edge above.
    // It exists to stop a reviewer approving its OWN review, and it works by
    // comparing the acting actor's id against the `producerActorId` stamped on
    // the item — data only the coordinator has. The actor taking this edge is
    // the scheduler's `orchestrator`, which is not a reviewer and holds no
    // execution at all, so the guard could never fail here; copying it would
    // add an unevaluable check that reads as a guarantee it does not give.
    (WorkItemState.reviewInProgress, WorkItemState.agentCompleted): [
      GuardConditions.actorAllowed([ActorType.orchestrator]),
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
        // The design-review park's "re-triage" answer. It lands on
        // `designNotRequired` because that is the state triage dispatches from
        // — byte-identically to `(escalation, approve)` above — so the routing
        // precedent is this edge's own.
        //
        // DELIBERATELY NOT added to the bound below. See that guard's comment:
        // `qaRework`, `qaWaiver` and `escalation` are not bounded either, and
        // `escalation` is the identical operator-invoked loop to the same
        // target on this same edge. A ceiling on re-triage — "how many times
        // may an operator re-triage an item?" — is product policy, not a
        // lockstep move, and is recorded as an open question rather than taken
        // here. `packages/workflow_engine/test/design_review_park_surface_test.dart` pins this absence
        // from both sides: a bounded pair fails this edge, this pair does not.
        (
          type: HumanDecisionType.designReviewRequest,
          choice: HumanDecisionChoice.reTriage,
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
      // lockstep move. `designReviewRequest` is not added for the SAME reason,
      // and it is named here because it is the newest type to reach this edge:
      // its `reTriage` answer is the same operator-invoked loop to the same
      // target as `(escalation, approve)`, so `(escalation, approve)` not
      // being bounded is a precedent for it rather than an argument against
      // bounding it. Whether an operator may re-triage an item a bounded number
      // of times is product policy and is an open question, not a lockstep
      // move; `packages/workflow_engine/test/design_review_park_surface_test.dart` pins the absence.
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
    (
      WorkItemState.waitingForHumanDecision,
      WorkItemState.implementationReady,
    ): [
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
        // The design-review park's "put it back in the lane" answer — the same
        // target `(escalation, rework)` above names, asked at a different gate.
        (
          type: HumanDecisionType.designReviewRequest,
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
