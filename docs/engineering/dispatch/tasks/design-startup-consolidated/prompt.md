# Dispatch — design-startup-consolidated

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: design-startup-consolidated
TASK_TYPE: design-produce
FEATURE: Bootstrap as a compose service plus a server startup that boots a chain-migrated database
AREA: docker/compose.qa.yaml + server startup ordering + run mode
WORKTREE: /private/tmp/shipit-design-startup2
BRANCH: design/startup-consolidated
BASE_SHA: a8a990b
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-startup-consolidated/**
READ_ONLY_PATHS:
  - apps/server/tool/schema_bootstrap.dart
  - apps/server/tool/schema_bootstrap.sql
  - apps/server/tool/verify_schema_bootstrap.sh
  - apps/server/migrations/**
  - apps/server/config/**
  - docker/**
  - Makefile
  - .github/workflows/integration.yaml
  - docs/deployment/local-qa.md
  - .decisions/6d2bfffe-1631-498a-b053-4edaf8bd3048.yaml
  - .decisions/4078cd9d-5c5d-430b-b83c-64133e20b0f1.yaml
  - .decisions/02a99cb6-b9c3-40b7-976d-227afce23ff0.yaml
  - docs/engineering/dispatch/tasks/design-qa-startup-restructure/DESIGN_REVISION.md
PROHIBITED_PATHS:
  - apps/server/**
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
  One Design Revision covering both the bootstrap compose service and the server startup, with
  ordering that boots a chain-migrated database, objects guaranteed present before the server,
  explicit project naming, idempotence, and a two-directional verification plan.
VALIDATION_COMMANDS:
  - docker compose -f docker/compose.qa.yaml config --no-interpolate
  - bash apps/server/tool/verify_schema_bootstrap.sh
ROUTING_CLASS: PRECISION
```

---

## Authority — two decisions, read both first

- `4078cd9d-5c5d-430b-b83c-64133e20b0f1` **RESOLVED / OPTION_B** — make the schema bootstrap a **compose
  service**. Fix the cause, not the symptom.
- `02a99cb6-b9c3-40b7-976d-227afce23ff0` **RESOLVED / OPTION_C** — return to the `6d2bfffe` OPTION_B
  startup restructure.

**These two are one system.** A compose service applying the bootstrap *before* the server makes the
presence of the six hand-maintained objects **deterministic rather than advisory**. That removes the
dependence on an operator, a run mode, or an analyzer comparison. With the objects guaranteed present,
whether the analyzer is fatal in QA stops being load-bearing — which is what makes the startup restructure
workable at all.

## What has already been rejected — do not re-propose it

- **Design Revision F38E4B34** — rejected at Gate D4. **Not revived as-is.** It may not be cited as
  authority, though its *verified root-cause analysis* is carried forward below as input.
- **The Protocol override** (`getTargetTableDefinitions()`) — **SUPERSEDED and DROPPED, not deferred.**
  With a compose service guaranteeing the objects it has no remaining benefit and would add a maintenance
  surface. Do not carry it forward.
- **The `definition.sql` premise is FALSE.** Verified against pinned Serverpod 3.4.13:
  `verifyDatabaseIntegrity` (`migration_manager.dart:311-312`) compares the live database against
  `session.db.serializationManager.getTargetTableDefinitions()` — the generated Dart protocol.
  `definition.sql` appears nowhere in that path. Do not design around changing it.
- **The analyzer is ONE-DIRECTIONAL.** `like()` is `liveTable.like(target)`, iterating LIVE indexes and
  looking each up in the target (`extensions.dart:120-135`), so `Missing Index` means *missing from the
  model*. There is **no reverse loop**, so the analyzer can **never** report a modelled object missing from
  the database. Do not claim otherwise; that error was already made once and corrected.

## Carry this forward — verified root-cause analysis, re-verify it yourself

`verifyDatabaseIntegrity` is called at `serverpod.dart:882` **outside** the `if (applyMigrations)` guard,
which is why omitting `--apply-migrations` produced an identical failure. The sole fatal branch is
`config.runMode == 'development'` at `:894`. Every `runMode` consumer in Serverpod 3.4.13 is an equality
test against `development`; there is no exhaustive switch. The bootstrap tool already runs
`Serverpod(['-m','test', …])`, so it has always tolerated the analyzer mismatch — only the server ran in
`development`. Verify against the pinned version; do not take it on trust.

## What your design must resolve

1. **The bootstrap compose service.** Shape, command, and how it signals completion. It must apply the
   six objects and exit 0, and it must gate the server's start.
2. **Ordering without a circular dependency.** The bootstrap runs `dart run
   tool/schema_bootstrap.dart` *inside a container built from the server image*, but the server container
   is the thing that fails. Show how the service and the server sequence without a cycle.
3. **Run mode for the server**, and the evidence for it. This is where the analyzer stops gating. State
   the change in observable behaviour plainly.
4. **Idempotence and repeat starts.** A stack start with the objects already present must succeed; a
   start with them absent must apply them. Both directions.
5. **Compose project naming.** `docker/compose.qa.yaml` declares **no** top-level `name:`, so it resolves
   to project `docker` — which **is the live QA stack's project**. This is a hazard, not a detail. Your
   design must name projects explicitly and must never rely on the default. Read `AGENTS.md` § Shared
   Docker state and § Test resource hygiene first.
6. **Mutating-behaviour disclosure.** A stack start will now **apply schema objects** — a deliberate
   change to live-stack behaviour. State it as such.
7. **DL-2 closed, and honestly.** Claim the compose service *fixes* the unenforced-schema false
   assurance. Do **not** claim the analyzer detects a missing object; it cannot.
8. **Verification plan, two directions.** (a) A chain-migrated database boots. (b) A database missing the
   objects has them applied by the service before the server starts. A fresh QA database cannot be the
   only evidence — the reproduction must happen in a **disposable** environment, never the live stack.
9. **Rollback.** How to revert, and what happens to an environment already carrying the objects.
10. **The guard.** `verify_schema_bootstrap.sh` asserts two wiring sites today and must become three, or
    the guard reads as coverage over an unenforced stack. State exactly which of its checks change and why.
    Run it and report.
11. **Production run mode — UNRESOLVED and promotion-blocking.** Nothing in this repository establishes
    whether production runs in `development` mode. If it does, the analyzer becomes a live boot gate there
    for the first time. Record it as a promotion blocker with a named owner. Do not guess.
12. **CI parity.** `.github/workflows/integration.yaml` already applies the bootstrap and is correct. Do
    not diverge local, CI and QA behaviour.

## Hard constraints

- **No production source, migration, CI, or compose change.** `OWNED_PATHS` is your design artifacts only.
  Proposed diffs go **in the document as text**, never applied. `git diff` must be empty at the end.
- Read `docker/**` as **text**. Do **not** start a stack to find out what it does.
- The only sanctioned way to obtain a real database is `make test-integration` (disposable Postgres under
  compose project `shipit_integration_<pid>`, self-cleaning on success, failure and interrupt).
- **Never safe, for any lane:** `make clean`, `make test-env-down`, `make e2e-down`, and any bare
  `docker compose … down -v` without explicit `-p <project>`. These resolve to project `docker`.
- `docker compose … config` is a read-only interpolation and IS permitted. Note that `config` exits 1 on
  the gitignored `.env`; `--no-interpolate` exits 0. Report rather than "fixing" it.
- Keep the runbook invariant and recovery instruction in `docs/deployment/local-qa.md` **regardless of
  outcome** — a compose file alone does not make the constraint discoverable to an operator.

## Deliverable

A Design Revision under your task directory per `DESIGN_GOVERNANCE.md` covering all twelve items, with a
**proposed diff as text**. Include `RISK_LEVEL` with rationale, per-constraint traceability, and an
explicit statement of which guard assertions change. Note the scale is UI-oriented; state your mapping
rather than adopting a level silently.

## Other lanes

- `review-fix-golden-ci-environment` is a read-only focused review of `apps/control_plane/test/**` and
  `.github/workflows/**`. You own only your design artifacts. **No path overlap.**
- Manager holds `LANES.md` / `WORK_STATE.md` / `.decisions/**`.

Report `SAFE_PARALLEL_WORK` and `PROHIBITED_PARALLEL_WORK`. Report
`READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES`. You cannot approve this.