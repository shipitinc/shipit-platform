# Design Revision 3 — Add Product mobile boards, correction pass 2 after Gate D3 re-review

> **SUPERSEDED — this is revision 3. The current revision is `design-revision-4.md`, and its metadata is
> `design-revision-metadata-4.yaml`.** This file is retained **unedited** so the correction history stays
> diffable. Revision 4 is a **record-only** pass: **it changed no board, no layer and no shape.** It
> overturns four claims in this file, each of which is a record defect rather than a design error:
>
> 1. **§ 3.2's contrast ledger annotated away a live AA failure.** The row `inkTertiary` on `card`, marked
>    `pass / FAIL` at **4.23:1 in dark**, carried the note *"now unused on these boards"*. **That annotation is
>    false**: layer `Art K` ("DEPLOY KEY · THIS PRODUCT ONLY") is `inkTertiary` inside `Art Bg` = card on all
>    four boards, and the build does the same at `add_product_page.dart:533`/`:1029`. Board and build agree;
>    the dark figure is an AA FAIL. Recorded as **N10** with the design-system owner (Level 1). See
>    `design-revision-4.md` § 3.2.
> 2. **§ 6's `Art S · PENDING D4 (at-rest model)` row named the wrong authority.** Its "Settled by" cell read
>    `b869ec24`, which is `RESOLVED` and settles *where* the keypair lives — not the at-rest substrate. The
>    open human gate is **`9417f8bf` (`PENDING`)**. See `design-revision-4.md` § 6.1. **The layer's name, its
>    string and its `PENDING D4` marker are unchanged and remain open.**
> 3. **§ 6's `Submit Sub` helper row named `inkSecondary`**, which is what the boards draw; the build renders
>    `palette.inkTertiary` (`add_product_page.dart:918`), and the row named no surface. See
>    `design-revision-4.md` § 6.
> 4. **§ 0 and § 7.1 cite line numbers that this file's own withdrawal markers invalidated** (and § 0's
>    lesson was persisted to "§ 13", which does not contain it). See `design-revision-4.md` § 0.1.
>
> Substantive text left unedited. Four pointer lines were added below, at the sites a reader lands on.

Per `docs/engineering/DESIGN_GOVERNANCE.md` § *Artifacts → Design Revision*. Metadata in
`design-revision-metadata-3.yaml`. **Revisions 1 and 2 are retained unedited** as `design-revision.md` and
`design-revision-2.md`; this file is the current revision. Each retained file now carries a one-line
**supersession header** naming the claims revision 3 overturns (§ 7.1).

```yaml
revision_id: B5006A15-2DEE-47BE-BF2F-C44196B089E3
brief_id:    52CB4098-FF87-4B78-81DA-1104269551A1
revision_number: 3
supersedes:  1F8DC787-E88C-4DF2-B2CC-E8B0E60BBF67   # revision 2, retained intact
status: UNDER_REVIEW          # the Design Agent never approves its own work
```

Provenance — worktree `/private/tmp/shipit-correct-addproduct-mobile`, branch
**`design-correct-addproduct-mobile`** (`git branch --show-current`, `git worktree list`; revision 2
recorded this wrongly and § 7.2 corrects it), `BASE_SHA` = `HEAD_SHA` =
`77c19f114ee691e8c434afe37b7c84494b66dc40`. Nothing committed, nothing pushed.
**No Docker or Compose command was run at any point in this lane**, including read-only ones.

---

## 0. A false claim of mine, corrected before anything else

Revision 2's `design-revision-metadata-2.yaml` (`risk_rationale`, `corrections_applied.M-R1`) and
`correction-report.md:67` state that the "36px" claim *"has been deleted from § 2a, from the `risk_rationale`
and from `report.md`"*. **It was deleted from none of them.** It survives verbatim at
`design-revision.md:70`, `:72-73`, `report.md:48`, `report.md:197` and
`design-revision-metadata.yaml:15-16`. This is finding **M-N6**, and it is the same failure mode F8 was
deleted for: asserting a record rather than checking one.

**The corrected statement is "superseded by revision 2 §6a, not deleted."** Retaining revision 1
byte-identical is a legitimate and deliberate choice — it is what makes the correction diffable — so the
fix is a withdrawal marker, not a deletion. Markers are applied and listed in § 7.1.

**The lesson is now persisted** (§ 13, `WORKFLOW_IMPROVEMENT`): byte-identical retention silently
resurrects a disproven claim for whoever opens the file first. **Retention requires an explicit withdrawal
marker**, or the retention is not neutral.

> ⚠️ **BOTH CROSS-REFERENCES IN THIS PARAGRAPH ARE WRONG — CORRECTED AT REVISION 4 § 0.1 (L-R1, L-R3).**
> The lesson is **not** in § 13; § 13 is *Assumptions carried forward* (A1–A6). It is in **§ 0 (this
> paragraph)** and **§ 12**, and its classified entries are at **`correction-report-3.md:261-281`**. The line
> numbers cited above (`design-revision.md:70`, `:72-73`, `report.md:48`, `:197`) no longer resolve either.

---

## 1. Independent verification of every dispatched finding

Every finding was re-checked against source at `77c19f1` and against the live Penpot file before I acted.
Nothing was applied on the dispatch's authority alone. **One dispatched item is partly wrong (§ 1.1).**

| Finding | Dispatched claim | My independent verification |
|---|---|---|
| **H-N1** | `Trust Btn L` is `align: left`, 0px inset; desktop `Host Btn L` is `align: center` | **CONFIRMED exactly.** Mobile `Trust Btn L`: `align: left`, `growType: fixed`, box x=30 w=180, rendered width **79.266**, so the glyph inset is **0px**. `Trust Btn` rect is x=30 w=180 → the label box's left edge *is* the button's left edge. Desktop `Host Btn L` on **both** `S · Add Product · Unknown host · Light` and `· Dark`: `align: center`, same 180-wide box at x=254, rendered width 79.258 → inset **50.371px**. My own `Submit L` is also `align: center`. So the mobile boards were the single place in the set that diverged from both the desktop pattern and the primitive. |
| **M-N1** | the desktop `TechnicalDetails` is also on `canvas`; no `card` surface lies under the expanded lines on either platform | **CONFIRMED exactly, and it is worse than the review states for my own ledger.** `add_product_page.dart:316`'s `TechnicalDetails` is a direct child of the desktop page `Column` (inside `SingleChildScrollView` → `Padding` → `Column`), a **sibling** of the `Row` at `:303-311` that carries `_RightPanel`; `_RightPanel` is the `DesignPanel` (`:632`) and contains only "What happens next", "Registering is not governing.", two `ContentRule`s, the four `_StepText`s and the `FilledButton`. `scaffoldBackgroundColor: palette.canvas` (`core/theme.dart:23`). Mobile `TechnicalDetails` at `:925` sits **outside** the `DesignPanel` at `:853`. So the surface is `canvas` on both platforms, and revision 2's `card` row described a surface that does not exist beneath these lines on any platform. |
| **M-N2** | revision 2 has no matrix of its own; revision 1's carries three wrong rows | **CONFIRMED exactly.** `design-revision.md:325` `Art T` → "`bodySmall` w600"; `:335` `Bottom Nav` → `inkQuiet`/`inkPrimary`; `:330` `Trust K/Body/Body 2/Host` → no foreground token. A corrected matrix is added in § 5. |
| **M-N3** | `penpot-board-evidence.md` publishes `42/42/34/34`, a bare `Register product` count of `1`, and §3/§5 text that predates the last pass | **CONFIRMED exactly.** Live top-level layer counts are `44/44/36/36`; live text-layer counts are `29/29/24/24`; under revision 2's own substring rule the Unknown boards' `Register product` count is **2**. Regenerated in § 6. |
| **M-N4** | `Nav Label 3` is w400 where `mobile_chrome.dart:297` renders the active label at `w600`; the "clone of a PROHIBITED board" reason does not hold | **CONFIRMED exactly.** `Nav Label 3` ("Products") was 10/400 on all four boards while the other four were also 10/400 — the active tab was indistinguishable by weight, and its fill (`#1f2120`/`#f5f4f0`) is `inkPrimary`, i.e. it is the active tab. `mobile_chrome.dart:296-298` is `navLabelMobile.copyWith(fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: tone)`, and `navLabelMobile` is 10px (`design_tokens.dart:500`). **The review is right that my stated reason does not hold**: the four boards I own and everything inside them are in scope, and § 2's own resolution of `microLabel` tracking ("my boards follow the token; the reference board is low-fidelity here") applies verbatim here. |
| **M-N5** | `FilledButton` receives `onPressed: null` when `canRegister == false`, `core/theme.dart:67-83` sets only enabled colours, so M3 disabled defaults apply and the button will not paint the accent at opacity 1 | **CONFIRMED — and I derived the exact resolved colours from the Flutter 3.44.7 source rather than assuming them (§ 5a).** `add_product_page.dart:906` and `:679` both pass `null` when `canRegister == false`; `core/theme.dart:67-83` sets no `disabledBackgroundColor`/`disabledForegroundColor` (grep for both: **no match** in the file). The resolution chain is in § 5a and is worth stating because the obvious reading is wrong. |
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
substance and wrong on one detail. The rule that follows is the one I should have applied throughout: a
finding is a set of claims, and each claim gets checked.

---

## 2. H-N1 — `Trust Btn L` centred (a defect this lane introduced)

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

### 3.2 Full ledger, re-measured this pass

| Foreground | Background | Light | Dark | AA | Note |
|---|---|---|---|---|---|
| `inkSecondary` | `card` | 6.74:1 | 6.10:1 | pass / pass | helper, `Trust Host`, `Art S` |
| `inkTertiary` | `card` | 4.99:1 | 4.23:1 | pass / **FAIL** | now unused on these boards |
| `inkPrimary` | `card` | 16.20:1 | 13.48:1 | pass / pass | |
| `inkTertiary` | **`canvas`** | **4.65:1** | **4.62:1** | **pass / pass** | **expanded `TechnicalDetails` — both platforms** |
| `inkQuiet` | `rail` | 4.60:1 | 4.57:1 | pass / pass | **light** nav label |
| `inkTertiary` | `rail` | 4.33:1 | 4.88:1 | **FAIL** / pass | **dark** nav label |
| `inkPrimary` | `rail` | 14.06:1 | 15.57:1 | pass / pass | active nav label (after M-N4) |
| `#241a02` | `attentionTick` | 8.42:1 | 8.42:1 | pass / pass | `Nav Badge` numeral |
| `#ffffff` | `accent` | 5.27:1 | 2.99:1 | pass / **FAIL** | enabled `Register` label, light |
| `#06121f` | `accent` | 3.58:1 | 6.30:1 | **FAIL** / pass | enabled `Register` label, dark |
| `inkPrimary@38%` on `inkPrimary@12%`/`card` | — | **2.22:1** | **2.78:1** | n/a — see § 5a | **disabled `Register` label** |

> ⚠️ **SUPERSEDED BY REVISION 4 § 3.2 — the row above reads `pass / FAIL` (4.23:1 in dark) and its Note says
> "now unused on these boards". That Note is FALSE.** `Art K` is an `inkTertiary`-on-`card` call site on all
> four boards and in the build (`add_product_page.dart:533`/`:1029`). Do not rely on it. Notification **N10**;
> the N7 withdrawal immediately below is scoped to the `TechnicalDetails` lines only.

**N7 is withdrawn.** It escalated to the design-system owner a desktop AA failure "on `card`" that Add
Product does not exhibit on any platform. The `inkTertiary`-on-`card` failure is real and remains in the
ledger as a *different* row, but no Add Product call site puts these lines on `card`, so it is not Add
Product's finding to raise.

### 3.3 A surface mismatch this exercise exposed (**new — G12**)

Verifying M-N1 forced me to read what the `Register` button actually sits on, and the answer contradicts
the boards in a way nothing in revisions 1 or 2 recorded:

- **Mobile:** `MobilePrimaryButton` (`:904-911`) is **inside** the `DesignPanel` opened at `:853`, which
  is `palette.card` (`apps/control_plane/lib/shared/design_primitives.dart:320`).
- **Desktop:** the `FilledButton` (`:679`) is **inside** `_RightPanel`'s `DesignPanel` (`:632`).
- **The boards** draw `Register` on the bare page background, because the "What happens next" panel has no
  board at all (already filed as **G5/F1** — but recorded there as *copy* with no board, not as *the
  primary action's surface* being wrong).

This is not a colour defect; it is a fidelity gap in the surface under the feature's one committing
control, and it is the reason § 5a's read-back had to include its own `card` backing. Recorded as **G12**.

---

## 4. M-N4 — the active nav label now matches `mobile_chrome.dart:297`

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

## 5. M-N5 — the disabled `Register` read-back, and how the code actually resolves it

### 5.1 The chain, and why the obvious reading is wrong

`core/theme.dart:67-83` calls `FilledButton.styleFrom(backgroundColor: palette.accent, foregroundColor: …)`
and sets **no** `disabledBackgroundColor` / `disabledForegroundColor` (grep for both in that file: no
match). The intuitive conclusion — "so the enabled accent stays and nothing looks disabled" — is **wrong**,
and it took reading the framework to find out. Three steps, each verified against Flutter **3.44.7**
(the SDK this repository pins, `/Users/alkebut/fvm/versions/3.44.7`):

1. **`filled_button.dart:287-288`** — `styleFrom` wraps the colours in
   `ButtonStyleButton.defaultColor(backgroundColor, disabledBackgroundColor)`.
2. **`button_style_button.dart:266-273`** — with `disabledBackgroundColor == null`, `defaultColor` returns
   `WidgetStateProperty.fromMap({ WidgetState.disabled: null, WidgetState.any: enabled })`.
3. **`widget_state.dart:1008-1013`** — `WidgetStateMapper.resolve` walks the map in insertion order and
   **`return entry.value` on the first satisfied key**, even when that value is `null`. So when disabled the
   theme's resolver returns `null`.
4. **`button_style_button.dart:381-391`** — `effectiveValue` is `widgetValue ?? themeValue ?? defaultValue`.
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
| `Art S · PENDING D4 (at-rest model)` | R1, R6 | **b869ec24** | `monoMeta` 10/400; **`inkSecondary`** |
| `Key State` | R6/2b,2c | 73097d48 + sibling lane | `attention` / `positive` / `negative` — § 3.2 ledger, note `negative`-on-`card` dark = 3.68:1 (N2) |
| `Art L1 · Copy key` | R1, R6 | 73097d48 | `InlineLink`; `link` `:426` 11/**500**; `accent` |
| `Art L2 · Check access` / `Check again` | R6/2c | 73097d48 | `InlineLink`; `link` 11/500; `accent` |
| **`Trust K/Body/Body 2/Host`** | R6/2d | 73097d48 + human 2d | `MicroLabel` → `microLabel` **`inkSecondary`**; `bodySmall` **`inkSecondary`** 11/400; `monoMeta` 10/400 **`inkSecondary`**; surface `DesignPanel` = **`card`**; edge `attention` — *revision 1 named "`card`, `attention`" with **no foreground token at all**, which is precisely how `Trust Host` shipped at `inkTertiary` unreviewed* |
| `Trust Btn` `Trust this host` | R6/2d | 73097d48 + human 2d | `FilledButton` (accent fill, theme foreground); label **12/600**, **`align: center`** after H-N1 |
| `Submit` + `Submit L` | **R2** | human 2e | `MobilePrimaryButton` — **label only**, `buttonLabelMobile` `:508-514` **11/600**, `align: center`. Rect 358×34 @ x=16; fill `accent`. **Surface = `card` in code, bare page background on the board (G12)** |
| `Submit Sub` helper below button | **R2**, **R5** | human 2e + R5 | `monoMeta` 10/400; **`inkSecondary`** |
| `Disclose` `Show technical details ▸` | **R3** | human 2f | `TechnicalDetails`; `linkMicro` `:443` 10/500; `accent` |
| **`Bottom Nav / … / Products`** | R1 | 73097d48 | `MobileBottomNav`; **per theme**: Light `inkQuiet` `#6A6C6A` on `rail`; Dark **`inkTertiary` `#8A8983`** on `rail` (4.60:1 / 4.88:1); **active** item `inkPrimary` on `rail` and **`w600`** after M-N4; `Nav Badge` `attentionTick` + `#241a02`, Mono 11/700 — *revision 1 said `inkQuiet`/`inkPrimary`, which is **false for dark**: the boards draw `#8A8983` = `inkTertiary`, not `inkQuiet` `#85847E`* |
| `M-N5 READ-BACK` groups ×2 | R2, R6 | revision 3 | `FilledButton` disabled resolution under `core/theme.dart:67-83` + `:32`; **not** a `ShipItPalette` token (N4/G9); `· PROVISIONAL (G1 hostUnrecognised)` |

`requirements_covered`: **R1, R2, R3, R4, R5, R6, R7**. `requirements_gaps`: **none**. No requirement
moved in this pass.

> ⚠️ **TWO CELLS ABOVE ARE SUPERSEDED BY REVISION 4 § 6 / § 6.1.**
> * `Art S · PENDING D4 (at-rest model)` — "Settled by" reads **`b869ec24`**, a `RESOLVED` decision about
>   *where* deploy-key generation and storage belongs. The at-rest substrate is the **open** gate
>   **`9417f8bf` (`PENDING`)**. The cell is corrected there; the layer, its string and its `PENDING D4` marker
>   are untouched and the decision remains the human's.
> * `Submit Sub` helper below button — reads **`inkSecondary`**, which is what the **boards** draw. The
>   **build** renders `palette.inkTertiary` (`add_product_page.dart:918`), and this row names no surface.

---

## 7. M-N3, L-N1, L-N2, L-N3, L-N4 — the record corrections

### 7.1 Withdrawal markers applied (L-N1, M-N6)

Byte-identical retention is legitimate for diffability; **retention without a marker is not**, because
whichever file a reader opens first is the only file they read. Two kinds of marker were applied:

| Site | Disproven claim | Marker added |
|---|---|---|
| `design-revision.md` head | — | `SUPERSEDED — revision 1. See design-revision-3.md. Two claims inside are disproven and marked in place: F8 (§10 table) and the 36px `minimumSize` derivation (§2a).` |
| `design-revision.md:70`, `:72-73` | "36.4 → clamped by `minimumSize` to **36px**", "collapses … landing on its own declared `minimumSize`" | `> **WITHDRAWN — revision 2 §6a.** `minimumSize` is a minimum; `Size.constrain` raises only values *below* it, and 36.4 > 36 already. The button collapses **50.4 → 36.4**, not to 36. Retained unedited for diffability; **superseded, not deleted.**` |
| `design-revision.md:414` (F8 row) | "Penpot's IBM Plex Sans has no `500` weight (supported: 200/300/400/600/700/900)" | `> **WITHDRAWN — revision 2 §2.** **False in both directions.** Variants are `100,200,300,400,500,600,700`: `500normal` **exists**, `900` **does not**, `100` exists and was omitted. F8 was deleted from the current revision; this row is retained unedited and must not be relied on.` |
| `report.md` head | — | `SUPERSEDED — revision 1's report. See design-revision-3.md. Claims disproven since: the 36px derivation, and "no 500 weight" (line 100). Both marked in place.` |
| `report.md:100` | "Penpot's IBM Plex Sans has no `500` weight, so link layers render at 400" | `> **WITHDRAWN — revision 2 §2.** False: `500` exists and `900` does not. The link layers are now **11/500** (`ShipItType.link`, `design_tokens.dart:426`).` |
| `report.md:48`, `:197`; `design-revision-metadata.yaml:15-16` | "≈50.4px → 36px, landing on its own declared `minimumSize`" | `> **WITHDRAWN — revision 2 §6a.** 50.4 → **36.4**; `minimumSize` never binds. Superseded, not deleted.` |
| `design-revision-2.md` head | — | `SUPERSEDED — revision 2. The current revision is design-revision-3.md. Revision 3 overturns three claims in this file: §8 L-R5 and N8 (`Trust Btn L` flush-left — it was **not** a faithful copy of the desktop pattern, and the label is now centred); the §5 two-row `canvas`/`card` split (the surface is `canvas` on **both** platforms, and **N7 is withdrawn**); and §2's reason for leaving `Nav Label 3` at w400 (the four boards I own are in scope, so the label is now **w600**). Substantive text left unedited for diffability.` |
| `design-revision-2.md` §5 / §8 / §10 | the `card` row, L-R5, N8, N7 | in-place `SUPERSEDED BY REVISION 3 §3.1` / `§2` / `§8` pointers at each site |
| `correction-report.md:67` | "every clamp claim deleted from § 2a, the `risk_rationale` and `report.md`" | `> **CORRECTED — revision 3 §0.** This claim was **false**: nothing was deleted from § 2a, the `risk_rationale` or `report.md`. The corrected statement is "**superseded by revision 2 §6a, not deleted**", and withdrawal markers are now in place at all five sites.` |
| `design-revision-metadata-2.yaml` `risk_rationale` | "The 36px claim has been deleted from § 2a, from the risk rationale and from report.md" | `SUPERSEDED — see design-revision-3.md §0. The claim is "superseded by revision 2 §6a, not deleted"; markers applied.` |

> ⚠️ **THE `Site` COLUMN ABOVE IS SUPERSEDED BY REVISION 4 § 7.1 (L-R3) AND CORRECTED AGAIN BY REVISION 5
> (§ M-1).** This table's line numbers were correct when written, were then **invalidated by this lane's own
> markers**, which sit *at* the cited sites, and **revision 4's replacement numbers were themselves low by
> six**. Live numbers, re-read from the files at `289f1d3`:
> `design-revision.md:83` (the `total` row), `:85` (the "collapses from ≈50px" sentence), marker block
> **`:89-95`**; F8 at `design-revision.md:435`, marker **`:437-444`**;
> `report.md:68` (marker **`:70-74`**), `:126` (marker **`:128-133`**), `:230` (marker **`:237-243`**).
> **Applying a uniform "+6" would have fixed six of these and broken the three ranges** — the marker blocks
> moved +8, +8 and +13, and the provenance note moved +5 (`26-31` → `31-37`). `design-revision-metadata.yaml:15-16`
> is **still correct**. Full map: `design-revision-4.md` § 0.1 and `design-revision-5.md` § M-1.

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

None of these raise the risk level and none are mine to fix.

| Id | Item | Status |
|---|---|---|
| N1 | Board naming `SM - ` vs the page's `S · ` | carried from B2; unchanged |
| N2 | `ShipItPalette.negative` fails AA on dark — 4.02:1 `canvas` / 3.68:1 `card` | carried from B4/G3; **kept distinct from H-R1** |
| N3 | `TechnicalDetails` paints an unconditional `ContentRule` the mobile board lacks | carried from G4 |
| N4 | **No disabled-primary token.** Now with the resolved appearance attached: the primitive renders `inkPrimary@12%` fill + `inkPrimary@38%` label = **#E4E4E4 / #999A9A** in Light (**2.22:1**) and **#3F403F / #848482** in Dark (**2.78:1**). A 2.22:1 label is unreadable in Light and the 10px helper is not a substitute carrier. Request a disabled container/label pair in `ShipItPalette` | **strengthened this pass, not re-raised** |
| N5 | `BPM · Add Product · Light` draws `Submit L` at **13/600**, matching no primitive | raised in revision 2; unchanged |
| N6 | **`BPM · Add Product · Light/Dark` only:** `microLabel` at ls 0 vs the token's ls 1.1, and the nav's **active** label at w400 vs `mobile_chrome.dart:297`'s w600 | **narrowed this pass.** The w400 nav label on *my* boards was mine to fix and is fixed (M-N4, § 4); what remains is the reference board, which is PROHIBITED to me |
| ~~N7~~ | ~~Expanded `TechnicalDetails` lines fail AA on `card` in dark (4.23:1)~~ | **WITHDRAWN — revision 3 §3.** The surface is `canvas` on **both** platforms (4.65 / 4.62, both pass). There is no `card` surface under these lines anywhere in Add Product. Escalating this would have sent the owner a desktop AA failure Add Product does not exhibit |
| ~~N8~~ | ~~`Trust Btn L` is flush-left, copying the desktop `Host Btn L` pattern at x=254~~ | **WITHDRAWN AND FIXED — revision 3 §2.** The premise was false (it compared box `x` and ignored `align`; desktop `Host Btn L` is `align: center`). The label is now centred, 50.367px inset. `Submit L` was already centred and was never affected |
| N9 | **new —** the primary action's surface: in code `Register` sits inside `DesignPanel` = `card` on **both** platforms, while the boards draw it on the bare page background because the "What happens next" panel has no board (G5) | **raised this pass, from G12** |

Carried from revision 1 and **not** re-raised: **B3** (footer-copy scope) remains filed as Human Decision
`27ea6536`. **G2** (`Art S` at-rest wording) stays `PENDING D4` and unresolved.

> ⚠️ **BOTH CLAIMS IN THE PARAGRAPH ABOVE ARE SUPERSEDED BY REVISION 5. BOTH ARE RESOLVED; NEITHER IS
> RE-RAISED.** *(Revision 5 finding L-1 — retention without a marker is not neutral.)*
>
> * **B3 / `27ea6536`** — now **RESOLVED** (OPTION_A as nearest equivalent, `decided_by: repository owner`,
>   `decided_at: 2026-10-06T13:05:00Z`). The human checked the boards and ruled: **desktop**
>   (`S · Add Product · …`) = a divider plus a **right-aligned** `Show technical details` text button and
>   **no footer copy**; **mobile** (`BPM · Add Product · …`) = the button **left-aligned with no
>   divider** and **no footer copy**.
>
>   **⚠️ CORRECTED AT REVISION 5 AFTER A SECOND LIVE READ. The mobile half is confirmed; the desktop half
>   is NOT — and revision 5's own first draft of this pointer got it wrong too.** Re-read at `289f1d3`:
>
>   | Claim | Verdict |
>   |---|---|
>   | Mobile matches all four `SM` boards | **CONFIRMED.** `Disclose` at `parentX` 16 = the content left edge; zero divider rectangles in the band between the button helper and `Disclose`; zero footer-copy text layers. `SM` Verified `16,580`; `SM` Unknown `16,748`. |
>   | Desktop `Disclose` right-aligned at rel 1036,862, width 220 | **CONFIRMED** on all four `S` boards. Right edge `1036 + 220 = 1256` = the content column's right edge (`236 + 1020`). |
>   | Desktop carries a `Footer Rule` divider at rel 236,848, 1020×1 | **CONFIRMED** on all four `S` boards. |
>   | **"…and no copy"** | **FALSE.** All four `S` boards carry a **`Footer` text layer at rel 236,862, 1020×15**, `align: left`, reading *"Your decision is recorded permanently. The same piece of work then continues — nothing is restarted."* |
>
>   **This lane's original coordinate reading of a footer copy at (236,862) was therefore CORRECT, not a
>   misidentification, and is reinstated as measured.** Revision 5's first draft of this pointer asserted
>   that (236,862) was "the `Footer Rule` divider, not a text layer". That is wrong on both halves: the
>   divider is at (236,**848**), and a text layer *does* sit at (236,862). The human's **normative outcome is
>   unchanged and is not re-opened here** — the finding is that the four desktop boards do not conform to it,
>   closing them is a board edit this lane does not own, and it is escalated as an ownership blocker. See
>   finding **F6** in `design-revision-5.md`.
> * **G2 / `PENDING D4`** — now **RESOLVED** by `9417f8bf` (**OPTION_C / A3**, an external secret manager;
>   SHIP IT holds only a reference and asks the manager for material at push time). The layer is **no
>   longer** `PENDING D4` on any board: it was renamed `Art S` and its string corrected to
>   `ed25519 · generated on the server · the private half stays in the secret manager` on **all four
>   boards**, verified by live read-back. The rev-2 string this paragraph was written against
>   (`ed25519 · private half stays server-side`) asserted the private half is SHIP IT's; under A3 it is
>   not SHIP IT's at all.
>
> **Retained unedited above, superseded, not deleted.** Full specification: `design-revision-5.md` § 4.

---

## 9. Board inventory after this pass

Page `d8ac01df-6646-81d2-8008-a366c09aa9d3`. **160 boards / 164 root children.** The board count is
unchanged — this pass edited layers on four boards I own and created **no board**. Root children went from
162 to 164 because of the two `M-N5 READ-BACK` groups; the other two non-board root children
(`Tab Group`, `Rectangle`) were already present and are untouched.

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

**Read-back verification**, re-read from the live file after every change:

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

**No pre-existing board was edited, renamed, moved or deleted.** Only the four boards this lane owns were
written to, plus the two new page-level annotation groups.

---

## 10. Categorized mismatch list (boards vs the build at `77c19f1`)

- **MATERIAL** — the build renders a nested subtext inside the desktop `FilledButton.child` (`:692-717`) in
  `inkPrimary` on the fill, **3.07:1 light / 2.72:1 dark**, failing AA in both themes.
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
| G2 | at-rest wording for `Art S` | **~~open human decision; layer stays `PENDING D4`~~ — RESOLVED at revision 5 by `9417f8bf` (OPTION_C / A3); layer renamed `Art S`, string corrected on all four boards |
| G3 | `negative` on dark fails AA and no compliant token exists | `ShipItPalette` is design-system-owned (N2) |
| G4 | `TechnicalDetails`' unconditional `ContentRule` | shared primitive, 4 other screens (N3) |
| G5 | the build's "What you're registering" / "What happens next" panels have no board | removing them is a UX change (F1) |
| G6 | **re-scoped**: `_buildInfoPanel` **and `product_detail_page.dart:614`** repeat the false keychain guarantee | production source, PROHIBITED to me |
| G7 | 34px board submit vs 36px `MobilePrimaryButton` | pre-existing; needs QA baseline agreement |
| G8 | `flutter analyze` not run → feasibility cannot be HIGH | see metadata |
| G9 | no `ShipItPalette` disabled-primary token; the appearance is derived from M3 defaults | design-system owner (N4); consequence stated in § 5 |
| G10 | `Confirm the host above to enable Register product.` has no producing state | arrives with G1's `hostUnrecognised` |
| G11 | ~~the mobile design review report was never persisted (revision 2 § 0)~~ **— CLOSED in revision 4 (L-R2); re-confirmed at revision 5 (L-1).** The file `docs/engineering/dispatch/tasks/design-review-addproduct-mobile/report.md` exists and carries the closing sentence | `LANES.md` is PROHIBITED; Manager-owned. **Note:** the re-review report for revision 2 *was* reachable to me this pass, at the canonical checkout, so G11's practical impact on this pass was nil |
| **G12** | **new — the primary action's surface: in code `Register` sits on `palette.card` inside `DesignPanel` on both platforms; the boards draw it on the bare page background** | consequence of G5; recorded with the surface named (N9) |

**Assessment movement:**

- **design_system_compliance: PARTIAL → PARTIAL.** Improved again: the trust button's label now matches the
  primitive's centring (§ 2), and the active nav label now matches `mobile_chrome.dart:297` (§ 4) — two
  divergences from the production primitives removed. Still PARTIAL because the file holds boards
  disagreeing with mine on `Submit L` size (N5) and on `microLabel` tracking and the active nav weight
  (N6), and because `negative` on dark is unresolved (N2). All of those are PROHIBITED boards.
- **ux_accessibility_score: PARTIAL → PARTIAL.** The two AA failures this lane had authority to fix remain
  fixed. **Not PASS**, and the reasons are recorded rather than rounded away: (a) `Key State` still uses
  `negative` at **3.68:1 on `card` in dark** with no compliant token in `ShipItPalette` (N2); (b) the
  `canRegister == false` state still has **no token**, and the appearance the code produces has a label at
  **2.22:1** in Light (§ 5.2, N4). § 5 makes (b) measurable, which is progress; it does not make it PASS.
- **implementation_feasibility: MEDIUM → MEDIUM.** Unchanged, deliberately. `flutter analyze` was
  **NOT_RUN** in this lane — it needs `flutter pub get`, which writes outside this lane's read-only scope,
  and `apps/control_plane/.dart_tool/` does not exist at this HEAD. **No feasibility claim is derived from
  a gate that was not run.** What this pass *did* verify is every primitive, token and call site the design
  depends on, by source inspection, including the Flutter SDK's own resolution chain (§ 5.1).
- **RISK_LEVEL: 2 → 2.** Every change in this revision is Level 0/1: two `align` corrections, four
  font-weight corrections, twelve additive annotation layers in two new page-level groups, and record
  corrections. Nothing changes an interaction pattern, a navigation or information-architecture surface, or
  the primary action's structure. § 5 documents an appearance the code already produces; it does not
  choose one.

**No human gate is raised by this revision.** B3 remains with decision `27ea6536` and is not re-opened.
`Art S` stays `PENDING D4`.

---

## 12. The verification-discipline lesson, stated for the next lane

The re-reviewer's closing judgement was that this lane's *judgment* was good and its *verification
discipline* lapsed where it stopped checking. Four lapses are now corrected (H-N1, M-N1, M-N4, M-N6) and
one dispatched correction was itself wrong (§ 1.1). The pattern behind all five is worth writing down,
because it is not a knowledge gap:

> **Every one of those was a check this lane had already performed correctly somewhere else in the same
> document.** `Trust Btn L`'s centring was checked against `Submit L` and missed against the desktop
> board; the desktop `TechnicalDetails`' surface was checked on mobile and missed on desktop; the nav
> label's token was checked for `microLabel` and missed for the active item; the deletion was asserted
> instead of re-read.

The operational rule that follows, and that I will apply:

1. **A comparison needs both operands.** Comparing box `x` without comparing `align` is not a comparison;
   comparing mobile without comparing desktop is not a comparison. Name both sides before concluding.
2. **Re-read the artifact before claiming anything about it.** Every M-N6-class failure is a claim about a
   file made from memory of having written it.
3. **A finding is a set of claims.** Apply the ones that survive checking and say which you rejected.

---

## 13. Assumptions carried forward

Unchanged and still pending `design-addproduct-keyservice`: **A1** "Check access" does not rotate the key ·
**A2** the trust outcome is persisted server-side · **A3** `hostUnrecognised` is a page state, not a modal
sheet · **A4** the trust decision is not a register event · **A5** (revision 2)
`Confirm the host above to enable Register product.` is the string `hostUnrecognised` will produce
(G10/M-R3).

**A6 is new.** The § 5.1 disabled appearance is derived from Flutter 3.44.7's `_FilledButtonDefaultsM3`
plus `core/theme.dart:32`, read from the SDK source at
`/Users/alkebut/fvm/versions/3.44.7` (the version this repository pins). **It is not executed** — no
Flutter widget was rendered in this lane. If the project moves to a framework version whose
`ButtonStyle` precedence differs, the resolution must be re-derived; the *shape* of the argument
(`defaultColor` → `WidgetStateMapper` returns `null` on the first satisfied key → `effectiveValue`
falls through to the M3 default) is what makes it checkable rather than a remembered number.