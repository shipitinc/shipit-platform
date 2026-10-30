# Dispatch — focused-review-f237-integration

```yaml
MANAGER: orchestrator-main
TASK_ID: focused-review-f237-integration
TASK_TYPE: re-review
FEATURE: F-237 integration-suite settle migration correction
AREA: apps/server integration tests
WORKTREE: /private/tmp/shipit-f237-integration-settle
BRANCH: fix/f237-integration-settle
BASE_SHA: 6fcb630
CORRECTED_HEAD: cb5f76f (commits 9e11a5e, 2fc08aa, 65f1038, 2cca690, cb5f76f)
ROUTING_CLASS: STANDARD
```

Focused re-review of the corrected finding (make test-integration RED at 6fcb630 — 35 failures,
`Expected: succeeded, Actual: running`) + regression risk — not a full re-review.

Verify at `cb5f76f`:
1. All 4 originally-failing files migrated to reconcile-adoption settle — same observable
   assertions preserved (no weakening/skipping/timeout-as-assertion).
2. `test/support/integration_settle.dart` waits on durable claim-release, never a sleep.
3. The `PersistenceDatabase(db.db)` wrapper-per-logical-caller fix (65f1038) is sound and
   confined to test code — AND confirm the corresponding PRODUCTION note (server.dart wiring
   three stores to one `db`) is left untouched and correctly flagged as out-of-scope (F-238).
4. Teardown leak: detached executions no longer outlive session disposal in the migrated files.
5. Dogfood `.git` fix accepts both dir and file — minimal, correct.
6. lane_f mid-batch deferral assertion change is a correct reflection of capacity-1 defer→adopt
   semantics, not a weakened assertion.
7. Re-run gates yourself: `dart format --set-exit-if-changed .` (root), `dart analyze` (apps/server),
   `dart run tool/run_unit_tests.dart` (apps/server). `make test-integration` was verified +319 by
   the lane — you MAY re-run it (sanctioned disposable-Postgres path) or verify from the recorded
   tally; state which you did.

Read-only otherwise; no docker beyond make test-integration, no DB writes. End with exactly
`RESULT: APPROVE_CORRECTIONS` / `RESULT: DO_NOT_APPROVE_CORRECTIONS`.
