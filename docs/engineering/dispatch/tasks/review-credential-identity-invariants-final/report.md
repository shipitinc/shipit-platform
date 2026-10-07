# Report — Focused Re-review, `fix/credential-identity-invariants` at `a4c211c` (now pinnable)

Persisted per `aef-orchestrator` §14. Reviewer: `focused-reviewer`, read-only.

```yaml
RESULT: APPROVE_CORRECTIONS
TASK_ID: review-credential-identity-invariants-final
TASK_TYPE: re-review
FEATURE: Add Product rebuild — credential identity invariants, final pre-merge review
WORKTREE: /private/tmp/shipit-credential-identity
BRANCH: fix/credential-identity-invariants
BASE_SHA: 3f3f4f4
HEAD_SHA: a4c211c
COMMITTED: YES
REVIEWED_HEAD: a4c211ccd1d094b4955f56f7d9ae385e377bb15f
REGRESSIONS: none
READY_FOR_MERGE: YES — conditional on the two tracked items in §11, neither of which is a gate
CORRECTION_REQUIRED: NO
HUMAN_DECISION_REQUIRED: NO
```

**Exact tree reviewed:** `/private/tmp/shipit-credential-identity`, branch tip `a4c211c`,
`git status --porcelain` **empty**. No uncommitted drift, no untracked files.

---

## 0. Headline for the Manager

**`3f3f4f4` genuinely reproduces the tree I reviewed — I verified it independently, and I add one
oracle the lane did not have: the MEDIUM itself reproduces there, bit for bit.** Provenance is no
longer a question. See §1.

**All three prior findings are genuinely resolved.** The MEDIUM is closed in the exact §2.5 shape, I
reproduced **both** of the lane's fail-open proofs myself, and the guard went **18 → 20 by pure
addition** — I diffed the assertion sets, nothing was removed.

**T4 is real, it is NOT this correction's regression, and it does NOT block the merge — but it is not
a cosmetic flake and the lane's mechanism for it is incomplete in a way that changes the right fix.**
The precise defect: in D-4 both callers mint the **same id into the same repository**, so the losing
tuple violates **two** unique constraints at once, and the test asserts *which one Postgres names*.
Nothing in this repository pins that. The right disposition is **fix the behaviour, not the test** —
one small change fixes the flake *and* a real misleading-diagnostic defect the flake exposes. §3.

**The new self-test is safe, and I proved the containment check is live rather than decorative** by
making it fire. §6.

---

## 1. Provenance — `3f3f4f4` is VERIFIED (not unverified provenance)

The lane says it could not find the reviewed tree anywhere and **reconstructed it by exact inverse
edits**. That is an unusual, consequential operation, so I tested it rather than accepting it.

### 1.1 Every recorded oracle passes

| Oracle | Where I checked it | Result |
|---|---|---|
| `git show --stat 3f3f4f4` = **8 files, 1271 insertions, 90 deletions** | `--numstat`, summed | **8 / 1271 / 90 — exact** ✅ |
| guard is **361 lines** | `git show 3f3f4f4:…/verify_schema_bootstrap.sh \| wc -l` | **361** ✅ |
| pre-correction clause-strip `sed` at **:267** | `ddl_statement()` | **:267** ✅ |
| `exit 2` "cannot judge" idiom at **:221-228** | guarded-column read-backs | **:221–228** ✅ |
| policy comment "nothing has to be remembered in two places" at **:306-312** | check 4 header | **spans :308–:312, section opens :306** ✅ |
| `hand_maintained_names` derivation at **:313-315** | `sed 's/^[^:]*://'` | **:314** ✅ |
| guard **18 `OK:` / 0 `FAIL:` / exit 0** | ran it from a `git archive` export of `3f3f4f4` | **18 / 0 / 0** ✅ |
| test file `+478/-5` | `--numstat` | **478 / 5** ✅ |

> **Dispatch-prose correction, disclosed.** The dispatch labels the `:267` oracle as
> `sed 's/^[^:]*://'`. That sed is at **:314**; **:267** is the *clause-strip* sed
> (`s/CREATE UNIQUE INDEX IF NOT EXISTS/CREATE UNIQUE INDEX/`), which is the thing the MEDIUM is about.
> Both seds are exactly where the two prior reviews recorded them — the dispatch's own label conflates
> them. **The correction lane's oracle table got this right** (it correctly puts the derivation at
> `:313-315` → `:314`). No oraclemissed; the conflation is in the dispatch text, not in the tree.

### 1.2 The oracle the lane did not have — **the MEDIUM reproduces at `3f3f4f4`**

I re-ran my own §2.2 negative controls against a `git archive` export of `3f3f4f4`:

| # | Mutation | Result at `3f3f4f4` | My prior report recorded |
|---|---|---|---|
| **E1** | drop `IF NOT EXISTS` from `20261006150645000` | **exit 0, 18 OK, 0 FAIL**, still reports *"declares byte-identical DDL in both homes"* | **identical** ✅ |
| **E2** | drop `IF NOT EXISTS` from the bootstrap asset | **exit 0, 18 OK, 0 FAIL**, same | **identical** ✅ |

A file can be the right length, the right line count and the right assertion count and still not be
the tree that was reviewed. **`3f3f4f4` is the tree on which the MEDIUM reproduces.** That is a
behavioural oracle and it passes.

### 1.3 Eleven further line-level oracles across five of the eight files — all exact

`postgres_product_registry_store.dart` `:284` (`"lastFailureReason" = @lastFailureReason,`) ·
`:315-320` (CAS predicate, four-field immutability) · `:321-327` (`_noClear` × **7**) ·
`in_memory_product_registry_store.dart` `:287-293` (`_clearsDurableEvidence` × **7**) ·
`product_registry_store.dart` `:82-84` (six-column prose) ·
`migrations/20261006150645000/migration.sql:53` (clause present) ·
`migrations/20260920232118956/migration.sql:86` (clause absent) ·
`tool/schema_bootstrap.sql` `:38-42` (IDEMPOTENCE CONTRACT), `:87`, `:112` (both clause present) ·
`product_registry_engine.dart:1074` (`recordCredentialCheck` **sets** `lastFailureReason`) ·
`platform_contracts/.../repository_credential.dart:162` (`?? this.lastFailureReason`).
**Every one matches exactly.**

### 1.4 One disclosed outlier, and why it is NOT tree drift

The **baseline** review's LOW-1 cites `in_memory_product_registry_store.dart:281` for
`hostKeyFingerprint`. At `3f3f4f4` it is at **:293**; **:281 is a doc-comment line** about `copyWith`.

This cannot be a consistent alternative version of the file: `_clearsDurableEvidence`'s seven
`_clears` calls occupy `:287-293` **contiguously**, and `:281` falls *inside* the `_sameKeyMaterial`
region — no seven-column arrangement of this function puts `hostKeyFingerprint` at `:281`. **My own
prior report cited `:287-293`, which matches `3f3f4f4` exactly.** The same baseline report admits
wrong line counts in five of eight entries (its LOW-2). This is baseline citation imprecision, not
drift. Recorded so the Manager is not surprised by it.

### 1.5 The reviewed state really is gone — the reconstruction account is honest

I did not take this on trust either:

- **26** (not the 25 the lane reports) `/private/tmp/shipit-*` worktrees exist. Their guard variants
  are **278** (the pre-feature script, identical to `0bf2fa0`), **248**, **200** — and `542` (this
  correction). **No 361-line copy exists anywhere on disk.**
- The object store has **one dangling tree**; its guard blob is the **278-line** version. Every dangling
  commit is unrelated WIP. `git stash list` holds exactly the one pre-existing unrelated entry.

**Conclusion: `3f3f4f4` is verified as a faithful reconstruction. Provenance is settled, and the
lane's honesty about *how* it produced the commit is itself worth recording.**

`a4c211c` = **3 files, +515/-16**, exactly as reported: the guard (+195/-14), the new self-test
(+300), the store comment (+20/-2).

---

## 2. The MEDIUM — CLOSED. All five required elements verified independently

### 2.1 Expectation inside the same `required_objects` entry — no second list ✅

```bash
required_objects=(
  "trigger:trigger_design_revision_immutability"
  "trigger:trigger_design_review_independence"
  "index:design_revision_approved_unique_per_work_item:asset-only"
  "index:product_credential_active_repository_unique:both"
)
```

`checked_objects` / `clause_expectations` are **derived in one parse pass (`:148-214`)**, not
hand-maintained. The script's own principle at `:481-485` survives intact. **§2.5 point 1 satisfied.**

### 2.2 Absent/unrecognised expectation `exit 2` — never falls back ✅ — **six forms, tested**

I did not trust the harness; I ran the guard directly in a throwaway export:

| Malformed entry | Exit | `OK:` assertions |
|---|---|---|
| baseline, unmutated | **0** | 20 |
| no expectation field (`index:name`) | **2** | **0** |
| empty / trailing colon (`index:name:`) | **2** | **0** |
| misspelled (`index:name:btoh`) | **2** | **0** |
| a **fourth** field (`index:name:both:extra`) | **2** | **0** |
| a **trigger** carrying an expectation | **2** | **0** |
| unknown `kind` (`indexx:…`) | **2** | **0** |

Six of six fail closed, with **zero** pass assertions and a named `FAIL: cannot run the guard, …`.
**It never falls back to forgiving behaviour.** §2.5 point 2 satisfied.

### 2.3 TWO comparisons per index object ✅

- **clause-stripped DDL parity** (`:436-446`) — whitespace collapse only; unchanged, still proves
  table / key column / `WHERE` / `UNIQUE`.
- **clause presence per home vs. the declared expectation** (`:452-472`) — `clause_presence` returns
  `yes` / `no` / **empty**, and empty is deliberately **not** folded into `no`.

Same code for every object; the per-object fact is data in `required_objects`, not a branch.
**§2.5 point 3 satisfied.**

### 2.4 Check 4's name derivation fixed in the SAME commit ✅

`cut -d: -f2` at `:495`, not the one-field `sed`. `git show a4c211c` lists the old
`sed 's/^[^:]*://'` among its **14 deletions**, so the fix is in this commit, not a later one.
Checks 1–3 were also moved onto the validated projection — they were **broken-but-loud**, not silent,
so that is an improvement, not a regression. **§2.5 point 4 satisfied.**

### 2.5 All FOUR required negative controls present, each genuinely exits 1 ✅

```
ok   baseline:                                    exit 0, 20 OK, 0 FAIL
ok   drop-clause-from-migration:                  exit 1, 19 OK, 1 FAIL   <- REQUIRED 1
ok   drop-clause-from-asset:                      exit 1, 19 OK, 1 FAIL   <- REQUIRED 2
ok   add-clause-where-asset-only-declared:        exit 1, 19 OK, 1 FAIL   <- REQUIRED 3
ok   plant-index-in-definition:                   exit 1, 19 OK, 1 FAIL   <- REQUIRED 4
ok   index-entry-without-expectation:             exit 2,  0 OK, 1 FAIL
ok   index-entry-with-unrecognised-expectation:   exit 2,  0 OK, 1 FAIL
ok   drift-in-where-predicate:                    exit 1, 19 OK, 1 FAIL
ok   drift-in-key-column:                         exit 1, 19 OK, 1 FAIL
ok   drift-in-table:                              exit 1, 19 OK, 1 FAIL
ok   drift-in-where-predicate-of-asset:           exit 1, 19 OK, 1 FAIL
ok   repository-untouched:  every file this harness reads is byte-identical
12 cases, 0 failed.
```

### 2.6 I reproduced BOTH of the lane's fail-open proofs

| Proof | Lane's claim | **My reproduction** |
|---|---|---|
| revert **only** check 4's derivation | `plant-index-in-definition` exits 0 silently | **CONFIRMED** — `FAIL plant-index-in-definition: expected exit 1, got 0 (20 OK, 0 FAIL)`. Baseline still 20 OK. A **silent pass**. |
| delete **only** the clause-presence comparison | all three clause controls exit 0, baseline drops to 18 | **CONFIRMED exactly** — baseline **18 OK**; `drop-clause-from-migration` **exit 0**, `drop-clause-from-asset` **exit 0**, `add-clause-where-asset-only-declared` **exit 0**; 4 of 12 cases fail. |

**The harness is not a fixture that checks nothing.** It has actually run the drift it was written to
catch, in both directions.

### 2.7 Also fixed, correctly

The self-contradictory comment that justified normalising the clause away by arguing *"the chain path
must not fail where the bootstrap already ran"* — an argument that the clause **must be there** — is
replaced with a comment that says so. The `asset-only` asymmetry caveat is written **at the
declaration** (`:117-125`), which is exactly what my §2.5 caveat asked for: it forces a human to look
without quietly settling it.

**The MEDIUM is closed.**

---

## 3. T4 — the open determinism defect. **Real. NOT a regression. Does NOT block. But do not call it cosmetic.**

### 3.1 The flakiness is real, and I measured it

**My four runs of `make test-integration`, in order: `+170 -2`, `+171 -1`, `+171 -1`, `+171 -1`.**
The lane's four: `+171 -1`, `+170 -2`, `+170 -2`, `+171 -1`. **Combined: 3 of 8 runs.** The failure:

```
product_credential_immutability_postgres_test.dart:
  D-4 under concurrency: two mints of one id yield one row and one identity conflict [E]

  Expected: (contains 'already exists' and not contains 'already has an active credential')
    Actual: 'repository credimm-repo-1 already has an active credential;
             another caller recorded one first, so rotate it instead of issuing a second one'
   Which: does not contain 'already exists'
```

I traced that string: it is **only** produced by
`postgres_product_registry_store.dart:452-457`, the `_activeCredentialUniqueIndex` translation — **not**
by the engine's pre-read guard (whose text differs at `product_registry_engine.dart:967-971`). So the
loser's `INSERT` was refused by **Postgres, naming the partial active-repository index**.

### 3.2 Is it this correction's regression? **No — and I did not take the reassurance**

The lane's stated evidence was: "touches no `lib/`, `test/`, `migrations/` or `schema_bootstrap.sql`,
0 non-comment Dart lines." **That evidence is literally imprecise and I am recording it**, because I
was told not to take it on trust:

- `a4c211c` **does** touch a file under a `lib/` directory:
  `packages/product_registry/lib/src/store/product_registry_store.dart`.
- **Substance holds.** I grepped every changed line in that file against `^[+-]\s*///`:
  **the result is empty — 100% doc-comment lines.** And the whole commit touches **no** Dart under
  `apps/server/lib/`, **no** `apps/server/test/`, **no** `migrations/`, and **no**
  `tool/schema_bootstrap.sql`. Nothing it changes is compiled or used to build the disposable database
  the suite runs against.
- `dart test test/integration/` never executes the self-test, and the guard script is not in that path.

**So: not a regression. Confirmed by me, on the diff, not on the assurance.**

### 3.3 Is the diagnosis right? **Right about the barrier, incomplete about the cause**

**What the lane got right — I verified it from the bytes.** `_GatedStore`
(`product_credential_immutability_postgres_test.dart:1276-1283`):

```dart
final result = await super.readActiveCredentialForRepository(repositoryId);
await _gate.arrive();          // <- barrier released AFTER the read completed
return result;
```

Both `SELECT`s complete before either caller proceeds to `saveProductCredential`. **The barrier is
correct, and it does not let one caller read the other's write.** The lane is right that it
"synchronises the readers but not the subsequent writes".

**What the lane got wrong — and it changes the fix.** "Which refusal path the loser takes depends on
how the two `INSERT`s interleave" is only half of it. The sharper and sufficient statement:

> In D-4 **both callers mint the SAME `credentialId` (`cred-race`) into the SAME repository**. The
> loser's tuple therefore violates **two unique constraints simultaneously** —
> `product_credential_id_unique` (the `ON CONFLICT ("credentialId")` arbiter) **and** the partial
> `product_credential_active_repository_unique` on `("repositoryId") WHERE status <> 'revoked'`.
> **Exactly one row is written either way — that half is deterministic. What varies is which
> constraint Postgres names in the refusal, and nothing in this repository pins that order.**

**Independent corroboration that this is the mechanism:** `T-C` (`:716-744`) constructs the *same*
double-violation **sequentially** — re-mint `cred-1`, whose own row is the repository's active row —
and asserts the *same* `contains('already exists')`. It has not flaked in any of the eight runs. **Same
ambiguity; stable when the insert is sequential, unstable under genuine concurrency.** That is why
T-B never flakes: its two callers use *different* ids, so the loser violates only **one** constraint.

**What I did NOT establish, stated plainly:** the precise PostgreSQL-internal reason the concurrent
case names the partial index on some runs. I did not instrument the disposable database, and a review
lane should not. It is not needed — the finding above is sufficient and is independently checkable
from the DDL.

### 3.4 Is there a real ordering bug being masked? **No in the security path — and yes, one real LOW**

**No masked bug in what D-4 exists to prove.** The three security assertions are deterministic and
held in **all eight runs**: exactly one `RepositoryCredential` returned, exactly one refusal, and
exactly one row in the database. Either refusal leaves the stored row untouched. T-B (deterministic —
one constraint violated), T-C, T-D, GAP-2 and the `+148` unit suite all pin the same invariants
deterministically. **The security content of D-4 is sound; only its message-attribution assertion is
not.**

**But the flake exposes a real, sequentially-reachable diagnostic defect — NEW LOW.** The mint branch
has **no read-back**, unlike the CAS branch (`:341-350`). So when the partial index is the one named,
the store asserts *"another caller recorded one first"* — which is **false** when a single caller
sequentially re-mints the very row that occupies the active slot. It names a race that did not happen.
No test pins it, so nothing would catch it. **Severity LOW: the write is still refused and nothing is
written; only the explanation is wrong.**

### 3.5 Disposition — **does NOT block the merge. Fix the BEHAVIOUR, not the test.**

**Why it does not block:** it is provably not this correction's regression; it is pre-existing in the
reviewed work and in its own test; the invariants D-4 exists to prove hold deterministically in every
run; and the reviewed change's requirements (D-4/D-5) are met.

**Why it is not cosmetic:** the suite gating a security fix is **not deterministically green** and CI
can go red at random, at ~37% across eight runs. The Manager must know that.

**Recommended fix — one change, two defects.** Give the **mint branch** the read-back the CAS branch
already has: when `23505` on `_activeCredentialUniqueIndex` fires, read the row back and, if the stored
`credentialId` equals the one being minted, report the **identity** conflict instead. That (a) makes
D-4's existing assertion correct **unconditionally**, and (b) makes the message **true** in every
case. Small, local to `postgres_product_registry_store.dart`.

**The alternative — relaxing D-4's assertion to accept either refusal — is the wrong trade.** It would
bless a demonstrably false diagnostic in a store contract a future implementer is held to.

**Sequence:** this does not gate the merge. It must be a **tracked item with an owner and a date**,
and it must be fixed before `20261006150645000` reaches a deployed database.

---

## 4. LOW-1 — the lane's judgement was **better** than my instruction, and the comment is correct

I said "name all seven". The lane named the seven enforced columns **and** named `lastFailureReason`
separately as the eighth, explicitly **NOT** claimed as guarded.

**That judgement is right, and here is why.** LOW-1's defect was a *mismatch between prose and
enforcement*. Naming eight while the tiers enforce seven reproduces the **same defect in the opposite
direction** — a reader would conclude clearing `lastFailureReason` is refused when it is not, which
would **suppress the very fix that must land**. My "name all seven" was about the *enforced list*; the
enforced list now has all seven. The lane did not evade the finding; it discharged it correctly.

**And the comment is factually correct about the code. I checked every claim it makes:**

| Claim at `product_registry_store.dart:82-113` | Verified |
|---|---|
| seven columns named, in both tiers' order | ✅ `postgres :321-327` ×7 · `in-memory :287-293` ×7 |
| *"both tiers currently enforce seven"* | ✅ `lastFailureReason` in neither list |
| *"copyWith preserves it on a null argument"* | ✅ `repository_credential.dart:162` |
| *"the only engine writer sets it without clearing it"* | ✅ `product_registry_engine.dart:1074` |
| *"live on the Postgres `SET` clause"* | ✅ `postgres :284` |
| *"a store-level caller handing in a null would erase it on **both tiers**"* | ✅ `in_memory :259` is `_credentials[id] = credential;` — a whole-object **replace** on the CAS path |
| *"Design rev5's `D-6` requires eight columns"* | ✅ rev5 § R.9.4 / `H9` |
| *"A CAS write MUST NOT set any of them back to null"* — the narrowing the baseline approved | ✅ **preserved at `:85`** |

**LOW-1 is CLOSED.** (One rhetorical overreach: *"this paragraph does not have to be edited again when
the set changes"* — the very next paragraph documents the eighth column, so something will be edited
when `D-6` lands. Harmless.)

---

## 5. The NEW MEDIUM (`lastFailureReason`, latent) — recorded, NOT folded in ✅

- **Genuinely absent from the diff.** Every changed Dart line in `a4c211c` is a `///` doc comment
  (verified by grep). `lastFailureReason` appears in the diff **only** in the new prose. Neither tier's
  guard lists changed.
- **Correctly tracked** in three places: the correction lane's §6 **T2**, rev5's **`H9`**, and now the
  in-code declaration itself — so a future implementer cannot miss it.
- **Gap for the Manager:** it is **not** in `docs/engineering/WORK_STATE.md` or `LANES.md`. Put it in
  whatever the durable register is. Required before `20261006150645000` reaches a deployed database.

---

## 6. The new self-test is SAFE — and I made the containment check fire

`apps/server/tool/tests/verify_schema_bootstrap_negative_controls.sh` (300 lines, mode `100755`).
**A self-test that wrote to the repository would destroy the evidence it verifies**, so I did not take
the containment claim on trust. I checked it two ways.

**6.1 Coverage is complete.** `repo_fingerprint` checksums *every* file under
`${server_dir}/tool` and `${server_dir}/migrations` (`find -type f`), plus `Makefile` and
`.github/workflows/integration.yaml` — which is **exactly the guard's full input set** (asset, applier,
reference migration, chain migrations, CI workflow, Makefile). The *after* fingerprint re-runs `find`,
so a **newly created** file under those trees is caught too.

**6.2 The check is LIVE, not decorative — I induced a breach and it fired.** In a throwaway export I
made one case append to the **real** `tool/schema_bootstrap.sql`:

```
FAIL plant-index-in-definition: expected exit 1, got 0 (20 OK, 0 FAIL)
FAIL repository-untouched: a file this harness reads CHANGED during the run.
    Every case is supposed to run in a temporary fixture. The diff:
    -6d2de1517e39868d7d57700f3ed22bccd8e8ea02e749f3bf3d38fc36f6571f90  apps/server/tool/schema_bootstrap.sql
    +91ee9b5798880b635133c1db2162b913a9f168739897dd3e431b8ad9cdc92bdf  apps/server/tool/schema_bootstrap.sql
11 cases, 2 failed.
```

It named the exact file, printed both hashes, and the run exited non-zero. Every write in the harness
targets `${work}` (`mktemp -d`) or a fixture beneath it; `replace_line` deliberately avoids
platform-dependent `sed -i` and fails loudly if the mutation target is not found.

**6.3 The real repository is untouched.** After I ran it: `git status --porcelain` **empty**;
`git diff --exit-code a4c211c -- apps/server/tool/schema_bootstrap.sql` **clean**; no leftover
`verify_schema_bootstrap_controls.*` directories (the trap works).

**6.4 But it is NOT a CI gate.** `.github/workflows/**` was `PROHIBITED` for the lane, so
`grep -rn negative_controls .github/` is **empty**. The guard itself *is* wired
(`ci.yaml:56`, job `schema-guard`); **these twelve controls are not run on any push.** Twelve green
controls locally is **not** a gate, and the lane says so in the script header, in its report, and in
its own summary. **That honesty is correct and the gap must be closed by the Manager.**

---

## 7. Gates — every one re-run by me at `a4c211c`

| Gate | Command | Result |
|---|---|---|
| format | `dart format --output=none --set-exit-if-changed .` | **pass** — `Formatted 631 files (0 changed)`, exit 0 |
| analyze | `dart analyze` | **pass** — exit 0; 2 `info` deprecations, **both in untouched `packages/workflow_engine`** (pre-existing) |
| unit | `cd packages/product_registry && dart test` | **pass** — **`+148: All tests passed!`** |
| schema guard | `apps/server/tool/verify_schema_bootstrap.sh` | **pass** — **20 `OK:`, 0 `FAIL:`, exit 0** |
| self-test | `apps/server/tool/tests/verify_schema_bootstrap_negative_controls.sh` | **pass** — **12 cases, 0 failed**, exit 0 |
| integration | `SERVERPOD_DATABASE_PASSWORD=… make test-integration` | **run 4×** — `+170 -2`, `+171 -1`, `+171 -1`, `+171 -1` |

**`NOT_RUN`: nothing.** No gate was skipped, weakened or removed.

### 7.1 The guard went **18 → 20 by ADDITION** — mechanically proven, not asserted

I diffed the **normalised assertion sets** from the two revisions:

```
removed from 3f3f4f4  ->  (EMPTY)
added at a4c211c      ->  index design_revision_approved_unique_per_work_item: IF NOT EXISTS is asset-only as declared (bootstrap yes, chain no)
                         index product_credential_active_repository_unique: IF NOT EXISTS is both as declared (bootstrap yes, chain yes)
```

**Zero removed, exactly two added, one per index object.** A "fix" that lowers coverage while raising
assertions would have shown up here as removals. It did not. Corroborated independently: deleting only
the new comparison drops the baseline back to **exactly 18** (§2.6). All 14 deletions in the guard are
accounted for: 2 `required_objects` entries gaining a field, 4 loop headers renamed to the validated
projection, 3 self-contradictory comment lines, `ddl_statement` split into `_raw` + stripped form, and
check 4's `sed` → `cut`. **No check was removed.**

### 7.2 Regression risk from the correction — **NONE**

Only three files changed. The guard: proven additive (§7.1). The self-test: new file, contained (§6).
The store comment: **100% doc-comment lines**; the behaviour-narrowing sentence the baseline approved
is preserved verbatim at `:85`. **Nothing in the previously-approved area moved.**

---

## 8. Corrections I am making to the lane's own claims (disclosed)

1. *"its diff touches no `lib/`"* — **literally wrong**: it touches
   `packages/product_registry/lib/src/store/product_registry_store.dart`. **Substance holds** (100%
   doc-comment lines). I verified the substance rather than accepting the claim.
2. *"25 worktrees"* — I count **26**.
3. **T4's mechanism is incomplete** (§3.3): the barrier diagnosis is right; the cause is *two
   simultaneously-violated unique constraints*, not insert interleaving alone. This changes the
   recommended fix.
4. The dispatch's own `:267` oracle label conflates two different `sed`s (§1.1). The lane got it right.

---

## 9. Docker disclosure — **no breach**

- **`make test-integration`, four invocations, and nothing else.**
- **Never** run: `down`, `stop`, `rm`, `prune`, `volume rm`, `compose up`, `pull`, `build`, `--rmi`.
- **Never** run, despite being read-only-looking: `docker compose ps`, `logs`, `config`, `docker info`.
- **Never** `make clean`, `make test-env-down`, `make e2e-down`, or any bare `docker compose … down -v`
  without `-p <project>`. I did not test the rule.
- I read the `test-integration` recipe **as text** (`Makefile:191-230`) *before* running it: it declares
  its own project `shipit_integration_$$$$`, has an unconditional `down -v --remove-orphans` trap, and
  a labelled leak check that reports only a real leak.
- **All four runs tore down their own project and reported removal** —
  `shipit_integration_39302`, `_54426`, `_57136`, `_65318`: each printed `Container … Removed` and
  `Network … Removed`. **`CLEANUP FAILED` count: 0, 0, 0, 0.**
- I did **not** use the `postgresql_query` MCP tool — I could not establish which database it targets,
  and a read-only query against the live QA stack is not something a review lane should guess at.
- **The reviewed worktree is byte-identical to how I found it:** `HEAD` `a4c211c`,
  `git status --porcelain` empty. Every mutation experiment ran in throwaway `git archive` exports
  under `/var/folders/…/T/opencode/`, all removed. **I edited nothing except my own report directory** —
  including `verify_schema_bootstrap.sh` and the self-test.

---

## 10. What I did **NOT** review

- **No full review.** I did not re-review D-1/D-2 non-regression, the SQLSTATE translation,
  `_noClear`'s seven types, tier ordering, `rotateCredential`, or the masking-defect reasoning. Both
  prior reviews cleared those and re-litigating them is outside a focused re-review.
- **I did not verify the nine RESOLVED Human Decisions** and re-opened none.
- **I did not review rev5's full content** — only the `D-6` eight-column requirement and `H9`, and its
  approval status.
- **I did not instrument the disposable Postgres**, so the PostgreSQL-internal reason the concurrent
  D-4 case names the partial index remains unestablished (§3.3). The finding does not depend on it.
- **I did not run any Docker/Compose command** beyond the sanctioned `make test-integration`, so I did
  **not** replay the migration chain onto a bootstrapped database against a live DB — which is the one
  experiment that would settle §3.3 definitively. That needs DB authority a review lane does not hold.
- **I did not fix anything**, including T4.
- **I did not run `.github/workflows`** — the negative controls remain unwired (§6.4).

---

## 11. Minimum remaining steps

**Merge is not gated.** Steps 1–2 are records with owners; step 3 is the one engineering follow-up.

1. **Wire the negative controls into CI** (`.github/workflows/**`, outside this lane's ownership). Twelve
   green controls that nothing runs on every push are **not a gate** — the guard is wired at
   `ci.yaml:56`; its own harness is not.
2. **Put the two tracked items in the durable register** (`WORK_STATE.md` / `LANES.md`), which neither
   currently carries:
   - **`D-6`'s eighth column (`lastFailureReason`)** — latent, unreachable via any engine path, live on
     the Postgres `SET` clause and on the in-memory whole-object replace; **required before
     `20261006150645000` reaches a deployed database.**
   - **T4** (§3) — see step 3.
3. **Fix T4 by fixing the behaviour**, in a separate small change: give the mint branch the read-back
   the CAS branch already has, so the store reports the identity conflict when that is what was
   violated. This makes D-4 deterministic *and* removes a genuinely false diagnostic. **Do not relax
   D-4's assertion instead.** Before `20261006150645000` ships.
4. **Carry forward unchanged** (not mine, not blocking): `design-revision-5.md` is
   `DESIGN_REVIEW_CHANGES_REQUIRED` and **that review report is itself uncommitted** — a design verdict
   with no provenance, in a third place; the duplicate-credential audit must be run by a human against
   every deployed database before `20261006150645000`; `CredentialIdentityConflictException` still needs
   an `exceptions.dart` ownership grant.

**Provenance is settled, the MEDIUM is closed, LOW-1 is closed, the `D-6` finding is properly recorded
and untouched, and nothing regressed.** `a4c211c` is mergeable.

**A revoked credential should not stay resurrectable on `main` while a flaky *test assertion* and a
misleading diagnostic message — neither of which weakens any invariant — are tidied up.**

---

## 12. Cleanup confirmation

- [x] All processes started by this lane are stopped (no integration run in flight; no compose process).
- [x] Temporary artifacts removed (all `git archive` throwaway exports and scratch dirs deleted;
      no leftover `verify_schema_bootstrap_controls.*`).
- [x] `git status --short` clean for tracked files in the worktree — `HEAD` `a4c211c`, empty status.
- [x] No files modified outside `OWNED_PATHS` (this report directory only).

## Files touched

```text
docs/engineering/dispatch/tasks/review-credential-identity-invariants-final/report.md
```

## Model and reasoning effort

```yaml
ROUTING_CLASS_REQUESTED: PRECISION
MODEL_USED: opencode/space-bunny-free
REASONING_EFFORT: n/a
ESCALATED_INSIDE_TASK: NO
ESCALATION_REASON: n/a
```

## Safe parallelism

```yaml
SAFE_PARALLEL_WORK:
  - integration of fix/credential-identity-invariants (a4c211c) into main
  - wiring verify_schema_bootstrap_negative_controls.sh into .github/workflows/ci.yaml
  - the D-6 eighth-column change, on both tiers, with its own SC-17 / T-J / T-K
PROHIBITED_PARALLEL_WORK:
  - any edit to verify_schema_bootstrap.sh by another lane — this review's findings are stated
    against its exact bytes, and §2.6 shows its integrity is what the harness depends on
```

## Recommended next action

`MERGE`

---

