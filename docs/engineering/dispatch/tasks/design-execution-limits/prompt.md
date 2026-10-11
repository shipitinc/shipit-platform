# Dispatch — design-execution-limits

```yaml
MANAGER: engineering-manager
TASK_ID: design-execution-limits
TASK_TYPE: design-produce
FEATURE: Bound agent execution so a burst of intake cannot exhaust the host
AREA: scheduler dispatch, triage re-dispatch, agent runtime
WORKTREE: /private/tmp/shipit-limits
BRANCH: design/execution-limits
BASE_SHA: 5fb319a
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-execution-limits/**
READ_ONLY_PATHS:
  - packages/scheduler/lib/**
  - apps/server/lib/src/triage/**
  - packages/agent_runtime/lib/**
  - apps/server/lib/server.dart
  - AGENTS.md
PROHIBITED_PATHS:
  - packages/**
  - apps/**
  - docker/**
  - .github/**
  - .decisions/**
  - AGENTS.md
ACCEPTANCE_CRITERIA: >
  A burst of N queued defects produces at most C concurrent agent executions, a bounded queue
  depth, a per-defect invocation ceiling, and a host-load guard — each independently testable.
VALIDATION_COMMANDS:
  - bash apps/server/tool/verify_schema_bootstrap.sh
ROUTING_CLASS: PRECISION
URGENCY: The host crashed. QA is down and must not restart without at least the concurrency cap.
```

---

## Why this lane exists — a production incident

The operator queued ~9 defects and ~several feature requests through the Add Defect and Add Feature
Request UIs. The host **crashed** (reboot at 22:47:04; load average had reached 138 in the 5-minute
window). Server logs from before the crash:

```
[triage.processed] {..., defectId: DEF-..., classification: implementation_defect, clarificationCount: 3}
defects triaged: 9   (8 implementation_defect, 1 design_defect)
clarificationCount: total=21, max_per_defect=3
```

Nine defects, each driving up to three agent sessions — roughly 21–27 opencode invocations, each
forking a workspace of the triage repo — with nothing bounding concurrency.

**This is a defect in the system this work item built.** Every prior gate was static analysis and
in-memory tests; the agent path had never executed at all before that burst. The operator found it by
using it.

## Verified facts — do not re-derive

- **There is no capacity limit anywhere.** `packages/scheduler/lib/src/scheduler.dart:258-286` is
  `for (;;) { final eligible = ...; for (final job in eligible) { await _dispatchOne(job, now); } }`
  with **no cap**. The comment at :258 says *"lets a job that completed during this tick free a
  capacity slot for the next one"* — but no capacity concept is implemented. That comment is a
  description of a limit that does not exist.
- `_eligibleRunnableJobs` (`:297`) filters by state/claim only — never by running-workload size.
- `packages/agent_runtime/lib/src/acp/opencode_process_transport.dart:58` is where a real process is
  spawned (`Process.start`). `workspace_verifier.dart:75` spawns more.
- `triage_processor.dart:137-140` creates clarifications and logs `clarificationCount`;
  `clarificationCount` reached **3** for a single defect.
- `defect_endpoints.dart:207 answerClarification` exists; there is **no** `enqueueIfAbsent` in
  `defect_endpoints.dart`, so a clarification answer does not itself re-enqueue — establish where the
  second and third rounds are actually driven from before designing the per-defect ceiling.
- `model_execution_record` exists and is written by the runtime; it is the natural durable home for a
  per-defect invocation count, subject to the schema question below.

## What to design

### 1. Global concurrency cap (the most important — design this first)
A cap `C` on **simultaneously running agent executions**, enforced where dispatch actually spawns.
Decide and justify:
- **Where the semaphore lives.** In-process in `Scheduler`/dispatcher, or durable in the job store
  (e.g. count `running` jobs at claim time)? Consider: QA is a single process, but production may run
  more than one replica, and a restart must not silently reset the count. If durable, what is the
  claim-time transaction and does it stay correct under two replicas?
- **Whether the cap is global or per-(product, worker, runtimeType).** Nine defects for one product
  should still be bounded; per-product scoping does not bound the host.
- **What happens to a job that does not get a slot.** It must stay `queued`/`deferred` and be retried on
  a later tick — never marked failed, never silently dropped. State it explicitly.
- **The default `C`.** Justify it from evidence (core count, memory per agent, measured cost), and make
  it configurable without a code change.

### 2. Queue depth limit
A bound on how many jobs may sit eligible per tick / per product, so 50 queued defects drain at a
sane rate. Decide: is this a per-tick dispatch budget, a backlog cap that refuses new intake, or both?
If it refuses intake, the refusal must be **honest and visible** — the operator gets a real answer, not
a silent drop. Reuse the established skip-code / honest-reporting shape.

### 3. Per-defect invocation ceiling
A hard ceiling on total agent invocations for one defect, independent of per-job `maxAttempts`
(which is 2). Design: where the count is kept (see schema question), what happens when the ceiling is
reached (terminal state with an honest reason, not a retry loop), and how it interacts with
clarification rounds. A defect that legitimately needs more than the ceiling must have a named,
visible path — never a silent truncation.

### 4. Host-load guard (optional per the operator — assess and recommend)
A guard that refuses to dispatch when the host is already loaded. **Critically: this may be a bad idea
in a container.** Assess honestly:
- The server runs inside a container; does it have a reliable view of host CPU/memory, or only its own
  cgroup limit? If it cannot see the host, a "host load" guard is fiction — say so.
- What is the alternative? A cgroup/Compose memory+CPU limit on the server and worker services is a
  **deployment** concern rather than a code concern and may be strictly better. Recommend accordingly,
  and design the code guard only if a real signal exists.

### 5. Tests
Design the verification for each, including the negative cases:
- N queued jobs never exceed C running, verified by an instrumented fake runtime that counts concurrent
  entries and records the observed maximum.
- The cap is enforced **across ticks**, not just within one tick.
- A job denied a slot is retried on a later tick and eventually succeeds.
- Two concurrent `run()` calls cannot both take the last slot (no overshoot by one).
- The per-defect ceiling is reached and the defect reaches a terminal, honest state.
- A refusal due to depth/ceiling/load is **visible in the record**, never silent.

## Constraints

- Design only. Proposed diffs go IN THE DOCUMENT AS TEXT. No production source, no generated files, no
  tests changed.
- `packages/**`, `apps/**`, `docker/**`, `.github/**`, `.decisions/**`, `AGENTS.md`, `docs/**` (outside
  your task dir) are PROHIBITED — read them, do not touch them.
- ZERO Docker/Compose commands. The QA stack is DOWN after the crash and I will bring it back; it is
  not yours to touch. Read compose as text. `bash apps/server/tool/verify_schema_bootstrap.sh` is
  read-only and permitted — run it and report. Never `make clean` / `make qa-down` /
  `make test-env-down` / `make e2e-down` / bare `down -v`.
- Do not resolve a Human Decision. Where the design needs human authority — especially the default
  value of `C`, and whether intake should ever refuse — escalate rather than choosing.
- Read `AGENTS.md` and honour the established lane conventions: non-overlapping `OWNED_PATHS`,
  `SAFE_PARALLEL_WORK` / `PROHIBITED_PARALLEL_WORK`, and the honest-reporting discipline this
  work item has enforced throughout (an unavailable dependency is recorded as `EXTERNAL_*`, never
  stubbed).

## Deliverable

A Design Revision under your task directory per `DESIGN_GOVERNANCE.md` with proposed diffs as text,
`RISK_LEVEL` with rationale, per-constraint traceability, the implementation lane plan with
non-overlapping `OWNED_PATHS` and dependency edges, and a clear statement of what must ship
**before QA is restarted** versus what can follow.

Report `READY_FOR_INDEPENDENT_DESIGN_REVIEW`. Escalate any decision you decline to make.