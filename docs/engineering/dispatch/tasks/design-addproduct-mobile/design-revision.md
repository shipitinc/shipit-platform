# Design Revision — Add Product mobile state boards + layout/copy corrections

> **SUPERSEDED — this is revision 1. The current revision is `design-revision-5.md`.** This file is retained
> **unedited** so the whole correction history stays diffable. Retention without a marker is not neutral,
> because a reader who opens this file first sees only this file — so **two claims inside it are disproven
> and are marked in place**: the 36px `minimumSize` derivation (§2a, **lines 83 and 85**) and follow-up
> **F8** (§10, **line 435**). Both carry `WITHDRAWN` markers. See `design-revision-5.md` § M-1.
>
> **Corrected twice: revision 4 (L-R3), then revision 5 (§ M-1).** Revision 4's numbers — "lines 77 and
> 79", "line 429" — were themselves wrong; those lines hold `ShipItType._lh = 1.2` and the **F2** row.
> Re-read live at `289f1d3`: **`:83`**, **`:85`**, F8 at **`:435`**; markers at **`:89-95`** and
> **`:437-444`**. **No uniform offset repairs these** — a marker at a cited line moves it, which is why
> this header's line budget is held fixed: adding a line here would invalidate every number below it.

Per `docs/engineering/DESIGN_GOVERNANCE.md` § *Artifacts → Design Revision*. Metadata in
`design-revision-metadata.yaml`. Board evidence in `penpot-board-evidence.md` — **regenerated** at
revision 3; its figures here are superseded.

```yaml
revision_id: 65995C2B-4905-419F-A6E9-E547E86D8ECE
brief_id:    52CB4098-FF87-4B78-81DA-1104269551A1
revision_number: 1
status: UNDER_REVIEW          # Gate D3 pending — the Design Agent never approves its own work
```

Provenance: worktree `/private/tmp/shipit-design-addproduct-mobile`, branch `design/addproduct-mobile`,
`BASE_SHA` = `HEAD_SHA` = `77c19f114ee691e8c434afe37b7c84494b66dc40`. Nothing committed; artifacts left in
the worktree for the Manager to persist.

---

## 1. The four boards (R1)

Page `d8ac01df-6646-81d2-8008-a366c09aa9d3` (`Page 1`), all at **390x844**, exported as PNG evidence.

| Board | Penpot id | Position | Top-level layers |
|-------|-----------|----------|------------------|
| `SM - Add Product - Unknown host - Light` | `6d055762-a70b-804c-8008-bf65ff750422` | (7550, 10750) | 42 |
| `SM - Add Product - Unknown host - Dark` | `6d055762-a70b-804c-8008-bf65e644269b` | (7550, 9800) | 42 |
| `SM - Add Product - Verified - Light` | `6d055762-a70b-804c-8008-bf660e124738` | (8000, 10750) | 34 |
| `SM - Add Product - Verified - Dark` | `6d055762-a70b-804c-8008-bf65f36b1c9a` | (8000, 9800) | 34 |

Board count went 156 → 160. No pre-existing board was edited, renamed, moved or deleted — verified by
re-reading the four reference boards after authoring (`BPM · Add Product · Light/Dark` still 36 children
each at their original positions; `S · Add Product · Unknown host · Light` 69, `… · Verified · Light` 65).

**Grammar followed** (from `BPM · Add Product · Light`, geometry reproduced exactly): back link
`‹  Products` → H1 `Add a product` → `NOT REGISTERED YET` eyebrow → `Rule 1` → 3 fields at a 64px pitch
(14px label slot + 4px gap + 34px box, `FormMetrics.labelSlot`/`labelGap`/`padSingle`) → deploy-key panel
(`DEPLOY KEY · THIS PRODUCT ONLY`, title, meta line, state label, `Copy key`, `Check access`) → trust
panel (Unknown host only) → `Register product` → helper **below** → `Show technical details ▸` → bottom nav.

**Deliberately absent**, per dispatch: no "What you're registering" panel and no "What happens next" panel.
The build renders both (`add_product_page.dart:405` and `:639`/`:859`) — see § 7 follow-up F1.

### Naming-convention conflict — flagged, not decided

The dispatch names the grammar reference `BPM - Add Product - Light` (hyphen) and prescribes an `SM -`
prefix. The live page uses **U+00B7 middle dots** and an **`S ·`** prefix for mobile/desktop *state* boards:
`BPM · Add Product · Light`, `S · Add Product · Unknown host · Light`. I followed the dispatch literally —
the acceptance criterion requires the exact names and a rename is trivially reversible — but this creates a
second naming convention on the page. **This needs a decision at Gate D4** (see § 8 blocker B2).

---

## 2. R2 — one button/helper structure (human point 2e)

**Specified structure (both platforms, no exception): the button carries its label only; the helper is a
sibling rendered immediately after it, separated by an 8px gap.**

This is the mobile structure the board already specifies and the build already implements at
`add_product_page.dart:912-920`. Desktop's structure is the one that changes: the nested
`Column[label, SizedBox(2), subtext]` inside `FilledButton.child` (`:692-717`) is removed.

### 2a. Button height — stated, as prior finding H2 required

`ShipItType._lh = 1.2` (`design_tokens.dart:313`).

| | Desktop, before | Desktop, after | Mobile |
|---|---|---|---|
| content | `14.4 + 2 + 12 = 28.4` (12px label, 2px gap, 10px subtext) | `14.4` (label only) | `13.2` (11px `buttonLabelMobile`) |
| padding | `11 + 11 = 22` (`:685`) | `22` | — |
| total | **50.4px**, content-driven (`minimumSize: Size(0,36)` at `:689` is not binding, `tapTargetSize: shrinkWrap`) | `36.4` → clamped by `minimumSize` to **36px** | fixed **36px** (`mobile_chrome.dart:440`) |

**So the desktop button collapses from ≈50px to exactly 36px** — landing on its own declared `minimumSize`
and matching `MobilePrimaryButton`'s hard-coded 36. `minimumSize`/`padding` need no change; only the
`child` does.

> **WITHDRAWN — revision 2 §6a; marker added at revision 3.** Every claim in this sub-section about the
> button landing on 36px is **false**. `minimumSize: Size(0, 36)` is a *minimum*; `Size.constrain` raises
> only values **below** it, and the content-driven height is `14.4 + 22 = 36.4`, already above 36, so the
> minimum never binds. **The desktop button collapses 50.4px → 36.4px, not to 36px**, and the panel's inner
> height **grows ≈5.6px** rather than staying level (the helper is `monoMeta` at `fontSize: 10` = a 12px
> line box: 8 + 12 gained against a 14.0 loss). The corrected derivation is `design-revision-3.md` §3 and
> revision 2 §6. **This paragraph is retained unedited for diffability and is superseded, not deleted.**

*Board note:* `BPM · Add Product · Light` draws the submit rect **34px** tall while `MobilePrimaryButton`
is 36px. I drew 34 to match the sibling board exactly rather than silently introduce a new value; the 2px
divergence is pre-existing and is follow-up F6, not a change I made.

### 2b. Desktop gap — stated

Today the desktop `FilledButton` is the **last child** of `_RightPanel` (`:676-719`), so nothing follows it
inside the panel and there is no gap to specify. After the change the helper needs one:

- insert `SizedBox(height: 8)` between the button and the helper — **the same 8px the mobile path already
  uses at `:912` and the board uses at `Submit` y=510 → `Submit Sub` y=552**;
- the helper stays **inside** `_RightPanel`, below the button, so the panel's existing bottom padding
  (`EdgeInsets.fromLTRB(20,20,20,20)`, `:633`) continues to bound the composition;
- no change to the two `ContentRule`s at `:648` and `:674`.

**Net desktop consequence: the panel's inner height is unchanged** (it loses 14.4px of button content and
gains ~15px of helper plus the 8px gap).

### 2c. Helper colour — corrected (R5)

`add_product_page.dart:918` paints the mobile helper `inkTertiary`; the boards draw it `#6e706e`
(= `inkTertiary`) too. **Both are wrong for dark.** Specified **`inkSecondary`**:

| Surface | `inkSecondary` | AA (4.5:1) |
|---|---|---|
| `card` light `#5a5c5b` on `#ffffff` | **6.74:1** | pass |
| `card` dark `#a8a6a0` on `#262827` | **6.10:1** | pass |

### 2d. Button label colour — corrected (R5), and it is the *code* that is wrong

`theme.dart:70-74` already documents the board authority: "every approved filled action carries a dark navy
label in Dark (`#06121f`) and a white label in Light (`#ffffff`)". Measured:

| | `#ffffff` on `accent` | `#06121f` on `accent` | `inkPrimary` on `accent` (current code) |
|---|---|---|---|
| Light | **5.27:1** pass | 3.58:1 | **3.07:1 fail** |
| Dark | 2.99:1 | **6.30:1** pass | **2.72:1 fail** |

`add_product_page.dart:703-705` and `:713` set the label to `palette.inkPrimary` "FilledButton uses
onPrimary" — 3.07:1 light / **2.72:1 dark**, failing AA in both themes, and it *overrides* the theme's
correct `foregroundColor`. Once the nested subtext is removed there is exactly one label left, which must
drop the `color:` override entirely and inherit the theme. The boards already draw the correct colours.

---

## 3. R3 — the footer (human point 2f)

**This is not a restoration.** Two premises in the dispatch are contradicted by the code and by the board;
both were verified, not assumed.

### Premise correction 1 — `Show technical details` is present in the build, not removed

The literal string appears in no `add_product_page.dart` line because Add Product does not spell it: it
renders the shared `TechnicalDetails` primitive, which hard-codes that label
(`design_primitives.dart:415`). Add Product instantiates it **twice** — `:316` (desktop) and `:925`
(mobile). The row has never been removed; a repo-wide grep for the literal only proves the spelling is
centralised in the primitive. R3's "restoration" framing is therefore wrong, and so was the earlier claim
that there were two rows.

### Premise correction 2 — the footer copy line at `:383` is desktop-only

`_buildFooter` (`:375-389`) is called only from `_DesktopAddProduct` (`:314`). `_MobileAddProduct` has no
footer copy at all. So on the screens this brief governs (mobile), the copy line is **absent**, and the only
bottom copy is `TechnicalDetails`' `note`.

### What the board actually specifies

`BPM · Add Product · Light` has, below the helper and with **no** `ContentRule` between them, exactly one
element: `Disclose` — `Show technical details ▸` at (16, 580), 10px, `accent`. That is human 2f's "only one
footer line … only a Show technical details widget down there".

The desktop boards put the same disclosure on one line **with** copy beside it: `S · Add Product · …
· Light` has `Footer` ("Your decision is recorded permanently…", `#6e706e`) at (236, 862) and `Disclose`
at (1036, 862) — the same y, opposite ends. That is precisely `TechnicalDetails`' collapsed shape:
`ContentRule` + `SizedBox(13)` + `Row[note, InlineLink]` (`design_primitives.dart:396-420`).

### Specification

| Platform | Footer composition | Change required |
|---|---|---|
| **Mobile** | one `Show technical details ▸` row, **no copy line beside it** | drop the `note:` argument at `:926-928` |
| **Desktop** | one row = `Row[copy note, Show technical details ▸]`, i.e. `TechnicalDetails(note:)` | **delete `_buildFooter` entirely** and its `SizedBox(12)` at `:315`; keep `:316-328` |

Deleting `_buildFooter` also removes the duplicated `ContentRule` the desktop build currently paints twice
(`:380` and again inside `TechnicalDetails` at `:396`) and the duplicated copy line
(`:383` and the `note` at `:317-319`).

**Expanded/collapsed behaviour (unchanged, primitive-owned):** collapsed → `Row[note?, InlineLink]`;
expanded → `MicroLabel('TECHNICAL DETAILS')` + one `monoMeta` line per entry + `SizedBox(12)`, and the link
flips to `Hide technical details ▾` (`design_primitives.dart:383-420`). Expanded raw lines for this page
are `productName=`, `repository=`, `revision=`, `deployKeyFingerprint=` (only when a key exists) and
`accessStatus=` (`:929-936` mobile / `:320-327` desktop).

**Named conflict, not resolved by this lane:** `TechnicalDetails` unconditionally paints a `ContentRule`
(`:396`) that the mobile board does not have. Suppressing it needs a new parameter on a primitive used by
defect list/detail, feature-request list and `plain_language.dart` — outside my `OWNED_PATHS` and a
shared-component decision. Follow-up F4.

**Copy-removal scope, flagged not decided:** human 2f says "there's no copy at the bottom". I read that
against the **mobile** boards and mobile build (no copy) — which is what I drew. The **desktop** boards
do carry that copy line beside the disclosure, so if the human intends the copy gone on desktop too, that
is a one-line change (`note: null` at `:317`) plus a desktop-board edit I am forbidden to make. Raised as
blocker B3 rather than decided.

---

## 4. R4 — required-field convention, re-grounded on production (B1, B2)

### The convention already exists — premise confirmed

`create_defect_page.dart:458,477,495,504` mark optional fields with an in-label `(OPTIONAL)` suffix;
absence of the suffix marks required, matching the submit gate at `create_defect_bloc.dart:201,207,216,229,238`
(title, description, expectedBehavior, severity, productId). **No second convention is introduced.**

### Add Product's three fields

| Label | Classification | Basis |
|---|---|---|
| `PRODUCT NAME` | **required** — no suffix | `canGenerateKey`/`canRegister` (`:230-236`) and `_onRegisterProductRequested` (`:149-153`) both return early when empty |
| `REPOSITORY  (SSH)` | **required** — no suffix | same two guards |
| `REVISION OR BRANCH` | **required** — no suffix | it is the deploy target; `_onRegisterProductRequested` passes the form and a branch is not optional for a clone |

All three stay exactly as the boards already draw them (`F K 0/1/2`), i.e. **no visual change** to the
boards is required for R4.

### Full coverage of all 15 `FormFieldSlot(` call sites

Verified by enumeration, not by the prior report's "~8". `grep -rn "FormFieldSlot(" apps/control_plane/lib`
returns 16 lines: **15 invocations + 1 constructor declaration** at `form_primitives.dart:69`.

| # | Site | Label | Required? |
|---|---|---|---|
| 1 | `add_product_page.dart:456` (desktop) | `PRODUCT NAME` | required |
| 2 | `add_product_page.dart:455` → `:955` (mobile) | `PRODUCT NAME` | required |
| 3–4 | `create_defect_page.dart:433` / `:443` | `TITLE`, `WHAT HAPPENED?` | required (gated `:201`, `:207`) |
| 5 | `create_defect_page.dart:450` | `WHAT DID YOU EXPECT?` | required (gated `:216`) |
| 6 | `create_defect_page.dart:457` | `REPRODUCTION STEPS (OPTIONAL)` | optional — marked |
| 7 | `create_defect_page.dart:464` | `SEVERITY` | required (gated `:229`) |
| 8 | `create_defect_page.dart:476` | `INTAKE CATEGORY (OPTIONAL)` | optional — marked |
| 9 | `create_defect_page.dart:485` | `PRODUCT` | required (gated `:238`) |
| 10 | `create_defect_page.dart:494` | `AFFECTED WORK ITEM (OPTIONAL)` | optional — marked |
| 11 | `create_defect_page.dart:503` | `EVIDENCE (OPTIONAL)` | optional — marked |
| 12–14 | `create_feature_request_page.dart:212/222/232` | `TITLE`, `USE CASE`, `PRODUCT` | required — **unverified**: I did not read that page's bloc, so this is stated as an assumption, not a verified fact |
| 15 | `form_primitives.dart:304` inside `DesignTextField` | caller-supplied | see below |

The prior report's "create_defect ×10" is itself wrong — there are **9**, and the five required defect
fields are `TITLE`, `WHAT HAPPENED?`, `WHAT DID YOU EXPECT?`, `SEVERITY`, `PRODUCT` (exactly the five the
gate validates).

### The `DesignTextField` compile trap, and how this design avoids it

`DesignTextField` (`form_primitives.dart:287`) has **no** `requirement` parameter; it forwards the caller's
`label` straight into `FormFieldSlot` at `:305`. Its three call sites —
`model_executions_page.dart:851,857,863`, labelled `Work Item ID`, `Provider`, `Model ID` — pass only
`initialValue`, `label`, `onChanged`. Adding a **non-defaulted** `requirement` parameter breaks all three at
compile.

**Specified resolution: add no parameter.** The marker already lives in the label string, so those three
sites need no change at all, and the compile risk never arises. `DesignTextField`'s three sites are also
**explicitly out of the convention's domain** — they are filter inputs with no submit gate, so
"required" is undefined for them and stamping `(OPTIONAL)` on every filter field would be noise. Declaring
that exclusion is the decision; it is a scope statement about *submit-gated form fields*, not a second
convention.

---

## 5. R5 — accessibility contrast ledger (all figures measured)

Measured with the WCAG 2.1 relative-luminance formula from the hex values at
`apps/control_plane/lib/core/design_tokens.dart:99-101` (light) and `:120-122` (dark).
**Line-number note:** the dispatch cites `:96,101,117,122`; at `77c19f1` the ink tokens are at
`:99-101` and `:120-122`. The dispatch's ratios are all correct; only its line numbers are stale.

| Foreground | Background | Light | Dark | AA (≥4.5:1) |
|---|---|---|---|---|
| `inkSecondary` | `card` | **6.74:1** | **6.10:1** | pass / pass |
| `inkTertiary` | `card` | 4.99:1 | **4.23:1** | pass / **FAIL** |
| `inkPrimary` | `card` | 16.20:1 | 13.48:1 | pass / pass |
| `inkPrimary` | `accent` (button fill) | **3.07:1** | **2.72:1** | **FAIL** / **FAIL** |
| `#ffffff` | `accent` | **5.27:1** | 2.99:1 | pass / **FAIL** |
| `#06121f` | `accent` | 3.58:1 | **6.30:1** | **FAIL** / pass |
| `positive` | `canvas` | 4.97:1 | 13.01:1 | pass / pass |
| `negative` | `canvas` | 5.33:1 | **4.02:1** | pass / **FAIL** |
| `negative` | `card` | 5.72:1 | **3.68:1** | pass / **FAIL** |
| `attention` | `card` | 5.01:1 | 7.28:1 | pass / pass |

Confirms the dispatch's three load-bearing figures exactly: `inkSecondary` 6.74/6.10, `inkTertiary`
4.99/4.23 (fails dark), and `inkPrimary`-on-fill 2.72 dark.

### Decisions

1. **Helper below the button → `inkSecondary`** (§ 2c). Clears AA in both themes.
2. **Button label → inherit the theme's `foregroundColor`**, i.e. `#ffffff` light / `#06121f` dark
   (§ 2d). One of the two passes in each theme; `inkPrimary` passes neither.
3. **The key-panel meta line is already `inkSecondary` on the boards** (`BPM · Add Product · Light`'s
   `Art S` is `#5a5c5b`, dark `#a8a6a0`) — so R5's correction moves the *build* toward the *board*, not
   the other way round. My four boards keep `inkSecondary`.
4. **`Key State` uses `negative` on the Unknown-host boards**, matching the desktop boards — but
   `negative` on dark is **4.02:1 on canvas / 3.68:1 on card**, i.e. it **fails AA in dark**, and no
   compliant alternative exists in `ShipItPalette`. This is a **pre-existing design-system defect that
   affects the existing desktop boards too**, so it is not mine to unilaterally re-token. Recorded as
   follow-up F3 and blocker B4. I am reporting the failure rather than hiding it.

---

## 6. R6 — the visual consequence of human points 2a–2d

**2a — the page generates a key on Repository SSH URL input.** The boards show the key panel present in
*both* states with a real public key line, and the `NOT REGISTERED YET` eyebrow unchanged, so the eyebrow
never over-claims registration. The generation *trigger* is backend behaviour and belongs to the sibling
lane; what the boards fix is that a key panel exists and is visibly scoped "DEPLOY KEY · THIS PRODUCT ONLY".

**2b — `Register product` depends on key generation *and* host trust.** Both boards show a single
`Register product` label; the only thing that differs is the helper, which names the outstanding action —
`Confirm the host above to enable Register product.` vs `Access verified — this product can be registered`.
That is human 2e's rule ("read from the top … what the user must do to enable the button") expressed as a
single line that changes with state.

**2c — "Check access" is undocumented.** Labelled unambiguously on the boards as `Check access` in the
unverified state and `Check again` once verified — the same pair the desktop boards already use
(`S · Add Product · Verified · Light`'s `Key Check`). What it *does* is the sibling lane's normative
property; the boards additionally carry the desktop boards' `Key Help` sentence position, which on mobile
I did **not** add, because the mobile grammar has no Key-Help line and inventing one would be
board-implied behaviour. Assumption A1 below.

**2d — no Cancel on the trust step.** The Unknown-host boards carry a `CONFIRM THIS HOST BEFORE
CONNECTING` panel with the host fingerprint and a `Trust this host` button and **nothing else**. The
`Cancel` affordance present on the existing desktop board (`S · Add Product · Unknown host · Light`,
`Host Cancel` at (452, 695)) is deliberately **absent**. This implements human 2d and addendum 2
verbatim; it is settled human input, which is why I drew it rather than escalating it.
Audit confirms 0 occurrences of "Cancel" across all four boards.

---

## 7. Traceability

### Element → requirement → decision → production primitive/token

| Board element | Req | Settled by | Production primitive / token |
|---|---|---|---|
| `Back` `‹  Products` | R1 | 73097d48 | `MobileBackBar`; `accent` |
| `H1` `Add a product` | R1 | 73097d48 | `ShipItType.pageTitleMobile`; `inkPrimary` |
| `St Tick` + `Status` `NOT REGISTERED YET` | R1, R6/2a | 73097d48 | `AccentTick`; `microLabel`; `inkTertiary` |
| `Rule 1` | R1 | 73097d48 | `ContentRule`; `rule` |
| `F K 0/1/2` labels | R4 | B1 (existing convention) | `FormFieldSlot.label`; `microLabel`; `inkTertiary` |
| `Field Box 0/1/2` | R1, R4 | 73097d48 | `SingleLineInput` + `formBoxDecoration(vertical: padSingle)`; `controlBorder` |
| `Field Val 0/1/2` | R1, R6 | 73097d48 | `bodySmall`; `inkPrimary` |
| `Art Bg` / `Art Edge` | R1 | 73097d48 | `DesignPanel(edgeColor:)`; `card`, `accent` |
| `Art K` eyebrow | R1 | 73097d48 | `MicroLabel`; `inkTertiary` |
| `Art T` | R1, R6 | 73097d48 | `bodySmall` w600; `inkPrimary` |
| `Art S · PENDING D4 (at-rest model)` | R1, R6 | **b869ec24** | `monoMeta`; **`inkSecondary` (corrected)** |
| `Key State` | R6/2b,2c | 73097d48 + sibling lane | `attention` / `positive` / `negative` — see § 5 note 4 |
| `Art L1 · Copy key` | R1, R6 | 73097d48 | `InlineLink`; `accent` |
| `Art L2 · Check access` / `Check again` | R6/2c | 73097d48 | `InlineLink`; `accent` |
| `Trust K/Body/Body 2/Host` | R6/2d | 73097d48 + human 2d | `MicroLabel`, `bodySmall`, `monoMeta`; `card`, `attention` |
| `Trust Btn` `Trust this host` | R6/2d | 73097d48 + human 2d | `FilledButton` (accent fill, theme foreground) |
| `Submit` + `Submit L` | **R2** | human 2e | `MobilePrimaryButton` (label only) |
| `Submit Sub` helper below button | **R2**, **R5** | human 2e + R5 | `monoMeta`; **`inkSecondary`** |
| `Disclose` `Show technical details ▸` | **R3** | human 2f | `TechnicalDetails`; `accent` |
| `Bottom Nav / … / Products` | R1 | 73097d48 | `MobileBottomNav`; `inkQuiet`/`inkPrimary` |

### Requirements covered / gaps

- `requirements_covered`: R1, R2, R3, R4, R5, R6, R7.
- `requirements_gaps`: none for R1–R7. The gaps below are **not** requirement gaps — they are
  implementation and design-system items this lane cannot own:

| Id | Gap | Why it is not mine |
|---|---|---|
| G1 | The normative `hostUnrecognised` state machine and what "Check access" verifies | sibling lane `design-addproduct-keyservice` owns it |
| G2 | At-rest protection wording for `Art S` | ~~open human decision; string marked `PENDING D4`~~ — **RESOLVED at revision 5 by `9417f8bf` (OPTION_C / A3, an external secret manager); layer renamed `Art S`, string corrected to `ed25519 · generated on the server · the private half stays in the secret manager` on all four boards** |
| G3 | `negative` on dark fails AA (4.02:1 / 3.68:1) and no compliant token exists | `ShipItPalette` is design-system-owned |
| G4 | `TechnicalDetails`' unconditional `ContentRule` vs a board with none | shared primitive used by 4 other screens |
| G5 | The build's "What you're registering" / "What happens next" panels have no board | removing them is a UX change; see F1 |
| G6 | `_buildInfoPanel` (`:480`, `:979`) repeats the false keychain claim | production source, PROHIBITED to me; the mobile boards have no such panel |
| G7 | 2px submit-height divergence (board 34 vs `MobilePrimaryButton` 36) | pre-existing; needs QA baseline agreement |
| G8 | `flutter analyze` not run → `implementation_feasibility` cannot be HIGH | see metadata |

---

## 8. Sibling-lane coupling and stated assumptions

Assumptions, every one pending `design-addproduct-keyservice`:

- **A1** — "Check access" is a user-triggered verification that does **not** rotate the key. The prior
  review's finding B6 recorded that today each press calls `_generateMockKeyPair` (`:113-120`) and so
  silently rotates the key the user just copied. My boards show one key line that is stable across the
  unknown → verified transition. **If the sibling lane's design keeps rotation on re-check, the `Art S`/
  key block does not change but the `Check again` affordance must be re-specified** — see below.
- **A2** — the trust step's outcome is persisted server-side (so returning to the page later resumes it),
  per addendum 2 ("we'll find the key on the machine ready to be verified again").
- **A3** — `hostUnrecognised` is a *state of the page*, not a modal sheet, so the mobile layout can carry
  it inline as a panel between the key block and the submit action.
- **A4** — the trust decision is not itself a "register" event, so `NOT REGISTERED YET` stays on all four boards.

**Would these boards need redrawing if the sibling's state machine diverges?** Only the **Unknown-host**
pair (2 of 4 boards), and only in the region between the key panel and the submit button:
- if `hostUnrecognised` becomes a **modal/sheet**, the inline `Trust Bg`/`Trust Btn` block moves out and the
  submit block returns to the Verified boards' geometry (y=510/552/580) — a re-layout of 6 layers;
- if trust offers **any third affordance** (e.g. "connect with a different host"), one more line appears in
  the trust panel and the panel grows past 160px, pushing submit/helper/disclose down;
- if verification is **server-push rather than a user-tapped "Check access"**, `Art L2` is removed from both
  boards and the Unknown-host helper text changes.
The **Verified** pair and all copy, tokens, geometry and the footer are unaffected. So the blast radius is
bounded to ≤6 layers on 2 boards — I would rather redraw than have the sibling lane guess, so treat the
`Trust *` layers as provisional.

---

## 9. Premise corrections carried into this revision

Recorded because each changed what I drew, and each was verified rather than accepted:

| Dispatch premise | Verified finding |
|---|---|
| "`Show technical details` appears nowhere… it was removed, so this is a restoration" | **False.** It renders via `TechnicalDetails` (`design_primitives.dart:415`), instantiated at `add_product_page.dart:316` and `:925`. Nothing to restore. |
| "the footer copy line IS present at `add_product_page.dart:383`" | **Desktop-only.** `_buildFooter` is called only at `:314`; `_MobileAddProduct` has no footer copy. |
| "the design has copy at the bottom plus one footer line" | The **mobile** board has no copy line — only `Disclose`. The **desktop** board has copy + disclosure on one line. |
| "it was de-duplicated … the original report said two rows" | The duplication is real but is `_buildFooter`'s rule+copy **plus** `TechnicalDetails`' own rule+note; the disclosure itself was never duplicated. |
| "`defects/create_defect_page.dart`" | path is `features/defect_report/create_defect_page.dart`; `features/defects/` does not exist. |
| "`shared/design_tokens.dart`" | path is `core/design_tokens.dart`; `shared/design_tokens.dart` does not exist. |
| "15 `FormFieldSlot(`, create_defect ×10" | 15 invocations + 1 constructor = 16 grep lines, but create_defect has **9**, not 10. |
| "`design_tokens.dart:96,101,117,122`" | ink tokens are at `:99-101` / `:120-122` at `77c19f1`. Ratios all confirmed correct. |
| "`BPM - Add Product - Light`", `SM -` prefix | Page uses `·` and an `S ·` prefix. See § 1. |

---

## 10. Follow-ups (not owned by this lane)

| Id | Item | Owner |
|---|---|---|
| F1 | Decide the fate of the build's "What you're registering" and "What happens next" panels — no board has them | design-system owner / human (Level 2) |
| F2 | `_buildInfoPanel` copy at `:480-482` and `:979-981` asserts the browser-keychain guarantee and must be removed or rewritten; the mobile boards have no info panel | implementation |
| F3 | `negative` on dark is 4.02:1/3.68:1 — design an AA-compliant dark semantic or accept and document | design-system owner |
| F4 | `TechnicalDetails` always paints a `ContentRule` the mobile board does not have | design-system owner |
| F5 | Reconcile `BPM · Add Product · Light/Dark` (helper still `inkTertiary` 4.23:1 dark; key meta still "private half stays in the keychain") with these four boards | design-system owner |
| F6 | 34px board submit vs 36px `MobilePrimaryButton` | QA golden baseline |
| F7 | Add Product has **zero** test coverage (26 test files, none imports it) — from 73097d48 follow-up actions | implementation |
| F8 | Penpot's IBM Plex Sans has no `500` weight (supported: 200/300/400/600/700/900), so links are drawn at 400 while `ShipItType.link` uses 500 — a file-fidelity limitation, not a spec change | design-system owner |

> **WITHDRAWN — revision 2 §2; marker added at revision 3. F8's premise is false in BOTH directions.**
> The variants of Penpot's `IBM Plex Sans` are `100, 200, 300, 400, 500, 600, 700`: **`500normal` exists**
> (the one weight F8 claimed was missing), **`900` does not exist at all**, and `100` exists though F8
> omitted it. There was no file-fidelity limitation; the link layers simply had to be drawn at the right
> weight, and they now are — **`Art L1`/`Art L2` at 11/500**, matching `ShipItType.link`
> (`apps/control_plane/lib/core/design_tokens.dart:426`). F8 was **deleted** from the current revision
> precisely so no future lane would rely on this premise; it survives here only because revision 1 is
> retained byte-identical. **Do not rely on this row.**