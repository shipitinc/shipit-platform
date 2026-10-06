# Report — Independent Design Re-Review, mobile boards, Revision 2 (Gate D3, cycle 2)

Persisted per `aef-orchestrator` §14. Reviewer: a **fresh** `design-reviewer`, read-only, who did not
produce the design and did not write the correction.

**REVIEWED_HEAD `77c19f114ee691e8c434afe37b7c84494b66dc40`** — worktree
`/private/tmp/shipit-correct-addproduct-mobile`; only the untracked task directory present; no tracked
file modified. Branch as recorded in the artifacts is wrong (L-N2).

REVISION_ID `1F8DC787-E88C-4DF2-B2CC-E8B0E60BBF67` (revision 2), supersedes
`65995C2B-4905-419F-A6E9-E547E86D8ECE`; BRIEF_ID `52CB4098-FF87-4B78-81DA-1104269551A1`.

```
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
REVIEWED_HEAD: 77c19f114ee691e8c434afe37b7c84494b66dc40
CORRECTION_REQUIRED: YES
HUMAN_DECISION_REQUIRED: NO
HUMAN_DECISION_TYPE: DESIGN
INDEPENDENT_RISK_LEVEL: 2
RISK_LEVEL_AGREEMENT: YES
```

## Verification summary

**Provenance.** `git rev-parse HEAD` matches the claimed `REVIEWED_HEAD` ✓. Worktree ✓.
`git status --porcelain=v1` shows only `?? docs/engineering/dispatch/tasks/design-addproduct-mobile/` —
no tracked file modified, no prohibited path touched ✓. **Branch name is recorded wrong in three
places** (L-N2).

**B-R1 is genuinely closed.** Every text layer's actual `fontWeight`/`fontSize`/`letterSpacing`/
`fontFamily`/fill was read on all four boards. Emphasis weights now match their production tokens
exactly: `Back` 12/500, `H1` 20/600, `Status`/`F K 0/1/2`/`Art K`/`Trust K` 9/600 ls 1.1 (Mono),
`Art T` 13/600, `Art L1`/`Art L2` 11/500, `Disclose` 10/500, `Trust Btn L` 12/600, `Submit L` 11/600.
Independently confirmed `IBM Plex Sans` variants = `100…700` normal+italic — **`500normal` exists,
`900` does not, `100` exists.** The 52-change count reproduces (14×2 Unknown + 12×2 Verified).
`bodySmall` is 11/w400 at `:386`; `sectionTitle` is 13/w600 at `:352` ✓.

**H-R1 is genuinely closed.** `Trust Host` is now `#5a5c5b`/`#a8a6a0` on both Unknown boards, on
`Trust Bg` = `#ffffff`/`#262827` = `card`. All 14 ledger rows were re-measured from
`design_tokens.dart:99-101`/`:120-122` with an independent WCAG 2.1 implementation (sanity: black-on-white
21.00, white-on-white 1.00) — **every figure reproduces exactly**, including the four new rows.
`inkSecondary`/`card` = 6.74/6.10 ✓. Kept distinct from `negative`-on-dark (3.68) ✓. Visually confirmed
legible in both PNG exports.

**`Submit L` — the correction is right and the prior review was wrong.** `R Submit L` on all four
desktop boards: **12/600 Sans ls 0**, not 13. Only `BPM · Add Product · Light/Dark` draw 13. 11/600 is
applied on all four boards and re-centred (518→520, 686→688) ✓.

Also confirmed closed: H-R2 (`product_detail_page.dart:614` verbatim), H-R3 (reproduces 2/2/1/1
substring and 1/1/1/1 exact), M-R1 arithmetic (14.4+22=36.4, +5.6px — `Size.constrain` semantics
correct), M-R2 (16 renames live), M-R3 (`:726-735` has exactly six returns; Verified matches `:734`
byte-for-byte), M-R4 (guards at `:201/:207/:216/:225/:234`, `errorMessage` at
`:203/:211/:220/:229/:238`), L-R1 (badge at (206,772), byte-identical to the reference), L-R3
(harmonised + `Art T` cross-layer consequence fixed), L-R4 (measured 34+14+16=64 from live
y=194/258/322), L-R6. Inventory 160 boards/162 root children, no strays, all four reference boards
unchanged. `Art S` still `PENDING D4`, not resolved ✓. No Docker/Compose command run.

## BLOCKERS

**None.** B-R1 is closed — verified, not taken on report: every text layer on all four boards matches its
production token, `500normal` exists, `900` does not, F8's premise is false in both directions, and
`Art T`'s token is corrected to `sectionTitle` (13/w600, `design_tokens.dart:352`). H-R1 is closed —
`Trust Host` reads `inkSecondary` on the trust panel's `card` surface, 6.74:1 / 6.10:1 by the reviewer's
own measurement, the ledger row names the surface, and it stays distinct from `negative`-on-dark. **No
new blocker was found.**

## HIGH

### H-N1 — `Trust Btn L`'s flush-left is a **lane-introduced** defect that both L-R5 and N8 dismiss on a false premise

Verified: mobile `Trust Btn L` is `align: left`, x=30 in a 180-wide `Trust Btn` at x=30 → glyphs render
at the button's left edge, **0px inset**. Desktop `S · Add Product · Unknown host · Light` `Host Btn L`
is **`align: center`**, same 180-wide box at x=254, `textBounds` dx=+50 → glyphs at x=304, i.e.
**centred**.

Both dispositions rest on comparing box `x` while ignoring `align`, so the conclusion "it faithfully
copies the desktop `Host Btn`/`Host Btn L` pattern at x=254" (`design-revision-2.md` §8 L-R5, N8;
`correction-report.md:75`) is **false**. The mobile boards' own `Submit L` is `align: center`, and
Flutter's `FilledButton` centres its label, so this is the single place these boards diverge from both
the desktop pattern and the primitive. Visibly wrong in both PNG exports. **It is on a board the lane
owns, so it is not out of scope.**

**FIX:** set `Trust Btn L` `align` to `center` on both Unknown boards (`…ff750422`, `…e644269b`),
matching `Submit L` and desktop `Host Btn L`; OR, if the flush-left label is genuinely wanted, say so and
route it as a new design-system item with the real rationale — **but do not carry N8's current text,
because notifying the owner that this "copies the desktop pattern" will cause a real defect to be
deliberately preserved.**

## MEDIUM

### M-N1 — L-R7's ledger row and N7 both assert a desktop `card` surface that does not exist

The desktop `TechnicalDetails` is also on `canvas`. `add_product_page.dart:316`'s `TechnicalDetails` is a
direct child of the desktop page `Column` (inside `SingleChildScrollView` → `Padding` → `Column`), a
**sibling** of the `Row` that carries `_RightPanel`; `_RightPanel` is the `DesignPanel` =
`palette.card` and contains only "What happens next", the four steps and the button.
`scaffoldBackgroundColor` is `palette.canvas` (`core/theme.dart:23`). So **no `card` surface lies under
the expanded lines on either platform**, and the mobile `TechnicalDetails` at `:925` is likewise outside
the `DesignPanel` at `:853`.

Therefore: (i) the per-platform split in the §5 ledger row (`canvas` mobile / `card` desktop) does not
exist and should become **one row naming `canvas` for both platforms at 4.65:1 / 4.62:1** (both pass AA —
reproduced); (ii) N7 escalates to the design-system owner a desktop AA failure "on `card`" that Add
Product does not exhibit. Either drop N7 or re-derive it from a genuine `card`-surface call site and cite
it.

**The correction is right to reject the reviewer's 4.23:1 for the governed boards; it is wrong to
attribute it to the desktop `_RightPanel`.**

### M-N2 — The traceability matrix was not corrected, and revision 2 contains no matrix of its own

The only matrix in the artifact set is revision 1's (`design-revision.md:318-335`), retained
byte-identical. Three of its rows are wrong, and **two are exactly the rows B-R1 and L-R2 named**:

- `:325` `Art T` → "`bodySmall` w600". `bodySmall` is Sans 11/w400 (`design_tokens.dart:386`); the board
  now draws 13/600 = `sectionTitle` (`:352`). Revision 2 names `sectionTitle` only in its §2 weight table.
- `:335` `Bottom Nav / … / Products` → `inkQuiet`/`inkPrimary`. **False for the dark boards**, which draw
  `#8A8983` = `inkTertiary` (not `inkQuiet` `#85847E`). Revision 2 records the correct per-theme tokens
  in the contrast ledger (§5) but never in the matrix.
- `:330` `Trust K/Body/Body 2/Host` → **no foreground token at all**. Corrected in revision 2 §3 as
  prose, not in the matrix row.

**FIX:** add a corrected traceability matrix to `design-revision-2.md` (at minimum these three rows), so
the revision that gets frozen does not carry a matrix whose token names contradict the boards it governs.

### M-N3 — `penpot-board-evidence.md` was not updated and now publishes superseded figures plus the exact unreproducible number H-R3 was raised about

- `:21-24` layer counts still `42 / 42 / 34 / 34`; live is **`44 / 44 / 36 / 36`**.
- `:56-61` `Register product` count still a bare `1` with **no counting rule**. Under the rule revision 2
  publishes, the figure is **2** on both Unknown boards.
- `:34-49` and `:69-85` predate the weight pass, the `Trust Host` token swap, the badge additions, the
  repository harmonisation and the 16 renames.

**FIX:** regenerate §2, §3, §4 and §5 from the live file with revision 2's rules, or add a superseded
banner and restate the four boards' current figures.

### M-N4 — The active nav label is 10/400 on all four boards where `mobile_chrome.dart:297` renders the active label at `FontWeight.w600`

B-R1's rule ("token/primitive wins") was applied to `Back`, `H1`, the microLabels, `Art T`, the links,
`Disclose`, `Trust Btn L` and `Submit L` — **but not here.** `Nav Label 3` ("Products") is the active
tab: its fill is `inkPrimary` (`#1f2120`/`#f5f4f0`) while the other four are `inkQuiet`/`inkTertiary`, and
the nav board is named `Bottom Nav / … / Products`; it sits at w400 on all four boards, as it does on the
reference.

§2's stated reason — "the nav is a clone of a PROHIBITED board's sub-tree and the active-label weight
was not in scope" — **does not hold**: the four boards the lane owns and everything inside them are in
scope; only `BPM · Add Product · Light/Dark` and the desktop `S · Add Product · …` boards are PROHIBITED.
It is also inconsistent with §2's own resolution of `microLabel` tracking ("my boards follow the token;
the reference board is low-fidelity here"), and folding it into N6 misroutes a lane-owned fix to the
design-system owner.

**FIX:** set `Nav Label 3` to w600 on all four boards and report the `BPM` reference's w400 as the
separate N6 item it is. If the lane holds a reason not to, state it instead of attributing it to the
reference board.

### M-N5 — H-R4 was routed, not designed; that part is right, but the boards still assert a fill the code will not paint

The reviewer does **NOT** re-raise the routing: raising N4/G9 to the design-system owner is correct, and
§7 states the consequence plainly and correctly declines to fake a treatment. **But §4's own point 1 —
"the board is factually wrong about its own target" — applies here and was not applied.**
`FilledButton` receives `onPressed: null` when `canRegister == false` (`add_product_page.dart:906`,
`:679`), and `core/theme.dart:67-83` sets only **enabled** colours on `filledButtonTheme`, so Material 3's
disabled defaults apply: the button will **not** paint `#1668d6`/`#4496fc` at opacity 1. The board
therefore specifies a treatment the primitive cannot produce — exactly the defect class B-R1 and the
`Submit L` decision were both about. **Specifying what the primitive already renders requires no palette
token and no human gate.**

**FIX:** add a disabled-state read-back to the Unknown-host pair showing the appearance
`FilledButton(onPressed: null)` produces under `core/theme.dart`, mark it provisional with the trust panel
(same G1 marker), and keep N4/G9 for the *token* the design system still lacks. The §7 statement that the
boards are "the known-wrong expression for the Unknown-host state" should stay in place either way.

### M-N6 — A false claim about work performed, of the same kind F8 was deleted for

`design-revision-metadata-2.yaml` (`risk_rationale`; `corrections_applied.M-R1`) and
`correction-report.md:67` state the 36px claim was "deleted from § 2a, from the `risk_rationale` and from
`report.md`". **It was deleted from none of them:**

- `design-revision.md:70` still reads "`36.4` → clamped by `minimumSize` to **36px**"
- `design-revision.md:72-73` still reads "collapses from ≈50px to exactly 36px — landing on its own
  declared `minimumSize`"
- `report.md:48` and `:197` still read "≈50.4px → 36px, landing on its own declared `minimumSize`"
- `design-revision-metadata.yaml:15-16` still reads "collapses from ~50.4px to its declared 36px
  minimumSize"

Retaining revision 1 byte-identical is a legitimate and stated choice, **but then the claim must read
"superseded by revision 2 §6a, not deleted".** The corrected 50.4 → 36.4 arithmetic itself is right and
was verified.

**FIX:** restate as superseded, or add a one-line supersession pointer at the head of each retained
revision-1 artifact.

## LOW

- **L-N1** — **F8, and the false weight claim it carries, survive verbatim and un-marked in two retained
  artifacts:** `design-revision.md:414` (F8 table row) and `report.md:100`, both still stating "Penpot's
  IBM Plex Sans has no `500` weight". Revision 2 says "F8 deleted"; **nothing was deleted or annotated**,
  because both files were retained intact. B-R1 directed deletion **precisely so no future lane relies on
  it**. A reader who opens `design-revision.md` first sees only F8. Alphabetical listing puts
  `design-revision-2.md` first, which mitigates but does not remove it.
  **FIX:** a one-line withdrawal marker on F8's row and on `report.md:100` pointing to revision 2 §2, or
  move the retained revision-1 artifacts to a clearly superseded subdirectory.
- **L-N2** — **Provenance:** the branch is recorded as `design/correct-addproduct-mobile` in
  `design-revision-2.md:16`, `design-revision-metadata-2.yaml:220` and `correction-report.md:136,183`.
  The actual branch at HEAD `77c19f1` is **`design-correct-addproduct-mobile`** (`git branch
  --show-current`, `git worktree list`). **This is the same class of error the pass itself escalates as
  G11** (a ledger asserting a path that does not exist) and it would misdirect anyone reproducing the lane.
- **L-N3** — Three adjacent citations off by one or omit a directory:
  `fontWeight: active ? FontWeight.w600 : FontWeight.w400` is `mobile_chrome.dart:297` (`:296` is the
  `navLabelMobile.copyWith(` line), cited as `:296`; `class MobilePrimaryButton` is `:425` (`:424` is its
  doc comment), cited as `:424`; and the §5/correction-report citations to `design_primitives.dart:320`/
  `:391` omit the `apps/control_plane/lib/shared/` directory the file actually lives in. **M-R4 was raised
  precisely because two wrong line numbers would misdirect the next lane.**
- **L-N4** — The published text-layer counts are wrong and, like H-R3, **carry no stated rule**:
  `design-revision-2.md` §9 and `correction-report.md:116-119` publish "24 / 24 / 19 / 19". Live counts
  are **29 / 29 / 24 / 24**. The published figures are reproducible only by excluding the five `Nav Label`
  layers while still including the `Nav Badge` text layer, which is not stated.

## TRACEABILITY_GAPS

- The traceability matrix that would be frozen is **wrong in three rows** (`Art T` → `bodySmall`;
  `Trust K/Body/Body 2/Host` → no foreground token; `Bottom Nav` → `inkQuiet`/`inkPrimary` for dark).
  All three were named by B-R1, H-R1 and L-R2 and **none was corrected in the matrix itself**; revision 2
  carries no matrix of its own. See M-N2.
- `canRegister == false` has **no traced design element**: no board expresses it, no token exists, and no
  traceability row carries it. Recorded as G9/N4 rather than traced. See M-N5.
- `Confirm the host above to enable Register product.` has **no producing state in the trace**; it is
  classified AMBIGUOUS with `hostUnrecognised` named (M-R3 satisfied in substance) but the string is not
  traced to a requirement.
- No requirement moved: R1–R7 covered, `requirements_gaps: []` accepted.

## SAFE_PARALLEL_WORK

**SAFE:**
- **DRAFTING the copy corrections.** Independent of every finding above and of the boards:
  `product_detail_page.dart:614`, `add_product_page.dart:383`, `:918`, `:480-482`, `:542`, `:1038`. All
  remain the live false-claim surface (H-R2 confirmed verbatim on all of them).
- The implementation lane's **NON-UI** preparation — mock-key removal (`:126-138`), the missing
  `AccessStatus.verified` producer, first-ever test coverage for `add_product_page.dart`. None depends on
  the four boards.
- `design-addproduct-keyservice` — disjoint `OWNED_PATHS`. **One update owed to it:** the Unknown-host
  helper string is now traced to ITS `hostUnrecognised` state as A5/G10, so its state-machine design owns
  producing that string.

**PROHIBITED:**
- Any implementation of these four boards' typography or tokens until **H-N1, M-N4 and M-N2** close.
- **Visual-QA golden-baseline capture.** It would bake in the flush-left `Trust Btn L` (H-N1), the w400
  active nav label (M-N4) and an enabled-looking `Register` on the state where `canRegister == false`
  (M-N5). **F6** (34px board submit vs 36px `MobilePrimaryButton`) is still unsettled and would bake in
  the wrong height independently.
- Any lane editing `BPM · Add Product · Light/Dark` or the desktop `S · Add Product · …` boards (N5, N6
  need a design-system owner).
- Manager action outside any lane: correct `LANES.md:224` (G11) and the branch name in the three
  artifacts (L-N2).

## NOT RUN (explicit — no gate claimed that was not run)

- `flutter analyze` — **NOT_RUN**. Requires `flutter pub get`, which writes outside this lane's read-only
  scope. The missing `apps/control_plane/.dart_tool/package_config.json` that
  `implementation_feasibility: MEDIUM` rests on was independently confirmed; **no claim is made about the
  analyzer's output.**
- Any Docker or Compose command — **NOT_RUN, none issued**, per the hard rule.
- Automated pixel-diff against the reference boards — **NOT_RUN**; no such tooling exists here. Geometry
  comparison used layer name/position/size, **not pixels**.
- Full content inspection of the two **Dark** desktop boards — **PARTIAL**: identity verified (position,
  1280x900, 69/65 children, `R Submit L` 12/600) but not every layer walked.
- **No Penpot board was edited, renamed, moved or deleted**, including `BPM · Add Product · Light/Dark`
  and the desktop `S · Add Product · …` boards. Penpot access was read / inspect / PNG export only
  (3 exports).
- Nothing was persisted; this report is returned to the Manager.

## Reviewer's closing judgement

B-R1 and H-R1 are genuinely, independently closed — the reviewer tried to break both and could not. H-R4's
routing was the right call and no palette decision is being forced; but the boards still specify a fill
the code will not paint for the disabled state, which needs no human gate to correct, so it becomes
M-N5 rather than a re-escalation.

**The correction's *judgment* was consistently good** — it disproved a reviewer premise it had been handed
and said so (§4, §13), which is the single strongest thing in this pass. **Its *verification discipline*
lapsed in exactly the places where it stopped checking:** `Host Btn L`'s `align`, the desktop
`TechnicalDetails`' surface, the active nav label's weight, and the claim about what it had deleted.
Every one of those is a check the correction had already performed correctly somewhere else in the same
document.
