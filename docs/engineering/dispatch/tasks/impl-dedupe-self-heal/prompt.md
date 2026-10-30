# Dispatch prompt — impl-dedupe-self-heal

```yaml
MANAGER: orchestrator-main
TASK_ID: impl-dedupe-self-heal
TASK_TYPE: implement
FEATURE: F-227 activeDedupeKey self-heal on terminal job rows
AREA: scheduler job queue / postgres job store
WORKTREE: /private/tmp/shipit-fix-dedupe-self-heal
BRANCH: fix/dedupe-key-self-heal
BASE_SHA: fb8dde3
OWNED_PATHS:
  - packages/scheduler/lib/src/queue/**
  - packages/scheduler/test/**
  - apps/server/lib/src/persistence/postgres_job_store.dart
  - apps/server/test/**
READ_ONLY_PATHS:
  - packages/scheduler/lib/**
  - packages/platform_contracts/**
  - apps/server/lib/src/persistence/**
  - apps/server/lib/server.dart
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
  - packages/worker_runtime/** (owned by another live lane)
  - **/generated/**
  - apps/server/migrations/**
ACCEPTANCE_CRITERIA: see below
VALIDATION_COMMANDS:
  - dart format --output=none --set-exit-if-changed .            # cwd: repo root of the worktree
  - dart analyze                                                # cwd: packages/scheduler
  - dart test                                                   # cwd: packages/scheduler
  - dart analyze                                                # cwd: apps/server
  - dart run tool/run_unit_tests.dart                           # cwd: apps/server
ROUTING_CLASS: STANDARD
```

## Isolation pre-flight

```bash
cd /private/tmp/shipit-fix-dedupe-self-heal
git branch --show-current    # must equal fix/dedupe-key-self-heal
git rev-parse HEAD           # must start with fb8dde3
```

If either check fails, STOP and report `IMPLEMENTATION_BLOCKED` with the observed values.

## Original request (verbatim, from the Manager's live-QA diagnosis 2026-10-30)

> **F-227 `activeDedupeKey` leak.** `PostgresJobStore._jobToParams` derives
> `activeDedupeKey = job.isTerminal ? null : dedupeKey` (`postgres_job_store.dart:391`), so a
> terminal row written through the store always releases the key. But terminal rows written by ANY
> OTHER path — manual ops SQL, a repair migration, a future raw UPDATE — can hold a non-NULL
> `activeDedupeKey` forever. `enqueueIfAbsent` then collides on `job_active_dedupe_unique`, throws
> `DuplicateActiveJobException`, and returns `created: false` every tick (`job_queue.dart:103-115`) —
> permanent, silent suppression of a work item the queue is supposed to admit. Live repro on QA:
> `jb-hnny3s8b5p` (cancelled, `activeDedupeKey='DEF-fresh-test:design_revision'`) suppresses every
> enqueue for a work item parked at `design_required`, even though a cancelled job is meant to yield
> the key (`job_queue.dart:76`).

## Context and authoritative sources

- F-227 entry: `docs/engineering/FOLLOW_UPS.md` (end of file).
- The principled line already in `enqueueIfAbsent` (`job_queue.dart:42-64`): only `cancelled` yields
  the dedupe key; `failed`/`succeeded` deliberately keep it — **preserve that semantic**. The defect
  is the stale ACTIVE key on a terminal row, not the dedupe-retention policy. A `failed` latest row
  must still suppress re-enqueue; a `cancelled` latest row must not.
- `job_active_dedupe_unique` is a partial-key unique index; NULLs do not conflict.
- `apps/server/migrations/**` is prohibited: no schema change, no repair migration — fix the read/
  write path, not the table.
- Other live lane: `impl-worker-lease-starvation` owns `packages/worker_runtime/**` — disjoint.
- Open Human Decision ids this lane depends on: none.

## Acceptance criteria

- [ ] A terminal job row holding a stale `activeDedupeKey` can no longer wedge the queue: either
      `enqueueIfAbsent` self-heals (on `DuplicateActiveJobException`, if the conflicting holder is
      terminal, clear its `activeDedupeKey` and retry once) or an equivalent mechanism with the same
      effect. Choose the minimal-change option and say why.
- [ ] The dedupe-retention semantics are unchanged: `succeeded`/`failed` latest rows still suppress
      re-enqueue by policy (`created: false` without touching the row); `cancelled` latest rows yield.
- [ ] Regression coverage: a test that writes/forces a terminal job with a non-NULL `activeDedupeKey`
      (simulate the out-of-band write) then enqueues — proving the stale key is healed and the new
      job is created; plus a test that a `failed` holder still blocks by policy.
- [ ] If you find a second, distinct write path in the tree that can produce this state, report it;
      do not expand scope to fix it unless it is inside `OWNED_PATHS`.

## Required validation commands

- [ ] `dart format --output=none --set-exit-if-changed .` — repo root, exit 0
- [ ] `dart analyze` — `packages/scheduler`, exit 0
- [ ] `dart test` — `packages/scheduler`, all pass; report the count line verbatim
- [ ] `dart analyze` — `apps/server`, exit 0
- [ ] `dart run tool/run_unit_tests.dart` — `apps/server`; report the summary verbatim

## Hard rules

- Write only inside `OWNED_PATHS`. Never touch `PROHIBITED_PATHS`.
- Commit your work on `fix/dedupe-key-self-heal` with a conventional-style message; do NOT push.
- Do not approve your own work.
- Run no Docker or Compose command of any kind — shared Docker state is read-only for this lane.
- Do not connect to or mutate the QA Postgres database.
- Every result carries exact worktree/HEAD provenance.

## Cleanup before returning

- [ ] Stop every process you started; report any port/PID left running.
- [ ] Leave the worktree clean and committed, matching reported `HEAD_SHA`.

## Report format

Return a report conforming to `subtask-report.md`. Your `RESULT:` token is your own lane token
(`IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`), plus `SAFE_PARALLEL_WORK` and `PROHIBITED_PARALLEL_WORK`.
