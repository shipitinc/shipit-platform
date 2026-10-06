# Report — Design Agent, correction lane `design-correct-addproduct-mobile`, cycle 2

Returned verbatim by the `design-agent` and persisted here per `aef-orchestrator` §14.
**Current revision: `design-revision-3.md` (`REVISION_ID B5006A15-2DEE-47BE-BF2F-C44196B089E3`).**
Metadata: `design-revision-metadata-3.yaml`. Board evidence: `penpot-board-evidence.md` (regenerated).

## Mandatory header

```yaml
RESULT: DESIGN_REVISION_COMPLETE
TASK_ID: design-correct-addproduct-mobile
TASK_TYPE: design-produce     # correction pass over a design revision; the design-agent's own lane
FEATURE: Add Product rebuild — Gate D3 correction pass 2 on revision 2 (11 findings)
WORKTREE: /private/tmp/shipit-correct-addproduct-mobile
BRANCH: design-correct-addproduct-mobile
BASE_SHA: 77c19f1
HEAD_SHA: 77c19f1
COMMITTED: NO
```

`BASE_SHA == HEAD_SHA` because committing is forbidden to this lane.
**No Docker or Compose command was run** — not even a read-only one.

## The review report was found and read in full

Revision 2 recorded (G11) that its review report did not exist. **This pass's report did:**
`docs/engineering/dispatch/tasks/design-review-addproduct-mobile/report-revision-2.md` was read in full
from the canonical checkout before anything was written. **G11's practical impact on this pass was nil**
and the report's closing judgement is answered in `design-revision-3.md` §12.

---

## Correction-by-correction changelog

| Finding | What I changed |
|---|---|
| **H-N1** | `Trust Btn L` `align: left` → **`center`** on both Unknown boards. Glyph inset **0px → 50.367px** ((180 − 79.266)/2). Revision 2's dismissal compared box `x` (30 vs 254) and ignored `align`: desktop `Host Btn L` is **`align: center`** on both `S · Add Product · Unknown host · Light/Dark`, same 180-wide box, 50.371px inset. **This lane's own `Submit L` was already centred.** A defect **this lane introduced**, on boards **this lane owns** — never out of scope. Verified in both PNG exports. |
| **M-N1** | §5's two-row `canvas`/`card` split **collapsed to one row: `canvas`, both platforms, 4.65:1 / 4.62:1, both pass.** Verified: `add_product_page.dart:316`'s `TechnicalDetails` is a direct child of the desktop page `Column` and a **sibling** of the `Row` at `:303-311` carrying `_RightPanel`; `_RightPanel` is the `DesignPanel` (`:632`) holding only the panel's own content; `scaffoldBackgroundColor` is `palette.canvas` (`core/theme.dart:23`); mobile `:925` is likewise outside the `DesignPanel` at `:853`. **`N7` WITHDRAWN** — it escalated a desktop AA failure Add Product does not exhibit. **New `G12`/`N9`:** `Register` sits inside `DesignPanel` = `card` on **both** platforms in code, while the boards draw it on the bare page background. |
| **M-N2** | **Corrected traceability matrix added** as revision 3 §6. Revision 2 had no matrix, so the one that would have frozen was revision 1's — wrong in three rows: `:325` `Art T` said "`bodySmall` w600" (`bodySmall` is 11/400 at `:386`; the board draws 13/600 = `sectionTitle` at `:352`); `:335` `Bottom Nav` said `inkQuiet`/`inkPrimary`, **false for dark**, which draws `#8A8983` = `inkTertiary`, not `inkQuiet` `#85847E`; `:330` `Trust K/Body/Body 2/Host` named **no foreground token at all**. The new matrix also names each row's **surface** and **alignment** — the omission that let an AA-failing layer and a 0px-inset label through review twice. |
| **M-N3** | **`penpot-board-evidence.md` regenerated from the live file**, not annotated. Was publishing `42/42/34/34` (live `44/44/36/36`), a bare `Register product` count of `1` with no rule (2 on both Unknown boards under revision 2's own substring rule), unreproducible text counts `24/24/19/19` (live `29/29/24/24`), and §3/§5 text predating the weight pass, the token swap, the badges, the repository harmonisation and the 16 renames. **Counting rules are now stated beside every number**, and a table explains why each superseded figure was wrong. An **operations log** records the two failed API calls and the two plugin suspensions, because a failed write that is assumed rather than re-read is how a stray ships. |
| **M-N4** | `Nav Label 3` ("Products") **10/400 → 10/600 on all four boards**. `mobile_chrome.dart:296-298` sets `fontWeight: active ? FontWeight.w600 : FontWeight.w400` and `navLabelMobile` is 10px (`design_tokens.dart:500`); the active tab was drawn at the same weight as the four inactive ones. `Nav Label 0/1/2/4` stay 400 (correct). **Revision 2's stated reason is withdrawn** — "the nav is a clone of a PROHIBITED board's sub-tree" does not hold; the four boards this lane owns and everything inside them are in scope, and it contradicted §2's own `microLabel` resolution. **`N6` narrowed** to the PROHIBITED reference boards. Verified in all four PNG exports. |
| **M-N5** | **Disabled-state read-back added to the Unknown-host pair.** `FilledButton` gets `onPressed: null` when `canRegister == false` (`:906`, `:679`) and `core/theme.dart:67-83` sets no disabled colour — **confirmed by grep, no match for either parameter**. The resolved appearance was then **derived from Flutter 3.44.7 source rather than assumed**: `styleFrom` → `defaultColor(enabled, null)` → `WidgetStateProperty.fromMap({disabled: null, any: enabled})` → `WidgetStateMapper.resolve` returns the **first satisfied key's value even when that value is `null`** (`widget_state.dart:1008-1013`) → `ButtonStyleButton.effectiveValue` sees `themeValue == null` and falls through to `_FilledButtonDefaultsM3` → `colorScheme.onSurface` @12% fill / @38% label, with `theme.dart:32` setting `onSurface: palette.inkPrimary`. Composited over `DesignPanel`'s `card`: **`#E4E4E4` + `#999A9A` (2.22:1)** Light, **`#3F403F` + `#848482` (2.78:1)** Dark. Added as **two page-level groups** (6 layers each) at y=11600, x=7550/7970, 358×121, lowest shape 11721 with 79px clearance and **zero overlap against all 160 boards**. Every layer name carries the same `· PROVISIONAL (G1 hostUnrecognised)` marker as the trust panel. **No palette token invented, no human gate needed.** The four screen boards are deliberately unchanged — §7's "known-wrong expression for the Unknown-host state" stands. `N4`/`G9` kept and **strengthened with measurements**. |
| **M-N6** | **My own false claim, corrected at the head of the revision.** Revision 2 said the 36px clamp claim was "deleted from § 2a, from the `risk_rationale` and from `report.md`". **It was deleted from none of them** — `design-revision.md:70`, `:72-73`, `report.md:48`, `:197`, `design-revision-metadata.yaml:15-16` all still carried it. Corrected statement: **"superseded by revision 2 §6a, not deleted."** Withdrawal markers now at all five sites, plus the `correction-report.md` row itself and the revision-2 metadata's `risk_rationale` and `M-R1`. |
| **L-N1** | F8's false "no `500` weight" claim survived verbatim and un-marked at `design-revision.md:414` and `report.md:100`. **`WITHDRAWN` markers added to both**, naming the current weights (`500normal` exists; `900` does not; `100` exists and was omitted) and the corrected link weight (11/500, `design_tokens.dart:426`). Supersession headers added to the heads of all six retained artifacts. |
| **L-N2** | Branch recorded as `design/correct-addproduct-mobile` at `design-revision-2.md:16`, `design-revision-metadata-2.yaml:220` and `correction-report.md`. **Actual: `design-correct-addproduct-mobile`** (`git branch --show-current`; `git worktree list`). Corrected in every artifact this pass writes, and flagged in the retained revision-2 artifacts beside the wrong value rather than silently rewritten. **Revision 1's own provenance block is left alone** — it records worktree `/private/tmp/shipit-design-addproduct-mobile` on branch `design/addproduct-mobile`, and `git worktree list` confirms **both exist**. Falsifying an accurate historical record is the same error in the other direction. |
| **L-N3** | **Two of three applied, one rejected.** `mobile_chrome.dart`'s `fontWeight:` is at **`:297`** (`:296` is the `.copyWith(` line) — applied throughout. `design_primitives.dart` citations now written in full as **`apps/control_plane/lib/shared/design_primitives.dart:320`/`:391`** (`find` confirms exactly one such file) — applied throughout. **REJECTED: the review states `class MobilePrimaryButton` is at `:425` and that `:424` is its doc comment. `grep -n` returns `424:class MobilePrimaryButton extends StatelessWidget {` and `425:  const MobilePrimaryButton({`; the doc comment is `:422-423`. Revision 2 already cited `:424` correctly, so nothing changed.** Applying the reviewer's off-by-one would have introduced the exact error the citation exists to prevent, in a document whose purpose is to stop off-by-ones. |
| **L-N4** | Published counts corrected to live figures **with the counting rule stated beside them**: top-level layers **44/44/36/36** (`board.children.length`) and text layers **29/29/24/24** (every `type === 'text'` in the subtree, **including** the five `Nav Label` layers and the `Nav Badge` numeral). Revision 2's "24/24/19/19" was reproducible only by excluding `Nav Label` while still counting `Nav Badge` — a rule nobody stated, and a wrong one. |

### One dispatched premise rejected (the second in two passes)

`report-revision-2.md` L-N3 is wrong on `MobilePrimaryButton:425` (§ row above). The first was "both desktop
boards draw 13/600" — they draw 12/600. **Both times the correction was right on substance and wrong on one
detail.** The operational rule this pass adopted, and recorded in `design-revision-3.md` §12: *a finding is a
set of claims, and each claim gets checked.*

---

## Validation results

| Command / check | Status | Evidence |
|---|---|---|
| `git branch --show-current` | pass | `design-correct-addproduct-mobile` |
| `git rev-parse HEAD` | pass | `77c19f114ee691e8c434afe37b7c84494b66dc40` |
| `git status --porcelain=v1` | pass | only `?? docs/engineering/dispatch/tasks/design-addproduct-mobile/` — **no tracked file modified** |
| `git worktree list` | pass | confirms both revision 1's and this lane's worktree/branch pairs |
| **Read the dispatched review report** | **pass — file found and read in full** | `docs/engineering/dispatch/tasks/design-review-addproduct-mobile/report-revision-2.md`, from the canonical checkout. G11's practical impact nil |
| `Trust Btn L` align / inset, both Unknown boards | pass | `center`, 50.367px (was `left`, 0px) |
| Desktop `Host Btn L` align, both desktop boards | pass | `center`, 50.371px inset — the comparison revision 2 got wrong |
| `Nav Label 3` weight, all four boards | pass | **600** (was 400); `Nav Label 0/1/2/4` still 400 |
| `Register` rect unchanged, all four | pass | 358×34 @ x=16, `#1668d6@1` / `#4496fc@1`, y=678 / 510 |
| WCAG re-measure, all 13 ledger pairs | pass | sanity 21.00 / 1.00; **every revision-1 and revision-2 figure reproduced exactly**; `inkTertiary` on `canvas` = **4.65:1 light / 4.62:1 dark, both platforms** |
| `scaffoldBackgroundColor` | pass | `core/theme.dart:23` = `palette.canvas` |
| Desktop `TechnicalDetails` parentage | pass | `:316` is a child of the page `Column`, sibling of the `Row` at `:303-311`; `_RightPanel` `DesignPanel` at `:632` |
| Mobile `TechnicalDetails` parentage | pass | `:925` outside the `DesignPanel` at `:853` |
| `filledButtonTheme` disabled params | pass | grep for `disabledBackgroundColor` / `disabledForegroundColor` in `core/theme.dart` → **no match** |
| Flutter `ButtonStyle` resolution chain | pass | read in the pinned SDK `/Users/alkebut/fvm/versions/3.44.7`: `filled_button.dart:287-288`, `button_style_button.dart:266-273` and `:381-391`, `widget_state.dart:1008-1013`, `filled_button.dart:531-562` |
| `colorScheme.onSurface` | pass | `core/theme.dart:32` = `palette.inkPrimary` |
| Disabled-state colours composited | pass | script-computed: `#E4E4E4`/`#999A9A` (2.22:1), `#3F403F`/`#848482` (2.78:1) |
| `navLabelMobile` / active weight | pass | `design_tokens.dart:500` = 10px; `mobile_chrome.dart:297` = `active ? w600 : w400` |
| `class MobilePrimaryButton` | pass | **`mobile_chrome.dart:424`** — the review's `:425` is wrong; `:422-423` is the doc comment |
| `design_primitives.dart` path | pass | `apps/control_plane/lib/shared/design_primitives.dart` (one match); `:320` = `palette.card`, `:391` = `monoMeta` + `inkTertiary` |
| `DesignPanel` surface | pass | `apps/control_plane/lib/shared/design_primitives.dart:320` = `palette.card` |
| Token citations | pass | `sectionTitle:352`, `bodySmall:386`, `microLabel:368`, `link:426`, `linkMicro:443`, `buttonLabelMobile:508-514`, `pageTitleMobile:561` |
| Board / text-layer counts, live | pass | `44/44/36/36` and `29/29/24/24`, rules stated |
| `M-N5 READ-BACK` groups | pass | 2 groups × 6 layers, 358×121, in-band, 79px clearance, **0 overlaps vs all 160 boards** |
| Root children | pass | 164 = 160 boards + `Tab Group` + `Rectangle` (pre-existing) + 2 read-back groups. **Strays: none** |
| Forbidden-copy audit | pass | 0 hits, all four boards |
| `Register product` counts | pass | exact 1/1/1/1; substring **2/2/1/1**, rule stated |
| `Trust *` provisional markers | pass | **8 / 8** on each Unknown board |
| `Art S · PENDING D4 (at-rest model)` | pass | present and **unresolved** on all four |
| Pre-existing board integrity | pass | `BPM · Add Product · L/D` (5280,10750)/(5280,9800) 36/36; `S · Unknown · L/D` (10400,11800)/(10400,12750) 69/69; `S · Verified · L/D` (11700,11800)/(11700,12750) 65/65 — **all unchanged** |
| PNG export + visual read-back | pass | 4 boards + 2 read-back groups; one export-renderer artefact recorded, canvas geometry verified by `textBounds` |
| **A Flutter widget rendered** | **NOT_RUN** | no app was run. The disabled-state colours are a documented derivation from framework source (assumption A6), **not** a screenshot |
| `flutter analyze` | **NOT_RUN** | needs `flutter pub get`, which writes outside this lane's read-only scope; `apps/control_plane/.dart_tool/` absent. No feasibility claim derived from it |
| `docker` / `docker compose` — any | **NOT_RUN** | **none issued**, including read-only, per the hard rule |
| Automated pixel diff vs reference boards | **NOT_RUN** | no such tooling; geometry compared by name/position/size/`textBounds`, **not pixels** |
| Full walk of the four desktop `S · Add Product` boards | **PARTIAL** | identity + position + `Host Btn`/`Host Btn L`/`R Submit L` read (what H-N1 needed); not every layer walked |
| Commit / push / self-approval | **NOT_RUN** | none performed; `READY_FOR_INDEPENDENT_DESIGN_REVIEW` is my readiness statement, not an approval |

## Cleanup confirmation

- [x] **No Docker or Compose command issued.**
- [x] Throwaway WCAG/compositing script `/var/folders/.../opencode/wcag_r3.py` deleted after use.
- [x] A **duplicate Light heading** and a **54px surface rect** left by a partial retune were detected on
      read-back (13 shapes where 12 were intended), and both were fixed — the duplicate removed, both
      surfaces normalised to 48px.
- [x] Two groups created by a first attempt at the read-back were dissolved by removing their descendants
      and then their shells (the documented `penpotUtils.ungroup` was not available), verified back to 162
      root children before rebuilding.
- [x] A failed `createText` call was probed down rather than retried blindly, and confirmed to have left
      **nothing** behind (`found: []`) before the rebuild.
- [x] The Penpot plugin tab **suspended twice** mid-pass. Woken each time, and **every timed-out write was
      re-read from the live file rather than assumed** — which is how the H-N1/M-N4 edits and the final
      repositioning were confirmed despite the timeouts.
- [x] No commit, no push, no self-approval.
- [x] Nothing written outside `docs/engineering/dispatch/tasks/design-addproduct-mobile/**`, the four boards
      this lane owns, and the two new page-level annotation groups. `LANES.md`, `WORK_STATE.md`,
      `.decisions/**`, production source and the keys lane's directory untouched.
- [x] `BPM · Add Product · Light/Dark` and the desktop `S · Add Product · …` boards were **read only** —
      never edited, renamed, moved or deleted — and their integrity is re-verified above.

---

```yaml
RESULT: DESIGN_REVISION_COMPLETE
FEATURE: Add Product rebuild — Gate D3 correction pass 2 on revision 2 (11 findings)
BRIEF_ID: 52CB4098-FF87-4B78-81DA-1104269551A1
REVISION_ID: B5006A15-2DEE-47BE-BF2F-C44196B089E3
REVISION_NUMBER: 3
BRANCH: design-correct-addproduct-mobile
BASE_SHA: 77c19f1
HEAD_SHA: 77c19f1

OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**
  - penpot:d8ac01df-6646-81d2-8008-a366c09aa9d3 — the 4 boards below, plus the 2 page-level
    M-N5 READ-BACK annotation groups created by this pass
READ_ONLY_PATHS:
  - apps/control_plane/lib/**; packages/**; docs/engineering/**; AGENTS.md; .decisions/**
  - /Users/alkebut/fvm/versions/3.44.7/packages/flutter/lib/src/**   # Flutter SDK source, read only
PROHIBITED_PATHS:
  - apps/**; packages/**; docker/**; .github/workflows/**
  - .decisions/**; docs/engineering/WORK_STATE.md; docs/engineering/dispatch/LANES.md
  - the keys lane's task directory
  - EVERY other Penpot board, including 'BPM · Add Product · Light/Dark' and the desktop
    'S · Add Product · …' boards — read-only, never edited/renamed/moved/deleted, integrity
    re-verified after all authoring (36/36/69/69/65/65 children, positions unchanged)

ARTIFACT_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-3.md
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-metadata-3.yaml
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/penpot-board-evidence.md      # REGENERATED
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/correction-report-3.md
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-2.md          # + superseded header
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-metadata-2.yaml # + corrected claims
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/correction-report.md         # + corrected claim
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision.md            # + withdrawal markers
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-metadata.yaml # + withdrawal marker
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/report.md                      # + withdrawal markers
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-brief.md               # unchanged
  - penpot:6d055762-a70b-804c-8008-bf65ff750422  SM - Add Product - Unknown host - Light  44 layers / 29 text
  - penpot:6d055762-a70b-804c-8008-bf65e644269b  SM - Add Product - Unknown host - Dark   44 layers / 29 text
  - penpot:6d055762-a70b-804c-8008-bf660e124738  SM - Add Product - Verified - Light      36 layers / 24 text
  - penpot:6d055762-a70b-804c-8008-bf65f36b1c9a  SM - Add Product - Verified - Dark       36 layers / 24 text
  - penpot:6d055762-a70b-804c-8008-bf7d2cd65125  M-N5 READ-BACK Register product DISABLED Light (group, 6 layers)
  - penpot:6d055762-a70b-804c-8008-bf7d2ce38c50  M-N5 READ-BACK Register product DISABLED Dark  (group, 6 layers)

RISK_LEVEL: 2
RISK_RATIONALE: >
  Unchanged at 2 for the third pass, and unchanged for a reason this revision makes explicit rather than
  repetitive: every change is Level 0/1. Two `align` corrections (Trust Btn L, left -> centre, both
  Unknown-host boards); four font-weight corrections (the active bottom-nav label, 400 -> 600, all four
  boards); twelve ADDITIVE annotation layers in two new page-level groups recording what
  FilledButton(onPressed: null) already paints; and record corrections - a corrected traceability matrix, a
  collapsed contrast-ledger row, regenerated board evidence, corrected citations, withdrawal markers on
  disproven claims in retained artifacts, and a corrected branch name.
  None of it changes an interaction pattern, a navigation or information-architecture surface, or the
  primary action's structure. Two changes make previously-unmeasured reality measurable rather than
  inventing anything: the disabled Register appearance is DERIVED from Flutter 3.44.7's
  _FilledButtonDefaultsM3 plus core/theme.dart:32 (no palette token chosen, no human gate needed), and the
  expanded TechnicalDetails surface is corrected to `canvas` on BOTH platforms.
  The one genuinely new judgement is the opposite of a re-design: revision 3 RECORDS that the code paints a
  disabled Register at #E4E4E4 / #999A9A (Light, 2.22:1) and #3F403F / #848482 (Dark, 2.78:1), and leaves
  the screen boards' enabled-looking rect in place as the known-wrong expression. The token the design
  system still lacks stays a design-system-owner item (N4/G9). Independently agreed at
  INDEPENDENT_RISK_LEVEL: 2, RISK_LEVEL_AGREEMENT: YES at the revision-2 gate, and nothing here moves it.
  No human gate is raised. B3 remains filed as Human Decision 27ea6536 and is NOT re-opened, and 'Art S'
  stays PENDING D4.

CHANGELOG:
  - revision 3 — correction pass 2 after the Gate D3 re-review of revision 2. 11 findings applied:
    H-N1, M-N1…M-N6, L-N1…L-N4. Six board corrections (2 align + 4 weights), one additive annotation
    pair (12 layers in 2 groups), one new traceability matrix, one collapsed ledger row, one regenerated
    evidence file, withdrawal markers on ten disproven-claim sites across six retained artifacts, and one
    corrected branch name. One dispatched correction REJECTED (L-N3's MobilePrimaryButton:425 - the class
    is at :424). Two notifications WITHDRAWN (N7 false surface, N8 false premise and now fixed), one
    NARROWED (N6), one STRENGTHENED with measurements (N4), one RAISED (N9, from the new G12).
  - revision 2 — correction pass after Gate D3 (16 findings). Retained intact. §5's two-row canvas/card
    split, §8's L-R5 and N7/N8, §2's reason for leaving Nav Label 3 at w400, and its branch name are
    overturned by revision 3 and carry in-place SUPERSEDED pointers.
  - revision 1 — initial. Retained intact; F8's premise and the 36px minimumSize derivation are
    withdrawn in place. The parked register-button round (18A97195) was folded in by decision 73097d48.

TRACEABILITY:
  REQUIREMENTS_COVERED: [R1, R2, R3, R4, R5, R6, R7]
  REQUIREMENTS_GAPS: []
  NON_REQUIREMENT_GAPS:
    - G1 normative hostUnrecognised state machine + 'Check access' semantics — sibling lane
    - G2 at-rest wording for 'Art S' — open human decision, marked PENDING D4, NOT resolved here
    - G3 negative on dark fails AA (4.02:1 canvas / 3.68:1 card); no compliant token exists
    - G4 TechnicalDetails' unconditional ContentRule vs a board with none
    - G5 build's 'What you're registering' / 'What happens next' panels have no board
    - G6 RE-SCOPED: _buildInfoPanel AND product_detail_page.dart:614 repeat the false keychain guarantee
    - G7 34px board submit vs 36px MobilePrimaryButton
    - G8 flutter analyze not executed -> implementation_feasibility cannot be HIGH
    - G9 no ShipItPalette disabled-primary token; the painted appearance is derived from Flutter M3
        defaults. Now MEASURED and on the boards as a provisional read-back
    - G10 'Confirm the host above to enable Register product.' has no producer
    - G11 the revision-1 mobile design review report was never persisted. Practical impact on THIS pass
        was nil: the revision-2 report was found and read in full
    - G12 NEW — the primary action's surface: in code Register sits inside DesignPanel = palette.card on
        BOTH platforms, while the boards draw it on the bare page background (consequence of G5)

DESIGN_SYSTEM_COMPLIANCE: PARTIAL
UX_ACCESSIBILITY_SCORE: PARTIAL
IMPLEMENTATION_FEASIBILITY: MEDIUM

DISCOVERIES:
  - DESIGN_DISCOVERY / PRODUCT_SPECIFIC / automatic — a Material 3 disabled control's appearance is decided
    by a three-step fall-through that is easy to get backwards: `FilledButton.styleFrom` with only the
    enabled colour builds a `WidgetStateProperty.fromMap` whose resolver returns the FIRST satisfied key's
    value EVEN WHEN THAT VALUE IS NULL, so the theme's own property resolves to null when disabled and
    `ButtonStyleButton.effectiveValue` falls through to the M3 default — `colorScheme.onSurface` at 12%
    (fill) and 38% (label). The intuitive reading ("the enabled colour stays, so nothing looks disabled")
    is wrong. Verified file-and-line in the pinned Flutter 3.44.7 source. This is why ShipItPalette has no
    disabled token and why the design system owns that decision, not this lane.
  - DESIGN_DISCOVERY / PRODUCT_SPECIFIC / automatic — the MobilePrimaryButton sits INSIDE a DesignPanel
    (palette.card) on mobile (:904 in the panel at :853) and the desktop FilledButton sits inside
    _RightPanel's DesignPanel (:679 in :632). So the feature's one committing control is on `card` in code
    while every board draws it on the bare page background, because the "What happens next" panel has no
    board at all. G5 was recorded as a COPY gap; the SURFACE consequence under the primary action was
    never recorded. This also means any disabled-state colour must be composited over `card`, not canvas.
  - DESIGN_DISCOVERY / PRODUCT_SPECIFIC / automatic — a text layer's `align` is a separate property from its
    box `x`, and a flush-left label inside a wider button is invisible to any check that compares positions
    alone. Reading `align` plus `textBounds.width` turns "is this centred?" into arithmetic:
    (buttonWidth - textWidth)/2 + (labelX - buttonX). It produced a 0px-inset defect that survived two
    review passes and was then defended with a comparison that had not been made.
  - DESIGN_DISCOVERY / PRODUCT_SPECIFIC / automatic — the expanded TechnicalDetails lines sit on `canvas` on
    BOTH platforms. add_product_page.dart:316 is a direct child of the page Column and a sibling of the Row
    carrying _RightPanel; that DesignPanel holds only the panel's own content. So a contrast ratio measured
    against `card` describes a surface the component never sees, on either platform, and produces a false
    defect report on one and a false all-clear on the other.
  - CONTRADICTION / PRODUCT_SPECIFIC / human-review — report-revision-2.md L-N3 states that
    `class MobilePrimaryButton` is at mobile_chrome.dart:425 and that :424 is its doc comment. `grep -n`
    returns 424 for the class and 422-423 for the comment; revision 2's citation was already correct.
    Second consecutive pass in which a dispatched premise is right on substance and wrong on one detail.
    Surfaced and NOT acted on rather than applied.
  - CONTRADICTION / PRODUCT_SPECIFIC / human-review — revision 2 asserted that the 36px clamp claim had been
    deleted from three files. It was deleted from none. Self-reported, corrected in the current revision
    rather than quietly amended, and recorded as a learning below.
  - WORKFLOW_IMPROVEMENT / REUSABLE / independent-review — a retained artifact that still carries a disproven
    claim needs an EXPLICIT WITHDRAWAL MARKER, because byte-identical retention — legitimate and desirable
    for diffability — silently resurrects the error for whichever file the next reader opens first.
    Retention is not neutral. Concretely: a correction that says "deleted from X" must re-read X before it
    says so, and if the file is deliberately retained, the sentence must read "superseded, not deleted"
    and a marker must sit at each site.
  - WORKFLOW_IMPROVEMENT / REUSABLE / independent-review — the four lapses this lane was caught on
    (`Host Btn L`'s align, the desktop TechnicalDetails' surface, the active nav label's weight, the
    deletion claim) were each a check the lane had ALREADY performed correctly elsewhere in the same
    document. Verification lapses where checking stops, not where knowledge is missing. Three operational
    rules, recorded in design-revision-3.md §12: (1) a comparison needs BOTH operands named before a
    conclusion; (2) re-read an artifact before claiming anything about it; (3) a finding is a set of
    claims — apply the ones that survive checking and say which you rejected.
  - WORKFLOW_IMPROVEMENT / REUSABLE / independent-review — routing is not a substitute for ownership. A
    lane-owned defect (the active nav label on boards the lane owns) folded into a design-system-owner
    notification misroutes it and asks the owner to fix something on a board they cannot edit. Before
    filing a notification, ask whether the board carrying the defect is in the lane's OWNED_PATHS.
  - WORKFLOW_IMPROVEMENT / REUSABLE / independent-review — an evidence file that publishes a count with no
    counting rule will eventually be caught by a reviewer who cannot reproduce it. Publish the rule beside
    every number, and when superseding an old figure, say why the old one differed. Three separate findings
    in two passes (H-R3, L-R4, M-N3) trace to this single omission.
  - AUTOMATION_OPPORTUNITY / REUSABLE / independent-review — every class of defect in this pass is
    mechanically detectable from the live design file plus source: (a) a text layer whose `align` disagrees
    with its primitive's behaviour; (b) a text layer whose weight disagrees with its named ShipItType token
    or its call-site expression; (c) a published count with no rule. A CI check over the Penpot file would
    have caught the 52 weight mismatches of revision 2 and the 0px-inset label of revision 3.

KNOWLEDGE_PERSISTED:
  - design-revision-3.md, design-revision-metadata-3.yaml, penpot-board-evidence.md (regenerated),
    correction-report-3.md — all inside OWNED_PATHS.
  - Withdrawal / supersession markers on six retained artifacts, at ten disproven-claim sites, plus two
    headers. All inside OWNED_PATHS.
  - The two M-N5 READ-BACK annotation groups in the live Penpot file, inside the lane's declared ownership.
  - Nothing written to docs/engineering/** outside this task directory, and nothing to .decisions/**.
  - WORKFLOW_IMPROVEMENT and AUTOMATION_OPPORTUNITY items are product-agnostic and exceed this lane's
    authority; reported, not persisted.

BLOCKERS:
  - N4 / G9 (design-system owner, Gate D4) — ShipItPalette still has no disabled container/label pair. The
    appearance the code actually paints is now derived, measured and on the boards as a provisional
    read-back; the TOKEN remains a palette decision and was NOT invented here. Design consequence stated in
    design-revision-3.md §5.
  - G12 / N9 (design-system owner, new) — the primary action's surface differs between the boards and the
    build on both platforms. Recorded with the surface named; not fixed, because fixing it means drawing
    the "What happens next" panel, which is G5/F1 and a UX decision.
  - G3 / N2 (design-system owner) — negative fails AA on dark (4.02:1 canvas / 3.68:1 card).
  - G1 / G10 (sibling lane) — the hostUnrecognised state machine, and the helper string with no producer.
  - G6 (implementation) — the false keychain claim on product_detail_page.dart:614 and the in-scope
    add_product_page sites; production source, PROHIBITED to this lane.
  - B2 / N1, B3, N5, N6, N8-withdrawn, N7-withdrawn — carried Level-1 notifications. B3 is already filed
    as Human Decision 27ea6536 and is NOT re-raised.
  - G11 (Manager, non-blocking) — the revision-1 mobile design review report was never persisted and
    LANES.md:224 asserts it exists. Correct the ledger. (No impact on this pass: the revision-2 report was
    found and read in full.)
  - G2 / D4 — the at-rest protection model for 'Art S'. The human's decision; the layer stays PENDING D4
    and is deliberately unresolved.
  - NOT blockers, reported: flutter analyze NOT_RUN (G8); no Flutter widget rendered; no Docker or Compose
    command run; the Penpot plugin tab suspended twice mid-pass and every timed-out write was re-read.

READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES
```

**What that `YES` does and does not mean.** It means the eleven findings are applied, read back from the
live file, and documented with the sources they rest on — including the places where I **rejected** a
dispatched correction rather than applying it. It is not a claim that every gate passed: `flutter analyze`
was not run, no Flutter widget was rendered, no Docker command was run, and the desktop boards were walked
only partially. Those are listed above as `NOT_RUN` and `PARTIAL`, not rounded into passes.

**I am not the reviewer and I do not approve this revision.**