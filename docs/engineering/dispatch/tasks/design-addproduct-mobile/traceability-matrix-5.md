# Traceability matrix — Design Revision 5

`design-addproduct-mobile` · `REVISION_ID CB4BEECA-CA9D-4F26-9464-E1B6F7C9BDCB` · base `289f1d3` ·
board evidence `penpot-board-evidence.md` §6.2 / §6.3 / §6.4.

**Reading rule.** Every board row was read back from the live Penpot file at the state named in the column;
nothing in this matrix is inherited from a prior revision's claim. Every source citation was re-read at
`289f1d3`, and `git diff --name-only 43d328b 289f1d3 -- apps/control_plane packages` returns **empty**, so
all `:NNN` values into `apps/control_plane/**` hold.

---

## 1. Board element → token / primitive → requirement → verification

The four `SM` boards, 390×844. Token values re-read from `apps/control_plane/lib/core/design_tokens.dart:92-123`.

| Layer | Board geometry (`parentX`,`parentY`,`w`×`h`) | Fill light / dark | Token / primitive | Req | Verification |
|---|---|---|---|---|---|
| `Top Bg` | 0,0 390×56 | `#f7f7f5` / `#1f2120` | `canvas` | R1 | live read |
| `Top Rule` | 0,55 390×1 | rule | `Top Rule` idiom | R1 | live read |
| `Back` | 16,20 200×18 | `inkSecondary` | back-link family | R1 | live read |
| `H1` | 16,72 340×56 | `inkPrimary` | `pageTitleMobile` (`design_tokens.dart:561`) | R1 | live read |
| `St Tick` | 16,138 2×11 | state | status tick idiom | R1 | live read |
| **`Status`** | 26,137 240×14 | `#6e706e` / `#8a8983` | **`inkTertiary`** | **R1, H-1(c)** | live read; **rewritten by this revision** |
| `Rule 1` | 16,164 358×1 | rule | content divider | R1 | live read |
| `F K 0/1/2` | 16,{178,242,306} | `inkTertiary` | `microLabel` (`:368`) | **R4** | live read; **no `(OPTIONAL)` suffix — all three required** |
| `Field Box 0/1/2` | 16,{194,258,322} 358×34 | `canvas`/`card` | `formBoxDecoration` + `SingleLineInput` | R4 | live read |
| `Field Val 0/1/2` | 28,{202,266,330} | `inkPrimary` | `bodySmall` (`:386`) | R4 | live read |
| `Art Bg` | 16,370 358×116 | `#ffffff` / `#262827` | **`card`** = `DesignPanel` (`design_primitives.dart:318-320`) | R1, M-R1 | live read; **not grown by this revision** |
| `Art Edge` | 16,370 2×116 | accent | panel edge idiom | R1 | live read |
| `Art K` | 30,382 300×14 | `#6e706e` / `#8a8983` | **`inkTertiary` on `card` → 4.99 / 4.23 FAIL in dark** | R5 | live read; **known FAIL, N10, design-system-owned, untouched** |
| `Thumb`, `Thumb B*`, `Thumb Blk` | 30,402 … | `canvas` | key preview idiom | R1 | live read |
| `Art T` | 138,400 220×19 | `inkPrimary` | `sectionTitle` (`:352`) | R1 | live read; box bottom 419 vs `Art S` top 418 — 1px box overlap, **pre-existing**, rendered rows clear |
| **`Art S`** | 138,418 **220×24** | `#5a5c5b` / `#a8a6a0` | **`inkSecondary`** → 6.74 / 6.10 PASS | **R5, H-1(a)** | live read; **rewritten + re-wrapped by this revision** |
| `Key State` | 138,**446** 220×15 | `#c22b28`/`#e93e3a`; `#0e7a56`/`#6fffce` | state colour | R6 | live read; **moved by this revision** |
| `Art L1 · Copy key` | 138,**466** 96×16 | `inkSecondary` | `link` (`:426`) | R6 | live read; **moved by this revision** |
| `Art L2 · Check access` | 244,**466** 116×16 | `inkSecondary` | `link` (`:426`) | **R6, 2c** | live read; label reads `Check access` (Unknown pair) / `Check again` (Verified pair) |
| `Trust Bg` | 16,502 358×160 | `#ffffff` / `#262827` | `card` | H-1(c) | live read; **unchanged** |
| `Trust Edge` | 16,502 2×160 | accent | panel edge idiom | H-1(c) | live read |
| **`Trust K`** | 30,514 320×14 | `inkSecondary` | `microLabel` | **H-1(c)** | live read; **rewritten by this revision** |
| **`Trust Body`** | 30,532 330×27 | `inkSecondary` → 6.74 / 6.10 | `bodySmall` | H-1(c) | live read; **unchanged** |
| **`Trust Created`** | 30,**566** 330×24 | `inkSecondary` → 6.74 / 6.10 | `monoMeta` family | **H-1(c)** | live read; **NEW in this revision**; contained in `Trust Bg`; 0 nav collisions |
| ~~`Trust Body 2`~~ | — | — | — | **H-1(c)** | **REMOVED by this revision** — its claim was false under `898b07d0` |
| `Trust Host` | 30,596 330×15 | `inkSecondary` | `monoMeta` | R6 | live read; `git.internal.acme.com · ed25519 · SHA256:+DiY…` |
| `Trust Btn` | 30,618 180×30 | `#1668d6` / `#4496fc` | `accent` | 2d | live read |
| `Trust Btn L` | 30,624 180×18 | `#ffffff` / `#06121f` → 5.27 / 6.30 | `buttonLabelMobile` (`:508-514`) | 2d | live read; `align: center` |
| `Submit` rect | 16,**510** Verified / **678** Unknown | `#1668d6`/`#4496fc` | `MobilePrimaryButton` 358×34 | **R2, 2e** | live read; **deliberately left at the enabled accent** — M-N5 read-back below is the correction of record |
| `Submit L` | 16,**520** / **688** 358×19 | on accent | `buttonLabelMobile` | **R2, 2e** | live read; **`Register product` only** |
| `Submit Sub` helper | 16,**552** / **720** 358×15 | `#5a5c5b` / `#a8a6a0` | `monoMeta` | **R2, 2e** | live read; **BELOW the button**; Unknown reads *"Confirm the host above to enable Register product."*, Verified reads *"Access verified — this product can be registered"* |
| **`Disclose`** | 16,**580** / **748** 220×15 | `inkSecondary` | `linkMicro` (`:443`) | **R3, H-1(b)** | live read; **left-aligned at 16 = content left edge; ZERO dividers above it; ZERO footer-copy layers** |
| `Bottom Nav` | 0,764 390×80 | `rail` | `MobileBottomNav` | R1 | live read; cloned + retinted on the clone only |
| `Nav Badge Bg` / `Nav Badge` | 206,772 | accent | `mobile_chrome.dart:280-284` | R1 | live read |
| `Nav Label 3` | active | — | `mobile_chrome.dart:297` (`active ? w600 : w400`) | R1 | live read |

---

## 2. Requirement → disposition

### Cycle-1 requirements R1–R7

| Req | Requirement | Disposition | Evidence |
|---|---|---|---|
| **R1** | four boards at 390×844, both themes, readable | **MET** | 4 boards, exact names, exact ids, 390×844; §1 above is the live read of all four; layer counts 44/44/36/36 top-level, 29/29/24/24 text, with the counting rules published (`penpot-board-evidence.md` §1) |
| **R2** | `Register product` only in the button; helper **below**; one structure both platforms | **MET** | `Submit L` characters **equal** `Register product` (count 1 exact per board); helper is a sibling below at y+42; desktop gap stated in rev 1 §2a and withdrawn per §M-1 |
| **R3** | footer: copy line + exactly one `Show technical details` row, framed as a restoration | **SUPERSEDED and specified by `27ea6536`** | mobile: one `Disclose` row, left-aligned, no divider, **no copy**; desktop: divider + right-aligned, no copy. Restoration, not de-duplication — `Show technical details` was absent from the build entirely |
| **R4** | re-ground the required-field convention on the existing `(OPTIONAL)` suffix | **MET** | all three Add Product fields carry **no** suffix ⇒ required; `create_defect_page.dart:458,477,495,504` is the convention in production use. The 15-site coverage beyond Add Product remains the sibling's/owner's scope and is **not** claimed here |
| **R5** | `inkSecondary`, cited ratios, no unmeasured contrast claim | **MET** | `inkSecondary`/`card` **6.74 light / 6.10 dark**, recomputed and sanity-checked; `Art S` and `Trust Created` both use it. The known `inkTertiary`-on-`card` **4.99 / 4.23 FAIL** is stated, not hidden (N10) |
| **R6** | visual consequence of 2a/2b; `Check access` labelled | **MET, with a named boundary** | `Art S`, `Key State`, `Art L1`/`Art L2` present and labelled on all four boards. The *normative* meaning of "Check access" and the `hostUnrecognised` machine remain the sibling's (`design-revision-5.md` § R.11). No backend semantics invented |
| **R7** | traceability + risk + honest self-assessment | **MET** | this matrix; `risk_level: 3` re-derived; `PARTIAL`/`PASS`/`MEDIUM` each with a stated reason, including `UNKNOWN`-class limits written as NOT_RUN |

### Cycle-5 findings

| Finding | Requirement | Disposition | Evidence |
|---|---|---|---|
| **H-1(a)** | custody string corrected on four boards and ~30 record sites | **MET** | live read-back, all four boards; zero `PENDING D4`/`PROVISIONAL` names; sweep across brief/rev 2/3/4/evidence/headers |
| **H-1(b)** | human's normative footer alignment, **both** platforms | **MET on mobile** (already conformant, measured) · **GAP on desktop boards → F6** | `penpot-board-evidence.md` §6.3 (mobile) and §6.4 (desktop, all four `S` boards) |
| **H-1(c)** | Unknown-host re-grounded on `898b07d0` + `ae1c1f79`, with a genuine **user-facing** element | **MET** | `Status`, `Trust K`, `Trust Created` (new), `Trust Body 2` removed, 17 suffixes retired; Verified eyebrow also re-grounded; compliance with R.11g item 5 stated in rev 5 §5.3 |
| **M-1** | cross-references corrected by re-reading | **MET** | rev 5 §8 — 13 numbers, each re-read after the edits |
| **L-1** | three missing pointers | **MET** | rev 5 §9 — `design-revision-3.md:583` (G2), `:592` (G11), `:452-486` (B3 + G2, one block). Re-measured after this pass's own edit to rev 3 |

### `9417f8bf` follow-ups owned by `design-agent`

| Follow-up | Requirement | Disposition | Evidence |
|---|---|---|---|
| G-7 — remove `referenceName` or replace with a non-identifying handle | **REQUIRED** | **SPECIFIED**, not implemented — `packages/**` and `apps/server/**` are not `OWNED_PATHS` | 6 sites measured, incl. **2 UI render sites** (`product_detail_page.dart:471`, `:676`) — the reason it is security-relevant, not cosmetic |
| A3 unavailability path with concrete remediation copy | **REQUIRED** | **SPECIFIED**, not rendered — needs boards outside `OWNED_PATHS` | four causes × Title/Body/Action consumed from `7b1bc8b7` + sibling § R.5.4 verbatim; board spec in rev 5 §6.2; contrast 6.28/6.65 on `canvas`, 6.74/6.10 on `card`, PASS both themes |

---

## 3. Decision → what it changed here

| Decision | Selected | Where it lands in this revision |
|---|---|---|
| `9417f8bf` | OPTION_C — A3 | §3 (custody string), §6.1 (G-7), §6.2 (unavailability path) |
| `27ea6536` | OPTION_A — copy removed both platforms, per-platform alignment **new** | §4.1 (governing spec), §4.2 (build change), §4.3 (D-2), §4.4 (F6) |
| `898b07d0` | OPTION_A — split identity | §5.1 (step order + copy), §5.2 (the user-facing element), §4.5 (R.11g item 3) |
| `ae1c1f79` | OPTION_A — refusal creates nothing | §5.3 (Unknown-host must not imply a refused mint created a product), §6.2 (separate surface) |
| `7b1bc8b7` | OPTION_A — fail closed with remediation | §6.2 (remediation copy is a required deliverable) |
| `b869ec24` | OPTION_A — server-side custody | superseded as the *governing* constraint on the copy by `9417f8bf`; recorded in `design-brief.md` |

---

## 4. Gaps, reported not narrowed

| Id | Gap | Class | Owner |
|---|---|---|---|
| **F6** | four desktop `S` boards carry footer copy; they do not satisfy `27ea6536`'s desktop clause, and they are the decision's own declared authority | `CONTRADICTION` | **Manager — ownership (N6b)**. Outcome settled; only the board edit is unowned |
| **G14 / SC-9** | the A3 refused-mint surface needs two boards; R.11g item 5 forbids folding it onto the Unknown-host board | ownership | **Manager — ownership (N6c)** |
| **G13** | R.11g item 3's resume affordance on `ProductDetailPage` specified, not rendered | ownership | **Manager — ownership (N6c)** |
| **D-4** | build `:542` **and** `:1038` carry `created on this device · the private half stays in the keychain` — two false halves | production | keys lane / implementer |
| **F5** | `BPM · Add Product · Light/Dark` carry the same false custody string and the now-false eyebrow | ownership | Manager (read-only boards) |
| **D-5** | `N-9`'s "name no substrate" rule contradicts its own prescribed string | `CONTRADICTION` | keys lane — flagged, **not** silently resolved; the prescribed string was adopted verbatim as a binding item |
| **D-3** | "no footer copy" is two `note:` sites plus `_buildFooter`; this lane's own records repeated the false claim | `CONTRADICTION` | corrected here; the sibling has corrected it in its own revision 5 |
| **G3 / G4 / G9 / G12** | `negative` on dark fails AA; `TechnicalDetails`' `ContentRule`; no disabled-primary token; primary action's surface | design-system | N2 / **N6** / N4 / N9 |
| **F8** | `design-revision-metadata-4.yaml`'s first fenced YAML block **does not parse** (a `-` list item with a `“: ”` continuation). **Pre-existing** — confirmed by parsing the committed blob, which fails identically | hygiene | reported, **not** fixed: unrelated to this revision's findings; repairing it here would be scope creep. Rev 5's own metadata: 7/7 fenced blocks parse |
| **G8** | `flutter analyze` NOT_RUN | verification | QA |

---

## 5. Claims this matrix does **not** make

- **`flutter analyze` was NOT_RUN.** No score here derives from the analyzer.
- **No pixel comparison.** All geometry is layer name, `parentX`/`parentY`, `width`, `height` and containment.
- **Penpot `textBounds` is not used as evidence.** Its scale could not be reconciled against `parentX`
  (it tracked 2×), so the previously published 214.53px figure is withdrawn (§3.2 of the revision).
- **Pre-edit board state is not recoverable** — the API exposes no version history. Every "before" is a
  recorded rev-2-era value.
- **No screen-reader or focus-order verification** for the new `Trust Created` element; contrast only.
- **The four desktop `S` boards were read in the footer band in full**, not walked end to end.
- **Nothing outside `OWNED_PATHS` was written**: no production source, no `.decisions/**`, no `WORK_STATE.md`,
  no `LANES.md`, no keys-lane artifact, no `docs/adr/**`, no BPM/S board.
- **No Docker or Compose command was issued at any point, including read-only ones.**