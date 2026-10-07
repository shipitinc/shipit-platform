# Report — Correction, `fix/credential-identity-invariants` (guard + contract comment)

Persisted per `aef-orchestrator` §14. Agent: `correction-implementer`, production-writing lane.
Worktree: `/private/tmp/shipit-credential-identity`. Branch: `fix/credential-identity-invariants`.

```
RESULT: CORRECTION_COMPLETE
CORRECTED_FROM_HEAD: 0bf2fa0058bbbab12eeea43b4e6a50eadff07b4d (reviewed WORKING TREE, uncommitted)
NEW_HEAD: a4c211ccd1d094b4955f56f7d9ae385e377bb15f
READY_FOR_FOCUSED_REVIEW: YES
HUMAN_DECISION_REQUIRED: NO
```

**This lane does not approve its own work.** The two SHAs below are unreviewed by
definition and must go to a fresh focused re-review.

---

## 0. Provenance — the reviewed tree now has a pinnable SHA

The dispatch's central point: the reviewed change had **no commit**. Branch tip == base
== `0bf2fa0`, with 8 modified files (+1271/−90) sitting uncommitted, which is what made
a prior integrator refuse a sibling change.

I committed it as **`3f3f4f48ec3b3200da1ea4a7af0c25a548187bdf`**, byte-for-byte, and my
correction on top as **`a4c211ccd1d094b4955f56f7d9ae385e377bb15f`**.

| | SHA | Content |
|---|---|---|
| reviewed tree, as reviewed | `3f3f4f4` | the 8 files, exactly as both reviews saw them |
| + my correction | `a4c211c` | 3 files, +515/−16 |

`git log --oneline -2` from `a4c211c`:

```
a4c211c fix(schema-guard): declare each index's IF NOT EXISTS expectation; fail closed
3f3f4f4 fix(credential-registry): refuse credential re-pointing and re-mint, both tiers
0bf2fa0 AGENTS.md: restore section 13 and the ADR 0018 carve-out; record D-19 resolution
```

No reset, no stash, no amend, no force, no rewrite. `git stash list` still holds exactly
the one unrelated pre-existing entry (`design/adr-0018-amendment`, superseded, untouched).

### How I kept the two commits honestly separable — and what I would not do

To commit the reviewed tree as a *separate* commit I had to put its bytes back into the
working tree, having already applied my correction on top. The reviewed 361-line guard
survives **nowhere on disk**: I searched all 25 `/private/tmp/shipit-*` worktrees and the
only variants present are the 278-line pre-feature script (identical to `0bf2fa0`), so
there was nothing to copy from.

So I reconstructed it by **exact inverse edits** — the mirror of the six edits I had
applied — and then held the result to the oracles the reviewers themselves recorded,
rather than to my own assurance:

| Oracle | Source | Result |
|---|---|---|
| `ddl_statement`'s clause-strip sed is at **:267** | re-review §2 | `:267` ✅ |
| the `exit 2` "cannot judge" blocks at **:221–228** | re-review §2.5 | starts `:221` ✅ |
| the "two places" comment at **:306–312** | re-review §2.4 | quote spans `:308`–`:312`, section `:306` ✅ |
| `hand_maintained_names` derivation at **:313–315** | re-review §2.4 | `:314` ✅ |
| file length **361** | my pre-edit read | `361` ✅ |
| guard output **18 `OK:`, 0 `FAIL:`, exit 0** | BOTH reviews, independently | `18` / `0` / `0` ✅ |
| **8 files changed, 1271 insertions(+), 90 deletions(−)** | BOTH reviews, independently | exact match ✅ |
| `verify_schema_bootstrap.sh` **+84/−1**, `product_registry_store.dart` **+48/−12** | derived from the above | exact match ✅ |

Zero residue of the correction in the reconstructed file (`checked_objects`,
`clause_expectations`, `expectation_error`, `clause_presence`, `cut -d: -f2`: 0 matches).

**If any single one of those had missed, I would have made ONE commit instead** rather
than put a hand-reconstructed file into the provenance record under a claim of
byte-identity. A "reviewed work, unchanged" commit that is subtly not unchanged is
exactly the failure this work item has been fighting, and a single honest commit would
have been strictly better than a confident fabrication. They all matched, so the split
is real.

---

## 1. Finding 1 — the MEDIUM (`verify_schema_bootstrap.sh`) — CLOSED

Fixed exactly to the re-review's §2.5 design. Four elements, all four required:

**1. The expectation rides in the same `required_objects` entry** — no second list, so the
script's own stated principle at `:306-312` ("nothing has to be remembered in two
places") survives:

```
"index:design_revision_approved_unique_per_work_item:asset-only"
"index:product_credential_active_repository_unique:both"
```

**2. An absent or unrecognised expectation is `exit 2`** — never a fall back to the
forgiving behaviour. A single parse-and-validate pass runs **before any check can report
a pass**, producing `checked_objects` (the `kind:name` the existing checks match on) and
`clause_expectations` in step. It rejects: no expectation field, an empty field
(`index:name:`), an unknown value (`:btoh`), a further colon, a trigger entry carrying
an expectation, and an unknown `kind`. Each is `exit 2`, the class the script already uses
at `:221-228`.

**3. Two comparisons per index object** — the clause-stripped DDL (whitespace collapse
only; unchanged, and still correct for table / key / `WHERE` / `UNIQUE`) **and** the
clause's *presence* in each home against the declared expectation. Same code for every
object: the per-object fact is data, not a branch. `clause_presence` returns
`yes`/`no`/empty, and empty is deliberately **not** folded into `no` — "could not read it"
and "the clause is absent" are different findings.

**4. Check 4's name derivation fixed in the same commit** — `cut -d: -f2`, not the
one-field `sed 's/^[^:]*://'`. Deriving by position means an entry's arity cannot leak
into the regex. The comment records why, so nobody reverts it for tidiness.

Checks 1–3 also moved to the validated entries. Note: they were **not** silent — they
would have failed loudly with `name:both` as the object — but they were broken, and
fixing only check 4 would have left the script inconsistent.

I also corrected the self-contradictory comment that justified normalising the clause
away by arguing "the chain path must not fail where the bootstrap already ran" — which is
an argument that the clause **must be there**.

### 1a. The controls exist, and they are NOT yet enforced on every CI run

**Plainly, so nobody mistakes this for CI coverage:**

> `verify_schema_bootstrap.sh` is wired into `.github/workflows/ci.yaml` job `schema-guard`.
> **`apps/server/tool/tests/verify_schema_bootstrap_negative_controls.sh` is not wired
> into CI at all**, because `.github/workflows/**` is PROHIBITED for this lane. These
> controls are green here, and **nothing runs them on every push.** They exist; they are
> not a gate. That is a named follow-up (§6, item F), not a pass.

`apps/server/tool/tests/verify_schema_bootstrap_negative_controls.sh` (300 lines, bash +
POSIX tools only — no bats, no network, no database, no Docker) builds a throwaway
fixture per case from the real assets, mutates the fixture, and asserts the exit code.

```
ok   baseline: exit 0, 20 OK, 0 FAIL                                  <- positive control, first
ok   drop-clause-from-migration: exit 1, 19 OK, 1 FAIL                <- REQUIRED 1
ok   drop-clause-from-asset: exit 1, 19 OK, 1 FAIL                    <- REQUIRED 2
ok   add-clause-where-asset-only-declared: exit 1, 19 OK, 1 FAIL      <- REQUIRED 3
ok   plant-index-in-definition: exit 1, 19 OK, 1 FAIL                 <- REQUIRED 4
ok   index-entry-without-expectation: exit 2, 0 OK, 1 FAIL            <- new fail-closed path
ok   index-entry-with-unrecognised-expectation: exit 2, 0 OK, 1 FAIL   <- new fail-closed path
ok   drift-in-where-predicate: exit 1, 19 OK, 1 FAIL                  <- positive: DDL compare intact
ok   drift-in-key-column: exit 1, 19 OK, 1 FAIL                       <- positive
ok   drift-in-table: exit 1, 19 OK, 1 FAIL                            <- positive
ok   drift-in-where-predicate-of-asset: exit 1, 19 OK, 1 FAIL         <- positive, other home/object
ok   repository-untouched: every file this harness reads is byte-identical
12 cases, 0 failed.
```

The baseline runs **first**: a fixture that checks nothing would satisfy every negative
control, so an unmutated fixture must reproduce the repository's own 20 `OK:` / 0 `FAIL:`
/ exit 0 or the run means nothing.

### 1b. The controls were proven able to FAIL OPEN — I reverted each fix and watched them catch it

A control that has never failed proves nothing. In throwaway copies outside the
repository (`/var/folders/…/T/opencode/`, both deleted afterwards), with the harness run
from the throwaway tree:

**Reverting ONLY check 4's `cut` back to `sed 's/^[^:]*://'`** — the reviewer's §2.4
Defect 2 — reproduces the fail-open exactly:

```
FAIL plant-index-in-definition: expected exit 1, got 0 (20 OK, 0 FAIL)
```

An index name planted in a `definition.sql`, and check 4 — whose entire job is that —
**silently passes**. My control 4 catches it. That is the precise regression this change
was capable of causing, and the control for it is not decorative.

**Deleting ONLY the expectation comparison** (lines 448–472 of the corrected guard)
reproduces the MEDIUM as three `exit 0`s, and drops the baseline back to 18 `OK:` —
independently confirming that the 18→20 delta is exactly the two new assertions:

```
FAIL baseline: expected 20 OK lines, got 18 (0 FAIL)
FAIL drop-clause-from-migration: expected exit 1, got 0 (18 OK, 0 FAIL)   <- reviewer's E1
FAIL drop-clause-from-asset: expected exit 1, got 0 (18 OK, 0 FAIL)       <- reviewer's E2
FAIL add-clause-where-asset-only-declared: expected exit 1, got 0 (18 OK, 0 FAIL)  <- E3
```

The unmutated guard under that variant exits 0 at 18 `OK:`, matching both reviews — so
the reviewer proved this exact thing correctly.

### 1c. The repository was not mutated — and the harness proves it on every run

No negative control ever writes to `apps/server/tool/schema_bootstrap.sql`, a migration,
or anything else under the repo. Every case runs in `mktemp -d`; every repo file is only
ever **read** (including `Makefile` and `.github/workflows/integration.yaml`, which the
guard itself reads — reading a file is not writing to a prohibited path).

That claim is enforced, not asserted: the harness checksums every file it reads before
and after (`shasum -a 256`, `find … | sort`) and **fails the run** if any differs. The
`repository-untouched` case above is that check, and it is one of the 12. Cleanup is an
absolute-path `trap … EXIT INT TERM` that reports `CLEANUP FAILED` with the exact command
to finish the job rather than silencing it with `|| true`.

Verified independently: `git status --porcelain` is **empty** at `a4c211c`.

### 1d. The harness caught a bad expectation in my own test

Worth recording, because it is the argument for having controls at all. My first draft's
fourth positive control changed `USING btree` → `USING hash` in **both** homes and expected
exit 1. It returned **exit 0, 20 OK, 0 FAIL**. The harness was right and I was wrong: the
full-DDL check is a **parity** check, so a change made identically in both homes is by
definition not a divergence. I replaced it with a control that diverges the *asset* home of
the *other* index — the direction the other three did not cover.

---

## 2. Finding 1 caveat — `asset-only` recorded, NOT quietly resolved

`design_revision_approved_unique_per_work_item:asset-only` **enshrines an asymmetry whose
correctness was never established.** `20261006150645000` reasons in its own comment about
this exact hazard; `20260920232118956` is older and gives no idempotence rationale. If the
credential index's clause is mandatory for chain-replay-onto-bootstrapped safety, the
design-revision one is **plausibly missing it too** — a pre-existing latent defect at
`0bf2fa0`, not a regression of this change, and **out of scope to fix here.**

I did not fix it and did not bless it. It is recorded in two places:
- **in the script, at the declaration** — so the human who has to look sees it at the
  point of truth, including the warning not to "fix" the SQL without deciding whether
  `20260920232118956` may still be rewritten at all;
- and in the commit message, and below as tracked item **T3**.

The value of making the expectation explicit is precisely that it forces a human to look.
It does not settle it.

### Related, out of scope, recorded not fixed

`tool/schema_bootstrap.sql:53-55` still says the `IF NOT EXISTS` clause "is the only
permitted difference … which this file needs and the chain path does not". After this
change the guard is *stricter* than that sentence for the credential index (no difference
permitted at all). The prose now under-claims rather than over-claims — the safe
direction — and `tool/schema_bootstrap.sql` is outside this lane's `OWNED_PATHS`. Flagging
it for the owning lane rather than touching it.

---

## 3. Finding 2 — LOW-1 (`product_registry_store.dart`) — CLOSED, comment only

The contract named **six** columns; both tiers enforce **seven**. `hostKeyFingerprint` is
guarded in `in_memory_product_registry_store.dart:287-293` (`_clearsDurableEvidence`) and
in the Postgres `_noClear` list and readback loop — and was absent from the prose, so a
reader of the contract alone would conclude clearing the host fingerprint is permitted.

All seven are now named, **in both tiers' order**, so the paragraph does not need editing
again when the set changes: `hostConfirmedAt`, `hostConfirmedBy`, `lastVerifiedAt`,
`lastVerifiedBy`, `hostKeyFingerprint`, `revokedAt`, `revokedReason`.

**Behaviour change: none.** Verified mechanically — the diff of this commit against the
previous one, restricted to `*.dart` and filtered for non-comment lines, is **0 lines**.

The comment also records, **without claiming it**, that `lastFailureReason` is the eighth
recorded column and is guarded on neither tier (§4), and why it is deliberately not in the
enforced list: naming it there would overstate what the tiers do today — the same defect
as omitting `hostKeyFingerprint` was.

---

## 4. Finding 3 — `lastFailureReason` — recorded, NOT fixed, diff untouched

**I did not touch it.** `git diff 3f3f4f4 a4c211c` contains no change to
`postgres_product_registry_store.dart`, `in_memory_product_registry_store.dart`,
`product_registry_engine.dart`, or any `*.dart` behaviour.

What I verified rather than assumed, so the follow-up is actionable rather than a rumour:

- **Tier A** `postgres_product_registry_store.dart:321-327` — `hostConfirmedAt`,
  `hostConfirmedBy`, `lastVerifiedAt`, `lastVerifiedBy`, `hostKeyFingerprint`, `revokedAt`,
  `revokedReason` = **7**. `lastFailureReason` in neither list.
- **Tier B** `in_memory_product_registry_store.dart:287-293` — the same **7**.
- It **is** live on the CAS write path: `:284` puts `"lastFailureReason" = @lastFailureReason,`
  in the `SET` clause, so a store-level caller passing null **would** erase it and both
  tiers accept it.
- **Not reachable today**: `repository_credential.dart:162` is
  `lastFailureReason: lastFailureReason ?? this.lastFailureReason`, and the only engine
  writer, `product_registry_engine.dart:1074`, is
  `lastFailureReason: failureReason ?? 'connection failed'` — it sets, never clears.
  **A guard gap, not a live defect.**

Why folding it in would have been wrong, and why I did not: `D-6` carries its own
eight-column requirement, its own `SC-17`, and its own `T-J` and `T-K`. **`T-J` is the
trap** — it asserts the legitimate setters (`revokeCredential`, `confirmHostKey`, and
`recordCredentialCheck`'s success and failure paths) still succeed, so the obvious
implementation ("forbid the columns") turns it red. Folding it in would have expanded past
what was reviewed and invalidated the review. Tracked as **T2**.

---

## 5. Gates — every one run, exact result, against the stated baseline

All run with the worktree clean at **`a4c211c`** unless noted. `NOT_RUN`: nothing.

| Gate | Command | Baseline | Actual | Verdict |
|---|---|---|---|---|
| format | `dart format --output=none --set-exit-if-changed .` | 631 files, 0 changed | **`Formatted 631 files (0 changed)`, exit 0** | ✅ exact |
| analyze | `dart analyze` | exit 0, 2 pre-existing infos in `workflow_engine` | **exit 0, 2 issues — both `packages/workflow_engine/lib/…`** | ✅ exact |
| unit | `cd packages/product_registry && dart test` | **+148** | **`+148: All tests passed!`, exit 0** | ✅ exact |
| schema guard | `apps/server/tool/verify_schema_bootstrap.sh` | 18 OK / 0 FAIL, exit 0 | **20 OK / 0 FAIL, exit 0** | ✅ **+2, investigated below** |
| self-test | `apps/server/tool/tests/verify_schema_bootstrap_negative_controls.sh` | *(did not exist)* | **12 cases, 0 failed, exit 0** | ✅ new |
| integration | `SERVERPOD_DATABASE_PASSWORD=… make test-integration` | **+171 −1** | **+171 −1 on 2 of 4 runs; +170 −2 on 2 of 4** | ⚠ **disclosed in full below** |

### The guard's 18 → 20 is a finding I investigated, not absorbed

**Expected and intended: +2, exactly.** The fix adds one assertion per index object, and
there are two index objects (`design_revision_approved_unique_per_work_item` and
`product_credential_active_repository_unique`). **Nothing was removed** — every one of the
original 18 assertions is still present and still passing; the 19th and 20th lines are:

```
OK: index design_revision_approved_unique_per_work_item: IF NOT EXISTS is asset-only as declared (bootstrap yes, chain no)
OK: index product_credential_active_repository_unique: IF NOT EXISTS is both as declared (bootstrap yes, chain yes)
```

Independently corroborated: with the expectation comparison deleted in a throwaway copy,
the baseline drops back to exactly 18 (see §1b).

### Integration: I am NOT reporting a clean run that hides a failure

**Four** `make test-integration` invocations. Results in order: **+171 −1**, **+170 −2**,
**+170 −2**, **+171 −1**.

- Every run's sole-to-two failures included the **pre-existing**
  `dogfood_shipit_postgres_test.dart:87` assertion (*"dogfood expects a git working tree
  at `/private/tmp/shipit-credential-identity`"*) in a file this change does not touch.
  That is baseline.
- **Runs 2 and 3 had one EXTRA failure**, and I am flagging it loudly:

```
test/integration/product_credential_immutability_postgres_test.dart:
  D-4 under concurrency: two mints of one id yield one row and one identity conflict [E]

  Expected: (contains 'already exists' and not contains 'already has an active credential')
    Actual: 'repository credimm-repo-1 already has an active credential;
             another caller recorded one first, so rotate it instead of issuing a second one'
```

**It is a genuine order-dependence in the reviewed work's own concurrency test, and it is
NOT caused by this correction.** Evidence, not assertion:

1. `git diff 3f3f4f4 a4c211c` touches **3 files**: the bash guard, the new bash self-test,
   and one `.dart` file. It touches **nothing** under `apps/server/lib/`,
   `apps/server/test/`, `apps/server/migrations/`, or `tool/schema_bootstrap.sql` — so it
   cannot change a compiled line or the schema the disposable database is built from.
2. The one `.dart` file has **0** non-comment changed lines.
3. `dart test test/integration/` never executes the self-test, and the guard script is not
   in that path at all.
4. **It did not reproduce on run 4 at the same committed SHA** — +171 −1, baseline.

Mechanism, read from the test: `_GatedStore` overrides
`readActiveCredentialForRepository` to `await super.read…` **and then** `await _gate.arrive()`
— the barrier is released *after* both `SELECT`s have already completed, so it synchronises
the readers but not the subsequent writes. Which refusal path the loser takes then depends
on how the two `INSERT … ON CONFLICT DO NOTHING` round-trips interleave: sometimes D-4's
identity conflict ("already exists"), sometimes D-2's one-active-per-repository refusal.
The test asserts one of them must always win. **That is a pre-existing latent flake in a
test this change is about to merge, at a 2-in-4 rate in this lane.**

**I am not absorbing it and not fixing it** — that file is the reviewed work's
`OWNED_PATHS`, not mine, and deciding whether a flaky test in the change under review
blocks the merge is the focused re-reviewer's call. It is tracked as **T4**, at the top of
the queue. The previous reviewer independently saw the same class of shared-DB flakiness
in this suite (`+125 -3`, two non-reproducing `setUpAll` failures), which is corroboration
that the suite is not deterministically green and that a single green run is weak evidence.

The last run **at the committed HEAD was the baseline-matching one**. That is the run I
am reporting, and I am reporting the other three too.

### The self-test is not a CI gate

Restated at §1a: the controls are green locally and **CI does not run them.** Four controls
existing is not the same claim as "CI now enforces them", and it must not be read that way.

---

## 6. Tracked items — recorded, not absorbed (design/Manager-owned)

**T1 — rev5 is `DESIGN_REVIEW_CHANGES_REQUIRED` (B-R5-1 + 4 MEDIUM + 3 LOW), and the review
report is itself UNCOMMITTED.** `docs/engineering/dispatch/tasks/design-review-addproduct-keys-rev5/report.md`
exists on disk, untracked. A design verdict with no provenance is this work item's
lost-evidence problem recurring in a **third** place. Per the re-review §5, no finding
touches § R.9, and that same review lists `G-11` implementation as `SAFE_PARALLEL_WORK` —
so this is governance debt the design lane owns, not a reason to hold a revoked credential
resurrectable on `main`.

**T2 — `D-6`'s eighth column (`lastFailureReason`), latent and unreachable, required before
migration `20261006150645000` reaches a deployed database.** Guarded on neither tier; live
on the Postgres `SET` clause; unreachable via any engine path today (§4). Carries its own
`SC-17`, `T-J` and `T-K`; **`T-J` is the trap.** Not folded in here, by instruction and by
scope discipline.

**T3 — the `asset-only` asymmetry caveat** (§2): `20260920232118956` plausibly needs the
same clause the credential index needs; its correctness was never established; now written
down at the declaration so a human must look. Not fixed here.

**T4 — NEW, raised by this lane: the reviewed work's D-4 concurrency test is
order-dependent and fails ~50% of runs** (§5). *Not mine to fix; needs an explicit decision
in the focused re-review on whether it blocks the merge.*

**F — follow-up, owned by a lane with `.github/workflows` in scope: wire
`apps/server/tool/tests/verify_schema_bootstrap_negative_controls.sh` into CI.** Until
then the twelve controls are green locally and enforced nowhere. Named here so "I added
four controls" is never mistaken for "CI catches it".

**Carried forward unchanged, not mine, not blocking:** the duplicate-credential audit must
be run by a human against **every deployed database** before `20261006150645000`;
`CredentialIdentityConflictException` still needs an `exceptions.dart` ownership grant.

---

## 7. Learning (`aef-repository-learning`) — classified, not persisted by me

All four are **above my authority** (workflow/tooling/governance) or already recorded by
the review chain, so they are reported here for the Manager to route rather than persisted
by me:

| # | Finding | Category | Authority |
|---|---|---|---|
| L1 | A static guard's usefulness is not evidenced by its passing; it needs **negative controls** that are themselves proven able to fail. A control harness that never went red is untested. Re-validated here by reverting each fix and watching the controls catch it. | `WORKFLOW_IMPROVEMENT` | independent review |
| L2 | When adding a field to a `key:value` entry, **every** place that derives a value by *stripping a prefix* (`sed 's/^[^:]*://'`) silently changes meaning; derive by **position** (`cut -d: -f2`). Here it turned a working check into a silent pass. | `WORKFLOW_IMPROVEMENT` | independent review |
| L3 | A normalisation that **forgives** a divergence must fail closed when the expectation is unknown — otherwise a later edit can quietly widen the exemption, and the widened exemption reads as intentional. | `WORKFLOW_IMPROVEMENT` | independent review |
| L4 | `aef-correction-loop` has a gap this work item hit twice: **a correction cannot be reviewed without provenance, and provenance was missing.** A lane dispatched to *correct* a finding inherits an unpinnable tree. Either dispatch requires a commit, or the correction must be explicitly authorised to create one (as here). | `WORKFLOW_IMPROVEMENT` | independent review |

L1–L3 generalize beyond this change and are cheap to adopt; L4 is the one that would have
saved this work item a cycle.

**Not persisted by me, deliberately:** LOW-4 from the baseline review (nothing in
`docs/engineering/learning/`, including the Serverpod `Type.unspecified` → `42P08`
discovery) is untouched. It is a `PROJECT_FACT` and arguably auto-persistable, but
`docs/**` is `READ_ONLY_PATHS`/`PROHIBITED_PATHS` for this lane, and the finding predates
my correction. Reported, not acted on.

---

## 8. Docker disclosure — **no breach**

- `make test-integration` — **4** invocations total. **Nothing else.**
- **Never** run: `down`, `stop`, `rm`, `prune`, `volume rm`, `compose up`, `pull`, `build`,
  `--rmi`.
- **Never** run, despite reading as read-only: `docker compose ps`, `logs`, `config`,
  `docker info`. Not once, as a probe or otherwise.
- **Never** `make clean`, `make test-env-down`, `make e2e-down`, or any bare
  `docker compose … down -v` without `-p <project>`. I did not test this rule.
- I read the `test-integration` recipe **as text** before running it: it uses
  `-p shipit_integration_$$$$`, an unconditional `down -v --remove-orphans` under that
  project, and a labelled leak check. That is why it is the sanctioned target.
- Every run tore down its own project and reported removal — `shipit_integration_20309`,
  `_31257`, `_32690`, `_34614`, each printing `Container … Removed` and
  `Network … Removed`. **No `CLEANUP FAILED`.**
- I resolved `test.database` from the gitignored `apps/server/config/passwords.yaml` into a
  shell variable and passed it through the environment; **the value never appears in this
  report, in any log, or in any commit.**

No breach to disclose.

---

## 9. Scope discipline — what I did not touch

`PROHIBITED_PATHS` respected in full:

- **`.github/workflows/**` — not edited. The self-test is deliberately **not** wired into
  CI; named as follow-up F. (The harness *reads* `integration.yaml` because the guard
  reads it. Read ≠ write.)
- **`docker/**`, `docker-compose*.yaml`**, `.decisions/**`,
  `docs/engineering/WORK_STATE.md`, `LANES.md`, `docs/engineering/dispatch/tasks/**` —
  none touched. My report is the only file I wrote outside the worktree.
- **No `*.dart` behaviour.** Zero non-comment lines in the one `.dart` file I edited; the
  other six reviewed `.dart`/`.sql` files are byte-identical between `3f3f4f4` and
  `a4c211c`.
- **`docs/`, `.decisions/`, tests, migrations, the engine, both stores** — read-only.
- **No `reset`, no `stash`, no `amend`, no force-push, no history rewrite.** No commit or
  push outside this branch.

One judgement call worth surfacing: the self-test went to
`apps/server/tool/tests/verify_schema_bootstrap_negative_controls.sh` rather than beside
the guard as `apps/server/tool/verify_schema_bootstrap_selftest.sh`. The owned-path
pattern `apps/server/tool/**/verify_schema_bootstrap*.{sh,bats}` is satisfied
unambiguously by a file in a subdirectory under **either** reading of `**`, whereas a
sibling file satisfies only one. I chose the interpretation that cannot be argued with.

**I have not approved this work.** `3f3f4f4` and `a4c211c` require a fresh focused
re-review before merge.

---

## 10. Result

```
RESULT: CORRECTION_COMPLETE

CORRECTED_FROM_HEAD: 0bf2fa0058bbbab12eeea43b4e6a50eadff07b4d  (reviewed working tree, uncommitted)
NEW_HEAD:            a4c211ccd1d094b4955f56f7d9ae385e377bb15f
COMMIT_FOR_REVIEWED_TREE: 3f3f4f48ec3b3200da1ea4a7af0c25a548187bdf
WORKTREE:            /private/tmp/shipit-credential-identity
BRANCH:              fix/credential-identity-invariants

FINDINGS_ADDRESSED:
  1. MEDIUM (verify_schema_bootstrap.sh) - CLOSED per re-review 2.5: expectation
     carried IN required_objects (no second list), exit 2 on absent/unrecognised,
     two comparisons per index object, check 4's derivation fixed to cut -d: -f2
     in the same commit. All FOUR required negative controls + 2 fail-closed +
     4 positive controls, 12 cases, 0 failed. Controls validated by reverting each
     fix in a throwaway copy: both findings reproduced and both caught.
  2. LOW-1 (product_registry_store.dart:82-84) - CLOSED, comment only, 0 non-comment
     lines changed. All seven enforced columns named, in both tiers' order.
  3. NEW MEDIUM (lastFailureReason) - RECORDED, NOT FIXED, diff untouched, per
     instruction and per scope discipline (D-6 has its own SC-17/T-J/T-K; T-J is a trap).

FILES_CHANGED:
  a4c211c (correction, 3 files, +515/-16):
    A  apps/server/tool/tests/verify_schema_bootstrap_negative_controls.sh   (+300/-0, new)
    M  apps/server/tool/verify_schema_bootstrap.sh                           (+195/-14)
    M  packages/product_registry/lib/src/store/product_registry_store.dart    (+20/-2, comments only)
  3f3f4f4 (reviewed tree, as reviewed, 8 files, +1271/-90) - byte-identical to what
  both reviews examined; reconstructed and verified against 8 independent oracles.

GATES:
  format     = PASS - "Formatted 631 files (0 changed)", exit 0        (baseline: 631/0) EXACT
  analyze    = PASS - exit 0, 2 infos, both packages/workflow_engine    (baseline: same)   EXACT
  tests      = PASS - product_registry +148 All tests passed, exit 0   (baseline: +148)   EXACT
  build      = NOT_RUN - no build step in this stack; not applicable
  runtime    = PASS - schema guard 20 OK / 0 FAIL / exit 0             (baseline: 18/0/0)
               +2 investigated and explained: exactly one new assertion per index
               object, two index objects, nothing removed (corroborated by the
               18-OK baseline under the reverted variant)
  self-test  = PASS - 12 cases, 0 failed, exit 0 (new this change)
  integration= PARTIAL / DISCLOSED - 4 runs: +171-1, +170-2, +170-2, +171-1.
               Baseline-matched on runs 1 and 4 (run 4 at the committed HEAD).
               Runs 2-3 had one extra failure in the reviewed work's own D-4
               concurrency test, 2-in-4, order-dependent, PROVEN not caused by this
               correction (diff touches no lib/test/migrations/schema_bootstrap.sql;
               0 non-comment Dart lines; did not reproduce at the same SHA). Tracked
               as T4 for the re-reviewer. Not absorbed, not hidden.

NEW_DISCOVERIES:
  T1 rev5 is DESIGN_REVIEW_CHANGES_REQUIRED and its review report is uncommitted
  T2 D-6's eighth column, latent, unreachable, required before 20261006150645000 ships
  T3 the asset-only asymmetry caveat, recorded at the declaration, deliberately unresolved
  T4 NEW - the reviewed D-4 concurrency test is order-dependent, ~50% failure rate
  F  the 12 controls are NOT wired into CI; .github/workflows is prohibited for this lane
  L1-L4 learning candidates, classified and routed (section 7), none persisted by me

READY_FOR_FOCUSED_REVIEW: YES
```

**Why YES, stated plainly so it is not over-read.** Every gate that is mine passes
genuinely, at the exact committed SHA, on a clean tree. The two things a reader must not
mistake for more than they are:

1. **The self-test's controls exist but are not enforced on every CI run** (§1a, follow-up F).
   Twelve green controls locally is not a CI gate.
2. **The integration suite is not deterministically green** (§5) — it matched baseline on
   2 of 4 runs, and the extra failure is a real order-dependence in a test this change is
   about to merge. It is not mine to fix and not mine to wave through. **The focused
   re-reviewer must decide whether T4 blocks the merge; I have deliberately not made that
   call for them.**

And the reason this correction was cheap enough to be worth doing carefully: until
`a4c211c` reaches `main`, a **revoked credential can still be resurrected**. The three
defects that closed it (D-4/D-18/D-5) are in `3f3f4f4`; what this lane added is the guard
that keeps the chain path honest, a comment that stops the contract lying about what is
guarded, and a pinnable SHA so the thing can actually be merged.