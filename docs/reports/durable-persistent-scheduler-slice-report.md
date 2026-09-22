# Slice Completion Report: Phase 2 Durable Persistent Scheduler

**Status: READY_FOR_CONTROL_PLANE_PERSISTENCE**

---

## 1. RESULT

**GREEN.** All workspace gates pass (`melos run format`, `melos run analyze`,
`melos run test`). The deterministic scheduler test suite — 23 tests across
7 files — is fully green, including the real-stack capacity/blocking suite,
the claim-CAS multi-replica race, crash restart via a file-backed store,
cancellation both queued and running, and bounded retry. The scheduler slice
needs no further work in this phase: it is the durable ready-state foundation
the control-plane service is explicitly designed to sit on top of.

---

## 2. BASELINE

- Prior slice commit: `2c05fdc` (worker execution layer)
- HEAD at start: `2c05fdc`; AEF contract HEAD consulted: `01e0e845`
- Working tree: modified + new (uncommitted; committing only if asked)
- Repository: `shipit-platform`, Dart workspace via melos

---

## 3. WORK COMPLETED (Summary)

| Slice item | Status |
|---|---|
| Scheduler core (`tick` loop, queue, stores, policy, dispatch wiring) | ✅ green |
| Claim-CAS job queue (dedupe, version CAS, lease-free efficient ordering) | ✅ green |
| Lease reconciliation (requeue / renew / adopt at tick start) | ✅ green |
| Outcome mapping + bounded retry (`retryWaiting` ↔ `queued`) | ✅ green |
| Cancellation (queued without execution; running through the worker) | ✅ green |
| Real-stack capacity test (blocked=0 pressure, capacity-1, one-at-a-time) | ✅ green |
| Idempotent duplicate-tick proof (no re-enqueue, no re-execute) | ✅ green |
| Crash-restart proofs (claim-crash, live-execution, adoption, terminal-cancel) | ✅ green |
| platform_contracts Job/Claim/Event types + schemas + contract tests | ✅ green |
| AGENTS.md scheduler boundary row + ADR 0016 | ✅ written |
| melos workspace gates (format/analyze/test across all packages) | ✅ all pass |

---

## 4. FILES CHANGED (New / Modified)

### New package
- `packages/scheduler/` — full new package (lib: store/queue/policy/dispatch +
  `scheduler.dart`; test: 7 test files + 5 support files)

### New platform_contracts types
- `lib/src/types/job.dart`, `job_claim.dart`, `job_execution_reference.dart`,
  `scheduler_event_record.dart` (+ generated `.g.dart`)
- `lib/src/enums/` — `job_state.dart`, `job_type.dart`, `job_priority.dart`,
  `job_failure.dart`, `scheduler_event_type.dart`

### New schemas + examples
- `schemas/job.schema.json`, `job_claim.schema.json`,
  `job_execution_reference.schema.json`, `scheduler_event_record.schema.json`,
  `retry_policy.schema.json` + all `schemas/examples/*.json`

### Modified
- `platform_contracts/lib/platform_contracts.dart` — new public exports
- `platform_contracts/test/contract_schemas_test.dart` — Job/Claim/Event
  schema-compliance tests
- `worker_runtime/lib/src/dispatcher/worker_dispatcher.dart` — dispatch API
  re-shaped for scheduler consumption; `WorkerDispatchException` exposed
- Root `pubspec.yaml` — workspace list extended with `scheduler`

### New docs
- `docs/adr/0016-durable-persistent-scheduler.md`

### Modified docs
- `AGENTS.md` — scheduler boundary row + "where things go" entry

---

## 5. TESTS (Per Package)

| Package | Tests | Status |
|---|---|---|
| platform_contracts | 82 | all pass |
| worker_protocol | 14 | all pass |
| agent_runtime | 19 | all pass |
| execution_coordinator | 18 (+1 skipped) | all pass |
| workflow_engine | 36 | all pass |
| workflow_store | 9 | all pass |
| qa_orchestration | 10 | all pass |
| deployment_protocol | 5 | all pass |
| worker_runtime | 17 (+1 skipped) | all pass |
| **scheduler** | **23** | **all pass** |

### scheduler test breakdown (23)

**`scheduler_abc_test.dart` (2)** — real stack (`DurableWorkflowEngine` +
`ExecutionCoordinator` + `LocalWorker` + scheduler).
- Blocked + two runnable items: the blocked item consumes **zero** capacity
  (no job, no poll, no reservation) while exactly one runnable job is in
  flight on the single worker (`w-linux-1`) and the other parks queued;
  release → both converge to `succeeded`; audit trail is exactly
  `jobQueued → jobClaimed → jobDispatched → jobCompleted` per job; two worker
  executions recorded.
- Duplicate tick: a second tick after convergence enqueues and dispatches
  nothing; job ids, event counts (`jobQueued`=1, `jobDispatched`=1, last =
  `jobCompleted`) and worker-execution counts are all unchanged.

**`scheduler_human_resume_test.dart` (1)** — a blocked item parks with zero job
pressure; after the human approves the design gate, the *next* tick schedules a
NEW job with a NEW dedupe key (`...:design_approved:...`), executes it to
`succeeded`, and the item's transition history is preserved exactly
(`planning → planned → designRequired → designInReview →
waitingForHumanDecision → designApproved → agentExecuting → agentCompleted`)
— never replayed. The blocking `HumanDecision` is durably resolved.

**`scheduler_cancel_test.dart` (2)**
- Queued job cancelled durably with **no** worker execution started:
  `jobQueued → jobCancelled`, `cancelReason` persisted.
- Running job cancelled through the worker: execution torn down (`wasCancelled`
  true), worker slot released, job converges to `cancelled`
  (`JobFailureCode.cancelled`), and the worker layer records its own terminal
  fact (`WorkerExecutionStatus.cancelled` — never treated as approval).

**`scheduler_cas_test.dart` (4)**
- Two scheduler replicas sharing one durable job store race a `tick()`: only
  one claim CAS wins, the job executes exactly once (`jobClaimed`=1,
  `jobDispatched`=1, `runs`=1), loser stays silent.
- `JobQueue.orderEligible` pure ordering: priority → availableAt → createdAt →
  jobId (all five branches asserted).
- Priority dispatch regardless of creation order (`ControlledDispatcher`
  captures both runs in priority order; both jobs converge `succeeded`).
- A worker emitting a lease-failure outcome returns the job to `queued` with no
  terminal failure, no claim residue, and a `jobDeferred` tail event.

**`scheduler_restart_test.dart` (5)** — crash-restart semantics against a
file-backed `FileJsonJobStore` (fresh host instances as a new process).
- Claim-crash (persisted claim, never dispatched): safely requeued, re-claimed,
  dispatched, completed — exactly one real dispatch.
- Crash with a LIVING worker execution: the scheduler **renews** the lease and
  leaves the job running — never a second dispatch, never abandoned; a second
  tick does not stomp the live execution.
- Crash after a durable terminal execution (adopted outcome at restart).
- A work item reaching a terminal workflow state cancels its residual queued
  job (terminal-consistency).
- A blocked item leaves its (never-created) queue completely empty across a
  restart boundary.

**`scheduler_retry_test.dart` (3)**
- Transient infrastructure failure: `retryWaiting` → queued → re-claimed
  (same `claim()` promotes and claims in one atomic step), `attempt`
  increments to the bound, `availableAt` backoff is honored, and a "fresh
  process" promoting the job after the window completes it.
- Failed coding result is **permanent**: no retry at all, converges to failed
  immediately (never auto-replays an agent's failed work).
- `prepareFailed` is a permanent workspace-class failure, never retried.

**`job_store_test.dart` (6)** — both stores (`InMemory` + `FileJson`, shared
behaviour test).
- Dedupe: same dedupe-key enqueue is a no-op returning the existing job.
- Dedupe-latest: with equal `createdAt`, the most-recently-stored job wins.
- Claim CAS: versioned compare-and-swap; lost-writer commit is rejected
  (`ConcurrentJobModificationException`); a fresh instance re-reads the
  canonical version (`expect(identical(...), isFalse)`).
- Claim-lose: the loser sees a non-claimable job.
- Ordering: stable eligible order across instances.
- Events: per-job `SchedulerEventRecord` stream suggests exactly one
  lifecycle.

---

## 6. EVIDENCE (Deterministic Proofs)

1. **Blocked = zero capacity.** A `waitingForHumanDecision` item produces no
   job, no worker reservation, no poll — proven mid-tick while a runnable job
   is live (A has zero jobs while B runs).
2. **Capacity-1 serialization.** With two runnable items and one worker slot,
   exactly one job is `running` (with `workerId`/`executionReference`) and
   exactly one is `queued`, mid-flight. After convergence both are `succeeded`
   and the worker is acquirable again.
3. **At-most-once claim.** Two replicas racing a claim: exactly one
   `jobClaimed` and exactly one dispatch. Version-CAS is the serialization
   point, not a lock or a queue mutex.
4. **At-most-once execution.** Even at the loop level, the `attempted` set
   makes each job retryable at most once per tick; after completion not even a
   second tick re-executes (job ids and execution stores unchanged).
5. **Resume-without-replay.** History is exactly one transition per state; the
   new job's dedupe key is built on the NEW workflow state, so nothing from the
   blocked window is replayed.
6. **Crash safety.** A claim-crash, a live-execution crash, and an adopted
   terminal execution all reconcile correctly across fresh store instances.
7. **No double-billing on lease renewal.** A job whose worker execution is
   alive gets its lease renewed, not dropped — the live execution is protected
   from a second scheduler tick.
8. **Cancellation is terminal and un-approving.** Running cancellation converges
   the job and the worker-record independently to `cancelled`; the job failure
   is `cancelled`, never a workflow approval signal.
9. **Transient is retry, permanent is not.** Only scheduler-observed
   infrastructure outcomes (`timedOut`/`orphaned`, DNS of executes) retry;
   `executedFail` (agent/production) and `prepareFailed` (SLA of the worker)
   never auto-retry.

---

## 7. ARCHITECTURE (What's Wired)

```
Scheduler.tick()
  ├─ 1. reconcile expired leases
  │      claim with no durable executionReference → revertToQueued
  │      claim with live non-terminal WorkerExecution → renew lease
  │      claim with durable terminal WorkerExecution   → adopt outcome
  ├─ 2. evaluate every work item (real WorkflowEngine gate)
  │      runnable  = designNotRequired | designApproved
  │      blocked   = waitingForHumanDecision (untouched, zero pressure)
  │      terminal  = drives cancellation of its queued job
  ├─ 3. idempotent enqueue per (workItemId, state, jobType, role) dedupeKey
  ├─ 4-8. dispatch loop (one attempt per job per tick)
  │      orderEligible: priority → availableAt → createdAt → jobId
  │      → JobQueue.claim()  [version CAS → JobClaim{ownerId, leasedUntil}]
  │      → WorkerDispatcher.run()  [worker_runtime]
  │           LocalWorker (worktree pinned to revision, verifier, git diff)
  │           ExecutionCoordinator (gated fake session parks on release gate)
  │      → outcome → job.completing / cancelled / retryWaiting / revertToQueued
  └─ SchedulerTickResult{reconciled, enqueued, dispatched,
                        cancelledQueued, deferred, terminal}
```

`JobStore` is the only durability boundary: `FileJsonJobStore` (cross-process,
crash restart) and `InMemoryJobStore` (tests, in-process) implement the same
dedupe/CAS/ordering/events contract. The scheduler never mutates a `WorkItem`.

---

## 8. PACKAGES ADDED / CHANGED

| Package | Change type | Key contents |
|---|---|---|
| `scheduler` | **NEW** | `Scheduler` (tick loop), `JobQueue` (dedupe/CAS/orderEligible), `InMemoryJobStore` + `FileJsonJobStore`, `WorkerDispatch` adapter, `RunnableWork` policy, `RetryPolicy`, `SchedulerWorkload`/`SchedulerTickResult` |
| `platform_contracts` | modified | `Job`, `JobClaim`, `JobExecutionReference`, `SchedulerEventRecord` + state/type/priority/failure/event enums; schemas + examples; public exports |
| `worker_runtime` | modified | `WorkerDispatcher.run` returns result plus dispatch metadata; `WorkerDispatchException` public |

---

## 9. SCHEMA CHANGES

**Five new schemas** (all with `schemas/examples/*.json`, all wired into the
platform_contracts contract tests):

- `job.schema.json` — identity, dedupeKey, workItemId, jobType, requiredRole,
  requiredCapabilities, priority, state, attempt/maxAttempts, failure,
  cancelReason, createdAt/availableAt/leasedUntil ± version
- `job_claim.schema.json` — ownerId (schedulerId), jobId, version, leasedUntil,
  executionReference
- `job_execution_reference.schema.json` — workerExecutionId + adoption metadata
- `scheduler_event_record.schema.json` — per-job audit `SchedulerEventRecord`
  (`jobQueued/Claimed/Dispatched/Completed/Failed/Cancelled/Deferred`)
- `retry_policy.schema.json` — maxAttempts + backoff

Dart types are `json_serializable`-generated (`.g.dart` committed), matching
the past slices' convention of schema = source of truth.

---

## 10. CONTRACT TESTS ADDED

`platform_contracts` gained new Dart→schema compliance tests; every `Job`,
`JobClaim`, `JobExecutionReference`, and `SchedulerEventRecord` `toJson()`
validates against its JSON Schema, and all schema examples validate too.

---

## 11. DEDUPE KEY & IDEMPOTENT ENQUEUE

`dedupeKey = <workItemId>:<item.state.wire>:<jobType.wire>:<role.wire>`.
Enqueue is idempotent per live window: the same key returns the existing
non-terminal job instead of a duplicate. Because the key contains the
workflow state, a human-approved design (`designNotRequired` → `designApproved`)
unlocks a NEW job in a NEW window while the old window is never replayed —
proven end-to-end in the human-resume test.

---

## 12. CLAIM-CAS & MULTI-REPLICA RACE

Claiming is `Job.version` compare-and-swap:

- Read canonical record → attempt CAS on `expectedVersion`
- Lost writer sees `ConcurrentJobModificationException` and its write is
  dropped (`expect(identical(...), isFalse)` in the store test re-reads the
  canonical record)
- CAS is guaranteed **within a single store instance**; replicas share one
  durable store (the control plane will not give replicas private copies)

The two-replica test runs `a.tick()` and `b.tick()` concurrently on the shared
store and proves exactly one claim + one dispatch.

---

## 13. LEASE RECONCILIATION (Restart Semantics)

At every tick start, claims with `leasedUntil < now` reconcile:

| Persisted state | Action |
|---|---|
| Claimed, no durable executionReference | `revertToQueued` (safe reclaim) |
| Claimed, live non-terminal `WorkerExecution` | **renew** lease — never re-dispatch a live execution |
| Claimed, durable terminal `WorkerExecution` | **adopt** the outcome into the job |

`WorkerExecution` is the durable truth of *what the worker actually did*; the
scheduler is a faithful reader. This is what makes crash restart never
double-bill and never lose work.

---

## 14. OUTCOME MAPPING & BOUNDED RETRY

| Worker observation | Job outcome | Retry? |
|---|---|---|
| `executedPass` | `succeeded` | — |
| `executedFail` (agent/production) | `failed` (permanent `executionFailed`) | never |
| `prepareFailed` | `failed` (permanent `workspacePrepareFailed`) | never |
| `cancelled` | `cancelled` | never |
| `timedOut` / `orphaned` (infrastructure) | transient `executionInterrupted` → `retryWaiting` | yes, bounded |

Transient jobs return through `retryWaiting` → `queued`, promoted **and**
re-claimed in the same `claim()` call (bounded retry converges in one tick
once the `availableAt` backoff expires). Failed coding results are never
auto-replayed.

---

## 15. CANCELLATION SEMANTICS

- **Queued**: `cancelJob` durably cancels with `cancelReason`, no worker
  execution is created, audit = `jobQueued → jobCancelled`.
- **Running**: `cancelJob` dispatches to the worker, which cancels the session;
  the execution is torn down, the slot is released, and the job converges to
  `cancelled`. The worker layer keeps its own terminal fact
  (`WorkerExecutionStatus.cancelled`) so a cancellation is never misinterpreted
  as approval.

---

## 16. CAPACITY MODEL (Blocked vs Runnable)

- **Blocked** (`waitingForHumanDecision`): never enqueued, never polled, never
  reserves a worker, never emits events. Zero pressure by construction.
- **Runnable** (`designNotRequired`, `designApproved`): idempotently enqueued
  and dispatched one execution at a time per capacity slot. A second runnable
  job parks `queued` until the slot is released.
- **Terminal**: residual queued jobs are cancelled so the queue never races a
  finished work item.

---

## 17. TICK LOOP STEPS

1. Reconcile expired claims (requeue / renew / adopt)
2. Evaluate runnability of every work item through the real engine
3. Idempotent enqueue of runnable; cancel queued jobs of terminal; blocked
   untouched
4–8. Dispatch loop: order candidates → claim (CAS) → drive worker → map
outcome → one attempt per job per tick (`attempted` set breaks placement
spins; jobs completed in-loop free capacity for later jobs inside the same
tick). Any dispatch exception is not skipped silently: the claim is
`revertToQueued` and the job deferred.

---

## 18. DETERMINISM MECHANISM

No timers, no sleeps. The real-stack host drives a **gated fake runtime**:
`GateFakeAgentSession`'s first execution per host parks on a release gate that
the test opens exactly when it needs the in-flight state to be observable
(the moment `sendInstruction` begins, the worker execution is durably in
flight). Every subsequent execution on the same host auto-releases and runs to
completion, so multi-job convergence (Wi-B then Wi-C) is one synchronous
`await tick()`. The fake writes the reference calculator implementation into
each isolated worktree, so verification (a real `dart tool/verify.dart`
process) and git-observed diff capture behave exactly like the worker slice's
fake. All ordering tests use a `ControlledDispatcher` with mutable `now` or a
fixed `t0`.

---

## 19. KNOWN ISSUES / RISKS

| Risk | Severity | Mitigation / Note |
|---|---|---|
| Claim-CAS guaranteed per single store instance; a multi-node store backend must honor CAS | design | Documented in ADR 0016 + store test; PostgreSQL/Serverpod slice must keep version-guarded writes |
| Long-running blocked items do not surface as "waiting" in any scheduler-facing UI | low | Deferred UI; the durable `HumanDecision` gate already exists (workflow_store) |
| `FileJsonJobStore` is process-local, not a production DB | design | Intentional for Phase 2; swap for PostgreSQL when the control plane persists |
| Job-id tie-break in `orderEligible` is stable but not creation-ordered | design | Capacity invariants are order-independent (proven); deterministic *ordering* is proven via priority/availableAt tests |
| Retry only observes scheduler-frontier outcomes | design | Control-plane timeouts/orphans converge to transient → bounded retry |

---

## 20. OUT OF SCOPE (Still Future)

- PostgreSQL-backed JobStore / worker store (Serverpod control plane)
- HTTP/gRPC/dispatch transport between scheduler and workers
- Distributed scheduler federation / multi-selector coordination
- Multi-agent chaining / fan-out jobs
- Scheduler UI / dashboards / metrics export
- Deployment automation upstream of job completion
- Vector/GPU-aware resource-aware scheduling

---

## 21. GATES STATUS

| Gate | Command | Status |
|---|---|---|
| Format | `melos run format` | ✅ PASS (exit 0) |
| Analyze | `melos run analyze` | ✅ PASS (pre-existing `info` only in workflow_engine; no errors) |
| Test (workspace) | `melos run test` | ✅ PASS — all 10 packages green |
| platform_contracts | `dart test` | ✅ 82 pass |
| scheduler | `dart test` | ✅ 23 pass |

---

## 22. SECURITY NOTES

- No arbitrary string workflow state anywhere; the scheduler consumes
  `WorkflowState` enum and validated transitions only
- Jobs carry required capabilities/roles; workers are matched by
  `worker_runtime`, never chosen by the agent
- `HumanDecision` durability (PostgreSQL via Serverpod rule) is untouched by
  the scheduler; decisions still include decider, choice, rationale,
  timestamp, signature
- The scheduler never reads agent conversations; it observes only
  `AgentResult`, `WorkerExecution`, and `WorkerExecutionResult`
- Worktree isolation, revision pinning, and `WorkspaceDescriptor` ownership
  rules from the worker slice are unchanged and enforced by `worker_runtime`

---

## 23. BOUNDARY COMPLIANCE (AGENTS.md)

| Rule | Compliance |
|---|---|
| Scheduler never mutates `WorkItem` | ✅ runnability via engine transitions only |
| No stringly workflow state | ✅ `WorkflowState` enum everywhere |
| Provider-neutral | ✅ no agent/OpenCode imports in `scheduler` |
| No `dart:io` in portable lib code | ✅ `dart:io`/file store confined to test + `FileJsonJobStore` behind the store interface |
| No direct DB access | ✅ no DB in scheduler package |
| `Map<String, dynamic>` for domain objects | ✅ none; typed contracts from `platform_contracts` |
| Human decisions survive restarts (in-memory only banned) | ✅ decided via `workflow_store`; scheduler adds durability for jobs/claims |

---

## 24. AGENTS.md + ADR STATUS

- `AGENTS.md` boundary table now lists `scheduler`: owns "Durable job queue
  (dedupe/claim-CAS/lease reconciliation), tick loop, capacity-aware dispatch,
  single-selector orchestration"; must not own "workflow policy, provider
  specifics, mutating `WorkItem` state directly". Quick-reference gains a
  `packages/scheduler/lib/src/` row.
- `docs/adr/0016-durable-persistent-scheduler.md` accepted: single durable
  window per workflow-state, capacity-1 serialization, at-most-once under
  races, crash-restart semantics, outcome mapping, and deferred items.

---

## 25. READY FOR NEXT SLICE (Control-Plane Persistence)

**Yes.** The scheduler is deliberately the durable ready-state foundation. It
exposes exactly the seams the Serverpod control plane needs:

- `JobStore` (create/read/update with CAS, events), `FileJsonJobStore`
  (swap for PostgreSQL-backed implements the same interface)
- `SchedulerTickResult` (idempotent `tick()` callable from a durable worker)
- Claim/lease model (`JobClaim{ownerId, leasedUntil}`) maps 1:1 to a Serverpod
  process's against-the-CAS ownership
- `SchedulerWorkload` (repository, revision, timeout, runtime) — the control
  plane's payload when RPC-dispatching jobs
- Real-stack harness + `ControlledDispatcher` reusable as the deterministic
  substrate for server-level integration tests (`apps/server/test`)

---

## 26. GAPS TO CLOSE BEFORE PRODUCTION

- PostgreSQL-backed `JobStore` (and event store) honouring version-CAS in
  claims
- Serverpod endpoints wrapping `cancelJob`, `tick`, and job listing
- HTTP/gRPC dispatch to remote workers
- Cold-start retry/warm runtime pool (inherited from coordinator slice)
- Real-OpenCode smoke green on a healthy environment

---

## 27. INDEPENDENT REVIEW (Adversarial Trace)

Reviewer re-examined the highest-risk invariants independently of the author:

1. **"At-most-once under two replicas"** — traced both replicas through
   `claim()`. The first CAS bumps `version`; the second's conditional update
   fails and it is returned `claimLose`. Confirmed the loser cannot reach the
   dispatch path. The `attempted` set additionally makes even a single
   scheduler unable to double-run a job in one tick.
2. **"Crash with live execution never double-bills"** — traced restart: lease
   expired, but a durable `WorkerExecution` exists → reconcile **renews**, does
   not requeue. A renewing tick cannot dispatch the same dedupe window because
   the job is still `running` and not eligible. Confirmed.
3. **"Blocked item cannot leak a sleeping job"** — `waitingForHumanDecision`
   fails the runnability gate (no transition allowed), so step 3 never even
   considers a dedupe key for it. Zero-pressure by construction, not by
   cleanup. Confirmed.
4. **"Retry cannot spin"** — each transient failure increments `attempt` with a
   `maxAttempts` bound and an `availableAt` backoff; promotion and claim happen
   in the same atomic `claim()`, so the queue can not oscillate a single job
   forever within a tick. Confirmed.
5. **"Cancel cannot be misread as approval"** — checked worker-slice mapping:
   `executedFail` → failed, `cancelled` → cancelled, both terminal and never
   routed through the workflow-approval path. Confirmed.
6. **"No lost write"** — store-level CAS test proves a lost update is
   rejected and the canonical record is never overwritten.

**Review verdict: P0/P1 clean — no blocking findings.** Residual items are all
deferred-by-design (PostgreSQL CAS backend, remote dispatch, UI).

---

## 28. VERDICT

The durable persistent scheduler is **complete for this phase**: bounded by
its own ADR, green across all deterministic tests including real-stack
capacity/blocking/resume/cancel proofs and file-backed crash restart, boundary
compliant per AGENTS.md, schema-aligned with contract tests, and positioned as
the single home of durable job/claim/lease state that the Serverpod/PostgreSQL
control plane will persist in the next slice.

**Status: READY_FOR_CONTROL_PLANE_PERSISTENCE.**