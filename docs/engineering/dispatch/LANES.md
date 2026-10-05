# LANES.md — Manager lane ledger

One row per lane. Rebuilt from disk + Git on 2026-10-05 per `aef-orchestrator` §14
recovery procedure. Git is authoritative for code state.

## Prior session — work item "Add Product page UI implementation"

Recovery finding: **all ten lanes have `prompt.md` only — no `report.md`, no
`state.json` was ever persisted.** Every lane worktree is still at `693cfbc` with
uncommitted changes, so no lane produced a commit and no lane produced reviewable
provenance. The prior ledger therefore cannot be trusted and was not reconstructed
from reports.

| task_id | type | recorded state | worktree | branch | base_sha | head_sha | next action |
|---|---|---|---|---|---|---|---|
| design-produce-add-product | design-produce | artifacts present, uncommitted | /private/tmp/shipit-design-add-product | design/add-product | 693cfbc | 693cfbc | PARKED — uncommitted artifacts, no report |
| design-review-add-product | design-review | in-flight per Git, no report | /private/tmp/shipit-design-review-add-product | design-review/add-product | 693cfbc | 693cfbc | PARKED — treated as not-run (no report) |
| design-correct-add-product | design-produce | in-flight per Git, no report | /private/tmp/shipit-design-correct-add-product | design-correct/add-product | 693cfbc | 693cfbc | PARKED — no report |
| design-re-review-add-product | design-review | in-flight per Git, no report | /private/tmp/shipit-design-re-review-add-product | design-re-review/add-product | 693cfbc | 693cfbc | PARKED — no report |
| design-correct-2-add-product | design-produce | in-flight per Git, no report | /private/tmp/shipit-design-correct-2-add-product | design-correct-2/add-product | 693cfbc | 693cfbc | PARKED — no report |
| design-re-review-2-add-product | design-review | in-flight per Git, no report | /private/tmp/shipit-design-re-review-2-add-product | design-re-review-2/add-product | 693cfbc | 693cfbc | PARKED — no report |
| qa-contract-add-product | qa-contract | artifact present, uncommitted | /private/tmp/shipit-qa-contract-add-product | qa-contract/add-product | 693cfbc | 693cfbc | PARKED — `QA_CONTRACT_add_product.json` uncommitted, never frozen |
| implement-add-product | implement | **RESULT: IMPLEMENTATION_BLOCKED** (verified in worktree `IMPLEMENTATION_REPORT.md`) | /private/tmp/shipit-implement-add-product | implement/add-product | 693cfbc | 693cfbc | PARKED — blocker is the missing product baseline (see decision 130f3a7e) |
| review-add-product | review | dispatched with no valid upstream result; no report | /private/tmp/shipit-review-add-product | (detached) | 693cfbc | 693cfbc | PARKED — lane should never have been dispatched |
| integrate-add-product | integrate | dispatched with no approval; no report | /private/tmp/shipit-integrate-add-product | (detached) | 693cfbc | 693cfbc | PARKED — lane should never have been dispatched |

Defect recorded: the prior session advanced to `review` and `integrate` without a
parsed `RESULT: IMPLEMENTED` or any independent approval, and without persisting
child reports. Both lanes are void.

## Current session — FEATURE c46b6807

Item ref: favicon · duplicate "Show technical details" row on Add a product ·
Register-product button disabled / required-field convention · isolated test environment.

| task_id | type | state | worktree | branch | base_sha | head_sha | routing_class | result | next action |
|---|---|---|---|---|---|---|---|---|---|
| review-runtime-config-interop | review | CLOSED | canonical checkout (read-only) | main | bfbbd68 | bfbbd68 | STANDARD | `APPROVE_WITH_NON_BLOCKING_FOLLOWUP` — 0 blockers, CORRECTION_REQUIRED: NO | follow-ups recorded; change included in baseline |
| integrate-baseline-product | integrate | CLOSED — BLOCKED | canonical checkout + throwaway worktree | baseline/product-2026-10-05 | bfbbd68 | 0d5d132 | STANDARD | `INTEGRATION_BLOCKED` — B1 missing review, B2 ledger, B3–B7 non-blocking | superseded in substance by review-baseline-0d5d132 |
| review-baseline-0d5d132 | review | CLOSED — BLOCKED | /private/tmp/shipit-review-baseline (removed) | (detached) | bfbbd68 | 0d5d132 | PRECISION | `DO_NOT_MERGE` — CORRECTION_REQUIRED: YES, HUMAN_DECISION_REQUIRED: YES | parked; mechanical corrections + 2 human decisions required |
| (feature lanes) | — | NOT DISPATCHED | — | — | — | — | — | — | blocked: no reviewed, buildable BASE_SHA exists |

## Current session — product baseline

| item | branch | head | note |
|---|---|---|---|
| baseline commit | `baseline/product-2026-10-05` | `0d5d132` | 585 files changed (+203997/-4838); explicitly unreviewed except the runtime-config fix |
| `main` | `main` | `bfbbd68` | 3 commits ahead of `origin/main` (693cfbc, 9d98efe, bfbbd68) — never pushed |
| `origin/main` | — | `ea9b03d` | |

Verified from a fresh detached worktree at `0d5d132`: `flutter pub get` resolves,
`flutter analyze` 0 errors, `flutter test` 190/190, `flutter build web` succeeds,
`createProduct` and `lib/shared/form_primitives.dart` both present (they existed in no
prior commit). Clean fast-forward: `merge-base main baseline` = `bfbbd68`.

## Stale lane worktrees — all pinned to 693cfbc, 4 behind baseline

Per integrator blocker B9, none may be removed without a decision, because they hold
uncommitted design/QA artifacts and one of the superseded `add_product_page.dart`
variants.

| worktree | branch | holds |
|---|---|---|
| /private/tmp/shipit-design-add-product | design/add-product | DESIGN_BRIEF / DISCOVERY / REVISION (untracked) |
| /private/tmp/shipit-design-review-add-product | design-review/add-product | same three design artifacts |
| /private/tmp/shipit-design-correct-add-product | design-correct/add-product | design artifacts + superseded add_product_page.dart |
| /private/tmp/shipit-design-re-review-add-product | design-re-review/add-product | design artifacts |
| /private/tmp/shipit-design-correct-2-add-product | design-correct-2/add-product | design artifacts + superseded add_product_page.dart |
| /private/tmp/shipit-design-re-review-2-add-product | design-re-review-2/add-product | design artifacts + superseded add_product_page.dart |
| /private/tmp/shipit-qa-contract-add-product | qa-contract/add-product | `QA_CONTRACT_add_product.json` (never frozen) |
| /private/tmp/shipit-implement-add-product | implement/add-product | `IMPLEMENTATION_REPORT.md` (`RESULT: IMPLEMENTATION_BLOCKED`) + superseded variant |
| /private/tmp/shipit-review-add-product | (detached) | superseded add_product_page.dart — VOID lane |
| /private/tmp/shipit-integrate-add-product | (detached) | superseded add_product_page.dart — VOID lane |

`0d5d132` pins the authoritative `add_product_page.dart` (canonical checkout, 1117 lines),
so the four worktree variants are superseded for code purposes. The design and QA
artifacts remain unreconciled (blocker B10).
## Correction lane — baseline mechanical

| task_id | type | state | worktree | branch | base_sha | head_sha | routing_class | result | next action |
|---|---|---|---|---|---|---|---|---|---|
| correct-baseline-mechanical | correct | CLOSED — BLOCKED | /private/tmp/shipit-correct-baseline (retained) | correct/baseline-mechanical | 0d5d132 | 07c48ed | STANDARD | `CORRECTION_BLOCKED` — B1/B2/B3/M2/M3 all cleared; A and B unmeetable in OWNED_PATHS | human must rule on Blocker A (CI analyze gate) and Blocker B (coupled credential pair) |

Commits on top of the unrevised `0d5d132`: `dae3d68` (B1, M2) · `96928ed` (M3) ·
`d371265` (B3) · `07c48ed` (B2). 49 files, +995/-1689.

## Analysis cleanup — APPROVED

| task_id | type | state | worktree | branch | base_sha | head_sha | routing_class | result | next action |
|---|---|---|---|---|---|---|---|---|---|
| correct-analysis-cleanup | correct | CLOSED — APPROVED | /private/tmp/shipit-analysis-cleanup (retained) | correct/analysis-cleanup | 07c48ed | 6f5a693 | STANDARD | `CORRECTION_COMPLETE` — 337/339 cleared, `READY_FOR_FOCUSED_REVIEW: YES` | merged into comment correction below |
| focused re-review (F/R-1) | re-review | CLOSED — NOT APPROVED | read-only | (detached) | 07c48ed | 6f5a693 | PRECISION | `DO_NOT_APPROVE_CORRECTIONS` — 337 fixes CONFIRMED clean; blocked only on 2 false code comments | corrected below |
| correct-analysis-comments | correct | CLOSED — APPROVED | /private/tmp/shipit-analysis-cleanup | correct/analysis-cleanup | 6f5a693 | 38768d0 | CHEAP_READ | `CORRECTION_COMPLETE` — comment-only, 0 non-comment lines (mechanically proven) | merged into re-review below |
| focused re-review (F/R-2) | re-review | CLOSED — APPROVED | read-only | (detached) | 6f5a693 | 38768d0 | CHEAP_READ | `APPROVE_CORRECTIONS` — no blockers, `READY_FOR_MERGE: YES` | correction loop closed |

`correct/analysis-cleanup` @ `38768d0` is now **CI-green**: `dart analyze` exit 0 in all 16
packages, `melos run analyze` SUCCESS, `melos run format` SUCCESS, `flutter analyze` "No issues
found!", `flutter test` 190/190, `melos run test` SUCCESS, `flutter build web` exit 0.
Two `deprecated_member_use` infos on `WorkItemState.done` remain by deliberate STOP; they are
gate-neutral and `workflow_engine` still exits 0.

## Queued — authorised by the human, not yet dispatched

| item | scope | closes |
|---|---|---|
| credential / port lane | `apps/server/config/**`, `apps/server/docker-compose.yaml`, `.github/workflows/integration.yaml`, `apps/server/tool/seed_overview_qa.sql` | Blocker B; the `control_plane_test_pw` coupling; the 9090 vs 9099 mismatch; H1–H3 (never-executed migrations, via `dart test test/integration/` against real Postgres) |

## New product decisions surfaced, not yet filed

- `ControlPlaneRepository.addHumanBaselineClaim` returns a fabricated `DecisionView`
  (`baseline-claim:<µs>` id exists nowhere server-side, hardcoded `status: 'pending'`,
  `options: []`). PRODUCT decision — changes a returned payload.
- `WorkItemState.done` cannot be made lint-clean without dropping the enum member and handling
  legacy `'done'` at `fromWire`. PRODUCT decision.
- `AGENTS.md` § Product-specific policy is still fully `TBD` — no declared validation gate,
  path ownership map, or environment/deployment strategy. This is the root cause of the
  analyzer debt having accumulated untracked.
