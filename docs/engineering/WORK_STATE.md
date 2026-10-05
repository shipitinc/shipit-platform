# WORK_STATE.md — Product Repository (instantiated from framework)

Manager-owned lifecycle ledger for `aef-orchestrator`. Git is authoritative for code
state; this file is bookkeeping and never authorizes a gate.

## Current state
- Status: HUMAN_DECISION_REQUIRED (blocked in Phase 0 — Foundation prerequisites)
- Active workflow orchestrator: `orchestrator-main` (this session)
- Current lifecycle step (see framework WORKFLOW): Phase 0 Foundation, stopped before
  any dispatch. No design, implementation, QA, or deployment lane has been dispatched
  for the current feature.

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
STATE: HUMAN_DECISION_REQUIRED
OWNERSHIP: none declared — no writer dispatched
LANE: (none dispatched)
REVIEW_RESULT: n/a
QA_RESULT: n/a
DEPLOYMENT_RESULT: n/a
BLOCKERS:
  - type: HUMAN_DECISION
    decision_id: 130f3a7e-c364-4c1e-acd5-409d7af80675
    reason: >-
      No committed product baseline exists. ~390 product files exist only as
      uncommitted working-tree changes; no commit on any branch or in origin
      contains `ControlPlaneRepository.createProduct` or
      `apps/control_plane/lib/shared/form_primitives.dart`. `aef-orchestrator` §4
      precondition 6 cannot be satisfied, so no isolated lane worktree can contain
      the product.
  - type: BASELINE_GATE_FAILURE
    reason: >-
      `flutter analyze` in `apps/control_plane` — the only tree that contains the
      product — exits 1 with 3 `undefined_annotation` errors in
      `lib/data/client_provider.dart` (`JS` x2, `anonymous` x1). No lane can satisfy
      an "analyze passes with zero errors" criterion, and no reviewer can verify it.
  - type: CONFLICTING_SOURCES
    reason: >-
      `apps/control_plane/lib/features/products/add_product_page.dart` — the exact
      file two of the four feature items must edit — exists as 5 mutually divergent
      uncommitted variants (canonical checkout 1117 lines plus 4 lane worktrees),
      none committed and none arbitrated by a persisted review result.
DECISIONS:
  - open: 130f3a7e-c364-4c1e-acd5-409d7af80675
DEPENDENCIES:
  - Resolution of 130f3a7e before any production-writing lane.
SAFE_PARALLEL: none — every remaining item in this feature writes production source or
  agent-facing infrastructure documentation and therefore needs a committed baseline.
NEXT_AUTOMATIC_ACTION: On resolution of 130f3a7e, re-verify `flutter analyze` and
  `git worktree list`, then dispatch Phase 1 lanes per `aef-run-feature`.
SELF_EDITS: none to production source. Bookkeeping only, per `aef-orchestrator` §2
  "Workflow bookkeeping": `docs/engineering/WORK_STATE.md`,
  `docs/engineering/dispatch/LANES.md`, `docs/engineering/dispatch/DECISIONS.md`, and
  the Human Decision object under `.decisions/`.
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
    project declares "Required validation gates: TBD".
  - Repository integrity note: root `AGENTS.md` § Product-specific policy is unfilled,
    so there is no project-declared path ownership map and no project-declared
    environment/deployment strategy. Prior-session dispatch prompts cited
    `AGENTS.md §2 Dart Conventions`, `§8 Forbidden Patterns` and
    `§13 Penpot credentials`; **none of those sections exist** in this repository's
    `AGENTS.md` (71 lines, framework template).

---

## WORK_ITEM: Add Product page UI implementation (prior session) — ABANDONED/RESUMABLE
STATE: IMPLEMENTATION_BLOCKED
BLOCKERS:
  - type: BASELINE_MISSING — same root cause as 130f3a7e.
  - type: LEDGER_UNTRUSTWORTHY — zero persisted `report.md` / `state.json`; the
    `review-add-product` and `integrate-add-product` lanes were dispatched without a
    parsed `IMPLEMENTED` result or independent approval and are void.
NOTES:
  - `implement-add-product` independently reported `RESULT: IMPLEMENTATION_BLOCKED`
    (verified in `/private/tmp/shipit-implement-add-product/IMPLEMENTATION_REPORT.md`)
    because `createProduct` and `form_primitives.dart` were absent from its worktree.
  - Nothing was ever merged. `main` is at 693cfbc and is 1 commit ahead of
    `origin/main` (ea9b03d).

## Framework provenance
- Framework revision (authoritative): 693cfbc29e75
- Framework version (human-readable metadata): TBD
- Recorded in this product repo's `framework-manifest.yaml`. The manifest stores **provenance only**
  plus per-artifact baseline hashes; local modifications are **derived** from hash comparison.
  Upgrades are reviewable, isolated 3-way merges with no runtime dependency on the framework repo.