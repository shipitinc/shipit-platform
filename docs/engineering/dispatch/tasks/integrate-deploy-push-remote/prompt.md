# Dispatch — integrate-deploy-push-remote

```yaml
TASK_ID: integrate-deploy-push-remote
TASK_TYPE: integrate
FEATURE: verify merge-readiness of feat/deploy-push-remote (HEAD c9fc77e)
WORKTREE: /private/tmp/shipit-feat-deploy-push
BRANCH: feat/deploy-push-remote
BASE_SHA: d027477
HEAD_SHA_UNDER_REVIEW: c9fc77e7453de00d1a7220823cc0a14531c58a00
REVIEW_PROVENANCE: APPROVE_WITH_NON_BLOCKING_FOLLOWUP on c9fc77e (gates all green)
ROUTING_CLASS: PRECISION
```

Verify the approved change merges cleanly into current canonical `main` (advanced since
`d027477` — ledger commits only): `git fetch`/`merge-base`/dry-run merge of `c9fc77e` into
`/Users/alkebut/air/shipit-platform` `main`; verify no conflict (main-side delta is
docs-only since base); verify provenance; re-run gates on the merged tree if the base
diverged — `dart format`, `dart analyze` (apps/server), `dart run tool/run_unit_tests.dart`
(apps/server). Report `RESULT: MERGE_APPROVED` / `BLOCKED`.
