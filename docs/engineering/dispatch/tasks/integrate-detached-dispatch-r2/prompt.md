# Dispatch — integrate-detached-dispatch-r2

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-detached-dispatch-r2
TASK_TYPE: integrate
FEATURE: F-237 detached dispatch (corrected head)
WORKTREE: /private/tmp/shipit-fix-detached-dispatch + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/detached-dispatch
BASE_SHA: 94d8677
APPROVED_HEAD: 00ff16fed79717462c7cba611b732baec5b2fc95
REVIEW_CHAIN: APPROVE_WITH_NON_BLOCKING_FOLLOWUP (e5b739ea) → INTEGRATION_BLOCKED (4 server
  tests) → CORRECTION_COMPLETE 00ff16f → APPROVE_CORRECTIONS (957cd652, READY_FOR_MERGE)
CURRENT_MAIN: cfc2a71
ROUTING_CLASS: PRECISION
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. Verify: approved HEAD unchanged
(chain 94d8677→839277d→c02572c→00ff16f); merge rehearsal into current main clean, reviewed blobs
identical; the previously-failing gate `dart run tool/run_unit_tests.dart` (apps/server, all 69)
now passes ON THE MERGED TREE (the four migrated files + unaffected ones); full gate set: format
root, analyze+test packages/scheduler AND packages/worker_runtime, analyze + run_unit_tests
apps/server; state `make test-integration` run or deferred. No docker, no DB. Report per
subtask-report.md ending exactly `RESULT: MERGE_APPROVED` or `RESULT: INTEGRATION_BLOCKED`.
