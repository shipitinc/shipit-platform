# execution_coordinator

Glues a provider-neutral agent runtime to the durable workflow engine for
**one bounded, durable, independently-verified execution per work item**.

## Responsibility

Given an `AgentExecutionRequest` (a `runtimeTypeId`, a workspace, a bounded
instruction, a requested `AgentRole`):

1. Claims the execution id (idempotent; terminal records replay).
2. Moves the work item into `WorkItemState.agentExecuting` via the public
   workflow transitions.
3. Starts a session through `agent_runtime` (`AgentRuntime.startSession`),
   persisting every state change (`AgentExecution`, CAS-versioned) and every
   normalized event (`AgentEventRecord`, sequentially ordered).
4. On the session's terminal event, stamps the result with the *requested*
   role and execution id (never anything the agent asserted), runs the
   platform's independent `VerificationPlan` in the workspace, persists a
   `PlatformVerification` (pass or fail), and advances the work item to
   `agentCompleted` or `agentFailed`.
5. Exposes `cancelExecution` and `reconcileOrphans` for operator cancellation
   and process-exit recovery. Orphans become `orphaned` — executions are never
   resumed from a conversation the platform cannot prove is alive.

The coordinator is provider-agnostic: no OpenCode, model, or provider is
hardcoded here.

## Layout

- `lib/src/coordinator/execution_coordinator.dart` — orchestration, event
  normalization, terminal handling, orphan reconciliation.
- `lib/src/store/` — `ExecutionStore` interface + in-memory and atomic
  JSON-file implementations (compare-and-swap on the execution version).
- `lib/src/verifier/workspace_verifier.dart` — platform-runner for the
  verification command (real processes, capped output, timeout kill).

## Testing

- `test/execution_store_test.dart` — store round-trips, CAS conflicts, reload
  from disk.
- `test/workspace_verifier_test.dart` — passes/fails on real workspace state,
  spawn failures, timeouts, output caps.
- `test/execution_coordinator_test.dart` — happy path, replay, independent
  verification disagreement, fail/interrupt/cancel, unknown provider, orphan
  reconciliation, file-store durability (all with a scripted session — no
  network).
- `test/real_opencode_smoke_test.dart` — **opt-in** end-to-end proof against a
  real `opencode` binary:

  ```bash
  SHIPIT_REAL_OPENCODE=true dart test test/real_opencode_smoke_test.dart
  ```

  Skipped by default. A failure usually means the runtime could not cold-start
  within the session timeout (network/catalog fetch) — see the failure message.