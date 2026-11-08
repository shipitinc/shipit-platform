# Subtask Report — integrate-decision-detail-surface

```yaml
RESULT: MERGE_APPROVED
TASK_ID: integrate-decision-detail-surface
TASK_TYPE: integrate
FEATURE: Decision-detail page surfaces review verdict + findings + artifact + full context + real option consequences
WORKTREE: /private/tmp/shipit-decision-surface (feature) + /private/tmp/shipit-merge-rehearsal (scratch, removed)
BRANCH: feat/decision-detail-surface
BASE_SHA: da095e2
HEAD_SHA: 07b4b38
COMMITTED: NO
```

## Verification

- **Approved HEAD unchanged.** Worktree `/private/tmp/shipit-decision-surface` on
  `feat/decision-detail-surface`, HEAD `07b4b382d00182fe7e14e3acd44b40fd6a6accd3`, working tree clean.
  The lane never wrote to it.
- **Base provenance.** Merge-base of base and HEAD = `da095e27584f7d3e98a2d85d6ac35a248677e4ce`; base is
  an ancestor of current main.
- **Main advanced since base.** Current main `9099fab80832e0e0d470ef94c976ab759e35a638` is 6 commits
  ahead of base — all `docs/engineering/dispatch/` bookkeeping (LANES.md, 3 task prompts). Zero path
  overlap with the change's 16 files. `origin/main` = `f58d6fb` (local-first; local main 557 ahead —
  push not in scope regardless).
- **Merge rehearsal clean.** Detached scratch worktree at main, `git merge --no-ff
  feat/decision-detail-surface` → `ce739d2c38cdb068edae44af6088d492b3ae6656` ('ort', no conflicts).
- **Reviewed blobs identical.** `git diff <approved-HEAD> <merged-HEAD>` over every touched path is
  empty; merged tree differs only by the 4 dispatch/ledger docs main added. File count note: dispatch
  said 14; the diff is 16 files (6 control_plane incl. test, 3 control_plane_client incl. test,
  7 server + manifest + pin tests) — the dispatch's own enumeration covers all 16.

## Gates — all run on the merged tree (`ce739d2`), repo `/private/tmp/shipit-merge-rehearsal`

| gate | command / cwd | result |
|---|---|---|
| format | `dart pub get` then `dart format --output=none --set-exit-if-changed .` at root | PASS — 1093 files, 0 changed |
| analyze | `dart analyze` in `apps/control_plane` | PASS — No issues found |
| analyze | `dart analyze` in `packages/control_plane_client` | PASS — No issues found |
| analyze | `dart analyze` in `apps/server` | PASS — exit 0; 5 info-level lints, all pre-existing in untouched `test/integration/` files (deprecated_member_use ×4, curly_braces ×1) |
| tests | `flutter test` in `apps/control_plane` | PASS — 528 tests, `All tests passed!` |
| tests | `dart test` in `packages/control_plane_client` | PASS — `All tests passed!` |
| tests | `dart run tool/run_unit_tests.dart` in `apps/server` | PASS — 73 files, all passed; integration dir excluded by construction |
| integration | `SERVERPOD_DATABASE_PASSWORD=control_plane_test_pw make test-integration` at root | PASS — 319 tests, `All tests passed!`; disposable Postgres `shipit_integration_18114` self-cleaned |

## Disclosure — first integration attempt failed, environmental

The first `make test-integration` run was executed **concurrently** with the server unit-test sweep.
`dogfood_shipit_postgres_test` (S-1 dogfood: archives HEAD into a temp snapshot, walks it, builds a
baseline) exceeded its 30s test timeout under the CPU contention; on timeout the framework ran
`addTearDown`, which deleted the snapshot while the orphaned async `_walk` was still running —
surfacing as `PathNotFoundException` on `…/shipit-head-*/apps/server/lib/src/models/` inside a
timed-out test. Solo re-run: same test passed in ~8s, suite fully green. Root cause is gate-runner
scheduling on my side, not the change; disclosed per policy. No docker commands beyond the named
exemption were used; the failed run's compose project also self-cleaned.

## Integration strategy

`main` cannot fast-forward (it carries bookkeeping commits the branch lacks). Safe path: merge commit
`git merge --no-ff feat/decision-detail-surface` into `main` — rehearsal is trivially clean and
preserves reviewed history. (Rebase+FF would also replay cleanly given zero overlap, but a merge
commit avoids rewriting the reviewed commits.)

RESULT: MERGE_APPROVED

APPROVED_HEAD: 07b4b382d00182fe7e14e3acd44b40fd6a6accd3
CURRENT_MAIN: 9099fab80832e0e0d470ef94c976ab759e35a638

GATES:
format=PASS (0 changed / 1093 files)
analyze=PASS (3 roots; server has 5 pre-existing info lints in untouched test/integration files)
tests=PASS (528 flutter + client suite + 73 server unit files)
build=PASS (make test-integration: 319 tests green; solo re-run after a contention-timeout on the first attempt — disclosed)

PROVENANCE:
branch=feat/decision-detail-surface @ /private/tmp/shipit-decision-surface (clean, approved HEAD unchanged)
base=da095e27584f7d3e98a2d85d6ac35a248677e4ce (merge-base verified, ancestor of main)
rehearsal=ce739d2c38cdb068edae44af6088d492b3ae6656 (detached scratch, clean merge, reviewed blobs byte-identical; scratch removed)
origin/main=f58d6fb129c1d4265ada5af9dc359eb5ac27a9a2 (local-first; local main 557 ahead)

READY_FOR_INTEGRATION:
YES — merge commit `main ← feat/decision-detail-surface` is safe and rehearsed clean; a fast-forward
is not possible (main advanced with dispatch bookkeeping only). Actual merge still requires
human/orchestrator integration authority — I did not merge and did not push.
