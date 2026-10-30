# Dispatch — review-impl-onboarding-lease

```yaml
MANAGER: orchestrator-main
TASK_ID: review-impl-onboarding-lease
TASK_TYPE: review
FEATURE: F-232 OnboardingWorker lease bound (F-226 port)
AREA: worker_runtime / onboarding worker lease lifecycle
WORKTREE: /private/tmp/shipit-fix-onboarding-lease
BRANCH: fix/onboarding-worker-lease-bound
BASE_SHA: 128c721
HEAD_SHA_UNDER_REVIEW: 75d206c081baa554890eb409c0b74ca2797e10ba
ROUTING_CLASS: STANDARD
```

Independent read-only review of the F-226 port to OnboardingWorker. Verify at `75d206c` in the
worktree:
1. Whole diff — only `onboarding_worker.dart` + `onboarding_lease_bound_test.dart`; HEAD matches.
2. Fidelity of the port vs `local_worker.dart` at the same base: `_runBound` covers EVERY unbounded
   await (prepare, `_runCommand` phases, inspect, cleanup, store writes); epoch fencing on every
   resumable await before a store write; lease released ONLY by `run`'s `finally`; stale drive cannot
   write rows/results/events nor free a successor's lease.
3. No live-path behavior change; `timedOut` transient per RetryPolicy; abandon-path awaits bounded.
4. The 7 tests are non-vacuous (real wedges + assertions on lease/rows, not no-throw).
5. Re-run gates yourself: `dart format --set-exit-if-changed .` (root), `dart analyze` +
   `dart test` (packages/worker_runtime) — your own numbers.
6. Implementer-noted gaps: worker not exported/has no production construction site (verify true and
   whether that matters); `_runBound` uses request.timeoutSeconds vs onboarding's real
   git+build+test budget — assess whether the bound is mis-sized for this worker's actual budget.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`RESULT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `RESULT: DO_NOT_MERGE` +
`CORRECTION_REQUIRED:` + `HUMAN_DECISION_REQUIRED:`.
