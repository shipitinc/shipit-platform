# Report — design-correct-f5-custody-copy (F5: the false key-custody string, 8 boards + BP measurement)

```
RESULT: DESIGN_REVISION_BLOCKED
TASK_ID: design-correct-f5-custody-copy
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — F5: false key-custody copy on 8 boards; measure the 2 BP boards
WORKTREE: /Users/alkebut/air/shipit-platform  (canonical checkout; Penpot is a live shared file)
BRANCH: main
BASE_SHA: 25b6ac3baf3cb098354a8be1b788af28ae58b448
HEAD_SHA: b0d645687817ef4aa96ceb1933979b5a86fb320a
COMMITTED: NO
```

**WHY `BLOCKED` AND NOT `COMPLETE`.** The one-string edit itself landed **8/8** — that part is done and
verified. Three things stop a green:

1. **The dispatch's own acceptance criterion provably CANNOT pass under the grant.** It demands
   *zero* remaining `keychain` / `created on this device` page-wide. After all eight edits,
   **12 layers across 10 boards still say `keychain`** and **4 layers across 4 boards still say
   `created on this device`** — none of them in my grant (§4, §5).
2. **I introduced a measurable visual regression** on both `BPM` boards (§6).
3. **Two post-edit confirmations are `NOT_RUN`** — Penpot went dormant before they completed (§8).

Reporting a green here would be a false green on all three counts.

---

## 1. Provenance

`main` advanced one commit since `verify-g18-desktop-boards` reported (`25b6ac3b…` → `b0d64568…`).
That lane's Penpot baseline reproduces exactly in my own enumeration (§2), so the advance is not a
board-state change. **No Docker or Compose command was issued — not `info`, not `ps`, not `logs`,
not `config`, none.** No production source written. Nothing committed, nothing pushed.

## 2. Board enumeration — my own `findShapes`, ids verbatim, never reconstructed

1 page `Page 1` (`d8ac01df-6646-81d2-8008-a366c09aa9d3`), **164 root children**, **160 boards**,
12 `Add Product` boards. Child counts match the `verify-g18-desktop-boards` baseline exactly.

| board | id | x,y | w×h | kids before |
|---|---|---|---|---|
| `BP · Add Product · Dark` | `b5b63334-c22a-80a6-8008-a998ffed44a5` | 9100, 7900 | 1280×900 | 65 |
| `BP · Add Product · Light` | `b5b63334-c22a-80a6-8008-a9a8f06e3586` | 9100, 8850 | 1280×900 | 65 |
| `S · Add Product · Unknown host · Light` | `b5b63334-c22a-80a6-8008-a9a96fc40fa5` | 10400, 11800 | 1280×900 | 68 |
| `S · Add Product · Unknown host · Dark` | `b5b63334-c22a-80a6-8008-a9a03d9da341` | 10400, 12750 | 1280×900 | 68 |
| `S · Add Product · Verified · Light` | `b5b63334-c22a-80a6-8008-a9a979cd8fbc` | 11700, 11800 | 1280×900 | 64 |
| `S · Add Product · Verified · Dark` | `b5b63334-c22a-80a6-8008-a9a04943d6ae` | 11700, 12750 | 1280×900 | 64 |
| `BPM · Add Product · Dark` | `b5b63334-c22a-80a6-8008-a9ac5f5ad2dc` | 5280, 9800 | 390×844 | 36 |
| `BPM · Add Product · Light` | `b5b63334-c22a-80a6-8008-a9ad42be419b` | 5280, 10750 | 390×844 | 36 |
| `SM - Add Product - Unknown host - Dark` | `6d055762-a70b-804c-8008-bf65e644269b` | 7550, 9800 | 390×844 | 44 |
| `SM - Add Product - Verified - Dark` | `6d055762-a70b-804c-8008-bf65f36b1c9a` | 8000, 9800 | 390×844 | 36 |
| `SM - Add Product - Unknown host - Light` | `6d055762-a70b-804c-8008-bf65ff750422` | 7550, 10750 | 390×844 | 44 |
| `SM - Add Product - Verified - Light` | `6d055762-a70b-804c-8008-bf660e124738` | 8000, 10750 | 390×844 | 36 |

⚠️ The id-substring trap is real and I avoided it: `…a9a03d9da341` (`S · Unknown host · Dark`)
appears inside `…a9ac5f5ad2dc` (`BPM · Dark`). **Every board was matched by exact full id AND by
asserted exact board name before any write.** A name mismatch would have aborted the call.

## 3. Reference string, read from the APPROVED `SM` set (read-only — never edited)

All four SM boards carry exactly one custody layer named `Art S`, `characters` verbatim:

```
ed25519 · generated on the server · the private half stays in the secret manager
```

80 chars, parentX 138, parentY 418, box 220×24, fontSize 10, `growType fixed`.

**Every write I issued derived the new string from this approved reference at runtime**
(`findShapeById(SM…).characters`), never from typing it, and asserted `length === 80 &&
includes('secret manager') && !includes('keychain')` before mutating. That makes the replacement
byte-identical to the approved artifact by construction, and it is why the middle dot and spacing
cannot have been corrupted.

⚠️ **Correction to the dispatch's arithmetic.** The old desktop string measures **73 chars**, not 75.
The replacement is 80. The old mobile string measures **44 chars**, not what a 75→80 framing
implies. Both figures below are measured, not assumed.

## 4. ⚠️⚠️ THE "TWO DISTINCT STRINGS" PREMISE IS FALSIFIED — THERE ARE FIVE, AND F5's SCOPE IS INCOMPLETE

The dispatch and `verify-g18-desktop-boards` §8 both assert the false claim lives in exactly **two**
full strings on exactly **8** boards. That is wrong, and it is wrong in a way that would have made a
"zero `keychain`" report a false green.

**`verify-g18-desktop-boards` swept all 160 boards but filtered on the substring
`private half stays in the keychain`.** The other false strings say *"this device's keychain"*,
*"held in the keychain"*, *"written to the keychain"*, *"never leaves the keychain"* — none matched
its filter. **A substring census keyed on the known-bad phrase is blind to sibling phrasings of the
same lie.** I swept with a deliberately broader needle (`keychain|key chain|secret manager|
created on this device`).

### 4a. Remaining `keychain` — 12 layers on 10 boards, ZERO in my grant

| board | layer | parentX/Y | characters |
|---|---|---|---|
| `BP · Add Product · Dark` | `Ev Body` | 254, 622 | `It clones over SSH. The private half stays in this device's keychain — never shown, logged or stored.` |
| `BP · Add Product · Light` | `Ev Body` | 254, 622 | *identical* |
| `S · Add Product · Verified · Dark` | `Ev Body` | 254, 622 | *identical* |
| `S · Add Product · Verified · Light` | `Ev Body` | 254, 622 | *identical* |
| `BP · Product Credentials · Dark` | `F V 0` | 236, 210 | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in this device's keychain` |
| `BP · Product Credentials · Light` | `F V 0` | 236, 210 | *identical* |
| `BPM · Product Credentials · Dark` | `F V 0` | 16, 192 | `GIT_PRODUCT_PR_SHIP_SSH  ·  held in the keychain` |
| `BPM · Product Credentials · Light` | `F V 0` | 16, 192 | *identical* |
| `BP · Rotate Key · Dark` | `Tech 0` | 236, 778 | `GIT_PRODUCT_PR_SHIP_SSH  ·  ed25519  ·  private half written to the keychain, never shown` |
| `BP · Rotate Key · Dark` | `Art Sub` | 410, 496 | `Generated here · the private half never leaves the keychain` |
| `BP · Rotate Key · Light` | `Tech 0` | 236, 778 | *identical* |
| `BP · Rotate Key · Light` | `Art Sub` | 410, 496 | *identical* |

### 4b. Remaining `created on this device` — 4 layers on 4 boards, ZERO in my grant

| board | layer | parentX/Y | characters |
|---|---|---|---|
| `BP · Product Credentials · Dark` | `Act What 0` | 406, 704 | `Key created on this device` |
| `BP · Product Credentials · Light` | `Act What 0` | 406, 704 | *identical* |
| `BPM · Product Credentials · Dark` | `Ev What 0` | 100, 458 | *identical* |
| `BPM · Product Credentials · Light` | `Ev What 0` | 100, 458 | *identical* |

**Six boards outside the `Add Product` family carry the false claim** — `BP · Product Credentials`
×2, `BPM · Product Credentials` ×2, `BP · Rotate Key` ×2 — and **none of them appears in my dispatch.**

**`BP · Rotate Key` is the most severe finding in this report.** `Art Sub` reads *"Generated here ·
the private half never leaves the keychain."* Under A3 the key is generated **on the server**, and
SHIP IT never holds key bytes at rest at all. That board states the exact inverse of the resolved
decision, on the screen whose entire purpose is key rotation.

**Why I edited none of them.** Every one is a different layer with body copy or a different screen's
copy, and no decision object specifies a replacement for any of them. Inventing replacements would
be a Level 2 content decision I am not authorised to make. **Routed to the owner.**

## 5. The eight edits — per-board before/after

Every write was a single `text.characters` assignment guarded by (a) an exact full-id lookup,
(b) an asserted exact board name, (c) an exact-current-characters match required to be **exactly 1**,
and (d) the 80-char/secret-manager guard on the replacement string. Any failure returned `aborted`
**before** mutating.

| # | board | layer | id | chars before → after | pos (before → after) | size | font | kids before → after |
|---|---|---|---|---|---|---|---|---|
| 1 | `BP · Dark` | `Key Meta` | `b5b63334-c22a-80a6-8008-a99fc37ff007` | **73 → 80** | 248,460 → same | 560×16 → same | 11 | **65 → 65** |
| 2 | `BP · Light` | `Key Meta` | `b5b63334-c22a-80a6-8008-a9a8f4269e28` | **73 → 80** | 248,460 → same | 560×16 → same | 11 | **65 → 65** |
| 3 | `S · Unknown host · Light` | `Key Meta` | `b5b63334-c22a-80a6-8008-a9a9759fb021` | **73 → 80** | 248,460 → same | 560×16 → same | 11 | **68 → 68** |
| 4 | `S · Unknown host · Dark` | `Key Meta` | `b5b63334-c22a-80a6-8008-a9a04411d63f` | **73 → 80** | 248,460 → same | 560×16 → same | 11 | **68 → 68** |
| 5 | `S · Verified · Light` | `Key Meta` | `b5b63334-c22a-80a6-8008-a9a97fe423d3` | **73 → 80** | 248,460 → same | 560×16 → same | 11 | **64 → 64** |
| 6 | `S · Verified · Dark` | `Key Meta` | `b5b63334-c22a-80a6-8008-a9a04eace034` | **73 → 80** | 248,460 → same | 560×16 → same | 11 | **64 → 64** |
| 7 | `BPM · Dark` | `Art S` | `b5b63334-c22a-80a6-8008-a9ac6184ec97` | **44 → 80** | 138,418 → same | 220×15 → same | 10 | **36 → 36** |
| 8 | `BPM · Light` | `Art S` | `b5b63334-c22a-80a6-8008-a9ad46117b59` | **44 → 80** | 138,418 → same | 220×15 → same | 10 | **36 → 36** |

**EVERY ONE OF THE 8 WAS ACTUALLY CHANGED — 8/8, not "only some".** Every board's child count is
unchanged, which is the correct signature for a text-only edit and is what distinguishes this from
the timed-out lane's deletion pass. Layer names, ids, positions, box sizes and font sizes are all
unchanged; **only `characters` moved.**

Independently corroborated: the post-edit page-wide census (§7) read the corrected string back
verbatim on all 8 boards.

### 5a. A timed-out write that DID execute — stated, not assumed

Edit #1's call returned **`MCP error -32001: Request timed out`**, after which Penpot went dormant.
I did **not** assume either outcome. A single idempotent read established that `BP · Dark`'s
`Key Meta` **had** already been changed to the 80-char string, children 65 → 65.

**This is the second time in this work item a Penpot write has timed out with the write having
landed.** Two for two, the timeout is on the *response* path, not the write path. **A future lane
must never treat a Penpot timeout as evidence that a write failed** — and must never re-apply
without reading first, which would double-write.

I also caused one self-inflicted abort: a mistyped layer id (`a998fc37ff007` for the correct
`a99fc37ff007`) made the guard dereference `null`. **It threw before any mutation, so `BP · Light`
was untouched** and the corrected call ran clean.

## 6. ⚠️ WRAP / OVERLAP — I INTRODUCED A REAL REGRESSION ON BOTH `BPM` BOARDS

Re-read `textBounds` settled after each write, as instructed.

### 6a. The six DESKTOP boards: NO WRAP, NO OVERLAP ✓

| board | rendered | single-line baseline (median, fontSize 11, same board) | box | horiz clearance | wrapped? | bottom vs next layer |
|---|---|---|---|---|---|---|
| `BP · Dark` | 392.78 × **14** | 14 | 560×16 | **167.22px** | **NO** | bottom 473, `Key Public` at 486 → **13px clear** |
| `BP · Light` | 392.78 × **14** | 14.5 | 560×16 | **167.22px** | **NO** | **13px clear** |
| `S · Unk host · Light` | 392.78 × **14** | 14.5 | 560×16 | **167.22px** | **NO** | **13px clear** |
| `S · Unk host · Dark` | 392.78 × **14** | 14 | 560×16 | **167.22px** | **NO** | **13px clear** |
| `S · Verified · Light` | 392.78 × **14** | 14.5 | 560×16 | **167.22px** | **NO** | **13px clear** |
| `S · Verified · Dark` | 392.78 × **14** | 14 | 560×16 | **167.22px** | **NO** | **13px clear** |

Rendered height equals the single-line baseline on all six, so no wrap. The 560-wide box absorbs
80 chars with 167px to spare. **Desktop is clean.**

### 6b. The two `BPM` boards: **WRAPPED TO TWO LINES, NOW OVERLAPPING `Key State`** ✗

`Art S` box is **220 × 15**. The replacement is 36 chars longer than the old mobile string and
leaves only **5.47px** horizontal clearance.

| board | rendered | single-line baseline (`Key State`, same fontSize 10 / lineHeight 1.2) | ratio | rendered span (board-rel) | `Key State` box top | **overlap** |
|---|---|---|---|---|---|---|
| `BPM · Dark` | 214.53 × **25** | **13** | **1.92×** | 417 → **442** | **436** | **6px — CONFIRMED** |
| `BPM · Light` | 214.53 × **25** | **13** | **1.92×** | 417 → **442** | **436** | **6px — CONFIRMED** |

**Proof it is two lines and not a measurement artefact:** on `BPM · Dark` I measured five sibling
text layers as controls — `Key State` (17 chars, fontSize 10) → **h 13**; `Art T` (26 chars,
fontSize 13) → **h 17**; `Art L1`/`Art L2` (8/12 chars, fontSize 11) → **h 14**. A single
fontSize-10 line on this board is **13**. `Art S` at **25** is **1.92×** that, i.e. two lines.

**This overlap is NEW.** Before the edit `Art S` was 44 chars ≈ 118px — unambiguously one line,
h ≈ 13, spanning 418 → ~431, clear of `Key State` at 436. After: 417 → 442, **colliding by 6px** with
`Not installed yet`. The horizontal extent is fine (352.53 ≤ 374 board content edge); the failure is
purely vertical.

**Why the `SM` boards do not have this problem, and `BPM` does:** the approved `SM` reference layer
is **220 × 24** — authored to hold this exact 80-char string at two lines' height. `BPM`'s `Art S`
is **220 × 15**, inherited from the shorter 44-char string. **The replacement string does not fit
`BPM`'s box; it fits `SM`'s.** The correct copy and the mobile *desktop-width* board are mismatched.

**I did NOT fix it.** The dispatch's instruction is explicit: report, do not shrink the font —
"that is a second edit you were not granted". Every available fix is a design decision I hold no
authority over: raise the box to 24 (geometry change), reduce fontSize (a typographic decision that
also degrades the eyebrow), move the layer down and re-flow `Key State` (layout change), or shorten
the copy (a Level 2 content decision). **Escalated for a grant.**

## 7. Page-wide string census after the edit — my own sweep, all 160 boards, 4 chunks

Chunked to stay inside the call budget, per `verify-g18-desktop-boards`' measured finding that a
single 6,823-layer page-wide sweep exceeds the timeout. `totalBoards = 160` re-derived
independently in chunks 3 and 4, after all eight edits.

| needle | before | after | where after |
|---|---|---|---|
| `secret manager` | **4** | **12** | 4 pre-existing (`SM` ×4) **+ 8 created by this pass** |
| `keychain` | 8 (per prior lanes' filtered census) | **12 layers / 10 boards** | §4a — **none in my grant** |
| `created on this device` | 6 (per prior lanes) | **4 layers / 4 boards** | §4b — **none in my grant** |

⚠️ **Correction to the dispatch's census arithmetic.** It asks me to confirm "8 occurrences of
`secret manager` where before there were 4". Measured: **12 total** — 4 pre-existing on the `SM`
boards plus the 8 this pass created. An 8-board edit cannot leave 8 total when 4 already existed;
that figure is short by 4 and, like the `68/68/64/64` error in the previous task's dispatch,
would have produced a false verdict if applied literally.

**Unrelated to F5, recorded so the method is auditable:** chunk 1 also matched 34 layers of
`on this device` — `"Signed in on this device"`, `"Saved as you, on this device"`,
`"you · on this device"`. These are **session/identity** copy, not key custody, and are unaffected
by A3. They are the reason the broad needle returned noise, and I narrowed it after chunk 1. **Not
a finding.**

## 8. THE FOUR `SM` BOARDS ARE UNTOUCHED — mobile revision 6's approval is INTACT ✓

| check | result |
|---|---|
| any write issued against an SM board | **NONE.** Every write asserted an exact board name (`BP ·`/`S ·`/`BPM ·`) before mutating; all four SM names begin `SM -` and could not match |
| custody layer after edit | all four read `ed25519 · generated on the server · the private half stays in the secret manager` — **correct, unchanged** (chunk 4, a completed post-edit read) |
| layer id / position / size | unchanged: parentX 138, parentY 418, 220×24, fontSize 10 |
| child counts | **44 / 36 / 44 / 36 measured at lane start**; post-edit re-measure **`NOT_RUN`** (dormancy, §9) |
| approval validity | **VALID — not invalidated.** Nothing outside the four `Add Product` → nothing on the approved set |

## 9. NOT REACHED / NOT RUN

- **Final gate call timed out** (`MCP error -32001`) then Penpot reported *"plugin tab appears to be
  suspended by the browser (no heartbeat for 72s)"*. Per the dispatch's dormancy rule I made **one**
  minimal recovery read, it failed the same way, and I **stopped rather than retrying**.
- Consequently **`NOT_RUN`**: (a) post-edit re-measure of the four SM child counts, (b) post-edit
  re-read of the page root-children count. Mitigating: `totalBoards = 160` was re-derived after the
  edits; all eight writes were `characters` assignments with child counts re-read in each edit
  call's post-state and unchanged; no structural operation was performed. **Stated as not-re-confirmed
  rather than asserted.**
- **No independent review.** A lane that writes to eight live shared design artifacts cannot certify
  them. This is that review's job.
- No code fix attempted (out of grant — §10). No analyzer, test or build run.

## 10. REPORTED FOR THE IMPLEMENTER — four false-claim sites in shipped code, not two

`apps/control_plane/lib/features/products/add_product_page.dart` — **read-only, not edited**:

| line | code | board counterpart |
|---|---|---|
| **542** | `'ed25519 \u00b7 created on this device \u00b7 the private half stays in the keychain'` | `Key Meta` (desktop) — **the string this pass corrected** |
| **1038** | *identical literal* | `Art S` (mobile) — **the string this pass corrected** |
| **480–481** | `"It clones over SSH. The private half stays in this device's "` + `'keychain \u2014 never shown, logged or stored.'` | `Ev Body` — **not corrected, still false on 4 boards** |
| **979–980** | *identical literal* | `Ev Body` (mobile path) — **not corrected** |

⚠️ The dispatch named `:542` and `:1038`. **There are four**, in two duplicated code paths
(desktop ≈ 481/542, mobile ≈ 980/1038), and the code mirrors the boards exactly. A fix scoped to
only `:542` and `:1038` would correct the eyebrow while leaving the body copy directly beneath it
asserting the opposite — on screen and in code at the same time.

The build fix is a separate lane with different `OWNED_PATHS`; **I wrote no production source.**

## 11. What changed and why

- **8 text layers across 8 boards** now carry the A3-correct custody string, replacing a security
  claim that was false: under `9417f8bf` OPTION_C / A3 the private half is neither on the device nor
  in any local keychain — it is not SHIP IT's at all.
- **No abstraction, state or interface change.** No `.decisions/**` or `docs/adr/**` touched. Nothing
  committed or pushed.

## 12. Validation results

| command | status | note |
|---|---|---|
| `penpotUtils.getPages()` → Page 1 | pass | 1 page, `d8ac01df-6646-81d2-8008-a366c09aa9d3` |
| page inventory (start) | pass | 164 root children, 160 boards, 12 `Add Product` |
| `totalBoards` post-edit | pass | 160, re-derived in census chunks 3 and 4 |
| 8 custody layers corrected | pass | 8/8, each `changed: true`, children unchanged |
| desktop wrap/overlap re-read | pass | no wrap, 167px clearance, 13px vertical clearance ×6 |
| **BPM wrap/overlap re-read** | **FAIL** | **wrapped to 2 lines; 6px overlap with `Key State` ×2 — §6b** |
| page-wide census (160 boards) | pass | 4 chunks; `secret manager` 4→12 |
| SM boards untouched | pass | no write issued; custody layer correct post-edit |
| **SM child counts post-edit** | **NOT_RUN** | dormancy — §9 |
| **page root-children post-edit** | **NOT_RUN** | dormancy — §9 |
| docker / compose | **NEVER ISSUED** | no command of any kind |
| dart analyze / tests / build | n/a | no production source written, out of grant |

## 13. Files touched

```
docs/engineering/dispatch/tasks/design-correct-f5-custody-copy/report.md   (this file — OWNED_PATHS)
```

Nothing else. **Only the 8 granted Penpot text layers were written.** No board renamed, moved,
deleted or re-parented. No production source written. Nothing committed, nothing pushed. The
pre-existing modified `apps/control_plane/test/failures/*.png` baselines were already dirty on
arrival and were not touched.

## 14. Durable discoveries (for the Manager to route; this lane persists no knowledge base)

1. **CONTRADICTION / PROJECT_FACT — a substring census keyed on the known-bad phrase is blind to
   sibling phrasings of the same lie.** `verify-g18-desktop-boards` swept all 160 boards filtering
   `private half stays in the keychain` and reported 8 hits / 2 strings. A broader needle finds
   **five** distinct false-custody strings on **16 layers across 16 boards**, including
   `BP · Rotate Key`'s *"Generated here · the private half never leaves the keychain"* — the exact
   inverse of the resolved decision, on the key-rotation screen. **Generalisable: when verifying
   that a class of false copy is gone, enumerate the class semantically, never grep for the one
   phrase you happened to be given.**
2. **DESIGN_DISCOVERY / PROJECT_FACT — the approved `SM` reference layer is 220×24; the `BPM`
   layer is 220×15.** The A3-correct 80-char custody string is two lines tall. It fits `SM` and
   overflows `BPM` by 6px into the `Key State` eyebrow. **A copy replacement approved on one
   platform's board is not thereby approved on another's** — the box must be re-checked per board,
   and the passing `SM` set actively camouflages the failing one because the string is identical.
3. **RUNTIME_DISCOVERY — a Penpot write timeout does not mean the write failed.** Second occurrence
   in this work item; both timed-out writes had landed. The timeout is on the response path. **Never
   re-apply on a timeout — read the layer first.**
4. **RUNTIME_DISCOVERY — reading `textBounds` in the same call that sets `characters` returns a
   STALE value** (measured: 350.26 before *and* after on `BP · Light`). Settled re-read required, in
   a separate call, to detect wrapping.
5. **PROCESS_FACT — measure the single-line baseline before calling a height change a wrap.** A raw
   `textBounds.height` is meaningless in isolation; `h=25` reads as plausible until five sibling
   controls on the same board establish that one line at that fontSize is `h=13`.
6. **WORKFLOW_IMPROVEMENT — two dispatch prompts in this work item have carried arithmetic that
   inverts or understates the verdict** (`68/68/64/64` vs `69/69/65/65`; `8 secret manager` vs a
   measured `12`). The before/after counts in a dispatch are now the least reliable input to a
   verification lane. Reconcile them against the writing lane's own persisted record first.

## 15. Unresolved issues and blockers

- **BLOCKER-1 — `BPM` overlap, needs a grant.** `Art S` wraps to 2 lines and overlaps `Key State`
  by 6px on `BPM · Light/Dark` (§6b). Fix options are all design decisions. **Routed to owner.**
- **BLOCKER-2 — F5's scope is incomplete.** 12 `keychain` layers / 10 boards and 4
  `created on this device` layers remain false (§4). Six of those boards — `BP · Product
  Credentials` ×2, `BPM · Product Credentials` ×2, `BP · Rotate Key` ×2 — **were never in scope.**
  `BP · Rotate Key` is the priority: it claims generation happens on the device.
- **BLOCKER-3 — the dispatch's zero-occurrence criterion is unsatisfiable as written** and must be
  restated as "zero on the 8 granted layers" before it can gate anything.
- **For the implementer — 4 code sites, not 2** (§10), including the `Ev Body` pair that a
  `:542`/`:1038`-only fix would leave contradicting the eyebrow directly beneath it.
- **For the decision owner — `BP`'s footer copy** (§16 of this report is the measurement; the
  question of whether `BP` is in `27ea6536`'s no-footer-copy scope remains a routing decision, and I
  did not touch it).
- Penpot dormancy blocked two confirmations (§9); both are low-risk but **unverified, not verified**.

## 16. BP FOOTER MEASUREMENT (read-only — **NO EDIT MADE beyond the granted custody string**)

**`27ea6536`'s no-footer-copy clause does NOT name the `BP` boards. They nonetheless carry footer
copy.** Both boards measured independently; identical in every respect measured.

| measurement | `BP · Dark` | `BP · Light` |
|---|---|---|
| **`Footer` layer type** | **`text` — COPY, not a divider** | **`text` — COPY** |
| `Footer` `characters` | `Your decision is recorded permanently. The same piece of work then continues — nothing is restarted.` (100 chars) | identical |
| `Footer` **position** | parentX **236**, parentY **862** | **236, 862** |
| `Footer` **size** | **1020 × 15** | **1020 × 15** |
| fontSize / lineHeight / align / growType | 10 / 1.2 / left / fixed | identical |
| rendered `textBounds` | **600 × 13** — single line, **no wrap**, fits the 1020 box | **600 × 12.5** — same |
| rendered right edge, board-relative | **836** | **836** |
| `Footer Rule` | **rectangle (divider)**, 236, 848, **1020 × 1** | identical |
| `Disclose` | text `Show technical details ▸`, 1036, 862, 220×15 | identical |
| `Disclose` right edge | **1256 = 236 + 1020 = content column right edge → RIGHT-ALIGNED ✓** | **1256 — same** |
| **visual overlap `Footer` vs `Disclose`** | **NONE — 200px clearance** (copy ends 836, disclosure box starts 1036) | **NONE — same** |

**The three questions asked, answered directly:**

1. **TEXT or RECTANGLE?** → **TEXT. It is copy** — the exact layer and the exact string the `S`
   boards' `Footer` carried, which is why G-18's deletion took those boards 69/65 → 68/64. `BP` was
   never in that lane's grant, so it retains it. **The divider is a separate layer, `Footer Rule`,
   correctly typed `rectangle`.**
2. **Position and size?** → parentX **236**, parentY **862**, **1020 × 15**; rendered 600 × 13 (Dark)
   / 600 × 12.5 (Light); fontSize 10, lineHeight 1.2, align left.
3. **Does it otherwise match `27ea6536`'s desktop clause (divider + right-aligned
   `Show technical details`)?** → **YES on both of those, and only those.** Divider present and
   correctly typed; `Disclose` right-aligned at 1256. The clause's **third** element — **no footer
   copy** — is **VIOLATED on both BP boards**, identically and at the same coordinates the `S`
   boards violated it.

**Reported, not acted on.** Any grant to change `BP` comes after this measurement.

**This is a scope gap for the decision owner, not a defect I may fix.** `27ea6536` names the four `S`
boards; the human's verbatim intent — *"Our Add product desktop should be the same way"* — reads as
covering desktop generally, and `BP` is desktop.

## 17. Cleanup confirmation

- [x] No process, container or compose project started by this lane — **no Docker/Compose command issued at all**
- [x] No temporary artifacts left behind
- [x] `git status --short` — no new tracked-file modifications from this lane
- [x] Nothing modified outside `OWNED_PATHS`, other than the 8 granted Penpot text layers
- [x] No board renamed, moved, deleted or re-parented

## 18. Recommended next action

```
HUMAN_DECISION_REQUIRED
```

Three items are outside any lane's authority and must not be routed into a correction loop: the
`BPM` overlap fix (BLOCKER-1), F5's true scope across the six out-of-scope boards including
`BP · Rotate Key` (BLOCKER-2), and the `BP` footer-copy scope question (§16). The 8 granted edits are
done and individually evidenced, but **this lane cannot approve its own work** and three of its
gates did not pass.