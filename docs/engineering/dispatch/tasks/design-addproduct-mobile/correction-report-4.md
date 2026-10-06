# Correction Report 4 — Add Product mobile boards, cycle 4 (RECORD CORRECTIONS ONLY)

Returned verbatim by the `design-agent` lane and persisted here per `aef-orchestrator` §14. Revision 3 is
retained unedited at `design-revision-3.md`; the current revision is `design-revision-4.md`.

## Mandatory header

```yaml
RESULT: DESIGN_REVISION_COMPLETE
TASK_ID: design-correct-addproduct-mobile
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — four missing SM mobile boards + layout/copy corrections (record corrections only, cycle 4)
WORKTREE: /private/tmp/shipit-correct-addproduct-mobile
BRANCH: design-correct-addproduct-mobile
BASE_SHA: 77c19f1
HEAD_SHA: 77c19f1
COMMITTED: NO            # forbidden by dispatch; artifacts are untracked for the Manager to persist
```

**`BASE_SHA == HEAD_SHA` because I am forbidden to commit and did not.** `git status --short` reports exactly
one entry — the untracked `docs/engineering/dispatch/tasks/design-addproduct-mobile/` directory. **No tracked
file anywhere in the repository was modified.** Nothing committed, nothing pushed.

## What this pass was, and what it was not

The Gate D3 re-review of revision 3 returned `DESIGN_REVIEW_CHANGES_REQUIRED` with **zero BLOCKERS, zero
HIGH**, and an explicit refusal to let the record stand:

> this revision's own words currently make it unsafe to freeze: it annotates away an AA failure that its own
> ledger marks `FAIL` and that its own boards draw, and the matrix that `DESIGN_GOVERNANCE` invariant 8
> makes mandatory names the wrong foreground token for the primary action's helper. … **Approving because it
> is cycle 3 would relax a standard on the basis of the calendar.**

**This pass made no board edits.** Seven items were dispatched: six corrections and one record-only citation
fix. Every one is a change to a document.

| | |
|---|---|
| Boards edited | **0** |
| Layers edited | **0** |
| Shapes created | **0** |
| Boards created / renamed / moved / deleted | **0 / 0 / 0 / 0** |
| Penpot calls | **4, all read-only** (`findShapes`, `fills`, `bounds`; no setter, no `create*`, no `appendChild`, no `remove()`) |
| Docker / Compose commands | **NONE — not even read-only** |
| Tracked files modified | **NONE** |
| Commits / pushes | **NONE** |

## Independent verification before application — seven for seven

I did not take a single dispatched claim on faith. Each was re-derived from source at `77c19f1` and, where it
concerned a board, from a read-only sweep of the live Penpot file. **All seven confirmed on substance; none
rejected.** Full table: `design-revision-4.md` § 1.2. Two facts the dispatch did **not** state were found and
are recorded:

1. **`.decisions/9417f8bf-73b8-4827-9515-bdfe92e5a9d5.yaml` does not exist at this worktree's HEAD `77c19f1`** —
   `.decisions/` holds six files there. It was filed in commit `064703d` (*"five Gate D4 decisions filed"*, the
   child of `77c19f1`) and was read at the canonical checkout (`3a87e27`). Revision 3 already cites
   `27ea6536` on exactly this footing. Recorded as assumption **A8**.
2. **`docs/engineering/dispatch/tasks/design-review-addproduct-mobile/` does not exist in this worktree at all**
   — the worktree is one commit behind `25f723d`. `report.md` (revision 1's review, which closes G11) and
   `report-revision-2.md` were read read-only at the canonical checkout.

What I verified myself, with the figures:

- `DesignPanel` = `palette.card` — `design_primitives.dart:318-320`.
- `MicroLabel('DEPLOY KEY · THIS PRODUCT ONLY', color: palette.inkTertiary)` at `:531-534` (desktop) and
  `:1027-1030` (mobile); colour lines **`:533`** / **`:1029`**, inside `DesignPanel(` at **`:503`** / **`:1002`**.
- `Text(_registerButtonSubtext(state), … color: palette.inkTertiary)` at `:913-920`, colour line **`:918`**,
  inside the `DesignPanel(` at **`:853`**.
- Live boards: `Art K` = `#6e706e`/`#8a8983` inside `Art Bg` = `#ffffff`/`#262827`, **all four boards**;
  `Submit Sub · helper BELOW button` = `#5a5c5b`/`#a8a6a0` at y **11470–11485**, outside every `card` rect
  (`Trust Bg` ends **11412**), on the board's own `#f7f7f5`/`#1f2120` = `canvas`. A subtree sweep of **every**
  text layer against **every** card-coloured rect returns **`Art K` as the only `inkTertiary` on `card`**.
- Contrast recomputed independently from `design_tokens.dart:91-130` (sanity black-on-white **21.00**,
  white-on-white **1.00**): `inkTertiary`/`card` **4.99 / 4.23**; `inkTertiary`/`canvas` **4.65 / 4.62**;
  `inkSecondary`/`card` 6.74 / 6.10; `inkSecondary`/`canvas` 6.28 / 6.65. **Every published figure reproduced.**
- `b869ec24` — `RESOLVED`, ARCHITECTURE, *"Where does deploy-key generation and storage belong…"*.
  `9417f8bf` — `PENDING`, SECURITY, *"Which substrate holds the server-stored private half of a product's
  deploy key?"* `grep -c 9417f8bf` over revision 3, its metadata, the evidence file and correction-report-3 =
  **0 / 0 / 0 / 0**.
- Flutter 3.44.7 spans: `button_style_button.dart:266-274` (`defaultColor`), `:382-387` (`effectiveValue`);
  repo: `902` `MobilePrimaryButton(`, `678` `child: FilledButton(`, `679` `onPressed:`.

## Files touched

```text
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-4.md              # NEW — current revision
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-metadata-4.yaml   # NEW — current metadata
docs/engineering/dispatch/tasks/design-addproduct-mobile/correction-report-4.md            # NEW — this report
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-3.md             # rev 3: supersession header + 4 in-place pointers; substantive text untouched
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision.md               # rev 1: header line numbers corrected (L-R3); body untouched
docs/engineering/dispatch/tasks/design-addproduct-mobile/report.md                        # rev 1 report: header line numbers corrected (L-R3) + provenance note extended; body untouched
```

All six are inside `OWNED_PATHS`. **Nothing outside was touched** — not production source, not
`.decisions/**`, not `WORK_STATE.md`, `LANES.md`, `DECISIONS.md`, not the keys lane's directory, not the
review lane's directory.

## What changed and why — per finding, with the exact text replaced

Authoritative changelog: `design-revision-4.md` § 14.

**M-R1 — the ledger annotated away a live AA failure.** Revision 3's row read
`` `inkTertiary` | `card` | 4.99:1 | 4.23:1 | pass / **FAIL** | now unused on these boards ``. The annotation
was **false**. Four record changes, **zero board edits** — the boards are faithful to the build, and the build
is faithful to the token:

1. The annotation is deleted from § 3.2.
2. The row's Note now reads: **`Art K` (`DEPLOY KEY · THIS PRODUCT ONLY`), inside `Art Bg` = `DesignPanel` =
   card, all four boards; board and build agree — AA FAIL in dark.**
3. Reason **(c)** added to `ux_accessibility_score_reason`, citing 4.23:1 on `Art K`.
4. **N10** filed (Level 1, design-system owner): `ShipItPalette.inkTertiary` fails AA on `card` in dark
   (4.23:1) with live call sites at `:533`/`:1029`; `ShipItPalette` is design-system-owned, exactly as N2
   records for `negative`. **G13** added to the gap list; a MATERIAL bullet added to § 10.

Additionally, N7's withdrawal reason was **narrowed**. It read "no Add Product call site puts these lines on
`card`, so it is not Add Product's finding to raise" — true of the `TechnicalDetails` lines, **false once
generalised**, because `Art K` is exactly such a call site. The withdrawal now reads "for the
`TechnicalDetails` lines only" and points at N10.

**M-R2 — the matrix named the wrong foreground for the primary action's helper.** The cell was
`` `monoMeta` 10/400; **`inkSecondary`** `` with no surface. It now carries the build's **`inkTertiary`**
(`add_product_page.dart:918`), the **same surface note the `Submit` row one line above carries**
(`Surface = card in code, bare page background on the board (G12)`), both surfaces' ratios, and an explicit
statement of **which value the board keeps** — `inkSecondary`, aspirational and more legible (6.28:1 /
6.65:1 on `canvas`) — versus which the build renders (`inkTertiary`: 4.65/4.62 on `canvas`, **4.99/4.23 on
`card`**). The dark `card` figure is recorded against **N10**. New **§ 6.1** and **G14** record the reasoning.
**This is the row implementation and QA inherit as the acceptance baseline, which is why it was not a
follow-up note.**

**M-R3 — the matrix's "Settled by" for `Art S` pointed at a RESOLVED decision.** The cell was
`**b869ec24**`. It now reads **`9417f8bf (PENDING D4)`**, with `b869ec24` cited alongside for the
server-side-storage constraint it *does* settle. **The layer name, its string and its `PENDING D4` marker are
untouched; § 8, G2 and the metadata all keep it open.** The human's decision has **not** been quietly
resolved, before or by this pass — the defect was confined to one cell telling a reader which authority
closed a design element, on the one row that is explicitly not closed. That is invariant 8 failing in the
direction that makes an open gate look settled.

**L-R1 — a cross-reference to a section that does not contain the lesson.** `design-revision-3.md:37` persisted
the `WORKFLOW_IMPROVEMENT` lesson to "§ 13"; § 13 is *Assumptions carried forward* (A1–A6). Revision 4 names
**§ 0 and § 12 of the predecessor** and the classified entries at **`correction-report-3.md:261-281`**, and
`design-revision-3.md` carries a pointer at the wrong reference. Same class as revision 3's own §12 rule 2 —
a claim about an artifact made from memory.

**L-R2 — G11 was stale and is now closed.** `docs/engineering/dispatch/tasks/design-review-addproduct-mobile/report.md`
exists (commit `25f723d`), is revision 1's Gate D3 review, and its own header states *"This file is the
authoritative copy; the correction lane's G11 is now closed."* Read in full, read-only. **G11 struck from
§ 11's table and removed from `non_requirement_gaps`**, with a comment recording why — rather than left in the
open-gap list with a note contradicting it.

**L-R3 — the withdrawal markers invalidated their own line citations.** Verified live:

| Cited by revision 3 | Actually at | Marker |
|---|---|---|
| `design-revision.md:70`, `:72-73` | **`:77`**, **`:79`** | `:83-89` |
| `design-revision.md:414` | **`:429`** | `:431-438` |
| `report.md:48` | **`:62`** | `:64-68` |
| `report.md:100` | **`:120`** | `:122-…` |
| `report.md:197` | **`:224`** | `:231-…` |
| `design-revision-metadata.yaml:15-16` | **still correct** — left exactly as it stands | `:31-…` |
| `design-revision.md:6-7`, `report.md:7-8` (headers' own claims) | corrected | — |

Revision 4's § 0.1 and § 7.1 show each number as `**was …**` so the drift stays visible; `design-revision-3.md`
keeps pointer lines at the four affected sites rather than having its text rewritten.

**L-R4 — record only, NOT recorded as a finding.** `MobilePrimaryButton` `:902` (was `:904-911`); `FilledButton`
`:678` with `onPressed:` `:679` (both written and labelled, so neither can be misread again);
`button_style_button.dart:266-274` (was `:266-273`) and `:382-387` (was `:381-391`). **Every load-bearing
citation the review checked was already exact.**

**Not touched, deliberately:** H-N1, H-R1, M-N5, M-N1, M-N4, M-N3, L-N4, M-N6, L-N2, L-N3 (all confirmed
closed); `27ea6536` (B3), N1, N2, N4, N6 (**not** re-raised); the `Art S` string and its `PENDING D4` marker;
and every board.

## Validation results

| Command / check | Status | Evidence / note |
|-----------------|--------|-----------------|
| Independent WCAG 2.1 recomputation over `design_tokens.dart:91-130` | pass | 4.99/4.23, 4.65/4.62, 6.74/6.10, 6.28/6.65, 5.72/3.68, 14.06/15.57, 4.60/4.57, 4.33/4.88 all reproduce; sanity 21.00 / 1.00. Script run read-only in `/var/folders/…/opencode`, nothing written to the repo |
| Read-only Penpot sweep (4 `penpot_execute_code` calls) | pass | root children 44/44/36/36; subtree text 29/29/24/24; `Art K` = `#6e706e`/`#8a8983` in `Art Bg` = `#ffffff`/`#262827` on all four; `Submit Sub` = `#5a5c5b`/`#a8a6a0` at y 11470–11485, outside `Trust Bg` (ends 11412) and `Art Bg`; `Art S` present, untouched |
| `grep -n` citation checks at `77c19f1` | pass | `:902`, `:678`, `:679`, `:853`, `:531-534`, `:1027-1030`, `:913-920`, `:316`, `:925`; SDK `:266-274`, `:382-387` |
| `grep -c 9417f8bf` over revision 3 + metadata + evidence + report | pass | `0 / 0 / 0 / 0` |
| Decision-object status/question reads | pass | `b869ec24` RESOLVED/where; `9417f8bf` PENDING/at-rest substrate |
| `git status --short` in the worktree | pass | one untracked entry: `docs/engineering/dispatch/tasks/design-addproduct-mobile/` |
| Metadata structural check (top-level key uniqueness) | pass | 26 top-level keys, 0 duplicates |
| `flutter analyze` | **NOT_RUN** | needs `flutter pub get`, which writes outside `OWNED_PATHS`; `apps/control_plane/.dart_tool/` absent at this HEAD. **No feasibility claim derives from a gate that was not run** |
| `flutter pub get` | **NOT_RUN** | as above |
| Flutter widget render / visual diff | **NOT_RUN** | no widget was rendered; § 5's read-back remains a source derivation (assumption A6) |
| Docker / Compose (any command, including read-only) | **NOT_RUN** | forbidden by dispatch and by this lane's standing hygiene rule |
| Tests | **NOT_RUN** | no source change; nothing to test |
| Board export / screenshot comparison | **NOT_RUN** | no board edit, so no new visual evidence exists; the boards this pass asserts about are the ones revision 3 exported |

## Evidence (revision-pinned)

```yaml
EVIDENCE_REVISION: 77c19f114ee691e8c434afe37b7c84494b66dc40
BUILD_COMMAND: NOT_RUN — design artifacts only; no build exists for this lane
SERVE_OR_RUN_COMMAND: NOT_RUN — nothing to serve
ENVIRONMENT / BASE_URL: n/a — no runtime
ARTIFACTS:
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-4.md
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-metadata-4.yaml
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/correction-report-4.md
  - "penpot:d8ac01df-6646-81d2-8008-a366c09aa9d3 :: four SM boards read-only in 4 queries; 44/44/36/36 root children, 29/29/24/24 text layers; 0 writes"
```

Visual authority: the four `SM - Add Product — …` boards this lane owns, on Penpot page
`d8ac01df-6646-81d2-8008-a366c09aa9d3`. **No new captures this pass** — nothing was drawn, so there is
nothing new to capture, and revision 3's exports stand.

## Documentation updated

```text
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-4.md
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-metadata-4.yaml
docs/engineering/dispatch/tasks/design-addproduct-mobile/correction-report-4.md
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-3.md
docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision.md
docs/engineering/dispatch/tasks/design-addproduct-mobile/report.md
```

## Unresolved issues and blockers

**No blocker. One provenance gap I am reporting rather than closing, and one thing I declined to do.**

1. **The Gate D3 re-review report of revision 3 does not exist on disk.** The dispatch directed me to read
   `docs/engineering/dispatch/tasks/design-review-addproduct-mobile/report-revision-3.md` **in full**. It is
   absent from this worktree, from the canonical checkout (`3a87e27`), and from every object reachable from
   every ref (`git log --all -- '**/report-revision-3.md'` returns nothing). **I applied the findings as
   dispatched, verbatim, and verified every one independently** — so the corrections themselves rest on source
   and on the live file, not on the dispatch's authority. The residual risk is narrow and I state it rather
   than hide it: **I cannot assert the dispatch transcribed the review exhaustively.** This is the same class
   as G11 one generation earlier, and `LEARNING_POLICY.md`'s rule is the operative one — *never rely on
   in-memory-only state.*
2. **I did not write that report, and the dispatch's "persist path may need creating — write it there" was
   not a thing I could honestly do.** That document is the independent design-reviewer's; this lane's
   `OWNED_PATHS` does not include the review lane's directory; and authoring a review of my own work would be
   self-approval, which `AGENTS.md` and my own agent contract both forbid. **Persisting it is the reviewer's
   and the Manager's act.** If the Manager wants it on disk, dispatch the reviewer or do it from the returned
   text.
3. **For the design-system owner (not a blocker on this lane):** **N10** — `ShipItPalette.inkTertiary` is
   **4.99:1 light / 4.23:1 dark on `card`**, i.e. AA FAIL in dark, and it has a live Add Product call site on
   all four boards and in the build. Either a darker `inkTertiary` for `card` surfaces in dark, or a card-safe
   tertiary token for eyebrows inside a `DesignPanel`. This is the same routing N2 already uses for
   `negative`; it needs no decision from this lane.
4. **Open human gate, unchanged and NOT escalated by this revision:** **`9417f8bf`** — *"Which substrate holds
   the server-stored private half of a product's deploy key?"* (`status: PENDING`). Layer `Art S` keeps its
   string and its `PENDING D4` marker. Revision 4 corrected which decision id the matrix cites; it did not
   resolve, pre-empt or re-open anything. `27ea6536` (B3) is not re-raised.

## Safe parallelism

```yaml
SAFE_PARALLEL_WORK:
  - "Independent Design Review of revision 4 (Gate D3, cycle 4) — this is the next gate and nothing waits on it"
  - "Independent Design Review of the sibling lane's revision (design-addproduct-keyservice) — disjoint OWNED_PATHS"
PROHIBITED_PARALLEL_WORK:
  - "Design Contract freeze — prohibited until revision 4 is independently reviewed; freezing it is what the
     re-review refused, and re-freezing before review would repeat exactly that"
  - "Any lane editing docs/engineering/dispatch/tasks/design-addproduct-mobile/** — OWNED_PATHS overlap"
  - "Any lane editing the four SM boards — they are this lane's OWNED_PATHS, and revision 4 changed none of them"
```

## Cleanup confirmation

- [x] All processes started by this lane are stopped. **None were started.** No server, no container, no
      watcher, no port. The Penpot plugin tab was used read-only and left as found.
- [x] Temporary artifacts removed. The contrast script ran in `/var/folders/…/opencode` (outside the
      repository) and wrote nothing; no scratch file was left in the worktree. **No test database, container,
      volume or compose project was created, so none required teardown.**
- [x] `git status --short` clean for tracked files — one untracked entry, the task directory, which is the
      intended state under the no-commit policy.
- [x] No files modified outside `OWNED_PATHS`. **No Docker or Compose command was run at any point,
      including read-only ones.**
- [x] No board edited, renamed, moved or deleted.

## Recommended next action

`INDEPENDENT_DESIGN_REVIEW` — revision 4 needs a fresh Gate D3 review. **It should be cycle 4, and it should
read `design-revision-4.md` and `design-revision-metadata-4.yaml` rather than diffing against revision 3's
substance**, because revision 3 is retained and its four defects are already marked in place. If the Manager
persists the cycle-3 report first, the reviewer can compare its text against what was applied.

---

## Learning — classified per `docs/engineering/LEARNING_POLICY.md`

- **`WORKFLOW_IMPROVEMENT` / REUSABLE / independent-review.** A ledger that annotates away a measured failure
  is **worse** than one that reports it: the annotation converts a known defect into an invisible one, and
  nothing downstream re-measures an annotation. Revision 3 wrote "now unused on these boards" about a
  4.23:1 AA FAIL and never opened a board — and the layer it claimed was unused (`Art K`) is present on all
  four. **Rule: an annotation that minimises a measured result is itself an unmeasured claim, and must be
  verified exactly as the measurement was.** The general form: a *claim about an artifact* is the same kind of
  object as a *measurement of an artifact*, and both need the artifact opened.
- **`WORKFLOW_IMPROVEMENT` / REUSABLE / independent-review.** **An AA verdict must name the surface it was
  measured on, or it does not exist.** `4.23:1` is not a property of `inkTertiary`; it is a property of
  `inkTertiary` **on `card`**. The same ink is 4.62:1 — passing — on `canvas`, the surface the board draws.
  That one missing word is the whole defect in M-R1 **and** M-R2, and it is the same omission M-N2 was
  dispatched to fix in the matrix one pass earlier. Publish the pair (foreground, background) as one value, in
  every table that carries a ratio, including the board-evidence file.
- **`WORKFLOW_IMPROVEMENT` / REUSABLE / independent-review.** **Retention has a second failure mode.** The
  known one is that byte-identical retention resurrects a disproven claim. The one found this pass is the
  converse: **a marker inserted at a cited line invalidates the citation to it.** Revision 3 cited
  `design-revision.md:70`/`:414` correctly when it wrote them, inserted markers at those very sites, and never
  revisited — so six cross-references, including two in the headers of the files it marked, pointed at
  nothing. Rule: *after* editing a file, re-resolve every citation **into** it. Prefer naming a claim over
  citing a line, so the reference survives the edit.
- **`WORKFLOW_IMPROVEMENT` / REUSABLE / independent-review.** **A "Settled by" cell must name an authority
  that actually settled the thing, and its status must be checked at the row.** Revision 3 pointed `Art S`'s
  row — the one row explicitly marked `PENDING` — at a `RESOLVED` decision about a *different* question. The
  error's direction matters more than its size: it made an open human gate look closed, which is the one
  direction a traceability matrix must never fail in. Rule: for every "Settled by" cell, resolve the id,
  read its `status`, and check the decision's own `question` covers the row's subject.
- **`CONTRADICTION` / PRODUCT_SPECIFIC / human-review.** Revision 3 asserted "now unused on these boards"
  about four Penpot boards and was wrong. That is a contradiction between a design record and the design file
  it describes, **resolved here in favour of the file** (board and build agree; the token is the failure), and
  it is recorded rather than overwritten. No governance change was made as a side effect.
- **`PROJECT_FACT` / PRODUCT-SPECIFIC / automatic.** At HEAD `77c19f1`, `ShipItPalette.inkTertiary` fails WCAG
  1.4.3 AA on `card` in dark (**4.23:1**) and passes on `canvas` (**4.62:1**); the Add Product key panel puts
  it on `card` at `add_product_page.dart:533`/`:1029`. Persisted here, in the product repository's design
  artifacts, with the reproduction script's inputs (`design_tokens.dart:91-130`) named.
- **`PROJECT_FACT` / PRODUCT-SPECIFIC / automatic.** A design artifact's `BASE_SHA` does **not** guarantee the
  decision objects it cites resolve at that commit. `9417f8bf` and `27ea6536` were filed in `064703d`, the
  child of `77c19f1`. Recorded as assumption A8 with the filing commit named, so a reviewer can reproduce the
  citations from either.
- **`AUTOMATION_OPPORTUNITY` / REUSABLE / independent-review.** Every defect in this pass is mechanically
  detectable from the live design file plus source, with no judgement: (a) a text layer whose fill equals a
  palette token whose contrast **against the rect that geometrically contains it** fails AA; (b) a matrix cell
  whose token disagrees with the call site's `copyWith(color:)`; (c) a "Settled by" id whose decision file's
  `status` or `question` does not cover the row; (d) a `file:line` citation that does not resolve. All four
  are one-pass checks over data already fetched. **Revision 3's `inkTertiary`-on-`card` annotation is exactly
  the failure (a) would have caught, on the layer the check would have named.**

KNOWLEDGE_PERSISTED:
- `design-revision-4.md` § 0, § 0.1, § 1.2, § 3.2, § 6.1, § 8 (N10), § 9.1, § 11, § 12.1, § 13 (A7, A8), § 14, § 15
- `design-revision-metadata-4.yaml` — `corrections_applied` (M-R1, M-R2, M-R3, L-R1, L-R2, L-R3, L-R4),
  `premises_corrections`, `traceability.non_requirement_gaps` (G11 closed, G13, G14 added),
  `ux_accessibility_score_reason` reason (c), `design_system_compliance_reason`,
  `provenance.review_report_read` / `decision_objects_read` / `board_edits_this_pass`
- `design-revision-3.md` — supersession header + 4 in-place pointers (substantive text untouched)
- `design-revision.md`, `report.md` — supersession headers' line numbers corrected (bodies untouched)
- `correction-report-4.md` — this report
- **All inside `OWNED_PATHS`.** Nothing outside was written, and nothing outside is claimed as persisted.
  Items above marked for independent review or human decision are **reported**, not persisted into the
  framework's knowledge — that routing is the Manager's.

## Model and reasoning effort

```yaml
ROUTING_CLASS_REQUESTED: PRECISION
MODEL_USED: opencode/space-bunny-free
REASONING_EFFORT: n/a (not exposed by this runtime)
ESCALATED_INSIDE_TASK: NO
ESCALATION_REASON: n/a
```

## Mandatory structured result

```
RESULT: DESIGN_REVISION_COMPLETE

FEATURE: Add Product rebuild — four missing SM mobile boards + layout/copy corrections (record corrections only, cycle 4)
BRIEF_ID: 52CB4098-FF87-4B78-81DA-1104269551A1
REVISION_ID: A69AB98C-A672-4D98-9DCE-0F089D55A9B5
REVISION_NUMBER: 4
BRANCH: design-correct-addproduct-mobile
BASE_SHA: 77c19f114ee691e8c434afe37b7c84494b66dc40
HEAD_SHA: 77c19f114ee691e8c434afe37b7c84494b66dc40

OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**
  - penpot page d8ac01df-6646-81d2-8008-a366c09aa9d3 :: the four boards `SM - Add Product - {Unknown host, Verified} - {Light, Dark}` (READ-ONLY this pass: 0 edits)

READ_ONLY_PATHS:
  - apps/control_plane/**                      # cited, never written
  - .decisions/**                              # b869ec24, 9417f8bf, 27ea6536 read at the canonical checkout; never written
  - docs/engineering/DESIGN_GOVERNANCE.md, WORKFLOW.md, LEARNING_POLICY.md, STRUCTURED_RESULTS.md
  - docs/engineering/dispatch/tasks/design-review-addproduct-mobile/**   # read-only; NOT written despite the dispatch's "persist path may need creating" note
  - /Users/alkebut/fvm/versions/3.44.7/**       # Flutter SDK sources, read only
  - .agents/**, .opencode/**, .claude/**, .junie/**

PROHIBITED_PATHS:
  - WORK_STATE.md, LANES.md, DECISIONS.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**
  - .decisions/**
  - any production source, test, golden baseline, Makefile or CI config

ARTIFACT_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-4.md
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-metadata-4.yaml
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/correction-report-4.md
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-3.md
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision.md
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/report.md

RISK_LEVEL: 2
RISK_RATIONALE: >
  Unchanged at 2, and this pass moved it by nothing at all: revision 4 edits no board, no layer, creates no
  shape, chooses no token, and changes no interaction, navigation, information-architecture surface or
  primary-action structure. Every one of the seven dispatched items is a Level 0 record correction. N10 is the
  only new item of substance and it is Level 1 by the routing N2 already uses — ShipItPalette is
  design-system-owned — and recording a measured failure against the token's owner does not move a level;
  choosing a replacement colour would, and this lane chose none. The two load-bearing corrections REMOVE false
  records rather than add true ones: an AA failure the ledger marks FAIL had been annotated "now unused on
  these boards" (false — `Art K` is on all four boards and in the build), and the matrix invariant 8 makes
  mandatory named the wrong foreground for the primary action's helper with no surface at all. Freezing either
  would hand implementation and QA a wrong acceptance baseline. Below 3: no Level 3 condition is met, B3
  stays filed as 27ea6536 and is not re-opened, and `Art S` stays PENDING D4 under the open gate 9417f8bf.

CHANGELOG: >
  revision 4 — correction pass 3 after the Gate D3 re-review of revision 3 (DESIGN_REVIEW_CHANGES_REQUIRED,
  0 BLOCKERS, 0 HIGH, INDEPENDENT_RISK_LEVEL 2). RECORD-ONLY: zero board edits. Seven dispatched items applied,
  seven independently re-verified before application, none rejected. M-R1 deleted the false "now unused on
  these boards" annotation that hid a live 4.23:1 AA FAIL on `Art K`, named the call site and surface in the
  ledger, added reason (c) to the a11y score and filed N10 (Level 1, design-system owner; ShipItPalette,
  exactly as N2 does for `negative`); N7's withdrawal narrowed to the TechnicalDetails lines it was about.
  M-R2 set the `Submit Sub` matrix cell to the build's inkTertiary with the surface note the `Submit` row
  carries, both surfaces' ratios, and an explicit statement that the board keeps the aspirational inkSecondary;
  new § 6.1 and G14. M-R3 replaced the RESOLVED `b869ec24` with the PENDING gate `9417f8bf` on the one row that
  is not closed, citing b869ec24 alongside for what it does settle — the layer, its string and its PENDING D4
  marker are untouched. L-R1 fixed a lesson cross-reference that pointed at a section not containing it.
  L-R2 closed G11 (the review report exists at 25f723d) and removed it from the open-gap list. L-R3 corrected
  six stale line references that this lane's own withdrawal markers had invalidated, and corrected two headers'
  claims about themselves; design-revision-metadata.yaml:15-16 was verified still correct and left alone.
  L-R4 applied as a record-only citation fix and NOT recorded as a finding. New assumptions A7 (a layer's name
  is not evidence of its surface) and A8 (an artifact's BASE_SHA may not contain the decision objects it
  cites). Revisions 1-3 retained; revision 3 gained a supersession header and four in-place pointers, and no
  retained body text was rewritten. One provenance gap reported, not closed: the cycle-3 review report does not
  exist on disk anywhere and this lane did not author it.

TRACEABILITY:
  REQUIREMENTS_COVERED: R1, R2, R3, R4, R5, R6, R7   # unchanged; no requirement moved in this pass
  REQUIREMENTS_GAPS: none
  NON_REQUIREMENT_GAPS: G1, G2, G3, G4, G5, G6, G7, G8, G9, G10, G12, G13 (new), G14 (new); G11 CLOSED (L-R2)

DESIGN_SYSTEM_COMPLIANCE: PARTIAL
UX_ACCESSIBILITY_SCORE: PARTIAL
IMPLEMENTATION_FEASIBILITY: MEDIUM

DISCOVERIES:
  - PROJECT_FACT / PRODUCT_SPECIFIC / automatic — ShipItPalette.inkTertiary fails WCAG 1.4.3 AA on `card` in
    dark (4.99:1 light / 4.23:1 dark) while passing on `canvas` (4.65 / 4.62); the Add Product key panel puts it
    on `card` at add_product_page.dart:533 and :1029, and layer `Art K` draws it on all four boards. Persisted
    in the product repository's design artifacts (N10, G13).
  - WORKFLOW_IMPROVEMENT / REUSABLE / independent-review — a ledger that annotates away a measured failure is
    worse than one that reports it: the annotation converts a known defect into an invisible one, and it was
    itself an unverified claim about the boards. Reported for independent review, not persisted here.
  - WORKFLOW_IMPROVEMENT / REUSABLE / independent-review — an AA verdict must name the surface it was measured
    on, or it does not exist. 4.23:1 is a property of inkTertiary ON card, not of inkTertiary. Reported.
  - WORKFLOW_IMPROVEMENT / REUSABLE / independent-review — retention's converse failure: a marker inserted at a
    cited line invalidates the citation to it. Six cross-references pointed at nothing after revision 3's own
    insertions. Reported.
  - WORKFLOW_IMPROVEMENT / REUSABLE / independent-review — a "Settled by" cell must name an authority that
    settled the row's actual subject, with its status checked at the row. The failure direction that matters
    is an open gate made to look closed. Reported.
  - AUTOMATION_OPPORTUNITY / REUSABLE / independent-review — all four defect classes this pass are one-pass
    mechanical checks over data already fetched: contrast of a text fill against the rect that geometrically
    contains it; matrix token vs the call site's copyWith(color:); "Settled by" id vs its decision file's
    status and question; unresolvable file:line citations. Reported.
  - PROJECT_FACT / PRODUCT_SPECIFIC / automatic — a design artifact's BASE_SHA does not guarantee the decision
    objects it cites resolve at that commit: 9417f8bf and 27ea6536 were filed in 064703d, the child of
    77c19f1. Persisted as assumption A8 with the filing commit named.
  - CONTRADICTION / PRODUCT_SPECIFIC / human-review — revision 3's record contradicted the Penpot file it
    described ("now unused on these boards"). Resolved in favour of the file; recorded, not overwritten; no
    governance change made.

KNOWLEDGE_PERSISTED:
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-4.md (§ 0, 0.1, 1.2, 3.2, 6.1, 8/N10, 9.1, 11, 12.1, 13/A7+A8, 14, 15)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-metadata-4.yaml (corrections_applied, premises_corrections, traceability, assessment reasons, provenance)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/correction-report-4.md
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-3.md (supersession header + 4 pointers only)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision.md, report.md (supersession headers' line numbers only)
  - All inside OWNED_PATHS. Nothing outside was written or claimed.

BLOCKERS: none

READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES
```
