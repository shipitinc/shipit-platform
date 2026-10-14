# Repository Learning: a retry that cannot execute looks exactly like a retry that never ran

**Feature**: IMPL-B4-RETRYABLE-RETURN-EDGE
**Date**: 2026-10-14
**HEAD**: `fix/retryable-return-edge` on `45e6578`
**Decision**: `.decisions/3659984d-4e2a-4625-81ff-37aa73252375.yaml` (ARCHITECTURE, RESOLVED, option A)
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic authority.

---

## Summary

Decision `3659984d` fixed the *claim* half of a retryable execution failure and exposed the *execution*
half underneath it. Returning a work item to its lane's entry state makes a scheduled retry CLAIMABLE —
and a claimable retry still did not run a second agent session, because **every attempt of one job
reused one `workerExecutionId`**, and `ExecutionCoordinator.execute` is single-shot per agent execution
id.

Worth writing down because the second defect was *invisible for the whole time the first one existed*.
It could not be observed until the retry became claimable, and every unit test of the scheduler used a
dispatcher stub that reported a fresh agent execution id per run — so the stub answered a question the
production stack could not.

## What is true, and where it is true mechanically

| What is true | Where it is true, mechanically |
|---|---|
| A transient failure returns the item and the retry REALLY runs (2 executions, not 2 rows) | `packages/scheduler/test/retry_return_to_entry_state_test.dart` |
| A permanent failure strands; `maxAttempts` yields exactly N executions | same file, "the failure classes stay DISTINCT" / "maxAttempts bounds the retries FOR REAL" |
| Two attempts are two DISTINCT executions, not one row overwritten | `packages/scheduler/test/lane_j_execution_reference_test.dart` |
| The four return edges, their guards, and the deliberate ABSENCES | `packages/workflow_engine/test/retry_return_edges_test.dart` |
| A returned review item is not mistaken for implementation-ready work | `packages/scheduler/test/retry_return_od10_discriminator_test.dart` |
| End to end through a real Postgres, a real worktree, a real coordinator | `apps/server/test/integration/triage_execution_test.dart` — "a transient failure returns the item to the lane entry state and the scheduled retry REALLY RUNS" |

Read those, not this file, when you need the behaviour.

---

## The finding

Two facts, in this order.

**One. Every request builder spells the id `'wx-${job.jobId}'`.** So it is the same string for every
attempt of one job. `LocalWorker._agentRequest` derives the agent execution id from it
(`'agx-$workerExecutionId'`), and `ExecutionCoordinator.execute` returns the existing terminal record
for an id it has already seen instead of starting anything.

**Two. The retry therefore replayed the failure.** The retried dispatch received the FIRST attempt's
interrupted execution; `RetryPolicy.classify` classified it transient a second time; `canRetry` was
already spent; the job settled terminally `failed`. The retry was real enough to observe in a tick
result and useless in practice.

### Why nothing caught it

| Layer | What it does | Why it could not see the collision |
|---|---|---|
| `scheduler_retry_test.dart` | transient → retry → succeed | `ControlledDispatcher` never moves the work item, so the item never left its entry states and the defect-under-test was never reachable |
| `lane_j_execution_reference_test.dart` | "a retried attempt records ITS OWN agent execution id" | its `_ReportingDispatcher` returns a NEW `agentExecutionId` per run, so the id looked distinct at exactly the layer where it was not |
| `apps/server` integration | real `LocalWorker` + real coordinator | **the item was stranded before dispatch, so there was never a second attempt to look at** |

The unit tests and the integration test were each individually right about a world in which the other
was not exercising the path. That is the shape worth remembering: a defect guarded by two layers of
"obviously" can survive for a long time, and the thing that exposes it is almost never a stronger
assertion — it is making a previously unreachable path reachable.

### The fix, and the one property that had to be preserved

`Scheduler._scopedToAttempt` suffixes the worker execution id from attempt 2 onward
(`'wx-<jobId>:a2'`) and `markRunning` now records the request's OWN id.

Attempt 1 must stay **byte-identical** to every id ever persisted, and that is not cosmetic. Every
`WorkerExecution` row, and every `producerActorId` an item's `OD-10` discriminator resolves through,
is keyed on the unsuffixed spelling. Re-spelling the base would orphan all of them, and the next tick
would route work whose producer could no longer be identified. The same reasoning that keeps
`triageDefectDedupeKey` and `implementFeatureDedupeKey` byte-identical in their absent-marker case.

The suffix is applied in the scheduler, not in the five request builders: one rule, applied to every
definition including ones added later.

---

## Open action for a sibling lane (NOT done here)

`apps/server/test/budget_exhaustion_retries_test.dart` carries a test titled
`'GAP, PINNED: a retried job cannot re-dispatch while its work item has left the definition's entry
states, so it is retired one tick later'`, whose own reason string says:

> `PINNED BEHAVIOUR, not an endorsement. […] Whoever closes this must DELETE this assertion and
> replace it with one that shows the retry dispatching.`

**That file does not exist on this lane's base `45e6578`.** It lives only in the unmerged `b2-budget`
worktree (`fix/budgets-and-duration`, `362d047`). It could not be deleted from here without writing
into a concurrent lane's worktree, which is prohibited. The replacement assertion — a second reviewer
execution really running — now exists at `apps/server/test/integration/triage_execution_test.dart`
("a transient failure returns the item to the lane entry state and the scheduled retry REALLY RUNS")
and in `packages/scheduler/test/retry_return_to_entry_state_test.dart`.

Deleting the pin is owed by the `b2-budget` lane at merge time, or by whoever merges it.

---

## A note on the inventory assertion this changed

`packages/workflow_engine/test/operator_retry_edge_test.dart` asserted
`agentFailed` has "exactly TWO explicit outgoing edges". That inventory changed by decision, so the
assertion was rewritten rather than loosened: it is now **exact set equality**, which is stricter than
the `containsAll` + `length` it replaces — it fails on a deletion as well as an addition. The property
the test exists to protect (no self-transition out of `agentFailed`; escalation still impossible) is
unchanged and still asserted.