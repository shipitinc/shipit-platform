MANAGER: orchestrator-main
TASK_ID: IMPL-WORKER-REGISTRATION
TASK_TYPE: implement
FEATURE: LocalWorker never registers, so the operator surface invents a machine shortage that does not exist
AREA: packages/worker_runtime + composition root wiring
WORKTREE: /Users/alkebut/.aef-lanes/worker-registration
BRANCH: fix/worker-registration-lifecycle
BASE_SHA: e8cd0ce
OWNED_PATHS:
  - packages/worker_runtime/lib/src/worker/local_worker.dart
  - packages/worker_runtime/lib/src/worker/worker.dart          (only if the lifecycle hook genuinely belongs on the interface)
  - apps/server/lib/server.dart
  - apps/server/test/worker_registration_lifecycle_test.dart    (new file, this name only)
READ_ONLY_PATHS:
  - packages/worker_protocol/**
  - apps/server/lib/src/persistence/postgres_worker_store.dart
  - apps/server/lib/src/endpoints/worker_endpoints.dart
  - apps/server/lib/src/services/control_plane_service.dart
  - apps/control_plane/lib/core/plain_language.dart
PROHIBITED_PATHS:
  - apps/server/lib/src/persistence/util/db_row_util.dart        (OWNED BY CONCURRENT LANE IMPL-TRANSITION-ROW-500)
  - apps/server/lib/src/persistence/postgres_workflow_store.dart (OWNED BY CONCURRENT LANE IMPL-TRANSITION-ROW-500)
  - apps/server/migrations/**                                   (OWNED BY CONCURRENT LANE IMPL-TRANSITION-ROW-500)
  - apps/server/test/transition_row_malformed_guard_test.dart
  - apps/server/test/malformed_guard_evaluation_repair_migration_test.dart
  - packages/scheduler/**                                       (read-only; RESEARCH-AGENT-COMPLETED-INFLOW is investigating)
  - packages/execution_coordinator/**  apps/control_plane/**
  - docker/**  .github/**  infrastructure/**
ACCEPTANCE_CRITERIA:
  - Each production `LocalWorker` writes a registration row on startup and refreshes it on a bounded
    heartbeat, so `workerEndpoints.listWorkers` returns the real fleet instead of `[]`.
  - A worker that stops heartbeating becomes visibly stale rather than permanently "available".
    Use the existing staleness vocabulary in `packages/worker_protocol` if one already exists; do not
    invent a parallel one.
  - Heartbeat lifecycle is bounded and does NOT prevent clean server shutdown: no unbounded timer, no
    leaked subscription, no work surviving `Serverpod` stop. State how you proved this.
  - The operator surface stops claiming "waiting for a free machine" / "0 of 0 machines busy" when the
    real cause of a queued job is something else. If the label is derived server-side, registering the
    workers is sufficient and you touch NO client file. If it turns out a client change is required,
    STOP and report `IMPLEMENTATION_BLOCKED` naming the exact file — `apps/control_plane/**` is NOT
    yours.
  - Tests cover: registration appears on start; heartbeat refreshes; shutdown does not hang.
VALIDATION_COMMANDS:
  - cd /Users/alkebut/.aef-lanes/worker-registration && dart format --output=none --set-exit-if-changed packages/worker_runtime apps/server/lib apps/server/test
  - cd /Users/alkebut/.aef-lanes/worker-registration && dart analyze packages/worker_runtime apps/server
  - cd /Users/alkebut/.aef-lanes/worker-registration && dart test apps/server/test/worker_registration_lifecycle_test.dart
ROUTING_CLASS: STANDARD

## The original request, verbatim

"could work you on these concurrently (you're the orchestrator) where they don't conflict?"

## Evidence (independently reproduced by the Manager against the live QA stack)

The QA control plane is running and dispatching successfully. Live facts:

1. `POST /api/workerEndpoints {"method":"listWorkers"}` returns `{"workers": []}` — **zero rows.**
2. The Overview screen renders "0 of 0 machines busy" and labels queued jobs
   "waiting for a free machine".
3. **That machine shortage does not exist.** Jobs demonstrably ran. The live event log for
   `jb-hn8rwr8iwi-n2rynt` is:

       2026-10-15T19:27:38Z  job_queued
       2026-10-15T19:27:40Z  job_claimed
       2026-10-15T19:27:40Z  job_dispatched
       2026-10-15T20:54:55Z  job_retry_scheduled
       2026-10-15T20:56:31Z  job_claimed
       2026-10-15T20:56:31Z  job_dispatched
       2026-10-15T20:58:14Z  job_completed

   So three workers claimed and dispatched work on 2026-10-15.

The mechanism:

- `apps/server/lib/server.dart:325-379` constructs three real workers —
  `w-triage-local`, `w-review-local`, `w-impl-local` — and registers them into an **in-memory**
  `WorkerRegistry`, which is what `WorkerDispatcher` actually selects from (`server.dart:376-382`).
  Dispatch is therefore healthy.
- Each is constructed with `workerStore: workerStore` where `workerStore = PostgresWorkerStore(db)`
  (`server.dart:205`). **No `LocalWorker` ever calls it.** A grep of
  `packages/worker_runtime/lib/src/worker/local_worker.dart` for `register` / `upsert` / `heartbeat`
  returns nothing.
- `apps/server/lib/src/endpoints/worker_endpoints.dart:33` `listWorkers` reads the Postgres store,
  which nothing writes — hence `[]`.

**The operator is being told a machine shortage is the reason their work is stuck, and that reason
is fabricated.** One of the open defects in QA, `defect-DEF-1791686704991884` ("Machine UI says
1 of 0"), is a report of this same defect surface.

This matters beyond cosmetics: an operator debugging a stall is sent to the wrong cause by design.

## Authoritative sources

- `AGENTS.md` (root) — note the read-only-over-Docker rule; the QA stack is shared state
- `docs/engineering/WORKFLOW.md`, `docs/engineering/STRUCTURED_RESULTS.md`

## Other lanes running concurrently (you must not touch their paths)

- **IMPL-TRANSITION-ROW-500** — owns `db_row_util.dart`, `postgres_workflow_store.dart`,
  `apps/server/migrations/**`, and two named test files
- **RESEARCH-AGENT-COMPLETED-INFLOW** — read-only, investigating `packages/scheduler/**`

Your `OWNED_PATHS` and theirs do not intersect. If you need a file one of them owns, STOP and
report `IMPLEMENTATION_BLOCKED` naming the exact file and why.

## Cleanup checklist (mandatory)

- [ ] `git branch --show-current` == `fix/worker-registration-lifecycle`
- [ ] `git rev-parse HEAD` still descends from `e8cd0ce` before you start
- [ ] all VALIDATION_COMMANDS run and genuinely passing — report real output
- [ ] commit your work on your branch (a real commit, not just a dirty tree)
- [ ] report exact `git rev-parse HEAD` of your worktree
- [ ] **Do NOT run any docker or docker compose command.** AGENTS.md binds every lane. In particular
      do not restart the QA stack to "verify" — the Manager owns that.
- [ ] **Do NOT connect to or modify the live QA database** (no psql against localhost:5432).