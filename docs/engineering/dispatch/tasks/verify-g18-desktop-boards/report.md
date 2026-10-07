# Report — verify-g18-desktop-boards (independent read-only verification of the timed-out edit)

Persisted per `aef-orchestrator` §14. Lane: `design-reviewer`, task type `review`.
**I changed NOTHING.** No Penpot board was edited, renamed, deleted or moved. No Docker/Compose
command was issued. No production source written. Nothing committed or pushed.

```
RESULT: DESIGN_REVIEW_APPROVED

REVIEWED_HEAD: 25b6ac3baf3cb098354a8be1b788af28ae58b448  (branch `main`, matches the design lane's claimed HEAD_SHA)
REVISION_ID: n/a — this lane reviewed a live Penpot artifact state, not a Design Revision body.
              The owning revision is the keys lane's d26658219dea4955b0d2b4004a70aa4d.
```

---

## ⚠ THE DISPATCH PROMPT'S DECISIVE PREMISE IS WRONG. READ THIS BEFORE THE NUMBERS.

The dispatch told me to decide the outcome this way:

> "IF the pre-edit was 68/68/64/64 WITH one `Footer` layer each, then 68/68/64/64 now means THE EDIT DID
> NOT RUN, and 67/67/63/63 means it ran. **THAT SINGLE NUMBER DECIDES WHETHER THE EDIT HAPPENED AT ALL.**"

**That premise does not match the only surviving record of the before-state.** The design lane's own
§2/§3 — which the dispatch itself instructed me to read *first* and calls "the only record of the
before-state" — record:

| | lane §1 (BEFORE) | lane §3 (EXPECTED AFTER) |
|---|---|---|
| `S · Unknown host · Light/Dark` | **69 / 69** | **68 / 68** |
| `S · Verified · Light/Dark` | **65 / 65** | **64 / 64** |

The lane's §5.1 guard block independently re-asserts "board child count equals the recorded BEFORE
value (69/69/65/65)". The lane's record is internally consistent: **69 → 68**.

The dispatch's version dropped the *before* by one per board and asserted a 68→67 expectation that
the lane never specified. **The arithmetic in the dispatch is inverted.** Applied literally, the
dispatch's rule would have had me report that the edit did **not** run — on a board set that is in
fact exactly one deletion from conformant. This is precisely the "Manager premise turns out false"
failure mode the dispatch warned me about, and this time it is the premise **inside the dispatch
itself**.

**The correct inference, from the actual record:** measured **68/68/64/64 == lane §3 expected
post-state == lane §1 before-state minus exactly one per board.** The edit ran, exactly once, on
each of the four boards.

I did not reach that conclusion by trusting either the Manager or the dispatch. I measured the four
boards, plus all twelve `Add Product` boards, plus the page inventory, myself, read-only.

---

## 1. Did the edit land? **YES — verified on all four boards.**

| board | id | measured children | lane §1 BEFORE | delta | `Footer` layers (direct child) | `Footer` layers (any descendant) |
|---|---|---|---|---|---|---|
| `S · Add Product · Unknown host · Light` | `…a9a96fc40fa5` | **68** | 69 | **−1** | **0** | **0** |
| `S · Add Product · Unknown host · Dark` | `…a9a03d9da341` | **68** | 69 | **−1** | **0** | **0** |
| `S · Add Product · Verified · Light` | `…a9a979cd8fbc` | **64** | 65 | **−1** | **0** | **0** |
| `S · Add Product · Verified · Dark` | `…a9a04943d6ae` | **64** | 65 | **−1** | **0** | **0** |

Each board is **exactly one child** below the lane's recorded before-state — not two, not zero.
The `Footer` layer is absent as a direct child *and* absent from the entire descendant subtree, so it
was destroyed, not merely reparented or hidden.

The Manager's read (68/68/64/64, zero `Footer` layers, divider intact) is **REPRODUCED**. It is
promoted here from Manager observation to independently verified fact.

## 2. Exactly once? **YES.**

`−1` per board, four boards, is the signature of a single execution of the granted loop. A
no-op would read 69/69/65/65. A double-deletion would read 67/67/63/63. The measurement is 68/68/64/64.
There is no board that moved by anything other than exactly one.

This is also consistent with the lane's guard design (§5.2 validate-all-then-mutate, §5.3
idempotent-under-guards): a second run would have found `findShapeById` returning `null`, pushed
`'shape missing'` into `blockers`, and returned `ABORTED` having touched nothing.

## 3. Only what it was granted? **YES.**

The grant was: delete the `Footer` text layer at (236,862), one deletion per board. Nothing else.

Measured on all four boards, independently:

| check | result |
|---|---|
| `Footer Rule` divider | **present on all four** at parentXY **(236, 848)**, **1020×1** — unmoved |
| `Disclose` text | **present on all four** at parentXY **(1036, 862)**, 220×15, `"Show technical details ▸"` — unmoved |
| `Disclose` **right edge** | **1256 board-relative on all four** (= 1036 + 220 = 236 + 1020) — the content column's right edge. **RIGHT-ALIGNED. VERIFIED.** |
| footer band (everything at parentY 800-899) | **exactly two layers per board**: `rectangle\|Footer Rule\|236,848\|1020x1` and `text\|Disclose\|1036,862\|220x15`. Nothing else. |
| lowest child on each board (max child parentY) | **862** — no orphaned or shifted layer below the footer band |
| theme / spacing / all other text | **no drift observed**; board names, board geometry (x/y/w/h) and every remaining child's type/name/coords/size read identical to what the lane recorded |

**The `Disclose` alignment check the Manager could not complete — because the call timed out — is
MINE, and it PASSES.** The timeout that defeated the Manager did not defeat this lane; I measured all
four boards one per call and every one reads right-edge 1256.

The `Disclose` value 1256 is the **board-relative** right edge (absolute 11436 / 12736 / board.x+1256),
as the design lane recorded in its §2 note. Reading 1256 as an absolute page coordinate would target
the wrong board; I used the board-relative frame.

## 4. The other eight `Add Product` boards — **UNTOUCHED. All twelve enumerated in one read.**

Measured live, all twelve `Add Product` boards with ids from my own enumeration (never reconstructed
from a remembered pattern):

| # | board | id | x,y | w×h | kids now | lane §1 BEFORE | verdict |
|---|---|---|---|---|---|---|---|
| 1 | `BP · Add Product · Dark` | `…a998ffed44a5` | 9100, 7900 | 1280×900 | **65** | 65 | **untouched** |
| 2 | `BP · Add Product · Light` | `…a9a8f06e3586` | 9100, 8850 | 1280×900 | **65** | 65 | **untouched** |
| 3 | `S · Add Product · Unknown host · Dark` | `…a9a03d9da341` | 10400, 12750 | 1280×900 | **68** | 69 | −1 (granted) |
| 4 | `S · Add Product · Verified · Dark` | `…a9a04943d6ae` | 11700, 12750 | 1280×900 | **64** | 65 | −1 (granted) |
| 5 | `S · Add Product · Unknown host · Light` | `…a9a96fc40fa5` | 10400, 11800 | 1280×900 | **68** | 69 | −1 (granted) |
| 6 | `S · Add Product · Verified · Light` | `…a9a979cd8fbc` | 11700, 11800 | 1280×900 | **64** | 65 | −1 (granted) |
| 7 | `BPM · Add Product · Dark` | `…a9ac5f5ad2dc` | 5280, 9800 | 390×844 | **36** | 36 | **untouched** |
| 8 | `BPM · Add Product · Light` | `…a9ad42be419b` | 5280, 10750 | 390×844 | **36** | 36 | **untouched** |
| 9 | `SM - Add Product - Unknown host - Dark` | `6d055762-…f644269b` | 7550, 9800 | 390×844 | **44** | 44 | **untouched — APPROVED SET INTACT** |
| 10 | `SM - Add Product - Verified - Dark` | `6d055762-…f36b1c9a` | 8000, 9800 | 390×844 | **36** | 36 | **untouched — APPROVED SET INTACT** |
| 11 | `SM - Add Product - Unknown host - Light` | `6d055762-…f750422` | 7550, 10750 | 390×844 | **44** | 44 | **untouched — APPROVED SET INTACT** |
| 12 | `SM - Add Product - Verified - Light` | `6d055762-…0e124738` | 8000, 10750 | 390×844 | **36** | 36 | **untouched — APPROVED SET INTACT** |

**The four `SM` boards have not moved. Mobile revision 6's approval is VALID and is not invalidated.**
This was the dispatch's named BLOCKER-if-true condition, and it is **not** true. The approved artifact
set is intact, which is the outcome that matters most here — an approved, frozen, human-reviewed set
would have been compromised by a sibling lane had the guard failed.

## 5. Page inventory — **UNCHANGED.**

| | Manager's baseline | measured now | verdict |
|---|---|---|---|
| pages | 1 (`Page 1`, `d8ac01df-6646-81d2-8008-a366c09aa9d3`) | 1 — same id, same name | **unchanged** |
| root children | 164 | **164** | **unchanged** |
| boards | 160 | **160** | **unchanged** |
| root shape name | `Root Frame` | `Root Frame` | unchanged |

The 4 non-board root children are `Tab Group` (rectangle), `Rectangle` (rectangle), and two `M-N5
READ-BACK …` annotation groups. Nothing was added to or removed from the page.

## 6. Is G-18 conformant now? **YES — the four boards match `27ea6536` exactly.**

`27ea6536` `resolution.rationale`, DESKTOP clause, clause by clause:

| `27ea6536` desktop clause | measured on all four `S` boards | verdict |
|---|---|---|
| **a divider** | `Footer Rule` rectangle at parentXY (236, 848), 1020×1, present on all four | **SATISFIED** |
| **a right-aligned `Show technical details` text button** | `Disclose` text at parentXY (1036, 862), 220×15, right edge **1256** = 236 + 1020 = content column's right edge, on all four | **SATISFIED** |
| **NO footer copy** | `Footer`-named layers: **0** on all four, as direct child and across all descendants | **SATISFIED** |

**G-18 is DISCHARGED on the board artifact.** The gap registered in `27ea6536`'s appended
record-correction note — "All four desktop S boards carry the copy this decision forbids, so the
decision's outcome and the boards it declares authoritative are in conflict on exactly one clause" —
is now closed. The conflict the note left open is closed.

Scope of that statement, stated precisely: **the board half of G-18 is discharged.** `27ea6536`
follow_up_action #4 (`implementer`: delete `_buildFooter`, render `TechnicalDetails` with no note) is
explicitly a different owner and a different finding. The build must not be corrected on the strength
of this report alone — but equally, the boards no longer block it. That is a routing decision for the
Manager, not a defect in this artifact.

## 7. BPM — **G-23 CONFIRMED, independently, on BOTH boards. The lane's claim reproduces exactly.**

| `27ea6536` mobile clause | measured `BPM · Light` | measured `BPM · Dark` | verdict |
|---|---|---|---|
| `Show technical details` **left-aligned** | `Disclose` text at parentXY **(16, 580)**, 220×15, `"Show technical details ▸"` | **(16, 580)**, identical | **SATISFIED** — parentX 16 is the content column's left edge, same as `Submit L` (16,518), `Submit Sub` (16,552), `Rule 1` (16,164) |
| **no divider** above it | **0** `Footer Rule`. Thin-rect scan returns only `Top Rule` (0,55), `Rule 1` (16,164), `Nav Rule` (0,0, inside the bottom-nav sub-board) plus nav icon strokes. **No 1px rect anywhere in the footer band.** | **0** `Footer Rule`. Thin rects at parentY > 300: **none at all.** | **SATISFIED** |
| **no footer copy** | `Footer`-named layers **0**; text below y=500 is `Submit L`, `Submit Sub`, `Disclose` (580), then **nothing** until `Nav Badge` (206,772) | text in range 580–770: **empty** | **SATISFIED** |

Both boards: **36 direct children, 59 descendants** — matching the lane's §6.1 figures exactly.

**G-23 is DISCHARGED: BPM needs no edit, and none was made.** All three of `27ea6536`'s mobile
clauses were already satisfied. The grant to edit BPM was correct only in the trivial sense that
there was nothing to do. **No BPM board edit should ever be made under this finding.** The lane's
claim is reproduced on both boards in both themes.

## 8. F5 — **WIDER THAN BPM, CONFIRMED, AND THE TWO-STRING WARNING IS REAL.**

Measured page-wide across **all 160 boards**. The custody clause `private half stays in the keychain`
appears **exactly 8 times, on exactly 8 boards, in exactly TWO distinct full strings**:

| string | hits | boards | layer name | position |
|---|---|---|---|---|
| `ed25519 · created on this device · the private half stays in the keychain` | **6** | all six 1280×900 desktop boards — `BP` ×2, `S · Unknown host` ×2, `S · Verified` ×2 | `Key Meta` | (248, 460) |
| `ed25519 · private half stays in the keychain` | **2** | `BPM · Add Product · Light/Dark` | `Art S` | (138, 418) |
| — | **0** | **all four `SM` boards** | — | absent |

**The lane's claim reproduces exactly: 8 layers on 8 boards in two distinct strings, four `SM` boards
clean.** The lane's earlier page-wide figure of "16 hits" (§6.2) is **NOT** reproduced — I measure
**8** hits for this clause across the whole page. The discrepancy does not change any verdict: the
lane's own table lists one custody layer per board on 8 boards, which is 8, and the "16" appears to
have conflated custody layers with the co-located `Status` / `Key State` eyebrow layers named in the
same table. **The substantive finding — F5 is page-wide, not BPM-local, and the two platforms carry
DIFFERENT FULL STRINGS — is confirmed and is the important part.**

The practical consequence the lane flagged is real and I endorse it: **a whole-string replacement
applied page-wide would corrupt one platform.** Replacing the desktop string with the mobile one
would silently delete `created on this device · ` from six boards; replacing the mobile string with
the desktop one would inject a false provenance claim into the two `BPM` boards. F5 must be worked as
a per-platform edit. It is correctly **not** in this lane's grant, and correctly **not** worked.

F5's replacement copy is a product/architecture question (what is true about custody under `9417f8bf`'s
A3, and what the registration eyebrow should say after `898b07d0`). **Not a lane's decision.**

---

## VERIFIED vs NOT REACHED

**VERIFIED by me, read-only, this session:**

- All four `S` boards' child counts (68/68/64/64) and their delta against the lane's recorded before-state.
- All four: `Footer` absent as direct child AND across all descendants.
- All four: `Footer Rule` at (236, 848), 1020×1, intact.
- All four: `Disclose` at (1036, 862), 220×15, **right edge 1256 — right-aligned** (the check the Manager could not complete).
- All four: footer band contains exactly the divider and the disclosure; nothing below parentY 862.
- All twelve `Add Product` boards' child counts, ids, names and geometry — the eight ungranted boards all match the lane's BEFORE exactly.
- **All four `SM` boards unchanged — mobile revision 6's approval is valid.**
- Page inventory: 1 page, 160 boards, 164 root children.
- Both `BPM` boards in full: 36 children / 59 descendants, `Disclose` at (16, 580), zero `Footer Rule`, zero footer copy, no text after y=580 until nav.
- F5 page-wide across all 160 boards: 8 hits, 8 boards, two distinct strings (6 desktop / 2 mobile), 4 `SM` boards clean.
- git: HEAD `25b6ac3baf3cb098354a8be1b788af28ae58b448` on `main`, matching the design lane's claimed `HEAD_SHA`. Nothing staged or committed by me.

**NOT REACHED (one call, `MCP error -32001: Request timed out`, after which I stopped per the dispatch's dormancy rule):**

- `findShapeById` on the four deleted shape ids (`…a9a9738f2439`, `…a9a041f228ae`, `…a9a97dc29ab3`, `…a9a04cc64609`) to confirm each returns `null`. **This is a confirmatory nicety, not a gap in the verdict.** The child-count delta of exactly −1 on each board, plus `Footer` absent from every descendant subtree, establishes the deletion on its own. Penpot also disconnected ("No Penpot instance connected for user token") on two earlier calls and again on the 6,823-layer page-wide sweep, which I re-scoped successfully to a chunked 160-board pass.

**NOT CHECKED, deliberately, and out of this lane's grant:**

- Whether the **code** now matches the boards. `27ea6536` follow_up_action #4 (`implementer`) is untouched by this report. I read no production source and ran no analyzer, test or build.
- **F5's fix.** No copy decision, no board edit, no product judgement.
- The `NOT REGISTERED YET` eyebrow and `Key State` / `Not installed yet` items the lane flagged alongside F5. Reported, not assessed.

---

## BLOCKERS

**NONE.**

## HIGH

**NONE.**

## MEDIUM

**1. The dispatch prompt's decisive premise is arithmetically wrong, and it is load-bearing.**
`prompt.md` lines 46-49 assert a before-state of 68/68/64/64 with an expected 67/67/63/63. The only
record of the before-state — the design lane's §1 and §3, which the dispatch itself calls "the only
record of the before-state" — says **69/69/65/65 → 68/68/64/64**, and the lane's §5.1 guard block
re-asserts 69/69/65/65. **Applied literally, the dispatch's rule would have produced the wrong
verdict on these four boards.** Not a defect in the boards and not a defect in the design lane; a
defect in the task prompt, in the one file whose job was to make the lookup safe. Anyone re-using that
prompt against a second timed-out write will make the same inverted inference. Recommend correcting
the dispatch record.

## LOW

**1. The design lane's F5 hit count (16) does not reproduce; I measure 8.**
The lane's own table shows one custody layer per board on 8 boards = 8, and a page-wide sweep of all
160 boards finds exactly 8 occurrences of the clause. "16" appears to have counted the co-located
`Status` / `Key State` eyebrow layers. **No verdict changes** — 8 boards, 2 strings, two-platform
hazard — but the figure should not be quoted onward.

**2. The Manager's observation table carried the same transcription error as the dispatch.**
It reported 68/68/64/64 as though it were the pre-edit state. Its *conclusion* (the deletions
executed) is correct and is now verified here; only the framing was wrong.

## INDEPENDENT_RISK_LEVEL: 1
## RISK_LEVEL_AGREEMENT: YES

I independently assess **Level 1 (Design-System Correction)** per `DESIGN_GOVERNANCE.md:97` — an
inconsistency with the established pattern, requiring design-system owner notification, not a human
gate. I agree with the design lane's `RISK_LEVEL: 1`. It is not 0: it mutated four live shared design
artifacts with no version history, so recoverability is by re-authoring rather than by undo, and for a
period the outcome was unverified. It is not 2: no user flow, interaction pattern or feature-level UX
is touched; the deletion was specified by a resolved human decision; the change *removes* a surface
rather than adding one. Independent review was required regardless — a lane that edits four boards
cannot certify them — and that is this lane.

## TRACEABILITY_GAPS

- **`27ea6536` follow_up_action #4 (`implementer`)** — delete `_buildFooter`, `TechnicalDetails` with
  no note. **OUT OF GRANT, DELIBERATELY.** The boards no longer block it (that was the point of G-18),
  but the code half of this decision is unreconciled with the boards by design at this point. **The
  Manager must now decide whether to unblock it.** I am reporting the unblock condition, not taking it.
- **`27ea6536` follow_up_action #2 (verify the mobile footer against `BPM`)** — **ANSWERED BY
  MEASUREMENT** (§7): left-aligned, no divider, no copy, both themes. That action can be closed by its owner.
- **`G-19`** — out of grant and untouched. The decision's false `supersedes_design_lane_reading`
  clause ("carries NO footer copy") and its follow_up_action #3 ("treat as a misidentification") remain
  uncorrected in the record. `.decisions/**` was a PROHIBITED path for this lane. **Route to the
  decision owner**; I did not touch it.
- **`F5`** — measured, not worked. 8 layers, 8 boards, 2 strings, needs an owner and a copy decision.
- **`BP · Add Product · Dark/Light` carry a `Footer`-named layer** — measured: `footerNamed: 1` on each
  at 65 children, unchanged from the lane's BEFORE. `27ea6536` names only the four `S` boards in its
  desktop clause, so these two are **not** a violation of the decision as written. Flagged because the
  decision's stated intent is "no footer copy on both platforms" and the human's verbatim says "Our Add
  product desktop should be the same way" — which reads as covering desktop generally. **A scope
  question for the decision owner, not a defect.** I did not touch these boards; they were not granted.

## CORRECTION_REQUIRED: NO

No correction lane is owed anything on these four boards. The edit landed exactly once per board,
changed only what it was granted, and the boards now conform to `27ea6536`. The open items are
routing decisions for the Manager and the decision owner, not repairs to this artifact.

## HUMAN_DECISION_REQUIRED: YES
## HUMAN_DECISION_TYPE: DESIGN

**Not because of a defect in the artifact** — the artifact is clean and I approve it — but because
three items are genuinely outside any lane's authority and should not be routed into a correction loop:

1. **Whether to unblock `27ea6536` follow_up_action #4.** The board half of G-18 is discharged, so the
   `_buildFooter` deletion is no longer blocked by the boards. Whether the build now moves is a
   sequencing decision with a human-approved decision object behind it.
2. **F5's replacement copy** — a product/architecture question about custody under `9417f8bf`'s A3 and
   the registration eyebrow under `898b07d0`. The design lane flagged it as human-level and was right.
3. **Whether `BP · Add Product · Dark/Light` are in scope of `27ea6536`'s no-footer-copy clause** —
   they carry a `Footer` layer the decision's intent forbids but its text does not name.

These are reported for the Manager to route as a DESIGN Human Decision. **None blocks the G-18 board
state**, which is verified conformant.

## SAFE_PARALLEL_WORK

```yaml
SAFE_PARALLEL_WORK:
  - the four desktop S boards are now SETTLED — G-18 discharged, verified conformant, no further
    board writes needed or wanted against them
  - the keys lane (design-correct-addproduct-keys) and its remaining findings
  - the mobile lane — verified untouched; revision 6's approval is valid and I did not invalidate it
  - anything reading add_product_page.dart read-only
  - recording/correcting the dispatch prompt's arithmetic and G-19's false record clause
    (documentation only, no board writes)
PROHIBITED_PARALLEL_WORK:
  - ANY board-writing lane on the four S boards — they are conformant; a second writer can only
    introduce drift against a verified-good state
  - any BPM board edit — G-23 is measured; BPM needs none and never should be made under this finding
  - any page-wide whole-string replacement for F5 — it would corrupt one of the two platforms
  - any Docker/Compose mutating command, per this repository's standing rule
```

---

## Files touched

```
docs/engineering/dispatch/tasks/verify-g18-desktop-boards/report.md   (this file — OWNED_PATHS)
```

Nothing else. **No Penpot board was modified by this lane. No Docker/Compose command was issued. No
production source was written. Nothing committed, nothing pushed.** `git status` for tracked files is
unchanged by this lane (the pre-existing modified `apps/control_plane/test/failures/*.png` baselines
were already dirty on arrival and were not touched by me; the untracked `*.sql` files in the repo root
were also already there on arrival).

## Durable discoveries

Per `docs/engineering/LEARNING_POLICY.md`, recorded here for the Manager to route into the owning
artifacts. This lane writes **no** knowledge base — `.decisions/**` and `docs/adr/**` are PROHIBITED.

1. **CONTRADICTION / PROJECT_FACT — a dispatch prompt's transcribed before-state can invert the
   inference it exists to support.** `prompt.md` for this task states the pre-edit children as
   68/68/64/64 and the expected post-state as 67/67/63/63; the design lane's §1/§3/§5.1 record
   69/69/65/65 → 68/68/64/64. Applying the dispatch's rule as written yields a false negative on four
   boards that are in fact exactly one deletion from conformant. **Generalisable:** when a timed-out
   write's outcome must be inferred from a count, the count in the dispatch must be reconciled against
   the *writing lane's own persisted record* — which here was available and internally consistent —
   rather than restated from memory. A restatement can be off by one and silently invert the verdict.
2. **DESIGN_DISCOVERY / PROJECT_FACT — G-18 is discharged on the boards.** All four desktop `S` boards
   measured at 68/68/64/64 (one below the recorded before-state), zero `Footer` layers as direct child
   and across all descendants, `Footer Rule` intact at (236,848) 1020×1, `Disclose` at (1036,862) with
   **right edge 1256 board-relative = 236+1020 — right-aligned**. Conforms to `27ea6536`'s desktop
   clause on all three elements, both themes, both registration states.
3. **DESIGN_DISCOVERY / PROJECT_FACT — G-23 is discharged; BPM needs no edit.** Both `BPM` boards
   (36 children / 59 descendants each) already satisfy all three of `27ea6536`'s mobile clauses:
   disclosure left-aligned at parentX 16, **no divider**, **no footer copy**, and no text between the
   disclosure at y=580 and the bottom nav at y=764. Measured on both themes independently.
4. **DESIGN_DISCOVERY / PROJECT_FACT — F5's real blast radius, re-measured page-wide over all 160
   boards: 8 layers on 8 boards in TWO distinct full strings** (6 desktop with the
   `created on this device · ` prefix, 2 mobile without), four `SM` boards clean. **A whole-string
   replacement applied page-wide would corrupt one platform.** F5 must be a per-platform edit. (This
   lane measures **8** where the design lane reported 16 — the substantive finding is unchanged; see
   LOW-1.)
5. **RUNTIME_DISCOVERY — Penpot's MCP connection drops in two distinct failure modes, and they call
   for different responses.** Beyond the documented "no heartbeat" dormancy, the session also returned
   **`No Penpot instance connected for user token`** on three separate calls, which cleared after a
   ~20-25s wait with no user action, and **`MCP error -32001: Request timed out`** on the heaviest
   single call (a 6,823-layer page-wide sweep). Practical guidance for the next board lane: **a
   page-wide scan over every text layer on this page reliably exceeds the call budget** — scope the
   sweep by pre-filtering candidate boards (which I did: it completed and returned identical results),
   measure one board per call, and treat a single wait-and-reconnect as a legitimate recovery step
   rather than a retry loop.
6. **PROCESS_FACT — a verification lane must read the writing lane's persisted report BEFORE the
   dispatch's summary of it.** The dispatch was the less reliable source; the lane's §1/§3 were exact.
   Three reports have been lost in this work item, which is precisely why the persisted
   before-state was trustworthy enough to reconstruct the outcome from.

## Recommended next action

```
ADVANCE_G18
```

G-18's board gap is closed and verified. The three `HUMAN_DECISION_REQUIRED` items above are routing
decisions for the Manager, not blockers on this artifact. **Do not dispatch another board-writing lane
against the four `S` boards — they are verified conformant and a second writer can only introduce drift.**

---

```yaml
FEATURE: Add Product rebuild — independent read-only verification of the G-18 desktop board edit
TASK_ID: verify-g18-desktop-boards
TASK_TYPE: review
AREA: Penpot desktop `S · Add Product · …` boards (read-only; nothing changed)

BRANCH: main
BASE_SHA: 25b6ac3baf3cb098354a8be1b788af28ae58b448
HEAD_SHA: 25b6ac3baf3cb098354a8be1b788af28ae58b448
COMMITTED: NO

OWNED_PATHS:
  - docs/engineering/dispatch/tasks/verify-g18-desktop-boards/report.md
READ_ONLY_PATHS: everything, including every Penpot board
PROHIBITED_PATHS: EVERY Penpot board; apps/**, packages/**, docker/**, .github/**, .decisions/**, docs/adr/**

VALIDATION_COMMANDS:
  - penpot: penpotUtils.getPages() -> Page 1          PASS (1 page, id d8ac01df-6646-81d2-8008-a366c09aa9d3)
  - page inventory: 160 boards / 164 root children   PASS (unchanged from baseline)
  - four S boards: 68/68/64/64, one deletion each    PASS
  - Disclose right edge 1256 on all four             PASS (the check the Manager could not complete)
  - eight ungranted Add Product boards unchanged    PASS (incl. all four SM — approval intact)
  - BPM both boards: 36/59, left-aligned, no rule, no copy  PASS
  - F5 page-wide: 8 hits / 8 boards / 2 strings     PASS
  - docker / compose                                 NEVER ISSUED (no command of any kind)
  - dart analyze / tests / build                     n/a (no production source written, out of grant)

DESIGN_SYSTEM_COMPLIANCE: PASS
UX_ACCESSIBILITY_SCORE: PASS  (no new surface; a surface was removed; footer band is divider + right-aligned disclosure, per the resolved decision)
IMPLEMENTATION_FEASIBILITY: HIGH

BLOCKERS: none
HIGH: none
MEDIUM: 1 (dispatch prompt's load-bearing arithmetic is wrong — recorded, correction is to the record, not to the boards)
LOW: 2

READY_FOR_INDEPENDENT_DESIGN_REVIEW: n/a — this WAS the independent design review.
```
