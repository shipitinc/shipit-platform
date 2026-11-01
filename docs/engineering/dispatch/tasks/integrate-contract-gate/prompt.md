# Dispatch — integrate-contract-gate (F-242)

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-contract-gate
TASK_TYPE: integrate
FEATURE: F-242 contractless items defer (no guaranteed-fail agentCompleted)
WORKTREE: /private/tmp/shipit-fix-contract-gate + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/contract-gate
BASE_SHA: abcbbd4
APPROVED_HEAD: 375e94c695374af2bd84ab94f1cde7035f6cf114
REVIEW_VERDICT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP (1 MEDIUM composition text-pin gap, non-blocking)
CURRENT_MAIN: a9ee72e (includes F-241 merge)
ROUTING_CLASS: STANDARD
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. Verify: approved HEAD unchanged;
rehearsal clean, reviewed blobs identical (6 files: implementation_readiness_probe.dart,
qa_contract_dispatch_gate.dart new, server.dart, 3 test files); gates on merged tree:
`dart format --set-exit-if-changed .` (root), `dart analyze` + `dart run tool/run_unit_tests.dart`
(apps/server); state make test-integration run/deferred (server-side workload wiring — probably
needed; reasoning). No docker beyond make test-integration; no DB. Report per subtask-report.md
ending exactly `RESULT: MERGE_APPROVED` or `RESULT: INTEGRATION_BLOCKED`.
