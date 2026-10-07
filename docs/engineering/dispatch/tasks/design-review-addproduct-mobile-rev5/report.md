# Report — Independent Design Review, mobile Design Revision 5 (Gate D3, first review)

Persisted per `aef-orchestrator` §14. Reviewer: `design-reviewer`, **read-only** in git and in Penpot.

```yaml
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
TASK_ID: design-review-addproduct-mobile-rev5
TASK_TYPE: design-review
FEATURE: Add Product rebuild — mobile Design Revision 5 (first independent review)
WORKTREE: /Users/alkebut/air/shipit-platform   (canonical checkout; read-only)
BRANCH: main
BASE_SHA: 289f1d3   # producing worktree /private/tmp/shipit-correct-addproduct-mobile, @289f1d3, UNCOMMITTED
HEAD_SHA: 08c7590   # head actually reviewed
COMMITTED: YES       # this report only; nothing else was written
```

```
REVIEWED_HEAD: 08c7590
REVISION_ID: CB4BEECA-CA9D-4F26-9464-E1B6F7C9BDCB
BRIEF_ID: 52CB4098-FF87-4B78-81DA-1104269551A1

BLOCKERS: NONE
HIGH: NONE
MEDIUM: MR5-1, MR5-2, MR5-3
LOW: MR5-4, MR5-5, MR5-6, MR5-7

INDEPENDENT_RISK_LEVEL: 3
RISK_LEVEL_AGREEMENT: YES

TRACEABILITY_GAPS: G13, G14/SC-9 (the lane's own, correctly reported) + the G-7 site-table omission in MR5-3

CORRECTION_REQUIRED: YES
HUMAN_DECISION_REQUIRED: NO
HUMAN_DECISION_TYPE: (none)
```

---

## 1. Headline

**Revision 5 is a good revision and its load-bearing board claims are all true.** I was the first
reviewer in this work item with Penpot reachable, so I could do what two predecessors could not: verify
every board claim against the live file. **Every one of them reproduces exactly** — the custody string,
the layer renames, the geometry moves, `Trust Created`, the `Disclose` alignment, the absence of a
mobile footer copy, the D-8 coordinate table row for row, and F6 on all four desktop boards. I found
**no false claim about a board anywhere in the artifact set.**

What I did find is narrower and real: **one number that is wrong in two of its three published forms,
with a provable correct value** (MR5-1); **the design brief's own acceptance table records the lane's
only blocker as met** (MR5-2); and **a routed REQUIRED security change whose site table is missing a
file that breaks the build** (MR5-3). None of these changes the design. All three are record corrections.

**Risk level 3 agreed.** **No human gate.** The revision is otherwise ready.

---

## 2. Provenance — verified, including the Manager's copy claim

| Check | Result |
|---|---|
| `git rev-parse --short HEAD` | **`08c7590`** — matches the dispatch's `VALIDATION_COMMANDS` |
| Branch | `main`; 20 worktrees listed |
| Dispatch prompt claim | head `08c7590` ✓ · producing branch `design-correct-addproduct-mobile` @ `289f1d3` ✓ (both worktrees confirmed present) |
| **Manager's byte-identity claim (canonical copies vs producing worktree)** | **VERIFIED — all 12 artifacts `diff -q` IDENTICAL**: `design-revision-5.md`, `design-revision-metadata-5.yaml`, `traceability-matrix-5.md`, `correction-report-5c.md`, `penpot-board-evidence.md`, `design-brief.md`, `design-revision-2/3/4.md`, `design-revision.md`, `report.md`, `design-revision-metadata-4.yaml` |
| Artifacts reviewed | the **canonical copies** at `docs/engineering/dispatch/tasks/design-addproduct-mobile/` |
| `revision_id` | `CB4BEECA-CA9D-4F26-9464-E1B6F7C9BDCB` in the revision header **and** the metadata front matter — consistent |
| `supersedes` | `A69AB98C-A672-4D98-9DCE-0F089D55A9B5` (rev 4) ✓ matches the rev-4 report |

**Revision 5 is entirely UNTRACKED** — `?? design-revision-5.md`, `?? design-revision-metadata-5.yaml`,
`?? traceability-matrix-5.md`, `?? correction-report-5c.md` (plus the two orphaned prior-attempt reports).
The revision's own metadata discloses this (`committed: NO`), so it is not misstated — but the artifact
under review exists only as working-tree files, and three reports have already been lost in this work
item. **Persist before anything else acts on this review.**

**Ownership boundary — respected and verified.** `git diff --name-only` outside the owned set touches
**nothing** but `design-addproduct-mobile/` (8 modified files). Nothing in `apps/**`, `packages/**`,
`docker/**`, `.github/**`, `.decisions/**`, `docs/adr/**`, the keys lane's directory, `WORK_STATE.md` or
`LANES.md` was written. The revision's claim of no production-source edits holds.

**One disclosure gap at the reviewed head (MR5-5).** Feasibility rests on
`git diff --name-only 43d328b 289f1d3 -- apps/control_plane packages` = empty. I reproduced that at the
producing base (**0 files**). But at the **reviewed head `08c7590`** that diff is **4 files**
(`packages/product_registry/{engine,store,in_memory_store}.dart`, `credential_test.dart`) — `main` advanced
after the revision was written. **I re-verified every line the revision cites, individually, at
`08c7590`, and every one holds** (see §5). So no citation is wrong; the *stated basis* is stale at the
head being reviewed, and the artifact does not say so.

---

## 3. Penpot — verified LIVE. What I confirmed myself vs took on trust

**`penpot_high_level_overview` read first, as required. `penpotUtils.getPages()` → `["Page 1"]`,
id `d8ac01df-6646-81d2-8008-a366c09aa9d3`.** The tab was suspended on first contact and needed waking;
it then served every call.

### VERIFIED LIVE BY ME (read-only; I edited, renamed and deleted nothing)

| Claim | Producer's value | My independent live read |
|---|---|---|
| Page inventory | 160 boards / 164 root children, before **and** after | **160 / 164** ✓ |
| 4 × `SM` identity | exact names + ids, 390×844 | **4 exact names, 4 exact ids, 390×844** ✓ |
| `SM` top-level layers | 44/44/36/36 | **44/44/36/36** ✓ |
| `SM` text layers | 29/29/24/24 | **29/29/24/24** ✓ |
| Custody string, all 4 boards | the `N-9` string, **80 chars** | `ed25519 · generated on the server · the private half stays in the secret manager` — **80 chars on all four** ✓ |
| `Art S` layer name | `Art S` (PENDING suffix retired) | **`Art S`** on all four ✓ |
| `Art S` box | `138,418 220×24`, two lines | **`138,418 220×24`** on all four ✓ |
| `Art S` fill | `#5a5c5b` / `#a8a6a0` = `inkSecondary` | **`#5a5c5b` / `#a8a6a0`** ✓ |
| `Art S` font block | IBM Plex Sans / 10 / 400 / 0 / 1.2 / left / fixed | **all six identical on all four** ✓ |
| `Key State` parentY | 436 → **446** | **446** on all four ✓ |
| `Art L1`/`Art L2` parentY | 456 → **466** | **466 / 466** on all four ✓ (card bottom 486, label bottom 482 → **4px slack** ✓) |
| `Art Bg` not grown | `16,370 358×116` unchanged | **16,370 358×116** on all four ✓ |
| Zero `PENDING D4`/`PROVISIONAL` layer names | **0** on all four | **0** on all four ✓ |
| Zero forbidden text (ten strings) | **0** on all four | **0** on all four, incl. no `Your decision is recorded permanently…` on any `SM` board ✓ |
| `Status` Unknown pair | `REGISTERED · NOT YET USABLE` @ `26,137 240×14` | **exact, both themes** ✓ |
| `Status` Verified pair | `REGISTERED · READY TO REGISTER` | **exact, both themes** ✓ |
| `Trust K` | `CONFIRM THIS HOST TO FINISH REGISTERING` | **exact, both Unknown boards** ✓ |
| `Trust Body 2` | **REMOVED** | **absent on all four** ✓ |
| `Trust Created` | NEW `30,566 330×24`, 10/400, `inkSecondary` | **`30,566 330×24`, fontSize 10, weight 400, `#5a5c5b`/`#a8a6a0`, contained in `Trust Bg` = true** ✓ |
| Trust chain unchanged | 678 / 720 / 748 | **678 / 720 / 748** ✓ |
| `Disclose` mobile | `parentX` 16, left-aligned | **`x=16`, `align: left`, 220w** on all four ✓ |
| Zero dividers between helper and `Disclose` | **0** | **0** on all four ✓ |
| Zero nav collisions | 0 | **0** on all four ✓ |
| `Register product` exact / substring | 1/2, 1/2, 1/1, 1/1 | **1/2, 1/2, 1/1, 1/1** — exact ✓ |
| `Trust Btn L` | `#ffffff` on `#1668d6` / `#06121f` on `#4496fc`, `align: center` | **exact, `align: center`** ✓ |
| `Nav Label 3` active weight | w600 | **fontWeight `600`** ✓ |
| Helpers | Unknown `Confirm the host above to enable Register product.` · Verified `Access verified — this product can be registered` | **both verbatim** ✓ |
| Read-only board integrity | `BPM` 36×2, `S` 69/69/65/65 | **36 / 36 / 69 / 69 / 65 / 65** ✓ |
| `BPM` false custody string (F5) | `ed25519 · private half stays in the keychain` | **verbatim on both** ✓ |
| `BPM` false eyebrow (F5) | `NOT REGISTERED YET` | **verbatim on both** ✓ |

### F6 — I measured the desktop boards myself. **CONFIRMED.**

All four `S · Add Product · …` boards (1280×900), footer band, identical on all four:

| Layer | type | rel x, y | w × h | my read |
|---|---|---|---|---|
| `Footer Rule` | rectangle | **236, 848** | 1020 × 1 | the divider — `#dededa` light / `#383a39` dark |
| **`Footer`** | **text** | **236, 862** | **1020 × 15** | `#6e706e` / `#8a8983` — *"Your decision is recorded permanently. The same piece of work then continues — nothing is restarted."* |
| `Disclose` | text | 1036, 862 | 220 × 15 | `Show technical details ▸`, right edge **1256 = 236+1020** |

Against `27ea6536`'s desktop clauses: **divider — SATISFIED. Right-aligned disclosure — SATISFIED.
No footer copy — NOT SATISFIED.** The board copy is **byte-identical** to
`apps/control_plane/lib/features/products/add_product_page.dart:383-384`, which I read directly.

**So F6 is real, correctly measured, correctly attributed, and correctly escalated.** The cancelled lane's
two published claims — that the desktop spec matches the four `S` boards with "no copy", and that
(236,862) is the divider — are **both wrong**, exactly as the resumed lane states. The resumed lane's
correction is honest and it correctly distinguishes the decision's **observation** (wrong: the layer is
real, at those coordinates) from its **outcome** (untouched).

### D-8 — the coordinate table is MEASURED, not asserted. **CONFIRMED, row for row.**

I re-read `BPM` and `SM` independently. Every row of evidence §6.3 reproduces:

| Coordinate | `BPM` published | **mine** | `SM` Verified | **mine** | `SM` Unknown | **mine** |
|---|---|---|---|---|---|---|
| `Art S` box | `138,418 220×15` | **✓** | `138,418 220×24` | **✓** | `138,418 220×24` | **✓** |
| `Key State` box | `138,436 220×15` | **✓** | `138,446 220×15` | **✓** | `138,446 220×15` | **✓** |
| `Submit L` | `16,518` | **✓** | `16,520` | **✓** | `16,688` | **✓** |
| button helper | `16,552` | **✓** | `16,552` | **✓** | `16,720` | **✓** |
| `Disclose` | `16,580` 220w | **✓** | `16,580` 220w | **✓** | `16,748` 220w | **✓** |
| divider between | none | **✓ 0** | none | **✓ 0** | none | **✓ 0** |
| thin rules | `Top Rule 0,55` · `Rule 1 16,164` · `Nav Rule 0,764` | **✓** | identical | **✓** | identical | **✓** |
| `Disclose` left edge vs content | 16 vs 16 | **✓** | 16 vs 16 | **✓** | 16 vs 16 | **✓** |

**F7's correction is real.** `BPM` `Key State` = **436**, `SM` = **446**; `Art S` `BPM` 15 vs `SM` 24. The
cancelled lane's "every structural coordinate matches" was wrong on exactly the two rows the resumed lane
says were wrong, and the resumed lane's reasoning — that the two differing rows are content/wrap-dependent
and D-8 does not rest on them — is correct.

**D-8's consequence verified**: the human's mobile spec (left-aligned, no divider, no copy) is **already
satisfied** on all four `SM` boards, so H-1(b) correctly required **no mobile board edit**. `BPM` agrees.
This is a defensible, measured conclusion and it is the right answer to the question attempt 2 could not
reach.

### The `214.53px` withdrawal is HONEST

I checked the arithmetic rather than accepting the word "unreconcilable". Evidence §6.2 states
`parentX` 138 → `textLeft` 7826, 244 → 8038, 30 → 7610, on a board at absolute x 7550.
`7550 + 2×138 = 7826` ✓ · `7550 + 2×488 = 8038` ✓ · `7550 + 2×30 = 7610` ✓. **All three confirm a clean
2× scale**, so the figure genuinely is of unknown units. The withdrawal is well-founded, the replacement
claim (two lines, from the layer's own height 15→24) is stated as an observed layout fact rather than a
pixel inference, and the non-claim (exact rendered width, whether 24 is tightest) is stated explicitly.
**This is the correct way to withdraw a number.**

### Took on trust (not independently verifiable)

- **Pre-edit board state.** Penpot exposes no version history. I cannot judge any before/after; I judge
  the boards as they stand, as instructed, and I do not penalise the lane for an unanswerable question.
- **Whether revision 5's own board edits are the ones on the file.** The resumed lane made **zero** new
  board writes; the edits were the cancelled lane's. I verified the *end state* is correct and consistent
  with the decisions; I cannot attribute the writes.
- **No board was created or deleted by anyone.** I can only confirm 160/164 now.

---

## 4. G-7 — the two UI render sites are REAL and user-facing. **CONFIRMED, and the finding is right.**

I read both sites in the production source:

- `apps/control_plane/lib/features/product_detail/product_detail_page.dart:471` —
  `'${c.referenceName} · ${c.algorithm} ${c.fingerprint} · '`
- `…/product_detail_page.dart:676` — `: '${c.referenceName} · ${c.algorithm} '`

Both render, and `9417f8bf` states the reference "is a secret path or ARN" that "discloses vault
topology". **The lane's escalation from contract tidy-up to security defect is correct and I endorse it.**
The generated-package counts also reproduce exactly: `apps/server/.../generated/repository_credential_view.dart`
**12**, `packages/control_plane_client/.../repository_credential_view.dart` **11**. The YAML comments
(`repository_credential_view.yaml:3-5, :10`) do claim *"local secret store"* / *"held locally"* — **false
twice over**, as D-10 says.

**One caveat on method, in the lane's favour and against itself:** I searched `referenceName` repo-wide and
found ~30 more occurrences. I then checked whether each is a `RepositoryCredentialView` site and **most are
not** — `packages/platform_contracts/.../repository_credential.dart`, `product_credential.dart` (the DB row),
`postgres_product_registry_store.dart` and `schema_bootstrap.dart` are the **domain and storage** layers,
which `9417f8bf:167` explicitly keeps ("`referenceName` becomes an opaque row reference"), and
`generated/protocol.dart:3841` is the **`product_credential` DB table** (table name at `:3810`), not the
client view. **The 6-site framing is the right scope.** But one in-scope site is missing — MR5-3.

---

## 5. Source citations — every one re-read at the reviewed head `08c7590`

| Citation | Claim | Verified at `08c7590` |
|---|---|---|
| custody string `:542` **and** `:1038` | both `created on this device · the private half stays in the keychain` | **both exact** ✓ — D-4's "two false halves, two sites" is right |
| `_buildFooter` call `:314` / definition `:375` / copy `:383-384` | delete | **all exact** ✓ |
| desktop `note:` `:317-319` | delete | **exact** ✓ |
| mobile `TechnicalDetails` `:925` / `note:` `:926-928` | `note: null` | **exact, and the same string as `:317-319`** ✓ — D-3 confirmed |
| `design_primitives.dart:362` | `const TechnicalDetails({super.key, required this.lines, this.note});` | **exact** ✓ |
| `design_primitives.dart:396` | `const ContentRule(),` painted unconditionally | **exact** ✓ |
| `:398-410` `Row`/`Expanded(note ?? SizedBox.shrink())`/`InlineLink` | `note: null` ⇒ right-aligned | **exact** ✓ |
| **path** `apps/control_plane/lib/**shared**/design_primitives.dart` | not `lib/core/` | **exists and is `shared/`** ✓ — the lane's path correction is right |
| `repository_credential_view.yaml:10-11` | comment + `referenceName: String` | **exact** ✓ |
| `product_detail_page.dart:471`, `:676` | the two render sites | **exact** ✓ |
| `control_plane_repository.dart:108, :1098, :1691, :1709` | 4 client projections | **exact** ✓ |
| `design_tokens.dart:92-123` | palette values | **exact** ✓ |

**D-2's mechanism reasoning is correct and is the strongest engineering content in the revision.** `:396`
paints `ContentRule` unconditionally and `:402-403` makes `Expanded(SizedBox.shrink())` consume the width,
so `note: null` yields **divider + right-aligned button — the human's desktop spec, for free**. Mobile's
spec (no divider, left-aligned) is **opposite on both axes and not expressible today**. That is a
correct, non-obvious derivation and the Level-1 routing to the design-system owner is right: the human
decided the outcome; only the mechanism is open. **I concur with the lane and with the dispatch on this.**

### Contrast — I recomputed all ten figures independently. Every one reproduces to 0.00.

| Surface | Claimed | **Mine** | AA |
|---|---|---|---|
| `inkSecondary` on `card` light / dark | 6.74 / 6.10 | **6.74 / 6.10** | PASS |
| `inkTertiary` on `canvas` light / dark | 4.65 / 4.62 | **4.65 / 4.62** | PASS |
| `inkTertiary` on `card` light / **dark** | 4.99 / **4.23** | **4.99 / 4.23** | PASS / **FAIL** |
| `#ffffff` on accent light / `#06121f` on accent dark | 5.27 / 6.30 | **5.27 / 6.30** | PASS |
| SC-9 remediation, `inkSecondary` on `canvas` l/d | 6.28 / 6.65 | **6.28 / 6.65** | PASS |

Sanity anchors 21.00 and 1.00 reproduce. **The known `inkTertiary`-on-`card` dark FAIL at 4.23 is real,
unchanged, and correctly left as N10 rather than rounded away.** `a11y: PASS` is honestly scoped to the
surfaces this pass touched, and the artifact explicitly disclaims contrast-only limits. I concur.

---

## 6. M-1 — spot-checked, and it holds

I re-read **all 13** published numbers in the canonical files:

`design-revision.md` **`:83`** (the `total | 50.4px` row) · **`:85`** (the "collapses from ≈50px to exactly
36px" sentence) · marker **`:89-95`** (opens on the WITHDRAWN line, closes on "superseded, not deleted") ·
F8 row **`:435`** · marker **`:437-444`** — **all five exact.**
`report.md` **`:68`** (the button/helper bullet) · **`:126`** (the TRIVIAL F8 bullet) · **`:230`** (the
`risk_rationale` line) · markers **`:70-74`**, **`:128-133`**, **`:237-243`** · provenance note
**`:31-37`** — **all seven exact.** `design-revision-metadata.yaml:15-16` — **confirmed still correct.**

**All 13 hold.** The `+6 / +5 / +8 / +8 / +13` delta table is the right characterisation, and the lane is
right to have dropped the blanket "CONFIRMED, every number" claim in favour of a per-row table.

**L-1's three pointers, all verified present:** `design-revision-3.md:583` (G2 struck with the
`9417f8bf` resolution) ✓ · `:592` (G11 struck) ✓ · and the third site the rev-4 review missed — the B3 and
G2 claims on **one** paragraph, now at **`:449-450`** with a single pointer block at **`:452-486`**,
boundaries exact, retained text untouched ✓. The lane's correction of the review's own `:445` is right.

**The lane's account of hitting M-1 on itself is accurate, and I verified the direction of the damage.**
Its §4.4 correction to rev 3 added 13 lines above the gap table, which is why rev 4's `:633` is now
`:646` (I confirmed `grep -n '^## ' design-revision-3.md` → **`:646 ## 13. Assumptions carried forward`**)
and `:610-629` is now `:623-644`. The recorded lesson — *"re-reading what you edited is necessary but not
sufficient; you must re-read what you write about it"* — is the right lesson, and **MR5-1 below is that
same lesson missed once more, in this pass.**

---

## 7. Findings

### MR5-1 (MEDIUM) — the retired-suffix count is wrong in two of its three published forms, and I can prove the right value

The artifact set publishes **three different counts** for the same set of retirements:

| Where | Published |
|---|---|
| `design-revision-5.md:361` · `penpot-board-evidence.md:262` | **`7 ×` `Trust *` names** |
| `design-revision-metadata-5.yaml:99` · `traceability-matrix-5.md:77` | **17** / **Seventeen** suffixes retired |
| `design-revision-5.md:169` | **`PENDING D4` and `PROVISIONAL`** retired from **all sixteen** layer names |
| `penpot-board-evidence.md:181-188` | "was **8 / 8**. All **sixteen** suffixes retired" — and enumerates the eight: `Trust Bg`, `Trust Edge`, `Trust Btn`, `Trust K`, `Trust Body`, `Trust Created`, `Trust Host`, `Trust Btn L` |

**Live measurement settles it.** Each Unknown board carries **exactly 8** `Trust *` layers, **none
suffixed**; the Verified pair carries **0**:

```
Unknown-Light  trustCount 8  suffixed []  Trust Bg|Trust Body|Trust Btn|Trust Btn L|Trust Created|Trust Edge|Trust Host|Trust K
Unknown-Dark   trustCount 8  suffixed []  (identical)
Verified-Light trustCount 0
Verified-Dark  trustCount 0
```

So **16 is the correct count of retired `· PROVISIONAL` suffixes** — and §6 of the evidence file is right
while §6.2 of the same file contradicts it by one.

Required:

1. `design-revision-5.md:361` — `7 ×` → **`8 ×`**.
2. `penpot-board-evidence.md:262` — `7 ×` → **`8 ×`** (and it now agrees with its own `:181-188`).
3. `design-revision-metadata-5.yaml:99` — **Seventeen → Sixteen**.
4. `traceability-matrix-5.md:77` — **17 → 16**.
5. `design-revision-5.md:169` — currently conflates two sets. `PENDING D4` was retired on **4 more** layer
   names (one `Art S` per board, per its own §3.2 before/after table), so the combined total is **20**, not
   sixteen. Split the sentence into its two populations and give each its own number.
6. Retiring the count as `NOT_VERIFIABLE` would also be honest — Penpot has no version history — but since
   the end state *is* live-verifiable (8 unsuffixed layers × 2 boards), publishing the correct number is
   better than publishing none.

Why MEDIUM and not LOW: this is a **published-as-measured count that is wrong, in four files, including
the acceptance metadata a QA contract and an implementer will read** — and it is the **third instance of
this work item's signature defect in the very revision created to eliminate it.** Zero design impact, but
the pattern is the point.

### MR5-2 (MEDIUM) — the design brief records the lane's only BLOCKER as met

`design-brief.md:98`, the **SC-7** row:

> | **SC-7** *(added rev 5)* | Both platforms' footers match `27ea6536` **as measured**: desktop = divider
> + right-aligned disclosure + **no copy**; mobile = left-aligned + no divider + no copy | Live read-back of
> four `S` boards and four `SM` boards; `penpot-board-evidence.md` **§6.3** |

Three defects in one row:

1. **No `NOT MET` disposition.** SC-9, one row below, carries an explicit **"NOT MET — reported, not
   claimed"** marker and a "**Not met.**" verification cell. SC-7's desktop "no copy" clause is
   **demonstrably unmet on all four `S` boards** — that is F6, the revision's own BLOCKER — and carries no
   marker at all. The lane established the convention one row down and did not apply it here.
2. **Wrong section cited.** §6.3 is **D-8** (`SM` vs `BPM`). The desktop conformance read-back, and F6, are
   in **§6.4**. A reader following the citation goes to the section that cannot contain the desktop answer
   — which is plausibly how the failure was missed.
3. **The brief never mentions F6 at all.** `grep -n "F6\|footer copy\|N6b" design-brief.md` → **no hits.**
   The brief therefore presents the desktop footers as conformant and gives a reader nothing pointing at
   the blocker.

`traceability-matrix-5.md:76` and `design-revision-5.md` §4.4 **are** honest ("MET on mobile · GAP on desktop
boards → F6"). So this is confined to the brief — but the brief's Success criteria section **is the
acceptance baseline**, and it is the artifact a reader opens first.

Required: mark SC-7 **`MET on mobile · NOT MET on desktop (F6)`**, re-cite **§6.4**, and add a pointer to
F6 / N6b in the brief.

### MR5-3 (MEDIUM) — G-7's site table omits the server-side constructor; N6a would break the build

The revision's §6.1 table lists **6 sites**. I searched `referenceName` repo-wide (my first grep returned 0
— a zsh glob error on `--include=*.dart`; re-run quoted, the real count is ~30) and classified each. Most of
the extra hits are the **domain and storage** layers, which `9417f8bf:167` explicitly keeps ("`referenceName`
becomes an opaque row reference"), and `generated/protocol.dart:3841` is the **`product_credential` DB
table** (table name at `:3810`), not the client view — so the 6-site *scope* is right.

**But one in-scope site is missing:**

```
apps/server/lib/src/services/ui_view_mappers.dart:176
    // Reference name only — the private half is never in this payload.
    referenceName: c.referenceName,
```

This is `static RepositoryCredentialView repositoryCredentialView(RepositoryCredential c)` — **the
server-side code that constructs the view.** Dropping `referenceName` from the YAML regenerates both
client packages without it, and this call site **will not compile.** The revision's own text quotes the
decision's blast-radius statement as *"two will not compile"*, so it knows the change breaks compilation —
but an implementer working the published 6-site table misses this file.

Required: add `apps/server/lib/src/services/ui_view_mappers.dart:176` as a seventh site in §6.1 and in
N6a, noting it is the server-side view constructor. (Also worth stating that the `platform_contracts` and
`product_credential` occurrences are **deliberately retained** under `9417f8bf:167`, so a future lane does
not "helpfully" strip them too.)

### MR5-4 (LOW) — a one-off disagreement between two files this pass wrote

`design-revision-4.md:160` says the rev-3 §12 block is **`:624-644`**; `design-revision-metadata-4.yaml:154`
and `design-revision-5.md:62,588` all say **`:623-644`**. Measured: heading `623`, last content `642`, blank
`643`, `---` `644`. Both land on the right block, so nothing points at unrelated text — but the two files
were written in the same pass and disagree by one. Pick one and make them agree.

### MR5-5 (LOW) — the provenance basis for every line citation is stale at the reviewed head

See §2. `43d328b → 289f1d3` is empty (reproduced), but `289f1d3 → 08c7590` touches **4** files in
`packages/product_registry/`. **No cited line is wrong** — I verified each individually at `08c7590` — but
the revision should state the reviewed head and note the advance, or state the basis in a form that still
holds. Compounded by revision 5 being wholly untracked.

### MR5-6 (LOW) — SC-8 cites the wrong section

`design-brief.md:99` verifies `Trust Created` against "§4 of `design-revision-5.md`". `Trust Created` is in
**§5.1 / §5.2**. §4 is H-1(b), the footer. Same wrong-section class as MR5-2.

### MR5-7 (LOW) — "zero intra-panel overlaps" is not literally true

`penpot-board-evidence.md` §6.2 and `design-revision-5.md:376` claim **"zero intra-panel overlaps"**. I
measured: `Trust Btn` (`30,618 180×30`) geometrically encloses `Trust Btn L` (`30,624 180×18`), and
`Submit (label only — no nested subtext)` (`16,510/678 358×34`) encloses `Submit L`. That is the
button-rect-plus-label idiom, **not a defect** — and the lane already shows it applies this distinction
elsewhere, flagging the analogous 1px `Art T`/`Art S` box overlap as pre-existing and benign. The
substantive claims all hold: `Trust Created` is contained, the chain geometry is unchanged, zero nav
collisions. Wording precision only.

---

## 8. SC-9 — a correct scoping call, not an unfunded requirement

The dispatch asked me to judge this. **My judgement: the lane is right, and the way it is right matters.**

The `OWNED_PATHS` named **four boards by id and no more**. R.11g item 5 forbids doubling the refused-mint
surface onto the Unknown-host board. The lane therefore did **not** author two new boards on a shared page
of 160 — which is the failure `evidence §7` already records once, when scratch boards created by failed API
calls had to be caught by inventory diff and removed. Authoring them unilaterally would have exceeded
declared scope **and** repeated a known incident.

And critically, the lane **did not claim SC-9**. It marked it **NOT MET, reported not claimed**, wrote the
copy and full layout out anyway so an owner inherits a finished specification rather than a question, and
escalated as **N6c** to the Manager as an **ownership blocker**. The residual risk — an unowned
requirement quietly dying — is real, but the lane mitigated it the only way a design lane can: by making it
impossible to overlook. **Correct call. One recommendation: the Manager should assign the owner in this
cycle rather than carrying N6b/N6c forward, since both block implementation and neither needs a human.**

---

## 9. Risk level — independently 3, agreement YES

I re-derived it rather than inheriting it, and I re-verified the discharge claim myself.

**Level-3 gate DISCHARGE — verified directly, not taken on trust.** All five named decisions are
`status: RESOLVED`, all carry `decided_by: "repository owner (interactive structured question UI, session
orchestrator-main)"` **verbatim**, and their `owner: design-agent` follow-up counts are **2 / 3 / 2 / 2 / 1**
for `9417f8bf` / `27ea6536` / `898b07d0` / `ae1c1f79` / `7b1bc8b7` — **exactly the table in the
revision**. I also confirmed **all nine** decisions named in the dispatch are RESOLVED. **The gate is
discharged and correctly not re-opened.** (`876c6b97` does carry one `design-agent` follow-up, which is
consistent with the lane not naming it as load-bearing.)

**Three independent Level-3 clauses, each met:**

1. **Core workflow / user mental model** — `898b07d0` splits identity from registration, so "Register
   product" changes meaning from *creates the product* to *commits verification of a product that already
   exists*. **Verified on the boards**: both eyebrows rewritten, and `Trust Created` states the
   consequence in user-facing copy.
2. **Information architecture** — a new user-facing element (`Trust Created`) that exists in no prior
   revision. **Verified present on both Unknown boards, contained, correctly toned.**
3. **Navigation structure** — R.11g item 3's resume route on `ProductDetailPage`. Specified in §4.5,
   **not rendered** (G13, honestly reported).

**D-2 is correctly Level 1, not a gate** — the human decided the outcome in `27ea6536`; only the mechanism
(`TechnicalDetails` parameter vs mobile-local widget) is open, and that is design-system-owned. I concur,
and my §5 verification of `design_primitives.dart:396` and `:402-403` confirms the derivation.

**The revision's `design_system_compliance: PARTIAL` is the honest score.** Not PASS because D-2 is an
unsatisfied compliance requirement **and** F6 is an unsatisfied conformance requirement on four boards.
Both named, neither rounded, neither introduced by this lane. **Concurring.**

---

## 10. What I did NOT review — stated explicitly

- **Any Flutter widget render, app runtime, or screenshot.** Nothing here is evidence about a running app.
- **`flutter analyze`, `dart analyze`, any build, `flutter pub get`.** Feasibility **MEDIUM rests on
  reasoning, not a green build** — the lane's own disclosure, and I accept it rather than restating HIGH.
- **Any Docker or Compose command whatsoever** — not `info`, `ps`, `logs`, `config`, or any mutating one.
  **None issued. No breach.** I did not start a database and I did not need one; nothing in this review
  required one, so there is no blocker to report on that count.
- **Pre-edit board state.** Penpot exposes no version history. I cannot judge any before/after and did not.
- **Attribution of the board writes.** The resumed lane made zero new writes; the edits on the file are the
  cancelled lane's. I verified the end state, not who made it.
- **A full walk of the four desktop `S` boards.** I read the footer band in full (which is what F6 needs)
  plus inventory and counts — the same bound the producer declared. Not layer-by-layer.
- **The other 156 boards on the page**, except the two `BPM · Add Product` and four `S · Add Product` boards.
- **`Flutter` apps/**: `product_detail_page.dart` and `add_product_page.dart` were read **only** at the cited
  lines. I did not review their behaviour.
- **Screen-reader, focus order, WCAG beyond colour contrast.** The lane explicitly disclaims these and I do
  not supply them.
- **The lost rev-4-design-review report** authorising this morning's merge (still untracked — the Manager
  should recover or re-derive it; I did not, it is not mine).
- **The keys lane artifacts, the ADR-0018 amendment artifacts, `design-brief.md`'s non-SC content, and
  revisions 1–2 and 4 beyond the lines this pass cites.**
- **The settled items** — B2/N1, B4/N2, N4/G9, N6, N10, and all nine decisions. **None re-raised.**
- **`.decisions/**` beyond confirming all nine RESOLVED and reading the five load-bearing ones.**

---

## 11. TRACEABILITY

`requirements_covered` **R1–R7** and **H-1(a)/(b)/(c), M-1, L-1** — I verified every board row of the
traceability matrix §1 that names a coordinate or a fill; all reproduce exactly, and every token mapping
(`canvas`, `card`, `inkSecondary`, `inkTertiary`, `accent`) resolves to the exact hex in
`design_tokens.dart:92-123`. **R3** is correctly marked SUPERSEDED-and-specified. **The two
`9417f8bf` follow-ups are SPECIFIED, not implemented** — correctly, as neither is in `OWNED_PATHS`.

**Traceability gaps, all three the lane's own and correctly reported, none silently narrowed:**
- **G13** — R.11g item 3's resume affordance specified, not rendered (`ProductDetailPage` not owned).
- **G14 / SC-9** — the A3 refused-mint surface needs two unowned boards; **SC-9 recorded NOT MET**.
- **MR5-3** — the G-7 site table is incomplete by one file (mine).

**No orphan design element.** Every layer on the four `SM` boards traces to a requirement or a token.
`Trust Created` traces to `898b07d0` and is the element that discharges the requirement — the lane is
right that the `· PROVISIONAL` layer-name annotation never did, and right to retire it rather than count it.

---

## 12. Learning completeness

Per `docs/engineering/LEARNING_POLICY.md`: **no durable discovery was left unclassified.** The producing
lane's §10 classifies every discovery, assigns exactly one category and authority level, and routes the two
above-lane-authority items out (`CONTRADICTION` → human/governance for `27ea6536` vs its own boards;
sibling-lane for `N-9`'s internal contradiction). **That is correct and I endorse it** — in particular it
correctly declined to "resolve" `N-9`'s rule-vs-string tension by rewriting the string, and adopted the
prescribed string verbatim while flagging the tension to the keys lane.

**One observation for the Manager, consistent with the lane's own recommendation:** the stale-number defect
has now been caught by hand **four** times (rev 4's M-1, the cancelled lane's §6.3, this pass's own §4.4
correction, and MR5-1). It is mechanically checkable — grep every `:NNN` in the owned set and confirm the
target line — and MR5-1 is the argument for building that checker now rather than after the fifth
occurrence.

---

## 13. SAFE_PARALLEL_WORK

**SAFE**

- **The keys lane's independent review** — disjoint paths; its § R.11g numbers were re-verified here and
  hold at `08c7590`.
- **Non-UI implementation prep on `add_product_page.dart`** — the custody string at `:542` **and** `:1038`
  (D-4), `note: null` at `:317` and `:926`, deletion of `_buildFooter` (`:375` / `:314`) (D-3). Every
  number re-read by me at the reviewed head.
- **G-7's contract change (N6a)** — disjoint from this lane's paths — **but see MR5-3: include
  `ui_view_mappers.dart:176` in the work list.**
- **ADR 0018's A2 amendment** recording the `9417f8bf` supersession (owner: human / ADR owner).
- **Persisting revision 5 to git.** It is currently untracked and three reports have already been lost.

**PROHIBITED**

- **Design Contract freeze of revision 5** — three record corrections are outstanding (MR5-1/2/3), the
  Level-3 content is correct but the acceptance baseline in `design-brief.md` still records F6 as met, and
  two ownership blockers (N6b, N6c) are open.
- **Implementation of the desktop footer** — four `S` boards do not satisfy the resolved spec. The *build*
  change may proceed (`note: null`, `_buildFooter` deletion); the **boards** may not be edited by any lane
  that does not own them, and no lane currently does.
- **Any lane editing** the four `SM` boards, or `BPM ·` or `S · Add Product` boards, or
  `.decisions/**`, or this lane's task directory.
- **Authoring the refused-mint surface on the Unknown-host board** — forbidden by R.11g item 5.
- **"Helping" with G-7** by also stripping `referenceName` from `platform_contracts` /
  `product_credential` / the persistence layer — `9417f8bf:167` keeps it there deliberately as an opaque
  row reference.

---

## 14. Judgement

**This is a materially better revision than revision 4, and the improvement is real rather than
rhetorical.** Its predecessor was overtaken by decisions resolved after it was written; this one was
written *after* those decisions, re-verified them directly, and applied them — including a string that was
false in user-facing security copy and an element that was false about what a product can do. Where it
found the cancelled lane's work wrong, it said so with measurements rather than reverting it silently, and
its rule for deciding that — *retention without a marker is not neutral* — is the same rule the Gate-D3
review of revision 4 applied, quoted correctly and applied consistently.

**The board evidence is the strongest thing in this work item.** I had the file open and I could check, and
**every** claim held: the custody string and its 80 characters, the layer renames, the 436→446 and 456→466
moves and the 4px of preserved slack, the two-line wrap inferred from the layer's own height rather than
from pixels, `Trust Created`'s exact box, font, fill and containment, `Disclose` left-aligned at 16 with
zero dividers and zero footer copy, the D-8 table row for row across both board families, and **F6 itself,
on all four desktop boards, exactly as reported.** The 214.53px withdrawal is arithmetically sound, not
merely asserted to be unreconcilable — I checked the 2× scale on all three samples. And the D-2 derivation,
that `note: null` accidentally produces the human's desktop spec for free while making the mobile spec
inexpressible, is a genuinely useful finding.

**What I am returning is three record corrections, not a redesign.** One number that is wrong in two of its
three forms, with a value I can prove from the live boards. One success criterion in the brief that records
the lane's own blocker as met, cites the one section that cannot contain the answer, and never mentions
F6 — in the very artifact that states the acceptance baseline. And one REQUIRED security change routed to
the implementer whose site list is missing the file that constructs the view. **None of these changes a
board, a string, a geometry, a token or a requirement.** All three are the same defect class this work item
has now produced four times, which is precisely why the lane's own closing recommendation — a checker that
re-reads every `:NNN` after the last write — should be built now.

**Risk level 3, agreed, gate discharge independently verified. No human decision is needed and none is
requested.** I did not find a single false claim about a board.

