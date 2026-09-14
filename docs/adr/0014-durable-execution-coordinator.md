# ADR 0014: Durable Execution Coordinator Glues One Provider to the Workflow

## Status
Accepted

## Context
ADR 0006 selected OpenCode over ACP as the first real agent runtime and ADR
0013 made workflow gates durable. The remaining gap: a **single durable
execution** that connects that real runtime to the durable workflow engine and
results in *verifiable, platform-independent evidence* — without leaking
provider specifics into policy.

Requirements for this slice:

- **One bounded execution per decision.** The platform drives exactly one
  `AgentExecutionRequest` → `AgentExecution` → `AgentResult` cycle. The work
  item enters `agentExecuting` and leaves via `agentCompleted`/`agentFailed`;
  the agent can never move the work item by itself.
- **Durability at every stop.** The request, the execution record (with
  compare-and-swap versioning), every normalized event, the terminal result,
  and the platform's own verification survive process exits. Resume after a
  crash is *reconciliation*, never "trust me, the conversation was fine": any
  session this coordinator cannot prove is still alive is marked `orphaned`.
- **Role is stamped by the platform.** `AgentResult.role` and `executionId`
  come from the orchestration request, not from anything the agent says.
- **Evidence is independent.** QA evidence is collected by the platform, in the
  workspace, by running real commands (`WorkspaceVerifier` → `dart test`), and
  persisted as `PlatformVerification`. The agent's `claimedChecks` are claims
  and are never promoted to verification.
- **Provider-neutral routing.** Runtime selection is the request's
  `runtimeTypeId`; the coordinator never hardcodes a model, provider, or agent.
- **Never hang forever.** A wedged runtime must not pin an execution for the
  transport's lifetime.

## Decision
Add a `execution_coordinator` package that owns the orchestration seam:

- **`ExecutionCoordinator.execute`**: idempotent on the execution id (a
  terminal record replays, a live one rejects), moves the work item into
  `agentExecuting` through public workflow transitions, starts a
  provider-neutral `AgentSession`, persists each state change as an
  `AgentExecution` and each normalized event as an `AgentEventRecord`
  (sequential, per-execution), and finalizes on the session's terminal event.
- **Verification plan**: on success the platform runs an independent
  `VerificationPlan` (default `['dart', 'test']`, no network required for the
  hermetic fixtures) in the workspace and persists a `PlatformVerification`
  with the outcome — recorded whether it passes *or* fails, so the agent's
  success report and the platform's verdict can explicitly disagree.
- **`ExecutionStore`**: in-memory plus JSON-file implementations; the file
  store persists atomically (temp file + rename, serialized writes) and
  enforces compare-and-swap on the execution version.
- **`cancelExecution` / `reconcileOrphans`**: cancellation stops the live
  session and finalizes as `cancelled`; orphan reconciliation marks stranded
  non-terminal executions `orphaned` and exits the work item out of
  `agentExecuting` — orphaned, not "resumed".
- **Bounded runtime startup**: `OpenCodeProcessTransport` bounds every wire
  request (default 5 minutes), and `OpenCodeSession.start` bounds the
  `initialize`/`session/new` handshake to the session timeout. A
  slow-to-start runtime therefore fails timely instead of blocking the executor
  for up to 30 minutes.
- **Real-runtime proof is opt-in**: `real_opencode_smoke_test.dart` runs the
  entire loop against a real `opencode` binary only when
  `SHIPIT_REAL_OPENCODE=true`. All deterministic behavior (phantom providers,
  scripted sessions, capability routing, event normalization, orphan
  reconciliation, store durability) is covered by unit tests that never need a
  network.

## Consequences
- Workflow policy stays pure: `workflow_engine` still knows nothing about
  OpenCode, ACP, or providers.
- The dashboard/control plane can render any execution from the durable record
  without replaying the model.
- `orphaned` is a deliberate platform answer to the "fake resume" temptation:
  we never resurrect a conversation we cannot prove is alive.
- Cold-start variability of local runtimes (observed: 3s to >8 minutes on an
  intermittent network) is contained by the tight start bound, but the opt-in
  smoke test still requires a healthy runtime environment.
- Out of scope, still future work: scheduler/dispatcher, worker pool, queuing,
  PostgreSQL-backed store, multi-agent chains.