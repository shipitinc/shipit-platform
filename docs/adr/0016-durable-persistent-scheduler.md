# ADR 0016: Durable Persistent Scheduler with Claim-CAS Job Queue

## Status
Accepted

## Context
The worker slice (ADR 0015) dispatches one lifecycle per call: no backlog, no
queueing, no fairness. Items pile up exactly when more than one is runnable at
a time. This ADR adds the durable scheduler these layers were left without —
a single-selector orchestration loop that owns *when* durable work executes
against the worker layer, without ever owning workflow policy itself.

Requirements:

- **One durable job per workflow-state window.** A `Job` is identified by a
  `dedupeKey` built from the workflow state (`${workItemId}:${item.state.wire}
  :${jobType.wire}:${role.wire}`). Enqueueing is idempotent: if the exact
  window already has a non-terminal job, enqueue is a no-op. When a blocked
  item resolves (e.g. human approves design), the workflow state changes, the
  dedupe key changes, and a *new* job is created — the old window's closure is
  never replayed.
- **Blocked items consume zero capacity.** A `waitingForHumanDecision` item is
  never enqueued, never polled, and never reserves a worker slot. Runnable
  items (`designNotRequired`/`designApproved`) split a single worker slot one
  at a time; the losing job stays in the queue.
- **At-most-once execution under multi-replica races.** Claiming a job is a
  version compare-and-swap (`ConcurrentJobModificationException`); two
  scheduler replicas sharing one durable job store can race a claim, but only
  one CAS wins and the job executes exactly once. The writer must not commit a
  lost update (`expect(identical(...), isFalse)`).
- **Crash restart must not duplicate or lose work.** A claim carries a lease
  (`ownerId` + `leasedUntil`). Reconcile at tick start requeues claims whose
  executionReference was never durably written; claims whose worker execution
  already exists merely renew the lease and are never re-run. A durable
  terminal `WorkerExecution` is adopted as the job's outcome.
- **Outcome mapping is policy-shaped but never workflow-shaped.** Terminal
  production outcome (`executedPass`/`executedFail`) converges the job; SDK
  failure (`prepareFailed`) and orchestration cancellation produce distinct
  failures; timeout/orphan map to a *transient* failure that retries through
  `retryWaiting` → `queued` (promoted and claimed in the same `claim()` call)
  up to `maxAttempts`, and never auto-retries failed coding results.
- **Anything portable must live in the scheduler package.** `dart:io`,
  fake-store code, and the real-stack harness are test-only, so the library
  stays cross-platform for the eventual Serverpod control plane.

## Decision
**A new `scheduler` package implements one tick loop and a durable job queue.**

- **`tick()` is the only write path.** Eight deterministic steps: reconcile
  expired claims (lease → requeue/renew/adopt) → evaluate every item's
  runnability through the real `WorkflowEngine` transition gate → cancel the
  queued jobs of terminal items / idempotently enqueue runnable items / touch
  nothing for blocked items → dispatch loop. `SchedulerTickResult` reports
  `reconciled/enqueued/dispatched/cancelledQueued/deferred/terminal`.
- **The dispatch loop makes one attempt per job per tick.** A per-tick
  `attempted` set prevents infinite spins on worker-placement failures while
  still letting jobs completed earlier in the loop free capacity for later
  jobs. A dispatch exception is not skipped: the claim is `revertToQueued`
  and the job is deferred.
- **Terminality is a job property, not a dispatch property.** Only an adopted
  terminal outcome stops the loop; transient outcomes return to the queue and
  are eligible again on the next tick (`retryWaiting` → `queued` consumes the
  lease and produces a fresh claim in one `claim()` call).
- **Two durable job stores with identical semantics.** `FileJsonJobStore`
  (crash restart, cross-process) and `InMemoryJobStore` (tests, in-process)
  both enforce dedupe, version-CAS claims, and the stable eligible ordering
  (`priority` → `availableAt` → `createdAt` → `jobId`). Replicas must share one
  store instance; CAS is guaranteed within a single store connection.
- **Real-stack proof stays deterministic and full-fidelity.** Tests run a
  real `DurableWorkflowEngine` + `ExecutionCoordinator` + `LocalWorker` (real
  git worktree, capacity-1, git-observed diff capture) plus the scheduler on
  the same stores, with a gated fake runtime whose first execution parks on a
  release gate so capacity semantics are observed without timers.

## Consequences
- Jobs exist only for workflow-state windows, so a human-driven resume is a new
  job in a new state, never a replayed execution.
- Cancellation is a first-class durable action at the job layer (queued jobs
  cancel without an execution) and at the worker layer (running jobs cancel the
  worker and converge to `cancelled`, which is never treated as approval).
- At-most-once holds for claims, renewal, adoption, and dispatch; crash
  restart is covered by a full restart test against a file-backed store.
- The scheduler keeps all workflow policy (`WorkflowState`,
  `TransitionTrigger`, QA contracts) inside `workflow_engine` and never
  mutates a `WorkItem` itself.
- Still out of scope, deferred to the control plane slice: PostgreSQL-backed
  stores via Serverpod, HTTP/gRPC dispatch transport, distributed/remote
  workers, UI. Deferred work is documented in the scheduler slice report.