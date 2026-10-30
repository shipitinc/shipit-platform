# Dispatch — impl-persistence-tx-slot (F-238, PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: impl-persistence-tx-slot
TASK_TYPE: implement
FEATURE: F-238 PersistenceDatabase single-transaction-slot race under detached dispatch
AREA: persistence layer / composition wiring
WORKTREE: /private/tmp/shipit-fix-tx-slot
BRANCH: fix/persistence-tx-slot
BASE_SHA: ea7754a
OWNED_PATHS:
  - apps/server/lib/src/persistence/**
  - apps/server/lib/server.dart
  - apps/server/test/**
READ_ONLY_PATHS:
  - packages/scheduler/**
  - packages/worker_runtime/**
  - docs/engineering/FOLLOW_UPS.md
PROHIBITED_PATHS:
  - .agents/ .claude/ .opencode/ .junie/** AGENTS.md docs/adr/** .decisions/**
  - **/generated/**
VALIDATION_COMMANDS:
  - dart format --output=none --set-exit-if-changed .
  - dart analyze                                       # apps/server
  - dart run tool/run_unit_tests.dart                  # apps/server
ROUTING_CLASS: PRECISION
```

## Confirmed production defect (F-238 — observed live on QA, 2026-10-30)

`PersistenceDatabase` owns ONE transaction slot. Under F-237's detached dispatch, a tick (or its
detached continuation) can drive a second `inTransaction` while a detached run's commit is still
in flight — producing `DatabaseQueryException: Session or transaction has already finished` at
live sites (design.tick, implementation.tick, `redriveSettledReviews`→`PostgresJobStore.listJobs:336`).
`server.dart` wires the Postgres stores to ONE shared `db`/`PersistenceDatabase` wrapper (~:251-255),
so every logical writer shares the slot — the harness fix that worked in tests (one
`PersistenceDatabase(db.db)` wrapper per logical caller) maps directly to production.

## Task

Remove the transaction-slot race from the production path:
- Give each Postgres store that needs transactional integrity its OWN `PersistenceDatabase`
  (wrapping the same underlying `Session`/`db`), OR serialize `inTransaction` per wrapper with
  an explicit mutex/lock so concurrent `inTransaction` calls queue rather than collide —
  whichever matches the codebase's existing abstraction. Inspect `PersistenceDatabase`
  (`apps/server/lib/src/persistence/`) first; implement whichever remedy is structurally correct
  there, not per-call-site patches.
- Preserve: transaction semantics per logical caller, rollback behavior, advisory-lock usage in
  `inCapacityLockedTransaction`, and all existing call sites' contracts.
- Regression test(s) proving two concurrent logical writers (e.g. a detached-run commit racing a
  tick's `inTransaction`/`listJobs`) no longer throw `Session or transaction has already finished`
  — mirror the harness collision that exposed it (independent wrappers or serialized slot).

## Rules

- New commits on `fix/persistence-tx-slot`; no push. No docker, no DB.
- If the correct fix genuinely needs paths outside OWNED_PATHS, stop and report
  `IMPLEMENTATION_BLOCKED` with the exact contract.
- Report per subtask-report.md: `RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`, HEAD_SHA,
  `READY_FOR_INDEPENDENT_REVIEW: YES|NO`.
