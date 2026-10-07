# Report — implement-add-product-custody-and-footer

```yaml
RESULT: IMPLEMENTED
TASK_ID: implement-add-product-custody-and-footer
TASK_TYPE: implement
FEATURE: Add Product rebuild — correct the false key-custody copy and the forbidden footer copy in the build
WORKTREE: /private/tmp/shipit-implement-custody-footer
BRANCH: implement/add-product-custody-and-footer
BASE_SHA: 52d0894
HEAD_SHA: 52d0894
COMMITTED: NO
```

**Nothing committed, nothing pushed.** Two files modified in the worktree, left for the Manager.

---

## 0. READ THIS FIRST — one conflict between the two approved copy sources, and I followed the dispatch

**I shipped the 70-char eyebrow, per this dispatch's explicit instruction. It drops `ed25519`, and it
diverges from the boards. I did not decide that; I am flagging it.**

The dispatch's Part 1 table lists the eyebrow replacement as the **80-char**
`ed25519 · generated on the server · the private half stays in the secret manager`, and immediately
below says that string does **not** fit, and instructs: **"USE THE VARIANT FROM §7, NOT THE 80-CHAR
STRING."** The only FIT-verified variant in §7 is the **70-char**
`Generated on the server · the private half stays in the secret manager` (§4a — measured 340.29px in a
380px box, 39.71px clearance, **FITS**). That is what I shipped, at `:542` and `:1038`.

Three consequences the Manager must route onward:

1. **It drops `ed25519`.** That token appears nowhere else on the page — `:542`/`:1038` were its only
   occurrences — so the Add Product page no longer states the key algorithm. **No lane proposed a
   fitting string that keeps `ed25519`**, and inventing one would have been inventing copy.
2. **It re-opens a boards/build divergence on the eyebrow axis.** §7's divergence table calls the boards
   **CURRENT** carrying the 80-char string and calls this a **sync**, i.e. "no new copy needed". The 70-char
   value therefore contradicts the boards. The dispatch also warns that fixing all four sites is what
   prevents divergence — so on the eyebrow axis I followed the fit instruction and accept the
   divergence. **The dispatch's two instructions cannot both be satisfied for this one string.**
3. **The 380px box cited is not this slot's box.** §4a measures `Art Sub` at 380×18 on **`BP · Rotate
   Key`**, a different board family from the Add Product key-meta eyebrow (`:542`/`:1038`). In the build
   the string is a wrapping `Text` whose width is viewport-dependent (left column of a 3:flex row beside a
   fixed-width side panel), so no fixed 380px box applies and a `Text` wraps rather than overflows.

**A3-correctness holds either way** — both strings assert server-side generation and secret-manager
custody. What differs is information content and board convergence. This needs a design-lane call, not an
implementation judgment.

I did **not** treat this as a blocker: the dispatch stated the instruction twice and emphatically, the
outcome is not architecture/security-consequential, and both candidate strings are A3-correct. Flagging
rather than deciding.

---

## 1. Isolation pre-flight — CONFIRMED

```bash
git worktree list                                  # worktree present
cd /private/tmp/shipit-implement-custody-footer && git rev-parse --short HEAD   # 52d0894
git rev-parse --abbrev-ref HEAD                    # implement/add-product-custody-and-footer
git status --porcelain                             # EMPTY (clean tree at BASE_SHA)
```

- worktree: `/private/tmp/shipit-implement-custody-footer`
- branch: `implement/add-product-custody-and-footer`, created at `52d0894`
- tree was **clean** at pre-flight. The 48 dirty binaries in
  `apps/control_plane/test/failures/` are in the **canonical** checkout, not here; I neither staged,
  reverted nor cleaned them (verified: `git status --porcelain apps/control_plane/test/failures/` → 0).
- **No `git merge --ff-only` was needed** — the pre-flight hazard in the prompt did not materialise.

---

## 2. Every cited line verified against source BEFORE any edit

This work item's record includes a lane adopting a citation 43 lines off. I confirmed each site by
reading the string **and** its structure. Two citations were wrong:

| cited | actual | verdict |
|---|---|---|
| `apps/control_plane/lib/core/design_primitives.dart:396` | **FILE DOES NOT EXIST.** The file is `apps/control_plane/lib/shared/design_primitives.dart` (`lib/core/` holds `colors.dart`, `design_tokens.dart`, `plain_language.dart`, `product_language.dart`, `text_styles.dart`, `theme.dart`, `theme_controller.dart` — no `design_primitives.dart`) | ⚠ **PATH CITATION WRONG.** Line 396 inside the real file is exact. |
| `design_primitives.dart:398-410` renders `Row[Expanded(note ?? SizedBox.shrink()), InlineLink]` | `Row` at :398 ✓, `Expanded` :401-410 ✓, **`InlineLink` at :411** | off by one on the span end |
| `add_product_page.dart` all 7 sites | see §3/§4 | **all 7 exact** |

**On the path citation:** the dispatch's `OWNED_PATHS` names
`apps/control_plane/lib/core/design_primitives.dart`. That path is absent. The grant's intent — "the
shared `TechnicalDetails` primitive", `READ_ONLY` nowhere else, `PROHIBITED_PATHS` silent on
`lib/shared/**` — is unambiguous, and there is exactly one `class TechnicalDetails` in the repository.
I edited `apps/control_plane/lib/shared/design_primitives.dart`, **`TechnicalDetails` primitive only**,
and disclose it here rather than silently substituting a path.

All 7 `add_product_page.dart` citations were exact, including the trap.

---

## 3. THE TRAP — proof `:409-411` was not touched

`Registering records the product…` occurs **three** times. I scoped every change by **call site**, never
by text. Three independent proofs:

**Proof 1 — no diff hunk overlaps the original region.** The diff's original-line ranges are
`314-315`, `317-319`, `372-389`, `480-481`, `542`, `926-928`, `979-980`, `1038`. Programmatically
checked for overlap with `409-411`:

```
NONE -- no hunk touches original lines 409-411
```

**Proof 2 — the two forms are textually distinguishable.** The footer notes and the mid-page prose
**split the same sentence differently**, so they are not the same source text:

| site | line 1 of the literal |
|---|---|
| `:318` desktop footer note (**removed**) | `'Registering records the product. Nothing is governed until '` |
| `:927` mobile footer note (**removed**) | `'Registering records the product. Nothing is governed until '` |
| **`:410` mid-page prose (KEPT)** | `'Registering records the product. Nothing is governed until you '` |

The mid-page version ends the literal after `you `. A text-level search-and-replace could not have
distinguished them; scoping by call site did. Each removal was applied as a
**3-line block including its `note:` prefix**, which the mid-page prose does not have.

**Proof 3 — byte-exact, and only one survivor.** Original `406-412` vs working `385-391` (offset −21,
the 21 lines removed above it):

```
md5  f554ab3d7eb520546d66108afe440d2e   (original 406-412)
md5  f554ab3d7eb520546d66108afe440d2e   (working  385-391)
IDENTICAL -- mid-page prose byte-for-byte unchanged
```

Occurrences of the shared string in the finished file: **1** (was 3). The survivor, in context:

```dart
383         Text(
384           "What you're registering",
385           style: ShipItType.detailTitle.copyWith(color: palette.inkPrimary),
386         ),
387         const SizedBox(height: 4),
388         Text(
389           'Registering records the product. Nothing is governed until you '
390           'approve a baseline.',
391           style: ShipItType.bodySmall.copyWith(color: palette.inkSecondary),
392         ),
```

`27ea6536` forbids **footer** copy. This is mid-page explanatory body prose under
"What you're registering", which the decision never condemned. It is intact, including its distinctive
line break.

---

## 4. Per-site before/after — ALL SEVEN build sites

### Part 1 — the four false key-custody sites

Copy source: `design-draft-f5-copy/report.md` §7 (my copy source of truth). **No copy invented.**

**Site 1 — `Ev Body`, desktop, was `:479-483` (string literals `:480-481`)**

| | |
|---|---|
| before | `"It clones over SSH. The private half stays in this device's "` + `'keychain \u2014 never shown, logged or stored.'` |
| after | `'It clones over SSH. The private half stays in the secret manager '` + `'\u2014 never shown, logged or stored.'` |
| now `:456-457` | §7 §7-table proposed column, verbatim |

Rendered: `It clones over SSH. The private half stays in the secret manager — never shown, logged or stored.`
Matches §4b row 1. The prohibition clause `— never shown, logged or stored.` is carried **verbatim**
from string A, as §10 requires. **Em dash preserved as `\u2014`; no punctuation normalised.**

**Site 2 — key-meta eyebrow, desktop, was `:542`**

| | |
|---|---|
| before | `'ed25519 \u00b7 created on this device \u00b7 the private half stays in the keychain'` |
| after | `'Generated on the server \u00b7 the private half stays in the secret manager'` |
| now `:519` | §7 §4a FIT-verified 70-char variant — **not** the 80-char string. See §0. |

**Site 3 — `Ev Body`, mobile, was `:978-982` (string literals `:979-980`)** — byte-identical duplicate of
Site 1; same before/after; now `:955-956`.

**Site 4 — key-meta eyebrow, mobile, was `:1038`** — same as Site 2; now `:1014`.

All four were byte-identical pairs, applied as verified-count replacements (asserted `expect=2`,
`actual=2` before writing). The ` · ` separators stay as `\u00b7`, matching the file's existing
convention at `:532`/`:1028`.

**Boards/build divergence, both axes:** the **body** is now corrected in the build (§4b string applied).
The **eyebrow** is A3-correct in the build but, per §0, is the 70-char variant while the boards carry the
80-char — a **new, disclosed** divergence on that one axis, traded deliberately for the fit instruction.

### Part 2 — the three forbidden footer sites

| # | site (original) | action | now |
|---|---|---|---|
| 1 | `:314` `_buildFooter` **call site** | call removed | gone |
| 2 | `:380` duplicate `ContentRule` inside `_buildFooter` | removed with the block | gone |
| 3 | `:383-384` the footer copy string | removed with the block | gone |
| 4 | `:317-319` desktop `TechnicalDetails(note:)` | `note:` dropped | `:314-315` |
| 5 | `:926-928` mobile `TechnicalDetails(note:)` | `note:` dropped, new args added | `:904-907` |

**`_buildFooter` deleted entirely** (original `:375-389`, 15 lines) — the source of both the copy string
and the duplicate rule, exactly as `27ea6536` follow-up #4 directs. Verified gone:
`grep -c "_buildFooter" add_product_page.dart` → **0**. It was the **only** caller-free method; no other
caller existed. The other four `_DesktopAddProduct` methods (`_buildBreadcrumb`, `_buildH1`,
`_buildStatusRow`) are intact.

Desktop footer band now:

```dart
313             const SizedBox(height: 24),
314             TechnicalDetails(
315               lines: [
```

Mobile footer band now:

```dart
903                   const SizedBox(height: 20),
904                   TechnicalDetails(
905                     showRule: false,
906                     disclosureAlignment: DisclosureAlignment.start,
907                     lines: [
```

**Desktop's spec is produced by defaults alone — zero new arguments**, confirming the dispatch: divider
painted (`showRule` default `true`), disclosure pushed to the trailing edge by the expanded note slot
(`disclosureAlignment` default `end`), and no copy (`note` is `null`). Result: **divider + right-aligned
`Show technical details` + no copy**, which is `27ea6536`'s desktop spec verbatim.

**One judgment call I made and am flagging:** I also removed the `const SizedBox(height: 12)` that sat
between `_buildFooter(context)` and `TechnicalDetails`. It existed only to separate `_buildFooter`'s copy
from `TechnicalDetails`' rule; with `_buildFooter` deleted it would have stacked on the `SizedBox(24)` to
make a 36px gap. The surviving `SizedBox(24)` is the content→disclosure-band gap and matches mobile's
`SizedBox(20)`. `27ea6536` rules on copy, alignment and the divider — **not** on vertical rhythm, and I
had no board measurement for it. Recorded as a non-blocking finding.

**Duplicate rule resolved:** the desktop footer previously painted **two** `ContentRule`s and **two** copy
lines. It now paints **one** rule and **no** copy. Remaining `ContentRule`s in the file are at
`:300, 627, 653, 796, 851, 879` — all in-page/panel rules, none in either footer band.

---

## 5. Part 3 — the shared primitive

**Citation corrected:** `lib/shared/design_primitives.dart`, **not** `lib/core/`. Cited `:396` is exact.

### Signature change, with defaults

```dart
enum DisclosureAlignment { start, end }

const TechnicalDetails({
  super.key,
  required this.lines,
  this.note,
  this.showRule = true,                            // default = today's behaviour
  this.disclosureAlignment = DisclosureAlignment.end,  // default = today's behaviour
});
```

**Both new parameters default to today's rendering.** `showRule = true` keeps the `ContentRule` painted;
`disclosureAlignment = .end` keeps the note slot expanded so the disclosure sits at the trailing edge.

### Behaviour matrix — all four cases

| alignment | `note` | rendered children of the `Row` | disclosure | == today? |
|---|---|---|---|---|
| `end` (default) | `null` | `Expanded(SizedBox.shrink())`, `InlineLink` | trailing (right) | ✅ **identical** — this is desktop after my change |
| `end` (default) | non-null | `Expanded(Text(note))`, `InlineLink` | trailing (right) | ✅ **identical** — the 7 other callers |
| `start` | `null` | `InlineLink` only | **leading (left)** | new — mobile after my change |
| `start` | non-null | `Flexible(Text(note))`, `InlineLink` | leading (left) | new — no caller |

Rows 1–2 are **byte-identical widget trees to before**. This is why I kept `Expanded(...)` on the
`end` branch rather than switching both branches to `Flexible` — dropping the `Expanded` would have moved
the disclosure to the **left** on every screen in the app, which is exactly the regression the dispatch
warns about.

### CALLER COUNT — BEFORE AND AFTER

| | matches for `TechnicalDetails(` | class declaration | **construction call sites** |
|---|---|---|---|
| **BEFORE** | 17 | 1 | **16**, across 13 files |
| **AFTER** | 17 | 1 | **16**, across 13 files |

**Unchanged.** Per-file counts identical before and after
(`home_page` 2, `add_product_page` 2, `runs_page` 2, and 1 each in `products_page`, `run_detail`,
`model_policies`, `model_executions`, `model_stats`, `needs_you`, `decision_detail`, `product_detail`,
`state_views`, `detail_sections`).

**`showRule` / `disclosureAlignment` are passed at exactly ONE call site** — `add_product_page.dart:905-906`,
mobile. Grep-confirmed: no other file mentions either name. **7 other call sites still pass `note:`**
(`home_page:129`, `products_page:131`, `model_policies:123`, `model_executions:155`, `model_stats:124`,
`product_detail:442`, `runs_page:196`) and all take the unchanged default path.

**No other form's rendering shifts.** Combined with `flutter analyze` clean and 190/190 green, no
regression is detectable in any other screen's footer.

### One judgment call in the primitive

With `showRule: false`, the `const SizedBox(height: 13)` between the rule and the row is retained, so it
becomes leading top spacing. On mobile that puts the disclosure 33px below the register panel (20 parent
+ 13). Suppressing the gap as well would give 20px. `27ea6536` specifies **left-alignment and no divider**,
and says nothing about vertical rhythm; I removed the divider only, which is the minimal authorised
change. Non-blocking finding — a design lane with the board coordinates should confirm the Y.

---

## 6. Ownership

```
OWNED_PATHS:
  - apps/control_plane/lib/features/products/add_product_page.dart
  - apps/control_plane/lib/shared/design_primitives.dart   (TechnicalDetails primitive ONLY)
        ^^ dispatch cited lib/core/design_primitives.dart, which does not exist; see section 2
  - apps/control_plane/test/**            (NO test added — see section 8)
READ_ONLY_PATHS: apps/**, packages/**, docs/**, .decisions/**
PROHIBITED_PATHS (none touched):
  - packages/**            — no server-side work; substrate unbuilt
  - apps/server/**         — untouched
  - docker/**, .github/**  — untouched; ZERO Docker/Compose commands issued
  - .decisions/**, docs/adr/**, WORK_STATE.md, LANES.md
  - apps/control_plane/test/failures/**   — untouched, unstaged, unreverted
```

`git status --porcelain` → exactly two modified files. Nothing else.

---

## 7. Validation results

Baselines were measured **by me on the pristine tree first**, not taken on trust.

| Command | Baseline (measured by me) | Result | Evidence |
|---|---|---|---|
| `dart format --output=none --set-exit-if-changed .` | 631 files, 0 changed | **pass** | `Formatted 631 files (0 changed)`, exit **0** |
| `cd apps/control_plane && dart format --output=none --set-exit-if-changed lib test` | 110 files, 0 changed | **pass** | `Formatted 110 files (0 changed)`, exit **0** |
| `cd apps/control_plane && flutter analyze` | `No issues found!` | **pass** | `No issues found! (ran in 13.2s)` |
| `cd apps/control_plane && flutter test` | 190/190 | **pass** | `02:40 +190: All tests passed!` |
| `make test-integration` | n/a | **NOT_RUN** | This is a copy change with no data path. No database needed. |
| Docker / Compose — any command | n/a | **NOT_RUN** | **Zero issued**, of any kind, mutating or read-only |

### A gate failure I introduced and fixed — disclosed

After my first body-copy edit, `flutter analyze` returned **2 issues** (baseline 0):
`prefer_single_quotes` at `:459:13` and `:957:13`. Cause: the original string
`"…stays in this device's keychain…"` needed double quotes **because it contains an apostrophe**; the
approved replacement has none, so the doubles became unnecessary. Fixed by switching the delimiter to
single quotes at both sites — **the rendered string is byte-identical** (verified: both sites concatenate
to `It clones over SSH. The private half stays in the secret manager — never shown, logged or stored.`).
Analyze returned to `No issues found!` and format to 0 changed. **Not a weakened test** — no test,
skip, `@Ignore` or exclusion was touched at any point.

### A phantom baseline failure I investigated — disclosed

My **first** repo-root format run reported **`Formatted 631 files (69 changed)`, exit 65**, against a
stated baseline of 0 changed — a discrepancy I did not absorb. Investigation:

- All 69 were in **`apps/server`** (a PROHIBITED path for me); **zero** in `apps/control_plane`.
- The canonical checkout at the same `52d0894` reported **631 files, 0 changed**.
- Both checkouts lacked a per-package `.dart_tool/package_config.json`; this repo is a **pub workspace**
  (`pubspec.yaml` `workspace:` lists 12 packages) resolved at the **root**, and the fresh worktree had
  never had `pub get` run.
- Cause: with no `package_config.json`, `dart format` inferred an older language version and used the
  **pre-3.7 short style** against tall-style-formatted `apps/server` sources. `flutter pub get` in
  `apps/control_plane` (workspace root) restored resolution; the gate then reported
  **`631 files, 0 changed`, exit 0**, matching the stated baseline exactly.

**Finding for the Manager:** *a freshly created worktree fails the format gate with phantom changes in
`apps/server` until `flutter pub get` has been run.* A lane that "fixes" those 69 files would corrupt a
prohibited path while chasing an artifact. Classified `WORKFLOW_IMPROVEMENT`.

### Gates do NOT cover this change — stated plainly

**Zero of 26 test files import `add_product_page.dart`. Zero reference `TechnicalDetails`. Zero import
`design_primitives.dart`.** Verified directly:

```
apps/control_plane/test/**: 26 *_test.dart files
grep -rln "add_product_page" apps/control_plane/test/  ->  0
grep -rln "design_primitives" apps/control_plane/test/  ->  0
grep -rn  "TechnicalDetails"  apps/control_plane/test/  ->  0
```

Therefore: **the passing gates above verify that the change compiles, analyses clean, formats clean, and
breaks nothing that was already tested. They verify NONE of the seven copy strings, and none of the
footer alignment or divider behaviour.** Those rest on the source reading in §3–§5, which a human or an
independent reviewer must confirm against the boards. **I added no tests** (see §8).

---

## 8. Test coverage — NOT ADDED, stated plainly

**I added no tests.** Reason: this repository has **zero** widget-test infrastructure for either owned
file, and adding the first would mean constructing `_AddProductView` (a `BlocBuilder` over
`ControlPlaneRepository`) and a `TechnicalDetails` harness — new test architecture, not coverage for a copy
change, and `runtime=` remains `n/a` regardless since no browser/visual evidence was captured. The gates
are honest about what they cover and what they do not (§7, last paragraph). **A reviewer should not read
`tests=pass` as evidence that the new copy renders.** If you want executable coverage of the seven
strings, that is a scoped follow-up and I would rather it be granted explicitly than have it inferred.

---

## 9. Files touched

```text
apps/control_plane/lib/features/products/add_product_page.dart
apps/control_plane/lib/shared/design_primitives.dart
```

Both inside `OWNED_PATHS`. Diffstat: **2 files, +42 −44** (after the quote-style fix).
`git status --porcelain` shows nothing else.

## 10. Documentation updated

```text
none
```

`.decisions/**` and `docs/adr/**` are PROHIBITED — read only. The §0 eyebrow conflict and the §5 spacing
judgment are **reported here for the Manager to route**, not persisted unilaterally.

---

## 11. What changed and why

- **Four false-custody strings corrected** to the §7 human-approved copy. The private half is not on the
  device and not in any local keychain, and generation is server-side — `9417f8bf` A3 as scoped by its
  2026-10-07 note. Source of truth read, not invented.
- **Eyebrow uses §7's FIT-verified 70-char variant** per the dispatch's explicit instruction; the 80-char
  string is not a drop-in (measured 392.78px vs a 380px box). **Consequences disclosed in §0** —
  `ed25519` dropped, boards diverging on this axis.
- **Footer copy removed on both platforms** and `_buildFooter` deleted entirely — `27ea6536`: "no footer
  copy on either platform". This also removed the duplicate `ContentRule`, which is the same duplicate
  `27ea6536` §context and follow-up #4 record.
- **`TechnicalDetails` extended** with `showRule` and `disclosureAlignment`, both defaulted to today's
  behaviour. Desktop's spec falls out of `note: null` with **no new arguments**; mobile's left-aligned,
  no-divider spec was **not expressible** before and is now. Level 1 design-system-owner notification, not
  a human gate — the outcome is settled by `27ea6536`.
- **New abstraction / interface change:** one new top-level `enum DisclosureAlignment { start, end }` and
  two optional constructor parameters on a shared primitive. **No state, ownership, schema or interface
  change. No server-side, contract or data-path change.**
- **Deviation from plan:** (a) the eyebrow variant, §0; (b) removal of the orphaned
  `const SizedBox(height: 12)`, §4; (c) `lib/shared/` instead of the non-existent `lib/core/`, §2.

## 12. Discoveries

1. **`CONTRADICTION` / `DESIGN_DISCOVERY` — the two approved copy sources conflict on the eyebrow, and
   following the dispatch's fit instruction re-opens a boards/build divergence.** §7 §7-table and its
   divergence table make the 80-char string the approved **sync** value ("no new copy needed"); §3/§4a/§6
   and the dispatch forbid it as an overflow. Following the fit instruction drops `ed25519` (its only
   occurrence) and puts the build at odds with the boards on that axis. **Needs a design-lane decision.**
2. **`PROJECT_FACT` — the 380px/392.78px measurement belongs to `BP · Rotate Key`'s `Art Sub`, a different
   board from the Add Product key-meta eyebrow the dispatch cites at `:542`/`:1038`.** §7 §4a places
   `Art Sub` on `BP · Rotate Key · Dark/Light`. And in the build the string is a wrapping `Text` with
   viewport-dependent width, so no fixed box applies. **Generalisable: a fit verdict measured on one
   board's layer does not transfer to a different board, nor to code.**
3. **`WORKFLOW_IMPROVEMENT` — a fresh worktree fails the format gate with phantom `apps/server` changes
   until `flutter pub get` has run.** The repo is a pub **workspace** resolved at the root; without
   `package_config.json` the formatter infers an older language version and applies pre-3.7 short style.
   69 phantom changes, all in a prohibited path. See §7.
4. **`PROJECT_FACT` — the dispatch's `lib/core/design_primitives.dart` does not exist**; the primitive is
   at `lib/shared/design_primitives.dart`. Another instance of the citation-drift failure mode this work
   item already paid for twice.
5. **`PROJECT_FACT` — deleting a Dart method from a `StatelessWidget` needs the correct closing-brace
   anchor.** `_buildFooter` is preceded by `_buildStatusRow`, not `build`; anchoring on the wrong
   preceding `    );`/`  }` pair silently removed another method's closing brace. Caught by `dart format`
   (exit 65, parse error), **not** by review. **Generalisable: run the formatter after a structural
   deletion — it is a parser, and a brace error is loud there and quiet in review.**
6. **`PROJECT_FACT` — the `TechnicalDetails` note slot's `Expanded` is load-bearing for the disclosure's
   position.** Removing it moves the disclosure to the **left** on all 16 call sites. Any future
   refactor of that row must keep `Expanded` on the trailing-edge path.

## 13. Knowledge persisted

**none.** Per `aef-repository-learning`: `PROJECT_FACT`s 3–6 are reported here for the Manager to route.
`WORKFLOW_IMPROVEMENT` (3) and the reusable generalisations in (2) and (5) are independent-review
authority, not mine. The §0 copy conflict is a **CONTRADICTION touching design content** — human/design
authority, escalated here rather than persisted. I hold no authority to write a knowledge base, and
`.decisions/**` and `docs/adr/**` are PROHIBITED to me.

## 14. Blockers

**None blocking implementation.** All required gates pass at their measured baselines.

**Findings for the Manager, in priority order:**

1. **Eyebrow copy conflict (§0) — route to a design lane.** Decide: (a) accept the 70-char variant and
   correct the boards to match; (b) approve a fitting string that **keeps `ed25519`** (none exists in §7 —
   authoring one is a copy decision, not mine); or (c) confirm the 80-char string fits the build and
   accept the board divergence. **Until then the build's eyebrow diverges from the boards.**
2. **`ed25519` no longer appears anywhere on the Add Product page** (§0). Content loss to confirm.
3. **Boards still carry the forbidden footer copy.** All four desktop `S` boards carry the 100-char
   `Footer` text layer at (236, 862) 1020×15 — measured twice by independent lanes (`27ea6536`'s G-19
   scope note and §8 of the draft). **The build now matches `27ea6536`; the boards do not.** That is the
   open **G-18** ownership gap, blocked on the Penpot instance binding. **Out of my grant** — I touched no
   board.
4. **Vertical-rhythm judgment calls** (§4 `SizedBox(12)`; §5 the retained `SizedBox(13)` with
   `showRule: false`) — confirm against board coordinates.
5. **`Runtime/visual = n/a`.** No browser or visual evidence was captured. **No claim is made that the
   rendered footer matches the boards.** Confirming that needs a design-system-owner visual pass.
6. **`9417f8bf` A3 remains UNVERIFIED.** The substrate (`SecretProvider`, the three endpoints) does not
   exist; I built nothing against it per instructions. A3's reachability probe (that decision's follow-up
   action 4, owner `implementer`) is **still not done** and cannot be discharged by this lane — it needs a
   separate grant and runtime probe.
7. **Per the draft's §7 note, extracting the two duplicated `_buildInfoPanel`/`_buildKeyBox` copy pairs
   into constants** would stop them drifting again. Flagged by that lane as a suggestion; **not** done,
   as it is outside this grant's scope of copy correction.

## 15. Safe parallelism

```yaml
SAFE_PARALLEL_WORK:
  - independent engineering review of this HEAD_SHA (52d0894, uncommitted tree)
  - the design lane work in findings 1-3 above (no overlap with these two files)
PROHIBITED_PARALLEL_WORK:
  - any lane writing apps/control_plane/lib/features/products/add_product_page.dart — I own it
  - any lane writing apps/control_plane/lib/shared/design_primitives.dart — I own TechnicalDetails there
  - any Penpot board edit touching the footer copy — needs the G-18 ownership grant first
```

## 16. Cleanup confirmation

- [x] **ZERO Docker or Compose commands issued** — none, mutating or read-only. Not `info`, `ps`, `logs`,
      `config`, `down`, `up`, or any other. This repository has already lost its QA database to a lane
      running `docker compose -f docker/compose.qa.yaml down -v --rmi local`; I did not test that rule.
      I also verified no control_plane test shells out to Docker before running `flutter test` (the three
      `docker` hits are string literals in a widget test).
- [x] No process, container or compose project started; nothing left running.
- [x] `flutter pub get` was run (required to make the format gate meaningful — §7). Its only output is
      gitignored `.dart_tool/`, which does not appear in `git status`.
- [x] `apps/control_plane/test/failures/**` untouched — not staged, not reverted, not cleaned (0 entries).
- [x] Nothing written outside `OWNED_PATHS`; `git status --porcelain` lists exactly 2 files.
- [x] No test weakened, skipped, deleted or `@Ignore`d.
- [x] **Nothing committed, nothing pushed.** Tree left dirty for the Manager. **COMMITTED: NO.**
- [x] **I do not approve my own work.**

## 17. Recommended next action

`INDEPENDENT_ENGINEERING_REVIEW`

---

```
RESULT: IMPLEMENTED

FEATURE: Add Product rebuild — correct the false key-custody copy and the forbidden footer copy in the build
BRANCH: implement/add-product-custody-and-footer
BASE_SHA: 52d0894
HEAD_SHA: 52d0894   (uncommitted working tree at /private/tmp/shipit-implement-custody-footer)

OWNED_PATHS:
  - apps/control_plane/lib/features/products/add_product_page.dart
  - apps/control_plane/lib/shared/design_primitives.dart   (TechnicalDetails primitive only;
      the dispatch's cited lib/core/design_primitives.dart DOES NOT EXIST — disclosed)
  - apps/control_plane/test/**   (no test added — see report §8)
READ_ONLY_PATHS: apps/**, packages/**, docs/**, .decisions/**
PROHIBITED_PATHS:
  - packages/**, apps/server/**, docker/**, .github/**
  - .decisions/**, docs/adr/**, WORK_STATE.md, LANES.md
  - apps/control_plane/test/failures/**   (untouched)

FILES_CHANGED:
  - apps/control_plane/lib/features/products/add_product_page.dart
  - apps/control_plane/lib/shared/design_primitives.dart

GATES:
format=pass   (dart format --output=none --set-exit-if-changed . -> "Formatted 631 files (0 changed)", exit 0;
              baseline 631/0 measured by me on the pristine tree first. Also run scoped per the dispatch
              VALIDATION_COMMANDS: dart format --output=none --set-exit-if-changed lib test ->
              "Formatted 110 files (0 changed)", exit 0)
analyze=pass  (cd apps/control_plane && flutter analyze -> "No issues found! (ran in 13.2s)";
              baseline "No issues found!" measured first. One intermediate FAIL of 2 prefer_single_quotes
              infos was introduced by me and FIXED; see report §7)
tests=pass    (cd apps/control_plane && flutter test -> "02:40 +190: All tests passed!";
              baseline 190/190 measured first. NOTHING is weakened/skipped/deleted)
build=n/a     (no build target in scope for this Dart/Flutter app; flutter analyze is the compile-level gate)
runtime=n/a   (no browser/visual evidence captured; no claim made that the rendered footer matches the
              boards — needs a design-system-owner visual pass. See BLOCKERS 5.)

DISCOVERIES:
  - CONTRADICTION (route to design): the two approved copy sources conflict on the key-meta eyebrow.
    I followed the dispatch's explicit "use the variant from section 7, not the 80-char string"
    instruction and shipped the 70-char FIT-verified string. That DROPS "ed25519" (its only occurrence
    on the page) and RE-OPENS a boards/build divergence on the eyebrow axis. A3-correctness holds either
    way. Not decided by me — flagged, report section 0.
  - PROJECT_FACT: the 380px/392.78px overflow measurement belongs to "BP - Rotate Key"'s "Art Sub",
    a DIFFERENT board from the Add Product key-meta eyebrow cited at :542/:1038; and in the build the
    string is a wrapping Text with viewport-dependent width, so no fixed 380px box applies.
  - WORKFLOW_IMPROVEMENT: a fresh worktree fails the format gate with 69 PHANTOM "changed" files, all in
    apps/server, until `flutter pub get` has been run — the repo is a pub WORKSPACE resolved at the root,
    and without package_config.json the formatter applies pre-3.7 short style. A lane chasing this would
    corrupt a prohibited path.
  - PROJECT_FACT: the dispatch's cited lib/core/design_primitives.dart does not exist; the primitive is at
    lib/shared/design_primitives.dart.
  - PROJECT_FACT: deleting a Dart method needs the correct closing-brace anchor. _buildFooter is preceded
    by _buildStatusRow, not build; the wrong anchor silently removed another method's closing brace. Caught
    by `dart format` (exit 65), not by review. Run the formatter after any structural deletion.
  - PROJECT_FACT: the TechnicalDetails note slot's Expanded is load-bearing for disclosure POSITION —
    removing it moves the disclosure to the LEFT on all 16 call sites.
  - Unverified by any gate: ZERO of 26 control_plane test files import add_product_page.dart; zero
    reference TechnicalDetails; zero import design_primitives.dart. The gates verify compile/analyze/
    format/no-regression ONLY. They verify none of the seven strings nor the footer alignment/divider.

KNOWLEDGE_PERSISTED:
  none — this lane persists no knowledge base. Discoveries 2-6 are reported for the Manager to route
  under aef-repository-learning authority levels; the eyebrow CONTRADICTION is design/human authority.

BLOCKERS:
  None blocking. All required gates pass at their measured baselines. Open findings routed upward:
  1. Eyebrow copy conflict (above) — design-lane decision: accept 70-char and correct the boards, approve
     a fitting string that KEEPS ed25519, or confirm 80-char fits the build.
  2. "ed25519" no longer appears anywhere on the Add Product page — content loss to confirm.
  3. BOARDS still carry the forbidden footer copy (100-char "Footer" text layer at 236,862 1020x15 on all
     four desktop S boards; at least 4 boards across 2 families per the draft's section 8). The BUILD now
     matches 27ea6536; the boards do not. Open G-18 ownership gap, blocked on the Penpot binding, outside
     my grant. I touched no board.
  4. Vertical-rhythm judgment calls to confirm against board coordinates: removal of the orphaned
     SizedBox(height: 12) after deleting _buildFooter, and retaining SizedBox(height: 13) under
     showRule: false (33px vs 20px above the mobile disclosure).
  5. runtime/visual = n/a; no evidence the rendered footer matches the boards.
  6. 9417f8bf A3 remains UNVERIFIED — substrate does not exist, nothing built against it, reachability
     probe (that decision's follow-up action 4) still not done and not dischargeable by this lane.
  7. Extracting the two duplicated _buildInfoPanel/_buildKeyBox copy pairs into constants (draft section 7
     suggestion) NOT done — outside this grant.

READY_FOR_INDEPENDENT_REVIEW: YES
```