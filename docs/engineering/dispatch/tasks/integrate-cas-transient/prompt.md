# Dispatch — integrate-cas-transient (F-241)

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-cas-transient
TASK_TYPE: integrate
FEATURE: F-241 CAS loss → TRANSIENT
WORKTREE: /private/tmp/shipit-fix-cas + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/cas-transient
BASE_SHA: abcbbd4
APPROVED_HEAD: f3b46432daa2a9e90e4a1cffa76cc3f9267dfd73
REVIEW_VERDICT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP (1 MEDIUM latent product_registry CAS coverage
  filed F-243; LOW: pubspec newline, doc comment)
CURRENT_MAIN: c7f9550
ROUTING_CLASS: STANDARD
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. Verify: approved HEAD unchanged;
rehearsal clean, reviewed blobs identical (worker_runtime + scheduler files); gates on merged tree:
`dart format --set-exit-if-changed .` (root), `dart analyze` + `dart test` (packages/scheduler AND
packages/worker_runtime); state make test-integration run/deferred (scheduler/worker runtime —
probably needed; state reasoning). No docker beyond make test-integration; no DB. Report per
subtask-report.md ending exactly `RESULT: MERGE_APPROVED` or `RESULT: INTEGRATION_BLOCKED`.
