# Dispatch — integrate-dedupe-self-heal (re-dispatched after session loss)

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-dedupe-self-heal
TASK_TYPE: integrate
FEATURE: F-227 activeDedupeKey self-heal on terminal job rows
WORKTREE: /private/tmp/shipit-fix-dedupe-self-heal + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/dedupe-key-self-heal
BASE_SHA: fb8dde3
APPROVED_HEAD: 0d43d8f3cd0c81e7dcf8ced3d45317af3da3c4b8
REVIEW_VERDICT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP (engineering-reviewer 82559348 — 3 LOW, none gating)
CURRENT_MAIN: 61a2eb5
ROUTING_CLASS: STANDARD
```

Prior integrator died before reporting; fresh dispatch. You do NOT merge or push — stop at
MERGE_APPROVED / INTEGRATION_BLOCKED.

Verify:
1. Approved HEAD unchanged (no further commits / uncommitted drift in lane worktree).
2. Merge rehearsal into `main` (61a2eb5): clean, no conflicts, reviewed blobs identical in merged tree.
3. `git diff fb8dde3..61a2eb5` is docs-only — no invalidating advance.
4. Merge-tier gates on merged tree: `dart format --output=none --set-exit-if-changed .`, `dart analyze`
   (apps/server, packages/scheduler), `dart test` packages/scheduler, `dart run tool/run_unit_tests.dart`
   apps/server. Report whether `make test-integration` was run or deferred.
5. Reviewer's 3 LOW follow-ups confirmed non-gating.

No merge, no push, no docker, no DB. Report per subtask-report.md ending exactly
`RESULT: MERGE_APPROVED` or `RESULT: INTEGRATION_BLOCKED`.
