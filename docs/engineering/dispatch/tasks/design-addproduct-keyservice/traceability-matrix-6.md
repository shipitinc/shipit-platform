# Traceability Matrix — Design Revision 6 (`design-addproduct-keyservice`)

**REVISION_ID** `d26658219dea4955b0d2b4004a70aa4d` · **Base / HEAD** `1c3f5ad` ·
**Supersedes** `7C1E4A96-2B58-4D3F-A0C7-5E19D28B4F63` (Revision 5, retained byte-identical, **committed on
`main` at `16cd497`**) · **Risk level** **3**
**Author**: `design-agent`. **This lane does not approve its own work.** No approval of any kind stands
behind Revisions 1–6.

> **The matrix's own scope, stated first so it is not over-read.** Revision 6 is a **precision correction
> pass**. § 1 below is therefore **not** a fresh 74-row requirement map — that map is
> `traceability-matrix-5.md` (248 lines), which stands **unmodified and incorporated by reference**. What § 1
> adds is the three new rows Revision 6 creates and the one requirement whose disposition **changes**. § 2 is
> the **Rev-5 review finding → correction map** — the deliverable that does not exist anywhere for this
> review cycle. § 3 is the register-agreement check. § 4 is what was not reviewed.

---

## 1. Requirement → section → test → gap

### 1a. Carried from `traceability-matrix-5.md` — incorporated unchanged

`traceability-matrix-5.md` carries the full 74-row map for the design content: rows 1–71 for Revision 5's
content and rows 72–74 for the three things Revision 5 added (`★ row 72` the ownership step 3a, `★ row 73`
`rotateCredential`'s `credentialId` as a caller parameter, `★ row 74` `G-17`).

**Every row is carried unchanged.** **No requirement's disposition was weakened by this pass, and none was
strengthened either** — that is the honest summary of a correction that changed no design content. **The
Rev-5 reviewer independently confirmed** that § R.18.2 and `requirements_gaps` agreed, that `G-16` and `G-17`
were in **both** registers, and that § 10.2 item 12 passed on that check.

### 1b. ★ The one row whose disposition changes

| # | Requirement | Sections | Gate / test | Gap | Disposition |
|---|---|---|---|---|---|
| **★ 75** | **`R-UX2` — the boards must match the code *and* the code must match the boards** (human: *"Stay true to both designs in Penpot and in code"*) | **`§ R.11g-h`** (item 7 amended), **`§ R.18.2-h`** (`G-18`), **`§ 10.1` item 12** | **No test — this is a conformance obligation on four boards, and it cannot be test-automated** | **`G-18`** | **★ PARTIALLY COVERED — and this row is what `B-R5-1` was about.** The **code** side is fully specified: § R.11g item 7's **three code edits** (`_buildFooter` def `:375` / call `:314` / copy `:383-384`; desktop `note:` `:317-319`; mobile `note:` `:926-928`). The **board** side was **not specified at all by Revision 5** — no requirement, no gap entry, no action — and is now: `G-18` states the required edit, § R.11g-h states it in the consumption contract, § 10.1 item 12 assigns the owner. **The requirement is now COVERED; the OBLIGATION is UNOWNED and BLOCKED.** **Coverage and completion are different claims and only the first is true here.** |

**Why `G-18` is in `requirements_gaps` rather than dismissed as out-of-scope.** Revision 5's § R.18.2 closed
with a paragraph placing *"the Penpot boards and the mobile/desktop footer layout itself (`C-11`)"* outside
this lane. **That paragraph was half right and its error is the blocker**: not authoring a board is out of
scope, but **specifying what a board must contain, and recording that nobody owns the edit, is not** — and
the second is what was missing. A design that says *"no board is edited here"* and stops has not discharged a
requirement whose text is *"stay true to both designs."* `G-18` is the discharge.

### 1c. ★ The three new rows

| # | Element | Section | Traces to | Gap | Status |
|---|---|---|---|---|---|
| **★ 76** | **`G-19` — `27ea6536`'s record carries a demonstrably false factual claim** | **`§ 6`** (the exact record fix) | **`27ea6536`'s own `supersedes_design_lane_reading` and `follow_up_action` #3** | **`G-19`** | **REGISTERED, NOT WRITTEN.** `.decisions/**` is `PROHIBITED_PATHS`. **Nothing was written there and no such edit is claimed.** The fix is specified ready-to-apply. **Owner: Manager / decision owner.** |
| **★ 77** | **`G-20` — this lane's own supersession chain is not on disk** | **`§ 0.3.2`, `§ 0.3.3`, `§ 0.5`** | **This lane's pre-flight, four independent checks** | **`G-20`** | **REGISTERED.** 11 tracked files uncommitted; Revision 3's four artifacts **never added on any ref**. **Not this lane's to commit** (`COMMITTED: NO`) |
| **★ 78** | **`G-20(b)` — `human_correction_verbatim` is quoted beside the real board names, and the two differ** | **`§ R.11g-h`, `§ R.18.2-h`** | **`27ea6536:113-118`** vs `penpot-board-evidence.md:396-403` | **`G-20`** | **REGISTERED as a rider on `G-20`, not split out.** **The practice is correct** — a human's quoted words are not a file's names — but a reader holding only one is misled by whichever they have |

### 1d. `traceability.design_elements_without_a_requirement` — three entries

Recorded per `LEARNING_POLICY.md` and the metadata's own convention, so these cannot be mistaken for
traceable requirements when they are not:

| Element | Why it has no requirement | Recorded because |
|---|---|---|
| **`G-18`'s required four-board edit** | It **does** trace to a decided requirement — `27ea6536`'s *"No footer copy"* clause. What it lacks is an **OWNERSHIP grant**, and there is none. | So it does not read as an untraceable design choice. It is a decided requirement with no owner |
| **`G-19`, `G-20`** | Neither is a design element. Both are **record-integrity gaps**. | A decision record that denies a measured fact, and a chain whose supersession is uncommitted, both leave a reader unable to establish what is true. Named explicitly so they are not read as scope creep |
| **`§ R.11g-i`'s restatement of the three corrected `L8` numbers** | A **consumption aid**. It restates § R.11g item 7 and adds no normative content | It exists because the sibling lane is **blocked on Penpot and cannot ask** — so restating the numbers is the only way the correction can reach it |

---

## 2. Rev-5 review finding → correction

**`REVIEWED_HEAD 289f1d3`** · `RESULT: DESIGN_REVIEW_CHANGES_REQUIRED` ·
**BLOCKERS B-R5-1 · HIGH none · MEDIUM M-R5-1…M-R5-4 · LOW L-R5-1…L-R5-3** ·
`TRACEABILITY_GAPS: none — every design element maps to a requirement, a resolved decision, a named
architecture clause or an artifact at 5436a4d. § R.18.2 and requirements_gaps agree, including G-16 and
G-17 in both registers. The defect is not traceability but the ABSENCE of one register entry.`

**Eight findings. Each row names where it lands and what a reviewer should check to falsify it.**

| Finding | Class | Where it is corrected in Revision 6 | Falsifier — what would show this row is wrong |
|---|---|---|---|
| **`B-R5-1`** part 1 | **BLOCKER** | **`G-18` in § R.18.2-h AND in `requirements_gaps`** — identical id, summary and owner | `grep` either register for `G-18` and find it in only one. **Or** find a substantive divergence between the two copies |
| **`B-R5-1`** part 2 | **BLOCKER** | **§ 10.1 item 12** — design-system owner, per `27ea6536`'s own OPTION_B; both blocks named (no board ownership; Penpot binding down) | Find § 10.1 and no item 12. **Or** find item 12 naming an owner `27ea6536` did not name, **or** find it framed as a human question — **it must not be one** |
| **`B-R5-1`** part 3 | **BLOCKER** | **§ R.11g-h** — *"the boards are authoritative"* **scoped** (true of divider and alignment, **false of the copy line**); the change list is **four** edits with an owner each | Find the unconditional sentence still standing in § R.11g-h, **or** find a change list of **three** |
| **`B-R5-1`** part 4 | **BLOCKER** | **`G-19`** registered; the exact record fix specified in **§ 6** | Find `G-19` absent from both registers — **or** find that § 6 asks to re-open the decision, which it must not |
| **`M-R5-1`** | MEDIUM | **§ 0.4's `L8` row is gone.** Its content is carried in § 0.4 and § R.11g-i, agreeing with `design-revision-5.md:2414` | Find `:925` described as the **desktop** site, **or** as having **no** `note:`. **The mobile site EXISTS at `:926-928`.** Also: Revision 4's `_buildFooter` numbers `:375`/`:314` were **correct** — if this row says otherwise, it has repeated the error it corrects |
| **`M-R5-2`** | MEDIUM | **§ 0.4's `M5` row is gone**; the full sweep is **§ 0.4.1** | Find *"uncommitted and unmerged"* attributed to this base — **it is committed and landed at `5436a4d`**. **Or** find a § 10.1 action still asking for the merge that **was withdrawn** and replaced by **1a/1b**. **Or** find a § 0.4 row that was not swept — § 0.4.1 states the sweep's result and its **limit** |
| **`M-R5-3`** | MEDIUM | **The count is 19 findings and 5 MEDIUM** — § 0.4, § 0.1, the metadata changelog, and this row | Add up the Rev-4 report's own `RESULT:` block: `MEDIUM: M3, M4, M5, M6, M7` is **five**; 2 + 3 + 5 + 9 = **19**. **The rev-4 report's own MEDIUM line is the source of this correction** |
| **`M-R5-4`** | MEDIUM | **§ 0.5** — the reconciliation **performed and recorded**; `blockers[]` `PROVENANCE_GAP` **CLOSED**; residue as **`G-20`** | `git log --oneline --diff-filter=A -- .../design-review-addproduct-keys-rev4/report.md` returns nothing → § 0.5's central claim is false. **It returns `289f1d3`, whose subject line says it persisted the report.** Also: if `G-20` is missing, the closure buried a residue |
| **`L-R5-1`** | LOW | **`report-revision-6.md` prints the metadata's own blob hash**; **every `artifacts[]` entry carries a real `blob_hash`**; `V-2`'s falsifier restated | `rg "bae3c019"`-style search for the metadata's own hash finds nothing in the report — **it is printed there**. **Or** find an `artifacts[]` entry whose `blob_hash` is a pointer string rather than a hash |
| **`L-R5-2`** | LOW | **§ 0.6** — recorded for the Manager's ledger. **No artifact correction needed** | `git merge-base --is-ancestor 5436a4d 289f1d3` returns non-zero → § 0.6's claim is false. **It succeeds, and `5436a4d` is `289f1d3`'s direct parent.** Revision 5's re-base story is **better** than the dispatch's |
| **`L-R5-3`** | LOW | **§ R.11g-h** — real board names with `·` and `· Light/Dark`; **`SM` named** as two states of one mobile design already satisfying the mobile spec | Find a hyphenated or suffix-less board name in § R.11g-h, **or** find `SM` still absent. **Also: there must be NO mobile board edit requested** — the mobile spec is met |

### 2a. What this lane explicitly did **not** re-derive, and why that is not a gap

The reviewer's `SAFE_PARALLEL_WORK` list is carried unchanged, and with it the following, **each confirmed by
the reviewer against source and therefore not re-argued here**:

| Confirmed by the reviewer | This lane's action |
|---|---|
| **B5 / the ADR acceptance is real and cited accurately**; amendment revision 2's metadata fields exact; **no surviving bare "Accepted"** | **Carried unchanged.** § 0.2 incorporated by reference. **Re-verification would have re-litigated settled ground** |
| **Revision 5's self-downgrade to 0 IMPROVED / 2 UNCHANGED / 4 WORSE is honest** | **Carried verbatim**, character for character. **No reason moves in this pass** |
| **`G-17` is real** — `876c6b97` landed in the same commit (`5436a4d`) that wrote ADR 0018's denial | **Carried unchanged**, unedited. `docs/adr/**` is `PROHIBITED_PATHS`. **`G-19` is registered as its SIBLING, not as a correction of it** — `G-17` is right |
| **`D-3`: three edits, not two** — desktop `note:` `:317-319`, mobile `note:` `:926-928`, `_buildFooter` `:375` | **Carried.** Revision 5's body is right; **only its § 0.4 map was wrong** |
| **`design_primitives.dart:396`** paints `ContentRule` unconditionally; `:402-410` renders `Row[Expanded(note ?? SizedBox.shrink()), InlineLink]` → **the desktop spec falls out of `note: null` for free; mobile's is genuinely NOT expressible today** | **Carried unchanged.** **This lane re-read both files at `1c3f5ad` and confirmed both citations still resolve** — which is a **citation check**, not a re-argument (§ 7.1 `V-1`) |
| **Risk 3**, independently re-derived, agreement YES | **Re-affirmed** on this revision's own content (§ 2.2) |

### 2b. The one item the reviewer added that a matrix must record

**The Rev-5 reviewer found nothing wrong with the design's content about the key flow** — and it found
~25 `file:line` citations across five source files, **every one resolving exactly**. Revision 6 therefore
records this as a **row, not as an absence of rows**: the design content passed, the coupling did not. **A
correction pass that reported nothing about content would look like a pass on content; it was not one.**

---

## 3. Register agreement — `§ R.18.2-h` vs `requirements_gaps`

The Rev-5 reviewer's `TRACEABILITY_GAPS: none` verdict covered Revision 5's registers. **This is the same
check against Revision 6's additions**, and it is the check `B-R5-1` part 1 is really about — the defect was
**the absence of one entry in both**, not a disagreement between them.

| Entry | `§ R.18.2-h` | `requirements_gaps` | Agree? |
|---|---|---|---|
| `G-3` … `G-17`, `L-6`, `ADR 0018 :103 wording` | **Incorporated by reference** to `design-revision-5.md` § R.18.2 — 19 rows, unchanged | **Incorporated by reference** to `design-revision-metadata-5.yaml` — unchanged | **Yes.** No row weakened, removed or re-owned |
| **`G-18`** | ✔ row present | ✔ entry present | **Yes** — identical id, summary and owner. **Owner: design-system owner, via § 10.1 item 12** |
| **`G-19`** | ✔ row present | ✔ entry present | **Yes** — **Owner: Manager / decision owner.** `.decisions/**` not written |
| **`G-20`** | ✔ row present | ✔ entry present | **Yes** — **Owner: Manager** |
| *"the Rev-4 review report"* | n/a — **closed**, § 0.5 | ✔ entry present, marked **`CLOSED`** | **Yes.** § 0.5 carries the closure; this entry carries the residue as `G-20` so neither is lost |

**Row counts.** `§ R.18.2` **19 → 22 rows**. `requirements_gaps` **19 → 22 entries** plus the closed
provenance entry. **Both counts move together, which is the property the finding was about.**

---

## 4. What this matrix does **not** review, stated explicitly

- **It does not re-review the design content of `docs/adr/0018-per-product-git-credentials.md`** or of the
  amendment. Those are `PROHIBITED_PATHS` here. `G-17` is carried **unedited and unclaimed**.
- **It does not adjudicate the four desktop boards as a design.** It records the **measurement** two
  independent reviewers made. **This lane read no board, ran no Penpot tool, and holds no board ownership.**
- **It does not review the sibling mobile lane's `D-8` claim** that `SM` and `BPM` are two states of one
  design. It is recorded as **source of a measurement, not as authority** (§ R.11g-h).
- **It does not re-verify § 0.3's 22-row citation index** of Revision 5, nor every `file:line` in Revision
  5's § 0.4. **§ 0.4's sweep was against Revision 5's SECTIONS, not against every citation** — and
  `design-revision-6.md` § 0.4.1 states that limit rather than implying full re-derivation. **Only Revision 6's
  own citations were re-read at `1c3f5ad`** (§ 7.1 `V-1`).
- **It does not review `AGENTS.md` §13's restoration** or any governance text outside this lane's directory.
- **It ran no gate.** No analyzer, no build, no test, no contrast measurement, no integration run.
  **Every `NOT_RUN` remains `NOT_RUN`.**
- **It ran no Docker or Compose command of any kind** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has already lost its QA database** to a lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`. **The rule was not tested, because testing
  it is the forbidden act.** Compose files were **not read**.