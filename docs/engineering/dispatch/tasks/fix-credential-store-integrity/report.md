# Report — Implementation, `fix-credential-store-integrity` (D-1 + D-2 landed)

Persisted per `aef-orchestrator` §14. Lane: `implementer`. Worktree
`/private/tmp/shipit-credential-store`, branch `fix/credential-store-integrity`,
`BASE_SHA 064703d6a35ad144ba7babe776c46dc7e6c5496c`,
`HEAD_SHA 064703d6a35ad144ba7babe776c46dc7e6c5496c` (**nothing committed or pushed**, per the dispatch).
Resumed from the prior `IMPLEMENTATION_BLOCKED` report after the Manager widened `OWNED_PATHS`.

```
RESULT: IMPLEMENTED
FEATURE: Credential store integrity — immutable key fields and one active credential per repository
READY_FOR_INDEPENDENT_REVIEW: YES
```

## Gates

| Gate | Command | Status | Exact result |
|---|---|---|---|
| format | `dart format --set-exit-if-changed --output=none lib test` (`apps/server`) | **pass** | `Formatted 126 files (0 changed) in 0.80 seconds.` exit 0 |
| format | `dart format --set-exit-if-changed --output=none lib test` (`packages/product_registry`) | **pass** | `Formatted 31 files (0 changed) in 0.15 seconds.` exit 0 |
| analyze | `dart analyze apps/server packages/product_registry` | **pass** | `Analyzing server, product_registry... / No issues found!` exit 0 |
| tests (unit) | `dart test packages/product_registry/test` | **pass** | `00:01 +141: All tests passed!` exit 0 (137 baseline + 4 new) |
| tests (integration) | `make test-integration` | **pass, minus one proven pre-existing failure** | `00:40 +161 -1: Some tests failed.` — sole failure `dogfood_shipit_postgres_test.dart` |
| schema guard | `bash apps/server/tool/verify_schema_bootstrap.sh` | **pass** | 13/13 `OK:` lines, exit 0 |
| build | — | **n/a** | no build target in this Dart monorepo; `dart analyze` covers compilation |
| runtime | — | **n/a** | no browser/runtime surface in this change |

`make test-integration` exits non-zero because of the single dogfood failure. That failure is
re-proven below against a pristine `064703d` worktree and is **not** this change's.

## Files changed (all inside the widened `OWNED_PATHS`)

```
 M apps/server/lib/src/persistence/postgres_product_registry_store.dart        (+82/-1)
 M apps/server/tool/schema_bootstrap.dart                                     (+151)   <- D-2, widened grant
 M apps/server/tool/schema_bootstrap.sql                                       (+27)    <- D-2, widened grant
 M packages/product_registry/lib/src/engine/product_registry_engine.dart       (+16/-1)
 M packages/product_registry/lib/src/store/in_memory_product_registry_store.dart (+36/-1)
 M packages/product_registry/lib/src/store/product_registry_store.dart         (+20)
 M packages/product_registry/test/credential_test.dart                         (+191/-1)
 A apps/server/test/integration/product_credential_immutability_postgres_test.dart (new, 416 lines)
```

`PROHIBITED_PATHS` untouched: `apps/control_plane/**`, `docs/adr/**`, `.decisions/**`, `docker/**`,
`.github/workflows/**` all unmodified; `apps/server/migrations/**` **still untouched — no migration
created**. `apps/server/tool/verify_schema_bootstrap.sh` also unmodified (see GAP-1/GAP-2).

## D-2 as landed

`apps/server/tool/schema_bootstrap.sql:84-86`, idempotent, `BEGIN;`-wrapped like its neighbours,
placed directly after the existing partial-unique index it parallels:

```sql
CREATE UNIQUE INDEX IF NOT EXISTS "product_credential_active_repo_unique"
    ON "product_credential" USING btree ("repositoryId")
    WHERE ("status" <> 'revoked');
```

`apps/server/tool/schema_bootstrap.dart:71` adds `('index', 'product_credential_active_repo_unique')`
to `_requiredObjects` — the sixth entry, verified by the same `pg_class`/`relkind = 'i'` query the
existing index entry uses.

### Re-verified: the predicate is identical to the read path's

| | text | location |
|---|---|---|
| read path | `WHERE "repositoryId" = @repositoryId AND "status" <> 'revoked'` | `postgres_product_registry_store.dart:336` |
| index predicate | `WHERE ("status" <> 'revoked')`, key `("repositoryId")` | `schema_bootstrap.sql:84-86` |

Both select exactly the rows with `status <> 'revoked'` for one `repositoryId`. `"status"` is
`NOT NULL` (`migrations/20261001205247600/definition.sql:628`), so `<>` has no NULL-semantics
divergence. Constraint and query cannot contradict.

### Also re-verified: the index was genuinely absent before

The latest `definition.sql` creates only `product_credential_id_unique`, `_repo_idx` and
`_product_idx` — all non-unique-partial. Nothing on the fresh path supplied this index.

### Proved live, not just asserted

`make test-integration` runs the bootstrap against the real disposable Postgres:

```
  present: index product_credential_active_repo_unique
  rejected by the database: INSERT INTO "product_credential" (
  accepted by the database: INSERT INTO "product_credential" (
Schema bootstrap OK: 6 objects present, 5 enforcement probes behaved as required.
```

Baseline `064703d` prints `Schema bootstrap OK: 5 objects present, 3 enforcement probes` for the same
target — so the object and both new probes are new, and both took effect.

## Item 2 — decision: translate the violation into `CredentialNotUsableException`

**Chosen: translate.** Implemented in `PostgresProductRegistryStore.saveProductCredential`
(`:283-308`), matched on SQLSTATE `23505` **and** `DatabaseQueryException.constraintName ==
'product_credential_active_repo_unique'`, then rethrowing every other database error untouched.

This is not a preference — **the design mandates it.** `design-revision-2.md` § R.15b.2, *Cost,
stated*: "a genuine double-rotation race now surfaces as a unique violation rather than as a second
row. That is the point; **it must be mapped to a typed error, not swallowed.**" Letting it propagate
would have violated the design, not merely been a weaker choice.

Why the store and not the engine: `saveProductCredential` is where the driver lives; the engine is
store-agnostic and must not know about `DatabaseQueryException`. The `InMemoryProductRegistryStore`
raises the same `CredentialNotUsableException` for the same refusal, so both tiers now fail alike.

The match is verifiable rather than assumed — `postgres-3.5.12/lib/src/exceptions.dart:204` populates
`constraintName` from the Postgres error field `C`, and
`serverpod-3.4.13/lib/src/database/adapters/postgres/postgres_exceptions.dart:32-44` passes it
through to `DatabaseQueryException`. T-B asserts the caller sees the typed exception, so this is
covered by a green test, not by a code read.

**Rotation semantics intact, and now tested against real Postgres.** `rotateCredential` revokes first
(`engine:1118-1120`) and mints second (`:1122-1132`), so the old row leaves the index's predicate
before the replacement enters it. The integration suite's
`rotation still works and mints a new id with a new key` asserts `cred-2.supersedesCredentialId ==
'cred-1'`, that the superseded row keeps its key and reaches `revoked`, and that exactly one active
row remains — green against real Postgres.

## T-A and T-B

`make test-integration` on this worktree: **`+161 -1`**, and the reporter's `Failing tests:` block —
which is exhaustive — names **only** `dogfood_shipit_postgres_test.dart`.

**T-A: pass.** Already green in the prior pass and still green; no failure appeared.

**T-B: pass.** It was the second failure in the prior pass's `+160 -2` block. This pass is `+161 -1`
with the same total (162 tests) and dogfood as the sole failure, so T-B flipped fail → pass.

The new suite holds 4 tests — T-A, first-mint-still-succeeds, rotation-still-works, and T-B — and
adds `+4` over the `+157` baseline. Its T-B drives two engines through
`ProductRegistryEngine.recordGeneratedCredential` behind a read barrier, so both callers are past
`readActiveCredentialForRepository` before either writes; it asserts exactly one success, exactly one
typed `CredentialNotUsableException`, exactly one row total, and exactly one non-revoked row.

*Evidence limitation, stated rather than glossed:* `make test-integration` hardcodes
`dart test test/integration/`, so the run uses the compact reporter with no TTY, and per-test name
lines for this fast suite are overwritten by later files. The conclusive evidence is the exhaustive
`Failing tests:` block plus the total-count arithmetic, not per-test name lines. Recovering named
lines would require editing the `Makefile`, which is outside `OWNED_PATHS`.

## Baseline delta — the dogfood failure, re-proven

Re-ran the identical target on a **pristine `064703d`** worktree (`/private/tmp/shipit-baseline-064703d`,
detached, `git status` clean, immutability suite absent):

| | baseline `064703d` (re-run this pass) | this worktree | delta |
|---|---|---|---|
| result | `02:16 +157 -1` | `00:40 +161 -1` | **+4 passing** |
| dogfood | FAIL | FAIL | unchanged |
| sole failure | `dogfood_shipit_postgres_test.dart` | `dogfood_shipit_postgres_test.dart` | identical |
| bootstrap summary | `5 objects present, 3 enforcement probes` | `6 objects present, 5 enforcement probes` | +1 object, +2 probes |

The failure is `dogfood_shipit_postgres_test.dart:87`, `Directory('${repoRoot.path}/.git').existsSync()`.
In a **linked** worktree `.git` is a **file**, so this assertion can never pass under
`ISOLATION_CONVENTION`. **Environmental, unrelated to this change.** The whole delta is the four new
tests. This matches the prior report's independent baseline run.

## Schema guard — passes, but does NOT cover the new object

```
$ bash apps/server/tool/verify_schema_bootstrap.sh   # exit 0
OK:   bootstrap asset creates trigger trigger_design_revision_immutability
OK:   bootstrap asset creates trigger trigger_design_review_independence
OK:   bootstrap asset creates index design_revision_approved_unique_per_work_item
OK:   applier verifies trigger_design_revision_immutability
OK:   applier verifies trigger_design_review_independence
OK:   applier verifies design_revision_approved_unique_per_work_item
OK:   chain path creates trigger trigger_design_revision_immutability
OK:   chain path creates trigger trigger_design_review_independence
OK:   chain path creates index design_revision_approved_unique_per_work_item
OK:   immutability function guards the same 20 columns as the chain path
OK:   no generated definition.sql claims these objects; the bootstrap is their only source
OK:   CI applies the bootstrap (.github/workflows/integration.yaml)
OK:   the local test path applies the bootstrap (Makefile)
```

**GAP-1 (guard coverage).** The guard's `required_objects` list is hardcoded at
`verify_schema_bootstrap.sh:69-73` and has **three** entries; `product_credential_active_repo_unique`
is not among them (`grep -c` of the new name in that file → **0**). So the guard is green and, for
the new index, **silent**: deleting the new `CREATE UNIQUE INDEX` from the asset would leave the
guard at exit 0 — exactly the failure mode that script's own header says it exists to prevent. The
runtime half is covered instead: the applier's `_expectRejected` probe **did** observe Postgres
refuse a second non-revoked credential for one repository, which is a stronger check than a
`pg_class` existence test and fails loudly if the index is absent.

**GAP-2 (fresh-vs-chain parity divergence).** The new index exists **only** in
`tool/schema_bootstrap.sql`. No `migrations/**/migration.sql` creates it (`grep -rl` → **0**). So:

- **fresh** database = `definition.sql` + bootstrap → index **present**
- **chain-migrated** database = every `migration.sql` → index **ABSENT**

`schema_bootstrap.sql:37-44` (PARITY CONTRACT) calls this exact asymmetry "the defect this file
exists to remove", and the guard's check 3 enforces it for the three existing objects — which is why
`design_revision_approved_unique_per_work_item` was put in `migrations/20260920232118956/migration.sql`
**and** the bootstrap. D-2, as scoped, has the bootstrap half only.

Both gaps need files outside `OWNED_PATHS`: `verify_schema_bootstrap.sh` (not owned) and
`apps/server/migrations/**` (explicitly prohibited, "no migration is to be created"). I did not touch
either. See **BLOCKERS**.

## Deviations the Manager ruled on

1. **Exception type — `CredentialNotUsableException` stands**, per the dispatch. Recorded as a
   **naming follow-up, not implemented**: the design named
   `CredentialImmutabilityViolationException` (`exceptions.dart`), outside `OWNED_PATHS`. Callers
   distinguish by `reason`. A naming follow-up only — the behaviour is complete and typed.
2. **Identical-material re-mint test stays removed, per the dispatch.** Recorded below as an explicit
   design follow-up. No test asserts unspecified behaviour.

## Follow-ups carried forward (design authority — reported, not implemented)

1. **Identical-material re-mint is still permitted.** D-1's predicate is *satisfied* by identical
   values, so a re-mint with the same `publicKey`/`fingerprint`/`algorithm`/`referenceName` upserts,
   resetting a `verified` credential to `generated` and discarding host confirmation. Not an
   immutability violation — nothing immutable changed — but it is a real state-loss path. A
   never-upsert rule is **not** what D-1 specifies, so no test was written for it.
2. **`productId`/`repositoryId` remain rewritable** on the conflict branch. `copyWith` treats them as
   immutable; D-1 named only four fields. Note that `repositoryId` is the index key, so a
   `repositoryId` rewrite on an existing `credentialId` is now constrained by the new index too.
3. **Index name deviates from the design.** `design-revision-2.md` § R.15b.2 proposes
   `product_credential_active_repository_unique`; the dispatch specified and this change uses
   `product_credential_active_repo_unique`. Naming only, no behavioural difference — flagged so the
   reviewer does not read it as an unexplained divergence.

## Findings (per `aef-repository-learning`)

| Class | Finding | Authority |
|---|---|---|
| `ARCHITECTURE_DISCOVERY` | **GAP-2** — D-2's index has no migration counterpart, so a chain-migrated database does not enforce "one active credential per repository". Closes the bootstrap's own PARITY CONTRACT. | **Human decision** — Manager/human gate |
| `CONTRADICTION` | **GAP-1** — the static guard's `required_objects` (`verify_schema_bootstrap.sh:69-73`) omits the new index, so the guard is green while blind to it. | Manager (ownership of the guard script) |
| `RUNTIME_DISCOVERY` | `schema_bootstrap.dart` is wired into **only** `Makefile:228` and `.github/workflows/integration.yaml:131`. No QA/staging/production path runs it, so bootstrap-only objects reach no deployed database — true of the pre-existing `design_revision_approved_unique_per_work_item` too, which reaches production solely via its migration. This is why GAP-2 is material rather than cosmetic. | Manager |
| `RUNTIME_DISCOVERY` + `AUTOMATION_OPPORTUNITY` | `dogfood_shipit_postgres_test.dart:87` fails in **every** linked worktree — one red integration test per `ISOLATION_CONVENTION` lane, by construction. Fix: accept `.git` as file-or-directory. | Independent review (product repo) |
| `PROJECT_FACT` | A predicated `ON CONFLICT … DO UPDATE … WHERE` that matches nothing returns **silently** from `execute`. Only `RETURNING` surfaces it. Pinned by T-A. | Persisted as a test |
| `PROJECT_FACT` | Serverpod's `DatabaseQueryException.constraintName` is populated from the Postgres error field `C`, so a unique violation on a *partial unique index* is attributable by index name. This is what makes the D-2 translation precise. | Persisted as a test |
| `PROJECT_FACT` | The integration run logs `WARNING: The database does not match the target database: … Missing Index "product_credential_active_repo_unique"` — Serverpod comparing the live DB against the generated `definition.sql`. Expected and pre-existing in kind (the design-revision index already warns); it is corroborating evidence the object exists. | No action |
| `PROJECT_FACT` | `SERVERPOD_DATABASE_PASSWORD` is not set by default; `make test-integration` exits 2 before creating any container unless it is exported to match `test.database` in `apps/server/config/passwords.yaml`. No resource leak — the guard exits before `compose up`. | Report only |

## D-1 and D-2 are one invariant

The D-1 predicating `ON CONFLICT … DO UPDATE … WHERE` closes the **sequential** hole: one caller,
same `credentialId`, new key material — it must change nothing. The D-2 partial unique index closes
the **concurrent** hole: two callers, different `credentialId`, same `repositoryId` — the database
must choose one. Neither substitutes for the other: a predicate in the statement cannot order two
transactions, and a unique index says nothing about key material on an update. **They should be
reviewed together**, and the comment block at
`postgres_product_registry_store.dart:170-201` states that relationship where an implementer will
meet it.

## Disclosure

Docker was invoked **only** through `make test-integration` (four runs: two here, two on the pristine
baseline worktree). Every run's own `trap` reported successful removal of its `shipit_integration_<pid>`
container and network, including the one that exited 2 on the unset-password guard before creating
anything. The lane never ran `make clean`, `test-env-down`, `e2e-down`, or any `down -v`. No compose
project other than `shipit_integration_<pid>` was named, read, or targeted.

`apps/server/config/passwords.yaml` was absent in this fresh worktree (gitignored,
`apps/server/.gitignore:15`) and was copied from the canonical checkout — the documented prerequisite.
Confirmed still gitignored; absent from `git status` and from the diff.

## BLOCKERS

None blocking this change's gates. Two gaps are **not** mine to close and need Manager routing:

- **GAP-2 needs a human/architecture decision.** Either (a) grant `apps/server/migrations/**` so the
  index gets the migration counterpart the parity contract requires and reaches production the way
  `design_revision_approved_unique_per_workitem` does, or (b) record an accepted, documented
  divergence: the invariant holds on fresh/CI databases only. I am not choosing between those.
- **GAP-1 needs ownership of `apps/server/tool/verify_schema_bootstrap.sh`** to add the new index to
  `required_objects`. Note that doing so will also require the GAP-2 migration, because the guard's
  check 3 asserts the asset and the chain path create the same objects.

## Recommended next action

`INDEPENDENT_ENGINEERING_REVIEW` over the whole change at `HEAD_SHA 064703d` + working tree.
`READY_FOR_INDEPENDENT_REVIEW: YES` — format, analyze, unit tests and the integration suite are green,
T-A and T-B included, and the only red test is the dogfood failure demonstrated identical on pristine
`064703d` in this same pass.

**The reviewer must adjudicate GAP-2, not rubber-stamp this green.** T-B passing in CI is not the same
as the invariant existing on a chain-migrated database, and no gate in this repository can show the
latter. My reasoning for certifying over the dogfood delta: it is *proven* identical on pristine
`064703d` in this pass, it is a worktree-shape assertion unrelated to credentials, and it is not
something this change can affect. My reasoning for **not** certifying over GAP-2: it is specific to
what this change adds, it contradicts a contract the modified file itself states, and it is invisible
to every gate — which is exactly why it needs a human, not a green checkmark.