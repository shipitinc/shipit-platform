# Repository Learning: the tick order was the decision

**Feature**: IMPL-A5-CORRECTION-2 (OD-10 implementation completion inflow)
**Date**: 2026-10-13
**HEAD**: correction on `d883613` (finding raised by `engineering-reviewer`, BLOCKER-1)
**Category**: `PROJECT_FACT` — product-specific, evidence-backed, persisted at automatic authority.

---

## Summary

Two lanes claim the same work-item state. `sched-review` **dispatches** from
`agent_completed`; `sched-impl` **routes out of** it. They run inside ONE
`TickSingleFlight` callback, each in its own `try`, and review's
`blockedArtifactMissing` handler **writes** — it moves the item to
`review_in_progress` and raises a blocking human decision. So for one tick the
winner was decided by which `await` came first, and the review lane won, and
`implementation_ready` was never reached while both ticks reported success.

**This entry deliberately restates little.** The executable form exists and will not
go stale:

| What is true | Where it is true, mechanically |
|---|---|
| Both schedulers over real stores, BOTH orders, same landing state | `apps/server/test/implementation_inflow_tick_order_test.dart` |
| The composition's actual section order, and why it is load-bearing | same file, "the composition root ticks implementation FIRST" |
| The review handler defers to the inflow instead of parking | same file, "the stand-down is about the WORK, not about tick order" |
| The bound is the one case the stand-down must not swallow | same file, "the bound still reaches a human" |
| The scheduler-side half (every refusal routes to implementation) | `packages/scheduler/test/implementation_completion_inflow_test.dart` |
| The composition order, guarded from the scheduler package too | `packages/scheduler/test/implementation_composition_wiring_test.dart` |

Read those, not this file, when you need the behaviour. Read this file for the
shape of the mistake.

---

## The finding

Inside one tick callback, in this order:

```
await reviewScheduler.tick()                       // enqueues, resolver says null,
                                                  // reports blockedArtifactMissing
… blockedArtifactMissing loop …
    await engineeringReviewMissingArtifact(…)     // → review_in_progress, human gate
await implScheduler.tick()                         // never sees agent_completed
```

Swap the two `await`s and the item reaches `implementation_ready`. Nothing about
the work changed. The outcome was a function of the composition's line order.

And it was worse than order-dependent: it was **conditionally** order-dependent.
The handler's park only succeeded when `executionStore.latestExecutionForWorkItem`
returned a readable result. Live `agent_execution_rows` was 0, so the handler
bailed and the inflow fired — the mechanism worked *only* in the degenerate case
where it did not, and lost the moment the platform started recording executions.

## Why it stayed invisible — the part worth remembering

1. **Both ticks succeeded.** `completionInflow=[]` is a valid result for a tick
   that found nothing to do. There is no failure to alert on.
2. **The two lanes' tests were each individually correct.** The scheduler package
   proved the inflow routes correctly over in-memory stores; `apps/server` proved
   the handler parks correctly over a real coordinator. Neither ever ran both
   schedulers, because **no single package could**: the resolver and the handler
   live in `apps/server`, the inflow in `packages/scheduler`, and the scheduler
   package cannot import the app.
3. **The shared rule was transcribed, not shared.** Both sides implemented the same
   "did this run produce an artifact" test independently and identically, and a
   scheduler-side "divergence" test re-spelled one of them from the other's
   verdict — so it could not have detected divergence from the real resolver even
   if it existed.

That third point is the transferable one: **a duplication test that derives one
side from the other cannot fail.** It can only catch someone editing both in the
same commit.

## The correction

Two halves, both needed:

- **The handler stands down.** `engineeringReviewMissingArtifact` now calls the
  scheduler's own `producedCommitFor` and defers to the inflow for a no-artifact
  producer instead of parking it. The bound (`maxImplementationInflows`) is the
  one case it does not defer on, because the inflow will not route there either —
  both read the same number so they cannot disagree about whether the budget is
  spent.
- **The order was corrected anyway.** `implScheduler.tick()` now runs before the
  review section, and the reasoning is recorded at the section itself.

Neither half is sufficient alone, and the tests say so: both orderings are
executed, and both land in `implementation_ready`. The ordering is the braces; the
stand-down is why the braces are load-bearing rather than the only defence.

**The transcription is gone.** `engineeringReviewWorkloadResolver` now CALLS
`producedCommitFor` instead of re-stating it. The dependency runs from
`apps/server` onto `packages/scheduler`, which is the direction that already
exists, so sharing inverted nothing. What sharing could not cover — the mapping
from verdict to each lane's action, in two different packages — is executed in
`apps/server/test/inflow_vs_review_route_test.dart`, and the delegation itself is
asserted directly, because a behavioural test cannot tell a delegating resolver
from a re-inlined copy of it.

## Adjacent finding, deliberately NOT fixed here

`Scheduler._eligibleRunnableJobs` does not filter by `job.jobType`. Every other
loop in that file does. With one shared `JobStore` across three schedulers, a
scheduler whose definition finds the item runnable will attempt to dispatch
**another lane's** job for it. Reachable today through the inflow: in
review-first order, `sched-impl` picks up the stale `engineeringReview` job that
review enqueued before the item was routed away from it (observed as a second
`WorkerExecutionRequest` with `role: engineeringReviewer` built by the
implementation scheduler).

It is not fixed in this correction: it is a change to the shared dispatch path,
outside the findings handed to this lane, and it deserves its own review. Reported
to the Manager as a new discovery.

## Larger lesson — framework candidate, not persisted here

*Not persisted: `WORKFLOW_IMPROVEMENT` requires independent review.*

**When two components act on the same durable state inside one control-flow
cycle, the composition's statement order is part of their contract and must be
asserted like one.** Component tests cannot catch it: each sees a world where the
other has not yet run. The cheapest guard is a test that runs both in the real
order AND in the reversed order and asserts one outcome — order-independence is
then a property, and the ordering itself becomes a free choice rather than a
hidden dependency.

Pair it with: **a handler in the dispatch path that writes state is a competitor,
not a reporter.** Any fail-closed handler that moves a work item must be asked
"is this item still mine?" before it moves it, and the answer has to come from the
same function the competing lane uses — not from a second reading of the same
evidence.