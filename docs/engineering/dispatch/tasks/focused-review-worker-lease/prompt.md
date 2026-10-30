# Dispatch — focused-review-worker-lease (correction re-review, cycle 1)

```yaml
MANAGER: orchestrator-main
TASK_ID: focused-review-worker-lease
TASK_TYPE: re-review
FEATURE: F-226 worker-lease starvation — corrected post-checkpoint fencing
AREA: worker_runtime / local worker lease lifecycle
WORKTREE: /private/tmp/shipit-fix-worker-lease-starvation
BRANCH: fix/worker-lease-starvation
BASE_SHA: fb8dde3
REVIEWED_HEAD: 2b24f4ed676f2943a88a6092cada99f262b82a8a
CORRECTED_HEAD: 98bdca857901b3925e757223c039fec6ff66b276
ROUTING_CLASS: PRECISION
```

Focused re-review of ONLY the corrected findings + regression risk — not a full re-review.

Prior review's BLOCKER (verbatim): detached stale drive abandoned past the pre-`execute` checkpoint
(`local_worker.dart:482` only `_isStale` check) ran unfenced through inspect/commit/cleanup/`_finish`,
CAS-overwriting the abandon-path `timedOut` terminal, overwriting the saved result, emitting terminal
events, and `checkout -B`ing `shipit/impl/<workItemId>` onto an abandoned run's artifact.

Correction claims at `98bdca85` (verify each against the diff `2b24f4e..98bdca85`):
1. `epoch` threaded into `_finish` — stale drive returns `_detachedResult` without store writes.
2. Post-`settled` staleness re-check — abandonment during `execute`/executionStarted returns detached
   before inspect/verifications/commit/finish.
3. Stale guards in both catch arms (`TimeoutException`, `on Object`).
4. `artifactCommitter.commit` skipped when stale — `shipit/impl/<id>` cannot be force-moved.
5. Pre-`_finalCleanup` checkpoint — blocks `_setCleanup` version-bump regression write.
6. `_detachedResult` docstring corrected (reviewer LOW).
7. New regression test: drive wedged at `verificationsFor` unwedges post-abandon; asserts terminal
   row stays `timedOut`, result unchanged, commit never called, branch absent.

Also verify: reviewed HEAD `2b24f4e` preserved (correction is a NEW commit on top, no amend/rebase);
gates re-run by you: `dart format --set-exit-if-changed .` (root), `dart analyze` + `dart test`
(packages/worker_runtime). Assess regression risk the correction itself introduces — especially
whether a NON-stale drive's `_finish` path is unchanged and whether the stale checks can misfire on
a live (non-abandoned) drive.

Read-only; no docker, no DB. Report per subtask-report.md ending exactly one of
`RESULT: APPROVE_CORRECTIONS` / `RESULT: DO_NOT_APPROVE_CORRECTIONS`.
