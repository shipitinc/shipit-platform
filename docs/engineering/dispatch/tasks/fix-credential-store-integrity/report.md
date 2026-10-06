# Report — Implementation, `fix-credential-store-integrity` (D-1 + D-2 + migration + GAP-1 + GAP-2)

Persisted per `aef-orchestrator` §14. Lane: `implementer`. Third pass on this work item,
resumed after Human Decision `4d2c6b81` resolved **OPTION_A** (add the index to the migration
chain) and after `engineering-reviewer` returned `APPROVE_WITH_NON_BLOCKING_FOLLOWUP`.

```
RESULT: IMPLEMENTED
FEATURE: Credential store integrity — immutable key fields, one active credential per repository,
         and the index's migration counterpart so the invariant reaches deployed databases
BRANCH: fix/credential-store-integrity
BASE_SHA: 064703d6a35ad144ba7babe776c46dc7e6c5496c
HEAD_SHA: 064703d6a35ad144ba7babe776c46dc7e6c5496c

OWNED_PATHS:
  apps/server/lib/src/persistence/postgres_product_registry_store.dart   (prior grant)
  apps/server/tool/schema_bootstrap.dart                                (prior grant)
  apps/server/tool/schema_bootstrap.sql                                  (prior grant)
  apps/server/tool/verify_schema_bootstrap.sh                            (WIDENED this pass)
  apps/server/migrations/20261006150645000/**                            (WIDENED this pass — NEW dir only)
  apps/server/test/integration/product_credential_immutability_postgres_test.dart (prior grant)
  packages/product_registry/lib/src/engine/product_registry_engine.dart (prior grant)
  packages/product_registry/lib/src/store/in_memory_product_registry_store.dart (prior grant)
  packages/product_registry/lib/src/store/product_registry_store.dart   (prior grant)
  packages/product_registry/test/credential_test.dart                    (prior grant)

READ_ONLY_PATHS:
  docs/engineering/WORK_STATE.md, docs/engineering/dispatch/**, apps/server/migrations/*/definition.sql
  (read to confirm lineage hazards; not modified), docker/compose.qa.yaml (read only, to prove which
  Postgres port 5432 belongs to), ~/.pub-cache/** (serverpod-3.4.13 / serverpod_cli-3.4.13 sources)

PROHIBITED_PATHS:
  apps/control_plane/**, docs/adr/**, .decisions/**, docker/**, .github/workflows/**
  (all verified unmodified — `git status --porcelain -- <paths>` returns nothing)

FILES_CHANGED:
   M apps/server/lib/src/persistence/postgres_product_registry_store.dart        (+129/-…)  D-1 predicate (both branches), D-2 SQLSTATE translation
   M apps/server/tool/schema_bootstrap.dart                                       (+180)     D-2 applier; L-1 comment corrections; stale-home header fix
   M apps/server/tool/schema_bootstrap.sql                                         (+69/-…)  D-2 asset; PARITY CONTRACT rewritten for two migration homes
   M apps/server/tool/verify_schema_bootstrap.sh                                   (+44/-…)  GAP-1: 4th required object; chain parity now spans the WHOLE chain
   M packages/product_registry/lib/src/engine/product_registry_engine.dart        (+16/-1)
   M packages/product_registry/lib/src/store/in_memory_product_registry_store.dart(+36/-1)
   M packages/product_registry/lib/src/store/product_registry_store.dart          (+26)
   M packages/product_registry/test/credential_test.dart                           (+288/-1) T-A, one-per-field, one-active, M-2 CAS
   A apps/server/migrations/20261006150645000/                                    (NEW, 5 files) GAP-2 chain-path counterpart
   A apps/server/test/integration/product_credential_immutability_postgres_test.dart (NEW, 811 lines) 7 tests

GATES:
format=pass  — `dart format --set-exit-if-changed --output=none lib test` (apps/server)
              → `Formatted 126 files (0 changed) in 2.13 seconds.` exit 0
format=pass  — `dart format --set-exit-if-changed --output=none lib test` (packages/product_registry)
              → `Formatted 31 files (0 changed) in 0.26 seconds.` exit 0
analyze=pass — `dart analyze apps/server packages/product_registry`
              → `Analyzing server, product_registry... / No issues found!` exit 0
tests=pass   — `dart test packages/product_registry/test`
              → `00:00 +142: All tests passed!` exit 0
tests=pass*  — `make test-integration` → `+164 -1: Some tests failed.` exit 1
              * ONE failure, `dogfood_shipit_postgres_test.dart`, RE-PROVEN identical on a
                pristine `064703d` worktree this pass (`+157 -1`, same sole failure). Delta
                = +7 passing, all mine. Bootstrap summary 5 objects/3 probes (baseline)
                vs 6 objects/5 probes (this worktree).
schema_guard=pass — `bash apps/server/tool/verify_schema_bootstrap.sh`
              → 16 `OK:` lines, exit 0
build=n/a    — no build target in this Dart monorepo; `dart analyze` covers compilation
runtime=n/a   — no browser/runtime surface in this change

DISCOVERIES: (see "Findings" below — 1 PROJECT_FACT persisted as tests, 3 reported for routing)
KNOWLEDGE_PERSISTED: 2 PROJECT_FACTs as executable tests (chain-replay suite, M-2 CAS suite);
                    1 RUNTIME_DISCOVERY + 1 PROJECT_FACT reported, not persisted
BLOCKERS: none for this change. ONE deployment precondition this lane cannot discharge —
          the duplicate-credential audit against a DEPLOYED database is NOT_RUN. See §1.

READY_FOR_INDEPENDENT_REVIEW: YES
```

Nothing is committed and nothing is pushed. `HEAD_SHA` equals `BASE_SHA`; the change exists as a
working tree. `git rev-parse --abbrev-ref @{u}` → no upstream configured.

---

## 1. Duplicate-credential audit — the reviewer's binding warning

**Result: ZERO duplicate groups in every database this lane can reach. The audit against a
DEPLOYED database is `NOT_RUN` and cannot be discharged from here.**

### 1a. The dispatch's query does not run

```
$ psql ... -Atc "SELECT repositoryId, count(*) FROM product_credential WHERE status <> 'revoked'
                  GROUP BY repositoryId HAVING count(*) > 1;"
ERROR:  column "repositoryid" does not exist
HINT:  Perhaps you meant to reference the column "product_credential.repositoryId".
```

The column is `"repositoryId"` — quoted camelCase. Unquoted, `repositoryId` folds to
`repositoryid` and **errors instead of reporting**. An operator who ran the query as dispatched
would see an error and could easily read that as "no duplicates". The corrected form:

```
$ psql ... -Atc "SELECT \"repositoryId\", count(*) FROM product_credential
                  WHERE status <> 'revoked' GROUP BY \"repositoryId\" HAVING count(*) > 1;"
```

Both forms are in `migration.sql` (the migration's embedded copy is the **corrected** one, with a
comment calling the quoting trap out explicitly).

### 1b. What was audited, and what it found

| database | what it is | rows | non-revoked | duplicate groups |
|---|---|---|---|---|
| `control_plane` | developer database on the **native Homebrew Postgres 16** (`/opt/homebrew/var/postgresql@16`) | 0 | 0 | **0** |
| QA / staging / production | container `postgres:16`, DB `shipit`, user `shipit` | — | — | **NOT REACHABLE FROM THIS LANE** |

The only credential-bearing database reachable here holds **zero** `product_credential` rows, so
it answers "no duplicates" vacuously. **That is not the audit the reviewer asked for.** The
reviewer's warning stands in full and is now stated as the migration's own documented
prerequisite — a human with access to the target environment must run it before deployment.

I confirmed the target of my connections, because two servers were bound to `5432`:

```
$ psql -h 127.0.0.1 -p 5432 -Atc "SELECT current_setting('data_directory'), inet_server_addr();"
/opt/homebrew/var/postgresql@16|127.0.0.1/32
```

Native Homebrew, **not** the QA container (`docker/compose.qa.yaml` declares DB `shipit`/user
`shipit`; I connected as `postgres` and never saw a `shipit` database). Only `SELECT`s were run
against `control_plane`; no scratch schema was created in it (`pg_namespace` still contains `public`
only).

### 1c. The prerequisite is real — proven, not asserted

The only duplicates that existed anywhere were fixtures this lane planted to prove the warning.
Applying the migration to a chain-replayed database holding two non-revoked credentials for `r1`:

```
BEGIN
INSERT 0 1
INSERT 0 1
ERROR:  could not create unique index "product_credential_active_repository_unique"
DETAIL:  Key ("repositoryId")=(r1) is duplicated.
-- post-state: index ABSENT, recorded version still 20261001205247600  (rolled back, nothing changed)
```

So the migration fails loudly, rolls back completely, and touches no credential row. That is the
designed behaviour and it is now pinned by an automated test (§3).

---

## 2. The migration — path, and which case it serves

**`apps/server/migrations/20261006150645000/`** (new directory, generated by
`serverpod create-migration`, then given the hand-written `CREATE`).

**It serves the chain-replayed case — the only case that needed it.** A fresh database was already
covered by `tool/schema_bootstrap.sql`; this migration exists so a database that *already has a
recorded migration version* gets the index too, which is the path every deployed database takes.

`definition.sql` in this directory differs from the previous tip's by **exactly 4 lines**, all of
them the version stamp:

```
1198c1198
<     VALUES ('control_plane', '20261001205247600', now())
>     VALUES ('control_plane', '20261006150645000', now())
1200c1200
<     DO UPDATE SET "version" = '20261001205247600', ...
>     DO UPDATE SET "version" = '20261006150645000', ...
```

No shipped `definition.sql` was edited. `definition.sql` for a new migration is unavoidable — the
generator writes it — but the index is deliberately **not** in it, because
`serverpod create-migration` rewrites that file verbatim from the Dart models
(`serverpod_cli-3.4.13 generator.dart:543-581`) and would erase a hand edit.

`migration_registry.txt` was **not** modified (its header says `AUTOMATICALLY GENERATED DO NOT
MODIFY`, and the dispatch said so). That is safe, and now **empirically** safe — see §3b: serverpod
applied the new migration from a database whose registry file never mentioned it.

### 2a. Lineage hazards — checked against the real mechanism

`WORK_STATE.md` H1/H2 record that `listVersions()` ignores `migration_registry.txt` and sorts
directories lexically, and that `migration_manager.dart:169-172` throws when a database's recorded
version has no directory. Consequences for this migration, both benign and both verified:

- **Adding a version cannot brick anything.** The hazard is the reverse direction (recorded version
  with no directory). Every one of the 16 pre-existing directories is untouched.
- **The full 17-migration chain replays cleanly from scratch**, verified twice — by hand against a
  real Postgres and inside the integration suite.

`M1` in `WORK_STATE.md` records a shipped migration edited with a factually wrong rationale. I did
not repeat that: this file states the opposite of the wrong claim — that a database with no recorded
version gets the latest `definition.sql` and never replays the chain
(`migration_manager.dart _loadMigrationSQL`: `fromVersion == null` → `definitionSql`; only the
`else` branch walks `migration.sql`).

### 2b. Statement order

The generator emits DDL first and the `serverpod_migrations` rows after it; this file now matches,
with a comment saying why (the recorded version must never be the last durable effect of a
migration that did not complete). Both are inside the file's `BEGIN`/`COMMIT`, so atomicity does not
depend on the order — the shipped shape does.

---

## 3. GAP-2 — chain-replay verification

The whole point of GAP-2 was that a fresh database already worked. So the proof must be a
chain-replayed database. Three independent lines of evidence, weakest to strongest:

### 3a. Automated, in-suite, with a negative control

Two new tests in
`apps/server/test/integration/product_credential_immutability_postgres_test.dart` replay
`migrations/*/migration.sql` — and nothing else — into a scratch schema, which is exactly what
Serverpod does to a chain-migrated database.

- **GAP-2: replaying the migration chain alone creates the index.** Asserts the index exists in the
  replayed schema, is `CREATE UNIQUE INDEX`, is keyed on `("repositoryId")`, **is partial** (a
  non-partial index passes the "one active per repository" test but would refuse the revoked row
  `rotateCredential` writes), and that the chain recorded its own tip version.
- **GAP-2 negative control: without that migration the chain does not enforce it, and duplicates
  block it.** Replays the same chain **minus** the migration that declares the index, asserts the
  index is absent, asserts two non-revoked credentials for one repository are *accepted* there, then
  applies the declaring migration alone and asserts it **fails** — and that afterwards the index is
  still absent and the recorded version is unchanged.

A green "index exists after replay" proves nothing unless the replay can also be seen to miss it.
That is what the second test is for, and it is why the migration is located by *content*
(`_migrationDeclaringIndex()`) rather than a hard-coded version: adding a later unrelated migration
cannot silently turn this into a test of the wrong file.

**Negative controls — the tests are load-bearing, not decorative:**

| what I removed | what went red |
|---|---|
| the `CREATE UNIQUE INDEX` from `migration.sql` | **both** GAP-2 tests (`+162 -3`), *and* the static guard (exit 1) |
| the key-material predicate from the Postgres `UPDATE` | the M-2 integration test (`+163 -2`) |
| the in-memory key-material guard | the M-2 unit test |
| the in-memory guard, moved *after* the version guard | the M-2 unit test (pins "immutability refusal takes precedence") |

### 3b. The product's own migration machinery, end to end

The strongest evidence, and it settles the `migration_registry.txt` question empirically:

1. Built a database in the shape of a database deployed *before* this change — full chain replayed
   up to `20261001205247600`, index **absent**, recorded version `20261001205247600`.
2. Ran the product's own path: `dart run tool/schema_bootstrap.dart`, which passes
   `--apply-migrations` to Serverpod.
3. Result:

```
Applied database migration:
 - 20261006150645000
...
Schema bootstrap OK: 6 objects present, 5 enforcement probes behaved as required.
```

```
serverpod_migrations:  control_plane = 20261006150645000
pg_indexes: CREATE UNIQUE INDEX product_credential_active_repository_unique
           ON public.product_credential USING btree ("repositoryId") WHERE (status <> 'revoked'::text)
```

`migration_registry.txt` never mentioned `20261006150645000` (`grep -c` → 0) and Serverpod applied
it anyway, because `listVersions()` enumerates migration **directories**
(`file_system.dart:37-42`). That is no longer a claim read out of third-party source; it is
observed behaviour. **The invariant reaches a deployed database.**

### 3c. Ad-hoc replay, against a real Postgres

The same replay run by hand: chain replay of all 17 files → index present with the correct partial
predicate, `public` untouched (0 tables), version recorded. Chain replay of the first 16 → index
**ABSENT** and two non-revoked credentials for one repository **accepted**. That negative control is
what §3a's second test automates.

---

## 4. GAP-1 — the static guard now covers the object

`index:product_credential_active_repository_unique` is the fourth entry in `required_objects`
(`verify_schema_bootstrap.sh:91`). The guard is green at 16/16 `OK:` — and it is now **load-bearing
in both directions**:

| what I removed | guard |
|---|---|
| the `CREATE` from `schema_bootstrap.sql` | `FAIL: bootstrap asset does not create index …` exit 1 |
| the `CREATE` from `20261006150645000/migration.sql` | `FAIL: no migrations/*/migration.sql creates index …` exit 1 |
| the whole migration directory | `FAIL: no migrations/*/migration.sql creates index …` exit 1 |

### 4a. A second defect fixed here, which the ordering exposed

The guard's check 3 compared the bootstrap asset against **one** migration file
(`20260920232118956`). That was correct while all four objects lived in that one file, and would
have reported this change's correct later migration as a divergence. Parity is now computed over
**every** `migrations/*/migration.sql` concatenated — which is what a chain-migrated database
actually replays — with the single reference migration retained only for the guarded-column
comparison, which is specifically about the immutability function it defines.

The dispatch's ordering constraint was real and I honoured it: adding the object to
`required_objects` **before** the migration existed turns check 3 red. Both halves are now in place.

---

## 5. Reviewer findings carried

### M-2 (MEDIUM) — **fixed by widening enforcement, not narrowing the contract**

I chose the second option the reviewer offered: **keep the unconditional contract and make the
Postgres `expectedVersion` branch enforce it.** Narrowing the doc to the null-`expectedVersion` path
would have been cheaper and would have been wrong here:

- The doc is not an overstatement — it is the *correct* contract, and the in-memory store already
  implements it unconditionally. Narrowing it would have made the documented contract weaker than
  the stricter tier, leaving the two tiers disagreeing in the opposite direction.
- It is not reachable today only because every call site happens to use `copyWith`. A contract that
  holds only while no caller needs it is not a contract.
- The predicate is in the statement, so it closes the hole against any other connection; the
  read-back at `postgres_product_registry_store.dart:270-303` then distinguishes "you re-pointed
  key material" from "you lost a race", and prefers the immutability refusal.

**But I found the fix was only half-landed and corrected it.** The predicate and the read-back were
already in the Postgres store, and the in-memory tier had a test — while the **Postgres tier had no
test at all**. That is precisely the "in-memory green, Postgres red" shape this change exists to
eliminate, reintroduced inside its own repair. It is now asserted on both tiers, and the negative
control above shows the Postgres test fails when the predicate is removed.

The in-memory test also had a defect I found and fixed: it constructed a **fresh, empty**
`InMemoryProductRegistryStore` while `fullyVerified()` populated the engine's store, so it was
passing against a store that had never seen the row (`Concurrent modification … actual 0`). The
test would have stayed green while asserting nothing. It now uses the group-level store, and the
two negative controls above confirm it fails when the guard is removed *or* reordered.

### L-1 (LOW) — **corrected**

`schema_bootstrap.dart`'s file header and `_expectAccepted` both said the accepted probe row "is
rolled back immediately afterwards" / "COMMITS and is not rolled back" inconsistently. Both now
state the truth: `session.db.transaction` maps to postgres `runTx`, which **commits** when the
callback returns (`database_connection.dart:756-778`); nothing leaks because `_deleteProbeRows`
removes every probe row in a `finally`, and that cleanup — not the transaction — is what keeps them
invisible. Every remaining mention of "rolled back" in the file is now accurate (they concern
*rejected* mutations, which the driver genuinely does roll back).

### L-2 — resolved by the rename

`product_credential_active_repo_unique` → **`product_credential_active_repository_unique`**,
per HD `4d2c6b81`. `grep` for the old name across `*.dart`, `*.sql`, `*.sh`, `*.md`: **0 hits.**
All three former sites are on the new name (`schema_bootstrap.sql:98`,
`schema_bootstrap.dart:76`, `postgres_product_registry_store.dart:202`) and the SQLSTATE
translation matches on it exactly. The DDL is **byte-identical** between the bootstrap asset and
the migration (`diff` → identical).

### M-3 and M-4 — **not implemented, carried as follow-ups**

Both are real and reachable through the public domain API (the reviewer confirmed this and I did
not dispute it). Both are outside D-1's literal scope — the design named four fields — so they need
**design authority, not an implementation guess.** Recorded in §Follow-ups.

---

## 6. Follow-ups carried forward (design authority — reported, not implemented)

1. **M-3 — identical-material re-mint is still permitted.** D-1's predicate is *satisfied* by
   identical values, so a re-mint with the same `publicKey`/`fingerprint`/`algorithm`/
   `referenceName` upserts, resetting a `verified` credential to `generated` and discarding host
   confirmation. Not an immutability violation — nothing immutable changed — but a real state-loss
   path. **Needs design authority:** the fix is a never-upsert rule, which D-1 does not specify.
2. **M-4 — `repositoryId` remains rewritable**, so an installed deploy key can be re-pointed
   between repositories of one product. Note `repositoryId` is now the index key, so a rewrite is
   *partially* constrained: two non-revoked credentials cannot end up on one repository, but an
   existing credential can still be moved. **Needs design authority.**
3. **Naming.** The design's § R.15b.2 already proposed `product_credential_active_repository_unique`,
   which is what is used — the earlier `..._repo_unique` divergence is gone, not merely documented.
4. **Exception type.** The design named `CredentialImmutabilityViolationException`
   (`exceptions.dart`, outside `OWNED_PATHS`); the behaviour is complete and typed as
   `CredentialNotUsableException`. Naming only.
5. **`productId`/`repositoryId` on the conflict branch** (pre-existing, unchanged by this work).

---

## 7. Findings (per `aef-repository-learning`)

| Class | Finding | Authority |
|---|---|---|
| `PROJECT_FACT` | **A predicated `ON CONFLICT … DO UPDATE … WHERE` that matches nothing returns silently from `execute`.** Only `RETURNING` surfaces it. | Persisted as T-A |
| `PROJECT_FACT` | **Serverpod's `DatabaseQueryException.constraintName` is populated from Postgres error field `C`**, so a unique violation on a *partial unique index* is attributable by index name. This is what makes the D-2 translation precise. | Persisted as T-B |
| `PROJECT_FACT` | **`SET search_path` on a pooled Serverpod connection is session state and leaks.** It surfaced as `relation "product_credential" does not exist` in this file's own `tearDown`. `SET LOCAL` inside an explicit `BEGIN` is scoped to the transaction and reverts even when it aborts. Verified in one psql session, both success and failure. | Persisted as the chain-replay helper's contract |
| `PROJECT_FACT` | **The dispatch's audit query cannot run**: `repositoryId` is quoted camelCase; unquoted it folds to `repositoryid` and *errors*, which reads like "no duplicates". | Persisted in `migration.sql` with the correction |
| `RUNTIME_DISCOVERY` | **`migration_registry.txt` is not consulted at runtime.** `listVersions()` enumerates migration directories. Empirically proven: serverpod applied `20261006150645000` from a database whose registry file never listed it. Resolves a standing question in `WORK_STATE.md` H1 for this path. | Report only |
| `RUNTIME_DISCOVERY` | **A pre-existing chain-vs-definition drift, not mine:** `20260920191519315/migration.sql:6` does `ALTER TABLE "repository_credential" RENAME TO "product_credential"`, leaving the sequence named `repository_credential_id_seq` while `definition.sql` expects `product_credential_id_seq`. Serverpod's integrity check warns about it on every chain-migrated database. Nine migrations old, no relation to this change. | Manager — out of my `OWNED_PATHS` |
| `RUNTIME_DISCOVERY` + `AUTOMATION_OPPORTUNITY` | `dogfood_shipit_postgres_test.dart:87` fails in **every** linked worktree — one red integration test per `ISOLATION_CONVENTION` lane, by construction. Fix: accept `.git` as file-or-directory. | Independent review (product repo) |
| `PROJECT_FACT` | The integration run logs `Missing Index "product_credential_active_repository_unique"` from serverpod's integrity check comparing the live DB against the generated `definition.sql`. **Expected and correct**: the index is deliberately not in `definition.sql`. Same warning already exists for `design_revision_approved_unique_per_work_item`. | No action |
| `PROJECT_FACT` | `SERVERPOD_DATABASE_PASSWORD` is not set by default; `make test-integration` exits 2 before creating any container unless it is exported to match `test.database` in `apps/server/config/passwords.yaml`. No resource leak — the guard exits before `compose up`. | Report only |

### One process finding I must report against myself

The **prior** report's `format` gate ("0 changed") was accurate when written, but the M-2 test was
added *after* it and left **two files unformatted**. The format gate would have gone red on the
next CI run. Caught and fixed this pass; both packages now report `0 changed`. Also, the
in-memory M-2 test was green **for the wrong reason** (an empty store) and the Postgres M-2
behaviour had **no test at all**. Both are now fixed and both have negative controls. The lesson is
recorded as the general finding above: a test that passes for the wrong reason is worse than no
test, and the only way to tell is to remove the thing it claims to cover and watch it go red.

---

## 8. Disclosure

**Docker.** Invoked **only** through `make test-integration` (6 runs: 3 on this worktree, 2
negative-control runs on this worktree, 1 on the pristine baseline worktree). Every run's own
`trap` reported successful removal of its `shipit_integration_<pid>` container and network — the
final run's output shows `Container … Removed` / `Network … Removed`. The lane never ran
`make clean`, `test-env-down`, `e2e-down`, or any `down -v`. No compose project other than
`shipit_integration_<pid>` was named, read, or targeted.

**Native Postgres (`localhost:5432`, Homebrew 16).** Used **read-only** for the audit and for
ad-hoc replays, plus `CREATE`/`DROP DATABASE` for scratch databases this lane created. `control_plane`
received only `SELECT`s and no scratch schema (`pg_namespace` = `public` only). The QA stack's
database (`shipit`/user `shipit`, container) was **never** connected to; I proved the two are
different servers before drawing that conclusion.

**Test resource hygiene.** Seven scratch databases were created on the native Postgres across this
work item (`shipit_chain_audit`, `_baseline`, `_replay`, `_negctl`, `_proto`, `shipit_fresh_check`,
`shipit_mixed`) plus `shipit_serverpod_path`. **All nine are dropped**; the final listing is
`control_plane`, `postgres` — the two that existed before this lane. Before dropping
`shipit_fresh_check`/`shipit_mixed` I confirmed they record `control_plane = 20261006150645000`, a
version that exists only in this lane's uncommitted migration, so they are provably this lane's and
not someone's. The integration suite's own scratch schema is dropped in `tearDown` on every test.

**Run-to-run variance, reported rather than smoothed over.** The **first** integration run of this
pass produced `+43 -13` in 09:35, with 13 unrelated `setUpAll` failures all reading *"Serverpod did
not start within the timeout of 0:00:30"*. Two subsequent runs of the same code were `+163 -2`
(01:40) and `+164 -1` (01:47), with no such failures. I did not establish the cause. The first run
is the only one with a search-path leak present, and it is the run whose code differed; the two
clean runs came after the `SET LOCAL` fix. I am **not** claiming a cause. What I can state: the
failure mode was a mass connection/startup timeout across unrelated files, it did not reproduce, and
it did not appear in either run after the fix. If a reviewer sees `-13` again, this is the first
thing to suspect.

**Evidence limitation, unchanged from the prior report.** `make test-integration` hardcodes
`dart test test/integration/`, so the compact reporter overwrites per-test name lines for fast
files. The conclusive evidence is the exhaustive `Failing tests:` block plus count arithmetic
(165 total = 158 baseline + my 7), not per-test name lines. Recovering named lines would require
editing the `Makefile`, outside `OWNED_PATHS`.

`apps/server/config/passwords.yaml` was absent in this fresh worktree (gitignored,
`apps/server/.gitignore:15`) and was copied from the canonical checkout — the documented
prerequisite. Confirmed still gitignored and absent from `git status`.

---

## BLOCKERS

None blocking this change's gates. One item must reach a human before **deployment**, and it is
not a code defect:

> **The duplicate-credential audit against a deployed database is `NOT_RUN`.** No QA, staging or
> production database is reachable from this lane, and the only reachable database with the
> schema holds zero credential rows. If any deployed database holds two non-revoked credentials for
> one repository, `CREATE UNIQUE INDEX` fails and the migration rolls back cleanly (§1c) — the
> deployment fails loudly rather than corrupting data, but it will not succeed. Reconciling live
> credential rows is a human decision. The corrected query is embedded in `migration.sql`.

## Recommended next action

`INDEPENDENT_ENGINEERING_REVIEW` over the whole change at `HEAD_SHA 064703d` **+ working tree**
(nothing is committed). D-1, D-2, GAP-1 and GAP-2 are each closed with a negative control that
demonstrates the check fails when the thing it covers is removed.

Two things the reviewer should press on rather than accept:

1. **The audit is not discharged.** Every "no duplicates" result here comes from a database with
   no data in it. The reviewer's binding warning is answered by *mechanism* (the migration fails
   loudly and rolls back) but not by *evidence about the target environment*.
2. **My own test defects.** This pass found a test that passed against an empty store and a
   Postgres behaviour with no test at all — both introduced by the previous pass of this same lane.
   The negative controls in §3a are the evidence that the current tests are load-bearing; the
   reviewer should spot-check that judgement rather than take it on trust.
