# Report r6 — design-apply-f5-copy (**0 mutations confirmed; one batch of 6 layers is in UNKNOWN state; transport died at call 3**)

```
RESULT: DESIGN_REVISION_BLOCKED
TASK_ID: design-apply-f5-copy
TASK_TYPE: design-apply
REVISION: r6 (supersedes report.md / r1, report-r2.md / r2, report-r3.md / r3, report-r4.md / r4,
            report-r5.md / r5; all five preserved unmodified)
FEATURE: Add Product rebuild — apply the 24 approved A3-correct copy proposals + delete the page-wide
         footer copy
WORKTREE: /Users/alkebut/air/shipit-platform  (canonical checkout; Penpot is a live shared file)
BRANCH: main
BASE_SHA: 3b4bb6a575855f53f1c473bdecc6f9b07d700c3a
HEAD_SHA: 3b4bb6a575855f53f1c473bdecc6f9b07d700c3a
COMMITTED: NO
```

> ## The one line that matters
> **0 of 24 copy proposals applied, 0 of 52 footer deletions. The window opened — the first probe
> succeeded on the sixth consecutive attempt — and my very first batch call, a 6-shape guarded
> read+write, timed out. Because that call contained writes, the state of 6 layers
> (`BP · Rotate Key` Dark + Light, all three layers each) is now UNKNOWN, not clean.** I issued one
> read-only recovery call to resolve it; that also timed out. I did not retry.
>
> **I did not obtain the deliverable that was asked for.** Zero of the 24 layers were read. The
> "which layers were already correct" table below is **inherited from r5 and the Manager, not measured
> by me**, and is labelled as such throughout. I will not present a partially-inherited census as my own.

---

## 1. Probe result — the window opened, and this is the sixth round to get past call 1

Method: the prescribed minimal scalar probe, **not** `penpot_high_level_overview` (never called).

| # | call | method | result |
|---|---|---|---|
| 1 | `return penpotUtils.getPages().length;` | **minimal scalar probe** | **`1` — ALIVE.** Sixth consecutive round to clear call 1 |
| 2 | guarded read+write, **6 shapes** (`BP · Rotate Key` Dark+Light: `Art Sub`, `Tech 0`, `L Sub` each) | 6 × `findShapeById`, **no traversal, no `findShapes`** | **MCP request timeout — ⚠ THIS CALL CONTAINED WRITES** |
| 3 | 6 × `findShapeById`, **`characters` only, zero writes** | O(1) reads | **MCP request timeout** |
| 4 | `return penpotUtils.getPages().length;` | **the one sanctioned liveness probe** | **dormancy, 72 s** |
| 5 | — | — | **STOPPED. No third probe. No retry.** |

**r3's failure mode was not repeated:** no `findShapes`, no subtree traversal, no broad predicate at
any point. Every access was `findShapeById`.

**Two findings from this call pattern, both new:**

1. **The batch limit is below 6 shapes when the call performs writes.** r3 read 12 boards in one call
   successfully. r5 found 24 × O(1) lookups too heavy. **I have now bracketed it from the other side:
   6 × O(1) with a guarded write per shape also times out.** The safe unit is **1 shape per call.**
2. **A read-only recovery call is not cheaper than the write call that preceded it.** Call 3 did
   strictly less work than call 2 (no geometry read, no `textBounds`, no assignment) and still timed
   out. **So "the write call was too heavy, the read will be light" is false here** — once the plugin
   has stalled, the next call is not reliably serviceable regardless of size. *Recovering state after a
   timed-out write cannot be assumed to be cheap.*

---

## 2. The failure, exact text, and the mutation ledger

| # | call | outcome | exact error text |
|---|---|---|---|
| 1 | call 2 — 6-shape guarded read+write | **MCP request timeout** | `MCP error -32001: Request timed out` |
| 2 | call 3 — read-only 6-shape recovery | **MCP request timeout** | `MCP error -32001: Request timed out` |
| 3 | call 4 — liveness probe | **dormancy (72 s)** | `The Penpot plugin tab appears to be suspended by the browser (no heartbeat for 72s). Please click/focus the Penpot tab to wake it, then retry.` |

### 2.1 🔴 MUTATION LEDGER — UNKNOWN, NOT ZERO. This is the honest entry.

| group | planned | completed by me | attempted | failed | **UNKNOWN — in doubt** |
|---|---|---|---|---|---|
| copy writes (strings A–J) | 24 | **0 confirmed** | **6** | 0 | **6** |
| footer deletions | 52 | **0** | 0 | 0 | 0 |
| **total** | **76** | **0 confirmed** | **6** | 0 | **6** |

**The 6 in-doubt layers** — all of `BP · Rotate Key`, Dark and Light, three layers each:

| # | board | layer | id |
|---|---|---|---|
| 1 | `BP · Rotate Key · Dark` | `Art Sub` | `b5b63334-c22a-80a6-8008-a9b7ea0b85de` |
| 2 | `BP · Rotate Key · Dark` | `Tech 0` | `b5b63334-c22a-80a6-8008-a9b7e8f80ed1` |
| 3 | `BP · Rotate Key · Dark` | `L Sub` | `b5b63334-c22a-80a6-8008-a9b7e08c7860` |
| 4 | `BP · Rotate Key · Light` | `Art Sub` | `b5b63334-c22a-80a6-8008-a9b8223c615c` |
| 5 | `BP · Rotate Key · Light` | `Tech 0` | `b5b63334-c22a-80a6-8008-a9b82130fa17` |
| 6 | `BP · Rotate Key · Light` | `L Sub` | `b5b63334-c22a-80a6-8008-a9b819bbdb21` |

### 2.2 Why I nonetheless assess the risk of damage as LOW — as reasoning, explicitly not as measurement

The guard was ordered ahead of the assignment, and an assignment is **unreachable** for any layer that
already carries the approved string:

```
if (post === cur)                    -> ALREADY,  return, no assign   <-- fires for all 6
if (cur.indexOf('secret manager')>=0) -> DRIFT_SM, return, no assign   <-- fires for all 6
```

Both conditions are already satisfied for all six layers by evidence that exists **independently of
this session**: r5 read `Art Sub` and `L Sub` on Dark and returned **H and F verbatim**, and returned
`secret manager`-predicate-true for `Tech 0`; the Manager then verified on the live file that **all
three layers of both boards carry the approved strings verbatim**. On that evidence **all six calls
would have declined before the assignment statement**, and the loop would have returned six `ALREADY`
rows with no mutation.

**I state this as inference from verified pre-state, not as an observed post-state.** The distinction
matters and I will not blur it: I have **no read-back of these 6 layers after call 2.** The next lane
must read them before assuming anything.

**The residual risk that inference does not cover:** if the file changed between the Manager's
verification and my call 2, or if a layer held some *other* value that satisfied the needles while
lacking `secret manager`, an assignment could have executed. In that case the write would have been
**the approved text** — so even the damaging branch lands on the intended string, not a corrupt one.
That is the specific reason this batch was safe to attempt at all: every reachable assignment target
was a byte-exact approved string derived by substitution from the layer's own current characters.

### 2.3 Stop discipline

Per *"if a heartbeat error appears: STOP… never retry"*, and r1/r3/r5's precedent of one recovery
attempt: call 3 was that attempt and it failed; call 4 established dormancy factually. **I issued
nothing further.**

---

## 3. 🔴 THE DELIVERABLE I WAS ASKED FOR — **NOT OBTAINED.** Read all 24 first; I read none.

> **⚠️ The table below is a PRE-READ PLAN, not a measurement. Every "current text" and "ALREADY
> correct?" cell in it is either quoted from r5 or from the Manager's verification — I did not read a
> single one of the 24 in this session. It is here so the next lane has the guard spec and the
> substitution table in one place, NOT as evidence.**

| # | layer | board(s) | current text *(inherited)* | approved text | was it ALREADY correct? *(inherited)* | did I write it? | post-write `textBounds` fit |
|---|---|---|---|---|---|---|---|
| 1 | `Art Sub` | `BP · Rotate Key` D/L | `Generated here · the private half never leaves the keychain` *(r3)* | **H** `Generated on the server · the private half stays in the secret manager` | **YES** — Dark read verbatim as H by **r5**; Light confirmed by **Manager** | **UNKNOWN** (in doubt) | **NOT OBTAINED** |
| 2 | `Tech 0` | `BP · Rotate Key` D/L | `GIT_PRODUCT_PR_SHIP_SSH  ·  ed25519  ·  private half written to the keychain, never shown` *(r3)* | **G** `GIT_PRODUCT_PR_SHIP_SSH  ·  ed25519  ·  private half in the secret manager, never shown` | **YES (predicate)** — r5 confirmed `secret manager` present; **full text never captured**; both boards confirmed by **Manager** | **UNKNOWN** (in doubt) | **NOT OBTAINED** |
| 3 | `L Sub` | `BP · Rotate Key` D/L | `A new keypair is generated here. You install the public half, then work resumes.` *(r3)* | **F** `A new keypair is generated on the server. You install the public half, then work resumes.` | **YES** — Dark read verbatim as F by **r5**; Light confirmed by **Manager** | **UNKNOWN** (in doubt) | **NOT OBTAINED** |
| 4 | `Ev Body` | `BP · Add Product` D/L | `It clones over SSH. The private half stays in this device's keychain — never shown, logged or stored.` *(r3)* | **A** `It clones over SSH. The private half stays in the secret manager — never shown, logged or stored.` | **UNKNOWN — never read by anyone** | **no** — not reached | **NOT OBTAINED** |
| 5 | `Ev Body` | `S · Add Product · Verified` D/L | *(same as #4)* | **A** | **UNKNOWN — never read by anyone** | **no** — not reached | **NOT OBTAINED** |
| 6 | `L Sub` | `BP · Product Credentials` D/L | `One key, for this product only. The private half never leaves this device.` *(r3)* | **B** `One key, for this product only. The private half stays in the secret manager.` | **UNKNOWN — never read by anyone** | **no** — not reached | **NOT OBTAINED** |
| 7 | `F V 0` | `BP · Product Credentials` D/L | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in this device's keychain` *(r3)* | **C/E** `GIT_PRODUCT_PR_SHIP_SSH  ·  held in the secret manager` | **UNKNOWN — never read by anyone** | **no** — not reached | **NOT OBTAINED** |
| 8 | `Act What 0` | `BP · Product Credentials` D/L | `Key created on this device` *(r3)* | **D** `Key generated on the server` | **UNKNOWN — never read by anyone** | **no** — not reached | **NOT OBTAINED** |
| 9 | `F V 0` | `BPM · Product Credentials` D/L | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in the keychain` *(r3)* | **C/E** `GIT_PRODUCT_PR_SHIP_SSH  ·  held in the secret manager` | **UNKNOWN — never read by anyone** | **no** — not reached | **NOT OBTAINED** |
| 10 | `Ev What 0` | `BPM · Product Credentials` D/L | `Key created on this device` *(r3)* | **D** `Key generated on the server` | **UNKNOWN — never read by anyone** | **no** — not reached | **NOT OBTAINED** |
| 11 | `R Sub` | `S · Product Credentials · No key` D/L | `Generate a keypair here, then install the public half on the repository.` *(draft §1b)* | **J** `Generated on the server — install the public half on the repository.` | **UNKNOWN — never read by anyone** | **no** — not reached | **NOT OBTAINED** |
| 12 | `R Submit Sub` | `S · Product Credentials · No key` D/L | `The private half stays on this device — you copy out the public half` *(r3)* | **I** `The private half stays in the secret manager — you copy out the public half` | **UNKNOWN — never read by anyone** | **no** — not reached | **NOT OBTAINED** |

**Rows 1–3 are 2 layers each on 2 boards, so rows 4–12 likewise expand ×2 = 24 total:**
#4 ×2, #5 ×2, #6 ×2, #7 ×2, #8 ×2, #9 ×2, #10 ×2, #11 ×2, #12 ×2 = **18**, plus rows 1–3 ×2 = **6**.
**6 + 18 = 24 ✓.**

### 3.1 How many were already correct — the answer that outlives this round

- **Measured by me: 0. I read none of the 24.**
- **Inherited: ≥ 6 of 24** — all six layers of both `BP · Rotate Key` boards, confirmed verbatim by the
  Manager directly on the live file (and 3 of those 6 read verbatim by r5).
- **Unknown: 18.** Never examined by any lane in this work item, by any report on disk.
- **Never observed, in any lane, by any report: whether the other 18 are clean or false.** Five prior
  rounds all recorded zero reads of them.

**The single most important fact in this report is a negative one: after six rounds, 18 of the 24
copy layers have never been read by anyone, and I did not reach them either.** The boards are the sole
surface asserting the false custody claim (the build side merged at `c32f4f4`), so 18 unexamined layers
means **the false claim may still be live on 12 boards**, and no report can say otherwise.

---

## 4. The guard spec — complete and ready for the next lane (this is durable work product)

The guard from r5, as I implemented it. **It fires before the assignment, and its second clause is
what makes re-apply safe.** Substitutions are expressed as needle→replacement against the layer's
**own current characters**, so the em dash (U+2014) and the `  ·  ` separator are never typed into a
source literal and byte-identity is structural, not hoped-for.

| # | layer | needle | replacement | produces |
|---|---|---|---|---|
| 1, 4 | `Art Sub` | `Generated here` → then `never leaves the keychain` | `Generated on the server` → then `stays in the secret manager` | **H** |
| 2, 5 | `Tech 0` | `private half written to the keychain, never shown` | `private half in the secret manager, never shown` | **G** |
| 3, 6 | `L Sub` (RK) | `generated here.` | `generated on the server.` | **F** |
| 7, 8 | `Ev Body` | `this device's keychain` | `secret manager` | **A** |
| 9, 10 | `L Sub` (PC) | `never leaves this device` | `stays in the secret manager` | **B** |
| 11, 12 | `F V 0` (both families) | `held in this device's keychain` (BP) / `held in the keychain` (BPM) | `held in the secret manager` | **C/E** |
| 13, 14 | `Act What 0` / `Ev What 0` | `created on this device` | `generated on the server` | **D** |
| 15, 16 | `R Sub` | `Generate a keypair here, then install` | `Generated on the server — install` | **J** |
| 17, 18 | `R Submit Sub` | `stays on this device` | `stays in the secret manager` | **I** |

**Guard, in order, for each shape:**
```
1. findShapeById(id)          -> null            => NO_SHAPE, return          (no assign)
2. s.type === 'text'         -> else            => NOT_TEXT,  return          (no assign)
3. every needle present      -> else            => NEEDLE_MISS, return        (no assign)
4. post === cur              -> true            => ALREADY,   return         (no assign)
5. cur contains 'secret manager' -> true         => DRIFT_SM,  return         (no assign)
6. s.characters = post                                     <-- only reachable assignment
```
**Clauses 4 and 5 together are the idempotence guard.** Clause 4 catches the layer-is-correct case;
clause 5 catches the layer-holds-some-other-secret-manager-copy case. **Both must precede the
assignment, not follow it.**

⚠️ **NEW WARNING from this round, which r3's and r5's guard specs did not contain:** clauses 3–5 each
call `.indexOf()`/`.replace()` on `characters`, and clause 6 assigns. **The read cost of this loop is
real, and 6 of them timed out.** Do not put more than **one shape** in a call. This is a transport
constraint, not a correctness one — the guard logic is sound and unchanged.

---

## 5. Footer deletions — not started, scope untouched

| item | value |
|---|---|
| `remove()` calls issued | **0** |
| footers deleted by me | **0** |
| `Disclose` census run by me | **NOT RUN** |
| `Disclose` before / after | **NOT OBTAINED / NOT OBTAINED** — I never reached a `remove()`, so I **cannot have disturbed it**. The figure standing in the record remains second-hand: **116 exact + 4 `Disclose · single footer row` = 120**. Both forms remain mandatory to check before and after the first deletion. |
| y-values covered | **none** |

**The preconditions for the deletions are unchanged and still unexercised:** 52 layers named exactly
`Footer`, all `type: text`, at `y = 862×48, 910×2, 926×2`; `nonTextNamed_Footer: []`; 76 `Footer Rule`
**rectangles** that a prefix match would delete. **Exact-name + `type === 'text'` must be re-asserted
immediately before every `remove()`** — a 52-delete loop has the same batch-size problem as the copy
loop and **must not be batched** either.

---

## 6. Wrap check — **NOT OBTAINED for any layer, in any direction**

| required measurement | this round |
|---|---|
| post-write settled `textBounds`, any layer | **NOT OBTAINED — 0 of 24** |
| **layers that wrapped that the draft did not predict** | **CANNOT BE ENUMERATED — UNKNOWN, not "none"** |
| three flagged rows (`BPM · F V 0`, `R Sub`, `Art Sub`) post-apply | **NOT MEASURED** |
| `R Submit Sub` line count after any write | **NOT MEASURED** |

The draft's 23 FITS / 1 flagged remain **predictions**. I did not write a single layer, so I introduce
no new fit evidence and I remove none.

### 6.1 `R Submit Sub` — option (a) intact; box untouched **by construction, not by decision**

- **I issued no `resize()`, no `setParentXY`, no geometry call of any kind.** The `352×15` box is
  untouched — the only geometry-adjacent thing my code did was *read* `s.width`/`s.height`.
- Option (a) stands: apply as drafted, **do not resize.** I do not reopen it.
- r3's open finding stands unmeasured: box `352×15`, `tbW 342.00`, **`tbH 25`** — already 2 lines,
  10 px overflow, pre-existing, both boards. **`tbW 342.00` is the widest rendered LINE (57 × 6.000),
  not the string width of 408.00** — taking it at face value turns the 450 px proposal into a false
  "FITS". Option (b) still not granted; its downstream check (`R Submit L` y364 vs `R Submit Sub` y398)
  still NOT_RUN.

---

## 7. `SM - Add Product` boards — untouched, certain

The four `SM - Add Product` boards are APPROVED and were never edited. **I never addressed a single `SM`
id**, and no `SM` id appears in my in-doubt set (§2.1), which is composed entirely of
`BP · Rotate Key` ids. Zero mutations confirmed by me.

---

## 8. Files touched

```
docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r6.md   (this file — sole OWNED_PATH, created)
```

- **r1–r5 preserved unmodified** (`report.md`, `report-r2.md`, `report-r3.md`, `report-r4.md`,
  `report-r5.md`).
- No production source written. `apps/**`, `packages/**` untouched.
- `.decisions/**` and `docs/adr/**` untouched.
- Nothing committed, nothing pushed. This one untracked file is the only change I made.

---

## 9. Validation results

| check | status | note |
|---|---|---|
| **liveness probe — minimal `execute_code` scalar** | **pass** | `getPages().length` → `1`. Not the overview; never called |
| `penpot_high_level_overview` | **NOT CALLED** | r2: different liveness preconditions; not health evidence |
| `findShapes` traversal / broad predicate | **NEVER ISSUED** | all access via `findShapeById`; r3's failure mode not repeated |
| **the 24 copy layers read** | **NOT RUN — 0 of 24** | §3. **The deliverable was not obtained** |
| **copy proposals applied by me** | **0 confirmed; 6 UNKNOWN** | §2.1 — a timed-out call containing writes |
| **the 6 in-doubt layers read back** | **NOT RUN** | the recovery read (call 3) also timed out |
| guard clause ordering (all checks before assignment) | **pass by construction** | §4; but **not exercised** — no return value was ever received |
| post-apply settled `textBounds` re-reads | **NOT RUN — 0 obtained** | every candidate call timed out |
| **layers that wrapped unexpectedly** | **CANNOT BE ENUMERATED** | **unknown**, not "none" |
| three flagged rows post-apply | **NOT RUN** | §6 |
| `R Submit Sub` option (a) | **decision intact** | not applied by me; **no `resize()` issued at all** |
| `R Submit Sub` pre-existing overflow | **not re-measured** | r3's `tbW 342.00` / `tbH 25` stands; wrapped-line caveat restated §6.1 |
| **52 footer deletions** | **NOT RUN — 0 of 52** | **0 `remove()` calls issued** |
| `Disclose` before / after | **NOT OBTAINED / NOT OBTAINED** | no `remove()` reached, so it cannot have been disturbed |
| four `SM - Add Product` boards untouched | **pass** | no `SM` id addressed; none in the in-doubt set |
| **any confirmed Penpot mutation** | **NONE** | 0 `characters`, 0 `resize()`, 0 `setParentXY`, 0 `remove()`, 0 renames, 0 re-parents |
| **docker / compose** | **NEVER ISSUED** | **no command of any kind**, mutating or read-only. No `info`, no `ps`, no `logs`, no `config`. This rule was not tested. |
| shell commands run | read-only | `git rev-parse`, `git log --oneline`, `git status --porcelain` only |
| commit / push | **NOT RUN** | nothing committed, nothing pushed |
| `.decisions/**`, `docs/adr/**` | **UNTOUCHED** | |
| r1–r5 preserved | **pass** | five prior reports unmodified |

---

## 10. Durable discoveries (for the Manager to route; this lane persists no knowledge base)

1. **🔴 CONTRADICTION — the grant's "starting state is clean" premise is now falsified from the other
   side too, and I add no evidence for it.** The Manager's own `3b4bb6a` (HEAD) records *"at least 6 of
   24 F5 copy proposals were already applied, owned by no report."* Six prior reports and now a HEAD
   commit state that **18 of the 24 copy layers have never been read by any lane**, while the build
   side has merged and the boards are therefore the **sole remaining surface asserting the false
   custody claim.** **Generalisable: a shared-file apply grant must open by reading every target, not
   by counting the ones a census happens to cover. Footer and page-level checks certify nothing about
   copy layers — r5 proved that, and this round confirms nobody did the follow-up read.**
2. **🔴 PROCESS_FACT — the batch limit is bracketed on BOTH sides now: 12 O(1) reads pass (r3),
   24 O(1) reads fail (r5), and 6 O(1) read+writes fail (this round).** The safe unit is **one shape
   per call.** Six rounds have now produced this same finding in three different directions, and the
   practical consequence has not changed: **76 single-shape calls do not fit in one five-call window.**
   The dispatch's window strategy and the mutation count are incompatible at the observed rate, and
   that is an arithmetic fact about the transport, not a matter of call discipline.
3. **🔴 PROCESS_FACT — a read-only recovery call is NOT cheaper than the write call it follows, once
   the plugin has stalled.** My recovery read did strictly less work than the write batch (no
   geometry, no `textBounds`, no assignment) and timed out identically. **So a timed-out write cannot
   be cheaply reconciled afterwards** — which upgrades the cost of a write-timeout from "slow" to
   "unknown and not cheaply recoverable." **Prefer: read and verify every target BEFORE issuing any
   write, in calls small enough to survive, so no write is ever in flight when the window closes.**
   This is the inverse of the dispatch's stated priority order (copies first, deletions last) and I
   now think the priority order is backwards for this transport.
4. **DESIGN_DISCOVERY — express approved copy as needle→replacement against the layer's own current
   characters, never as a typed literal.** The separators are `  ·  ` (two spaces, U+00B7, two spaces)
   and the dash is U+2014 EM DASH. Deriving them by substitution makes byte-identity structural, keeps
   G-7 exposure impossible to widen by a typo, and — the reason it matters here — **guarantees that
   even the damaging branch of a guard lands on an approved string rather than a corrupt one.** That
   property is what made it defensible to attempt a batched write at all.
5. **PROCESS_FACT — a connectivity check that writes is not a connectivity check** (r5, re-confirmed as
   still unaddressed at `3b4bb6a`). `main` has advanced `b3e4c8b` → **`3b4bb6a`**, and the new HEAD
   commit is itself a *state note about unowned board mutations* — the repository is now formally
   recording that it has lost track of live board state. That is a governance signal, not a copy issue.
6. **PROJECT_FACT — `Disclose`'s count is matcher-dependent** (r3 → r5, still load-bearing):
   **116 exact + 4 `Disclose · single footer row` = 120.** A strict-equality count reads 116 and would
   falsely report four missing layers. Track both, before and after.
7. **PROJECT_FACT — the safe-batch ceiling is the binding constraint on this entire grant, and six
   rounds of evidence now bounds it.** The honest planning number is: **a five-call window affords
   ~4 productive single-shape calls after one probe and one recovery attempt.** At that rate the grant
   needs **~20 windows**, or the transport must change. Continuing to re-dispatch the same 76-mutation
   grant against a five-call window is not converging.

---

## 11. Blockers

- **🔴 BLOCKER — 6 layers in UNKNOWN state** (`BP · Rotate Key` Dark+Light, `Art Sub`/`Tech 0`/`L Sub`
  each, §2.1). A call containing writes timed out; the read-only recovery also timed out. **Risk assessed
  LOW by inference (§2.2), not measured.** **Read these 6 before any further write on this board.**
- **🔴 BLOCKER — Penpot heartbeat lost (72 s) after 1 successful call and 2 timeouts.** **0 of 24
  confirmed applied, 0 of 52 deleted.** The window opened for the first time in six rounds and the
  batch was still too heavy.
- **🔴 BLOCKER — the requested deliverable was not produced: 0 of the 24 copy layers were read.** 18 of
  them have now never been read by any lane in six rounds. The "which were already correct" finding —
  the one thing that outlives the round — remains **≥6 inherited, 18 unknown.**
- **🟥 OPEN FINDING (unchanged, unmeasured, not absorbed, not fixed) — `R Submit Sub` pre-existing 2-line
  / 10-px box overflow**, both `S · Product Credentials · No key` boards. Option (a) stands; the box is
  untouched (no geometry call issued at all). Post-write line count never read.
- **NOT OBTAINED, stated rather than assumed:** all 24 post-write `textBounds`; the three flagged rows;
  the current text of all 18 unexamined layers; a read-back of the 6 in-doubt layers; the 52-footer
  census; the `Disclose` before/after pair. **No figure in this report is inferred from a neighbouring
  measurement**, and §3 is labelled inherited throughout.
- **MUST PRECEDE ANY FUTURE `remove()` — still true, still unexercised:** exact-name `Footer` **plus**
  `type === 'text'` re-asserted immediately before every call (76 `Footer Rule` **rectangles** share the
  prefix), and the `Disclose` **120 / 116** baseline pair checked before and after. **And per §10.3, one
  shape per call.**
- **PROVENANCE NOTE** — `design-apply-f5-copy/prompt.md` still does not exist; dispatch arrived inline.
  Carried from r1. **`HEAD` moved again: `b3e4c8b` (r5) → `3b4bb6a`**, and the new commit is the state
  note recording the unowned board mutations.
- **I cannot approve this work.** A lane that attempts mutations against a live shared file cannot
  certify them — and this round's own ledger is **UNKNOWN, not zero**, which is precisely the condition
  that makes self-certification untenable.

---

```
RESULT: DESIGN_REVISION_BLOCKED

FEATURE: Add Product rebuild — apply the 24 approved A3-correct copy proposals + delete the page-wide footer copy
BRIEF_ID: design-draft-f5-copy
REVISION_ID: design-apply-f5-copy / r6
REVISION_NUMBER: 6
BRANCH: main
BASE_SHA: 3b4bb6a575855f53f1c473bdecc6f9b07d700c3a
HEAD_SHA: 3b4bb6a575855f53f1c473bdecc6f9b07d700c3a

OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r6.md
READ_ONLY_PATHS:
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report.md, report-r2.md, report-r3.md, report-r4.md, report-r5.md
  - docs/engineering/dispatch/tasks/design-draft-f5-copy/report.md
  - the 24 target Penpot layers (read/write only under the §4 guard; 6 currently in doubt)
  - the 52 `Footer` Penpot layers (in scope; 0 deleted by me)
  - git history (read-only)
PROHIBITED_PATHS:
  - the four SM - Add Product boards (APPROVED - never edited)
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, docs/adr/**, WORK_STATE.md, LANES.md
  - report.md, report-r2.md, report-r3.md, report-r4.md, report-r5.md (preserved unmodified)

ARTIFACT_PATHS:
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r6.md

RISK_LEVEL: 2
RISK_RATIONALE: >
  Level 2 (Feature UX Change), inherited from design-draft-f5-copy r1 and unchanged by anything this
  round did. The grant mutates user-visible security claims in product copy on 24 layers of 12 live
  shared boards and deletes 52 footer layers across 64 boards. No architecture, decision, interface or
  data change - 9417f8bf OPTION_C/A3 settled the substrate and ADR 0018 A2 recorded it. Not level 3: no
  workflow, navigation or IA change, nothing structurally destructive. Not level 1: the copy asserts a
  security property a reader may rely on, and ADR 0018 A2 records that a wrong absolute is worse than
  an absent one because a trusting reader stops looking for the real exposure. The level is asserted for
  the GRANT, not for this round's execution: this round issued no confirmed mutation, so its realised
  risk is 0, and it did NOT lower the level because the 6 in-doubt layers make the next write MORE
  consequential than a clean re-apply would be.
CHANGELOG: >
  r6 - no confirmed mutation; 6 layers in UNKNOWN state after a timed-out batched write; transport died at
  call 3. The liveness probe succeeded on the sixth consecutive attempt, then a 6-shape guarded
  read+write batch timed out, a read-only 6-shape recovery also timed out, and the sanctioned probe
  reported 72s dormancy. Stopped without retry. 0 of 24 copy layers were read - the requested deliverable
  was NOT obtained, and the 24-row table is labelled inherited-from-r5-and-the-Manager throughout, never
  presented as my own measurement. 0 of 52 footer deletions; 0 remove() calls; Disclose before/after both
  NOT OBTAINED and undisturbed by construction. New bounded findings: the safe batch is now bracketed on
  both sides (12 O(1) reads pass, 24 fail, 6 read+writes fail) so the unit is ONE shape per call; and a
  read-only recovery call is not cheaper than the write call it follows, which upgrades a write timeout
  from slow to unknown-and-not-cheaply-recoverable and inverts the dispatch's copies-before-deletions
  priority order. Durable work product: the complete 18-needle substitution table and the 6-clause guard
  spec, with the derivation-by-substitution rule that guarantees even the damaging branch lands on an
  approved string.

TRACEABILITY:
  REQUIREMENTS_COVERED:
    - Dispatch window strategy: probe once, findShapeById only, no traversal, ~5-6 calls per batch,
      bank after each batch - probe and call discipline honoured; the batch limit is now documented as
      ONE shape per call, which the dispatch's own target of 76 mutations cannot satisfy
    - "a write timeout does not mean the write failed... do not re-apply blind" - honoured: the only
      call after the timeout was read-only, and the in-doubt set is reported rather than re-applied
    - "if a heartbeat error appears: STOP... report precisely which layers you read, which you wrote,
      and which you did not reach" - honoured: one read-only recovery attempt, then stop; sections 2, 3
      and 11 are that accounting
    - "R Submit Sub is settled as option (a): apply as drafted, do NOT resize its box" - honoured in the
      strongest available form: no geometry call of any kind was issued, so the 352x15 box is untouched
    - "Do not approve your own work" - honoured; READY_FOR_INDEPENDENT_DESIGN_REVIEW is NO
    - AGENTS.md shared-Docker-state rule - no Docker or Compose command issued of any kind
    - "the four SM - Add Product boards are APPROVED - never edit one" - honoured; no SM id addressed
  REQUIREMENTS_GAPS:
    - The entire grant is unmet: 0 of 24 copy proposals confirmed applied, 0 of 52 footer deletions.
    - THE REQUESTED FINDING WAS NOT PRODUCED: 0 of the 24 layers read. 18 of them have never been read by
      any lane in six rounds.
    - The state of the 6 in-doubt BP - Rotate Key layers is unresolved and must be read before any
      further write on that board.
    - No post-write fit evidence exists for any layer, so no wrap verdict is available in either direction.
    - Reconciling the unexplained >=6-layer state remains a prerequisite to writing, not a follow-up.
    - G-7 reference-exposure remediation and A3-unavailability copy remain outside this grant (carried).

DESIGN_SYSTEM_COMPLIANCE: UNKNOWN
UX_ACCESSIBILITY_SCORE: UNKNOWN
IMPLEMENTATION_FEASIBILITY: HIGH

DISCOVERIES:
  - CONTRADICTION: after six rounds, 18 of the 24 copy layers have never been read by any lane, while the
    build side has merged and the boards are the sole remaining surface asserting the false custody claim
  - PROCESS_FACT: the safe batch is bracketed on both sides - 12 O(1) reads pass, 24 fail, 6 O(1)
    read+writes fail - so the unit is one shape per call, and 76 mutations cannot fit a five-call window
  - PROCESS_FACT: a read-only recovery call is not cheaper than the write call it follows once the plugin
    has stalled, so a timed-out write is unknown and not cheaply recoverable; verify-then-write beats
    write-then-reconcile for a live shared file
  - DESIGN_DISCOVERY: express approved copy as needle->replacement against the layer's own characters so
    byte-identity is structural and even a guard's damaging branch lands on an approved string
  - PROJECT_FACT: main advanced b3e4c8b -> 3b4bb6a, and the new HEAD commit is itself a state note
    recording board mutations owned by no report
  - PROJECT_FACT: Disclose's count is matcher-dependent - 116 exact + 4 suffixed = 120; track both forms

KNOWLEDGE_PERSISTED:
  none - this lane writes only its own report and performs no validation gate; discoveries are reported
  for the Manager to route under aef-repository-learning authority levels. The strongest candidate for
  executable knowledge is the section 4 guard: a reusable guarded-assign helper that performs
  needle->replacement derivation plus the pre-assignment idempotence clauses, at one shape per call. It
  generalises to any live shared design file, not just Penpot.

BLOCKERS:
  - 6 LAYERS IN UNKNOWN STATE: BP - Rotate Key Dark+Light, Art Sub / Tech 0 / L Sub each, ids in
    section 2.1. A call containing writes timed out and the read-only recovery also timed out. Risk
    assessed LOW by inference from verified pre-state, NOT measured. Read before any further write.
  - Penpot heartbeat lost (72s) after 1 successful call and 2 timeouts; 0 of 24 confirmed applied, 0 of 52
    deleted. The window opened for the first time in six rounds and the batch was still too heavy.
  - THE REQUESTED DELIVERABLE NOT PRODUCED: 0 of 24 layers read; 18 never read by any lane.
  - OPEN FINDING (unchanged): R Submit Sub pre-existing 2-line / 10-px box overflow on both
    S - Product Credentials - No key boards; option (a) stands; no geometry call issued; post-write line
    count never read.
  - NOT OBTAINED, stated not assumed: all 24 post-write textBounds, the three flagged rows, the current
    text of all 18 unexamined layers, a read-back of the 6 in-doubt layers, the 52-footer census, the
    Disclose 120/116 baseline pair before and after.
  - Still mandatory before any future remove(): exact-name Footer plus type === 'text' re-asserted per
    call (76 Footer Rule rectangles share the prefix), the Disclose 120 / 116 pair checked before and
    after, and one shape per call.
  - PROVENANCE: design-apply-f5-copy/prompt.md still absent (carried from r1); HEAD moved b3e4c8b ->
    3b4bb6a, whose commit is the state note recording the unowned board mutations.
  - This work is not certifiable by the lane that performs it, and this round's own ledger is UNKNOWN
    rather than zero.

READY_FOR_INDEPENDENT_DESIGN_REVIEW: NO
```