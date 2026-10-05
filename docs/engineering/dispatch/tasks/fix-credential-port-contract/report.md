# Report — fix-credential-port-contract

Persisted per `aef-orchestrator` §14. Lane: `correction-implementer`.
Worktree `/private/tmp/shipit-cred-port` (retained), branch `fix/credential-port-contract`.
BASE_SHA `38768d0`, NEW_HEAD `60c8136`, COMMITTED: YES, nothing pushed.

Provenance note from the lane: HEAD was already at `60c8136` on arrival because the first
dispatch attempt committed tasks (a)/(b)/(d) before an API connection error aborted it. The
successful session independently re-verified every load-bearing claim against Serverpod
3.4.13 source, then executed task (c). It added no commit because no correction was warranted.

## Structured result

```
RESULT: CORRECTION_COMPLETE
CORRECTED_FROM_HEAD: 38768d0
NEW_HEAD: 60c813694749b3e31e757b13d965edcd82585f70
READY_FOR_FOCUSED_REVIEW: NO
```

`READY_FOR_FOCUSED_REVIEW: NO` set **deliberately**: the `tests` gate is not fully green
(157 passed / 1 failed). The lane refused to self-certify a red suite. The single failure is
proven pre-existing and environmental.

## Findings addressed

- **(a) One env-sourced password.** All four `control_plane_test_pw` literals removed.
  Authoritative value = `SERVERPOD_DATABASE_PASSWORD`, matching the existing
  `_env(...)` convention. Verified empirically: unset env → falls back to `passwords.yaml`;
  wrong env → `password authentication failed`, proving env genuinely overrides. Compose uses
  `${VAR:?}` and therefore fails closed with its own message.
- **(b) One port.** `9099` in all three sites. Chosen deliberately because `9090` is held by
  `partnerhub-test-db`. The CI comment at `integration.yaml:13-16` is now factually true.
- **(c) Integration suite executed** against a disposable real Postgres.
- **(d)** Throwaway `shipit-test-port-override.yaml` marked superseded at all three sites.

Files changed: `apps/server/config/test.yaml`, `apps/server/docker-compose.yaml`,
`.github/workflows/integration.yaml`, `apps/server/tool/seed_overview_qa.sql`.

## H1 PROVEN — fresh databases silently lack design-revision immutability

Both migration paths were exercised on disposable databases.

| Path | Behaviour | Result |
|---|---|---|
| Fresh DB | only latest `definition.sql` applied (`migration_manager.dart:194-205`) | 52 tables, tests pass |
| Existing DB @ v1 | all 15 `migration.sql` in order | 52 tables, tests pass |

Both converge on 52 tables — which is why this hid. But the schemas are **not** the same:

- **fresh is missing** `trigger_design_revision_immutability`,
  `trigger_design_review_independence`, `design_revision_approved_unique_per_work_item`
- **chain has an extra** `design_revision_approved_unique_per_work_item` plus a
  `repository_credential_id_seq` naming divergence

Direct probe, tampering with an **approved** design revision:

- fresh DB → `UPDATE 1`, value became `TAMPERED` — **silently mutated**
- chain DB → `ERROR: Cannot modify approved design revision`, value stayed `dsr`

These triggers exist only in `20260920232118956/migration.sql`, which the model-driven
generator cannot express, so no `definition.sql` ever carried them. **Every fresh database —
CI included — lacks DB-level immutability and review-independence enforcement.**
`melos run verify:schema-deviations` passes while the divergence is live, because its guard
checks three unrelated patterns.

Manager-verified: `grep -rl trigger_design_revision_immutability apps/server/migrations/`
returns `20260920232118956/migration.sql` only, and `grep -rl trigger_design
apps/server/migrations/*/definition.sql` returns nothing. Confirmed.

This is an `ARCHITECTURE_DISCOVERY` above lane authority — fixing it means editing prohibited
`migrations/**`. **Requires a human gate.**

## Integration test counts

`dart test test/integration/` against disposable Postgres: **157 passed, 1 failed**, 18 files,
~93s. Reproduced at default concurrency: 157/1.

The single failure is **not this lane's**: `dogfood_shipit_postgres_test.dart:87` asserts
`Directory('.git').existsSync()`. In a linked worktree `.git` is a *file*; in the canonical
checkout it is a *directory*. The predicate was proven `true`/`false` respectively, and the
assertion is byte-identical at base `38738d0`. Environmental, pre-existing, in a READ_ONLY
path. Not weakened, not skipped.

## Constraints honoured

- **Owner's DB byte-identical** — `TABLES=52`, 617 rows, `MD5=1bad44fd…` unchanged from a
  baseline taken before touching anything. No `schema_version`. Both owner containers still
  `Up 2 days`. Manager re-verified 52 tables after the lane finished.
- `migrations/**`, `docker/**`, `infrastructure/**`, `apps/control_plane/**`,
  `**/analysis_options.yaml` — `git diff` empty.
- `passwords.yaml` ignored (`apps/server/.gitignore:15`), absent from `git status`, never in
  any commit.
- No weakened tests, no `continue-on-error`.

## Cleanup

All three disposable containers removed (`credport-scratch`, `credport-pwfallback`,
`credport-final2`) plus the compose project `credport-verify` with its volume. No ports or
PIDs left running. Worktree retained.

## New discoveries

1. **ARCHITECTURE_DISCOVERY (human gate)** — fresh-DB path omits
   `trigger_design_revision_immutability`, `trigger_design_review_independence` and
   `design_revision_approved_unique_per_work_item`. Proven by probe: tampering with an approved
   `design_revision` succeeds on a fresh DB and is rejected on a chain-migrated DB.
2. `verify:schema-deviations` passes while the divergence is live; its guard does not cover
   the design triggers.
3. Serverpod 3.x records versions in `serverpod_migrations`, **not** `schema_version`. The
   dispatch's "no schema_version table" premise used the wrong name — the lane corrected it.
4. **Prior agent session created a `migration_proof` database INSIDE the owner's
   `control_plane-postgres_test-1` container**, violating isolation. Left untouched — removing
   it from the owner's environment is a destructive op. **Needs an explicit human decision.**
5. `dogfood_shipit_postgres_test.dart:87` fails in every git linked worktree (asserts
   `Directory('.git')` but `.git` is a file). Pre-existing at `38768d0`.
