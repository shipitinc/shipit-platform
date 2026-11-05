# Dispatch — feat-operator-actions (F-254, re-dispatch with corrected ownership)

```yaml
MANAGER: orchestrator-main
TASK_ID: feat-operator-actions
TASK_TYPE: implement
FEATURE: expose operator actions for states the UI currently shows none — qa_passed -> advance to deploy, stranded agent_executing -> reclaim/retry
AREA: work_item_action endpoints + actionContext + generated serverpod connectors + control-plane UI actions
WORKTREE: /private/tmp/shipit-feat-operator-actions
BRANCH: feat/operator-actions
BASE_SHA: 6a4d307
OWNED_PATHS: [apps/server/lib/src/endpoints/**, apps/server/lib/src/services/**, apps/server/lib/src/generated/**, apps/server/test/**, packages/control_plane_client/lib/src/**, apps/control_plane/lib/**, apps/control_plane/test/**]
READ_ONLY_PATHS: [packages/workflow_engine/**, packages/workflow_store/**]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/**]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root, dart pub get first), dart analyze (apps/server + apps/control_plane + touched packages), dart run tool/run_unit_tests.dart (apps/server), flutter test (apps/control_plane)]
ROUTING_CLASS: PRECISION
```

## Re-dispatch context — the prior lane's verified findings (reuse, don't re-derive)

The prior lane blocked on ownership and verified the implementation plan end-to-end:
- `qa_passed -> deploying` (`work_item_transitions.dart:852`, orchestrator + artifactBuilt) has
  NO caller — that's why actionContext is empty. The honest deploy sequence: `qaPassed ->
  deploying` (orchestrator + artifactBuilt), THEN `requestHumanDecision(deploymentApproval)` ->
  `deploying -> waiting_for_human_decision`. `deploymentApproval` can't be raised from
  qaPassed directly.
- `artifactBuilt()` reads `context['deploymentArtifact']` as DeploymentArtifact — derivable
  from the producer's AgentResult (ArtifactFile is the same shape).
- The stranded `agent_executing` case needs a NEW operator action — the F-235 `_reclaimZombie`
  only fires on held-job/stale-execution reconciliation, not a jobless stranded item.
- `OperatorActionRecord.action` is a free-form string — new audit tokens ('deploy','reclaim')
  don't need OperatorActionKind changes.
- Both actions can return the existing `WorkItemActionResult` (no new wire models needed).

## Ownership correction

This re-dispatch grants ownership of the generated surface — `serverpod generate` output in
`apps/server/lib/src/generated/**` and `packages/control_plane_client/lib/src/protocol/**` is a
PERMITTED artifact of this lane (mechanically produced by the sanctioned schema/endpoint
change). You may run `serverpod generate` to produce the connectors. `apps/control_plane/lib/**`
(including `lib/data/control_plane_repository.dart` — the sole client->server path) is owned.

## Task (per the prior lane's verified plan)

1. Server: `advanceToDeploy` — transition(qaPassed->deploying, actor=orchestrator,
   context={deploymentArtifact built from the producer's AgentResult}), then
   requestHumanDecision(deploymentApproval) so the item parks at the human gate.
   `reclaimStrandedExecution` — detect agent_executing + no non-terminal AgentExecution + no
   active job -> transition(agent_executing->agent_failed) audited as a new 'reclaim' operator
   action (retriable via the existing retry path). Expose both via `actionContext.actions` as
   new WorkItemActionView tokens.
2. `serverpod generate` for the new endpoints + client protocol.
3. Client: `control_plane_repository.dart` calls + surface the actions (needs-you/action
   buttons for qa_passed-deploy + agent_executing-reclaim).
4. Regression tests: actionContext returns the deploy action for qa_passed + the reclaim for
   a stranded agent_executing; the actions fire the right transition/decision.

## Rules
New commits; no push; no docker/DB writes (read-only OK); generated output only via `serverpod
generate`; nothing outside OWNED_PATHS. Report per subtask-report.md:
`RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`, HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`,
`ACTIONS ADDED:`.
