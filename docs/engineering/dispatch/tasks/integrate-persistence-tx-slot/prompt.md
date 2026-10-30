# Dispatch — integrate-persistence-tx-slot

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-persistence-tx-slot
TASK_TYPE: integrate
FEATURE: F-238 PersistenceDatabase zone-scoped tx binding
WORKTREE: /private/tmp/shipit-fix-tx-slot + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/persistence-tx-slot
BASE_SHA: ea7754a
APPROVED_HEAD: e15b0ca36ec4d67e5f5583a9ad9cb219543ce168
REVIEW_VERDICT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP (engineering-reviewer 6bfd3a6f; 3 LOW — 2 stale
  doc comments, 1 verified environmental gate flake)
CURRENT_MAIN: f2111a6
ROUTING_CLASS: PRECISION
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. Verify: approved HEAD unchanged;
merge rehearsal into current main clean, reviewed blobs identical (5 files: persistence_database.dart
+ server.dart comment + 3 test/comment files); main advance since base is docs/merged-test-work only,
path-disjoint; gates on merged tree: `dart format --set-exit-if-changed .` (root), `dart analyze` +
`dart run tool/run_unit_tests.dart` (apps/server — report verbatim; the reviewer's lone flake
budget_exhaustion_retries was verified environmental), `dart test` packages/scheduler AND
packages/worker_runtime; state `make test-integration` run or deferred (it is owed — the F-237
integration settle migration is in main and this change should get the real-DB tier before deploy).
No docker beyond make test-integration; no DB writes. Report per subtask-report.md ending exactly
`RESULT: MERGE_APPROVED` or `RESULT: INTEGRATION_BLOCKED`.
