# Penpot board evidence — `design-addproduct-mobile`

Page `d8ac01df-6646-81d2-8008-a366c09aa9d3` (`Page 1`). All four boards at **390x844**.
Every figure below was read back from the live Penpot file via the Penpot plugin API, not asserted.

## 1. Before / after inventory

`page.root.children.filter(s => s.type === 'board')`

| | boards | root children |
|---|---|---|
| before authoring | **156** | 158 |
| after authoring | **160** | 162 |

Delta is exactly +4. `smBoards` before: `[]` — confirming no `SM -` board existed at any state or theme.

## 2. The four boards

| Board | id | x, y | w × h | top-level layers | children walked |
|---|---|---|---|---|---|
| `SM - Add Product - Unknown host - Light` | `6d055762-a70b-804c-8008-bf65ff750422` | 7550, 10750 | 390 × 844 | 42 | incl. bottom-nav board |
| `SM - Add Product - Unknown host - Dark` | `6d055762-a70b-804c-8008-bf65e644269b` | 7550, 9800 | 390 × 844 | 42 | " |
| `SM - Add Product - Verified - Light` | `6d055762-a70b-804c-8008-bf660e124738` | 8000, 10750 | 390 × 844 | 34 | " |
| `SM - Add Product - Verified - Dark` | `6d055762-a70b-804c-8008-bf65f36b1c9a` | 8000, 9800 | 390 × 844 | 34 | " |

Placement mirrors the existing mobile convention (Dark row y=9800 above Light row y=10750), in the
free column east of `BPM · Product Detail Onboarding` — verified free before authoring by testing every
candidate origin against all 156 board bounding boxes.

## 3. Both-theme legibility

Each board exported as PNG via `penpot_export_shape` and inspected:

| Board | Export |
|---|---|
| `… Unknown host - Light` | read back: 34px field boxes, trust panel, 2-line body, no collision |
| `… Unknown host - Dark` | read back: identical geometry, all tokens dark (`#4496FC` accent, `#6FFFCE`/`#E93E3A` state, `#1A1C1B` top bar) |
| `… Verified - Light` | read back: no trust panel, submit at y=510, helper y=552, disclose y=580 |
| `… Verified - Dark` | read back: identical geometry, dark tokens |

Two layout defects were found on visual read-back and **fixed before completion**:

1. the first-draft key-meta string (`ed25519 · created server-side · private half never sent to the
   browser`) wrapped to two lines at 10px in a 220px box and collided with the `Key State` line —
   shortened to `ed25519 · private half stays server-side`, which fits one line and still satisfies
   `b869ec24` (states the private half is server-side, claims no at-rest property);
2. the trust panel's second body line wrapped and collided with the host-fingerprint line — the panel was
   grown 150 → 160px and submit/helper/disclose shifted to y=678 / 720 / 748, still clear of the
   bottom nav at y=764.

## 4. Content audit (executable, re-runnable)

Forbidden strings asserted absent across all four boards:
`this device`, `keychain`, `browser storage`, `What you're registering`, `What happens next`, `Cancel`.

| Board | forbidden hits | `Show technical details` count | `Register product` count | helper fill |
|---|---|---|---|---|
| `… Unknown host - Dark` | **0** | 1 | 1 | `#a8a6a0` (`inkSecondary`) |
| `… Verified - Dark` | **0** | 1 | 1 | `#a8a6a0` (`inkSecondary`) |
| `… Unknown host - Light` | **0** | 1 | 1 | `#5a5c5b` (`inkSecondary`) |
| `… Verified - Light` | **0** | 1 | 1 | `#5a5c5b` (`inkSecondary`) |

Key-meta line (all four boards): `ed25519 · private half stays server-side` in `inkSecondary`
(`#5a5c5b` / `#a8a6a0`) — layer named `Art S · PENDING D4 (at-rest model)`.

Key-state lines: `Host not recognised` in `#C22B28` light / `#E93E3A` dark (Unknown host);
`Verified · just now` in `#0E7A56` light / `#6FFFCE` dark (Verified).

## 5. No pre-existing board was modified

Re-read after authoring:

| Board | id | position unchanged | name unchanged | children |
|---|---|---|---|---|
| `BPM · Add Product · Light` (grammar reference) | `b5b63334-…9ad42be419b` | yes (5280, 10750) | yes | 36 |
| `BPM · Add Product · Dark` | `b5b63334-…9ac5f5ad2dc` | yes (5280, 9800) | yes | 36 |
| `S · Add Product · Unknown host · Light` | `b5b63334-…9a96fc40fa5` | yes (10400, 11800) | yes | 69 |
| `S · Add Product · Verified · Light` | `b5b63334-…9a979cd8fbc` | yes (11700, 11800) | yes | 65 |

The bottom-nav board on each new board is a `clone()` of the corresponding existing nav board and was
retinted **on the clone only**; the source boards' child counts above are unchanged, which confirms it.

Scratch boards created by two failed API calls (an unnamed board, then a partial 3-layer board) were
detected by inventory diff and **removed**; the count returned to 156 before the successful build, and
`strayBoards` is now `[]`.

## 6. Naming-convention conflict (unresolved — see `design-revision.md` § 1)

The page's actual convention is `·` (U+00B7) with `S ·` for state boards:

```
BPM · Add Product · Light
S · Add Product · Unknown host · Light
```

The four boards were named **exactly as the dispatch specified** (`SM - …`, hyphen-separated) because the
acceptance criterion requires those names and a rename is trivially reversible. This leaves the page with
two naming conventions. Needs a design-system-owner decision at Gate D4 — it is not mine to settle.