# Dispatch — integrate-zombie-exec-orphan

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-zombie-exec-orphan
TASK_TYPE: integrate
FEATURE: F-235 — zombie reclaim retires agent_execution + wired at 5 Scheduler sites
WORKTREE: /private/tmp/shipit-fix-zombie-exec + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/zombie-exec-orphan
BASE_SHA: da62a2d
APPROVED_HEAD: b2fe008fa30ac07351aad180047b917d3f2b3dc9
REVIEW_VERDICT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP (residual adopt-path hole filed; env flake)
CURRENT_MAIN: HEAD
ROUTING_CLASS: STANDARD
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. Two commits
(74a7d2e reclaim + b2fe008 wiring). Verify: approved HEAD unchanged; rehearsal clean,
reviewed blobs identical (10 files: scheduler.dart, local_worker.dart, worker_runtime.dart,
agent_execution_retirement.dart new, composition_wiring_test.dart new, + test files);
gates on merged tree: `dart format --set-exit-if-changed .` (root), `dart analyze` + `dart test`
(scheduler, worker_runtime — the worker_lease_bound flake is pre-existing environmental,
confirmed on base; isolate-rerun if it fires), `dart run tool/run_unit_tests.dart` (apps/server);
make test-integration needed (scheduler reclaim path is DB-facing — state reasoning). No merge,
no push, no docker beyond make test-integration, no DB. Report ending exactly
`RESULT: MERGE_APPROVED` or `RESULT: INTEGRATION_BLOCKED`.
