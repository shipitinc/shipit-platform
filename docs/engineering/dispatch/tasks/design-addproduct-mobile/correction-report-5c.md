# Report — Add Product mobile boards, **Design Revision 5, final** (Gate D3, cycle 5b/5c)

Persisted per `subtask-report.md` § *Mandatory header*. Lane `design-agent`, **not** a reviewer; this lane
does not approve its own work. **This is a RESUME of a cancelled invocation** — see § 3.

```yaml
RESULT: DESIGN_REVISION_COMPLETE
TASK_ID: design-correct-addproduct-mobile-5b
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — mobile Design Revision 5 (cycle 5)
WORKTREE: /private/tmp/shipit-correct-addproduct-mobile
BRANCH: design-correct-addproduct-mobile
BASE_SHA: 289f1d3
HEAD_SHA: 289f1d3
COMMITTED: NO
```

```yaml
RESULT: DESIGN_REVISION_COMPLETE
FEATURE: Add Product rebuild — mobile Design Revision 5 (cycle 5)
BRIEF_ID: 52CB4098-FF87-4B78-81DA-1104269551A1
REVISION_ID: CB4BEECA-CA9D-4F26-9464-E1B6F7C9BDCB
REVISION_NUMBER: 5
BRANCH: design-correct-addproduct-mobile
BASE_SHA: 289f1d33dcf1a2f24ead765c9e573b2f1ba1f107
HEAD_SHA: 289f1d33dcf1a2f24ead765c9e573b2f1ba1f107

OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**
  - Penpot page "Page 1" (d8ac01df-6646-81d2-8008-a366c09aa9d3) — the four boards I own:
      SM - Add Product - Unknown host - Light  6d055762-a70b-804c-8008-bf65ff750422
      SM - Add Product - Unknown host - Dark   6d055762-a70b-804c-8008-bf65e644269b
      SM - Add Product - Verified - Light      6d055762-a70b-804c-8008-bf660e124738
      SM - Add Product - Verified - Dark       6d055762-a70b-804c-8008-bf65f36b1c9a
READ_ONLY_PATHS:
  - apps/control_plane/lib/**, packages/**, apps/server/**   (design the change; never write it)
  - docs/adr/**, docs/engineering/** (outside OWNED_PATHS)
  - .decisions/**
  - Every Penpot board not one of the four above — including all six BPM and S boards
PROHIBITED_PATHS:
  - apps/control_plane/lib/**, apps/server/**, packages/**
  - docker/** (and NO Docker/Compose command was executed at all — see § 9)
  - .github/workflows/**, .decisions/**, docs/engineering/WORK_STATE.md,
    docs/engineering/dispatch/LANES.md,
    docs/engineering/dispatch/tasks/design-addproduct-keyservice/**, docs/adr/**

ARTIFACT_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-5.md            (NEW)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-metadata-5.yaml  (NEW)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/traceability-matrix-5.md        (NEW)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/correction-report-5c.md        (NEW — this file)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/penpot-board-evidence.md        (EDITED — §5/§6/§6.2/§6.3/§6.4)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-3.md            (EDITED — pointers)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-4.md            (EDITED — supersession + pointers)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-2.md            (EDITED — pointers)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision.md              (EDITED — supersession + M-1)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/report.md                       (EDITED — supersession + M-1)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-brief.md                  (EDITED — closure note, SC-6…SC-9)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-metadata-4.yaml  (EDITED — fired triggers struck, L-R1 re-measured)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/correction-report-5.md            (EDITED — header re-pin note only)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/correction-report-5-retry.md     (EDITED — header re-pin note only)

RISK_LEVEL: 3
RISK_RATIONALE: >-
  Re-derived from DESIGN_GOVERNANCE.md against what this pass actually did — not inherited, and not asserted
  on an artifact that does not exist. Three independent clauses of the Level-3 definition are met, each
  reached by my own reading: (1) CORE WORKFLOW / MENTAL MODEL — `898b07d0` splits identity from
  registration, so "Register product" changes meaning from *creates the product* to *commits verification of
  a product that already exists*, and two of four boards' eyebrow strings were rewritten for that reason;
  (2) INFORMATION ARCHITECTURE — the accepted consequence (a visible product with no usable credential)
  required a NEW user-facing element, `Trust Created`, absent from every prior revision of this design;
  (3) NAVIGATION STRUCTURE — R.11g item 3 requires the flow be re-enterable from the product, a resume
  route on ProductDetailPage that the Products list does not have.
  THE LEVEL-3 HUMAN GATE IS DISCHARGED AND MUST NOT BE RE-OPENED — re-verified directly this pass, not
  inherited: `9417f8bf`, `27ea6536`, `898b07d0`, `ae1c1f79` and `7b1bc8b7` are all `status: RESOLVED`, all
  `decided_by: "repository owner (interactive structured question UI, session orchestrator-main)"`, and all
  carry `follow_up_actions` with `owner: design-agent`. The decisions did not remove the risk; they moved it
  into this lane as a mandate. The rev-4 reviewer's 3-escalation trigger HAS FIRED and is struck in the
  revision-4 metadata so no reviewer is sent to a discharged gate.
  ONE RESIDUAL COMPONENT IS NOT HUMAN-DECIDED AND IS NOT A GATE: D-2 — the human's mobile footer spec (no
  divider, left-aligned) is not expressible with `TechnicalDetails` as built, so choosing between a new
  primitive parameter and a mobile-local footer widget is a shared-component choice at LEVEL 1, routed to
  the design-system owner as N6. The human already decided the outcome; only the mechanism is open. It does
  not raise the risk level and does not require the human.
  The rev-4 reviewer was right that revision 4's MARGINAL risk was Level 0; that is inapplicable here,
  because this pass carries board writes and Level-3 content.

CHANGELOG:
  - "revision 5 ISSUED" — design-revision-5.md, design-revision-metadata-5.yaml, traceability-matrix-5.md.
    REVISION_ID CB4BEECA-CA9D-4F26-9464-E1B6F7C9BDCB, supersedes A69AB98C (rev 4), status UNDER_REVIEW
  - "H-1(a) APPLIED" — the N-9 custody string on all four SM boards, verified by live read-back. The board
    edits were already on the file from the cancelled invocation; THIS PASS VERIFIED THEM INDEPENDENTLY AND
    ADDED NO NEW BOARD WRITE, because they were already correct
  - "H-1(b) APPLIED to the record; mobile boards already conformant" — the human's per-platform footer spec
    is now the governing specification. Measured: the mobile spec is ALREADY satisfied on all four SM boards,
    so no mobile board edit was needed. Build change specified to the line (three edits, not one)
  - "H-1(c) APPLIED" — Unknown-host pair re-grounded on `898b07d0`; new user-facing `Trust Created` element;
    the false `Trust Body 2` removed; Verified eyebrow also re-grounded. Compliance with `ae1c1f79` / R.11g
    item 5 stated explicitly
  - "M-1 APPLIED BY RE-READING" — all 13 cross-reference values re-read after every edit and exact
  - "L-1 APPLIED" — all three pointers present; the third site (G2 on the same paragraph as B3) covered
  - "ESCALATION TRIGGERS REMOVED" — both fired triggers struck in design-revision-metadata-4.yaml
  - "TWO `9417f8bf` FOLLOW-UPS SPECIFIED" — G-7 (with a measured 6-site blast radius incl. 2 UI render
    sites) and the A3 remediation path. NEITHER IMPLEMENTED: both are outside OWNED_PATHS
  - "TWO FALSE CLAIMS IN THE CANCELLED LANE'S WORK FOUND AND CORRECTED" — see § 4. F6 (desktop footer copy)
    and F7 (§6.3's two stale rows published as measured)
  - "THE SWEEP WAS INCOMPLETE AND WAS COMPLETED" — the cancelled lane pointed only rev 3. Revs 1, 2 and 4
    each still carried live "the gate is open" claims with no pointer; all are now pointed

TRACEABILITY:
  REQUIREMENTS_COVERED: [R1, R2, R3, R4, R5, R6, R7, H-1(a), H-1(b), H-1(c), M-1, L-1,
                         9417f8bf_followup_1 (specified), 9417f8bf_followup_2 (specified)]
  REQUIREMENTS_GAPS: [G13 (resume affordance specified, not rendered — ownership),
                      G14 (A3 refused-mint boards unowned — ownership), SC-9 (NOT MET, reported)]

DESIGN_SYSTEM_COMPLIANCE: PARTIAL
UX_ACCESSIBILITY_SCORE: PASS   # on the surfaces this pass touched; reasons stated, not rounded
IMPLEMENTATION_FEASIBILITY: MEDIUM   # flutter analyze NOT_RUN; no score derived from it

DISCOVERIES: [D-1…D-10 carried/confirmed, F5, F6 NEW + BLOCKER, F7 NEW, F8 NEW (pre-existing YAML defect, reported not fixed)]
KNOWLEDGE_PERSISTED: none outside this lane's own directory — see § 10
BLOCKERS: [B1 F6 desktop-board conformance — OWNERSHIP, Manager; B2 G14/SC-9 refused-mint boards —
           OWNERSHIP, Manager. Neither blocks review of this revision; both block parts of implementation]
READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES
```

---

## 1. Isolation pre-flight

```
git branch --show-current   == design-correct-addproduct-mobile   ✓
git rev-parse HEAD          == 289f1d33dcf1a2f24ead765c9e573b2f1ba1f107   ✓
git rev-parse main          == 289f1d33dcf1a2f24ead765c9e573b2f1ba1f107   ✓ (BASE == HEAD)
```

**One deviation from the dispatch's pre-flight, reported rather than glossed.** The prompt says
`git status --porcelain` *"must show ONLY the two untracked prior-attempt reports"*. It did not: it showed
**seven modified tracked files plus the two untracked reports**. That is **exactly the state the Manager's
resume note measured and described**, i.e. the cancelled lane's uncommitted in-place edits — not drift, and
not a failed pre-flight. I did not treat it as a blocker; I reconciled it (§ 3).

---

## 2. Provenance, and the base re-check the dispatch required

```
git diff --name-only 43d328b 289f1d3 -- apps/control_plane packages   == EMPTY
```

**Every `:NNN` citation into `apps/control_plane/**` in this revision was re-read at `289f1d3` and holds.**
The dispatch's caveat (two commits past `43d328b`) is discharged by measurement, not assumption:

| Citation | At `289f1d3` |
|---|---|
| custody string | `:542` = `'ed25519 · created on this device · the private half stays in the keychain'` — and **`:1038`** carries the same string, which attempt 2 did not name |
| desktop `_buildFooter` call / definition / copy | `:314` / `:375` / `:383` |
| desktop `note:` | `:317-319` |
| mobile `TechnicalDetails` + `note:` | `:925` / `:926-928` — **the same string as `:317-319`** |
| `ContentRule` | `design_primitives.dart:396` = `const ContentRule(),` — **unconditional** |
| `TechnicalDetails` constructor | `design_primitives.dart:362` — `required this.lines, this.note`; **no rule/alignment parameter** |
| `EdgeInsets.fromLTRB(20,20,20,20)` cited at rev-1 `:633` | `add_product_page.dart:633`, inside `_RightPanel` (class at `:624`) — **resolves** |

**A path correction worth recording, because three lanes in this work item have been bitten by exactly
this.** `design_primitives.dart` is at **`apps/control_plane/lib/shared/`**, not `lib/core/`. I found it with
`find`, not by assuming. **No artifact in my owned set asserted the wrong path** — checked by grep — so
nothing needed correcting; the note is here so the next lane does not repeat the search.

---

## 3. Reconciliation of the cancelled lane's in-place edits — item by item

The resume note asked me to establish what the cancelled lane actually did, not take the Manager's summary on
trust. I read the full `git diff` and re-measured every claim. **The Manager's summary was accurate on
every board claim I could check.** The reconciliation decision and its reasoning are in
`design-revision-5.md` §0.1; the short form:

**The governing rule is this lane's own, already reviewed as correct:** *byte-identical retention is
legitimate for diffability, but **retention without a marker is not neutral**.* The Gate-D3 review of
revision 4 held revision 3 against that standard and recorded *"Regression check: rev 3 is intact. Zero
body lines changed, verified"* as the **positive** result. So the operative convention is **bodies retained
intact, headers and in-place pointers corrected** — not "earlier revisions are frozen files". Reverting the
cancelled lane's edits would have reinstated the exact defect M-1 exists to close.

| Cancelled lane's edit | Verdict |
|---|---|
| M-1 line numbers in `design-revision.md`, `report.md`, `design-revision-3.md`, `design-revision-4.md` | **KEPT** — I re-read all 13 values; **all exact** |
| L-1 pointers at rev-3's G2 row, G11 row, and the B3+G2 paragraph | **KEPT** — all three present; the third is genuinely there |
| Struck escalation triggers in `metadata-4.yaml` | **KEPT** — both genuinely fired |
| `design-brief.md` closure note + SC-6…SC-9 | **KEPT** — SC-6/7/8 met and verified; **SC-9 recorded NOT MET** |
| New §6.2 / §6.3 board evidence | **KEPT BUT §6.2 and §6.3 CORRECTED** — see § 4 |
| rev-3's L-1 pointer asserting the desktop boards carry "no copy" | **KEPT BUT SUBSTANTIALLY CORRECTED** — see § 4, F6 |
| `design-revision-3.md:449-450` B3+G2 paragraph | pointer **KEPT**, and the *surrounding* sweep extended |
| — | **NEW: I added the missing in-place pointers the cancelled lane never made** — revs 1, 2 and 4 each still carried live "the gate is open" claims with no pointer (§ 6) |

**The cancellation left the pass in a state no convention covers cleanly**: edits to *four* prior revisions,
no new revision, no report. I have resolved it by (a) keeping every correct edit, (b) correcting the two
false claims in place with the correction visible, (c) completing the sweep across all four revisions, and
(d) issuing revision 5 as the governing artifact with an explicit supersession header on each retained
revision.

---

## 4. Two claims the cancelled lane got wrong — found by independent re-measurement

**This is the substantive reason not to accept a prior lane's summary.** Both were published *as measured*.

### F6 — the desktop boards DO carry footer copy. BLOCKER.

`design-revision-3.md`'s new L-1 pointer asserted *"the desktop spec matches the four `S` boards … **no
copy**"*, and added that the lane's (236,862) reading *"is WITHDRAWN as a misidentification: that position
is the `Footer Rule` **divider**, not a text layer."*

**Live read of all four `S · Add Product · …` boards — every one is identical in the footer band:**

| Layer | type | rel x, y | w × h |
|---|---|---|---|
| `Footer Rule` | rectangle | **236, 848** | 1020 × 1 |
| **`Footer`** | **text** | **236, 862** | **1020 × 15** — *"Your decision is recorded permanently. The same piece of work then continues — nothing is restarted."* |
| `Disclose` | text | 1036, 862 | 220 × 15 |

**So the divider is at (236,848) and a text layer *does* sit at (236,862).** Both halves of the assertion
are wrong. The original lane reading was **correct as an observation**; `27ea6536` overrules its
**conclusion**, and I have left the decision's outcome completely untouched. A final read-back returned
`footerCopy: 1` on **all four** `S` boards.

**Consequence:** `27ea6536`'s desktop clause *"No footer copy"* is **NOT SATISFIED** on the four desktop
boards — the divider and right-alignment clauses **are**. Those boards are the decision's own declared
authority (*"Stay true to both designs in Penpot and in code"*), so they cannot be the authority for a spec
they do not meet. `27ea6536`'s OPTION_B named this cost verbatim: *"Requires `note: null` … **and editing
the four existing desktop boards, which no current lane owns** — so it needs a design-system-owner board
edit."* **Escalated as ownership blocker B1. No `S` board was edited; their child counts (69/69/65/65) and
positions are unchanged.**

### F7 — §6.3 published two stale numbers as measured

The new §6.3 coordinate table showed `Key State = 138,436` for **all three** columns and asserted *"Every
structural coordinate matches."* Live: `BPM` is at **436**, `SM` at **446** on all four boards — because
revision 5's own edit moved it from 436 to clear `Art S`'s new bottom. The `SM` cells carried the
**pre-move** value. `Art S` also no longer matches in height (`SM` 24 / two lines vs `BPM` 15).

**A verified edit followed by an unverified claim *about* the edit is M-1 one layer up.** Corrected. **D-8's
conclusion is unchanged and does not depend on the two corrected rows** — every *structural* footer
coordinate matches exactly.

**Also corrected: §6.2's width arithmetic.** It asserted a measured `textBounds` width of 214.53px *and* a
measured 4.46px/char; at that rate 80 chars is ~357px, and 214.53px would fit on one line and need no
wrap. I could not reconcile Penpot's `textBounds` scale against `parentX` (it tracked **2×**), so **the
214.53 figure is withdrawn as evidence** and the two-line wrap is now stated as an observed layout fact
from the layer's own height.

---

## 5. Board verification — what the Manager listed, confirmed independently

All four `SM` boards, live read-back, twice (mid-pass and after all record edits). **Every Manager claim
confirmed:**

| Claim | Verified |
|---|---|
| all four read the N-9 custody string | **yes**, 80 chars, on all four |
| zero PENDING/PROVISIONAL layer names | **yes**, **0** on all four |
| Unknown: `REGISTERED · NOT YET USABLE` | **yes**, all four at 26,137 240×14 |
| Unknown: `CONFIRM THIS HOST TO FINISH REGISTERING` | **yes**, `Trust K` at 30,514 |
| Unknown: the banner | **yes**, `Trust Created` at 30,566 330×24, contained in the panel |
| Verified: `REGISTERED · READY TO REGISTER` | **yes** |
| Verified: *"Access verified — this product can be registered"* | **yes**, `Submit Sub` at 16,552 |
| board counts 44/44/36/36 top-level, 29/29/24/24 text | **yes**, exactly |
| page 160 boards / 164 root children, before **and** after | **yes**, identical — **no board created, none deleted, no stray** |
| `BPM` carries the false custody claim | **yes** — `ed25519 · private half stays in the keychain`, identical to the build's `:542`/`:1038` |
| `BPM` carries the false `NOT REGISTERED YET` eyebrow | **yes** |

**D-8 answered** (`penpot-board-evidence.md` §6.3): `SM` and `BPM` are **two states of one mobile design**,
same grammar and same scale, differing in state and in one state-dependent y. **The consequence is the
useful part: the human's mobile footer spec is ALREADY satisfied on all four `SM` boards and `BPM` agrees**,
so H-1(b) required **no mobile board edit**.

---

## 6. The sweep the cancelled lane left incomplete

H-1(a)'s sweep was incomplete: the cancelled lane pointed **revision 3 only**. I audited every site in the
owned set asserting that the gate is open or that the layer stays `PENDING D4`, and found live unpointed
claims in three more revisions:

| Site | Claim found | Action |
|---|---|---|
| `design-revision.md:367` | G2 row: *"open human decision; string marked `PENDING D4`"* | **struck in place** |
| `design-revision-2.md:607` + `:665` | B3/G2 paragraph and G2 row, with **no revision-4 pointer anywhere in the file** | **in-place pointer added**; G2 row struck |
| `design-revision-4.md:526-528` | B3 *"remains filed"* + G2 *"stays `PENDING D4` and unresolved — the open gate is `9417f8bf`"* | **in-place pointer added** |
| `design-revision-4.md:664` | G2 row: *"**open human decision `9417f8bf` (`status: PENDING`)**"* | **struck in place** |
| `design-revision-4.md:159` | the M-R3 row — *"the open gate is `9417f8bf` … `status: PENDING`"*, correct for `77c19f1` | **pointed at, not rewritten** (historical verification row) |
| `design-revision-4.md:416-424` | § 6.1: *"the open human gate `9417f8bf` (`status: PENDING`)"* and *"the human's decision has not been quietly resolved"* | **pointed at**, noting the thing it said did not happen |
| `design-revision-4.md:709-710` | risk rationale: *"`Art S` stays `PENDING D4` under open gate `9417f8bf`; … remains the human's decision at Gate D4"* | **pointed at** — false now, accurate when written |
| `design-revision-4.md:816-817` | *"Not touched, deliberately: … the `Art S` string and its `PENDING D4` marker; and **every board**"* | **pointed at** — two of those items *were* touched at revision 5 |

**Bodies retained unedited throughout.** `898b07d0`, "split identity", "half-registered" and
`RegistrationCommitState` went from **0 hits each** across the whole set to **25 / 4 / 4 / 4** — H-1(c) is
now genuinely grounded, not asserted.

---

## 7. M-1 completed, including M-1 happening to me

**All 13 published values re-read after every edit, and exact** (`design-revision-5.md` §8). The `+6`-is-a-
trap table is preserved: **+6** on the six single-line citations, **+5** on both endpoints of the provenance
note, **+8 / +8 / +13** on the three marker ranges. Revision 4's self-contradiction resolved in favour of
`31-37`, checked against the **committed blob** — which also confirmed the review's three descriptions of
rev-4-era content were accurate.

**The blanket "CONFIRMED, every number" claim is not carried forward.** The claim is exactly the per-row
table.

**And then it happened to this pass, which is the most useful thing in this report.** My §4.4 correction to
rev 3 **added 13 lines**, which invalidated:

* rev 4's L-R1 row (`:633` → **`:646`**; `:610-629` → **`:623-644`**) — corrected in rev 4 **and** in
  `metadata-4.yaml:153-154`;
* my **own** first-draft rev-5 numbers (`:570` → **`:583`**, `:579` → **`:592`**, `:452-473` → **`:452-486`**)
  — corrected before persisting;
* three citations in the **retained** attempt-1/attempt-2 reports (rev-4 `:387`→`:406`, `:623`→`:663`,
  `:507-508`→`:541`) — those two reports got a **header re-pin note; not one number in their bodies was
  rewritten.**

**Re-reading the thing you edited is necessary but not sufficient. You must also re-read anything you then
write *about* it.** That is now finding **F7** and it is in the revision.

---

## 8. The two REQUIRED `9417f8bf` follow-ups — specified, not implemented

Both are quoted from the decision file in `design-revision-5.md` §6. **Neither is implemented, and neither is
in `OWNED_PATHS`.** Both were unaddressed across the whole artifact set before this pass.

**G-7.** Blast radius **measured** at `289f1d3`: **6 sites** — the YAML source of truth
(`apps/server/lib/src/models/repository_credential_view.yaml:10-11`), **two** generated packages,
**four** projections in `control_plane_repository.dart`, and — the finding that makes this security-relevant
rather than cosmetic — **two UI render sites**, `product_detail_page.dart:471` and `:676`. Under A3 the
reference is a secret path or ARN and the decision says it *"discloses vault topology"*, **so SHIP IT is
currently showing vault topology to the user in two places.** Also found: the contract's own comments still
claim the private half is *"held locally"*, false twice over.

**A3 remediation path.** The copy already exists and is binding — the sibling's § R.5.4 specifies four
named causes verbatim (Title / Body / Action, each naming a concrete operator action and each stating that
**nothing was created**). I consumed it as normative and added the **board specification** the sibling does
not own. Contrast verified for the new strings: **6.28:1 light / 6.65:1 dark on `canvas`**, **6.74 / 6.10 on
`card`** — PASS both themes.

**Why not rendered, stated plainly.** This dispatch's `OWNED_PATHS` names **four boards by id and no more**,
and R.11g item 5 **forbids** doubling the refused-mint surface onto the Unknown-host board. Authoring new
boards on a shared design page would exceed the declared scope and repeat what this lane already has on
record — `penpot-board-evidence.md` §7 documents scratch boards created by failed API calls at revision 1
that had to be detected by inventory diff and removed. **A scope decision is the Manager's, not a
substitution this lane makes on its own.** Recorded as **SC-9 NOT MET** and gap **G14**.

---

## 9. Validation results

| Command / call | Status | Evidence |
|---|---|---|
| `git branch --show-current` | pass | `design-correct-addproduct-mobile` |
| `git rev-parse HEAD` / `main` | pass | both `289f1d3…` |
| `git status --porcelain` | **deviation, reported** | 7 modified + 2 untracked at pre-flight (§ 1) — matches the resume note exactly |
| `git diff --name-only 43d328b 289f1d3 -- apps/control_plane packages` | pass | **empty** — every `:NNN` cited holds |
| `penpot_high_level_overview` | pass | read before any other Penpot tool |
| `penpotUtils.getPages()` | pass | `["Page 1"]` |
| Board inventory before edits | pass | 160 boards / 164 root children |
| Board inventory after edits | pass | **160 / 164, identical** — no board created, deleted or renamed |
| 4 × `SM` board identity / size | pass | exact names, exact ids, **390×844** |
| 4 × `SM` custody string | pass | N-9 string, 80 chars, all four |
| 4 × `SM` forbidden layer names | pass | **0** for `PENDING D4` / `PROVISIONAL` |
| 4 × `SM` forbidden text | pass | **0** for all ten strings |
| `Trust Created` containment + nav collision | pass | contained in `Trust Bg`; zero collisions |
| 6 × read-only board integrity | pass | `BPM` 36 children ×2; `S` 69/69/65/65 — all positions unchanged |
| `S` board footer-copy count | pass | **1 on all four** — F6 confirmed |
| M-1 values (13) | pass | all re-read after every edit, exact |
| L-1 pointers (3) | pass | all present |
| Contrast recomputation | pass | sanity-checked 21.00 / 1.00; all four touched layers ≥ 4.5:1 both themes |
| **Any Docker or Compose command, incl. `info`/`ps`/`logs`/`config`** | **NOT_RUN** | **none issued. No breach.** `AGENTS.md` § *Shared Docker state* honoured |
| `flutter analyze` | **NOT_RUN** | requires `flutter pub get`, outside read-only scope; `.dart_tool/` absent |
| Flutter widget render / pixel diff | **NOT_RUN** | — |
| Pre-edit board state | **NOT_REVERIFIABLE** | Penpot exposes no version history; every "before" is a recorded rev-2-era value |
| Penpot `textBounds` pixel units | **NOT_RECONCILABLE** | tracked 2× `parentX`; 214.53 figure **withdrawn** |
| Commit / push | **NOT_RUN** | forbidden by the dispatch |
| Boards created | **0** | no scratch board; `strays: []` |

**No gate is claimed as passed that did not run. No board-read claim is made that I did not make. No line
number is asserted as re-read that I did not re-read.**

---

## 10. Documentation and learning

**Written:** `design-revision-5.md`, `design-revision-metadata-5.yaml`, `traceability-matrix-5.md`,
`correction-report-5c.md` (this file). **Edited:** 10 files, all inside `OWNED_PATHS` (§ ARTIFACT_PATHS).

**Persisted outside this directory: nothing.** Per `aef-repository-learning`, classified discoveries are
reported, not written, where the authority is above this lane:

| Discovery | Category | Authority | Routed |
|---|---|---|---|
| custody copy is security copy, not a Level-0 detail | `DESIGN_DISCOVERY` | automatic (in-lane) | §3.5 of rev 5 |
| `referenceName` is **rendered in the UI** at two sites, so G-7 is security-relevant | `DESIGN_DISCOVERY` | automatic (in-lane) | N6a |
| contract comments claim the private half is "held locally" | `DESIGN_DISCOVERY` | automatic (in-lane) | N6a |
| `27ea6536`'s normative outcome vs the boards it declares authoritative | **`CONTRADICTION`** | **human/governance** | **B1 — escalated, not reconciled** |
| `N-9`'s rule contradicts its own prescribed string | **`CONTRADICTION`** | sibling lane | N6e |
| "no footer copy" is two `note:` sites — this lane's records repeated the false claim | `CONTRADICTION` | in-lane + sibling | §4.2, N6d |
| a verified edit followed by an unverified table about it | `WORKFLOW_IMPROVEMENT` / `AUTOMATION_OPPORTUNITY` | independent review | **F7** — candidate: a checker that re-reads every `:NNN` in the owned set after the last write |

The **last row is the one worth a follow-up lane**: in this work item a stale-number defect has now been
caught three times by hand (rev 4's M-1, the cancelled lane's §6.3, and this pass's own correction). It is
mechanically checkable — grep every `:NNN` in the owned set and confirm the target line — and it should be.

---

## 11. Unresolved issues and blockers

1. **B1 — F6, the four desktop boards do not conform to the resolved footer spec.** **Ownership, Manager.**
   All four `S` boards carry a `Footer` copy layer at rel 236,862. Closing it is a board edit on four
   **read-only** boards, and no lane owns them. `27ea6536`'s outcome is **not** in question and is **not**
   re-opened — only the board edit is unowned. **Not a human decision; nobody needs to re-decide anything.**
2. **B2 — G14 / SC-9, the A3 refused-mint surface needs two boards this lane does not own.** **Ownership,
   Manager.** Copy and layout fully specified (§6.2); only a board owner is missing. R.11g item 5 forbids
   folding it onto the Unknown-host board.
3. **G13 — R.11g item 3's resume affordance on `ProductDetailPage`** specified, not rendered. **Ownership.**
4. **For the keys lane / implementer:** N6a (G-7 is REQUIRED, 6 sites, 2 of them UI), N6d (two `note:`
   sites), N6e (`N-9`'s tension).
5. **For the design-system owner, Level 1:** **N6 / D-2** — `TechnicalDetails` must be able to suppress its
   `ContentRule` and align its disclosure start-aligned. F4 is now a **specified requirement**, not an
   observation. **The human decided the outcome; this is not a gate.**
6. **No Human Decision is needed from this lane.** All five relevant decisions are RESOLVED and name
   `design-agent`. `27ea6536` must **not** be re-raised, and B2/N1, B4/N2, N4/G9, N6, N10 are not re-raised.
7. **Pre-existing, carried:** D-10's contract comments, the build's custody string at `:542`/`:1038`,
   `BPM`'s false custody string and eyebrow (F5), the `inkTertiary`-on-`card` AA FAIL (N10).

---

## 12. Safe parallelism

```yaml
SAFE_PARALLEL_WORK:
  - The keys lane's independent review — disjoint paths; its revision 5 is on this base and its § R.11g line
    numbers were independently re-verified here (all six hold)
  - Non-UI implementation prep on add_product_page.dart: custody string at :542 AND :1038, note: null at
    :317 and :926, delete _buildFooter (:375 / :314) — every number re-read at 289f1d3
  - G-7's contract change (N6a) — disjoint from this lane's paths
  - ADR 0018's A2 amendment recording the 9417f8bf supersession (owner: human / ADR owner)
PROHIBITED_PARALLEL_WORK:
  - Design Contract freeze of revision 4 — four boards changed, one design-system requirement unsatisfied
    (D-2), four desktop boards non-conformant (F6)
  - Any lane editing this lane's task directory, the four SM boards, or any BPM/S board
  - Any lane editing .decisions/**
  - Implementation of the footer or the custody copy against revision 4's spec — superseded
  - Rendering the refused-mint surface on the Unknown-host board — forbidden by R.11g item 5
```

---

## 13. Cleanup confirmation

- [x] **No Docker or Compose command issued at any point, including read-only ones.** No breach.
- [x] No processes started by this lane remain running. No port or PID left open.
- [x] **No Penpot board created, deleted or renamed. 160 boards / 164 root children before and after — no
      scratch board left on the page.** Only the four owned `SM` boards were editable, and **this pass made
      no new board write** — it verified the cancelled lane's edits and corrected the records.
- [x] **No `BPM` or `S` board edited** — child counts and positions re-read unchanged (36/36; 69/69/65/65).
- [x] `git diff --name-only` touches **only** `design-addproduct-mobile/` — verified, no breach.
- [x] `.decisions/**`, `WORK_STATE.md`, `LANES.md`, `docs/adr/**` and the keys lane's directory: **untouched**
      — verified.
- [x] Nothing committed, nothing pushed.

---

## 14. Recommended next action

**`DESIGN_REVIEW` (Gate D3).** Revision 5 is issued, internally consistent, and every load-bearing claim is
either a live board read-back or a source line I re-read. **Two ownership questions are for the Manager, not
for a reviewer and not for the human: B1 (who edits the four desktop `S` boards) and B2 (who authors the two
refused-mint boards).** Neither blocks review of this revision; both block *implementation* of the parts they
cover.

**I do not approve this work. It goes to independent design review, and the Design Contract must not be
frozen against revision 4.**