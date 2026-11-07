# Dispatch — feat-reland-stranded-deployed (F-259)

```yaml
MANAGER: orchestrator-main
TASK_ID: feat-reland-stranded-deployed
TASK_TYPE: implement
FEATURE: re-land path — land the produced commit for items already `deployed` label-only (no deployedCommit stamp) so their fixes actually merge
AREA: deploy_landing / operator action or sweep — land for already-deployed items missing the stamp
WORKTREE: /private/tmp/shipit-feat-reland
BRANCH: feat/reland-stranded-deployed
BASE_SHA: HEAD
OWNED_PATHS: [apps/server/lib/src/**, apps/server/lib/src/generated/**, apps/server/test/**, packages/control_plane_client/lib/src/**]
READ_ONLY_PATHS: [packages/workflow_engine/**, packages/workflow_store/**, packages/execution_coordinator/**, packages/scheduler/**]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/**]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root, dart pub get first), dart analyze (apps/server + touched), dart run tool/run_unit_tests.dart (apps/server)]
ROUTING_CLASS: PRECISION
```

## Confirmed gap (live, verified)

13 items are `deployed` label-only: their `deployment_approval` resolved under the pre-deploy
artifact before `deploy_landing` existed — `deployedCommit`/`deployedBy` NULL, no commit landed
in any repositoryPath. The land arm only fires on approve of a PENDING deployment_approval —
`deployed` items have no re-land path. `deployed → deploymentFailed` and `deployed → deploying`
edges don't exist (workflow_engine is read-only anyway).

## Prior lane's verified facts (reuse)

- `landApprovedDeployment`/`maybeLandApprovedDeployment` (deploy_landing.dart) do the land:
  resolveProducerExecution -> producedCommitFor/workspace.startingRevision fallback ->
  merge --no-ff into WorkerExecution.repositoryPath current branch -> merge-base --is-ancestor
  verify -> stamp deployedCommit/deployedInto/deployedAt/deployedCommitBasis/deployedBy.
- The merge is verify-not-remerge (already-ancestor -> no-op) — so re-landing an already-landed
  item is honest, not a no-op-by-luck.
- deployed* metadata stamp is CAS on the item version.

## Task

A re-land path for items `deployed` WITHOUT the landed stamp (deployedCommit NULL / not owed):
1. Choose the honest trigger: (a) an operator action on `deployed` items missing the stamp —
   extends actionContext; or (b) a sweep/backfill that re-lands them. The user's intent is to
   land the stranded 13 + make re-land idempotent for future label-deploys. Pick the design —
   a `re-land` operator action (reuses the operator-actions surface) is likely honest; a sweep
   risks landing commits for items never meant to ship. State it.
2. Reuse `landApprovedDeployment`'s mechanism — the land itself is identical; only the trigger
   + the "owed" detection differ (a `deployed` item is owed the land iff deployedCommit is
   absent — verify that's the right predicate, e.g. deployedBy/deployedInto too).
3. Idempotent + crash-safe (verify-not-remerge; a partially-landed re-land finishes honestly);
   a no-producer/no-commit item refusals honestly (notApplicable, doesn't fabricate).
4. Regression tests: a `deployed` item without the stamp re-lands (commit merges + stamped);
   one with the stamp is a no-op/replayed; a no-commit one refuses honestly.
5. Report `RE-LAND:` design + how the 13 stranded items get landed.

## Rules
New commits; no push; no docker/DB writes (a scratch git repo under the worktree for merge
tests is fine); generated only via `serverpod generate`; nothing outside OWNED_PATHS —
IMPLEMENTATION_BLOCKED if it needs engine composition outside owned paths. Report per
subtask-report.md: `RESULT: IMPLEMENTED`/`IMPLEMENTATION_BLOCKED`, HEAD_SHA,
`READY_FOR_INDEPENDENT_REVIEW:`, `RE-LAND:`.
