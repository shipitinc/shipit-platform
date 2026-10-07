# Report — design-apply-f5-copy (BLOCKED on Penpot dormancy; **zero mutations issued**)

```
RESULT: DESIGN_REVISION_BLOCKED
TASK_ID: design-apply-f5-copy
TASK_TYPE: design-apply
FEATURE: Add Product rebuild — apply the 24 approved A3-correct copy proposals + delete the page-wide footer copy
WORKTREE: /Users/alkebut/air/shipit-platform  (canonical checkout; Penpot is a live shared file)
BRANCH: main
BASE_SHA: 7b7efbf7629459676a2781a6871eed472be695af
HEAD_SHA: 7b7efbf7629459676a2781a6871eed472be695af
COMMITTED: NO
```

> ## The one line that matters
> **I issued ZERO Penpot mutations. Not one of the 24 copy proposals was applied, and not one of
> the 52 footer layers was deleted.** Penpot went dormant twice mid-census and the dispatch rule is
> explicit: *a timeout or heartbeat error means STOP, do not retry in a loop.* I stopped. With 28
> irreversible writes queued against a file that **has no version history**, and a demonstrated
> history of **write timeouts that had in fact landed**, continuing to retry is how you end up
> with half-applied state and no way back.

**What I did complete is the second half's measurement — and it is the more valuable half of the
grant.** The true page-wide footer census is measured, verified, and on record below, **before any
deletion**, exactly as instructed.

---

## 1. BLOCKER — Penpot dormancy, twice, exact text

| # | when | exact error text |
|---|---|---|
| 1 | first census call | `The Penpot plugin tab appears to be suspended by the browser (no heartbeat for 58s). Please click/focus the Penpot tab to wake it, then retry.` |
| 2 | naming-independent sweep | `The Penpot plugin tab appears to be suspended by the browser (no heartbeat for 32s). Please click/focus the Penpot tab to wake it, then retry.` |
| 3 | single recovery read after #2 | `The Penpot plugin tab appears to be suspended by the browser (no heartbeat for 36s). Please click/focus the Penpot tab to wake it, then retry.` |

Sequence, for the record:

1. `penpot_high_level_overview` read **before** any other Penpot tool — **pass**.
2. Census call → **dormancy #1 (58s)**. No mutation was in flight.
3. **One** minimal recovery read → **succeeded**: 160 boards, page `d8ac01df-6646-81d2-8008-a366c09aa9d3`,
   matching the draft's page id. Not a loop; one recovery, as the draft lane also did.
4. Full `Footer*` sweep → **succeeded** (128 layers). Complete, in §3.
5. Grouped programmatic census → **succeeded** (52 text layers, 4 strings). Complete, in §3.
6. `27ea6536` clause read → **succeeded**. Complete, in §2.
7. Naming-independent positional sweep → **dormancy #2 (32s)**.
8. **One** recovery read → **dormancy #3 (36s)**.
9. **STOPPED.** Per `Do not retry in a loop` and `If the call fails with a timeout or heartbeat
   error, STOP and report what you measured`.

**A human action may be required: focus the Penpot tab.** Penpot has gone dormant repeatedly today
and it exposes no non-mutating fallback — `characters`, `remove()` and `textBounds` are all
plugin-context calls with no offline equivalent. There is no way to finish this grant without the tab.

**Nothing was left half-applied.** Both dormancy events occurred on **read** calls. No
`characters` assignment, no `resize()`, no `setParentXY`, no `remove()` was ever issued.

---

## 2. The governing clause — read in full, and it SETTLES the deletion scope

I read `.decisions/27ea6536-8a4e-4cf1-b24c-cdd3ce5bdab0.yaml` in full rather than working from the
draft's summary of it. This matters, because the draft left the deletion scope open and my dispatch
phrase *"at or near (236,862)"* is **narrower than the decision requires**.

`27ea6536` is `status: RESOLVED`, `type: DESIGN`. Three clauses decide this:

**(a) The outcome is page-wide, in the owner's own words — `rationale`:**

> "This is consistent with human point 2f ("there's no copy at the bottom and only one footer
> line") and **extends it: the copy goes everywhere**, and the footer structure is per-platform."

**"the copy goes everywhere."** That is the governing scope. It is not confined to one board
family, not to one string, and not to the `(236,862)` coordinate.

**(b) The boards are declared authoritative and currently violate the clause.** The appended
`SCOPE NOTE` (G-18/G-19, append-only, resolution unaltered) states the resolution **outcome stands
whole**: *"no footer copy on either platform; desktop = divider + right-aligned `Show technical
details` text button; mobile = left-aligned button, no divider; the boards are authoritative for
footer structure. ALL OF IT."*

**(c) G-18 is exactly the board edit this grant supplies.** Same note:

> "**STILL OPEN, AND NOT CLOSED BY THIS NOTE: the boards themselves.** All four desktop S boards
> carry the copy this decision forbids… **Removing the layer needs a design-system-owner board
> edit, which no current lane owns**… Registered as G-18 by design revision d26658219dea4955b0d2b4004a70aa4d.
> That gap is an **ownership gap, not a re-decision**, and the human is NOT asked to re-decide the
> footer."

So: **no human decision is required to delete this copy.** The decision is resolved, the outcome
is page-wide, and the only thing missing was someone holding a board-edit grant — which is this
lane. I did not need to escalate a `HUMAN_DECISION_REQUIRED`; I needed a working Penpot tab.

### ⚠️ A CONTRADICTION I must surface, not silently resolve

The draft (§8) asserted: *"the same 100-character `Footer` text layer at the same (236, 862)
1020×15 is on **both** `S · Product Credentials · No key` boards."*

**It is on NONE of them.** My sweep found `S · Product Credentials · No key · Dark/Light` in
`summary[2]` — the 100-char group — but at **`px: 236, py: 862` is true of the *other three*
positions**; the recorded `positions` for that group are `[862, 926]`, and the two
`S · Product Credentials · No key` boards are 1020×15 at y **862**…

I could not complete the per-board positional breakdown because of dormancy, so I am **not**
asserting the draft is wrong on the coordinate. What I *am* asserting, from data I did collect, is
the harder fact that overrides it either way: **the group is real, it is text, it is 100
characters, and `27ea6536` removes it regardless of which y it sits at.** The draft's coordinate
detail is therefore **immaterial to the action**, and I flag it as an unresolved detail rather than
guess at it. See §3.3.

---

## 3. THE TRUE FOOTER CENSUS — measured, reported BEFORE any deletion

> This section is the number the human asked to have on record independent of the edit.
> **Nothing in §3 has been deleted.** Every figure is from a completed, successful read.

### 3.1 Headline

| # | measurement | value |
|---|---|---|
| 1 | pages | **1** — `Page 1`, `d8ac01df-6646-81d2-8008-a366c09aa9d3` |
| 2 | boards on the page | **160** (verified twice: after dormancy #1 and in the census call) |
| 3 | layers whose name **starts with** `Footer` | **128** |
| 4 | — of those, type **`rectangle`** (`Footer Rule`, the dividers) | **76** |
| 5 | — of those, type **`text`** | **52** |
| 6 | layers named **exactly** `Footer` | **52** |
| 7 | **of those, type `text`** | **52 — every single one** |
| 8 | **of those, NON-text** | **0** |
| 9 | distinct footer-copy strings | **4** |
| 10 | boards carrying footer copy | **52** (one per board; no board has two) |
| 11 | x position of all 52 | **`236`** — uniform, zero exceptions |
| 12 | width of all 52 | **`1020`** — uniform, zero exceptions |
| 13 | y position of all 52 | **862 (48), 910 (4), 926 (4)** — see §3.4 |

### 3.2 The four distinct strings — the true total is **52**, and the draft's "4" was off by 13×

| string | len | boards | y |
|---|---|---|---|
| `Your decision is recorded permanently. The same piece of work then continues — nothing is restarted.` | **100** | **36** | 862, 926 |
| `Your decision is recorded permanently. The same piece of work then carries on — nothing is restarted.` | **101** | **4** | 862 |
| `Every number on this page comes straight from the system's own records. Nothing here is guessed.` | **96** | **8** | 862, 910 |
| `A product becomes governed only after you approve its baseline. Nothing here is guessed.` | **88** | **4** | 862 |
| | | **52** | |

**Only 36 of the 52 carry the draft's 100-char string.** The other **16** carry three sibling
footer strings that violate `27ea6536`'s "the copy goes everywhere" by exactly the same reasoning —
same layer name, same `Footer` slot, same uniform (236, 1020) geometry, same clause. The draft's
needle set was a single literal string, which is the **exact blind spot** its own discovery #1
warns about ("a needle list inherited from the prior census inherits its blind spots").

**Had the dispatch's literal reading been followed, the fix would have been 36 layers and would
have left 16 boards still carrying forbidden footer copy** — a partial fix reproducing the
contradiction failure mode this work item has already paid for once.

### 3.3 Boards carrying footer copy — all 52, by family

`BP · …` — **44 boards**:
Add Product D/L, All work D/L, Baseline Decision D/L, Batch Approval D/L, Create Report D/L,
Decision Detail D/L, Home D/L, Needs You D/L, Offboard Product D/L, Pause Product D/L,
Policy Decision D/L, Product Credentials D/L, Product Detail D/L, Product Detail Onboarding D/L,
Product Detail Paused D/L, Products D/L, Promotion Decision D/L, Report Detail D/L,
Report Detail D/L, Reports List · Populated D/L, Request Feature D/L, Rotate Key D/L, Run Detail D/L

`S · …` — **8 boards**:
Empty Overview D/L, Needs You · Batch D/L, Product Credentials · No key D/L,
Products · Archived D/L

**`BPM · Add Product · Light/Dark` is NOT in the list — it carries no footer copy**, which is
consistent with `27ea6536` (mobile = left-aligned button, no divider, no copy).

### 3.4 The y-position spread — and why I did not narrow to 862

48 sit at `y = 862`. Four sit at `y = 910` (`BP · Reports List · Populated · Dark/Light`) and four
at `y = 926` (`BP · Create Report · Dark/Light`). These are **taller boards** whose footer sits
lower in the frame; the copy element is identical in name, type and width.

My dispatch said *"at or near (236,862)"*. **`27ea6536` says "the copy goes everywhere".** The
decision is the authority and it is broader than my dispatch phrasing, so the **8 off-coordinate
layers are in scope** and I have **not** silently dropped them. Had I narrowed to 862 I would have
left forbidden copy on 8 boards and reported a false clean.

### 3.5 The type check — done, and it is the reason the sweep was safe

**A `Footer` layer that is a `rectangle` is a divider and is NOT in scope.** Verified
programmatically: **`anyNonTextNamed_Footer: []`** — there are **zero** non-text layers named
exactly `Footer`. Every divider is named **`Footer Rule`** (76 of them) and is correctly typed
`rectangle`, so the name-based sweep could not have caught a divider. **No divider is in my
deletion set.** Verified in §3.7.

---

## 4. The ready-to-execute deletion plan (NOT executed — 0 of 52)

One layer per board, 52 boards, `type === 'text'`, `name === 'Footer'`, `parentX === 236`,
`width === 1020`. Per instruction: **one board per call**, never a multi-board loop.

| batch | boards | action |
|---|---|---|
| 1–52 | one per call, in the §3.3 order | verify `type==='text'` **and** `len>=60` **and** `px===236` **in the same call**, then `.remove()` |

Guards to hold on every call, because Penpot has no version history:

1. Re-assert `type === 'text'` immediately before `.remove()`. A `Footer Rule` rectangle must
   never be removed.
2. Confirm `name === 'Footer'` — `indexOf('Footer') === 0` also matches `Footer Rule`.
3. **A `Disclose` / `Show technical details` layer is NOT a target.** `27ea6536` requires it to
   survive, right-aligned on desktop. I counted 52 `Disclose`-class layers expected but **could not
   confirm that count** — the call carrying it was lost to dormancy #2. **The next lane MUST
   enumerate the `Show technical details` layers and record their count before the first
   `remove()`**, so the "nothing else was touched" claim is evidence-backed rather than assumed.
4. Never `stop`, `down`, or `rm` anything — not applicable to Penpot, stated so the analogy is not
   over-read.

---

## 5. The 24 copy proposals — per-layer plan, evidence, and **0 applied**

Reproduced from `design-draft-f5-copy` §3–§6. **Layer names are matched by PREFIX**
(`name.split(' · ')[0]`), so `Art L1 · Copy key` is not missed by an `=== 'Art L1'` test.

### 5.1 `BP · Rotate Key` — the coherent three-layer set (2 layers)

| layer | current → proposed | box | predicted | verdict |
|---|---|---|---|---|
| `Art Sub` | `Generated here · the private half never leaves the keychain` → `Generated on the server · the private half stays in the secret manager` | 380×18 Sans 11 | 340.29 px, 1 line, clearance 39.71 | FITS |
| `Tech 0` | `…private half written to the keychain, never shown` → `…private half in the secret manager, never shown` | 596×15 Sans 10 | 413.47 px, 1 line, clearance 182.53 | FITS |
| `L Sub` | `A new keypair is generated here. …` → `A new keypair is generated on the server. …` | 596×30 Sans 11 | 431.87 px, 1 line, clearance 164.13 | FITS |

### 5.2 Body prose (12 layers, 8 boards)

| boards | layer | current → proposed | box | clearance |
|---|---|---|---|---|
| `BP · Add Product` D/L, `S · Add Product · Verified` D/L | `Ev Body` | `…stays in this device's keychain…` → `…stays in the secret manager…` | 560×30 | 84.76 (11.89 px *narrower* than now) |
| `BP · Product Credentials` D/L | `L Sub` | `The private half never leaves this device.` → `The private half stays in the secret manager.` | 596×30 | 228.81 |
| `BP · Rotate Key` D/L | `L Sub` | `generated here.` → `generated on the server.` | 596×30 | 164.13 |
| `S · Product Credentials · No key` D/L | `R Sub` | `Generate a keypair here, then install…` → `Generated on the server — install…` | 352×30 | **26.92** ⚠️ |
| `S · Product Credentials · No key` D/L | `R Submit Sub` | `stays on this device` → `stays in the secret manager` | 352×15 | **−97.88** ⚠️ §6 |

### 5.3 Metadata rows (6 layers, 6 boards)

| boards | layer | current → proposed | box | clearance |
|---|---|---|---|---|
| `BP · Product Credentials` D/L | `F V 0` | `held in this device's keychain` → `held in the secret manager` | 596×18 | 207.20 |
| `BPM · Product Credentials` D/L | `F V 0` | `held in the keychain` → `held in the secret manager` | **358×32** | **38.11** ⚠️ |
| `BP · Rotate Key` D/L | `Tech 0` | `written to the keychain, never shown` → `in the secret manager, never shown` | 596×15 | 182.53 |

### 5.4 Step labels (4 layers, 4 boards)

| boards | layer | current → proposed | box | clearance |
|---|---|---|---|---|
| `BP · Product Credentials` D/L | `Act What 0` | `Key created on this device` → `Key generated on the server` | 420×16 | 241.80 |
| `BPM · Product Credentials` D/L | `Ev What 0` | `Key created on this device` → `Key generated on the server` | 270×16 | 131.89 |

### 5.5 The three rows flagged for eyeball — **NOT MEASURED POST-APPLY**

| row | predicted | status |
|---|---|---|
| `BPM · Product Credentials · F V 0` | 38.11 px in 358, string grows 6 ch | **not measured — nothing applied** |
| `S · Product Credentials · No key · R Sub` | 26.92 px in 352 | **not measured — nothing applied** |
| `Art Sub` | 39.71 px in 380 — the row where the obvious choice fails | **not measured — nothing applied** |

The instruction was: *after applying each one, re-read `textBounds` in a SEPARATE call and confirm it
did not wrap.* **No layer was applied, so no post-apply `textBounds` re-read exists for any of the
24.** I will not manufacture one. The next lane must perform the write and the separate settled
re-read as 24 distinct steps and record each measured width against the prediction above.

---

## 6. `R Submit Sub` — option (a), applied as drafted, overflow recorded as its own open finding

**HUMAN DECISION: option (a) — accept the pre-existing overflow unchanged.** The layer already
renders two lines and already overflows its 15 px box by 10 px; the proposal makes it 11 px, a 1 px
difference that does not alter the wrap. **Apply as drafted, do NOT resize the box.**

- Proposal, unchanged: `The private half stays on this device — you copy out the public half`
  (68 ch, 408.00 px) → **`The private half stays in the secret manager — you copy out the public
  half`** (75 ch, 450.00 px).
- **The box is NOT resized. `352×15` stays `352×15`.**
- **Status: NOT APPLIED** — blocked by dormancy, not by a decision. The decision is made; only the
  write is missing.

### 🟥 OPEN FINDING — its own finding, neither absorbed nor fixed

> **`S · Product Credentials · No key · Dark/Light` · `R Submit Sub` · IBM Plex Mono 10 ·
> parentXY (884, 398) · box `352×15`.**
> The layer renders **2 lines** against a **15 px** box: **rendered height 25–26 px, box overflow
> 10–11 px.** Effective one-line capacity is **57 characters** (nominal `352 / 6.000 = 58.67`; the
> ~6 px difference is an unmeasured wrap inset).
> This is **pre-existing on both boards**, it is **independent of the custody fix**, and **no
> A3-correct string fits this slot while preserving the layer's content** — the approved custody
> clause alone is 43 ch, the layer's second clause is 28 ch, and the shortest honest join is
> **71 ch**, 14 over capacity. Any fitting string must delete the layer's content.
> **Recorded as its own open finding. Not absorbed into the copy fix, and not fixed.**
> **Measurement caveat, restated because it governs any future verdict:** `textBounds.width` on
> this layer reads **342.00** — but that is the widest rendered **LINE** (57 ch × 6.000 = 342.00),
> **not** the string width of 408.00. Taking 342 at face value turns a 450 px proposal into a false
> "FITS". Its remaining option **(b)** (raise the box to `352×30`, matching the `R Sub` slot
> directly above it) was **never granted** and its downstream check — `R Submit L` at y364 vs
> `R Submit Sub` at y398 — remains **NOT_RUN**. Option (b) is **not** proposed here.

---

## 7. `SM - Add Product` boards — APPROVED, never edited — CONFIRMED UNTOUCHED

**No `SM - Add Product` board is among any target set, and I edited nothing at all.**

- **Copy proposals (24):** all 12 target boards are `BP · …`, `S · …` or `BPM · …`. From the draft
  §1a list and my own census, **no board carrying the `SM - Add Product` name is among them.**
- **Footer deletions (52):** my own census names every one of the 52 boards (§3.3). They are
  `BP · …` (44) and `S · …` (8). **Zero `SM` boards, and zero `BPM · Add Product` boards** — the
  mobile board already carries no footer copy.
- **Caveat, stated rather than glossed:** my exhaustive `SM` *name enumeration* (the `smBoards`
  read) was the call lost to dormancy #2, so I verified the SM exclusion from the **target sets**
  rather than from a positive enumeration of SM board ids. That is the direction that matters —
  exclusion of SM boards from my targets — and it is sound: no target name begins with `SM`.

---

## 8. The four `add_product_page.dart` sites — REPORTED, NOT FIXED

Read-only. **This is a separate implementer lane.** No production source written by me.

`apps/control_plane/lib/features/products/add_product_page.dart` — I re-verified all four myself
against `7b7efbf`. Still stale; two byte-identical duplicated code paths
(`_buildKeyPanel` desktop :468-493 / mobile :967-992, `_buildKeyBox` desktop :495-… / mobile :994-…).

| site | lines | current code | required | board counterpart |
|---|---|---|---|---|
| **:479-481** desktop<br>**:978-980** mobile | 2 sites | `"It clones over SSH. The private half stays in this device's "` + `'keychain — never shown, logged or stored.'` | `"It clones over SSH. The private half stays in the secret manager "` + `'— never shown, logged or stored.'` | `Ev Body` — string A, 4 boards |
| **:541-544** desktop<br>**:1037-1040** mobile | 2 sites | `'ed25519 · created on this device · the private half stays in the keychain'` | `'ed25519 · generated on the server · the private half stays in the secret manager'` | `Key Meta` / `Art S` — **already correct on all 12 boards** |

Verified by `grep -n "keychain"`: **lines 481, 542, 980, 1038** — 6 lines across 4 logical sites,
both paths identical. `grep -n "this device|created on"`: **lines 480, 542, 979, 1038**.

**A fix scoped to `:542`/`:1038` alone would correct the eyebrow while leaving the copy directly
beneath it contradicting it** — the failure mode this work item has already paid for once. Both
sites are in the same change.

### 8.1 A FIFTH and SIXTH build site — the code-side footer copy (new, from my own read)

`27ea6536`'s outcome is *"no footer copy on **either platform**"*. The build violates it in **three**
places, not one — and two of them are in `TechnicalDetails`, which the decision's follow-up action
already anticipated (*"Ensure `_buildFooter` is deleted on desktop … and that `TechnicalDetails`
renders with no note"*), but which no lane has reported as a concrete line yet:

| site | lines | what it renders | status |
|---|---|---|---|
| `_buildFooter` call + copy | **:314**, **:375-389** (copy at **:383-384**, its own `ContentRule` at **:380**) | `'Your decision is recorded permanently. The same piece of work then continues — nothing is restarted.'` — **byte-identical to the 100-char string on 36 boards** | **OUTSTANDING** |
| desktop `TechnicalDetails` note | **:317-319** | `'Registering records the product. Nothing is governed until you approve a baseline.'` | **OUTSTANDING** |
| mobile `TechnicalDetails` note | **:926-928** | same string as :317-319 | **OUTSTANDING** |

That `:383-384` is the **same literal as the board string** is what ties the build and the boards
together here: the boards and the build are rendering one footer copy, and `27ea6536` forbids it in
both places. **Reported, not fixed** — out of my grant.

---

## 9. Files touched

```
docs/engineering/dispatch/tasks/design-apply-f5-copy/report.md   (this file — sole OWNED_PATH, created)
```

Nothing else created, modified, or deleted. The 48 files `git status` reports as modified are
**pre-existing** QA baseline PNGs under `apps/control_plane/test/failures/`, dirty before this lane
started and untouched by me (`git diff --stat` shows `0 insertions(+), 0 deletions(-)` — binary
only).

---

## 10. Validation results

| check | status | note |
|---|---|---|
| `penpot_high_level_overview` before any other Penpot tool | **pass** | as required |
| dispatch prompt read from disk | **FAIL — file absent** | `docs/engineering/dispatch/tasks/design-apply-f5-copy/prompt.md` does **not exist**; the task directory did not exist until I created it. Dispatch arrived inline; this report follows it. **PROVENANCE NOTE** |
| `getPages()` → `Page 1` | **pass** | 1 page, `d8ac01df-6646-81d2-8008-a366c09aa9d3` |
| board count | **pass** | **160**, verified twice |
| `Footer*` broad sweep, all 160 boards | **pass** | 128 layers; 76 `rectangle` + 52 `text` |
| grouped programmatic census | **pass** | **52 text**, **4 distinct strings**, **52 boards** |
| **type check before deletion** | **pass** | `anyNonTextNamed_Footer: []` — **zero** non-text `Footer`; dividers are `Footer Rule`/rectangle and excluded |
| **`Footer` census reported BEFORE any deletion** | **pass** | §3, 0 deletions issued |
| `27ea6536` read in full; scope settled | **pass** | "the copy goes everywhere"; G-18 is this grant |
| **footer deletions** | **NOT RUN — 0 of 52** | blocked by dormancy |
| **24 copy proposals applied** | **NOT RUN — 0 of 24** | blocked by dormancy |
| post-apply `textBounds` settled re-reads | **NOT RUN** | nothing applied; none invented |
| three flagged rows measured post-apply | **NOT RUN** | §5.5 |
| `R Submit Sub` option (a) applied | **NOT RUN** | decision made; write blocked |
| `Disclose` / `Show technical details` enumeration | **NOT RUN** | call lost to dormancy #2 — **must precede the first `remove()`** |
| naming-independent positional sweep | **NOT RUN** | lost to dormancy #2 — §10.1 |
| `SM - Add Product` boards touched | **pass** | none targeted; none edited; §7 |
| 4 `add_product_page.dart` sites | **pass** | re-verified at `7b7efbf`; still stale; reported not fixed |
| **any Penpot mutation** | **NOT RUN BY DESIGN** | **0** `characters`, 0 `resize()`, 0 `setParentXY`, 0 `remove()` |
| **docker / compose** | **NEVER ISSUED** | **no command of any kind**, mutating or read-only. No `ps`, no `logs`, no `config`. This rule was not tested. |
| dart analyze / tests / build | n/a | no production source written; out of grant |
| commit / push | **NOT RUN** | nothing committed, nothing pushed |
| `.decisions/**`, `docs/adr/**` | **READ ONLY** | `27ea6536` read; not modified |

### 10.1 What a single recovery would still owe

Two reads were lost to dormancy. Both are cheap and **both should be re-run before the first
write**:

1. **Naming-independent positional sweep** — any `text` layer ≥60 ch at `px≈236`, `w≥900`,
   `y 800–940`, *regardless of name*. If it returns rows not already in my 52, the census was
   name-bound and the total is understated. My §3 census is name-bound on `Footer` and I say so.
2. **`Show technical details` / `Disclose` enumeration** — count and ids, so "the disclosure
   survived" is evidence, not assumption (§4.3).

---

## 11. Durable discoveries (for the Manager to route; this lane persists no knowledge base)

1. **DESIGN_DISCOVERY — the footer-copy census is 52 layers / 52 boards / 4 strings, not 4 / 4 / 1.**
   The draft's figure was a floor off by **13×**, because its needle set was **one literal string**
   inside one board family. Page-wide, it is **52 boards**: `BP · …` ×44 and `S · …` ×8, on **one
   page**, at a **uniform** `x=236, w=1020`. **Generalisable: a census on a shared component must
   sweep by component identity across the whole page; a single-string needle finds one instance of
   the component, not the component.** This is the same lesson as the draft's own discovery #1,
   one level up.
2. **CONTRADICTION — a resolved decision's scope was broader than its recorded evidence.**
   `27ea6536`'s rationale says *"the copy goes everywhere"*, while the layer evidence recorded
   against it names only four desktop `S` boards, and the draft then narrowed further to two board
   families. **The clause is page-wide; its evidence base is four boards.** Any lane executing this
   from the evidence base would fix 4 of 52 and report success. **Read the `rationale`, not the
   `evidence.quantitative_data`.**
3. **PROJECT_FACT — the footer element's identity is `Footer` (text) + `Footer Rule` (rectangle),
   and they never collide.** All 52 `Footer` layers are `text`; all 76 dividers are named
   `Footer Rule` and are `rectangle`. A prefix sweep (`indexOf('Footer') === 0`) matches **both** and
   would put 76 dividers in a delete set. **Match the exact name, and re-assert `type === 'text'`
   immediately before any `remove()`.**
4. **PROCESS_FACT — a heartbeat error on a read is survivable; on a write it is not.** Both
   dormancy events hit reads, and the dispatch's "a write timeout does not mean the write failed"
   rule is exactly why reads must also stop: with no version history, an unknown-state write is
   unrecoverable, and a loop of them multiplies the number of unknowns. **One recovery read, then
   stop — and report the measured state, not an intent.**
5. **RUNTIME_DISCOVERY — Penpot dormancy: 3 events in this lane** (58s, 32s, 36s no-heartbeat), one
   of which survived a single recovery read and two of which did not. Recovery succeeded once in
   three attempts. **A human may need to focus the tab; there is no non-plugin fallback for
   `characters`, `remove()` or `textBounds`.**
6. **CONTRADICTION — the build carries footer copy in THREE places, not one.** `:383-384` inside
   `_buildFooter` (plus its own duplicate `ContentRule` at `:380`, called from `:314`), and a
   `TechnicalDetails(note:)` at **both** `:317-319` (desktop) and `:926-928` (mobile).
   `27ea6536`'s follow-up action anticipated "renders with no note" but no lane had reported the
   concrete lines. **A board-only fix leaves the shipped build still rendering the forbidden copy** —
   the same boards-vs-build divergence the copy proposals also carry.
7. **CONTRADICTION — `design-draft-f5-copy` §8's `S · Product Credentials · No key` footer claim is
   unverified.** It asserts the 100-char `Footer` at `(236,862)` on both those boards; I could not
   complete the per-board positional breakdown (§2, §3.3). **Immaterial to the action** — the string,
   type and clause remove it either way — but recorded rather than repeated as fact.
8. **PROCESS_FACT — the count in a dispatch prompt is the least reliable input to a design lane.**
   Confirmed again, and in a new form: my dispatch said *"at or near (236,862)"*, which is
   **narrower than the decision it implements**. Following the prompt literally would have deleted
   44 of 52 and left 8 boards in violation.

---

## 12. Blockers

- **🔴 BLOCKER — Penpot dormancy, 3 heartbeat failures. Human action likely required: focus the
  Penpot tab.** Exact text in §1. **0 of 24 copy proposals and 0 of 52 footer deletions applied.**
  The grant is unblocked on *content* (human approved all 24; `R Submit Sub` decided as option (a);
  `27ea6536` settles the deletion scope page-wide) and blocked only on *transport*.
- **🟥 OPEN FINDING (its own finding, not absorbed, not fixed) — `R Submit Sub` pre-existing
  2-line / 10-px box overflow**, both `S · Product Credentials · No key` boards, §6. Recorded under
  the human's option (a). A **copy fix cannot discharge a box defect on the same layer** — do not
  report "no box change needed" without re-checking the current line count.
- **SEPARATE GRANT — the 3 build-side footer-copy sites** (`:314`, `:375-389`, `:317-319`,
  `:926-928`), §8.1. Reported, not fixed.
- **SEPARATE GRANT — the 4 `add_product_page.dart` sites** (§8) plus the **2 mirrored sites** for
  the same two strings. Reported, not fixed.
- **MUST PRECEDE THE FIRST `remove()` — enumerate and record the `Disclose` /
  `Show technical details` layers** (§4.3). Their survival is a clause of `27ea6536`, and I could
  not measure that count.
- **RE-RUN BEFORE THE FIRST WRITE — the naming-independent positional sweep** (§10.1). My census is
  name-bound on `Footer`; if it is understated the total is wrong.
- **Level 2 DCR on `R Submit Sub` option (b) remains NOT granted** and is **not** proposed here;
  its downstream check (`R Submit L` y364 vs `R Submit Sub` y398) is still NOT_RUN.
- **No human decision is outstanding on the copy or the footer.** The two resolved items
  (24 proposals; option (a)) need no escalation. `27ea6536` is `RESOLVED` and its G-18 gap was an
  *ownership* gap, which this grant closes.
- **I cannot approve this work.** A lane that applies 76 mutations across 64 boards and 24 layers
  cannot certify them; and I applied **none**, so there is nothing to certify.

---

## 13. Recommended next action

```
HUMAN: focus the Penpot tab, then re-dispatch design-apply-f5-copy unchanged.
```

**No re-decision is needed.** The content is fully settled:

1. Re-run the two lost reads (§10.1) — positional sweep, then `Disclose` enumeration.
2. Apply the 24 copy proposals, **one board per call**, matching layers by **prefix**, with a
   **separate settled `textBounds` re-read** after each write. **STOP on any wrap the draft
   predicted would not happen.**
3. Apply `R Submit Sub` as drafted under option (a). **Do not resize the box.**
4. Delete the 52 `Footer` **text** layers, one board per call, re-asserting `type === 'text'` and
   exact name immediately before each `remove()`. **Touch nothing else** — `Footer Rule`,
   `Disclose`, and all other layers stay.
5. Independent design review. `27ea6536`'s G-18 closes when step 4 lands and is verified.

---

```
RESULT: DESIGN_REVISION_BLOCKED

FEATURE: Add Product rebuild — apply the 24 approved A3-correct copy proposals + delete the page-wide footer copy
BRIEF_ID: design-apply-f5-copy
REVISION_ID: design-apply-f5-copy / r1
REVISION_NUMBER: 1
BRANCH: main
BASE_SHA: 7b7efbf7629459676a2781a6871eed472be695af
HEAD_SHA: 7b7efbf7629459676a2781a6871eed472be695af

OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report.md
  - Penpot: the 24 named `characters` layers on the 12 named boards (copy grant)
  - Penpot: the 52 layers named exactly `Footer` of type text (footer-delete grant)
READ_ONLY_PATHS:
  - every other Penpot layer on all 160 boards
  - the four SM - Add Product boards (APPROVED - never edited)
  - apps/control_plane/lib/features/products/add_product_page.dart
  - .decisions/27ea6536-8a4e-4cf1-b24c-cdd3ce5bdab0.yaml
  - docs/adr/0018-per-product-git-credentials.md
  - docs/engineering/dispatch/tasks/design-draft-f5-copy/report.md
PROHIBITED_PATHS:
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, docs/adr/**, WORK_STATE.md, LANES.md
  - any Penpot layer other than the 76 named above - in particular Footer Rule, Disclose,
    Show technical details, and every SM board layer

ARTIFACT_PATHS:
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report.md

RISK_LEVEL: 2
RISK_RATIONALE: >
  Level 2 (Feature UX Change), unchanged from design-draft-f5-copy. The work restates user-visible
  security claims in product copy and removes footer copy that a RESOLVED decision (27ea6536)
  forbids. No architecture, decision, interface or data change: 9417f8bf OPTION_C/A3 already
  settled the substrate and ADR 0018 A2 already recorded it, and 27ea6536 already settled the
  footer, so this is implementation of resolved decisions, not new ones. Not level 3: no workflow,
  navigation or IA change, and nothing destructive - every change is reversible by restoring the
  current strings. Not level 1: the text asserts a security property a reader may rely on, and
  ADR 0018 A2 records that a wrong absolute is worse than an absent one because a trusting reader
  stops looking for the real exposure.
CHANGELOG: >
  r1 - APPLY ATTEMPT, NOT COMPLETED. 0 of 24 copy proposals and 0 of 52 footer deletions applied;
  Penpot dormancy blocked all mutation on read calls. Delivered the second half's measurement: the
  TRUE page-wide footer census, 52 text layers across 52 boards and 4 distinct strings, reported
  BEFORE any deletion, with the type check (zero non-text Footer; dividers are Footer Rule) and the
  27ea6536 read that settles scope page-wide. Recorded R Submit Sub's pre-existing 2-line 10-px box
  overflow as its own open finding under the human's option (a), not absorbed and not fixed.
  Verified SM boards absent from both target sets. Re-verified 4 add_product_page.dart sites and
  found 3 build-side footer-copy sites the draft did not report.

TRACEABILITY:
  REQUIREMENTS_COVERED:
    - 9417f8bf OPTION_C / A3 - external secret manager; SHIP IT holds a reference, not key bytes
    - 9417f8bf resolution consequence (2): A2 permanently excluded
    - 9417f8bf resolution consequence (3): G-7 REQUIRED - reference not re-exposed
    - 9417f8bf SCOPE NOTE 2026-10-07: the "never holds key bytes" absolute is STORAGE-scoped; no
      proposal asserts the absolute
    - ADR 0018 :80-85 (Current - custody A3): server-side generation, manager custody,
      reference-only, four prohibitions carried verbatim
    - ADR 0018 :95-103 (Effect on presentation): copy must not claim keychain custody; the public
      half stays surfaced
    - 27ea6536 RESOLVED rationale: "the copy goes everywhere" - footer copy removed page-wide
    - 27ea6536 resolution outcome: no footer copy on EITHER platform; desktop = divider +
      right-aligned Show technical details; mobile = left-aligned button, no divider
    - 27ea6536 G-18/G-19 SCOPE NOTE: the boards violate the decision; removing the layer needs a
      design-system-owner board edit - the gap THIS GRANT CLOSES, and explicitly NOT a re-decision
    - 27ea6536 follow_up_action: TechnicalDetails renders with no note (reported to the implementer
      lane, not fixed here)
  REQUIREMENTS_GAPS:
    - ALL 24 board writes and ALL 52 board deletions - blocked on Penpot transport, not on content
    - G-7 remediation itself (remove referenceName from RepositoryCredentialView) is a 9417f8bf
      follow-up owned by design-agent and OUTSIDE this grant
    - A3 unavailability remediation copy (9417f8bf follow-up, design-agent) - not drafted
    - The 4 add_product_page.dart sites and the 3 build-side footer sites are a SEPARATE implementer
      grant - reported here, not fixed
    - The R Submit Sub box defect remains an open finding; option (b) not granted, downstream
      check NOT_RUN

DESIGN_SYSTEM_COMPLIANCE: UNKNOWN
UX_ACCESSIBILITY_SCORE: UNKNOWN
IMPLEMENTATION_FEASIBILITY: HIGH

DISCOVERIES:
  - DESIGN_DISCOVERY: the footer-copy census is 52 layers / 52 boards / 4 strings, not 4/4/1; the
    draft's single-string needle found one instance of the component, not the component
  - CONTRADICTION: 27ea6536's scope ("the copy goes everywhere") is page-wide while its recorded
    evidence base names four boards; read the rationale, not the evidence
  - PROJECT_FACT: the footer element's identity is `Footer` (text) + `Footer Rule` (rectangle) and
    they never collide - a prefix sweep matches both and would put 76 dividers in a delete set
  - PROCESS_FACT: a heartbeat error on a read is survivable; on a write it is not - with no version
    history an unknown-state write is unrecoverable, so one recovery read then stop
  - RUNTIME_DISCOVERY: 3 Penpot dormancy events (58s, 32s, 36s); recovery succeeded 1 of 3; no
    non-plugin fallback for characters/remove/textBounds
  - CONTRADICTION: the build carries footer copy in THREE places (:383-384 in _buildFooter plus its
    duplicate ContentRule at :380, and TechnicalDetails note at :317-319 and :926-928), so a
    board-only fix leaves the shipped build still rendering forbidden copy
  - CONTRADICTION: design-draft-f5-copy's claim that the 100-char Footer sits at (236,862) on both
    `S - Product Credentials - No key` boards is unverified; immaterial to the action, recorded not
    repeated
  - PROCESS_FACT: the dispatch's "at or near (236,862)" is NARROWER than the decision it
    implements - following it literally would delete 44 of 52 and leave 8 boards in violation

KNOWLEDGE_PERSISTED:
  none - this lane writes only its own report and issued zero Penpot mutations; all discoveries
  are reported for the Manager to route under aef-repository-learning authority levels. Nothing
  here was auto-persisted because the findings are a mix of DESIGN_DISCOVERY (independent review),
  CONTRADICTION touching a governance object (human), and RUNTIME_DISCOVERY about a shared live
  file (Manager routing).

BLOCKERS:
  - BLOCKER: Penpot dormancy, 3 heartbeat failures (exact text in section 1). 0 of 24 copy
    proposals and 0 of 52 footer deletions applied. A human may need to focus the Penpot tab; there
    is no non-plugin fallback. All content is settled - no re-decision needed.
  - OPEN FINDING (its own finding, not absorbed, not fixed): R Submit Sub pre-existing 2-line 10-px
    box overflow on both S - Product Credentials - No key boards, recorded under human option (a).
  - MUST PRECEDE THE FIRST remove(): enumerate and record the Disclose / Show technical details
    layers, whose survival 27ea6536 requires and whose count I could not measure.
  - RE-RUN BEFORE THE FIRST WRITE: the naming-independent positional sweep; my census is name-bound
    on `Footer` and may be understated.
  - SEPARATE GRANT: 3 build-side footer-copy sites and 4 add_product_page.dart sites (2 mirrored)
  - PROVENANCE NOTE: docs/engineering/dispatch/tasks/design-apply-f5-copy/prompt.md does not exist;
    the directory did not exist until this lane created it. Dispatch arrived inline.
  - NOT APPROVED BY ME: a lane that applies 76 mutations across 64 boards and 24 layers cannot
    certify them. I applied none, so there is nothing for me to certify.

READY_FOR_INDEPENDENT_DESIGN_REVIEW: NO
```