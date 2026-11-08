# Dispatch — feat-deploy-push-remote (F-258)

```yaml
TASK_ID: feat-deploy-push-remote
TASK_TYPE: implement
FEATURE: deploy landing pushes the merged default branch to the product remote via the verified deploy key — closing the "lands locally only" gap
AREA: apps/server deploy landing + credential SSH materialization reuse
WORKTREE: /private/tmp/shipit-feat-deploy-push
BRANCH: feat/deploy-push-remote
BASE_SHA: HEAD
OWNED_PATHS: [apps/server/lib/src/deploy/**, apps/server/lib/src/credentials/**, apps/server/test/deploy/**, apps/server/test/credentials/**]
READ_ONLY_PATHS: [packages/workflow_engine/**, packages/workflow_store/**, apps/server/lib/src/endpoints/**]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/**]
ROUTING_CLASS: PRECISION
```

F-258 (verified live): `landApprovedDeployment`/`relandDeployedItem` merge the produced
commit into the product's recorded checkout default branch but never push — the commit stays
local. The platform ALREADY has the machinery: `product_credential` row
`cred-shipit-platform-1791635510472520` is `verified` + `hostKeyStatus: confirmed`
(ed25519, private PEM at `/var/lib/shipit/secrets/GIT_REPOSITORY_shipit-platform_SSH`),
and `SshPinnedSnapshotMaterializer` (credentials/repository_snapshot_acquirer.dart ~line
640-780) materializes the identity + known_hosts + ssh-wrapper for remote ops.

Task: after the merge into the resolved default branch succeeds and `deployedCommit` is
stamped, push `<defaultBranch>` to the repository's origin remote via the product's ACTIVE
verified credential — reuse the SSH materialization pattern (scratch dir, 0700/0600 modes,
identity + scan-then-match known_hosts + GIT_SSH wrapper, ambient-env redirection). Honest
refusals: if no active verified credential exists, or the remote is unreachable, or push is
rejected → surface a DeployLandingException-style honest failure (the decision stays
pending / item doesn't claim deployed-without-push; decide whether land-then-failed-push is
deploymentFailed or a distinct state per the existing transition vocabulary — the merge
already landed locally so the state model must be honest about "merged locally, push failed").
Consider whether push should be part of landApprovedDeployment or a separate step — check
existing transitions + how the QA drain/human-decision flow expects it. Idempotent: a
re-land/retry must not double-push or fail on already-pushed (remote already contains the
commit → success, not error). No new deps; reuse the existing ssh-wrapper materialization.

Gates: `dart format --output=none --set-exit-if-changed .` (root, dart pub get first),
`dart analyze` (apps/server), `dart run tool/run_unit_tests.dart` (apps/server). New tests:
push succeeds via mock/git-local-remote; honest refusal when no verified credential;
idempotent re-push. New commits; no push; no docker/DB. Report `RESULT: IMPLEMENTED`/
`BLOCKED`, HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`.
