# Report — Implementation, `fix-credential-identity-invariants` (D-4 + D-18 + D-5 + LOW-1 + LOW-2)

Persisted per `aef-orchestrator` §14. Lane: `implementer`. Worktree
`/private/tmp/shipit-credential-identity`, branch `fix/credential-identity-invariants`,
`BASE_SHA 0bf2fa0`, **`HEAD_SHA 0bf2fa0` — nothing committed or pushed**.

```
RESULT: IMPLEMENTED
READY_FOR_INDEPENDENT_REVIEW: YES
```

| gate | status | evidence |
|---|---|---|
| format | pass | apps/server 126 files 0 changed; product_registry 31 files 0 changed |
| analyze | pass | `No issues found!` |
| unit | pass | `dart test packages/product_registry/test` → `+148` (142 baseline + 6 new) |
| integration | pass, 1 proven pre-existing fail | `make test-integration` → `+171 -1`; sole failure `dogfood_shipit_postgres_test.dart`, **re-proven on a pristine `0bf2fa0` worktree this pass** at `+164 -1` with the same sole failure. Delta = exactly +7 tests |
| schema guard | pass | 19 `OK:` lines, exit 0 |

## Files changed

```
M packages/product_registry/lib/src/store/product_registry_store.dart              (+60)
M packages/product_registry/lib/src/store/in_memory_product_registry_store.dart     (+90/-3)
M apps/server/lib/src/persistence/postgres_product_registry_store.dart             (+165/-48)
M packages/product_registry/lib/src/engine/product_registry_engine.dart             (+21/-14)
M apps/server/tool/verify_schema_bootstrap.sh                                       (+74)
M apps/server/tool/schema_bootstrap.sql                                             (+24/-8)
M packages/product_registry/test/credential_test.dart                               (+360)
A apps/server/test/integration/product_credential_immutability_postgres_test.dart   (+472)
```

`schema_bootstrap.dart` was granted but needed no change: it makes no parity claim, already lists the
credential index in `_requiredObjects` (`:81`), and its five probes write raw SQL directly, so `D-4`/`D-5`
cannot affect them.

## Per-defect

**D-4 — mint must never upsert. CONFIRMED and reproduced with emitted values.** The mint reached
`ON CONFLICT ("credentialId") DO UPDATE SET $assignments WHERE <four immutable fields equal>` (`:323-329`);
`$assignments` (`:226-240`) assigns all 20 mutable columns from the object built at `engine:963-978`, which
carries `status: generated` (`:973`), `hostKeyStatus` defaulting to `unknown` (`:975`), no host/verification
state and `version: 1` (`:977`). The predicate is **satisfied by identical values**. Pre-fix in-memory output
was the design's whole column-by-column loss table in one value:

```
T-C: Expected: throws CredentialNotUsableException with reason containing 'already exists'
     Actual: emitted RepositoryCredential(cred-1, shipit, repo-1, …, CredentialStatus.generated,
       …, null, null, null, HostKeyStatus.unknown, github.com, null, …, cred-1, 1)
```

Fix — `:439`: `ON CONFLICT ("credentialId") DO NOTHING RETURNING "credentialId"`. **`DO NOTHING`, not
`DO UPDATE … WHERE <always false>`**, exactly as the design requires: the latter is still an update and would
keep the predicate's shape alive as a second source of truth. Empty result → `CredentialNotUsableException`
(`:467-471`). D-1's predicate and `e391c02`'s index untouched.

**The call-site table was checked, not taken.** Five `saveProductCredential` sites: `engine:979` (mint, no
`expectedVersion`) and `:1011`, `:1025`, `:1066`, `:1088` (all CAS). The only null-`expectedVersion` call is
the mint, so the upsert branch was reachable **only** by it and D-4 cannot break the other three.
`rotateCredential` (`engine:1098-1133`) mints a **new** `credentialId` after revoking.

**D-18 — resurrection. CONFIRMED.** `readActiveCredentialForRepository` excludes revoked rows
(`:375`, `in_memory:226`), so the engine's one-active guard (`engine:954-961`) reads `null` for a revoked
credential and cannot fire; combined with D-4 the row was rewritten to `generated` with `revokedAt` nulled.
Pre-fix: `T-D: emitted … CredentialStatus.generated` for a credential revoked one statement earlier.
Severity confirmed against `79e860e2` (OPTION_A: destroy the handle on revoke) — a resurrected row asserts a
deploy key exists while its private half is gone.

**D-5 — `repositoryId` rewritable. CONFIRMED on both branches.** `"repositoryId" = @repositoryId` is in
`$assignments` (`:228`) and in neither predicate — the CAS predicate at `:313-317` and the mint predicate at
`:325-328` covered only the four material fields. Pre-fix output, verbatim from the dispatch's scenario:

```
T-F: emitted RepositoryCredential(cred-1, shipit, repo-2, GIT_PRODUCT_SHIPIT_REPO1_SSH, …)
```

The deploy key installed on **repo-1** now authorises **repo-2**, with no rotation record. Fix — `:319-320`
adds the scope predicate to the CAS branch; the mint branch needs nothing because `DO NOTHING` updates nothing.

**One correction to the design's prose, not to its requirement.** § R.9.3:936-941 says re-pointing "carries
a human's confirmation of repo-1's host across to repo-2's host". Verified: true on the **CAS** branch, but
**not on the mint path** — `engine:963-978` builds the row with `hostKeyStatus` defaulting to `unknown` and no
`hostConfirmedAt`, and `$assignments` writes those. So the mint path **destroys** the confirmation and lands
a row on repo-2 naming a host nobody confirmed. Both contradict **ADR 0018 `:96-99`** the same way. The
requirement the implementer followed is correct; only the sentence conflates the branches.

## Negative controls — every check proven load-bearing

**In-memory (6 controls):** D-4 removed → T-C, T-D, T-E red. D-4 **and** D-5 removed → T-C, T-D, T-E, T-F,
T-G red (control 1+2 is T-F's own control: on the mint path D-4 alone masks it). D-4 replaced by the *wrong*
form (conflict predicated on material differing) → T-C, T-D red. D-4 moved after the key-material check →
T-E red. Durable-evidence guard removed → the CAS-clear test red.

**Real Postgres (4 controls):** mint branch restored to the **exact `0bf2fa0` statement** → `+167 -5`, exactly
dogfood + the four D-4 tests, **and only those** (T-A, T-B, M-2, T-G, rotation, GAP-2 stayed green). D-5's
CAS scope predicate removed → T-G red. `_noClear` clauses removed → the CAS-clear test red. Mint predicate
**inverted** to `<>` → T-E red (this is T-E's real control, and **only a real Postgres can witness it**,
because under the restored branch a different-material re-mint is still refused by D-1's predicate and the
message comes from Dart either way).

**Static guard (2 controls):** bootstrap's index predicate widened `'revoked'`→`'superseded'` → **base guard
exit 0, green** (LOW-1 confirmed real), fixed guard **exit 1** + both DDLs printed. Bootstrap's index **key
column** changed → fixed guard **exit 1**. A `definition.sql` planted containing the credential index → base
ERE **NO MATCH** (LOW-2 confirmed real), fixed ERE **matches** → reported as an offender.

## Two defects in the implementer's own work, found and fixed

**(a) A test passing for the wrong reason.** With D-4 removed, T-D and T-F **stayed green** — the
durable-evidence guard added to the in-memory store was firing on the mint path and masking D-4 behind it. The
Postgres tier cannot do this (`DO NOTHING` evaluates no column predicate), so the in-memory store was applying
a guard the SQL could not. Fixed by scoping the in-memory durable-evidence check to the CAS branch (`:243`),
which makes the tiers agree.

**(b) The durable-evidence predicate did not compile.** Serverpod binds every parameter as
`Type.unspecified`; a bare `@param IS NOT NULL` gives Postgres nothing to infer, failing at **Parse** time with
`42P08` and taking down every CAS write on the tier. `CAST(... AS text)` fixed inference but then pinned the
parameter to `text` and the SET failed with `42804`. `_noClear(column, type)` (`:251`) now takes the type
explicitly, so a future type change fails loudly at Parse inside the integration suite rather than silently.

**(c) A test-harness defect surfaced by control F.** Removing D-5's predicate made `T-G` red **and** the
concurrency test red — T-G's re-point moved `cred-1` to another `productId`, and `_purgeSuiteRows` deleted by
exact `productId`, so the row **escaped teardown** and poisoned the next test. Fixed by making the purge
prefix-based on both `productId` and `repositoryId` (`:77-100`).

## LOW-1 and LOW-2

**LOW-1 — fixed by enforcing the claim rather than softening it.** `ddl_pattern` matches
`CREATE UNIQUE INDEX … "<name>"`, so name-anchored parity says the object *exists* in both homes and nothing
about whether they declare the same thing. Added a full-DDL comparison for the two index objects
(`verify_schema_bootstrap.sh:260`, comparison `:274-300`) with exactly two deliberate normalisations:
whitespace collapsed, and `IF NOT EXISTS` removed (the asset must be re-runnable; the chain path must not
fail where the bootstrap already ran). The declaring migration is located **by content**, so a later unrelated
migration cannot turn the check into a test of the wrong file. Two `OK:` lines added.

The **remaining** overclaim was the sentence asserting trigger *function bodies* are byte-identical. They are
not compared and cannot be: the asset wraps each in `DROP TRIGGER IF EXISTS` + `CREATE` for idempotence and
the migration does not. `schema_bootstrap.sql:44-68` now states precisely what is enforced — indexes by full
DDL, the immutability function by its guarded column list — with the reason.

**LOW-2 — fixed by deleting the second list rather than adding a fourth name to it.** The offender ERE was
hand-maintained, which is exactly how the index came to be missing while every other check covered it. It is
now derived from `required_objects` (`:313-317`).

## Docker disclosure — no breach

Every database came from **`make test-integration`** and nothing else. **9 runs**, each its own
`shipit_integration_<pid>` project, each trap reporting `Container … Removed` / `Network … Removed`, no
`CLEANUP FAILED`. **No other Docker or Compose command** — not `down`, `stop`, `rm`, `prune`, `up`, `pull`,
`build`, `--rmi`, and not `docker info`, `compose ps`, `compose logs` or `compose config`. No `make clean`,
`test-env-down`, `e2e-down`, or bare `down -v`. Compose files read as **text** only.

## Blockers routed to the Manager

1. **`CredentialIdentityConflictException` was not created.** The design names a distinct type for D-4; its home
   `packages/product_registry/lib/src/exceptions.dart` is **outside `OWNED_PATHS`**. Behaviour is complete and
   correct — the refusal carries a distinct greppable reason. Both refusals map to a typed 500 per the
   design's table, so **no API behaviour changes**. Closing it needs an ownership grant.
2. **The design this work implements is uncommitted and unapproved.** `design-revision-3.md` exists only as an
   untracked file in `design-correct-addproduct-keys`' worktree at `77c19f1`. If `D-4`/`D-5` are to land with
   reviewed provenance behind them, it needs committing and approving first.
3. **Deployment precondition carried forward unchanged.** The duplicate-credential audit must be run by a human
   against every deployed database before migration `20261006150645000`. This change adds no migration and does
   not alter the index or the pre-existing predicate, so it neither creates nor discharges it.

## Four things a reviewer should press on

1. **The in-memory T-D/T-F masking defect** — the fix scopes the in-memory durable-evidence guard to the CAS
   branch on the argument that it must mirror what `DO NOTHING` can see. **That argument is the implementer's.**
2. **`_noClear`'s explicit type parameter** — the seven columns' types were read off `migrations/*/definition.sql`.
   Verify them, and judge whether a loud Parse-time failure on a future type change is the right failure mode.
3. **The tier-ordering decision** — D-4 fires *before* D-1 on the mint path, because `DO NOTHING` cannot see the
   supplied material, so a different-material re-mint can only be reported as an identity conflict if both tiers
   are to agree. Confirm the reasoning: **it changes the message a caller sees.**
4. **The design's § R.9.3 host-trust sentence** conflates the mint path with the CAS branch. The requirement was
   implemented as specified; if the design owner disagrees with that reading, the fix is in the design.

> *"Do not approve this work on my say-so — I have not reviewed it, and the two pre-existing defects this lane
> found in its own first pass are the reason."*
