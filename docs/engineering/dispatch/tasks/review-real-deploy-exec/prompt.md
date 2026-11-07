# Dispatch — review-real-deploy-exec (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-real-deploy-exec
TASK_TYPE: review
FEATURE: `deployed` lands the produced commit — deploy execution on deployment_approval approve
AREA: deploy_landing + control_plane_service.resolveHumanDecision
WORKTREE: /private/tmp/shipit-feat-real-deploy
BRANCH: feat/real-deploy-exec
BASE_SHA: 3fd55e0
HEAD_SHA_UNDER_REVIEW: 7e83f4e51d228959209eba5e3e42f56418c8241e
ROUTING_CLASS: PRECISION
```

Independent read-only review of `7e83f4e` — new `deploy_landing.dart` +
`resolveHumanDecision` dispatch: on `deployment_approval` → approve, the producer's commit
(`producedCommitFor` / `workspace.startingRevision` fallback) is merged `--no-ff` into the
product's recorded repo checkout (`WorkerExecution.repositoryPath` current branch), verified
via `merge-base --is-ancestor`, stamped on the item, BEFORE `deployed` is written.

Verify rigorously:
1. The land-before-deployed ordering — the merge + verification happens before the engine
   resolves the decision; a failed land throws `DeployLandingException`, writes NOTHING, and
   leaves the decision PENDING (the approve isn't consumed). The approve-park alternative's
   rejection reasoning is sound (waitingForHumanDecision→deploymentFailed admits reject only).
2. The merge is real — resolves the right producer commit (stamped first, implementer-role
   fallback per `resolveProducerExecution`/`requiredRole`), merges into `repositoryPath`'s
   current branch, `--no-ff`, `merge-base --is-ancestor` verify. A merge that can't verify
   doesn't reach `deployed`.
3. Crash-safety — merge before durable write; replay is verify-not-remerge (merge-base
   ancestor); failed merge aborts the checkout clean; the metadata stamp is CAS on version;
   the resolved-approve-parked-at-gate window is still owed the land on replay.
4. Honest scope — lands into the recorded checkout only, NOT push to the remote URI (deploy
   keys needed — separate authority); no rebuild/restart of shipit itself (flagged as
   Manager/Human call). Verify nothing sneaks a push or a stack mutation.
5. Tests — `deploy_landing_test.dart` (12 tests, real scratch git repo) covers land→deployed,
   verify-not-remerge replay, failure→pending-decision, deferral — non-vacuous.
6. Gates re-run: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart
   analyze` (apps/server + touched), `dart run tool/run_unit_tests.dart` (apps/server) — own
   numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:` — and note the flagged residuals (no remote push, no platform
rebuild, deploymentFailed unreachable post-approve without an engine edge).
