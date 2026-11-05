# Dispatch — feat-qa-passed-auto-deploy (F-256)

```yaml
MANAGER: orchestrator-main
TASK_ID: feat-qa-passed-auto-deploy
TASK_TYPE: implement
FEATURE: qa_passed items auto-advance to deploying + raise deploymentApproval -> land in Needs You
AREA: qa_drain / scheduler — fire qaPassed->deploying + requestHumanDecision(deploymentApproval) on qa_passed
WORKTREE: /private/tmp/shipit-feat-qa-deploy
BRANCH: feat/qa-passed-auto-deploy
BASE_SHA: HEAD
OWNED_PATHS: [apps/server/lib/src/**, apps/server/lib/src/generated/**, apps/server/test/**, packages/control_plane_client/lib/src/**, packages/scheduler/lib/src/**]
READ_ONLY_PATHS: [packages/workflow_engine/**, packages/workflow_store/**, packages/execution_coordinator/**]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/**]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root, dart pub get first), dart analyze (apps/server + touched), dart run tool/run_unit_tests.dart (apps/server)]
ROUTING_CLASS: PRECISION
```

## Confirmed gap (live)

`qa_passed` items don't surface in Needs You — `pendingDecisions` only lists
`blockingHumanDecisionId != null`. A `qa_passed` item has no pending decision; the deploy
advance (`qa_passed->deploying` + `deploymentApproval`) only fires via the new `advanceToDeploy`
operator action — so items park invisibly at `qa_passed` until a human opens run detail.

## Prior lane's verified plan (reuse, don't re-derive)

`advanceToDeploy` already implements the honest deploy sequence:
1. `transition(qaPassed->deploying, actor=orchestrator, context={deploymentArtifact built from
   producer AgentResult via producedCommitFor, workspace.startingRevision fallback})`
2. `requestHumanDecision(deploymentApproval)` -> `deploying -> waiting_for_human_decision`
   -> lands in Needs You.
`artifactBuilt()` reads `context['deploymentArtifact']` as DeploymentArtifact; completed
producer result required else notApplicable. `OperatorActionRecord.action` rides as 'deploy'.

## Task

Auto-fire the deploy advance for `qa_passed` items — so the `deploymentApproval` decision is
raised and the item parks at `waiting_for_human_decision` (Needs You) WITHOUT a human having
to click run detail:
1. Find where `qa_passed` lands in the scheduler/qa_drain sweep — add a step that, for each
   `qa_passed` item, fires `qaPassed->deploying` (artifact from the producer AgentResult per
   `advanceToDeploy`'s verified construction — reuse/refactor the shared logic) then
   `requestHumanDecision(deploymentApproval)` so it parks at the human gate.
2. Idempotent + crash-safe per the two-durable-step rule (a partially-advanced `deploying`
   item finishes the raise, not re-transitions); unbounded sweep budget (the drain pattern).
3. Items without a completed producer result stay `qa_passed` honestly (can't build the
   artifact -> can't advance) — not failed, just not auto-advanced.
4. Regression tests: a `qa_passed` item auto-advances to `waiting_for_human_decision` with a
   `deploymentApproval` decision pending; idempotent on re-tick; an item without a producer
   result stays `qa_passed`; Needs You (pendingDecisions) then surfaces it.
5. Report ROOT CAUSE of the invisibility + what now auto-advances.

## Rules
New commits; no push; no docker/DB writes (read-only OK); generated output only via
`serverpod generate`; nothing outside OWNED_PATHS — IMPLEMENTATION_BLOCKED if it needs engine
composition outside owned paths. Report per subtask-report.md: `RESULT: IMPLEMENTED` /
`IMPLEMENTATION_BLOCKED`, HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`, `AUTO-ADVANCE:`.
