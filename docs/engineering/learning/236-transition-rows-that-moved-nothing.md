# Repository Learning: 236 transition rows that moved nothing

**Feature**: IMPL-B8-REVIEW-STALL
**Date**: 2026-10-15
**HEAD**: `fix/review-item-stall`, base `0c51755`
**Category**: `CONTRADICTION` + `PROJECT_FACT` — see §1 and §7.
**Status**: PARTIALLY CLOSED. The churn is stopped and reported. The root cause is
in `packages/execution_coordinator/**`, which this lane does not own.

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

### Not fixed here, and why

`execution_coordinator.dart` is outside this lane's ownership. The one-line
correctness fix is to resolve the IMPLEMENTER's execution for that context (by
role, or by `item.metadata['producerActorId']`, which the same file's sibling
already writes) rather than the newest row of any role.

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

## 6. The operator surface is NOT delivered, and the reason is structural

The brief asked for the conclusion to reach the operator. It does not, and the
blocker is not the UI:

| needed | path | status |
|---|---|---|
| tick → operator channel | `apps/server/lib/server.dart` | **outside OWNED_PATHS** |
| tick drain | `apps/server/lib/src/triage/lane_i_tick_hook.dart` | **outside OWNED_PATHS** (`services/**` is owned; `triage/` is not) |
| new endpoint method | needs `serverpod generate` | `apps/server/lib/src/generated/**` is **READ_ONLY** |
| control-plane call | `packages/control_plane_client/**` | **outside OWNED_PATHS** |
| new view field | `apps/server/lib/src/models/*.yaml` + regen | **outside OWNED_PATHS** |

Adding an unwired endpoint method would be actively worse than adding none: the
repository already documents that class — *a generated client can reference a file
it never emitted*, `a-generated-client-can-reference-a-file-it-never-emitted.md` —
where `dart analyze` is green and the method is unreachable from every client.

The control-plane **could** render a stall panel today only by inferring one from
transition rows the client already fetches — and `TransitionView` carries no
`outcome`, so it cannot tell a refusal from a move. Inferring would be guessing,
which `N8` forbids.

**What is delivered instead** is `SchedulerTickResult.stalled`: a durable,
structured, operator-facing statement on a channel the composition root can act
on, carrying the work item, its state, the deferrals spent and a sentence saying
a human is needed. It is the input an affordance needs; the wiring is one lane
away.

**Unblocks by:** opening `apps/server/lib/server.dart` and
`apps/server/lib/src/triage/lane_i_tick_hook.dart`, plus `serverpod generate`
authority. Both were needed for `review_repair` too.

---

## 7. A second false state found beside this one

`apps/control_plane` renders every transition row through
`plainTransitionMessage(from, to)` → `('agent_completed','review_in_progress') =>
'Independent review started'`.

For these items that sentence was rendered **236 times, and no review ever
started.** The timeline asserts the opposite of the durable record because
`TransitionView` carries no `outcome`. Same class, same screen, one layer up.

Not fixed here (`apps/control_plane/lib/shared/transition_copy.dart` and the
`TransitionView` model are outside OWNED_PATHS).

---

## 8. Discovery records

- `PROJECT_FACT` — the review entry edge is permanently unsatisfiable for any work
  item that already has a reviewer execution. Persisted here at automatic authority.
- `CONTRADICTION` — a reviewer's own execution shadows the implementer's result in
  the only lookup the review entry transition uses. Reconciles §2 with
  `_reviewEntryTransitionContext`'s stated intent; escalated because the fix is in
  `execution_coordinator`.
- `WORKFLOW_IMPROVEMENT` (needs independent review) — an exception type carrying
  two causes with opposite correct answers is a scheduler hazard; the scheduler
  cannot distinguish them and applies one rule to both.
- `WORKFLOW_IMPROVEMENT` (needs independent review) — every query over
  `work_item_transition` that asks "what happened" must filter `outcome`.
- `PROJECT_FACT` — `test/retry_return_to_entry_state_test.dart` is unformatted at
  `0c51755` (`dart format` exits 1). Pre-existing, untouched here.
- `RUNTIME_DISCOVERY` — `apps/server/test/onboarding_test.dart` exits 1 with no
  test output at `0c51755` and at this HEAD. It kills any whole-suite run of
  `apps/server/test/`; run the other 32 files by name.