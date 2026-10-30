# Dispatch — integrate-worker-lease

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-worker-lease
TASK_TYPE: integrate
FEATURE: F-226 worker-lease starvation recovery (corrected HEAD)
WORKTREE: /private/tmp/shipit-fix-worker-lease-starvation + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/worker-lease-starvation
BASE_SHA: fb8dde3
APPROVED_HEAD: 1ec22f09a60d45f262c94a1ef00609d5e8dc9f84
REVIEW_CHAIN: DO_NOT_MERGE (c92e4e33) → CORRECTION_COMPLETE 98bdca85 → DO_NOT_APPROVE_CORRECTIONS
  (0405ad3d) → CORRECTION_COMPLETE 1ec22f0 → APPROVE_CORRECTIONS (389bc128, READY_FOR_MERGE: YES)
CURRENT_MAIN: 79008e1 (includes merge eeb9c97 of the dedupe fix)
ROUTING_CLASS: STANDARD
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push.

Verify: approved HEAD unchanged; merge rehearsal into current main is clean with the reviewed
blobs identical (chain is fb8dde3 → 2b24f4e → 98bdca85 → 1ec22f0, only 2 files under
packages/worker_runtime/**); main's advance since fb8dde3 (dedupe merge eeb9c97 + ledger docs)
doesn't conflict or invalidate; gates on merged tree: `dart format --output=none --set-exit-if-changed .`
(root), `dart analyze` + `dart test` packages/worker_runtime. Report whether `make test-integration`
was run or deferred (merge-tier gate owed by this change AND the already-merged dedupe change).
No docker, no DB. Report per subtask-report.md ending exactly `RESULT: MERGE_APPROVED` or
`RESULT: INTEGRATION_BLOCKED`.
