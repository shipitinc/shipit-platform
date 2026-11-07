# Dispatch — integrate-real-deploy-exec

```yaml
TASK_ID: integrate-real-deploy-exec
TASK_TYPE: integrate
FEATURE: verify merge-readiness of feat/real-deploy-exec (HEAD 7e83f4e)
WORKTREE: /private/tmp/shipit-feat-real-deploy
BRANCH: feat/real-deploy-exec
BASE_SHA: 3fd55e0
HEAD_SHA_UNDER_REVIEW: 7e83f4e51d228959209eba5e3e42f56418c8241e
REVIEW_PROVENANCE: APPROVE_WITH_NON_BLOCKING_FOLLOWUP on 7e83f4e (gates all green)
ROUTING_CLASS: PRECISION
```

Verify the approved change merges cleanly into current canonical `main` (advanced since
`3fd55e0` — deploy sweep + ledger merges): `git fetch`/`merge-base`/dry-run merge of `7e83f4e`
into `/Users/alkebut/air/shipit-platform` `main`; verify no conflict (main advanced in
`apps/server/lib/src/deploy/**` via the auto-deploy sweep — the real-deploy adds
`deploy_landing.dart` + a `control_plane_service.dart` hunk; check semantic overlap with
`deploy_gate_sweep.dart`/`deploy_advance.dart`); verify provenance (the reviewed HEAD is what's
merged); re-run gates on the merged tree if the base diverged. Report `RESULT: MERGE_APPROVED` /
`BLOCKED`.
