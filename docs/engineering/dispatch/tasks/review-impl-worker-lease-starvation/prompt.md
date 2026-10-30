# Dispatch — review-impl-worker-lease-starvation (re-dispatched after session loss)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-impl-worker-lease-starvation
TASK_TYPE: review
FEATURE: F-226 worker-lease starvation recovery
AREA: worker_runtime / local worker lease lifecycle
WORKTREE: /private/tmp/shipit-fix-worker-lease-starvation
BRANCH: fix/worker-lease-starvation
BASE_SHA: fb8dde3
HEAD_SHA_UNDER_REVIEW: 2b24f4ed676f2943a88a6092cada99f262b82a8a
ROUTING_CLASS: PRECISION
```

Prior reviewer died before reporting; this is a fresh dispatch against the same reviewed HEAD.

Verify independently at `2b24f4e` in the worktree:
1. `git diff fb8dde3..2b24f4e` — whole diff, only `local_worker.dart` + `worker_lease_bound_test.dart`.
2. `_runBound` (timeoutSeconds + workerLeaseGrace + 15m overhead bound) covers EVERY unbounded await
   in `_drive` (prepare, inspect, cleanup, store writes). Any path that can outlive the bound while
   holding the lease is a BLOCKER — that is the F-226 defect.
3. `.timeout` does not cancel the inner future: epoch fencing must prevent a stale detached drive
   from starting a session, clearing `_leased` under a successor, or writing dishonest rows.
4. Abandon-path awaits are themselves bounded; `timedOut` result must be transient per RetryPolicy.
5. Re-run: `dart analyze` + `dart test` (packages/worker_runtime), `dart format --set-exit-if-changed .`
   at worktree root. Report own numbers.
6. The 5 tests must not pass vacuously.
7. Regression: normal pass/fail/timeout paths unchanged; WorkerDispatcher interplay sound.

Read-only; no docker, no DB. Report per subtask-report.md, ending exactly one of
`RESULT: APPROVE_FOR_MERGE` / `RESULT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `RESULT: DO_NOT_MERGE`
+ `CORRECTION_REQUIRED:` + `HUMAN_DECISION_REQUIRED:`.
