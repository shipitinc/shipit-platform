# Design Revision 7 — the cross-reference convention, closing the dangling-pointer class

**Revision ID**: `3877696f-c15d-4ea8-9941-898fa601bf44` — a UUIDv4 minted by this lane with `uuidgen`,
lowercased, on 2026-10-07, as Revision 6 did for its own. **It identifies this artifact only. It is not an
approval.**
**Brief ID**: `97484D0E-E16C-485E-BAA2-A277889C0FB6` · **Brief version**: `1.1.0` (`design-brief-1.1.0.md`) —
**NOT re-issued**; no brief acceptance changes.
**Revision number**: 7 · **Status**: `DRAFT` · **Risk level**: **3** (carried from Revisions 5 and 6,
re-affirmed independently at `14b0267` — § 2)
**Supersedes**: `d26658219dea4955b0d2b4004a70aa4d` (Revision 6). **Revision 6's four artifacts are retained
byte-identical** at `2187065c…` / `5a9b5ae0…` / `fafcf362…` / `49b74ba5…`, **committed on `main` at
`af8e30f`** and carried into this base unchanged. **Revision 7 edits no line of them**, and this artifact
cites them **by `file:line` against that committed blob** — which is only possible *because* they were not
edited. § R.1-j says why the decline is deliberate and what it costs.
**Worktree**: `/private/tmp/shipit-correct-addproduct-keys` · **Branch**: `design-correct-addproduct-keys`
· **Base SHA**: `14b0267` · **HEAD SHA**: `14b0267` · **Committed**: **NO** · **Pushed**: **NO**

> **No revision in this chain has ever been approved.** Revision 2's `DESIGN_REVIEW_APPROVED` certified
> Revision 2's content and did not carry over. Revisions 3, 4, 5 and 6 each returned
> `CHANGES_REQUIRED` (`REVIEWED_HEAD` `361256c8`, `289f1d3`, `af8e30f`). **Revision 7 carries no approval
> of any kind behind it**, and **its author does not approve it.**

**No Docker or Compose command was executed by this lane** — none issued, not even a read-only one. No
analyzer, build, test or contrast tool was run. **No Penpot tool was called**; no board was read, listed,
exported, edited, renamed, moved or deleted. This lane holds **no board ownership** and cites every board
measurement rather than reproducing it (§ R.11g-h, incorporated). Every gate this lane did not run is
reported `NOT_RUN` (§ 7).

---

## 0. What this pass is, and what it deliberately is not

### 0.1 The verdict it answers

Revision 6's focused re-review returned `RESULT: DESIGN_REVIEW_CHANGES_REQUIRED` —
**0 BLOCKERS, 3 HIGH, 1 MEDIUM, 4 LOW**, `REVIEWED_HEAD: af8e30f`, `CORRECTION_REQUIRED: YES`,
`HUMAN_DECISION_REQUIRED: NO`, `INDEPENDENT_RISK_LEVEL: 3`, `RISK_LEVEL_AGREEMENT: YES`.

Of the eight findings, **none touches design content about the key flow.** All eight are defects in
Revision 6's **self-description**: a cross-reference to a section that does not exist, a closure claim its
own falsifier refutes, two wrong counts, an enumeration that contradicts itself, and four wording faults.

**This revision therefore changes no design content about the key flow, and says so rather than
manufacturing change.**

### 0.2 What the re-review confirmed, and what this lane therefore did **not** re-derive

Recorded because a correction pass that re-litigates settled ground is itself a defect. Each was verified
by the reviewer at byte level, and **this lane re-derived only the cross-references and counts Revision 6
itself carries**, because those are what it changed.

| The reviewer confirmed at byte level | This lane's position |
|---|---|
| **`B-R5-1`'s four parts all applied correctly** — `G-18` in **both** registers; **Revision 6 § 10.1-h** item 12 with the owner `27ea6536` itself named; the scoped **Revision 6 § R.11g-h** rule with a **four**-edit owner table; `G-19` registered with the writing lane touching nothing | **Accepted as settled.** All four are present and are re-verified by *reference existence* in § 0.4.1. **None is re-argued** |
| **§ 0.4's sweep arithmetic is sound and the third error is genuine** — Revision 5's `content_pins` carries 3 real hashes + 1 `SELF-EXCLUDED`, the unpinned file being the one holding `risk_level`/`gates`/`requirements_gaps`/changelog | **Accepted as settled.** Carried forward (§ 0.5) |
| **`G-20` verified strongly** — Revision 3 was never added before `af8e30f`; the committed artifact is byte-identical to what was measured (blob `1364727434…`, 137 494 bytes); the `2838` checks out | **Accepted as settled — and re-verified at `14b0267`, where it is now DISCHARGED** (§ 0.6) |
| **`5436a4d` really is `289f1d3`'s direct parent** | **Accepted as settled.** **Revision 5 § R.6** stands; no change |
| **The `G-19` note the Manager applied is SOUND**, including its framing — the object's recorded recommendation was `OPTION_A` "keep desktop copy", so *"the conclusion — that the copy stays"* is exact; the observation is what was measured; `27ea6536` is `type: DESIGN` with the owner as authority | **Accepted as settled.** No misrepresentation is recorded and none is alleged. **The two residual items the reviewer raised are a different matter and are registered** (`G-19`, residual items R-1 and R-2) |
| **`G-18`'s coverage/completion distinction is HONEST, not convenient** | **Accepted as settled** — and carried *further* in **Revision 7 § 10.1-j** item 12, because the ownership grant has since been issued and the distinction is now load-bearing |
| **The pin loop IS fixed and byte-exact** | **Accepted as settled. THE PINS ARE NOT RE-FIXED.** Only the *claim* about them is corrected (§ 0.4, `L-R5-1` row) |

### 0.3 Provenance — base `14b0267`, and a pre-flight recovery recorded rather than smoothed

**This revision's base is `14b0267`, not `1c3f5ad`.** `main` advanced by five commits while Revision 6 was
under review, and one of them (`14b0267`) carries material this pass must not miss. The pre-flight hit the
condition the dispatch warned about, and the resolution is recorded here in full because it is not a
formality.

#### 0.3.1 The fast-forward was refused first, and 19 shadowing files were recovered

`git merge --ff-only 14b0267` **refused**:

```
error: Your local changes to the following files would be overwritten by merge:
        design-revision-2.md  design-revision-4.md  design-revision-metadata-2.yaml
        design-revision-metadata-4.yaml  design-revision-metadata.yaml  design-revision.md
        discoveries.md  report-revision-4.md  traceability-matrix-2.md
        traceability-matrix-4.md  traceability-matrix.md
error: The following untracked working tree files would be overwritten by merge:
        design-revision-3.md  design-revision-6.md  design-revision-metadata-3.yaml
        design-revision-metadata-6.yaml  report-revision-3.md  report-revision-6.md
        traceability-matrix-3.md  traceability-matrix-6.md
Aborting
Updating 1c3f5ad..14b0267
```

**11 tracked files modified + 8 untracked = 19 shadowing files.** Before anything was removed, **all 19
were compared with `git hash-object` against the blobs `14b0267` carries. All 19 were byte-identical**, so
**none genuinely differed and no lane had to be stopped**. A full copy was taken **outside the repository
first**; the 8 untracked copies were then **moved out** (not deleted) and the 11 tracked modifications
restored with `git checkout --`; the fast-forward proceeded; and the 8 files were **re-compared after the
merge against the backup, all 8 identical**. `git status` is clean. **No content was discarded.**

**This is discovery `F-16`, and it is the second time this worktree has refused a fast-forward.** Revision
6 recorded the identical event for Revision 5's four artifacts (§ 0.3.1 of that revision). The class is
now established: *a lane's own artifacts, committed by someone else, shadowed by uncommitted copies in the
lane's worktree.* It is registered as **`G-22`**, because the residue — that Revision 6 still carries false
text on disk — is a Manager-owned item, not a silent fact.

#### 0.3.2 Two things changed on `main` while this pass was being dispatched, and both are load-bearing

**1. Accepted risk A1 was RETIRED BY THE OWNER on 2026-10-07.** Recorded, per the dispatch, as **the
owner's decision and not a design lane's**, and verified here against the shipped code and the ADR lane's
own scope note. § 0.7.

**2. ADR 0018's own body still records FOUR accepted risks.** The retirement is in the two decision
objects; it is **not** in the ADR. `docs/adr/**` is `PROHIBITED_PATHS` for this lane. Registered as
**`G-21`** — and it is the reason this revision says **three** while the ADR still says **four**, rather
than quietly matching one or the other.

#### 0.3.3 This lane's own commit status, stated without ambiguity

| | |
|---|---|
| Revision 6's four artifacts | **COMMITTED** on `main` at `af8e30f`, carried into `14b0267` unchanged |
| Revision 5's four artifacts | **COMMITTED** on `main` at `16cd497`, unchanged throughout |
| Revision 3's four artifacts | **COMMITTED** on `main` at `af8e30f` — **this is new** (§ 0.6) |
| The 11 superseded banners | **COMMITTED** at `af8e30f` — **this is new** (§ 0.6) |
| This lane's four Revision-7 artifacts | **UNCOMMITTED** in this worktree, as instructed. **Revision 6 is committed underneath them** |
| `.decisions/**`, `docs/adr/**` | **NOT TOUCHED.** `G-19`'s target and `G-21`'s target are Manager-owned and `PROHIBITED_PATHS`; the exact record fixes are specified in **Revision 7 § 7-j** |

### 0.4 Correction map — the rev-6 re-review, **3 HIGH · 1 MEDIUM · 4 LOW**, every row swept

**This is Revision 7's correction map, and it replaces Revision 6's § 0.4.** Revision 6's § 0.4 was itself
a re-derivation; this one is re-derived again, **against the live document**, and § R.11g-j's audit
extracts and resolves **every `§` token in all four Revision-6 artifacts** — not a spot-check. The count is
visible from its own arithmetic: **3 + 1 + 4 = 8**.

| # | Finding | Class | Where this revision corrects it | Swept? |
|---|---|---|---|---|
| **H-1** | `§ 10.2-h` does not exist. `design-revision-6.md:277` and `design-revision-metadata-6.yaml:352` both point at it and make **three untrue claims**; `:282-284` contradicts itself by omitting § 10.2 from its own restated-list | **HIGH** | **Not patched — re-derived.** The two dead pointers are corrected by *describing § 10.2 correctly* (§ R.1-j row, § R.11g-j rule **R3**), and **all 45 mis-resolving sites across the four Revision-6 artifacts are enumerated and classified** in § R.11g-j § A. § 0.4.1 records that the re-review reported **1** target / **2** sites and this lane found **7** / **45** | ✅ |
| **H-2** | `L-R5-1` reported closed on a false claim; `traceability-matrix-6.md:85`'s own falsifier is satisfied by four entries | **HIGH** | **The pins are NOT re-fixed** — the loop is real and the reviewer confirmed it byte-exact. The **claim** is restated accurately at **all eight** sites that assert it (the reviewer found five; **three more exist**: `design-revision-6.md:162`, `report-revision-6.md:286`, `report-revision-6.md:518`), the `two self-excluded files` miscount at `metadata-6.yaml:470` is corrected to **four**, and the falsifier at `traceability-matrix-7.md` § 2 is **amended to test what the artifact does**. § R.11g-j § B records the exact property | ✅ |
| **H-3** | Both register row counts wrong: actual **15 → 18** and **16 → 19**, not 19 → 22 | **HIGH** | **Re-counted from the live documents** (§ 0.5) and stated correctly, together with **Revision 7's own** figures — **21 rows / 22 entries** — so the register does not simply acquire a new wrong pair | ✅ |
| **M-1** | § 0.4.1 enumerated **17** rows as "sixteen check out", including `L13` which the next bullet calls wrong | **MEDIUM** | `L13` is dropped from the enumeration, leaving **16** names. The sweep's arithmetic is re-derived and stated: **16 + `L8` + `M5` + `L13` = 19**. § R.11g-j rule **R4** makes the extraction mechanical so the list and the count cannot diverge again | ✅ |
| **LOW-1** | The `G-19` note normalizes an em dash to a hyphen in the string it quotes | **LOW** | **The root cause is in Revision 6, not in the decision.** `design-revision-6.md:523` — the **paste-ready note block Revision 6 supplied** — carries the hyphen, and `design-revision-metadata-6.yaml:360` carries it too. **Both are fixed here.** The copy already pasted into `.decisions/27ea6536:175` is **not mine to edit**: § 7-j re-supplies the corrected block and names the Manager | ✅ |
| **LOW-2** | `27ea6536` carries a **third** inaccurate statement, unregistered | **LOW** | **Registered as `G-19` residual item R-2**, with its exact location (`:120` against its own `:15-17`) and with the scope limit stated: it was **not measured** by either desktop pass, so it does **not** widen `G-18`. § 7-j supplies the append-only text | ✅ |
| **LOW-3** | `G-20` and its two echoes are stale at the reviewed HEAD | **LOW** | **Re-verified at `14b0267` and DISCHARGED** (§ 0.6). The "before" claims are re-anchored to `1c3f5ad`, where they are true, and the register entry carries a **status** rather than being deleted | ✅ |
| **LOW-4** | `design-revision-5.md` has **no forward pointer** to Revision 6 | **LOW** | **Not fixed on Revision 5, and the reason is recorded rather than repeated.** Revision 5 is committed and this lane may not commit; editing it would dirty a committed artifact to add a pointer that the chain already provides. **The residual is registered as `G-22`** with the exact banner text for whoever commits next, and **Revision 5's zero mentions of Revision 6 are re-verified at `14b0267`** | ✅ |

### 0.4.1 What the sweep found — reported as the sweep's own result, with its limit

**Method: mechanical extraction, not reading.** Every `§`-token in all four Revision-6 artifacts was
extracted with its `file:line`, then resolved against the **live heading inventory** of each target
document — Revision 6, Revision 5, `report-revision-6.md`, `traceability-matrix-6.md`, the mobile lane's
`penpot-board-evidence.md`, the rev-5 review report, `AGENTS.md` and the framework skill. § R.11g-j § A is
the result. **Every `file:line` citation Revision 6 carries into its superseded artifacts was re-read at
`14b0267`** (§ 7, `V-1`).

**The sweep's result, stated plainly:**

- **7 distinct cross-reference targets mis-resolve, across 45 sites.** The re-review reported **1**
  (`§ 10.2-h`) at **2** sites. **Six targets — 43 sites — were not reported.**
- **Of the eight sites asserting the false `blob_hash` claim, three were not reported.**
- **The em-dash defect has a second site that IS mine** (`design-revision-6.md:523`), and it is the
  **cause** of the one in `.decisions/**`. The re-review recorded only the effect.
- **The `27ea6536` self-contradiction is confirmed at byte level** (`:120` against `:15-17`).
- **The row counts are confirmed by direct count**, and the `§ 10.2-h` absence is confirmed against the
  full heading inventory.

**The sweep's own limit, stated rather than implied.** This sweep resolves **cross-references and counts**.
It does **not** re-verify Revision 5's 3 372 incorporated lines, the two boards' measurements, or the
design content about the key flow — all carried as settled by § 0.2. **It did not call Penpot and cannot:
this lane holds no board ownership.** § 7.3's `UNVERIFIED` rows are unchanged from Revision 6's.

**The limit that matters, and why reading would not have caught this.** The re-reviewer read Revision 6's
Revision 6's § R.1 incorporation table, enumerated Revision 5's headings, and confirmed **every named target exists**.
That test is correct and it passed — and it could not find H-1, because H-1 is not a missing *target*, it is
a *reference* whose text asserts a target that does not exist while the surrounding table's targets all do.
**A target-existence check cannot see a lie in the cell describing the target.** § R.11g-j's rule **R4**
replaces the reading with an extraction.

### 0.5 The register counts, re-counted from the live documents (H-3)

Counted directly, not inferred. Revision 5's § R.18.2 body rows, in order:

```
G-4  G-3  G-5  G-6  G-8  G-10  G-11  G-12  G-13  G-16  G-17  G-14  G-15  L-6
ADR 0018 :103 wording                                                            = 15 rows
```

Revision 5's `requirements_gaps` is the same **15** plus `"the Rev-4 review report"` = **16 entries**.

| Register | Revision 5 | Revision 6 | **Revision 7** |
|---|---|---|---|
| Revision 5 § R.18.2 (rows) | **15** | 15 + 3 = **18** | 18 + 3 = **21 rows** |
| `requirements_gaps` (entries) | **16** | 16 + 3 = **19** | 19 + 3 = **22 entries** |

**The load-bearing claims are the deltas and the entry-level agreement, and both hold.** Revision 6 added
exactly three ids to each register, with identical summaries and owners, and the "+3 / +3" was right even
though both absolute "before" figures were wrong by 4 and 3. Revision 7 adds `G-21`, `G-22`, `G-23` to both.
**The asymmetry between the two registers is not an error**: Revision 5 § R.18.2 has no row for *"the Rev-4 review
report"* because that entry is **closed** in § 0.5, while `requirements_gaps` carries it marked `CLOSED` so
the residue survives. **18 vs 19 at Revision 6, 21 vs 22 at Revision 7 — stated, not smoothed.**

### 0.6 `G-20` is DISCHARGED (LOW-3) — re-verified at `14b0267`, not asserted

Revision 6 registered `G-20` because its own supersession chain was not on disk. That was **true at
`1c3f5ad`** and is **false at `14b0267`**. Re-verified here, with the same commands and full paths:

```
$ git log --all --oneline --diff-filter=A -- \
    .../design-addproduct-keyservice/design-revision-3.md
af8e30f docs(keys): persist revision 6 and revision 3; append the G-19 record correction to 27ea6536
```

— the same single commit for `design-revision-metadata-3.yaml`, `report-revision-3.md` and
`traceability-matrix-3.md`. And the 11 banners: `git status --porcelain` for this lane's directory returns
**empty** at `14b0267`, and `design-revision-2.md:1` and `design-revision-4.md:1` now carry
`> ## SUPERSEDED BY DESIGN REVISION 5`.

**`G-20` is CLOSED — DISCHARGED at `af8e30f` by the Manager's commit.** Revision 6's "before" claims are
**true and retained, re-anchored to `1c3f5ad`**, which is the base they were written at. The register entry
**keeps a status** rather than being deleted, because a gap that was real and was discharged is a fact, and
deleting it would leave the next reader to re-derive the residue.

### 0.7 Accepted risks: **three** — A1 retired **by the owner**, and the half it does not reach

**Recorded as the owner's decision, not a design lane's.** Two prior lanes (the rev-6 re-review's author
and the ADR lane) deliberately declined to retire A1 on the grounds that *"retiring it is the owner's
call"* — `876c6b97`'s first scope note says so in those words — **and they were right to.** A design lane
may not retire an accepted risk. The owner has now retired it; this revision records that fact and
attributes it.

**Evidence, checked here rather than adopted.**

| Claim | This lane's verification at `14b0267` |
|---|---|
| The mint is insert-only **on the Postgres tier** | `postgres_product_registry_store.dart:190-191` — *"A MINT NEVER OVERWRITES AN EXISTING IDENTITY — the null-`expectedVersion` branch is `DO NOTHING`, not a predicated `DO UPDATE`"*, followed by the resurrection path it closes |
| …**and on the in-memory tier** | `in_memory_product_registry_store.dart:167-169, 184` — *"is INSERT-ONLY. Checked FIRST…"*, refusing with *"a credential with this id already exists; minting is insert-only…"* |
| …and the engine states it as a contract | `product_registry_engine.dart:933-936` — *"`[credentialId]` must be a NEW identity. A mint is insert-only: supplying an id that already exists is refused by the store and changes nothing — whether the supplied material differs, matches, or the existing credential is revoked."* |
| The decision object records the retirement | `876c6b97`'s second scope note, appended at `14b0267`: *"the repository owner RETIRED A1 on 2026-10-07 after being shown that 08c7590 made the mint insert-only on both tiers. **THREE are now recorded (A2, A3, A4).**"* |

**Three accepted risks remain: `A2`, `A3`, `A4`.**

⚠ **Three readings of "A1" exist and this paragraph uses only the first.** Confusing them has already caused
one wrong conclusion in this work item, and the ADR now carries a three-way identifier table for that
reason.

| "A1" | Status | What it is |
|---|---|---|
| **Accepted risk A1** — *a revoked credential can be resurrected by a re-mint* | **RETIRED by the owner, 2026-10-07** | the thing retired above |
| **Amendment A1** — *"Scope is the repository, not the product"* (`docs/adr/0018…:35`) | **LIVE** | and it is **live in the code today**: `product_registry_store.dart:47` reads *"KEY MATERIAL IS IMMUTABLE (ADR 0018 A1)"* and `:52-53` *"ADR 0018 A1, 'scope is the repository'"*. **A reader told "A1 was retired" who meets these comments must not conclude the immutability rule is retired.** It is not |
| **Substrate option A1** — filesystem `0600` | **LIVE** — ADR `:107`, `:442` | the documented fallback when no secret manager is reachable |

**The half retirement does not reach, stated because it is the half that is still open.** A1 was the
**resurrection** half of the revocation clause. **No code destroys a secret-manager handle** — verified
here: `grep -rniE 'destroySecret|deleteSecret|removeSecret|secretManager\.delete' --include='*.dart' apps
packages` returns **0 matches**. So **revocation remains one-sided in practice**, and **that half was never
an accepted risk**: retiring A1 did not accept it, close it, or transfer it to `A2`–`A4`. It is `79e860e2`'s
territory. **A closed gap must never launder an open one.** Carried forward into § R.6-j.

**What is NOT changed by any of this: the design.** Substrate choice, custody model, the eight-column
`D-6` set, `G-14`, `G-10`'s unrun probe and `A4`'s unproven reachability are all untouched. `A4` remains
accepted **and** unproven, which is the combination that makes it worth recording.

---

## R.1 — Incorporated from Revision 6, unchanged, and where to find it

**Revision 7 is a precision correction pass. It does not restate Revision 6's design.** The following are
**incorporated verbatim by reference** from the named artifact and **not** reproduced here. Reproducing
them would create a second copy that can drift, which is a defect, not a completeness.

**Every Revision-5 § target below was verified to exist by direct heading enumeration at `14b0267`** (§ 7,
`V-2`). **The one row that Revision 6 got wrong is marked and corrected.**

| Revision 6 § | Content | Status at Revision 7 |
|---|---|---|
| § 0.1 | the verdict it answers | **Incorporated unchanged** |
| § 0.2 | what the reviewer confirmed, and what was not re-derived | **Incorporated unchanged**, and **extended by § 0.2 above** |
| § 0.3, § 0.3.1–§ 0.3.4 | provenance at base `1c3f5ad`; the 11 banners; the declined false Manager premise; the commit-status table | **Incorporated unchanged as a record of `1c3f5ad`.** § 0.3 above is Revision 7's own provenance and **does not replace it**. Its `G-20` conclusions are **discharged** at `14b0267` (§ 0.6) |
| § 0.4, § 0.4.1 | Revision 6's own correction map and sweep | **Superseded by § 0.4 and § 0.4.1 above.** Retained byte-identical; **not corrected in place** — see § R.1-j |
| § 0.5 | the `PROVENANCE_GAP` reconciliation | **Incorporated unchanged** |
| § 0.6 | `5436a4d` is `289f1d3`'s parent | **Incorporated unchanged** |
| § 2, § 2.1, § 2.2, § 2.3 | risk level **3**, the verbatim tally, the six grounds, the governance-debt argument | **Incorporated unchanged.** **Revision 7 § 2.1** carries the tally verbatim and **re-affirms** it; **§ 2.2** re-derives the six grounds; **§ 2.3** carries the governance-debt argument **forward and strengthens it** |
| Revision 5 § 0.2, § 0.3 | the ADR acceptance; provenance and the 22-row citation index | **Incorporated unchanged** |
| Revision 5 § R.1 – § R.10.3 | the at-rest model, the domain constraints, `referenceName`, the withdrawn substrate set, the degraded path, two-sided revocation, transport exposure, the store invariant, the per-tier specification, the key flow | **Incorporated unchanged. Revision 5 § R.6 is ANNOTATED, not amended** — see **Revision 7 § R.6-j** |
| Revision 5 § R.11 – § R.11.2 | the five client states and the selection rule | **Incorporated unchanged** |
| Revision 6 § R.11g, § R.11g-h, § R.11g-i | the consumption contract, the scoped footer rule with the four-edit owner table, the three corrected `L8` numbers | **Incorporated unchanged.** **Read with Revision 7 § R.11g-j's citation convention**, which is the fix for the class that produced `H-1`. Note that the consumption contract itself is **Revision 5 § R.11g**, whose numbered items live there and **not** in Revision 6's § R.11g — see § R.11g-j § A row **A-5** |
| Revision 5 § R.12 – § R.17.1 | the read path, *check access*, the endpoints, exposure, the reuse table, ADR 0018 and what is superseded | **Incorporated unchanged** |
| Revision 5 § R.18.1, Revision 6 § R.18.2-h | gaps closed; the gap register's additions | **Incorporated unchanged.** § R.18.2-j adds three rows; § 0.5 states the counts |
| Revision 5 § 8 | success criteria `SC-01`–`SC-20` | **Incorporated unchanged. No `SC` is added, removed or re-scoped by Revision 7** — a correction pass that changed success criteria would be a redesign |
| Revision 5 § 9.2 | the three ratings and the per-component feasibility table | **Incorporated unchanged.** Revision 7's own ratings are in `design-revision-metadata-7.yaml`, each explained in `report-revision-7.md` § 10.3 |
| **Revision 5 § 10.2** | what a reviewer should check hardest — 14 items | ★ **CORRECTED ROW — see § R.1-j** |

### R.1-j ★ CORRECTION of the incorporation row that was wrong (H-1)

Revision 6's § R.1 carried this row:

> `| § 10.2 | what a reviewer should check hardest | **Carried with § 10.2-h below**, which restates items 10 and 12 (L-R5-1) and adds the new items this pass creates |`

**All three claims are false.** There is no `§ 10.2-h` in Revision 6; it does not "restate items 10 and 12";
and it adds no items. Revision 6's own `design-revision-6.md:282-284` then contradicted itself by listing
what it restates — *"§ R.11g-h, § R.18.2-h, § 10.1 item 12, § 0.4, § 0.5, § 2"* — **which omits § 10.2**.

**The corrected row, and the reasoning:**

| | |
|---|---|
| **Revision 5 § 10.2** | what a reviewer should check hardest — **14 items** |
| **Status at Revision 7** | ★ **CARRIED UNCHANGED BY REFERENCE** to `design-revision-5.md:3299-3362`. **NOT restated, and NOT restated in Revision 6 either.** The two items Revision 6 said it restated — **item 10** (the pin/citation falsifier, `L-R5-1`'s subject) and **item 12** (register agreement, `B-R5-1`'s subject) — are **unamended in Revision 5** and remain so |

**Why "unchanged by reference" is the correct correction and not a patch.** Revision 6's own § R.1 states the
convention it holds itself to: *"Reproducing them would create a second copy that can drift, which is a
defect, not a completeness."* That reasoning is sound and it **applies identically to Revision 5 § 10.2**.
Writing a
`§ 10.2-h` would have created a second copy of a 14-item reviewer checklist — with **13 of the 14 items
silently omitted** — in a section whose whole purpose is to tell a reviewer what to check. **The defect was
not a missing section. The defect was a claim that a section existed.**

**Where the two fixes actually live, stated so the items are not lost:**

| Revision 5 § 10.2 item | Its subject | Its status, and where |
|---|---|---|
| **item 10** | the citation index and content pins; falsified if any artifact's blob hash differs from the metadata's `artifacts[].blob_hash` | **The falsifier is restated — at `provenance.content_pins.this_revision`, which is where the hashes live.** See **Revision 7 § 7.1 `V-2`** and `design-revision-metadata-7.yaml` → `provenance.content_pins`. **Its second half is NOT satisfiable as written and was never satisfiable:** an `artifacts[]` entry cannot carry its own file's hash, and `report-revision-7.md`'s cannot be printed in itself either. **Revision 7 § R.11g-j § B** states the property that **is** true and testable |
| **item 12** | **Revision 5 § R.18.2**'s registers; falsified if a gap lives in prose or a changelog only | **Delivered, and independently confirmed by the re-review.** `G-18`/`G-19`/`G-20` in **both** registers, plus `G-21`/`G-22`/`G-23` at Revision 7. See **Revision 7 § R.18.2-j** and `traceability-matrix-7.md` § 3 |

**Both items therefore have live, checkable falsifiers. Nothing is unexecutable, and Revision 5 § 10.2's own 14 items
are untouched.**

---

## 2 — Risk level: **3**, carried and re-affirmed

### 2.1 The tally is unchanged, and is reproduced verbatim

Revision 5's tally sentence is carried **character for character**, and remains the only tally in this
artifact set:

> **0 reasons IMPROVED, 2 reasons UNCHANGED (R1, R6), 4 reasons WORSE (R2, R3, R4, R5)**

**Revision 7 does not move any reason's status, in either direction**, and **claims no new reason**.
Claiming one for bookkeeping is the same error class as `H10` — a count asserted in five places.

### 2.2 Level 3 re-affirmed on Revision 7's own content

Revision 7 introduces **no** new workflow, navigation or IA. An unchanged level is not a carried label; it
is re-derived, and the ground is stated because the level is what gates this revision's approval. **All six
grounds Revision 6 stated are re-confirmed present at `14b0267`**, and none is touched by this pass:

1. `898b07d0` makes a `Product` visible **before** registration commits and turns registration into a commit.
2. `RegistrationCommitState` is a **five-state client model**; state 4 changes what product detail asserts
   and is currently indistinguishable from state 1 (`G-14`).
3. **Revision 5 § R.11g** item 3 adds a **resume route from the product into the credential flow** — new IA.
4. First handling of key material by SHIP IT, irreversible from SHIP IT's side.
5. An SSH transport seam with **no precedent**, carrying a **half-implemented** ADR requirement (`G-4`).
6. A credential-minting endpoint on a control plane declaring **no authentication**.

Level 3 therefore requires **product/design/architecture human approval** at Gate D4
(`DESIGN_GOVERNANCE.md:94-99`), and this revision **does not** have it.

### 2.3 The register grew by three more entries, and the argument for level 3 strengthens

`G-21`, `G-22` and `G-23` are new and open (§ R.18.2-j). `G-19` gains two residual items; `G-20` is
discharged. **Six open governance items remain against a design whose level is 3** — and this is an
argument *for* level 3, not against it: **a design at level 1 does not accumulate governance debt.**
Revision 6 made this argument with three; Revision 7 makes it with six and it is stronger, not weaker.
A correction pass that lowered the level because it changed no design content would be measuring the
correction rather than the design.

---

## R.11g-j ★ NEW — the cross-reference convention, and the audit that produced it (H-1)

### The defect, stated precisely so it can be recognised next time

Revision 6's § R.1 incorporation table has 24 rows. Nineteen of them name a Revision-5 section. **Every
named target exists** — the re-reviewer enumerated the heading inventory and confirmed it. **And the
twenty-fourth row names a section that does not exist anywhere, in three separate clauses, while the
surrounding rows all resolve.**

**That is why reading could not find it, and why the fix had to be mechanical.** A target-existence check
tests *"does the thing I pointed at exist?"*. It cannot test *"is what I said about it true?"*. Revision 6
made a claim about a section, and the claim was false; the section's non-existence was invisible to any test
applied to the other twenty-three rows.

**And the class is not one error — it is one error wearing six costumes**, six of which Revision 6
introduced itself, in the artifact built to eliminate it.

### The convention — five rules, normative

> **R1. A revision's own NEW sections carry a distinct suffix, so they cannot collide with a superseded
> revision's section of the same name.** Revision 6 used `-h` and `-i`; **Revision 7 uses `-j`** and
> nothing else. Inside this artifact a Revision-7 section is cited by its own name (`§ R.11g-j`,
> `§ 10.1-j`, `§ 7-j`); **from another artifact it is cited as `Revision 7 § …`**, so no reader has to
> guess which revision is meant.
>
> **R2. A SUPERSEDED revision's section is cited as `Revision N § X`, never as a bare `§ X`** — whenever
> this revision defines a section of the same name. This is the rule Revision 6 broke 17 and 16 times
> respectively.
>
> **R3. Every reference resolves, or names where it resolves.** A reference may not name a section that
> exists in no artifact, and may not make a claim about a section it does not contain. **A claim about a
> section is a reference too, and is audited as one.**
>
> **R4. The audit is an EXTRACTION, not a reading.** Every `§`-token in this artifact set is extracted with
> its `file:line` and resolved against the **live heading inventory** of its target document. The result is
> published (§ A below). A reading cannot produce it; a spot-check cannot produce it.
>
> **R5. An unnumbered heading is never cited with a `§`.** Revision 6's `report-revision-6.md` has
> `### Content pins` with **no number**, and seven sites cite it as `§ Content pins` under two spellings.
> If an anchor must be cited, the heading is numbered — so **Revision 7's report numbers it**, and
> **Revision 7 § 7-j** cites it by number.

### § A — THE AUDIT. Seven mis-resolving targets, 45 sites, 6 of them unreported

Resolved against the live heading inventory at `14b0267`. **Sites are occurrences, not findings**; each row
is one distinct defect with a single correction.

| # | Target | Sites | What it resolves to, and why that is wrong | Correction | Reported? |
|---|---|---|---|---|---|
| **A-1** | **`§ 10.2-h`** | **2** — `design-revision-6.md:277`, `design-revision-metadata-6.yaml:352` | **Nothing.** No such heading in any of the six documents in this chain | Both sites corrected: § 10.2 is carried **unchanged by reference** (§ R.1-j) | **YES — H-1** |
| **A-2** | **`§ 10.2`, meaning *this* revision's own** | **1** — `report-revision-6.md:364` | **Nothing.** Revision 6 has `## 10.1-h` and **no `§ 10.2`**. The site's own context is *"a deliberate, recorded choice (§ 10.2)"* — a choice recorded at Revision 6's § 0.3 and the metadata's changelog, **not** in any § 10.2 | Recorded in § R.1-j with the correct target named | **NO** |
| **A-3** | **`§ 3.1`, the ADR amendment's** | **1** — `design-revision-metadata-6.yaml:456`; inherited from `design-revision-5.md:2161` | **§ 3.1 exists — in the WRONG FILE.** It is `design-adr-0018-amendment/design-revision.md:142` (**Revision 1**). Revision 5's sentence names *"the ADR 0018 amendment design's § 3.1"* and then *"now tracked on `main` at `5436a4d` as `design-revision-2.md`"* — **`design-revision-2.md` has no § 3.1 at all** (its § 4.3 is a different finding). **The identifier is right and the file is wrong**, and the two were conflated in one sentence | Recorded with the correct file. **The file is in another lane's `OWNED_PATHS`; nothing was written there** | **NO** |
| **A-4** | **`§ Content pins`** and **`§ pins`** | **7** — `metadata-6.yaml:187, 188, 189, 475, 479, 482`; `design-revision-6.md:583` | The heading exists at `report-revision-6.md:28` but is **unnumbered**, so **`§ Content pins` resolves to no numbered section** — and two spellings are in use for one target | Revision 7 **numbers the heading** (§ 7-j) and cites it by number (rule **R5**) | **NO** |
| **A-5** | **`§ R.11g` (bare)** | **17** — `design-revision-6.md:157, 311, 334, 630`; `metadata-6.yaml:57, 302, 339, 342, 450, 611`; `traceability-matrix-6.md:35, 61`; `report-revision-6.md:150, 188, 415, 487, 539` | **A name collision Revision 6 created.** Revision 5's `### R.11g` carries **items 1–7** (`design-revision-5.md:2362-2388`). **Revision 6 defines its own `## R.11g` at `:330`, which has NO numbered items at all.** Every `§ R.11g item N` in Revision 6 means Revision 5's — so a reader who follows one lands on Revision 6's § R.11g and finds **no item 7** | Rule **R2**. Revision 7's own consumption-contract material is `§ R.11g-j`, and every cross-reference to Revision 5's is written **`Revision 5 § R.11g`** | **NO** |
| **A-6** | **`§ 10.1 item 12`** | **16** — `design-revision-6.md` ×5, `metadata-6.yaml` ×3, `traceability-matrix-6.md` ×3, `report-revision-6.md` ×5 | **A pointer whose literal target does not contain the named item.** Revision 5's `### 10.1` has **items 1–11** (`design-revision-5.md:3240-3297`). **Item 12 exists only in Revision 6's `## 10.1-h` at `:477`** — a section named `10.1-h` that the sixteen citations do not name | Rule **R2**, applied as **`Revision 6 § 10.1-h item 12`** | **NO** |
| **A-7** | **`§ R.1` (bare)** | **1** — `design-revision-6.md:261` | **A collision Revision 6 created.** Revision 6's `## R.1` (`:251`) is the **incorporation table**; the row means Revision 5's `## R.1` **at-rest protection model** (`design-revision-5.md:324`). **Mitigated**: the table's column header reads `Revision 5 §` | Rule **R2** for future citations. Recorded because the collision now exists and will be inherited | **NO** (and **mitigated in Revision 6** — this is the mildest row) |
| | **TOTAL** | **45** | **7 distinct targets.** The re-review reported **1 target / 2 sites** | | **1 of 7** |

**Plus, outside the `§`-token class, three further sites the re-review did not report** — all instances of
classes it *did* report, so the classes are confirmed rather than new:

| Class | Extra site | Why it matters |
|---|---|---|
| H-2's false `blob_hash` claim | `design-revision-6.md:162` | the claim appears in Revision 6's **own correction map**, in the row that disposes of `L-R5-1` — so the row that closes the finding is itself false |
| H-2's false `blob_hash` claim | `report-revision-6.md:286`, `:518` | one in the per-finding disposition, one in the structured `CHANGELOG` the Manager parses |
| LOW-1's em dash | `design-revision-6.md:523` | **the paste-ready block Revision 6 supplied to the Manager** — the *cause* of the hyphen in `.decisions/27ea6536:175` |

**And the two counts that needed re-deriving rather than patching: A-5 and A-6 together are 33 sites.** A
patch to the three sites named in H-1 would have left **42 of the 45** in place.

### § B — the pin property, stated as something a reviewer can actually run (H-2)

**The pin loop is fixed and this revision does not touch it.** `report-revision-6.md:37-42` prints three of
Revision 6's four hashes and the re-reviewer verified all three byte-exact against the committed blobs.
What was wrong was never the pins — it was the **claim**, asserted at **eight** sites, that *every*
`artifacts[]` entry carries a real hash. Not one of the four Revision-6 entries does.

**The property that is true, and testable:**

> Every `artifacts[]` entry carries **either** a real 40-character `blob_hash` — the four **superseded
> Revision-5** artifacts — **or** a pointer to `report-revision-7.md` § 1.1, where the hash is printed;
> **and** every pointer resolves to a printed hash, **except the report's own entry**, which no artifact
> can print, because a file cannot contain its own hash and no artifact is written after it.

**The one irreducible limit, stated rather than papered over: `report-revision-7.md`'s own hash is not
recoverable from any artifact in this set.** That is structural, not a defect — and it is exactly what
Revision 5 got wrong by *claiming* a report printed a hash it did not. **The recovered command is
`git hash-object report-revision-7.md`.**

**The amended falsifier** (replacing the one currently satisfied by four entries) is in
`traceability-matrix-7.md` § 2. **A falsifier an artifact fails is worse than no falsifier**, because it
teaches a reviewer that the row's own test is not worth running.

---

## R.6-j ★ NEW — revocation is still one-sided, and A1's retirement does not say otherwise

Revision 6's § 2.3 and the ADR lane's own § 4 both warn that *"a closed gap must never launder an open
one."* Recording that as a rule is not the same as discharging the obligation, so it is discharged here,
against **Revision 5 § R.6 — "Revocation is two-sided"**, incorporated unchanged.

**Verified at `14b0267` by this lane, read-only:** `grep -rniE
'destroySecret|deleteSecret|removeSecret|secretManager\.delete' --include='*.dart' apps packages` →
**0 matches**. **No code destroys a secret-manager handle.**

**Therefore:**

| Clause of the two-sided revocation guarantee | State at `14b0267` |
|---|---|
| A revoked credential **cannot be resurrected** by a re-mint | **CLOSED IN FACT.** The mint is insert-only on both tiers (§ 0.7). Accepted risk A1 **retired by the owner** |
| A revoked credential's **key material is destroyed** at the manager | **NOT IMPLEMENTED.** No code destroys a handle. Revocation is **one-sided in practice** |
| …and was that half ever an **accepted risk**? | **No.** It is **not** `A2`, `A3` or `A4`, and retiring A1 did not accept it, close it, or transfer it. It belongs to **`79e860e2`** |

**What this revision does and does not do with that.** It **records** the state; it does **not** create
`G-24` for it, because the item is **already registered and owned** — `G-17`'s sibling territory and
`79e860e2`'s own follow-up actions carry it, and inventing a fourth register entry for a known gap is how
a register stops being an index. **The reason it is written here rather than left to `79e860e2` is
narrow and specific: this is the revision that records A1's retirement, and the retirement is the exact
place a reader will conclude the revocation clause is discharged.** It is not. **Revision 5 § R.6** is **incorporated
unchanged** and remains correct; what changes is that one of its two halves now has a status.

---

## R.18.2-j — the gap register, additions and status changes only

Revision 6's § R.18.2-h (18 rows) and `requirements_gaps` (19 entries) are **incorporated unchanged**.
**Three entries are added and two carry a status. The counts move 18 → 21 rows and 19 → 22 entries**, from
the bases **re-counted in § 0.5**, not from the figures Revision 6 asserted.

### `G-21` — ★ NEW — ADR 0018's own body still records **four** accepted risks after the owner retired one

| | |
|---|---|
| **Gap** | **The authoritative record of the accepted risks has not been updated.** The owner's retirement of A1 is recorded in `876c6b97`'s second scope note (`14b0267`) and in `9417f8bf`'s — **and ADR 0018 itself still says four.** Verified at `14b0267`: `grep -c 'Consequence accepted' docs/adr/0018-per-product-git-credentials.md` → **`4`**; `:453` still reads **`**A1 — A revoked credential can be resurrected by a re-mint. ACCEPTED.**`**; `:448-451` still says *"The **four** gaps A2 carries"* and *"Nothing here is closed"*; `:527` still says *"the **four** accepted risks above"*; `:557` and `:574` still say *"the four accepted risks"* |
| **Why it is a gap and not an observation** | **A reader who checks the ADR — which is the artifact every lane cites for custody — concludes four accepted risks are live and A1 is one of them.** The decision objects and the ADR now disagree, and the ADR is the one that gets cited |
| **Same class as `G-17`** | `G-17` was *"ADR 0018 asserting no decision object records its acceptance, in the same commit that added the object."* This is **the same shape**: a record that will not be re-checked, because it is authoritative, asserting a state the owner has changed. `G-17` and `G-21` are **siblings, not one finding** — different files, different owners |
| **Not this lane's** | `docs/adr/**` is `PROHIBITED_PATHS`. **Nothing was written there and no such edit is claimed.** The ADR lane has already specified the exact edit in `design-adr-0018-amendment/design-revision-5.md` § 4, and its own report records the ADR as `UNCOMMITTED` (999 → 1212 lines) — **so at `14b0267` the specified edit is not on disk either** |
| **Owner** | **ADR lane + Manager** — apply the already-specified edit and commit it |

### `G-22` — ★ NEW — Revision 6's false and mis-resolving text is committed, and this correction does not travel with the file

| | |
|---|---|
| **Gap** | **45 mis-resolving cross-reference sites** (§ R.11g-j § A) and **8 sites asserting a false `blob_hash` claim** are **committed on `main` at `af8e30f`**, in four artifacts that are **retained byte-identical** and are the ones a reader will open. **This revision corrects them in its own text; it does not change theirs** |
| **Why that is a gap and not a design choice** | **A correction does not travel with a file.** A reader who opens `design-revision-6.md` directly — by search, by a citation, by `git show` at an older SHA — gets the false text with **no pointer to this revision**. The chain only helps a reader who walks it. **That is the `LOW-4` mechanism, generalised: Revision 5 has no forward pointer either, and now neither does Revision 6** |
| **The choice, and its cost, stated rather than made silently** | **Not editing committed artifacts is correct** — it is why `design-revision-6.md:277` is citable at `af8e30f` at all, and it is why this revision can cite `:277` and `:523` as stable evidence. **It is not free.** The cost is this entry |
| **The fix, exact** | A **supersession banner** on `design-revision-5.md` naming Revision 6 (LOW-4) and on `design-revision-6.md` naming Revision 7, each carrying the correction count. **Both are one-line prepends to committed files and belong to whoever commits** |
| **Owner** | **Manager** — add both banners with the next commit. Until then, **this entry is the redirect** |

### `G-23` — ★ NEW — the board-ownership grant is broader than `G-18`'s measured obligation, and the difference is not recorded anywhere

| | |
|---|---|
| **Gap** | **The grant as issued covers `BPM` as well as the four desktop `S` boards. `G-18`'s obligation does not.** Every measurement of a `Footer` text layer at (236, 862) — three independent lanes, all read-only — is on **the four desktop `S` boards**. **`BPM` was measured as carrying *no* footer copy:** `penpot-board-evidence.md` § 6.3/§ 6.4 and Revision 6's own § R.11g-h amendment 2 both record `BPM`/`SM` as **two states of one mobile design whose spec is already satisfied** |
| **What `BPM` *does* carry** | A **different** defect: `docs/engineering/WORK_STATE.md:639` records that *"`BPM` additionally carries the same false custody string and the now-false `NOT REGISTERED YET` eyebrow"* — which is the item Revision 6 registered under `blockers[]` `EXTERNAL_BLOCKER_NOT_MINE (b)`, **not** under `G-18` |
| **Why it must be recorded rather than resolved** | **A grant of ownership is not a finding of fact.** If the design-system lane reads "you own `BPM`" as "edit `BPM`'s footer", it will make an edit **no measurement supports and Revision 6's § R.11g-h explicitly says is not required.** That is the `B-R5-1` failure mode — *the build diverging from the authority it declares* — reappearing in the opposite direction, on the board rather than in the code |
| **What is decided and what is not** | **The grant is the human's and is DECIDED; this entry does not narrow it.** It records only that **`G-18`'s obligation is scoped to the four desktop `S` boards**, and that if the design-system lane measures a `Footer` layer on `BPM`, **that is a new measurement to register — not an authorisation this artifact confers** |
| **Owner** | **The design-system lane** (the granted owner) **+ Manager.** Recorded by this lane, which holds **no board ownership** and read no board |

---

## 10.1-j — ★ NEW Manager actions

**Revision 6's Manager-action list is carried forward whole: Revision 5 § 10.1's items 1–11 stand as
Revision 6 left them** (including the withdrawn merge action and actions `1a`/`1b`), **and Revision 6
§ 10.1-h item 12 stands.** **Revision 7 adds items 13, 14 and 15 below and amends none.**

> **12. (CARRIED, AND ITS SUBSTANCE HAS MOVED — read § 10.1-j's preamble.) `G-18` — the four-board edit.**
>    **The ownership grant the human was asked for HAS BEEN ISSUED.** A scoped design-system lane will own
>    the four desktop `S · Add Product · …` boards (and `BPM` — see `G-23`) to remove the single `Footer`
>    text layer at (236, 862). **The grant is decided. The obligation is NOT discharged.**
>    **THE BLOCKER HAS ALSO CHANGED FORM.** Revision 6 recorded *"No Penpot instance connected for user
>    token"* — a token-to-instance binding fault. **Penpot went dormant during the Manager's session: the
>    plugin tab is suspended and `getPages()` returns a heartbeat error.** Same destination, different
>    fault, and **the design-system lane may be dispatched but blocked on the plugin being re-focused.**
>    **DO NOT CLOSE THE WORK ITEM OVER `G-18` UNTIL THE BOARD EDIT IS DONE AND REVIEWED.** A grant is not
>    an execution.

> **13. `G-19` — apply the two residual items to `.decisions/27ea6536`.** **Revision 6 § 6's** note landed at `af8e30f`
>    and the re-review found its **framing sound**. Two things it did not carry remain: **(R-1)** the quoted
>    string carries a **hyphen** where the build renders an **em dash** (`add_product_page.dart:383-384`) —
>    **the cause was Revision 6's paste block at `:523`, corrected here**; **(R-2)** a **third** inaccurate
>    statement at `:120` (the mobile boards *"carry a copy plus a disclosure"*) contradicts the same
>    object's own `context.summary` at `:15-17` (*"The mobile boards have no bottom copy at all"*), and was
>    never measured. **Append-only; nothing above the marker is altered; the decision is not re-opened.**
>    **Exact text: Revision 7 § 7-j.** `.decisions/**` is `PROHIBITED_PATHS` — **nothing was written and no such edit
>    is claimed.**

> **14. `G-21` — apply the ADR-lane's already-specified accepted-risk retirement.** The owner retired A1 on
>    2026-10-07; **three accepted risks remain (`A2`, `A3`, `A4`)**. The edit is **already specified** in
>    `design-adr-0018-amendment/design-revision-5.md` § 4 and is **uncommitted**. **`docs/adr/**` is
>    `PROHIBITED_PATHS` — nothing was written there.** Commit it, or record a decision not to.

> **15. `G-22` — add the two supersession banners.** `design-revision-5.md` → *"SUPERSEDED BY DESIGN REVISION
>    6"*; `design-revision-6.md` → *"SUPERSEDED BY DESIGN REVISION 7"*. **Without them the committed false
>    text has no redirect.** Exact text in `report-revision-7.md` § 7. Not this lane's: it may not commit.

---

## 7 — Validation, verification and what this lane did not do

### 7.1 What was run

| # | Check | Result |
|---|---|---|
| **`V-1`** | **Every `file:line` citation the four Revision-6 artifacts carry into their superseded siblings, re-read at `14b0267`** | **Pass.** `design-revision-6.md:280` → `design-revision-5.md:2388-2393` is Revision 5's § R.11g **item 7**, verbatim the footer spec; `:158` and `metadata-6.yaml:552` → `design-revision-5.md:2414` is the `:925`-is-mobile correction; → `design-revision-metadata-5.yaml:739-742` and `traceability-matrix-5.md:139` both state *"the mobile site exists and has a `note:`"* and **agree** with the corrected claim. `design-revision-6.md:599` → `design-register-button/report.md:71-76` exists and carries `inkTertiary` **4.23:1 dark, fails AA** and `inkSecondary` 6.74:1 / 6.10:1. **All resolve exactly as Revision 6 stated** |
| **`V-2`** | **THE CROSS-REFERENCE AUDIT — every `§`-token in all four Revision-6 artifacts extracted and resolved against live heading inventories** (§ R.11g-j § A) | **Pass, with 7 findings.** Rev-6 headings, rev-5 headings, `report-revision-6.md`, `traceability-matrix-6.md`, `penpot-board-evidence.md`, the rev-5 review report, `AGENTS.md` and `aef-orchestrator/SKILL.md` all enumerated at `14b0267`. **45 mis-resolving sites across 7 targets; 6 targets unreported.** Rule **R4** publishes the method so the next pass can re-run it |
| **`V-3`** | **Pre-flight and the `F-16` recovery** (§ 0.3.1) | **Pass.** 19 shadowing files compared by `git hash-object` against `14b0267` — **all 19 byte-identical**; full copy taken outside the repository; 8 untracked moved out and 11 tracked restored; fast-forward; 8 re-compared post-merge, **all identical**; `git status` clean |
| **`V-4`** | **The register counts (H-3), counted not inferred** (§ 0.5) | **Pass.** Revision 5's § R.18.2 = **15** rows; `requirements_gaps` = **16**. Revision 6 = **18 / 19**. **Revision 7 = 21 rows / 22 entries** |
| **`V-5`** | **§ 0.4.1's enumeration recounted (M-1)** | **Pass.** The list held **17** names under the words *"all sixteen rows check out"*, and included `L13`, which the next bullet declares wrong. Corrected to **16**; coverage **16 + `L8` + `M5` + `L13` = 19** |
| **`V-6`** | **The `G-19` note's two residual items, at byte level** (LOW-1, LOW-2) | **Both confirmed, and the cause is Revision 6's.** `add_product_page.dart:383-384` renders `\u2014` (**em dash**); `27ea6536:175` and `design-revision-6.md:523` and `design-revision-metadata-6.yaml:360` carry `-` (**hyphen**). `27ea6536:120` asserts the mobile boards *"carry a copy plus a disclosure"*; `:15-17` says *"no bottom copy at all"*. **Three of the four hyphen sites are mine and are fixed here** |
| **`V-7`** | **Accepted risk A1's retirement — evidence, not adoption** (§ 0.7) | **Pass.** Insert-only confirmed on **both** tiers by reading the shipped source (`postgres_product_registry_store.dart:190-191`, `in_memory_product_registry_store.dart:167-169,184`, `product_registry_engine.dart:933-936`). `876c6b97`'s second scope note at `14b0267` records *"THREE are now recorded (A2, A3, A4)"*. **Revocation's other half: `grep` for handle-destroying calls across `apps`/`packages` → 0 matches** (§ R.6-j) |
| **`V-8`** | **`G-20`'s discharge (LOW-3)** | **Pass.** All four Revision-3 artifacts added at `af8e30f`; the 11 banners committed; `git status` for the directory is empty at `14b0267` |
| **`V-9`** | **`G-18`'s new state: grant issued, obligation open, blocker changed form** (§ 10.1-j item 12) | **Pass, as recorded — NOT verified against Penpot.** The grant and the dormancy are **the Manager's report of the human's decision and of a runtime condition**; this lane called **no Penpot tool** and read **no board**. `BPM`'s separate defects are cited from `WORK_STATE.md:639`. Recorded as **cited**, in the same shape Revision 6 used for the footer measurement |

### 7.2 `NOT_RUN` — nothing is claimed that was not observed

| Command / check | Status | Note |
|---|---|---|
| **`docker` / `docker compose`, any subcommand** | **NOT_RUN — none issued** | Not `info`, not `ps`, not `logs`, not `config`, not `down`, not `--rmi`. **This repository has already lost its QA database** to a lane running `docker compose -f docker/compose.qa.yaml down -v --rmi local`; the rule is not tested, because testing it is the forbidden act. **Compose files were not read** |
| **Any Penpot tool** — `penpot_execute_code`, `penpot_export_shape`, `penpot_high_level_overview`, the Penpot MCP resources | **NOT_RUN — none called** | **No board read, listed, edited, renamed, moved, exported or deleted. No board ownership.** `G-18`'s measurement and `G-23`'s `BPM` state are both **cited** |
| `dart analyze` / `flutter analyze` | **NOT_RUN** | Implementation-lane gate |
| Build | **NOT_RUN** | — |
| `dart test packages/product_registry/test` | **NOT_RUN** | No claim about `D-4`/`D-5`/`D-6` |
| `make test-integration` | **NOT_RUN** | The only sanctioned Docker exemption; not needed and not used |
| `T-A` … `T-L` execution | **NOT_RUN** | **Specified, not executed.** Not adopted as this lane's result |
| Contrast-ratio measurement | **NOT_RUN** | Figures **inherited** from `design-register-button/report.md:71-76`, not re-measured |
| ADR 0018 — read, edit, commit | **READ ONLY** (the 580-line body at `14b0267`, to count `Consequence accepted` and to read the A1 heading) | `docs/adr/**` is `PROHIBITED_PATHS`. **Nothing written.** `G-17` and `G-21` stand, unedited and unclaimed |
| `.decisions/**` — read, edit, create | **READ ONLY**, for the four decisions this pass cites | **Nothing written.** `G-19`'s residual fix is specified in **Revision 7 § 7-j** for the Manager |
| Commit / push | **NOT_RUN** | `COMMITTED: NO`, `PUSHED: NO`, as instructed |
| Deletions | **NONE.** Files moved during the `F-16` recovery went **outside the repository** to a backup, and were re-verified after the merge | **No file was deleted.** The 11 tracked modifications were restored with `git checkout --` against hashes verified byte-identical first (§ 0.3.1) |

### 7.3 `UNVERIFIED` — with what a human should run

Carried from Revision 6 unchanged; **this pass adds no new `UNVERIFIED` claim and closes none.**

| Claim | Status | What a human should run |
|---|---|---|
| **The four desktop `S` boards still carry the `Footer` text layer at 236, 862** | **UNVERIFIED by this lane — cited, not measured.** Now three agreeing read-only passes. **This lane holds no board ownership** | Read the four boards read-only; re-read the layer's type, position and text |
| **Whether `BPM` carries a `Footer` layer** (`G-23`) | **UNVERIFIED, and the design-system lane's to establish.** No measurement exists either way | Read `BPM · Add Product · Light/Dark` read-only and **record the result as a new measurement** |
| **A3 is reachable in this repository's target topology** | **UNVERIFIED** — `G-10`, `A4` | Provision the manager; run `verifyProtection` from the server container |
| A real SSH transport accepts the generated public key | **UNVERIFIED** | A stack under an explicit `-p`; install the returned `publicKey` in a scratch repo's `authorized_keys` |
| `D-4`/`D-5`/`D-6` behave as specified on both tiers | **UNVERIFIED** | `T-C`…`T-G`, `T-J`, `T-K` on both tiers |
| The mint endpoint refuses a foreign `repositoryId` on both tiers | **UNVERIFIED** — **Revision 4's sequence would NOT have** | `T-L`, both store tiers |
| The duplicate-credential audit finds no duplicates anywhere deployed | **`NOT_RUN, and not runnable from any lane** — `G-12` | The **corrected** query, by a human, before migration `20261006150645000` |
| **Revision 5's 3 372 incorporated lines** | **Not re-derived.** Only their **heading existence** was verified (`V-2`) | — |

### 7-j ★ The two record fixes this revision specifies — for the Manager, not for me

**Both targets are `PROHIBITED_PATHS` for this lane. Nothing was written to either and no such edit is
claimed.** These are the exact texts, ready to apply, in the same shape Revision 6 used and in the
`876c6b97` append-only form.

#### 7-j.1 — the two `G-19` residual items, for `.decisions/27ea6536-8a4e-4cf1-b24c-cdd3ce5bdab0.yaml`

**`G-19`'s note landed at `af8e30f` and the re-review found its framing sound.** Two things it did not
carry remain. **Both concern the record's factual basis. Neither concerns the answer.** The outcome, the
`status`, `selected_option`, `deviation_from_presented_options`, `decided_at`, `decided_by`,
`human_correction_verbatim`, the `rationale`'s outcome clauses and all four `follow_up_action` owners
**stand**, and **the human is not asked to re-decide the footer.**

| # | Residual item | Evidence, at byte level |
|---|---|---|
| **R-1** | The quoted string is **quoted with the wrong dash character.** The note renders *"The same piece of work then continues **-** nothing is restarted."* The shipped build renders `\u2014` — an **em dash** — at `apps/control_plane/lib/features/products/add_product_page.dart:383-384`. **Everything else in the note is byte-rigorous** (1020 × 15, 236 + 1020, right edge 1256), which is exactly why a normalised character in the one string it quotes is the imprecision that class invites | `add_product_page.dart:383-384` = `'… continues \u2014 nothing is restarted.'`; `27ea6536:175` = `'… continues - nothing is restarted.'` **The hyphen originated in `design-revision-6.md:523` — the paste-ready block this chain supplied — and is corrected there in Revision 7.** A second copy of the defect sat in `design-revision-6.md`'s metadata at `:360`, also corrected |
| **R-2** | **A third inaccurate statement, unregistered.** `resolution.supersedes_design_lane_reading:120` asserts the design lane recorded *"that the **mobile** boards carry a copy plus a disclosure."* **The same object's own `context.summary` fact 1, at `:15-17`, says the opposite**: *"The **mobile** boards have no bottom copy at all. `BPM · Add Product · Light/Dark` carry exactly one element below the helper."* **The object contradicts itself about the mobile half of the reading it overrules** | `27ea6536:120` vs `27ea6536:15-17`. **Pre-existing** (written by the Manager at `674b871`), **not introduced by Revision 6**, and **not measured by any of the three passes** — every measurement was of the **desktop** `S` boards |

**Scope limit, stated so the fix cannot be read as widening `G-18`:** R-2 is **unmeasured**, so registering
it **adds no board obligation**. It does **not** create an outcome conflict either — the decision's mobile
outcome (no copy, left-aligned, no divider) is consistent with the boards per **both** the context summary
and the human's own check — so **`G-18`'s scope of "conflict on exactly one clause" still holds.**

**Append after the existing marker; nothing above any marker is altered:**

```
# ---- SCOPE NOTE 2 appended <YYYY-MM-DD> by orchestrator-main. APPEND-ONLY: no line above this
# comment is altered. The resolution above stands, is NOT withdrawn, and no clause of the owner's
# answer is re-opened. ----------------------------------------------------------------------
#
# TWO RESIDUAL ITEMS OF THE G-19 RECORD-CORRECTION ABOVE. Neither concerns the OUTCOME. Both
# concern the accuracy of the note's own text. Found on re-review; registered so no future
# reader re-derives them.
#
# R-1 — THE QUOTED STRING QUOTES THE WRONG DASH CHARACTER. The note above renders
#   "The same piece of work then continues - nothing is restarted." The shipped build renders
#   \u2014, an EM DASH, at apps/control_plane/lib/features/products/add_product_page.dart:383-384.
#   Every other figure in the note is byte-rigorous; this one character is normalised. The
#   hyphen entered this object from the design side's paste-ready block
#   (design-revision-6.md:523), which carried it, and has been corrected in that artifact.
#   The correction is to the SOURCE, not to this object's outcome.
#
# R-2 — A THIRD INACCURATE STATEMENT IN THIS OBJECT, PRE-EXISTING AND NEVER MEASURED.
#   resolution.supersedes_design_lane_reading asserts the design lane recorded that "the
#   MOBILE boards carry a copy plus a disclosure". This object's own context.summary, fact 1,
#   says: "The MOBILE boards have no bottom copy at all. BPM . Add Product . Light/Dark carry
#   exactly one element below the helper." The object contradicts itself about the mobile half of
#   the reading it overrules. This statement was NOT introduced by the record-correction above,
#   was NOT measured by any read-only pass - every measurement was of the four DESKTOP S boards -
#   and does NOT create an outcome conflict: the decision's mobile outcome (no copy, left-aligned,
#   no divider) is consistent with the boards per both context.summary and the owner's own check.
#   IT IS RECORDED HERE ONLY SO A FUTURE READER DOES NOT RE-DERIVE IT, AND IT ADDS NO BOARD
#   OBLIGATION.
#
# WHAT IS UNCHANGED BY THIS NOTE: status: RESOLVED; selected_option;
#   deviation_from_presented_options; decided_at: 2026-10-06T13:05:00Z; decided_by;
#   human_correction_verbatim AS THE OWNER'S WORDS; every outcome clause of the rationale; all
#   four follow_up_action owners; and the record-correction note above, whose findings stand.
#   G-18 remains OPEN and unexecuted: a grant of board ownership has been issued and the
#   four-board edit has not been done. A grant is not an execution.
#
# Correcting source of record for the design side, revision 7:
#   docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-7.md,
#   sections R.11g-j, R.18.2-j and 7-j.
```

#### 7-j.2 — the accepted-risk count, for `docs/adr/0018-per-product-git-credentials.md`

**Not written. The edit is ALREADY SPECIFIED** by the ADR lane in
`design-adr-0018-amendment/design-revision-5.md` § 4, and its own report records the ADR as
**`UNCOMMITTED` (999 → 1212 lines)** — so at `14b0267` the specified edit is not on disk either.
**This lane therefore specifies nothing new; it records what must not be lost, and verifies the count.**

**Verified at `14b0267`, read-only:**

| Site | State |
|---|---|
| `grep -c 'Consequence accepted' docs/adr/0018-per-product-git-credentials.md` | **`4`** |
| `:453` | `**A1 — A revoked credential can be resurrected by a re-mint. ACCEPTED.**` |
| `:448-451` | *"The **four** gaps A2 carries…"* · *"Nothing here is closed"* |
| `:527` | *"None of these is one of the **four** accepted risks above"* |
| `:557`, `:574` | *"the **four** accepted risks"* |

**The state that must be recorded when the ADR-lane edit is applied:** **THREE accepted risks remain —
`A2`, `A3`, `A4`** — and `A1` was retired **by the repository owner on 2026-10-07**, on evidence
(`08c7590` made the mint insert-only on both tiers) that this lane re-verified at `14b0267`
(**`V-7`**). **Two prior lanes were right to decline to make that retirement**, because *"retiring it is
the owner's call"* (`876c6b97`'s first scope note). **Three things the edit must not get wrong**, each of
which has already caused one wrong conclusion in this work item:

1. **Do not retire the SUBSTRATE option `A1` (filesystem `0600`).** It is **live** — ADR `:107`, `:442` —
   and it is a **different identifier**. The ADR's three-way table exists precisely because these were
   conflated once. **Amendment `A1` is also live** (`:35`, *"Scope is the repository, not the product"*),
   and it is live **in the code today** at `product_registry_store.dart:47` and `:52-53`.
2. **Do not let the retirement imply the revocation clause is discharged.** **No code destroys a
   secret-manager handle** — `grep` across `apps`/`packages` returns **0 matches** — so revocation is
   **one-sided in practice**, and **that half was never an accepted risk.** Retiring `A1` did not accept
   it, close it, or transfer it to `A2`–`A4`. Revision 7 § R.6-j records this against the design.
3. **Record it as the owner's decision, not a design lane's.** A lane cannot retire an accepted risk.

---

## 8 — Safe parallelism

**Unaffected by every finding above, and safe to proceed on now.** Revision 6's § 8 list is carried
unchanged, **because no finding in this review touched any of it**:

- **Implementation of `G-11`** (`D-4`/`D-5`/`D-6`, both tiers, eight columns) — Revision 5 § R.9 untouched.
- **`G-13` step 3a + `G-16` step 3a + `T-L` + `SC-20`** — ship `G-16` first.
- **`G-14`** (Revision 5 § R.11.2) — one method, no schema change.
- The retirement of the `repositoryId: productId` placeholder (Revision 5 § 10.1 item 7).
- **The three code edits of Revision 6 § R.11g-h** — delete `_buildFooter`, desktop `note: null` at
  `:317-319`, mobile `note: null` at `:926-928`. Specified, sourced and unaffected.

**NOT SAFE while `G-18` is open:** any board edit by any lane that does not hold the grant; treating
Revision 6 § R.11g-h's *"boards are authoritative"* as unconditional; **reading the ownership grant as
authorising a `BPM` footer edit** (`G-23`); and **closing the work item**.

**`SC-01`–`SC-20` carried unchanged. No `SC` is added, removed or re-scoped.**

---

## 9 — Readiness

**Ready for Independent Design Review of Revision 7. Not approved by its author.** Revisions 3, 4, 5 and 6
each returned `CHANGES_REQUIRED`; Revision 2's approval does not carry over; **this revision carries no
approval from any reviewer.**

**Gate D4 status is unchanged.** The decisions are `RESOLVED`. `9417f8bf` and `876c6b97` carry
**append-only dated scope notes** and are cited **at their scoped reading**; **neither is re-opened**.
Specifically: the absolute *"never holds key bytes"* is true only in the **STORAGE** dimension — at
transport time SHIP IT must materialise the private half in process memory, which is what "transmit it"
requires of it. That absolute appears at **four** sites, `9417f8bf:140` being the load-bearing uniqueness
argument.

⚠ **THE ACCEPTED-RISK COUNT IS NOW THREE: `A2`, `A3`, `A4`.** `A1` was **retired by the repository owner** on
2026-10-07 after `08c7590` made the mint insert-only on both tiers — verified at `14b0267` (§ 0.7, `V-7`).
**That retirement is the owner's, and two prior lanes were right to decline to make it.** ADR 0018's own
body still records four; that is `G-21`, owned by the ADR lane and the Manager, and it is **not** this
lane's to fix. **And retiring A1 discharged the resurrection half only** — no code destroys a
secret-manager handle, so revocation is **one-sided in practice**, and that half was never an accepted risk
(§ R.6-j).

**One caveat stated so the reviewer is not surprised.** Four of this pass's items concern artifacts this
revision does not own: the four boards and `BPM` (`G-18`, `G-23`), `27ea6536`'s record (`G-19`), ADR 0018's
accepted-risk section (`G-21`), and the two supersession banners (`G-22`). **All four are registered with
owners; none was edited by me.** The two a reviewer should check hardest are **`G-18`**, because a grant
has now been issued and the obligation is still open — **the work item must not close over it** — and
**`G-22`**, because this revision's corrections do not travel with the files they correct.