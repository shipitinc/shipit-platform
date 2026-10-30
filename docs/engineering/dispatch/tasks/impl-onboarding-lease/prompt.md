# Dispatch — impl-onboarding-lease (F-232)

```yaml
MANAGER: orchestrator-main
TASK_ID: impl-onboarding-lease
TASK_TYPE: implement
FEATURE: F-232 OnboardingWorker same-shape lease starvation bound
AREA: worker_runtime / onboarding worker lease lifecycle
WORKTREE: /private/tmp/shipit-fix-onboarding-lease
BRANCH: fix/onboarding-worker-lease-bound
BASE_SHA: 128c721
OWNED_PATHS:
  - packages/worker_runtime/**
READ_ONLY_PATHS:
  - packages/scheduler/**
  - packages/platform_contracts/**
  - docs/engineering/FOLLOW_UPS.md
PROHIBITED_PATHS:
  - everything outside packages/worker_runtime/**
VALIDATION_COMMANDS:
  - dart format --output=none --set-exit-if-changed .   # worktree root
  - dart analyze                                       # packages/worker_runtime
  - dart test                                          # packages/worker_runtime
ROUTING_CLASS: STANDARD
```

## Defect (F-232, from the F-226 review's MEDIUM on 2b24f4e)

`OnboardingWorker` (`packages/worker_runtime/lib/src/worker/onboarding_worker.dart`, `run()` ~:114)
retains the pre-F-226 shape: no whole-run bound and `_finish` clears `_leased` inline (~:450) — a
wedged store/driver starves it identically to the F-226 `LocalWorker` defect.

## Task

Port the F-226 remedy to `OnboardingWorker`, mirroring the just-merged `LocalWorker` structure
(read `local_worker.dart` at HEAD — `_runBound`, `_abandonDrive`, epoch fencing on every resumable
await before a store write, lease released solely by `run`'s `finally`). Match the F-226 pattern
rather than inventing a parallel mechanism: whole-run bound sized from the role's budget +
`workerLeaseGrace` + drive-overhead bound; honest `timedOut` (transient) on abandon; epoch-fenced
writes; no behavior change on the live path. Include the same-class regression tests mirroring
`worker_lease_bound_test.dart` (wedge mid-run → lease freed, stale drive fenced).

## Rules

- Commit on `fix/onboarding-worker-lease-bound`; no push. No docker, no DB.
- If the correct fix genuinely requires paths outside `OWNED_PATHS`, stop and report
  `IMPLEMENTATION_BLOCKED` with the exact contract needed.
- Report per subtask-report.md: `RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`, HEAD_SHA,
  `READY_FOR_INDEPENDENT_REVIEW: YES|NO`.
