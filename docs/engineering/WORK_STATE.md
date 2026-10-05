# WORK_STATE.md — Product Repository (instantiated from framework)

Manager-owned lifecycle ledger for `aef-orchestrator`. Git is authoritative for code
state; this file is bookkeeping and never authorizes a gate.

## Current state
- Status: DO_NOT_MERGE — parked on baseline 0d5d132
- Active workflow orchestrator: `orchestrator-main` (this session)
- Current lifecycle step (see framework WORKFLOW): Phase 0 Foundation. The baseline that
  Foundation required now exists and is verified functional in isolation, but independent
  review returned `RESULT: DO_NOT_MERGE` with `HUMAN_DECISION_REQUIRED: YES`. No feature lane
  has been dispatched for FEATURE c46b6807; none can be until a reviewed, buildable BASE_SHA
  exists on `main`.

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
STATE: DO_NOT_MERGE (inherits baseline blockers — no buildable reviewed BASE_SHA exists)
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
  - open: 70b47372-8814-4098-81b2-6614497bad12 (OTHER_CONSEQUENTIAL — premise refuted by review)
  - open: 048f3367-5836-43c8-af05-747dbc9d3afd (SECURITY — credential + API authentication)
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

## WORK_ITEM: Product baseline — DO_NOT_MERGE
STATE: DO_NOT_MERGE (review-baseline-0d5d132)
LANE: review-baseline-0d5d132, type review, worktree /private/tmp/shipit-review-baseline
  (created and removed), branch detached at 0d5d132, base_sha bfbbd68, head_sha 0d5d132,
  routing PRECISION
REVIEW_RESULT: >-
  RESULT: DO_NOT_MERGE. CORRECTION_REQUIRED: YES. HUMAN_DECISION_REQUIRED: YES.
  Report: `docs/engineering/dispatch/tasks/review-baseline-0d5d132/report.md`.
  Explicitly a RISK-STRATIFIED review, not line-by-line; the reviewer published an
  explicit coverage statement listing what it did NOT review.
GATES_AT_0d5d132:
  - "flutter pub get": pass
  - "flutter analyze --no-pub (apps/control_plane)": 0 errors, 33 info, 0 warnings, exit 1
  - "flutter test --no-pub": 190/190 pass
  - "flutter build web --no-pub": pass (needed one retry; first attempt SIGTERM from host load)
  - "dart analyze packages apps/server": **FAIL — exit 3, 10 compile errors** (no prior lane ran this)
  - "melos run format equivalent": **FAIL — 40 files across 8 of 17 packages**
BLOCKERS:
  - type: COMPILE_FAILURE
    detail: >-
      B1. `apps/server` does not analyze. 10 errors, all in four dead scratch scripts newly
      added by the baseline and referenced nowhere: `bin/onboard_simple.dart` (6),
      `bin/onboard_direct.dart` (2), `bin/onboard_fixed.dart` (1),
      `bin/add_human_claims_mature.dart` (1). The real entrypoint is `bin/main.dart`
      (`apps/server/pubspec.yaml:49`). CI is red on arrival because
      `.github/workflows/ci.yaml:17` runs `melos run analyze` per package. Fix is mechanical:
      delete or repair the four scripts.
  - type: FORMAT_GATE_FAILURE
    detail: >-
      B2. CI format gate fails on 40 files across agent_runtime (1),
      execution_coordinator (2), platform_contracts (8), product_registry (4), scheduler (1),
      workflow_engine (1), apps/server (9), apps/control_plane (14). Fix is mechanical:
      `dart format lib test` per package. Note melos' format script covers only `lib` and
      `test`, which is why B1's unformatted `bin/` scripts survived.
  - type: SECURITY_FINDING
    detail: >-
      B3. Hardcoded PostgreSQL SUPERUSER password at `apps/server/bin/test_pod.dart:16`.
      Escalated as Human Decision 048f3367.
  - type: SELF_DECLARED_UNMERGEABLE
    detail: >-
      B4. The baseline contradicts its own committed status record.
      `S2_NON_VISUAL_RELEASE_BLOCKER_CLOSURE.md:236-245` ends in
      "## FINAL VERDICT -> RELEASE_CORRECTION_REQUIRED" with three open non-human blockers
      (triage execution path not green; migration clean-chain unproven via stale
      20260927120000000; Phase 6 durable boundary unresolved — ADR 0021 decision and
      confidence semantics), and `:172-181` leaves HUMAN_GOLDEN_REVIEW_REQUIRED,
      HUMAN_DECISION_REQUIRED and HUMAN_SECURITY_DECISION_REQUIRED all OPEN. The tree
      therefore cannot serve as BASE_SHA while it says so.
HIGH:
  - H1. Nine migrations are activated for the first time in 0d5d132, none ever executed. Prior
    lanes described one migration of 2 tables/8 indexes; it is 4 tables/17 indexes. Mechanism
    verified against serverpod-3.4.13 source: `listVersions()` ignores `migration_registry.txt`
    and sorts directories lexically; `_getVersionsToApply` is positional; with no installed
    version only the latest `definition.sql` runs. So a FRESH database never executes them, but
    an EXISTING database runs all nine at once, order-dependent, with zero execution history.
  - H2. Migration-lineage brick unremediated. `migration_manager.dart:169-172` throws when a
    database's recorded version has no directory; the baseline deletes `20260921_defect_tables`
    and had already deleted `20260927120000000` while a test DB still recorded it. Such a
    database cannot start the server at all.
  - H3. Every Postgres-backed durability claim is unverified —
    `S2_NON_VISUAL_RELEASE_BLOCKER_CLOSURE.md:79-84` records Defect, Product Registry and
    Triage PostgreSQL suites as NOT RUN, so the CAS / multi-replica race claims in
    `docs/reports/control-plane-persistence-slice-report.md:274-288` have no evidence.
  - M1. A PRE-EXISTING shipped migration was edited with a factually incorrect rationale
    (`20260920232118956/migration.sql` claims a fresh DB replays migrations in order; per
    serverpod-3.4.13 it does not). Migration-history hash drift plus a false technical claim.
  - M4. The entire control-plane API is unauthenticated (`apps/server/lib/server.dart:71-72`)
    justified by a "SECURITY ASSUMPTION" that appears nowhere in the repository. Escalated as
    Human Decision 048f3367.
DECISIONS:
  - resolved: 130f3a7e-c364-4c1e-acd5-409d7af80675 (INFRASTRUCTURE, OPTION_C)
  - open: 70b47372-8814-4098-81b2-6614497bad12 (OTHER_CONSEQUENTIAL — premise refuted,
    recommendation superseded to OPTION_C)
  - open: 048f3367-5836-43c8-af05-747dbc9d3afd (SECURITY — credential + API authentication)
SAFE_PARALLEL: >-
  B1/B2/M2/M3 are mechanical and need no human judgement — a correction lane may delete the
  four dead scripts, format the 8 packages, remove the `.bak`, and relocate the root report.
  Read-only design/requirement/QA-contract authoring is unblocked. Documentation under `docs/`.
PROHIBITED_PARALLEL: >-
  Any production-writing lane branching from 0d5d132 as BASE_SHA (B1/B2 make the tree CI-red, so
  every such lane's gate fails for reasons outside its own diff). Any lane touching
  `apps/server/bin`, `apps/server/migrations`, `.github/workflows`, `packages/product_registry`,
  `agent_runtime`, `scheduler`, `execution_coordinator`, `control_plane_client`,
  `platform_contracts`, or `apps/server/lib/src/triage`. Any credential rotation. Any merge or push.
NEXT_AUTOMATIC_ACTION: >-
  Dispatch a correction lane for the mechanical findings (B1, B2, M2, M3), then present
  decisions 048f3367 and 70b47372, then establish a real Postgres and run the never-executed
  migration chain (H1-H3) before any staging. Only then scope the remaining review as bounded
  parallel lanes, per the reviewer's proposal.
SELF_EDITS: >-
  Production source: the `client_provider.dart` JS-interop fix, made under explicit human
  authorization (HD 130f3a7e OPTION_C), NOT under the §2 escape hatch, and independently
  reviewed (`APPROVE_WITH_NON_BLOCKING_FOLLOWUP`) before inclusion in the baseline. Bookkeeping
  under §2 "Workflow bookkeeping": `docs/engineering/WORK_STATE.md`,
  `docs/engineering/dispatch/{LANES,DECISIONS}.md`, `docs/engineering/dispatch/tasks/*/{prompt,report}.md`,
  and Human Decision objects under `.decisions/`.

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