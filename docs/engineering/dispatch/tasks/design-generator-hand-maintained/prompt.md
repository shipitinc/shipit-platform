# Dispatch — design-generator-hand-maintained

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: design-generator-hand-maintained
TASK_TYPE: design-produce
FEATURE: Design making the migration tooling account for hand-maintained objects so definition.sql includes them
AREA: apps/server migration tooling + schema bootstrap contract
WORKTREE: /private/tmp/shipit-design-generator
BRANCH: design/generator-hand-maintained
BASE_SHA: a8a990b
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-generator-hand-maintained/**
READ_ONLY_PATHS:
  - apps/server/tool/schema_bootstrap.dart
  - apps/server/tool/schema_bootstrap.sql
  - apps/server/tool/verify_schema_bootstrap.sh
  - apps/server/migrations/**
  - apps/server/config/**
  - docker/compose.qa.yaml
  - docker/Dockerfile.server
  - Makefile
  - .github/workflows/integration.yaml
  - docs/deployment/local-qa.md
  - .decisions/30c00e6e-4168-44e0-8d1e-34d7de7e4c46.yaml
  - .decisions/6d2bfffe-1631-498a-b053-4edaf8bd3048.yaml
  - docs/engineering/dispatch/tasks/design-qa-startup-restructure/DESIGN_REVISION.md
PROHIBITED_PATHS:
  - apps/server/migrations/**
  - apps/server/lib/**
  - apps/control_plane/**
  - packages/**
  - docker/**
  - .github/workflows/**
  - .decisions/**
  - docs/adr/**
  - .agents/**
  - .claude/**
  - .junie/**
  - .opencode/**
ACCEPTANCE_CRITERIA: >
  A Design Revision specifies how definition.sql comes to account for the hand-maintained objects
  so Serverpod's analyzer enforces rather than rejects them, with the generator-change surface,
  the DL-2 compose consequence, CI parity, and a rollback/recovery story. No implementation.
VALIDATION_COMMANDS:
  - bash apps/server/tool/verify_schema_bootstrap.sh
ROUTING_CLASS: PRECISION
```

---

## Authority — and the reversal you must know about

Two decisions, and the second reverses the first:

- `6d2bfffe-1631-498a-b053-4edaf8bd3048` chose **OPTION_B** (restructure server startup so the
  analyzer stops gating). That object is now marked **SUPERSEDED IN PART**.
- `30c00e6e-4168-44e0-8d1e-34d7de7e4c46` chose **OPTION_C** at Gate D4, **rejecting** Design Revision
  F38E4B34 and **reversing** 6d2bfffe: the human kept the analyzer as a boot gate.

So the design you produce is the path 6d2bfffe itself offered as OPTION_C and originally classified
**HIGH** risk, which the human first declined and has now chosen. Read both decision objects before
starting. This is the most consequential design in the current work item.

## The fault

A database carrying the hand-maintained objects makes the Serverpod server refuse to boot:

```
Table "design_revision" is not like the target database:
 - Missing Index "design_revision_approved_unique_per_work_item".
Table "product_credential" is not like the target database:
 - Missing Index "product_credential_active_repository_unique".
```

Both indexes **exist** in the live database with correct definitions (verified in `pg_indexes`). The cause
is structural: they are hand-maintained objects the model-driven generator cannot render, so they live in
`tool/schema_bootstrap.sql` and the migration chain and can never appear in the generated
`definition.sql`. Serverpod compares the live database against the latest `definition.sql` and exits 1 on
mismatch.

**Carry this forward from F38E4B34** — it is verified root-cause analysis and it is your best input:
`verifyDatabaseIntegrity` is called at `serverpod.dart:881` **outside** the `if (applyMigrations)` guard
(which is why omitting `--apply-migrations` produced an identical failure), and the sole fatal branch is
`config.runMode == 'development'` at `:894`. Every `runMode` consumer in Serverpod 3.4.13 is an equality
test against `development`; there is no exhaustive switch. The bootstrap tool already runs
`Serverpod(['-m','test', …])`, so it has always tolerated the mismatch — only the server ran in
`development`. Verify these claims yourself against the pinned Serverpod version; do not take them on
trust.

## What your design must resolve

1. **How does `definition.sql` come to account for the hand-maintained objects?** This is the core. If
   the generator cannot render them, what is the actual mechanism — post-generation injection, a
   generator extension point, a different target the analyzer reads, or something else? Be concrete and
   name the exact file and hook.
2. **The generator-change surface.** Which parts of migration tooling change, and what is the blast
   radius? This tooling governs **every** environment, including production. Enumerate what could break
   in a database that is currently correct.
3. **DL-2, which becomes mandatory under your design.** `docker/compose.qa.yaml` applies **no** bootstrap
   at all — zero references under `docker/`. Today a fresh QA database is **silently unenforced**:
   analyzer-clean while missing all six hand-maintained objects, so the analyzer passing is evidence of
   an un-enforced schema rather than a correct one. Under your design, once `definition.sql` includes
   these objects, a fresh QA database **without** the bootstrap will fail the analyzer. That converts a
   false assurance into a loud failure — better, but still a failure, so making `compose.qa.yaml` apply
   the bootstrap becomes **mandatory for QA to boot at all**, not merely desirable. Treat it as in scope.
4. **CI parity.** `.github/workflows/integration.yaml` already applies the bootstrap and is correct. Your
   change must not diverge local, CI and QA behaviour.
5. **Ordering, idempotence, and repeat runs.** Restarts must be safe whether or not the bootstrap has run.
6. **Rollback and recovery.** What happens to an environment already carrying these objects if the
   generator changes? What happens if a future migration needs a hand-maintained object added or dropped?
   How is the contract kept true over time rather than by one-off intervention?
7. **Verification plan.** How is it proved that (a) a chain-migrated database now boots, and (b) a
   database **missing** the objects is now correctly rejected? Both directions must be shown, or the
   change has traded one failure for the other. A fresh QA database cannot be the only evidence.
8. **Production promotion.** State plainly what changes for a deployed artifact and what needs human
   authorisation at promotion.

## Hard constraints

- Read `AGENTS.md` § Shared Docker state and § Test resource hygiene before proposing anything that runs a
  compose command. `docker/compose.qa.yaml` declares **no** top-level `name:` and therefore resolves to
  project `docker`, which **is the live QA stack's project**. Never rely on the default project name.
- Read compose files and Dockerfiles as **text**. Do **not** start a stack to find out what it does.
- The only sanctioned way to obtain a real database is `make test-integration` (disposable Postgres under
  compose project `shipit_integration_<pid>`, self-cleaning).
- **Never safe, for any lane:** `make clean`, `make test-env-down`, `make e2e-down`, and any bare
  `docker compose … down -v` without explicit `-p <project>`.
- **No production source, migration, or CI change.** `OWNED_PATHS` is your design artifacts only. Proposed
  diffs go **in the document as text**, never applied.
- `bash apps/server/tool/verify_schema_bootstrap.sh` is read-only text verification and is permitted; run
  it and report its result. It asserts today that "no generated definition.sql claims these objects" —
  **your design will deliberately falsify that assertion.** Say explicitly which of the guard's checks
  must change and why, rather than leaving the guard and the design in contradiction.

## Deliverable

A Design Revision under your task directory following `DESIGN_GOVERNANCE.md`: problem statement with
evidence, the mechanism, generator-change surface, DL-2 treatment, CI parity, ordering/idempotence,
rollback and long-term contract, verification plan covering both directions, production-promotion impact,
and a **proposed diff as text**. Include `RISK_LEVEL` with rationale and per-constraint traceability.
State which existing guard assertions your design invalidates.

## Other lanes

- `correct-golden-ci-environment` owns `apps/control_plane/test/**` and `.github/workflows/**` as a
  production writer. You own only your design artifacts. **No path overlap.**
- Manager holds `LANES.md` / `WORK_STATE.md` / `.decisions/**`.

Report `SAFE_PARALLEL_WORK` and `PROHIBITED_PARALLEL_WORK`. Report
`READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES`. You cannot approve this.