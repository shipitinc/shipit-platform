# Design Revision 4 — Add Product mobile boards, correction pass 3 after the Gate D3 re-review of revision 3

Per `docs/engineering/DESIGN_GOVERNANCE.md` § *Artifacts → Design Revision*. Metadata in
`design-revision-metadata-4.yaml`. **SUPERSEDED BY REVISION 5** (`design-revision-5.md` /
`design-revision-metadata-5.yaml`), which changed **four live Penpot boards** — this pass changed none.
**Revisions 1, 2 and 3 are retained** as `design-revision.md`, `design-revision-2.md` and
`design-revision-3.md`; each retained file carries a **supersession header** naming the claims the current
revision overturns (§ 7.1), and revision 5 additionally corrects this file's own § 0.1 numbers.

**This pass changed no board** — revision 5 did. Every correction here is to a record. Revision 3's substantive text is carried
forward unchanged except where § 14 lists a correction; the four corrections are in § 3.2, § 6, § 8, § 11 and
§ 14.

```yaml
revision_id: A69AB98C-A672-4D98-9DCE-0F089D55A9B5
brief_id:    52CB4098-FF87-4B78-81DA-1104269551A1
revision_number: 4
supersedes:  B5006A15-2DEE-47BE-BF2F-C44196B089E3   # revision 3, retained intact
status: UNDER_REVIEW          # the Design Agent never approves its own work
```

Provenance — worktree `/private/tmp/shipit-correct-addproduct-mobile`, branch
**`design-correct-addproduct-mobile`** (`git branch --show-current`, `git worktree list`), `BASE_SHA` =
`HEAD_SHA` = `77c19f114ee691e8c434afe37b7c84494b66dc40`. Nothing committed, nothing pushed.
**No Docker or Compose command was run at any point in this lane**, including read-only ones.
`flutter analyze` **NOT_RUN**; no Flutter widget rendered; the Penpot file was read read-only.

---

## 0. What this pass is, and the one sentence it exists to enforce

Revision 3 was returned `DESIGN_REVIEW_CHANGES_REQUIRED` with **zero BLOCKERS and zero HIGH**. All four
items were **record corrections inside `OWNED_PATHS` requiring zero board edits and zero new design
judgment**. The reviewer refused to record them as non-blocking follow-ups for one reason, quoted:

> this revision's own words currently make it unsafe to freeze: it annotates away an AA failure that its
> own ledger marks `FAIL` and that its own boards draw, and the matrix that `DESIGN_GOVERNANCE` invariant 8
> makes mandatory names the wrong foreground token for the primary action's helper. Freezing that hands
> implementation and QA a wrong acceptance baseline.

**An AA verdict must name the surface it was measured on, or it does not exist.** Revision 3's ledger
carried an `inkTertiary`-on-`card` row at 4.99:1 / **4.23:1 FAIL** and annotated it *"now unused on these
boards"* — an assertion about the boards that **nobody had checked**, and which is **false**: `Art K` is
exactly such a call site, on all four boards. That annotation converts a known defect into an invisible one,
which is worse than reporting it.

**Correction applied here (M-R1, § 3.2):** the annotation is deleted, the row's Note now names the call
site, reason (c) is added to `ux_accessibility_score_reason`, and **N10** is filed with the design-system
owner — the same routing N2 already records for `negative`.

---

## 0.1 Revision 3's own false claim, re-corrected (line numbers, M-N6 / L-R3)

Revision 3's `design-revision-3.md:29` and its metadata asserted the "36px" claim *"survives verbatim at
`design-revision.md:70`, `:72-73`, `report.md:48`, `report.md:197` and `design-revision-metadata.yaml:15-16`"*.

**`design-revision-metadata.yaml:15-16` is correct. Every other citation in that sentence is stale**, because
revision 3's own withdrawal markers were inserted at those very sites and shifted them:

| Revision 3 cited | "Actually at (revision 4)" | **Actually at (revision 5, re-read)** | What moved it |
|---|---|---|---|
| `design-revision.md:70`, `:72-73` | `:77` and `:79` (marker at `:83-89`) | **`:83`** (the `total` row) and **`:85`** (the "collapses ≈50px" sentence); marker block **`:89-95`** | the marker block inserted at `:89` |
| `design-revision.md:414` (F8 row) | `:429` (marker at `:431-438`) | **`:435`** (marker **`:437-444`**) | the same insertions |
| `report.md:48` | `:62` (marker at `:64-68`) | **`:68`** (marker **`:70-74`**) | revision 3's `report.md` supersession header |
| `report.md:100` | `:120` (marker at `:122-…`) | **`:126`** (marker **`:128-133`**) | same |
| `report.md:197` | `:224` (marker at `:231-…`) | **`:230`** (marker **`:237-243`**) | same |
| `design-revision.md:6` "lines 70 and 72-73" | `:77` and `:79` | **`:83`** and **`:85`** | the header's own claim, also stale — twice |
| `design-revision.md:7` "line 414" | `:429` | **`:435`** | the header's own claim, also stale — twice |
| `report.md:7` "line ~100", "lines ~48 and ~197" | `:120`, `:62` and `:224` | **`:126`**, **`:68`** and **`:230`** | the header's own claims, also stale — twice |
| `report.md:8` "see the marker at line ~13" | the provenance note is at `report.md:26-31` | **`:31-37`** | same |

**Revision 4's middle column was wrong, and revision 4 said so about itself in the wrong direction.**
`report.md:12` already published `lines 31-37` for the provenance note, while this table's last row
published `26-31` — the self-contradiction the Gate-D3 review of revision 4 charged, and it is now
resolved in favour of `31-37`, which is where the note actually is.

**No uniform offset repairs this column, and the "+6" rule is a trap.** Re-measured per site at `289f1d3`:

| Item | Δ from the cited number | Why it is not +6 |
|---|---|---|
| the six single-line claim citations | **+6** | — |
| the provenance note (`26-31` → `31-37`) | **+5** on **both** endpoints | a note, not a table row |
| the three marker **ranges** | **+8**, **+8**, **+13** | a range has two endpoints, and the block was *lengthened* by the marker, not merely shifted |

Anyone applying +6 mechanically would have fixed six numbers and **broken three**. Every number in the
right-hand column was obtained by reading the live file after the edit, because a marker written at a
cited line moves that line — the exact rule revision 4 wrote in § 12.1 rule 6 and then broke.
**The markers are unambiguous about *what* is withdrawn; the numbers no longer resolved.** Corrected here,
in revision 4, in the two retained headers this lane owns (`design-revision.md:3-7`, `report.md:3-8`),
in `design-revision-3.md`'s re-published pointer, and again in `design-revision-5.md`, with in-place
pointers left rather than body text rewritten. Retention is not neutral — but neither is rewriting
history to make a stale citation look right.

**The lesson is persisted** (`design-revision-3.md` §0 **and §12**; classified `WORKFLOW_IMPROVEMENT`
entries at `correction-report-3.md:261-281`): byte-identical retention silently resurrects a disproven claim
for whoever opens the file first, **and a marker inserted at a cited site invalidates the citation to it**.
Both halves of that sentence are the same rule: *the number in a cross-reference is a claim about a file,
and must be re-read like one.*

---

## 1. Independent verification of every dispatched finding — revision 3's pass, retained

> **Retained as revision 3 wrote it.** The table below is the verification of the *revision 2* dispatch and
> is carried forward unchanged; it is *not* this pass's verification. This pass's is **§ 1.2**.

Every finding was re-checked against source at `77c19f1` and against the live Penpot file before I acted.
Nothing was applied on the dispatch's authority alone. **One dispatched item is partly wrong (§ 1.1).**

| Finding | Dispatched claim | My independent verification |
|---|---|---|
| **H-N1** | `Trust Btn L` is `align: left`, 0px inset; desktop `Host Btn L` is `align: center` | **CONFIRMED exactly.** Mobile `Trust Btn L`: `align: left`, `growType: fixed`, box x=30 w=180, rendered width **79.266**, so the glyph inset is **0px**. `Trust Btn` rect is x=30 w=180 → the label box's left edge *is* the button's left edge. Desktop `Host Btn L` on **both** `S · Add Product · Unknown host · Light` and `· Dark`: `align: center`, same 180-wide box at x=254, rendered width 79.258 → inset **50.371px**. My own `Submit L` is also `align: center`. So the mobile boards were the single place in the set that diverged from both the desktop pattern and the primitive. |
| **M-N1** | the desktop `TechnicalDetails` is also on `canvas`; no `card` surface lies under the expanded lines on either platform | **CONFIRMED exactly, and it is worse than the review states for my own ledger.** `add_product_page.dart:316`'s `TechnicalDetails` is a direct child of the desktop page `Column` (inside `SingleChildScrollView` → `Padding` → `Column`), a **sibling** of the `Row` at `:303-311` that carries `_RightPanel`; `_RightPanel` is the `DesignPanel` (`:632`) and contains only "What happens next", "Registering is not governing.", two `ContentRule`s, the four `_StepText`s and the `FilledButton`. `scaffoldBackgroundColor: palette.canvas` (`core/theme.dart:23`). Mobile `TechnicalDetails` at `:925` sits **outside** the `DesignPanel` at `:853`. So the surface is `canvas` on both platforms, and revision 2's `card` row described a surface that does not exist beneath these lines on any platform. |
| **M-N2** | revision 2 has no matrix of its own; revision 1's carries three wrong rows | **CONFIRMED exactly.** `design-revision.md:325` `Art T` → "`bodySmall` w600"; `:335` `Bottom Nav` → `inkQuiet`/`inkPrimary`; `:330` `Trust K/Body/Body 2/Host` → no foreground token. A corrected matrix is added in § 5. |
| **M-N3** | `penpot-board-evidence.md` publishes `42/42/34/34`, a bare `Register product` count of `1`, and §3/§5 text that predates the last pass | **CONFIRMED exactly.** Live top-level layer counts are `44/44/36/36`; live text-layer counts are `29/29/24/24`; under revision 2's own substring rule the Unknown boards' `Register product` count is **2**. Regenerated in § 6. |
| **M-N4** | `Nav Label 3` is w400 where `mobile_chrome.dart:297` renders the active label at `w600`; the "clone of a PROHIBITED board" reason does not hold | **CONFIRMED exactly.** `Nav Label 3` ("Products") was 10/400 on all four boards while the other four were also 10/400 — the active tab was indistinguishable by weight, and its fill (`#1f2120`/`#f5f4f0`) is `inkPrimary`, i.e. it is the active tab. `mobile_chrome.dart:296-298` is `navLabelMobile.copyWith(fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: tone)`, and `navLabelMobile` is 10px (`design_tokens.dart:500`). **The review is right that my stated reason does not hold**: the four boards I own and everything inside them are in scope, and § 2's own resolution of `microLabel` tracking ("my boards follow the token; the reference board is low-fidelity here") applies verbatim here. |
| **M-N5** | `FilledButton` receives `onPressed: null` when `canRegister == false`, `core/theme.dart:67-83` sets only enabled colours, so M3 disabled defaults apply and the button will not paint the accent at opacity 1 | **CONFIRMED — and I derived the exact resolved colours from the Flutter 3.44.7 source rather than assuming them (§ 5.1).** `add_product_page.dart:906` and `:679` both pass `null` when `canRegister == false`; `core/theme.dart:67-83` sets no `disabledBackgroundColor`/`disabledForegroundColor` (grep for both: **no match** in the file). The resolution chain is in § 5.1 and is worth stating because the obvious reading is wrong. |
| **M-N6** | the "deleted from § 2a / risk_rationale / report.md" claim is false | **CONFIRMED.** See § 0. |
| **L-N1** | F8's false "no `500` weight" claim survives verbatim and un-marked at `design-revision.md:414` and `report.md:100` | **CONFIRMED verbatim** at both sites. Withdrawal markers applied (§ 7.1). |
| **L-N3** | `navLabelMobile.copyWith(`'s `fontWeight:` is `:297`; `class MobilePrimaryButton` is `:425`; `design_primitives.dart:320`/`:391` need the `apps/control_plane/lib/shared/` directory | **Two of three confirmed, one is wrong — see § 1.1.** `mobile_chrome.dart:297` is correct (`:296` is the `.copyWith(` line) and `design_primitives.dart` does live at `apps/control_plane/lib/shared/design_primitives.dart` (`find` confirms exactly one such file). **`class MobilePrimaryButton` is at `:424`, not `:425`**: `:422-423` are its two-line doc comment. Revision 2 cited `:424`, which was already right. |
| **L-N4** | the published "24 / 24 / 19 / 19" text-layer counts are wrong and carry no rule | **CONFIRMED.** Live is **29 / 29 / 24 / 24** on all four boards. The published figures are reproducible only by excluding the five `Nav Label` layers while still counting the `Nav Badge` text layer. § 6 publishes the live counts **with the counting rule stated**. |
| **L-N2** | the branch is `design-correct-addproduct-mobile`, recorded wrongly in three artifacts | **CONFIRMED.** `git branch --show-current` and `git worktree list` both give `design-correct-addproduct-mobile`. Corrected everywhere I write (§ 7.2). |

### 1.1 One dispatched premise I have to correct

**L-N3's second item is wrong.** It states that `class MobilePrimaryButton` is at `mobile_chrome.dart:425`
and that "`:424` is its doc comment". `grep -n` returns:

```
296:              style: ShipItType.navLabelMobile.copyWith(
297:                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
424:class MobilePrimaryButton extends StatelessWidget {
425:  const MobilePrimaryButton({
```

`:422-423` is the doc comment (two lines: *"A full-width primary action, as used at the foot of every
mobile card and / detail screen."*). **`:424` was already correct in revision 2** and I have left it at
`:424`. The review's "off by one" is its own. I record it because applying it would have introduced an
off-by-one into a document whose entire purpose is to stop off-by-ones — and because the same L-N3 item
correctly identifies two real errors, which is exactly the case where an unchecked "fix" does damage.

**This is the second time in two passes that a dispatched premise has been wrong** (the first: "both
desktop boards draw 13/600" — they draw 12/600). Both times the correction was in the reviewer's favour on
substantive and wrong on one detail. The rule that follows is the one I should have applied throughout: a
finding is a set of claims, and each claim gets checked.

### 1.2 Cycle-4 verification — every finding dispatched against revision 3, re-checked from source and the live file

Nothing below was applied on the dispatch's authority alone. Contrast was recomputed from
`design_tokens.dart:91-130` by script (WCAG 2.1, sanity-checked at black-on-white **21.00** and
white-on-white **1.00**). The Penpot file was read **read-only**: `penpot_execute_code` returning data, zero
writes, zero board edits.

| Finding | Dispatched claim | My independent verification |
|---|---|---|
| **M-R1** | `DesignPanel` = `palette.card`; the `DEPLOY KEY · THIS PRODUCT ONLY` `MicroLabel` is `palette.inkTertiary` at `add_product_page.dart:533` / `:1029`, inside `DesignPanel(` at `:503` / `:1002`; `Art K` is the only `inkTertiary` text on `card`; the "now unused on these boards" annotation is therefore false | **CONFIRMED on all six claims.** `design_primitives.dart:318-320` — `DecoratedBox(… color: palette.card …)`, so `DesignPanel` = `card`. `add_product_page.dart:531-534` and `:1027-1030` — both `MicroLabel('DEPLOY KEY  ·  THIS PRODUCT ONLY', color: palette.inkTertiary)`, the colour line at **`:533`** and **`:1029`**, each inside a `DesignPanel(` opened at **`:503`** and **`:1002`**. Live board read: `Art K` = `#6e706e` / `#8a8983` = `inkTertiary`, inside `Art Bg` = `#ffffff` / `#262827` = `card`, **all four boards**; `Art Bg` spans y 11120–11236 (Light) / 10170–10286 (Dark) and `Art K` sits inside it. A subtree sweep of **every** `type === 'text'` layer against every `#ffffff`/`#262827` rect returns **`Art K` as the only `inkTertiary` layer on `card`** — `Status` and `F K 0/1/2` are `inkTertiary` but sit on the board's own fill, `#f7f7f5` / `#1f2120` = `canvas`. Contrast recomputed: **4.99:1 light, 4.23:1 dark → PASS / FAIL**. **The annotation was false and the boards were right.** |
| **M-R2** | the matrix names `inkSecondary` for the `Submit Sub` helper; the build uses `palette.inkTertiary` at `add_product_page.dart:918`; board surface is `canvas`, code surface is `card` (inside `DesignPanel(` at `:853`); `Submit Sub` is at y 11470–11485 and `Trust Bg` ends at 11412 | **CONFIRMED on all claims.** `:913-920` — `Text(_registerButtonSubtext(state), style: ShipItType.monoMeta.copyWith(fontSize: 10, color: palette.inkTertiary))`, inside the `DesignPanel(` at **`:853`**. Live board read: `Submit Sub · helper BELOW button` = `#5a5c5b` / `#a8a6a0` = **`inkSecondary`** on all four boards; its bounds on the Unknown-Light board are y **11470–11485**, and the two `card`-coloured rects there are `Art Bg` (11120–11236) and `Trust Bg` (11252–**11412**) — so the helper is **outside every panel** and sits on the board's own fill `#f7f7f5` / `#1f2120` = **`canvas`**. Recomputed for `inkTertiary`: **4.65:1 light / 4.62:1 dark on `canvas` (pass)**, **4.99:1 light / 4.23:1 dark on `card` (FAIL in dark)** — the compounding the reviewer describes. (For completeness: the board's `inkSecondary` on `canvas` is 6.28 / 6.65, pass both.) |
| **M-R3** | `b869ec24` is `RESOLVED` and asks *where* deploy-key generation and storage belongs; the open gate is `.decisions/9417f8bf-73b8-4827-9515-bdfe92e5a9d5.yaml`, `status: PENDING`, *"Which substrate holds the server-stored private half of a product's deploy key?"*; revision 3 and its metadata cite `9417f8bf` **zero** times | **CONFIRMED, with one provenance fact the dispatch did not state.** `b869ec24` — `status: RESOLVED`, `type: ARCHITECTURE`, question *"Where does deploy-key generation and storage belong, given that SHIP IT pushes from its backend and not from the web browser?"* → it settles **where**, not the at-rest substrate. `9417f8bf` — `status: PENDING`, `type: SECURITY`, question verbatim as dispatched, and its own `context.summary` records the human's reservation: *"I have NOT approved the at-rest protection model for the server-stored private half. Surface it as a decision at Gate D4; do not default it."* `grep -c 9417f8bf` on `design-revision-3.md`, `design-revision-metadata-3.yaml`, `penpot-board-evidence.md` and `correction-report-3.md` = **0 / 0 / 0 / 0**. **The layer name, §8, §11's G2 and the metadata all keep `Art S` `PENDING D4` — the human's decision has NOT been quietly resolved; the defect is confined to one matrix cell.** ⚠️ `9417f8bf` is **not present at this worktree's HEAD `77c19f1`** — `.decisions/` holds six files there. It was filed in commit **`064703d`** (*"five Gate D4 decisions filed"*, child of `77c19f1`) and is readable at the canonical checkout. Recorded in the metadata's provenance; revision 3 already cites `27ea6536` on the same footing. |
| **L-R1** | `design-revision-3.md:37` persists the `WORKFLOW_IMPROVEMENT` lesson to "§ 13", which is *Assumptions carried forward* and contains no learning; the lesson is in §0 and §12, classified at `correction-report-3.md:261-278` | **CONFIRMED.** `grep -n '^## ' design-revision-3.md` → **`:646 ## 13. Assumptions carried forward`** (A1–A6 only). The lesson text is at `design-revision-3.md:60-62` (inside §0) and **`:623-644`** (§12, heading at `:623`). *(Revision 4 measured `:633` and `:610-629`; revision 5's own §4.4 correction to rev 3 added **13 lines** above these sites, so revision 4's corrected numbers have themselves gone stale. Re-measured at `289f1d3`; the range end-points re-confirmed at `16cd497` by revision 6, **MR5-4**.)* The classified entries run **`:261-281`** (four `WORKFLOW_IMPROVEMENT / REUSABLE / independent-review` items at 261, 267, 274 and 278) — the dispatch's `261-278` names the start of the fourth; `:281` is its last line. Corrected cross-reference below. **All four numbers re-read at revision 5 (§ M-1): revision 4's `:558`, `:37-39` and `:535-554` were each wrong — `:37` is a code fence, and the first two shifted under revision 5's own L-1 pointers.** |
| **L-R2** | `docs/engineering/dispatch/tasks/design-review-addproduct-mobile/report.md` now exists (commit `25f723d`), is revision 1's review, and its own header says *"This file is the authoritative copy; the correction lane's G11 is now closed"*; §11 and the metadata still list G11 as an open gap | **CONFIRMED by reading the canonical checkout read-only.** The file exists; header lines 5–11 carry the persistence note and the quoted sentence verbatim. `git log --all --oneline` → **`25f723d` docs(review): persist the mobile Gate D3 review that ran but was never written**. §11's G11 row and `design-revision-metadata-3.yaml:196-198` both still carry it as open. Closed below. **Provenance fact:** the file does not exist *in this worktree* — the worktree's HEAD is `77c19f1`, one commit before `25f723d`; it was read at the canonical checkout at `3a87e27`. |
| **L-R3** | the withdrawal markers invalidated their own line citations: `design-revision.md:70`/`:72-73`/`:414` and `report.md:48`/`:100`/`:197` no longer resolve; `design-revision.md:7` states "line 414" flatly | **CONFIRMED, every number, and the true sites are in § 0.1's table.** Verified by reading the marked files: the 36px claim is at `design-revision.md:77`/`:79` (marker `:83-89`), F8 at `:429` (marker `:431-438`); `report.md:62` (marker `:64-68`), `:120` (marker `:122-…`), `:224` (marker `:231-…`). `design-revision-metadata.yaml:15-16` is **still correct** and is left as it stands. |
| **L-R4** *(record only, not a finding)* | `MobilePrimaryButton` is at `:902` (rev-3 says `:904-911`); `FilledButton` at `:678` (rev-3 says `:679`, which is the `onPressed:` line); `defaultColor` at `:267-274` (cited `:266-273`); `effectiveValue` at `:382-387` (cited `:381-391`) | **CONFIRMED; every load-bearing citation is EXACT, as the dispatch says.** `grep -n` gives `902: MobilePrimaryButton(`, `678: child: FilledButton(`, `679: onPressed: state.canRegister …`, `:853: DesignPanel(`. Flutter 3.44.7 `button_style_button.dart`: `266 static WidgetStateProperty<Color?>? defaultColor(` … `274 }`, and `382 T? effectiveValue<T>(…) {` … `387 }` — so `:266-274` and `:382-387` are the exact spans. `:679` is correct *as the `onPressed:` citation* and `:678` is correct *as the widget citation*; both are now written, labelled, so neither can be misread again. Fixed as instructed; **not** recorded as a finding. |

---

## 2. H-N1 — `Trust Btn L` centred (a defect this lane introduced) — **revision 3's, retained**

> Revision 4 changed no board. This section is the record of the board correction revision 3 made; it is
> retained unchanged so the board's history stays diffable.

`Trust Btn L` set `align: left` in a 180-wide box at x=30, and `Trust Btn` is a 180-wide rect at x=30 —
so the label's left edge coincided with the button's left edge and the glyphs rendered at the button's
border, **0px inset**. Revision 2's §8 L-R5 and N8 dismissed this as "faithfully copying the desktop
board's identical `Host Btn`/`Host Btn L` pattern, where `Host Btn L` is at x=254". **That comparison
compared box `x` while ignoring `align`, and it was false.** Both desktop `Host Btn L` layers are
`align: center`.

| | Was | Now |
|---|---|---|
| `Trust Btn L` `align` | `left` | **`center`** |
| glyph inset from the button's left edge | **0px** | **50.367px** = (180 − 79.266) / 2 |
| desktop `Host Btn L` for comparison | — | `center`, 50.371px inset |
| this lane's own `Submit L` | — | `center` (unchanged) |

Applied to **both** Unknown-host boards. Box position, size, weight (12/600) and fill are unchanged; only
`align` moved. `FilledButton` centres its label and so does `MobilePrimaryButton`; the flush-left label
was wrong on the primitive's own terms, before any comparison to the desktop boards.

**N8 is withdrawn and replaced (§ 8).** It told the design-system owner that this "copies the desktop
`Host Btn L` pattern at x=254". Left uncorrected, that notification would have caused a real defect to be
deliberately preserved.

---

## 3. M-N1 — the expanded `TechnicalDetails` lines sit on `canvas` on **both** platforms

Revision 2's §5 published two ledger rows: `canvas` for mobile at 4.65/4.62 (pass) and `card` for desktop
at 4.99/4.23 (fail). **The second row describes a surface that does not exist beneath these lines on any
platform.** The desktop `TechnicalDetails` (`:316`) is a sibling of the `Row` carrying `_RightPanel`, not
a child of it; `_RightPanel` is the `DesignPanel` = `palette.card` and holds only the panel's own content.
The reviewer's mobile conclusion was right and its desktop correction is right; my attribution of 4.23:1
to the desktop `_RightPanel` was not.

### 3.1 The collapsed ledger row

Re-measured from `design_tokens.dart:99-101` / `:120-122` with a WCAG 2.1 implementation sanity-checked at
black-on-white = **21.00** and white-on-white = **1.00**:

| Foreground | Background | Light | Dark | AA (≥4.5:1) | Platform |
|---|---|---|---|---|---|
| `inkTertiary` | **`canvas`** | **4.65:1** | **4.62:1** | **pass / pass** | **both** — `add_product_page.dart:316` (desktop) and `:925` (mobile), both direct children of the page `Column` |

So the expanded lines **pass AA in both themes on both platforms**, and no token change is warranted
anywhere. Every other revision-2 ledger figure reproduced exactly on re-measurement (§ 3.2).

### 3.2 Full ledger — re-measured in revision 3, **re-measured again in revision 4**

> Every figure below was recomputed this pass from `design_tokens.dart:91-130` and reproduced to two
> decimals (§ 1.2, M-R1). Revision 4 changed **one** row of this table — the `inkTertiary`/`card` row, whose
> "now unused on these boards" annotation was false (M-R1). Every other row is revision 3's.

| Foreground | Background | Light | Dark | AA | Note |
|---|---|---|---|---|---|
| `inkSecondary` | `card` | 6.74:1 | 6.10:1 | pass / pass | helper, `Trust Host`, `Art S` |
| `inkTertiary` | `card` | 4.99:1 | **4.23:1** | pass / **FAIL** | **`Art K` (`DEPLOY KEY · THIS PRODUCT ONLY`), inside `Art Bg` = `DesignPanel` = card, all four boards; board and build agree — AA FAIL in dark** (M-R1, N10) |
| `inkPrimary` | `card` | 16.20:1 | 13.48:1 | pass / pass | |
| `inkTertiary` | **`canvas`** | **4.65:1** | **4.62:1** | **pass / pass** | **expanded `TechnicalDetails` — both platforms** |
| `inkQuiet` | `rail` | 4.60:1 | 4.57:1 | pass / pass | **light** nav label |
| `inkTertiary` | `rail` | 4.33:1 | 4.88:1 | **FAIL** / pass | **dark** nav label |
| `inkPrimary` | `rail` | 14.06:1 | 15.57:1 | pass / pass | active nav label (after M-N4) |
| `#241a02` | `attentionTick` | 8.42:1 | 8.42:1 | pass / pass | `Nav Badge` numeral |
| `#ffffff` | `accent` | 5.27:1 | 2.99:1 | pass / **FAIL** | enabled `Register` label, light |
| `#06121f` | `accent` | 3.58:1 | 6.30:1 | **FAIL** / pass | enabled `Register` label, dark |
| `inkPrimary@38%` on `inkPrimary@12%`/`card` | — | **2.22:1** | **2.78:1** | n/a — see § 5.1 | **disabled `Register` label** |

**N7 is withdrawn — for the `TechnicalDetails` lines only.** It escalated to the design-system owner a
desktop AA failure "on `card`" that Add Product does not exhibit on any platform. The `inkTertiary`-on-`card`
failure is real and remains in the ledger as a *different* row, and for these lines it is true that no Add
Product call site puts them on `card` — so it is not Add Product's finding to raise.

> **M-R1 correction (this pass).** Revision 3 stated that withdrawal reason **as a general claim**, and it is
> **false once generalised**: `Art K` *is* an Add Product call site that puts `inkTertiary` on `card`, on all
> four boards, at **4.23:1 in dark**. The withdrawal of N7 stands for the `TechnicalDetails` lines; it is
> **not** a statement that no Add Product call site puts `inkTertiary` on `card`. The live failure is now
> recorded as **N10**, and the ledger row above no longer carries the annotation that hid it.

### 3.3 A surface mismatch this exercise exposed (**G12** — raised in revision 3)

Verifying M-N1 forced me to read what the `Register` button actually sits on, and the answer contradicts
the boards in a way nothing in revisions 1 or 2 recorded:

- **Mobile:** `MobilePrimaryButton` (`:902-911`) is **inside** the `DesignPanel` opened at `:853`, which
  is `palette.card` (`apps/control_plane/lib/shared/design_primitives.dart:320`).
- **Desktop:** the `FilledButton` (`:678`, its `onPressed:` at `:679`) is **inside** `_RightPanel`'s
  `DesignPanel` (`:632`).
- **The boards** draw `Register` on the bare page background, because the "What happens next" panel has no
  board at all (already filed as **G5/F1** — but recorded there as *copy* with no board, not as *the
  primary action's surface* being wrong).

This is not a colour defect; it is a fidelity gap in the surface under the feature's one committing
control, and it is the reason § 5.1's read-back had to include its own `card` backing. Recorded as **G12**.

---

## 4. M-N4 — the active nav label now matches `mobile_chrome.dart:297` — **revision 3's, retained**

> Revision 4 changed no board. Retained as revision 3 wrote it.

`Nav Label 3` ("Products") was **10/400** on all four boards. `MobileNavBar` renders the active item's
label at `FontWeight.w600` (`mobile_chrome.dart:296-298`), so the active tab was drawn at the same weight
as the four inactive ones — the one dimension that distinguishes it was the one dimension the board got
wrong.

| Layer | Was | Now | Token |
|---|---|---|---|
| `Nav Label 3` "Products" (all four boards) | 10/**400** | 10/**600** | `navLabelMobile` + `active ? w600 : w400` (`mobile_chrome.dart:297`; token `design_tokens.dart:500`) |
| `Nav Label 0/1/2/4` | 10/400 | 10/400 (unchanged, correct) | same expression, inactive branch |

**What I was wrong about.** Revision 2's §2 gave this as a file-fidelity gap and folded it into N6, on the
stated ground that "the nav is a clone of a PROHIBITED board's sub-tree and the active-label weight was not
in scope". That ground does not hold: the four boards I own, and every layer inside them, are in scope.
Only `BPM · Add Product · Light/Dark` and the desktop `S · Add Product · …` boards are PROHIBITED. Folding
a lane-owned fix into a design-system-owner notification misroutes it — the owner would have been asked to
fix something on a board they cannot edit.

It was also inconsistent with §2's own resolution of `microLabel` tracking three paragraphs earlier:
*"My boards follow the token; the reference board is low-fidelity here."* The same rule applies to the nav
label, and I applied it to one and not the other.

**N6 is narrowed to the reference board only** (§ 8): `BPM · Add Product · Light/Dark` still draw the
active nav label at w400 and `microLabel` at ls 0. Both are PROHIBITED boards, so both remain the owner's.

---

## 5. M-N5 — the disabled `Register` read-back, and how the code actually resolves it — **revision 3's, retained**

> Revision 4 changed no board and added no annotation. Two citation spans in § 5.1 were corrected (L-R4)
> and nothing else in this section changed.

### 5.1 The chain, and why the obvious reading is wrong

`core/theme.dart:67-83` calls `FilledButton.styleFrom(backgroundColor: palette.accent, foregroundColor: …)`
and sets **no** `disabledBackgroundColor` / `disabledForegroundColor` (grep for both in that file: no
match). The intuitive conclusion — "so the enabled accent stays and nothing looks disabled" — is **wrong**,
and it took reading the framework to find out. Three steps, each verified against Flutter **3.44.7**
(the SDK this repository pins, `/Users/alkebut/fvm/versions/3.44.7`):

1. **`filled_button.dart:287-288`** — `styleFrom` wraps the colours in
   `ButtonStyleButton.defaultColor(backgroundColor, disabledBackgroundColor)`.
2. **`button_style_button.dart:266-274`** — with `disabledBackgroundColor == null`, `defaultColor` returns
   `WidgetStateProperty.fromMap({ WidgetState.disabled: null, WidgetState.any: enabled })`.
3. **`widget_state.dart:1008-1013`** — `WidgetStateMapper.resolve` walks the map in insertion order and
   **`return entry.value` on the first satisfied key**, even when that value is `null`. So when disabled the
   theme's resolver returns `null`.
4. **`button_style_button.dart:382-387`** — `effectiveValue` is `widgetValue ?? themeValue ?? defaultValue`.
   `themeValue` is `null` (step 3), so resolution falls through to
   `defaultStyleOf(context)` = `_FilledButtonDefaultsM3`.
5. **`filled_button.dart:531-562`** — that default is
   `backgroundColor: colorScheme.onSurface.withOpacity(0.12)` and
   `foregroundColor: colorScheme.onSurface.withOpacity(0.38)` when disabled.
6. **`core/theme.dart:32`** — `onSurface: palette.inkPrimary`.

**Therefore `FilledButton(onPressed: null)` under this theme paints
`palette.inkPrimary` at 12% as the fill and `palette.inkPrimary` at 38% as the label — not `#1668d6`/
`#4496fc` at opacity 1.** The reviewer is right, and the reason is more interesting than "M3 defaults".

### 5.2 What it looks like, computed

Composited by script over the surface the button actually sits on — `DesignPanel` = `palette.card`
(`design_primitives.dart:320`), **not** the page canvas (§ 3.3):

| | Light | Dark |
|---|---|---|
| surface beneath | `card` `#FFFFFF` | `card` `#262827` |
| fill = `inkPrimary` @12% over that | **`#E4E4E4`** | **`#3F403F`** |
| label = `inkPrimary` @38% over the fill | **`#999A9A`** | **`#848482`** |
| **label on its own fill** | **2.22:1** | **2.78:1** |
| enabled label for comparison | `#FFFFFF` on `#1668d6` = **5.27:1** | `#06121f` on `#4496fc` = **6.30:1** |

WCAG 1.4.3 exempts inactive user-interface components, so **2.22:1 is not a conformance failure**. It is
recorded because it is the strongest available argument for N4: a disabled control whose label is at
2.22:1 on its own fill in **Light** cannot be read at all, and a 10px `monoMeta` helper is not a reliable
substitute carrier for "this control is unavailable".

### 5.3 What is now on the boards

An additive read-back, one per theme, **below** the two Unknown-host boards in the free band
`y = 11600 … 11721` (verified free: every board above ends at y=11594 and every board below starts at
y=11800, so the whole horizontal band is empty; the lowest read-back shape is at 11721, **79px clear**).
They are page-level **groups**, not children of the 390×844 screen boards, so no screen board's geometry
or layer count changes:

| Group | id | x, y | w × h | children |
|---|---|---|---|---|
| `M-N5 READ-BACK · Register product DISABLED · Light · annotation, NOT screen content` | `6d055762-…bf7d2cd65125` | 7550, 11600 | 358 × 121 | 6 |
| `M-N5 READ-BACK · Register product DISABLED · Dark · annotation, NOT screen content` | `6d055762-…bf7d2ce38c50` | 7970, 11600 | 358 × 121 | 6 |

Each group carries: the theme heading, the one-line mechanism, the measured values, a `card`-coloured
surface named `READ-BACK M-N5 surface · DesignPanel = palette.card`, the disabled rect
(`#E4E4E4` / `#3F403F`, 358×34, r=3) and the centred 11/600 `Register product` label
(`#999A9A` / `#848482`). **Every layer name carries `· PROVISIONAL (G1 hostUnrecognised)`**, the same
marker the trust panel's eight layers carry, because this state exists only when the host is
unrecognised.

**This needed no palette token and no human gate**, and none was invented: nothing here chooses a disabled
appearance — it *records the appearance the primitive already produces*. N4/G9 stays open for the **token**
`ShipItPalette` still lacks, and § 7's statement stands unchanged:

> the boards are adequate *for the Verified state* and are the **known-wrong expression for the
> Unknown-host state**.

The four screen boards are deliberately **not** changed: their `Register` rect still reads
`#1668d6@1` / `#4496fc@1`, which is the known-wrong expression, and the read-back sits beside them as the
correction of record. A reviewer should be able to see the wrong thing *and* the right thing in the same
viewport — that is the point of an annotation rather than a substitution.

---

## 6. M-N2 — corrected traceability matrix (revision 3's own)

Revision 1's matrix (`design-revision.md:314-335`) is the only matrix in the artifact set, is retained
byte-identical, and was wrong in three rows — two of which B-R1 and L-R2 had already named. Revision 2
carried no matrix at all. **This is revision 3's matrix**, and it governs the boards as they now stand.

| Board element | Req | Settled by | Production primitive / token — **as drawn now** |
|---|---|---|---|
| `Back` `‹  Products` | R1 | 73097d48 | `MobileBackBar`; `accent`; 12/**500** |
| `H1` `Add a product` | R1 | 73097d48 | `pageTitleMobile` (`design_tokens.dart:561`) 20/600; `inkPrimary` |
| `St Tick` + `Status` | R1, R6/2a | 73097d48 | `AccentTick`; `microLabel` `:368` **Mono 9/600 ls 1.1**; `inkTertiary` |
| `Rule 1` | R1 | 73097d48 | `ContentRule`; `rule` |
| `F K 0/1/2` labels | R4 | B1 | `FormFieldSlot.label`; `microLabel` `:368` **Mono 9/600 ls 1.1**; `inkTertiary` |
| `Field Box 0/1/2` | R1, R4 | 73097d48 | `SingleLineInput` + `formBoxDecoration(vertical: padSingle)`; `controlBorder` |
| `Field Val 0/1/2` | R1, R6 | 73097d48 | `bodySmall` `:386` 11/400; `inkPrimary` |
| `Art Bg` / `Art Edge` | R1 | 73097d48 | `DesignPanel(edgeColor:)`; `card`, `accent` |
| `Art K` eyebrow | R1 | 73097d48 | `MicroLabel`; **Mono 9/600 ls 1.1**; `inkTertiary` |
| **`Art T`** | R1, R6 | 73097d48 | **`sectionTitle` (`design_tokens.dart:352`) 13/600**; `inkPrimary` — *revision 1 said "`bodySmall` w600", which is 11/w400 (`:386`) and therefore contradicted the board* |
| `Art S · PENDING D4 (at-rest model)` | R1, R6 | **9417f8bf (PENDING D4)** + `b869ec24` (RESOLVED — server-side storage constraint only) | `monoMeta` 10/400; **`inkSecondary`** |
| `Key State` | R6/2b,2c | 73097d48 + sibling lane | `attention` / `positive` / `negative` — § 3.2 ledger, note `negative`-on-`card` dark = 3.68:1 (N2) |
| `Art L1 · Copy key` | R1, R6 | 73097d48 | `InlineLink`; `link` `:426` 11/**500**; `accent` |
| `Art L2 · Check access` / `Check again` | R6/2c | 73097d48 | `InlineLink`; `link` 11/500; `accent` |
| **`Trust K/Body/Body 2/Host`** | R6/2d | 73097d48 + human 2d | `MicroLabel` → `microLabel` **`inkSecondary`**; `bodySmall` **`inkSecondary`** 11/400; `monoMeta` 10/400 **`inkSecondary`**; surface `DesignPanel` = **`card`**; edge `attention` — *revision 1 named "`card`, `attention`" with **no foreground token at all**, which is precisely how `Trust Host` shipped at `inkTertiary` unreviewed* |
| `Trust Btn` `Trust this host` | R6/2d | 73097d48 + human 2d | `FilledButton` (accent fill, theme foreground); label **12/600**, **`align: center`** after H-N1 |
| `Submit` + `Submit L` | **R2** | human 2e | `MobilePrimaryButton` — **label only**, `buttonLabelMobile` `:508-514` **11/600**, `align: center`. Rect 358×34 @ x=16; fill `accent`. **Surface = `card` in code, bare page background on the board (G12)** |
| **`Submit Sub` helper below button** | **R2**, **R5** | human 2e + R5 | `monoMeta` 10/400; **`inkTertiary`** (`add_product_page.dart:918`) — **Surface = `card` in code, bare page background on the board (G12)**, the same surface note the `Submit` row above carries. **The board draws `inkSecondary`** (`#5a5c5b`/`#a8a6a0`, y 11470–11485 on the Unknown-Light board, outside every panel since `Trust Bg` ends at 11412) — **the board's value is the aspirational one and is more legible**: `inkSecondary` on `canvas` is 6.28:1 / 6.65:1, whereas the build's `inkTertiary` is 4.65:1 / 4.62:1 on `canvas` and **4.99:1 / 4.23:1 on `card` — AA FAIL in dark, the surface the code actually renders on (N10)**. *Revision 3 said `inkSecondary`, which is what the board draws but **not** what the build renders, and named no surface at all — the row implementation and QA inherit as the acceptance baseline, so it must carry the build's token, the surface, and which of the two the board keeps* |
| `Disclose` `Show technical details ▸` | **R3** | human 2f | `TechnicalDetails`; `linkMicro` `:443` 10/500; `accent` |
| **`Bottom Nav / … / Products`** | R1 | 73097d48 | `MobileBottomNav`; **per theme**: Light `inkQuiet` `#6A6C6A` on `rail`; Dark **`inkTertiary` `#8A8983`** on `rail` (4.60:1 / 4.88:1); **active** item `inkPrimary` on `rail` and **`w600`** after M-N4; `Nav Badge` `attentionTick` + `#241a02`, Mono 11/700 — *revision 1 said `inkQuiet`/`inkPrimary`, which is **false for dark**: the boards draw `#8A8983` = `inkTertiary`, not `inkQuiet` `#85847E`* |
| `M-N5 READ-BACK` groups ×2 | R2, R6 | revision 3 | `FilledButton` disabled resolution under `core/theme.dart:67-83` + `:32`; **not** a `ShipItPalette` token (N4/G9); `· PROVISIONAL (G1 hostUnrecognised)` |

### 6.1 The two cells revision 4 corrects (M-R2, M-R3)

**`Art S · PENDING D4 (at-rest model)` — "Settled by" pointed at a RESOLVED decision (M-R3).** Revision 3
wrote `b869ec24` alone. That decision is `status: RESOLVED` and asks *"Where does deploy-key generation and
storage belong…"* — it settles **where the keypair lives (server-side, behind an API returning only the
public half)**, which is a real and binding constraint on this string. It does **not** settle the **at-rest
substrate**, which is the open human gate `9417f8bf` (`status: PENDING`, *"Which substrate holds the
server-stored private half of a product's deploy key?"*), and it is the substrate the layer's own string is
parameterised on. Revision 3 and its metadata cited `9417f8bf` **zero times**. The cell now names
`9417f8bf (PENDING D4)` with `b869ec24` cited alongside for what it does settle.

**This is invariant 8 failing in the direction that makes an open gate look settled** — on the one row that is
explicitly *not* closed. Note what did **not** go wrong: the layer's name, its string, its `PENDING D4`
marker, §8's "G2 stays `PENDING D4`", §11's G2 and the metadata all keep it open. **The human's decision has
not been quietly resolved and is not resolved here.**

> ⚠️ **REVISION 5 — THE PARAGRAPHS ABOVE ARE SUPERSEDED, AND THE THING THEY SAY DID NOT HAPPEN.** They are
> *correct for `77c19f1`*, where `9417f8bf` genuinely was `status: PENDING` and the layer genuinely was
> untouched. **At `289f1d3` `9417f8bf` is `RESOLVED`** (OPTION_C / A3), the matrix cell's `9417f8bf (PENDING D4)`
> is stale, and **the layer was edited on all four boards** — renamed `Art S`, string corrected. Retained
> unedited with this pointer rather than rewritten. See `design-revision-5.md` §3. One cell was wrong; the layer is untouched.

> ⚠️ **REVISION 5 — THIS WHOLE M-R3 ROW IS SUPERSEDED. IT WAS CORRECT *FOR `77c19f1`* AND IS NOT NOW.**
> *(It is a historical verification row, so it is **pointed at, not rewritten** — the same treatment rev 4's
> own § 1.2 rows received.)* Two independent changes: **`9417f8bf` is `status: RESOLVED`** — OPTION_C / A3,
> an external secret manager; SHIP IT holds a reference only — so this row's `status: PENDING`, its
> *"open human gate"* framing and its `"the human's decision has not been resolved"` conclusion are all **false
> at `289f1d3`**. And the layer is **no longer untouched**: it was renamed `Art S` and its string corrected on
> **all four boards**, verified by live read-back. `b869ec24` still settles *where* the keypair lives and is still
> correctly cited. Governing text: `design-revision-5.md` §3; evidence `penpot-board-evidence.md` §6.2.

**`Submit Sub` helper below button — the wrong foreground token, and no surface (M-R2).** Corrected above.
The row now names the build's `inkTertiary`, the same surface note the `Submit` row carries, and states
explicitly which value **the board keeps** (`inkSecondary`, aspirational and more legible) versus which the
**build renders** (`inkTertiary`). The two rows compound with § 3.2: the same ink is **4.62:1 on `canvas`
(pass)** and **4.23:1 on `card` (FAIL)** in dark, and the code's surface is `card`.

`requirements_covered`: **R1, R2, R3, R4, R5, R6, R7**. `requirements_gaps`: **none**. No requirement
moved in this pass.

---

## 7. M-N3, L-N1, L-N2, L-N3, L-N4 — the record corrections (revision 3's pass, retained)

### 7.1 Withdrawal markers applied (L-N1, M-N6)

Byte-identical retention is legitimate for diffability; **retention without a marker is not**, because
whichever file a reader opens first is the only file they read. Two kinds of marker were applied.

> **L-R3 correction (this pass).** The `Site` column below carried revision 3's line numbers, and **revision
> 3's own marker insertions invalidated every one of them**: the marker is written *at* the cited site, so the
> site moves. The numbers in this table are now the live ones (§ 0.1 has the full map). `design-revision.md`
> and `report.md` themselves are **unchanged** — only the citations are corrected, and the stale ones are
> left visible in `design-revision-3.md` behind a pointer rather than rewritten out of history.

| Site (**live line numbers**) | Disproven claim | Marker added |
|---|---|---|
| `design-revision.md` head | — | `SUPERSEDED — revision 1. See design-revision-4.md. Two claims inside are disproven and marked in place: F8 (§10 table) and the 36px `minimumSize` derivation (§2a).` |
| `design-revision.md:77`, `:79` (marker at `:83-89`) — **was `:70`, `:72-73`** | "36.4 → clamped by `minimumSize` to **36px**", "collapses … landing on its own declared `minimumSize`" | `> **WITHDRAWN — revision 2 §6a.** `minimumSize` is a minimum; `Size.constrain` raises only values *below* it, and 36.4 > 36 already. The button collapses **50.4 → 36.4**, not to 36. Retained unedited for diffability; **superseded, not deleted.**` |
| `design-revision.md:429` (F8 row; marker at `:431-438`) — **was `:414`** | "Penpot's IBM Plex Sans has no `500` weight (supported: 200/300/400/600/700/900)" | `> **WITHDRAWN — revision 2 §2.** **False in both directions.** Variants are `100,200,300,400,500,600,700`: `500normal` **exists**, `900` **does not**, `100` exists and was omitted. F8 was deleted from the current revision; this row is retained unedited and must not be relied on.` |
| `report.md` head | — | `SUPERSEDED — revision 1's report. See design-revision-4.md. Claims disproven since: the 36px derivation, and "no 500 weight" (now at `report.md:120`, marked). Both marked in place.` |
| `report.md:120` (marker at `:122-…`) — **was `:100`** | "Penpot's IBM Plex Sans has no `500` weight, so link layers render at 400" | `> **WITHDRAWN — revision 2 §2.** False: `500` exists and `900` does not. The link layers are now **11/500** (`ShipItType.link`, `design_tokens.dart:426`).` |
| `report.md:62` (marker at `:64-68`), `report.md:224` (marker at `:231-…`); `design-revision-metadata.yaml:15-16` (marker at `:31-…`, **this one is still correct**) — **were `:48`, `:197`** | "≈50.4px → 36px, landing on its own declared `minimumSize`" | `> **WITHDRAWN — revision 2 §6a.** 50.4 → **36.4**; `minimumSize` never binds. Superseded, not deleted.` |
| `design-revision-2.md` head | — | `SUPERSEDED — revision 2. The current revision is design-revision-4.md. Revision 3 overturned three claims in this file: §8 L-R5 and N8 (`Trust Btn L` flush-left — it was **not** a faithful copy of the desktop pattern, and the label is now centred); the §5 two-row `canvas`/`card` split (the surface is `canvas` on **both** platforms, and **N7 is withdrawn for those lines only**); and §2's reason for leaving `Nav Label 3` at w400 (the four boards I own are in scope, so the label is now **w600**). Substantive text left unedited for diffability.` |
| `design-revision-2.md` §5 / §8 / §10 | the `card` row, L-R5, N8, N7 | in-place `SUPERSEDED BY REVISION 3 §3.1` / `§2` / `§8` pointers at each site |
| `correction-report.md:67` | "every clamp claim deleted from § 2a, the `risk_rationale` and `report.md`" | `> **CORRECTED — revision 3 §0.** This claim was **false**: nothing was deleted from § 2a, the `risk_rationale` or `report.md`. The corrected statement is "**superseded by revision 2 §6a, not deleted**", and withdrawal markers are now in place at all five sites.` |
| `design-revision-metadata-2.yaml` `risk_rationale` | "The 36px claim has been deleted from § 2a, from the risk rationale and from report.md" | `SUPERSEDED — see design-revision-4.md §0.1. The claim is "superseded by revision 2 §6a, not deleted"; markers applied.` |

### 7.2 L-N2 — the branch name, corrected

The branch is **`design-correct-addproduct-mobile`**, confirmed by `git branch --show-current` and by
`git worktree list`:

```
/private/tmp/shipit-correct-addproduct-mobile  77c19f1 [design-correct-addproduct-mobile]
```

It was recorded as `design/correct-addproduct-mobile` at `design-revision-2.md:16`,
`design-revision-metadata-2.yaml:220` and `correction-report.md:136,183`. Corrected in every artifact this
revision writes, and flagged in the supersession headers above. This is the same class of error the pass
escalates as **G11** — a record asserting a path that does not exist — and it would have misdirected anyone
reproducing the lane.

Revision 1's own provenance block is **left alone**: it records worktree
`/private/tmp/shipit-design-addproduct-mobile` on branch `design/addproduct-mobile`, and
`git worktree list` confirms **both exist**. That record is accurate for its own lane and falsifying it
would be the same error in the opposite direction.

### 7.3 L-N3 — citations

| Claim | Correction |
|---|---|
| `navLabelMobile.copyWith(`'s `fontWeight:` cited as `:296` | **`:297`** ✓ (`:296` is the `.copyWith(` line) — applied in § 4 and § 6 |
| `class MobilePrimaryButton` cited as `:424`, "corrected to `:425`" | **`:424` stands.** `:425` is the constructor. The dispatched correction is wrong (§ 1.1); nothing changed |
| `design_primitives.dart:320` / `:391` | now written as **`apps/control_plane/lib/shared/design_primitives.dart:320` / `:391`** throughout this revision ✓ |

### 7.4 L-N4 — counts, with the counting rule stated

| Board | Top-level layers | Text layers |
|---|---|---|
| `SM - Add Product - Unknown host - Light` | **44** | **29** |
| `SM - Add Product - Unknown host - Dark` | **44** | **29** |
| `SM - Add Product - Verified - Light` | **36** | **24** |
| `SM - Add Product - Verified - Dark` | **36** | **24** |

> **Counting rules, published next to the numbers.** *Top-level layers* = `board.children.length`.
> *Text layers* = every shape with `type === 'text'` anywhere in the board's subtree, **including
> descendants** — which is why the five `Nav Label` layers and the `Nav Badge` numeral are all counted.
> Revision 2's published "24 / 24 / 19 / 19" excluded the five `Nav Label` layers while still counting
> `Nav Badge`; that was a rule nobody stated, and it was wrong.

---

## 8. Notification list (Level-1 design-system-owner; recorded, not escalated)

None of these raise the risk level and none are mine to fix. Rows marked *revision 3* are revision 3's, carried
forward unchanged except where a pointer says otherwise.

| Id | Item | Status |
|---|---|---|
| N1 | Board naming `SM - ` vs the page's `S · ` | carried from B2; unchanged |
| N2 | `ShipItPalette.negative` fails AA on dark — 4.02:1 `canvas` / 3.68:1 `card` | carried from B4/G3; **kept distinct from H-R1** |
| N3 | `TechnicalDetails` paints an unconditional `ContentRule` the mobile board lacks | carried from G4 |
| N4 | **No disabled-primary token.** Now with the resolved appearance attached: the primitive renders `inkPrimary@12%` fill + `inkPrimary@38%` label = **#E4E4E4 / #999A9A** in Light (**2.22:1**) and **#3F403F / #848482** in Dark (**2.78:1**). A 2.22:1 label is unreadable in Light and the 10px helper is not a substitute carrier. Request a disabled container/label pair in `ShipItPalette` | **strengthened in revision 3, not re-raised** |
| N5 | `BPM · Add Product · Light` draws `Submit L` at **13/600**, matching no primitive | raised in revision 2; unchanged |
| N6 | **`BPM · Add Product · Light/Dark` only:** `microLabel` at ls 0 vs the token's ls 1.1, and the nav's **active** label at w400 vs `mobile_chrome.dart:297`'s w600 | **narrowed in revision 3.** The w400 nav label on *my* boards was mine to fix and is fixed (M-N4, § 4); what remains is the reference board, which is PROHIBITED to me |
| ~~N7~~ | ~~Expanded `TechnicalDetails` lines fail AA on `card` in dark (4.23:1)~~ | **WITHDRAWN — revision 3 §3, for these lines only.** The surface is `canvas` on **both** platforms (4.65 / 4.62, both pass). Escalating this would have sent the owner a desktop AA failure Add Product does not exhibit. ⚠️ **M-R1 (this pass):** the withdrawal reason was written as a *general* claim — "no Add Product call site puts these lines on `card`" — and that generalisation is **false**: `Art K` does. The withdrawal stands for the `TechnicalDetails` lines and says nothing about `Art K`; the live `inkTertiary`-on-`card` failure is **N10** |
| ~~N8~~ | ~~`Trust Btn L` is flush-left, copying the desktop `Host Btn L` pattern at x=254~~ | **WITHDRAWN AND FIXED — revision 3 §2.** The premise was false (it compared box `x` and ignored `align`; desktop `Host Btn L` is `align: center`). The label is now centred, 50.367px inset. `Submit L` was already centred and was never affected |
| N9 | the primary action's surface: in code `Register` sits inside `DesignPanel` = `card` on **both** platforms, while the boards draw it on the bare page background because the "What happens next" panel has no board (G5) | **raised in revision 3, from G12** |
| **N10** | **`ShipItPalette.inkTertiary` fails AA on `card` in dark — 4.99:1 light / 4.23:1 dark — and it has a LIVE Add Product call site.** The `MicroLabel('DEPLOY KEY · THIS PRODUCT ONLY', color: palette.inkTertiary)` sits inside `DesignPanel` (= `palette.card`) at `add_product_page.dart:533` (desktop) and **`:1029`** (mobile); the boards draw it faithfully as `Art K` inside `Art Bg` on **all four boards**. Request either a darker `inkTertiary` for `card` surfaces in dark, or a card-safe tertiary token for eyebrows/labels that sit inside a `DesignPanel`. **`ShipItPalette` is design-system-owned**, exactly as N2 already records for `negative` — this is not a board defect and not mine to fix | **NEW — this pass (Level 1).** Does **not** move the risk level: no board edit, no token chosen, no human gate |

Carried from revision 1 and **not** re-raised: **B3** (footer-copy scope) remains filed as Human Decision
`27ea6536`. **G2** (`Art S` at-rest wording) stays `PENDING D4` and unresolved — the open gate is
**`9417f8bf`**, and the at-rest protection model remains the human's decision at Gate D4 (§ 6.1).

> ⚠️ **REVISION 5 — ALL THREE CLAIMS IN THE PARAGRAPH ABOVE ARE SUPERSEDED. NOT RE-RAISED.** *(Revision 5
> finding L-1. Retained unedited.)* `9417f8bf` is **RESOLVED** (**OPTION_C / A3**) — it is **not** `PENDING`,
> and the at-rest model is **not** the human's open decision. The layer is renamed `Art S` and its string
> corrected on all four boards. `27ea6536` is **RESOLVED**; mobile is measured conformant, **the four
> desktop `S` boards are not** (finding **F6**). Full specification: `design-revision-5.md` §3, §4.

---

## 9. Board inventory — unchanged by this pass (revision 3's inventory, re-read read-only)

Page `d8ac01df-6646-81d2-8008-a366c09aa9d3`. **160 boards / 164 root children.** **Revision 4 edited no
board, no layer, no group, and created nothing.** The counts below are revision 3's, re-read read-only this
pass and confirmed identical (root children **44/44/36/36**; subtree text layers **29/29/24/24**). Revision
3's own note, retained: root children went from 162 to 164 because of the two `M-N5 READ-BACK` groups; the
other two non-board root children (`Tab Group`, `Rectangle`) were already present and are untouched.

| Board | Penpot id | Pos | Layers | Text layers | Trust panel | Repo | Submit rect | Badge |
|---|---|---|---|---|---|---|---|---|
| `SM - Add Product - Unknown host - Light` | `6d055762-…ff750422` | (7550, 10750) | 44 | 29 | yes, 8/8 provisional | internal | 358×34 `#1668d6@1` | yes |
| `SM - Add Product - Unknown host - Dark` | `6d055762-…e644269b` | (7550, 9800) | 44 | 29 | yes, 8/8 provisional | internal | 358×34 `#4496fc@1` | yes |
| `SM - Add Product - Verified - Light` | `6d055762-…e124738` | (8000, 10750) | 36 | 24 | none | internal | 358×34 `#1668d6@1` | yes |
| `SM - Add Product - Verified - Dark` | `6d055762-…36b1c9a` | (8000, 9800) | 36 | 24 | none | internal | 358×34 `#4496fc@1` | yes |

Per-board weights and alignments (identical on all four boards unless noted):

```
Back 12/500   H1 20/600   Status 9/600 ls1.1   F K 0/1/2 9/600 ls1.1   Art K 9/600 ls1.1
Art T 13/600  Art L1 11/500  Art L2 11/500     Disclose 10/500       Nav Badge 11/700
Submit L 11/600 align:center
Nav Label 3 (ACTIVE) 10/600      <- corrected this pass, M-N4
Unknown pair only:  Trust K 9/600 ls1.1   Trust Btn L 12/600 align:center   <- corrected this pass, H-N1
Deliberately 400: Field Val 0/1/2 11/400  Art S 10/400  Key State 10/400
                Trust Body 11/400  Trust Body 2 10/400  Trust Host 10/400  Submit Sub 10/400
                Nav Label 0/1/2/4 10/400   (inactive branch of mobile_chrome.dart:297)
```

**Read-back verification** — the table below is **revision 3's**, retained. Revision 4 changed nothing on the
boards, and its own read-only sweep is **§ 9.1**. Revision 3's rows that say "this pass" mean *revision 3's*
pass.

| Check | Result |
|---|---|
| `Trust Btn L` `align` / glyph inset, Unknown pair | **`center` / 50.367px** (was `left` / 0px) |
| `Nav Label 3` weight, all four | **600** (was 400); `Nav Label 0/1/2/4` still 400 |
| `Register` rect unchanged on all four | 358×34 @ x=16, `#1668d6@1` / `#4496fc@1`, y=678 / 510 |
| Forbidden strings (`this device`, `keychain`, `browser storage`, `What you're registering`, `What happens next`, `Cancel`) | **0 hits on all four boards** |
| `Register product` — exact-equality label count | 1 / 1 / 1 / 1 |
| `Register product` — case-sensitive substring count | **2 / 2 / 1 / 1** |
| `TeamHub` repository identical across the set | yes, all four = `git@git.internal.acme.com:platform/teamhub.git` |
| `Art T` consistent with the repository path | yes, `platform/teamhub` on the Verified pair |
| `Trust Host` fill, Unknown pair | `#5a5c5b` / `#a8a6a0` (`inkSecondary`) |
| `Trust *` layers carrying the provisional marker | **8 / 8** on each Unknown board |
| `Art S · PENDING D4 (at-rest model)` present, unresolved | yes, all four |
| `M-N5 READ-BACK` groups | 2 groups × 6 layers, x=7550/7970 y=11600, 358×121, lowest shape 11721, **79px clear of y=11800** |
| Band vs all 160 boards | **0 overlaps** (bounding-box test) |
| Pre-existing root children `Tab Group`, `Rectangle` | untouched |
| `BPM · Add Product · Light/Dark` | (5280, 10750) / (5280, 9800), 36 children each — **unchanged** |
| `S · Add Product · Unknown host · Light/Dark` | (10400, 11800) / (10400, 12750), 69 children each — **unchanged** |
| `S · Add Product · Verified · Light/Dark` | (11700, 11800) / (11700, 12750), 65 children each — **unchanged** |
| Stray or scratch shapes | none |

**No pre-existing board was edited, renamed, moved or deleted** — by revision 3, which wrote only to the four
boards this lane owns plus the two new page-level annotation groups; **and by revision 4, which wrote to no
board at all.**

### 9.1 Revision 4's read-only sweep (the evidence behind § 3.2, § 6.1 and M-R1/M-R2)

**Four** `penpot_execute_code` calls, all **read-only**: `findShapes` reads, `fills` and `bounds` reads, no
setter touched, no `create*`, no `appendChild`, no `remove()`. The first two located the layers by name; the
third mapped every text layer to the `card`-coloured rect containing it; the fourth repeated that sweep over
each board's full subtree and filtered to `inkTertiary`.

| Check | Result |
|---|---|
| Root children per board | **44 / 44 / 36 / 36** — identical to revision 3 |
| Subtree text layers per board | **29 / 29 / 24 / 24** — identical to revision 3 |
| `Art K` fill, all four | **`#6e706e` / `#8a8983`** = `inkTertiary` |
| `Art Bg` fill, all four | **`#ffffff` / `#262827`** = `card` |
| `Art K` bounds inside `Art Bg` | **yes** — y 11132–11146 in 11120–11236 (Light); 10182–10196 in 10170–10286 (Dark) |
| `inkTertiary` text layers on `card` | **`Art K` only**, all four boards. `Status` and `F K 0/1/2` are `inkTertiary` but sit on the board's own fill `#f7f7f5` / `#1f2120` = `canvas` |
| `Submit Sub · helper BELOW button` fill, all four | **`#5a5c5b` / `#a8a6a0`** = `inkSecondary` |
| `Submit Sub` bounds, Unknown-Light | y **11470–11485**; the only two `card` rects on that board are `Art Bg` (11120–11236) and `Trust Bg` (11252–**11412**) → **outside every panel**, on `canvas` |
| Board own fill | `#f7f7f5` / `#1f2120` = `canvas` |
| `Art S · PENDING D4 (at-rest model)` | present on all four, string and marker **untouched** |
| Boards edited / created / renamed / moved / deleted by this pass | **0 / 0 / 0 / 0 / 0** |

---

## 10. Categorized mismatch list (boards vs the build at `77c19f1`)

- **MATERIAL** — the build renders a nested subtext inside the desktop `FilledButton.child` (`:692-717`) in
  `inkPrimary` on the fill, **3.07:1 light / 2.72:1 dark**, failing AA in both themes.
- **MATERIAL — recorded in revision 4 (M-R2)** — the `Submit Sub` helper: the boards draw `inkSecondary`
  (`#5a5c5b`/`#a8a6a0`) and the build renders `palette.inkTertiary` (`add_product_page.dart:918`). Same row of
  the matrix, and it is the **acceptance baseline** implementation and QA inherit. The two surfaces differ too:
  `canvas` on the board, `card` in code. Not a board edit — the boards are the aspirational side and are more
  legible — so it is recorded as a divergence plus N10, not resolved here.
- **MATERIAL — recorded in revision 4 (M-R1/N10)** — `Art K` is `inkTertiary` on `card` in dark at **4.23:1**,
  i.e. **AA FAIL**, on all four boards *and* in the build. Board and build agree, so this is a token failure
  routed to the design-system owner, not a fidelity gap.
- **MATERIAL** — build renders "What you're registering" (`:405`, desktop only) and "What happens next"
  (`:639` desktop / `:859` mobile); neither exists on any board. **Now also a surface defect (G12/N9):**
  the panel is `DesignPanel` = `card`, and it wraps the primary action on both platforms.
- **MATERIAL** — `_buildInfoPanel` (`:480-482`, `:979-981`) claims the private half "stays in this device's
  keychain"; false by `b869ec24`. **G6 re-scoped** to `product_detail_page.dart:614`.
- **MATERIAL** — key meta (`:542`, `:1038`) says "created on this device · the private half stays in the
  keychain"; boards corrected.
- **MATERIAL** — desktop paints two `ContentRule`s and two copy lines at the footer (`:380` + `:317-319`).
- **MATERIAL** — `canRegister` requires `AccessStatus.verified` (`:233-236`) which nothing in the repository
  ever assigns; the button is unreachable in every state, and the boards' `Register` rect shows the
  **enabled** treatment where the build paints the M3 disabled one (§ 5.1).
- **MATERIAL** — the desktop submit label is `monoMeta` 12/600/ls 1.1 in code while the desktop boards draw
  Sans 12/600/ls 0; and the mobile boards now draw 11/600 against the reference board's 13/600 (N5).
- **TRIVIAL** — board submit rect 34px vs `MobilePrimaryButton` 36px (pre-existing, G7/F6).
- **AMBIGUOUS** — `Confirm the host above to enable Register product.` has **no producer** in
  `_registerButtonSubtext` (`:726-735`); arrives with the sibling lane's `hostUnrecognised`.
- **AMBIGUOUS** — `ShipItPalette` has no disabled-primary token, so the appearance the code actually paints
  is derived from Flutter's M3 defaults rather than from a token (§ 5.1, N4).
- **AMBIGUOUS** — `TechnicalDetails` always paints a `ContentRule` (`:396`); the mobile board has none.
- **RESOLVED this pass** — ~~`Trust Btn L` is flush-left~~ (H-N1, § 2).
- **RESOLVED in revision 2, marker applied here** — ~~Penpot's IBM Plex Sans has no `500` weight~~ — `500`
  exists; `900` does not; `100` exists.
- **RESOLVED in revision 2, marker applied here** — ~~the desktop button is clamped to 36px~~ — 36.4px.

---

## 11. Requirements, gaps, and assessment

- `requirements_covered`: **R1, R2, R3, R4, R5, R6, R7** — unchanged. No requirement moved.
- `requirements_gaps`: **none.**

| Id | Gap | Why it is not mine |
|---|---|---|
| G1 | normative `hostUnrecognised` state machine; "Check access" semantics | sibling lane `design-addproduct-keyservice` |
| G2 | at-rest wording for `Art S` | ~~**open human decision `9417f8bf` (`status: PENDING`)**; layer stays `PENDING D4`. `b869ec24` settles only *where* the keypair lives, not the at-rest substrate~~ — **RESOLVED at revision 5: `9417f8bf` is `status: RESOLVED` (OPTION_C / A3, an external secret manager); layer renamed `Art S`, string corrected on all four boards** | (§ 6.1) |
| G3 | `negative` on dark fails AA and no compliant token exists | `ShipItPalette` is design-system-owned (N2) |
| G4 | `TechnicalDetails`' unconditional `ContentRule` | shared primitive, 4 other screens (N3) |
| G5 | the build's "What you're registering" / "What happens next" panels have no board | removing them is a UX change (F1) |
| G6 | **re-scoped**: `_buildInfoPanel` **and `product_detail_page.dart:614`** repeat the false keychain guarantee | production source, PROHIBITED to me |
| G7 | 34px board submit vs 36px `MobilePrimaryButton` | pre-existing; needs QA baseline agreement |
| G8 | `flutter analyze` not run → feasibility cannot be HIGH | see metadata |
| G9 | no `ShipItPalette` disabled-primary token; the appearance is derived from M3 defaults | design-system owner (N4); consequence stated in § 5 |
| G10 | `Confirm the host above to enable Register product.` has no producing state | arrives with G1's `hostUnrecognised` |
| ~~G11~~ | ~~the mobile design review report was never persisted~~ | **CLOSED in revision 4 (L-R2).** `docs/engineering/dispatch/tasks/design-review-addproduct-mobile/report.md` exists (commit `25f723d`), is revision 1's Gate D3 review, and its own header states *"This file is the authoritative copy; the correction lane's G11 is now closed."* Read in full read-only at the canonical checkout. Removed from the open-gap list; **not** carried as a live gap |
| **G12** | the primary action's surface: in code `Register` sits on `palette.card` inside `DesignPanel` on both platforms; the boards draw it on the bare page background | consequence of G5; recorded with the surface named (N9) |
| **G13** | **new in revision 4 — `ShipItPalette.inkTertiary` fails AA on `card` in dark (4.23:1) with a live Add Product call site** (`Art K`, `add_product_page.dart:533`/`:1029`) | design-system owner (N10); identical routing to G3/N2 |
| **G14** | **new in revision 4 — the `Submit Sub` helper's foreground differs between board (`inkSecondary`) and build (`inkTertiary`), on different surfaces (`canvas` vs `card`)** | recorded in the matrix (§ 6) as the acceptance baseline; the divergence is a build-side choice I cannot make, and its dark `card` consequence is N10 |

**Assessment movement — this pass changed no score, and the reason is stated rather than rounded away.**

- **design_system_compliance: PARTIAL → PARTIAL.** Revision 4 makes **no board edit**, so no divergence was
  closed. Still PARTIAL because the file holds boards disagreeing with mine on `Submit L` size (N5) and on
  `microLabel` tracking and the active nav weight (N6), because `negative` on dark is unresolved (N2), and now
  because `inkTertiary` on `card` is unresolved (N10). The M-R2 row adds a recorded **board-vs-build**
  divergence on the `Submit Sub` helper's foreground; it is recorded in § 6 with the surface named rather than
  resolved, because resolving it means choosing a palette token, which is the design-system owner's call.
- **ux_accessibility_score: PARTIAL → PARTIAL.** The two AA failures this lane had authority to fix remain
  fixed. **Not PASS**, and the reasons are recorded rather than rounded away: **(a)** `Key State` still uses
  `negative` at **3.68:1 on `card` in dark** with no compliant token in `ShipItPalette` (N2); **(b)** the
  `canRegister == false` state still has **no token**, and the appearance the code produces has a label at
  **2.22:1** in Light (§ 5.2, N4); **(c) — NEW in revision 4** `Art K` renders `inkTertiary` on `card` at
  **4.99:1 light / 4.23:1 dark — AA FAIL in dark** — on all four boards *and* in the build at
  `add_product_page.dart:533`/`:1029`, with no compliant token in `ShipItPalette` (N10). § 5 makes (b)
  measurable and § 3.2/§ 6.1 make (c) visible; neither makes this PASS. **(c) exists because revision 3
  annotated it away, and that annotation was itself an unverified claim about the boards (§ 0).**
- **implementation_feasibility: MEDIUM → MEDIUM.** Unchanged, deliberately. `flutter analyze` was
  **NOT_RUN** in this lane — it needs `flutter pub get`, which writes outside this lane's read-only scope,
  and `apps/control_plane/.dart_tool/` does not exist at this HEAD. **No feasibility claim is derived from
  a gate that was not run.** What this pass verified is every primitive, token and call site the corrections
  depend on, by source inspection, plus the Flutter SDK spans (§ 1.2). No Flutter widget was rendered.
- **RISK_LEVEL: 2 → 2.** Every change in this revision is a **Level 0 record correction**: a deleted
  annotation, a corrected matrix cell, a corrected ledger Note, a corrected decision citation, a narrowed
  withdrawal reason, a new Level-1 notification (**N10**), four stale line references, a gap closed, and four
  citation spans. **No board was touched, no interaction pattern, navigation or information-architecture
  surface changed, no primary-action structure changed, and no design decision was made.** N10 is Level 1 by
  the same routing N2 already uses; recording it does not move the level. § 5's read-back still documents an
  appearance the code already produces rather than choosing one.

**No human gate is raised by this revision.** B3 remains with decision `27ea6536` and is not re-opened.
`Art S` stays `PENDING D4` under open gate `9417f8bf`; the at-rest protection model remains the human's
decision at Gate D4, and revision 4 records it as open rather than as settled.

> ⚠️ **REVISION 5 — THE SENTENCE ABOVE IS NOW FALSE AND WAS ACCURATE WHEN WRITTEN.** `9417f8bf` is
> **`RESOLVED`** (OPTION_C / A3, `decided_at 2026-10-06T13:05:00Z`); the at-rest protection model **was settled**
> at Gate D4, by the human; and `Art S` **no longer stays `PENDING D4`** — it is renamed and corrected on all
> four boards. Revision 4 recorded it as open *because it was* open. `B3`/`27ea6536` is likewise **RESOLVED**
> and was not re-opened — it was **decided**. See `design-revision-5.md` §2, §3, §4.

---

## 12. The verification-discipline lesson (revision 3's, retained — and extended by this pass)

The re-reviewer's closing judgement was that this lane's *judgment* was good and its *verification
discipline* lapsed where it stopped checking. Four lapses were corrected (H-N1, M-N1, M-N4, M-N6) and
one dispatched correction was itself wrong (§ 1.1). The pattern behind all five is worth writing down,
because it is not a knowledge gap:

> **Every one of those was a check this lane had already performed correctly somewhere else in the same
> document.** `Trust Btn L`'s centring was checked against `Submit L` and missed against the desktop
> board; the desktop `TechnicalDetails`' surface was checked on mobile and missed on desktop; the nav
> label's token was checked for `microLabel` and missed for the active item; the deletion was asserted
> instead of re-read.

The operational rules that follow:

1. **A comparison needs both operands.** Comparing box `x` without comparing `align` is not a comparison;
   comparing mobile without comparing desktop is not a comparison. Name both sides before concluding.
2. **Re-read the artifact before claiming anything about it.** Every M-N6-class failure is a claim about a
   file made from memory of having written it.
3. **A finding is a set of claims.** Apply the ones that survive checking and say which you rejected.

### 12.1 The fourth rule, written by this pass (M-R1, M-R2, L-R1, L-R3)

**Revision 3 broke rule 2 about its own artifacts, one pass after writing rule 2.** It annotated a measured
AA failure with *"now unused on these boards"* — a claim about four boards, asserted without opening one. It
then persisted a lesson to *"§ 13"*, a section that does not contain it, and cited line numbers that its own
markers had shifted. Three rules follow, and all three are the same rule seen from a different side:

4. **A ledger that annotates away a measured failure is worse than one that reports it**, because the
   annotation converts a **known** defect into an **invisible** one. Report the failure, name the call site,
   route it to the owner. An annotation that minimises a measured result is itself a result, and it is the
   only kind here that nobody re-measures.
5. **An AA verdict must name the surface it was measured on, or it does not exist.** `4.23:1` is not a
   property of `inkTertiary`; it is a property of `inkTertiary` **on `card`**. The same ink is 4.62:1 —
   passing — on `canvas`, which is the surface the board draws. That single missing word is what let an AA
   failure read as a non-issue for two review cycles, and it is the same omission M-N2 was dispatched to fix
   in the matrix.
6. **A cross-reference is a claim about a file; re-read it like one — including after you edit the file it
   points into.** A marker written *at* a cited line moves that line. Revision 3 cited `design-revision.md:70`
   and `:414` correctly **when it wrote them**, then invalidated both by inserting markers, and never went
   back. That is rule 2 one level down.

**And the counter-rule, which is the reason this section exists at all:** revision 1's provenance block is
**still accurate** (`/private/tmp/shipit-design-addproduct-mobile` on `design/addproduct-mobile` — both exist
in `git worktree list`) and the reviewer was right that it must be left alone. Correcting a record means
correcting what is wrong, never rewriting what is right to look tidy.

---

## 13. Assumptions carried forward

Unchanged and still pending `design-addproduct-keyservice`: **A1** "Check access" does not rotate the key ·
**A2** the trust outcome is persisted server-side · **A3** `hostUnrecognised` is a page state, not a modal
sheet · **A4** the trust decision is not a register event · **A5** (revision 2)
`Confirm the host above to enable Register product.` is the string `hostUnrecognised` will produce
(G10/M-R3).

**A6** (revision 3). The § 5.1 disabled appearance is derived from Flutter 3.44.7's `_FilledButtonDefaultsM3`
plus `core/theme.dart:32`, read from the SDK source at
`/Users/alkebut/fvm/versions/3.44.7` (the version this repository pins). **It is not executed** — no
Flutter widget was rendered in this lane. If the project moves to a framework version whose
`ButtonStyle` precedence differs, the resolution must be re-derived; the *shape* of the argument
(`defaultColor` → `WidgetStateMapper` returns `null` on the first satisfied key → `effectiveValue`
falls through to the M3 default) is what makes it checkable rather than a remembered number.

**A7 is new.** The contrast figures in § 3.2 were **recomputed this pass** from `design_tokens.dart:91-130`
with an independent WCAG 2.1 implementation (sanity: black-on-white **21.00**, white-on-white **1.00**), and
every value reproduced the published one to two decimals. The **surface attribution** — which rect a given
text layer actually sits on — was established by a read-only subtree sweep of the live Penpot file (§ 9.1),
not by reading layer names. **A7 is that a layer's name is not evidence of its surface**; `Art K` reads as a
free-floating eyebrow and is in fact inside `Art Bg` = `card` on all four boards.

**A8 is new.** The two gate-D4 decision objects this lane cites — `9417f8bf` (PENDING) and `27ea6536` — are
**not present at this worktree's HEAD `77c19f1`**; they were filed in commit **`064703d`**, its child, and were
read at the canonical checkout (`3a87e27`). Revision 3 already cited `27ea6536` on this footing. The
consequence for a reviewer: a design artifact's `BASE_SHA` and the decision objects it cites are **not
guaranteed to be in the same commit**, and this lane records the commit each was filed in rather than leaving
a bare id that resolves in one checkout and not another.

---

## 14. Revision 4 changelog — per finding, with the exact text replaced

The Gate D3 re-review of revision 3 returned `RESULT: DESIGN_REVIEW_CHANGES_REQUIRED`,
`CORRECTION_REQUIRED: YES`, `HUMAN_DECISION_REQUIRED: NO`, **0 BLOCKERS, 0 HIGH**, and
`INDEPENDENT_RISK_LEVEL: 2`. Seven items were dispatched; six are corrections and one (L-R4) is record-only.

| Finding | Where | Text removed → text written |
|---|---|---|
| **M-R1** | § 3.2 ledger row | `\| \`inkTertiary\` \| \`card\` \| 4.99:1 \| 4.23:1 \| pass / **FAIL** \| now unused on these boards \|` → `… \| pass / **FAIL** \| **\`Art K\` (\`DEPLOY KEY · THIS PRODUCT ONLY\`), inside \`Art Bg\` = \`DesignPanel\` = card, all four boards; board and build agree — AA FAIL in dark** (M-R1, N10) \|` |
| **M-R1** | § 3.2 N7 withdrawal | `**N7 is withdrawn.** … but no Add Product call site puts these lines on \`card\`, so it is not Add Product's finding to raise.` → `**N7 is withdrawn — for the \`TechnicalDetails\` lines only.**` + a block quoting `Art K` as the counter-example and pointing at N10 |
| **M-R1** | § 8 N7 status cell | `…There is no \`card\` surface under these lines anywhere in Add Product.` → the same sentence **scoped to these lines**, plus `⚠️ **M-R1 (this pass):** … that generalisation is **false**: \`Art K\` does.` |
| **M-R1** | § 8 notification list | **added row `N10`** — `ShipItPalette.inkTertiary` fails AA on `card` in dark (4.23:1), live call sites `:533`/`:1029`, routed as design-system-owned exactly as N2 does for `negative`. Level 1; **no risk-level movement** |
| **M-R1** | § 11 / § 10 / § 3.2 | **added reason (c)** to `ux_accessibility_score` (`Art K` 4.23:1 in dark, N10); **added G13** to the gap table; **added a MATERIAL bullet** to § 10 |
| **M-R2** | § 6 matrix cell | `\| \`Submit Sub\` helper below button \| **R2**, **R5** \| human 2e + R5 \| \`monoMeta\` 10/400; **\`inkSecondary\`** \|` → the same row with **\`inkTertiary\` (\`add_product_page.dart:918\`)**, the **surface note the \`Submit\` row carries**, the board's `inkSecondary` named as the aspirational value the board keeps, and both surfaces' ratios (6.28/6.65 on `canvas`; 4.65/4.62 on `canvas` and **4.99/4.23 on `card`**) with the dark `card` figure recorded against N10 |
| **M-R3** | § 6 matrix cell | `\| \`Art S · PENDING D4 (at-rest model)\` \| R1, R6 \| **b869ec24** \|` → `… \| **9417f8bf (PENDING D4)** + \`b869ec24\` (RESOLVED — server-side storage constraint only) \|`; **new § 6.1** explains both halves and states that the layer, its string and its `PENDING D4` marker are untouched |
| **L-R1** | § 0 (was `design-revision-3.md:37`) | `**The lesson is now persisted** (§ 13, \`WORKFLOW_IMPROVEMENT\`)` → `**The lesson is persisted** (\`design-revision-3.md\` §0 **and §12**; classified \`WORKFLOW_IMPROVEMENT\` entries at \`correction-report-3.md:261-281\`)` |
| **L-R2** | § 11 gap table + metadata | `\| G11 \| the mobile design review report was never persisted (revision 2 § 0) \| \`LANES.md\` is PROHIBITED; Manager-owned… \|` → `\| ~~G11~~ \| … \| **CLOSED in revision 4 (L-R2).** … exists (commit \`25f723d\`) … "This file is the authoritative copy; the correction lane's G11 is now closed." \|`, and `G11` **removed from `non_requirement_gaps`** in the metadata |
| **L-R3** | § 0.1 (new) + § 7.1 table + the two retained headers | `design-revision.md:70`, `:72-73`, `:414`, `report.md:48`, `:100`, `:197`, and both headers' own stale numbers → the live numbers (`:77`, `:79`, `:429`, `:62`, `:120`, `:224`), each shown as `**was …**` so the drift is visible rather than quietly erased. `design-revision-metadata.yaml:15-16` verified **still correct** and left alone |
| **L-R4** *(record only)* | § 3.3, § 5.1 | `MobilePrimaryButton (\`:904-911\`)` → `(\`:902-911\`)`; `the \`FilledButton\` (\`:679\`)` → `(\`:678\`, its \`onPressed:\` at \`:679\`)`; `button_style_button.dart:266-273` → `:266-274`; `button_style_button.dart:381-391` → `:382-387`. **Not recorded as a finding** — every load-bearing citation was already exact |

**Not touched, deliberately:** H-N1, H-R1, M-N5, M-N1, M-N4, M-N3, L-N4, M-N6, L-N2, L-N3 (all confirmed
closed by the re-review); `27ea6536` (B3), N1, N2, N4, N6 (not re-raised); the `Art S` string and its
`PENDING D4` marker; and **every board** — 0 edits, 0 creations, 0 renames, 0 moves, 0 deletions.

> ⚠️ **REVISION 5 — TWO ITEMS ON THAT "not touched, deliberately" LIST WERE TOUCHED, DELIBERATELY, AT
> REVISION 5.** (a) **The `Art S` string and its `PENDING D4` marker** — both corrected/retired on **all four
> boards** under `9417f8bf`. (b) **Every board** — revision 4 edited none; **revision 5 edited four** (the `SM`
> pair for custody + the `Unknown host` pair for `898b07d0`). Items (c) `27ea6536` and (d) N1/N2/N4/N6 remain
> correctly untouched, though (c) was **decided** rather than merely filed. No BPM or `S` board was touched by
> revision 5 either — those remain read-only, and finding **F6** records that they do not conform to the
> resolved footer spec.

**The one thing this pass did not do, and it is deliberate:** it did not persist the Gate D3 re-review report
of revision 3. That document is the independent reviewer's, it is not in this lane's `OWNED_PATHS`, and
writing it here would be authoring a review of my own work. § 15 records where it was read from and what is
missing.
---

## 15. Provenance gap I am reporting rather than closing — the revision-3 review report

The dispatch for this pass directed me to read
`docs/engineering/dispatch/tasks/design-review-addproduct-mobile/report-revision-3.md` **in full**.

**That file does not exist.** Not in this worktree, not at the canonical checkout, not in any object
reachable from any ref:

```
$ ls docs/engineering/dispatch/tasks/design-review-addproduct-mobile/     # canonical, 3a87e27
report.md  report-revision-2.md
$ find /private/tmp/shipit-correct-addproduct-mobile /Users/alkebut/air/shipit-platform \
       -name 'report-revision-3.md'                                       # → no output
$ git log --all --oneline -- '**/report-revision-3.md'                   # → no output
$ grep -rl 'B5006A15' docs/                                             # → 4 files, all in design-addproduct-mobile/
```

`docs/engineering/dispatch/tasks/design-review-addproduct-mobile/` **does not exist in this worktree at all** —
the worktree's HEAD is `77c19f1`, and the review directory arrived at `25f723d`, one commit later.

**What I did instead, and what it costs.** The findings were dispatched to me verbatim, including the
reviewer's own `RESULT` line, its judgement quoted at length, and for each finding the exact file, line,
board layer and proposed text. I applied **those**, and I did not take a single one on faith: every claim was
re-derived from source at `77c19f1` and from a read-only sweep of the live Penpot file (§ 1.2). All seven
were confirmed on substance; the two provenance facts the dispatch did not state (`9417f8bf` and
`design-review-…/report.md` both postdate this worktree's HEAD) are recorded in § 1.2 and A8.

**The gap that remains:** I cannot assert that the dispatch transcribed the review exhaustively. If the report
contains a finding the dispatch omitted, this revision does not know about it. **This is reported to the
Manager as a provenance caveat, not as a blocker** — it is the same class as G11 one generation earlier, and
`LEARNING_POLICY.md`'s rule is the operative one: *never rely on in-memory-only state.* The fix is not mine to
make; persisting an independent review is the reviewer's and the Manager's, and I will not author a review of
my own work.
