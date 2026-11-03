# Dispatch — integrate-missing-success-artifact

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-missing-success-artifact
TASK_TYPE: integrate
FEATURE: missing_success_artifact — denied-ask summary + getResult fallback + denial-aware reason
WORKTREE: /private/tmp/shipit-fix-artifact + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/missing-success-artifact
BASE_SHA: 65c8a38
APPROVED_HEAD: 94208c55bdb06458f39ba8ac56cc7a58d6ba1253
REVIEW_VERDICT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP (mechanisms verified; check stays permanent)
CURRENT_MAIN: HEAD
ROUTING_CLASS: STANDARD
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. 8 files all under
`packages/agent_runtime` + `packages/execution_coordinator`. Verify: approved HEAD unchanged;
rehearsal clean, reviewed blobs identical; gates on merged tree: `dart format
--set-exit-if-changed .` (root, dart pub get first), `dart analyze` + `dart test`
(agent_runtime + execution_coordinator); make test-integration needed (execution_coordinator
produces the durable terminal event/verdict — DB-facing; reasoning). No merge, no push, no
docker beyond make test-integration, no DB. Report ending exactly `RESULT: MERGE_APPROVED` or
`RESULT: INTEGRATION_BLOCKED`.
