# Dispatch — review-impl-detached-dispatch (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-impl-detached-dispatch
TASK_TYPE: review
FEATURE: F-237 detached dispatch — tick no longer awaits execution completion
AREA: scheduler dispatch loop / settle path
WORKTREE: /private/tmp/shipit-fix-detached-dispatch
BRANCH: fix/detached-dispatch
BASE_SHA: 94d8677
HEAD_SHA_UNDER_REVIEW: c02572c29d1f59e34506dc39cd3d8115ce355eca
ROUTING_CLASS: PRECISION
```

Independent read-only review of a PRECISION core-scheduler change. The change: `_dispatchOne`
keeps claim+markRunning then fires `unawaited(_settleDetachedRun)` — the tick no longer awaits the
terminal result. Settle: `WorkerDispatchException` → `revertToQueued`; other error → claim release;
success → `_releaseClaimForReconcile` deletes the claim so the NEXT tick's `_reconcileClaim` →
`_adoptFromExecution` adopts the durable terminal execution (restart-safe: lease expiry backstop).

This is the highest-risk change of the session — it rewrites the settle path every lane depends on.
Verify at `c02572c` (two commits on `94d8677`: `839277d` design + `c02572c` fallout repair):

1. **Settle correctness under failure/crash**: job dispatched → process dies mid-execution →
   claim lease expires → reconcile adopts terminal execution OR the job is reclaimed (which path?
   is a running-but-dead job stranded?); dispatched → execution fails → terminal adopted on next
   tick; `revertToQueued` preserves prior verdict semantics.
2. **Claim-release design**: `_releaseClaimForReconcile` deletes the claim BEFORE adoption — is the
   window between release and the adopting reconcile safe (can anything else claim/dispatch the job
   in between; does `markRunning` state + `isEligibleAt` prevent re-dispatch of a `running` job)?
3. **Restart/crash path**: detached `unawaited` continuation is in-process only — on process death
   after `markRunning`, what settles the job? (Claim lease + reconcile — verify the reconciliation
   actually handles `running` jobs with expired/no claims.)
4. **No semantic regressions**: capacity gating (the C=2 cap now reachable in one tick — verify the
   gate still bounds correctly), dedupe, retry/terminal classification, drain contract
   (`dispatched ∪ terminal ∪ reconciled` — adopt lands in `reconciled`, confirm composition-root
   drain consumes it), ordering.
5. **The ~18 test-file fallout repair did not weaken assertions** — spot-check the repaired tests
   assert the same observable outcomes via the settle path, not no-throw.
6. Re-run gates yourself: `dart format --set-exit-if-changed .` (root), `dart analyze` +
   `dart test` (packages/scheduler AND packages/worker_runtime) — report own numbers.
7. The implementer's noted behavioral delta: a lost `markRunning` CAS now costs a re-execution
   (stale-claim requeue on ref==null) — assess whether that's acceptable or a defect.

Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`RESULT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `RESULT: DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:`.
