# Integrator Report — integrate-infra-decision-resolve

```yaml
RESULT: MERGE_APPROVED
TASK_ID: integrate-infra-decision-resolve
TASK_TYPE: integrate
FEATURE: resolveDecision handles system:provider-health decisions — store-level system-scope resolve
WORKTREE: /private/tmp/shipit-fix-infra-decision (feature) + /private/tmp/shipit-integrate-infra-decision (merge rehearsal)
BRANCH: fix/infra-decision-resolve
BASE_SHA: 18172c6
HEAD_SHA: ccb6538
COMMITTED: YES
```

## Provenance — verified

- `fix/infra-decision-resolve` tip = `ccb6538135d21382c5a78974de77b3d69a113409` — approved HEAD unchanged.
- `git merge-base main ccb6538` = `18172c6f3b9…` — matches declared BASE_SHA.
- Current `main` = `e55749f729734401fd72449c1bb7757d68bfeb54`; branch is not merged (ccb6538 not an ancestor) and main is not an ancestor of the branch (merge-base ≠ main) → **non-fast-forward, merge-commit strategy required**.
- `origin/main` = `f58d6fb…` — far behind local main (local orchestration, ~618 unpushed commits); remote is not the integration target.
- Diff `18172c6..ccb6538` touches exactly the 4 declared files, all under `apps/server/lib/`: `src/endpoints/workflow_endpoints.dart`, `src/endpoints/system_scope_resolve_decision_test.dart`, `src/services/control_plane_service.dart`, `src/services/ui_view_mappers.dart` (+558/−23).

## Merge rehearsal — clean

- `git merge-tree --write-tree e55749f ccb6538` → tree `8ca361ef7bd7…`, **zero conflicts**.
- Scratch merge commit `ec52a08e36af…` (parents e55749f + ccb6538) materialized at `/private/tmp/shipit-integrate-infra-decision` — all gates below ran on that merged tree.
- **Reviewed blobs identical**: all 4 files' blob SHAs in the merged tree are byte-identical to the approved HEAD (baeccc9, cb80822, ae28b28, e3662cc).

## Gates on merged tree `ec52a08`

| gate | command / cwd | result |
|---|---|---|
| format | `dart format --set-exit-if-changed .` @ root (after `dart pub get`) | **PASS** — 1099 files, 0 changed |
| analyze | `dart analyze` @ `apps/server` | **PASS** — exit 0; 5 info-level only, all in untouched `test/integration/` files (pre-existing) |
| targeted tests | `dart test lib/src/endpoints/system_scope_resolve_decision_test.dart lib/src/qa/qa_drain_reentry_test.dart` @ `apps/server` | **PASS** — +11, `All tests passed!` |
| unit tier | `dart run tool/run_unit_tests.dart` @ `apps/server` | **PASS** — `73 files, all passed` (runner's `all passed` line verified to precede `exit(0)` only) |
| integration tier | `SERVERPOD_DATABASE_PASSWORD=control_plane_test_pw make test-integration` @ root | **PASS on rerun** — see disclosure |

## Disclosure — integration run 1 carried a documented pre-existing flake

Two full `make test-integration` invocations on the identical merged tree:

- **Run 1: `+318 −1`**, sole failure `product_credential_immutability_postgres_test.dart` — "D-4 under concurrency: two mints of one id yield one row and one identity conflict". Expected `contains 'already exists'`, got the one-active-per-repository refusal message.
- **Run 2: `+319 All tests passed!`** — clean green.

This exact signature is a **documented, pre-existing latent flake**: `dispatch/tasks/correct-credential-identity-invariants-guard/report.md` records the identical assertion diff, characterizes it as a race between two unique-index refusal paths (the gate synchronizes reads, not writes), measured ~2-in-4, and explicitly NOT caused by the change under review there. Here likewise: the merged tree differs from main only in the 4 reviewed files — resolveDecision routing + UI mappers — none of which touch credential minting. It remains an unfixed flake on main; flagged, not absorbed.

- Teardown verified both runs: `shipit_integration_<pid>` container + network removed; zero leaked containers (`docker ps -a --filter` empty).
- Process note: the first unit-tier invocation was killed mid-run (output unreadable in backgrounded shell) and re-run cleanly to completion — no impact on evidence; the recorded green run is a single complete pass.
- Rehearsal worktree `/private/tmp/shipit-integrate-infra-decision` left in place at `ec52a08` (clean tree) in case the manager wants the rehearsed merge; safe to remove.

## Result

```
RESULT: MERGE_APPROVED

APPROVED_HEAD: ccb6538135d21382c5a78974de77b3d69a113409
CURRENT_MAIN: e55749f729734401fd72449c1bb7757d68bfeb54

GATES:
format=PASS (dart format --set-exit-if-changed . @ root: 1099 files, 0 changed)
analyze=PASS (dart analyze @ apps/server: exit 0, 5 pre-existing infos in untouched files)
tests=PASS (targeted 2-file suite +11 green; unit tier 73 files all passed)
build=PASS (merge/release tier: make test-integration — +319 all passed on rerun; run 1 sole failure = documented pre-existing credential-concurrency flake unrelated to change)

PROVENANCE: branch fix/infra-decision-resolve @ approved ccb6538; base/merge-base 18172c6; main e55749f advanced since base (non-FF); merge-tree rehearsal clean, all 4 reviewed blobs byte-identical in merged tree; origin/main f58d6fb stale/behind local

READY_FOR_INTEGRATION: YES — non-fast-forward merge commit of ccb6538 into main e55749f (rehearsed clean at tree 8ca361e / scratch commit ec52a08). Merge authority: standing human-granted authorization noted in ledger (7e4c840) covers the local merge per orchestrator policy; no push performed — remote promotion remains human-authorized per repo policy.
```
