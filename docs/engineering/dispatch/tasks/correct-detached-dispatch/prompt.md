# Dispatch — correct-detached-dispatch (server-side settle fallout)

```yaml
MANAGER: orchestrator-main
TASK_ID: correct-detached-dispatch
TASK_TYPE: correct
FEATURE: F-237 detached dispatch — migrate apps/server tests to deferred-settle path
AREA: apps/server unit tests consuming the settle path
WORKTREE: /private/tmp/shipit-fix-detached-dispatch
BRANCH: fix/detached-dispatch
BASE_SHA: 94d8677
REVIEWED_HEAD: c02572c29d1f59e34506dc39cd3d8115ce355eca
OWNED_PATHS:
  - apps/server/test/budget_exhaustion_retries_test.dart
  - apps/server/test/scheduler_retry_dispatches_again_test.dart
  - apps/server/test/tick_single_flight_test.dart
  - apps/server/test/engineering_review_e2e_test.dart
  - apps/server/test/support/**  (if a settle helper is needed there)
  - packages/scheduler/test/support/settle.dart (reference; extend only if genuinely needed)
READ_ONLY_PATHS:
  - packages/scheduler/lib/src/scheduler.dart
  - packages/scheduler/test/support/** (the settled-path pattern to mirror)
  - apps/server/lib/server.dart
PROHIBITED_PATHS:
  - everything else, incl. apps/server/lib/**
VALIDATION_COMMANDS:
  - dart format --output=none --set-exit-if-changed .   # worktree root
  - dart analyze                                       # apps/server
  - dart run tool/run_unit_tests.dart                  # apps/server — all 69 must pass
  - dart test                                          # packages/scheduler — must stay 446 green
ROUTING_CLASS: STANDARD
```

## Integrator finding (INTEGRATION_BLOCKED on c02572c, verbatim)

4 of 69 `apps/server` unit-test files fail on the merged tree (all pass individually on `main` —
deterministic regression): `budget_exhaustion_retries_test.dart` (6), `scheduler_retry_dispatches_again_test.dart`
(3), `tick_single_flight_test.dart` (2), `engineering_review_e2e_test.dart` (3). Uniform signature:
tests assert terminal/routed state after the run resolves and instead observe the pre-adoption state
(`Expected: JobState.failed/retryWaiting, Actual: JobState.running`; `Expected: agentCompleted,
Actual: agentExecuting`). The `packages/scheduler` suite was migrated to reconcile-adoption settle in
`c02572c`; the server suite consumes the same settle path via the composition root and was not migrated.

## Task

Migrate the four files to the two-step settle — run resolves → continuation releases claim → an
extra reconcile tick adopts the terminal execution — exactly as `packages/scheduler/test/support/settle.dart`
(`waitUntil`/`settleHeldJobs`) does it. Assert the SAME observable outcomes as before via the settle
path; no weakening, no skipping, no timeouts-as-assertions. If the server tests need a settle helper,
add it under `apps/server/test/support/` (owned) mirroring the scheduler pattern.

## Rules

- NEW commit on top of `c02572c` — never amend/rebase (reviewed provenance). No push.
- The server-side tests may use composition-root scheduling; figure out where their tick driver lives
  and call the reconcile tick explicitly — same mechanism, different package.
- No docker, no DB. Report per subtask-report.md: `RESULT: CORRECTION_COMPLETE` /
  `CORRECTION_BLOCKED`, NEW_HEAD, `READY_FOR_FOCUSED_REVIEW: YES|NO`.
