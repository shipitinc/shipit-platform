# Dispatch — fix-zombie-exec-orphan (F-235 elevated to defect)

```yaml
MANAGER: orchestrator-main
TASK_ID: fix-zombie-exec-orphan
TASK_TYPE: implement
FEATURE: Zombie reclaim closes the job but leaves agent_execution 'running' — stale rows hold the agent-execution cap forever
AREA: scheduler reclaim / execution lifecycle
WORKTREE: /private/tmp/shipit-fix-zombie-exec
BRANCH: fix/zombie-exec-orphan
BASE_SHA: HEAD
OWNED_PATHS: [packages/scheduler/**, packages/worker_runtime/**, packages/workflow_store/**]
READ_ONLY_PATHS: [packages/platform_contracts/**, packages/execution_coordinator/**, apps/server/lib/**]
PROHIBITED_PATHS: [apps/server/**, .agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/**]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root), dart analyze + dart test (each touched package)]
ROUTING_CLASS: STANDARD
```

## Confirmed defect (live on QA)

The zombie-reclaim path (`_reclaimZombie`/the staleness sweep) drives a wedged job to terminal
`failed` but leaves its `agent_execution` row at `status='running'` forever — the row was written
by the dead drive and is never finalized. 13+ stale `running` `agent_execution` rows accumulated;
they held the concurrent-agent cap (phantom capacity) and blocked every queued job until closed
manually.

## Task

1. Find the reclaim path — wherever a stale `agentExecuting`/`running` execution is reclaimed and
   the JOB is driven terminal. The `agent_execution` row must be transitioned to a terminal status
   (with `completedAt` + reason like 'zombie execution reclaimed') in the same durable write/TX as
   the job terminal write — not left running.
2. Audit the capacity-cap read: confirm whether it counts `agent_execution` rows, `worker_execution`
   rows, or both — the phantom-cap hazard is whichever counts un-ended rows forever. If a worker
   tier row also stays un-ended, close it the same way.
3. Regression test: a wedged execution reclaimed → both the job AND the `agent_execution` row are
   terminal (not just the job); a genuinely-live execution is untouched.
4. The repair must not double-close: if the reclaim path is invoked again on the same execution it
   should be idempotent (closing an already-terminal row is a no-op, not an error).

## Rules
New commits; no push; no docker/DB. Report per subtask-report.md: `RESULT: IMPLEMENTED` /
`IMPLEMENTATION_BLOCKED`, HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`.
