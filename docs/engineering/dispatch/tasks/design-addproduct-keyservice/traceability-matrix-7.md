# Traceability Matrix — Design Revision 7 (`design-addproduct-keyservice`)

**REVISION_ID** `3877696f-c15d-4ea8-9941-898fa601bf44` (a UUIDv4 minted by this lane; **not** an approval) ·
**Base / HEAD** `14b0267` ·
**Supersedes** `d26658219dea4955b0d2b4004a70aa4d` (Revision 6, retained byte-identical, **committed on
`main` at `af8e30f`**) · **Risk level** **3**
**Author**: `design-agent`. **This lane does not approve its own work.** No approval of any kind stands
behind Revisions 1–7.

> **The matrix's own scope, stated first so it is not over-read.** Revision 7 is a **precision correction
> pass**. § 1 below is **not** a fresh requirement map — that map is `traceability-matrix-5.md` (248 lines),
> which stands **unmodified and incorporated by reference**, and this pass **adds no requirement and changes
> no requirement's disposition in substance.** § 2 is the **rev-6 re-review finding → correction map**. § 3 is
> the register-agreement check, with its counts **re-derived from the live documents** because Revision 6's
> were wrong in both registers. § 4 is what was not reviewed.

---

## 1. Requirement → section → test → gap

### 1a. Carried from `traceability-matrix-5.md` — incorporated unchanged

`traceability-matrix-5.md` carries the full 74-row map for the design content: rows 1–71 for Revision 5's
content and rows 72–74 for the three things Revision 5 added. **Every row is carried unchanged, and this
pass adds no requirement row.**

**No requirement's disposition was weakened by this pass, and none was strengthened either** — that is the
honest summary of a correction that changed no design content. The one exception is `R-UX2`, whose
*operational* state moved (an ownership grant was issued), and it is recorded in § 1b in the matrix's own
words rather than by reusing Revision 6's, which described a base that has moved on.

### 1b. The one row whose operational state moved

| # | Requirement | Sections | Gate / test | Gap | Disposition |
|---|---|---|---|---|---|
| **★ 75** | **`R-UX2` — the boards must match the code *and* the code must match the boards** (human: *"Stay true to both designs in Penpot and in code"*) | **Revision 7 § 10.1-j** item 12 · **Revision 6 § R.11g-h** · **Revision 7 § R.18.2-j** (`G-18`, `G-23`) | **No test — this is a conformance obligation on boards, and it cannot be test-automated** | **`G-18`** (+ `G-23`) | **★ STILL PARTIALLY COVERED, AND THE STATUS HAS MOVED — THE WORDS BELOW ARE NOT REVISION 6'S.** Revision 6 recorded *"the requirement is now COVERED; the OBLIGATION is UNOWNED and BLOCKED."* **That was true at `1c3f5ad`.** **At `14b0267` the board side has an OWNER — the human has GRANTED board ownership to a scoped design-system lane — and the edit has NOT been done.** So the obligation is now **OWNED and EXECUTED-PENDING**, blocked on Penpot's dormancy rather than on ownership. **The code side is unchanged and fully specified:** Revision 6 § R.11g-h's three code edits (`_buildFooter` def `:375` / call `:314` / copy `:383-384`; desktop `note:` `:317-319`; mobile `note:` `:926-928`). **Coverage and completion are different claims and only the first is true here. A GRANT IS NOT AN EXECUTION, and the work item must not close over `G-18` until the board edit is done and reviewed.** **`G-23` records that the grant also covers `BPM`, which no measurement supports as needing a footer edit.** |

### 1c. ★ The three new rows

| # | Element | Section | Traces to | Gap | Status |
|---|---|---|---|---|---|
| **★ 76** | **`G-21` — ADR 0018's own body still records four accepted risks after the owner retired one** | **Revision 7 § 7-j.2** · `blockers[]` | **`876c6b97`'s second scope note at `14b0267`: *"THREE are now recorded (A2, A3, A4)"*** — against the ADR's own `:453` `ACCEPTED` heading and five "four" statements | **`G-21`** | **REGISTERED, NOT WRITTEN.** `docs/adr/**` is `PROHIBITED_PATHS`; **nothing was written and no such edit is claimed.** The edit is **already specified** by the ADR lane (`design-adr-0018-amendment/design-revision-5.md` § 4) and is **uncommitted there too**. **Owner: ADR lane + Manager.** |
| **★ 77** | **`G-22` — Revision 6's false and mis-resolving text is committed, and this correction does not travel with the file** | **Revision 7 § R.11g-j § A** · `report-revision-7.md` § 7 (banner texts) | **This lane's own audit (`V-2`): 45 sites, 7 targets, 8 false-claim sites — all on `main` at `af8e30f`** | **`G-22`** | **REGISTERED.** The artifacts are **retained byte-identical on purpose**; the redirect is missing, not the correction. **Not this lane's to commit.** **Owner: Manager** |
| **★ 78** | **`G-23` — the board-ownership grant is broader than `G-18`'s measured obligation** | **Revision 7 § R.18.2-j** · § 10.1-j item 12 | **The Manager's report of the human's grant, against `penpot-board-evidence.md` § 6.3/§ 6.4 and Revision 6 § R.11g-h amendment 2** (BPM already satisfied) and `WORK_STATE.md:639` (BPM's *other* defects) | **`G-23`** | **REGISTERED. NOT MEASURED BY THIS LANE — no Penpot tool was called and no board was read.** Whether BPM carries a `Footer` layer is **UNVERIFIED IN BOTH DIRECTIONS** and is the granted lane's to establish. **Owner: granted design-system lane + Manager** |

### 1d. ⚠ Accepted-risk count — **THREE**, and the ADR still says four

**Recorded here so a reviewer reading only this matrix gets the number.**

**`A2`, `A3`, `A4`.** Accepted risk **`A1`** (resurrection of a revoked credential by a re-mint) was
**retired by the repository owner on 2026-10-07**, after `08c7590` made the mint insert-only on both tiers.
**Verified against the shipped source, not adopted** — `postgres_product_registry_store.dart:190-191`,
`in_memory_product_registry_store.dart:167-169,184`, `product_registry_engine.dart:933-936`. **Two prior
lanes were right to decline to make that call**: `876c6b97`'s first scope note says *"RETIRING IT IS THE
OWNER'S CALL"*, and a design lane may not retire an accepted risk.

| "A1" | State — **do not conflate** |
|---|---|
| Accepted risk `A1` | **RETIRED 2026-10-07** |
| **Amendment** `A1` — *"Scope is the repository, not the product"* (ADR `:35`) | **LIVE**, and live **in the code today** at `product_registry_store.dart:47` and `:52-53` |
| **Substrate option** `A1` — filesystem `0600` | **LIVE** — ADR `:107`, `:442` |

**ADR 0018's own body still records four** (`grep -c 'Consequence accepted'` → **`4`**; `:453` still
`ACCEPTED`; `:448-451`, `:527`, `:557`, `:574` all say four). **That disagreement is `G-21`**, owned by the
ADR lane + Manager, and `docs/adr/**` is `PROHIBITED_PATHS` — **nothing was written there.**

**Retiring `A1` discharged the resurrection half only.** `grep` for handle-destroying calls across
`apps`/`packages` → **0 matches**, so **revocation remains one-sided in practice**, and **that half was
never an accepted risk** (`design-revision-7.md` § R.6-j).

### 1e. `traceability.design_elements_without_a_requirement` — six entries

Recorded per `LEARNING_POLICY.md` and the metadata's own convention, so these cannot be mistaken for
traceable requirements when they are not:

| Element | Why it has no requirement | Recorded because |
|---|---|---|
| **`G-18`'s required four-board edit** | It **does** trace to a decided requirement — `27ea6536`'s *"No footer copy"* clause. What it lacks is **not** an ownership grant any more; **the grant exists.** What it lacks is the **EXECUTION** | So it does not read as an untraceable design choice, and so a reader does not mistake a *grant* for a *discharge* |
| **`G-19`'s two residual items** | Neither is a design element. Both are **record-integrity** defects in the same authoritative object `G-19` already covers | They extend `G-19` rather than becoming two new entries, because a register that duplicates is a register that has stopped being an index |
| **`G-21`, `G-22`** | Neither is a design element. Both are **record-integrity** gaps: an ADR that says four where the owner retired one, and a committed revision whose false text has no redirect | Named explicitly so a reviewer does not read them as scope creep |
| **`G-23`** | A **scope-precision** entry, not a design element: a permission and an obligation do not coincide | Named so the granted lane is not handed an obligation nobody measured |
| **Revision 7 § R.11g-j's five citation rules** | A **process rule / consumption aid**, not a requirement. They add no normative product content | They exist because the class they close **recurred inside the artifact built to close it**, and because a *reading* cannot detect it — only an *extraction* can |
| **Revision 7 § R.6-j** | An **annotation** on an incorporated requirement, not a new one | Revision 5 § R.6 is incorporated unchanged; § R.6-j records which of its two halves now has a status, because this is the revision that records A1's retirement |

---

## 2. rev-6 re-review finding → correction

**`REVIEWED_HEAD af8e30f`** · `RESULT: DESIGN_REVIEW_CHANGES_REQUIRED` ·
**BLOCKERS: none · HIGH: H-1, H-2, H-3 · MEDIUM: M-1 · LOW: LOW-1…LOW-4** ·
`CORRECTION_REQUIRED: YES` · `HUMAN_DECISION_REQUIRED: NO` · `INDEPENDENT_RISK_LEVEL: 3`

**Eight findings. Each row names where it lands and what a reviewer should check to falsify it — and every
falsifier below was checked against the artifact before being published.** Revision 6's matrix published one
that its own artifact satisfied (`L-R5-1`); **a falsifier an artifact fails is worse than no falsifier**,
because it teaches a reviewer that the row's own test is not worth running.

| Finding | Class | Where it is corrected in Revision 7 | Falsifier — what would show this row is wrong |
|---|---|---|---|
| **`H-1`** | **HIGH** | **§ R.1-j** (the incorporation row corrected: § 10.2 carried **unchanged by reference**, not "with § 10.2-h") and **§ R.11g-j** (five rules + the full audit at § A) | Run the extraction: every `§`-token in all four Revision-6 artifacts, resolved against live heading inventories. **If it finds no target outside Revision 7 § R.11g-j § A, this row is wrong.** It finds **7 targets / 45 sites**, and § A is that result. **Or** find `design-revision-6.md:277` / `metadata-6.yaml:352` still naming `§ 10.2-h` as a section that restates items 10 and 12 |
| **`H-2`** | **HIGH** | **The pins are not re-fixed.** The **claim** is restated at all eight sites that make it (metadata-7 `provenance.content_pins.note`, `artifacts[]`, `changelog`; body § R.11g-j § B); `metadata-6.yaml:470`'s "two self-excluded" is corrected to **four** | ★ **THE AMENDED FALSIFIER — it replaces one this artifact previously satisfied.** Find an `artifacts[]` entry whose `blob_hash` is a pointer string **whose hash is not printed in `report-revision-7.md` § 1.1**, **excluding** the entry for `report-revision-7.md` itself, which no artifact can carry. **If you find one, this row is wrong.** *The previous falsifier — "find an `artifacts[]` entry whose `blob_hash` is a pointer string rather than a hash" — was satisfied by four entries and was withdrawn because it tested a property the artifact cannot have.* **EXECUTED BEFORE PUBLICATION: 17 `artifacts[]` entries parsed — 8 real hashes (all verified against `git hash-object` on the files), 2 pointers (both resolve to a printed hash), 2 self-exclusions (both the permitted kind), 5 entries with no `blob_hash` key at all.** Those 5 are **outside this falsifier's scope** and are named here so the scope is not read as coverage: `design-revision-3.md`, `design-revision-2.md`, `design-revision.md`, `design-revision-4.md`, `discoveries.md`. Also: `git hash-object report-revision-7.md` is the stated recovery for the one irreducible limit |
| **`H-3`** | **HIGH** | **§ 0.5** — counted from the live documents: Revision 5 **15 rows / 16 entries**; Revision 6 **18 / 19**; **Revision 7 = 21 rows / 22 entries**. Also § R.1-j, `requirements_gaps`' header comment, and the changelog | Count Revision 5 § R.18.2's body rows directly — **15**, not 19. Count Revision 5 `requirements_gaps` — **16**, not 19. **Or** find Revision 7 publishing a different pair than **21 / 22**. **Note the direction Revision 6 got wrong: it OVER-reported its own size, which is the safer error and still means the register could not be counted by the party publishing it** |
| **`M-1`** | **MEDIUM** | **§ 0.4.1** — the enumeration now lists **16** names and `L13` appears only in the bullet that reports its error | Count the names in § 0.4.1's first bullet — **16**, and `L13` is **not** among them. Coverage: **16 + `L8` + `M5` + `L13` = 19** |
| **`LOW-1`** | **LOW** | **The cause, not the effect.** `design-revision-6.md:523` (the paste-ready block) and `metadata-6.yaml:360` carried a hyphen; Revision 7 carries an **em dash** and **§ 7-j.1** re-supplies the corrected block for the Manager | Read `add_product_page.dart:383-384` — `\u2014`, an em dash. **Or** find a hyphen-normalised rendering of that string in any Revision-7 artifact. **The `.decisions/**` copy is not this lane's** and is specified, not written |
| **`LOW-2`** | **LOW** | **`G-19` residual item R-2**, with `27ea6536:120` against its own `:15-17`, and **§ 7-j.1**'s append-only text | Find `:120` asserting the mobile boards *"carry a copy plus a disclosure"* and `:15-17` asserting *"no bottom copy at all"* **in the same object** — they do. **Or** find `G-19` in Revision 7's registers **without** the third statement |
| **`LOW-3`** | **LOW** | **§ 0.6** — `G-20` **CLOSED, DISCHARGED at `af8e30f`**, re-verified at `14b0267`; `blockers[]` carries the status | `git log --all --oneline --diff-filter=A -- <FULL PATH>/design-revision-3.md` returns nothing → § 0.6 is false. **It returns `af8e30f`.** **Use the full path, never a basename glob** — a basename glob returns two *other lanes'* commits |
| **`LOW-4`** | **LOW** | **Not fixed on Revision 5, and generalised: `G-22`**, with both banner texts specified at `report-revision-7.md` § 7 | `grep -c 'Revision 6\|Revision 7' design-revision-5.md` returns non-zero → Revision 5 *does* carry a forward pointer. **It returns 0 at `14b0267`.** **Or** find `G-22` missing from both registers |

### 2a. What this lane explicitly did **not** re-derive, and why that is not a gap

The rev-6 reviewer's confirmed findings are carried unchanged. Re-verification would have re-litigated
settled ground:

| Confirmed by the rev-6 reviewer | This lane's action |
|---|---|
| **`B-R5-1`'s four parts all applied** — `G-18` in **both** registers; § 10.1 item 12 naming the owner `27ea6536` itself named; the scoped § R.11g-h rule with a **four**-edit owner table; `G-19` registered with the writing lane touching nothing | **Carried unchanged.** Re-verified by *reference existence* only (§ 0.4.1). **None re-argued** |
| **The pin loop IS fixed and byte-exact** | **Carried unchanged. THE PINS ARE NOT RE-FIXED.** Only the *claim* is corrected (`H-2`) |
| **§ 0.4's sweep arithmetic is sound and the third error is genuine** — Revision 5's `content_pins` carries 3 real hashes + 1 `SELF-EXCLUDED`, the unpinned file holding `risk_level`/`gates`/`requirements_gaps`/changelog | **Carried unchanged** (§ 0.2) |
| **`G-20` verified strongly** — Revision 3 never added before `af8e30f`; blob `1364727434…`, 137 494 bytes; `2838` checks out | **Carried, and discharged** (`LOW-3`) |
| **`5436a4d` is `289f1d3`'s direct parent** | **Carried unchanged.** Revision 6 § 0.6 stands |
| **The `G-19` note the Manager applied is SOUND, including its framing** — the object's recorded recommendation was `OPTION_A` "keep desktop copy", so *"the conclusion — that the copy stays"* is exact; `27ea6536` is `type: DESIGN` with the owner as authority | **Carried unchanged. NO MISREPRESENTATION IS ALLEGED.** The two residual items are a different matter and are registered as such |
| **`G-18`'s coverage/completion distinction is HONEST, not convenient** | **Carried, and relied upon** in § 1b and § 8 |

### 2b. The one thing a matrix must record that is not a row

**The rev-6 reviewer found nothing wrong with the design's content about the key flow — and it found
fifteen file:line citations across six documents, every one resolving.** Revision 7 therefore records this
as a row's premise rather than as an absence of rows: the design content passed; the **self-description**
did not. **A correction pass that reported nothing about content would look like a pass on content; it was
not one.**

---

## 3. Register agreement — Revision 7 § R.18.2-j vs `requirements_gaps`

The rev-6 reviewer's `TRACEABILITY_GAPS: none` verdict covered Revision 5's registers. **This is the same
check against Revision 7's additions** — the check `B-R5-1` part 1 is really about.

| Entry | Revision 7 § R.18.2-j | `requirements_gaps` | Agree? |
|---|---|---|---|
| Revision 5 § R.18.2's rows (`G-3`…`G-17`, `L-6`, `ADR 0018 :103 wording`) and Revision 6 § R.18.2-h's (`G-18`, `G-19`, `G-20`) | **Incorporated by reference** — unchanged | **Incorporated by reference** — unchanged | **Yes.** No row weakened, removed or re-owned |
| **`G-21`** | ✔ row present | ✔ entry present | **Yes** — identical id, summary and owner. **Owner: ADR lane + Manager** |
| **`G-22`** | ✔ row present | ✔ entry present | **Yes** — **Owner: Manager** |
| **`G-23`** | ✔ row present | ✔ entry present | **Yes** — **Owner: granted design-system lane + Manager** |
| *"the Rev-4 review report"* | n/a — **closed**, carried in Revision 6 § 0.5 | ✔ entry carried, marked **`CLOSED`** | **Yes.** The closure carries no residue, because `G-20` carried it separately — and `G-20` is now itself closed |

**Row counts, re-derived from the live documents — NOT copied from Revision 6, which got both wrong.**

| Register | Revision 5 | Revision 6 (actual) | **Revision 7** |
|---|---|---|---|
| § R.18.2 rows | **15** | 15 + 3 = **18** | 18 + 3 = **21 rows** |
| `requirements_gaps` entries | **16** | 16 + 3 = **19** | 19 + 3 = **22 entries** |

**Revision 6 published `19 → 22` in both registers. Both "before" figures were wrong — by 4 and 3.** The
**deltas (+3/+3) and the entry-level agreement were right**, and those are the load-bearing claims.

**The asymmetry between the two registers is not an error, and is stated rather than smoothed:** § R.18.2
has **no row** for *"the Rev-4 review report"* because that entry is **closed**, while `requirements_gaps`
carries it marked `CLOSED` so the residue survives. **18 vs 19 at Revision 6; 21 vs 22 at Revision 7.**

---

## 4. What this matrix does **not** review, stated explicitly

- **It does not re-review the design content** of Revision 5's 3 372 lines, the ADR 0018 amendment, or the
  credential flow. Only their **heading existence** was re-derived (`V-2`).
- **It does not adjudicate any board.** It records the **measurement** three independent reviewers made and
  the **grant** the Manager reported. **This lane read no board, ran no Penpot tool, and holds no board
  ownership.**
- **It does not answer whether `BPM` carries a `Footer` layer.** That is **unverified in both directions**
  and is `G-23`'s, for the granted lane to establish.
- **It does not re-verify `27ea6536`'s outcome**, its `selected_option`, or the human's authority. **It
  does not re-adjudicate the footer** — no human is asked to re-decide anything.
- **It ran no gate.** No analyzer, no build, no test, no contrast measurement, no integration run.
  **Every `NOT_RUN` remains `NOT_RUN`.**
- **It ran no Docker or Compose command of any kind** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has already lost its QA database** to a lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`. **The rule was not tested, because testing
  it is the forbidden act.** Compose files were **not read**.
- **It does not review** the sibling mobile lane's directories, the ADR lane's directories, `AGENTS.md`, or
  any governance text outside this lane's directory.