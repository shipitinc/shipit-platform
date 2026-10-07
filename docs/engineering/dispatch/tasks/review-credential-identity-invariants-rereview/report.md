# Report — Focused Re-review, `fix-credential-identity-invariants` (before merge)

Persisted per `aef-orchestrator` §14. Reviewer: `focused-reviewer`, read-only.

```
RESULT: DO_NOT_APPROVE_CORRECTIONS
REVIEWED_HEAD: 0bf2fa0058bbbab12eeea43b4e6a50eadff07b4d  (WORKING TREE — NO COMMIT EXISTS)
READY_FOR_MERGE: NO
CORRECTION_REQUIRED: YES
BLOCKERS: 1 (provenance — structural, resolved by committing)   HIGH: 0
MEDIUM: 1 (open, unfixed)   NEW-MEDIUM: 1 (found by this review)   LOW: 4 (all still open)
REGRESSIONS: none from the 5 commits of drift
```

**Exact tree reviewed:** branch `fix/credential-identity-invariants` at `0bf2fa0`, working tree of
`/private/tmp/shipit-credential-identity`, 8 modified files, **+1271/-90, nothing committed, nothing
staged, no untracked files.** `git rev-parse HEAD` = `0bf2fa0`; branch tip == base. There is **no
pinnable SHA for this change.** See "Provenance" below — this is a hard gate on integration.

---

## 0. Headline for the Manager

**No regression.** All five commits of drift touch **zero** of the eight reviewed files, zero
migrations, and zero of the guard's dependencies. The implementation is exactly as sound as the
baseline review found it, and I independently re-confirmed the gates.

**But this review cannot return APPROVE**, for three concrete and bounded reasons:

1. **The MEDIUM is still open** — I re-proved it, and proved it is *precisely* scoped (four positive
   controls show the guard catches table, key-column, `WHERE` and uniqueness drift; `IF NOT EXISTS` is
   the **only** forgiven divergence). The proposed fix is **directionally right but not yet actionable
   as written** — done naively it introduces a **new fail-open hole in a different check of the same
   script**. I supply a corrected fix in §2.
2. **A NEW MEDIUM that the baseline could not see**, because `design-revision-5.md` landed in the
   drift: the durable-evidence guard enforces **seven** columns where the now-committed spec requires
   **eight**. See §4. Latent, not live — proved unreachable today.
3. **Provenance.** Nothing to approve. It must be committed, then re-verified against the new SHA.

None of this touches the security-relevant core: **D-4/D-18/D-5 remain correctly closed.** This is a
merge-readiness verdict, not a rejection of the fix. **Three bounded steps (§10) stand between this tree
and merge.**

**Two headline corrections I made to my own draft, disclosed up front:**

- I initially concluded rev5 had **never been design-reviewed**. **Wrong** — it was reviewed
  (`DESIGN_REVIEW_CHANGES_REQUIRED`, B-R5-1 + 4 MEDIUM + 3 LOW) and I missed the report because it is
  **untracked**. Corrected in §5, with the self-disclosure preserved there. The correction makes the
  merge case **stronger**, not weaker: that review lists `G-11` implementation as `SAFE_PARALLEL_WORK`
  and confirms no finding touches § R.9.
- One `make test-integration` run returned `+125 -3` with two extra `setUpAll` failures. A second run
  returned `+171 -1`, matching baseline exactly; the extras **did not reproduce**. Reported as
  **pre-existing flakiness**, not hidden — see §7.1.

---

## 1. Provenance — verified, and it is a blocker to integration

Dispatched claims, all independently confirmed:

| Claim | Verified |
|---|---|
| `HEAD_SHA` == `0bf2fa0` | `git rev-parse HEAD` → `0bf2fa0058bbbab12eeea43b4e6a50eadff07b4d` ✅ |
| branch == base (no commits) | `git log -1` → `0bf2fa0 AGENTS.md: restore section 13…` ✅ |
| 8 files, +1271/-90 | `git diff --stat` → byte-identical to the dispatch ✅ |
| all uncommitted | `git status --porcelain` → 8× ` M`, no `??`, nothing staged ✅ |
| 5 commits behind `main` | `main` = `289f1d3`; `0bf2fa0..289f1d3` = 5 commits ✅ |

**Nothing has changed since the baseline review.** The bytes I reviewed are the bytes the baseline
reviewed. There were **no corrections** to re-review — which is itself why this returns
`DO_NOT_APPROVE_CORRECTIONS`: the correction loop never ran.

> **A commit must exist before integration, and this review must then be re-verified against the new
> SHA.** I reviewed **`0bf2fa0058bbbab12eeea43b4e6a50eadff07b4d` plus an uncommitted working-tree diff
> of +1271/-90**. That is not a pinnable revision, and it is the exact condition that already cost this
> work item one integration (`fix/credential-store-integrity` → `INTEGRATION_BLOCKED`). Do not repeat it.

---

## 2. The MEDIUM — re-verified, and the proposed fix needs correcting

`apps/server/tool/verify_schema_bootstrap.sh:267`, in `ddl_statement()`:

```sh
| sed -e 's/[[:space:]][[:space:]]*/ /g' -e 's/^ //' -e 's/ *$//' \
      -e 's/CREATE UNIQUE INDEX IF NOT EXISTS/CREATE UNIQUE INDEX/'
```

An **unconditional, blanket** sed applied to both homes independently.

### 2.1 The clause asymmetry is real (verified at the bytes)

| Object | Migration home | Bootstrap asset |
|---|---|---|
| `product_credential_active_repository_unique` | `20261006150645000/migration.sql:53` — **has** `IF NOT EXISTS` | `tool/schema_bootstrap.sql:112` — **has** `IF NOT EXISTS` |
| `design_revision_approved_unique_per_work_item` | `20260920232118956/migration.sql:86` — **no** clause | `tool/schema_bootstrap.sql:87` — **has** `IF NOT EXISTS` |

`20261006150645000`'s own comment makes the credential index's clause **mandatory, not optional**, and
the asset's `IDEMPOTENCE CONTRACT` (`schema_bootstrap.sql:38-42`) states the asset must be safe to
re-run against a **chain-migrated** database — so the reverse direction (a chain migration replayed
onto a bootstrapped database) is a real supported hazard.

### 2.2 Negative controls — the MEDIUM reproduces in **both** directions

Ran in a throwaway copy outside the workspace (`server_dir` is derived from `$0`, so a minimal copy
with `tool/`, `migrations/`, `Makefile` and `.github/workflows/integration.yaml` is faithful).
**Baseline first: `exit=0`, 18 `OK:`, 0 `FAIL:` — matching the baseline review exactly**, which
validates the harness before any mutation.

| # | Mutation | Result | Verdict |
|---|---|---|---|
| **E1** | drop `IF NOT EXISTS` from `20261006150645000` | `exit=0`, 18 OK, **0 FAIL**, still reports *"declares byte-identical DDL in both homes"* | **MEDIUM confirmed** |
| **E2** | drop `IF NOT EXISTS` from the bootstrap asset | `exit=0`, 18 OK, **0 FAIL**, same | **MEDIUM confirmed** |
| **P1** | drop the `WHERE` predicate from the migration | `exit=1` | guard works |
| **P2** | change the key column | `exit=1` | guard works |
| **P3** | change the table | `exit=1` | guard works |
| **P4** | `UNIQUE` → non-unique | `exit=1` (2 FAILs) | guard works |

**The finding is exact and correctly scoped by the baseline: `IF NOT EXISTS` is the *only* forgiven
divergence.** The blanket normalisation is genuinely needed for `design_revision_approved_unique_per_work_item`
(that asymmetry is real), and wrongly applied to the credential index. The guard's own comment is
self-contradictory — it justifies removing the clause by the chain path "must not fail where the
bootstrap already ran", which is an argument that the clause **must be there**.

### 2.3 The hazard has ZERO test coverage anywhere

- `schema_bootstrap.dart` applies the **asset** to a fresh database. It never replays `migration.sql`.
- `20261006150645000` appears **only** inside `schema_bootstrap.sql`'s own text — in **no** test, in
  **no** tool other than the asset.

So **no runtime test anywhere witnesses the migration-replay-onto-bootstrapped hazard.** The static
guard forgives it and nothing else can catch it. This materially raises the priority of the fix: the
negative control the proposal asks for would be the *only* mechanism that could ever detect it.

### 2.4 Judgement on the proposed fix — **correct in intent, defective as specified**

The proposal (keep whitespace collapse as the only blanket normalisation; make the clause an explicit
per-object expectation; assert `both` for the credential index and `asset-only` for the design-revision
index; add a negative control) is **the right diagnosis and the right shape**. I do not rubber-stamp it,
because it has two concrete defects:

**Defect 1 — it violates the principle this very script was written to encode.** At lines 306-312 the
script says, of its own check 4:

> *"The object NAMES are taken from `required_objects` above, not written out again here. A
> hand-maintained second list is exactly how the one-active-credential index came to be missing from
> this check while every other check covered it: adding an object to `required_objects` is enough, and
> **nothing has to be remembered in two places**."*

A **separate per-object expectation table** reintroduces exactly the two-places failure that sentence
exists to prevent.

**Defect 2 — done naively, it creates a NEW fail-open hole in check 4. I proved this.** Check 4 derives
its names with `sed 's/^[^:]*://'` (one field stripped). If the expectation is added as a third
colon-delimited field, that sed must be updated in lockstep — and if it is not, the name list becomes
`product_credential_active_repository_unique:both`, the regex no longer matches, `offenders` is empty,
and **check 4 silently passes**:

```
plant "product_credential_active_repository_unique" into a definition.sql   (the thing check 4 catches)
  UNMODIFIED script : exit=1   FAIL: these generated definition.sql files mention the hand-maintained objects
  AFTER the ripple : exit=0   18 OK, 0 FAIL   <-- SILENT PASS. Fail-open.
```

**A fix to a MEDIUM that opens a HIGH-class hole in the same script is not shippable as written.**

### 2.5 My corrected fix — same idea, one list, fails closed

**Put the expectation in the SAME `required_objects` entry, and make a missing expectation a hard error.**

1. Extend the entry syntax in place — no second list, so the script's stated principle holds:
   ```
   "index:design_revision_approved_unique_per_work_item:asset-only"
   "index:product_credential_active_repository_unique:both"
   ```
2. **A third field that is absent or unrecognised must `exit 2`** ("the guard itself could not run"),
   never fall back to the forgiving behaviour. This is what forces a future author to *state* the
   expectation, and it converts the old silent-forgiveness into a loud failure. (The script already
   uses `exit 2` for exactly this class of "cannot judge" condition — `:221-228`.)
3. Perform **two** comparisons per index object:
   - **clause-stripped** DDL (whitespace-collapsed only) → proves table / key / `WHERE` / `UNIQUE`
     parity. Keep the current behaviour; it is correct.
   - **clause presence** compared against the declared expectation → catches the clause in **both**
     directions for **every** object, with no per-object special-casing in the comparison itself.
4. **Update check 4's name derivation in the same commit** — `sed 's/^[^:]*:[^:]*://'` — or better,
   derive names with `cut -d: -f2` so the arity of the entry cannot leak into the regex. Then re-run the
   planted-index control above and assert it still exits 1. **Make that a required negative control**,
   because that is precisely the regression the change is capable of causing.

**Negative controls to add (all four; the proposal asked for one, one is not enough):**
- drop the clause from `20261006150645000` → expect `exit 1`
- drop it from the bootstrap asset → expect `exit 1`
- add it to `20260920232118956` where `asset-only` is expected → expect `exit 1`
- plant an index name in a `definition.sql` → expect `exit 1` (proves check 4 survived the arity change)

**A caveat the correction lane must record, not silently bless.** Codifying `asset-only` for
`design_revision_approved_unique_per_work_item` *enshrines an asymmetry whose correctness was never
established.* `20260920232118956` is an older migration whose comment gives no idempotence rationale,
while `20261006150645000` explicitly reasons about this exact hazard. If the credential index's clause
is mandatory for chain-replay-onto-bootstrapped safety, the design-revision one is **plausibly missing
it too** — a pre-existing latent defect at `0bf2fa0`, not this change's regression, and out of scope to
fix here. The value of making the expectation explicit is precisely that it forces a human to look.
Record it as a finding; do not quietly resolve it inside this change.

**No negative-control harness exists today** — the script is referenced only by CI as a step, by a
decision file, and by `schema_bootstrap.dart`. Adding negative controls means introducing a fixture-based
self-test for a bash script. That is the honest cost of this fix, and it should be scoped as its own
small piece of work with its own review, since it touches `.github/workflows/` (outside this change's
`OWNED_PATHS`).

---

## 3. Regression risk from the 5 commits of drift — **NONE** (verified)

`git diff --name-only 0bf2fa0..289f1d3` over the eight reviewed files: **empty.**
Over `apps/server/migrations`: **empty.**

I also checked the reviewed change's *dependencies* that are not in the diff:

| Dependency | Drift |
|---|---|
| `Makefile` | UNCHANGED |
| `.github/workflows/integration.yaml` | UNCHANGED |
| `.github/workflows/ci.yaml` | UNCHANGED |
| `apps/server/tool/schema_bootstrap.dart` | UNCHANGED |

The 5 commits touch 23 files, **all documentation/decisions/reviews/design revisions**
(+12015/-124): ADR 0018, `WORK_STATE.md`, `LANES.md`, decision records, and design revisions 2/4/5 with
their metadata and traceability matrices. **No code regression risk.** Drift is documentation-only, so
the semantic drift question reduces to "do the docs change a requirement?" — answered in §5.

**One genuine change drift did produce: a newly-committed specification the code does not meet. §4.**

---

## 4. NEW MEDIUM — durable evidence is guarded on **7** columns where the committed spec requires **8**

Found by this review; invisible to the baseline because `design-revision-5.md` landed in the drift.

`design-revision-5.md` (committed on `main` at `289f1d3`) defines **`D-6`** — "a recorded fact may be
set, never erased" — and fixes the set **once, as eight**:

> `lastVerifiedAt`, `lastVerifiedBy`, **`lastFailureReason`**, `hostKeyFingerprint`, `hostConfirmedAt`,
> `hostConfirmedBy`, `revokedAt`, `revokedReason` — **eight, in § R.9.4's order**

and raises it as a finding of its own:

> **H9** `D-6`'s requirement box names EIGHT columns; the constructs cover SEVEN — **HIGH** —
> `lastFailureReason` (`text`, nullable, `definition.sql:632`) added to **Tier A**
> (`_noClear('lastFailureReason', 'text')`) and to **Tier B** (`_clears`) — *"…which would ship one
> diagnostic column erasable on the CAS branch on both tiers."*

**Verified against the implementation's bytes. Both tiers guard exactly seven, and `lastFailureReason`
is in neither:**

- Tier A, `postgres_product_registry_store.dart:321-327` — `hostConfirmedAt`, `hostConfirmedBy`,
  `lastVerifiedAt`, `lastVerifiedBy`, `hostKeyFingerprint`, `revokedAt`, `revokedReason` = **7**
- Tier B, `in_memory_product_registry_store.dart:287-293` — `_clearsDurableEvidence` = the same **7**

And the column **is** live on the CAS write path — `postgres_product_registry_store.dart:284` puts it in
the UPDATE `SET` clause (`'"lastFailureReason" = @lastFailureReason,'`), so a store-level caller handing
in a `RepositoryCredential` with a null `lastFailureReason` against a row that has one **would erase it,
and both tiers accept it.**

**Severity: a guard gap, NOT a live defect — and I verified the distinction rather than assuming it.**
`RepositoryCredential.copyWith` uses `lastFailureReason: lastFailureReason ?? this.lastFailureReason`
(`packages/platform_contracts/lib/src/types/repository_credential.dart:162`), i.e. a null argument
**preserves** the current value. The only engine writer, `recordCredentialCheck`
(`product_registry_engine.dart:1074`), **sets** the column and never clears it; its success path does
not null it either. So **no engine path can erase `lastFailureReason` today.** Exactly the same class as
the MEDIUM: the guard is incomplete, the behaviour is not wrong yet.

**Scope discipline — do NOT fold `D-6` into this change.** `D-6` carries its own eight-column
requirement, its own success criteria (`SC-17`), and two of its own tests — `T-J` (the legitimate setters
must still **succeed**: `revokeCredential`, `confirmHostKey`, and `recordCredentialCheck`'s success and
failure paths) and `T-K` (erasure of each of the eight, by name, is refused). `T-J` is the trap: the
obvious implementation of `D-6` is "forbid the columns", which turns `T-J` red. Folding it in would
(a) expand the change beyond what the baseline and I reviewed, (b) risk breaking the legitimate setters,
and (c) **invalidate this review**. It is a separate change with its own review.

**Correct disposition:** record it as a tracked follow-up — *`D-6` eighth column (`lastFailureReason`),
latent, unreachable via any engine path, must land before migration `20261006150645000` reaches any
deployed database* — and let the Manager decide whether it is in scope here or a separate lane. **I am
not making it a blocker on this merge**, because it is provably not exploitable through the reviewed code
and because the reviewed change's own requirements (D-4/D-5) are met.

**This also explains LOW-1, which is now a three-way ladder:**

| Layer | Columns | Missing |
|---|---|---|
| Store contract prose (`product_registry_store.dart:82-84`) | **6** | `hostKeyFingerprint`, `lastFailureReason` |
| Both tiers actually enforce | **7** | `lastFailureReason` |
| Committed spec `rev5` requires | **8** | — |

---

## 5. The design-approval question — my position

> ### ⚠ CORRECTION TO THIS REPORT (self-disclosed)
> An earlier draft of this section stated that **rev5 had never been independently design-reviewed**
> and that **no rev5 review report existed**. **Both statements were WRONG.** I searched git refs and
> the `/private/tmp/shipit-*` worktrees, missed an **untracked** review directory in the main
> workspace, and repeated — in the very report that criticises a lane for trusting a negative result —
> **the exact error the dispatch warned about.** Caught on a final verification sweep of my own report
> directory listing. The corrected position is below, and it is *stronger* for the merge, not weaker.

The dispatch asks me to state plainly whether an unapproved design blocks the merge. Here is the verified
picture, and it is not the baseline's.

**There are two different `design-revision-3.md` files, and only one is the D-4/D-18/D-5 spec:**

- `docs/engineering/dispatch/tasks/design-addproduct-**mobile**/design-revision-3.md` — **committed** at
  `4e2d237`, on `main`. A lane grepping this name could easily have found it and concluded the artifact
  exists when the *keys* one does not.
- `docs/engineering/dispatch/tasks/design-addproduct-**keyservice**/design-revision-3.md` — the spec
  D-4/D-18/D-5 implement. Verified across **every** ref in the repo: it exists in **none**. It survives
  only as an untracked `??` file in `/private/tmp/shipit-correct-addproduct-keys`. The baseline was
  right about this one.

**rev3 is superseded, and the live governance state is this:**

1. **rev3 was superseded.** The keys lane went rev3 → rev4 → rev5. `rev4` and `rev5` **are committed on
   `main`** (`289f1d3`). rev5 explicitly corrects rev3 — *"Revision 5 is not self-approved:*
   `READY_FOR_INDEPENDENT_DESIGN_REVIEW` *is a statement about readiness, not a verdict"* — and splits
   out **`D-6`**. **Nothing should be reviewed against rev3 any more.**
2. **rev5 HAS been independently reviewed**, by a fresh `design-reviewer`, at
   **`REVIEWED_HEAD 289f1d3`** — the exact `main` tip I analysed:
   `docs/engineering/dispatch/tasks/design-review-addproduct-keys-rev5/report.md`
   (present on disk, **uncommitted and untracked**).
   ```
   RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
   BLOCKERS: B-R5-1        HIGH: none
   MEDIUM: M-R5-1..4       LOW: L-R5-1..3
   CORRECTION_REQUIRED: YES      HUMAN_DECISION_REQUIRED: NO
   ```
3. **Every one of those findings is outside § R.9.** B-R5-1 is Penpot **desktop board conformance**
   absent from rev5's gap register; M-R5-1/M-R5-2 are § 0.4's correction-map rows contradicting the
   artifacts they map; M-R5-3/M-R5-4 are **provenance bookkeeping** (finding counts; stale `§ 0.7`).
   **None** concerns § R.9, § R.14.1, § R.11.1/§ R.11.2 or the risk rationale.
4. **And the reviewer explicitly authorises this implementation lane**, in that same report's
   `SAFE_PARALLEL_WORK`:
   > *"Implementation of G-11 (D-4 / D-5 / D-6, both tiers, **eight columns**) — **§ R.9 is untouched by
   > every finding below** and I verified its citations exactly."*

### My position

**The design's `CHANGES_REQUIRED` does not block the merge — and that is not my judgement call, it is
the design reviewer's own published position.**

- **It does not block, because the design reviewer cleared exactly this work as safe parallel work.**
  `G-11` (D-4/D-5/D-6) is named as safe-to-implement, § R.9 verified exactly, with no finding touching
  it. The blocker (desktop board conformance) and the four MEDIUMs are a **design-lane bookkeeping and
  board-registration correction**, orthogonal to the credential invariants.
- **It does not block, because the spec is one requirement ahead of the code, and waiting does not close
  that.** rev5 splits `D-6` out of rev3's sentence. Approving rev5 changes the *target*, not the
  *deliverable*; the `D-6` eighth column still has to be built (§4). Serialising the merge behind rev5
  approval buys governance tidiness while a **live revocation hole stays open on `main`**.
- **It does not block, because rev5 has already consumed this implementation.** rev5 cites it
  construct-by-construct as `[UNCOMMITTED 0bf2fa0]` at `/private/tmp/shipit-credential-identity`, and
  its `H9` correction *presupposes* the seven-column constructs. Approving rev3 would approve a
  superseded document.
- **It blocks nothing here, but it is a real and unrecorded governance debt**, and the design lane owns
  it: rev5 is `CHANGES_REQUIRED`, and the review that says so **is itself uncommitted**. Two design-lane
  items to track: (a) B-R5-1 + the 4 MEDIUMs in the keys design lane; (b) commit
   `design-review-addproduct-keys-rev5/report.md` and `design-revision-3.md`'s disposition — the former
  is another instance of this work item's lost-evidence problem.
- **One caveat the design reviewer makes that cuts against me, and I am recording it rather than burying
  it:** it names the implementable scope as **"D-4 / D-5 / D-6, both tiers, eight columns."** The
  reviewed tree implements **seven**. So the design reviewer's clearance is for a scope one column
  larger than what is in front of me. That is precisely my §4 finding, and it is why §4 must be recorded
  as a follow-up rather than waved through — not a reason to hold the resurrection fix.

**Summary:** merge the reviewed tree once §1 and §2 are done; **do not** let a superseded `rev3` or an
out-of-scope design blocker keep a revoked credential resurrectable on `main`. The design lane keeps
B-R5-1, the 4 MEDIUMs, `D-6`'s eighth column, and the uncommitted review report.

## 6. The four LOWs — all still open, none has become a blocker

| LOW | Status now | Material? |
|---|---|---|
| **LOW-1** `product_registry_store.dart:82-84` names **six** columns while both tiers enforce **seven** | **Confirmed, and now worse.** The ladder is **6 documented / 7 enforced / 8 required** (§4). | **More material than the baseline judged.** No behavioural divergence *today* — a reader of the contract alone would still conclude clearing the host fingerprint is permitted. Fixing it must also name `lastFailureReason`, or the doc will be stale the moment `D-6` lands. |
| **LOW-2** implementer `report.md` line counts wrong on 5 of 8 entries; test file labelled `A` when it is `M`; gate table says "19 OK:" (actual 18) | **Unchanged.** No implementer report dir exists in the worktree; the report is committed on `main` at `docs/engineering/dispatch/tasks/fix-credential-identity-invariants/report.md` and was not corrected. | **Cosmetic.** But it is the provenance record for an uncommitted change, and mislabelling a file that already exists at `0bf2fa0` hides that it carries D-1/D-2's tests. It becomes moot the moment a commit exists. |
| **LOW-3** prefix purge (`credimm-%`) closes the leak class **by convention** | **Confirmed unchanged** — `product_credential_immutability_postgres_test.dart:98-114`, five prefix-scoped `DELETE`s. | No. Loud-by-design (surfaces as a `createProduct` unique-constraint failure in the *next* test), and the prefix is unique to this suite. Baseline's stronger closure suggestion still stands as optional. |
| **LOW-4** nothing persisted to `docs/engineering/learning/` | **Confirmed unchanged** — no learning file in the diff. | No. Mitigated by `LEARNING_POLICY`'s preference for executable knowledge; the Serverpod `Type.unspecified` / `42P08` discovery still deserves a `PROJECT_FACT` entry, but it is not merge-blocking. |

---

## 7. Gates — all re-run by me at the reviewed tree

| Gate | Command | Result |
|---|---|---|
| format | `dart format --output=none --set-exit-if-changed .` | **pass** — 631 files, **0 changed** |
| analyze | `dart analyze` | **pass** — `exit 0`; 2 `info` deprecations, **both in `packages/workflow_engine`**, a package this change does not touch (pre-existing) |
| unit | `cd packages/product_registry && dart test` | **pass** — **+148 All tests passed** (matches baseline's `+148`) |
| schema guard | `apps/server/tool/verify_schema_bootstrap.sh` | **pass** — **18 `OK:`, 0 `FAIL:`**, `exit 0` (matches baseline exactly) |
| integration | `SERVERPOD_DATABASE_PASSWORD=… make test-integration` | **+171 -1** — matches baseline exactly; sole failure the **pre-existing** `dogfood_shipit_postgres_test.dart` assertion, in a file this change does not touch |

**`NOT_RUN`: nothing.** No gate was skipped, and I did not weaken or skip any test.

### 7.1 Integration flakiness — disclosed, because I saw it

My **first** `make test-integration` run returned **`+125 -3`**, with two failures the baseline does not
have: `e2e_restart_persistence_test.dart (setUpAll)` and `store_contracts_postgres_test.dart
(setUpAll)`, alongside the known dogfood failure. Both are **`setUpAll` fixture failures**, and far fewer
tests ran (125 vs 171), consistent with suites aborting at setup.

A **second run returned `+171 -1`, byte-for-byte matching the baseline.** The extra failures **did not
reproduce**, so I record them as **flakiness under repeated runs in one environment, not a regression**.
But it is a real observation and it weakens the evidentiary weight of any single green integration run:
**a pre-existing shared-database flake in this suite is worth a tracking item**, and it means the
integration gate should be read as "green on at least one clean run", not "deterministically green".
I am reporting this rather than quietly keeping only the green run.

---

## 8. Docker disclosure — **no breach**

- `make test-integration` — **three** invocations total (one aborted immediately on a missing env var
  before any container was useful; two full runs), and **nothing else**.
- **Never** run: `down`, `stop`, `rm`, `prune`, `volume rm`, `compose up`, `pull`, `build`, `--rmi`.
- **Never** run, despite being read-only-looking: `docker compose ps`, `logs`, `config`, `docker info`.
- **Never** `make clean`, `make test-env-down`, `make e2e-down`, or any bare `docker compose … down -v`
  without `-p <project>`. I did not test the rule.
- I read the test-integration recipe **as text** (it uses `-p shipit_integration_$$$$` with an
  unconditional `down -v --remove-orphans` and a labelled leak check) before running it.
- Every run tore down its own project and reported removal: `shipit_integration_87836`,
  `_88117`, `_90826` — each printed `Container … Removed` and `Network … Removed`. **No `CLEANUP FAILED`.**
- (Unavoidable artefact of the sanctioned target: when the recipe aborts on the missing env var, its
  trap prints *"removing shipit_integration_87836"* and `make` then prints `Error 2`. The container is
  gone either way. Same known usability quirk the baseline review recorded.)

**The reviewed worktree is byte-identical to how I found it** — `git diff --stat` still 8 files,
+1271/-90, `HEAD` `0bf2fa0`, no untracked files. All mutation experiments ran in throwaway copies under
`/var/folders/…/T/opencode/`, now deleted. **I edited nothing except my own report directory.**

---

## 9. What I did **NOT** review

- **No full review.** I did not re-review the D-1/D-2 non-regression, the concurrency test, the
  SQLSTATE translation, `_noClear`'s seven types, tier ordering, or the masking-defect reasoning. The
  baseline approved those and re-proved them on pristine base; re-litigating them is outside a focused
  re-review. I read them only far enough to confirm the 7-vs-8 finding.
- **I did not fix the MEDIUM**, per my instructions — `verify_schema_bootstrap.sh` is unmodified.
- **I did not verify the nine RESOLVED Human Decisions** (`9417f8bf`, `898b07d0`, `ae1c1f79`,
  `27ea6536`, `7b1bc8b7`, `79e860e2`, `4d2c6b81`, `b869ec24`, `876c6b97`) and re-opened none.
- **I did not review rev5's full content** — only the sections bearing on D-4/D-5/D-6, the eight-column
  set, and its approval status. Its `G-13`–`G-17`, `SC-11`–`SC-20`, `N-9` and § R.14.1 are a design
  lane's scope, not mine.
- **I did not run any Docker command** beyond the sanctioned `make test-integration`, and therefore did
  **not** verify the credential index's behaviour against a real Postgres replaying the migration chain
  onto a bootstrapped database. That experiment is exactly what the MEDIUM's negative control should
  assert, and it needs DB authority a review lane does not hold.
- **I did not re-run the 13 new tests against pristine `0bf2fa0`** to re-prove redness. The baseline
  recorded this and I accepted it; re-proving it is a correction-lane task if the tree changes.
- **I did not review anything in the drift's 12 000 lines** beyond what bears on these eight files and
  their requirements.

---

## 10. Minimum steps before integration

1. **Commit the tree.** One commit on `fix/credential-identity-invariants`, no history rewrite. Then
   re-verify `git rev-parse HEAD` and re-run `dart format` / `dart analyze` / `dart test` /
   `verify_schema_bootstrap.sh` against **that SHA**. Record it as the reviewed revision.
2. **Fix the MEDIUM** per §2.5 — expectation carried **in** `required_objects`, **fails closed** on a
   missing/unrecognised expectation, check 4's name derivation fixed in the same commit, and all **four**
   negative controls in place (assert the planted-index control still exits 1).
3. **Fix LOW-1** in the same pass (one-line comment edit, `product_registry_store.dart:82-84`) — naming
   **all seven** enforced columns, so the prose does not have to be edited again when `D-6` lands.
4. **Record three tracked items, owned by the design lane** — do not absorb any of them into this change:
   - **`design-revision-5.md` is `DESIGN_REVIEW_CHANGES_REQUIRED`** (B-R5-1 + 4 MEDIUM + 3 LOW,
     `CORRECTION_REQUIRED: YES`) — and, per §5, **no finding touches § R.9**; that same review lists
     `G-11` implementation as `SAFE_PARALLEL_WORK`.
   - **Commit `design-review-addproduct-keys-rev5/report.md`** — the review that records rev5's verdict
     is itself **untracked and uncommitted**. A design verdict with no provenance is this work item's
     lost-evidence problem recurring, in a third place.
   - **`D-6`'s eighth column (`lastFailureReason`)** is unguarded on both tiers — latent, unreachable via
     any engine path, and named as in-scope for implementation by rev5's own review ("D-4 / D-5 / D-6,
     both tiers, eight columns"). Required before `20261006150645000` reaches a deployed database.
5. **Carry forward unchanged** (not mine, not blocking): the duplicate-credential audit must be run by a
   human against every deployed database before `20261006150645000`;
   `CredentialIdentityConflictException` still needs an `exceptions.dart` ownership grant.

**With steps 1–3 done, this is mergeable.** Steps 4 and 5 are records, not gates. I am explicitly
**not** recommending that a revoked credential stays resurrectable on `main` while a superseded design
revision awaits review — and the keys design lane's **own** independent review of rev5 (at the exact
`main` tip I analysed) lists `G-11` — "D-4 / D-5 / D-6, both tiers, eight columns" — as
**`SAFE_PARALLEL_WORK`**, with § R.9 "untouched by every finding". That is the design lane authorising
this lane to proceed, and this merge is that authorisation's natural completion.

**But note the one-line gap between what was cleared and what is in front of us:** the cleared scope is
"**eight** columns" and the tree implements **seven**. That is §4, and it is why step 4 is a record and
not a gate — the missing column is provably unreachable through the reviewed code, and building it here
would expand scope past what this review covered and risk `T-J`.
