# Subtask Report — design-correct-addproduct-keys-7 (Design Revision 7)

```yaml
RESULT: DESIGN_REVISION_COMPLETE
TASK_ID: design-correct-addproduct-keys-7
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — deploy-key service, Design Revision 7
WORKTREE: /private/tmp/shipit-correct-addproduct-keys
BRANCH: design-correct-addproduct-keys
BASE_SHA: 14b0267
HEAD_SHA: 14b0267
COMMITTED: NO
```

**Note on BASE_SHA:** the dispatch named `762e5cd`. `main` had advanced to **`14b0267`** by launch, and that
commit carries material this pass must not miss — it is the A1 retirement. I fast-forwarded to `14b0267`
and based on it. Disclosed rather than silently re-based.

---

## 0. Isolation pre-flight — F-16 fired again, and it was recovered

`git merge --ff-only 14b0267` **failed**, exactly as warned: **11 tracked + 8 untracked = 19 shadowing
files**. Per the instruction, **nothing was deleted and I did not refuse to start.**

All **19** were compared with `git hash-object` against the blobs `14b0267` carries: **all 19
byte-identical.** A full copy went **outside the repository first**; the 8 untracked were **moved out**
(not deleted); the 11 tracked were restored with `git checkout --`; the fast-forward proceeded; the 8 were
**re-compared after the merge — all 8 identical.** `git status` clean. **No lane had to be stopped, because
no file genuinely differed.** Recorded as `F-16` / `D-40` / `G-22`.

**Revision 6's artifacts are on `main` at `af8e30f`** and were reviewed from there; all eight of Revision 5's
and Revision 6's superseded artifacts are verified **byte-identical to `14b0267`** at the end of this pass.

---

## 1. Per-finding disposition

| Finding | Disposition |
|---|---|
| **H-1** — `§ 10.2-h` does not exist; three false claims; rev 6 self-contradicts at `:282-284` | **✅ APPLIED BY RE-DERIVATION, NOT BY PATCH.** The two dead pointers are corrected by **describing § 10.2 correctly** — carried **unchanged by reference** to `design-revision-5.md:3299-3362`, not "with § 10.2-h", and **not restated in rev 6 either** (§ R.1-j). Writing a `§ 10.2-h` would have created a second copy of a **14-item** reviewer checklist with **13 items silently omitted**, in the section whose purpose is telling a reviewer what to check. **AND every cross-reference in the rev-6 artifact set was re-derived from the live documents** — every `§`-token extracted with its `file:line` and resolved against live heading inventories (§ R.11g-j § A). The audit is published as **normative rule `R4`**, so the next pass re-runs it instead of reading |
| **H-2** — `L-R5-1` reported closed on a false claim; its own falsifier satisfied by four entries | **✅ APPLIED. THE PINS ARE NOT RE-FIXED** — the loop is real and was verified byte-exact; that is settled. The **claim** is restated at **all eight** sites that make it (the reviewer found **five**). `metadata-6.yaml:470`'s *"THE **two** self-excluded files"* corrected to **four**. **The falsifier is AMENDED** and **executed against the artifact before publication** — it passes: 17 entries parsed, 8 real hashes verified against `git hash-object`, 2 pointers resolving to printed hashes, 2 permitted self-exclusions, 5 with no `blob_hash` key (named, so scope isn't read as coverage). The irreducible limit is stated: the report's own hash is carried by **no** artifact |
| **H-3** — both register counts wrong (19→22; actual 15→18 and 16→19) | **✅ APPLIED, and rev 7's OWN figures counted from the same bases.** Rev 5 = **15 rows / 16 entries**; rev 6 = **18 / 19**; **rev 7 = 21 rows / 22 entries.** The **21-vs-22 asymmetry is stated, not smoothed** (§ R.18.2 has no row for the closed *"Rev-4 review report"*; `requirements_gaps` carries it marked `CLOSED`) |
| **M-1** — 17 rows enumerated as "sixteen check out", including `L13` | **✅ APPLIED.** `L13` dropped, leaving **16** names; coverage **16 + `L8` + `M5` + `L13` = 19**. The list is now produced by extraction, so it cannot diverge from the count |
| **LOW-1** — em dash normalised to hyphen | **✅ APPLIED, AND THE CAUSE RE-ATTRIBUTED.** **The cause is rev 6's, not the decision's**: `design-revision-6.md:523` — the **paste-ready block** — and `metadata-6.yaml:360`. The Manager pasted faithfully; the defect was **inherited**. Both of rev 6's sites are corrected here; the `.decisions/**` copy is not mine and the corrected block is specified at § 7-j.1 |
| **LOW-2** — unregistered third inaccurate statement in `27ea6536` | **✅ APPLIED, REGISTERED** as **`G-19` residual R-2** (`:120` against its own `:15-17`), with scope limit: **unmeasured**, so it **adds no board obligation and does not widen `G-18`** |
| **LOW-3** — `G-20` stale at the reviewed HEAD | **✅ APPLIED. DISCHARGED**, re-verified at `14b0267` with **full paths**: all four rev-3 artifacts added at `af8e30f`; the 11 banners committed; `git status` empty. The entry **keeps a `CLOSED` status** rather than being deleted |
| **LOW-4** — rev 5 has no forward pointer to rev 6 | **✅ APPLIED AS A GENERALISATION.** Not fixed on rev 5 (committed; this lane may not commit), and the residual is **generalised as `G-22`**, which also covers rev 6's own committed false text — **the same mechanism one revision later**. Verified: rev 5 has **zero** mentions of Revision 6 or 7. Both fixes are one-line banners, specified for the Manager |

---

## 2. ⚠ MY OWN COUNT OF DANGLING CROSS-REFERENCES — the measure of whether the re-derivation was done

| | Reported by the re-review | **Found by me** |
|---|---|---|
| Distinct mis-resolving **targets** | **1** | **7** |
| **Sites** | **2** | **45** |
| False `blob_hash`-claim sites | 5 | **8** |

**Six targets and 43 sites were unreported.** Itemised at `design-revision-7.md` § R.11g-j § A:

| # | Target | Sites | Why it mis-resolves |
|---|---|---|---|
| **A-1** | `§ 10.2-h` | **2** | **Nothing.** No such heading anywhere in the chain — *reported* |
| **A-2** | `§ 10.2` meaning rev 6's own | **1** | **Nothing.** Rev 6 has `## 10.1-h` and no § 10.2 — **`report-revision-6.md:364`**, unreported |
| **A-3** | the ADR amendment's `§ 3.1` | **1** | **Exists in the WRONG FILE** — it is `design-adr-0018-amendment/design-revision.md:142` (**Revision 1**), while rev 5 names `design-revision-2.md` beside it, **which has no § 3.1**. Identifier right, file wrong, conflated in one sentence — unreported |
| **A-4** | `§ Content pins` / `§ pins` | **7** | The heading at `report-revision-6.md:28` is **unnumbered**, so `§ Content pins` resolves to **no numbered section** — under two spellings — unreported |
| **A-5** | bare `§ R.11g` | **17** | **A collision rev 6 created**: rev 6's `## R.11g` has **no numbered items**, so every `§ R.11g item 7` lands where no item 7 exists — unreported |
| **A-6** | `§ 10.1 item 12` | **16** | **The literal target has no item 12** — rev 5's § 10.1 has items 1–11; item 12 is in rev 6's `§ 10.1-h`, which the 16 citations never name — unreported |
| **A-7** | bare `§ R.1` | **1** | Collision rev 6 created (its incorporation table vs rev 5's at-rest model) — **mitigated in rev 6** by the column header, and recorded as the mildest row |

**A-5 + A-6 alone are 33 sites.** **A patch to the three sites named in H-1 would have left 42 of the 45 in
place** — which is precisely why the dispatch said not to patch.

**Why reading could not find these, which is the design content of the pass:** the re-reviewer enumerated
rev 6's § R.1 targets and confirmed **every one exists** — and still confirmed a row that *lies about* one.
**A target-existence check cannot see a false claim about a target.** The five rules in § R.11g-j, and
especially **`R4` (the audit is an EXTRACTION, not a reading)**, are the durable fix.

**I ran that same audit on my own four artifacts: 0 unresolved `§` tokens.**

---

## 3. ⚠ Confirmation: every stale four-risk count is now three

**Accepted risk A1 was retired by the repository owner on 2026-10-07. `A2`, `A3`, `A4` remain.** Revision 6
carried four and said so at **three** sites (`design-revision-6.md:651-652`,
`design-revision-metadata-6.yaml:465`, `report-revision-6.md:165-166`) — **all three are now corrected, and
the rev-7 set contains no assertion that four risks are current.**

**Verified against the shipped source, not adopted** (`V-7`): `postgres_product_registry_store.dart:190-191`
(*"the null-`expectedVersion` branch is `DO NOTHING`, not a predicated `DO UPDATE`"*);
`in_memory_product_registry_store.dart:167-169,184`; `product_registry_engine.dart:933-936`; and
`876c6b97`'s second scope note at `14b0267` — *"THREE are now recorded (A2, A3, A4)"*.

**Recorded as the owner's decision, and attributed that way.** Two prior lanes were **right to decline** —
`876c6b97`'s first scope note says *"RETIRING IT IS THE OWNER'S CALL"*. **A design lane may not retire an
accepted risk.**

**Three things I did not do, and each would have been wrong:**

1. **I did not conflate the retired risk id with the live substrate option.** Three readings of "A1" are kept
   apart: the **accepted risk** (retired); **Amendment A1** *"scope is the repository"* (ADR `:35`) — **live,
   and live in the code today** at `product_registry_store.dart:47` and `:52-53` (*"KEY MATERIAL IS IMMUTABLE
   (ADR 0018 A1)"*); and the **substrate option A1** = filesystem `0600` (ADR `:107`, `:442`).
2. **I did not match the ADR by editing the count in the wrong place.** **ADR 0018's own body still records
   FOUR** — `grep -c 'Consequence accepted'` → **`4`**; `:453` still `ACCEPTED`; `:448-451`, `:527`, `:557`,
   `:574` all say four. That disagreement is registered as **`G-21`**, owned by the ADR lane + Manager.
   `docs/adr/**` is `PROHIBITED_PATHS` — **nothing written.** The edit is **already specified** by the ADR
   lane (`design-revision-5.md` § 4) and is **uncommitted there too**.
3. **I did not record the retirement as reaching revocation.** It discharged the **resurrection half only**:
   `grep` for handle-destroying calls across `apps`/`packages` → **0 matches**, so **revocation remains
   one-sided in practice** and **that half was never an accepted risk**. Recorded against Revision 5 § R.6 at
   **§ R.6-j** — because this is the revision that records A1's retirement, and that is exactly where a
   reader will conclude the clause is discharged. **No `G-24` was invented for it:** `79e860e2` already owns
   it, and duplicating a known gap is how a register stops being an index.

---

## 4. G-18 — the ownership grant recorded, the obligation kept OPEN

**THE GRANT IS DECIDED.** A scoped design-system lane will own the four desktop `S · Add Product · …` boards
(and `BPM`) to remove the single `Footer` text layer at (236, 862).

**Recorded as decided. NOT recorded as discharged.** Two things recorded rather than resolved:

- **A grant is not an execution. THE WORK ITEM MUST NOT CLOSE OVER `G-18` UNTIL THE BOARD EDIT IS DONE AND
  REVIEWED.** And the blocker **changed form**: Penpot went **dormant** — plugin tab suspended,
  `getPages()` returning a **heartbeat error** — so the lane may be dispatched but blocked on the plugin. A
  different fault from the *"No Penpot instance connected for user token"* binding failure rev 6 recorded, same
  destination.
- **`G-23` — the grant is broader than the obligation.** Every measurement of a `Footer` layer at (236, 862)
  is on **the four desktop `S` boards**; **BPM was measured as carrying no footer copy**, and its recorded
  defects are **different** (the false custody string and the now-false `NOT REGISTERED YET` eyebrow,
  `WORK_STATE.md:639`). **A grant of ownership is not a finding of fact.** Whether BPM carries the layer is
  **UNVERIFIED IN BOTH DIRECTIONS** and is the granted lane's to establish. **I called no Penpot tool and read
  no board.**

---

## 5. New register entries — 3 added, 1 discharged, 1 extended

| Id | State | Owner |
|---|---|---|
| **`G-21`** | **NEW** — ADR 0018's body still records four accepted risks | ADR lane + Manager |
| **`G-22`** | **NEW** — rev 6's 45 mis-resolving sites and 8 false-claim sites are committed at `af8e30f`, and this correction **does not travel with the file**. Not editing a committed artifact is **correct** (it is what made `design-revision-6.md:277` and `:523` citable, which is *how* two findings were found) — **and it is not free.** Two one-line banner texts specified for the Manager | Manager |
| **`G-23`** | **NEW** — grant covers `BPM`; `G-18`'s obligation does not | granted lane + Manager |
| **`G-20`** | **CLOSED — DISCHARGED at `af8e30f`**, status retained rather than the entry deleted | — |
| **`G-19`** | main note applied at `af8e30f`; **two residual items open** (R-1 hyphen, R-2 third statement) | Manager |

**Counts, from the live documents:** rev 5 = **15 rows / 16 entries** → rev 6 = **18 / 19** → **rev 7 = 21 rows /
22 entries.**

---

## 6. Hard rules — all honoured, and stated rather than assumed

- **NO Docker or Compose command of any kind was run** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **Compose files were not read.** This repository has already lost its QA database to a
  lane running `docker compose -f docker/compose.qa.yaml down -v --rmi local`. The rule was not tested,
  because testing it is the forbidden act.
- **NO Penpot tool was called. NO board read, listed, edited, renamed, moved, exported or deleted.** No board
  ownership.
- **Nothing written** to `.decisions/**` or `docs/adr/**`, both `PROHIBITED_PATHS`. Both record fixes are
  **specified, ready to apply** (§ 7-j), and **no such edit is claimed**.
- **No production source.** No mobile-lane or ADR-lane directory. No `WORK_STATE.md` / `LANES.md`.
- **NOTHING COMMITTED, NOTHING PUSHED.** `HEAD` is still `14b0267`; the four rev-7 artifacts are untracked and
  `discoveries.md` is modified-uncommitted. Revision 7 is **left in the worktree**.
- **I do not approve my own work.** `READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES` is a readiness statement, not a
  verdict.
- **Full paths, never basenames.** Every `git log --all --diff-filter=A` used the **exact full path** — and the
  basename glob `'*design-revision-3.md'` is documented as a trap that returns **two other lanes'** commits.
- **Line and section numbers move when you edit, and I re-read after each edit.** This caught **four
  non-existent section references I had introduced myself** (`§ 7-j`, `§ 7-i`, `§ 7-k`, `§ 2-j`) plus two
  rule-R2 violations — before the artifacts were finished, not after. Every one is fixed, and the final audit
  of my own set reports **0 unresolved**.

---

## 7. Provenance and artifacts

```
RESULT: DESIGN_REVISION_COMPLETE

FEATURE: Add Product rebuild — deploy-key service, Design Revision 7
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
    docs/engineering/dispatch/tasks/design-review-*/**, design-rereview-*/**,
    EVERY Penpot board

ARTIFACT_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-7.md            (758 lines)
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata-7.yaml  (883 lines)
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix-7.md          (180 lines)
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/report-revision-7.md              (641 lines)
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/discoveries.md  (APPENDED: D-35..D-40
    + "Not persisted — Revision 7"; D-1..D-34 unchanged in substance)

RISK_LEVEL: 3
RISK_RATIONALE: >
  Unchanged and re-affirmed, not inherited. Per DESIGN_GOVERNANCE.md:94-99, Level 3 requires
  product/design/architecture human approval, which this revision does NOT have and does not claim. All six
  grounds re-confirmed present at 14b0267. THE TALLY IS UNCHANGED AND VERBATIM: "0 reasons IMPROVED,
  2 reasons UNCHANGED (R1, R6), 4 reasons WORSE (R2, R3, R4, R5)" — no reason moves in either direction and
  no new reason is claimed, since claiming one for bookkeeping is the same error class as H10.
  FIVE open governance items (G-18; G-19 + two residual items; G-21; G-22; G-23) against a level-3 design
  are an argument FOR level 3, not against it: a design at level 1 does not accumulate governance debt.
  Revision 6 argued this with three; Revision 7 argues it with five and the argument is STRONGER, not
  weaker — a correction pass that lowered the level because it changed no design content would be measuring
  the correction rather than the design. ACCEPTED RISKS ARE NOW THREE: A2, A3, A4. A1 was retired BY THE
  REPOSITORY OWNER on 2026-10-07, verified against the shipped source (insert-only mint on both tiers) and
  NOT retired by a design lane — two prior lanes were right to decline. Retiring A1 discharged the
  RESURRECTION half only: no code destroys a secret-manager handle, so revocation remains ONE-SIDED IN
  PRACTICE and that half was never an accepted risk. ADR 0018's own body still records four; that is G-21,
  owned by the ADR lane + Manager, with nothing written there.

CHANGELOG:
  - H-1: NOT PATCHED — RE-DERIVED. § 10.2 carried UNCHANGED BY REFERENCE, not "with § 10.2-h"; and every
    cross-reference in the rev-6 set re-derived from live documents. 7 targets / 45 sites against the
    reviewer's 1 / 2. Itemised at § R.11g-j § A; the METHOD published as normative rule R4.
  - H-2: THE PINS ARE NOT RE-FIXED — THE CLAIM IS. Corrected at all eight sites (three unreported:
    design-revision-6.md:162, report-revision-6.md:286, :518). "Two self-excluded" -> FOUR. The falsifier
    rev 6 published, which its own artifact satisfied with four entries, is AMENDED and EXECUTED before
    publication; it PASSES.
  - H-3: 15/16 -> 18/19 -> 21/22, counted from the live documents.
  - M-1: 17 names -> 16, L13 claimed only in the bullet that reports its error. 16 + L8 + M5 + L13 = 19.
  - LOW-1: THE CAUSE IS REV 6's — design-revision-6.md:523 (the paste-ready block) and metadata-6.yaml:360.
    Corrected here; the .decisions/** copy specified for the Manager.
  - LOW-2: REGISTERED as G-19 residual R-2 (27ea6536:120 vs its own :15-17). Unmeasured; does NOT widen G-18.
  - LOW-3: G-20 CLOSED — DISCHARGED at af8e30f, re-verified with full paths. The entry KEEPS a status.
  - LOW-4: Not fixed on rev 5; GENERALISED as G-22, which also covers rev 6's own committed false text.
  - NEW G-21: ADR 0018's body still records four accepted risks. Already specified by the ADR lane and
    uncommitted there too. Nothing written; docs/adr/** is PROHIBITED.
  - NEW G-22: rev 6's false and mis-resolving text is committed and this correction does not travel with the
    file. Not editing a committed artifact is CORRECT and is what made :277 and :523 citable; its cost is
    registered rather than paid silently. Owner: Manager.
  - NEW G-23: the grant covers BPM; G-18's measured obligation does not. A grant of ownership is not a finding
    of fact. Whether BPM carries the layer is UNVERIFIED IN BOTH DIRECTIONS.
  - NEW § R.6-j: revocation is still ONE-SIDED, recorded against Revision 5 § R.6 because this is where a
    reader will conclude the clause is discharged. No G-24 invented — 79e860e2 already owns it.
  - NEW § R.11g-j: the CROSS-REFERENCE CONVENTION, five normative rules. This is the design content of the pass.
  - G-18: OPEN. Grant decided; obligation NOT discharged; blocker changed form. The work item must not close
    over it.
  - SC-01..SC-20 and the risk tally carried unchanged.

TRACEABILITY:
  REQUIREMENTS_COVERED:
    - R-B1 provenance — CLOSED. BASE_SHA = HEAD_SHA = 14b0267 by fast-forward; F-16 and the 19-file recovery
      recorded; nothing deleted.
    - R-B2 compensation construct — UNCHANGED. Revision 5 § R.5.7's five obligations and both forms.
    - R-B3 state 4 renderable — UNCHANGED. § R.11.2; G-14 open and unaffected.
    - R-B4 per-tier specification — UNCHANGED. § R.9 untouched by every finding.
    - R-B5 ADR acceptance / acceptance-is-not-review — CLOSED and CONFIRMED by the Rev-5 reviewer; re-derived
      by nobody.
    - R-B6 cross-product disclosure — UNCHANGED. § R.14.1 step 3a and T-L; G-16 stays first.
    - R-R1 ADR 0018 dependence — UNCHANGED. G-17 open, unedited, unclaimed. G-21 is its SIBLING, not a
      correction of it.
    - R-UX1 refusal leaves no residue — UNCHANGED. § R.11g item 5.
    - R-UX2 boards match code and code matches boards — ★ STILL PARTIALLY COVERED, and THE STATUS HAS MOVED.
      The CODE side is unchanged and fully specified. The BOARD side now HAS AN OWNER (the human granted board
      ownership) and THE EDIT HAS NOT BEEN DONE — so the obligation is OWNED and EXECUTED-PENDING, blocked on
      Penpot's dormancy rather than on ownership. Coverage and completion are different claims and only the
      first is true. A GRANT IS NOT AN EXECUTION.
  REQUIREMENTS_GAPS:
    - G-3 … G-17, L-6, ADR 0018 :103 wording, and G-18, G-19, G-20 — CARRIED UNCHANGED by reference. No row
      weakened, removed or re-owned.
    - G-18 — OPEN. Owner granted; execution not done. THE WORK ITEM MUST NOT CLOSE OVER IT.
    - G-19 — main note applied at af8e30f; TWO RESIDUAL ITEMS OPEN (hyphen-normalised quotation; third
      inaccurate statement about the mobile boards).
    - G-20 — CLOSED, DISCHARGED at af8e30f.
    - G-21 — NEW. ADR 0018's body still records four accepted risks. Owner: ADR lane + Manager.
    - G-22 — NEW. 45 mis-resolving sites and 8 false-claim sites committed at af8e30f with no redirect.
      Owner: Manager.
    - G-23 — NEW. The grant covers BPM; the obligation does not. Owner: granted lane + Manager.
    - "the Rev-4 review report" — ★ CLOSED (carried from Revision 6; a revision may not re-claim a closure it
      did not perform, and this lane did not re-derive it).

DESIGN_SYSTEM_COMPLIANCE: PARTIAL
UX_ACCESSIBILITY_SCORE: PARTIAL
IMPLEMENTATION_FEASIBILITY: MEDIUM

DISCOVERIES:
  - DESIGN_DISCOVERY (persisted, D-35): A TARGET-EXISTENCE CHECK CANNOT SEE A FALSE CLAIM ABOUT A TARGET.
    The rev-6 reviewer enumerated every § R.1 target, found them all present, and confirmed a row that lies.
    Executable rule: cross-references are audited by EXTRACTION against a live heading inventory, never by
    reading. This found 45 sites where reading found 2.
  - DESIGN_DISCOVERY (persisted, D-36): A REVISION THAT INTRODUCES A COLLIDING HEADING POISONS ITS OWN
    CITATIONS. Rev 6 created `## R.11g` (no numbered items) and `## 10.1-h`, then cited the bare names 33
    times, every one landing where the named item does not exist. Rules R1/R2.
  - PROJECT_FACT (persisted, D-37): A FALSIFIER AN ARTIFACT FAILS IS WORSE THAN NO FALSIFIER — it teaches a
    reviewer that the row's own test is not worth running. Every falsifier here is executed against the
    artifact before publication.
  - PROJECT_FACT (persisted, D-38): A RECORD-CORRECTION NOTE IS ONLY AS BYTE-ACCURATE AS THE BLOCK THAT
    PRODUCED IT. The em-dash defect's origin is the design side's paste-ready block; reviewing the decision
    object alone would find the symptom and miss the cause.
  - CONTRADICTION (escalated, not persisted): ADR 0018 says four accepted risks; the owner's retirement is
    recorded only in the decision objects. G-21. Governance-touching, PROHIBITED path.
  - CONTRADICTION (escalated, not persisted): 27ea6536:120 contradicts its own :15-17. G-19 R-2.
  - PROJECT_FACT (persisted, D-39): THE BASENAME GLOB RETURNS ANOTHER LANE'S ANSWER.
    '*design-revision-3.md' returns two commits, both another lane's file. Full paths, always.
  - WORKFLOW_IMPROVEMENT (routed, D-40): F-16 is the second merge precondition refused in this worktree; the
    hash-compare-then-MOVE-then-re-compare recovery is the reusable part, and moving rather than deleting is
    what made it safe.
  - AUTOMATION_OPPORTUNITY (reported): the cross-reference audit is mechanical and could fail a build on an
    unresolved §-token — the check that found 45 sites where reading found 2.
  - PROJECT_FACT (persisted): A CLOSED GAP MUST NEVER LAUNDER AN OPEN ONE. Retiring A1 closed resurrection
    and left the revocation half open and never accepted; both facts are now recorded in one place, without
    inventing a fourth register entry for a gap 79e860e2 already owns.

KNOWLEDGE_PERSISTED:
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/discoveries.md — D-35..D-40 added:
    (D-35) target-existence checks are blind to false claims, (D-36) heading collisions poison citations,
    (D-37) falsifiers must pass before publication, (D-38) a supplied block's byte accuracy is the
    producing lane's, (D-39) the basename glob trap, (D-40) F-16 and the move-then-re-compare recovery.
    Plus a "Not persisted — Revision 7" table. D-1..D-34 unchanged in substance. CONTRADICTION-class items
    are REPORTED, not persisted, per LEARNING_POLICY.md.
  - Nothing outside OWNED_PATHS. No board. No .decisions/**. No docs/adr/**. No production source.

BLOCKERS:
  - NONE in the design content. All 8 rev-6 findings are APPLIED.
  - Registered, owned by others, and NOT resolved by this lane:
      * G-18 — the four-board edit. THE OWNERSHIP GRANT EXISTS; THE EXECUTION DOES NOT. A grant is not an
        execution. THE WORK ITEM MUST NOT CLOSE OVER THIS UNTIL THE BOARD EDIT IS DONE AND REVIEWED. The
        blocker changed form: Penpot is dormant (plugin tab suspended, getPages() returns a heartbeat error).
      * G-19 — two residual record items on .decisions/27ea6536, specified ready to apply (§ 7-j.1).
      * G-21 — ADR 0018's accepted-risk section still says four. Already specified by the ADR lane and
        uncommitted there too.
      * G-22 — two supersession banners so the committed false text has a redirect (§ 7).
      * G-23 — BPM's state must be ESTABLISHED by the granted lane before it edits BPM.
  - Penpot remains unreachable from every lane; the mechanism changed and is recorded. NOT verified by me.
  - F-16 recovered with no content loss; no file genuinely differed from main.
  - This revision is NOT self-approved.

READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES
```

**What the reviewer should check hardest, in order:** (1) **§ R.11g-j § A — run the extraction**; if it finds
nothing outside that table, this revision is wrong. (2) **Every falsifier in `traceability-matrix-7.md` § 2 was
executed against the artifact before publication**, especially the amended `L-R5-1` one. (3) **The four-risk
correction says THREE and the ADR says FOUR** — both stated, neither smoothed, the disagreement is `G-21`,
A1's retirement attributed to **the owner**, and the revocation half **not** presented as discharged. (4)
**`G-18`: grant decided, obligation open, blocker changed form; the work item must not close over it**, and
`G-23` must stop `BPM` being read as an authorised footer edit. (5) **`G-22` — the committed false text and
the redirect that does not exist**: check that not editing Revision 6 was right *and* that its cost is
recorded. (6) **The register counts 15/16 → 18/19 → 21/22.** (7) **`report-revision-7.md` § 1.1 is
numbered** — the seven unnumbered-`§` sites are why, and rule `R5` is the generalisation.

---

*Design Agent (design-agent). No design artifact was modified outside `OWNED_PATHS`. No commit, no push.
**No Docker or Compose command of any kind was run**, and compose files were not read. **No Penpot tool was
called and no board was read or touched.** `.decisions/**` and `docs/adr/**` were read-only; nothing was
written to either. Full report persisted at
`docs/engineering/dispatch/tasks/design-correct-addproduct-keys-7/report.md`.*