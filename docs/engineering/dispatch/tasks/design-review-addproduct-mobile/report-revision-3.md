# Report — Independent Design Re-Review, mobile boards, Revision 3 (Gate D3, cycle 3)

Persisted per `aef-orchestrator` §14. Reviewer: a **fresh** `design-reviewer`, read-only, who produced
neither the design nor any of its three correction passes.

> **Persistence note.** This report was returned and parsed but not written to disk before the correction
> lane was dispatched; the lane found it absent and **declined to author it** — correctly, since the review
> directory is not its `OWNED_PATHS` and writing it would be self-approval. This file is the authoritative
> copy. The cycle-4 lane applied its findings as dispatched and re-verified each independently.

**REVIEWED_HEAD `77c19f114ee691e8c434afe37b7c84494b66dc40`** — worktree
`/private/tmp/shipit-correct-addproduct-mobile`, branch `design-correct-addproduct-mobile`,
`BASE_SHA == HEAD_SHA == 77c19f1`, `committed: NO`. Canonical checkout was `3a87e27`; the four rev-3
artifacts were byte-identical in both checkouts and `git diff 77c19f1..3a87e27 -- apps/ packages/ docker/
Makefile` was empty, so all source citations remained valid.

REVISION_ID `B5006A15-2DEE-47BE-BF2F-C44196B089E3` (revision 3), supersedes `1F8DC787-…` (rev 2),
supersedes `65995C2B-…` (rev 1).

```
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
REVIEWED_HEAD: 77c19f114ee691e8c434afe37b7c84494b66dc40
BLOCKERS: NONE
HIGH: NONE
CORRECTION_REQUIRED: YES
HUMAN_DECISION_REQUIRED: NO
INDEPENDENT_RISK_LEVEL: 2
RISK_LEVEL_AGREEMENT: YES
```

## Producer claims — each independently reproduced

**H-N1 — CLOSED, verified at the property, not just the arithmetic.** `Trust Btn L · PROVISIONAL (G1
hostUnrecognised)` reads `align: "center"` on both Unknown boards; box x=7580 w=180; `textBounds.width` =
79.265625 → inset **50.3671875**. The `Trust Btn` rect is x=7580 w=180, so the left edge genuinely
coincided and centring was required. Desktop `Host Btn L` is `align: "center"` on **both** `S · Add Product ·
Unknown host · Light` and `· Dark`, w=180, textW 79.2578125 → **50.37109375**. Both figures reproduce
exactly. H-R1 also still closed: `Trust Host` = `#5a5c5b`/`#a8a6a0` on `Trust Bg` = `#ffffff`/`#262827`.

**M-N5 — CLOSED, and the derivation is better than the dispatched premise.** The pinned SDK was read line
by line: `filled_button.dart:287-288` (`styleFrom` wraps in `defaultColor`) → `button_style_button.dart:267-274`
(`fromMap({disabled: null, any: enabled})`) → `widget_state.dart:1008-1013`, which is precisely
`for (…) { if (key.isSatisfiedBy(states)) { return entry.value; } }` — the first satisfied key's value
**even when null** → `button_style_button.dart:382-387` `widgetValue ?? themeValue ?? defaultValue` →
`filled_button.dart:548-562` `onSurface.withOpacity(0.12)` / `(0.38)` → `theme.dart:32 onSurface:
palette.inkPrimary`. `themeStyleOf` = `FilledButtonTheme.of(context).style` (`:469`), `defaultStyleOf` =
`_FilledButtonDefaultsM3(context)` (`:432-434`). `MobilePrimaryButton` (`mobile_chrome.dart:424-445`) is a
bare `FilledButton` with no style overrides, so the same chain holds. Composites reproduce to the byte:
`#E4E4E4` + `#999A9A` (**2.22:1**), `#3F403F` + `#848482` (**2.78:1**), over **`card`** — not canvas. Both
read-back groups exist as **page-level** groups (parent = page root), 6 children, 358×121, at
(7550,11600)/(7970,11600), **zero overlaps against all 160 boards**, lowest shape 11721 with **79px**
clearance. **The page-level trade is the right call and would not have been redone** — it leaves all four
boards' geometry and counts untouched, so §7.4 stays reproducible.

**M-N1 — CLOSED.** Desktop `TechnicalDetails` at `add_product_page.dart:316` is a sibling of the `Row`
(`:302-312`) carrying `_RightPanel` (`:309`); `_RightPanel`'s `DesignPanel` at `:632`;
`scaffoldBackgroundColor: palette.canvas` at `theme.dart:23`; mobile `TechnicalDetails` at `:925`, outside
the `DesignPanel` at `:853`. All thirteen ledger figures re-measured with an independent WCAG 2.1
implementation (sanity black-on-white **21.00**, white-on-white **1.00**) against
`design_tokens.dart:99-101`/`:120-122`: **every figure reproduces to ±0.00**, including the collapsed
4.65/4.62 row.

**M-N4 — CLOSED.** `Nav Label 3` reads **10/600** with fill `inkPrimary` on all four boards; `Nav
Label 0/1/2/4` are 10/400 ✓. `mobile_chrome.dart:296-298` confirms the expression.

**M-N3 / L-N4 — CLOSED.** Reproduced: **44/44/36/36** top-level, **29/29/24/24** text (rule: every
`type === 'text'` in the subtree), 160 boards / 164 root children, 4 non-board root shapes. `Register
product` exact **1/1/1/1**, substring **2/2/1/1**, forbidden strings **0**.

**M-N6 / L-N1 — CLOSED.** Markers real at every named site. "Superseded, not deleted" restated. Prohibited
boards verified untouched: `BPM · Add Product · Light/Dark` 36/36; `S · Add Product · …` 69/69/65/65.

**L-N3 rejection — CORRECT.** `grep -n` returns `424:class MobilePrimaryButton extends StatelessWidget {`
and `425:  const MobilePrimaryButton({`; the doc comment is `:422-423`. Revision 2's `:424` was already
right. The review's third item was wrong and declining to apply it was right — applying it would have
introduced the off-by-one the citation exists to prevent.

**`Art S` — still `PENDING D4`**, unresolved on all four boards. **No correction resolved it.**

**G12/N9 — REAL, correctly identified, verified on both sides.** Boards: `Submit` rect spans y 11428–11462;
`Art Bg` ends 11236, `Trust Bg` ends 11412; board background `#f7f7f5`/`#1f2120` = `canvas`. Code: mobile
`MobilePrimaryButton` at `:902` inside `DesignPanel(` at `:853`; desktop `FilledButton` at `:678` inside
`DesignPanel(` at `:632`; both `palette.card`. Declining to fix it is **correct** — drawing the panel is
G5/F1, a UX decision. But G12 is **not merely cosmetic**: it is load-bearing for two AA verdicts — `Art K`
and `Submit Sub` both pass on `canvas` and fail on `card` in dark.

## MEDIUM

### M-R1 (NEW) — `inkTertiary` on `card` is a live AA failure that the ledger annotates away

`DesignPanel` = `palette.card` (`design_primitives.dart:320`). `MicroLabel('DEPLOY KEY · THIS PRODUCT ONLY',
color: palette.inkTertiary)` is at `add_product_page.dart:533` (desktop, inside `DesignPanel(` at `:503`) and
`:1029` (mobile, inside `DesignPanel(` at `:1002`). **The boards are faithful to that**: `Art K` =
`#6e706e`/`#8a8983` inside `Art Bg` = `#ffffff`/`#262827` = card, on all four boards. Every text layer on
both Unknown boards was swept against the card-coloured rects — **`Art K` is the only `inkTertiary` text on
card**, so the set is complete.

Yet `design-revision-3.md` §3.2 marks the row `inkTertiary`/`card` as `pass / FAIL` (4.99:1 light, 4.23:1
dark) and annotates it **"now unused on these boards"**. **That annotation is false.** §8's N7 withdrawal
reasons "no Add Product call site puts these lines on `card`, so it is not Add Product's finding to raise"
— true of the TechnicalDetails lines, false once generalised; `Art K` is exactly such a call site.
`ux_accessibility_score_reason` (a) names only `Key State`/`negative`.

**FIX (record-only, no board change — the board is correct):** (i) delete the annotation; (ii) name `Art K`,
the surface and the FAIL in the row's Note; (iii) add reason (c) to `ux_accessibility_score_reason` citing
4.23:1 on `Art K`; (iv) add notification **N10** (Level 1, design-system owner) — Level-1 notification, does
not move the risk level.

### M-R2 (NEW) — the matrix names the WRONG foreground token for the primary action's helper

Board, all four: `Submit Sub · helper BELOW button` = `#5a5c5b`/`#a8a6a0` = `inkSecondary`.
Matrix §6 row says `inkSecondary`. Build: `add_product_page.dart:918` = `palette.inkTertiary`. Surface:
board `canvas`; code `card` (inside `DesignPanel(` at `:853`); on the board `Submit Sub` (y 11470–11485) is
outside every panel, since `Trust Bg` ends at 11412.

**The same foreground is 4.62:1 (pass) on canvas and 4.23:1 (FAIL) on card in dark**, so M-R1 and M-R2
compound and this row cannot carry a verdict without naming the surface — the exact omission M-N2 was
dispatched to fix. Note the asymmetry: the `Submit` row **does** carry "Surface = `card` in code, bare page
background on the board (G12)".

**FIX:** set the cell to the build's `inkTertiary`, add the same surface note, and state explicitly which the
board keeps. **This is the row implementation and QA inherit as the acceptance baseline**, which is why it
is not a follow-up note.

### M-R3 (NEW) — the matrix's "Settled by" for `Art S` points at a RESOLVED decision, not the PENDING one

§6: "`Art S · PENDING D4 (at-rest model)` | R1, R6 | **b869ec24**". `.decisions/b869ec24-…yaml` is
`status: RESOLVED` and asks *where deploy-key generation and storage belongs* — **not** the at-rest
substrate. The open gate is `.decisions/9417f8bf-…yaml`, `status: PENDING`. Revision 3 and its metadata
cite `9417f8bf` **zero times**.

The layer name, §8, §11's G2 and the metadata all correctly keep it PENDING — **the human's decision has NOT
been quietly resolved, and that is the important part.** The defect is confined to one cell, but it is the
cell telling a reader which authority closed a design element, on the one row that is explicitly not closed:
invariant 8 failing in the direction that makes an open gate look settled.

**FIX:** that cell becomes `9417f8bf (PENDING D4)`, with `b869ec24` alongside for the constraint it does settle.

## LOW

- **L-R1** — `design-revision-3.md:37` says the `WORKFLOW_IMPROVEMENT` lesson is persisted "**§ 13**". §13
  is *Assumptions carried forward* (A1–A6) and contains no learning. The lesson is in §0 and §12; the
  classified entries are `correction-report-3.md:261-278`. Same "claim about an artifact made from memory"
  class that §12's own rule 2 forbids.
- **L-R2** — **G11 is stale.** `tasks/design-review-addproduct-mobile/report.md` now exists (commit
  `25f723d`) and its own header states G11 is closed. §11 and the metadata still list G11 as open.
- **L-R3** — the withdrawal markers invalidated their own line citations; §7.1 and the metadata cite
  `design-revision.md:70`/`:72-73`/`:414` and `report.md:48`/`:100`/`:197`, but after insertion those sites
  sit at `:83`/`:429-436` and `:62-65`/`:120-122`/`:224-232`. `design-revision.md:7` states "line 414"
  flatly. The markers are unambiguous about *what* is withdrawn, but the numbers no longer resolve.
- **L-R4** — citation slack recorded **so it is not mistaken for a defect and not re-raised**:
  `MobilePrimaryButton` at `:902` (rev-3 says `:904-911`); `FilledButton` at `:678` (rev-3 says `:679`,
  which is the `onPressed:` line — the review's usage was correct); `defaultColor` at `:267-274`;
  `effectiveValue` at `:382-387`. **Every load-bearing citation is EXACT:** `onPressed:` null at `:906` and
  `:679`, `DesignPanel` at `:853` and `:632`, `TechnicalDetails` at `:316` and `:925`, `palette.card` at
  `design_primitives.dart:320`, TechnicalDetails ink at `:391`, and all ten `design_tokens.dart` lines.

## Traceability gaps

- **CLOSED:** the three wrong rev-1 matrix rows; the matrix is now revision 3's own and names surface and
  alignment — **the omission that let an AA-failing layer and a 0px-inset label through two reviews.**
- **CLOSED:** `canRegister == false` now has a traced design element — two page-level read-back groups plus
  N4/G9 kept for the token.
- **STILL OPEN (correctly):** `Confirm the host above to enable Register product.` has no producing state —
  G10, AMBIGUOUS, A5, arrives with the sibling lane's `hostUnrecognised`.
- **STILL OPEN (new):** `Art K` (`inkTertiary` on `card`, dark 4.23:1) is a live AA failure the ledger
  annotates as unused — M-R1.
- **STILL OPEN:** G12/N9 — the surface under the primary action differs between board and build on both
  platforms. The lane is right not to have drawn the panel, but **G12 is load-bearing for M-R1 and M-R2**,
  not merely cosmetic, and should not be parked as if it were.
- **ACCEPTED:** R1–R7 covered, `requirements_gaps: []`.

## Safe parallelism

**SAFE:** the sibling `design-addproduct-keyservice` (disjoint paths; the Unknown-host helper string is
traced to ITS `hostUnrecognised` state as A5/G10) · NON-UI implementation preparation on
`add_product_page.dart` (mock-key removal `:126-138`, the missing `AccessStatus.verified` producer —
independently confirmed nothing ever **ASSIGNS** `verified` — and first-ever test coverage) · copy
corrections in production source, all confirmed still false: `add_product_page.dart:383`, `:385`, `:539`,
`:1035`, `product_detail_page.dart:614` · implementation of H-N1's centring and M-N4's active-nav weight,
which now have unambiguous specs.

**PROHIBITED:** freezing this revision while M-R2 stands (the mandatory matrix would hand implementation and
QA a wrong acceptance baseline) · visual-QA golden-baseline capture (still blocked by F6 — 34px board submit
vs 36px `MobilePrimaryButton` — and now by M-R2) · any lane editing `BPM · Add Product · Light/Dark` or the
desktop boards · any change to `Art S`'s string or its `PENDING D4` marker.

## NOT RUN

`flutter analyze` — **NOT_RUN** (`package_config.json` absent, so ~8090 `undefined_identifier` would be
package resolution, not a real failure; no feasibility claim rests on it) · any Docker or Compose command —
**NOT_RUN**, none issued · no Flutter widget rendered (the disabled colours are a derivation from framework
source plus `core/theme.dart`, **not screenshots of a running app**) · automated pixel diff — **NOT_RUN** ·
full layer walk of the four desktop boards — **PARTIAL** (identity, position, size, child counts, `Host Btn`,
`Host Btn L`, `R Submit L` read — what H-N1 required) · the pre-edit state of `Trust Btn L` is not
independently re-verifiable from the live file (the Penpot API exposes no version history); verified instead
that the box is still x=30 w=180, so `align: left` would put the glyphs at the button's border, and that
`align` is now `center` with everything else unchanged · nothing persisted, no board edited.

## Is a fourth correction pass warranted? — **Yes, and it is not a loop**

> *"One bounded pass is warranted. All four items are record corrections inside `OWNED_PATHS` requiring zero
> board edits and zero new design judgment … **I will not record them as non-blocking follow-ups** …
> Freezing that hands implementation and QA a wrong acceptance baseline — the same harm that made H-R1 a
> HIGH in the rev-2 review, on the identical 4.23:1 number. **Approving because it is cycle 3 would relax a
> standard on the basis of the calendar.**"*

The escalation for M-R1, if cheaper, belongs to the **design-system owner** — `ShipItPalette` has no
AA-compliant dark `inkTertiary`, exactly as N2 already records for `negative`. N10 can be filed at Gate D4
alongside N2 and N4 without any lane. M-R2, M-R3 and L-R1–L-R3 are record fixes carrying no authority
question. **`9417f8bf` stays with the human at D4; nothing here disturbs it.**

## Reviewer's closing judgement on the lane

> *"On the record layer this lane is now in better shape than the review that is reviewing it; the two
> findings above are in the layer the rule it wrote for itself does not cover — every text layer on every
> board against the surface it is actually drawn on."*
