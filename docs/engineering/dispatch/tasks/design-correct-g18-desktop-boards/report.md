# Report — design-correct-g18-desktop-boards (G-18: the four-board footer edit)

Persisted per `aef-orchestrator` §14. Lane: `design-agent`, task type `design-produce`.

```
RESULT: DESIGN_REVISION_BLOCKED

TASK_ID: design-correct-g18-desktop-boards
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — G-18: bring the four desktop `S` boards into conformance with 27ea6536
WORKTREE: /Users/alkebut/air/shipit-platform  (canonical; no worktree created, none required)
BRANCH: main
BASE_SHA: 25b6ac3
HEAD_SHA: 25b6ac3
COMMITTED: NO            # policy: this lane commits nothing; Penpot is not a git artifact
```

> **Persistence note.** Written to disk **before** being returned, at the path above, per the
> dispatch — three reports were already lost in this work item. If you are reading a paraphrase of
> this lane rather than this file, the receiving lane is working from second-hand evidence.

> ## ⚠️ READ THIS FIRST — THE FOUR BOARDS ARE IN A STATE OF UNKNOWN OUTCOME
>
> **I issued the four deletions and the call timed out.** I then discovered the Penpot plugin was
> dormant and could not re-read the file. **I therefore do not know whether the edit landed.**
>
> | | |
> |---|---|
> | Deletion call issued? | **YES** |
> | Deletion call result? | **`MCP error -32001: Request timed out`** |
> | Layers deleted? | **UNKNOWN — 0, 1, 2, 3 or 4** |
> | Post-edit verification? | **NOT RUN — plugin dormant, see § 6** |
> | Could I have made it worse by retrying? | **No.** The call is guard-idempotent — see § 5.3. |
>
> **This is the one thing the Manager must resolve before anything else.** It is a read, not a
> judgement: someone must focus the Penpot tab and read four boards. § 2 below is the exact
> expected pre-edit state and § 3 the exact expected post-edit state, so the reading is a lookup,
> not an investigation.
>
> **The recorded before-state in § 2 is the only record of the pre-edit boards.** Penpot has **no
> version history**. If the deletions did *not* land, this section is the only thing that can
> reconstruct what was there. That is why step 1 was not optional.

---

## 0. Provenance and ownership

| | |
|---|---|
| Canonical checkout | `/Users/alkebut/air/shipit-platform`, branch `main`, `HEAD_SHA` `25b6ac3baf3cb098354a8be1b788af28ae58b448` |
| Penpot file | `Page 1`, id `d8ac01df-6646-81d2-8008-a366c09aa9d3` (the only page; `penpotUtils.getPages()` returns exactly one) |
| Root shape | a board named `Root Frame`; **164** root children |
| Source of the finding | `docs/engineering/dispatch/tasks/design-review-addproduct-keys-rev5/report.md` § 2.3 (F6, measured live, read-only) |
| Decision satisfied | `.decisions/27ea6536-8a4e-4cf1-b24c-cdd3ce5bdab0.yaml`, `resolution.rationale` desktop clause |
| Copy string's source | `apps/control_plane/lib/features/products/add_product_page.dart:375-390` — `_buildFooter`, literal copy at `:383-384` (read only) |

**I changed no git state.** HEAD is `25b6ac3`, the same value before and after this lane. Nothing
was staged, committed or pushed.

### OWNED_PATHS / READ_ONLY_PATHS / PROHIBITED_PATHS — as declared, as honoured

| Declaration | Honoured |
|---|---|
| **OWNED** — the four `S · Add Product · …` boards, and this report file | Yes |
| **READ_ONLY** — `add_product_page.dart` | Yes — read `:370-394`, wrote nothing |
| **PROHIBITED** — the other **8** `Add Product` boards, all other boards, `apps/**`, `packages/**`, `docker/**`, `.github/**`, `.decisions/**`, `docs/adr/**`, `WORK_STATE.md`, `LANES.md`, the keys and mobile task dirs | Yes — **zero** writes; see § 4 for the child-count evidence |
| **HARD RULE — no Docker/Compose command of any kind** | Yes — **not one was issued**, not `info`, `ps`, `logs`, `config` or any mutating one. No database was started, created, queried or touched. |

---

## 1. Page inventory — BEFORE (complete)

```
penpotUtils.getPages()  ->  [ { id: d8ac01df-6646-81d2-8008-a366c09aa9d3, name: "Page 1" } ]
page.root.children      ->  164
```

All **12** `Add Product` boards, identified from my own `findShapes` call — **not** from the
dispatch table. This page has 12 and only 4 are mine:

| # | board name | id | x,y | w×h | **kids BEFORE** | mine? |
|---|---|---|---|---|---|---|
| 1 | `BP · Add Product · Dark` | `…a9a998ffed44a5` | 9100, 7900 | 1280×900 | 65 | no |
| 2 | `BP · Add Product · Light` | `…a9a8f06e3586` | 9100, 8850 | 1280×900 | 65 | no |
| 3 | **`S · Add Product · Unknown host · Light`** | **`…a9a96fc40fa5`** | 10400, 11800 | 1280×900 | **69** | **YES** |
| 4 | **`S · Add Product · Unknown host · Dark`** | **`…a9a03d9da341`** | 10400, 12750 | 1280×900 | **69** | **YES** |
| 5 | **`S · Add Product · Verified · Light`** | **`…a9a979cd8fbc`** | 11700, 11800 | 1280×900 | **65** | **YES** |
| 6 | **`S · Add Product · Verified · Dark`** | **`…a9a04943d6ae`** | 11700, 12750 | 1280×900 | **65** | **YES** |
| 7 | `BPM · Add Product · Dark` | `…a9ac5f5ad2dc` | 5280, 9800 | 390×844 | 36 | no |
| 8 | `BPM · Add Product · Light` | `…a9ad42be419b` | 5280, 10750 | 390×844 | 36 | no |
| 9 | `SM - Add Product - Unknown host - Dark` | `6d055762-…f644269b` | 7550, 9800 | 390×844 | 44 | no — **APPROVED, frozen** |
| 10 | `SM - Add Product - Verified - Dark` | `6d055762-…f36b1c9a` | 8000, 9800 | 390×844 | 36 | no — **APPROVED, frozen** |
| 11 | `SM - Add Product - Unknown host - Light` | `6d055762-…f750422` | 7550, 10750 | 390×844 | 44 | no — **APPROVED, frozen** |
| 12 | `SM - Add Product - Verified - Light` | `6d055762-…0e124738` | 8000, 10750 | 390×844 | 36 | no — **APPROVED, frozen** |

> **The trap the dispatch named, and the id that makes it live.** `S · Add Product · Unknown host ·
> Dark` is `…a9a03d9da341`. That is a *long* run of characters that also appears inside
> `…a9ac5f5ad2dc` (`BPM · Add Product · Dark`) and `…a9ad42be419b` (`BPM · Add Product · Light`)
> — different boards, not mine. Worse, `…a9a8f06e3586` is `BP · Add Product · **Light**`, sitting one
> character-pattern away from `…a9a96fc40fa5` (`S · Unknown host · **Light**`). Every id above came
> from my own `findShapes` enumeration and every id was re-asserted by exact string equality in the
> guard block before any mutation (§ 5.2). I never constructed an id from a remembered pattern.

---

## 2. BEFORE — the `Footer` layer on all four boards (the only record; Penpot has no history)

Measured with
`penpotUtils.findShapes(s => s.type === 'text' && s.name === 'Footer', board)`.
**All four identical in the footer band.** `parentX/parentY` are board-relative; `x/y` absolute.

| board | layer id | type | name | parentXY | absolute x,y | size |
|---|---|---|---|---|---|---|
| `S · Unknown host · Light` | `…a9a9738f2439` | text | `Footer` | **(236, 862)** | 10636, 12662 | 1020×15 |
| `S · Unknown host · Dark` | `…a9a041f228ae` | text | `Footer` | **(236, 862)** | 10636, 13612 | 1020×15 |
| `S · Verified · Light` | `…a9a97dc29ab3` | text | `Footer` | **(236, 862)** | 11936, 12662 | 1020×15 |
| `S · Verified · Dark` | `…a9a04cc64609` | text | `Footer` | **(236, 862)** | 11936, 13612 | 1020×15 |

`characters`, byte-identical on all four:

> `Your decision is recorded permanently. The same piece of work then continues — nothing is restarted.`

The dash is U+2014 EM DASH, matching `add_product_page.dart:384`'s `\u2014`. The string is
byte-identical to `_buildFooter`'s copy at `:383-384`, which is what makes this the board's
rendering of the desktop footer's copy line and not some other text a human could have misread.

**The other two footer-band elements, measured so their survival could be checked:**

| element | measured | verdict per the grant |
|---|---|---|
| `Footer Rule` divider, rectangle, **parentXY (236, 848)**, 1020×1 | present on all four | **correct — leave it** |
| `Disclose` text, parentXY (1036, 862), 220×15, `"Show technical details ▸"` | present on all four; right edge **board-relative 1256** = 236 + 1020 = the content column's right edge | **right-aligned, correct — leave it** |

> **One correction to the rev-5 report's own arithmetic, for the record.** Rev-5 § 2.3 states the
> `Disclose` *right edge* is `1256`. That is the **board-relative** value (absolute 11656 on the
> Unknown-host boards, absolute 12956 on the Verified boards — `board.x + 1256`). Both readings are
> correct in their own frame; the conclusion — that it is right-aligned to the content column — is
> unaffected. Recorded because a later lane reading "1256" as an absolute page coordinate would look
> for it on the wrong board. It does not change any verdict.

---

## 3. AFTER — **NOT RUN. This is the blocker.**

The re-read never executed. The plugin went dormant between the deletion call and the verification
read. See § 6 for the verbatim errors.

**What the AFTER read must show, so the Manager can check it as a lookup:**

| check | expected |
|---|---|
| `…a9a9738f2439` (UH·Light) | **not found** by `findShapeById` |
| `…a9a041f228ae` (UH·Dark) | **not found** |
| `…a9a97dc29ab3` (Ver·Light) | **not found** |
| `…a9a04cc64609` (Ver·Dark) | **not found** |
| `Footer`-named text per board | **0** |
| child counts | **68, 68, 64, 64** (each exactly one lower) |
| `Footer Rule` | still at parentXY (236, 848), 1020×1, on all four |
| `Disclose` right edge | still board-relative **1256** on all four |
| root children | still **164** (deletions are inside boards) |
| the **8** boards I do not own | still **65, 65, 36, 36, 44, 36, 44, 36** |

---

## 4. The other eight boards — untouched, and how I know

**I issued no edit against any of them.** Not one `remove()`, no rename, no move, no property write.
Every `findShapes`/`findShapeById` call I made on them was a read.

Their BEFORE child counts are in § 1. **Their AFTER child counts could not be read** (plugin
dormant), so I report this honestly:

| | |
|---|---|
| Board ids I passed to a *mutating* call | **4 — the four owned boards, nothing else** |
| Board ids I passed to a *reading* call | all 12 + BPM + SM (read-only by construction) |
| Risk of collateral change | **none** — `remove()` was called only on four shape ids, each of which was proven to be a direct child of an owned board |

The reading is stronger than the count comparison anyway: the deletion loop was a `for` over a
four-element hard-coded array of shape ids. There is no code path in it that could reach a fifth
board. **The verification is still owed**, because "the code could not have done it" is not the
same as "it was observed not to have happened" — but the exposure is genuinely nil.

**Mobile revision 6's approval is safe.** No `SM` board (`6d055762-…`) was mutated. Nothing in this
lane touched the approved artifact set.

---

## 5. The deletion

### 5.1 Pre-flight: a dry-run guard block (no mutation) — `allGuardsPass: true`

Before any mutation I ran every guard for all four targets and aborted on any failure. All four
passed, each asserting:

- board found, `type === 'board'`, **name** equals the expected name exactly
- board child count equals the recorded BEFORE value (69/69/65/65) — drift detector
- **board is not a component instance** (`board.component()` returned `null` on all four) — so
  `remove()` destroys outright and does **not** merely make the layer invisible
- shape found; `type === 'text'`; `name === 'Footer'`; `parentX === 236`; `parentY === 862`;
  `width === 1020`; `height === 15`
- `characters` equals the exact expected string
- the shape's **`parent` is the board directly** — not nested in a group

The component check is the one the dispatch specifically warned about, and it is why the dry run
existed: had any board been a component asset, `remove()` would have hidden the layer instead of
deleting it and I would have learned that only after the fact. It was `null` on all four.

### 5.2 The mutating call — validate-all, then remove, then report

The call was written so there is **no half-done state**:

```
PHASE 1 — re-run all nine guards for all four targets. If any fails: return { ABORTED: true } with no mutation.
PHASE 2 — for each of the four: s.remove(); record kidsBefore/kidsAfter/delta and whether findShapeById now returns null.
```

Every id was asserted by **exact string equality** against the id my own `findShapes` returned in § 2
— never assembled from a pattern.

### 5.3 Why re-running the call would have been safe (and why I still did not)

I did not retry, per the dispatch's dormancy rule. But the design is worth recording for whoever
resumes: the call is **idempotent under its own guards**. If the deletions already landed,
`findShapeById(p.shapeId)` returns `null` and PHASE 1 pushes `'shape missing'` into `blockers`, so
the call returns `ABORTED` having touched nothing. It cannot double-delete and cannot remove a
different layer. **Whoever finishes this should still re-read first** (§ 3) rather than blind-retry —
a fresh read is the correct instrument, not a re-run.

### 5.4 What actually came back

```
MCP error -32001: Request timed out
```

The call produced no result object. I have **no** `removed[]` array, **no** per-board `kidsAfter`,
and **no** confirmation that any `remove()` executed. A timeout means the transport gave up; it does
not distinguish "never ran" from "ran but the reply was lost".

---

## 6. The two open questions — **settled, measured, read-only**

### 6.1 `BPM` — **it needs no edit at all. `G-23` resolves to "already conformant".**

I dumped every descendant of both BPM boards (36 direct children, 59 descendants each, Light and
Dark identical in structure). Clause by clause against `27ea6536`'s **mobile** clause:

| `27ea6536` mobile clause | measured on `BPM · Add Product · Light` **and** `· Dark` | verdict |
|---|---|---|
| `Show technical details` button **left-aligned** | `Disclose` text at parentXY **(16, 580)**, 220×15, `"Show technical details ▸"`. `parentX` **16** is the content column's left edge — same as `Rule 1` (16,164), `Submit` (16,510), `Submit Sub` (16,552) | **SATISFIED — left-aligned** |
| **no divider** above it | The nearest rule is `Rule 1` at y=**164** — a field rule near the top, 402px above the disclosure. There is **no** `Footer Rule`, **no** `ContentRule`, and no 1px-tall rectangle anywhere between y=486 (`Art Bg` bottom) and y=764 (`Bottom Nav`). A rule scan of the whole board returns only `Top Rule` (0,55), `Rule 1` (16,164), `Nav Rule` (0,0, inside the bottom-nav sub-board) | **SATISFIED — no divider** |
| **no footer copy** | `Footer`-named layers: **0**. After `Disclose` at y=580 there is **no text at all** until the bottom nav at y=764. Nothing at y in [830,900] | **SATISFIED — no footer copy** |

**There is nothing on BPM to delete.** The layer the desktop boards carry does not exist there.

> **This is the useful answer to G-23.** It was registered as unverified **in both directions** —
> nobody had measured whether BPM carries a footer or not. It now resolves **in the direction of no
> change**: BPM already satisfies the mobile spec on all three clauses, in both themes, and the
> grant to edit BPM was correct only in the trivial sense that there was nothing to do. **No BPM edit
> was made, and none should ever be made under this finding.**

**Independent corroboration of the sibling mobile lane's D-8** (`SM` and `BPM` are two states of one
design), measured read-only: all four `SM` boards carry a disclosure at **`parentX` 16** — the same
left edge — with names `Disclose · single footer row`, **zero** `Footer` layers, and a rule scan
returning only `Top Rule`, `Rule 1`, `Nav Rule`. **No footer divider, no footer copy, left-aligned**,
on all four. BPM and SM are the same footer design in two states. This corroborates L-R5-3's note
that the contract under-cites the mobile boards; it does **not** re-open the mobile lane's approval.

### 6.2 `F5` — measured, page-wide. **Confirmed on BPM, and it is wider than BPM.**

A page-wide sweep of all **6,823** text layers for the two strings found **16 hits on 8 boards**:

| board | `Status` layer | custody string layer |
|---|---|---|
| `BP · Add Product · Light` / `· Dark` | (246, 83) `"NOT REGISTERED YET"` | `Key Meta` (248, 460) `"ed25519 · created on this device · the private half stays in the keychain"` |
| **`S · Add Product · Unknown host · Light/Dark`** | (246, 83) `"NOT REGISTERED YET"` | `Key Meta` (248, 460) — same string |
| **`S · Add Product · Verified · Light/Dark`** | (246, 83) `"NOT REGISTERED YET"` | `Key Meta` (248, 460) — same string |
| **`BPM · Add Product · Light/Dark`** | (26, 137) `"NOT REGISTERED YET"` | `Art S` (138, 418) `"ed25519 · private half stays in the keychain"` |
| **`SM - Add Product - …` ×4** | **absent** | **absent** |

Three findings:

1. **F5 is confirmed on BPM**, in both themes, exactly as the dispatch stated — `Status` at (26,137)
   and `Art S` at (138,418).
2. **The custody string is not byte-identical across platforms.** The false *clause* —
   "private half stays in the keychain" — is common to both, and is false under `9417f8bf`'s A3
   (external secret manager custody) in both. But the desktop variant carries an extra
   `"created on this device · "` prefix, so the full strings differ:
   - desktop (6 boards): `ed25519 · created on this device · the private half stays in the keychain`
   - mobile (2 boards):  `ed25519 · private half stays in the keychain`
   **A fix that replaces one whole string with the other would break the other platform.** It must be
   a per-platform edit. Recorded because this is exactly the shape of edit that turns into a
   collateral change when a lane assumes one string.
3. **F5 is page-wide, not BPM-local: 8 boards, not 2.** It is present on all six 1280×900 desktop
   boards (`BP` and `S`) **and** both `BPM` boards. The four `SM` boards are **clean** — carrying
   neither string. If F5 is worked, its blast radius is the eight non-`SM` `Add Product` boards, and
   `SM` needs no part of it.

**I made no F5 edit.** It is not in my grant, and the replacement copy is a product/architecture
question (what *is* true about custody and about the registration eyebrow, given A3 and
`898b07d0`'s committed-registration change). That is a human-level decision, not a lane's.

An adjacent item for whoever works F5, reported because I saw it and it belongs to the same eyebrow:
`Key State` at (138, 436) on both BPM boards reads `"Not installed yet"` — the same family as the
`NOT REGISTERED YET` eyebrow.

---

## 7. Is G-18 discharged? **UNKNOWN. Not discharged, not partially — undetermined.**

I will not claim a green I did not measure.

| | |
|---|---|
| **G-18 as registered** | the four desktop `S` boards carry a `Footer` text layer at (236,862) carrying the code's copy string, so `27ea6536`'s desktop clause "No footer copy" is not satisfied on the boards that decision declares authoritative |
| **Precondition** | **VERIFIED, independently, live** — all four layers present, correct type, correct position, byte-identical copy string, `board.component() === null` |
| **The edit itself** | **ISSUED, OUTCOME UNKNOWN** — one call, timed out |
| **Post-state** | **NOT OBSERVED** |
| **Verdict** | **G-18 is UNDETERMINED.** It is *conformed if* the call executed, *unconformed if* it did not. I am not permitted to guess which, and the rev-5 reviewer's discipline — do not adopt an unverified premise — applies to me with full force. |

**What is genuinely settled by this lane, regardless of the deletion outcome:**

- The **premise** of G-18 is confirmed to the letter: the layer exists on all four boards, at
  (236,862), 1020×15, type `text`, carrying `_buildFooter`'s exact copy. This is now a **third**
  independent measurement (the mobile lane's, rev-5 reviewer's, and mine).
- **`27ea6536`'s `supersedes_design_lane_reading` is falsified**, per the record-correction note at
  the end of that file — the "misidentification" clause is wrong; the owner's *outcome* stands.
- **`G-23` is discharged**: BPM needs no edit (§ 6.1).
- **`F5` is measured and its true blast radius established**: 8 boards, 16 layers, two distinct
  strings (§ 6.2).

---

## 8. Validation results

| Command | Status | Evidence / note |
|---|---|---|
| `penpotUtils.getPages()` | **pass** | returns exactly `Page 1` / `d8ac01df-6646-81d2-8008-a366c09aa9d3` |
| Page inventory BEFORE | **pass** | 164 root children; all 12 `Add Product` boards enumerated with ids |
| Footer-layer BEFORE on 4 boards | **pass** | § 2 — name/type/coords/size/characters/kids on each |
| Guard dry-run (9 guards × 4) | **pass** | `allGuardsPass: true`; no mutation |
| **Deletion call** | **UNKNOWN** | `MCP error -32001: Request timed out` |
| AFTER re-read | **NOT_RUN** | plugin dormant — § 6 errors below |
| Other-8-board AFTER counts | **NOT_RUN** | plugin dormant; see § 4 for why exposure is nil |
| `dart analyze` / `flutter analyze` / tests | **n/a** | no production source written; out of grant |
| Docker / Compose (any) | **n/a** | **never issued** — no database started, created, queried or touched |

### The two dormancy errors, verbatim

```
Error: The Penpot plugin tab appears to be suspended by the browser (no heartbeat for 74s).
Please click/focus the Penpot tab to wake it, then retry.

Error: The Penpot plugin tab appears to be suspended by the browser (no heartbeat for 84s).
Please click/focus the Penpot tab to wake it, then retry.
```

Sequence: the deletion call returned `-32001 Request timed out`; my first re-read returned the 74s
error; I made **one** further read attempt to determine whether the plugin had recovered on its own
and received the 84s error. **I then stopped.** That was two failed calls after the timeout, not a
retry loop, and **I issued no further mutation of any kind**. I did not guess board contents from
memory at any point.

---

## 9. What changed and why

- **Issued** four `shape.remove()` calls, one per owned board — each on a shape id proven by exact
  string equality to be the `Footer` text layer at (236,862) on that board. **Outcome unobserved.**
- **Nothing else was changed anywhere**, in Penpot or in git. No second edit was made or attempted;
  had I wanted one, I would have stopped and reported instead.

**Deviation from the plan:** the plan ended at "AFTER re-read and confirm". The lane is blocked
before that step. The mutation was not rolled back — **it cannot be**, because Penpot has no version
history; if the call executed, the layer is genuinely gone and the correct next action is to
*verify*, not to restore.

---

## 10. Files touched

```text
docs/engineering/dispatch/tasks/design-correct-g18-desktop-boards/report.md
```

Nothing else. Penpot edits are not files. `git status` for tracked files is unchanged by this lane
(the pre-existing modified `apps/control_plane/test/failures/*.png` were already dirty on arrival —
visual-regression baselines from an earlier lane — and I did not touch them).

---

## 11. Documentation updated

```text
docs/engineering/dispatch/tasks/design-correct-g18-desktop-boards/report.md
```

`.decisions/**` and `docs/adr/**` untouched — both `PROHIBITED_PATHS`. `27ea6536`'s record-correction
note (which already carries the G-18/G-19/G-23 registration) is unchanged, and `27ea6536` was **not
re-opened**: its outcome stands, and the human is not asked to re-decide the footer.

---

## 12. Model and reasoning effort

```yaml
ROUTING_CLASS_REQUESTED: STANDARD
MODEL_USED: opencode/space-bunny-free
REASONING_EFFORT: n/a (not surfaced to this lane)
ESCALATED_INSIDE_TASK: NO
ESCALATION_REASON: n/a
```

---

## 13. Unresolved issues and blockers

1. **BLOCKER — the four boards are in a state of unknown outcome.** A deletion call was issued and
   timed out; the plugin then went dormant and the AFTER read never ran. **Someone must focus the
   Penpot tab and read four boards**, checking them against § 3. This is a lookup, not an
   investigation: § 2 is the before-state and § 3 is the after-state.
2. **If the deletions did not land**, the fix is to re-issue § 5's call once the plugin is awake. It
   is guard-idempotent — it aborts rather than double-deleting (§ 5.3). **Re-read first; do not
   blind-retry.**
3. **If they did land**, G-18 is discharged on the boards and the remaining work is the keys lane's:
   the `_buildFooter` deletion and `TechnicalDetails` with `note: null` (`27ea6536` follow-up action
   #4, owner `implementer`). The build must not be corrected while the boards still carry the copy.
4. **`F5` needs an owner and a copy decision** (§ 6.2). It is not a string swap: two distinct
   strings across two platforms, 16 layers on 8 boards, and the replacement copy is a
   product/architecture question. Not this lane's to decide.
5. **`27ea6536`'s `follow_up_action` #2** — "Verify the mobile footer against `BPM`" — is now
   **answered by measurement** (§ 6.1): left-aligned, no divider, no copy, both themes. No
   correction needed. That action can be closed by its owner.

No Human Decision is requested by this lane. `27ea6536` stands; nothing here re-opens it.

---

## 14. Safe parallelism

```yaml
SAFE_PARALLEL_WORK:
  - the keys lane (design-correct-addproduct-keys) — G-11, G-13, G-14, G-16, per rev-5's own § SAFE_PARALLEL_WORK
  - anything reading add_product_page.dart read-only
  - the mobile lane's remaining work — I touched no SM board, so mobile revision 6's approval stands
PROHIBITED_PARALLEL_WORK:
  - any lane that edits the four desktop `S · Add Product · …` boards — until the unknown outcome in
    § 13.1 is resolved, a second writer could delete a layer that is already deleted, or act on a
    board state neither of us has observed
  - any BPM or F5 board edit — G-23 is now measured as needing no BPM change, and F5 has no owner
```

---

## 15. Cleanup confirmation

- [x] No processes started by this lane (no Docker, no Compose, no servers, no databases).
- [x] No temporary artifacts left; only this report was written.
- [x] `git status --short` — this lane modified no tracked file. HEAD unchanged at `25b6ac3`.
- [x] No files modified outside `OWNED_PATHS`. No board outside the four owned was mutated.
- [ ] **UNRESOLVED** — the Penpot mutation's outcome is unverified. Deliberately left open rather
      than ticked: it is the report's central finding.

---

## 16. Recommended next action

```
WAIT_FOR_GATES
```

The Manager must have the Penpot tab focused and § 13.1 resolved by reading the four boards before
this work item advances. **Do not dispatch a board-writing lane until then.**

---

```yaml
FEATURE: Add Product rebuild — G-18: bring the four desktop `S` boards into conformance with 27ea6536
BRIEF_ID: n/a (conformance correction, not a new brief)
REVISION_ID: n/a (board-layer correction; the owning revision is the keys lane's d26658219dea4955b0d2b4004a70aa4d)
REVISION_NUMBER: n/a

BRANCH: main
BASE_SHA: 25b6ac3
HEAD_SHA: 25b6ac3

OWNED_PATHS:
  - Penpot Page 1 (d8ac01df-6646-81d2-8008-a366c09aa9d3) — exactly these four boards:
      S · Add Product · Unknown host · Light   b5b63334-c22a-80a6-8008-a9a96fc40fa5
      S · Add Product · Unknown host · Dark    b5b63334-c22a-80a6-8008-a9a03d9da341
      S · Add Product · Verified · Light       b5b63334-c22a-80a6-8008-a9a979cd8fbc
      S · Add Product · Verified · Dark        b5b63334-c22a-80a6-8008-a9a04943d6ae
  - docs/engineering/dispatch/tasks/design-correct-g18-desktop-boards/report.md
READ_ONLY_PATHS:
  - apps/control_plane/lib/features/products/add_product_page.dart
  - .decisions/27ea6536-8a4e-4cf1-b24c-cdd3ce5bdab0.yaml
  - docs/engineering/dispatch/tasks/design-review-addproduct-keys-rev5/report.md
PROHIBITED_PATHS:
  - the other 8 Penpot Add Product boards (BP ×2, BPM ×2, SM ×4) and every non-Add-Product board
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, docs/adr/**, WORK_STATE.md, LANES.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**, design-addproduct-mobile/**

ARTIFACT_PATHS:
  - docs/engineering/dispatch/tasks/design-correct-g18-desktop-boards/report.md
  - Penpot Page 1, four `S · Add Product · …` boards — one `Footer` text layer removed per board,
    outcome UNVERIFIED (§ 13.1)

RISK_LEVEL: 1
RISK_RATIONALE: >
  Level 1, not 0 and not 2. The intent is a pure conformance edit: it makes the boards match a
  RESOLVED human decision (27ea6536) that the boards were already declared authoritative for, and
  it deletes rather than adds, so no new user-facing surface appears. It is not 0 because it mutates
  four live shared design artifacts with no version history, and because the outcome is currently
  unverified — recoverability is by re-authoring, not by undo. It is not 2 because it is not a Level-2
  "Feature UX Change": no workflow, navigation or IA is touched, the deletion was specified by a
  resolved decision, and the grant forbade any second edit. Independent reviewer required regardless:
  the lane that edits four boards cannot be the lane that certifies them.

CHANGELOG: >
  G-18 desktop-board conformance pass, BLOCKED at verification.
  - Verified the G-18 premise live on all four boards: `Footer` text layer at parentXY (236,862),
    1020x15, carrying `_buildFooter`'s byte-identical copy string (add_product_page.dart:383-384);
    board.component() === null on all four, so remove() destroys rather than hides.
  - Verified the two elements that must survive: `Footer Rule` at (236,848) 1020x1, and `Disclose`
    with right edge at board-relative 1256 = 236+1020.
  - Issued the four deletions. The call returned `MCP error -32001: Request timed out`. The AFTER
    read could not run — Penpot plugin dormant ("no heartbeat for 74s", then "84s"). Outcome UNKNOWN.
  - Measured the two open questions, read-only, no edits: BPM carries no `Footer` layer, a
    left-aligned disclosure at (16,580) and no divider, i.e. it ALREADY satisfies 27ea6536's mobile
    clause in both themes -> G-23 resolves to "no change needed" (6.1). F5 confirmed on BPM and
    measured page-wide: 16 layers across 8 boards, in TWO distinct strings (6.2).
  - Corroborated the mobile lane's D-8: all four SM boards share BPM's footer design and are clean
    of both F5 strings. No SM board was touched; mobile revision 6's approval is unaffected.

TRACEABILITY:
  REQUIREMENTS_COVERED:
    - 27ea6536 resolution.rationale, DESKTOP clause: "a divider, and a right-aligned Show technical
      details text button. NO footer copy." — premise verified on all four boards; deletion issued.
    - 27ea6536 resolution.rationale: "the boards are authoritative" — this is the edit that makes
      them so on the one clause where they diverged.
    - 27ea6536 follow_up_action #2 (verify the mobile footer against BPM) — ANSWERED BY MEASUREMENT,
      read-only: left-aligned at parentX 16, no divider, no copy, both themes. No change needed.
    - design-review-addproduct-keys-rev5 § 2.3 F6 / B-R5-1 — independently reproduced, not adopted.
    - G-18 (keys) and F6/N6b (mobile) — premise independently confirmed by a third measurement.
  REQUIREMENTS_GAPS:
    - G-18 — UNDETERMINED. The edit was issued but its result was never observed (§ 13.1). G-18 is
      neither discharged nor open; it is unmeasured on its outcome.
    - G-19 — unchanged and out of grant. 27ea6536's `supersedes_design_lane_reading` clause calling
      the (236,862) reading "a misidentification" is falsified by this lane's measurement, exactly as
      the decision's own appended record-correction note states. The record still carries the false
      clause; correcting the record needs the ADR/decision owner. I did not touch .decisions/**.
    - G-23 — DISCHARGED by measurement: BPM needs no edit (§ 6.1).
    - F5 — MEASURED, NOT WORKED. 16 layers on 8 boards; needs an owner and a copy decision (§ 6.2).
    - 27ea6536 follow_up_action #4 (`implementer`: delete `_buildFooter`, `TechnicalDetails` with no
      note) — NOT mine. Must not be applied while the boards may still carry the copy.

DESIGN_SYSTEM_COMPLIANCE: PASS
UX_ACCESSIBILITY_SCORE: PASS
IMPLEMENTATION_FEASIBILITY: HIGH

DISCOVERIES:
  - DESIGN_DISCOVERY / PROJECT_FACT — G-18's premise independently confirmed a third time: all four
    desktop `S` boards carry a `Footer` text layer at parentXY (236,862), 1020x15, byte-identical to
    add_product_page.dart:383-384, with board.component() === null on all four. The rev-5 reviewer's
    F6 measurement is reproducible; a lane can reach it with
    `findShapes(s => s.type === 'text' && s.name === 'Footer', board)`.
  - DESIGN_DISCOVERY / PROJECT_FACT — BPM and SM are two states of ONE mobile footer design, now
    measured on all six boards: disclosure left-aligned at parentX 16, no footer divider, no footer
    copy. BPM therefore needs NO edit; G-23 resolves to no-change. This substantiates D-8 and
    L-R5-3 with first-hand evidence.
  - DESIGN_DISCOVERY / PROJECT_FACT — F5's blast radius is 8 boards and 16 layers, in TWO distinct
    strings: desktop (BP+S, 6 boards) carries "ed25519 · created on this device · the private half
    stays in the keychain"; mobile (BPM, 2 boards) carries "ed25519 · private half stays in the
    keychain". A whole-string replacement applied across the page would corrupt one platform. The
    four SM boards are clean.
  - RUNTIME_DISCOVERY — Penpot's plugin goes dormant mid-session and a mutating `execute_code` call
    can return `MCP error -32001: Request timed out` while leaving the mutation's fate UNKNOWN.
    Consequence: a timeout after a write must be treated as an unverified write. Guard design should
    make writes idempotent under re-assertion (validate-all-then-mutate), and the pre-write read must
    be persisted BEFORE the write, because Penpot has no version history and the pre-state is
    otherwise unrecoverable. This is the concrete mechanism behind the dispatch's "step 1 is not
    optional", and it cost this lane its verification step.
  - CONTRADICTION — rev-5 § 2.3 reports the Disclose right edge as "1256"; that is the BOARD-RELATIVE
    value (absolute 11656 / 12956 = board.x + 1256). Conclusion unaffected; recorded because reading
    1256 as an absolute page coordinate would target the wrong board.
  - WORKFLOW_IMPROVEMENT (candidate, not persisted — outside this lane's authority) — a board-editing
    dispatch should require the lane to persist its before-state to disk before mutating, and should
    mandate guard-idempotent mutation, so that a plugin timeout costs verification rather than
    leaving the artifact in an unknown state.

KNOWLEDGE_PERSISTED:
  - This report only (docs/engineering/dispatch/tasks/design-correct-g18-desktop-boards/report.md).
    It is the durable record of: the complete pre-edit state of the four boards, the live
    measurement of BPM and SM, and the page-wide F5 measurement. No other knowledge base was written
    to — no .decisions/**, no docs/adr/**, no design revision artifact. This lane produced no Design
    Revision body, so there was no gap register to append to; the findings above are reported to the
    Manager to route into the owning lanes' registers.

BLOCKERS:
  - B-G18-1 (BLOCKER, tool/environment) — "The Penpot plugin tab appears to be suspended by the
    browser (no heartbeat for 74s)" then "...(no heartbeat for 84s)". The deletion call returned
    "MCP error -32001: Request timed out" and the AFTER verification never ran. The four boards'
    current state is UNKNOWN and G-18 is UNDETERMINED. Resolution is a human/Manager action: focus
    the Penpot tab, then read the four boards against § 3 of this report. Not retryable by this lane
    per the dispatch's dormancy rule, and not safely retryable blind in any case.

READY_FOR_INDEPENDENT_DESIGN_REVIEW: NO
```

**Why `NO`, in one line:** `READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES` requires
`RESULT: DESIGN_REVISION_COMPLETE`, and this lane is `DESIGN_REVISION_BLOCKED` — the edit it was
sent to make is of unverified outcome, so there is no revision here for a reviewer to review.
Independently: **a lane that edits four boards cannot be the lane that certifies them.** Even had the
verification succeeded, certification of this edit belongs to a separate, read-only design-reviewer
lane. Two reasons, either sufficient.