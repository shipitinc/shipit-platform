# Dispatch — integrate-f237-integration-settle

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-f237-integration-settle
TASK_TYPE: integrate
FEATURE: F-237 integration-suite settle migration (corrected)
WORKTREE: /private/tmp/shipit-f237-integration-settle + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/f237-integration-settle
BASE_SHA: 6fcb630
APPROVED_HEAD: cb5f76f9fc9728afcc9f8123d9dc85b6d210c42b
REVIEW_VERDICT: APPROVE_CORRECTIONS (focused-reviewer 574a082e, READY_FOR_MERGE)
CURRENT_MAIN: 0b53f6d
ROUTING_CLASS: STANDARD
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. Verify: approved HEAD unchanged
(5 commits on 6fcb630); merge rehearsal into current main clean, reviewed blobs identical (test-only
diff under apps/server/test/**); gates on merged tree: `dart format --set-exit-if-changed .` (root),
`dart analyze` + `dart run tool/run_unit_tests.dart` (apps/server), `dart test` packages/scheduler;
`make test-integration` — the reviewer already re-ran it green (+319) at cb5f76f on the branch;
state whether you re-run on the merged tree or accept that evidence. No docker beyond
make test-integration; no DB writes. Report per subtask-report.md ending exactly
`RESULT: MERGE_APPROVED` or `RESULT: INTEGRATION_BLOCKED`.
