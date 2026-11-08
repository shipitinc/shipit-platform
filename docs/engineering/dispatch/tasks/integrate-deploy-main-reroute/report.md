# Report — integrate-deploy-main-reroute

RESULT: MERGE_APPROVED

## Provenance
- Approved HEAD: `d6e995dca86cbee075451ccea812a8e8aa51b5ff` (a3a6bc5 + copy-arm correction)
- `git rev-parse feat/deploy-main-reland-reroute` == d6e995d; lane worktree `/private/tmp/shipit-feat-deploy-main` HEAD == d6e995d (matches)
- merge-base(main, branch) = `aa83787` == declared BASE_SHA; branch is a 2-commit linear stack on the base
- `git fetch origin`: `origin/main` = f58d6fb, ancestor of local `main`; canonical local `main` = `5e1082b` (unchanged during verification)
- Ledger: review `DO_NOT_MERGE` (missing copy arm) → correction → d6e995d → focused review 61cbcd11; dispatch asserts `APPROVE_CORRECTIONS` on d6e995d

## Merge verification
- `git merge-tree --write-tree main d6e995d` → clean, tree `e733d36`, zero conflicts
- Real `--no-ff` merge in throwaway worktree (detached @ 5e1082b) → clean, merge commit `c4eaf69`
- main advanced past base only via orchestration ledger/dispatch docs (`docs/engineering/dispatch/**`, LANES.md) — re-land merge `d1de65a` is already inside `aa83787`, i.e. in the branch's base
- Semantic overlap: merged `deploy_landing.dart` / `work_item_action_endpoints.dart` / `packages/workflow_engine` / `transition_copy.dart` are byte-identical to the branch (`git diff d6e995d HEAD` on those paths = 0). `_resolveDefaultBranch` + `rerouteToImplementation` present; no main-side edits to same files → no semantic conflict possible

## Gates on merged tree (exact pinned commands)
- format: `dart format --output=none --set-exit-if-changed .` @ root → 0 changed, exit 0
- analyze: `dart analyze` → apps/server exit 0 (5 info), packages/workflow_engine exit 0 (2 info), apps/control_plane exit 0 (no issues)
- tests: `dart run tool/run_unit_tests.dart` @ apps/server → 77 files, all passed
- tests: `dart test` @ packages/workflow_engine → +232 all passed
- tests: `fvm flutter test` @ apps/control_plane → +553 all passed
- (pre-merge format showed 190 phantom "changed" files — artifact of running before `dart pub get`; re-run post-resolution was clean)

## Cleanup
- Temp merge worktree `/private/tmp/shipit-integrate-merged` removed; canonical worktree untouched; no commits made to main (stopped at merge-readiness)
