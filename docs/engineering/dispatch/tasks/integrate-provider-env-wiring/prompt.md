# Dispatch — integrate-provider-env-wiring

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-provider-env-wiring
TASK_TYPE: integrate
FEATURE: OPENROUTER_API_KEY wired into QA compose env + prod docs
WORKTREE: /private/tmp/shipit-provider-env + canonical /Users/alkebut/air/shipit-platform
BRANCH: feat/provider-env-wiring
BASE_SHA: 7ca2b49
APPROVED_HEAD: 4f477bf90fef00a78b09c30e7911c34224fd0631
REVIEW_VERDICT: APPROVE_FOR_MERGE (3 LOW non-blocking)
CURRENT_MAIN: HEAD
ROUTING_CLASS: STANDARD
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. Config-only change
(compose env + docs + gitignore). Verify: approved HEAD unchanged; rehearsal clean,
reviewed blobs identical (6 files: compose.qa.yaml, docker/.env.example new, .env.example,
production.yaml, README.md, .gitignore); gates on merged tree: `dart format
--set-exit-if-changed .` (root), `docker compose -f docker/compose.qa.yaml config`
renders both vars (may need a scratch .env for the mandatory ../.env); make test-integration
NOT needed (no code, no server runtime change — state reasoning). Scan the merge for any
secret-shaped string — the change must carry zero key material. No docker beyond compose
config; no DB. Report per subtask-report.md ending exactly `RESULT: MERGE_APPROVED` or
`RESULT: INTEGRATION_BLOCKED`.
