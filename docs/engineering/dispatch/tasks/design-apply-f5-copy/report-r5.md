# Report r5 — design-apply-f5-copy (**zero mutations issued**; stopped on first heartbeat error — and the dispatch's "no partial state" premise is FALSIFIED by my own reads)

```
RESULT: DESIGN_REVISION_BLOCKED
TASK_ID: design-apply-f5-copy
TASK_TYPE: design-apply
REVISION: r5 (supersedes report.md / r1, report-r2.md / r2, report-r3.md / r3, report-r4.md / r4;
            all four preserved unmodified)
FEATURE: Add Product rebuild — apply the 24 approved A3-correct copy proposals + delete the page-wide footer copy
WORKTREE: /Users/alkebut/air/shipit-platform  (canonical checkout; Penpot is a live shared file)
BRANCH: main
BASE_SHA: b3e4c8b4bb7ad0b9c55583855cc2293efcedd8b7
HEAD_SHA: b3e4c8b4bb7ad0b9c55583855cc2293efcedd8b7
COMMITTED: NO
```

> ## The one line that matters
> **0 of 24 copy proposals and 0 of 52 footer deletions were applied by me — 0 mutations, 0 removals,
> 0 resizes, 0 renames.** I stopped on the first heartbeat error after 5 successful plugin calls.
>
> **But I must lead with the finding, not the zero: at least 3 of the 24 copy layers ALREADY carried the
> approved A3-correct strings when I read them, and no report on disk accounts for writing them.** The
> dispatch's precondition — *"no partial state from any prior round"* — is **false**, and I falsified it
> with my own reads rather than inheriting it. r1, r2, r3 and r4 all report zero; the git history reports
> zero; **the file says otherwise.**

**I did not create this state and I cannot certify it.** A guard I added for an unrelated reason — refusing
to re-apply a write that had already landed — is the only reason it was caught at all.

---

## 1. Probe result — the window opened, and I spent it correctly

**Method: the prescribed minimal scalar probe. Not `penpot_high_level_overview`.** The overview, API-info
and export tools were **never called** (r2's finding: the overview is static tool documentation with
different liveness preconditions and is not health evidence).

| # | call | method | result |
|---|---|---|---|
| 1 | `return penpotUtils.getPages().length;` | **minimal scalar probe** | **`1` — window ALIVE.** Fifth consecutive round to get past call 1 |
| 2 | guarded write, `Art Sub` `…a9b7ea0b85de` | 1 shape, `findShapeById` | **guard abort: `TEXT_DRIFT`** — layer already carries string **H** |
| 3 | guarded write, `Tech 0` `…a9b7e8f80ed1` | 1 shape | **guard abort: `ALREADY_APPLIED`** — already contains `secret manager` |
| 4 | guarded write, `L Sub` `…a9b7e08c7860` | 1 shape | **guard abort: `TEXT_DRIFT`** — layer already carries string **F** |
| 5 | 24-shape O(1) read, all 24 copy targets | 24 × `findShapeById`, **no traversal** | **MCP timeout** — see §2 |
| 6 | `return penpotUtils.getPages().length;` | **the one sanctioned recovery probe** | **heartbeat dormancy, 70 s** |
| 7 | — | — | **STOPPED. No third probe. No retry.** |

**All five productive calls were single-shape or a scalar.** No `findShapes` with a subtree traversal and
no broad predicate was issued at any point — r3's call-7 failure mode was not repeated. Call 5 was 24 × O(1)
id lookups, not a traversal; it still timed out, which is new information (§7, discovery 3).

---

## 2. The failure, exact text, and why there is no unknown-state write

| # | call | outcome | exact error text |
|---|---|---|---|
| 1 | call 5 — 24-shape read | **MCP request timeout** | `MCP error -32001: Request timed out` |
| 2 | call 6 — recovery probe | **dormancy (70 s)** | `The Penpot plugin tab appears to be suspended by the browser (no heartbeat for 70s). Please click/focus the Penpot tab to wake it, then retry.` |

**Stop discipline: one recovery probe after the first heartbeat error, then stop.** Call 6 was that probe
and it failed. I issued nothing further. Same precedent as r1 and r3.

### 2.1 🟢 The guarded outcome provably cannot have occurred — and this is structural, not luck

**Every one of my three write attempts returned from its guard clause *before* the assignment statement.**
The guards were ordered ahead of `s.characters = next`, and each returned a `why` with the live value:

| layer | guard that fired | where it returned | assignment reached? |
|---|---|---|---|
| `Art Sub` `…a9b7ea0b85de` | `!cur.startsWith('Generated here')` | **before** `s.characters=next` | **NO** |
| `Tech 0` `…a9b7e8f80ed1` | `cur.indexOf('secret manager')>=0` | **before** `s.characters=next` | **NO** |
| `L Sub` `…a9b7e08c7860` | `!cur.startsWith('A new keypair is generated here.')` | **before** `s.characters=next` | **NO** |

The mutation ledger is therefore **unambiguous rather than uncertain**: three writes were *attempted*, zero
were *executed*. This is the difference between r3 (which never reached a write) and this round (which
reached three and declined all three). **There is nothing to reconcile, because nothing changed.**

### 2.2 Why the guards existed — and the one that matters most

Every write was wrapped in four preconditions, in this order: `findShapeById(id)` non-null →
`type === 'text'` → `name` matches the r3 inventory exactly → the **current** `characters` matches r3's
recorded pre-write string → **`secret manager` is not already present** → then assign.

The last precondition is the one that did the work. It was written to satisfy the dispatch's rule *"on a
timeout, `findShapeById` that shape and check — **do not re-apply blind**"*, extended to apply on the
**pre-write** read as well. Without it, all three writes would have fired and **overwritten live
security-relevant copy that another actor had already set correctly** — and because this file has no
version history, that overwrite would have been **unrecoverable and silent**.

**I did not write these guards as a discovery instrument. I wrote them as ordinary write hygiene, and they
caught an undocumented state change that four reports and the dispatch all asserted did not exist.**

---

## 3. 🟥 The finding — an undocumented partial state exists, and the dispatch premise is falsified

### 3.1 What I read directly, in my own calls, before any error

All three layers are on **`BP · Rotate Key · Dark`** (`b5b63334-c22a-80a6-8008-a9b7dda85056`) — which the
draft names **the coherent three-layer set** and **THE PRIORITY**.

| layer | id | draft string | **what the live layer held when I read it** |
|---|---|---|---|
| `Art Sub` | `…a9b7ea0b85de` | **H** | `Generated on the server · the private half stays in the secret manager` — **H, verbatim, returned in full by the guard** |
| `Tech 0` | `…a9b7e8f80ed1` | **G** | contains `secret manager` — predicate true; **full text not captured** (that guard branch returns no value) |
| `L Sub` | `…a9b7e08c7860` | **F** | `A new keypair is generated on the server. You install the public half, then work resumes.` — **F, verbatim, returned in full** |

**Three layers, one board, the priority set, already correct. My session did not write them** (§2.1).

### 3.2 No report on disk accounts for it

| source | claim |
|---|---|
| `report.md` (r1) | zero mutations |
| `report-r2.md` | zero mutations |
| `report-r3.md` | *"0 of 24 copy proposals applied… **no write was ever issued**"* |
| **`report-r4.md` (17:00)** | *"**0 of 24 copy proposals applied.** …The 24 target layers carry their **original false custody strings**, byte-for-byte as r3 recorded them."* |
| `implement-add-product-custody-and-footer/report.md` | *"I touched no"* board; *"any Penpot board edit touching the footer copy"* out of grant |
| `review-…-final/report.md` | *"No lane in this work item had Penpot access"* |
| `correct-add-product-eyebrow-copy/report.md` | *"I have **no Penpot access**"* |
| **this dispatch** | *"The Manager re-verified this again minutes ago… **no partial state from any prior round**"* |
| **my own reads** | **3 of 24 carry the approved strings** |

**The dispatch's precondition is falsified.** Note exactly what the Manager verified: *52 footers, the
y-distribution, `root.children === 164`*. Those are **footer and page-level** checks. **The 24 copy layers
were never among them**, which is how a partial state survives a verification pass that is otherwise careful.

### 3.3 The most likely explanation — a hypothesis, explicitly not a fact

`b3e4c8b docs(state): Penpot connectivity check — **reconnected, served 3 calls**, died again; no partial state`
is **HEAD**. My session served **3 successful plugin calls before trouble (2–4), then died on call 5.**

Two candidate explanations, and I can distinguish neither from where I stand:

1. **A connectivity-check lane applied three copy writes** and its "no partial state" note did not account
   for them. The coincidence — *three calls served* — is suggestive and nothing more.
2. **A human edited the three layers in the browser** while the tab was focused. This file is a live shared
   artifact with a human in the loop, and the same human who must click the tab to wake the plugin is the
   only actor with continuous access.

**I am not asserting either.** What is established is the fact in §3.1 and its absence from every report.

### 3.4 Why this must not be "tidied up" by the next lane

The file has **no version history**. Consequently:

- The 3 applied layers are **not evidence that the apply lane works** — they may be correct by
  construction, or correct by luck, or one of the three may hold a *drifted* value. **I did not read
  `Tech 0`'s full text**, so I cannot even assert that all three are correct.
- The remaining **21 copy layers are UNKNOWN**. My 24-shape read timed out. **I will not extrapolate 3/24
  to 24/24 in either direction.**
- Re-applying all 24 blindly would **overwrite 3 layers that may be right**. That is the exact failure my
  guard prevented, and it is unrecoverable.

---

## 4. Mutation accounting — exactly what completed, exactly what did not

| group | planned | **completed by me** | attempted by me | failed | **unknown / in doubt** |
|---|---|---|---|---|---|
| copy writes (strings A–J) | **24** | **0** | **3** (all aborted pre-assignment) | 0 | **0 caused by me; 21 unexamined** |
| footer deletions | **52** | **0** | **0** | 0 | **0** |
| **total** | **76** | **0** | **3** | 0 | — |

**Independently of me**, 3 of the 24 copy layers were already written before my first call (§3.1).

**Mutations I did not issue, and did not attempt:** 0 `resize()`, 0 `setParentXY`, 0 `remove()`,
0 `clone()`, 0 renames, 0 re-parents, 0 board creates, 0 board deletes. **No geometry was touched on any
layer, so `R Submit Sub`'s box is untouched by definition.**

---

## 5. The 52 deletions — not started, and scope untouched

| item | value |
|---|---|
| `remove()` calls issued | **0** |
| footers deleted by me | **0** |
| `Disclose` census run by me | **NOT RUN** — my one census-class call (24-shape read) timed out |
| pre-write baseline check before the first `remove()` | **N/A — no `remove()` was ever reached** |

**y-values covered among the 52: none.** I deleted nothing, so I covered no y-value. The recorded
distribution remains **r3's: `862 ×48`, `910 ×2`, `926 ×2` = 52**, all named `Footer`, all `type: text`, all
`px 236` / `w 1020`. I did not re-derive it and I do not restate it as mine.

**`Disclose` — I cannot report 120 as verified.** My own count is **NOT OBTAINED**. The figure standing in
the record is second-hand from r3 and from the Manager: **116 exact + 4 `Disclose · single footer row` =
120**. Both forms must be tracked together; a strict-equality count reads 116 and would falsely report
four missing layers. **I neither confirmed nor disturbed it — I removed nothing, so I cannot have
disturbed it.**

---

## 6. Wrap check, the three flagged rows, and `R Submit Sub`

### 6.1 Post-apply measurements — none exist, and none is invented

**I obtained no settled `textBounds` read for any layer. Not one.** Every call that would have returned one
timed out (§1, call 5). Therefore:

| required measurement | this round |
|---|---|
| 24 × settled post-apply `textBounds` re-read, separate call | **NOT RUN — 0 obtained** |
| **layers that wrapped that the draft did not predict** | **CANNOT BE ENUMERATED.** Not "none" — **unknown**. The draft's 23 FITS / 1 flagged remain **predictions** |
| three flagged rows post-apply | **NOT MEASURED** |
| `R Submit Sub` line count after a copy write | **NOT MEASURED** |

**The honest statement:** the three layers I read (§3.1) carry the approved strings, and **I do not know
whether any of them now wraps**, because r3 measured them *pre-apply* and no post-apply read ever
succeeded. r3's §5.4 caution applies verbatim and I will not improve on it by assertion: *"no layer wrapped
that the draft did not predict" cannot be said about a file that has changed.*

### 6.2 The three flagged rows — still unmeasured, unchanged

| row | draft prediction | this round |
|---|---|---|
| `BPM · Product Credentials · F V 0` (⚠ **Sans 12**, not Mono) | 38.11 px in a **358** px box; grows 6 ch | **not measured** |
| `S · Product Credentials · No key · R Sub` | 26.92 px in 352; 4 ch shorter, low risk | **not measured** |
| `Art Sub` | 39.71 px in 380 — the row where the obvious choice fails | **live text is already H** (§3.1), but **`tbW`/`tbH` NOT measured**, so the wrap question is **open**, not answered |

### 6.3 `R Submit Sub` — option (a) intact, and satisfied by inaction

**Human decision stands: option (a) — accept the pre-existing overflow unchanged. Apply as drafted. Do NOT
resize the box (`352×15` stays `352×15`). I do not reopen it.**

- **I did not resize it.** I issued **no** `resize()`, no `setParentXY`, no geometry change of any kind, and
  I never read the layer (my 24-shape read timed out before returning). The box is **untouched by
  definition**, not by decision.
- r3's open finding stands unchanged and unmeasured this round: box `352×15`, `tbW 342.00`, **`tbH 25`**,
  `growType fixed` — **2 lines against a 15 px box, 10 px overflow, pre-existing, both boards**.
- **`tbW 342.00` is the widest rendered LINE (57 × 6.000), not the string width of 408.00.** Taking it at
  face value turns a 450 px proposal into a false "FITS". This governs any future verdict on this layer.
- Option (b) was never granted; its downstream check (`R Submit L` y364 vs `R Submit Sub` y398) is still
  **NOT_RUN**.

---

## 7. `SM - Add Product` boards — untouched, and certain from the mutation ledger

**The four `SM - Add Product` boards are APPROVED and were never edited. I issued zero mutations and never
addressed any `SM` id.** r3's verification is inherited and still valid: none of the four appears in either
target set, none carries a `Footer`, and each holds exactly one left-aligned `Disclose · single footer row`
at `parentX = 16`.

---

## 8. Build-side state — changed since r3, and it raises the stakes

**r3's §9 build-side census is no longer the whole story. The build has been implemented and merged.**

| commit | subject |
|---|---|
| `37aadc5` | `fix(add-product): correct the false key-custody copy and remove the forbidden footer copy` |
| `c32f4f4` | `Merge implement/add-product-custody-and-footer: …` |
| `f7c0dfb` | `docs(build): engineering review DO_NOT_MERGE on one string; correction restores the approved value` |
| `b3e4c8b` | `docs(state): Penpot connectivity check — reconnected, served 3 calls, died again; no partial state` ← **HEAD** |

**`main` advanced from `9fd935f` (r3, r4) to `b3e4c8b`.** All r3 §9 line numbers are now stale against
HEAD.

**Why this matters for the boards.** The shipped build now carries the A3-correct custody copy and no
forbidden footer note. **The boards are now the only surface still asserting the false custody claim** —
and 3 of the 24 boards layers have already been corrected by an unaccounted-for actor while 21 have not.
So the divergence r3 described as *boards lag build* has become *boards are the sole remaining defect*, and
the board file is in an undocumented, partly-applied, unversioned state. **This raises the cost of getting
it wrong, which is exactly the situation in which a partial result must be reported rather than chased.**

**I wrote no production source.** `apps/**` untouched by me; the above is read-only `git log`.

---

## 9. Files touched

```
docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r5.md   (this file — sole OWNED_PATH, created)
```

- **r1's `report.md`, `report-r2.md`, `report-r3.md` and `report-r4.md` are preserved unmodified.**
- No production source written. `apps/**`, `packages/**` untouched.
- `.decisions/**` and `docs/adr/**` untouched.
- Nothing committed, nothing pushed. Working tree: this one untracked file is the only change I made.

---

## 10. Validation results

| check | status | note |
|---|---|---|
| **liveness probe — minimal `execute_code` scalar** | **pass** | `getPages().length` → `1`. Not the overview; r2's finding applied |
| `penpot_high_level_overview` | **NOT CALLED** | r2: different liveness preconditions; not health evidence |
| **3 of the 24 copy targets found already carrying the approved string** | **pass — MATERIAL FINDING** | §3.1; `Art Sub` = H and `L Sub` = F returned **verbatim** |
| `Tech 0` full text captured | **partial** | `secret manager` predicate true; that guard branch returns no value |
| write-guard ordering (guards before assignment) | **pass** | 3/3 aborted pre-assignment; **0 mutations executed** |
| **the other 21 copy targets examined** | **NOT RUN** | 24-shape read timed out; **not extrapolated in either direction** |
| **24 copy proposals applied by me** | **NOT RUN — 0 of 24** | 3 attempted, 3 declined by guard |
| post-apply settled `textBounds` re-reads | **NOT RUN — 0 obtained** | every candidate call timed out |
| **layers that wrapped unexpectedly** | **CANNOT BE ENUMERATED** | **unknown**, not "none" — the file has changed and no read succeeded |
| three flagged rows post-apply | **NOT RUN** | §6.2 |
| `R Submit Sub` option (a) | **decision intact** | **not applied by me; box untouched — no `resize()` issued at all** |
| `R Submit Sub` pre-existing overflow | **not re-measured** | r3's `tbW 342.00` / `tbH 25` stands; wrapped-line caveat restated §6.3 |
| **52 footer deletions** | **NOT RUN — 0 of 52** | **0 `remove()` calls issued** |
| **`Disclose` baseline before first `remove()`** | **N/A** | no `remove()` was ever reached |
| **`Disclose` at 120 (116 + 4)** | **NOT RUN — own count NOT OBTAINED** | second-hand figure unchanged; **I removed nothing, so I cannot have disturbed it** |
| four `SM - Add Product` boards untouched | **pass** | zero mutations issued; no `SM` id addressed |
| `findShapes` traversal / broad predicate | **NEVER ISSUED** | all lookups were `findShapeById`; r3's failure mode not repeated |
| **any Penpot mutation** | **NOT RUN** | **0** `characters`, 0 `resize()`, 0 `setParentXY`, 0 `remove()`, 0 renames, 0 re-parents |
| **docker / compose** | **NEVER ISSUED** | **no command of any kind**, mutating or read-only. No `info`, no `ps`, no `logs`, no `config`. This rule was not tested. |
| shell commands run | read-only | `ls`, `sed -n`, `grep`, `git log`, `git rev-parse` only |
| commit / push | **NOT RUN** | nothing committed, nothing pushed |
| `.decisions/**`, `docs/adr/**` | **UNTOUCHED** | |
| r1–r4 preserved | **pass** | four prior reports unmodified |

---

## 11. Durable discoveries (for the Manager to route; this lane persists no knowledge base)

1. **🔴 CONTRADICTION — the grant's stated precondition was false, and it was falsified only by reading the
   target layers themselves.** The dispatch asserted *"no partial state from any prior round"*, re-verified
   *"minutes ago"*, naming **52 footers, the y-distribution and `root.children === 164`**. Those are
   **footer and page-level** measurements. **The 24 copy layers were never measured**, and three of them
   already carried the approved strings. **Generalisable: a "no partial state" verification is only as broad
   as the set it inspected. A census that covers one half of a grant cannot certify the other half, and
   "no partial state" is a claim about every target, not about the targets that were counted.**
2. **🔴 CONTRADICTION — five consecutive reports, a git history and a dispatch all record zero mutations,
   and the file records three.** No lane on disk claims writing them, and two reviewer lanes assert no lane
   in this work item ever had Penpot access. **A mutation with no owning report is invisible to every
   process that reads reports instead of the artifact.** For an unversioned shared file this is the worst
   possible failure class, because there is no `git diff` to ask.
3. **PROCESS_FACT — an idempotence guard in the *pre-write* read is what makes a re-apply safe against a
   file that changed underneath you.** The dispatch's rule covered the *timeout* case (*read it back before
   re-applying*). Extending the same read to *check the pre-write value against the recorded expectation*
   is strictly stronger, because it fires **before** the first attempt, needs no timeout, and cannot be
   defeated by a silent concurrent edit. **Recommended for every future apply lane against a live shared
   file: assert the recorded pre-state and assert the absence of the post-state, both before assigning.**
4. **DESIGN_DISCOVERY — a connectivity check that writes is not a connectivity check.** HEAD is
   `b3e4c8b docs(state): Penpot connectivity check — reconnected, served 3 calls, died again; no partial
   state`. Three layers on the priority board are already correct. **I cannot prove these are the same
   event and I am not asserting it** — but a liveness probe must be read-only *by construction*, so that
   its own conclusion cannot be the thing it got wrong. **Prefer `getPages().length` as the probe because
   it cannot mutate anything; that is now an argument for the minimal probe beyond transport reasons.**
5. **PROCESS_FACT — 24 × O(1) `findShapeById` in one call also timed out**, where r3's single 12-board read
   passed and its 24-traversal call failed. So the batch limit sits between 12 and 24 lookups **regardless of
   whether they are traversals or id lookups** — the cost is per-call request size, not subtree walking.
   **r3's prescription ("use `findShapeById`, one shape per call") is necessary but was not sufficient; the
   working batch is smaller than either report assumed.** Do not batch 24.
6. **PROJECT_FACT — `main` advanced `9fd935f` → `b3e4c8b`, and the build side is now merged** (`37aadc5`,
   `c32f4f4`), having already been through a `DO_NOT_MERGE` on one string. The build therefore carries the
   A3-correct custody copy and no forbidden footer note, which **inverts the boards-vs-build divergence**:
   the boards are now the only surface still asserting the false custody claim. All r3 §9 line numbers are
   stale against HEAD.
7. **PROJECT_FACT — `Disclose`'s count is matcher-dependent** (r3, carried forward and still load-bearing):
   **116 exact + 4 `Disclose · single footer row` = 120.** **A strict-equality count reads 116 and would
   falsely report four missing layers.** Both numbers are baseline pairs, never interchangeable.

---

## 12. Blockers

- **🔴 BLOCKER — undocumented partial board state.** At least **3 of the 24** copy layers (all on
  `BP · Rotate Key · Dark`) already carry the approved strings; **no report accounts for it**; the other
  **21 are unexamined**; the file has no version history. **Re-applying all 24 blindly would overwrite up
  to three layers that may already be correct, unrecoverably. This must be reconciled by reading the 24
  layers, not by writing them.**
- **🔴 BLOCKER — Penpot plugin heartbeat lost again (70 s), after 5 successful calls and one timeout.**
  0 of 24 copy proposals and 0 of 52 deletions applied. The window opened this time and the per-shape call
  discipline held for five calls; call 5 (24 × O(1) lookups) is the heaviest thing I did and it failed.
  **A human may still need to focus the tab, but the batch size must also come down** (§11.5).
- **🟥 OPEN FINDING (unchanged, unmeasured, not absorbed, not fixed) — `R Submit Sub` pre-existing 2-line /
  10-px box overflow**, both `S · Product Credentials · No key` boards. Option (a) remains the human's
  decision and stands; the box is **untouched**. **A copy fix cannot discharge a box defect on the same
  layer**, and no post-apply line count was ever read, so the wrap state of that layer is unknown.
- **NOT MEASURED / NOT OBTAINED, stated rather than assumed:** all 24 post-apply `textBounds`; the three
  flagged rows; `Tech 0`'s full current text; the identity and current text of the remaining 21 copy layers;
  the 52-footer census; the `Disclose` 120 baseline. **No figure in this report is inferred from a
  neighbouring measurement.**
- **MUST PRECEDE ANY FUTURE `remove()` — still true and still unexercised:** exact-name `Footer` **plus**
  `type === 'text'` re-asserted immediately before every `remove()` (76 `Footer Rule` **rectangles** share
  the prefix and a prefix match would delete all of them), and the `Disclose` **120 / 116** baseline pair
  checked before and after.
- **PROVENANCE NOTE** — `design-apply-f5-copy/prompt.md` still does not exist; dispatch arrived inline.
  Carried from r1 and unchanged. `BASE_SHA`/`HEAD_SHA` has now moved again, `9fd935f` → **`b3e4c8b`**.
- **SEPARATE GRANTS, unchanged from r3** — the build-side footer copy (now merged; r3's 11-sites-in-10-files
  figure needs re-measuring against HEAD, not re-reading from r3) and the 4 custody literals (now merged).
- **I cannot approve this work.** A lane that applies 76 mutations across 64 boards cannot certify them —
  and this round did not even apply them, but inherited three it cannot vouch for.

---

```
RESULT: DESIGN_REVISION_BLOCKED

FEATURE: Add Product rebuild — apply the 24 approved A3-correct copy proposals + delete the page-wide footer copy
BRIEF_ID: design-draft-f5-copy
REVISION_ID: design-apply-f5-copy / r5
REVISION_NUMBER: 5
BRANCH: main
BASE_SHA: b3e4c8b4bb7ad0b9c55583855cc2293efcedd8b7
HEAD_SHA: b3e4c8b4bb7ad0b9c55583855cc2293efcedd8b7

OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r5.md
READ_ONLY_PATHS:
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report.md, report-r2.md, report-r3.md, report-r4.md
  - docs/engineering/dispatch/tasks/design-draft-f5-copy/report.md
  - docs/engineering/dispatch/tasks/implement-add-product-custody-and-footer/report.md
  - docs/engineering/dispatch/tasks/review-implement-add-product-custody-and-footer*/report.md
  - docs/engineering/dispatch/tasks/correct-add-product-eyebrow-copy/report.md
  - git history (read-only)
PROHIBITED_PATHS:
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, docs/adr/**, WORK_STATE.md, LANES.md
  - report.md, report-r2.md, report-r3.md, report-r4.md (preserved unmodified)

ARTIFACT_PATHS:
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r5.md

RISK_LEVEL: 2
RISK_RATIONALE: >
  Level 2 (Feature UX Change), inherited from the grant under design-draft-f5-copy r1 and unchanged by
  anything this round did. The work mutates user-visible security claims in product copy on 24 layers of
  12 live shared boards and deletes 52 footer layers across 64 boards. No architecture, decision, interface
  or data change — 9417f8bf OPTION_C/A3 settled the substrate and ADR 0018 A2 recorded it. Not level 3: no
  workflow, navigation or IA change, nothing destructive. Not level 1: the copy asserts a security property
  a reader may rely on, and ADR 0018 A2 records that a wrong absolute is worse than an absent one.
  The level is asserted for the GRANT, not for this round's execution: this round issued 0 mutations, so
  its own realised risk is 0, and it did not lower the level because the unexplained 3-layer state makes
  the next write MORE consequential than a clean re-apply would be.

CHANGELOG: >
  r5 — zero mutations issued; stopped on the first heartbeat error after 5 successful plugin calls.
  Material finding: at least 3 of the 24 approved copy proposals (all on BP - Rotate Key - Dark, the draft's
  priority three-layer set) already carried the approved A3-correct strings when I read them, and no report
  on disk accounts for writing them — falsifying the dispatch's "no partial state from any prior round"
  precondition. 3 write attempts, all aborted by pre-write guards before assignment, because an idempotence
  guard fired on the pre-write read. 0 of 52 footer deletions; 0 remove() calls; Disclose census not run.
  0 post-apply textBounds obtained, so the wrap state of every copy layer is UNKNOWN, not clean. 0
  resizes, so R Submit Sub's box is untouched by definition and option (a) stands. New process findings: a
  "no partial state" check covering only footers cannot certify copy layers; a connectivity probe must be
  read-only by construction; and 24 O(1) lookups in one call also times out, so the safe batch is below 24.
  Build side observed merged at b3e4c8b, inverting the boards-vs-build divergence.

TRACEABILITY:
  REQUIREMENTS_COVERED:
    - Dispatch window strategy: probe once, findShapeById only, no subtree traversal, one shape per write,
      copy proposals before deletions — applied; the batch-size limit is now documented as lower (§11.5)
    - "A write timeout does not mean the write failed... do not re-apply blind" — honoured, and generalised
      to a pre-write idempotence guard, which is what caught the undocumented state
    - "If a heartbeat error appears: STOP... report exactly which of the 76 completed and which did not"
      — one recovery probe, then stop; §4 is that accounting
    - "Do not approve your own work" — honoured; READY_FOR_INDEPENDENT_DESIGN_REVIEW is NO
    - AGENTS.md shared-Docker-state rule — no Docker or Compose command issued of any kind
    - 27ea6536 no-footer-copy clause — NOT actioned (0 of 52 deleted); scope untouched
    - 9417f8bf OPTION_C / A3 and ADR 0018 -80-85 - read and applied to the three guard checks I could run;
      no copy text was authored or written by me
  REQUIREMENTS_GAPS:
    - The entire grant is unmet: 0 of 24 copy proposals and 0 of 52 footer deletions.
    - The 21 unexamined copy layers, the 52-footer census and the Disclose 120 baseline are all NOT RUN.
    - No post-apply fit evidence exists for any layer, so no wrap verdict is available in either direction.
    - Reconciling the unexplained 3-layer state is a prerequisite to any further write, not a follow-up to it.
    - G-7 reference-exposure remediation and A3-unavailability copy remain outside this grant (carried).

DESIGN_SYSTEM_COMPLIANCE: UNKNOWN
UX_ACCESSIBILITY_SCORE: UNKNOWN
IMPLEMENTATION_FEASIBILITY: HIGH

DISCOVERIES:
  - CONTRADICTION: the dispatch's "no partial state" precondition was false; it was verified against footers
    and root children but never against the 24 copy layers, and 3 already carry the approved strings
  - CONTRADICTION: five reports plus git history record zero mutations; the file records three, owned by none
  - PROCESS_FACT: a pre-write idempotence guard (assert recorded pre-state AND absence of the post-state,
    before assigning) prevents a blind re-apply without needing a timeout to trigger it
  - DESIGN_DISCOVERY: a connectivity check that writes is not a connectivity check; prefer a probe that
    cannot mutate by construction
  - PROCESS_FACT: 24 x O(1) findShapeById in one call times out too; the safe batch is below 24 regardless
    of traversal vs id lookup, so r3's prescription was necessary but not sufficient
  - PROJECT_FACT: main advanced 9fd935f -> b3e4c8b and the build side is merged, inverting the
    boards-vs-build divergence so the boards are the sole remaining surface asserting the false claim
  - PROJECT_FACT: Disclose's count is matcher-dependent - 116 exact + 4 suffixed = 120; track both forms

KNOWLEDGE_PERSISTED:
  none - this lane writes only its own report and performs no validation gate; discoveries are reported for
  the Manager to route under aef-repository-learning authority levels. The idempotence-guard pattern
  (discovery 3) is the strongest candidate for executable knowledge: a reusable guarded-assign helper that
  asserts the recorded pre-state and the absence of the post-state before every assignment to a live
  shared file. It generalises beyond Penpot.

BLOCKERS:
  - UNDOCUMENTED PARTIAL BOARD STATE: >=3 of 24 copy layers already carry the approved strings, owned by no
    report; 21 unexamined; no version history. Read before writing, never write to reconcile it.
  - Penpot heartbeat lost (70s) after 5 successful calls; 0 of 24 and 0 of 52 applied.
  - OPEN FINDING (unchanged): R Submit Sub pre-existing 2-line / 10-px box overflow on both
    S - Product Credentials - No key boards; option (a) stands; box untouched; post-apply line count never read.
  - NOT OBTAINED, stated not assumed: all 24 post-apply textBounds, the three flagged rows, Tech 0's full
    text, the other 21 layers' identity and text, the 52-footer census, the Disclose 120 baseline.
  - Still mandatory before any future remove(): exact-name Footer plus type === 'text' re-asserted per call
    (76 Footer Rule rectangles share the prefix), and the Disclose 120 / 116 baseline pair before and after.
  - PROVENANCE: design-apply-f5-copy/prompt.md still absent (carried from r1); HEAD moved 9fd935f -> b3e4c8b,
    so r3's build-side line numbers are stale.
  - This work is not certifiable by the lane that performs it, and this round additionally inherits three
    mutations it did not make and cannot vouch for.

READY_FOR_INDEPENDENT_DESIGN_REVIEW: NO
```