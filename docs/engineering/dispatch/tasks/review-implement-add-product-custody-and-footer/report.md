# Report — review-implement-add-product-custody-and-footer

```yaml
RESULT: DO_NOT_MERGE
TASK_ID: review-implement-add-product-custody-and-footer
TASK_TYPE: review
FEATURE: Add Product rebuild — build-side custody and footer copy correction (focused independent review)
WORKTREE: /private/tmp/shipit-implement-custody-footer
BRANCH: implement/add-product-custody-and-footer
BASE_SHA: 52d0894
HEAD_SHA: 52d0894   (UNCOMMITTED working tree — nothing committed, nothing pushed)
COMMITTED: NO
REVIEWED_HEAD: 52d0894 + uncommitted working tree at /private/tmp/shipit-implement-custody-footer
```

---

## 0. Bottom line

The change is **mechanically clean**. I re-verified every proof the implementer offered and every
gate, and I found **no defect in the execution**. The trap was avoided, the shared primitive is
correctly extended with no cross-screen regression, no test was weakened, no prohibited path was
touched, and all three gates pass when re-run by me.

It is nevertheless **not mergeable**, because **one shipped string is wrong** — and it is wrong
because the **dispatch**, not the approved copy source, was defective. The approved source names a
different value for that slot. I resolved that question from the artifacts; what remains is a
**copy/design decision** (which words ship on the custody axis, and whether the boards converge or
diverge), which no implementation lane may take. Hence `HUMAN_DECISION_REQUIRED: YES`.

**The implementer was right to escalate and should not be faulted.** It flagged the conflict three
times, correctly diagnosed that the 380px fit measurement belongs to a different board, and refused
to invent copy. Its process was correct; the artifact it was following was not.

---

## 1. Provenance — VERIFIED

| Check | Result |
|---|---|
| `git rev-parse --short HEAD` in worktree | `52d0894` |
| `git rev-parse --abbrev-ref HEAD` | `implement/add-product-custody-and-footer` |
| `git status --porcelain` | exactly 2 modified files, both declared-owned |
| `git log --oneline -n 3` | `52d0894 docs(boards): F5 copy drafted and approved…` |
| nothing committed / nothing pushed | CONFIRMED — `HEAD_SHA == BASE_SHA`, tree dirty |

**main = `2dd2b3e`, and the advance IS bookkeeping only — VERIFIED, not assumed.**
`git diff --stat 52d0894..main` returns **4 files, all under
`docs/engineering/dispatch/tasks/`** (`design-apply-f5-copy/report-r3.md`, `report-r4.md`, and this
lane's `prompt.md`/`report.md`). **No production code moved on main**, so the reviewed revision does
not conflict with it and no rebase is needed.

I read `report-r3.md` and `report-r4.md` on main because they bear directly on the eyebrow conflict
(§3 below). They changed nothing about the reviewed tree; they *decided* it.

---

## 2. The seven verify-items — explicit verdicts

### ITEM 1 — THE TRAP, `:409-411` mid-page prose · **VERDICT: PASS**

Three independent proofs, each re-derived by me:

**(a) No diff hunk overlaps the region.** I parsed the hunk headers programmatically rather than
trusting the report. Original-line ranges touched: `314-315, 317-319, 374-389, 480-481, 542,
926-928, 979-980, 1038`. Intersection with `409-411`: **NONE**. Nearest hunk edges are `389` and
`480` — 20 lines clear on both sides.

**(b) Only one survivor, and it is the distinguishable one.** In `HEAD` the string occurs **3×**
(`:318`, `:410`, `:927`); in the working tree it occurs **1×**, at `:389`:

```dart
389          'Registering records the product. Nothing is governed until you '
390          'approve a baseline.',
```

The survivor carries the **`until you `** line break — the mid-page variant. The two removed ones
both ended the literal after `until `. **A text-level search-and-replace could not have produced
this outcome**, because the surviving text is a strict superstring-prefix of the deleted text's
first line. Each removal was scoped by call site.

**(c) Byte-exact.** `md5` of original `406-412` and of working `385-391` are both
`f554ab3d7eb520546d66108afe440d2e` — **identical**, offset −21, which reconciles exactly
(2 + 3 + 16 = 21 removed lines above it).

**This is the one finding that would have made the change wrong, and it is not present.** Copy the
decision never condemned survived intact.

*Correction to the report:* its proof 1 lists the deleted range as `372-389`; the hunk range is
`374-389` (the blank separator line 374 went with the block; `_buildFooter` itself is `375-389`,
15 lines, as reported). Immaterial — neither range comes near 409-411.

### ITEM 2 — THE SHARED PRIMITIVE · **VERDICT: PASS**

All three numbers independently re-measured:

| measure | before (`HEAD`) | after | claim holds? |
|---|---|---|---|
| raw `TechnicalDetails(` matches | **17** | **17** | YES — unchanged |
| of which: class declaration | 1 | 1 | YES |
| of which: **construction call sites** | **16** | **16** | YES — unchanged |
| distinct files | 13 | 13 | YES |

Per-file counts identical before and after (`home_page` 2, `add_product_page` 2, `runs_page` 2, and
1 each in the other ten files). **No call site added, removed or moved.**

> The brief told me the params are passed at "2" sites. The implementer said **one**. My
> measurement agrees with the implementer: **1 call site** (`add_product_page.dart:905-906`),
> carrying 2 arguments. Repo-wide, `showRule` / `disclosureAlignment` / `DisclosureAlignment` appear
> nowhere else. The brief's "2" is the argument count.

Then the four regression checks:

- **`Expanded` is still on the trailing-edge path.** `design_primitives.dart:426` — present, inside
  the `disclosureAlignment == DisclosureAlignment.end` branch. **The dispatch's specific warning is
  honoured.** With default params and a null note the Row still sizes to `maxMainSize`, so the
  disclosure still lands at the trailing edge.
- **The `start` path does not collapse the row.** `InlineLink` is an **unconditional** child
  (`:433`); with `note == null` the Row has exactly one child. I confirmed RenderFlex semantics
  against the pinned SDK (`fvm/versions/3.44.7`) rather than assuming: `_computeSizes` states
  *"The first pass lays out non-flex children"*, and `performLayout` assigns offsets by accumulating
  `childMainPosition` **in child order**, so the first child always leads.
- **`showRule: false` is reachable and suppresses the rule.** `:418` — `if (widget.showRule) const
  ContentRule()`. Reached by the one call site. **Yes, it actually suppresses it.**
- **The default path is semantically identical.** The only edit on that path is hoisting
  `ShipItType.monoMeta.copyWith(color: palette.inkTertiary)` into `noteStyle` (`:401`). `copyWith` is
  pure, so the resulting `TextStyle` is equal. **No other screen's rendering shifts.** The 7 sites
  that still pass `note:` (`home_page:129`, `products_page:131`, `model_policies:123`,
  `model_executions:155`, `model_stats:124`, `product_detail:442`, `runs_page:196`) — all 7
  confirmed present, all on the unchanged default path.

**Both defaults reproduce today's rendering exactly** (`showRule = true`,
`disclosureAlignment = DisclosureAlignment.end`).

I also confirmed the rendered result against the decision `.decisions/27ea6536…yaml`, whose text
says desktop = *"a divider, and a **right-aligned** `Show technical details` text button. **No footer
copy.""* and mobile = *"**left-aligned, with no divider**. **No footer copy."*" Desktop gets both
**for free from defaults with zero new arguments** (`:314`); mobile gets them from the two new
arguments (`:905-906`). Both match the decision verbatim.

### ITEM 3 — THE EYEBROW · **VERDICT: DEFECT (not a documented trade)**

This is the finding. My position, with the evidence.

**What shipped:** `Generated on the server · the private half stays in the secret manager`
(70 chars, no `ed25519`) at `:519` and `:1016`.

**What the approved copy source says that slot's value is.** `design-draft-f5-copy/report.md` §7,
line 299, for exactly `:541-544` / `:1037-1040`:

| current code | proposed code | board counterpart |
|---|---|---|
| `'ed25519 \u00b7 created on this device \u00b7 the private half stays in the keychain'` | `'ed25519 \u00b7 generated on the server \u00b7 the private half stays in the secret manager'` | `Key Meta` / `Art S` — **already correct on all 12 boards** |

I grepped §7 (lines 289-324) for the shipped 70-char string: **NOT PRESENT.** §7's proposal *is* the
80-char string, `ed25519` included.

**Where the 70-char actually comes from.** §4a line 215 and §3 line 181 — `BP · Rotate Key ·
Dark/Light`, layer **`Art Sub`**, box 380×18. That row's **current** string is a different sentence
(`Generated here · the private half never leaves the keychain`). It is a different board family and
a different layer.

**A third artifact settles it.** `design-apply-f5-copy/report-r3.md` maintains its own string
registry: the 70-char string is registered as **`H`** and scoped to **`Art Sub` ×2** (line 299),
while §9.3 (line 486), headed *"The four custody sites (unchanged from r1/r2, re-verified)"*, states
the eyebrow's required value as the **80-char with `ed25519`**. **Three independent artifacts agree:
the 70-char belongs to `BP · Rotate Key`; the Add Product eyebrow's approved value keeps `ed25519`.**

**Therefore the dispatch's premise is false.** It said *"Use the variant from §7, not the 80-char
string"* while its own Part 1 table listed the 80-char as the replacement — §7's variant IS the
80-char string. Its fit warning (392.78px vs a 380px box) was imported from §4a's `Art Sub`, a layer
that is not this one. **The dispatch conflated two rows of the source it cited.** The dispatch
prompt's own warning is worth repeating: this work item has a record of a lane adopting a citation
that was 43 lines wrong; here the failure is one level up, in the citation's *interpretation*.

**Why this is a defect and not a documented trade.** A trade would be choosing between two approved
values. Here the implementer shipped a string that **no approved artifact ever proposed for this
slot**, validated against a box that **does not belong to this slot**. Consequences:

1. **Boards/build divergence re-opened on the axis this work item exists to close.** Draft §7's
   divergence table classifies the eyebrow axis as a pure **sync** — *"already correct on all 12
   boards … no new copy needed, this is a sync."* The shipped value makes the build disagree with
   all 12 boards.
2. **Content loss — but smaller than the implementer reported.** Its BLOCKERS item 2 states
   *"`ed25519` no longer appears anywhere on the Add Product page"*. **That is factually wrong.**
   `add_product_page.dart:135` builds `publicKey: 'ssh-ed25519 $base64Key shipit+$productName'`, and
   that key **is rendered** via `SelectableText(deployKey.publicKey)` at `:526` and `:1021`. The
   algorithm remains visible on the page; what is lost is its *prose* statement. This materially
   de-escalates that finding — and it is a factual correction the human should have before deciding.
3. **The sentence is true.** The shipped value asserts server-side generation and secret-manager
   custody, so it does **not** reintroduce the false-custody defect. This is a content/convergence
   defect, not a security one. But shipping a security-copy fix that leaves build and boards
   disagreeing — in the very work item whose purpose is board/build convergence — is worth calling
   out, and it should not be merged and then fixed later.

**The fix is not mine to author.** Shipping §7's own approved 80-char value is the likely answer, but
nobody has measured the Add Product `Key Meta` / `Art S` box; §7 records **no box measurement for
that layer at all**. Choosing between "the approved value, on an unmeasured box" and "commission a
fitting variant that keeps `ed25519`" is a design decision. **Route it.**

**The implementer's framing is also imprecise and the human should know that.** Its §0 says the two
instructions *"cannot both be satisfied"* — an irreconcilable conflict. In fact they **could** both
have been satisfied: §7 was directly checkable and named the 80-char value, and had the dispatch's
misattributed fit warning been ignored as unverified, the implementer would have shipped the correct
string. The conflict was an artifact of the dispatch, not of the sources.

### ITEM 4 — THE GATE FAILURE IT INTRODUCED · **VERDICT: PASS**

The double→single quote fix was at the **delimiter only**. I extracted and decoded the rendered
concatenation at both sites rather than reading the diff:

```
BEFORE: It clones over SSH. The private half stays in this device's keychain — never shown, logged or stored.
AFTER : It clones over SSH. The private half stays in the secret manager — never shown, logged or stored.
APPROVED (§4b string A): It clones over SSH. The private half stays in the secret manager — never shown, logged or stored.
```

**`AFTER` is byte-identical to `APPROVED`.** The em dash is preserved as `\u2014`; no punctuation
normalised. The original genuinely needed doubles (it contains `device's`); the replacement does not,
so `prefer_single_quotes` was correct to fire.

**No test was weakened, skipped or removed.** `git diff --stat -- apps/control_plane/test` → empty
(**zero test files changed**). `@Ignore` / `@Skip` / `skip:` markers: **0 in `HEAD`, 0 in the working
tree**. The 2 infos were fixed, not suppressed.

### ITEM 5 — THE PHANTOM BASELINE · **VERDICT: PASS**

- `git status --porcelain -- apps/server` → **empty. No `apps/server/**` file was modified.** The
  prohibited path is untouched.
- Re-ran the gate myself: repo-root `dart format --output=none --set-exit-if-changed .` →
  **`Formatted 631 files (0 changed)`, exit 0**. Scoped `lib test` → **`Formatted 110 files (0
  changed)`, exit 0**. Both match the claimed baselines exactly.
- Cause claim corroborated: this is a **pub workspace** resolved at the root, and
  `.dart_tool/package_config.json` now exists at the worktree root (created by the implementer's
  `flutter pub get`). Without it the formatter infers an older language version and applies pre-3.7
  short style — which would have "changed" 69 `apps/server` files that are in fact already
  tall-style-formatted. **The diagnosis is sound and the warning is genuinely valuable:** a lane that
  "fixed" those 69 files would have corrupted a prohibited path while chasing an artifact.

### ITEM 6 — ITS OWN MID-COURSE CORRECTION · **VERDICT: PASS**

`_buildStatusRow` is **intact** — working `:356-368` (original `:361-373`, offset −5, which
reconciles with the 5 lines removed above it). `_buildBreadcrumb` `:330-340` and `_buildH1`
`:342-354` are intact. `class _DesktopAddProduct` closes cleanly at `:369`. `grep -c "_buildFooter"`
→ **0**, and the forbidden copy string appears **0×** in `lib/`.

The deletion anchored correctly: original `:373` (`  }`, closing `_buildStatusRow`) is retained, and
`:374` (blank) + `:375-389` (`_buildFooter`, 15 lines) were removed, leaving the class's own `}`.
**The class structure is sound.** Its discovery — *run the formatter after any structural deletion,
it is a parser and a brace error is loud there and quiet in review* — is the single most valuable
thing in the report.

### ITEM 7 — WHAT THE GATES DO NOT COVER · **VERDICT: CONFIRMED — and I disagree with "no coverage needed"**

Independently confirmed, exactly as reported: **26** test files; **0** import `add_product_page.dart`;
**0** import `design_primitives.dart`; **0** reference `TechnicalDetails`, `showRule` or
`disclosureAlignment`.

`READY_FOR_INDEPENDENT_REVIEW: YES` reflects **gates passing**, not visual confirmation that the
rendered footer matches the boards. **That is correctly stated in the report and I confirm it.**

**Judgement on acceptability for this change's risk level — split by risk, because the two halves
are not the same risk:**

- **The 4 copy sites: acceptable with no tests.** These are string literals. A test asserting the
  literal would be a change-detector that breaks on every future copy edit and can never catch a
  *wrong* string. Zero coverage here is the right call, and I would not grant a test.
- **The primitive change: NOT acceptable, and the gap is cheap to close.** This is a
  **shared component with 16 call sites across 13 files, zero tests, and a new branch.** The
  specific invariant the dispatch singled out — *"dropping `Expanded` would move the disclosure to
  the **left** on every screen in the app"* — is **asserted nowhere in the repository.** I verified by
  inspection that it holds, but inspection is exactly what failed to catch this class of change in
  the past.
  The implementer's justification — *"adding the first would mean constructing `_AddProductView`
  (a `BlocBuilder` over `ControlPlaneRepository`) and a `TechnicalDetails` harness"* — is **only half
  right, and the half that matters is wrong.** The `_AddProductView` part is accurate and
  unnecessary. **`TechnicalDetails` is a self-contained `StatefulWidget` with no repository
  dependency**: pumping it needs no bloc, no fixture, no architecture. A harness is ~10 lines.

  **The coverage I would want** (one file, ~40 lines, all four assertions mechanical):

  | # | assertion | guards |
  |---|---|---|
  | 1 | default `TechnicalDetails(lines: […])` renders **one** `ContentRule` | `showRule` default |
  | 2 | `showRule: false` renders **zero** `ContentRule` | `showRule: false` actually suppresses it |
  | 3 | default + null note → the `Show technical details` link's **right edge ≈ the widget's right edge** | **the `Expanded` regression guard — the exact mistake the dispatch warned about** |
  | 4 | `disclosureAlignment: .start` → the link's **left edge ≈ the widget's left edge** | `.start` is reachable and does what it says |

  Assertions 3 and 4 are `tester.getTopLeft/getBottomRight` comparisons — no golden, no pixel tooling,
  no repo claim to inflate. **This is the finding I would hold open longest.**

---

## 3. Ownership, prohibited paths, prohibited resources

| Check | Result |
|---|---|
| Files modified | **2**, both substantively intended (`add_product_page.dart`, `shared/design_primitives.dart`) |
| `apps/server/**` | **untouched** |
| `packages/**` | **untouched** |
| `docker/**`, `.github/**` | **untouched** |
| `.decisions/**`, `docs/adr/**`, `WORK_STATE.md`, `LANES.md` | **untouched** |
| `apps/control_plane/test/failures/**` | **untouched — 0 entries** in `git status --porcelain`; not staged, reverted or cleaned |
| Untracked files | none beyond gitignored `.dart_tool/` |
| Test files modified | **none** |
| Docker/Compose commands by me | **ZERO** — none issued, mutating or read-only-looking. I did not run `make clean`, `make test-env-down`, `make e2e-down`, or any `docker compose …`. I confirmed before running `flutter test` that the only `docker` occurrences in the suite are string literals in `product_detail_page_test.dart` (`:372,374,379`), so the run could not have invoked it. |

**Ownership deviation — the dispatch's defect, not the implementer's.** The dispatch's `OWNED_PATHS`
named `apps/control_plane/lib/core/design_primitives.dart`, **which does not exist** (I confirmed
`lib/core/` holds `colors.dart`, `design_tokens.dart`, `plain_language.dart`, `product_language.dart`,
`text_styles.dart`, `theme.dart`, `theme_controller.dart`). I confirmed there is **exactly one**
`class TechnicalDetails` in the repository, at `lib/shared/design_primitives.dart:364`. The grant's
intent — *"the shared `TechnicalDetails` primitive"*, `READ_ONLY` silent on `lib/shared/**` — is
unambiguous, the implementer disclosed the substitution instead of making it silently, and its edits
in that file are confined to the enum + the `TechnicalDetails` constructor/fields/`build`. **I do not
hold this against the change**; the fix belongs in the dispatch, and `.decisions/27ea6536` cites the
same file without the erroneous `core/` segment, which is how the mistake propagated.

---

## 4. Gates — re-run by me, at the reviewed revision

| Command | Status | Evidence (mine, this session) |
|---|---|---|
| `dart format --output=none --set-exit-if-changed .` (worktree root) | **pass** | `Formatted 631 files (0 changed) in 11.62 seconds.` — **exit 0**. Baseline 631/0 confirmed. |
| `cd apps/control_plane && dart format --output=none --set-exit-if-changed lib test` | **pass** | `Formatted 110 files (0 changed) in 4.28 seconds.` — **exit 0** |
| `cd apps/control_plane && flutter analyze` | **pass** | `No issues found! (ran in 52.9s)` — **exit 0**. Baseline confirmed; 0 infos. |
| `cd apps/control_plane && flutter test` | **pass** | `02:26 +190: All tests passed!` — **exit 0**. Baseline 190/190 confirmed. |
| `make test-integration` | **NOT_RUN** | Not needed — a copy/primitive change with no data path. **Correctly not run.** |
| Docker / Compose (any command) | **NOT_RUN** | **Zero issued.** |
| `runtime` / visual | **NOT_RUN** | No browser or visual evidence. I make **no claim** that the rendered footer matches the boards. |

All four reported baselines reproduce exactly. **No gate was taken on trust.**

---

## 5. Claimed-vs-actual corrections to the implementer's report

I am recording these so the human decides on accurate information, and so the same errors are not
carried into the next lane:

1. **§0 / BLOCKERS 2 — FACTUALLY WRONG.** *"`ed25519` … appears nowhere else on the page — `:542`/
   `:1038` were its only occurrences."* It appears at `add_product_page.dart:135` inside the rendered
   `publicKey: 'ssh-ed25519 …'`, displayed at `:526`/`:1021`. The content loss is **prose-only**.
2. **§0 — IMPRECISE FRAMING.** *"The dispatch's two instructions cannot both be satisfied"* — they
   could. §7:299 directly names the 80-char value; the conflict was manufactured by the dispatch
   misreading its own source (§3 above). Had the implementer tested the dispatch's premise against
   §7 — the file it was told to read — the correct string was discoverable without escalation.
3. **§9 — STALE DIFFSTAT.** Reports `+42 −44` "after the quote-style fix"; the tree is **`+42 −42`**.
4. **§3 proof 1 — RANGE OFF BY 2.** `372-389` vs the actual hunk range `374-389`. Immaterial.
5. **§5 behaviour matrix row 4 — CORRECT, and I checked it hard.** `start` + non-null note renders
   note-then-link. I confirmed against the pinned SDK's `flex.dart` that non-flex children are laid
   out in the first pass and that offsets accumulate in child order, so the first child always
   leads. The matrix's "leading (left)" is accurate; **no defect there.**
6. **The path substitution (§2, §6) — CORRECT AND PROPERLY DISCLOSED.** Called out above.

---

## 6. What I did NOT review

Stated explicitly, per my obligations:

- **The design work item.** I did not re-review the design, the boards, or the F5 draft's proposals
  beyond the four `add_product_page.dart` values and the eyebrow's provenance.
- **The boards themselves.** No Penpot access, no board read, no board edit. I cannot independently
  confirm that all 12 `Add Product` boards currently carry the 80-char string, nor the
  `Key Meta` / `Art S` box geometry. I verified what the **artifacts assert**, which is a different
  claim from what the boards contain. **The human must confirm the boards' current text before
  acting on §3.**
- **Rendered behaviour.** No runtime, no browser, no visual capture. My footer and alignment findings
  are **source-derived**, not rendered-confirmed. I verified widget-tree semantics against the pinned
  Flutter SDK, which is strong for *whether a branch collapses or shifts* and worthless for *whether
  it matches a board*.
- **`9417f8bf` A3 reachability / substrate.** The `SecretProvider` and the three endpoints. I
  confirmed the change is A3-*consistent* copy; I did not and cannot confirm A3's reachability probe,
  which remains outstanding. **The implementer is right that this lane could not discharge it.**
- **The other 15 call sites' screens.** I verified the primitive's default path is byte-equivalent and
  that all 7 remaining `note:` sites are on it. I did **not** individually review each of those 13
  files' layouts — I relied on the default-path equivalence, which is the correct basis.
- **The G-18 Penpot ownership gap** and the boards' stale footer copy. Out of this grant; not touched.
- **`AGENTS.md` §13 / ADR 0018** credential mechanics. The change touches copy only; I confirmed no
  secret value appears anywhere in the diff. All strings are prose.
- **The `27ea6536` decision's own merits** — I verified the build conforms to it, and did not
  re-litigate whether the decision is right.
- **The rest of the work item** (`design/add-product`, `implement/add-product`, and the 25 sibling
  worktrees). Out of scope for a focused review.

---

## 7. Findings by severity

### BLOCKERS

**B1 — The shipped key-meta eyebrow is not the value any approved artifact specifies for that slot,
and it re-opens the boards/build divergence this work item exists to close.**
Shipped at `add_product_page.dart:519` and `:1016`:
`Generated on the server · the private half stays in the secret manager` (70 chars, no `ed25519`).
Approved source says (`design-draft-f5-copy/report.md` §7:299, re-verified at
`design-apply-f5-copy/report-r3.md` §9.3:486):
`'ed25519 \u00b7 generated on the server \u00b7 the private half stays in the secret manager'`.
The 70-char value is registered as string **`H`** and scoped to **`Art Sub` ×2** on `BP · Rotate Key`
(r3:299 / §4a:215) — a different board, a different layer, a different current sentence. The 380px /
392.78px overflow warning belongs to that `Art Sub` box and was never measured against `Key Meta` /
`Art S`, for which the draft records **no box measurement at all**.
**Consequence:** the build now disagrees with all 12 `Add Product` boards on the axis §7 classified
as a pure sync, having shipped a string no source proposed for it.
**This is a copy/design decision, not an implementation one.** It needs: (a) the boards' current
`Key Meta`/`Art S` text confirmed; (b) that layer's box measured against the 80-char value; and
(c) a decision between shipping §7's approved 80-char value and commissioning a fitting variant that
keeps `ed25519`. **Recommended default if the 80-char value fits `Key Meta`/`Art S`: ship §7's value
verbatim — it is the approved string, it keeps the algorithm, and it converges the axes.**
Not correctable by a correction lane without a human/design ruling.

### HIGH

None. The execution carries no high-severity defect.

### MEDIUM

**M1 — A shared primitive with 16 call sites, a new branch, and no test asserting the invariant the
dispatch explicitly warned about.** `TechnicalDetails` (`lib/shared/design_primitives.dart:364`) is
extended with `showRule` + `disclosureAlignment`; **0 of 26** control-plane test files reference it.
The `Expanded`-on-the-trailing-edge invariant — whose removal *"would move the disclosure to the
**left** on every screen in the app"* — is asserted nowhere. The implementer's stated reason for not
adding coverage (new test architecture: a `BlocBuilder` over `ControlPlaneRepository`) **does not
apply to `TechnicalDetails`**, which is a self-contained `StatefulWidget`. **Concrete follow-up:** add
`apps/control_plane/test/shared/technical_details_test.dart` with the four assertions in Item 7
(default paints one rule; `showRule: false` paints none; default + null note puts the link at the
trailing edge; `.start` puts it at the leading edge). ~40 lines, no bloc, no golden, no new
architecture. **I verified the code is correct today** — this finding is about the missing guard, not
a live bug.

### LOW

**L1 — Vertical-rhythm judgment calls, both disclosed, both outside the decision's scope.** (a) The
orphaned `const SizedBox(height: 12)` between the deleted `_buildFooter` and `TechnicalDetails` was
removed, so the gap is now `SizedBox(24)` (desktop) instead of a stacked 36px. (b) With
`showRule: false`, the `const SizedBox(height: 13)` (`:419`) is retained, putting mobile's disclosure
33px below the register panel rather than 20px. `27ea6536` rules on copy, alignment and the divider —
not on vertical rhythm. Confirm (b) against `BPM · Add Product` board coordinates. **I judge both
defensible; neither is a defect.**

**L2 — `noteStyle` is computed unconditionally** (`:401`), including when `note == null` and when the
disclosure is expanded. One `TextStyle` allocation per `build()` that the previous code only paid on
the non-null path. Immaterial; noted for completeness.

**L3 — Report accuracy.** §9 diffstat `+42 −44` vs actual `+42 −42`; §3 proof-1 range `372-389` vs
`374-389`; §0/BLOCKERS 2's `ed25519` claim is wrong (see §5). No effect on the code; all three are
worth correcting so the next lane does not inherit them.

---

## 8. Learning completeness

Per `docs/engineering/LEARNING_POLICY.md`, the implementer persisted **no** knowledge and reported six
discoveries for the Manager to route, correctly identifying that `WORKFLOW_IMPROVEMENT` and
independent-review authority are not its to write. **That is the right call** — `.decisions/**` and
`docs/adr/**` were `PROHIBITED`.

Two discoveries are **already durably placed or already known** and need no new action:
- *`_buildFooter` preceded by `_buildStatusRow`, not `build`* and *"run the formatter after a
  structural deletion"* — the right generalisation, correctly routed to review authority.
- *The phantom `apps/server` format baseline in a fresh worktree* — I reproduced the resolved state
  (root `.dart_tool/package_config.json` present, gate at 631/0) and confirm the diagnosis. **This one
  is worth persisting as `WORKFLOW_IMPROVEMENT`**: it will recur in every future worktree, and the
  failure mode is a lane corrupting a prohibited path.

The `CONTRADICTION` on the eyebrow is **design/human authority** and is escalated here (B1), not
persisted unilaterally. **Correct handling.**

**One gap in the escalation itself:** discovery 2 (`PROJECT_FACT` — *a fit verdict measured on one
board's layer does not transfer to a different board, nor to code*) was the finding that **would have
prevented B1**, and it was reported. It was not acted on because the dispatch's instruction was
followed literally instead of being checked against the source. **Recorded here so the Manager can
treat "verify a cited measurement belongs to the cited slot" as a standing pre-flight check on any
lane that cites a fit measurement.**

---

## 9. Cleanup confirmation

- [x] **ZERO Docker or Compose commands issued** — none, mutating or read-only-looking. Not `info`,
      `ps`, `logs`, `config`, `down`, `up`. **This repository has already lost its QA database
      irrecoverably to a lane running `docker compose -f docker/compose.qa.yaml down -v --rmi local`;
      I did not test that rule and did not come near it.**
- [x] No process, container or compose project started; nothing left running.
- [x] `make test-integration` not run — not needed, and it is the only sanctioned way to obtain a real
      database. **I did not need one.**
- [x] **No production file modified.** I hold no `Write`/`Edit` tool; the only file I created is this
      report at the path the dispatch specified. I did not touch the implementer's report, the
      reviewed worktree, or any tracked file.
- [x] Nothing committed, nothing pushed.
- [x] The reviewed worktree's state is exactly as I found it: 2 modified files, both owned.
- [x] I did not approve the implementer's work; I did not approve my own.

---

## 10. Safe parallelism

```yaml
SAFE_PARALLEL_WORK:
  - the design/human lane that decides B1 (no file overlap; needs board access, not code access)
  - M1's test file — apps/control_plane/test/shared/technical_details_test.dart — IF the Manager
    prefers not to bundle it with the B1 fix; note it reads the primitive and writes only under test/,
    so it does not overlap the owned lib files
  - the L1 vertical-rhythm confirmation against board coordinates (read-only on the boards)
PROHIBITED_PARALLEL_WORK:
  - any lane writing apps/control_plane/lib/features/products/add_product_page.dart until B1 is decided
    — the eyebrow value at :519/:1016 is under active dispute and a second writer would race it
  - any lane writing apps/control_plane/lib/shared/design_primitives.dart — TechnicalDetails is under
    review here; M1's guard should land after B1 so it asserts the final state
  - any Penpot board edit to the Add Product footer or Key Meta — G-18 ownership must be granted first
    and B1 changes what the boards should converge to
```

---

## 11. Recommended next action

`HUMAN_DECISION_REQUIRED`

---

## 12. Required structured result (verbatim block from `.agents/agents/engineering-reviewer.md`)

```
RESULT: DO_NOT_MERGE

REVIEWED_HEAD: 52d0894 + uncommitted working tree at /private/tmp/shipit-implement-custody-footer
  (branch implement/add-product-custody-and-footer; HEAD == BASE_SHA; 2 owned files modified, nothing
  committed or pushed. main = 2dd2b3e, verified bookkeeping-only: 4 files, all under
  docs/engineering/dispatch/tasks/, no production code moved, no rebase needed.)

BLOCKERS:
  B1 — The key-meta eyebrow shipped at add_product_page.dart:519 and :1016 is not the value any
  approved artifact specifies for that slot, and it re-opens the boards/build divergence this work
  item exists to close. Shipped: "Generated on the server · the private half stays in the secret
  manager" (70 chars, ed25519 dropped). Approved source (design-draft-f5-copy/report.md §7 line 299,
  re-verified at design-apply-f5-copy/report-r3.md §9.3 line 486): "ed25519 · generated on the server
  · the private half stays in the secret manager". The 70-char value is registered as string H and
  scoped to Art Sub ×2 on BP · Rotate Key (r3 line 299; draft §4a line 215) — a different board,
  layer and current sentence; the 380px/392.78px overflow warning belongs to that Art Sub box and was
  never measured against Key Meta / Art S, for which the draft records no box measurement at all.
  ROOT CAUSE: the dispatch misread its own cited source — its Part 1 table gave the 80-char string as
  the replacement while its next paragraph forbade "the 80-char string", conflating §7's Add Product
  value with §4a's BP · Rotate Key value. The correct value was directly discoverable at §7 line 299.
  NOT CORRECTABLE BY A CORRECTION LANE. Needs a human/design ruling on: (a) the boards' current
  Key Meta/Art S text, (b) that layer's box measured against the 80-char value, and (c) ship §7's
  approved 80-char value (recommended if it fits — it keeps ed25519 and converges the axes) vs
  commission a fitting variant that keeps ed25519. NOTE for the human: the implementer's BLOCKERS 2 is
  factually wrong — ed25519 IS still rendered on the page via publicKey 'ssh-ed25519 …'
  (add_product_page.dart:135, displayed at :526 and :1021); the loss is prose-only, which de-escalates
  that sub-finding but not B1 itself.

HIGH: none.

MEDIUM:
  M1 — Shared primitive TechnicalDetails (lib/shared/design_primitives.dart:364) extended with
  showRule + disclosureAlignment, 16 construction call sites across 13 files, and ZERO test coverage:
  0 of 26 control-plane test files reference TechnicalDetails, design_primitives.dart, showRule or
  disclosureAlignment. The invariant the dispatch specifically warned about — dropping Expanded would
  move the disclosure LEFT on every screen — is asserted nowhere. The implementer's stated reason for
  no coverage (a BlocBuilder over ControlPlaneRepository) does not apply here: TechnicalDetails is a
  self-contained StatefulWidget with no repository dependency, so the harness is ~10 lines. FOLLOW-UP:
  add apps/control_plane/test/shared/technical_details_test.dart asserting (1) default paints one
  ContentRule, (2) showRule:false paints none, (3) default + null note puts "Show technical details"
  at the trailing edge, (4) DisclosureAlignment.start puts it at the leading edge. ~40 lines, no bloc,
  no golden, no new test architecture. I verified the code is CORRECT today — this is the missing
  regression guard, not a live bug.

LOW:
  L1 — Two disclosed vertical-rhythm judgment calls outside 27ea6536's scope: the orphaned
  SizedBox(height:12) was removed (desktop gap is now SizedBox(24), not a stacked 36px), and the
  SizedBox(height:13) at design_primitives.dart:419 is retained under showRule:false, putting mobile's
  disclosure 33px below the register panel rather than 20px. Confirm the latter against
  BPM · Add Product board coordinates. Both defensible; neither is a defect.
  L2 — noteStyle (design_primitives.dart:401) is computed unconditionally, including when note == null;
  one TextStyle allocation per build() the previous code only paid on the non-null path. Immaterial.
  L3 — Report accuracy: §9 diffstat says +42 −44, actual is +42 −42; §3 proof 1 gives the deleted
  range as 372-389, actual hunk range is 374-389; §0/BLOCKERS 2's ed25519 claim is wrong (see
  BLOCKERS). No effect on code; correct them so the next lane does not inherit them.

CORRECTION_REQUIRED: NO

HUMAN_DECISION_REQUIRED: YES
HUMAN_DECISION_TYPE: DESIGN   # product copy on the key-custody axis + boards/build convergence

SAFE_PARALLEL_WORK:
  - the design/human lane deciding B1 (board access, no code access; no file overlap)
  - M1's test file IF the Manager prefers it unbundled from the B1 fix (writes only under test/,
    reads the primitive, no overlap with the owned lib files)
  - L1's vertical-rhythm confirmation against board coordinates (read-only)
PROHIBITED_PARALLEL_WORK:
  - any lane writing apps/control_plane/lib/features/products/add_product_page.dart until B1 is
    decided — :519/:1016 are under active dispute
  - any lane writing apps/control_plane/lib/shared/design_primitives.dart — M1's guard should land
    after B1 so it asserts the final state
  - any Penpot board edit to the Add Product footer or Key Meta — G-18 ownership first, and B1 changes
    what the boards should converge to
```

**Reviewer note for the Manager, in one line:** the execution is sound and the trap was avoided —
the single blocker is a copy value the dispatch mis-specified, and the implementer escalated it
correctly three times rather than burying it.
