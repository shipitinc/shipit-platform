# Dispatch — review-zombie-exec-orphan

```yaml
MANAGER: orchestrator-main
TASK_ID: review-zombie-exec-orphan
TASK_TYPE: review
FEATURE: F-235 — zombie reclaim retires agent_execution row + seam wired at all 5 Scheduler sites
AREA: scheduler reclaim / execution lifecycle / composition wiring
WORKTREE: /private/tmp/shipit-fix-zombie-exec
BRANCH: fix/zombie-exec-orphan
BASE_SHA: da62a2d
HEAD_SHA_UNDER_REVIEW: b2fe008fa30ac07351aad180047b917d3f2b3dc9
ROUTING_CLASS: STANDARD
```

Independent read-only review of TWO commits on `fix/zombie-exec-orphan`:
- `74a7d2e` — `_reclaimZombie` retires the `agent_execution` row (new AgentExecutionRetirement seam;
  `storeBackedAgentExecutionRetirement` CAS-closes the row in the reclaim TX); the implementer's own
  audit found the stale rows didn't hold the JOB-tier cap (which counts job.state) — they blocked
  re-execution via ExecutionAlreadyActiveException + held phantom liveness. Verify that mechanism
  claim, not the original premise.
- `b2fe008` — `agentExecutionRetirement:` wired at all 5 `Scheduler(` sites in server.dart +
  `composition_wiring_test.dart` source-binding guard.

Verify rigorously:
1. The reclaim write: `_retireAgentExecutionRow` CAS-closes orphaned+completedAt+reason+audit in
   the same durable TX as the job terminal write — not a separate/racy write; terminal/missing =
   no-op; CAS loss swallowed (reclaim re-entrant); other failures propagate honestly.
2. agentExecutionIdForWorkerExecution derivation — how a wx executionId maps to its agx row; the
   orphaned worker row now carries resolved agentExecutionId.
3. Wiring: exactly five `Scheduler(` sites each carry `agentExecutionRetirement:` over the right
   store (the discovery: `coordinator.store` vs `implementationCoordinator.store` are distinct
   PostgresExecutionStore over the same table — either works, but verify the impl site's choice
   doesn't break the `implementation_verification_plan_test.dart` 3-occurrence pin).
4. composition_wiring_test is a source-binding guard (text match) — verify it's non-vacuous and
   can't silently pass if a site unwires.
5. The implementer flagged a residual hole OUT of scope: `_reconcileClaim`'s adopt path
   (execution.isTerminal → _adoptFromExecution) can complete a job while an agent_execution row
   stays running. Confirm it's genuinely residual (needs its own lane) not a blocker here.
6. Gates re-run: `dart format --set-exit-if-changed .` (root), `dart analyze` + `dart test`
   (scheduler, worker_runtime), `dart run tool/run_unit_tests.dart` (apps/server) — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:`.
