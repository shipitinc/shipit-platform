# Design Review Gate Spec — the HD-1 gate

**Parent:** [`design-revision.md`](./design-revision.md) §4 — deliverable 2
**Governing decision:** `.decisions/2a8f5c31-9d47-4e6b-b2f8-7c15e0d9a4b2.yaml` (HD-1, RESOLVED)
**Authoring HEAD:** `e3634a0cbbdf656267b22908284dd1ae8b655085` (revision 1)
**Corrected at:** `c8fd361906f0d831bbcfd431b75d1eb21ae9db5d` (revision 2, correction lane
`design-QA-CONTRACTS-CORRECTION`)
**Status of this document:** a specification. This lane implements no production code.

---

## 1. The invariant being designed to

HD-1's `delegated` clause, quoted in full because its two halves are the whole design problem:

> The gate's SHAPE is a design question and is delegated to the design lane: where the review sits
> in the graph, which actor satisfies it, what happens to an item that never gets one, and whether a
> defect-origin item takes the same path. **What is NOT delegated is that an IMPLEMENTER dispatch
> must be preceded by a satisfied design review for items originating on these two paths.**

And its `rationale_given`:

> Refusing completion outright was also rejected: it re-creates the dead end this work exists to
> remove, leaving two of three intake paths unable to run at all. The chosen middle keeps both intake
> paths alive while refusing to let an unreviewed request reach implementation **unattended**.

**Revision 1 read "unattended" out of the rationale and left the human edge unguarded.** Independent
review found that this reads the word out of the wrong half of the decision, and this revision
specifies the opposite reading. **§5.2 states it in full, says why, and marks it as the single point
an independent `design-reviewer` must judge.** It is not treated as settled here.

---

## 2. The exposure, located

`implementationReady` is the **only** state that dispatches an `AgentRole.implementer` in a wired
lane:

```dart
// packages/scheduler/lib/src/implement_feature.dart:110-118
const JobDefinition implementFeatureDefinition = JobDefinition(
  jobType: JobType.implementFeature,
  requiredRole: AgentRole.implementer,                  // :112
  entryStates: {WorkItemState.implementationReady},    // :114
  completionInflowFrom: {WorkItemState.agentCompleted},// :117  ← THE ONLY completionInflowFrom
);
```

Reached by `(implementationReady, agentExecuting)`
(`packages/workflow_engine/lib/src/transitions/work_item_transitions.dart:135-138`), guarded only by
`actorAllowed([orchestrator])` and `agentAvailable()`.

`implementationReady` has exactly **three** in-edges, and **only one of them has a caller**:

| # | Edge | Line | Guard today | Who takes it |
|---|---|---|---|---|
| 1 | `agentCompleted -> implementationReady` | `:340-342` | `actorAllowed([orchestrator])` | **`Scheduler._routeOneCompletion`** — the one automatic route. Reachable. |
| 2 | `agentFailed -> implementationReady` | `:265-267` | `actorAllowed([orchestrator])` | **NOBODY.** See below. |
| 3 | `waitingForHumanDecision -> implementationReady` | `:599-602` | `actorAllowed([orchestrator])` + `blockingHumanDecisionResolved({…})` + `decisionActorIsHuman()` + `escalationIndexWithinLimitForDecisionTypes` | A human-driven route. Reachable in principle; **not for the two intake origins today** — §5.3. |

### 2.1 Route 2 has no caller, and revision 1 said it did

Revision 1's table marked routes 1 **and** 2 as "**automatic**" and placed the guard on both.
**That was wrong**, and independent review was right to fail it. Verified:

- the **only** `completionInflowFrom` in the repository is
  `{WorkItemState.agentCompleted}` (`implement_feature.dart:117`) — verified by
  `grep -rn completionInflowFrom packages apps`, which returns this one production line plus
  `runnable_work.dart:49,128,132` (the field itself) and tests;
- the completion inflow filters by it — `if (!sources.contains(item.state)) continue;`
  (`packages/scheduler/lib/src/scheduler.dart:1522`) — so an item at `agentFailed` is skipped before
  any routing is attempted;
- **no production code calls `transition(to: WorkItemState.implementationReady)`.** The only
  production sites are the three table rows (`:265`, `:340`, `:601`) and
  `human_decision_routing.dart:100-120, 204-206`, which is the routing table *returning a target*,
  not a caller. Every actual `to: WorkItemState.implementationReady` call site in the tree is in a
  `*_test.dart`.

**So route 2 is a declared edge with no caller** — the same defect class as
`reviewApproved -> qaInProgress` (`design-revision.md` §2.1, corrected) and the one `server.dart:1327-1330`
records this repository as shipping once.

**The design does not place the guard on route 2, and says why.** A guard on an edge no caller takes
reads `context['workItemOrigin']` from a context nobody built, returns `pass` because the map is
empty, and **can never fail**. That is not defence in depth; it is an assertion that looks like one
in review and is inert in production. Placing it would let a future caller add the route believing
the gate was already there.

Route 2's guard is instead covered by **G11** (§6), a drift assertion that *fails if the guard is
absent from route 2 **and** any production caller of `agentFailed -> implementationReady` appears.
That is the correct time to add it: with the caller, not before it.

### 2.2 Route 1 is the one automatic route, and why it exists

The path that reaches route 1 is named:

```dart
// packages/scheduler/lib/src/implementation_inflow.dart:437-440
WorkItemState completionRouteFor(ProducedCommit produced) => switch (produced) {
  CommitProduced() => WorkItemState.reviewInProgress,
  NoCommitProduced() => WorkItemState.implementationReady,
};
```

A triage run commits nothing — *"the producing execution reached … and finished at …, so it committed
no code. It produced a report, not an artifact"*
(`implementation_inflow.dart:383-390`) — so it takes `NoCommitProduced` and lands on
`implementationReady`. That is the operator's recorded intent, verbatim: *"After triage completes,
the item goes to implementationReady instead of waiting at a human gate"*
(`implementation_inflow.dart:406-407`).

**This is why the gate belongs on the edge and not on the lane:** `completionRouteFor` is correct,
and HD-1 did not ask to change it. HD-1 asks that the *destination* be refused for two origins.

---

## 3. Why the gate is a guard and not a state

Three facts about the design lane, each verified at `e3634a0`.

### 3.1 No scheduler dispatches it

`apps/server/lib/server.dart` constructs exactly three `Scheduler` instances:

| Line | `schedulerId` | `definition` |
|---|---|---|
| `:475-481` | `sched-triage` | `triageDefectDefinition` |
| `:523-529` | `sched-review` | `engineeringReviewDefinition` |
| `:706-712` | `sched-impl` | `implementFeatureDefinition` |

`designRevisionDefinition` (`packages/scheduler/lib/src/scheduler.dart:3255-3265`) and
`designReviewDefinition` (`:3269-3280`) are declared and exported
(`packages/scheduler/lib/scheduler.dart:31-32`) and **never instantiated**. ADR 0021:112 states the
same from the governance side.

### 3.2 The design lane and the implementation lane are disconnected

There is **no edge from any design state to `implementationReady`.** The three in-edges are listed
in §2, and none starts at a design state.

**And `designApproved` is a trap.** Its only out-edge is `designApproved -> agentExecuting`
(`:111-114`), and it is in `triageDefectDefinition.entryStates`
(`packages/scheduler/lib/src/triage_defect.dart:128`). So an approved design routes the item into
**triage**, not implementation. `defaultImplementFeatureDefinition` (`scheduler.dart:3196-3203`) is
the one definition listing `designApproved` in `entryStates` — and it is not wired either.

### 3.3 `designInReview -> designApproved` does not exist

Approval is reachable only from `waitingForHumanDecision` (`:73-82`), guarded by
`decisionActorIsHuman()`. There is no `designInReview -> designApproved` edge, and
`designRequired -> designInReview` (`:55-58`) requires
`GuardConditions.designContractUnderReview()`, which reads `context['designContractStatus']`
(`guard_conditions.dart:166-168`) — a key `DurableWorkflowEngine.transition` **discards**
(`packages/workflow_store/lib/src/durable_workflow_engine.dart:173`, `:211-233`). This is the exact
defect `lane_e_design_remediation_work_item.dart:116-123` documents and stopped to avoid.

`designInReview` has exactly two out-edges: `-> waitingForHumanDecision` (`:63`) and
`-> agentExecuting` (`:69`). It is `designReviewDefinition.entryStates`
(`packages/scheduler/lib/src/scheduler.dart:3276`) — declared, exported, and **never instantiated**
(§3.1). **So an item parked at `designInReview` is dispatchable by nobody only by accident of an
unwired scheduler.** This design does not park there; §5.1 explains why an accidental invariant is
not a park.

### 3.4 The conclusion

A gate placed on the design states could never be satisfied, and a gate placed on the path *through*
`designApproved` would route the item into triage. **The only reachable placement is a precondition
on the route into `implementationReady`.**

And it can be an **artifact** precondition rather than a state walk, because the artifact's
persistence layer already exists (§4).

### 3.5 A new state **is** required, and revision 1 was wrong to exclude it

Revision 1 rejected a new state here, on the grounds that *"one guard on an existing edge cannot
create that failure, because a refused guard leaves the item exactly where it was, in a state that
already has exits."*

**The premise is false, and this is the BLOCKING finding of the independent review.** Leaving the
item where it was is only safe if *something* takes it from there. For the two intake origins at
`agentCompleted`, **nothing does** — §5.1. The guard leaves the item in a state whose only escape is
an edge the gate has just closed, and a refusal is therefore indistinguishable from a scheduler that
stopped ticking.

**A new state is the correction, and the precedent for it already shipped in this repository.**
`featureIntakeParked` (`work_item_transitions.dart:31-53`) is exactly this shape, built by `ddfbfff`
/ F-48 for exactly this problem:

```dart
(WorkItemState.planned, WorkItemState.featureIntakeParked): [       // :31-33
  GuardConditions.actorAllowed([ActorType.orchestrator]),
],
// THE WAY OUT OF THE FEATURE PARK. `featureIntakeParked` is in the
// entryStates of NO wired JobDefinition, so an item parked here is
// dispatchable by nobody -- the point of the state. Without an edge out it
// would be a terminal state nobody can leave, which is the same class of
// defect this state was created to end.
(WorkItemState.featureIntakeParked, WorkItemState.waitingForHumanDecision): [   // :51-53
  GuardConditions.actorAllowed([ActorType.human, ActorType.orchestrator]),
],
```

**No edge back** — `:45-50` records why (`planned_entry_state_hop_test` asserts `planning -> planned`
is the only edge into `planned`; a second predecessor re-opens the loop that invariant closes).

The revision's non-goal "**Not** a new `WorkItemState`" is therefore **withdrawn**; §5.1 specifies
the state and §11 records the reversal and what it costs. `design-revision.md` R3's mitigation is
withdrawn with it.

---

## 4. The guard

### 4.1 Placement

Add one guard to **two existing edges that have callers**, and to **one more that revision 1 left
open**. No edge is added, removed, or retargeted *in this sub-slice*; the two new park edges are
§5.1 and §6 sub-slice 1d.

```dart
// work_item_transitions.dart
(WorkItemState.agentCompleted, WorkItemState.implementationReady): [   // :340-342
  GuardConditions.actorAllowed([ActorType.orchestrator]),
  GuardConditions.intakeDesignReviewSatisfied(),                      // ← ADDED
],

(WorkItemState.waitingForHumanDecision, WorkItemState.implementationReady): [  // :599-602
  GuardConditions.actorAllowed([ActorType.orchestrator]),
  GuardConditions.blockingHumanDecisionResolved({ …unchanged… }),      // :604-624
  GuardConditions.intakeDesignReviewSatisfied(),                      // ← ADDED
  GuardConditions.decisionActorIsHuman(),                              // :624 unchanged
  GuardConditions.escalationIndexWithinLimitForDecisionTypes( … ),    // unchanged
],
```

**The guard is added to route 3 — the human-driven edge — and that is the substance of §5.2.**
Revision 1 deliberately omitted it. It is no longer omitted.

**It is NOT added to `(agentFailed, implementationReady)` (`:265-267`)** — that edge has no caller
(§2.1), so a guard there is inert, and G11 covers the day one appears.

**It is NOT added to `(implementationReady, agentExecuting)` (`:135-138`)** — §5.1, and G6.

### 4.2 What it reads

```dart
class _IntakeDesignReviewSatisfiedGuard extends GuardCondition<WorkItemState> {
  @override String get name => 'intake_design_review_satisfied';

  @override
  GuardResult evaluate(WorkflowState<WorkItemState> from,
                       WorkflowState<WorkItemState> to,
                       Map<String, dynamic>? context) {
    final origin = context?['workItemOrigin'] as String?;

    // INERT for every other origin. The guard is a precondition on two
    // origins, not a policy for the platform.
    if (origin != 'featureIntake' && origin != 'designRemediation') {
      return GuardResult.pass(name);
    }

    final revisionId = context?['approvedDesignRevisionId'] as String?;
    return revisionId != null
        ? GuardResult.pass(name)
        : GuardResult.fail(name,
            'This work item originated on feature intake or design remediation, '
            'so an APPROVED design revision is required before it may be routed '
            'to implementation. No approved design revision exists for it, and '
            'no design lane has produced one.');
  }
}
```

| Key | Type | Supplied by | Meaning |
|---|---|---|---|
| `workItemOrigin` | `String?` | the routing component, derived from `WorkItem.workItemId`'s prefix | `featureIntake` \| `designRemediation` \| anything else ⇒ inert |
| `approvedDesignRevisionId` | `String?` | the routing component, after `readApprovedDesignRevisionForWorkItem` | non-null ⇒ satisfied |

### 4.3 The fact it reads is real, durable, and already implemented

```dart
// packages/design_governance/lib/src/store/design_revision_store.dart:16-19
/// Reads the currently approved design revision for a work item, if any.
Future<DesignRevision?> readApprovedDesignRevisionForWorkItem(String workItemId);
```

```sql
-- apps/server/lib/src/persistence/postgres_design_governance_store.dart:46-60
SELECT * FROM "design_revision"
 WHERE "workItemId" = @workItemId AND "status" = @status   -- 'approved'
```

Backed by a real table (migrations `20260928233022000`, `20261012145629000`) and a real status
whose transition into it is itself constrained:

```dart
// packages/platform_contracts/lib/src/enums/design_revision_status.dart:24-28
bool get canTransitionToApproved => switch (this) {
  DesignRevisionStatus.reviewPassed => true,
  DesignRevisionStatus.humanApprovalRequired => true,
  _ => false,
};
```

**So the fact the guard reads — "this work item has a design revision that passed independent
review and, where the risk tier requires it, human approval" — is not a flag anyone sets. It is a
durable row whose status the type refuses to enter without passing review first.** That is the
strongest form the gate could take given what exists, and it is the direct answer to
`design-brief.md` §6's assumption that the design-review artifact would have to be invented.

**It is nevertheless `DECLARED` today, not `PASSING`:** nothing writes those rows
(`design-revision.md` §6, M5–M7). The guard will therefore refuse **every** intake item in the
current deployment. That is correct under HD-1, and it is called out in `design-revision.md` §13.2
so nobody discovers it in staging.

### 4.4 The one property this design cannot give the guard

A `GuardCondition` reads `context` and nothing else. `DurableWorkflowEngine.transition` hands the
whole map to the policy (`packages/workflow_store/lib/src/durable_workflow_engine.dart:173`,
`context: {'workItemId': workItemId, ...context}`) and then reads back **exactly two keys of its
own** — `humanDecision` (`:216`) and `blockingReason` (`:223`) — both of which it writes into the
item itself.

**Stated precisely, because revision 1 overstated it:** the engine does not persist "nothing" from
`context`; it persists **no guard-supplied key**. The load-bearing claim survives the correction —
a key a `GuardCondition` reads is not durable, so the guard is re-evaluated from whatever the caller
supplied on this attempt and from nothing else. `qaContractExists()` is the same shape
(`guard_conditions.dart:247`, a null-check on `context['qaContractId']`).

This is not a defect of this design — it is the platform's existing enforcement model, and the
closest precedent says so itself: `qaContractExists()` null-checks `context['qaContractId']`
(`guard_conditions.dart:247`), and the transition table's comment states that the guard sits on the
`agentExecuting -> agentCompleted` edge precisely *because* the coordinator there can supply the id
from the store while the scheduler cannot (`work_item_transitions.dart:126-134`).

**What the design must therefore do is name the component and make it the only writer.** §6,
sub-slice 1b.

### 4.5 Which actor satisfies it

**A human**, today — not an agent.

That is a consequence of §3, not a preference. An agent design review requires a dispatcher for
`designReviewDefinition` (absent, §3.1), a reachable `designInReview` (blocked on a discarded
context key, §3.3), and a producer for `DesignRevision` (absent). Until M5–M7 land, the only thing
that can produce a `status: approved` row is a human acting through the design-governance surface.
ADR 0021:126-127 already names that gate: `HUMAN_DESIGN_APPROVAL_REQUIRED` is a `HumanDecision`
with `decisionType: designApproval`, *"reuses existing machinery"*.

Once M5–M7 land, the same guard is satisfied by a machine-produced approved revision with **no
change to the guard** — because it reads the artifact, not the actor. **The guard is
actor-agnostic by construction, and that is the property worth having.**

---

## 5. The dead-end question, answered — and the one reading an independent reviewer must judge

> *"What happens to an item that never gets one — it must not become a new dead end. The lesson of
> this session is that a state nothing leaves is worse than one nothing enters."*

### 5.1 The refusal sink — revision 1's answer was wrong and there is no drain to defer to

Revision 1 answered this in four steps. **Step 3 is false**, and its falsity is the BLOCKING finding.
Re-derived against the actual handler:

1. The guard refuses. `DurableWorkflowEngine.transition` throws
   `WorkflowTransitionRejectedException` (`:205-208`); `_routeOneCompletion` catches per item and
   leaves the item where it is, reporting why (`packages/scheduler/lib/src/scheduler.dart:1582-1599`).
   ✅ correct, unchanged.
2. `agentCompleted` **is** `engineeringReviewDefinition.entryStates`
   (`scheduler.dart:3361`), so `sched-review` does look at it on its next tick. ✅ correct.
3. The item's producer committed nothing, so the review workload resolver returns `null` and no
   reviewer execution is burned. ✅ correct.
4. ~~"the tick surfaces `blockedArtifactMissing`, and the review drain turns it into a **blocking
   human decision**."~~ ❌ **FALSE.**

**What actually happens at step 4** (`apps/server/lib/src/review/engineering_review_gate.dart`):

```dart
// :2860-2871
if (item.state == WorkItemState.agentCompleted) {
  if (standDown.owns) {
    logger?.call('engineering-review-missing-artifact-stands-down', { … });
    return;                       // ← no decision, no park, no durable reason
  }
  logger?.call('engineering-review-missing-artifact-parking', { … });
}
```

and `standDown.owns` is **`true`** for exactly this item, because:

```dart
// :2210-2228
_InflowStandDown _implementationInflowOwns(ProducedCommit produced) {
  if (produced.isProduced) return (owns: false, why: '…');
  return (
    owns: true,
    why: 'the producer left no commit, and the implementation lane\'s completion '
        'inflow routes it back into implementationReady without a bound — so this '
        'gate stands down rather than asking a human a question whose options are '
        'only rework and reject',
  );
}
```

The composition root documents the same stand-down in prose
(`apps/server/lib/server.dart:1416-1421`).

**So the chain is:** guard refuses → item sits at `agentCompleted` → resolver returns `null` →
`blockedArtifactMissing` → **the handler stands down** → nothing happens → next tick, the same
refused route is attempted and stands down again. **A silent dead end, repeating every tick.** That
is precisely the outcome HD-1's delegated sub-question required this design to rule out, and it is
the shape `server.dart:1327-1330` records this repository as shipping once already ("built, tested
green, and unreachable… a green suite over a dead end").

**And revision 1's non-vacuity suite would have been green over it.** G1 and G2 asserted only that
the item does **not** reach `implementationReady`. A dead end satisfies that. **Revision 1's
assertions could not distinguish "refused and parked" from "refused and vanished."** That is the
structural weakness G7 below exists to close, and revision 2 says so in its own words: **G1/G2
alone are insufficient and must not be cited as evidence that this gate fails closed.**

#### 5.1.1 The park, specified

**A new state, `designReviewRequired`, mirroring `featureIntakeParked` (`:31-53`) row for row.**

| # | Change | Where | Mirrors |
|---|---|---|---|
| P1 | `WorkItemState.designReviewRequired('design_review_required')` | `packages/platform_contracts/lib/src/enums/workflow_state.dart` (beside `featureIntakeParked`, `:5`) | the F-48 variant |
| P2 | `(agentCompleted, designReviewRequired)` — `actorAllowed([orchestrator])` | `work_item_transitions.dart` | `(planned, featureIntakeParked)` `:31-33` |
| P3 | `(waitingForHumanDecision, designReviewRequired)` — `actorAllowed([orchestrator])` | `work_item_transitions.dart` | — (needed: the human route is refused too, §5.2) |
| P4 | `(designReviewRequired, waitingForHumanDecision)` — `actorAllowed([human, orchestrator])` | `work_item_transitions.dart` | `(featureIntakeParked, waitingForHumanDecision)` `:51-53` |
| P5 | register the state in `workflow_state.dart`'s terminal/category lists (`:46`, `:50`, `:90`, `:195-196`) and in `packages/workflow_engine/lib/src/states/workflow_state.dart` | both | the `featureIntakeParked` entries |

**Properties, each with the precedent that establishes it:**

- **Dispatchable by nobody, by construction.** `designReviewRequired` is listed in **no**
  `JobDefinition.entryStates`. Verified: every `entryStates` set in the repository is
  `baseline_product.dart:42`, `triage_defect.dart:126`, `scheduler.dart:3200, 3262, 3276, 3361`,
  `implement_feature.dart:114` — none contains it. `RunnableWorkEvaluator` returns `noAction` for a
  state outside `entryStates` **before** consulting any policy
  (`packages/scheduler/lib/src/policy/runnable_work.dart:172-174`). This is the park's whole point
  (`:34-36`).
- **Not a terminal state.** P4 is the way out, and the reasoning at `:34-43` applies verbatim: *"an
  edge out … would be a terminal state nobody can leave, which is the same class of defect this
  state was created to end."*
- **No edge back to any dispatchable state.** Same reasoning as `:45-50`. Specifically **not** back to
  `planned`, `designNotRequired` or `agentCompleted`; `planned_entry_state_hop_test` asserts
  `planning -> planned` is the only edge into `planned`, and a second predecessor re-opens the loop
  that invariant closes.
- **The park carries a durable reason.** The P2/P3 hops pass
  `context['blockingReason']`, which `DurableWorkflowEngine.transition` writes into
  `item.blockingReason` (`durable_workflow_engine.dart:222-225`). `:34-40` of the same table records
  this as the reason the feature park is not a silent stop.
- **Idempotent, and idempotence is free.** Once parked, the item is at `designReviewRequired`, which
  is in no `completionInflowFrom` (`implement_feature.dart:117` — the only one) and is not
  `agentCompleted`, so the stand-down branch at `:2860` is never reached for it again. This matters
  because `server.dart:1412-1414` states the re-surfacing requirement: *"The scheduler re-surfaces
  the same job every tick until the item leaves `agentCompleted`, so this must be idempotent — the
  handler is."* **The new state is what makes that true.**
- **P3 is what stops the human route from being a bypass loop**, and it is why a state was chosen
  over parking directly into `waitingForHumanDecision`: a human who resolves a decision and is
  routed to `implementationReady` is refused there (§5.2) and returns to the park. Without a
  *distinct* state, the item would re-park into the state it was just routed out of, with no
  durable change, forever.

#### 5.1.2 Who parks it, and when

**Inside the same tick that raised the refusal, by the caller that attempted the transition.** Not
by a downstream drain.

- **Route 1 refusal:** `_routeOneCompletion`'s per-item handler takes P2 immediately after catching
  the rejection, **inside** the existing per-item `try` (`scheduler.dart:1582-1599`).
- **Route 3 refusal:** whoever takes `waitingForHumanDecision -> implementationReady` takes P3
  immediately after catching the rejection, in that same call.

**A single shared helper**, named in sub-slice 1b, so the two callers cannot drift — the same
discipline `human_decision_routing.dart:151-162` states for `targetFor`/`escalationTargetFor`
("a value here that disagrees … does not error — it silently stops the escalation index advancing").

### 5.2 The undelegated clause is unconditional — **this is the reading this design specifies, and
it is the one point an independent `design-reviewer` must judge**

The operator was asked and answered: *"Let the design lane specify it and have it reviewed."* So the
reading is specified here, argued, and **left open**.

#### The two readings

| | Reading A (revision 1) | **Reading B (this revision specifies)** |
|---|---|---|
| Text | "unattended" (from `rationale_given`) qualifies the clause, so a human's resolved decision **is** the override | the `delegated` clause is **unconditional**: *"an IMPLEMENTER dispatch must be preceded by a satisfied design review for items originating on these two paths"* |
| Guard on route 1 | yes | yes |
| Guard on route 2 (`agentFailed`) | yes | **no** — no caller (§2.1); G11 covers it |
| Guard on route 3 (human) | **no** | **yes** |
| Human can reach an implementer without a design review | **yes** | **no** |

#### Why this revision specifies Reading B

1. **HD-1's author drew the line explicitly, in the same sentence.** *"The gate's SHAPE is a design
   question and is delegated to the design lane: … **What is NOT delegated is that an IMPLEMENTER
   dispatch must be preceded by a satisfied design review for items originating on these two
   paths.**"* The clause is stated without a qualifier. Reading A imports one from a different field
   of the same document.
2. **The rationale's word describes the harm, not the exception.** *"refusing to let an unreviewed
   request reach implementation unattended"* — read as a whole sentence, the object of "refusing to
   let … reach implementation" is **an unreviewed request**. Under Reading A a request that has
   never been reviewed, answered by one human at a routing gate, would reach implementation. That is
   the harm the sentence names, arriving by a different route.
3. **A routing answer is not a review.** The operator already named the design-review decision type
   — `designApproval`, as a `HumanDecision` *"reuses existing machinery"* (ADR 0021:126-127). A
   `rework`/`approve`/`reject` at `blockingHumanDecisionResolved` is a **routing instruction**, and
   the guard's own subject is an **artifact** (`status == 'approved'`). Conflating them means the
   gate's satisfaction fact is whatever a human typed, which is the same weakness R1 already records
   about context keys, one level up.
4. **Reading A's exemption is not theoretical.** `HumanDecisionRouting.targetFor` routes **four**
   decision pairs to `implementationReady`
   (`packages/workflow_engine/lib/src/transitions/human_decision_routing.dart:103-104, 107-108,
   109-110, 119-120`): `(engineeringReview, rework)`, `(qaWaiver, reject)`, `(qaRework, reject)`,
   `(humanQaApproval, reject)`. **Each becomes reachable for an intake origin as soon as the missing
   runtimes land** — `(engineeringReview, rework)` the moment a design-remediation or feature-intake
   run produces a commit (M8/M10, slice 4); the `qa*` and `humanQaApproval` pairs the moment slice
   2c makes `qaInProgress` reachable at all. Under Reading A, HD-1's invariant would hold today and
   dissolve the first time anyone shipped the backlog HD-1 was decided *because of*.
   - *One correction to the review's own phrasing:* the review named `(escalation, approve)` as a
     fourth human route. It is in the edge's `blockingHumanDecisionResolved` set (`:618-620`), but
     `targetFor(escalation, approve)` is `designNotRequired`
     (`human_decision_routing.dart:132-133`), so the routing table does **not** send it to
     `implementationReady`. The edge would permit it; nothing routes it there. Recorded, not relied
     on.

#### What Reading B costs, stated plainly

**Reading B means no human can move an intake-origin item to an implementer until an approved
`design_revision` row exists — and nothing in this repository writes one** (§4.3, M5–M7). The
park's exits, via `targetFor`, are therefore:

| Human answers | `targetFor` sends it to | Effect |
|---|---|---|
| `(escalation, approve)` | `designNotRequired` (`:132-133`) | re-enters triage; walks back to `agentCompleted`; refused again; parked again. **A cycle — visible, durable, and dispatching nothing.** |
| `(escalation, rework)` | `planning` (`:134-135`) | re-plans. |
| `(escalation, cancel)` | `cancelled` (`:121`) | **honest stop.** |
| `cancelled` / `terminated` | generic escape | **honest stop.** |

**So the honest statement of Reading B's consequence is this:** until the design lane exists,
feature-intake and design-remediation items **cannot reach an implementer**. They park, visibly, with
a durable reason, and a human can re-triage, re-plan or stop them — and cannot dispatch code from a
request that has never been designed.

**That is HD-1's requirement being unsatisfiable by the current repository, not a defect of this
design.** HD-1's `rationale_given` rejected "refusing completion outright" because it *"re-creates
the dead end this work exists to remove."* Reading B does not refuse **completion** — the item
completes, is recorded, and parks. What it refuses is the **implementer dispatch**, which is exactly
what the undelegated clause says it must refuse. §6 slice 3 (M6 + M7 + M5) is what makes the park
resolvable, and it is sequenced so the gate is already in place when the producer appears.

> #### ⚠ THE POINT AN INDEPENDENT `design-reviewer` MUST JUDGE
>
> **This document specifies Reading B and argues for it. It does not decide it.**
>
> The question is narrow and answerable: **did HD-1's operator intend a human's resolved routing
> decision to substitute for a design review on the two intake paths, or not?**
>
> - If **Reading B** is right, §4.1, §5.1, §5.2 and sub-slices 1a/1d are correct as written, and
>   the operational consequence in the table above is what the operator chose.
> - If **Reading A** is right, this revision is wrong in a consequential place: remove the guard from
>   route 3, restore P3, and **state explicitly that four decision pairs
>   (`human_decision_routing.dart:103-104, 107-108, 109-110, 119-120`) are a deliberate bypass of
>   HD-1's undelegated clause**, which becomes a live bypass as soon as slice 2c and slice 4 land.
>   That is not a smaller change; it is a different gate.
>
> Evidence a reviewer should weigh: the operator's literal text (above); the four routing arms;
> ADR 0021:126-127's separate naming of `designApproval`; and the fact that Reading B's cost is paid
> entirely by the two intake paths, which is who HD-1 was about.

### 5.3 How §5.1 and §5.2 interact — note for the implementer

**Independent review observed this and it is correct:** fixing B1 makes the route-3 reachability
question live, and the two items cannot be sequenced independently.

**Today, before either lands:** route 3 is unreachable for the two intake origins. No `qa*` or
`humanQaApproval` decision can be pending, because `qaInProgress` is unreachable
(`design-revision.md` §2.1 — nothing takes `reviewApproved -> qaInProgress`), and no
`engineeringReview` decision can be raised, because a triage run commits nothing so the review
resolver returns `null` and the handler stands down (§5.1). So guarding route 3 changes nothing
observable — which is exactly why revision 1 could call it optional.

**After 1d lands (B1):** the refused item parks at `designReviewRequired` and hops to
`waitingForHumanDecision` carrying a blocking decision. If that decision is `escalation`-typed, its
answers route to `designNotRequired`/`planning`/`cancelled` — never to `implementationReady`. **Route 3
is still not reached.**

**After slice 2c lands:** `reviewApproved -> qaInProgress` gets a caller (`design-revision.md` §8,
slice 2c widened), so an item can be failed by QA, raise `qaRework`/`qaWaiver`, be refused by a human,
and be routed to `implementationReady` by `targetFor`. **Now route 3 matters.**

**After slice 4 lands (M8/M10):** a real intake run commits, an `engineeringReview` decision
becomes raisable, and `(engineeringReview, rework) -> implementationReady` becomes a live path for an
intake origin. **Now Reading A vs Reading B is the difference between holding HD-1's invariant and
not holding it.**

**The sequencing consequence, which is the actionable part:**

> **Sub-slice 1a MUST land both route-1 and route-3 guards in one commit.** Splitting them creates a
> window in which the park exists but the human route is unguarded — and every slice-2 and slice-4
> change above widens that window's value. A reviewer seeing "route 1" and "route 3" land separately
> should treat it as a finding.

---

## 6. Sub-slices, each independently mergeable

**Ordering constraint between them, from §5.3: 1a must add BOTH the route-1 and the route-3 guard in
one commit.** 1b, 1c and 1d may be separate. 1d must land no later than 1a+1a+1b in practice, because
without it the route-1 guard refuses into a void.

### 1a — the guard and its context contract

**Files:** `packages/workflow_engine/lib/src/validation/guard_conditions.dart`,
`packages/workflow_engine/lib/src/transitions/work_item_transitions.dart`.

- `GuardConditions.intakeDesignReviewSatisfied()` and its guard class — **byte-identical to revision
  1's class**; only its *placement* changes (§4.1).
- Added to `:340-342` **and** `:599-602`. **Not** to `:265-267` (§2.1).
- **Does not change any existing guard.** In particular `qaContractExists()` is untouched,
  `blockingHumanDecisionResolved` and `decisionActorIsHuman()` on `:599-602` keep their order and
  their arguments, and `(implementationReady, agentExecuting)` is untouched — for the reason its own
  comment gives (`:126-134`).

**Non-vacuity assertions, in the fail-when-bypassed shape `evaluator-spec.md` §4.3 uses:**

| # | Assertion | Fails if |
|---|---|---|
| G1 | a `WI-feature-*` item at `agentCompleted` with no approved revision does not reach `implementationReady` | the guard is removed from `:340` |
| G2 | same for `design-remediation-*` | the origin check is narrowed |
| G3 | a `WI-feature-*` item **with** an approved revision does reach `implementationReady` | the guard is inverted |
| G4 | a `defect-*` item with no approved revision **does** reach `implementationReady` | the guard is widened past its two origins |
| **G5′** | the guard is **present** on `waitingForHumanDecision -> implementationReady` **and** the edge still admits all five original `blockingHumanDecisionResolved` pairs | the route-3 guard is dropped, or added at the cost of an existing bound |
| G6 | the guard is **absent** from `(implementationReady, agentExecuting)` | the dispatch edge is made unsatisfiable and the lane strands |
| **G7** | **a refused `WI-feature-*` item is at `designReviewRequired` — not `agentCompleted` — within one tick of the refusal** | **the park is missing, or deferred to a drain that stands down (§5.1)** |
| **G8** | **the same, for `design-remediation-*`, and via the route-3 refusal as well as route 1** | only one of the two park entries (P2/P3) is implemented |
| **G9** | **a second tick over an already-parked item performs no transition and raises no second decision** | idempotence is lost — `server.dart:1412-1414`'s requirement |
| **G10** | **after a human resolves and is routed to `implementationReady`, the guard refuses and the item returns to `designReviewRequired`** — no loop, no dispatch | the route-3 guard is missing, or P3 is missing |
| **G11** | **drift:** the guard is present on `:265-267` **iff** some production (non-`test`) caller of `agentFailed -> implementationReady` exists | §2.1's rule is forgotten and the guard is added while the edge is still callerless |
| **G12** | **`designReviewRequired` is in no `JobDefinition.entryStates`**, asserted over the parsed definitions rather than by name | M6 wires `designReviewDefinition` or a future definition over this state and the park starts dispatching |
| **G13** | **no edge out of `designReviewRequired` other than P4** (plus the generic escapes) | a second predecessor into `planned`/`designNotRequired` re-opens the loop `:45-50` records |

**G7 is the assertion revision 1 did not have and could not have had.** G1 and G2 alone are
satisfied by a dead end: a refused item that simply stops at `agentCompleted` passes both. **This
document no longer cites G1/G2 as evidence that the gate fails closed**, and §5.1 says so in its own
words. **A reviewer should check G7 and G10 first** — they are the two that the BLOCKING and HIGH
findings were about.

### 1b — the context supplier, and the one park helper

**Files:** `packages/scheduler/lib/src/implementation_inflow.dart`, the composition root
`apps/server/lib/server.dart`, and the caller of `waitingForHumanDecision -> implementationReady`.

- **One** function that fills `workItemOrigin` and `approvedDesignRevisionId` from a `WorkItem` and
  the store. **It must be the only writer of both keys** (§4.4; `design-revision.md` R11).
  - `workItemOrigin` is derived from the **work-item id prefix** and nowhere else.
    `design-remediation-DEF-x` *is* defect-origin, so "has a defect" is the wrong discriminator and
    would silently exempt the remediation lane — the prefix is the discriminator.
  - It runs on **both** route-1 and route-3 callers. Revision 1 only considered route 1; under
    §5.2 the human route needs the same two keys or the guard is inert there.
- **One** park helper, shared by the two callers (§5.1.2). Its `why` string is written **once**, so
  the durable `blockingReason` a human reads in the operator surface is the same on both entries.
- `PostgresDesignGovernanceStore` is **instantiated nowhere today**
  (`apps/server/lib/src/persistence/postgres_design_governance_store.dart:9-10` — verified: the only
  occurrences in `apps/server/lib` and `packages/` are its own declaration); this sub-slice adds it
  to the composition root beside the other stores (`server.dart:208-219`).
- **Per-item isolation is mandatory.** `_routeOneCompletion` already guards every per-item read in
  one `try` (`scheduler.dart:1582-1599`) for exactly the reason
  `implementation_inflow.dart:1543-1578` documents: a throw outside it takes the **whole lane's
  tick**. Both the store read and the park transition go **inside** that guard.

### 1c — the transition-table pins

`packages/workflow_engine/test/implementation_ready_edge_test.dart` already pins the
`waitingForHumanDecision -> implementationReady` edge by name. Extend it for **G5′ and G6**, and add
a drift guard that fails if the new guard appears on any edge not listed in §4.1 — including
`(implementationReady, agentExecuting)`, the one edge whose contamination would strand the lane.

### 1d — the park

**Files:** `packages/platform_contracts/lib/src/enums/workflow_state.dart`,
`packages/workflow_engine/lib/src/states/workflow_state.dart`,
`packages/workflow_engine/lib/src/transitions/work_item_transitions.dart`.

- P1–P5 of §5.1.1, plus G7–G10, G12, G13.
- Model every element on `work_item_transitions.dart:31-53` and its comment, which is the pattern
  this repository has already shipped and proved for this exact shape. Do not shorten that comment:
  it is the design.
- **No new `HumanDecisionType`, no new `HumanDecisionRouting` arm.** The park exits to
  `waitingForHumanDecision` on `escalation`, whose `targetFor` arms already exist
  (`human_decision_routing.dart:121, 132-135`). §5.2's table states what a human can then do — the
  honest set, which does not include reaching an implementer.

---

## 7. Answers to the four delegated questions

| Question | Answer |
|---|---|
| **Where does the design review sit in the graph?** | Not in the design states — it cannot, they are unreachable (§3). As a **precondition on every edge into `implementationReady` that has a caller**: `agentCompleted -> implementationReady` (`:340-342`) and `waitingForHumanDecision -> implementationReady` (`:599-602`). Satisfied by an approved `design_revision` row. It reads the **artifact**, not the actor, so it is the same gate whether a machine or a human produced the revision. `agentFailed -> implementationReady` (`:265-267`) is deliberately not guarded because it has **no caller** (§2.1); G11 makes adding it a gated, drift-tested act. |
| **Which actor satisfies it?** | Today, a **human** — the only possible producer of an approved revision (§4.5). ADR 0021:126-127 names the gate `designApproval` on existing machinery. When M5–M7 land, an agent lane satisfies the **same unchanged guard**, because it reads `status == 'approved'`. |
| **What happens to an item that never gets one?** | The guard refuses; the caller **parks it at `designReviewRequired` in the same tick** (§5.1.1) — a state in no `JobDefinition.entryStates`, with no edge back to anything dispatchable, and one named way out: `-> waitingForHumanDecision`. **It does not wait at `agentCompleted`**, because the review drain stands down there for a no-commit producer (`engineering_review_gate.dart:2860-2871`) and the item would vanish silently, repeating every tick. G7 asserts the item leaves `agentCompleted` within one tick; G9 asserts the park is idempotent. |
| **Do defect-origin items take the same path?** | **No.** `defect-*` is exempt; `WI-feature-*` and `design-remediation-*` are gated. Keyed on the **work-item id prefix**, not on whether an underlying defect exists — `design-remediation-DEF-x` *has* a defect and is still gated. Defect-origin is exempt because it has already been triaged, and because route 1 serves OD-10's recorded operator intent (`implementation_inflow.dart:406-407`); gating it would reopen a resolved decision for the main lane. HD-1 names only the two intake origins, and this is exactly it. |

**And the invariant — stated for Reading B, which §5.2 specifies and which a reviewer must judge.**

Every edge into `implementationReady` that has a caller carries the guard: the one automatic route
(`agentCompleted`, §2.2) and the human-driven route (`waitingForHumanDecision`). There is therefore
**no path, attended or unattended, by which an item of feature-intake or design-remediation origin
reaches `AgentRole.implementer` without a satisfied design review** — which is HD-1's undelegated
clause read without the qualifier revision 1 imported from the rationale.

The price is §5.2's table: until M5–M7 land, those items park and a human can re-triage, re-plan or
stop them, and nothing else. **That price is the point of the gate on this repository today.** It is
flagged rather than minimised, and it is the second half of the judgement §5.2 asks a reviewer to
make.
