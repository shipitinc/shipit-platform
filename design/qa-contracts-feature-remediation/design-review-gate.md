# Design Review Gate Spec — the HD-1 gate

**Parent:** [`design-revision.md`](./design-revision.md) §4 — deliverable 2
**Governing decision:** `.decisions/2a8f5c31-9d47-4e6b-b2f8-7c15e0d9a4b2.yaml` (HD-1, RESOLVED)
**Authoring HEAD:** `e3634a0cbbdf656267b22908284dd1ae8b655085`
**Status of this document:** a specification. This lane implements no production code.

---

## 1. The invariant being designed to

From the decision's own `delegated` clause — this is **not** delegated and this document does not
reopen it:

> an IMPLEMENTER dispatch must be preceded by a satisfied design review for items originating on
> these two paths.

And from its `rationale_given`, which pins the *scope* of the gate:

> The chosen middle keeps both intake paths alive while refusing to let an unreviewed request reach
> implementation **unattended**.

**"Unattended" is the operative word**, and §5 is built around it. A gate that also blocked the
human's own deliberate route would satisfy the first sentence and violate the second — it would stop
being a gate and become a wall.

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
  completionInflowFrom: {WorkItemState.agentCompleted},
);
```

Reached by `(implementationReady, agentExecuting)`
(`packages/workflow_engine/lib/src/transitions/work_item_transitions.dart:135-138`), guarded only by
`actorAllowed([orchestrator])` and `agentAvailable()`.

`implementationReady` has exactly **three** in-edges:

| # | Edge | Line | Guard today | Nature of the caller |
|---|---|---|---|---|
| 1 | `agentCompleted -> implementationReady` | `:340-342` | `actorAllowed([orchestrator])` | **automatic** — `Scheduler._routeOneCompletion` |
| 2 | `agentFailed -> implementationReady` | `:265-267` | `actorAllowed([orchestrator])` | **automatic** |
| 3 | `waitingForHumanDecision -> implementationReady` | `:599-602` | `actorAllowed([orchestrator])` + `blockingHumanDecisionResolved({…})` + `decisionActorIsHuman()` + `escalationIndexWithinLimitForDecisionTypes` | **human** |

**Automatic routes 1 and 2 are the gate's seam. Route 3 is deliberately left alone** — §5.

The automatic path that reaches route 1 is named, and it is the exact mechanism HD-1 was decided
about:

```dart
// packages/scheduler/lib/src/implementation_inflow.dart:437-440
WorkItemState completionRouteFor(ProducedCommit produced) => switch (produced) {
  CommitProduced() => WorkItemState.reviewInProgress,
  NoCommitProduced() => WorkItemState.implementationReady,
};
```

A triage run commits nothing — *"This is the triage shape — the defect row was written, no file
was"* (`implementation_inflow.dart:187-189`, `:383-390`) — so it takes `NoCommitProduced` and lands
on `implementationReady`. That is the operator's recorded intent, verbatim: *"After TRIAGE
COMPLETIDES, the item goes to implementationReady instead of waiting at a human gate"*
(`:406-407`).

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
(`guard_conditions.dart:166-168`) — a key that `DurableWorkflowEngine.transition` **discards**
(`packages/workflow_store/lib/src/durable_workflow_engine.dart:173`, `:211-233`). This is the exact
defect `lane_e_design_remediation_work_item.dart:116-123` documents and stopped to avoid.

### 3.4 The conclusion

A gate placed on the design states could never be satisfied, and a gate placed on the path *through*
`designApproved` would route the item into triage. **The only reachable placement is a precondition
on the route into `implementationReady`.**

And it can be an **artifact** precondition rather than a state walk, because the artifact's
persistence layer already exists (§4).

A **new state** was considered and rejected: a state needs a producer to be reachable and an edge
to be leaveable, and both are absent here. `design-revision.md` R3 and the `qaInProgress` finding
(§2.1 there) are the same lesson twice — **a state nothing leaves is worse than one nothing
enters.** One guard on an existing edge cannot create that failure, because a refused guard leaves
the item exactly where it was, in a state that already has exits.

---

## 4. The guard

### 4.1 Placement

Add one guard to **two existing edges**. No edge is added, removed, or retargeted.

```dart
// work_item_transitions.dart
(WorkItemState.agentCompleted, WorkItemState.implementationReady): [   // :340-342
  GuardConditions.actorAllowed([ActorType.orchestrator]),
  GuardConditions.intakeDesignReviewSatisfied(),                      // ← ADDED
],

(WorkItemState.agentFailed, WorkItemState.implementationReady): [      // :265-267
  GuardConditions.actorAllowed([ActorType.orchestrator]),
  GuardConditions.intakeDesignReviewSatisfied(),                      // ← ADDED
],
```

Deliberately **not** added to `(waitingForHumanDecision, implementationReady)` (`:599-602`) — §5.

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

A `GuardCondition` reads `context` and nothing else. `DurableWorkflowEngine.transition` hands
`context` to the policy (`:173`) and writes **nothing** from it (`:211-233`). **A context guard is
exactly as strong as the component that fills its context.**

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

## 5. The dead-end question, answered

> *"What happens to an item that never gets one — it must not become a new dead end. The lesson of
> this session is that a state nothing leaves is worse than one nothing enters."*

### 5.1 The refusal is a park, not a trap

The guard refuses. `DurableWorkflowEngine.transition` then **throws**
`WorkflowTransitionRejectedException` (`:205-208`), and `_routeOneCompletion` handles it as a
per-item refusal — the same shape as its existing unreadable-discriminator refusal
(`scheduler.dart:1587-1599`), which leaves the item where it is and reports why.

The item stays at `agentCompleted`. **That is not a dead end**, because:

1. `agentCompleted` is `engineeringReviewDefinition.entryStates` (`scheduler.dart:3361`), so
   `sched-review` picks it up on its next tick;
2. the item's producer committed nothing — it is a triage or intake run
   (`implementation_inflow.dart:383-390`) — so `producedCommitFor` returns `NoCommitProduced`, the
   review workload resolver returns `null`
   (`apps/server/lib/server.dart:540-543`), and **no reviewer execution is burned**;
3. the tick surfaces `SchedulerTickResult.blockedArtifactMissing`, and the review drain turns it
   into a **blocking human decision** — fail closed, with a durable record naming the cause;
4. and `runnable_work.dart:168-170` returns `blocked` for `waitingForHumanDecision`, so the park
   grants no dispatch while it waits.

**This is the identical mechanism `ddfbfff` established for the feature park** — park at a state
nothing dispatches, record a durable reason, route out through a human
(`work_item_transitions.dart:34-53`). The gate reuses a pattern this repository has already shipped
and proved; it does not invent one.

### 5.2 The human keeps the override — and why the guard is on two edges, not three

**If the guard were also on `waitingForHumanDecision -> implementationReady` (`:599-602`), no human
could ever move an intake item to implementation**, because that edge's own `decisionActorIsHuman()`
(`:624`) would be permanently overridden by a gate no human can satisfy (§4.3: nothing writes
approved revisions today). The item would sit at `waitingForHumanDecision` with its decision
answered and no route forward — **a genuine dead end, manufactured by the very gate that was
supposed to prevent one.**

So the guard is on the two **automatic** edges only. The human route is left intact, and it is
already a real gate: a resolved blocking decision of a named type and choice (`:604-623`), by a
human, recorded durably.

**This is faithful to the decision, which asks for no *unattended* dispatch.** A human who answers
a blocking decision at the gate has made the call personally, and the audit trail names them. That
is the override, and it is the correct place for it.

`design-revision.md` R4 records this: in an earlier pass the guard was to be placed on all three
edges, and R4 is the dead end that would have caused.

---

## 6. Sub-slices, each independently mergeable

### 1a — the guard and its context contract

**Files:** `packages/workflow_engine/lib/src/validation/guard_conditions.dart`,
`packages/workflow_engine/lib/src/transitions/work_item_transitions.dart`.

- `GuardConditions.intakeDesignReviewSatisfied()` and its guard class.
- Added to `:340-342` and `:265-267` only.
- **Does not change any existing guard.** In particular `qaContractExists()` is untouched, and
  `(implementationReady, agentExecuting)` is untouched — for the reason its own comment gives
  (`work_item_transitions.dart:126-134`).

**Non-vacuity assertions, in the fail-when-bypassed shape `evaluator-spec.md` §4.3 uses:**

| # | Assertion | Fails if |
|---|---|---|
| G1 | a `WI-feature-*` item at `agentCompleted` with no approved revision does not reach `implementationReady` | the guard is removed from `:340` |
| G2 | same for `design-remediation-*` | the origin check is narrowed |
| G3 | a `WI-feature-*` item **with** an approved revision does reach `implementationReady` | the guard is inverted |
| G4 | a `defect-*` item with no approved revision **does** reach `implementationReady` | the guard is widened past its two origins |
| G5 | the guard is **absent** from `waitingForHumanDecision -> implementationReady` | §5.2's dead end is reintroduced |
| G6 | the guard is **absent** from `(implementationReady, agentExecuting)` | the dispatch edge is made unsatisfiable and the lane strands |

**G5 and G6 are negative assertions on placement**, and they are the two that protect against the
two dead ends this design could have shipped. A reviewer should check them first.

### 1b — the context supplier

**Files:** `packages/scheduler/lib/src/implementation_inflow.dart`, and the composition root
`apps/server/lib/server.dart` for the `DesignGovernanceStore` wiring.

- A single function that fills `workItemOrigin` and `approvedDesignRevisionId` from a `WorkItem`
  and the store. **It must be the only writer of both keys.**
- `workItemOrigin` is derived from the **work-item id prefix** and nowhere else. Note that
  `design-remediation-DEF-x` *is* defect-origin, so "has a defect" is the wrong discriminator and
  would silently exempt the remediation lane — the prefix is the discriminator.
- `PostgresDesignGovernanceStore` is **instantiated nowhere today**
  (`apps/server/lib/src/persistence/postgres_design_governance_store.dart:9`); this sub-slice adds
  it to the composition root beside the other stores (`server.dart:208-219`).
- **Per-item isolation is mandatory.** `_routeOneCompletion` already guards every per-item read in
  one `try` (`scheduler.dart:1582-1599`) for exactly the reason
  `implementation_inflow.dart:1543-1578` documents: a throw outside it takes the **whole lane's
  tick**, including every unrelated runnable item. The new read goes **inside** that guard.

### 1c — the transition-table pins

`packages/workflow_engine/test/implementation_ready_edge_test.dart` already pins the
`waitingForHumanDecision -> implementationReady` edge by name. Extend it for G5/G6, and add a drift
guard that fails if the new guard appears on any edge not listed in §4.1.

---

## 7. Answers to the four delegated questions

| Question | Answer |
|---|---|
| **Where does the design review sit in the graph?** | Not in the design states — it cannot, they are unreachable (§3). As a **precondition on the two automatic edges into `implementationReady`** (`work_item_transitions.dart:340`, `:265`), satisfied by an approved `design_revision` row. It reads the **artifact**, not the actor, so it is the same gate whether a machine or a human produced the revision. |
| **Which actor satisfies it?** | Today, a **human** — the only possible producer of an approved revision (§4.5). ADR 0021:126-127 names the gate `designApproval` on existing machinery. When M5–M7 land, an agent lane satisfies the **same unchanged guard**, because it reads `status == 'approved'`. |
| **What happens to an item that never gets one?** | The guard refuses; the item **stays at `agentCompleted`**, which `sched-review` picks up, whose resolver returns `null` for a no-commit producer so no execution is burned, and which surfaces `blockedArtifactMissing` → a **blocking human decision** (§5.1). It is a park with a durable reason, the `ddfbfff` shape — **not a dead end.** And the human retains the override, because the guard is deliberately absent from the human-driven edge (§5.2). |
| **Do defect-origin items take the same path?** | **No.** `defect-*` is exempt; `WI-feature-*` and `design-remediation-*` are gated. Keyed on the **work-item id prefix**, not on whether an underlying defect exists — `design-remediation-DEF-x` *has* a defect and is still gated. Defect-origin is exempt because it has already been triaged, and because the automatic route serves OD-10's recorded operator intent (`implementation_inflow.dart:406-407`); gating it would reopen a resolved decision for the main lane. HD-1 names only the two intake origins, and this is exactly it. |

**And the invariant:** routes 1 and 2 (§2) are the only automatic paths to `implementationReady`.
Both carry the guard. A human answering a blocking decision is not an unattended dispatch. **So
there is no path by which an item of feature-intake or design-remediation origin reaches
`AgentRole.implementer` without a satisfied design review** — which is HD-1's undelegated clause.