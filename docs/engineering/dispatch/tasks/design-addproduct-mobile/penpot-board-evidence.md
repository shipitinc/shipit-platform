# Penpot board evidence — `design-addproduct-mobile`

> **REGENERATED at revision 3** from the live Penpot file, not carried forward. Revision 1 published
> `42/42/34/34` layer counts, a bare `Register product` count of `1`, text-layer counts that were not
> reproducible, and §3/§5 text that predated the weight pass, the `Trust Host` token swap, the badge
> additions, the repository harmonisation and the 16 renames (finding M-N3). Every figure below was read
> back from the live file after the last edit. **Counting rules are stated beside every number** — the
> previous failure in this file was publishing a number with no rule (H-R3, L-R4, L-N4).

Page `d8ac01df-6646-81d2-8008-a366c09aa9d3` (`Page 1`). Current revision: **`design-revision-3.md`**
(`REVISION_ID B5006A15-2DEE-47BE-BF2F-C44196B089E3`). Access: Penpot plugin API, read + inspect + write to
the four boards this lane owns, plus **PNG export**. **No other board was edited, renamed, moved or deleted.**

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
   shortened to `ed25519 · private half stays server-side`, which fits one line and still satisfies
   `b869ec24` (states the private half is server-side, claims no at-rest property);
2. the trust panel's second body line wrapped and collided with the host-fingerprint line — the panel was
   grown 150 → 160px and submit/helper/disclose shifted to y=678 / 720 / 748, still clear of the bottom
   nav at y=764.

---

## 6. Content audit

> Forbidden strings asserted absent across all four boards: `this device`, `keychain`, `browser storage`,
> `What you're registering`, `What happens next`, `Cancel`. Rule: a hit is any text layer whose
> `characters` contains the string.

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

Key-meta line (all four boards): `ed25519 · private half stays server-side` in `inkSecondary`
(`#5a5c5b` / `#a8a6a0`) — layer named `Art S · PENDING D4 (at-rest model)`, **unresolved by design** (the
at-rest protection model is the human's decision, G2/D4).

Key-state lines: `Host not recognised` in `#C22B28` light / `#E93E3A` dark (Unknown host);
`Verified · just now` in `#0E7A56` light / `#6FFFCE` dark (Verified).

Repository: `git@git.internal.acme.com:platform/teamhub.git` on **all four** boards, and `Art T` on the
Verified pair reads `Installed on platform/teamhub` — consistent with the field. The Unknown pair's
`Art T` reads `Generated for this product` and carries no path.

`Trust *` layers carrying `· PROVISIONAL (G1 hostUnrecognised)`: **8 / 8** on each Unknown board
(`Trust Bg`, `Trust Edge`, `Trust Btn` rectangles + `Trust K`, `Trust Body`, `Trust Body 2`,
`Trust Host`, `Trust Btn L` text).

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

---

## 7. No pre-existing board was modified

Re-read at the end of this pass, by direct `page.root.children` lookup:

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