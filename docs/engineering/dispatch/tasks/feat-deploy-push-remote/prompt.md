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

## Resumption note (lane died after design phase — worktree clean at base)

The first lane completed the design investigation then exited without writing code.
Its verified design (reuse it — do not re-investigate):

- Push is part of `landApprovedDeployment` (both the merge arm and the already-landed
  arm) — `relandDeployedItem` gets it for free; a retried approve/reland completes an
  interrupted push. Push failure throws `DeployLandingException` → nothing durable
  written → decision stays pending (NOT deploymentFailed — the approve is not consumed
  by a platform failure; the merge stays local and honestly reported).
- Wiring constraint: the only callers (`control_plane_service.dart`,
  `work_item_action_endpoints.dart`) were outside that lane's ownership, so dependencies
  arrive via optional params + a production default resolving `ProductRegistryEngine`
  over `Serverpod.instance.internalSession` + `resolveSecretProvider()`, plus a
  `deployPushEnvironmentOverride` hook for endpoint-driven tests. (This lane's OWNED_PATHS
  additionally includes `apps/server/lib/src/endpoints/**` and
  `apps/server/lib/src/services/**` so the callers can be wired directly instead —
  prefer real wiring over the optional-params workaround if it's cleaner.)
- Credential resolution: `git remote get-url origin` → normalized `SshRemote` match
  against the product's registered repositories → `readActiveCredential` → same
  provenance checks the workspace provisioner runs → one secret read by name, wiped in
  `finally`.
- Transport: `SshDeployPushTransport` reuses the scan-then-match + wrapper
  materialization; `pushBranchToRemote` does fetch→ancestry→push→re-fetch→verify
  (idempotent: already-contained → `alreadyCurrent`; non-ff + concurrent pusher →
  recheck before refusing).
- Tests at TOP-LEVEL `test/deploy_push_test.dart` — the runner (`run_unit_tests.dart`)
  is non-recursive by construction; `test/deploy/` subdirs would never execute.

OWNED_PATHS amended to: [apps/server/lib/src/deploy/**, apps/server/lib/src/credentials/**,
apps/server/lib/src/endpoints/work_item_action_endpoints.dart,
apps/server/lib/src/services/control_plane_service.dart,
apps/server/test/*.dart]
