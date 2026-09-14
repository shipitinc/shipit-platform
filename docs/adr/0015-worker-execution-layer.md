# ADR 0015: One Worker Execution = One Pinned, Isolated, Verified Workspace

## Status
Accepted

## Context
ADR 0014 gave the platform one durable `ExecutionCoordinator` bounded to a
single provider. The remaining gap: the coordinator would run **in whatever
directory you tell it to**. Running agents in a shared checkout is how a
second-hand model run edits files someone else is relying on. This ADR adds
the worker layer that decides *where* and *under what lease* one execution
runs. Requirements:

- **One request, one worker, one worktree.** A `WorkerExecutionRequest` (with
  explicit `startingRevision` and `requiredCapabilities`) is matched to a
  compatible worker with exactly one live execution slot. There is no
  scheduler, queue, or fairness here; dispatch selects and drives.
- **Source isolation is a correctness property.** The agent must never run in
  the shared repository checkout. It runs in a detached `git worktree` pinned
  **exactly** to the requested revision, so a dirty or newer checkout can
  never influence the worktree the agent sees.
- **Evidence must be git-observed, not agent-claimed.** After execution the
  worker inspects the worktree with git (`rev-parse`, `diff --name-status`)
  and captures `ChangedFile`s before anything is cleaned up.
- **Lifecycle must be durable and resumable by policy, not by conversation.**
  A `WorkerExecution` record (compare-and-swap versioned) plus a
  `WorkerEventRecord` stream survive restarts, and a reconciler recovers
  stranded executions as `orphaned` — it never "resumes" them.
- **Cleanup must be conservative and idempotent.** Only workspaces the
  platform owns (marked by a `WorkspaceDescriptor` JSON written *outside* the
  worktree) are ever cleaned. `preserveOnFailure` keeps a failed worktree for
  debugging; the default removes it. Cleanup runs a second time safely.

## Decision
**A new `worker_runtime` package implements the worker layer**, keeping all
workflow policy in `workflow_engine` and all provider logic in `agent_runtime`.
Dispatch refuses to start if the runtime would run on the wrong revision.

- **Selection is pure and deterministic.** `WorkerSelector` + `CapabilityMatcher`
  choose a compatible, available (capacity-1) worker; outcomes are
  `dispatched` / `noCompatibleWorker` / `workerBusy`. The dispatcher re-checks
  the live lease before driving the run.
- **`LocalWorker` drives one lifecycle.** It acquires the worker, prepares the
  worktree, delegates to `ExecutionCoordinator` (`AgentExecutionId =
  agx-<workerExecutionId>`, `workspace = the worktree`), inspects the git state
  before cleanup, honors the cleanup policy, and always releases the worker in
  `finally`. Worker-level backstop timeout = `timeoutSeconds +
  workerLeaseGrace`; the coordinator's own session bound already fires first.
- **`GitWorktreeWorkspaceManager` writes a `WorkspaceDescriptor`** with
  `workspaceId`, `workerExecutionId`, `startingRevision`, and `worktreePath` as
  a JSON file outside the worktree. Reconciliation discovers ownership from
  these files and **never deletes a directory without one**.
- **`WorkerReconciler`** marks executions stranded mid-flight (non-terminal
  record + cleaned/lost workspace) as `orphaned` and reclaims their workspaces.
  Reconcile is idempotent across brand-new store/manager instances.
- **Environment is policy-gated.** `EnvironmentPolicy` resolves the agent
  environment from an explicit allowlist of host variables plus non-secret
  overrides; precedence is low→high: allowlisted host vars, request
  `environment`, policy `explicit`. Un-inherited host variables never reach the
  runtime.
- **Real-runtime proof stays opt-in** (`SHIPIT_REAL_OPENCODE=true`); all
  deterministic behavior is proven with a fake writing runtime against real
  git repositories.

## Consequences
- The shared checkout is never mutated by agent execution, and the worktree can
  never drift from the requested revision.
- The platform can prove after the fact, from git, what the agent changed —
  independent of the agent's claims and before any cleanup.
- Workers are deliberately not a scheduler: no backlog, fairness, or queueing.
  A future slice can sit on top of `WorkerSelector`/`WorkerRegistry`.
- Interrupted runs are `orphaned` and cleaned/reclaimable; they are never
  credulously resumed.
- Worktrees are an isolation boundary, not a security sandbox — an agent can
  still reach the network and the host.
- Out of scope, still future work: distributed/remote workers, gRPC/HTTP
  transport, PostgreSQL-backed worker store, GPU provisioning, scheduling.