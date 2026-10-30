# Dispatch — impl-detached-dispatch (F-237, PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: impl-detached-dispatch
TASK_TYPE: implement
FEATURE: F-237 detach dispatch-start from execution completion (tick serialization defect)
AREA: scheduler dispatch loop / tick composition
WORKTREE: /private/tmp/shipit-fix-detached-dispatch
BRANCH: fix/detached-dispatch
BASE_SHA: 94d8677
OWNED_PATHS:
  - packages/scheduler/lib/src/scheduler.dart
  - packages/scheduler/lib/src/dispatch/**
  - packages/scheduler/lib/src/queue/**
  - packages/scheduler/test/**
  - packages/worker_runtime/lib/src/dispatcher/**
  - packages/worker_runtime/test/**
READ_ONLY_PATHS:
  - apps/server/lib/server.dart
  - apps/server/lib/src/triage/**
  - packages/execution_coordinator/**
  - packages/platform_contracts/**
  - docs/engineering/FOLLOW_UPS.md
PROHIBITED_PATHS:
  - .agents/ .claude/ .opencode/ .junie/** AGENTS.md docs/adr/** .decisions/**
  - apps/server/lib/** (this lane changes the LIBRARY; the server.dart composition
    change is a separate lane if needed — report it if so)
  - **/generated/**
VALIDATION_COMMANDS:
  - dart format --output=none --set-exit-if-changed .
  - dart analyze        # packages/scheduler
  - dart test           # packages/scheduler
  - dart analyze        # packages/worker_runtime
  - dart test           # packages/worker_runtime
ROUTING_CLASS: PRECISION
```

## Defect (F-237, research-verified on live QA)

`await _dispatch.run(request)` at `scheduler.dart:1960` returns the TERMINAL
`WorkerExecutionResult` — the whole agent execution — awaited serially in `Scheduler.tick()`'s
dispatch loop (`:1068`). All five schedulers run inside ONE `TickSingleFlight`
(`server.dart:1242-1245`), so during ANY in-flight execution there is no tick at all: no
reconcile, no enqueue, no drain, every lane at once. `server.dart:1115-1148` already names it
"PRE-EXISTING and NOT fixed".

## Required change (research option 1 — detach dispatch from completion)

- `_dispatchOne` keeps claim + `markRunning` (`scheduler.dart:1940-1957`) but must NOT await the
  terminal result inside the tick. The terminal settlement path already exists and is
  restart-safe: `_reconcileClaim` → `_adoptFromExecution` (`scheduler.dart:2709-2750`, `:3030`)
  adopts a terminal worker execution once the claim lease expires.
- Add an in-process completion continuation so adoption is prompt rather than lease-latency-bound
  (the reconcile remains the durable backstop for crash/restart).
- Preserve: capacity-gate behavior (claim still acquired before dispatch), dedupe semantics,
  retry/terminal classification, `job_dispatched`/terminal event contract, and the dispatch
  loop's ordering/attempt tracking.
- Regression tests: a job dispatched mid-tick settles via the reconcile-adoption path after its
  execution terminates (not via the tick await); a second queued job dispatches in the SAME tick
  while the first execution is still running (the defect's observable signature).

## Rules

- New commits on the branch; no push. No docker, no DB.
- If the correct fix genuinely requires server.dart composition or other prohibited paths, stop
  and report `IMPLEMENTATION_BLOCKED` with the exact contract needed.
- Report per subtask-report.md: `RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`, HEAD_SHA,
  `READY_FOR_INDEPENDENT_REVIEW: YES|NO`.
