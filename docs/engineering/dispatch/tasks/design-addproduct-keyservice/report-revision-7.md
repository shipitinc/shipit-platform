# Report — Design Revision 7, `design-addproduct-keyservice` (the dangling-pointer class)

Persisted per `aef-orchestrator` §14. Lane: `design-agent`. **The Design Agent never approves its own work.**
Nothing in this report is an approval, and no approval of any kind stands behind Revisions 1–7.

**FINDING SET ANSWERED**: `design-rereview-keys-rev6/report.md` — 0 BLOCKERS, 3 HIGH, 1 MEDIUM, 4 LOW.
**Per-finding disposition: H-1…H-3, M-1, LOW-1…LOW-4 — § 5 below. All 8 APPLIED.**

---

## 1. Provenance

| | |
|---|---|
| **Worktree** | `/private/tmp/shipit-correct-addproduct-keys` |
| **Branch** | `design-correct-addproduct-keys` |
| **`BASE_SHA`** | **`14b026719a1433362059fb02d3fccc37c678462b`** |
| **`HEAD_SHA`** | **`14b026719a1433362059fb02d3fccc37c678462b`** |
| Re-based from | `1c3f5ad` — by **`git merge --ff-only 14b0267`**. Fast-forward. **Nothing rewritten.** `main` advanced by 5 commits while Revision 6 was under review |
| **`REVISION_ID`** | **`3877696f-c15d-4ea8-9941-898fa601bf44`** — a UUIDv4 minted by this lane (`uuidgen`, lowercased). **Not an approval** |
| **`REVISION_NUMBER`** | **7** |
| **`RISK_LEVEL`** | **3** — carried, **re-affirmed on this revision's own content** |
| Committed / pushed | **NO / NO**, as instructed. **Revision 6 IS committed underneath at `af8e30f`** |
| Docker or Compose | **NONE ISSUED — not `info`, not `ps`, not `logs`, not `config`, not any mutating one. Compose files not read** |
| **Penpot** | **NO TOOL CALLED. NO BOARD READ, EDITED, RENAMED, MOVED, EXPORTED OR DELETED.** See § 3 |
| `876c6b97`, `9417f8bf`, `27ea6536` | **READ ONLY, at their SCOPED readings. Nothing written under `.decisions/**`** |
| `docs/adr/0018-…` | **READ ONLY** (the 580-line body, to count `Consequence accepted` and read the A1 heading). **Nothing written** |

### 1.1 Content pins — `git hash-object`, run at `14b0267`

**This subsection is NUMBERED, and that is the point of it.** Revision 6's report carried
`### Content pins` **unnumbered**, and seven sites cited it as `§ Content pins` under two spellings — so
`§ Content pins` resolved to no numbered section anywhere. That is rule **R5** in
`design-revision-7.md` § R.11g-j, and this is the heading it was written for.

**The honest property, stated rather than claimed — see `H-2`.** An `artifacts[]` entry **cannot** carry its
own file's blob hash. Only the **superseded Revision-5** entries do. Revision 6 asserted otherwise at
**eight** sites; the re-review found **five**.

```
design-revision-7.md             ff96e05b3151743b8590427c9db4da7e50375a15
design-revision-metadata-7.yaml  e5f7b6be6be69355514ce390e8b7b1ab647f9d50   <-- SELF-EXCLUDED, PRINTED HERE
traceability-matrix-7.md         59cd5a73c413d62b98709e8f15e4e67254c59abf
report-revision-7.md             SELF-EXCLUDED — this file, and NO artifact is written after it
```

**The one irreducible limit, stated rather than papered over:** `report-revision-7.md`'s own hash is
**carried by no artifact in this set.** A file cannot contain its own hash, and nothing here is written
after the report. **The recovery is `git hash-object report-revision-7.md`.** Revision 5 got this wrong by
*claiming* a report printed a hash it did not; Revision 6 got it wrong by claiming all four entries carried
real hashes when none did. **This is the third distinct shape of the same error in three consecutive
revisions**, which is why the property is now stated once, in a falsifier that passes, instead of in a claim
that has to be re-audited every pass.

**Revision 6's four artifacts, pinned and byte-identical at `14b0267` — verified, and NOT re-fixed:**

```
2187065c0beffc3020886cc1b16027865f7ae71c  design-revision-6.md
5a9b5ae03dfa64f97fe7962edec60308805be889  design-revision-metadata-6.yaml
fafcf362dc873fa2a9169448bec39711d4b7dd9f  traceability-matrix-6.md
49b74ba5925ac3dc480292c357e488274b3b2804  report-revision-6.md
```

**Revision 5's four superseded artifacts:**

```
fb99f9e216b10db655b673111062355e690d61fa  design-revision-5.md
bae3c019be3a28c2d9347944eacc8eca4ccecec6  design-revision-metadata-5.yaml
0778b37d567c25d60efd4a6fb2dbac316212334c  traceability-matrix-5.md
121273aee65c2e771f2cc3cf3be25f534fe09d14  report-revision-5.md
```

### 1.2 The merge precondition — recorded rather than smoothed

`git merge --ff-only 14b0267` **aborted the first time** on **19 shadowing files** (11 tracked + 8 untracked).
This is discovery **`F-16`**, and it is the **second** time this worktree has refused a fast-forward —
Revision 6 recorded the identical event for Revision 5's four artifacts.

**Nothing was deleted and no lane had to be stopped**, because all 19 were **byte-identical** to the blobs
`14b0267` carries — verified with `git hash-object` on every file **before anything moved**. Then, in order:
a full copy went **outside the repository first**; the 8 untracked copies were **moved out**; the 11 tracked
modifications were restored with `git checkout --`; the fast-forward proceeded; and the 8 files were
**re-compared against the backup after the merge — all 8 identical**. `git status` clean.

The full hash table is at `design-revision-metadata-7.yaml` → `provenance.merge_precondition_note`.

---

## 2. ⚠ Three pre-flight findings the Manager must act on

### 2a. ⚠ Accepted risks are **THREE**, not four — and the ADR still says four

**A1 was retired by the repository owner on 2026-10-07.** Recorded **as the owner's decision**, and
**verified against the shipped source rather than adopted** (`V-7`):

| Tier | Site | What it says |
|---|---|---|
| Postgres | `postgres_product_registry_store.dart:190-191` | *"A MINT NEVER OVERWRITES AN EXISTING IDENTITY — the null-`expectedVersion` branch is `DO NOTHING`, not a predicated `DO UPDATE`"*, followed by the resurrection path it closes |
| In-memory | `in_memory_product_registry_store.dart:167-169, 184` | *"is INSERT-ONLY. Checked FIRST…"*, refusing with *"a credential with this id already exists; minting is insert-only…"* |
| Contract | `product_registry_engine.dart:933-936` | *"A mint is insert-only: supplying an id that already exists is refused by the store and changes nothing — whether the supplied material differs, matches, or the existing credential is revoked."* |
| Record | `876c6b97`, second scope note at `14b0267` | *"the repository owner RETIRED A1 … **THREE are now recorded (A2, A3, A4)**"* |

**Two prior lanes were right to decline to make this call** — `876c6b97`'s first scope note says
*"RETIRING IT IS THE OWNER'S CALL"*, and **a design lane may not retire an accepted risk.**

⚠ **Three readings of "A1" exist, and conflating them has already caused one wrong conclusion here:**

| "A1" | State |
|---|---|
| **Accepted risk A1** — resurrection by re-mint | **RETIRED 2026-10-07** |
| **Amendment A1** — *"Scope is the repository, not the product"* (ADR `:35`) | **LIVE — and live in the code today:** `product_registry_store.dart:47` reads *"KEY MATERIAL IS IMMUTABLE (ADR 0018 A1)"*, `:52-53` *"ADR 0018 A1, 'scope is the repository'"* |
| **Substrate option A1** — filesystem `0600` | **LIVE** — ADR `:107`, `:442` |

⚠ **ADR 0018's own body still records FOUR** — `grep -c 'Consequence accepted'` → **`4`**; `:453` still
`ACCEPTED`; `:448-451`, `:527`, `:557`, `:574` all still say four. **Registered as `G-21`.** The edit is
**already specified** by the ADR lane and is **uncommitted there too**. **Nothing was written** — `docs/adr/**`
is `PROHIBITED_PATHS`.

⚠ **Retiring A1 discharged the RESURRECTION half only.** `grep -rniE 'destroySecret|deleteSecret|
removeSecret|secretManager\.delete' --include='*.dart' apps packages` → **0 matches**. **No code destroys a
secret-manager handle, so revocation is ONE-SIDED IN PRACTICE — and that half was never an accepted risk.**
Recorded at `design-revision-7.md` § R.6-j against Revision 5 § R.6. **A closed gap must never launder an
open one.**

### 2b. ⚠ `G-20` is discharged, and the chain now rests on a redirect that does not exist

`G-20` is **CLOSED — DISCHARGED at `af8e30f`**, re-verified with **full paths** and `--diff-filter=A`:
all four Revision-3 artifacts were added there, and the 11 banners were committed alongside them
(`git status` for the directory is **empty** at `14b0267`).

**The remaining residue is `G-22`, and it is the honest cost of this pass's main decision.** Revision 6's
**45 mis-resolving cross-reference sites** and **8 false-claim sites** are committed on `main` at
`af8e30f`, in four artifacts this revision **retains byte-identical**. A correction does not travel with a
file: a reader who opens `design-revision-6.md` by search, by citation, or by `git show` at an older SHA gets
the false text with no pointer to this revision. **Revision 5 has no forward pointer to Revision 6, and now
neither does Revision 6.** **The fix is two one-line supersession banners — § 7 — and it belongs to whoever
commits.**

### 2c. ⚠ The `G-18` ownership grant is decided; the obligation is not discharged

**THE HUMAN HAS GRANTED BOARD OWNERSHIP.** A scoped design-system lane will own the four desktop
`S · Add Product · …` boards — **and `BPM`** — to remove the single `Footer` text layer at (236, 862).

**Two things that grant does not do, and both are recorded as gaps rather than resolved:**

1. **A grant is not an execution. THE WORK ITEM MUST NOT CLOSE OVER `G-18` UNTIL THE BOARD EDIT IS DONE AND
   REVIEWED.** And the blocker has **changed form**: Penpot went **dormant** during the Manager's session —
   the plugin tab is suspended and `getPages()` returns a **heartbeat error** — so the lane may be dispatched
   but blocked on the plugin being re-focused. That is a different fault from the *"No Penpot instance
   connected for user token"* binding failure Revision 6 recorded, with the same destination.
2. **`BPM` is inside the grant and outside `G-18`'s obligation** (`G-23`). Every measurement of a `Footer`
   layer at (236, 862) is on **the four desktop `S` boards**; BPM was measured as carrying **no** footer copy.
   **A grant of ownership is not a finding of fact.** If the granted lane reads "you own `BPM`" as "edit
   `BPM`'s footer", it will make an edit **no measurement supports** and Revision 6 explicitly says is not
   required. **Whether BPM carries the layer is UNVERIFIED IN BOTH DIRECTIONS and is that lane's to
   establish.** This lane called no Penpot tool and read no board.

---

## 3. Confirmation — **no Penpot board was touched**

**Explicit, as instructed.**

- **No Penpot tool was called.** Not `penpot_execute_code`, not `penpot_export_shape`, not
  `penpot_high_level_overview`, not the Penpot MCP resources. **No board was read, listed, edited, renamed,
  moved, exported or deleted.** No board was created or cloned.
- **This lane holds no board ownership in this pass**, and every board is `PROHIBITED_PATHS`.
- **`G-18`'s measurement, `G-23`'s `BPM` state and Penpot's dormancy are all CITED or REPORTED, never
  reproduced** — the sibling lane's `penpot-board-evidence.md` § 6.4, the Rev-5 reviewer's own independent
  live pass, and the Manager's report, all named as **source of evidence, not as authority**.
- **The discipline, stated because it was the temptation.** `G-18` is the single fact a designer could most
  easily re-verify, and re-verifying it needs a board this lane does not own. **An unowned second
  measurement would not have made the first more true.**

---

## 4. Risk level — **3**, with rationale

**`RISK_LEVEL: 3`** · **`RISK_LEVEL_AGREEMENT: YES`** (the rev-6 reviewer independently re-derived 3 and
agreed; this lane re-affirms it on Revision 7's own content).

**The tally is unchanged and is reproduced verbatim:**

> **0 reasons IMPROVED, 2 reasons UNCHANGED (R1, R6), 4 reasons WORSE (R2, R3, R4, R5)**

**Revision 7 moves no reason's status in either direction and claims no new reason.** Claiming one for
bookkeeping is the same error class as `H10` — a count asserted in five places.

**Level 3 re-affirmed, not inherited.** `DESIGN_GOVERNANCE.md:94-99` — *"Change to core workflow, navigation
structure, or information architecture affecting multiple features or user mental models"* → approval path
`HUMAN_DECISION_REQUIRED`. **Six grounds, every one re-confirmed present at `14b0267`:** (1) `898b07d0`
makes a `Product` visible before registration commits; (2) `RegistrationCommitState` is a five-state client
model and state 4 is indistinguishable from state 1 (`G-14`); (3) **Revision 5 § R.11g** item 3 adds a
resume route into the credential flow — new IA; (4) first handling of key material by SHIP IT; (5) an SSH
transport seam with no precedent carrying a **half-implemented ADR requirement** (`G-4`) on the credential
path; (6) a credential-minting endpoint declaring **no authentication**.

**The register grew by three more entries, and the argument for level 3 strengthens.** `G-18`, `G-19`,
`G-21`, `G-22`, `G-23` are open; `G-20` is discharged. **Five open governance items** — `G-19` plus its two
residual items — against a design whose level is 3 is an argument *for* level 3, not against it: **a design
at level 1 does not accumulate governance debt.** Revision 6 argued this with three; **Revision 7 argues it
with five and the argument is stronger, not weaker.** A correction pass that lowered the level because it
changed no design content would be measuring the correction rather than the design.

**Three accepted risks remain: `A2`, `A3`, `A4`** — § 2a.

---

## 5. Per-finding disposition — all eight

### `H-1` — `§ 10.2-h` does not exist — **✅ APPLIED BY RE-DERIVATION, NOT BY PATCH**

**The two dead pointers are corrected by describing § 10.2 correctly.** `design-revision-7.md` § R.1-j: § 10.2
is **carried unchanged by reference** to `design-revision-5.md:3299-3362` — **not restated**, and never was,
in Revision 6 either. **Writing a `§ 10.2-h` would have created a second copy of a 14-item reviewer
checklist with 13 of the 14 items silently omitted**, in the section whose purpose is to tell a reviewer what
to check. **The defect was not a missing section; the defect was a claim that a section existed.** Both items
(10 and 12) are traced to where their falsifiers actually live.

**And every cross-reference in the Revision-6 artifact set was re-derived from the live documents:**

| | Reported by the re-review | **Found by this lane** |
|---|---|---|
| Distinct mis-resolving targets | **1** | **7** |
| Sites | **2** | **45** |
| False `blob_hash` claim sites | 5 | **8** |

**Six targets and 43 sites were unreported** — itemised at `design-revision-7.md` § R.11g-j § A:
`§ 10.2` meaning Revision 6's own (`report-revision-6.md:364`); the ADR amendment's **`§ 3.1`, which exists in
the wrong file** — `design-revision-6.md`… it is `design-adr-0018-amendment/design-revision.md:142`
(**Revision 1**), while Revision 5 names `design-revision-2.md` alongside it, **which has no § 3.1 at all**;
**`§ Content pins`** at 7 sites, where the heading is **unnumbered**, under two spellings; **bare `§ R.11g`
at 17 sites** and **`§ 10.1 item 12` at 16** — **both collisions Revision 6 created itself**, by introducing a
`## R.11g` with no numbered items and a `## 10.1-h` while citing the bare names. **Those two alone are 33
sites; a patch to the three sites named in `H-1` would have left 42 of the 45 in place.**

**The fix that persists is rule `R4`: the audit is an EXTRACTION, not a reading.** A target-existence check
cannot see a false *claim* about a target — which is exactly why the re-reviewer could enumerate every § R.1
target, find them all present, and still confirm a row that lies.

### `H-2` — `L-R5-1` reported closed on a false claim — **✅ APPLIED. THE PINS ARE NOT RE-FIXED.**

**The pin loop is real and the reviewer verified it byte-exact. That is accepted as settled and this lane
touched no pin.** What was wrong was the **claim**, made at **eight** sites — the reviewer found **five**,
and **three more exist**: `design-revision-6.md:162` (**inside Revision 6's own correction-map row for
`L-R5-1`**, so the row disposing of the finding was itself false), `report-revision-6.md:286`, and
`report-revision-6.md:518`. Plus `metadata-6.yaml:470`'s *"THE **two** self-excluded files"*, which is
**four**.

**Not one of the four Revision-6 `artifacts[]` entries carries a hash.** Only the four **superseded
Revision-5** entries do.

**The falsifier Revision 6 published for its own correction was satisfied by four entries.** It is
**amended** at `traceability-matrix-7.md` § 2 to test what the artifact actually does — *find a pointer whose
hash is not printed in `report-revision-7.md` § 1.1, excluding the report's own entry* — and **that one was
checked against the artifact before publication, because a falsifier an artifact fails is worse than no
falsifier**: it teaches a reviewer that the row's own test is not worth running.

### `H-3` — both register counts wrong — **✅ APPLIED, AND REVISION 7's OWN FIGURES COUNTED TOO**

| Register | Revision 5 | Revision 6 (actual) | **Revision 7** |
|---|---|---|---|
| § R.18.2 rows | **15** | 15 + 3 = **18** | **21 rows** |
| `requirements_gaps` entries | **16** | 16 + 3 = **19** | **22 entries** |

Revision 6 published **`19 → 22`** in both registers; both "before" figures were wrong, **by 4 and 3**. The
**deltas (+3/+3) and entry-level agreement were right**, and those are the load-bearing claims. **Revision 7
does not simply acquire a new wrong pair** — its figures come from the same bases. The **21 vs 22 asymmetry
is stated, not smoothed**: § R.18.2 has no row for *"the Rev-4 review report"* because it is **closed**, while
`requirements_gaps` carries it marked `CLOSED` so the residue survives.

### `M-1` — 17 rows enumerated as "sixteen check out" — **✅ APPLIED**

`L13` is dropped from the enumeration, leaving **16** names that check out, and `L13` now appears **only** in
the bullet that reports its error. **Coverage: 16 + `L8` + `M5` + `L13` = 19.** The list can no longer
diverge from the count, because it is now produced by extraction (rule `R4`) rather than typed.

### `LOW-1` — the em dash — **✅ APPLIED, AND THE CAUSE WAS RE-ATTRIBUTED**

**The re-review recorded the effect. The cause is in Revision 6.** `add_product_page.dart:383-384` renders
`—` — an **em dash**. The hyphen appears at **`design-revision-6.md:523`, the paste-ready block Revision 6
supplied to the Manager**, and at `design-revision-metadata-6.yaml:360`. **The Manager pasted
`27ea6536:175` faithfully; the hyphen was inherited, not introduced there.** Three of the four sites are in
artifacts this chain controls and are corrected in Revision 7; **the `.decisions/**` copy is not this lane's**,
and the corrected block is specified at `design-revision-7.md` § 7-j.1.

### `LOW-2` — `27ea6536`'s third inaccurate statement — **✅ APPLIED, REGISTERED**

`27ea6536:120` asserts the design lane recorded that *"the **mobile** boards carry a copy plus a
disclosure."* **The same object's own `context.summary` at `:15-17` says *"The **mobile** boards have no
bottom copy at all."*** Registered as **`G-19` residual item R-2**. **Pre-existing** (Manager, `674b871`),
**not** introduced by Revision 6, and **not measured** by any pass — every measurement was of the **desktop**
`S` boards. **It does not widen `G-18`**: it adds no board obligation and creates no outcome conflict, because
the decision's mobile outcome is consistent with the boards per **both** `context.summary` and the human's
own check.

### `LOW-3` — `G-20` stale — **✅ APPLIED. DISCHARGED, with the status kept.**

Re-verified at `14b0267` with **full paths and `--diff-filter=A`**: all four Revision-3 artifacts added at
`af8e30f`; the 11 banners committed; `git status` empty. **The register entry keeps a `CLOSED` status rather
than being deleted** — a gap that was real and was discharged is a fact, and deleting it would send the next
reader to re-derive the residue. Revision 6's "before" claims are **true and retained**, re-anchored to
`1c3f5ad`.

### `LOW-4` — Revision 5 has no forward pointer — **✅ APPLIED AS A GENERALISATION, NOT A PATCH**

Revision 5 is committed and this lane may not commit; editing it would dirty a committed artifact to add a
pointer the chain already provides. Verified at `14b0267`: `design-revision-5.md` has **zero** mentions of
Revision 6 or Revision 7. **The residual is generalised and registered as `G-22`**, which also covers Revision
6's own committed false text — **the same mechanism, one revision later.** Both fixes are one-line banners
(§ 7), owned by the Manager.

---

## 6. What was NOT done, deliberately

- **No redesign.** The footer spec, the three code edits and `design_primitives.dart:396` are unchanged.
- **No decision re-opened.** `27ea6536` is `RESOLVED`; its outcome, per-platform clauses and
  *boards-are-authoritative* instruction all stand. **The human is not asked to re-decide the footer.**
- **No risk retired by this lane.** A1 was retired **by the owner**; this lane records it and says so.
- **No pin re-fixed.** The loop was already correct.
- **No committed artifact edited** — Revision 5's or Revision 6's. **That is what makes
  `design-revision-6.md:277` and `:523` citable, which is how two of these findings were found at all — and
  its cost is `G-22`, stated rather than paid silently.**
- **No board touched** (§ 3). **Nothing written** to `.decisions/**` or `docs/adr/**`.

---

## 7. The two supersession banners `G-22` needs — for whoever commits

**One-line prepends to committed files. Not this lane's: it may not commit.**

**On `design-revision-5.md`:**

```
> ## SUPERSEDED BY DESIGN REVISION 6 (`d26658219dea4955b0d2b4004a70aa4d`), which is itself superseded by
> DESIGN REVISION 7 (`3877696f-…`). This artifact is **retained verbatim**; no line below is edited.
> Its § 10.2 (14 items) is **carried unchanged by reference** — see design-revision-7.md § R.1-j.
```

**On `design-revision-6.md`:**

```
> ## SUPERSEDED BY DESIGN REVISION 7 (`3877696f-c15d-4ea8-9941-898fa601bf44`). This artifact is
> **retained byte-identical** at `2187065c…` and is **committed on main at `af8e30f`**; no line below is
> edited, which is what makes it citable as the reviewed text.
> ⚠ **45 cross-reference sites across 7 targets in this artifact mis-resolve, and 8 sites assert a false
> `blob_hash` claim. Both are corrected in `design-revision-7.md` § R.11g-j § A and § B — NOT here.**
> See gap `G-22`. Itemised defects: `§ 10.2-h` (2 sites, nonexistent) · `§ 10.2` meaning this revision's own
> (1) · the ADR amendment's `§ 3.1` (1, wrong file) · `§ Content pins` (7, unnumbered heading) · bare
> `§ R.11g` (17, collision with Revision 5's) · `§ 10.1 item 12` (16, item 12 is in § 10.1-h) · bare `§ R.1`
> (1). Register counts: § R.18.2 is **18 rows**, `requirements_gaps` **19 entries** — not 19 → 22.
```

---

## 8. Gates

### 8.1 `NOT_RUN`

| Check | Status |
|---|---|
| **`docker` / `docker compose`, any subcommand** | **NONE ISSUED.** Not `info`, not `ps`, not `logs`, not `config`, not `down`, not `--rmi`. **This repository has ALREADY lost its QA database** to a lane running `docker compose -f docker/compose.qa.yaml down -v --rmi local`. **The rule was not tested, because testing it is the forbidden act.** Compose files **not read** |
| **Any Penpot tool** | **NONE CALLED.** No board read, listed, edited, renamed, moved, exported, created or deleted |
| `dart analyze` / `flutter analyze` / build | **NOT_RUN** |
| `dart test packages/product_registry/test` | **NOT_RUN** |
| `make test-integration` | **NOT_RUN** — the only sanctioned exemption; not needed |
| `T-A` … `T-L` | **NOT_RUN** — specified, not executed; not adopted as this lane's result |
| Contrast measurement | **NOT_RUN** — figures **inherited**, not re-measured |
| ADR amendment — merge / edit / review | **NOT_RUN**, none of the three. `docs/adr/**` is `PROHIBITED_PATHS`. `G-17` and `G-21` stand, unedited and unclaimed |
| `.decisions/**` — write | **NOT_RUN.** Read only; `G-19`'s residual fix **specified**, not applied |
| Commit / push | **NOT_RUN** — as instructed |
| Deletions | **NONE.** The 8 displaced files went **outside the repository** and were re-verified after the merge |

### 8.2 What **was** verified

| # | Check | Result |
|---|---|---|
| **`V-1`** | **Every `file:line` citation Revision 6 carries into its superseded siblings, re-read at `14b0267`** | **Pass.** `design-revision-6.md:280` → `design-revision-5.md:2388-2393` is Revision 5 § R.11g **item 7**, verbatim the footer spec; `:158` → `:2414` is the `:925`-is-mobile correction; → `design-revision-metadata-5.yaml:739-742` and `traceability-matrix-5.md:139` **both** state *"the mobile site exists and has a `note:`"* and **agree**; `:599` → `design-register-button/report.md:71-76` resolves and carries `inkTertiary` **4.23:1 dark, fails AA**. **All resolve exactly** |
| **`V-2`** | **THE CROSS-REFERENCE AUDIT — every `§`-token in all four Revision-6 artifacts extracted and resolved against live heading inventories** | **Pass, with 7 findings: 7 targets / 45 sites.** Rev-6 headings, rev-5 headings, `report-revision-6.md`, `traceability-matrix-6.md`, `penpot-board-evidence.md`, the rev-5 review report, `AGENTS.md` and `aef-orchestrator/SKILL.md` all enumerated at `14b0267`. **Method published as rule `R4`** |
| **`V-3`** | **Pre-flight and the `F-16` recovery** | **Pass.** 19 shadowing files compared by `git hash-object` — **all 19 byte-identical**; backup outside the repository; 8 moved out, 11 restored; fast-forward; 8 re-compared post-merge, **all identical**; `git status` clean |
| **`V-4`** | **Register counts, counted not inferred** | **Pass.** 15 / 16 at Revision 5; **18 / 19** at Revision 6; **21 / 22** at Revision 7 |
| **`V-5`** | **§ 0.4.1's enumeration recounted** | **Pass.** Was 17 names under "sixteen check out", including `L13`, which the next bullet calls wrong. Now **16** |
| **`V-6`** | **The `G-19` note's two residual items, at byte level** | **Both confirmed, and the cause is Revision 6's.** Source `\u2014`; hyphen at `27ea6536:175`, `design-revision-6.md:523`, `metadata-6.yaml:360`. `:120` vs `:15-17` self-contradiction confirmed |
| **`V-7`** | **A1's retirement — evidence, not adoption** | **Pass.** Insert-only on **both** tiers read from the shipped source; `876c6b97` records *"THREE are now recorded (A2, A3, A4)"*. **Revocation's other half: 0 matches** for handle-destroying calls |
| **`V-8`** | **`G-20`'s discharge** | **Pass.** All four Revision-3 artifacts added at `af8e30f`; the 11 banners committed; `git status` empty |
| **`V-9`** | **`G-18`'s new state** | **Recorded, NOT verified against Penpot.** The grant and the dormancy are the Manager's report; **no Penpot tool was called, no board was read.** `BPM`'s separate defects cited from `WORK_STATE.md:639` |

### 8.3 Ratings — all **carried unchanged**, each explained

| Rating | Value | Why it did not move |
|---|---|---|
| `design_system_compliance` | **PARTIAL** | The boards are not this lane's and it read none. **What this pass adds is not a compliance improvement but a registered non-conformance** (`G-18`) and a register that can finally be counted by the party publishing it — `H-3`'s fix means the register no longer over-reports its own size |
| `ux_accessibility_score` | **PARTIAL** | Figures **inherited, not re-measured** (`inkTertiary` 4.23:1 dark **fails WCAG AA**). **Revision 7 adds no user-facing surface and changes no copy, contrast, focus order or semantic.** The em-dash defect is a **quotation-accuracy** defect in a record, not a user-facing one |
| `implementation_feasibility` | **MEDIUM** | Unchanged at the aggregate: the three code edits are unchanged and remain **HIGH**. **One component's state changed and it moved the wrong way, so it is stated rather than absorbed:** `G-18` is no longer blocked on *ownership* — **the grant exists** — but on **Penpot's dormancy**. That is an **infrastructure** precondition, not a design difficulty |

### 8.4 Safe parallelism — carried unchanged

**Unaffected by every finding, safe now:** `G-11` (`D-4`/`D-5`/`D-6`, both tiers, eight columns); `G-13` step
3a + `G-16` step 3a + `T-L` + `SC-20`, **shipping `G-16` first**; `G-14`; the `repositoryId: productId`
placeholder retirement; and Revision 6 § R.11g-h's **three code edits**. **None is touched by any rev-6
finding.**

**NOT SAFE while `G-18` is open:** any board edit by a lane that does not hold the grant; treating
*"boards are authoritative"* as unconditional; **reading the grant as authorising a `BPM` footer edit**
(`G-23`); and **closing the work item**.

**`SC-01`–`SC-20` carried unchanged. No criterion added, removed or re-scoped.**

---

## 9. Discoveries

| Class | Finding | Disposition |
|---|---|---|
| **`DESIGN_DISCOVERY`** | **A target-existence check cannot see a false claim about a target.** The rev-6 reviewer enumerated Revision 6's § R.1 targets, found every one present, and still confirmed a row that lies about a section. **The class recurred inside the artifact built to eliminate it because the reviewer's method was structurally blind to it** | **Persisted** as the executable rule: **cross-references are audited by EXTRACTION against a live heading inventory, never by reading** — rule `R4`, published with the audit result |
| **`DESIGN_DISCOVERY`** | **A revision that introduces a heading name colliding with a superseded revision's section poisons its own citations.** Revision 6 created `## R.11g` (no numbered items) and `## 10.1-h`, then cited bare `§ R.11g item 7` **17 times** and `§ 10.1 item 12` **16 times** — every one resolving to a section that does not contain the named item | **Persisted** as rules **R1**/**R2**: new sections carry a distinct suffix; a superseded revision's section is cited as **`Revision N § X`** |
| **`PROJECT_FACT`** | **A falsifier an artifact fails is worse than no falsifier** — it teaches a reviewer that the row's own test is not worth running. Revision 6 published one its own artifact satisfied with four entries | **Persisted** as a pre-publication rule: **every falsifier in this artifact set is executed against the artifact before it is published** |
| **`PROJECT_FACT`** | **The em-dash defect's cause was upstream.** A paste-ready block supplied by the design side carried a normalised character, and the Manager pasted it faithfully — so the decision object inherited the defect from the artifact that specified its fix | **Persisted**: **a record-correction note is only as byte-accurate as the block that produced it**, and the producing lane owns the cause |
| **`CONTRADICTION`** | **ADR 0018's body says four accepted risks; the owner's retirement of A1 is recorded only in the decision objects** | **Escalated, not resolved** — `G-21`. Governance-touching, and `docs/adr/**` is `PROHIBITED_PATHS` |
| **`CONTRADICTION`** | **`27ea6536:120` contradicts its own `:15-17`** about the mobile boards | **Escalated, not resolved** — `G-19` residual R-2. `.decisions/**` is Manager-owned |
| **`PROJECT_FACT`** | **The basename-glob trap is now documented twice and it is still live.** `git log --all --diff-filter=A -- '*design-revision-3.md'` returns exactly two commits, and **both add another lane's file** | **Persisted** as the rule this lane executed: **full paths, always** |
| **`WORKFLOW_IMPROVEMENT`** *(reported, not acted on)* | **A merge precondition that refuses on untracked shadows is now the second occurrence in one worktree** (`F-16`), and it cost four commands plus a comparison step to recover safely | **Reported for independent review.** The recovery *is* the reusable part: back up outside the repository, compare by hash, move rather than delete, re-compare after |
| **`AUTOMATION_OPPORTUNITY`** *(reported)* | **The cross-reference audit is mechanical and could be a script.** Extract every `§`-token with its `file:line`, resolve against the target's heading inventory, and fail on an unresolved target — the exact check that found 45 sites where reading found 2 | **Reported for independent review**, not persisted as tooling from a design lane |

---

## 10. Ownership

| | |
|---|---|
| **`OWNED_PATHS`** | `docs/engineering/dispatch/tasks/design-addproduct-keyservice/**` — **the only paths written.** **Four new files created** (`design-revision-7.md`, `design-revision-metadata-7.yaml`, `traceability-matrix-7.md`, `report-revision-7.md`) and **one existing file appended to**: **`discoveries.md`**, adding **`D-35`…`D-40`** and a *"Not persisted — Revision 7"* table. **D-1…D-34 unchanged in substance** |
| **`READ_ONLY_PATHS`** | `.decisions/**`; `docs/adr/**`; `docs/engineering/**` outside `OWNED_PATHS`; `AGENTS.md`; all `apps/**` and `packages/**` source |
| **`PROHIBITED_PATHS`** | `apps/**`, `packages/**`; `docker/**`, `.github/**`; `.decisions/**`, `WORK_STATE.md`, `LANES.md`; the mobile lane's directory; the ADR lane's directory; `docs/engineering/dispatch/tasks/design-review-*/**`, `design-rereview-*/**`; **every Penpot board** |
| **Not written** | `apps/**`, `packages/**`, `docker/**`, `.github/**`, `.decisions/**`, `docs/adr/**`, any sibling lane's directory, any review directory, **any board** |
| **Superseded artifacts edited** | **NONE.** Revisions 5's and 6's four artifacts each are **retained byte-identical**, committed on `main` at `16cd497` and `af8e30f`. **That is deliberate and its cost is `G-22`** |
| **Committed / pushed** | **NO / NO.** **Revision 6 IS committed underneath** |

---

## 11. Result

```
RESULT: DESIGN_REVISION_COMPLETE

FEATURE: Add Product rebuild — server-side deploy-key service, Design Revision 7
BRIEF_ID: 97484D0E-E16C-485E-BAA2-A277889C0FB6
REVISION_ID: 3877696f-c15d-4ea8-9941-898fa601bf44
REVISION_NUMBER: 7
BRANCH: design-correct-addproduct-keys
BASE_SHA: 14b026719a1433362059fb02d3fccc37c678462b
HEAD_SHA: 14b026719a1433362059fb02d3fccc37c678462b

OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**

READ_ONLY_PATHS:
  - .decisions/**, docs/adr/**, docs/engineering/** (outside OWNED_PATHS),
    AGENTS.md, apps/**, packages/**

PROHIBITED_PATHS:
  - apps/**, packages/**, docker/**, .github/**,
    .decisions/**, WORK_STATE.md, LANES.md,
    docs/engineering/dispatch/tasks/design-addproduct-mobile/**,
    docs/engineering/dispatch/tasks/design-adr-0018-amendment/**,
    docs/engineering/dispatch/tasks/design-review-*/**,
    docs/engineering/dispatch/tasks/design-rereview-*/**,
    EVERY Penpot board

ARTIFACT_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-7.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata-7.yaml
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix-7.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/report-revision-7.md

RISK_LEVEL: 3
RISK_RATIONALE: >
  Unchanged and re-affirmed, not inherited. Per DESIGN_GOVERNANCE.md:94-99, Level 3 requires
  product/design/architecture human approval, which this revision does NOT have and does not claim.
  All six grounds re-confirmed present at 14b0267: 898b07d0 makes a Product visible before
  registration commits; RegistrationCommitState is a five-state client model and state 4 is
  currently indistinguishable from state 1 (G-14); Revision 5 § R.11g item 3 adds a resume route
  from the product into the credential flow; this is the first handling of key material by SHIP IT;
  the SSH transport seam has no precedent and carries a half-implemented ADR requirement (G-4) on
  the credential path; and the credential-minting endpoint declares no authentication.
  THE TALLY IS UNCHANGED AND VERBATIM: "0 reasons IMPROVED, 2 reasons UNCHANGED (R1, R6), 4
  reasons WORSE (R2, R3, R4, R5)". Revision 7 moves no reason's status in either direction and
  claims no new reason — claiming one for bookkeeping is the same error class as H10.
  FIVE open governance items (G-18, G-19 + 2 residual items, G-21, G-22, G-23) are an argument FOR
  level 3, not against it: a design at level 1 does not accumulate governance debt. Revision 6
  argued this with three; Revision 7 argues it with five and the argument is STRONGER.
  ACCEPTED RISKS ARE NOW THREE: A2, A3, A4. A1 was retired BY THE REPOSITORY OWNER on 2026-10-07,
  verified against the shipped source (insert-only mint on both tiers) and NOT retired by a design
  lane — two prior lanes were right to decline. Retiring A1 discharged the RESURRECTION half only:
  no code destroys a secret-manager handle, so revocation remains ONE-SIDED IN PRACTICE and that
  half was never an accepted risk. ADR 0018's own body still records four; that is G-21.

CHANGELOG:
  - H-1: NOT PATCHED — RE-DERIVED. The two dead pointers are corrected by describing § 10.2
    correctly (carried unchanged by reference, not "with § 10.2-h"), and EVERY cross-reference in the
    Revision-6 artifact set was re-derived from the live documents. THE AUDIT FOUND 7 DISTINCT
    MIS-RESOLVING TARGETS ACROSS 45 SITES against the re-review's 1 target / 2 sites. Six targets
    and 43 sites were unreported. Itemised at design-revision-7.md § R.11g-j § A; the METHOD is
    published as normative rule R4. A patch to the three named sites would have left 42 of the 45.
  - H-2: THE PINS ARE NOT RE-FIXED — THE CLAIM IS. Corrected at all EIGHT sites that assert it; the
    re-review found five, and design-revision-6.md:162 (inside Revision 6's OWN L-R5-1 correction-
    map row), report-revision-6.md:286 and :518 were the three it missed. The "two self-excluded
    files" comment is corrected to FOUR. The falsifier Revision 6 published — which its own artifact
    satisfied with four entries — is AMENDED to test what the artifact actually does, and was
    executed against the artifact before publication. The irreducible limit is stated: the report's
    own hash is carried by no artifact; `git hash-object report-revision-7.md` recovers it.
  - H-3: BOTH COUNTS RE-COUNTED FROM THE LIVE DOCUMENTS — 15 rows / 16 entries at Revision 5,
    18 / 19 at Revision 6 (published as 19 -> 22; wrong by 4 and 3). REVISION 7 = 21 ROWS /
    22 ENTRIES, counted from the same bases so it does not acquire a new wrong pair.
  - M-1: § 0.4.1's enumeration recounted — 16 names, with L13 claimed only in the bullet that reports
    its error. Coverage 16 + L8 + M5 + L13 = 19.
  - LOW-1: THE ROOT CAUSE IS REVISION 6's, not the decision's. design-revision-6.md:523 — the
    paste-ready block — and metadata-6.yaml:360 carried a hyphen where the build renders an em dash;
    the Manager pasted 27ea6536 faithfully, so the defect was inherited. Corrected here; the
    .decisions/** copy specified for the Manager.
  - LOW-2: REGISTERED as G-19 residual R-2 (27ea6536:120 against its own :15-17). Pre-existing,
    unmeasured, and it does NOT widen G-18.
  - LOW-3: G-20 CLOSED — DISCHARGED at af8e30f, re-verified at 14b0267 with full paths. The register
    entry KEEPS a status rather than being deleted.
  - LOW-4: NOT FIXED ON REVISION 5, and GENERALISED as G-22 — which also covers Revision 6's own
    committed false text. Two one-line banners specified; owned by the Manager.
  - NEW G-21: ADR 0018's own body still records FOUR accepted risks. Already specified by the ADR
    lane and uncommitted there too. Nothing written; docs/adr/** is PROHIBITED.
  - NEW G-22: Revision 6's false and mis-resolving text is committed and this correction does not
    travel with the file. Not editing a committed artifact is CORRECT and is what made
    design-revision-6.md:277 and :523 citable — and it is not free. Owner: Manager.
  - NEW G-23: THE BOARD-OWNERSHIP GRANT COVERS BPM; G-18's MEASURED OBLIGATION DOES NOT. A grant of
    ownership is not a finding of fact. Whether BPM carries the layer is UNVERIFIED IN BOTH
    DIRECTIONS and is the granted lane's to establish.
  - NEW § R.6-j: revocation is still ONE-SIDED, recorded against Revision 5 § R.6 because this is
    the revision that records A1's retirement and that is exactly where a reader will conclude the
    clause is discharged.
  - NEW § R.11g-j: the CROSS-REFERENCE CONVENTION — five normative rules. This is the design content
    of the pass.
  - G-18: OPEN. THE GRANT IS DECIDED; THE OBLIGATION IS NOT DISCHARGED, and the blocker changed form
    from ownership to Penpot's dormancy. THE WORK ITEM MUST NOT CLOSE OVER IT.
  - SC-01..SC-20 and the risk tally carried unchanged; no reason moves and no new reason is claimed.

TRACEABILITY:
  REQUIREMENTS_COVERED:
    - R-B1 provenance — CLOSED. BASE_SHA = HEAD_SHA = 14b0267 by fast-forward. The F-16 merge
      precondition and the 19-file recovery are recorded in full (§ 0.3.1). Nothing deleted.
    - R-B2 compensation construct — UNCHANGED. Revision 5 § R.5.7's five obligations and both forms.
    - R-B3 state 4 renderable — UNCHANGED. § R.11.2; G-14 open and unaffected.
    - R-B4 per-tier specification — UNCHANGED. § R.9 untouched by every finding.
    - R-B5 ADR acceptance cited, acceptance-is-not-review — CLOSED and CONFIRMED by the Rev-5
      reviewer; re-derived by nobody.
    - R-B6 cross-product disclosure — UNCHANGED. § R.14.1 step 3a and T-L; G-16 stays first.
    - R-R1 ADR 0018 dependence — UNCHANGED. G-17 open, unedited, unclaimed. G-21 is its SIBLING.
    - R-UX1 refusal leaves no residue — UNCHANGED. § R.11g item 5.
    - R-UX2 boards match code and code matches boards — ★ STILL PARTIALLY COVERED, and the STATUS
      HAS MOVED: the CODE side is unchanged and fully specified; the BOARD side now HAS AN OWNER
      (the human granted board ownership) and the EDIT HAS NOT BEEN DONE. So the obligation is OWNED
      and EXECUTED-PENDING, blocked on Penpot's dormancy rather than on ownership. Coverage and
      completion are different claims and only the first is true. A GRANT IS NOT AN EXECUTION.
  REQUIREMENTS_GAPS:
    - G-3 … G-17, L-6, ADR 0018 :103 wording, and G-18, G-19, G-20 — CARRIED UNCHANGED by
      reference. No row weakened, removed or re-owned.
    - G-18 — OPEN. The four-board edit has an OWNER and no EXECUTION. § 10.1-j item 12.
    - G-19 — MAIN NOTE APPLIED at af8e30f (framing sound); TWO RESIDUAL ITEMS OPEN: a hyphen
      normalised in a quoted string, and a third inaccurate statement about the mobile boards.
    - G-20 — CLOSED, DISCHARGED at af8e30f.
    - G-21 — NEW. ADR 0018's body still records four accepted risks. Owner: ADR lane + Manager.
    - G-22 — NEW. 45 mis-resolving sites and 8 false-claim sites committed at af8e30f with no
      redirect. Owner: Manager.
    - G-23 — NEW. The grant covers BPM; the obligation does not. Owner: granted lane + Manager.
    - "the Rev-4 review report" — ★ CLOSED (carried from Revision 6, not re-claimed).

DESIGN_SYSTEM_COMPLIANCE: PARTIAL
UX_ACCESSIBILITY_SCORE: PARTIAL
IMPLEMENTATION_FEASIBILITY: MEDIUM

DISCOVERIES:
  - DESIGN_DISCOVERY (persisted): a TARGET-EXISTENCE CHECK CANNOT SEE A FALSE CLAIM ABOUT A TARGET.
    The re-reviewer enumerated every § R.1 target, found them all present, and confirmed a row that
    lies. Persisted as the executable rule: cross-references are audited by EXTRACTION against a
    live heading inventory, never by reading.
  - DESIGN_DISCOVERY (persisted): a revision that introduces a heading colliding with a superseded
    revision's section poisons its own citations — 33 of the 45 sites. Persisted as rules R1/R2.
  - PROJECT_FACT (persisted): A FALSIFIER AN ARTIFACT FAILS IS WORSE THAN NO FALSIFIER. Every
    falsifier here is executed against the artifact before publication.
  - PROJECT_FACT (persisted): a record-correction note is only as byte-accurate as the block that
    produced it; the producing lane owns the cause of the em-dash defect.
  - CONTRADICTION (escalated, not resolved): ADR 0018 says four accepted risks; the owner's
    retirement is recorded only in the decision objects. G-21.
  - CONTRADICTION (escalated, not resolved): 27ea6536:120 contradicts its own :15-17. G-19 R-2.
  - PROJECT_FACT (persisted): the basename-glob trap — '*design-revision-3.md' returns two OTHER
    lanes' commits. Full paths, always.
  - WORKFLOW_IMPROVEMENT (reported for independent review): F-16 is the second merge precondition
    refused in one worktree; the hash-compare-then-move recovery is the reusable part.
  - AUTOMATION_OPPORTUNITY (reported): the cross-reference audit is mechanical and could be a script
    that fails on an unresolved target — the check that found 45 sites where reading found 2.

KNOWLEDGE_PERSISTED:
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/discoveries.md — D-35..D-40 added;
    D-1..D-34 unchanged in substance. CONTRADICTION-class items are REPORTED, not persisted, per
    LEARNING_POLICY.md.
  - Nothing outside OWNED_PATHS. No board. No .decisions/**. No docs/adr/**. No production source.

BLOCKERS:
  - NONE in the design content. All 8 rev-6 findings are APPLIED.
  - UNOWNED or UNEXECUTED, and registered rather than resolved:
      * G-18 — the four-board edit. THE OWNERSHIP GRANT EXISTS; THE EXECUTION DOES NOT. A grant is
        not an execution. THE WORK ITEM MUST NOT CLOSE OVER THIS UNTIL THE BOARD EDIT IS DONE AND
        REVIEWED. The blocker has changed form: Penpot went dormant (plugin tab suspended,
        getPages() returns a heartbeat error), so the granted lane may be blocked on the plugin.
      * G-19 — two residual record items on .decisions/27ea6536. Specified ready to apply (§ 7-j.1).
        This lane wrote nothing there.
      * G-21 — ADR 0018's accepted-risk section still says four. Already specified by the ADR lane
        and uncommitted there too. This lane wrote nothing there.
      * G-22 — two supersession banners so the committed false text has a redirect (§ 7).
      * G-23 — BPM's state must be ESTABLISHED by the granted lane before it edits BPM.
  - Penpot remains unreachable from every lane; the mechanism has changed and is recorded.
  - This revision is NOT self-approved. READY_FOR_INDEPENDENT_DESIGN_REVIEW is a statement about
    readiness, not a verdict, and no approval of any kind stands behind Revisions 1-7.

READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES
```

**What the reviewer should check hardest, in order.**

1. **§ R.11g-j § A — run the extraction.** That is the load-bearing claim of this pass: **7 targets /
   45 sites**, against the re-review's 1 / 2. **If it finds nothing outside that table, this revision is
   wrong.**
2. **Every falsifier in `traceability-matrix-7.md` § 2 was executed against the artifact before
   publication** — especially the amended `L-R5-1` one, which replaced a falsifier Revision 6's own
   artifact satisfied.
3. **The four-risk correction says THREE and the ADR says FOUR.** Both are stated, neither is smoothed,
   and the disagreement is `G-21`. Check that A1's retirement is attributed to **the owner** and that the
   revocation half is **not** presented as discharged.
4. **`G-18`'s new state: grant decided, obligation open, blocker changed form.** The work item must not
   close over it, and `G-23` must stop `BPM` being read as an authorised footer edit.
5. **`G-22` — the committed false text and the redirect that does not exist.** Check that not editing
   Revision 6 was the right call *and* that its cost is recorded rather than paid silently.
6. **The register counts: 15/16 → 18/19 → 21/22**, counted from the live documents.
7. **`report-revision-7.md` § 1.1 is numbered** — the seven unnumbered-`§` sites are the reason, and rule
   `R5` is the generalisation.