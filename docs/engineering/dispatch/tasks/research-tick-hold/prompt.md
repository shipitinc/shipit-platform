# Dispatch — research-tick-hold (read-only investigation)

```yaml
MANAGER: orchestrator-main
TASK_ID: research-tick-hold
TASK_TYPE: research
FEATURE: which call in the tick path awaits in-flight executions — the lane-serialization defect
AREA: scheduler tick / drain / dispatch path
WORKTREE: canonical checkout (read-only)
BRANCH: main
BASE_SHA: 128c721
OWNED_PATHS: [] (read-only)
ROUTING_CLASS: CHEAP_READ
```

## Evidence to explain (live QA, 2026-10-30)

- Items at `design_required` with yielded dedupe keys took ~1h to get a `design_revision`
  job enqueued (reset ~04:08 → jobs `jb-hnonk0ef5n`/`jb-hnonk0e93b` created 05:06).
- 25 `TICK_OVERLAP_DROPPED` events and zero `design.*.tick.drained` lines while executions ran.
- Enqueues only seem to happen once the in-flight execution ends — the platform appears to
  serialize ALL lanes to ~1 execution per tick epoch.

## Answer these questions precisely, with file:line evidence

1. Which call in the shared tick path (`runTick`/`runDesignLaneTick`/`drainTriageOutcomesFromTick`/
   `_dispatchOne` in `packages/scheduler/lib/src/scheduler.dart` + `apps/server/lib/server.dart`)
   BLOCKS while an execution is in-flight? Is the enqueue phase itself blocked behind it, or does
   the enqueue run each tick and something else suppresses it?
2. Is the block by design (single-flight lease + drain awaiting completions) or a defect
   (an await that should be bounded/decoupled)?
3. What is the minimal-change remediation shape (e.g., split enqueue/dispatch from the
   completion drain, bound the drain, or run lanes in separate ticks)? Report options, not code.
4. Confirm or refute: does the *claimed* hypothesis (tick held for the execution's duration)
   explain the observed enqueue delay, or is something else (capacity, evaluator, claim
   inheritance) the actual cause?

Read-only: no writes, no docker, no DB mutations. Return findings with exact file:line citations
and a recommended remediation path. `RESULT:` token per your lane contract.
