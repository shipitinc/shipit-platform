# Dispatch — focused-review-detached-dispatch (correction re-review)

```yaml
MANAGER: orchestrator-main
TASK_ID: focused-review-detached-dispatch
TASK_TYPE: re-review
FEATURE: F-237 detached dispatch — server-test settle migration correction
AREA: apps/server unit tests consuming the settle path
WORKTREE: /private/tmp/shipit-fix-detached-dispatch
BRANCH: fix/detached-dispatch
BASE_SHA: 94d8677
CORRECTED_HEAD: 00ff16fed79717462c7cba611b732baec5b2fc95
ROUTING_CLASS: STANDARD
```

Focused re-review of ONLY the corrected finding (INTEGRATION_BLOCKED on `c02572c`: 4 apps/server
test files asserting same-tick settle) + regression risk — not a full re-review.

Verify at `00ff16f` (new commit on `c02572c`, provenance preserved):
1. The 4 files (`budget_exhaustion_retries`, `scheduler_retry_dispatches_again`,
   `tick_single_flight`, `engineering_review_e2e`) + new `test/support/settle.dart` settle via
   reconcile-adoption — same assertions as before, none weakened/skipped, no timeout-as-assertion.
   `tick_single_flight_test` reworked its wedge to a durable `readJob` park — verify the new wedge
   actually exercises the tick-hold mechanism it intends (parked read inside `_dispatchOne`
   pre-claim) and all original assertions (lease frees, recovered tick dispatches 1,
   maxConcurrency==2, hold_expired 1, dropped_overlap 0) are preserved.
2. The settle helper waits on durable claim-release, never a sleep.
3. `ScriptedDispatch` now persists the terminal execution tail — verify it mirrors LocalWorker's
   durable tail correctly (terminal WorkerExecution + stored result under request's
   workerExecutionId).
4. Regression: nothing else in the diff; `packages/scheduler` suite untouched and still green.
5. Re-run gates yourself: `dart format --set-exit-if-changed .` (root), `dart analyze` +
   `dart run tool/run_unit_tests.dart` (apps/server), `dart test` (packages/scheduler) — own numbers.

Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_CORRECTIONS` /
`RESULT: DO_NOT_APPROVE_CORRECTIONS`.
