# Report — design-correct-f5-bpm-stack (Art L1/L2 456→466 on both BPM boards; the predicted `Submit L` collision did NOT occur)

```
RESULT: DESIGN_REVISION_COMPLETE
TASK_ID: design-correct-f5-bpm-stack
TASK_TYPE: design-produce
FEATURE: Add Product — F5 geometry correction: match BPM's `Art L1`/`Art L2` stack to the approved SM reference
AREA: Penpot — 2 BPM board layouts, 2 layers each (4 geometry writes total)
WORKTREE: /Users/alkebut/air/shipit-platform  (canonical checkout; Penpot is a live shared file)
BRANCH: main
BASE_SHA: b0d645687817ef4aa96ceb1933979b5a86fb320a
HEAD_SHA: b0d645687817ef4aa96ceb1933979b5a86fb320a
COMMITTED: NO
```

**The grant is complete and the acceptance figure is met on both boards.** All four moves landed, both
boards now match the approved `SM` reference exactly on every measured gap, and the `Key State` ↔
`Art L1`/`Art L2` overlap the prior pass introduced is cleared to SM's own +7.

**One dispatch prediction did not survive measurement, and it is reported rather than smoothed over:**
the dispatch said to assume this move would knock `Submit L` at 518 into a collision, as the previous
move did. **It does not.** `Submit L` ends **+38px clear** of `Art L1`/`Art L2` on both boards, measured
from settled `textBounds`. Nothing was fixed there because nothing is broken there. §5 states the
measurement and the arithmetic that explains why this move behaves differently from the previous one.

---

## 1. Provenance

`main` at `b0d645687817ef4aa96ceb1933979b5a86fb320a` — **identical** to the `BASE_SHA`/`HEAD_SHA`
recorded by the prior lane (`design-correct-f5-pass2`). No commit, no push, no source change.

**No Docker or Compose command was issued — not `info`, not `ps`, not `logs`, not `config`, not any
mutating one.** I ran no Docker command of any kind. No production source written. Nothing touched
outside `OWNED_PATHS` except the four granted Penpot geometry values.

## 2. Page baseline — my own enumeration, ids verbatim, never reconstructed

`penpotUtils.getPages()` → exactly one page, `Page 1` (`d8ac01df-6646-81d2-8008-a366c09aa9d3`).
**164 root children, 160 boards, 12 `Add Product` boards** — matches the prior lane's baseline exactly.

Every board id below was taken from my own root-children read and matched by **exact full id AND
asserted exact board name** before any write. The id-substring trap the dispatch names is **real and
present on this page**: `…a9a03d9da341` (`S · Add Product · Unknown host · Dark`) is a substring of
`…a9ac5f5ad2dc` (`BPM · Add Product · Dark`). Both dispatch ids verified correct:

| dispatch id | resolved name | children |
|---|---|---|
| `b5b63334-c22a-80a6-8008-a9ad42be419b` | `BPM · Add Product · Light` | 36 |
| `b5b63334-c22a-80a6-8008-a9ac5f5ad2dc` | `BPM · Add Product · Dark` | 36 |

## 3. THE APPROVED `SM` REFERENCE — measured FIRST, before any write

Every verdict below is stated against SM. §3a records a method fault I made and corrected, because it
would otherwise have invalidated the reference.

### 3a. ⚠️ The named reference board was the wrong board for `Art L1`/`Art L2` — and my first scan missed it

The dispatch named `SM - Add Product - Unknown host - Light` (`6d055762-a70b-804c-8008-bf65ff750422`)
as the board on which to measure `Art S`, `Key State` **and** `Art L1`.

My first search of that board's full 67-shape subtree for `name === 'Art L1'` returned **zero matches**.
I did **not** report that as "SM has no `Art L1`". I re-searched by prefix, and the fault was mine:

> **SM's layers are named `Art L1 · Copy key` and `Art L2 · Check access` — with a ` · <label>` suffix.**
> Exact-equality name matching silently misses them. This is the same class of defect as the
> id-substring trap: **a lookup that returns zero rows is evidence about the query, not about the file.**

The named board does carry both layers, at the same y. The correct structural reference for BPM is
`SM - Add Product · Verified · Light/Dark` — **36 children, the same count as BPM**, same layer set.
`Unknown host` (44 children) diverges below the fold: `Trust K` 514 / `Trust Body` 532 / `Submit L` 688.

### 3b. `SM - Add Product · Verified · Light` — `6d055762-a70b-804c-8008-bf660e124738` · 36 children

| layer | id | parentXY | box | fs | chars | textBounds y / h |
|---|---|---|---|---|---|---|
| `Art S` | `…bf66155c3679` | **(138, 418)** | **220×24** | 10 | 80 | 11167.5 / 24.5 |
| `Key State` | `…bf6615adae1b` | **(138, 446)** | 220×15 | 10 | 19 | 11195.5 / 12.5 |
| `Art L1 · Copy key` | `…bf6615f89020` | **(138, 466)** | 96×16 | 11 | 8 | 11215 / 14.5 |
| `Art L2 · Check access` | `…bf661646e2f7` | **(244, 466)** | 116×16 | 11 | 11 | 11215 / 14.5 |
| `Submit (label only — no nested subtext)` | `…bf6616942a00` | (16, 510) | 358×34 | — | — | — |
| `Submit L` | `…bf6616d709d0` | (16, 520) | 358×19 | 11 | 16 | 11269 / 14 |

### 3c. `SM - Add Product · Verified · Dark` — `6d055762-a70b-804c-8008-bf65f36b1c9a` · 36 children

Identical y values, dark abs band (9800): `Art S` tb 10217.5/24.5 → 10242 · `Key State` tb
10245.5/12.5 → 10258 · `Art L1`/`Art L2` tb **10265**/14.5 → 10279.5 · `Submit L` (16,520) tb
10319/14 → 10333.

**The reference is a house pattern, not a one-board quirk: `Art L1`/`Art L2` sit at parentY 466 on all
four SM boards** (`Unknown host` Dark/Light also carry them at `(138,466)` 96×16 and `(244,466)` 116×16 —
confirmed in the §7 integrity pass).

### 3d. The reference constants every verdict is measured against

| reference figure | value |
|---|---|
| **BOX gap** `Art S` → `Key State` | 446 − 418 − 24 = **4** |
| **BOX gap** `Key State` → `Art L` | 466 − 446 − 15 = **5** |
| **RENDERED gap** `Key State` → `Art L` | 11215 − 11208 = **+7** (Light) · 10265 − 10258 = **+7** (Dark) |
| **BOX gap** `Art L` → `Submit` rect | 510 − 466 − 16 = **28** |

## 4. BPM BEFORE → AFTER

### 4a. `BPM · Add Product · Light` · `…a9ad42be419b` · 36 children · no flex/grid layout

| layer | id | before parentXY | before box | before tb y/h | **after parentXY** | after box | after tb y/h |
|---|---|---|---|---|---|---|---|
| `Art S` | `…a9ad46117b59` | (138, 418) | 220×24 | 11167 / 25 | (138, 418) | 220×24 | 11167 / 25 |
| `Key State` | `…a9ad4c477ded` | (138, 446) | 220×15 | 11195 / 13 | (138, 446) | 220×15 | 11195 / 13 |
| **`Art L1`** | `…a9ad463ad1be` | (138, **456**) | 96×16 | 11205 / 14 | **(138, 466)** | 96×16 | **11215 / 14** |
| **`Art L2`** | `…a9ad4663333c` | (244, **456**) | 116×16 | 11205 / 14 | **(244, 466)** | 116×16 | **11215 / 14** |

Unchanged neighbours (full before-state measured, none of it moved): `Thumb` (30,402) 96×64 abs
11152..11216 · `Thumb Blk` (38,462) 72×14 abs 11212..11226 · `Submit` (16,510) 358×34 abs 11260..11294 ·
`Submit L` (16,**518**) 358×19 **fs 13** tb 11267/17 → 11284 · `Submit Sub` (16,552) 358×15 tb
11301/13 → 11314.

**Pre-move collision, confirmed to the pixel:** `Key State` tbBottom 11208 vs `Art L1` tbY 11205 =
**−3 rendered overlap** (boxes: 461 vs 456 = −5). The dispatch's figure is exact.

### 4b. `BPM · Add Product · Dark` · `…a9ac5f5ad2dc` · 36 children · no flex/grid layout

| layer | id | before parentXY | before box | before tb y/h | **after parentXY** | after box | after tb y/h |
|---|---|---|---|---|---|---|---|
| `Art S` | `…a9ac6184ec97` | (138, 418) | 220×24 | 10217 / 25 | (138, 418) | 220×24 | 10217 / 25 |
| `Key State` | `…a9ac68588488` | (138, 446) | 220×15 | 10245 / 13 | (138, 446) | 220×15 | 10245 / 13 |
| **`Art L1`** | `…a9ac61999a67` | (138, **456**) | 96×16 | 10255 / 14 | **(138, 466)** | 96×16 | **10265 / 14** |
| **`Art L2`** | `…a9ac61adb38c` | (244, **456**) | 116×16 | 10255 / 14 | **(244, 466)** | 116×16 | **10265 / 14** |

Unchanged neighbours: `Thumb` abs 10202..10266 · `Thumb Blk` abs 10262..10276 · `Submit` abs
10310..10344 · `Submit L` (16,**518**) 358×19 **fs 13** tb 10317/17 → 10334 · `Submit Sub` tb 10351/13.

**Pre-move collision, confirmed to the pixel:** `Key State` tbBottom 10258 vs `Art L1` tbY 10255 =
**−3 rendered overlap**. Same figure on both boards.

### 4c. `Art S` and `Key State` CONFIRMED UNCHANGED ✓

| | expected (dispatch §5) | `BPM · Light` measured | `BPM · Dark` measured | verdict |
|---|---|---|---|---|
| `Art S` box | 220×24 @ 418 | 220×24 @ 418, tb 11167/25 | 220×24 @ 418, tb 10217/25 | **UNCHANGED** |
| `Key State` box | 220×15 @ 446 | 220×15 @ 446, tb 11195/13 | 220×15 @ 446, tb 10245/13 | **UNCHANGED** |

Byte-for-byte identical to the §4a/§4b before-states. `fontSize` 10 both. `growType` `fixed` both.
`Art S` `characters` = **80** on both boards — the A3-correct custody string, untouched.

### 4d. Child counts — the expected 36/36 signature

| board | before | after | verdict |
|---|---|---|---|
| `BPM · Add Product · Light` | 36 | **36** | unchanged ✓ |
| `BPM · Add Product · Dark` | 36 | **36** | unchanged ✓ |
| page root children | 164 | **164** | unchanged ✓ |
| page boards | 160 | **160** | unchanged ✓ |

All 12 `Add Product` boards after: `65 / 68 / 64 / 65 / 68 / 64 / 36 / 36 / 44 / 36 / 44 / 36`. Geometry
edits did not add, remove or re-parent anything.

## 5. ⚠️ THE `Submit L` RE-CHECK — REPORTED, NOT FIXED. **IT DOES NOT COLLIDE.**

The dispatch said: *"re-check `Submit L` at 518 for a new collision — the previous move produced one,
so assume this will too. REPORT IT. DO NOT FIX IT."* I measured it. **There is nothing to report as a
collision.** `Submit L` was not touched and does not collide.

Measured, settled, both boards:

| measurement | SM reference | `BPM · Light` | `BPM · Dark` | verdict |
|---|---|---|---|---|
| `Submit L` parentY | 520 | **518** (untouched) | **518** (untouched) | pre-existing −2 delta, §6 |
| **BOX gap** `Art L1` → `Submit L` | — | **+36** | **+36** | **CLEAR** |
| **RENDERED gap** `Art L1` → `Submit L` | +42.5 | **+38** | **+38** | **CLEAR** |
| **RENDERED gap** `Art L1` → `Submit` rect (bg) | +30.5 | **+31** | **+31** | **CLEAR, exact match** |
| **BOX gap** `Art L1` → `Submit` rect | 28 | **28** | **28** | **EXACT MATCH — SM's 28** |

- Light: `Art L1` tbBottom **11229** vs `Submit L` tbY **11267** = **+38**
- Dark: `Art L1` tbBottom **10279** vs `Submit L` tbY **10317** = **+38**

### 5a. Why this move behaves differently from the previous one

The previous collision was not a coincidence of "one more move"; it was an asymmetry of available space,
and this grant exploits the other half of it:

- **Above** `Art L1` sat `Key State`, whose box bottom (446+15 = 461) left only **2px** of clearance
  above `Art L1`'s 456 — and −3 rendered. Shifting anything down 10px *there* must overflow.
- **Below** `Art L1` sits the `Submit` rect at 510, leaving **28px** of box clearance beneath a 16px-tall
  `Art L1`. Shifting `Art L1` down 10px *here* lands with 18px to spare.

So the same 10px that had to overflow above fits below. The prior lane's BLOCKER-2 diagnosis was right
about the cause and right that a third variable was needed — it could not have known which way the
arithmetic would fall, because the answer depends on `Submit L`'s own position, which it flagged as
unmeasured.

### 5b. Full-board overlap scan after the move — no new collision anywhere

Every pair of the 36 children was tested on **effective (rendered) rects**, not box rects:

| board | text-vs-text overlaps | unexpected overlaps | total overlaps |
|---|---|---|---|
| `BPM · Add Product · Dark` | **`[]` — none** | **`[]` — none** | 25, all intentional containment |
| `BPM · Add Product · Light` | **none** | **none** | 26, all intentional containment |

Every surviving overlap is the panel-chrome idiom, in this repository's own published vocabulary —
`design-revision-metadata-6.yaml` MR5-7 names it: *"geometrically encloses … the button-rect-plus-label
idiom, not a defect"*. The classes are `Art Bg` enclosing `Art S`/`Key State`/`Art L1`/`Art L2`,
`Submit` enclosing `Submit L`, `Thumb` enclosing `Thumb B0`/`B1`/`B2`/`Blk`, `Field Box N` enclosing
`Field Ph N`, `Bottom Nav` enclosing `Nav Badge`, and the `Top Bg`/`Top Rule`/`Back` header chrome.

`Thumb Blk` (abs y 11212..11226, x 5318..5390) and `Art L1` (11215..11229, x 5418..5514) share a y band
but **zero x overlap** — the thumb is at x 5310..5406, the labels at x 5418+. Separated.

## 6. What I did NOT do, deliberately

- **`Submit L` untouched** at (16,518) on both boards — measured, not moved, not resized, not
  re-typeset. No third variable.
- **`Art S`, `Key State`, `Submit`, `Submit Sub`, `Thumb`, `Thumb B*`, `Art T`, `Art Bg` and all 20
  other layers** on both boards untouched.
- **No `characters` assignment anywhere.** No copy changed on any board.
- **No font size changed.** The 0.5px `textBounds` delta between BPM and SM (§7) was reported, not
  absorbed by nudging a position — the prior lane's discovery 5, re-confirmed here.
- **No `SM` board edited.** No write was issued against any of the four.
- **`Submit L`'s own two pre-existing deltas from SM were NOT fixed** — they are outside the grant and
  are listed below as findings, not changes.

### 6a. Pre-existing BPM↔SM deltas found while measuring, reported not fixed

| layer | BPM | SM | class | in grant? |
|---|---|---|---|---|
| `Submit L` parentY | **518** | 520 | geometry | **NO** — not named in the grant |
| `Submit L` fontSize | **13** | 11 | typography (renders 17 tall vs 14) | **NO** |
| `Key State` characters | 17 | 19 | content | **NO** |
| `Art L2` characters | 12 | 11 (Light) / 12 (Dark) | content | **NO** |
| `Art T` characters | 26 | 29 | content | **NO** |
| `Status` characters | 18 | 30 | content | **NO** |

None is a collision. None is a copy-custody claim. All are pre-existing and all need their own grant.
**`Submit L` at fs 13 is the only one with any visual consequence** — it is the largest text in the
lower panel and does not match the approved treatment — so it is the one worth a decision.

## 7. THE FOUR `SM` BOARDS ARE UNTOUCHED ✓

| board | id | children (expect) | `Art S` | `Key State` | `Art L1 · Copy key` | `Art L2 · Check access` | `Submit L` |
|---|---|---|---|---|---|---|---|
| `SM - Unknown host - Dark` | `…bf65e644269b` | 44 → **44** ✓ | 138,418 220×24 fs10 c80 | 138,446 220×15 fs10 c19 | 138,**466** 96×16 fs11 c8 | 244,**466** 116×16 fs11 c12 | 16,688 fs11 |
| `SM - Verified - Dark` | `…bf65f36b1c9a` | 36 → **36** ✓ | 138,418 220×24 fs10 c80 | 138,446 220×15 fs10 c19 | 138,**466** 96×16 fs11 c8 | 244,**466** 116×16 fs11 c11 | 16,520 fs11 |
| `SM - Unknown host - Light` | `…bf65ff750422` | 44 → **44** ✓ | 138,418 220×24 fs10 c80 | 138,446 220×15 fs10 c19 | 138,**466** 96×16 fs11 c8 | 244,**466** 116×16 fs11 c12 | 16,688 fs11 |
| `SM - Verified - Light` | `…bf660e124738` | 36 → **36** ✓ | 138,418 220×24 fs10 c80 | 138,446 220×15 fs10 c19 | 138,**466** 96×16 fs11 c8 | 244,**466** 116×16 fs11 c11 | 16,520 fs11 |

- **No write was issued against any SM board.** All four write guards asserted an exact board name
  beginning `BPM ·`; no SM name can match that string.
- Page root **164 children / 160 boards** — unchanged, closing the inventory question the prior lane
  left as a `NOT_RUN` item.
- **Add Product revision 6 is neither advanced nor invalidated.** Its own metadata records
  `status: UNDER_REVIEW`, `reviewed_by: null`; this lane wrote nothing it owns, so that state is
  untouched. (The prior lane called revision 6's "approval VALID" — its metadata says
  `UNDER_REVIEW`, so I state the metadata rather than the paraphrase.)

## 8. Acceptance figure — BPM vs SM, after

| measurement | SM reference | `BPM · Light` | `BPM · Dark` | verdict |
|---|---|---|---|---|
| `Art S` box | 220×24 @ 418 | 220×24 @ 418 | 220×24 @ 418 | **IDENTICAL** |
| `Key State` box | 220×15 @ 446 | 220×15 @ 446 | 220×15 @ 446 | **IDENTICAL** |
| `Art L1` box | 96×16 @ (138,466) | 96×16 @ (138,466) | 96×16 @ (138,466) | **IDENTICAL** |
| `Art L2` box | 116×16 @ (244,466) | 116×16 @ (244,466) | 116×16 @ (244,466) | **IDENTICAL** |
| **BOX gap** `Art S` → `Key State` | **4** | **4** | **4** | **EXACT** |
| **BOX gap** `Key State` → `Art L1` | **5** | **5** | **5** | **EXACT** |
| **RENDERED gap** `Key State` → `Art L1` | **+7** | **+7** | **+7** | **EXACT — −3 overlap CLEARED** |
| **BOX gap** `Art L1` → `Submit` rect | **28** | **28** | **28** | **EXACT** |
| `Art S` vs `Key State` overlap | none | **none** | **none** | **AC from prior pass still holds** |
| overlap *before* this pass | — | **−3** | **−3** | dispatch's figure confirmed ×2 |

**The four geometry values written this pass, all granted:**

| board | layer | change |
|---|---|---|
| `BPM · Add Product · Dark` | `Art L1` | parentY 456 → **466** |
| `BPM · Add Product · Dark` | `Art L2` | parentY 456 → **466** |
| `BPM · Add Product · Light` | `Art L1` | parentY 456 → **466** |
| `BPM · Add Product · Light` | `Art L2` | parentY 456 → **466** |

Applied with `penpotUtils.setParentXY(shape, shape.parentX, 466)` — `parentY` is read-only computed, so
absolute `y` was never assigned. Every write was guarded by exact full-id lookup **scoped to that
board's own children**, an exact board-name assertion, an exact layer-name assertion, an exact pre-state
match on `parentX`/`parentY`/box, and `isContainedIn` board membership. **A guard failure aborts that
layer without writing**; none fired. Confirmed landed by re-reading `parentY` in separate settled calls.

## 9. Validation results

| command / check | status | note |
|---|---|---|
| `penpot_high_level_overview` read first | **pass** | before any other Penpot tool |
| page inventory (start) | **pass** | 164 root children, 160 boards, 12 `Add Product` |
| board ids verified from own `findShapes` call | **pass** | exact full id AND exact name ×3; substring trap present |
| **SM reference measured BEFORE any write** | **pass** | §3 — all four SM boards, `Art L1`/`Art L2` @ 466 |
| SM reference board re-scanned after prefix fault | **pass** | §3a — corrected my own method fault |
| BPM before-state measured (both boards, full stack) | **pass** | §4a/§4b — 36 layers each |
| writes | **pass** | 4/4 `wrote: true`, `setParentXY` only, zero guard failures |
| **settled re-read in SEPARATE calls** | **pass** | §4, one board per call; no stale `textBounds` |
| `Art S` 220×24 @ 418 unchanged | **pass** | §4c, both boards |
| `Key State` 220×15 @ 446 unchanged | **pass** | §4c, both boards |
| child counts 36/36 | **pass** | §4d — the expected geometry-only signature |
| page root 164 / 160 | **pass** | unchanged |
| **`Key State` ↔ `Art L1` overlap** | **pass** | −3 → **+7**, matching SM ×2 |
| **box gap vs SM = 5 / rendered = +7** | **pass** | exact ×2 |
| **`Submit L` @ 518 re-check** | **pass** | **+38 rendered — NO COLLISION** (§5) |
| full-board overlap scan | **pass** | zero text-vs-text, zero unexpected, both boards |
| **SM boards untouched** | **pass** | no write issued; 44/36/44/36 unchanged; geometry identical |
| **independent design review** | **NOT RUN** | a lane that wrote 4 geometry values cannot certify them |
| docker / compose | **NEVER ISSUED** | **no command of any kind** |
| dart analyze / tests / build | n/a | no production source written, out of grant |
| visual / pixel diff | NOT_RUN | no such tooling claimed for Penpot here |

## 10. Files touched

```
docs/engineering/dispatch/tasks/design-correct-f5-bpm-stack/report.md   (this file — OWNED_PATHS)
```

Nothing else. **Only the 4 granted Penpot geometry values were written.** No board renamed, moved,
deleted or re-parented; no layer created, deleted or re-parented; no `characters` assignment issued; no
`resize()` issued. The pre-existing modified `apps/control_plane/test/failures/*.png` baselines, the
modified `melos_shipit_platform.iml`, and the untracked `*.sql` / `*.archive` / `human_claims_export.txt`
files were **already dirty on arrival and were not touched**.

## 11. Durable discoveries (for the Manager to route; this lane persists no knowledge base)

1. **DESIGN_DISCOVERY — the `Submit L` collision the prior pass predicted for this move does not exist.**
   The asymmetry is in the *available clearance*, not in the move count: 2px above `Art L1`, 28px below.
   **Generalisable: when a knock-on collision is predicted from an earlier collision, check the
   clearance on the other side of the moved layer before assuming it repeats.** The prior lane correctly
   refused to fix it without that measurement, and this lane's measurement is what shows it was safe —
   the refusal cost one round-trip, not a defect.
2. **PROJECT_FACT / PROCESS_FACT — `Art L1`/`Art L2` are suffixed on every SM board
   (`Art L1 · Copy key`), and exact-equality name matching silently misses them.** A search that returns
   zero rows is evidence about the query. This is the **same class as the id-substring trap** the
   dispatch warned me about, on the *name* axis instead of the id axis, and it nearly cost this lane
   its reference measurement. **A design lane must prefix-match layer names, not equality-match, when
   establishing a reference.**
3. **PROJECT_FACT — the approved `SM` reference is split across two boards and the dispatch named the
   one without the structural match.** BPM (36 children) matches `SM · Verified` (36), not
   `SM · Unknown host` (44). All four SM boards agree on 466, so the *figure* was safe; the *board* was
   not the structural equivalent.
4. **DESIGN_DISCOVERY, carried from the prior lane and now closed — `BPM`'s stack now equals `SM`'s
   stack on every row the grant covers** (418 / 446 / 466, boxes 220×24 / 220×15 / 96×16 / 116×16,
   gaps 4 / 5 / +7 / 28). **The prior lane's discovery 4 is discharged for these four layers.** The
   sub-pixel `textBounds` delta it also recorded (BPM `tbH` 25/13/14 vs SM 24.5/12.5/14.5) is
   **unchanged and still present** — reported, not absorbed.
5. **RUNTIME_DISCOVERY — every one of the 10 Penpot calls this lane made returned; no timeout occurred.**
   The stale-`textBounds`-in-the-writing-call behaviour was avoided by construction rather than
   discovered: all four writes are `setParentXY` on a text layer's **position**, and every `textBounds`
   figure in §4/§5 comes from a later, separate call. Penpot has still gone dormant on prior lanes today;
   this lane simply never needed a retry.
6. **PROJECT_FACT — BPM and SM diverge in six non-geometry properties beyond the custody string**
   (`Submit L` y 518 vs 520 **and** fs 13 vs 11; `Key State` 17 vs 19 chars; `Art L2` 12 vs 11; `Art T`
   26 vs 29; `Status` 18 vs 30). None collides; all predate this lane; all are outside this grant.
   **`Submit L` at fs 13 is the only one with a visual consequence** and the prior lane's §3d flagged its
   518 position without measuring its type size.

## 12. Unresolved issues and blockers

- **No blocker on this grant.** All four moves landed and verified; the acceptance figure is met on
  both boards; `Submit L` does not collide.
- **For the decision owner — `BPM · Add Product`'s `Submit L` is still off-pattern**: parentY **518**
  vs SM's **520**, and `fontSize` **13** vs SM's **11** (renders 17 tall against 14, in a 358×19 box, so
  no wrap). This is a *fourth* variable on a board whose stack now matches SM everywhere else, and it
  was **not** granted. Low visual impact; it is the obvious next geometry grant if the Manager wants
  BPM byte-equal to SM.
- **Carried forward from `design-correct-f5-pass2`, untouched by this lane and still open** — reported
  so the Manager does not read this lane's green as clearing them:
  - **BLOCKER-1 — Part 2 (22 false custody layers / 12 boards, not 8).** Needs a decided A3-correct
    string per layer role; Level 2 content decision; the prior lane's §5b/§5c proposals are ready.
  - **BLOCKER-3 — the dispatch's AC #2 is unsatisfiable as written** and must be restated against 22.
  - `add_product_page.dart` still ships `created on this device … keychain` at `:542`/`:1038` and the
    `Ev Body` pair at `:480-481`/`:979-980` — boards and build remain diverged.
- **No independent design review.** This lane wrote four geometry values to two live shared design
  artifacts and cannot certify them. Verifying §8 against the `SM` reference is that review's job.

## 13. Cleanup confirmation

- [x] No Docker or Compose command issued — **none of any kind**, mutating or read-only
- [x] No process, container or compose project started by this lane
- [x] No temporary artifacts left behind
- [x] Nothing modified outside `OWNED_PATHS`, other than the 4 granted Penpot geometry values
- [x] No board renamed, moved, deleted or re-parented; no layer created or deleted
- [x] No `characters` assignment and no `resize()` issued
- [x] Nothing committed, nothing pushed; no production source written
- [x] `.decisions/**` and `docs/adr/**` untouched
- [x] The four `SM` boards untouched — mobile revision 6's state neither advanced nor invalidated

## 14. Recommended next action

```
INDEPENDENT_DESIGN_REVIEW
```

The four granted moves landed, both boards are verified against the approved `SM` reference on every
measured gap, and `Submit L` was checked and is **not** in collision — the dispatch's prediction did not
materialise and is reported as measured rather than as assumed. A lane that wrote four geometry values to
two live shared boards cannot certify them. The open items this lane did **not** touch (the 22-layer
copy decision, and BPM's `Submit L` at 518/fs 13) are listed in §12 for the Manager to route.