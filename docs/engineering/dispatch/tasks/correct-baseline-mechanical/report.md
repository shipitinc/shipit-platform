# Report — correct-baseline-mechanical

Persisted verbatim per `aef-orchestrator` §14. Lane: `correction-implementer`.
Worktree `/private/tmp/shipit-correct-baseline`, branch `correct/baseline-mechanical`,
BASE_SHA `0d5d132`, HEAD_SHA `07c48ed`, COMMITTED: YES. Worktree retained for re-review.

## Structured result

```
RESULT: CORRECTION_BLOCKED
TASK_ID: correct-baseline-mechanical
TASK_TYPE: correct
FEATURE: Clear the mechanical review blockers so the baseline compiles and passes CI
WORKTREE: /private/tmp/shipit-correct-baseline
BRANCH: correct/baseline-mechanical
BASE_SHA: 0d5d132
HEAD_SHA: 07c48ed
COMMITTED: YES
```

The implementer declined to claim completion: all five findings are substantively corrected
and verified, but two dispatch acceptance criteria cannot be satisfied inside its declared
`OWNED_PATHS`, and one gate is still red.

## Findings cleared

| Finding | Outcome | Evidence |
|---|---|---|
| B1 — `apps/server` 10 compile errors | CLEARED | 4 unreferenced scratch scripts deleted (`bin/onboard_simple.dart`, `bin/onboard_direct.dart`, `bin/onboard_fixed.dart`, `bin/add_human_claims_mature.dart`). Unreferenced-ness verified first: the only repo-wide hit for `onboard_simple` was a string literal *inside* the deleted file. `bin/main.dart` and `pubspec.yaml:49` untouched. |
| B2 — format gate, 40 files / 8 packages | CLEARED | Post-state clean in all 16 workspace packages. Formatting proven logic-free: all 40 files byte-identical to HEAD once whitespace and trailing commas are stripped. |
| B3 — 3 committed credential literals | CLEARED (3/3 named sites) | All three now use the existing `onboard_shipit_dev.dart` convention verbatim: `password: _env('SERVERPOD_DATABASE_PASSWORD', 'shipit')`. Nothing rotated. |
| M2 — committed `.bak` | CLEARED | Deleted after verifying zero references; live endpoint intact. |
| M3 — 51 KB report at repo root | CLEARED | `git mv` to `docs/reports/`, sha256 `76371c07…8527fe` identical before/after, recorded `R100` with 0-line diff. No link repair needed (document contains zero markdown links). Verdict untouched. |
| M7 — inert `.gitignore` rules | SKIPPED as instructed | No `git rm --cached`. |

Commits on `correct/baseline-mechanical` (4, on top of `0d5d132`, history not rewritten):
`dae3d68` (B1, M2) · `96928ed` (M3) · `d371265` (B3) · `07c48ed` (B2).
Diff: 49 files changed, +995/-1689.

## Why CORRECTION_BLOCKED

| # | Unmet criterion | Cause |
|---|---|---|
| A | `dart analyze packages apps/server` exits 0 | 0 errors achieved (was 10), but exits **2** on 2 pre-existing warnings + 303 pre-existing infos that live in `PROHIBITED_PATHS`. Severity census: `0d5d132` = 10 errors / 2 warnings / 433 infos / exit 3; `07c48ed` = **0 errors** / 2 warnings / 303 infos / exit 2. The 2 warnings (`unused_shown_name`, `product_registry_endpoints.dart:16,17`) are pre-existing and byte-identical in count. Clearing the rest requires edits to `apps/server/lib/**`, `apps/server/test/**`, `packages/workflow_engine/lib/**` — all format-only by dispatch. **CI's `melos run analyze` is therefore still red**: 14 of 16 packages exit 0; `apps/server` and `apps/control_plane` exit 2. |
| B | credential grep returns nothing | 3 residual `control_plane_test_pw` hits outside `OWNED_PATHS`, and they are a **coupled pair**, not a mechanical edit: `apps/server/docker-compose.yaml:24` (`POSTGRES_PASSWORD` for `postgres_test`) and `apps/server/config/test.yaml:32` (Serverpod `test` mode `database.password`) **must stay equal** or integration auth breaks; plus `apps/server/tool/seed_overview_qa.sql:9` (comment). |

## Dispatch discrepancies, corrected by evidence

- Workspace has **16** packages, not 17 (all 16 have `lib`/`test`; all 16 checked).
- `flutter analyze` shows **34** issues, not 33 — the extra is a pre-existing warning the
  dispatch did not count, reproduced by restoring the HEAD version of that file.
- HD 048f3367 scopes "three credential literals"; the same dev password is in 3 more places.

## Validation results

| Command | Status | Evidence |
|---|---|---|
| `dart analyze packages apps/server` | **fail** | exit 2 — 0 errors, 2 warnings, 303 infos (was exit 3, 10 errors) |
| format gate, all 16 packages | **pass** | clean 16/16 |
| `flutter analyze --no-pub` | **pass** | 0 errors, 33 infos + 1 pre-existing `unused_local_variable` |
| `flutter test --no-pub` | **pass** | 190/190 |
| `flutter build web --no-pub` | **pass** | ✓ Built build/web |
| credential grep | **fail** | 3 residuals outside `OWNED_PATHS` |

No gate weakened: zero tests weakened, skipped or deleted; no test files deleted; no lint
suppressed; `analysis_options.yaml` untouched.

## New discoveries (not persisted — `docs/engineering/**` is prohibited to this lane)

1. **PROJECT_FACT** — CI's analyze gate cannot reach exit 0 without a dedicated lint pass:
   272 of the 303 remaining infos are `avoid_print` in operator scripts and `onboarding_test.dart`.
2. **AUTOMATION_OPPORTUNITY / needs a human** — HD 048f3367's "three credential literals"
   undercounts; the same dev password is committed in 3 more places, 2 a coupled
   compose↔Serverpod-config pair. Needs its own decision, not a code lane.
3. **PROJECT_FACT** — workspace is 16 packages, not 17.
4. **WORKFLOW_IMPROVEMENT** — `dart analyze` emits some issues at column 0 without leading
   whitespace, so a `^\s+(error|warning)` grep silently undercounts. Review scripts should use
   `^[[:space:]]*`.

## Cleanup

No processes left running. Two `dart test` processes and listeners on 5432/8080/8081/9090/9099
belong to Docker Desktop, postgres, and a different project
(`/Users/alkebut/IdeaProjects/partnerhub/`) — not this lane, not touched. Temp scratch removed.
Worktree status clean (0 entries). Worktree retained. Canonical checkout never written to.

## Recommended next action

`HUMAN_DECISION_REQUIRED` — rule on Blockers A and B: either expand ownership to a
lint/credential pass, or amend the two acceptance criteria to their verified substance
(zero errors; the three named B3 sites). `READY_FOR_FOCUSED_REVIEW: NO` because a required
gate is red. No self-approval.
