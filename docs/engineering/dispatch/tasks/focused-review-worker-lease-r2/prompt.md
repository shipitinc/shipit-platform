# Dispatch — focused-review-worker-lease-r2 (correction re-review, cycle 2)

```yaml
MANAGER: orchestrator-main
TASK_ID: focused-review-worker-lease-r2
TASK_TYPE: re-review
FEATURE: F-226 worker-lease starvation — cycle-2 mid-stage fencing correction
AREA: worker_runtime / local worker lease lifecycle
WORKTREE: /private/tmp/shipit-fix-worker-lease-starvation
BRANCH: fix/worker-lease-starvation
BASE_SHA: fb8dde3
CORRECTED_HEAD: 1ec22f09a60d45f262c94a1ef00609d5e8dc9f84
ROUTING_CLASS: PRECISION
```

Focused re-review of the CYCLE-2 findings (DO_NOT_APPROVE_CORRECTIONS on 98bdca85) + regression risk
of the new diff `98bdca85..1ec22f0` — not a fresh full review.

Cycle-2 findings handed to the lane (verify each is now fenced):
1. `_setCleanup` blind upsert after mid-stage abandonment in `_finalCleanup`/`_cleanupAfterFailure`
   — claimed fix: `epoch` threaded into `_setCleanup` ({int? epoch}, null=legitimate writer), check
   between the `workspaceManager.cleanup` await and the record write.
2. `_finish` CAS window — claimed: staleness re-check after `readWorkerExecution` AND at the top of
   the `inTransaction<bool>` body (uncommitted → `_detachedResult`).
3. `verificationStarted`/`artifactCommitFailed` post-resume event writes — claimed: re-checks after
   `verificationsFor`/`inspect` and after `artifactCommitter.commit`.
4. Same-class writes fenced in-reach: initial acquiring transaction body-top check; `_transition`
   {int? epoch} (workspacePreparing/agentExecuting); prepare catch; post-prepare bail; and the
   `executionStarted`→`execute` gap.
5. New regression test wedges inside `workspaceManager.cleanup` (first call only, so the abandon
   path's own cleanup still runs) — row stays `timedOut`, `endedAt` non-null, result unchanged.
   Mutation-verified: disabling the fence makes the test fail `timedOut → agentExecuting`.

Verify: `98bdca85` is the parent of `1ec22f0` (no amend/rebase); the epoch/null contract is
consistent — a NULL-epoch caller is the legitimate writer and CANNOT be invoked by a detached drive
(check every new `_setCleanup`/`_transition` call site passes the drive's epoch, and the abandon
path passes none); live non-abandoned drive path remains behavior-identical (no misfire); and the
declared residual (abandonment between individual writes inside `_finish`'s tx body relies on
`expectedVersion` CAS) is honestly documented and genuinely irreducible without store-internal
support. Re-run gates yourself: `dart format --set-exit-if-changed .` (root), `dart analyze` +
`dart test` (packages/worker_runtime) — report your own numbers.

Read-only; no docker, no DB. Report per subtask-report.md ending exactly one of
`RESULT: APPROVE_CORRECTIONS` / `RESULT: DO_NOT_APPROVE_CORRECTIONS`.
