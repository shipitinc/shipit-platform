# Dispatch — design-qa-startup-restructure

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: design-qa-startup-restructure
TASK_TYPE: design-produce
FEATURE: Design a server startup sequence where the schema bootstrap runs after the analyzer
AREA: docker entrypoint + compose ordering for the Serverpod server
WORKTREE: /private/tmp/shipit-design-startup
BRANCH: design/qa-startup-restructure
BASE_SHA: 1657082
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-qa-startup-restructure/**
  - docker/**
READ_ONLY_PATHS:
  - apps/server/tool/schema_bootstrap.dart
  - apps/server/tool/schema_bootstrap.sql
  - apps/server/tool/verify_schema_bootstrap.sh
  - apps/server/migrations/20261006150645000/migration.sql
  - apps/server/migrations/20261006150645000/definition.sql
  - docker/compose.qa.yaml
  - docker/Dockerfile.server
  - docker/build-client.sh
  - Makefile
  - .github/workflows/integration.yaml
  - .decisions/6d2bfffe-1631-498a-b053-4edaf8bd3048.yaml
  - docs/deployment/local-qa.md
PROHIBITED_PATHS:
  - apps/server/lib/**
  - apps/server/migrations/**
  - apps/control_plane/**
  - packages/**
  - .github/workflows/**
  - .decisions/**
  - docs/adr/**
  - .agents/**
  - .claude/**
  - .junie/**
  - .opencode/**
ACCEPTANCE_CRITERIA: >
  A Design Revision exists that specifies a server startup sequence in which a chain-migrated
  database boots without data loss, with explicit compose project naming, an ordering argument
  that survives CI and local dev, and a verification plan reproducible in a disposable
  environment. Production-promotion impact is stated explicitly.
VALIDATION_COMMANDS:
  - docker compose -f docker/compose.qa.yaml config
ROUTING_CLASS: PRECISION
```

---

## Authority

Human Decision `6d2bfffe-1631-498a-b053-4edaf8bd3048`, **RESOLVED / OPTION_B — "Restructure server
startup"** — resolved through the structured question UI on 2026-10-08. Read the object first; it is your
authority and it records accepted consequences you must design within.

**This lane produces a DESIGN, not the change.** OPTION_B is production-promotion-affecting, so
independent design review precedes implementation. Do not implement the entrypoint.

Note the human chose this **over the Manager's recommended option** (document plus a preflight check). That
is deliberate: remove the failure entirely rather than make it actionable.

## The fault

A database carrying the hand-maintained schema objects makes the Serverpod server refuse to boot:

```
Table "design_revision" is not like the target database:
 - Missing Index "design_revision_approved_unique_per_work_item".
Table "product_credential" is not like the target database:
 - Missing Index "product_credential_active_repository_unique".
```

Both indexes **exist** in the live database with correct definitions (verified in `pg_indexes`). The cause
is structural: they are **hand-maintained objects the model-driven generator cannot render**, so they live
in `tool/schema_bootstrap.sql` and `migration.sql` and can never appear in the generated
`definition.sql` (0 occurrences, versus 2 in `migration.sql` — `schema_bootstrap.dart`'s own header
documents this). Serverpod compares the live database against the **latest `definition.sql`** target and
exits 1 on mismatch, so a chain-migrated database — one carrying those objects — can never satisfy it.

Confirmed it is **not** `--apply-migrations`: running the server with the flag omitted produced an
**identical** failure, so there is no non-destructive workaround on the current code path. A **fresh**
database has none of the objects, boots clean, and is the shape CI and `make test-integration` produce.

## What your design must resolve

1. **The ordering.** How does the bootstrap run *after* the analyzer passes, given the analyzer is
   Serverpod's own startup gate? Be concrete about the sequence and where each step fails.
2. **The chicken-and-egg.** The bootstrap is a Dart tool run with `dart run tool/schema_bootstrap.dart`
   inside the server container. The container is what fails to start. Show how this is sequenced without a
   circular dependency.
3. **Idempotence and repeat runs.** A restart must be safe whether or not the bootstrap has run, and must
   not re-apply objects it has already applied.
4. **Compose project naming.** This is a hazard, not a detail. `AGENTS.md` § Shared Docker state records
   that `docker/compose.qa.yaml` declares **no top-level `name:`**, so it resolves to project `docker` —
   which **is the live QA stack's project**. Your design must name projects explicitly with `-p` and must
   not rely on the default. Read `AGENTS.md` § Shared Docker state and § Test resource hygiene before
   proposing anything that runs a compose command.
5. **CI parity.** `.github/workflows/integration.yaml` already applies the bootstrap and is correct. Your
   change must not diverge local and CI behaviour.
6. **Failure modes.** What happens on a genuinely broken database? The new sequence must not turn a clear
   error into a hang or a silent skip.
7. **Verification plan.** How do you *prove* a chain-migrated database boots after the change? Note the
   constraint below — this cannot be demonstrated on the current fresh QA database.
8. **Production promotion.** State plainly what this changes in the deployed artifact and what would need
   human authorisation at promotion.

## The verification constraint — do not design around this by ignoring it

**A fresh database does not exhibit the fault**, so the current QA stack cannot validate the fix. The
failing behaviour must be **reproduced first**, in a **disposable** environment — never the live QA stack.
Say in your design how you would produce that reproduction, and treat it as a prerequisite step rather than
an optional verification nicety.

## Hard constraints

- **`AGENTS.md` § Shared Docker state binds you.** You may read `docker/**` as **text** — that is the
  supported way to establish what a stack does. Do **not** start it to find out.
- **The single sanctioned way to obtain a real database is `make test-integration`**, which creates a
  disposable Postgres under compose project `shipit_integration_<pid>` and removes it on success, failure
  and interrupt. Anything else that mutates shared Docker state is out of bounds for this lane.
- **Never safe, for any lane:** `make clean`, `make test-env-down`, `make e2e-down`, and any bare
  `docker compose … down -v` without an explicit `-p <project>`. These resolve to project `docker`, the
  live QA stack.
- Keep the documented invariant and a recovery instruction in `docs/deployment/local-qa.md` as part of the
  design **regardless of the outcome** — a compose file alone does not make the constraint discoverable to
  an operator. That was a standing follow-up in the decision.
- **No production source, migration, or CI change.** `OWNED_PATHS` is design artifacts plus `docker/**`
  for reading and for the Design Revision's proposed diffs **as text**.

## Deliverable

A Design Revision under your task directory, following `DESIGN_GOVERNANCE.md`, containing at minimum:
the problem statement with the evidence above, the proposed sequence, the ordering/idempotence argument, the
compose-project-naming treatment, failure modes, the reproduction prerequisite, the verification plan, the
production-promotion impact, and a **proposed diff as text** for the implementation lane to apply.

Include `RISK_LEVEL` with rationale and per-constraint traceability.

## Other lanes

- `fix-golden-domination-n2` owns `apps/control_plane/test/**` and `.github/workflows/**` as a
  **production writer**. You own `docker/**` and your own design artifacts. **No path overlap.**
- Two design re-reviewers are read-only.
- Manager holds `LANES.md` / `WORK_STATE.md` / `.decisions/**`.

Report `SAFE_PARALLEL_WORK` and `PROHIBITED_PARALLEL_WORK`.

## You cannot approve this

Report `READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES`. An independent `design-reviewer` will verify you, and a
separate `engineering-reviewer` will verify the implementation afterwards.