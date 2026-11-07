# Dispatch — integrate-reland-stranded

```yaml
TASK_ID: integrate-reland-stranded
TASK_TYPE: integrate
FEATURE: verify merge-readiness of feat/reland-stranded-deployed (HEAD 959bef4)
WORKTREE: /private/tmp/shipit-feat-reland
BRANCH: feat/reland-stranded-deployed
BASE_SHA: 1457603
HEAD_SHA_UNDER_REVIEW: 959bef45faeb328f7effe85145441e52bd5568c0
REVIEW_PROVENANCE: APPROVE_WITH_NON_BLOCKING_FOLLOWUP on 959bef4 (gates all green)
ROUTING_CLASS: PRECISION
```

Verify the approved change merges cleanly into current canonical `main` (advanced since
`1457603` — real-deploy merge + ledger commits): `git fetch`/`merge-base`/dry-run merge of
`959bef4` into `/Users/alkebut/air/shipit-platform` `main`; verify no conflict (the real-deploy
merge added `deploy_landing.dart` + `control_plane_service.dart` — the re-land adds to the same
`deploy_landing.dart` + `work_item_action_endpoints.dart`; check for semantic overlap); verify
provenance (the reviewed HEAD is what's merged); re-run gates on the merged tree if the base
diverged. Report `RESULT: MERGE_APPROVED` / `BLOCKED`.
