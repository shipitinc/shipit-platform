# Repository Learning: a retry the scheduler cannot reach is not a retry

**Feature**: IMPL-B2-BUDGETS-AND-DURATION (B-1, reviewer retry)
**Date**: 2026-10-14
**HEAD**: `fix/budgets-and-duration`, base `45e6578`
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic authority.
**Status**: OPEN. The mechanism is fixed; the re-dispatch path is not, and it is not
in this lane's ownership.

---

## Summary

B-1 fixed the classification: a budget expiry now settles `interrupted`, which
`RetryPolicy` classifies TRANSIENT, which spends an attempt, which makes
`maxAttempts` reachable for the first time. **That is necessary and not sufficient.**

A failed execution moves the work item OUT of its lane's `entryStates`
(`agentCompleted → reviewInProgress` for review, `agentExecuting → agentFailed` for
everything else). `RunnableWorkEvaluator` rejects any item outside its own
`entryStates` *before it asks the policy anything*, so on the next tick the item
classifies `noAction` — and `Scheduler._retireSupersededForItem` **cancels** the
`retryWaiting` job whose retry was just scheduled.

So the retry is spendable and still does not run.

This applies to **every `Scheduler`-based lane**, not only review:
`triageDefectDefinition`, `implementFeatureDefinition`, `defaultImplementFeatureDefinition`,
`designRevisionDefinition`, `designReviewDefinition`, `engineeringReviewDefinition` all
declare pre-execution entry states, and every failure path leaves the item outside them.

The one retry path that genuinely works is `BaselineProductDispatcher`
(`packages/scheduler/lib/src/baseline_dispatch.dart:670`), which is **not** a
`Scheduler`, carries its own transient flag, and claims product-scoped jobs with no
`WorkItem` state machine behind them.

---

## What is already in the repository

`triage_execution_test.dart:1763` — *"PRODUCTION DEFECT: a transient failure queues a
retry that no scheduler tick can ever claim"* — already pins this, for the triage
lane, with the root cause written out. That test **fails at base `45e6578` and still
fails after this lane's change**; it is a characterisation of the bug, not a regression.

What this lane adds is the scope: it is not triage-specific, and the review lane has
no route back at all (`reviewInProgress → agentCompleted` is not an edge in
`packages/workflow_engine`, which is READ-ONLY).

---

## Executable knowledge

| What is true | Where it is true, mechanically |
|---|---|
| The scheduled retry is retired one tick later, for the review lane | `apps/server/test/budget_exhaustion_retries_test.dart`, `GAP, PINNED` |
| With the work item held in its entry state, a timeout really does dispatch again — and a crash really does not | `apps/server/test/scheduler_retry_dispatches_again_test.dart` |
| The existing characterisation, for the triage lane | `apps/server/test/integration/triage_execution_test.dart:1763` |

---

## Operator-visible consequence, stated plainly

Before this change, a review killed at its budget produced a **terminal failed job**,
which `drainTriageOutcomesFromTick` hands to `engineeringReviewTickHandler`, which
raises a blocking `engineeringReview` human decision. The item did not silently
disappear.

After this change it produces a **`retryWaiting` job that is retired as superseded on
the next tick** — and `cancelledQueued` is *not* in the drain's
`dispatched ∪ terminal ∪ reconciled` union, so **no human decision is raised**.

So the classification fix removes the operator signal for a timed-out review, until
something returns the work item to a dispatchable state. That is a real regression in
visibility and it is reported as a blocker, not absorbed: the repair is a lifecycle
change (a new edge, or restoring `agentCompleted` on a retryable failure) in
`packages/workflow_engine` and `packages/scheduler`, neither of which this lane owns,
and which under `AGENTS.md` is a consequential architecture decision.

**Related:** [[the-executor-cancelled-itself-to-settle-a-timeout]].