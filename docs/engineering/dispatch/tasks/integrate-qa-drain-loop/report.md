# Subtask Report — integrate-qa-drain-loop

```yaml
RESULT: MERGE_APPROVED
TASK_ID: integrate-qa-drain-loop
TASK_TYPE: integrate
FEATURE: qa.drain loop fix — qaAttempt-scoped idempotency + qaFailed candidate arm (F-245)
WORKTREE: /private/tmp/shipit-fix-drain-loop (rehearsal: /private/tmp/shipit-integrate-rehearsal, removed)
BRANCH: fix/qa-drain-loop
BASE_SHA: 7ace9ef
HEAD_SHA: 158d8317
COMMITTED: NO
```

## What was verified

- **Approved HEAD unchanged**: `fix/qa-drain-loop` worktree is at
  `158d8317ec9026a7eab0fb2489b5fb7ed7ad38d2`, clean, exactly the reviewed revision.
- **Main advanced since base**: base `7ace9ef` is the merge-base; current local `main`
  is `b0334c3` (ledger/dispatch commits only — `FOLLOW_UPS.md`, `LANES.md`, task prompts).
  Zero path overlap with the change (`apps/server/lib/src/qa/qa_drain.dart`,
  `apps/server/lib/src/qa/qa_drain_reentry_test.dart`), so a true merge — not a rebase —
  is required and is clean.
- **Rehearsal merge**: disposable worktree + temp branch off `main`, `git merge --no-ff
  158d8317` — clean, no conflicts. Post-merge blob ids for both touched files are
  byte-identical to the approved HEAD (`qa_drain.dart` `c7a041a`, `qa_drain_reentry_test.dart`
  `7f27eeb`). Rehearsal worktree and branch removed afterwards; `main` untouched.
- **Remote provenance**: `origin/main` = `f58d6fb` is an ancestor of local `main`
  (local is ~579 commits ahead — the established unpushed orchestration ledger pattern,
  not a divergence). Nothing pushed by this lane.

## Validation results (all run on the merged rehearsal tree)

| Command | Status | Evidence / note |
|---------|--------|-----------------|
| `dart pub get` (repo root) | pass | prerequisites resolved |
| `dart format --output=none --set-exit-if-changed .` (repo root) | pass | 1095 files, 0 changed |
| `dart analyze` (apps/server) | pass | exit 0; 5 info-level lints, all pre-existing in `test/integration/`, none in touched files |
| `dart test lib/src/qa/qa_drain_reentry_test.dart test/qa_drain_test.dart` (apps/server) | pass | 24 tests (6 reentry + 18 drain), `All tests passed!` |
| `dart run tool/run_unit_tests.dart` (apps/server) | pass | `73 files, all passed`, EXIT=0 |
| `SERVERPOD_DATABASE_PASSWORD=control_plane_test_pw make test-integration` (merged tree root) | pass | 319 integration tests, `All tests passed!`; disposable Postgres `shipit_integration_96713` removed by the target's trap |

## Unresolved issues and blockers

- None blocking. Two observations for the Manager:
  1. The review's non-blocking followup is already recorded in `FOLLOW_UPS.md`
     (product decision: `intake-structured-result-admitted` gate vs implementation-produced
     items — a genuine human product call, explicitly not blocking F-245).
  2. `qa_drain_reentry_test.dart` is co-located under `lib/src/qa/` (an established pattern —
     17 such files exist), so the pinned runner's `test/*.dart` enumeration does not pick it
     up. It passed under the dispatch-declared explicit `dart test` invocation; if the
     contract intends runner coverage for co-located tests that is a separate policy question.

## Cleanup confirmation

- [x] No processes left running; disposable Postgres removed by `make test-integration` trap.
- [x] Rehearsal worktree `/private/tmp/shipit-integrate-rehearsal` removed; temp branch `integrate-rehearsal` deleted.
- [x] `main` unchanged at `b0334c3`; feature worktree clean at approved HEAD.
- [x] No files modified outside this task's dispatch directory.

## Recommended next action

`MERGE` — clean non-fast-forward merge of `158d8317` into `main`; requires human/deployment
authority per repository policy (production promotion is human-authorized). This lane merged
nothing and pushed nothing.

RESULT: MERGE_APPROVED
