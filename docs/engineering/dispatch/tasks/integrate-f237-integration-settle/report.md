# Subtask Report — integrate-f237-integration-settle

```yaml
RESULT: MERGE_APPROVED
TASK_ID: integrate-f237-integration-settle
TASK_TYPE: integrate
FEATURE: F-237 integration-suite settle migration (corrected)
WORKTREE: /private/tmp/shipit-f237-integration-settle (branch) + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/f237-integration-settle
BASE_SHA: 6fcb630
HEAD_SHA: cb5f76f
COMMITTED: NO
```

## Verification performed (read-only; no merge, no push)

**Approved HEAD** — worktree HEAD is exactly `cb5f76f9fc9728afcc9f8123d9dc85b6d210c42b`, working tree
clean. 5 commits on base `6fcb630` as declared (`9e11a5e` … `cb5f76f`).
`merge-base(main, cb5f76f)` = `6fcb630` — base has not moved; branch is not an ancestor of main.

**Main advanced** — declared `CURRENT_MAIN: 0b53f6d`; actual local main is `f11b064`, one commit ahead:
the integrator dispatch prompt commit itself (docs-only). `origin/main` is `f58d6fb` (local main is 457
commits ahead — standing local-provenance state, unchanged by this lane).

**Diff scope** — 6 files, all under `apps/server/test/**` (5 integration suites +
`test/support/integration_settle.dart`). Nothing outside tests, nothing prohibited.
Main-side delta since base is docs/engineering dispatch/ledger files only — zero path overlap.

**Merge rehearsal** — `git merge-tree --write-tree main cb5f76f` → tree `0ce326f`, exit 0, no conflict
messages. A staged `git merge --no-commit --no-ff` in a disposable worktree at `f11b064` staged exactly
the 6 test files and nothing else. All 6 reviewed blob OIDs are identical between `cb5f76f` and the
merged tree `0ce326f` — reviewed content is what the merge produces. Rehearsal worktree was aborted
and removed; the branch worktree was never mutated.

**Gates on the merged tree** (rehearsal worktree; `dart pub get` at workspace root first):
- `dart format --output=none --set-exit-if-changed .` (root): 1072 files, 0 changed — PASS
- `dart analyze` (`apps/server`): exit 0; 5 info-level lints, no warnings/errors — PASS
- `dart run tool/run_unit_tests.dart` (`apps/server`): "69 files, all passed", exit 0 — PASS
- `dart test` (`packages/scheduler`): +446, "All tests passed!", exit 0 — PASS

**`make test-integration`** — ACCEPTED the focused-reviewer's evidence rather than re-running: it was
independently re-run green (+319) at `cb5f76f` on the branch. The merged tree `0ce326f` differs from
`cb5f76f`'s tree only in `docs/engineering/**` files added on main; every blob the integration suite can
observe (`apps/`, `packages/`, `tool/`, `Makefile`, `docker/`) is bit-identical, so a re-run would
exercise identical code. No docker commands were issued by this lane.

## Files touched

None. Verification was read-only against git objects; gates ran in a disposable worktree that was
aborted (`git merge --abort`) and removed (`git worktree remove`). `dart pub get` wrote only to the
disposable worktree's `.dart_tool/` and the shared pub cache.

## Unresolved issues

None. Local main ahead of `origin/main` by 457 commits is pre-existing repo state, not introduced here.

## Required structured result

```
RESULT: MERGE_APPROVED

APPROVED_HEAD: cb5f76f9fc9728afcc9f8123d9dc85b6d210c42b
CURRENT_MAIN: f11b0648b32d042fc42383154a15a63355930074 (declared 0b53f6d + 1 docs-only dispatch commit; origin/main f58d6fb)

GATES:
format=PASS (dart format --output=none --set-exit-if-changed . — 1072 files, 0 changed, repo root, merged tree)
analyze=PASS (dart analyze — apps/server, exit 0, 5 info-level lints only, merged tree)
tests=PASS (dart run tool/run_unit_tests.dart — apps/server, 69 files all passed, exit 0; dart test — packages/scheduler, +446 all passed, exit 0; both on merged tree)
build=NOT_REQUIRED (no build gate declared for this repo; integration-tier make test-integration green +319 at approved HEAD by focused-reviewer — accepted, merged tree bit-identical outside docs/)

PROVENANCE: branch fix/f237-integration-settle at /private/tmp/shipit-f237-integration-settle, HEAD == approved cb5f76f9fc9728afcc9f8123d9dc85b6d210c42b, clean; 5 commits on base 6fcb630d8bfa8c5c2d8e485b038a57427e909557; merge-base with main == base; merge rehearsal clean (tree 0ce326f, zero conflicts, zero path overlap); all 6 reviewed blob OIDs identical in merged tree; test-only diff under apps/server/test/**.

READY_FOR_INTEGRATION: YES — clean non-fast-forward merge (main advanced past base; rehearsal tree 0ce326f applies with no conflicts and no semantic drift). No push/merge performed. Human/deployment authority is still required before any actual push or merge: production promotion is human-authorized under repo policy; this lane stops at merge-readiness.
```

RESULT: MERGE_APPROVED
