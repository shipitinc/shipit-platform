# Dispatch — feat-real-deploy-exec (F-257)

```yaml
MANAGER: orchestrator-main
TASK_ID: feat-real-deploy-exec
TASK_TYPE: implement
FEATURE: make `deployed` real — a deploy execution merges the work item's produced commit into the product repo's target branch on deployment_approval, instead of the label-only synchronous transition
AREA: deploy execution / scheduler — new deploy job or execution path between approval and deployed
WORKTREE: /private/tmp/shipit-feat-real-deploy
BRANCH: feat/real-deploy-exec
BASE_SHA: HEAD
OWNED_PATHS: [apps/server/lib/src/**, apps/server/lib/src/generated/**, apps/server/test/**, packages/control_plane_client/lib/src/**, packages/scheduler/lib/src/**]
READ_ONLY_PATHS: [packages/workflow_engine/**, packages/workflow_store/**, packages/execution_coordinator/**]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/**]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root, dart pub get first), dart analyze (apps/server + touched), dart run tool/run_unit_tests.dart (apps/server)]
ROUTING_CLASS: PRECISION
```

## Confirmed gap (live, verified)

`deployed` is a label: no deploy/merge/release job type exists (only
triage_defect/implement_feature/engineering_review/design_revision/onboard_product).
On `deployment_approval` → approve, `waiting_for_human_decision → deployed` fires
synchronously — the implementer's commit stays in its worktree branch, never merged,
never landed. `artifactBuilt()` only verifies a DeploymentArtifact exists in transition
context, not that code went anywhere.

## Verified facts to reuse

- Producer commit resolution: `producedCommitFor` (packages/scheduler) → produced commit
  else `workspace.startingRevision` fallback; workspace/worktree info in
  `agent_execution.workspaceJson`.
- Decision→transition flow: resolveDecision fires `waiting_for_human_decision → deployed`
  (guards: blockingHumanDecisionResolved approve + decisionActorIsHuman). The real deploy
  must land the merge BEFORE `deployed` — design options: deploy execution on approval that
  merges then transitions to `deployed` / `deploymentFailed`, or a job that picks up approved
  items. `deploying → deploymentFailed` and `deploymentFailed → deploying` (retry) edges exist.
- Products are onboarded with repo checkouts (`onboard_product`, `triage_repo_qa` volume,
  deploy keys per ADR 0018). For shipit itself, landing = merge into canonical main; whether
  the deploy execution may also trigger rebuild is a Manager/Human call — flag it, don't
  silently rebuild the running platform.
- `runDeployGateSweep`/`deploy_advance.dart` own the deploying→wait step — extend, don't fork.

## Task

1. A deploy execution that runs on `deployment_approval` approve (BEFORE `deployed`):
   resolves the producer's commit/worktree, merges it into the product's target branch
   (the product's recorded repo checkout), verifies the merge, then fires the item to
   `deployed`. On merge failure → `deploymentFailed` (or honest refusal — not silent).
2. Reconcile with the current synchronous resolve→deployed: the approval must no longer
   jump straight to `deployed` — either the resolution path dispatches the deploy execution
   and the transition fires on its success, or an approve parks the item for a deploy sweep
   that lands then transitions. Pick the honest design and state it.
3. Idempotent + crash-safe (a partially-landed deploy finishes honestly; replay doesn't
   re-merge); per-item containment.
4. Regression tests: approve → merge happens (commit lands in target repo) → `deployed`;
   merge conflict/failure → `deploymentFailed` or deferred, never falsely `deployed`;
   no-commit item defers.
5. Report: how deploy now lands, what remains human-only (e.g. rebuild of shipit itself),
   and `DEPLOY_LANDS:`.

## Rules
New commits; no push; no docker/DB writes (read-only OK — a scratch git repo under the
worktree for merge tests is fine); generated output only via `serverpod generate`; nothing
outside OWNED_PATHS — IMPLEMENTATION_BLOCKED if it needs engine composition outside owned
paths. Report per subtask-report.md: `RESULT: IMPLEMENTED`/`IMPLEMENTATION_BLOCKED`,
HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`, `DEPLOY_LANDS:`.
