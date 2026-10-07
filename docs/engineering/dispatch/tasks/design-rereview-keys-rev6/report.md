# Focused Re-Review — Add Product rebuild, Design Revision 6

**Task**: `design-rereview-keys-rev6` · **Lane**: `design-reviewer` (independent, read-only)
**Baseline**: `docs/engineering/dispatch/tasks/design-review-addproduct-keys-rev5/report.md`
**Reviewed artifacts**: `design-revision-6.md`, `design-revision-metadata-6.yaml`,
`report-revision-6.md`, `traceability-matrix-6.md`, `discoveries.md` (D-32…D-34),
`.decisions/**` (nine RESOLVED)
**REVISION_ID reviewed**: `d26658219dea4955b0d2b4004a70aa4d`
**ROUTE**: PRECISION · **Scope**: FOCUSED (B-R5-1 · M-R5-1..4 · L-R5-1..3 · Manager's G-19 record
correction · regression risk)

---

## 0. Provenance — DISCREPANCY FOUND, REVIEWED CONTENT UNAFFECTED

| Claimed (`prompt.md`) | Observed |
|---|---|
| `BASE_SHA: 1c3f5ad` | ✓ `1c3f5ad` |
| `HEAD_SHA: af8e30f` | ✗ **actual HEAD is `bd01bc0`** |
| branch `main` | ✓ `main` |

`bd01bc0` — *"docs(mobile): fix two wrong-record findings from the rev-6 re-review; persist its report"* —
is **one commit ahead** of the reviewed SHA and touches **only the sibling mobile lane**:

```
docs/engineering/dispatch/tasks/design-addproduct-mobile/correction-report-6.md
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-6.md
docs/engineering/dispatch/tasks/design-rereview-mobile-rev6/prompt.md
docs/engineering/dispatch/tasks/design-rereview-mobile-rev6/report.md
```

**Verified that nothing under review moved:**

```
$ git diff --name-only af8e30f bd01bc0 -- \
    docs/engineering/dispatch/tasks/design-addproduct-keyservice/ .decisions/
(EMPTY)
```

Every byte I reviewed is the byte at `af8e30f`. **REVIEWED_HEAD recorded as `af8e30f`** — the revision whose
content I inspected — with the drift disclosed rather than silently re-based onto `bd01bc0`. The dispatch's
`HEAD_SHA` was stale, not wrong about the content. Recording this rather than quietly reviewing at
`bd01bc0` is the same discipline this work item has been built on.

`git status` also shows unrelated modified visual-baseline PNGs and an untracked `check_baselines.sql` in
`apps/control_plane/test/failures/`. Not mine, not in scope, not touched.

---

## 1. What I VERIFIED AS CORRECT

Everything below was checked against the repository, not taken from the producing lane's report.

### 1.1 B-R5-1 — all four parts CLOSED

| Part | Required (baseline `:266-278`) | Landed | Verdict |
|---|---|---|---|
| 1 | `G-18` in **both** § R.18.2 and `requirements_gaps` | `design-revision-6.md:435-444`; `design-revision-metadata-6.yaml:355-378` | ✓ both registers, same id/summary/owner |
| 2 | § 10.1 Manager action assigning the four-board edit an owner **+ Penpot-binding block** | `design-revision-6.md:477-495` — owner = **design-system owner**, the owner `27ea6536`'s OPTION_B named in advance; both blocks named | ✓ coherent — rev5 § 10.1 runs 1…11, so item 12 is the correct next number |
| 3 | § R.11g item 7 amended so *"boards are authoritative"* is not asserted against a contradicting board; board edit stated alongside the three code edits | `design-revision-6.md:380-391` (scoped rule, one named exception) and `:396-401` (**FOUR**-edit table, owner per edit) | ✓ the unconditional sentence is gone |
| 4 | `G-19` registered, same class as `G-17`, owner = decision owner, **not a re-opening** | `design-revision-6.md:446-454`; metadata `:379`; exact fix specified at § 6 (`:499-572`) | ✓ lane wrote **nothing** under `.decisions/**` — `PROHIBITED_PATHS`, and `af8e30f`'s only decision edit is Manager-attributed |

### 1.2 M-R5-1 … M-R5-4 and L-R5-2, L-R5-3

- **M-R5-1** ✓ — rev6 § 0.4 has no `L8` row (map re-derived in full); `§ R.11g-i:414-426` restates the
  corrected numbers: `:925` is **mobile**, it **does** carry `note:` at `:926-928`; `_buildFooter` def `:375`
  / call `:314` / copy `:383` preserved as correct. I re-read the source: `_buildFooter` is at `:375`, called
  at `:314`, and the copy string is at `:383-384`.
- **M-R5-2** ✓ — no `M5` row; the full sweep is § 0.4.1 with its own limit stated.
- **M-R5-3** ✓ — rev6 § 0.4 heading reads **"19 findings and 5 MEDIUM"**, and the arithmetic is visible and
  correct (rev-4 report's own `MEDIUM: M3, M4, M5, M6, M7` = five; 2+3+5+9 = 19). rev5's own wrong
  `18`/`4 MEDIUM` was **left byte-identical** — verified: `design-revision-5.md:12` still reads
  *"3 HIGH, 4 MEDIUM, 9 LOW"*. That is the correct handling of a committed superseded artifact.
- **M-R5-4** ✓ — § 0.5 performs and records the reconciliation; `blockers[0]` `PROVENANCE_GAP` is
  `CLOSED — M-R5-4` with `289f1d3` cited; the residue is registered **separately** as `G-20` rather than
  swallowed by the closure.
- **L-R5-2** ✓ — `$ git rev-parse --short 289f1d3^` → `5436a4d`; `--is-ancestor` exits 0. § 0.6 is right.
- **L-R5-3** ✓ — real board names with `·` and `· Light/Dark`; `SM` named as a second state of one mobile
  design, already satisfying the mobile spec; **no mobile board edit requested**; sibling evidence named as
  *source of a measurement, not as authority*.

### 1.3 The § 0.4 sweep — VERIFIED, and the third error is genuine

The dispatch asked me to verify a re-derivation (not an amendment) of § 0.4 across 16+ rows.

- **Coverage arithmetic is sound**: 19 findings − `L8` − `M5` − `L13` = **16 rows check out**. Sweep is
  complete.
- **The two known errors**: `L8` and `M5` absent from rev6's map. ✓
- **The third error is GENUINE AND INDEPENDENTLY CONFIRMED.** § 0.4.1 says rev5's `L13` row claimed pins were
  recorded *"per artifact"* and *"only three of the four had pins"*, the unpinned one being
  `design-revision-metadata-5.yaml`. I checked rev5's metadata directly:

  ```
  content_pins.this_revision:
    design-revision-5.md:            "fb99f9e2…"   ← real
    traceability-matrix-5.md:        "0778b37d…"   ← real
    report-revision-5.md:            "121273ae…"   ← real
    design-revision-metadata-5.yaml: "SELF-EXCLUDED — see report-revision-5.md"   ← NOT a hash
  ```

  Three of four, and the fourth is the file carrying `risk_level`, `gates`, `requirements_gaps` and the
  changelog — exactly as disclosed. rev5's `artifacts[]` carried a `blob_hash` key on **exactly one** entry,
  whose value was the pointer string `"RECORDED IN § 0.3 AND report-revision-5.md — see L13"`.
  **The third error is real, correctly diagnosed, and genuinely disclosed.** This is the lane's strongest work.

### 1.4 `design-revision-3.md` persistence and G-20's honesty — VERIFIED

Using `git log --all --diff-filter=A` on the **exact full path**, never a basename:

```
$ git log --all --diff-filter=A -- \
    docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-3.md
af8e30f  docs(keys): persist revision 6 and revision 3; append the G-19 record correction to 27ea6536
```

Persisted at `af8e30f`. **G-20's before-state is honest and I verified every part of it:**

| G-20 / § 0.3 claim | My verification |
|---|---|
| rev-3's four artifacts were never added on any ref, **before** `af8e30f` | `git log 1c3f5ad --diff-filter=A -- <exact path>` → **empty** ✓ |
| 11 tracked files carried rev-3/4/5 banners + `discoveries.md` additions, **uncommitted** | `git show 1c3f5ad:…/design-revision-2.md \| head -3` begins `# Design Revision 2` — **no banner present** at `1c3f5ad` ✓ |
| rev-3 is 137 494 bytes, blob `13647274346f183f87ef6510ca2da9d539120a6a` | At `af8e30f`: blob **`1364727434…`**, size **137 494** — **exact match** ✓ |

That last row is the strongest result in this review: **the artifact the Manager committed at `af8e30f` is
byte-identical to the worktree copy the lane measured**, so the chain of custody is unbroken. `2838` also
checks out as the four *new* rev-3 files (1802 + 481 + 176 + 379).

**The lane was right to decline the false premise.** My dispatch stated rev-3 *"exists and is committed on
main"*. It did not. Adopting it would have retired a revision from the record on a false statement. This is
recorded as `G-20` and as `D-34` (`WORKFLOW_IMPROVEMENT`, **ROUTED, not auto-persisted**) — and the Manager's
own dispatch text is classified `CONTRADICTION → ESCALATED, NOT PERSISTED`, correctly, because it is the
Manager's text and the repository must not assert a fact about a dispatch it does not own. **Per
`LEARNING_POLICY.md` this is exemplary.**

### 1.5 Banner state, the decline, and the incorporation claim

- **The decline is literally true.** `design-revision-5.md` and `design-revision-metadata-5.yaml` are
  **untouched** at `af8e30f` (`git diff 1c3f5ad af8e30f -- …` empty for both). No supersession banner was
  extended on them. ✓
- What *was* edited is coherent and, on inspection, principled: the 11 files modified at `af8e30f` carry
  banners **Revision 5 itself wrote and left stranded** (§ 0.3.2). Rev 6 persisted rev-5's own output rather
  than authoring new content on a committed artifact — a defensible distinction, and disclosed. The banners
  added to rev-2/rev-4 say *"SUPERSEDED BY DESIGN REVISION 5"*; neither mentions Revision 6.
- **The incorporation claim FAILS on § 10.2** — see **HIGH-1**. All other R.1 targets resolve: I enumerated
  rev5's full heading list (`§ 0.2`, `§ 0.3`, `R.1`…`R.10`, `R.11`…`R.18.1`, `§ 8`, `§ 9.2`, `§ 10.2`) and
  every named target exists.

### 1.6 Four accepted risks remain four — VERIFIED

`grep -c 'Consequence accepted' docs/adr/0018-per-product-git-credentials.md` → **4**.
`876c6b97`'s appended note retains **A1** deliberately ("RETIRING IT IS THE OWNER'S CALL") while recording
that `08c7590` closes it in fact. **Revision 6 respects this**: no `A1` retirement or closure claim appears
anywhere in `design-revision-6.md` or `design-revision-metadata-6.yaml` (grep empty). rev6 § 9 states
*"No accepted-risk count changed: exactly four were put to the owner and exactly four are recorded."* ✓

### 1.7 Regression risk — none found in the key flow

`design_primitives.dart:396` (real path `apps/control_plane/lib/shared/design_primitives.dart`) still reads
`const ContentRule(),` — painted unconditionally, as the baseline verified. `add_product_page.dart` retains
`_buildFooter` def `:375` / call `:314` / copy `:383-384`. Rev 6 changed **no design content**, so there is no
regression surface in the key flow. § 10.1 item 12, `§ R.11g-h`, `§ R.18.2-h`, `§ 0.4`, `§ 0.5` and `§ 2` are
all restated in full as claimed (§ 10.2 excepted). The four rev-5 artifacts are byte-identical at `16cd497`
and at the reviewed HEAD.

---

## 2. The Manager's applied G-19 record correction — AUDIT

`.decisions/27ea6536-8a4e-4cf1-b24c-cdd3ce5bdab0.yaml`, `1c3f5ad` → `af8e30f`. This is a **Manager edit to a
resolved human decision** — the most sensitive edit class in this framework. Audited at byte level.

### 2.1 Append-only — VERIFIED

The diff has exactly two hunks' worth of change: **one line replaced**, **content appended after it**.

| Protected field | Line | State |
|---|---|---|
| `status: RESOLVED` | 4 | **UNTOUCHED** |
| `selected_option: OPTION_A` | 103 | **UNTOUCHED** |
| `decided_by` | 104 | **UNTOUCHED** |
| `decided_at: 2026-10-06T13:05:00Z` | 105 | **UNTOUCHED** |
| `deviation_from_presented_options` | 106-112 | **UNTOUCHED** |
| `human_correction_verbatim` | 113-118 | **UNTOUCHED** |
| `rationale` — all outcome clauses | 127-145 | **UNTOUCHED** |
| `follow_up_actions` #1-#4 owners | 149, 152, 155, 158 | **UNTOUCHED** (design-agent ×3, implementer ×1) |
| `created_by` / `created_at` | 159-160 | **UNTOUCHED** |
| **`updated_at`** | 161 | **only field changed**: `2026-10-06T13:05:00Z` → `2026-10-07T00:00:00Z` + inline comment |

The note begins strictly after `updated_at` and matches `876c6b97`'s pattern as specified. **No decision was
re-opened. No accepted-risk count changed. No owner was reassigned. No outcome clause was rewritten.**

### 2.2 The note's quotations — VERIFIED VERBATIM

Both quoted statements exist in the record exactly as quoted:

- `supersedes_design_lane_reading` (line 122-123): *"The human checked and reports the desktop state boards
  carry NO footer copy - only a divider and a right-aligned Show technical details text button"*
- `follow_up_action` #3 (line 154): *"the design lane's coordinate-based reading of a 'Footer' layer at
  (236,862) should be treated as a misidentification"*

A record-correction note that misquotes the record it corrects is worse than none. **This one does not.**

### 2.3 The note's one source claim — I VERIFIED IT MYSELF

The note claims the board text is *"the SAME string `_buildFooter` renders … at
`apps/control_plane/lib/features/products/add_product_page.dart:383-384`"*. From source:

```
383:          'Your decision is recorded permanently. The same piece of '
384:          'work then continues \u2014 nothing is restarted.',
```

**Confirmed.** `_buildFooter` is defined at `:375` and called at `:314`. This is the load-bearing anchor that
makes the board layer the *build's own* copy rather than text a human could plausibly have misread — and it
is the one link in the chain I could close without Penpot.

### 2.4 ⚠ I am ACCEPTING the board measurement, NOT reproducing it

**I have no Penpot board ownership in this lane. I called no Penpot tool. I read no board.** I am therefore
**accepting the two independent read-only measurements** rather than reproducing them:

1. **Sibling mobile lane** — `design-addproduct-mobile/penpot-board-evidence.md` § 6.4, titled *"Attempt 2
   could not run this either. Read at revision 5, read-only, on all four `S · Add Product · …` boards."*
2. **The Rev-5 reviewer** — its own report § 2.3, titled *"F6 … CONFIRMED INDEPENDENTLY, BY ME, LIVE"*,
   stating *"I reached Penpot from this session (read-only) and measured the footer band of all four
   desktop `S` boards myself. I did not adopt the sibling lane's measurement."*

I verified both **exist**, that rev6 cites the correct section (§ 2.3 — the number is right), and that the two
**agree exactly** on every figure: `Footer Rule` rectangle 236, 848, 1020×1; **`Footer` TEXT 236, 862,
1020×15, `align: left`**; `Disclose` text 1036, 862, 220×15, right edge 1256 = 236 + 1020. Clause verdicts
also agree: divider **SATISFIED**, right-aligned button **SATISFIED**, *"No footer copy"* **NOT SATISFIED**.
Independent corroboration in the Rev-5 report: a 160-board inventory with child counts matching. **I accept
this measurement on the strength of two agreeing independent passes plus my own source confirmation.**

### 2.5 ⚠ VERDICT ON THE NOTE'S FRAMING — **SOUND. NO MISREPRESENTATION.**

The framing claim: *"WHAT THE DECISION OVERRULED WAS THE LANE'S CONCLUSION, NOT THE LANE'S OBSERVATION. The
observation was correct and is now measured; the conclusion — that the copy stays — is what the owner reversed,
and the owner was entitled to reverse it."*

I tested each clause against the record rather than accepting it:

| Clause | Test against `27ea6536` | Verdict |
|---|---|---|
| the lane's **conclusion** was *"that the copy stays"* | `context.recommendation:71-78` → `recommended_option: OPTION_A`; `OPTION_A:81-91` = *"Mobile only; **keep desktop copy**"* | **EXACT** |
| the lane's **observation** was the `(236,862)` footer-copy reading | `supersedes_design_lane_reading:120-121` records precisely that, *"beside a disclosure at (1036,862)"* — and that is what was measured | **EXACT** |
| the **owner was entitled** to reverse the conclusion | `type: DESIGN`; `decided_by` = repository owner; rationale:124 *"The human is the authority on the boards and has stated they checked"*; `deviation:107` records the owner checking the boards directly and rejecting **both** presented options | **YES** |

The note's own summary of its scope — *"Both concern the factual BASIS on which the owner's answer rests.
Neither concerns the ANSWER"* — is the accurate characterisation of what actually happened: a competent
exercise of design authority on an erroneous factual premise. **That is exactly what the note says, and
nothing more.**

Three further reasons I judge the framing honest rather than convenient:

1. **It is corroborated by a source independent of rev 6.** `penpot-board-evidence.md` § 6.4 makes the same
   distinction — *"What the decision overrules is the lane's *conclusion*, not the lane's *observation* — and
   this revision reinstates the observation as measured while leaving the decision's outcome untouched"* —
   and that text predates Revision 6. Rev 6 did not invent a charitable framing.
2. **It does not invite re-litigation.** The note protects the owner explicitly: *"the owner was entitled to
   reverse it. Nothing here disturbs that"*; *"The OUTCOME stands … ALL OF IT"*; *"`27ea6536` is not re-opened
   and the human is NOT asked to re-decide the footer."*
3. **It refuses to over-claim in the lane's own favour.** `G-19`'s framing is stated as *the record being
   wrong*, not *the human being wrong*. `design-revision-6.md:451` names the class honestly: *"a decision
   record **denying a thing that exists** … both are records that will not be re-checked because they are
   authoritative."*

**The framing is correct. The note does not misrepresent the human decision. It is correctly appended,
correctly scoped, and correctly framed. I record no finding against it beyond LOW-1 and LOW-2 below, which
concern detail rather than substance.**

---

## 3. G-18 — open, owned by nobody, and the distinction is HONEST

The dispatch asked me to judge whether *"R-UX2 is COVERED but the OBLIGATION is UNOWNED and BLOCKED"* is honest
or convenient. **It is honest.** Evidence:

- The lane claims **only coverage, never completion**. `design-revision-metadata-6.yaml:341` and
  `traceability-matrix-6.md` row 75 both read **`PARTIALLY COVERED`** — not "covered", not "closed".
- The distinction is *defined*, not asserted: *"**Coverage and completion are different claims and only the
  first is true here.**"*
- The unowned obligation is routed to a **named** owner — the design-system owner, the one `27ea6536`'s own
  OPTION_B named in advance — with an explicit **do-not-close** instruction in **three independent places**:
  § 10.1 item 12 (*"Do not close the work item before this has an owner"*), `G-18`'s owner field
  (*"DO NOT CLOSE THE WORK ITEM BEFORE THIS HAS AN OWNER — the build would then be able to diverge
  permanently from the authority it declares"*), and § 8 SAFE_PARALLEL_WORK (*"NOT SAFE while `G-18` and
  `G-19` are open: any board edit; treating § R.11g item 7's 'boards are authoritative' as unconditional; and
  **closing the work item**"*).
- It refuses the convenient move. `traceability-matrix-6.md` § 1b calls rev5's own out-of-scope paragraph
  *"half right and **its error is the blocker**"* — *"not authoring a board is out of scope, but **specifying
  what a board must contain, and recording that nobody owns the edit, is not**."* A convenient reading would
  have left `G-18` inside that paragraph.
- **The required edit is scoped to the minimum**: remove that one layer, leave `Footer Rule` and `Disclose`,
  *"change nothing else."* And it is correctly classified **as an ownership grant plus an infrastructure fix,
  not a design question** — so it is **not** a `HUMAN_DECISION_REQUIRED`, and the human is **not** asked to
  re-decide the footer.

**G-18 remains OPEN, OWNED BY NOBODY, and BLOCKED on the Penpot instance binding. The work item must not close
over it.** It needs an **ownership grant**, not a re-decision.

---

## 4. FINDINGS

### HIGH-1 — `§ 10.2-h` is a dangling cross-reference; the "every changed sentence is restated in full" claim FAILS

`design-revision-6.md` has **no `§ 10.2-h`**. I enumerated every heading in the artifact:

```
27:## 0. · 29:### 0.1 · 45:### 0.2 · 61:### 0.3 · 143:### 0.4 · 166:### 0.4.1
188:### 0.5 · 233:### 0.6 · 251:## R.1 · 288:## 2 · 290:### 2.1 · 302:### 2.2 · 321:### 2.3
330:## R.11g · 332:### R.11g-h · 414:### R.11g-i · 430:## R.18.2-h · 435:### G-18
446:### G-19 · 456:### G-20 · 472:## 10.1-h · 499:## 6 · 576:## 7 · 578:### 7.1 · 588:### 7.2
605:### 7.3 · 619:## 8 · 640:## 9
```

`10.2-h` is absent. Two references point at it:

- `design-revision-6.md:277` — the § R.1 incorporation table's § 10.2 row:
  *"**Carried with § 10.2-h below**, which restates items 10 and 12 (L-R5-1) and adds the new items this pass
  creates"*
- `design-revision-metadata-6.yaml:352` — *"REGISTER AGREEMENT (design-revision-6.md § 10.2-h)"*

None of the three claims is true. § 10.2 is *"What a reviewer should check hardest — **each item is now
checkable**"* — so the dead pointer sits in the section that governs reviewer attention, on exactly the two
items rev 6 says it handled. Rev 5's § 10.2 has 14 items; its **item 10** is the pin/citation falsifier
(L-R5-1's subject) and its **item 12** is the register-agreement check (B-R5-1's subject). Both remain in
rev 5 unamended and unaddressed.

**Rev 6 also contradicts itself.** Line 282-284 states what it *does* restate in full: *"§ R.11g-h,
§ R.18.2-h, § 10.1 item 12, § 0.4, § 0.5, § 2."* **§ 10.2 is not in that list.** So the artifact both claims
to restate § 10.2 and lists a set of restatements that excludes it.

**Substance is not lost** — both fixes were delivered elsewhere, and I confirmed each: `V-2`'s falsifier is
restated against `provenance.content_pins.this_revision` (`design-revision-metadata-6.yaml:578`), and
register agreement is stated in `§ R.18.2-h`. So nothing is unexecutable and this is **not** a blocker.

**Why HIGH.** This is the **L-R5-1 defect class recurring inside the artifact created to fix it** — a
circular/dangling pointer with an unexecutable falsifier. My dispatch specifically flagged *"a 3 372-line
revision referenced rather than restated is a traceability risk"* and asked me to verify the restatement claim.
**It fails.** And the incorporation table is the mechanism that makes a 658-line revision sound against a
3372-line referent: if one row points at a section that does not exist, every other row's pointer must be
re-checked. Every *other* target I checked resolves; this one does not.

**Required correction.** Either write `§ 10.2-h` restating items 10 and 12 as claimed, **or** correct both
references to say § 10.2 is carried **unchanged by reference** from rev 5 with the two fixes delivered at
`§ 7.1 V-2` and `§ R.18.2-h` — and add § 10.2 to the restated-list at line 282-284, or remove it from the
claim at line 277. Fix in `design-revision-6.md` **and** `design-revision-metadata-6.yaml`.

---

### HIGH-2 — L-R5-1 is reported closed on a claim that is false, and the matrix's own falsifier for it is currently satisfied

Five places assert that every `artifacts[]` entry carries a real `blob_hash`:

| Location | Text |
|---|---|
| `design-revision-metadata-6.yaml:178-181` | *"EVERY entry in `artifacts[]` below carries a REAL blob_hash … **Both are corrected here.**"* |
| `design-revision-metadata-6.yaml:470` | *"**Every entry here carries a REAL hash.**"* |
| `design-revision-metadata-6.yaml:576-577` | *"**EVERY artifacts[] entry now carries a REAL blob_hash**"* |
| `report-revision-6.md:30` | *"**every `artifacts[]` entry is a real hash**"* |
| `traceability-matrix-6.md:85` | *"**every `artifacts[]` entry carries a real `blob_hash`**"* |

**It is false for all four Revision-6 artifacts.** The actual `artifacts[]` values:

```
design-revision-6.md            blob_hash: "RECORDED IN report-revision-6.md § Content pins AND design-revision-6.md § 7.1 V-2"
design-revision-metadata-6.yaml blob_hash: "SELF-EXCLUDED BY CONSTRUCTION — printed in report-revision-6.md § Content pins"
traceability-matrix-6.md        blob_hash: "RECORDED IN report-revision-6.md § Content pins"
report-revision-6.md            blob_hash: "SELF-EXCLUDED BY CONSTRUCTION — this file is the report"
```

Not one is a hash. Only the four **superseded rev-5** entries carry real hashes. `metadata-6.yaml:470`'s
accompanying comment compounds it — *"The **two** self-excluded files cannot contain their own hash"* — when
in fact **all four** Revision-6 artifacts are self-excluded by construction.

**The lane published a falsifier for its own correction, and the falsifier is satisfied.**
`traceability-matrix-6.md:85` supplies: *"**Or** find an `artifacts[]` entry whose `blob_hash` is a pointer
string rather than a hash."* A reviewer running that test finds four. So the correction row currently **fails
its own stated test**, and it reports a LOW finding as closed when the second half of it is open.

**The underlying traceability property is genuinely fixed, and I verified it byte-exact.** `report-revision-6.md`
prints the metadata's own hash, and all four rev-6 hashes match the committed blobs at `af8e30f`:

```
design-revision-6.md             2187065c0beffc3020886cc1b16027865f7ae71c  ✓
design-revision-metadata-6.yaml  5a9b5ae03dfa64f97fe7962edec60308805be889  ✓  (metadata's OWN hash)
traceability-matrix-6.md         fafcf362dc873fa2a9169448bec39711d4b7dd9f  ✓
report-revision-6.md             SELF-EXCLUDED — this file
rev-5's four                     fb99f9e2… · bae3c019… · 0778b37d… · 121273ae…  ✓ all match
```

So the pin loop now works both ways and an auditor can recover every hash from one place. **The baseline's
L-R5-1 offered an explicit either/or** — give the entries real hashes **or** *"drop the field and restate
§ 10.2 item 10's falsifier against `provenance.content_pins.this_revision`."* Rev 6 took the **second** branch
(correctly) and then also claimed the **first** branch's completion, which it did not do.

**Why HIGH.** Misreporting a finding as closed when half of it is open, in the traceability deliverable, with a
self-defeating falsifier attached — in a work item whose recorded lesson is precisely *"a record denies a thing
that exists, and nothing will re-check it, because it is authoritative."* This is that pattern again.

**Required correction.** Restate the claim accurately in all five locations — e.g. *"every `artifacts[]` entry
carries either a real `blob_hash` (the four superseded rev-5 artifacts) or a pointer to
`report-revision-6.md` § Content pins, where all four Revision-6 hashes are printed, including this file's
own"* — and either amend or withdraw the falsifier at `traceability-matrix-6.md:85` so it tests what the
artifact actually does.

---

### HIGH-3 — Register row counts are wrong in both registers, in both artifacts

Two artifacts state the gap-register row counts as **19 → 22**:

- `design-revision-6.md:433` — *"**Three entries are added. The table's row count goes from 19 to 22.**"*
- `traceability-matrix-6.md` § 3 — *"**Row counts.** `§ R.18.2` **19 → 22 rows**. `requirements_gaps`
  **19 → 22 entries** plus the closed provenance entry. **Both counts move together, which is the property
  the finding was about.**"*

**Both "before" figures are wrong.** I counted rev5's registers directly:

| Register | rev5 actual | rev6 claims | Correct |
|---|---|---|---|
| `design-revision-5.md` § R.18.2 | **15 rows** — `G-3 G-4 G-5 G-6 G-8 G-10 G-11 G-12 G-13 G-14 G-15 G-16 G-17`, `L-6`, `ADR 0018 :103 wording` | 19 → 22 | **15 → 18** |
| `design-revision-metadata-5.yaml` `requirements_gaps` | **16 entries** — the same 15 plus `"the Rev-4 review report"` | 19 → 22 | **16 → 19** |

The **deltas are right** (+3 and +3) and the three new entries genuinely are in both registers with identical
ids, summaries and owners — I verified that directly. Only the absolute figures are wrong, by 4 and 3.
Note that `16 + 3 = 19`: the "before" number quoted for `requirements_gaps` is the **post**-addition count.

**Why HIGH.** § 3 of the matrix exists for one purpose — certifying that the two registers agree — and its
closing sentence is *"Both counts move together, which is the property the finding was about."* It certifies
with two wrong numbers. And § R.18.2-h's count is the figure a reviewer uses to confirm B-R5-1 part 1 actually
added entries. **This is the M-R5-3 error class recurring** — *"a finding set counted wrong"* — inside the
register-agreement check of the pass commissioned to fix it. I weighted it HIGH rather than MEDIUM because it
is not merely a stale total: it is wrong in **two** artifacts, in **two** registers, in the specific check
whose purpose is register agreement, and it would misdirect any reviewer who counts the register.

**Required correction.** State **15 → 18** (`§ R.18.2`) and **16 → 19** (`requirements_gaps`) in
`design-revision-6.md:433` and in `traceability-matrix-6.md` § 3, and note that the deltas (+3/+3) and
entry-level agreement are the load-bearing claims.

---

### MEDIUM-1 — § 0.4.1's sweep enumeration lists 17 rows as "all sixteen rows check out", and includes the row it then declares wrong

`design-revision-6.md:171-172`:

```
- **`B5`, `B6`, `H8`, `H9`, `H10`, `M3`, `M4`, `M6`, `M7`, `L5`, `L6`, `L7`, `L9`, `L10`, `L11`, `L12`,
  `L13` — all sixteen rows check out** against the sections they name, at Revision 5's own base.
```

The enumeration contains **17** names. `L13` is then declared **wrong** in the very next bullet
(*"One additional error the reviewer did not find… § 0.4's `L13` row claims content pins were recorded
'per artifact', and only three of the four had pins"*). So `L13` is simultaneously listed as verified and as
an error.

The **coverage arithmetic is sound** — 16 + `L8` + `M5` + `L13` = **19** ✓ — and the prose number 16 is the
correct count *of rows that check out*, once `L13` is removed from the list. The defect is that the list
includes `L13`.

**Why MEDIUM, not HIGH.** No row is missing from the sweep, no wrong-row is claimed correct in substance, and
the sweep's conclusion is correct. But this is a self-contradiction in the sweep result that M-R5-2 explicitly
demanded, in the correction map § 10.2 tells reviewers to trust, in the same error class as M-R5-3.

**Required correction.** Drop `L13` from the enumeration at lines 171-172 (leaving 16 names), so the list and
the count agree and `L13` is claimed only in the bullet that reports its error.

---

### LOW-1 — the G-19 note normalizes an em dash to a hyphen in the string it quotes

The note quotes the board/build string as *"…The same piece of work then continues - nothing is
restarted."* The source at `add_product_page.dart:383-384` is `… continues \u2014 nothing is restarted.` — an
**em dash**, rendered `-`. Everywhere else the note is byte-rigorous (1020 × 15, 236 + 1020, right edge 1256).
Trivial, but in a record-correction note whose subject is a false factual claim, a normalised character in a
quoted string is the one imprecision that class invites. **Fix:** use the em dash.

---

### LOW-2 — `27ea6536` contains a third inaccurate statement that G-19 does not register

`supersedes_design_lane_reading` (line 121) asserts the design lane recorded *"that the **mobile** boards
carry a copy plus a disclosure."* The **same file's own** `context.summary` fact 1 (lines 15-17) says
*"The **mobile** boards have no bottom copy at all. `BPM · Add Product · Light/Dark` carry exactly one
element below the helper."* The record contradicts itself about the mobile half of the lane's reading.

This is **pre-existing** (written by the Manager at `674b871`), **not** introduced by rev 6, and it was **not
measured** by either of the two desktop passes — so G-19's scoping to *"Two statements"* is accurate and not
an under-claim about what was measured. But it is a third false statement in the **same paragraph** G-19
corrected, and it is registered nowhere. It does **not** create an outcome conflict (the decision's mobile
outcome — no copy, left-aligned, no divider — is consistent with the boards per both the context summary and
the human's check), so G-18's scope of *"conflict on exactly one clause"* still holds. **Fix:** register it in
`G-19` as an unmeasured third item, so a future reader does not re-derive it.

---

### LOW-3 — `G-20` and its two echoes are now stale at the reviewed HEAD

Three places assert a provenance state that was true at rev 6's base and is false at `af8e30f`:

- `design-revision-metadata-6.yaml:503` — *"RETAINED, SUPERSEDED, AND UNCOMMITTED — **NEVER ADDED ON ANY
  REF** (G-20)"*
- `traceability-matrix-6.md` row 77 — *"11 tracked files uncommitted; Revision 3's four artifacts **never added
  on any ref**"*
- `design-revision-6.md:460` — `G-20`'s row: *"exist only as uncommitted working-tree files"*

At `af8e30f` **all of it is on disk**, and the 11 modified banners were committed along with rev 3's four
artifacts. **This is unavoidable staleness, not dishonesty** — rev 6's `BASE_SHA`/`HEAD_SHA` are `1c3f5ad`
and `COMMITTED: NO`, and it could not have written about a commit that did not yet exist. § 0.3.4 is explicit
and honest about the then-current state. But left as-is, a reviewer reading rev 6 at `af8e30f` would conclude
the supersession chain is still missing when it is not, and `G-20` reads OPEN when the Manager has in fact
discharged it. **Fix:** record that `G-20` was discharged by the Manager at `af8e30f`, re-anchoring the
"before" claims to `1c3f5ad` where they are true.

---

### LOW-4 — `design-revision-5.md` has no forward pointer to Revision 6

Rev 5 (3372 lines, committed on `main` at `16cd497`) carries no banner naming Revision 6 as its successor; its
header still reads *"**Supersedes**: `F2D5AF31…` (Revision 4) …"*. A future lane opening rev 5 will read it as
current. The pointer exists only *inside* rev 6 and its metadata.

The lane's **decline is literally correct** and disclosed — I verified `design-revision-5.md` and
`design-revision-metadata-5.yaml` are **untouched** at `af8e30f` — and persisting rev-5's own stranded
banners on rev-2/rev-4 (rather than authoring new ones on a committed artifact) is a coherent distinction.
So this is a **residual, disclosed** traceability risk rather than a defect. **Fix:** none required on rev 5;
note the residual in the work-item ledger so the next lane does not treat rev 5 as current.

---

## 5. Do NOT re-open — confirmed as directed

- **`RISK_LEVEL: 3`, tally verbatim `0 reasons IMPROVED, 2 reasons UNCHANGED (R1, R6), 4 reasons WORSE (R2,
  R3, R4, R5)`** — reproduced character-for-character at `design-revision-6.md:295` and
  `design-revision-metadata-6.yaml:67`, and rev 5's wrong `18`/`4 MEDIUM` left byte-identical. **No reason moved
  in either direction.** Not re-opened.
- **Three new gap registers argue FOR level 3, not against.** Agreed: a level-1 design does not accumulate
  governance debt, and `G-18` (unowned), `G-19` (a false record) and `G-20` (chain not on disk) are three
  open governance items. Six grounds in § 2.2 are present at the base.
- **Banner state** — coherent and the decline is literally honoured (see § 1.5 above; LOW-4 records the
  residual).
- **Four accepted risks remain four**; A1 verified closed in fact but deliberately not retired, and rev 6 does
  not touch it (see § 1.6).

---

## 6. What I did NOT review — stated explicitly

- **The design's content about the key flow.** The baseline found nothing wrong with it; my dispatch forbids
  re-review. I confirmed rev 6 changed **no** design content and spot-checked only the citations rev 6 itself
  carries (`add_product_page.dart:314/317-319/375/383-384/926-928`; `design_primitives.dart:396`).
- **Revision 5's 3372 incorporated lines.** I verified every § R.1 table target *exists*, that rev 5 and its
  three siblings are byte-identical at `16cd497` and at the reviewed HEAD, and that rev 6's *restatement
  claim* fails on § 10.2 (HIGH-1). I did not re-derive rev 5's substance.
- **The Penpot boards.** **No Penpot tool called. No board read, listed, exported, edited, renamed, moved or
  deleted.** The footer-band measurement is **accepted** from two independent read-only passes (§ 2.4), not
  reproduced.
- **`docs/adr/**`** — the design content of ADR 0018 and its amendment. `G-17` is carried unedited and
  unclaimed. I confirmed only that ADR 0018 records exactly four accepted risks.
- **The sibling mobile lane's `D-8` claim** (`SM` and `BPM` are two states of one design) — recorded as *source
  of a measurement, not as authority*, and not adjudicated.
- **`bd01bc0`'s mobile-lane content** — the drifted HEAD, outside scope.
- **Any gate.** No analyzer, no build, no test, no contrast measurement, no integration run, no schema check.
  Every `NOT_RUN` in rev 6 remains `NOT_RUN` and I ran none of them.
- **Docker / Compose: NONE RUN** — not `info`, not `ps`, not `logs`, not `config`, not `down`, not any
  mutating command. **I did not read the compose files either.** This repository has already lost its QA
  database to a review lane running `docker compose -f docker/compose.qa.yaml down -v --rmi local`. The rule
  was not tested, because testing it is the forbidden act.
- **`WORK_STATE.md`, `LANES.md`, `AGENTS.md` §13 restoration, and any governance text outside this lane's
  directory.**

---

## 7. Result

```
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED

REVIEWED_HEAD: af8e30f
REVISION_ID: d26658219dea4955b0d2b4004a70aa4d

BLOCKERS: none
  (B-R5-1 is genuinely CLOSED — all four parts verified in both registers, § 10.1 item 12,
   the scoped § R.11g-h rule with a FOUR-edit owner table, and G-19 registered with the
   writing lane touching nothing. Nothing in rev 6 would let the work item close over an
   unowned obligation. The HIGH findings are self-description and traceability defects,
   not unowned obligations, and so are not blockers on the baseline's own precedent.)

HIGH: 3
  HIGH-1  § 10.2-h is a dangling cross-reference. design-revision-6.md:277 and
         design-revision-metadata-6.yaml:352 both point to a section that does not exist;
         none of the three claims made for it is true; and design-revision-6.md:282-284
         contradicts itself by omitting § 10.2 from its own restated-list. Falsifies the
         claim "every sentence it changes IS restated in full". Recurrence of the L-R5-1
         dangling-pointer class. Fix in rev6 + metadata-6.
  HIGH-2  L-R5-1 is reported closed on a false claim, and traceability-matrix-6.md:85's own
         falsifier for it is currently satisfied. Five locations assert every artifacts[]
         entry carries a real blob_hash; all four Revision-6 entries carry pointer strings or
         self-exclusion markers. The underlying pin loop IS fixed and I verified it
         byte-exact, and metadata-6:470 also miscounts self-excluded files as two rather than
         four. Fix the claim in all five places and amend/withdraw the falsifier.
  HIGH-3  Register row counts wrong in both registers and both artifacts: rev6:433 and
         traceability-matrix-6 §3 say 19 → 22; actual § R.18.2 is 15 → 18 and
         requirements_gaps is 16 → 19. Deltas (+3/+3) and entry-level agreement are correct.
         M-R5-3's error class recurring inside the register-agreement check.

MEDIUM: 1
  MEDIUM-1  design-revision-6.md:171-172 enumerates 17 rows as "all sixteen rows check out"
            and includes L13, which the next bullet declares wrong. Coverage arithmetic is
            sound (16 + L8 + M5 + L13 = 19). Drop L13 from the list.

LOW: 4
  LOW-1  G-19 note normalizes an em dash to a hyphen in the string it quotes from
         add_product_page.dart:383-384.
  LOW-2  27ea6536's supersedes_design_lane_reading carries a third inaccurate statement
         (mobile "copy plus a disclosure") that contradicts its own context.summary and is
         registered nowhere. Pre-existing, unmeasured by either desktop pass; does not widen
         G-18's scope.
  LOW-3  G-20 and its echoes (metadata-6:503, traceability-matrix-6 row 77, rev6:460) are
         stale at the reviewed HEAD: everything they describe as uncommitted / never added was
         committed at af8e30f. Unavoidable base-scoped staleness, but G-20 reads OPEN when
         the Manager has discharged it.
  LOW-4  design-revision-5.md (3372 lines, on main) has no forward pointer to Revision 6.
         Decline literally honoured and disclosed; residual traceability risk only.

INDEPENDENT_RISK_LEVEL: 3
RISK_LEVEL_AGREEMENT: YES

TRACEABILITY_GAPS:
  The design's requirements remain traced; TRACEABILITY_GAPS is not the defect here and I did
  not reproduce the baseline's "none" without checking. Two gaps in the TRACEABILITY
  DELIVERABLE, both recorded above and neither a missing requirement:
   - HIGH-1: § 10.2 is carried neither restated nor correctly described as incorporated, and
     the two cross-references naming § 10.2-h are dead.
   - HIGH-2: traceability-matrix-6.md § 2's L-R5-1 row carries a falsifier its own artifact
     currently satisfies, so the Rev-5 finding → correction map is not a sound audit index
     for that row.
  Both are correction-lane work on the trace artifacts; neither requires design content.
  Requirement-level traceability itself: the three new entries are present with identical ids,
  summaries and owners in both registers, and G-18's four-board edit is recorded under
  design_elements_without_a_requirement as a DECIDED requirement lacking an OWNERSHIP grant —
  the correct characterisation.

CORRECTION_REQUIRED: YES

HUMAN_DECISION_REQUIRED: NO
  Nothing here is a product/architecture/design decision for a human. HIGH-1..3, MEDIUM-1 and
  LOW-1..4 are all corrections to self-description, counts, pointers and wording inside the
  design lane's own artifacts. G-18 is explicitly NOT a human decision: 27ea6536 is RESOLVED,
  its outcome is not in question, and the human is NOT asked to re-decide the footer — what is
  missing is an ownership grant plus an infrastructure fix.

HUMAN_DECISION_TYPE: DESIGN

SAFE_PARALLEL_WORK:
  - Everything in Revision 6 § 8, carried unchanged: implementation of G-11 (D-4/D-5/D-6, both
    tiers, eight columns); G-13 step 3a + G-16 step 3a + T-L + SC-20 (ship G-16 first);
    G-14 (§ R.11.2, one method, no schema change); retirement of the repositoryId:productId
    placeholder (§ 10.1 item 7). No Rev-5 finding and none of mine touches any of it.
  - The three code edits of § R.11g item 7 — delete _buildFooter, desktop note: null at
    :317-319, mobile note: null at :926-928 — are specified, sourced and regression-checked by
    me at the reviewed HEAD, and are unaffected by every finding in this review.
  - Manager-side: record that G-19 was applied at af8e30f (done), and discharge G-20 by
    recording the af8e30f persistence of rev 3 and the 11 banners (LOW-3).
  - The G-19 correction lane can proceed in parallel with nothing else, but must NOT touch
    .decisions/** beyond what § 6 of rev 6 specifies, and must not re-open 27ea6536.
  NOT SAFE while G-18 is open: any board edit; treating § R.11g item 7's "boards are
  authoritative" as unconditional; and CLOSING THE WORK ITEM.
```

**Verdict in one line:** Revision 6 closes B-R5-1 genuinely and improves the chain's honesty in three
substantive ways (a real full sweep, a genuinely-disclosed third error, a declined false Manager premise
whose residue is now on disk at exactly the blob the lane measured) — but it re-introduces the L-R5-1
dangling-pointer class in its own incorporation table, reports L-R5-1 closed on a claim its own falsifier
refutes, and states both register row counts wrong. All five defects are corrections to self-description and
traceability, **none to design content**; a focused correction lane can close them without re-deriving any
analysis in this report.

---

*Reviewer: `design-reviewer` (independent, read-only). No design artifact was modified. No commit, no push.
No Docker or Compose command of any kind was run. No Penpot tool was called and no board was read or touched.
Only this report directory was written.*
