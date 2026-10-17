# Design Review Gate Spec — the HD-1 gate

**Parent:** [`design-revision.md`](./design-revision.md) §4 — deliverable 2
**Governing decisions:**
- `.decisions/2a8f5c31-9d47-4e6b-b2f8-7c15e0d9a4b2.yaml` — HD-1, RESOLVED
- `.decisions/7f3e2a95-6c81-4d70-b215-8e94a0c7d382.yaml` — **the reading of HD-1's undelegated
  clause, RESOLVED by the operator 2026-10-17: `READING_B_CLAUSE_COVERS_EVERY_ROUTE`.** This
  document no longer asks the question; see §5.2.
- `.decisions/b81f40c7-2a96-4e38-bd51-6c07e9f3a824.yaml` — **the SEQUENCING, RESOLVED by the
  operator 2026-10-17: `HUMAN_SURFACE_FIRST`.** The park's human surface is built **BEFORE** the
  gate, reversing the order this document's previous pass used. See §0.2 and §5.2.2.
**Authoring HEAD:** `e3634a0cbbdf656267b22908284dd1ae8b655085` (revision 1)
**Revision 2 at:** `c8fd361906f0d831bbcfd431b75d1eb21ae9db5d`
**Revision 2 corrected at:** `90b6f5f` (revision 2 correction lane
`design-QA-CONTRACTS-CORRECTION-2`)
**Correction pass 3 at:** `2b182fd3215fde12a5814f0c7db4753514aa4c62` (lane
`design-QA-CONTRACTS-CORRECTION-3`) — the sequencing reversal, plus M-A through M-D and L-A, L-B.
**Status of this document:** a specification. This lane implements no production code.

---

## 0. What changed at revision 2 correction, in one place

Revision 2 specified a park at a new state `designReviewRequired` and asserted, as fact in three
artifacts, that **"the park carries a durable reason"** — citing
`durable_workflow_engine.dart:222-225`. **That citation says the opposite.** `transition` writes
`blockingReason` only when `to == waitingForHumanDecision`, and writes `null` otherwise, so the
park hop *erased* its own reason. The distinct state survived; the promise did not.

Two other corrections change what §5.2 is allowed to say, and one changes sub-slice 2b's file list.

| | Revision 2 said | Actual | §
|---|---|---|---|
| **B-1** | the park carries a durable reason, written by `transition` (`durable_workflow_engine.dart:222-225`) and established by the `featureIntakeParked` precedent at `:34-40` | `transition` writes `blockingReason: null` for every target other than `waitingForHumanDecision` (`:222-225`); the feature park has no durable reason either — `:34-40` explains the **way out**, not a reason | §5.1.1 |
| **H-2** | the park's only out-edge is `(designReviewRequired, waitingForHumanDecision)`, taken by nothing, and no component originates it | the out-edge is taken by **`DurableWorkflowEngine.requestHumanDecision`**, a named, already-called component (`:546`, writing at `:651-653`); the route-3 refusal that re-enters the park is originated by **`resolveHumanDecision`** (`:758-761`, refusing at `:820-841`) | §5.1.2 |
| **H-3** | Reading B is "specified, argued, and **left open**" for an independent reviewer to judge; the rationale's word is disposed of "as a different field" | **Reading B is DECIDED** (`.decisions/7f3e2a95…`). Reading A is rejected. The artifacts must say so, and must stop disposing of the rationale as a different field | §5.2 |
| **M-2** | the park is taken "inside the existing per-item `try` (`scheduler.dart:1582-1599`)" | that range is the **`try` around the four per-item reads**, whose reason string is *"this item could not be read well enough to decide whether it should be reviewed or implemented."* The transition's `try` is `:1740-1843`, rejection caught at `:1823-1833` | §5.1.2 |
| **M-3** | sub-slice 1b lists `implementation_inflow.dart`, `server.dart`, and the route-3 caller | the actual route-1 context writer is `packages/scheduler/lib/src/scheduler.dart`, whose context at `:1746` is a **`const` literal** — the two keys cannot exist until it becomes a computed map | §6, 2b |

**The correction spec recommended landing the park at `waitingForHumanDecision` instead of a new
state. This revision does not, and §5.1.1b states why with evidence — because that option is not
implementable as written, and it moves the dead end rather than closing it.**

---

## 0.1 What correction pass 3 changed, in one place

**The previous pass's BLOCKING finding is closed and is NOT rebuilt.** The independent review
verified at the line level that the park carries a durable reason, a resolvable decision id, is
idempotent, and has a reachable raiser — and that **this lane's refusal of the correction spec's
recommended B-1 fix was correct on the merits**: there is no `(agentCompleted,
waitingForHumanDecision)` edge, and `resolveHumanDecision` saves the decision as resolved then
throws. Everything below is metadata, argument and sequencing. `durable_discoveries` at
`not_rebuilt_this_pass` in `design-revision-metadata.yaml` records the confirmations.

| | Correction pass 3 changed | § |
|---|---|---|
| **SEQ** | **The slice order REVERSES.** The park's human surface is now built **BEFORE** the gate. The previous pass routed it as "slice 1.5", after the gate — a flagged judgement that the operator has now overridden **on authority, not reasoning**. | §0.2, §5.2.2, §6 |
| **M-A** | **`FOLLOW_UPS` F-55 now EXISTS.** The previous pass cited it in six places as the place the gap "is recorded", while stating in four of them that it had never been written. `0bfb6fb` wrote F-55 and F-56. Every one of those citations now resolves, and each is corrected to say so. | §5.2.2 |
| **M-C** | §5.1.1a stated the park's two steps without saying the order is **load-bearing**. It is: step 1's `transition` is what clears the resolved blocking id that would make step 2 throw. | §5.1.1a |
| **M-D** | The route-3 caller was named by role ("the human-decision endpoint"). It is now named with `file:line` end to end, and the design says that **discriminating the rejection is the work** — the existing catch is generic. | §5.1.2, §6 (2b) |
| **L-A** | Three artifacts called `durable_workflow_engine.dart:996` "the escalation-index computation". It is inside `_isReWorkDecision`, which drives `nextTriageAttempt`. The escalation-index predicate is `:1007-1021`. | §6 (2d), `design-revision.md` §11 |
| **G17** | **NEW.** The invariant the reversal exists to enforce, now **asserted** rather than asserted-by-convention: `designReviewRequired` may not have an in-edge while the decision raised there offers no "do the design review" answer. | §5.2.2, §6 (1c) |
| **G17b** | **NEW — and it corrects this document's own text.** §5.2.2 stated the `targetFor`/`escalationTargetFor` lockstep rule flatly for this work. It does **not** apply to an `approve` answer, and an implementer who believed it would have started escalation accounting silently on a design approval. | §5.2.2, §6 (1c) |
| **PASS3-1** | **FOUND BY THIS PASS, NOT BY THE REVIEW.** `implementation_inflow.dart:1543-1578` — a range 1103 lines past the end of a 440-line file, cited twice for a load-bearing property. | §6 (2b), `evaluator-spec.md` §4.3 |

### 0.2 The sequencing reversal — recorded, with the merits argument kept

> **Decision `b81f40c7-2a96-4e38-bd51-6c07e9f3a824.yaml`** · `type: ARCHITECTURE` · `status: RESOLVED` ·
> `resolution.selected: HUMAN_SURFACE_FIRST` · `decided_by: operator` · `decided_at:
> 2026-10-17T14:10:00Z`
>
> **`consequence`, verbatim:** *"Slice ordering REVERSES: the human surface becomes the FIRST slice,
> the gate follows. This costs a new HumanDecisionType plus a routing arm, and
> human_decision_routing.dart:151-162 records why that is not small — 'a value here that disagrees
> with targetFor does not error, it silently stops the escalation index advancing.' The two routing
> tables must move in lockstep."*
>
> **`invariant`, verbatim:** *"NO item may be parked at `designReviewRequired` before the decision
> raised there offers a 'do the design review' answer. A park without a way to produce what the item
> waits for is the dead-end class (F-42, F-50, F-54) this area has produced repeatedly. This
> invariant is the whole point of the reversal and must be asserted, not assumed."*

**What the previous pass argued, and it is not withdrawn.** It routed the human surface as slice 1.5
because while the gate is absent, a refused intake item sits at `agentCompleted`, whose only consumer
**stands down** (`engineering_review_gate.dart:2860-2871`, §5.1) — a silent position, which is worse
than parking. **The independent review agreed with that argument on the merits** and held the
opposite on authority: *"a flagged judgement is not a discharged obligation."* The decision's own
`authority_note` records the same thing: *"The lane's merits argument is recorded and is not
dismissed. It is overridden on AUTHORITY, not on reasoning."*

**So a reader must be able to see which it was.** The distinction this artifact draws, everywhere the
point appears: **a merits argument is this lane's; deferring a Level 3 operator instruction is the
operator's.** The previous pass made the first and claimed the second. That is corrected here, and
the correction is not a change of mind about the merits.

**What the reversal costs, stated rather than minimised.** For the window in which the human surface
exists and the gate does not, the platform carries **a new `HumanDecisionType` and a routing arm
that no guard consumes** — an answer an operator is offered that changes nothing about whether an item
may reach an implementer. The design's judgement was that a silent `agentCompleted` is worse; the
operator has decided it is not. **That is the whole disagreement, and it is resolved against this
lane.**

#### Slice-number crosswalk — read this if you are holding the previous review

The reversal moves the gate off "slice 1", so every slice is renumbered. **No claim changed; the
numbers moved.** A reviewer reading `225ee5c`'s review alongside this document should use this table.

| | This document | Previous pass (`225ee5c`) | What it is |
|---|---|---|---|
| **1** | **the park's human surface** — a `HumanDecisionType` + routing arm answering "do the design review" | slice 1.5 | **the reversal** |
| **2** | **the design-review gate** (§6, sub-slices 2a–2d) | slice 1 (sub-slices 1a–1d) | the gate |
| **3** | the evaluator (§6 `evaluator-spec.md`, 3a–3c) | slice 2 (2a–2c) | unchanged in content |
| **4** | the design lane (M6 + M7 + M5) | slice 3 | unchanged |
| **5** | the path-specific contracts (M8–M12) | slice 4 | unchanged |
| **0** | Manager-owned ledger | slice 0 | unchanged |

> **One decision quote needs a gloss.** `.decisions/7f3e2a95…`'s `precondition` reads *"sub-slice
> 1a's pinned content depends on this answer … so slice 1 may not begin until this decision is
> recorded — which it now is."* **"Slice 1" and "1a" in that decision mean the design-review gate,
> which this revision numbers 2a.** The precondition is discharged: the decision is recorded, and
> §6 2a's pinned content is the one the decision describes (both guards, one commit). The decision
> predates the reversal; the renumbering does not reopen anything it settled.

---

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
review found that this reads the word out of the wrong half of the decision, and revision 2
specified the opposite reading. **The operator has since decided it**:
`.decisions/7f3e2a95-6c81-4d70-b215-8e94a0c7d382.yaml` records
`READING_B_CLAUSE_COVERS_EVERY_ROUTE` — the clause covers **every** route to
`implementationReady`, human-driven included, and Reading A is rejected. **§5.2 states what that
decides and what it costs.** It is no longer the open question of revision 2, and this document does
not present it as one.

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

> **What this precedent establishes, and what it does not.** Revision 2 cited `:34-40` of this
> comment as recording *why the feature park is not a silent stop*. **It does not say that.** Read in
> full, `:34-40` explains **the way out of the park** — why an edge out exists and where it goes. It
> says nothing about a durable reason, and **the feature park has none**: `featureIntakeParked` is
> reached by `transition`, which nulls `blockingReason` for every target that is not
> `waitingForHumanDecision` (`durable_workflow_engine.dart:222-225`). So `featureIntakeParked` is a
> state a human can *see* and a decision can be *raised from*, but an item parked there carries
> **no `blockingReason` and no `blockingHumanDecisionId`** of its own.
>
> **This is why the park's durable reason cannot be inherited from this precedent and must be
> produced by a named component.** §5.1.1 does that, and §5.1.1's own property table no longer cites
> `:34-40` for a property it does not state.

The revision's non-goal "**Not** a new `WorkItemState`" is therefore **withdrawn**; §5.1 specifies
the state and §11 of `design-revision.md` records the reversal and what it costs. `design-revision.md`
R3's mitigation is withdrawn with it.

---

## 4. The guard

### 4.1 Placement

Add one guard to **two existing edges that have callers**, and to **one more that revision 1 left
open**. No edge is added, removed, or retargeted *in this sub-slice*; the two new park edges are
§5.1 and §6 sub-slice 2d.

```dart
// work_item_transitions.dart
(WorkItemState.agentCompleted, WorkItemState.implementationReady): [   // :340-342
  GuardConditions.actorAllowed([ActorType.orchestrator]),
  GuardConditions.intakeDesignReviewSatisfied(),                      // ← ADDED
],

(WorkItemState.waitingForHumanDecision, WorkItemState.implementationReady): [  // :599-602
  GuardConditions.actorAllowed([ActorType.orchestrator]),
  GuardConditions.blockingHumanDecisionResolved({ …unchanged… }),      // :604-623 — all SIX pairs
  GuardConditions.intakeDesignReviewSatisfied(),                      // ← ADDED
  GuardConditions.decisionActorIsHuman(),                              // :624 unchanged
  GuardConditions.escalationIndexWithinLimitForDecisionTypes( … ),    // :630-635 unchanged
],
```

**The guard is added to route 3 — the human-driven edge — and that is what §5.2 decides.** Revision 1
deliberately omitted it on the narrower reading; the operator has now rejected that reading
(`.decisions/7f3e2a95…`), so it is not omitted. **The route-3 guard is required, not optional, and
Reading A's alternative — drop it, restore P3 — is closed.**

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
sub-slice 2b.

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

## 5. The dead-end question, answered — under the operator's DECIDED reading of HD-1

> *"What happens to an item that never gets one — it must not become a new dead end. The lesson of
> this session is that a state nothing leaves is worse than one nothing enters."*

**§5.1 answers where a refused item goes. §5.2 applies `.decisions/7f3e2a95…`, which decides the
reading the answer is built on. §5.3 says how the two interact for an implementer.**

### 5.1 The refusal sink — revision 1's answer was wrong and there is no drain to defer to

Revision 1 answered this in four steps. **Step 3 is false**, and its falsity is the BLOCKING finding.
Re-derived against the actual handler:

1. The guard refuses. `DurableWorkflowEngine.transition` throws
   `WorkflowTransitionRejectedException` (`:205-208`); `_routeOneCompletion` catches per item and
   leaves the item where it is, reporting why — **in the transition's own catch,
   `packages/scheduler/lib/src/scheduler.dart:1823-1833`**.
   ✅ correct, unchanged. **This is the catch the park is taken in (§5.1.2); revision 2 cited the
   wrong one.**
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

**A new state, `designReviewRequired`, mirroring `featureIntakeParked` (`:31-53`) for its shape —
but NOT for its durable reason, which `featureIntakeParked` does not have either (§3.5). The
reason is produced by a named component, specified below.**

| # | Change | Where | Mirrors |
|---|---|---|---|
| P1 | `WorkItemState.designReviewRequired('design_review_required')` | `packages/platform_contracts/lib/src/enums/workflow_state.dart` (beside `featureIntakeParked`, `:5`) | the F-48 variant |
| P2 | `(agentCompleted, designReviewRequired)` — `actorAllowed([orchestrator])` | `work_item_transitions.dart` | `(planned, featureIntakeParked)` `:31-33` |
| P3 | `(waitingForHumanDecision, designReviewRequired)` — `actorAllowed([orchestrator])` | `work_item_transitions.dart` | — (needed: the human route is refused too, §5.2) |
| P4 | `(designReviewRequired, waitingForHumanDecision)` — `actorAllowed([human, orchestrator])` | `work_item_transitions.dart` | `(featureIntakeParked, waitingForHumanDecision)` `:51-53` |
| P5 | register the state in `workflow_state.dart`'s terminal/category lists (`:46`, `:50`, `:90`, `:195-196`) and in `packages/workflow_engine/lib/src/states/workflow_state.dart` | both | the `featureIntakeParked` entries |

**Properties, each with the precedent that establishes it — and, where there is none, the component
that produces it. A property with neither is a property this design does not have.**

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
- **Idempotent, and idempotence is free.** Once parked, the item is at `designReviewRequired`, which
  is in no `completionInflowFrom` (`implement_feature.dart:117` — the only one) and is not
  `agentCompleted`, so the stand-down branch at `:2860` is never reached for it again. This matters
  because `server.dart:1412-1414` states the re-surfacing requirement: *"The scheduler re-surfaces
  the same job every tick until the item leaves `agentCompleted`, so this must be idempotent — the
  handler is."* **The new state is what makes that true.**
- **P3 is what stops the human route from being a bypass loop**, and it is why a state was chosen
  over parking directly into `waitingForHumanDecision`: a human who resolves a decision and is
  routed to `implementationReady` is refused there (§5.2) and returns to the park. §5.1.1b shows,
  against the tree, that the alternative has no sink at all.

##### 5.1.1a The durable reason — who writes it, and what revision 2 got wrong

**Revision 2 asserted this property and cited a range that says the opposite.** The correction:

```dart
// packages/workflow_store/lib/src/durable_workflow_engine.dart:222-225
blockingReason: to == WorkItemState.waitingForHumanDecision
    ? context['blockingReason'] as String? ??
          'Awaiting human decision at ${DateTime.now().toUtc().toIso8601String()}'
    : null,          // ← P2/P3 land on designReviewRequired, so THIS branch runs
```

`blockingHumanDecisionId` is conditional the same way (`:215-221`, `null` for any target other than
`waitingForHumanDecision` that is not the item's own state). **So a P2/P3 hop taken through
`transition` erases whatever reason the item had and writes none.** B1's signature — *"no decision,
no park and no durable reason"* — would have survived under the new state name.

**The writer is `DurableWorkflowEngine.requestHumanDecision`, and it does not go through
`transition`'s `copyWith` at all.** It takes P4 as its own policy evaluation and then writes both
fields itself:

```dart
// packages/workflow_store/lib/src/durable_workflow_engine.dart:614-622  (P4 is the edge it validates)
final gateEntry = _policy.evaluateWorkItemTransition(
  from: item.state,
  to: WorkItemState.waitingForHumanDecision,
  trigger: TransitionTrigger.humanDecision,
  actor: actor,
  context: validationContext,
  decisionId: id,
);

// :651-653  (the two fields revision 2 claimed transition wrote)
blockingHumanDecisionId: id,
blockingReason: question ?? 'Awaiting human decision',
```

**So the park is specified as a two-step, not a single hop:**

| Step | Call | Produces |
|---|---|---|
| 1 | `transition(to: designReviewRequired)` — P2 or P3 | the dispatchable-by-nobody state |
| 2 | **`requestHumanDecision(decisionType: escalation, blocking: true, question: <park reason>, options: <§5.2's set>)`** | the item moves to `waitingForHumanDecision`, and writes **`blockingHumanDecisionId`** (a real decision id) and **`blockingReason`** (the text a human reads) itself |

**The order is load-bearing. Do not collapse these two calls into one, and do not invert them.**

The previous pass specified the order and **never said why**, which leaves an implementer free to
"optimise" it. The reason is in the tree, and it is stronger than the order itself:

```dart
// packages/workflow_store/lib/src/durable_workflow_engine.dart:564-584  (requestHumanDecision)
if (item.state == WorkItemState.waitingForHumanDecision &&
    item.blockingHumanDecisionId != null) {                      // :564-565
  final existing = await _store.readHumanDecision(item.blockingHumanDecisionId!);
  if (existing.decisionType == decisionType &&
      !existing.status.isResolved) {                             // :569-570
    return existing;                                             // :571  ← idempotence arm
  }
  throw WorkflowTransitionRejectedException( …                    // :573-583
    reason: 'Work item is already waiting for a blocking human decision',   // :581
  );
}
```

**So `requestHumanDecision` REFUSES to raise anything for an item that is already at
`waitingForHumanDecision` carrying a non-null blocking id whose decision is resolved. And that is
precisely the state a P3 entry is taken from** — §5.1.1b establishes it: a route-3 refusal saves the
decision as **resolved** (`:817`) and then throws (`:821`), leaving the item at
`waitingForHumanDecision` holding that resolved id, because the `copyWith` that would move it is at
`:854`, after the throw.

Step 1 is therefore not a formality that gives the item a nicer place to wait. **Step 1 is the only
thing that makes step 2 possible**, because `transition`'s own `copyWith` is what clears the id:

```dart
// :215-221  (transition)
blockingHumanDecisionId: to == WorkItemState.waitingForHumanDecision
    ? …                                                          // :215-218
    : identical(to, item.state)
      ? item.blockingHumanDecisionId                            // :219-220
      : null,                                                    // :221  ← P2/P3 land here
```

P3 changes the state (`waitingForHumanDecision -> designReviewRequired`), so `identical` is false and
the id is **nulled**. That null is the precondition step 2 checks at `:564-565`.

**Three ways to get this wrong, all of which a single-call helper would do:**

1. **One call, no hop** — call `requestHumanDecision` straight from the catch. On a **P3** entry the
   call **throws**, inside a catch block, and §6 2b's per-item isolation is what stands between that
   and a whole-lane tick (`scheduler.dart:1582-1599`, `implementation_inflow.dart:124-126`). The item
   keeps its resolved id and no decision is ever raised — B1 with a different state name.
2. **Hop, but skip step 2** — the reason-less park. That is R3b, and G14/G15/G16 fail on it.
3. **Step 2 before step 1** — same as (1).

**This coupling is the strongest argument for the distinct state that this artifact has**, and it is
the one §5.1.1b's negative claim could not make: even granting that parking at
`waitingForHumanDecision` was somehow reachable, the *exit* could not be taken from the state a
route-3 refusal leaves behind. **Recorded because §5.1.1a previously asserted the order without
this, and an undriven step is what produced the last two BLOCKING findings in this design.**

Step 2's consumer of P4 is `requestHumanDecision`'s own `evaluateWorkItemTransition`; its default
actor is `orchestrator` (`:41-44`), which P4's `actorAllowed([human, orchestrator])` admits.

**`requestHumanDecision` is a shipped, production-called component — this is H-2's answer.** Its one
production caller today is `raiseStallDecision`
(`apps/server/lib/src/triage/stalled_work_item_gate.dart:195-227`), and the two-hop shape used here
is that function's own shape (`:136-160`, `:194-227`). It is also **idempotent by construction**: an
item already at `waitingForHumanDecision` with a pending blocking decision of the same type returns
that decision rather than minting a second one (`durable_workflow_engine.dart:564-572` for the
return arm; the throw arm is `:573-583` and is what the order of §5.1.1a's two steps turns on), and
`stalled_work_item_gate.dart:111-118` documents why that matters at a 30-second tick.

**And it puts the item somewhere an operator already looks.** `blockingHumanDecisionId` is what the
Needs You surface reads — routed at `/needs-you` and `/needs-you/:decisionId`
(`apps/control_plane/lib/router.dart:70-75`, `apps/control_plane/lib/features/home/home_page.dart:538`).
That is the whole of the operator-facing surface this design adds, and it is an existing one.

##### 5.1.1b Why the review's alternative was not taken — against the tree

The correction spec offered two fixes and recommended the second: **land the item directly at
`waitingForHumanDecision` with a raised `HumanDecision`**, which it argued would give a real reason, a
real decision id, and the Needs You page, while removing the callerless out-edge H-2 describes.

**That option is not implementable as written, and it relocates the dead end rather than closing it.
Two independent reasons, both verified at `90b6f5f`:**

**1. `agentCompleted` has no edge to `waitingForHumanDecision`, so route 1 cannot park there.**
The complete set of in-edges to `waitingForHumanDecision` is `:51` (`featureIntakeParked`), `:63`
(`designInReview`), `:351` (`reviewInProgress`), `:703` (`qaPassed`), `:709` (`qaFailed`), `:738`
(`deploying`). The repository says so itself:

> `apps/server/lib/src/triage/stalled_work_item_gate.dart:97-99` — *"`agentCompleted` has no direct
> edge to `waitingForHumanDecision`; the only route runs through `reviewInProgress`, and that edge is
> guarded by `agentResultValid()`."*

and why that function did not add one:

> `apps/server/lib/src/triage/stalled_work_item_gate.dart:40-42` — *"the state machine names the
> decision type for it. Picking a different type here would have meant **adding an edge**, which is a
> state-machine change and not this lane's to make."*

So "land directly at `waitingForHumanDecision`" means either adding `(agentCompleted,
waitingForHumanDecision)` — the state-machine change that precedent declined to make — or reusing the
`reviewInProgress` hop, which is exactly P2-with-a-rename.

**2. Decisively: `waitingForHumanDecision` cannot be the park, because route 3's refusal leaves the
item *there*, and nothing can move it off.** Under Reading B (§5.2) the gate refuses
`(engineeringReview, rework)`, `(qaWaiver, reject)`, `(qaRework, reject)` and
`(humanQaApproval, reject)` → `implementationReady`. Those resolutions arrive from the item's *own*
lanes (`qaFailed -> waitingForHumanDecision` at `:709`, and so on) — not only from the park — so
this is not hypothetical. On refusal:

```dart
// packages/workflow_store/lib/src/durable_workflow_engine.dart:816-841
if (!alreadyResolved) {
  await _store.saveHumanDecision(resolved);        // :817  ← the decision is ALREADY RESOLVED
}
if (!unlock.isValid) {
  throw WorkflowTransitionRejectedException(...);   // :821  ← and the work item is never touched
}
```

The `copyWith` that would move the item is at `:854`, **after** the throw. So the item is left at
`waitingForHumanDecision` carrying a **resolved** decision id and a stale `blockingReason`. And
re-parking it is refused:

> `durable_workflow_engine.dart:564-584` — an item already at `waitingForHumanDecision` with a
> non-null `blockingHumanDecisionId` either returns a pending decision of the same type, or throws
> `'Work item is already waiting for a blocking human decision'`. A resolved one is the throw case.

And there is **no `(waitingForHumanDecision, reviewInProgress)` edge** — the out-edges from
`waitingForHumanDecision` are `:73, :83, :93, :425, :435, :445, :528, :599, :641, :716, :723, :744,
:754`. **So the item would sit at the one state whose entire meaning is "an operator is needed",
with nothing pending for them.** `RunnableWorkEvaluator` returns `blocked` for it
(`runnable_work.dart:169-171`), and `apps/server/lib/src/endpoints/work_item_action_endpoints.dart:880`
records the operator-visible consequence by name: an item in that position must still read *"Nothing
needs you here."*

**That is a worse outcome than the one this revision corrects**, and P3 is precisely the sink it
needs. **The distinct state is retained, and the reason it carries is produced by the component named
above.**

#### 5.1.2 Who parks it, and when

**Inside the same tick that raised the refusal, by the caller that attempted the transition.** Not
by a downstream drain.

- **Route 1 refusal — `_routeOneCompletion`, named.**
  `packages/scheduler/lib/src/scheduler.dart` catches the refusal in the transition's own `try`,
  **`:1823-1833`**, whose `reason` is *"the item moved while this lane was reading it … so no route
  was taken."* It takes P2 there, then step 2 of §5.1.1a.
  - **Correction (M-2). Revision 2 pointed the implementer at `:1582-1599`.** That range is the `try`
    around the **four per-item reads** (`producedCommitFor`, `readTriageAttempt`,
    `lastCompletionWasUndetermined`, `nextUndeterminedReturnStreak`), and its reason string is *"this
    item could not be read well enough to decide whether it should be reviewed or implemented."*
    **Routing the park through it would file the refusal under a reason about readability, and the
    `CompletionInflowMove` an operator reads would be wrong.** The transition's `try` is `:1740-1843`;
    the rejection is caught at `:1823-1833`; the concurrent-writer catch is `:1834-1843`. `:672` uses
    `:1582-1599` correctly, for read isolation — one range, two jobs, two different meanings.
- **Route 3 refusal — the whole chain, named to `file:line`.**
  The previous pass named this caller **by role only** ("the human-decision endpoint"), which is
  weaker than the citation discipline applied everywhere else in this document — and against its own
  standard at `design-review-gate.md` §16(2): *"check that the design names a component that exists
  and is reachable, not one that merely sounds right."* Here is the chain, every hop verified:

  | Hop | Where | What |
  |---|---|---|
  | 1 | `apps/server/lib/src/endpoints/workflow_endpoints.dart:141-142` | `WorkflowEndpoints.resolveDecision` opens a `try` and calls `service.resolveHumanDecision(…)` |
  | 2 | `apps/server/lib/src/services/control_plane_service.dart:2040` | `ControlPlaneService.resolveHumanDecision({…})` — one pre-engine refusal of its own at `:2048-2071` (`throw StateError`, `:2065`) |
  | 3 | `apps/server/lib/src/services/control_plane_service.dart:2073` | `await workflowEngine.resolveHumanDecision(…)` — the engine call |
  | 4 | `packages/workflow_store/lib/src/durable_workflow_engine.dart:758-761` | `HumanDecisionRouting.targetFor(decision.decisionType, effectiveChoice)` computes the target |
  | 5 | `packages/workflow_store/lib/src/durable_workflow_engine.dart:820-841` | `if (!unlock.isValid) throw WorkflowTransitionRejectedException(…)` — **the refusal the new guard causes**, carrying `unlock.guardResults` at `:830-838` |
  | 6 | `apps/server/lib/src/endpoints/workflow_endpoints.dart:168-174` | the only catch on that path today |

  **Step 6 is where the work is, and it is not already done.** It is a **generic**
  `catch (error, stackTrace)` that logs `workflow.resolve.failed` (`:169-172`) and rethrows unchanged
  via `Error.throwWithStackTrace(error, stackTrace)` (`:173`). **It does not discriminate
  `WorkflowTransitionRejectedException`** — so today a guard refusal on route 3 surfaces to the
  operator as a generic endpoint failure with a `500`-class shape and no park. **Discriminating it is
  part of this sub-slice, not a consequence of it**, and there are two kinds to tell apart at that
  boundary:

  - the **engine's** `WorkflowTransitionRejectedException` from step 5 — this is the one the park
    helper takes P3 on, and it carries the `guardResults` that say which guard refused;
  - the **service's** `StateError` from `control_plane_service.dart:2065` — a different refusal, raised
    *before* the engine is called and with **nothing written** (`:2049-2051`, `:2068-2069`). **It must
    keep propagating.** A catch written as "on any error, park" would park an item the engine never
    touched, which is a fourth way to get §5.1.1a's order wrong.

  **P3 is therefore taken in a `catch` that tests the exception type**, in
  `apps/server/lib/src/endpoints/workflow_endpoints.dart` — a file in `apps/server/lib`, outside this
  slice's two transition-table files, and named here as a required third file. Naming the engine
  method removes the ambiguity about *which* hop was refused; naming the endpoint with `file:line` is
  what makes the edge **reachable**, because the reachable place to catch it is the one already open.

**A single shared helper**, named in sub-slice 2b, so the three callers (route 1's catch, the
route-3 endpoint, and step 2's `requestHumanDecision`) cannot drift — the same discipline
`human_decision_routing.dart:151-162` states for `targetFor`/`escalationTargetFor`
("a value here that disagrees … does not error — it silently stops the escalation index advancing").
The helper's `why` string is written **once**, so the durable `blockingReason` an operator reads is
the same whichever route parked the item.

### 5.2 The undelegated clause is unconditional — **DECIDED: Reading B**

**This is no longer the open question revision 2 left for a reviewer to judge. It is a recorded
human decision, and this section states what it decides and what it costs.**

> **`.decisions/7f3e2a95-6c81-4d70-b215-8e94a0c7d382.yaml`**
> `type: ARCHITECTURE` · `status: RESOLVED` ·
> `resolution.selected: READING_B_CLAUSE_COVERS_EVERY_ROUTE` ·
> `label: "The gate applies to waitingForHumanDecision -> implementationReady as well as the
> automatic routes"` · `decided_by: operator` · `decided_at: 2026-10-17T13:40:00Z`
>
> **`rationale_given`, verbatim:** *"The clause is unqualified — 'an implementer dispatch must be
> preceded by a satisfied design review for items originating on these two paths' — and **a clause
> that is not qualified is not narrowed by a rationale that explains why it was written.** Reading A
> was rejected."*
>
> **`rejected_alternative`, verbatim:** *"Reading A … was recommended by neither party unprompted: the
> design lane argued for it, and the independent reviewer found it 'defensible and not compelled'
> while noting **the design disposes of the rationale 'as a different field' in a single clause**, and
> never reconciles the design's own cost table — the strongest evidence against its own pick."*

**Revision 2's §5.2 was written to be judged and was instead decided against.** Three things in it
were wrong in the way the operator's `rejected_alternative` names, and they are corrected here rather
than left standing with a new label:

1. **The "different field" disposal is removed.** Revision 2 argued Reading B on the ground that
   *"Reading A imports one from a different field of the same document"* — which is the sentence the
   operator's rejection singles out. **This revision does not rely on it.** The reasoning it does
   rely on is the operator's own: the clause is unqualified, and a rationale explaining why a clause
   was written does not narrow it. Revision 2's grounds 2–4 are retained below as the design's
   supporting argument, not as the decision's basis.
2. **The cost table is reconciled rather than left to argue against itself.** Revision 2 stated
   Reading B's cost and then still offered the reviewer the choice. Under the decision the cost is
   *accepted*, and the honest task becomes naming what the operator must be told and who owns it —
   which is the "next slice, named owner" below.
3. **The dead end is not accepted as a state to leave the item in.** The decision says so in terms:
   *"This decision does not make the dead end acceptable; it makes it the next thing to build."*
   **§5.2.2 now records it as SLICE 1** — the first slice — and `.decisions/b81f40c7…` says so in
   terms, having overridden the "after the gate" ordering this document's previous pass chose (§0.2).

#### The two readings, and which one is in force

| | Reading A (revision 1) — **REJECTED** | **Reading B — DECIDED** |
|---|---|---|
| Text | "unattended" (from `rationale_given`) qualifies the clause, so a human's resolved decision **is** the override | the `delegated` clause is **unconditional**: *"an IMPLEMENTER dispatch must be preceded by a satisfied design review for items originating on these two paths"* |
| Guard on route 1 | yes | yes |
| Guard on route 2 (`agentFailed`) | yes | **no** — no caller (§2.1); G11 covers it |
| Guard on route 3 (human) | **no** | **yes** |
| Human can reach an implementer without a design review | **yes** | **no** |
| Status | rejected by the operator 2026-10-17 | in force |

#### The design's supporting argument for Reading B (retained, no longer load-bearing)

1. **HD-1's author drew the line explicitly, in the same sentence.** *"The gate's SHAPE is a design
   question and is delegated to the design lane: … **What is NOT delegated is that an IMPLEMENTER
   dispatch must be preceded by a satisfied design review for items originating on these two
   paths.**"* The clause is stated without a qualifier.
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
4. **Reading A's exemption was not theoretical.** `HumanDecisionRouting.targetFor` routes **four**
   decision pairs to `implementationReady`
   (`packages/workflow_engine/lib/src/transitions/human_decision_routing.dart:103-104, 107-108,
   109-110, 119-120`): `(engineeringReview, rework)`, `(qaWaiver, reject)`, `(qaRework, reject)`,
   `(humanQaApproval, reject)`. **Each becomes reachable for an intake origin as soon as the missing
   runtimes land** — `(engineeringReview, rework)` the moment a design-remediation or feature-intake
   run produces a commit (M8/M10, slice 5); the `qa*` and `humanQaApproval` pairs the moment slice
   3c makes `qaInProgress` reachable at all. Under Reading A, HD-1's invariant would have held today
   and dissolved the first time anyone shipped the backlog HD-1 was decided *because of*.
   - *Correction to a prior review's phrasing, retained:* an earlier review named
     `(escalation, approve)` as a fourth human route. It is in the edge's
     `blockingHumanDecisionResolved` set (`:619-622`), but `targetFor(escalation, approve)` is
     `designNotRequired` (`human_decision_routing.dart:132-133`), so the routing table does **not**
     send it to `implementationReady`. The edge would permit it; nothing routes it there. Recorded,
     not relied on.

#### 5.2.1 What Reading B costs, stated plainly

**Reading B means no human can move an intake-origin item to an implementer until an approved
`design_revision` row exists — and nothing in this repository writes one** (§4.3, M5–M7). The park's
exits, via `targetFor`, are therefore:

| Human answers | `targetFor` sends it to | Effect |
|---|---|---|
| `(escalation, approve)` | `designNotRequired` (`:132-133`) | re-enters triage; walks back to `agentCompleted`; refused again; parked again. **A cycle — visible, durable, and dispatching nothing.** |
| `(escalation, rework)` | `planning` (`:134-135`) | re-plans. |
| `(escalation, cancel)` | `cancelled` (`:121`, the `(_, cancel)` catch-all) | **honest stop.** |
| `cancelled` / `terminated` | generic escape | **honest stop.** |

**So the honest statement of Reading B's consequence is this:** until the design lane exists,
feature-intake and design-remediation items **cannot reach an implementer**. They park, visibly, with
a durable reason and a real pending decision (§5.1.1a), and a human can re-triage, re-plan or stop
them — and cannot dispatch code from a request that has never been designed.

**That is HD-1's requirement being unsatisfiable by the current repository, not a defect of this
design.** HD-1's `rationale_given` rejected "refusing completion outright" because it *"re-creates
the dead end this work exists to remove."* Reading B does not refuse **completion** — the item
completes, is recorded, and parks. What it refuses is the **implementer dispatch**, which is exactly
what the undelegated clause says it must refuse. §6 slice 4 (M6 + M7 + M5) is what makes the park
resolvable, and it is sequenced so the gate is already in place when the producer appears.

#### 5.2.2 The dead end Reading B creates — **NOW SLICE 1, and the invariant it exists to enforce**

**Under Reading B the park's human surface offers re-triage / re-plan / stop, and NONE of them is
"do the design review"** — which is the very thing the item is parked waiting for. This was
revision 2's §13.7 "deliberate gap". **The operator's decision closes the question of whether to
accept it, and the answer is no** (`consequence`: *"The dead end this creates must be solved FIRST …
This decision does not make the dead end acceptable; it makes it the next thing to build."*).

**What the decision changed about slice 2a's content:** revision 2 noted that its sub-slice 1a — the
gate's, now 2a — pinned both guards in one commit and left the reading open. **With the answer recorded, the route-3 guard is not
optional and 2a is specified with both guards** (§5.3, R12). The decision's own `precondition` says
the same: *"sub-slice 1a's pinned content depends on this answer … so slice 1 may not begin until
this decision is recorded — which it now is."* (**"1a" and "slice 1" there mean the gate — this
revision numbers them 2a and slice 2; §0.2's gloss.**)

**And a second decision changed the ORDER, not the content.**

> `.decisions/b81f40c7-2a96-4e38-bd51-6c07e9f3a824.yaml` · `resolution.selected: HUMAN_SURFACE_FIRST`
> · `decided_by: operator` · `decided_at: 2026-10-17T14:10:00Z`
> — *"Slice ordering REVERSES: the human surface becomes the FIRST slice, the gate follows."*

The previous pass routed this as **slice 1.5, after the gate**, and flagged that ordering as its own
judgement against the decision's word "FIRST". **That judgement is now overridden, on authority.**
§0.2 keeps the merits argument in full and states plainly which axis the override was on; the
independent review agreed with the merits and held that *"a flagged judgement is not a discharged
obligation."*

#### The invariant the reversal exists to enforce — stated, and ASSERTED

> **NO item may be parked at `designReviewRequired` before the decision raised there offers a
> "do the design review" answer.** *(the decision's `invariant`, verbatim)*

**This artifact's previous pass asserted that property by convention and nothing checked it** — which
is the failure mode this design has now produced twice and names twice (R3, R3b: *"G7 asked whether
the item MOVED and nothing asked what it CARRIED"*). **So the invariant is pinned by an assertion,
and the assertion fails on absence: G17** (§6, sub-slice 1c). Its shape:

> **G17 — `designReviewRequired` has an in-edge (`P2` or `P3`) IF AND ONLY IF the decision raised at
> the park offers an answer that routes to `designApproved`.**

Both halves are checkable against the tree, and neither is a convention:

- **the "if"** — the park's option set (`requestHumanDecision`'s `options`) contains a
  `(decisionType, choice)` pair for which **`HumanDecisionRouting.routesTo(type, choice,
  WorkItemState.designApproved)` is true** — the predicate the routing table already provides for
  exactly this question (`:219-225`), rather than a comparison this document would hand-roll;
- **the "only if"** — `designReviewRequired` appears as a target in `work_item_transitions.dart` at
  all, i.e. P2 and P3 are absent.

**Today G17 fails**, and it is *supposed* to: `designReviewRequired` does not exist yet (it arrives
with slice 2d) and the human surface does not exist yet (slice 1). **What the assertion forbids is the
window between them** — the gate and park landing while no answer can produce what the item waits for.
That window is precisely what the previous pass's ordering opened and the reversal closes. A park
with no way to produce what the item waits for is the dead-end class (F-42, F-50, F-54) this area has
produced repeatedly, and it is now checked rather than assumed.

**What this design cannot specify, and hands on:**

| | |
|---|---|
| **The gap** | No `HumanDecisionType` offers "produce an approved design revision". The park's `escalation` answers route to `designNotRequired` / `planning` / `cancelled` — none is the design review. `FOLLOW_UPS` **F-55** records this in the Manager's own words: *"The operator is offered three answers — approve → `designNotRequired`, rework → `planning`, cancel → `cancelled` (`human_decision_routing.dart:121, 132-135`). **None of them is 'do the design review.'**"* |
| **Why it needs care, and what is actually required** | It needs a `targetFor` arm whose target is `designApproved`, and `human_decision_routing.dart:151-162` states that `targetFor` and `escalationTargetFor` must move in lockstep or escalation accounting *"silently stops"* advancing (`:159-162`). **CORRECTED IN PASS 3, and this is the L3 pattern in the other direction:** the previous pass stated that rule flatly for this work, and the cited range **does not state it for an `approve` answer**. `escalationTargetFor` returns `null` for any choice that is not `reject` or `rework` (`:196-199`), so an `approve` arm has **no lockstep obligation at all** — and `_isEscalationTransition` short-circuits on the same condition (`durable_workflow_engine.dart:1012-1015`). `:213`'s `(designApproval, _)` arm exists for `reject`/`rework` and is **unreachable for `approve`**. **So the lockstep rule bites only if the new answer is a `reject` or a `rework`, and "do the design review" is neither.** Pinned by **G17b** so the answer stays a decision rather than a side effect. The architecture change that DOES remain is the `HumanDecisionType` itself, which `AGENTS.md` reserves to the human. |
| **What IS specified here** | **Slice 1 itself**, to the point an implementer needs (§6): the new `HumanDecisionType`, the `targetFor` arm, the matching `escalationTargetFor` arm, the park's option list widened to include the new answer, and **G17**. §6 sub-slices 1a–1c. This is the material change from the previous pass, which specified only a hand-off. |
| **The shape of the answer, named** | The existing type is already there: `targetFor(designApproval, approve) = designApproved` (`human_decision_routing.dart:93-94`, inside `targetFor` at `:88-138`). **What is missing is a `HumanDecision` of that type reachable FROM the park** — the park's `options` must offer it, and its blocking decision must be answerable while the item sits at `waitingForHumanDecision`. **This design's reading is that no NEW enum value is needed**, and a reviewer who thinks one is — or who thinks re-using `designApproval` conflates approving a design with producing one — should say so; it is `points_for_independent_review: SLICE-1-MECHANISM`. **Whether answering it can actually produce an approved revision is slice 4's job (M5–M7); until then the answer exists and the producer does not, which is the same `DECLARED`-not-`PASSING` state §5.2.1 already names.** Stated so no one reads slice 1 as making the park resolvable. |
| **What is specified about the options list** | It is **explicit** (`requestHumanDecision`'s `options` argument; `stalled_work_item_gate.dart:199-211` is the shipped shape — two `HumanDecisionOption`s with `optionId`, `label`, `description`, then `recommendation` and `blocking`). §6 sub-slice 1b pins the widened set, and G16 is **widened with it** — G16 as written today asserts "exactly escalation's three", which becomes "exactly the set including the design-review answer". |
| **`FOLLOW_UPS` F-55 — NOW EXISTS** | **Correction (M-A).** The previous pass cited `FOLLOW_UPS` **F-55** in **six places** across two artifacts as an existing ledger entry, while stating in four of them that it had never been written. **It was genuinely absent — the file ended at F-54 — and the pointer originated in the decision's own `consequence` text.** `0bfb6fb` has since written **F-55** (§16, *"the park's human surface has no 'do the design review' answer"*) **and F-56** (the process note). **Every one of those six citations now resolves, and F-55 independently confirms this section's gap statement** — its `### The gap, precisely` names the same three answers and the same `human_decision_routing.dart:121, 132-135` citations, all re-verified above. **It also reserves the sequencing question to the operator, which is how `b81f40c7…` came to exist.** `docs/engineering/FOLLOW_UPS.md` is Manager-owned; this lane read F-55 and F-56 and wrote neither. |
| **What makes it cheaper by then** | Slice 4 (M5–M7) is what makes the park resolvable at all. **This lane's judgement, and it is now moot as to ORDER and stands only as to SCOPE:** slice 1's decision and slice 4's producer are the same missing capability, so they should be scoped together. The operator has ordered them apart; that is the reversal's cost, named in §0.2. |
| **Stated residual risk under the new order** | **The window between slice 1 and slice 2 is the one this lane argued against and lost.** During it the platform carries a `HumanDecisionType` and a routing arm that **no guard consumes** — an answer an operator is offered that does not change whether an item may reach an implementer. It is strictly *additive* (§5.2.1's table already held that no park answer reaches an implementer), so nothing regresses; it is an answer to a question nothing is yet asking. **Recorded as R4** in `design-revision.md` §10. |
| **The residual that survives everything** | "stop" (`cancel` → `cancelled`) remains the only park answer that terminates, and it still terminates: slice 1 does not change §5.1's refusal, it changes what the operator is offered when the refusal is answered. After slice 2 lands, the answer exists and the producer does not — until slice 4. **That gap is R4 and it is not closed by slice 1.** |

> #### ⚠ WHAT AN INDEPENDENT `design-reviewer` IS NOW BEING ASKED
>
> **Not** whether Reading B is right. It is decided, in `7f3e2a95`, by the operator, and this
> document applies it.
>
> **Not** whether the sequencing is right. It is decided, in `b81f40c7`, by the operator, and this
> document applies it — human surface first. The merits argument for the other order is recorded in
> §0.2 because the decision's own `authority_note` says it *"is recorded and is not dismissed"* and
> overrides *"on AUTHORITY, not on reasoning."* **A reviewer who wants to re-argue the merits should
> know the axis they are on: it is a merits argument against a decision that was made on authority,
> so re-arguing it here changes nothing without a new human decision.**
>
> **Instead, three things that the decisions did not settle — all of them this design's own:**
>
> 1. **Is this document's application of Reading B faithful and complete** — §4.1's guard on both
>    caller-bearing edges, §5.1's park, §5.1.1a's two-step `requestHumanDecision` **and the coupling
>    that makes the order load-bearing**, §5.1.1b's rejection of the `waitingForHumanDecision`
>    alternative, and §5.1.2's chain to `file:line`. The decision chose a *scope*; it did not choose a
>    mechanism, and the mechanism is this design's own.
> 2. **Is slice 1 as specified here the right slice 1?** The operator ordered the human surface first
>    and **left the mechanism to this design** — the decision's `consequence` names the cost (a new
>    `HumanDecisionType` plus a routing arm, two tables in lockstep) without prescribing the shape.
>    §6 sub-slices 1a–1c are that mechanism, and **they are the substantive new content of this pass**.
>    The sharpest question: **does G17 state the invariant the decision requires, or is it a weaker
>    restatement of it?** A reviewer who thinks the invariant should be checked at a different seam —
>    on the `options` list rather than on the transition table, say — should say so, because G17 is
>    the only thing standing between this document and the assertion-by-convention it corrects.
> 3. **Is the cost named in §0.2 the right cost?** The reversal leaves, for the slice-1→slice-2 window, a
>    decision type and a routing arm that **no guard consumes**. This document calls that additive and
>    harmless; **a reviewer who thinks an unconsumed human-facing answer is itself a dead end — an
>    operator offered something that changes nothing — should make that finding.** It is the one
>    respect in which the merits argument survives into the implemented order, and it is the reason the
>    merits argument is kept rather than deleted.

### 5.3 How §5.1 and §5.2 interact — note for the implementer

**Independent review observed this and it is correct:** fixing B1 makes the route-3 reachability
question live, and the two items cannot be sequenced independently.

**Before slice 1 lands (today, and after the reversal):** route 3 is unreachable for the two intake
origins. No `qa*` or `humanQaApproval` decision can be pending, because `qaInProgress` is unreachable
(`design-revision.md` §2.1 — nothing takes `reviewApproved -> qaInProgress`), and no
`engineeringReview` decision can be raised, because a triage run commits nothing so the review
resolver returns `null` and the handler stands down (§5.1). So guarding route 3 changes nothing
observable — which is exactly why revision 1 could call it optional.

**After slice 1 lands (the reversal's window):** **nothing about §5.1 changes.** The gate is still
absent; no item is parked; no intake origin reaches `implementationReady` if it does not today. What
changes is that a `designApproval`-typed decision with a `targetFor` of `designApproved` is
**raisable and answerable** — an answer that exists before anything raises it. **This is additive and
this lane has lost the argument that it should not be:** §0.2 states the merits case and states that
it was overridden on authority. **G17 passes in this window for the honest reason** — `designReviewRequired`
does not exist yet, so neither half of the iff is violated by a park that cannot happen.

**After 2d lands:** the refused item parks at `designReviewRequired` and then raises its
blocking decision via `requestHumanDecision` (§5.1.1a), landing at `waitingForHumanDecision` with a
real `blockingHumanDecisionId` and `blockingReason`. The decision is `escalation`-typed, whose
answers route to `designNotRequired`/`planning`/`cancelled` — never to `implementationReady`. **Route
3 is still not reached from the park.** **This is where G17 becomes load-bearing:** from here the park
exists, and the new answer from slice 1 must be in its option list or the invariant is violated.

**Route 3 is nevertheless reached from elsewhere, and that is why P3 is required rather than
optional.** The four `targetFor` pairs that route to `implementationReady` belong to the item's *own*
lanes — `qaFailed -> waitingForHumanDecision` (`:709-715`) raises `qaRework`/`qaWaiver`,
`reviewInProgress -> waitingForHumanDecision` (`:351-360`) raises `engineeringReview`, and so on.
**When those lanes become reachable (slices 3c and 5), route 3 refuses for an intake origin with the
item at `waitingForHumanDecision` and a now-RESOLVED decision** — and §5.1.1b shows that position is
unrecoverable. **P3 is the sink for exactly that case.**

**After slice 3c lands:** `reviewApproved -> qaInProgress` gets a caller (`design-revision.md` §8,
slice 3c widened), so an item can be failed by QA, raise `qaRework`/`qaWaiver`, be refused by a human,
and be routed to `implementationReady` by `targetFor`. **Now route 3 matters, and P3 has a caller.**

**After slice 5 lands (M8/M10):** a real intake run commits, an `engineeringReview` decision
becomes raisable, and `(engineeringReview, rework) -> implementationReady` becomes a live path for an
intake origin. **This is the path Reading B closes** — the decision is recorded
(`.decisions/7f3e2a95…`), so the guard is required and P3 must exist.

**The sequencing consequence, which is the actionable part:**

> **Sub-slice 2a MUST land both route-1 and route-3 guards in one commit.** Splitting them creates a
> window in which the park exists but the human route is unguarded — and every slice-3 and slice-5
> change above widens that window's value. A reviewer seeing "route 1" and "route 3" land separately
> should treat it as a finding.
>
> **This is no longer a design choice. `.decisions/7f3e2a95…`'s `precondition` states it directly:**
> *"sub-slice 1a's pinned content depends on this answer … so slice 1 may not begin until this
> decision is recorded — which it now is."* **2a's pinned content changed with the answer, and this
> is the change:** revision 2 pinned the route-3 guard as the point under judgement; it is now
> pinned as required, and Reading A's alternative (drop the guard, restore P3) is **closed**.
> (**"1a"/"slice 1" in the quoted decision are the gate — this document numbers it 2a/slice 2.
> §0.2's gloss.**)

**And one sequencing consequence that is new, and comes from the reversal:**

> **Slice 1 must land BEFORE slice 2, and slice 1 alone is not enough.** `b81f40c7…` orders it, and
> **G17 is what makes the order checkable rather than asserted**: if `designReviewRequired` acquires
> P2/P3 while the park's option set carries no answer routing to `designApproved`, G17 fails. That
> is the specific window this document's previous pass opened by routing the human surface as
> "slice 1.5", and §5.2.2 states the invariant in the decision's own words.

---

## 6. Sub-slices, each independently mergeable

**Two ordering constraints, and both are load-bearing.**

**A. Across slices, from `.decisions/b81f40c7…`: slice 1 (the human surface) precedes slice 2 (the
gate).** Slice 3 (the evaluator), slice 4 (the design lane) and slice 5 (the contracts) follow
unchanged. §0.2 carries the crosswalk from the previous pass's numbering, so a reader holding that
review can follow.

**B. Inside slice 2, from §5.3: 2a must add BOTH the route-1 and the route-3 guard in one commit** —
now required by `.decisions/7f3e2a95…`, not merely recommended by this design. 2b, 2c and 2d may be
separate. **2d must land no later than 2a+2b in practice**, because without the park the route-1
guard refuses into a void — that is the BLOCKING finding reproduced in code. (The previous pass wrote
"1d must land no later than 1a+1a+1b", which double-counted 1a; the constraint is one guard commit
plus the context writer.)

### 1 — the park's human surface — "do the design review"

**NEW in this pass, and it is the substantive change.** `.decisions/b81f40c7…` ordered it first
and left the mechanism to this design. **Files, all four verified:**
`packages/platform_contracts/lib/src/enums/human_decision.dart:1-30` — **this is where
`HumanDecisionType` is declared** (the enum carries NINETEEN values at `:1-20`, each with a `wire` at
`:22-24`; `designApproval('design_approval')` is `:2`). **It carries no `options` field**, so the
answer set is a property of the **call site**, not of the type — which is why sub-slice 1b touches the
park helper and 1a touches the enum separately, and why conflating them would hide the work.
`packages/workflow_engine/lib/src/transitions/human_decision_routing.dart` — the `targetFor` arm
(`:88-138`) and, **only if the answer is a `reject` or a `rework`**, the `escalationTargetFor` arm
(`:192-216`; G17b says it is not, for an `approve`).
`packages/workflow_engine/lib/src/transitions/work_item_transitions.dart` — **only** if the new answer
needs a bound on an existing edge; on this design's reading (re-use `designApproval`) it does not.
And the park helper's option list, in slice 2b.

- **1a — the type and the `targetFor` arm.** Add the `HumanDecisionType` whose answer means "do the
  design review", with a `targetFor` arm to `designApproved`. **The existing type to reuse is
  `designApproval`**, whose `(approve)` arm already targets `designApproved`
  (`human_decision_routing.dart:93-94`, inside `targetFor` at `:88-138`) — so the honest reading of
  "what is missing" is *a decision of that type reachable from the park*, not necessarily a new enum
  value.
  **And the lockstep rule does NOT bind this arm, which is the part an implementer would get wrong.**
  `:151-162` requires `targetFor` and `escalationTargetFor` to move together or escalation accounting
  *"silently stops"* advancing — **but that obligation is conditional on the answer being a `reject` or
  a `rework`.** `escalationTargetFor` returns `null` for any other choice (`:196-199`), and
  `_isEscalationTransition` short-circuits on the same condition
  (`durable_workflow_engine.dart:1012-1015`), so **an `approve` answer increments no escalation index
  and appends no `EscalationTriggered` record.** `:213`'s `(designApproval, _)` arm exists for
  `reject`/`rework` and is unreachable for `approve`. **Do not add an `escalationTargetFor` arm for an
  `approve` answer** — doing so would start escalation accounting silently on a design approval, which
  is the exact failure `:159-162` warns about. **G17b pins this.** (If slice 1's answer turns out to
  be a `rework` — "send it back to be designed" — the lockstep rule binds and `:213` already covers
  the pair.)
- **1b — the park's option list gains the answer.** One `HumanDecisionOption` added to the set slice
  2b raises, beside the three §5.2.1 names. **`HumanDecisionOption` carries `optionId`, `label` and
  `description`** and `requestHumanDecision` also takes `recommendation` and `blocking`
  (`stalled_work_item_gate.dart:199-214` is the shipped shape for all five).
- **1c — G17 and G17b, the assertions.** §5.2.2 specifies G17 and §6's table carries both.
  **G17 is the deliverable of this sub-slice**: it fails if `designReviewRequired` has an in-edge while
  no park answer routes to `designApproved`, and it fails if such an answer is offered while the park
  is still unreachable — **which is the window the reversal exists to close.** G17b pins 1a's
  escalation-index consequence so it stays a decision.
- **What slice 1 does NOT do, stated so it is not over-read:** it does not make the park resolvable.
  Answering the new question routes the item to `designApproved`, and **nothing produces an approved
  `design_revision` until slice 4** (M5–M7, §6 of `design-revision.md`). **After slice 1 and slice 2
  and before slice 4, the operator has an answer that changes the item's state and still cannot
  produce what the item needs.** That is the same `DECLARED`-not-`PASSING` distinction §5.2.1 makes,
  applied to a different artifact, and it is **R4**.

### 2a — the guard and its context contract

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
| **G5′** | the guard is **present** on `waitingForHumanDecision -> implementationReady` **and** the edge still admits all **six** `blockingHumanDecisionResolved` pairs | the route-3 guard is dropped, or added at the cost of an existing bound |
| G6 | the guard is **absent** from `(implementationReady, agentExecuting)` | the dispatch edge is made unsatisfiable and the lane strands |
| **G7** | **a refused `WI-feature-*` item is at `designReviewRequired` — not `agentCompleted` — within one tick of the refusal** | **the park is missing, or deferred to a drain that stands down (§5.1)** |
| **G8** | **the same, for `design-remediation-*`, and via the route-3 refusal as well as route 1** | only one of the two park entries (P2/P3) is implemented |
| **G9** | **a second tick over an already-parked item performs no transition and raises no second decision** | idempotence is lost — `server.dart:1412-1414`'s requirement |
| **G10** | **after a human resolves and is routed to `implementationReady`, the guard refuses and the item returns to `designReviewRequired`** — no loop, no dispatch | the route-3 guard is missing, or P3 is missing |
| **G11** | **drift:** the guard is present on `:265-267` **iff** some production (non-`test`) caller of `agentFailed -> implementationReady` exists | §2.1's rule is forgotten and the guard is added while the edge is still callerless |
| **G12** | **`designReviewRequired` is in no `JobDefinition.entryStates`**, asserted over the parsed definitions rather than by name | M6 wires `designReviewDefinition` or a future definition over this state and the park starts dispatching |
| **G13** | **no edge out of `designReviewRequired` other than P4** (plus the generic escapes) | a second predecessor into `planned`/`designNotRequired` re-opens the loop `:45-50` records |
| **G14** | **NEW — the durable reason.** A refused intake item reaches `waitingForHumanDecision` with `item.blockingReason` **non-null and non-default**, and it is the park helper's `why` string | the park is taken by a bare `transition`, which writes `blockingReason: null` for any non-`waitingForHumanDecision` target (`durable_workflow_engine.dart:222-225`) — **the exact defect this revision corrects** |
| **G15** | **NEW — the blocking decision id.** The same item reaches `waitingForHumanDecision` with `item.blockingHumanDecisionId` **non-null**, and that decision is resolvable through `resolveHumanDecision` (`durable_workflow_engine.dart:747-748` requires `blockingHumanDecisionId == decisionId` **and** state `waitingForHumanDecision`) | the park is taken by `transition` instead of `requestHumanDecision`, which nulls the id for any other target (`:215-221`) — a decision nothing can answer |
| **G16** | **NEW — the operator surface.** A refused intake item at `waitingForHumanDecision` appears as a pending blocking decision in the operator surface, and its offered options are **exactly the set §6 sub-slice 1b specifies** — re-triage / re-plan / stop (`escalation`'s three) **plus** the design-review answer, and no others | the options list is left implicit, widened past §5.2's set, or an operator is offered an answer the gate will refuse. **WIDENED by correction pass 3:** the previous pass asserted "exactly `escalation`'s three — no fourth", which would have **failed** the moment slice 1 landed. G16 is now pinned to the set, not to the enum. |
| **G17** | **NEW — the reversal's invariant.** `designReviewRequired` has an in-edge (`P2`/`P3`) **iff** the park's `options` list contains a `(decisionType, choice)` pair for which **`HumanDecisionRouting.routesTo(type, choice, WorkItemState.designApproved)` is true** (`human_decision_routing.dart:219-225`). Both halves read the parsed routing table and the parsed transition table, never a name or a comment | the gate and park land while no park answer can produce what the item waits for — **the dead-end class (F-42, F-50, F-54), which is what `.decisions/b81f40c7…`'s reversal exists to close.** Also fails if such an answer is offered while the park is still unreachable, which is the same defect pointed the other way |
| **G17b** | **NEW — the escalation-index consequence of the new answer.** Answering the park's design-review question with `approve` does **not** increment `metadata['escalationIndex']` and appends **no** `EscalationTriggered` record. Asserted so it is a decision rather than a side effect | an implementer reads `:151-162`'s lockstep rule as requiring an `escalationTargetFor` arm for the new answer and adds one, **silently starting escalation accounting on a design approval.** Verified false twice over: `escalationTargetFor` returns `null` for any choice that is not `reject`/`rework` (`:196-199`), and `_isEscalationTransition` short-circuits on the same condition (`durable_workflow_engine.dart:1012-1015`). `:213`'s `(designApproval, _)` arm is therefore **unreachable for `approve`** |

**G5′ says six, and the count must be exact.** G5′ exists to prove the new guard was added **at the
cost of no existing bound**, so an off-by-one would defeat the assertion. The edge's
`blockingHumanDecisionResolved` set (`:604-623`) contains **six** pairs:
`(engineeringReview, rework)`, `(engineeringReview, reject)`, `(qaWaiver, reject)`,
`(qaRework, reject)`, `(humanQaApproval, reject)`, `(escalation, approve)`. Revision 2's "all five"
was inherited verbatim from the **stale comment** at `:595` (*"WHICH of the five pairs move here is
`OD-3`"*), which predates the set as it now stands. **The sixth is `(escalation, approve)` — the pair
§5.2 argues about — so the count is load-bearing, not cosmetic.**

**G7 is the assertion revision 1 did not have and could not have had.** G1 and G2 alone are
satisfied by a dead end: a refused item that simply stops at `agentCompleted` passes both. **This
document no longer cites G1/G2 as evidence that the gate fails closed**, and §5.1 says so in its own
words.

**A reviewer should check G17 first, then G7, G10 and G14.** **G17 is new and it is the whole point
of the reversal**: if it does not state the invariant `.decisions/b81f40c7…` requires, then this
document has committed the L3 pattern a third time — a property asserted, in prose, with nothing
that fails when it is absent. G7 and G10 are the BLOCKING and HIGH findings of earlier rounds;
**G14 is the correction of revision 2's own error** — it is the assertion whose absence let a null
`blockingReason` pass as a durable reason in three artifacts. **G14/G15/G16 exist because B-1 was a
claim about a property that no assertion checked, and G17 exists because the sequencing reversal was
a claim about an ordering that nothing checked.**

### 2b — the context supplier, and the one park helper

**Files:** `packages/scheduler/lib/src/scheduler.dart`, `packages/scheduler/lib/src/implementation_inflow.dart`,
`apps/server/lib/server.dart`, `apps/server/lib/src/endpoints/workflow_endpoints.dart` (the
route-3 caller, named to `file:line` in §5.1.2), the composition root.

> **Correction (M-3). Revision 2's file list omitted `packages/scheduler/lib/src/scheduler.dart`,
> which is the actual route-1 context writer** — `_routeOneCompletion` builds the map that reaches
> `engine.transition` at `:1741-1813`. **And that map is a `const` literal today:**
>
> ```dart
> // packages/scheduler/lib/src/scheduler.dart:1746
> context: const {'agentAvailable': true, 'capabilitiesMatch': true},
> ```
>
> **`workItemOrigin` and `approvedDesignRevisionId` therefore cannot exist on route 1 until this
> becomes a computed map.** Revision 2 specified a context supplier for a call site that currently
> cannot carry one, and the file appeared in no sub-slice's list. It is first here.

- **One** function that fills `workItemOrigin` and `approvedDesignRevisionId` from a `WorkItem` and
  the store. **It must be the only writer of both keys** (§4.4; `design-revision.md` R11).
  - `workItemOrigin` is derived from the **work-item id prefix** and nowhere else.
    `design-remediation-DEF-x` *is* defect-origin, so "has a defect" is the wrong discriminator and
    would silently exempt the remediation lane — the prefix is the discriminator.
  - It runs on **both** route-1 and route-3 callers. Revision 1 only considered route 1; under
    §5.2 the human route needs the same two keys or the guard is inert there.
  - **The `const` at `:1746` becomes a computed map.** `metadataMerge` at `:1809-1812` is unaffected
    and is the existing precedent for passing per-item facts alongside the route.
- **One** park helper, shared by the three callers (§5.1.2). **It performs both steps of §5.1.1a:**
  the `transition` to `designReviewRequired` **and** the `requestHumanDecision` that writes the
  durable reason and the blocking decision id. Its `why` string is written **once**, so the durable
  `blockingReason` a human reads in the operator surface is the same on both entries. **A helper that
  only performs step 1 is the B-1 defect and must not be written** — that is G14.
- `PostgresDesignGovernanceStore` is **instantiated nowhere today**
  (`apps/server/lib/src/persistence/postgres_design_governance_store.dart:9-10` — verified: the only
  occurrences in `apps/server/lib` and `packages/` are its own declaration); this sub-slice adds it
  to the composition root beside the other stores (`server.dart:208-219`).
- **Per-item isolation is mandatory — and the two `try` blocks are not the same one.** `_routeOneCompletion`
  guards every per-item **read** in one `try` (`:1582-1599`) and takes the **transition** in another
  (`:1740-1843`), for exactly the reason `implementation_inflow.dart:124-126` documents in its own
  words: *"It throws INSIDE `_routeOneCompletion`'s per-item guard, which turns that throw into 'leave
  this one item alone and say so', rather than out of `tick`, which would cost the whole lane its
  pass."* The store read goes **inside `:1582-1599`**; the park goes **inside the transition's own
  catch, `:1823-1833`** (§5.1.2, M-2). Putting the park in the reads' `try` files the refusal under
  *"this item could not be read well enough to decide whether it should be reviewed or implemented"*
  — true of nothing that happens there.
  > **Correction found in correction pass 3, and it is the L3 pattern the reviewer named:** the
  > previous pass cited **`implementation_inflow.dart:1543-1578`** for this property, in this file and
  > in `evaluator-spec.md` §4.3 (V6). **`packages/scheduler/lib/src/implementation_inflow.dart` is 440
  > lines long.** The range is 1103 lines past the end of the file. **The property is real and the
  > correction above is exact** — it is stated at `:124-126` and demonstrated at
  > `scheduler.dart:1582-1599` — but the citation pointed at nothing, and a well-formed `file:line`
  > is exactly what invites acceptance without reading. **Both instances are corrected here and
  > recorded in `design-revision.md` §12.**
- **The route-3 catch discriminates by exception type, and the shipped precedent for it is named.**
  `stalled_work_item_gate.dart:228-234` is a production `on WorkflowTransitionRejectedException
  catch` around its own `requestHumanDecision` call (`:195-227`) — it logs `stall.decision-refused`
  (`:229-232`) and returns `StallGateOutcome.notParkable` (`:233`). **Follow that shape at
  `workflow_endpoints.dart:168-174`, which is currently a generic `catch` (§5.1.2), and do not
  swallow the `StateError` from `control_plane_service.dart:2065`.**

### 2c — the transition-table pins

`packages/workflow_engine/test/implementation_ready_edge_test.dart` already pins the
`waitingForHumanDecision -> implementationReady` edge by name. Extend it for **G5′ and G6**, and add
a drift guard that fails if the new guard appears on any edge not listed in §4.1 — including
`(implementationReady, agentExecuting)`, the one edge whose contamination would strand the lane.

### 2d — the park

**Files:** `packages/platform_contracts/lib/src/enums/workflow_state.dart`,
`packages/workflow_engine/lib/src/states/workflow_state.dart`,
`packages/workflow_engine/lib/src/transitions/work_item_transitions.dart`.

- P1–P5 of §5.1.1, plus G7–G10, G12–G16.
- Model the **shape** on `work_item_transitions.dart:31-53` and its comment, which is the pattern
  this repository has already shipped and proved for this exact shape. Do not shorten that comment:
  it is the design. **But do not inherit its silent-reason property** — §3.5 records that the feature
  park has no durable reason, and §5.1.1a names the component that produces one here.
- **The park's exit is `requestHumanDecision`, not a bare `transition`** (§5.1.1a), so the exit
  writes `blockingHumanDecisionId` and `blockingReason` itself
  (`durable_workflow_engine.dart:651-653`). **The order of the two steps is load-bearing and §5.1.1a
  says why** — a single-call helper is refused there, with the three failure modes enumerated.
- **No new `HumanDecisionType` in THIS sub-slice, and no new `HumanDecisionRouting` arm.** The park
  itself raises `HumanDecisionType.escalation`, whose `targetFor` arms already exist
  (`human_decision_routing.dart:132-135`, and the `(_, cancel)` catch-all at `:121` for the stop
  answer). **The human-surface arm that slice 1 adds lands before this, not here** — that is what
  the reversal is for, and **G17 fails if this sub-slice's P2/P3 land without it.**
  §5.2.1's table states what a human can then do — the honest set, which does not include reaching an
  implementer — **plus the answer slice 1 added.**
  - **Recorded because it is a first:** `escalation` is **raised nowhere in production today**. The
    only production references to the *type* are the routing arms
    (`human_decision_routing.dart:132`, `:134`) and one comparison inside the engine —
    `durable_workflow_engine.dart:996`.
    > **Correction (L-A, correction pass 3).** Three artifacts called `:996` *"the escalation-index
    > computation."* **It is not.** `:996` is the single line inside **`_isReWorkDecision`
    > (`:987-1005`)**, whose result becomes `reTriageAttempt` at `:788-792` — the
    > **`nextTriageAttempt` counter, which is not escalation accounting at all.** The
    > escalation-index predicate is **`_isEscalationTransition` (`:1007-1021`)**, which is called at
    > `:770` and whose only job is to gate the `metadata['escalationIndex']` increment at `:847-849`.
    > It **delegates** to `HumanDecisionRouting.routesToEscalation` (`:1016`;
    > `human_decision_routing.dart:228-234`, itself `escalationTargetFor(type, choice) == target`) and
    > therefore **never names `HumanDecisionType.escalation` itself** — which is exactly why
    > `grep -rn 'HumanDecisionType.escalation' --include='*.dart' apps packages | grep -v test`
    > returns `:996` and the routing arms and nothing else. **The grep RESULT claim was accurate
    > throughout and is unchanged; only the characterisation was wrong.**
    > **One corroboration found while verifying, and it is not this lane's to fix:** the class
    > comment that states the lockstep rule cites `DurableWorkflowEngine._isEscalationTransition
    > (packages/workflow_store/.../durable_workflow_engine.dart:979)` — **`_isEscalationTransition` is
    > at `:1007`, not `:979`.** The repository's own comment about this rule points 28 lines off, so
    > a reader who trusts it lands on `_getMaxEscalationForDecisionType`. **Recorded, not corrected:
    > `packages/**` is `PROHIBITED_PATHS` for this lane.**
  - This sub-slice would be `escalation`'s **first production raiser**. That is a *new use of an
    existing type*, not a new type — which is what keeps it inside slice 2 — and it is named because
    "the park uses an existing decision type" and "the park introduces the first production use of
    that type" are different statements and only the second is a surprise.
  - **The `escalation` answer set is fixed and explicit** (`requestHumanDecision`'s `options`
    argument), matching §5.2.1's table and §5.2.2's gap. **No answer routes to
    `implementationReady`, so the park can never re-enter the refusal it exists to handle** — G16.
- **The park's human surface DOES offer "do the design review" — because slice 1 lands first.** That
  is the reversal (`.decisions/b81f40c7…`, §0.2), and **G17 is what makes it an enforced property of
  the order rather than a promise in prose**. The previous pass recorded this as a gap with a named
  owner and put it *after* the gate; both halves of that are reversed. §5.2.2.
- **What the human surface still does not do:** produce an approved `design_revision`. Answering it
  routes the item to `designApproved`; **nothing writes that row until slice 4** (M5–M7). So the
  answer exists and the producer does not — R4, and the same `DECLARED`-not-`PASSING` distinction
  §5.2.1 draws for the contract.

---

## 7. Answers to the four delegated questions

| Question | Answer |
|---|---|
| **Where does the design review sit in the graph?** | Not in the design states — it cannot, they are unreachable (§3). As a **precondition on every edge into `implementationReady` that has a caller**: `agentCompleted -> implementationReady` (`:340-342`) and `waitingForHumanDecision -> implementationReady` (`:599-602`). Satisfied by an approved `design_revision` row. It reads the **artifact**, not the actor, so it is the same gate whether a machine or a human produced the revision. `agentFailed -> implementationReady` (`:265-267`) is deliberately not guarded because it has **no caller** (§2.1); G11 makes adding it a gated, drift-tested act. |
| **Which actor satisfies it?** | Today, a **human** — the only possible producer of an approved revision (§4.5). ADR 0021:126-127 names the gate `designApproval` on existing machinery. When M5–M7 land, an agent lane satisfies the **same unchanged guard**, because it reads `status == 'approved'`. |
| **What happens to an item that never gets one?** | The guard refuses; the caller **parks it at `designReviewRequired` in the same tick** (§5.1.1) — a state in no `JobDefinition.entryStates`, with no edge back to anything dispatchable, and one named way out: `-> waitingForHumanDecision`, taken by **`requestHumanDecision`**, which writes the durable `blockingReason` and a real blocking `decisionId` (§5.1.1a). **It does not wait at `agentCompleted`**, because the review drain stands down there for a no-commit producer (`engineering_review_gate.dart:2860-2871`) and the item would vanish silently, repeating every tick. **One consequence an operator will actually see, named here because this design's own idiom is to name the log they will see:** the review handler takes its `else` arm for a parked item and logs **`engineering-review-missing-artifact-unexpected-state`** (`engineering_review_gate.dart:2898-2905`) on **every tick** — `:2860` is unreachable for a parked item, because it is neither at `agentCompleted` nor in `engineeringReviewDefinition.entryStates`. **That log is expected, not a fault**, and `stalled_work_item_gate.dart` is the pattern that answers it rather than riding it: it checks the state before logging (`stall.already-parked`, `:129-133`). G7 asserts the item leaves `agentCompleted` within one tick; G9 asserts idempotence; **G14/G15 assert the durable reason and the decision id, which is what revision 2 asserted and did not check.** |
| **Do defect-origin items take the same path?** | **No.** `defect-*` is exempt; `WI-feature-*` and `design-remediation-*` are gated. Keyed on the **work-item id prefix**, not on whether an underlying defect exists — `design-remediation-DEF-x` *has* a defect and is still gated. Defect-origin is exempt because it has already been triaged, and because route 1 serves OD-10's recorded operator intent (`implementation_inflow.dart:406-407`); gating it would reopen a resolved decision for the main lane. HD-1 names only the two intake origins, and this is exactly it. |

**And the invariant — stated for Reading B, which is DECIDED (`.decisions/7f3e2a95…`).**

Every edge into `implementationReady` that has a caller carries the guard: the one automatic route
(`agentCompleted`, §2.2) and the human-driven route (`waitingForHumanDecision`). There is therefore
**no path, attended or unattended, by which an item of feature-intake or design-remediation origin
reaches `AgentRole.implementer` without a satisfied design review** — which is HD-1's undelegated
clause as the operator has now ruled it, covering **every** route.

The price is §5.2.1's table: until M5–M7 land (slice 4), those items park and a human can re-triage,
re-plan, stop — **or, from slice 1, say "do the design review"**, which moves the item to
`designApproved` and, on its own, still produces nothing, because no producer exists. **That price is
the point of the gate on this repository today, the operator chose it knowing it, and it is flagged
rather than minimised.**

### 7.1 The second invariant — the one the reversal exists to enforce

The first invariant is HD-1's: no intake-origin item reaches an implementer unreviewed. **The second
is this document's own, and it is what `.decisions/b81f40c7…` decided:**

> **No item may be parked at `designReviewRequired` before the decision raised there offers a "do the
> design review" answer.** *(decision `invariant`, verbatim)*

**Stated, and asserted.** G17 (§6, sub-slice 1c) fails if `designReviewRequired` has an in-edge while
no park answer routes to `designApproved`, and fails if such an answer exists while the park is
unreachable. **A park without a way to produce what the item waits for is the dead-end class (F-42,
F-50, F-54) this area has produced repeatedly** — and this design has now produced it twice inside
its own corrections (R3, R3b). **So the invariant is a test, not a convention**, which is the only
form this document will accept for a property it asserts.
