# WORK_STATE.md — Product Repository (instantiated from framework)

Manager-owned lifecycle ledger for `aef-orchestrator`. Git is authoritative for code
state; this file is bookkeeping and never authorizes a gate.

## Current state
- Status: INTEGRATION_BLOCKED (baseline created and verified; integration parked)
- Active workflow orchestrator: `orchestrator-main` (this session)
- Current lifecycle step (see framework WORKFLOW): Phase 0 Foundation complete;
  integration-readiness verification returned `RESULT: INTEGRATION_BLOCKED`. No feature
  lane has been dispatched for FEATURE c46b6807.

## Architecture
- Decision record(s): none for this work item. Baseline/repository-state decision is
  pending as Human Decision `130f3a7e-c364-4c1e-acd5-409d7af80675`.

## Design
- Design Contract: none for this work item.
- Prior work item "Add Product page UI implementation" produced
  `DESIGN_REVISION_add_product.md`, `DESIGN_BRIEF_add_product.md` and
  `DESIGN_DISCOVERY_add_product.md` as **untracked files inside lane worktrees only**.
  They were never committed, never persisted as reports, and were never independently
  reviewed to a parseable result. They are not an approved Design Contract.

## Infrastructure / CI-CD / Deployment
- Environments: undeclared in `AGENTS.md` § Product-specific policy (still `TBD`).
  Observed in-repo, unverified: `docker/compose.qa.yaml` (QA, local manual),
  `docker/compose.test.yaml` (isolated test env, ephemeral DB, ports 8083/8082/5433),
  `docker/compose.e2e.yaml` (legacy), driven by `make qa-*` / `make test-env-*` /
  `make e2e-*`. `.github/workflows/` holds `ci.yaml`, `infrastructure.yaml`,
  `integration.yaml`, `macos-workers.yaml`, `release.yaml`.
- Deployment strategy & rollback: undeclared (`TBD`).

---

## WORK_ITEM: FEATURE c46b6807 — favicon, Add-a-product row + Register button, isolated test env
STATE: INTEGRATION_BLOCKED (inherits baseline blocker)
OWNERSHIP: none declared — no writer dispatched
LANE: (none dispatched)
REVIEW_RESULT: n/a
QA_RESULT: n/a
DEPLOYMENT_RESULT: n/a
BLOCKERS:
  - type: UPSTREAM_INTEGRATION_BLOCKED
    lane: integrate-baseline-product
    result: INTEGRATION_BLOCKED
    reason: >-
      The baseline commit `0d5d132` (585 files changed, +203997/-4838; 389 added,
      194 modified, 1 deleted, 1 renamed) is deterministically sound — 0 analyzer
      errors, 190/190 tests, `flutter build web` succeeds, clean fast-forward from
      `main`, no secrets or build artifacts in the diff — but carries no independent
      engineering review. Per `AGENTS.md`, integration is allowed only for
      independently reviewed results. See `docs/engineering/dispatch/tasks/integrate-baseline-product/`.
  - type: CONFLICTING_SOURCES
    reason: >-
      Five divergent copies of `apps/control_plane/lib/features/products/add_product_page.dart`
      existed uncommitted. `0d5d132` now pins ONE authoritative variant (canonical
      checkout, 1117 lines), so this is resolved for code purposes; the four superseded
      lane-worktree variants and four stranded design/QA artifacts still need reconciling.
DECISIONS:
  - resolved: 130f3a7e-c364-4c1e-acd5-409d7af80675 (INFRASTRUCTURE, OPTION_C)
  - open: 6f1c9d84-3a5e-4c17-9b62-1e8a4f70d5c3 (OTHER_CONSEQUENTIAL — may an
    explicitly-unreviewed baseline land on `main` as the isolation anchor?)
DEPENDENCIES:
  - Independent review of `0d5d132` before integration.
  - Resolution of the open decision above before any merge or push.
SAFE_PARALLEL: read-only review lanes on `0d5d132`; AGENTS.md policy fill-in; stale
  worktree reconciliation.
NEXT_AUTOMATIC_ACTION: independent engineering review of `0d5d132`, then human decision,
  then re-dispatch the integrator.
SELF_EDITS: >-
  §2 "Mechanical config fixes to an already-declared gate" was **not** available — no gate
  is declared. The `client_provider.dart` JS-interop fix was made under explicit human
  authorization (HD 130f3a7e OPTION_C), NOT under the §2 escape hatch, and was
  independently reviewed (`RESULT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP`) before being
  included in the baseline. Bookkeeping edits under §2 "Workflow bookkeeping":
  `docs/engineering/WORK_STATE.md`, `docs/engineering/dispatch/LANES.md`,
  `docs/engineering/dispatch/DECISIONS.md`, `docs/engineering/dispatch/tasks/*/prompt.md`,
  and the Human Decision object under `.decisions/`.
CONVENTIONS_USED: (project declares none — root `AGENTS.md` § Product-specific policy
  is `TBD` throughout, so `aef-orchestrator` §3 defaults apply)
  - SUBTASK_PROMPT_TEMPLATE: `.agents/skills/aef-orchestrator/templates/subtask-prompt.md`
  - SUBTASK_REPORT_TEMPLATE: `.agents/skills/aef-orchestrator/templates/subtask-report.md`
  - DISPATCH_STATE_DIR: `docs/engineering/dispatch/`
  - DECISION_DIR: `.decisions/`
  - WORKFLOW_STATE: `docs/engineering/WORK_STATE.md`
  - ISOLATION_CONVENTION: `git worktree add -b <branch> <abs-path> <base>`
  - MAX_CONCURRENT_WRITERS: 3
  - ROUTING_CLASS: no project routing policy declared, so the §12
    CHEAP_READ | STANDARD | PRECISION table applies directly
  - Required validation gates: UNDECLARED. Observed candidates in-repo: `melos`
    `analyze` / `format` scripts in root `pubspec.yaml`, `flutter analyze`,
    `dart format --set-exit-if-changed`. **This gap is itself unresolved** — the
    project declares "Required validation gates: TBD". Measured on `0d5d132`:
    `dart format --output=none --set-exit-if-changed .` FAILS on 47 files
    (30 under `apps/`, 17 under `packages/`), so adopting a format gate as-is
    would require either a 47-file formatting commit or an explicit recorded debt.
    `flutter analyze` in `apps/control_plane` is 0 errors / 34 issues / exit 1
    (33 info + 1 pre-existing warning at `lib/data/control_plane_repository.dart:951`).
    `flutter test` is 190/190. `flutter build web` succeeds.
  - Toolchain fidelity: `.fvmrc` pins Flutter **3.44.0**; all gates in this session ran
    on **3.44.7** (Dart 3.12.2). Minor, unverified fidelity gap.
  - Repository integrity note: root `AGENTS.md` § Product-specific policy is unfilled,
    so there is no project-declared path ownership map and no project-declared
    environment/deployment strategy. Prior-session dispatch prompts cited
    `AGENTS.md §2 Dart Conventions`, `§8 Forbidden Patterns` and
    `§13 Penpot credentials`; **none of those sections exist** in this repository's
    `AGENTS.md` (71 lines, framework template).

---

## WORK_ITEM: Product baseline — INTEGRATION_BLOCKED
STATE: INTEGRATION_BLOCKED
LANE: integrate-baseline-product, type integrate, worktree canonical checkout,
  branch baseline/product-2026-10-05, base_sha bfbbd68, head_sha 0d5d132, routing STANDARD
REVIEW_RESULT: >-
  Partial. `review-runtime-config-interop` returned
  `RESULT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP` (no blockers, CORRECTION_REQUIRED: NO)
  for the runtime-config interop change only. The other 584 files are unreviewed.
DEPLOYMENT_RESULT: n/a
BLOCKERS:
  - type: MISSING_INDEPENDENT_REVIEW
    detail: >-
      B1. 585 files / +203997 lines have no independent engineering review. Sole hard
      blocker. Resolution: dispatch `engineering-reviewer` on `0d5d132`.
  - type: LEDGER_INCONSISTENT
    detail: >-
      B2. RESOLVED for this session: the baseline commit had been created while
      `.decisions/130f3a7e...yaml` still read `IN_PROGRESS` with an empty `resolution`
      block, so `0d5d132` carried no committed authorization. The RESOLVED
      OPTION_C state is now committed alongside this ledger.
  - type: MIGRATION_UNVALIDATED
    detail: >-
      B3. `20260925181113034/migration.sql` becomes an ACTIVE migration at `0d5d132`
      (its directory previously held only `definition.sql`). It creates `defect` and
      `defect_clarification` plus 8 indexes, and has never executed in any environment.
      Must be validated against real Postgres before staging. Not a merge blocker.
  - type: SECURITY_FINDING
    detail: >-
      B4. A hardcoded Postgres superuser password
      (`fd6239170e2e5511e8ac0fa79a03695f28781037d4c8b644`) was removed from
      `apps/server/bin/onboard_shipit_dev.dart` but propagated into a new file,
      `apps/server/bin/test_pod.dart`. Pre-existing at `bfbbd68`, dev-loopback only.
      Whether a committed credential blocks merge is a security-policy call for the
      human. Clean up in a FOLLOW-UP commit; do not rewrite `0d5d132`.
  - type: HYGIENE
    detail: >-
      B5. `apps/server/lib/src/endpoints/human_direction_endpoints.dart.bak`
      (247-line editor backup) committed as a new file. Follow-up removal.
      B7. New `.gitignore` entries `**/test/failures/` and `.idea/` are ineffective
      for already-tracked files (80 PNGs + `.idea/`). Follow-up `git rm --cached`.
DECISIONS:
  - resolved: 130f3a7e-c364-4c1e-acd5-409d7af80675
  - open: 6f1c9d84-3a5e-4c17-9b62-1e8a4f70d5c3
DEPENDENCIES: none
SAFE_PARALLEL: >-
  read-only review of `0d5d132`; AGENTS.md policy fill-in; stale worktree reconciliation.
PROHIBITED_PARALLEL: >-
  any merge/push of `0d5d132` to `main` or `origin`; FEATURE c46b6807
  production-writing lanes; staging/production migration runs.
NEXT_AUTOMATIC_ACTION: >-
  Re-dispatch `integrator` once `0d5d132` is independently reviewed and the open decision
  is resolved. Integration authority remains with the human; fast-forward only, never
  rebase/squash, so the reviewed `client_provider.dart` provenance survives.

## Known leaked processes (not terminated by any lane)
- Four orphaned `flutter_tester` processes — PIDs 77709, 77710, 77711, 78174 — started
  13:41–13:42, all referencing the canonical checkout. Flagged by
  `integrate-baseline-product`; outside that lane's authority so left running.
  Safe for the human to `kill` them.

## Framework provenance
- Framework revision (authoritative): 693cfbc29e75
- Framework version (human-readable metadata): TBD
- Recorded in this product repo's `framework-manifest.yaml`. The manifest stores **provenance only**
  plus per-artifact baseline hashes; local modifications are **derived** from hash comparison.
  Upgrades are reviewable, isolated 3-way merges with no runtime dependency on the framework repo.