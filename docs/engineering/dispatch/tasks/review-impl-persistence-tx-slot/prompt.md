# Dispatch — review-impl-persistence-tx-slot (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-impl-persistence-tx-slot
TASK_TYPE: review
FEATURE: F-238 PersistenceDatabase tx-slot race — zone-scoped transaction binding
AREA: persistence layer (shared by every Postgres store + all lanes)
WORKTREE: /private/tmp/shipit-fix-tx-slot
BRANCH: fix/persistence-tx-slot
BASE_SHA: ea7754a
HEAD_SHA_UNDER_REVIEW: e15b0ca36ec4d67e5f5583a9ad9cb219543ce168
ROUTING_CLASS: PRECISION
```

Independent read-only review of a core-abstraction change. `PersistenceDatabase.inTransaction`
now binds the `Transaction` as a `Zone` value (caller's async context) instead of an instance
slot — so concurrent logical writers no longer collide (`Session or transaction has already
finished`, confirmed live on QA at 3 sites).

Verify at `e15b0ca`:
1. The zone binding is correct — a caller inside a body attaches to ITS OWN transaction; an
   outsider's query on the same wrapper does NOT attach to the open tx (the exact F-238 crash);
   nested `inTransaction` still refuses with StateError; rollback/commit semantics preserved;
   `hasActiveTransaction` scoping correct; `inCapacityLockedTransaction` advisory lock intact;
   cross-wrapper delegation (`PostgresDefectStore._triageStore`) still attaches properly.
2. The flagged semantic tightening: work escaping a body's async context (timers/fire-and-forget
   spawned inside a body) now carries the binding and attaches to a finished tx — verify the
   implementer's claim that NO production tx body does this (spot-check local_worker,
   execution_coordinator, durable_workflow_engine, job_queue, baseline_dispatch tx bodies).
   Also verify _settleDetachedRun / detached continuations can't carry a stale zone binding.
3. Pool-backed concurrency claim: `session.db` (serverpod 3.4.13) is `pg.Pool`-backed so
   concurrent `runTx` calls run on independent pooled connections — confirm against the vendored
   package; if the connection were single-shared, the fix would serialize differently.
4. The 9 regression tests are discriminating — verify they fail on the PRE-FIX implementation
   (the lane claims 5 do; check the mechanism, don't re-run the pre-fix).
5. server.dart change is comment-only — verify nothing else changed there.
6. Re-run gates yourself: `dart format --set-exit-if-changed .` (root), `dart analyze` +
   `dart run tool/run_unit_tests.dart` (apps/server) — report own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`RESULT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `RESULT: DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:`.
