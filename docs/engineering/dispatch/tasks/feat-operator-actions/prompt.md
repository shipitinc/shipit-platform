# Dispatch — feat-operator-actions (F-254)

```yaml
MANAGER: orchestrator-main
TASK_ID: feat-operator-actions
TASK_TYPE: implement
FEATURE: expose operator actions for states the UI currently shows none — qa_passed -> advance to deploy, stranded agent_executing -> reclaim/retry
AREA: work_item_action endpoints + actionContext + control-plane UI actions
WORKTREE: /private/tmp/shipit-feat-operator-actions
BRANCH: feat/operator-actions
BASE_SHA: HEAD
OWNED_PATHS: [apps/server/lib/src/endpoints/**, apps/server/lib/src/services/**, apps/control_plane/lib/features/**, apps/control_plane/test/**]
READ_ONLY_PATHS: [packages/workflow_engine/**, packages/workflow_store/**, packages/control_plane_client/lib/src/generated/**]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/**]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root, dart pub get first), dart analyze (apps/server + apps/control_plane + touched packages), dart run tool/run_unit_tests.dart (apps/server), flutter test (apps/control_plane)]
ROUTING_CLASS: PRECISION
```

## Confirmed gap (live)

`actionContext` returns `actions: []` for BOTH states:
- `qa_passed` — the deploy advance (`qa_passed -> deploying` — orchestrator-guarded +
  `artifactBuilt()`) is orchestrator-level, no endpoint -> no UI action.
- `agent_executing` (stranded — no live execution) — `retryFailedWorkItem` is notApplicable
  (only agent_failed); the stranded item can't be retried -> no UI action.

The operator should be able to handle both from the UI, not via a lane.

## Task

1. Server — operator action(s):
   - `advanceToDeploy(workItemId)` for `qa_passed` items: fires `qa_passed -> deploying`
     (orchestrator-actor, artifactBuilt() gate) — or raises the `deploymentApproval` decision
     honestly if that's the real first step (verify the flow — the `deploying ->
     waiting_for_human_decision` edge raises `deploymentApproval`; which transition the
     action should fire).
   - A stranded `agent_executing` repair: detect "agent_executing with no live
     agent_execution" and allow the operator to reclaim/force `agent_executing ->
     agent_failed` so it becomes retriable — or whatever the honest reclaim is (verify the
     F-235 reclaim path handles this or that a new operator action is needed).
   - Expose both via `actionContext` so the UI can render them.
2. Client — surface the actions: the needs-you/action buttons for `qa_passed` (deploy) and
   `agent_executing` (reclaim) — following the existing actionContext-driven action pattern.
3. Regression tests: `actionContext` returns the deploy action for qa_passed + the reclaim
   for a stranded agent_executing; the actions fire the right transition/decision.
4. Report ROOT CAUSE of why these states had no action + the actions added.

## Rules
New commits; no push; no docker/DB writes (read-only OK); nothing outside OWNED_PATHS —
IMPLEMENTATION_BLOCKED if the deploy advance genuinely needs engine composition outside
owned paths. Report per subtask-report.md: `RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`,
HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`, `ACTIONS ADDED:`.
