# Dispatch prompt — impl-worker-lease-starvation

```yaml
MANAGER: orchestrator-main
TASK_ID: impl-worker-lease-starvation
TASK_TYPE: implement
FEATURE: F-226 worker-lease starvation recovery
AREA: worker_runtime / local worker lease lifecycle
WORKTREE: /private/tmp/shipit-fix-worker-lease-starvation
BRANCH: fix/worker-lease-starvation
BASE_SHA: fb8dde3
OWNED_PATHS:
  - packages/worker_runtime/**
READ_ONLY_PATHS:
  - packages/scheduler/**
  - packages/execution_coordinator/**
  - packages/platform_contracts/**
  - apps/server/lib/server.dart
  - apps/server/lib/src/persistence/postgres_job_store.dart
  - apps/server/lib/src/persistence/postgres_worker_registration_store.dart
  - docs/engineering/FOLLOW_UPS.md
  - AGENTS.md
PROHIBITED_PATHS:
  - .agents/
  - .claude/
  - .opencode/
  - .junie/**
  - AGENTS.md
  - docs/adr/**
  - .decisions/**
  - apps/server/lib/** (other than reading server.dart / the two persistence files above)
  - packages/scheduler/** (read-only for this lane)
  - packages/execution_coordinator/** (read-only for this lane)
  - packages/agent_runtime/** 
  - **/generated/**
ACCEPTANCE_CRITERIA: see below
VALIDATION_COMMANDS:
  - dart format --output=none --set-exit-if-changed .            # cwd: repo root of the worktree
  - dart analyze                                                # cwd: packages/worker_runtime
  - dart test                                                   # cwd: packages/worker_runtime
ROUTING_CLASS: PRECISION
```

## Isolation pre-flight

```bash
cd /private/tmp/shipit-fix-worker-lease-starvation
git branch --show-current    # must equal fix/worker-lease-starvation
git rev-parse HEAD           # must start with fb8dde3
```

If either check fails, STOP and report `IMPLEMENTATION_BLOCKED` with the observed values.

## Original request (verbatim, from the Manager's live-QA diagnosis 2026-10-30)

> **F-226 worker lease starvation.** `w-impl-local` and `w-triage-local` report `busy 1/1` on every
> heartbeat with ZERO running jobs. `LocalWorker._leased` (`packages/worker_runtime/lib/src/worker/
> local_worker.dart:125`) is held by `run()` futures wedged inside `_drive` — two live executions ran
> 8.2h and 9.2h before the 90-minute zombie sweep orphaned their ROWS at 02:05 (budgets: impl 4h,
> triage 30m). The sweep is a DB-level act with no path back to the worker process: nothing aborts the
> hung run and nothing releases the in-process lease. All 7 queued `implement_feature` jobs plus every
> future triage job defer `workerBusy` on every tick — the implementation lane on live QA is starved.

## Context and authoritative sources

- F-226 entry: `docs/engineering/FOLLOW_UPS.md` (end of file).
- The only timed await in `_drive` is `executionDriver.execute(agentRequest).timeout(...)` at
  `local_worker.dart:279-285` (timeoutSeconds + `workerLeaseGrace`). The wedge is therefore in an
  UNBOUNDED await: candidates are `_event(...)` writes, `inspector.inspect` (full git walk — the
  dogfood timeout signature from prior sessions), `_cleanupAfterFailure`, `_finish`, or a DB write on
  a locked connection pool.
- The zombie reclaim lives in `packages/scheduler/lib/src/scheduler.dart` (search "zombie",
  "orphaned", `zombieStalenessAfter`). It is read-only for this lane: if your fix requires a
  scheduler-side signal (e.g. an abort flag the worker polls), implement the worker-side half and
  report the needed scheduler contract as an unresolved issue — do NOT edit the scheduler.
- `executionDriver.cancel(executionId, reason)` already exists and is used by the timeout arm
  (`_cancelAgent`, `local_worker.dart:475-484`).
- No other lanes currently running except `impl-dedupe-self-heal` (owns `packages/scheduler/lib/src/queue/**`,
  `packages/scheduler/test/**`, `apps/server/lib/src/persistence/postgres_job_store.dart`,
  `apps/server/test/**`) — disjoint from yours.
- Open Human Decision ids this lane depends on: none.

## Acceptance criteria

- [ ] A wedged `_drive` can no longer hold `LocalWorker._leased` forever: the worker has a bound
      on the WHOLE run (not only the `execute` await) after which it abandons the drive, marks the
      execution terminal with an honest status/failureCode, releases the lease, and keeps heartbeating.
- [ ] A hung agent session is actually stopped where possible — use the existing
      `executionDriver.cancel` path rather than only unblocking the await.
- [ ] Regression coverage: a test that wedges `_drive` at an unbounded await (stub the driver or the
      inspector) and proves the lease is released and the worker returns to `idle`/`isAcquirable`.
- [ ] No behavior change for the normal pass/fail/timeout paths; existing tests stay green.
- [ ] If the correct fix genuinely requires changes outside `OWNED_PATHS`, stop at the boundary and
      report `IMPLEMENTATION_BLOCKED` with the precise contract needed — do not self-widen.

## Required validation commands

- [ ] `dart format --output=none --set-exit-if-changed .` — repo root, exit 0
- [ ] `dart analyze` — `packages/worker_runtime`, exit 0
- [ ] `dart test` — `packages/worker_runtime`, all pass; report the count line verbatim

## Hard rules

- Write only inside `OWNED_PATHS`. Never touch `PROHIBITED_PATHS`.
- Commit your work on `fix/worker-lease-starvation` with a conventional-style message; do NOT push.
- Do not approve your own work.
- Run no Docker or Compose command of any kind (`ps`, `logs`, `config`, `info`, `up`, `down`, …) —
  shared Docker state is read-only for this lane; read compose files as text if needed.
- Do not connect to or mutate the QA Postgres database.
- Every result carries exact worktree/HEAD provenance.

## Cleanup before returning

- [ ] Stop every process you started; report any port/PID left running.
- [ ] Leave the worktree clean and committed, matching reported `HEAD_SHA`.

## Report format

Return a report conforming to `subtask-report.md`. Your `RESULT:` token is your own lane token
(`IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`), plus `SAFE_PARALLEL_WORK` and `PROHIBITED_PARALLEL_WORK`.
