# Penpot board evidence — `design-addproduct-mobile`

> **REGENERATED at revision 5** from the live Penpot file, not carried forward. Revision 1 published
> `42/42/34/34` layer counts, a bare `Register product` count of `1`, text-layer counts that were not
> reproducible, and §3/§5 text that predated the weight pass, the `Trust Host` token swap, the badge
> additions, the repository harmonisation and the 16 renames (finding M-N3). Every figure below was read
> back from the live file after the last edit. **Counting rules are stated beside every number** — the
> previous failure in this file was publishing a number with no rule (H-R3, L-R4, L-N4).
>
> **Revision 5 re-read the live file and corrected §5, §6 and §6.2, which were rev-2-era records of a
> rev-2-era string.** Attempts 1 and 2 of cycle 5 could not reach Penpot and therefore could not correct
> them; §6.2 below is the live read-back that supersedes them. Sections 1–4 and 6.1 are unchanged and
> remain current — verified, not assumed.

Page `d8ac01df-6646-81d2-8008-a366c09aa9d3` (`Page 1`). Current revision: **`design-revision-5.md`**.
Prior revision: `design-revision-3.md` (`REVISION_ID B5006A15-2DEE-47BE-BF2F-C44196B089E3`). Access: Penpot
plugin API, read + inspect + write to the four boards this lane owns, plus **PNG export**. **No other
board was edited, renamed, moved or deleted.**

---

## 1. Counting rules, stated once so every number below is reproducible

| Measure | Rule |
|---|---|
| **boards** | `page.root.children.filter(s => s.type === 'board').length` |
| **root children** | `page.root.children.length` — boards **plus** non-board root shapes |
| **top-level layers** | `board.children.length` — direct children only, **not** descendants |
| **text layers** | every shape with `type === 'text'` anywhere in the board's subtree, **including descendants** — which is why the five `Nav Label` layers and the `Nav Badge` numeral are all counted |
| **`Register product` — exact** | text layers whose `characters` **equals** `Register product` |
| **`Register product` — substring** | text layers whose `characters` **contains** `Register product`, case-sensitive |

**Superseded counts and why they were wrong:**

| Measure | Revision 1 published | Live | Why the published figure differed |
|---|---|---|---|
| top-level layers | `42 / 42 / 34 / 34` | **`44 / 44 / 36 / 36`** | predates the `Nav Badge Bg` + `Nav Badge` additions (+2 per board) |
| text layers | `24 / 24 / 19 / 19` (revision 2) | **`29 / 29 / 24 / 24`** | revision 2's figure excluded the five `Nav Label` layers while still counting the `Nav Badge` text layer — a rule that was never stated (L-N4) |
| `Register product` count | `1` (no rule) | **2 / 2 / 1 / 1** substring, **1 / 1 / 1 / 1** exact | revision 1 published a bare `1` matching neither rule; on the Unknown boards the substring also appears inside `Confirm the host above to enable Register product.` (H-R3) |

---

## 2. Page inventory

| | boards | root children | non-board root shapes |
|---|---|---|---|
| before this lane authored anything | 156 | 158 | 2 |
| after authoring (revision 1) | 160 | 162 | 2 (`Tab Group`, `Rectangle`) |
| **now (revision 3)** | **160** | **164** | **4** (`Tab Group`, `Rectangle`, and the two `M-N5 READ-BACK` groups) |

Board delta from authoring is exactly **+4**. **This pass created no board**; root children rose by 2
because of the two `M-N5 READ-BACK` annotation groups (§ 6). `Tab Group` and `Rectangle` pre-date this
lane and are untouched. **Stray or scratch shapes: none.**

---

## 3. The four boards this lane owns

| Board | id | x, y | w × h | Top-level layers | Text layers |
|---|---|---|---|---|---|
| `SM - Add Product - Unknown host - Light` | `6d055762-a70b-804c-8008-bf65ff750422` | 7550, 10750 | 390 × 844 | **44** | **29** |
| `SM - Add Product - Unknown host - Dark` | `6d055762-a70b-804c-8008-bf65e644269b` | 7550, 9800 | 390 × 844 | **44** | **29** |
| `SM - Add Product - Verified - Light` | `6d055762-a70b-804c-8008-bf660e124738` | 8000, 10750 | 390 × 844 | **36** | **24** |
| `SM - Add Product - Verified - Dark` | `6d055762-a70b-804c-8008-bf65f36b1c9a` | 8000, 9800 | 390 × 844 | **36** | **24** |

Placement mirrors the existing mobile convention (Dark row y=9800 above Light row y=10750) in the free
column east of `BPM · Product Detail Onboarding`, verified free before authoring by testing every candidate
origin against all 156 board bounding boxes. **Free space re-verified at revision 3**: the band
`y = 11600 … 11790` is empty across the whole page width (every board above ends at y=11594; every board
below starts at y=11800), which is where the M-N5 read-backs sit.

---

## 4. Typography and alignment, as the live file reads it

Identical on all four boards unless marked. Every value matches its production token.

| Layer | size / weight | token | citation |
|---|---|---|---|
| `Back` | 12 / **500** | back-link family | matches the `BPM` reference |
| `H1` | 20 / 600 | `pageTitleMobile` | `apps/control_plane/lib/core/design_tokens.dart:561` |
| `Status`, `F K 0/1/2`, `Art K`, `Trust K` | 9 / 600, ls 1.1, **Mono** | `microLabel` | `:368` |
| `Art T` | 13 / 600 | `sectionTitle` | `:352` |
| `Field Val 0/1/2` | 11 / 400 | `bodySmall` | `:386` |
| `Art L1`, `Art L2` | 11 / **500** | `link` | `:426` |
| `Disclose` | 10 / **500** | `linkMicro` | `:443` |
| `Art S`, `Key State`, `Trust Body`, `Trust Body 2`, `Trust Host`, `Submit Sub` | 10–11 / 400 | `monoMeta` family | — |
| `Trust Btn L` (Unknown pair) | 12 / 600, **`align: center`** | desktop `Host Btn L` = 12/600 Sans, `align: center` | verified this pass |
| `Submit L` | **11** / 600, `align: center` | `buttonLabelMobile` | `:508-514` |
| `Nav Badge` | 11 / **700**, **Mono** | `ShipItType.ref` + `w700` | `mobile_chrome.dart:280-284` |
| **`Nav Label 3` (active)** | 10 / **600** | `active ? w600 : w400` | **`mobile_chrome.dart:297`** ← corrected this pass |
| `Nav Label 0/1/2/4` (inactive) | 10 / 400 | same expression, inactive branch | — |

**Two alignment facts, both corrected at revision 3:**

| Layer | Was | Now | Evidence |
|---|---|---|---|
| `Trust Btn L` (Unknown pair) | `align: left`, box x=30 w=180, rendered width 79.266 → **0px glyph inset** (`Trust Btn` rect is also at x=30) | **`align: center`**, same box → **50.367px inset** | desktop `Host Btn L` is `align: center` on **both** `S · Add Product · Unknown host · Light/Dark`, same 180-wide box at x=254, rendered width 79.258 → 50.371px inset. This lane's own `Submit L` was already `center` (H-N1) |
| `Submit L` | already `center` | unchanged | revision 2's re-centring for the 13→11px change held |

---

## 5. Both-theme legibility

Each of the four boards and both `M-N5 READ-BACK` groups exported as PNG via `penpot_export_shape` and
inspected.

| Board / group | Export |
|---|---|
| `… Unknown host - Light` | `Trust this host` **centred** in its button; `Products` in the nav **bold**; `Register product` centred; no collision or wrap |
| `… Unknown host - Dark` | identical geometry, all tokens dark (`#4496FC` accent, `#E93E3A` state, `#1A1C1B` rail); `Trust this host` centred, `Products` bold |
| `… Verified - Light` | no trust panel, submit at y=510, helper y=552, disclose y=580; `Products` bold |
| `… Verified - Dark` | identical geometry, dark tokens; `Products` bold |
| `M-N5 READ-BACK … Light` | heading, derivation, measured line, `card` surface, `#E4E4E4` rect, centred `#999A9A` label — all sequential, no overlap |
| `M-N5 READ-BACK … Dark` | same, `#3F403F` rect and `#848482` label |

**One export-renderer artefact, recorded so a reviewer is not misled:** the PNG export renders these
8–9px **annotation** lines in a fallback face that is wider than IBM Plex Sans/Mono, so the heading
reflows to two lines and the 8px lines appear to touch the box edges. On canvas the geometry is correct:
`textBounds` widths are **292.5 / 352.9 / 311.8** px, all ≤ the 358px box, and the layer boxes are
sequential with no overlap (heading 11600–11622, derivation 11626–11655, measured 11659–11669, surface
11673–11721, rect 11680–11714, label 11690–11704). **Treated as an export artefact, not a canvas defect** —
but stated, because a reviewer will see the same thing.

Two layout defects were found on visual read-back at revision 1 and **fixed before completion**:

1. the first-draft key-meta string (`ed25519 · created server-side · private half never sent to the
   browser`) wrapped to two lines at 10px in a 220px box and collided with the `Key State` line —
   **shortened at revision 2 to `ed25519 · private half stays server-side`, which fit one line. That
   shortening is what revision 5 undoes**, for a reason that is not cosmetic: the string it produced is
   FALSE under `9417f8bf` (A3 — an external secret manager). "Private half stays server-side" asserts
   that SHIP IT holds the private half on its own server; under A3 SHIP IT **never holds key bytes at
   all** and asks the manager for the material at push time. Revision 5 restores the wrapping two-line
   form at full length — see §6.2. The collision is resolved by geometry, not by a shorter sentence;
2. the trust panel's second body line wrapped and collided with the host-fingerprint line — the panel was
   grown 150 → 160px and submit/helper/disclose shifted to y=678 / 720 / 748, still clear of the bottom
   nav at y=764. **Unchanged at revision 5** — the panel is still 160px at y=502 and the submit/helper/
   disclose chain is still 678 / 720 / 748, re-measured live.

---

## 6. Content audit

> Forbidden strings asserted absent across all four boards: `this device`, `keychain`, `browser storage`,
> `the vault`, `server-side`, `PENDING D4`, `PROVISIONAL`, `What you're registering`, `What happens next`,
> `Cancel`. Rule: a hit is any text layer whose `characters` contains the string, **or** any layer
> (including non-text) whose **name** contains `PENDING D4` or `PROVISIONAL`.
>
> **Revision 5 widened this rule.** The original six-string list could not see the rev-2 string's defect,
> because `server-side` is a substring of nothing the old list looked for, and because layer **names**
> were not audited at all. `PENDING D4` and `PROVISIONAL` are markers, not content: a board can pass a
> text audit while its layer names still advertise a discharged gate. Both are now in the rule.

| Board | forbidden hits | `Register product` exact | `Register product` substring | `Register` rect | helper fill |
|---|---|---|---|---|---|
| `… Unknown host - Dark` | **0** | **1** | **2** | 358×34 @ x=16 y=678, `#4496fc@1` | `#a8a6a0` (`inkSecondary`) |
| `… Verified - Dark` | **0** | **1** | **1** | 358×34 @ x=16 y=510, `#4496fc@1` | `#a8a6a0` (`inkSecondary`) |
| `… Unknown host - Light` | **0** | **1** | **2** | 358×34 @ x=16 y=678, `#1668d6@1` | `#5a5c5b` (`inkSecondary`) |
| `… Verified - Light` | **0** | **1** | **1** | 358×34 @ x=16 y=510, `#1668d6@1` | `#5a5c5b` (`inkSecondary`) |

The Unknown boards' substring count is **2** because the label also occurs inside
`Confirm the host above to enable Register product.` The Verified boards' helper reads
`Access verified — this product can be registered`, which does not contain the capitalised label, so their
count is 1 under both rules. **The `Register` rect is deliberately left unchanged at the enabled accent
fill** — it is the known-wrong expression for the Unknown-host state, and the M-N5 read-back below is the
correction of record rather than a substitution.

Key-meta line (all four boards): **`ed25519 · generated on the server · the private half stays in the
secret manager`** in `inkSecondary` (`#5a5c5b` light / `#a8a6a0` dark) — layer named **`Art S`**,
box `x=138 y=418 220×24`, laid out over two lines at 10/400 IBM Plex Sans, `lineHeight` 1.2, `align: left`,
`growType: fixed`. **Settled by `9417f8bf` (OPTION_C / A3), not pending anything** — this string is `N-9`'s
and is binding on this lane per the sibling's R.11g item 4. Verified on all four boards at revision 5 by a
second live read; see §6.2, including the correction to the width figure this sentence used to carry.

Key-state lines: `Host not recognised` in `#C22B28` light / `#E93E3A` dark (Unknown host);
`Verified · just now` in `#0E7A56` light / `#6FFFCE` dark (Verified).

Repository: `git@git.internal.acme.com:platform/teamhub.git` on **all four** boards, and `Art T` on the
Verified pair reads `Installed on platform/teamhub` — consistent with the field. The Unknown pair's
`Art T` reads `Generated for this product` and carries no path.

`Trust *` layers carrying `· PROVISIONAL (G1 hostUnrecognised)`: **0 / 0** on each Unknown board at
revision 5 (was 8 / 8). All sixteen suffixes retired, because `hostUnrecognised` is no longer a
provisional state — `898b07d0` (split identity from registration) and `ae1c1f79` (refusal creates
nothing) are both RESOLVED and together settle what this panel depicts. The eight layers are now named
`Trust Bg`, `Trust Edge`, `Trust Btn`, `Trust K`, `Trust Body`, `Trust Created`, `Trust Host`,
`Trust Btn L`. **`Trust Body 2` no longer exists** — its copy is replaced by `Trust Created` (§6.2).

### 6.1 The `M-N5 READ-BACK` annotation groups

| Group | id | x, y | w × h | children |
|---|---|---|---|---|
| `M-N5 READ-BACK · Register product DISABLED · Light · annotation, NOT screen content` | `6d055762-a70b-804c-8008-bf7d2cd65125` | 7550, 11600 | 358 × 121 | 6 |
| `M-N5 READ-BACK · Register product DISABLED · Dark · annotation, NOT screen content` | `6d055762-a70b-804c-8008-bf7d2ce38c50` | 7970, 11600 | 358 × 121 | 6 |

Each holds: theme heading (9/600 Mono), the mechanism line (8/400 Sans), the measured line (8/400 Sans), a
`palette.card`-coloured surface named `READ-BACK M-N5 surface · DesignPanel = palette.card`, the disabled
rect (358×34, r=3) and the centred 11/600 `Register product` label.

| | Light | Dark |
|---|---|---|
| disabled rect | `#E4E4E4` | `#3F403F` |
| disabled label | `#999A9A` | `#848482` |
| label on its own fill | 2.22:1 | 2.78:1 |

**Containment:** every shape lies inside `x 7550…7908`, `y 11600…11721`; lowest shape 11721, **79px clear**
of the nearest board below (y=11800); **zero bounding-box overlaps against all 160 boards.** They are
page-level groups, not children of the 390×844 screen boards, so no screen board's geometry or layer count
changed.

### 6.2 Revision 5 live read-back — every edit, read back from the file

Attempts 1 and 2 of cycle 5 returned `DESIGN_REVISION_BLOCKED` on Penpot unavailability and could not
re-read the boards, so §5 and §6 above carried the rev-2 string as though it were live. **It was not.**
This is the live read-back, taken after the last revision-5 write.

**Edits made, four boards each, all re-read:**

| Layer | Before (rev-2 era, as recorded in §5/§6) | After (live at revision 5) |
|---|---|---|
| `Art S` — `characters` | `ed25519 · private half stays server-side` (40 ch) | `ed25519 · generated on the server · the private half stays in the secret manager` (80 ch) |
| `Art S` — layer `name` | `Art S · PENDING D4 (at-rest model)` | `Art S` |
| `Art S` — box | `x=138 y=418 220×15`, 1 line | `x=138 y=418 220×24`, 2 lines |
| `Key State` — `parentY` | 436 | **446** (clears `Art S`'s new bottom at 442) |
| `Art L1` / `Art L2` — `parentY` | 456 | **466** (card bottom 486 → 4px slack) |
| `Art S` fill | `#5a5c5b` / `#a8a6a0` | **unchanged** — `inkSecondary`, so R5 compliance is preserved through the re-wrap |
| `Art Bg` (the card) | `16,370 358×116` | **unchanged** — deliberately not grown, so the card stays geometrically identical to `BPM`'s |

`Art S` font, weight, letterSpacing, lineHeight, `align` and `growType` are all **unchanged**
(`IBM Plex Sans` / 10 / 400 / 0 / 1.2 / `left` / `fixed`). Only `characters`, `name` and position moved.

> ⚠️ **CORRECTED AT REVISION 5, SECOND PASS — the width arithmetic below was internally inconsistent and
> the reviewer must not rely on the rendered-width figure.** The first pass asserted a measured
> **`textBounds` width of 214.53px** *and* a measured **4.46px/char** from the 40-char rev-2 string
> (178.44px). Those cannot both hold: at 4.46px/char the new 80-char string is ~**357px**, while 214.53px
> would fit inside the 220-wide box on **one** line and need no wrap at all.
>
> **The Penpot `textBounds` scale could not be reconciled, so it is not used as evidence here.** On a live
> read, `textBounds.x` tracked `2 × parentX` for every layer sampled (`parentX` 138 → `textLeft` 7826;
> `parentX` 244 → 8038; `parentX` 30 → 7610; all on a board whose absolute x is 7550), so absolute
> positions from `textBounds` are on an unstated 2× scale and **214.53 is of unknown units**.
>
> **What is stated instead, from `parentX`/`parentY`/`width`/`height`, which are unambiguous:** the string
> is 80 characters in a 220-wide box, it is set at 10/400 with `lineHeight` 1.2, and it is laid out over
> **two lines** — the layer's height is **24** where the single-line rev-2 string was **15**. The **two-line
> wrap is therefore an observed layout fact**, not an inference from a pixel measurement. Two rows below
> `Art S` were moved for that reason, and the 4px of slack at the card's bottom edge is preserved.
>
> **Not verifiable, and not claimed:** the exact rendered pixel width, and therefore whether 24 is the
> tightest correct height. Penpot exposes no version history and no layout engine diagnostics to this API.
> The geometry as built is internally consistent — 4px slack at the card bottom, zero shapes below the card
> edge — and that is the claim being made.

**H-1(c) edits, Unknown-host pair only:**

| Layer | Before | After |
|---|---|---|
| `Status` — `characters` | `NOT REGISTERED YET` | **`REGISTERED · NOT YET USABLE`** (width 150 → 240) |
| `Trust K` — `characters` | `CONFIRM THIS HOST BEFORE CONNECTING` | **`CONFIRM THIS HOST TO FINISH REGISTERING`** |
| `Trust Body 2` | `It pushes and merges on its own. Only promotion to production waits for you.` | **REMOVED** — the claim is false under `898b07d0`; a product with no committed credential cannot push or merge |
| `Trust Created` | — | **NEW**, `x=30 y=566 330×24`, 10/400, `#5a5c5b`/`#a8a6a0`: `This product is already in your list. It cannot push or merge until you finish registering.` |
| 8 × `Trust *` layer names | `… · PROVISIONAL (G1 hostUnrecognised)` | suffix stripped — **16 across the two Unknown boards; this cell published `7 ×` until revision 6 (MR5-1)** |

`Trust Created` occupies exactly the slot `Trust Body 2` held, so the trust panel's height (160px at
y=502), its contents' order and the whole submit/helper/disclose chain (678 / 720 / 748) are **unchanged**.
Verified: zero intra-panel overlaps **other than the button-rect-plus-label idiom** — `Trust Btn` (`30,618 180×30`) geometrically encloses `Trust Btn L` (`30,624 180×18`), and `Submit (label only — no nested subtext)` (`16,510` / `16,678`, 358×34) encloses `Submit L`; zero shapes outside the panel, and **zero collisions with the bottom
nav** on all four boards. **CORRECTED AT REVISION 6 (MR5-7):** the former wording, *"zero intra-panel overlaps"*, was not literally true of those two pairs. It is the same distinction this file already draws for the 1px `Art T`/`Art S` box overlap. The substantive claims are unaffected: `Trust Created` is contained, the chain geometry is unchanged, and there are zero nav collisions.

`Status` on the Verified pair was also re-grounded, `NOT REGISTERED YET` → **`REGISTERED · READY TO
REGISTER`**, because `898b07d0` makes the old eyebrow false there too: it creates the Product row with
state `registered` as its first step, so on *every* one of these boards a product row already exists.

**Counts after the edits — unchanged, and for a stated reason:**

| Measure | Rev 3 | Rev 5 | Why identical |
|---|---|---|---|
| top-level layers | 44 / 44 / 36 / 36 | **44 / 44 / 36 / 36** | `Trust Body 2` removed (−1) and `Trust Created` added (+1) on the Unknown pair only — nets zero |
| text layers | 29 / 29 / 24 / 24 | **29 / 29 / 24 / 24** | same netting |
| `Register product` exact / substring | 1 / 2, 1 / 2, 1 / 1, 1 / 1 | **unchanged** | no button copy touched |

Ordering in the table is Dark-Unknown / Dark-Verified / Light-Unknown / Light-Verified, as in §6.

**Content audit under the widened §6 rule: 0 hits on all four boards** — no text hit and no layer-name
hit for `this device`, `keychain`, `browser storage`, `the vault`, `server-side`, `PENDING D4`,
`PROVISIONAL`, `Cancel`, `What you're registering`, `What happens next`.

### 6.3 D-8 — `SM` and `BPM` are two **states** of one mobile design, not two designs

Attempt 2 named this the first question of the retry and could not answer it. **Answered by reading both
families live.** `27ea6536`'s mobile footer ruling is stated against `BPM · Add Product · Light/Dark`;
this lane owns `SM - Add Product - …`. The families are byte-for-byte the same grammar:

| Coordinate (relative to board) | `BPM` (both) | `SM` Verified (both) | `SM` Unknown (both) |
|---|---|---|---|
| `Art S` box | `138,418 220×15` | **`138,418 220×24`** | **`138,418 220×24`** |
| `Key State` box | **`138,436 220×15`** | **`138,446 220×15`** | **`138,446 220×15`** |
| `Submit L` box | `16,518` | `16,520` | `16,688` (+168 = the trust panel) |
| button helper | `16,552` | `16,552` | `16,720` |
| `Disclose` | **`16,580`, 220w** | **`16,580`, 220w** | **`16,748`**, 220w |
| divider between helper and `Disclose` | **none** | **none** | **none** |
| thin rules | `Top Rule 0,55` · `Rule 1 16,164` · `Nav Rule 0,764` | **identical** | **identical** |
| `Disclose` left edge vs content left edge | `16` vs `16` | **`16` vs `16`** | **`16` vs `16`** |

> ⚠️ **CORRECTED AT REVISION 5, SECOND PASS. Two rows of this table were published wrong on the first
> pass, and both were published as *measured*.** The first draft showed `Art S` as `138,418 220w` and
> `Key State` as `138,436` for **all three** columns, and asserted *"Every structural coordinate matches."*
> Re-read at `289f1d3`:
>
> * **`Key State` does not match.** `BPM` is at **436**; `SM` is at **446** on all four boards, because
>   revision 5 moved it from 436 to clear `Art S`'s new bottom at 442 (§6.2). The first draft's `138,436`
>   in the `SM` columns was the **pre-move** value — a stale number published as a live measurement, which is
>   precisely the M-1 defect class this revision exists to close.
> * **`Art S` no longer matches in height.** `SM` is **24** (two lines at the full `N-9` string); `BPM` is
>   **15** (one line, because `BPM` still carries the shorter, false keychain string). The first draft
>   published only `220w`, omitting the height, and then claimed every coordinate matched.
>
> **What still holds, and is what D-8 rests on:** every *structural* coordinate of the footer chain matches
> exactly (`Submit L`, helper, `Disclose`, its width, the absence of a divider, the three thin rules, and
> `Disclose`'s left edge against the content edge). The two rows that now differ are **content and
> wrap-dependent** rows — the state line's y follows the custody string's line count, which is a
> consequence of revision 5's own re-wrap, not a grammar difference. **The conclusion of D-8 is unchanged
> and does not depend on the two corrected rows.**

**The footer chain matches; the differences are state and wrap, not design:**

| | `BPM` | `SM` |
|---|---|---|
| `Key State` | `Not installed yet` | `Host not recognised` / `Verified · just now` |
| fields | placeholders (`e.g. TeamHub`) | filled values (`TeamHub`) |
| trust panel | absent | present on the Unknown pair |
| `Art S` string | `…stays in the keychain` | `…stays server-side` (rev 2) → **the N-9 string** (rev 5) |

**Consequences, and they are the reason this mattered:**

1. **The human's mobile footer spec — left-aligned, no divider, no copy — is ALREADY satisfied on all
   four `SM` boards, and `BPM` agrees with it.** H-1(b) required no mobile board edit. Measured, not
   assumed: `Disclose` at `parentX = 16`, zero divider rectangles between the helper and `Disclose`, and
   zero footer-copy text layers (`Registering records the product…` / `Your decision is recorded…`).
2. **The spec applies once, not twice.** No reconciliation across two board families is needed.
3. **`BPM` carries the SAME false custody claim** — `ed25519 · private half stays in the keychain`, false
   under A3 for the same reason, and identical to the build's `:542`/`:1038`. **`BPM` is not this lane's
   to edit** (read-only per the dispatch), so this is reported, not fixed: finding **F5**.
4. **`BPM` also carries the now-false `NOT REGISTERED YET` eyebrow**, like the `S` desktop boards. Same
   finding class; also not mine.

### 6.4 The desktop footer, read live — the `27ea6536` conformance check, and finding **F6**

Attempt 2 could not run this either. Read at revision 5, read-only, on all four `S · Add Product · …`
boards. All four are identical in the footer band:

| Layer | type | rel x, y | w × h | Content |
|---|---|---|---|---|
| `Footer Rule` | rectangle | **236, 848** | **1020 × 1** | the divider |
| **`Footer`** | **text** | **236, 862** | **1020 × 15** | **`align: left` — *"Your decision is recorded permanently. The same piece of work then continues — nothing is restarted."*** |
| `Disclose` | text | **1036, 862** | **220 × 15** | `Show technical details ▸` |

**Verdict against `27ea6536`'s desktop spec, one clause at a time:**

| `27ea6536` desktop clause | Measured | Verdict |
|---|---|---|
| a divider | `Footer Rule`, 236,848, 1020×1, all four boards | **SATISFIED** |
| a **right-aligned** `Show technical details` text button | `Disclose` at rel 1036 → right edge **1256** = `236 + 1020` = the content column's right edge | **SATISFIED** |
| **No footer copy** | a `Footer` **text** layer exists at rel 236,862 on **all four** boards | **NOT SATISFIED** |

**The mobile half of the same spec is satisfied on all four `SM` boards** (§6.3): `Disclose` left-aligned at
`parentX` 16, no divider, no footer copy.

**What this is, precisely.** It is **not** a re-opening of `27ea6536`, which is RESOLVED and whose normative
outcome this revision implements without question: the build is to carry no footer copy on either platform,
and `27ea6536`'s own implementer follow-up already says so. It is a **CONTRADICTION between the resolved
decision's normative outcome and the boards the decision itself declares authoritative** (*"Stay true to both
designs in Penpot and in code"*). The four desktop boards cannot satisfy the spec they are the authority for.
`27ea6536`'s OPTION_B anticipated exactly this cost: *"Requires `note: null` … **and editing the four
existing desktop boards, which no current lane owns** — so it needs a design-system-owner board edit."*

**Two further facts recorded so the next lane does not repeat this measurement incorrectly:**

1. `27ea6536`'s `supersedes_design_lane_reading` calls this lane's coordinate reading of a `Footer` layer
   at (236,862) *"a misidentification"*. **It is not.** The layer exists, at those coordinates, on all four
   boards. The divider is at (236,**848**), not (236,862). What the decision overrules is the lane's
   *conclusion*, not the lane's *observation* — and this revision reinstates the observation as measured
   while leaving the decision's outcome untouched.
2. `27ea6536`'s context asserts *"`_MobileAddProduct` renders no footer copy whatsoever"* and the sibling's
   pre-revision-5 item 7 asserted mobile's `TechnicalDetails` *"has no `note:`"*. Both are **false against
   source at `289f1d3`** — mobile carries `note:` at `add_product_page.dart:926-928` with the same string as
   desktop's `:317-319`. The sibling has since corrected this itself (§ R.11g item 7, its L8). Recorded here
   because this lane's own artifact set repeated the false claim before revision 5. See finding **D-3**.

---

## 7. No pre-existing board was modified

Re-read at the end of this pass, by direct `page.root.children` lookup. **Re-verified at revision 5** —
all six names intact, all six positions intact, all six child counts identical to the values below:

| Board | id | position | name | children |
|---|---|---|---|---|
| `BPM · Add Product · Light` | `b5b63334-…9ad42be419b` | (5280, 10750) unchanged | unchanged | **36** |
| `BPM · Add Product · Dark` | `b5b63334-…9ac5f5ad2dc` | (5280, 9800) unchanged | unchanged | **36** |
| `S · Add Product · Unknown host · Light` | `b5b63334-…9a96fc40fa5` | (10400, 11800) unchanged | unchanged | **69** |
| `S · Add Product · Unknown host · Dark` | — | (10400, 12750) unchanged | unchanged | **69** |
| `S · Add Product · Verified · Light` | `b5b63334-…9a979cd8fbc` | (11700, 11800) unchanged | unchanged | **65** |
| `S · Add Product · Verified · Dark` | — | (11700, 12750) unchanged | unchanged | **65** |

The bottom-nav board on each new board is a `clone()` of the corresponding existing nav board and was
retinted **on the clone only**; the source boards' child counts above are unchanged, which confirms it.

Scratch boards created by two failed API calls at revision 1 (an unnamed board, then a partial 3-layer
board) were detected by inventory diff and **removed**; the count returned to 156 before the successful
build. `strays` is `[]`.

**Operations log for this pass** — recorded because two of them failed and a failed write that is assumed
rather than re-read is how a stray ships:

| Operation | Outcome |
|---|---|
| `Trust Btn L` `align` → `center`, 2 boards | applied; the call **timed out** and was re-read and confirmed |
| `Nav Label 3` `fontWeight` → `600`, 4 boards | applied; same call, re-read and confirmed |
| first `M-N5` create attempt | **FAILED** — `Value not valid. Code: :createText`. Left nothing behind (`found: []`, root children still 162). Narrowed by probing `createText` against every character class and length used; all passed, so the failure was a transient plugin error, not the content |
| duplicate Light heading + a 54px surface from a partial retune | **detected on read-back** (13 shapes where 12 were intended), duplicate removed and both surfaces normalised to 48px |
| `penpotUtils.ungroup` | **not a function** in this API surface — groups were dissolved by removing their descendants then the shell, verified back to 162 |
| Penpot plugin tab | **suspended twice** mid-pass (no heartbeat). Woken each time; every timed-out write re-read from the live file rather than assumed. Final read-back is this document |

---

## 8. Naming-convention conflict (unresolved — see `design-revision.md` § 1, notification N1)

The page's actual convention is `·` (U+00B7) with `S ·` for state boards:

```
BPM · Add Product · Light
S · Add Product · Unknown host · Light
```

The four boards were named **exactly as the dispatch specified** (`SM - …`, hyphen-separated) because the
acceptance criterion requires those names and a rename is trivially reversible. This leaves the page with
two naming conventions. **Needs a design-system-owner decision at Gate D4 — it is not mine to settle, and
it is not re-raised here.**

---

## 9. What this file does **not** evidence

- **`flutter analyze` — NOT_RUN.** Requires `flutter pub get`, which writes outside this lane's
  read-only scope; `apps/control_plane/.dart_tool/` does not exist at this HEAD. No claim is made about
  the analyzer's output, and `implementation_feasibility` is not derived from it.
- **No Flutter widget was rendered.** The disabled-state colours in § 6.1 are a documented derivation from
  the Flutter 3.44.7 framework source plus `core/theme.dart` — see `design-revision-3.md` §5.1 for the
  file-and-line chain and assumption A6. They are **not** screenshots of a running app.
- **No automated pixel diff against the reference boards.** No such tooling exists here. All geometry
  comparison used layer name, position, size and `textBounds` — **not pixels**.
- **No Docker or Compose command was run** at any point in this lane, including read-only ones.
- **Full content inspection of the four desktop `S · Add Product · …` boards: PARTIAL** — identity,
  position and the `Host Btn` / `Host Btn L` / `R Submit L` layers were read (which is what H-N1 required),
  but not every layer was walked.