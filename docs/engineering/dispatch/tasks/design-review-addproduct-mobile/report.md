# Report — Independent Design Review, Add Product mobile boards (Gate D3)

Persisted per `aef-orchestrator` §14. Reviewer: `design-reviewer`, read-only.

> **Persistence note.** This report was returned by the reviewer and parsed by the Manager, but was
> **not written to disk** before the correction lane was dispatched — so
> `docs/engineering/dispatch/LANES.md:224` asserted a persisted report that did not exist
> (`git rev-list --all` → 0 objects for this path). The correction lane flagged it as G11 and
> correctly refused to proceed on an unreadable input: it re-verified all 16 findings independently
> instead. This file is the authoritative copy; the correction lane's G11 is now closed. Recorded
> per `aef-orchestrator` §14 rule 6 — never rely on in-memory-only state.

REVIEWED_HEAD `77c19f1` (worktree `/private/tmp/shipit-design-addproduct-mobile`, branch
`design/addproduct-mobile`; artifacts persisted into the canonical tree at `064703d`).
REVISION_ID `65995C2B-4905-419F-A6E9-E547E86D8ECE` · BRIEF_ID `52CB4098-FF87-4B78-81DA-1104269551A1`.

```
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
REVIEWED_HEAD: 77c19f1
CORRECTION_REQUIRED: YES
HUMAN_DECISION_REQUIRED: NO
HUMAN_DECISION_TYPE: DESIGN
INDEPENDENT_RISK_LEVEL: 2
RISK_LEVEL_AGREEMENT: YES
```

## PROVENANCE

Worktree `/private/tmp/shipit-design-addproduct-mobile` HEAD `77c19f1` matches the claimed SHA; branch
`design/addproduct-mobile`; `git status --porcelain` shows only
`?? docs/engineering/dispatch/tasks/design-addproduct-mobile/` — no tracked file modified, no
prohibited path touched. Canonical tree is `064703d`.

## CLAIM 1 — four boards, 390x844, both themes, no collision: **CONFIRMED**

All four exist at exactly 390x844 with the dispatched names, at the claimed positions, 42/42/34/34
children, correct dark retint (`#4496FC` accent, `#E93E3A`/`#6FFFCE` states, `#1A1C1B` top bar). All
four PNGs were exported and read: all legible. Exactly one *declared*-box overlap per board
(`Art T`/`Art S`, 1px), but rendered `textBounds` show 1px clearance and that overlap is reproduced
verbatim from BPM. `Art S` renders 178px inside a 220px box on ONE line (the shortened string does
fit); trust body lines render 2+2 lines inside the grown 160px panel with 5–7px clearance. **No text
overflows its box.** Both previously-found defects are genuinely fixed.

Geometry fidelity is stronger than claimed: **every layer position and size on the Verified pair is
byte-identical to `BPM · Add Product · Light`.**

## CLAIM 2 — key custody copy corrected: **CONFIRMED**

`ed25519 · private half stays server-side` on all four, in `inkSecondary` (`#5A5C5B` / `#A8A6A0`).
Automated audit: **ZERO** occurrences of "this device", "keychain", "browser storage", "Cancel",
"What you're registering", "What happens next". Satisfies `b869ec24` follow-up action 3. The reference
board genuinely does carry the false "private half stays in the keychain".

## CLAIM 3 — three contradicting premises: **CONFIRMED, all three**

**(a)** `TechnicalDetails` instantiated at `add_product_page.dart:316` (desktop) and `:925` (mobile);
label hard-coded at `design_primitives.dart:415`. **Not a restoration**; the ledger's "appears nowhere"
was a grep false negative. The producer is right.

**(b)** `_buildFooter` (`:375`) is called only at `:314`, inside `_DesktopAddProduct` (`:276-391`);
`_MobileAddProduct` (`:774-1117`) has no footer copy. **Desktop-only.** The producer is right.

**(c)** `BPM · Add Product · Light` has exactly one element below the helper — `Disclose` at (16,580) —
and **NO** copy line; visually confirmed. The desktop board carries `Footer` at (236,862) and `Disclose`
at (1036,862): same y, opposite ends, matching `TechnicalDetails`' collapsed shape. The producer is
right on both halves. The footer's platform split is therefore **justified, not arbitrary**.

## CLAIM 4 — accessibility token: **CONFIRMED, and the numbers are real**

All ten ledger rows were recomputed from `design_tokens.dart:99-101`/`:120-122` with the WCAG 2.1
relative-luminance formula. **All ten reproduce EXACTLY:**

| Pair | Light | Dark |
|---|---|---|
| inkSecondary / card | 6.74 | 6.10 |
| inkTertiary / card | 4.99 | **4.23 FAIL** |
| inkPrimary / card | 16.20 | 13.48 |
| inkPrimary / accent | 3.07 | **2.72 FAIL** |
| #ffffff / accent | 5.27 | 2.99 |
| #06121f / accent | 3.58 | 6.30 |
| positive / canvas | 4.97 | 13.01 |
| negative / canvas | 5.33 | **4.02** |
| negative / card | 5.72 | **3.68** |
| attention / card | 5.01 | 7.28 |

The dispatch's figures are right and the prior round's "≈6.0:1, above threshold" was numerically
false. Token path is `core/design_tokens.dart`; `shared/design_tokens.dart` does not exist; ink tokens
are at `:99-101`/`:120-122` exactly as stated. Also verified the surface the helper actually sits on:
mobile's button + helper are inside a `DesignPanel` (`:853`), so `card` is the correct surface for the
6.74/6.10 figures.

## CLAIM 5 — button/helper geometry: arithmetic verified **except the clamp**

`:685` padding `symmetric(vertical: 11)` → 22; `:689` `minimumSize: Size(0, 36)`; `:692-717` the
nested `Column[label, SizedBox(2), subtext]`; label 12px → 14.4, subtext 10px → 12, content 28.4,
total **50.4** — all correct. `ShipItType._lh = 1.2` at `:313` confirmed. Mobile gap `SizedBox(height: 8)`
at `:912` confirmed; `MobilePrimaryButton` fixed 36 at `mobile_chrome.dart:440` with
`buttonLabelMobile` 11/w600 → 13.2 confirmed; the board helper gap is **8px** (Submit 678→712, helper
720) confirmed. Only the post-change clamp is wrong — see **M-R1**.

Also verified `:703-705`/`:713` set `palette.inkPrimary` at 3.07/2.72 (fail both) and that the boards
already carry the correct `#FFFFFF`/`#06121F` — so **the code, not the board, is wrong**, matching
`theme.dart:70-74`.

## CLAIM 6 — `(OPTIONAL)` convention: **CONFIRMED, the count is exactly right and the compile risk is genuinely gone**

`create_defect_page.dart:458,477,495,504` carry the in-label suffix; the path is `features/defect_report/`
and `features/defects/` does not exist. `grep -rn "FormFieldSlot("` returns **16 lines = 15 invocations
+ 1 constructor** at `form_primitives.dart:69`; composition 2 add_product + 9 create_defect + 3
create_feature_request + 1 `DesignTextField` forwarding — the producer's 15 is exact, and
`create_defect`'s 9 (not the prior round's 10) is exact. `DesignTextField` is at
`form_primitives.dart:287` with **NO** `requirement` parameter, forwarding `label:` at `:305`;
`model_executions_page.dart:851,857,863` pass only `initialValue`/`label`/`onChanged` and are filter
inputs with no submit gate. Adding no parameter leaves the signature untouched, so **the prior round's
compile break at those three sites genuinely cannot occur.**

## CLAIM 7 — board count integrity: **CONFIRMED**

160 boards / 162 root children (from 156/158), delta exactly +4. The only boards under 300x300 are six
pre-existing `Tab`/`Tab Group` boards at (0,0) with an older id prefix; **no scratch board from a failed
API call remains**. All four reference boards unchanged in position, name and child count (BPM
Light/Dark 36 each at 5280; S Unknown Light 69 at 10400; S Verified Light 65 at 11700).

## IA / BOARD FIDELITY

Back link, H1, `NOT REGISTERED YET` eyebrow, Rule 1, 3 fields at 64px pitch, 116px deploy-key panel,
`Register product`, helper BELOW, `Show technical details ▸`, bottom nav — all present on all four
boards. **NO** "What you're registering" and **NO** "What happens next" on any board, while the build
renders both (`:405` desktop only; `:639` desktop + `:859` mobile) — the producer's MATERIAL mismatch
call is correct.

## SELF-ASSESSMENT HONESTY

`DESIGN_SYSTEM_COMPLIANCE: PARTIAL`, `UX_ACCESSIBILITY_SCORE: PARTIAL`, `IMPLEMENTATION_FEASIBILITY:
MEDIUM`, `flutter analyze: NOT_RUN`. Independently confirmed
`apps/control_plane/.dart_tool/package_config.json` is absent, so the stated reason for NOT_RUN is
accurate and MEDIUM-not-HIGH is the honest ceiling. The contrast work is genuine — every figure tested
reproduced. **The one dishonest artifact is F8** (see B-R1).

## LEARNING COMPLETENESS: SATISFIED

All eleven discoveries carry exactly one `LEARNING_POLICY` category, product-specific vs reusable scope,
and an authority level; `KNOWLEDGE_PERSISTED` correctly confines writes to `OWNED_PATHS` and defers the
two framework-level categories.

---

## BLOCKERS

### B-R1 — Board-wide typography weight divergence, defended by a false claim

All four boards render **EVERY** emphasis layer at `400`; the production tokens and the reference board
render 500/600. Follow-up F8 attributes this to "Penpot's IBM Plex Sans has no `500` weight (supported:
200/300/400/600/700/900)". **That is false**, verified three ways:

- **(a)** `penpot.fonts.findByName('IBM Plex Sans').variants` = 100/200/300/400/500/600/700, each
  normal+italic. **`500normal` EXISTS. `900` does NOT exist.** F8's list is wrong **in both
  directions**.
- **(b)** The reference board `BPM · Add Product · Light`, in the SAME file with the SAME family,
  renders `500` (`Back`, `Art L1`, `Art L2`, `Disclose`) and `600` (`H1`, `Status`, `F K 0/1/2`,
  `Art K`, `Art T`, `Submit L`).
- **(c)** The production tokens require it: `pageTitleMobile` 20/w600 (`design_tokens.dart:561`),
  `microLabel` 9/w600 ls 1.1 (`:368`), `sectionTitle` 13/w600 (`:352`), `link` 11/w500 (`:426`),
  `linkMicro` 10/w500 (`:443`).

Visible in the exports: the four boards are markedly flatter than every other board in the file.
Violates acceptance criterion 5 ("every board element maps to a named existing token") and contradicts
the revision's own traceability row "`Art T` … `bodySmall` w600".

**CORRECTION** — set on all four boards: `Back` 12/400→12/**500**; `H1` 20/400→20/**600**;
`Status`,`F K 0/1/2`,`Art K` 9/400 ls=0 → 9/**600** ls=**1.1**; `Art T` 13/400→13/**600**;
`Art L1 · Copy key`,`Art L2 · Check access` 11/400→11/**500**; `Disclose` 10/400→10/**500**;
`Trust Btn L` 12/400→12/**600** (desktop `Host Btn L` is 12/…; match the reference).

`Submit L` needs a **DECISION, not a copy**: the reference BPM board and both desktop boards draw
13/600, but `MobilePrimaryButton` renders `ShipItType.buttonLabelMobile` = 11/w600
(`mobile_chrome.dart:443`) — so either the board adopts 11/600 to match the primitive its own matrix
names, or the design records 13px as an intentional divergence.

Also fix the matrix token name `bodySmall` → **`sectionTitle`** for `Art T` (`bodySmall` is 11px/w400),
and **DELETE follow-up F8 rather than correcting it** — its premise is disproved.

> **Manager note (added at correction time):** the `Submit L` justification above was itself wrong —
> the **desktop** boards draw `R Submit L` at **12**/600, not 13. Only `BPM · Add Product · Light`
> draws 13, and 13 matches no primitive on either platform. The correction lane caught this and decided
> 11/600 on the stronger ground that **13 corresponds to nothing**, not that two boards agree on it.

### H-R1 — `Trust Host` ships an AA-failing text layer in dark

`Trust Host` = "git.internal.acme.com · ed25519 · SHA256:+DiY…", 10px IBM Plex Mono, fill `#8A8983` =
`inkTertiary`, sitting on the trust panel's `card` surface `#262827` (`DesignPanel` is `palette.card`,
`design_primitives.dart:320`). Measured **4.23:1** → fails WCAG AA 4.5:1 for normal text. **This is the
identical pairing the revision's own ledger row 2 records as "4.23:1 dark — FAIL"**, and the same token
it rejects for the helper in §2c.

It is the **host fingerprint the user must read to decide whether to trust a host** — the
highest-consequence string on the board, and visibly the dimmest text on the dark export. Violates SC-4
("every body/secondary text layer ≥ 4.5:1 … in both themes").

**CORRECTION:** set `Trust Host` to `inkSecondary` on all four boards (6.74 / 6.10), add the row to the
ledger **with the surface named**, and add the missing token to the traceability row
`Trust K/Body/Body 2/Host` (it currently names only surfaces `card`, `attention`).

**This is DISTINCT from B4** (`negative` on dark, 3.68:1) — do not merge them; B4 is already a recorded
design-system item.

### H-R2 — The false key-custody claim also lives on the Product Detail page and is not enumerated

`b869ec24` settled server-side generation and storage; its follow-up action 3 asks that the copy
"describe what actually happens on the server". Follow-up F2 enumerates only Add Product's
`_buildInfoPanel` (`:480-482`, `:979-981`). A repo-wide grep at `77c19f1` also returns
**`apps/control_plane/lib/features/product_detail/product_detail_page.dart:614`** — "One key per
repository. The private half never leaves this device." Same false claim, on a **live user-facing
screen**, outside this lane's owned file and therefore outside F2's scope.

(Lower-stakes, different claim: `sidebar.dart:389` "Signed in on this device";
`decision_detail_page.dart:337,436`; `defect_detail_page.dart:1087` "Saved as you, on this device".)

**CORRECTION:** extend the copy-correction scope to name `product_detail_page.dart:614` and route it as
production source (PROHIBITED to this lane); **G6 is currently under-scoped.**

> **Manager note (added at correction time):** this is the screen reached **after** registering, so the
> false claim is what a user reads once they believe the setup succeeded.

### H-R3 — The evidence's `Register product` count is not reproducible

`penpot-board-evidence.md` §4 reports count = 1 for all four boards. Substring counting over the four
boards' text layers returns **2** on both Unknown-host boards: the button label plus the substring
inside the helper "Confirm the host above to enable Register product."

SC-3 is satisfied in intent (exactly one *label*), but **the published figure is wrong under the audit's
own stated method** and a re-runner will get 2.
**CORRECTION:** publish the counting rule next to the number (exact match on the layer whose text IS the
label), or publish the substring count.

### H-R4 — Human point 2b's gating has no visual expression on any board

The `Register product` rect is `#1668D6`/`#4496FC` at opacity 1 on all four boards —
**byte-identical between the Unknown-host state (`canRegister == false`, `:233-236`) and the Verified
state.** Every CTA rectangle on all 34 mobile boards was swept: only those two fills at opacity 1 exist,
so there is genuinely no disabled-primary precedent in the file (the producer's AMBIGUOUS note is
accurate).

But the producer frames it as a missing token and **never states the design consequence**: a human
requirement (2b) has **zero** board expression, and an implementer reading these boards would ship a
control that **looks enabled and does nothing**.

**CORRECTION:** state in §6/§7 whether helper-only signalling is the accepted answer for 2b; if it is
not, raise the disabled-primary token as a design-system-owner item beside B4.

---

## MEDIUM

**M-R1 — Desktop button height: `minimumSize` cannot clamp downward.** §2a says the button goes "36.4 →
clamped by `minimumSize` to 36px"; the metadata and report repeat "≈50.4px → 36px, landing on its own
declared `minimumSize`". `FilledButton.styleFrom(minimumSize: Size(0, 36))` sets a **MINIMUM** —
`Size.constrain` only raises values below it. Content+padding is 14.4 + 22 = 36.4, already above 36, so
the height is **36.4** and `minimumSize` is **not binding** — exactly as §2a correctly says for the
"before" state ("minimumSize … is not binding"), then contradicts for the "after". Delta **14.0px**, not
14.4px.

No layout conclusion changes, but this is the precise number prior finding H2 demanded and **the category
error must not reach a frozen contract.**
**CORRECTION:** write 50.4 → **36.4**; delete "clamped by `minimumSize`" and "landing on its own declared
`minimumSize`" from §2a, the metadata `risk_rationale`, and report.md.

Also in §2b: "gains ~15px of helper plus the 8px gap" — the helper is `monoMeta` at `fontSize: 10`
(`:917`) = 12px content, so the gain is 8 + 12 = **20px** against a 14px loss; **the panel's inner height
GROWS ~6px** and is not "unchanged".

**M-R2 — The provisional `Trust *` layers are marked in prose only.** `Art S · PENDING D4 (at-rest model)`
correctly carries its deferral in the layer name. But `Trust Bg`, `Trust Edge`, `Trust K`, `Trust Body`,
`Trust Body 2`, `Trust Host`, `Trust Btn`, `Trust Btn L` — **8 layers on 2 of 4 boards** — carry no
provisional marker, although §8 and blocker B5 declare them provisional pending the sibling lane's
`hostUnrecognised` state machine. **A designer opening the file cannot tell.**
**CORRECTION:** rename them to carry the marker (e.g. `Trust K · PROVISIONAL (G1 hostUnrecognised)`) or
add one annotation layer.

**M-R3 — The Unknown-host helper string is producible by no code path and is absent from the mismatch
list.** `_registerButtonSubtext` (`:726-735`) returns only: 'Registering…', 'Product name is required',
'Repository URL is required', 'Generate a deploy key first', 'Access must be verified before a product
can be registered', 'Access verified — this product can be registered'. The **Verified** board's helper
matches `:734` byte-for-byte (implementable with no code change). The **Unknown-host** board's "Confirm
the host above to enable Register product." matches **none of them** — a new string needing a new state
branch, absent from the categorized mismatch list and from G1–G8.
**CORRECTION:** add it to the mismatch list and name the state that must produce it, or state that it
arrives with the sibling lane's `hostUnrecognised`.

**M-R4 — `create_defect_bloc.dart` gate citations are off by four on two of five fields.** §4 cites
`:201, :207, :216, :229, :238`; the `if` guards are at `:201`, `:207`, `:216`, `:225`, `:234` (`:229`/
`:238` are the `errorMessage:` string lines). **Substance is correct** — the five gated fields are exactly
`title`, `description`, `expectedBehavior`, `severity`, `productId`, matching `TITLE`,
`WHAT HAPPENED?`, `WHAT DID YOU EXPECT?`, `SEVERITY`, `PRODUCT`.
**CORRECTION:** fix the two line numbers so a correction lane does not "fix" the wrong lines.

---

## LOW

- **L-R1** — The bottom nav drops the `Nav Badge` ("2" on "Needs you") that `BPM · Add Product · Light`
  carries; undocumented and in tension with "geometry mirrors BPM exactly". The nav boards are otherwise
  clean: verified against six other dark mobile boards and they match the file convention exactly (nav bg
  `#1A1C1B`/`#EFEFEC`, pill `#2D2F2E`/`#DEDEDA`, inactive label `#8A8983`/`#6A6C6A`, rule
  `#383A39`/`#DEDEDA`, 23 children). Add the badge or record the omission.
- **L-R2** — The traceability matrix maps the bottom nav to `inkQuiet`/`inkPrimary`. True for the light
  boards (`#6A6C6A`) but **false for the dark boards, which use `#8A8983` = `inkTertiary`** (not
  `inkQuiet` `#85847E`). Both pass AA on `rail` — measured 4.60:1 light, 4.88:1 dark. Fix the matrix.
- **L-R3** — The same product (`TeamHub`) shows `git@git.internal.acme.com:platform/teamhub.git` on the
  Unknown-host pair and `git@github.com:acme/teamhub.git` on the Verified pair. Harmonise for a coherent
  state pair.
- **L-R4** — §1's decomposition "3 fields at a 64px pitch (14px label slot + 4px gap + 34px box)" sums to
  **52**, not 64. The pitch itself is verified exact (boxes at y=194/258/322 → 64px) and matches BPM and
  `FormMetrics.fieldGap = 18` (`form_primitives.dart:36`); only the parenthetical is incomplete. State the
  12px remainder or drop the decomposition.
- **L-R5** — `Trust Btn L` is flush to its button's left edge (0px inset; button x=30 w=180, label x=30)
  whereas `Submit L` is centred. This reproduces the desktop board's identical `Host Btn`/`Host Btn L`
  pattern at x=254, so it is **a faithful copy of a pre-existing pattern, not a new defect** — worth a
  design-system-owner note.
- **L-R6** — `"What you're registering"` exists **only** at `:405` (desktop left column); mobile renders
  only `"What happens next"` (`:859`). §1 and report.md cite "both" without the platform split, which is
  inconsistent with the revision's own care about desktop-only vs mobile elsewhere.
- **L-R7** — The ledger has no row for the **EXPANDED** technical-details lines, which render `monoMeta` +
  `inkTertiary` (`design_primitives.dart:390-392`) = 4.23:1 on `card` in dark. Add the row or note the
  exemption.

> **Manager note (added at correction time):** on **mobile** those expanded lines sit on `canvas`, not
> `card`, so `inkTertiary` **passes** there (4.65 / 4.62). L-R7's 4.23:1 was the **desktop surface only**.
> The correction lane recorded the row **per platform** rather than copying a ratio that does not govern
> these boards — which is the right call, and the reason H-R1 had to name its surface explicitly.

---

## RISK ASSESSMENT (independent): **2**, agreeing with the producer

Level 2 is right — the feature's one committing control changes structure on both platforms (nested
reason removed, button geometry changed, new helper line and new 8px desktop gap), a specified token is
replaced, and the required-field convention reaches four files plus a shared primitive.

**Not Level 3:** no navigation, IA or cross-feature workflow change; and the trust-Cancel removal was
checked specifically rather than accepted on argument — `Trust *` is an inline panel inside the existing
page flow with `‹ Products` as a persistent way out, so removing Cancel is a **control-level** change,
not a navigation change.

The correction required by B-R1/H-R1 is **Level 0/1** (mechanical re-weighting and a token swap on
already-drawn boards): it does not raise the level and needs no human gate.

## HUMAN DECISION: none new

- **B3** is already filed as `27ea6536` (DESIGN, PENDING) — do not re-escalate.
- **G2** is covered by `9417f8bf` / `79e860e2` / `7b1bc8b7` (SECURITY, PENDING).
- Registration ordering is covered by `898b07d0` (ARCHITECTURE, PENDING).
- **B2** (board naming `SM -` vs the page's `S ·`) and **B4** (`negative` on dark) are **Level-1
  design-system-owner notifications** already correctly recorded as such.

## SAFE_PARALLEL_WORK

**SAFE:**
- `design-addproduct-keyservice` — disjoint `OWNED_PATHS`; proceed. The coupling is honestly declared
  (four labelled assumptions A1–A4, three named divergence scenarios, blast radius bounded to the
  Unknown-host pair between key panel and submit button). Its one weakness is marking (M-R2), plus
  M-R3's copy divergence is not counted in the radius.
- The implementation lane's **NON-UI** preparation — mock-key removal (`:126-138`), the missing
  `AccessStatus.verified` producer, test coverage (F7) — none depends on my findings.
- **DRAFTING** the copy decisions now (`:383`, `:918`, `:480-482`, `:979-981`, `:542`, `:1038`, and
  `product_detail_page.dart:614`) is independent of the board-weight fix.

**PROHIBITED:**
- Any implementation of the four boards' typography (B-R1) or the `Trust Host` token (H-R1).
- **Visual-QA golden-baseline capture** — it would bake in 400-weight eyebrows and a 4.23:1 fingerprint
  line. F6 (34 vs 36px submit) must also be settled first.
- Any lane editing `BPM · Add Product · Light/Dark` or the desktop BP/S Add Product boards (F5 needs a
  design-system owner).

## NOT RUN (explicit)

- `flutter analyze` — **NOT_RUN**. Requires `flutter pub get`, which writes outside this lane's
  read-only scope. The missing `package_config.json` was independently confirmed as the real reason; no
  claim is made about the analyzer's output.
- Any Docker or Compose command — **NOT_RUN**, none issued, per the hard rule.
- Automated pixel-diff — **NOT_RUN**, none available in this repository.
- **No Penpot board was edited, renamed, moved or deleted**, including `BPM · Add Product · Light/Dark`
  and the desktop `S · Add Product · …` boards; Penpot access was read/inspect/export only.
- Nothing was persisted; this report is returned to the Manager to persist.
