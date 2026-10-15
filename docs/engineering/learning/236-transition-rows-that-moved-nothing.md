# Repository Learning: 236 transition rows that moved nothing

**Feature**: IMPL-B8-REVIEW-STALL
**Date**: 2026-10-15
**HEAD**: `fix/review-item-stall`, base `0c51755`
**Category**: `CONTRADICTION` + `PROJECT_FACT` — see §1 and §7.
**Status**: CLOSED. Root cause fixed in `packages/execution_coordinator`
(`producer_execution.dart`); the stall now reaches a human
(`apps/server/lib/src/triage/stalled_work_item_gate.dart`); the refused-attempt
rendering is fixed (§7). Follow-up correction: `ce20f88` → the HEAD recorded in
the correction report.

---

## Summary

Two work items churned at four jobs a minute, steady, reaching **214 jobs each**
against a normal of six or seven. Each cycle was `jobQueued → jobClaimed →
jobDispatched → jobCancelled`, and the cancellation carried a correct, precise
conclusion — *"Stopping rather than spinning — a human should check why this item
cannot complete an execution"* — into `scheduler_event.payloadJson`, where no
operator surface reads it.

Two claims about that state were measured and both were wrong.

---

## 1. There was NO state/audit divergence. Both candidate explanations are refuted

The alarming reading of the evidence was:

```
agent_completed → review_in_progress   236 occurrences
review_in_progress → agent_completed     0 occurrences
work_item.state = agent_completed, version = 18
```

236 rows, none returning the item, and a version of 18 — which reads as "roughly
218 of those rows were written without a durable state change", i.e. **an audit
trail that can be written without the thing it audits**.

They were not. Those 236 rows are `outcome = 'rejected'`:

```sql
SELECT "outcome", count(*) FROM work_item_transition
 WHERE "workItemId" = 'defect-DEF-1791685264570406'
   AND "toState" = 'review_in_progress'
 GROUP BY 1;
--  rejected | 243
--  accepted | 1
```

`DurableWorkflowEngine.transition` appends a **rejected attempt record** and
changes nothing when the policy refuses the edge (`durable_workflow_engine.dart:205-208`).
Version 18 is exactly 17 accepted transitions plus the initial create. The engine
is correct and self-consistent.

**Both stated candidate explanations are refuted.** There is no direct state write
bypassing the engine (a), and no lost return-edge transition (b).

**The B4 retry-return pass was not involved and could not have been.** It only
acts on `JobState.retryWaiting` carrying a `transient` failure
(`scheduler.dart:_returnRetriableItemsToEntryStates`). Every job in this cycle was
`cancelled`. That pass never ran, here or anywhere in this cycle.

### The lesson, which is the reusable part

**`work_item_transition.outcome` is a column, and counting transitions without
filtering on it counts attempts as moves.** A refused transition is an audit row
by design — it is the durable record that the platform *tried* and was *refused* —
so a `GROUP BY fromState, toState` over that table silently mixes "this moved"
with "this was denied", and the mixture reads as a missing write.

The two look identical in a count and are opposite facts. Any query over
`work_item_transition` that is trying to answer *what happened to this work item*
must filter `WHERE "outcome" = 'accepted'`.

---

## 2. The item never moved at all. The breaker's own diagnosis is wrong here

`_supersessionDeferrals` is immune to re-minting and correctly reports 3. Its
reason text says the item *"kept moving before an execution started"*.

It did not move once. It sat at `agent_completed` for the whole two-and-a-half
hours, and the deferral detector saw "movement" because **the return edge was
never involved and there was nothing to return**: what recurred was a refusal,
and `WorkItemSupersededException` names both.

### Root cause (measured, in `packages/execution_coordinator/**`)

`ExecutionCoordinator.execute` moves a reviewer into `review_inProgress` by
attempting `agentCompleted → reviewInProgress`, which is guarded by
`agentResultValid()`. It supplies that result from
`_reviewEntryTransitionContext` (`execution_coordinator.dart:222-236`), which
calls **`store.latestExecutionForWorkItem(workItemId)`** — a *role-blind* lookup
ordered by `startedAt DESC`.

On the first review that is the implementer, and it is correct. After any reviewer
execution exists, the newest row is the **reviewer**:

```
executionId                    role                  status     result status
agx-wx-jb-hn7bdou768-12vlbk4   IMPLEMENTER           completed  completed
agx-wx-jb-hn7gq1nj5w-70d6ix    ENGINEERING_REVIEWER  failed     failed
```

So the coordinator hands the guard the reviewer's **failed** result, `agent_result_valid`
fails, the engine records the refusal, and `execute` re-raises
`WorkItemSupersededException` — whose own comment says *"the item moved between
the load above and this write"*, which is false in this case. Nothing ran, nothing
moved, and the edge can never be taken for this item again.

`WorkItemSupersededException` therefore conflates two facts that need opposite
answers:

| | item moved | item did not move |
|---|---|---|
| real cause | stale read | a guard that cannot be satisfied |
| correct action | requeue | **stop and tell a human** |

The scheduler only ever sees the first name, so it applies the first answer
forever. **A single exception type carrying two causes is why a correct breaker
could not stop a correct loop.**

### Fixed, and the rule it produced

`_reviewEntryTransitionContext` no longer calls
`latestExecutionForWorkItem`. It resolves **the execution that produced the
item** through `resolveProducerExecution`
(`packages/execution_coordinator/lib/src/coordinator/producer_execution.dart`),
which is now the single place in the platform that answers "what produced this
work item":

1. **`item.metadata['producerActorId']`** — primary. It names an execution id
   exactly, and `_completeSuccess` stamps it in the SAME `transition()` call
   that moves the item to `agent_completed`, so the stamp and the state are one
   durable fact. It is also a single primary-key read, and it is the identifier
   `producedCommitFor` already treats as authoritative.
2. **the newest `AgentRole.implementer` execution** — fallback, when the stamp
   is absent. `producerActorId` was added to this repository *after* the first
   `agent_completed` items were already durable; failing closed on a missing
   stamp would refuse a perfectly good review for a legacy item and **trade one
   self-lock for another**. `AgentExecution.role` is a durable column, so this is
   a determinate read, not a guess.
3. **never** "the newest execution of any role". That is the defect.

The guarantee, asserted in both directions:

> An item whose producer execution completed successfully can enter review
> **regardless of what any reviewer execution did, in any order, any number of
> times** — and an item whose producer did **not** complete is still refused.

`producer_evidence_entry_test.dart` runs the real coordinator end to end with a
failed reviewer present, and `producer_execution_resolution_test.dart` contains
a non-vacuity check: it asserts the OLD role-blind lookup really does return
the failed reviewer on the measured QA rows, so the ALLOW tests fail against
the old code rather than passing vacuously.

### The lesson that generalises

**A "latest X" lookup is only correct until X stops being the latest.** The
lookup was right for the first review of an item and wrong for every one after,
and no test caught it because every existing test ran on a fresh item. The
defect is not that the lookup was role-blind; it is that **the thing being
looked up and the thing the guard needed were different things**, and nothing
in the type system said so.

### STILL OPEN, and in a path this lane does not own

`apps/server/lib/src/review/engineering_review_gate.dart:700` performs the same
role-blind `latestExecutionForWorkItem` lookup to supply the identical
`agentResultValid()` evidence for `engineeringReviewMissingArtifact`. That path
has the same defect and has NOT been fixed: `apps/server/lib/src/review/**` is
PROHIBITED to this lane. It is one call away from being fixed by passing the
already-resolved producer result, and the shared function now exists for
exactly that. **Escalated as a finding, not worked around.**

---

## 3. The breaker stopped the JOB. Nothing stopped the PRODUCER.

`JobQueue.enqueueIfAbsent` yields a dedupe key the moment its holder is
`cancelled` — a deliberate, documented rule. The cap firing IS a cancellation, so
the key was free and the next tick minted a fresh one. Because the deferral count
is taken across every job the item has ever held, the fresh job was over the cap
on its **first** supersession and cancelled immediately: four ticks per job, one
job per cycle, forever.

**Cancelling a job and stopping the work that mints jobs are different acts, and
only the second ends a loop.** This is the generalisable half of B8, and it is
independent of §2: any breaker that ends a job on a released key leaves the
producer running.

---

## 4. What this lane changed, and the property that proves it

`Scheduler` now **STALLS** a work item: the cap's cancellation records the work
item's `version` at the moment it fired, and every later tick refuses to mint for
an item whose version has not moved past it. A stall is reported on
`SchedulerTickResult.stalled` and its queued jobs are withdrawn.

**The class of stop was chosen deliberately, and the reasoning is worth keeping.**

A terminal *workflow state* is not available here, and not as a matter of taste:
`agentCompleted`'s only routes out are `implementationReady`, `reviewInProgress`
and `designInReview`, and the review gate cannot reach `waitingForHumanDecision`
without passing through `reviewInProgress` — which is the edge that is refused.
**There is no legal transition to park this item on.** What was available is the
only lever that actually stops the bleeding: the producer.

It is recoverable, and the recovery needs no new write surface: the diagnosis is
lifted by evidence, and the evidence is `WorkItem.version`, the durable counter of
real moves. A producer running again, or an operator action on the item, moves it,
and moving it lifts the stall. No flag for anybody to remember to clear.

**The assertion is on a COUNT, because a state assertion cannot see this defect.**
The item reads `agent_completed` while the lane spins and while it does not:

| after 12 ticks | jobs for the item | worker executions |
|---|---|---|
| `0c51755` | **9** | 12 |
| with the stall | **1** | 4 |

---

## 5. The cost lesson: `O(items × jobs)` reads on every tick broke another lane

The first implementation derived stalls per work item — `listJobsForWorkItem` then
`readEvents` for each job, for every item, on every tick. It broke
`capacity_limit_test.dart` T5 ("the cap survives a restart") at every load.

It was **not** load. The baseline passed the full suite at the same load average.
`SerializedJobStore` models every durable read as two event-loop yields, and that
test calibrates its interleaving on how many yields a tick spends, so the extra
reads pushed the restarted process past the point where it could still take a
freed slot.

A store read is not free because it is indexed, and a tick is the one place in
`packages/scheduler` that must not get slower for every other work item in the
system. The sweep is now **inverted**: one `listJobs()`, a row-level prefix test
on `Job.cancelReason`, and **zero** event-log reads unless a row matches.

Recorded because the tempting shape — "derive it where the other derived facts are
derived, per item" — is the one that costs `O(n²)` on the hottest path in the
lane.

---

## 6. The operator surface is DELIVERED, and it needed no new endpoint

The brief asked for the conclusion to reach the operator. At `ce20f88` it did
not, and the blocker was structural rather than a matter of effort — the
`review_repair` lane's pattern needs a `models/*.yaml` to declare a protocol
model, and `apps/server/lib/src/models/**` was outside `OWNED_PATHS`:

| needed | path | status |
|---|---|---|
| tick → operator channel | `apps/server/lib/server.dart` | **done** — all three lanes' `stalled` lists are drained |
| drain | `apps/server/lib/src/triage/stalled_work_item_gate.dart` | **done** (new) |
| new endpoint method | — | **not needed**, see below |
| control-plane call | `packages/control_plane_client/**` | **not needed**, see below |

**The stall reuses a decision the platform already knows how to show.** It raises
a blocking `engineeringReview` `HumanDecision`, which the existing decision
screen already renders and submits through the existing `resolveDecision`
endpoint. A new endpoint would have been a second way to reach the server from
the feature layer, which is the same class of defect as
`a-generated-client-can-reference-a-file-it-never-emitted.md`.

Two facts forced the shape rather than preference:

* `agentCompleted` has **no** edge to `waitingForHumanDecision`. The only route
  runs through `reviewInProgress`, and that edge carries
  `blockingHumanDecisionPendingOfType([engineeringReview])`
  (`work_item_transitions.dart:317`). The state machine names the decision type
  for you; choosing `escalation` here would have meant adding an edge, which is
  a state-machine change and not a wiring change.
* **`engineeringReview` + `rework` routes to `implementationReady`**, the
  implementation lane's entry state. That IS the operator retry the brief asked
  for: the work runs again, a fresh producer runs, and the item reaches
  `agent_completed` with a fresh `producerActorId`.

**Recovery needs no new control and clears no flag.** `Scheduler` lifts a stall
when `WorkItem.version` moves past the version recorded when it fired, and every
resolution is a real transition — so the recovery is a write, not a reset.

The one interaction worth naming: `review_repair`'s
`repairUnreviewedReview` will classify this decision as repairable (it has no
reviewer output, which is the class repair targets), so the repair affordance
offers a *second* correct recovery on the same item. Suppressing it would mean
editing `apps/server/lib/src/review/**`, which is PROHIBITED here.

**The stall drain shares the producer resolution with the coordinator.** It has
to park the item through the same guarded edge, so it calls
`resolveProducerExecution` rather than re-deriving it. That is the point: two
call sites that each re-derive "what produced this item" is how they come to
disagree, and §2 is what that looks like.

---

## 7. A second false state found beside this one — NOW FIXED

`apps/control_plane` rendered every transition row through
`plainTransitionMessage(from, to)` → `('agent_completed','review_in_progress') =>
'Independent review started'`.

For these items that sentence was rendered **236 times, and no review ever
started.** The timeline asserted the opposite of the durable record because
`TransitionView` carried no `outcome`. Same class, same screen, one layer up.

`TransitionView` now carries `outcome` (nullable, verbatim from
`work_item_transition.outcome`), and `timelineMessageFor`
(`operator_action_copy.dart`) tells the two apart:

* `accepted` → the move copy, **byte-identical to what it always was**;
* `rejected` → the same copy behind a `Not applied — ` prefix;
* **null or unrecognised → treated as refused**, never as a move.

### WHY THE NULL CASE IS THE INTERESTING ONE

`outcome` is nullable, and defaulting null to `accepted` would reintroduce the
original defect the instant a client met a row without the field. An attempt
whose outcome cannot be read is **not evidence that the item moved**, so it is
worded as an attempt. The cost is that the fixtures had to be made faithful:
`makeTransition` now sets `outcome: 'accepted'` by default, because that is what
those fixtures always meant. No golden image moved.

### WHY A REFUSED ROW IS RENDERED RATHER THAN DROPPED

Dropping `outcome != 'accepted'` rows was considered and rejected. 236 refused
attempts are the single most diagnostic fact on that screen — it is what
identified a spin loop nobody had noticed — so hiding them would replace a false
state ("236 transitions happened") with a different one ("nothing happened") and
destroy the only trace the operator has. What changes is the WORDING, so "review
started" and "a review was tried and was refused" are distinguishable.

A refused row also never tints as handing control to the operator, whatever
state it names: it did not hand over.

---

## 8. Discovery records

- `PROJECT_FACT` — the review entry edge is permanently unsatisfiable for any
  work item that already has a reviewer execution. **RESOLVED** at the corrected
  HEAD; the resolution rule is `resolveProducerExecution`.
- `CONTRADICTION` — a reviewer's own execution shadowed the implementer's result
  in the only lookup the review entry transition used. **RESOLVED**, and
  reconciled in §2.
- `CONTRADICTION` (NEW, **NOT RESOLVED**) — the same role-blind lookup still
  exists at `apps/server/lib/src/review/engineering_review_gate.dart:700`.
  Same defect, prohibited path, reported rather than worked around.
- `ARCHITECTURE_DISCOVERY` (NEW, human decision) — **one rule for "what produced
  this work item" should be shared, not re-derived per call site.** There are
  now three places that need it (`execution_coordinator`, the stall gate, and the
  review gate above). Two of them share one function; the third cannot be
  reached. If a fourth appears, this is an architecture decision, not a
  convenience refactor.
- `WORKFLOW_IMPROVEMENT` (needs independent review) — an exception type carrying
  two causes with opposite correct answers is a scheduler hazard; the scheduler
  cannot distinguish them and applies one rule to both.
  `WorkItemSupersededException` is still that type: it still says "the item
  moved" on a path where nothing moved, and the scheduler still cannot tell.
  The root-cause fix means the common path no longer produces it, but the
  conflation itself is untouched.
- `WORKFLOW_IMPROVEMENT` (needs independent review) — every query over
  `work_item_transition` that asks "what happened" must filter `outcome`.
- `WORKFLOW_IMPROVEMENT` (NEW, needs independent review) — **a "latest X" lookup
  is only correct until X stops being the latest.** No test caught §2 because
  every test ran on a fresh item. Any fixture for a "most recent" lookup should
  include a *later row of a different kind*.
- `PROJECT_FACT` — `test/retry_return_to_entry_state_test.dart` is unformatted at
  `0c51755` (`dart format` exits 1). Pre-existing, untouched. It is the ONLY file
  that makes `packages/scheduler`'s `dart format --set-exit-if-changed` fail.
- `RUNTIME_DISCOVERY` — `apps/server/test/onboarding_test.dart` produces no test
  output at all (it prints only `loading`), at `0c51755` and at the corrected
  HEAD. It kills any whole-suite run of `apps/server/test/`. Run the other 33
  files by name — all 33 are green at the corrected HEAD.
- `RUNTIME_DISCOVERY` (NEW) — **`docker/compose.test.yaml`'s
  `postgres_integration` interpolates `SERVERPOD_DATABASE_PASSWORD` at `up`
  time.** Exporting it *after* `compose up` — which the obvious hand-rolled
  replica of `make test-integration` does, because the Makefile checks it in a
  separate earlier step — yields `container ... exited (1)` with no message. The
  published port is a *second*, differently-named variable
  (`SHIPIT_TEST_DB_PORT`), so overriding the port for `dart test` without
  exporting it to compose publishes 9199 and connects to nothing. Both must be
  exported before `up`.