# Dispatch — integrate-auto-model-escalation

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-auto-model-escalation
TASK_TYPE: integrate
FEATURE: Automatic paid-model escalation on provider failure
WORKTREE: /private/tmp/shipit-auto-escalation + canonical /Users/alkebut/air/shipit-platform
BRANCH: feat/auto-model-escalation
BASE_SHA: 7ca2b49
APPROVED_HEAD: cbd85bae4d20a057103068db25f6e5729d1b6895
REVIEW_VERDICT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP (3 LOW: undeclared scope on
  declared_owned_paths persistence; broad stderr substrings; cosmetic subtype mislabel)
CURRENT_MAIN: HEAD
ROUTING_CLASS: STANDARD
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. Verify: approved HEAD unchanged;
rehearsal clean, reviewed blobs identical (16 files across agent_runtime/worker_runtime/scheduler/
workflow_engine — incl. the reviewer's noted undeclared-scope postgres_design_governance_store +
store_contract_tests, which are legitimate); gates on merged tree: `dart format
--set-exit-if-changed .` (root), `dart analyze` + `dart test` (each touched package:
agent_runtime, worker_runtime, scheduler, workflow_engine); state make test-integration
run/deferred (scheduler/engine/runtime mechanism — probably needed; reasoning). No docker
beyond make test-integration; no DB. Report per subtask-report.md ending exactly
`RESULT: MERGE_APPROVED` or `RESULT: INTEGRATION_BLOCKED`.
