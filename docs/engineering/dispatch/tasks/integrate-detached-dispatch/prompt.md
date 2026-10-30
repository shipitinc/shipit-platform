# Dispatch — integrate-detached-dispatch (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-detached-dispatch
TASK_TYPE: integrate
FEATURE: F-237 detached dispatch (tick no longer awaits execution completion)
WORKTREE: /private/tmp/shipit-fix-detached-dispatch + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/detached-dispatch
BASE_SHA: 94d8677
APPROVED_HEAD: c02572c29d1f59e34506dc39cd3d8115ce355eca (commits 839277d + c02572c)
REVIEW_VERDICT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP (engineering-reviewer e5b739ea; 4 LOW, none gating)
CURRENT_MAIN: 5f9d55f (contains merges eeb9c97, a661aae, b2148d9)
ROUTING_CLASS: PRECISION
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. Verify: approved HEAD unchanged
(chain 94d8677→839277d→c02572c); merge rehearsal into current main clean, reviewed blobs identical;
main advance since 94d8677 is docs/merged-worker-fixes only, path-disjoint (F-232 touched
worker_runtime/worker, not dispatcher — verify no semantic interaction); gates on merged tree:
`dart format --set-exit-if-changed .` (root), `dart analyze` + `dart test` packages/scheduler AND
packages/worker_runtime, `dart run tool/run_unit_tests.dart` apps/server (regression check on the
server-side consumption of the settle path); state `make test-integration` run or deferred.
No docker, no DB. Report per subtask-report.md ending exactly `RESULT: MERGE_APPROVED` or
`RESULT: INTEGRATION_BLOCKED`.
