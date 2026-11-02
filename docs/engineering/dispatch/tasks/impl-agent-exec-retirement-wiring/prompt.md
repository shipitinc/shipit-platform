# Dispatch — impl-agent-exec-retirement-wiring

```yaml
MANAGER: orchestrator-main
TASK_ID: impl-agent-exec-retirement-wiring
TASK_TYPE: implement
FEATURE: Wire agentExecutionRetirement seam into the Scheduler constructors in server.dart (completes F-235)
AREA: composition wiring (apps/server)
WORKTREE: /private/tmp/shipit-fix-zombie-exec (SAME worktree — prior lane done at 74a7d2e)
BRANCH: fix/zombie-exec-orphan (continue — the seam lives here)
BASE_SHA: 74a7d2e
OWNED_PATHS: [apps/server/lib/server.dart, apps/server/test/composition_wiring_test.dart]
READ_ONLY_PATHS: [packages/worker_runtime/lib/src/execution/agent_execution_retirement.dart, packages/scheduler/lib/src/scheduler.dart]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/**, packages/**]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root), dart analyze (apps/server), dart run tool/run_unit_tests.dart (apps/server)]
ROUTING_CLASS: STANDARD
```

## The wiring gap (verified by the prior implementer)

`74a7d2e` adds an optional `AgentExecutionRetirement` seam —
`worker_runtime/lib/src/execution/agent_execution_retirement.dart` exports
`storeBackedAgentExecutionRetirement(<ExecutionStore>)` — that makes `_reclaimZombie` retire the
`agent_execution` row (the F-235 fix). But it's optional and NOT wired: the `Scheduler(...)`
constructors in `apps/server/lib/server.dart` (the prior lane counted five sites) need
`agentExecutionRetirement: storeBackedAgentExecutionRetirement(<ExecutionStore>)` — same pattern
as `executionLiveness`. Until wired, production retains the prior behavior.

## Task

1. Grep the five `Scheduler(` sites in `apps/server/lib/server.dart`; each already wires
   `executionLiveness:` — add `agentExecutionRetirement:` the same way, using the store instance
   each site already has (the ExecutionStore).
2. Verify `storeBackedAgentExecutionRetirement` is exported via worker_runtime.dart (it is —
   `74a7d2e`).
3. Extend `apps/server/test/composition_wiring_test.dart` (or add a matching test) to assert the
   seam is wired at all sites — same guard style as existing wiring tests.
4. Gates: `dart format --set-exit-if-changed .` (root), `dart analyze` (apps/server),
   `dart run tool/run_unit_tests.dart` (apps/server).

## Rules
New commits on `fix/zombie-exec-orphan` (continue the same worktree — the seam lives there);
no push; no docker/DB. Report per subtask-report.md ending `RESULT: IMPLEMENTED` /
`IMPLEMENTATION_BLOCKED` with exact HEAD + `READY_FOR_INDEPENDENT_REVIEW:`.
