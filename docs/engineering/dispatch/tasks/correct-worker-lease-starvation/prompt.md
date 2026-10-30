# Dispatch — correct-worker-lease-starvation (correction loop cycle 1)

```yaml
MANAGER: orchestrator-main
TASK_ID: correct-worker-lease-starvation
TASK_TYPE: correct
FEATURE: F-226 worker-lease starvation recovery — post-checkpoint fencing correction
AREA: worker_runtime / local worker lease lifecycle
WORKTREE: /private/tmp/shipit-fix-worker-lease-starvation
BRANCH: fix/worker-lease-starvation
BASE_SHA: fb8dde3
REVIEWED_HEAD: 2b24f4ed676f2943a88a6092cada99f262b82a8a
OWNED_PATHS:
  - packages/worker_runtime/**
READ_ONLY_PATHS:
  - packages/scheduler/**
  - packages/execution_coordinator/**
  - packages/platform_contracts/**
  - apps/server/lib/src/persistence/postgres_worker_registration_store.dart
PROHIBITED_PATHS:
  - everything outside packages/worker_runtime/**
  - .agents/ .claude/ .opencode/ .junie/** AGENTS.md docs/adr/** .decisions/**
ACCEPTANCE_CRITERIA: see below
VALIDATION_COMMANDS:
  - dart format --output=none --set-exit-if-changed .   # worktree root
  - dart analyze                                       # packages/worker_runtime
  - dart test                                          # packages/worker_runtime
ROUTING_CLASS: PRECISION
```

## Reviewer finding to correct (verbatim, DO_NOT_MERGE BLOCKER on 2b24f4e)

> A detached stale drive abandoned *after* the pre-`execute` checkpoint still writes rows, results,
> and artifact commits — the epoch fence protects slot state and session start but not the rest of
> the drive. The only `_isStale` check is at `local_worker.dart:482`. A drive abandoned while wedged
> at `inspector.inspect`, `verificationsFor`, `artifactCommitter.commit`, `_finalCleanup`/
> `_cleanupAfterFailure`, `_finish`, or any post-496 `_event`/`_transition` resumes detached with no
> fence and runs to `_finish`, which CAS re-reads the `timedOut` terminal the abandon path wrote and
> cleanly overwrites it with `executedPass`/`executedFail`, overwrites the saved
> `WorkerExecutionResult`, and appends a `workspaceCleaned`/`workerReleased` event. With
> `preservesOnFailure` it also runs `artifactCommitter.commit`, which `checkout -B` force-moves
> `shipit/impl/<workItemId>` — the shared branch a retry's commit and a downstream reviewer resolve —
> to an abandoned run's artifact. `_detachedResult`'s doc claims the detached drive "writes nothing";
> that is only true before the checkpoint.

Suggested shape (reviewer's, advisory): thread `epoch` into `_finish` and return the detached result
without writing when `_isStale(epoch)`; re-check staleness after `settled` so a drive abandoned
during `execute` skips inspect/commit/finish; skip `artifactCommitter.commit` when stale.

## Also in scope (reviewer MEDIUM/LOW, same file — fold in, they are the same defect class)

- `_detachedResult` docstring overclaims ("writes nothing" — true only pre-checkpoint); correct it.
- Add a regression test for the post-checkpoint resume: a drive abandoned mid/post-`execute` that
  unwedges must NOT flip the terminal row, write a result, or run the artifact commit.
- Reviewer note: `_abandonDrive` cleanup can race a detached drive's in-flight worktree git ops —
  document the race where the cleanup runs.

## NOT in scope

- `OnboardingWorker` same-shape starvation (onboarding_worker.dart) — separate follow-up F-232, do
  not touch it here.

## Rules

- New correction commit on `fix/worker-lease-starvation` — NEVER amend/rebase `2b24f4e` (review
  provenance depends on it). Do not push.
- No docker/compose commands, no DB connections.
- Report per subtask-report.md: `RESULT: CORRECTION_COMPLETE` / `CORRECTION_BLOCKED`, the new
  HEAD_SHA, and `READY_FOR_FOCUSED_REVIEW: YES|NO`.
