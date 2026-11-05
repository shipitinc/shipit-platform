# Dispatch — integrate-qa-passed-auto-deploy

```yaml
TASK_ID: integrate-qa-passed-auto-deploy
TASK_TYPE: integrate
FEATURE: verify merge-readiness of feat/qa-passed-auto-deploy (HEAD 7df90d7)
WORKTREE: /private/tmp/shipit-feat-qa-deploy
BRANCH: feat/qa-passed-auto-deploy
BASE_SHA: 4eb53c4
HEAD_SHA_UNDER_REVIEW: 7df90d7ffcd99b785dbe356b2e193a93f2a09bbd
REVIEW_PROVENANCE: APPROVE_FOR_MERGE on 7df90d7 (engineering-reviewer, gates all green)
ROUTING_CLASS: PRECISION
```

Verify the approved change merges cleanly into current canonical `main` (which has advanced —
multiple merges since `4eb53c4`): `git fetch`/`merge-base`/dry-run merge of `7df90d7` into
`/Users/alkebut/air/shipit-platform` `main`; verify no conflict; re-run the required gates on the
merged tree if the base diverged; verify provenance (the reviewed HEAD is what's being merged,
not a later commit). Report `RESULT: MERGE_APPROVED` / `BLOCKED`.
