# Report — fix-design-triggers

Persisted per `aef-orchestrator` §14. Lane: `correction-implementer`.
Worktree `/private/tmp/shipit-triggers` (retained), branch `fix/design-triggers-and-cleanup`.
BASE_SHA `60c8136`, NEW_HEAD `14608dc` (commits `d374ff2`, `14608dc`). Base not rewritten.

## Structured result

```
RESULT: CORRECTION_COMPLETE
CORRECTED_FROM_HEAD: 60c8136
NEW_HEAD: 14608dc
READY_FOR_FOCUSED_REVIEW: YES
```

## Before / after probe — side by side

All probes on disposable databases in the lane's own container `shipit-corr-pg` (tmpfs, port
19501), created and destroyed by the lane.

| | BEFORE (`60c8136`) | AFTER (`14608dc`) |
|---|---|---|
| Fresh DB (latest `definition.sql` only) | objects: **0 rows**, no triggers | `t / t / t` |
| Tamper an APPROVED `design_revision` | `UPDATE 1` → row became **`TAMPERED`** | `ERROR: Cannot modify approved design revision`, row unchanged |
| Chain-migrated DB | objects present, tamper rejected | identical |
| Second approved revision for one work item | — | rejected |
| Self-review insert | — | rejected |

## Mechanism, and why it survives regeneration

The lane first verified Serverpod 3.4.13 extension points against the pinned source and found
**none**: `MigrationManager._loadMigrationSQL` (`migration_manager.dart:194-205`) returns the
single `definitionSql` entry when `fromVersion == null`; the artifact store reads it verbatim;
the CLI writes it with `definitionSqlFile.writeAsString(definitionSql)`
(`generator.dart:543-581`). No hook, no way to make a hand edit stick.

Chosen: a hand-maintained SQL asset plus a Dart applier, wired into CI and the local test path.

- `apps/server/tool/schema_bootstrap.sql` — the DDL, **outside `migrations/`** where
  regeneration cannot reach it. Idempotent (`CREATE OR REPLACE FUNCTION`,
  `CREATE UNIQUE INDEX IF NOT EXISTS`, `DROP TRIGGER IF EXISTS` + `CREATE`), with function bodies
  byte-identical to `migrations/20260920232118956/migration.sql` so fresh and chain enforce the
  same thing.
- `apps/server/tool/schema_bootstrap.dart` — passes `--apply-migrations`, applies the asset, then
  **fails loudly**: 5 objects must exist and 3 mutations must be rejected, or exit 1.

**Regeneration survival proven**: a real `serverpod generate` + `serverpod create-migration` was run
in a throwaway repo copy (creating version `20261005141817106`). The newly generated
`definition.sql` contains **0 occurrences** of all three objects while the asset is untouched. A
fresh DB built from that regenerated `definition.sql` plus the bootstrap rejected tampering.

**Guard**: `apps/server/tool/verify_schema_bootstrap.sh`, wired into the existing `schema-guard` CI
job (`ci.yaml:56`). Asserts asset↔applier agreement, fresh-vs-chain parity (identical object names
**and** identical guarded-column list), that no generated `definition.sql` claims them, and that
both wiring sites invoke it **as a recipe line, not a comment**. Negative-tested 5 ways: dropping
a guarded column, hand-editing a `definition.sql`, unwiring Make, unwiring CI, desyncing the
applier — each fails; restoring passes. The comment-vs-invocation weakness was found by negative
test 3, not by reading.

Manager independently re-ran the guard: exit 0, all 12 assertions OK.

## Cleanup changes per site

| Site | Leak | Fix |
|---|---|---|
| `make test-env-test` | `compose up` left containers + `test_triage_*` volumes; `--abort-on-container-exit` stops but never removes | own project `shipit_test`, `down -v` from `trap EXIT INT TERM`, absolute compose path, cleanup output printed on failure |
| `make e2e-test` | same, plus `triage_repo_e2e`/`triage_workspaces_e2e` | same |
| `make test-integration` (new) | — | own project, disposable Postgres, bootstrap + suite, `down -v` trap |
| `integration.yaml` teardown | `cd docker && docker compose down -v` resolved whatever project that directory named — a real hazard on a self-hosted runner | `-p shipit_test`, `--remove-orphans`, scoped |
| `docker/compose.test.yaml` | — | `postgres_integration` behind an `integration` profile, tmpfs not a volume |
| `run-e2e-tests.sh`, other workflows | **no leak** — creates nothing on the host; browser cache dies with the container | not owned, not changed |

## Ledger — zero leaks

Created then destroyed: 4 probe DBs + container `shipit-corr-pg` (tmpfs, so zero volumes);
copy `/private/tmp/shipit-regen-proof`; 4 `make test-integration` runs. **All three paths
proven**: failure (exit 1), interrupt (SIGINT to process group → suite did not complete, exit 130),
success (exit 0). Verified none remain: containers, volumes, networks, compose projects; ports
19501 and 9199 free. Owner's `control_plane-postgres_test-1` and 6 `partnerhub-*` containers
untouched; 0 probe rows in their DB; no new database ever created in it.

## Two bugs the lane shipped and caught

1. The trap ran after the recipe `cd`-ed to `apps/server`, so the relative compose path failed —
   and `>/dev/null 2>&1 || true` **silently leaked the container**.
2. Its first `AGENTS.md` text recommended exactly that silencing. Corrected in `14608dc`.

Both recorded in `AGENTS.md` so they cannot recur.

## Gates

`melos run format` SUCCESS · `melos run analyze` SUCCESS (2 pre-existing `workflow_engine`
deprecation infos, outside this lane's ownership, non-failing) · `dart test test/integration/`
**157/158** — single failure is `dogfood_shipit_postgres_test.dart:87`
`dogfood expects a git working tree at /private/tmp/shipit-triggers`, the predicted pre-existing
environmental case, no others · guard + `verify:schema-deviations` pass · `passwords.yaml`
gitignored, absent from `git status` and from both commits.

## Files changed (all within OWNED_PATHS)

`apps/server/tool/schema_bootstrap.sql` (new, 138) · `apps/server/tool/schema_bootstrap.dart`
(new, 378) · `apps/server/tool/verify_schema_bootstrap.sh` (new, 200) ·
`.github/workflows/integration.yaml` (+46/-5) · `.github/workflows/ci.yaml` (+15) ·
`Makefile` (+122/-4) · `docker/compose.test.yaml` (+31) · `AGENTS.md` (+25)

## New discoveries

- **RUNTIME_DISCOVERY** — the owner's own `control_plane-postgres_test-1` on 9099 is a fresh-DB
  database and does **not** have `trigger_design_revision_immutability`. It is silently unenforced
  today. It will not self-heal; it needs one `dart run tool/schema_bootstrap.dart` or a rebuild.
  Not touched by the lane.
- **PROJECT_FACT** — Serverpod 3.4.13 has no extension point for extra SQL on a fresh database;
  the only generator escape is content the models express. Hand-maintained DDL must live outside
  `migrations/`.
- **PROJECT_FACT** — Serverpod's `_applyMigrations` only throws `ExitException` in development
  runMode; in test mode a failed migration only prints a warning, so any bootstrap must verify
  independently.
- **RUNTIME_DISCOVERY** — `design_revision_approved_unique_per_work_item` is not in
  `design_revision.spy.yaml`, so `verifyDatabaseIntegrity` prints "Missing Index" on every
  bootstrapped or chain database. Cosmetic, identical on both paths, pre-existing.
- **RUNTIME_DISCOVERY** — `pod.shutdown(exitProcess: false)` leaves timers behind; a tool using it
  must call `exit()` explicitly or the CI step hangs to job timeout.
- **PROJECT_FACT** — a bash trap does not fire while a foreground child runs; cleanup must signal
  the whole process group to look like a real Ctrl-C. Testing teardown with a single-PID signal
  gives a false pass.
- **HUMAN_DECISION_REQUIRED (reported, not changed)** — `make clean` runs
  `docker volume prune -f`, deleting unused volumes **machine-wide**, not just this repository's.
- Noted, unchanged: `test-env-test` uses project `shipit_test` while `test-env-up/down` use the
  default project, so both can run side by side and collide on ports 5433/8082. Pre-existing, and
  each is now independently cleaned.
