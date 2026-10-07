# Report — Design Revision 6, `design-addproduct-keyservice` (precision correction of Revision 5)

Persisted per `aef-orchestrator` §14. Lane: `design-agent`. **The Design Agent never approves its own work.**
Nothing in this report is an approval, and no approval of any kind stands behind Revisions 1–6.

**FINDING SET ANSWERED**: `design-review-addproduct-keys-rev5/report.md` — 1 BLOCKER, 0 HIGH, 4 MEDIUM,
3 LOW. **Per-finding disposition: B-R5-1 §5, M-R5-1…M-R5-4 §6, L-R5-1…L-R5-3 §7.** All 8 **APPLIED**.

---

## 1. Provenance

| | |
|---|---|
| **Worktree** | `/private/tmp/shipit-correct-addproduct-keys` |
| **Branch** | `design-correct-addproduct-keys` |
| **`BASE_SHA`** | **`1c3f5ad2e6fe206e77277f948ada70bbebed672c`** |
| **`HEAD_SHA`** | **`1c3f5ad2e6fe206e77277f948ada70bbebed672c`** |
| Re-based from | `5436a4d` — by **`git merge --ff-only 1c3f5ad`**. Fast-forward. **Nothing rewritten.** `main` advanced by 5 commits while Revision 5 was under review |
| **`REVISION_ID`** | **`d26658219dea4955b0d2b4004a70aa4d`** |
| **`REVISION_NUMBER`** | **6** |
| **`RISK_LEVEL`** | **3** — carried, **re-affirmed on this revision's own content** |
| Committed / pushed | **NO / NO**, as instructed |
| Docker or Compose | **NONE ISSUED — not `info`, not `ps`, not `logs`, not `config`, not any mutating one.** Compose files **not read** |
| **Penpot** | **NO TOOL CALLED. NO BOARD READ, EDITED, RENAMED, MOVED, EXPORTED OR DELETED.** See § 3 |
| `876c6b97`, `27ea6536`, `9417f8bf` | **READ ONLY.** **Nothing written under `.decisions/**`** |

### Content pins — `git hash-object`, run at `1c3f5ad`

**L-R5-1's fix, both halves: this file carries the metadata's OWN hash, and every `artifacts[]` entry is a
real hash.** Revision 5's metadata said *"A FILE CANNOT CONTAIN ITS OWN HASH, so this file's own value is
printed in `report-revision-5.md`"* — **and it was not printed there.** That report read
`design-revision-metadata-5.yaml (pinned in the Manager-facing report)`, naming a document that does not exist
as an artifact. The pointer was circular and dangling, and the unpinned file was the one carrying
`risk_level`, `gates`, `requirements_gaps` and the whole changelog.

```
design-revision-6.md             2187065c0beffc3020886cc1b16027865f7ae71c
design-revision-metadata-6.yaml  5a9b5ae03dfa64f97fe7962edec60308805be889   <-- SELF-EXCLUDED, PRINTED HERE
traceability-matrix-6.md         fafcf362dc873fa2a9169448bec39711d4b7dd9f
report-revision-6.md             SELF-EXCLUDED — this file
```

**Revision 5's four superseded artifacts, pinned and byte-identical** — verified **twice**, before and after
the fast-forward:

```
fb99f9e216b10db655b673111062355e690d61fa  design-revision-5.md
bae3c019be3a28c2d9347944eacc8eca4ccecec6  design-revision-metadata-5.yaml
0778b37d567c25d60efd4a6fb2dbac316212334c  traceability-matrix-5.md
121273aee65c2e771f2cc3cf3be25f534fe09d14  report-revision-5.md
```

### The merge precondition, recorded rather than smoothed

`git merge --ff-only 1c3f5ad` **aborted** the first time:

```
error: The following untracked working tree files would be overwritten by merge:
        .../design-revision-5.md   .../design-revision-metadata-5.yaml
        .../report-revision-5.md   .../traceability-matrix-5.md
```

Revision 5's artifacts were **untracked in this worktree and committed on `main`** — the same condition
Revision 5 documented for its own predecessor. All four untracked copies were compared against `1c3f5ad`'s
blobs **before** anything was removed: **all four byte-identical.** A copy was taken **outside the
repository first**; the untracked copies were then removed; the fast-forward restored them at the same four
hashes, re-verified after. **No content was discarded.**

---

## 2. ⚠ Two pre-flight findings the Manager must act on

### 2a. ⚠ A Manager premise in this lane's dispatch is **FALSE** — declined, not adopted

The dispatch states: *"`design-revision-3.md` is **no longer an untracked file** — it exists and is committed
on `main`."*

**It is not.** Checked four ways:

```
git ls-tree --name-only main:…/design-addproduct-keyservice/ | grep -- '-3\.'   →  0 matches
git log --all --oneline --diff-filter=A -- …/design-revision-3.md              →  EMPTY (never added)
ls …/design-addproduct-keyservice/ | grep -- '-3\.'
    → design-revision-3.md   design-revision-metadata-3.yaml
      report-revision-3.md   traceability-matrix-3.md
```

**The premise is true for two OTHER lanes and false for this one.**
`git log --all --diff-filter=A -- '*design-revision-3.md'` returns exactly two commits, and both add a
**different lane's** file: `16cd497` → `design-adr-0018-amendment/design-revision-3.md`; `4e2d237` →
`design-addproduct-mobile/design-revision-3.md`.

**This lane's four Revision-3 artifacts exist only as untracked working-tree files**
(`design-revision-3.md` = 137,494 bytes, blob `13647274346f183f87ef6510ca2da9d539120a6a`).

**Consequence.** Adopting the premise would have retired a revision from the record on a false statement
about where it lives. Revision 6 records Revision 3 as **present and untracked**, does **not** mark it
committed, and registers the residue as **`G-20`**. This work item has a documented history of a lane
accepting a Manager premise that turned out false; this lane checked.

### 2b. ⚠ Eleven supersession banners are uncommitted, so the chain's readability is not on disk

`git status` at `5436a4d` showed **11 tracked files modified** in this lane's own directory — Revision 3/4/5
supersession banners plus a `discoveries.md` addition — and **8 untracked**. `git diff 5436a4d 1c3f5ad`
shows **none of the 11 is changed by the fast-forward** (`UNCHANGED-BY-MERGE`, 11/11), so the merge carried all
eleven forward **intact**. They are **still uncommitted**. **Revision 5's own supersession of Revisions 1–4 —
the thing that makes the chain readable — is not on disk.**

This is the **same `PROVENANCE_GAP` class** § 0.5 closed, found **while** closing it. It is registered
separately as **`G-20`** precisely so that closing one gap is not a reason to stop looking.
**Manager action: commit the eleven banners and the four Revision-3 artifacts, or record a decision not to.**

---

## 3. Confirmation — **no Penpot board was touched**

**Explicit, as instructed.**

- **No Penpot tool was called.** Not `penpot_execute_code`, not `penpot_export_shape`, not
  `penpot_high_level_overview`, not the Penpot MCP resources. **No board was read, listed, edited, renamed,
  moved, exported or deleted.** No board was created or cloned.
- **This lane holds no board ownership in this pass**, and every board is `PROHIBITED_PATHS`.
- The **F6 / `G-18` measurement is cited, not reproduced** — from the sibling lane's
  `design-addproduct-mobile/penpot-board-evidence.md` § 6.4 **and** the Rev-5 reviewer's own independent live
  pass. Both are named as **source of evidence, not as authority**.
- **The discipline, stated because it was the one real temptation.** F6 is the single fact a designer could
  most easily be tempted to re-verify — and re-verifying it would have required a board the lane does not own.
  An unowned second measurement would not have made the first one more true. **Cited, not reproduced.**

---

## 4. Risk level — **3**, with rationale

**`RISK_LEVEL: 3`** · **`RISK_LEVEL_AGREEMENT: YES`** (the Rev-5 reviewer independently re-derived 3 and
agreed; this lane re-affirms it on Revision 6's own content).

**The tally is unchanged and is reproduced verbatim:**

> **0 reasons IMPROVED, 2 reasons UNCHANGED (R1, R6), 4 reasons WORSE (R2, R3, R4, R5)**

**Revision 6 moves no reason's status in either direction and claims no new reason.** Its corrections are to
Revision 5's **coupling** and **self-description**, not to any of the six reasons. Claiming one for
bookkeeping would be the same error class as H10 — a count wrong in five places.

**Level 3 re-affirmed, not inherited.** `DESIGN_GOVERNANCE.md:94-99` — *"Change to core workflow, navigation
structure, or information architecture affecting multiple features or user mental models"* → approval path
`HUMAN_DECISION_REQUIRED` (product/design/architecture). Six grounds, **every one confirmed present at
`1c3f5ad`**: (1) `898b07d0` makes a `Product` visible before registration commits; (2) `RegistrationCommitState`
is a five-state client model and state 4 is currently indistinguishable from state 1 (`G-14`); (3) § R.11g
item 3 adds a resume route from the product into the credential flow — new IA; (4) first handling of key
material by SHIP IT; (5) an SSH transport seam with no precedent carrying a **half-implemented ADR
requirement** (`G-4`) on the credential path; (6) a credential-minting endpoint declaring **no
authentication**.

**The gap register grew by three entries and two of them are open governance items.** `G-18` is
newly-discovered and now owned; `G-19` and `G-20` are records that are wrong or missing and are not this
lane's to write. **Three open governance items against a design whose level is 3 is an argument *for* level 3,
not against it** — a design at level 1 does not accumulate governance debt.

**`9417f8bf` / `876c6b97` cited at their scoped reading, neither re-opened.** Both carry append-only dated
scope notes appended by the Manager at `1c3f5ad`: *"never holds key bytes"* is true only in the **storage**
dimension — at transport time SHIP IT must materialise the private half in process memory, which is what
transmitting it requires of it — and the absolute appears at **four** sites, `9417f8bf:140` being the
load-bearing uniqueness argument. **No accepted-risk count changed: exactly four were put to the owner and
exactly four are recorded.**

---

## 5. Per-finding disposition — `B-R5-1`, the BLOCKER

### `B-R5-1` — **ALL FOUR PARTS APPLIED**

> *"the desktop board-conformance gap is real, unowned, and absent from Revision 5's gap register and change
> list"* — *"the correction is small and I have made it actionable below."*

**Measured, by two independent read-only measurements, cited not reproduced:** all four desktop
`S · Add Product · …` boards carry a **`Footer` TEXT layer at 236, 862**, 1020 × 15, `align: left`, holding
*"Your decision is recorded permanently. The same piece of work then continues — nothing is restarted."* —
**the same string `_buildFooter` renders at `add_product_page.dart:383-384`**. The other two clauses **are**
satisfied: the divider (`Footer Rule`, 236, 848, 1020 × 1) and the right-aligned disclosure (`Disclose`,
1036, 862, 220 × 15, right edge 1256 = 236 + 1020).

| Part | Required | **Disposition** | Where |
|---|---|---|---|
| **1** | `G-18` in **both** § R.18.2 **and** `requirements_gaps` | **✅ APPLIED** | `design-revision-6.md` § R.18.2-h and `design-revision-metadata-6.yaml` → `requirements_gaps`, **with identical id, summary and owner**. Register row count **19 → 22 in both** |
| **2** | a § 10.1 Manager action assigning the four-board edit an owner | **✅ APPLIED** | § 10.1 **item 12** — **design-system owner**, which is exactly what `27ea6536`'s OPTION_B named in advance. **Both blocks recorded: (a) no lane owns those boards, (b) the Penpot instance binding is down** |
| **3** | amend § R.11g item 7 so *"boards are authoritative"* is not asserted against a contradicting board, and state the required board edit alongside the three code edits | **✅ APPLIED** | § R.11g-h. The rule is **scoped**: *"true of the divider and the alignment and false of the copy line."* The change list is now **FOUR edits** — the three code edits Revision 5 got right **plus** the board edit — **each with a named owner** |
| **4** | register `G-19` (or fold into `G-17`'s class) | **✅ APPLIED — as `G-19`, registered, NOT written** | § R.18.2-h and `requirements_gaps`. **The target `.decisions/27ea6536…` is Manager-owned and `PROHIBITED_PATHS`; nothing was written there and no such edit is claimed.** The exact record fix is § 8 below. **Named `G-19` rather than folded into `G-17`** because the two live in **different files with different owners** (`docs/adr/**` vs `.decisions/**`) and merging them would hide one behind the other |

**What was NOT done, deliberately.**
- **No redesign.** The footer spec, the three code edits and `design_primitives.dart:396` are **unchanged** —
  the reviewer confirmed all three are right and they were not re-derived.
- **No decision re-opened.** `27ea6536` is `RESOLVED`; its outcome, its per-platform clauses and its
  *boards-are-authoritative* instruction all stand. **The human is not asked to re-decide the footer.**
- **No board touched.** § 3.
- **Nothing in `.decisions/**` written.**

---

## 6. Per-finding disposition — `M-R5-1` … `M-R5-4`

### `M-R5-1` — § 0.4's `L8` row stated the `:925` inversion — **✅ APPLIED**

**The row is gone.** § 0.4 of Revision 6 **replaces** Revision 5's map rather than patching it. The corrected
content is carried in § 0.4 and § R.11g-i, **agreeing with the three places Revision 5's body already got it
right** — `design-revision-5.md:2414`, `design-revision-metadata-5.yaml:739-742`,
`traceability-matrix-5.md:139`:

> **`:925` is the MOBILE site** (inside `_MobileAddProduct`, class opened at `:774`), and it **does** carry a
> `note:` at **`:926-928`**, the same string as desktop's `:317-319`.

**Also carried:** Revision 4's `_buildFooter` numbers — definition `:375`, call site `:314`, copy `:383` —
were **correct and are preserved**, and this revision does not repeat the map's *"inverts …"* wording, which
was the wrong part.

### `M-R5-2` — § 0.4's `M5` row contradicted § 10.1 — **✅ APPLIED, AS A FULL SWEEP**

**The row is gone, and the sweep M-R5-2 asked for was performed** — not a two-line patch. Every row of § 0.4
was checked against the section it names. **§ 0.4.1 reports the sweep's own result:**

- **16 rows check out** — `B5`, `B6`, `H8`, `H9`, `H10`, `M3`, `M4`, `M6`, `M7`, `L5`, `L6`, `L7`, `L9`,
  `L10`, `L11`, `L12`, `L13`.
- **`L8` and `M5` were wrong** — the reviewer's two, **and the only two**.
- **One further error found and disclosed**, which the reviewer did not have: § 0.4's `L13` row claims content
  pins recorded *"per artifact"*, and **only three of four had pins** — the unpinned file was the metadata
  carrying `risk_level`, `gates`, `requirements_gaps` and the changelog. That is L-R5-1's substance seen from
  inside.

**The two false clauses, corrected where they belong:** the amendment **is** an in-place edit of
`docs/adr/0018-per-product-git-credentials.md` and **is committed and landed** (at `5436a4d`, unchanged
through `1c3f5ad`); and § 10.1's *"merge the ADR amendment"* action **is withdrawn**, replaced by **1a**
(review) and **1b** (`G-17`).

**The sweep's own limit, stated rather than implied:** the rows were checked against **Revision 5's
sections**, whose citations were verified at `5436a4d`. This lane re-verified at `1c3f5ad` only **its own**
citations (§ `V-1`) — **not** all nineteen rows' `file:line` references. § 0.4.1 says so.

### `M-R5-3` — the count is **19 findings and 5 MEDIUM**, not 18 and 4 — **✅ APPLIED**

The rev-4 report's own `RESULT:` block reads `MEDIUM: M3, M4, M5, M6, M7` — **five** — under the heading
`## M3–M7 and L5–L13`. 2 + 3 + 5 + 9 = **19**. Revision 5 enumerated the nineteen itself, three lines below
a heading that said eighteen.

**Corrected throughout every artifact this revision controls** — § 0.1, § 0.4, the metadata changelog header
(which now prints the correction **in place**, so the wrong line is visibly corrected rather than quietly
replaced), and `traceability-matrix-6.md` § 2.

**The thirteen locations that carried `18`/`4` are in Revision 5's artifacts, which this revision does not
edit** — § 0.3 of the body says why. Editing a committed superseded artifact's text is how a chain stops
being auditable. They remain the historical record of what Revision 5 said.

**And the recovered report is the SOURCE of this correction, not merely its confirmation** — its `MEDIUM:`
line is what exposes the error. That is a finding the reviewer could only make *because* M-R5-4's gap was
closed; the two findings are causally linked and that is recorded.

### `M-R5-4` — § 0.7's `PROVENANCE_GAP` is stale at the reviewed HEAD — **✅ APPLIED, RECONCILED AND CLOSED**

**The reconciliation the reviewer was asked to do was performed and recorded** — § 0.5:

```
git log --oneline --diff-filter=A -- …/design-review-addproduct-keys-rev4/report.md
  289f1d3 docs(review): ADR amendment review; keys rev5; persist the rev4 review that never landed
git merge-base --is-ancestor 289f1d3 1c3f5ad   →  0 (YES)
```

**`289f1d3` IS the commit that persisted the rev-4 report**, and it is an ancestor of this lane's base. The
gap was **true at Revision 5's base `5436a4d`** and **has not existed since `289f1d3`** — the very HEAD at
which Revision 5 was reviewed. The recovered report's `RESULT:` block was read and compared
finding-by-finding against Revision 5's correction map: **all nineteen are present, all correctly described,
all correctly corrected.** `blockers[]`'s `PROVENANCE_GAP` is **CLOSED** with the evidence recorded.

**The residue is not inside that closure.** § 2a and § 2b's uncommitted Revision 3 and uncommitted banners
are registered as **`G-20`** — because closing one provenance gap must not become a reason to stop looking,
and this one was found *while* closing the other.

---

## 7. Per-finding disposition — `L-R5-1` … `L-R5-3`

### `L-R5-1` — the pin loop is circular and § 10.2 item 10's falsifier unexecutable — **✅ APPLIED, BOTH HALVES**

1. **`report-revision-6.md` prints this metadata file's own blob hash** under its pin table —
   `5a9b5ae03dfa64f97fe7962edec60308805be889`. A report written after the metadata can hold it, which is the
   **entire reason** the metadata points at the report; in Revision 5 it did not.
2. **Every `artifacts[]` entry now carries a real `blob_hash`.** Revision 5 gave the key to **one of four**
   and its value was the pointer *string* `"RECORDED IN § 0.3 AND report-revision-5.md — see L13"`, not a
   hash — so `traceability-matrix-5.md`'s *"recorded per artifact"* was not literally true.
3. **§ 7.1's `V-2` falsifier is restated** against `provenance.content_pins.this_revision`, which is where the
   hashes actually live.

### `L-R5-2` — `5436a4d` **is** `289f1d3`'s parent — **✅ RECORDED FOR THE MANAGER'S LEDGER**

**The Rev-5 review's dispatch claimed `5436a4d` is *not* an ancestor of `289f1d3` — *"the branch was never
rebased."*** **That is false:** `git merge-base --is-ancestor 5436a4d 289f1d3` succeeds, `5436a4d` is
`289f1d3`'s **direct parent**, and `main` contains it.

**Revision 5's own re-base account is therefore *better* than the dispatch's:** the producing branch was
**fast-forwarded onto `main`**, and `main` then advanced by exactly one commit. **Nothing was rewritten and
there is no topology concern.** Recorded in § 0.6 so the next lane does not re-derive a defect that does not
exist. **No artifact correction needed; none made.**

### `L-R5-3` — board names imprecise, and the mobile citation names 2 of 4 conformant boards — **✅ APPLIED**

**Real names, with `·` and the `· Light/Dark` suffix** Revision 5 dropped everywhere:
`S · Add Product · Unknown host · Light` / `· Dark`; `S · Add Product · Verified · Light` / `· Dark`;
`BPM · Add Product · Light` / `· Dark`.

**The hyphenated forms come from `27ea6536`'s `human_correction_verbatim`** — the **owner's words**, not the
file's names. **Quoting a human verbatim and citing a board are different acts** and Revision 5 conflated them.
The verbatim is **not** corrected anywhere.

**`SM` is now named**, and Revision 5 named only `BPM` — so its spec appeared to govern two mobile boards
when it governs four. Recorded: the mobile half is reported **already satisfied on all four `SM` boards**
(`Disclose` left-aligned at `parentX` 16, no divider, no footer copy), and the sibling lane reports `SM` and
`BPM` as **two states of one mobile design**. **No mobile board edit is required and there is no substantive
conflict.** The evidence file is named as **source of the measurement, not as authority.**

---

## 8. ★ `G-19` — the EXACT record fix `.decisions/27ea6536-8a4e-4cf1-b24c-cdd3ce5bdab0.yaml` needs

**For the Manager to apply. This lane wrote nothing under `.decisions/**` and claims no such edit.**

**What is false, precisely — two places:**
1. `resolution.supersedes_design_lane_reading` states the desktop boards *"carry NO footer copy - only a
   divider and a right-aligned Show technical details text button"*, while recording that the design lane read
   a footer copy line at **(236,862)** — **a coordinate two independent reviewers have since measured**, on all
   four boards, to hold a `Footer` **TEXT** layer carrying the build's own string.
2. `follow_up_action` #3 directs that *"the design lane's coordinate-based reading of a 'Footer' layer at
   (236,862) **should be treated as a misidentification**."* **It is not a misidentification — it is the same
   string `_buildFooter` renders at `add_product_page.dart:383-384`.**
   **What the decision overruled was the lane's CONCLUSION, not its OBSERVATION.**

**Form, following the `876c6b97` precedent exactly:** an **append-only dated `SCOPE NOTE` comment**, placed at
the end of the file, with **no line above the marker altered**, because that object is the citable id for a
human answer and its `resolution` must stay byte-verifiable. Set `updated_at` to the edit date — matching
`876c6b97:164` (`updated_at: "2026-10-07T00:00:00Z"   # scope note appended; the resolution itself is
unaltered`).

**The verbatim note text is in `design-revision-6.md` § 6**, ready to paste. Summary of its content:

| It states | It asserts **unchanged** |
|---|---|
| The measured `Footer` text layer, its type, coordinates, size, alignment and exact string; that it is the same string `add_product_page.dart:383-384` renders; that the divider is at (236, **848**) and the right-aligned disclosure at (1036, 862) with right edge 1256 | **`status: RESOLVED`; `selected_option`; `deviation_from_presented_options`; `decided_at: 2026-10-06T13:05:00Z`; `decided_by`; the `rationale`'s outcome clauses; and all four `follow_up_action` owners** |
| That follow-up action #3's *"misidentification"* is false, and that the **conclusion** — not the **observation** — is what the owner reversed, and was entitled to reverse | **`human_correction_verbatim` AS THE OWNER'S WORDS — explicitly NOT corrected.** Its hyphenated board names are the owner's spelling; the file's names are `S · Add Product · Unknown host · Light` / `· Dark`. **A verbatim quote is not a file listing and must not be edited into one** |
| That this is the **same class as `G-17`** — a record denying a thing that exists; there, ADR 0018 asserted no decision object records its acceptance **in the same commit that added it**; here, a decision object calls a measured board layer a misidentification. **In both cases an authoritative record denies something real, and nothing will re-check it because it is authoritative** | **The OUTCOME in full: no footer copy on either platform; desktop = divider + right-aligned `Show technical details` text button; mobile = left-aligned button, no divider; the boards are authoritative for footer structure** |
| That **`G-18` is still open** — the boards themselves conflict with the decision on exactly one clause; removing the layer needs a design-system-owner board edit that no lane owns, blocked on the Penpot binding. **Registered as `G-18` by `design-revision-6.md`. It is an ownership gap, not a re-decision, and the human is NOT asked to re-decide the footer** | — |

**Explicitly NOT requested:** re-opening `27ea6536`; changing `status`, `selected_option`, `decided_at`,
`decided_by` or `human_correction_verbatim`; **or any human gate on the footer.** A record correction that
re-opens a resolved decision is a **different act** and is not asked for here.

---

## 9. Ownership

| | |
|---|---|
| **`OWNED_PATHS`** | `docs/engineering/dispatch/tasks/design-addproduct-keyservice/**` — **the only paths written.** **Four new files created** (`design-revision-6.md`, `design-revision-metadata-6.yaml`, `traceability-matrix-6.md`, `report-revision-6.md`) and **one existing file appended to**: **`discoveries.md`**, adding **`D-32`…`D-34`** and a *"Not persisted — Revision 6"* table. **`D-1`…`D-31` are unchanged.** **No superseded revision's body or banner was edited** |
| **`READ_ONLY_PATHS`** | `.decisions/**`; `docs/adr/**`; `docs/engineering/**` outside `OWNED_PATHS`; `AGENTS.md`; all `apps/**` and `packages/**` source |
| **`PROHIBITED_PATHS`** | `apps/**`, `packages/**`; `docker/**`, `.github/**`; `.decisions/**`, `WORK_STATE.md`, `LANES.md`; the mobile lane's directory; the ADR lane's directory; `docs/engineering/dispatch/tasks/design-review-*/**`; **every Penpot board** |
| **Not written** | `apps/**`, `packages/**`, `docker/**`, `.github/**`, `.decisions/**`, `docs/adr/**`, the mobile lane's directory, the ADR lane's directory, any review directory, **any board** |
| **Superseded artifacts edited** | **NONE.** Revision 5's four artifacts are **retained byte-identical**, committed on `main` at `16cd497` — **including no supersession-banner extension**, which is a deliberate, recorded choice (§ 10.2) |
| **Committed / pushed** | **NO / NO.** Revision 5 **is** committed underneath Revision 6 |

**Deletions: none outside `OWNED_PATHS`.** Four **untracked** Revision-5 working-tree copies were removed
**only after** being verified byte-identical to `1c3f5ad`'s blobs **and** copied outside the repository; the
fast-forward **restored them at the same four hashes**. **No tracked file was deleted, moved or renamed**, and
the eleven uncommitted banners were carried forward untouched.

---

## 10. Gates — what was and was not run

### 10.1 `NOT_RUN`

| Check | Status |
|---|---|
| **`docker` / `docker compose`, any subcommand** | **NONE ISSUED.** Not `info`, not `ps`, not `logs`, not `config`, not `down`, not `--rmi`. **This repository has ALREADY lost its QA database** to a lane running `docker compose -f docker/compose.qa.yaml down -v --rmi local`. **The rule was not tested, because testing it is the forbidden act.** Compose files **not read** |
| **Any Penpot tool** | **NONE CALLED.** No board read, listed, edited, renamed, moved, exported, created or deleted |
| `dart analyze` / `flutter analyze` / build | **NOT_RUN** |
| `dart test packages/product_registry/test` | **NOT_RUN** — no claim about `D-4`/`D-5`/`D-6` |
| `make test-integration` | **NOT_RUN** — the only sanctioned exemption; not needed |
| `T-A` … `T-L` | **NOT_RUN** — specified, not executed. `T-A`/`T-B`/`GAP-2` remain reported-passing by the implementer's report and are **not adopted as this lane's result** |
| Contrast measurement | **NOT_RUN** — figures **inherited**, not re-measured |
| ADR amendment — merge / edit / review | **NOT_RUN**, none of the three. `docs/adr/**` is `PROHIBITED_PATHS`. `G-17` stands, unedited and unclaimed |
| `.decisions/**` — write | **NOT_RUN.** Read only; `G-19`'s fix **specified**, not applied |
| Commit / push | **NOT_RUN** — as instructed |

### 10.2 What **was** verified

| # | Check | Result |
|---|---|---|
| **`V-1`** | **Every source citation this revision carries, re-read at `1c3f5ad`** | **Pass.** `add_product_page.dart` and `design_primitives.dart` **UNCHANGED** between `5436a4d` and `1c3f5ad` (`git diff --quiet`). Re-read: `_buildFooter` def `:375` / call `:314` / copy `:383-384`; desktop `note:` `:317-319`; mobile `note:` `:926-928`; `design_primitives.dart:396` paints `const ContentRule()` **unconditionally**; `:402-410` renders `Expanded(note ?? SizedBox.shrink())` beside `InlineLink`. **All resolve exactly as Revision 5 stated** |
| **`V-2`** | Content pins | **Pass.** Revision 5's four blobs verified byte-identical **before and after** the fast-forward. Revision 6's four printed, **including the metadata's own hash** |
| **`V-3`** | Pre-flight | **Pass**, with the two disclosures at § 2a and § 2b |
| **`V-4`** | The `PROVENANCE_GAP` reconciliation | **Pass** — § 0.5. `289f1d3` confirmed as the commit that added the rev-4 report and as an ancestor of `1c3f5ad` |
| **`V-5`** | § 0.4's full sweep | **Pass** — § 0.4.1: 16 rows check out, `L8` and `M5` wrong, **one further error found and disclosed** |

### 10.3 Ratings — all **carried unchanged**, and each one explained

| Rating | Value | Why it did not move |
|---|---|---|
| `design_system_compliance` | **PARTIAL** | Unchanged for the same reasons as Revisions 2, 3, 4: the boards are the sibling lane's and board compliance is **UNVERIFIED** by this lane — and this lane read no board. **What this pass adds is not a compliance improvement but a recorded NON-conformance.** `G-18` *is* a design-system compliance defect; that it was unregistered was the blocker, and that it is unregistered-but-now-registered is what `PARTIAL` means here |
| `ux_accessibility_score` | **PARTIAL** | Unchanged. Figures **inherited, not re-measured** (`inkTertiary` 4.23:1 dark **fails WCAG AA**). **Revision 6 adds no new user-facing surface**, and `G-18`'s board edit **removes** a text layer rather than adding one, so it cannot move an accessibility score. A score that moved on a bookkeeping correction would be measuring the correction pass |
| `implementation_feasibility` | **MEDIUM** | Unchanged at the aggregate: the three code edits are exactly Revision 5's three and remain **HIGH**. **One component moves and it moves the wrong way, so it is stated rather than absorbed:** the four-board edit (`G-18`) has **UNKNOWN** feasibility as an executed task, because no lane owns those boards and the Penpot binding is down. That is an **ownership and infrastructure** precondition, not a design difficulty — `27ea6536`'s own OPTION_B predicted the cost and named the owner |

### 10.4 Safe parallelism — carried unchanged

**Unaffected by every finding, safe now:** `G-11` (`D-4`/`D-5`/`D-6`, both tiers, eight columns); `G-13`
step 3a + `G-16` step 3a + `T-L` + `SC-20`, **shipping `G-16` first**; `G-14` (§ R.11.2); the
`repositoryId: productId` placeholder retirement. **None is touched by any Rev-5 finding.**

**NOT SAFE while `G-18` and `G-19` are open:** any board edit; treating § R.11g item 7's *"boards are
authoritative"* as unconditional; and **closing the work item** — the build would then be able to diverge
permanently from the authority it declares.

**`SC-01`–`SC-20` carried unchanged.** **No success criterion was added, removed or re-scoped** — `G-18`'s
board edit is a **conformance** obligation, not a new user-visible criterion, and inventing one would be a
redesign.

### 10.5 The recorded choice not to edit Revision 5's banners

**Revision 5's four artifacts were NOT edited, including no supersession-banner extension.** They are
committed on `main` at `16cd497`, and this lane is instructed **not to commit**. Editing them would dirty
them and **re-create the exact condition the dispatch warned about** — a revision 5 that is not present as a
commit — while a banner is recoverable from the chain the moment this revision lands. **Not editing them is a
deliberate, recorded choice, not an omission**, and it is recorded in the metadata's changelog so a reviewer
does not read it as a gap.

---

## 11. Discoveries

| Class | Finding | Disposition |
|---|---|---|
| **`CONTRADICTION`** | **A Manager premise in this lane's dispatch was false**: *"design-revision-3.md … exists and is committed on `main`."* It is untracked and **never added on any ref**; the premise is true for two *other* lanes. **Adopting it would have retired a revision from the record on a false statement.** | **Escalated, not resolved** — § 2a. Registered as `G-20`. **Not written to the repository's knowledge** — `CONTRADICTION` is reported per `LEARNING_POLICY.md`, and this one is the Manager's own text |
| **`CONTRADICTION`** | **A decision record denies a thing two reviewers have measured** (`27ea6536`'s *"misidentification"*), **same class as `G-17`** | **Recorded, not resolved.** `G-19`; exact record fix § 8. **Owner: Manager.** Governance-touching → escalated, not auto-persisted |
| **`PROJECT_FACT`** | **§ 0.4 — the correction map a reviewer is told to TRUST — had two wrong rows out of the two spot-checked.** A map that is wrong about two rows cannot be used as the index a reviewer is told to check | **Persisted** in this lane's own `discoveries.md` as the executable rule: **when a document tells a reviewer which table to trust, that table must be swept against its targets before the document ships** |
| **`PROJECT_FACT`** | **Closing a provenance gap can create the conditions for the next one.** `289f1d3` closed the rev-4-report gap; the *same pre-flight* that proved it closed found Revision 3 uncommitted and eleven banners uncommitted | **Persisted** as the rule: **a gap closure must record its residue separately**, which is why `G-20` exists rather than being folded into the § 0.5 closure |
| **`WORKFLOW_IMPROFITUNITY`** *(reported, not acted on)* | A Manager premise about **where an artifact lives** was false, and **checking it cost four commands.** `git log --all --diff-filter=A -- <path>` would have answered it in one | **Reported for independent review**, not persisted. This work item has already produced three false *"artifact absent"* conclusions; the dispatch warned about it and the warning was correct |
| **`AUTOMATION_OPPORTUNITY`** *(reported)* | `design-revision-metadata-5.yaml`'s self-pin loop (L-R5-1) is mechanically preventable: a metadata file that declares itself self-excluded should carry the hash in a **sibling** artifact, and the sibling should be **asserted** to contain it | **Reported for independent review.** Applied as a manual discipline here (`V-2`) |

---

## 12. Result

```
RESULT: DESIGN_REVISION_COMPLETE

FEATURE: Add Product rebuild — server-side deploy-key service, Design Revision 6
BRIEF_ID: 97484D0E-E16C-485E-BAA2-A277889C0FB6
REVISION_ID: d26658219dea4955b0d2b4004a70aa4d
REVISION_NUMBER: 6
BRANCH: design-correct-addproduct-keys
BASE_SHA: 1c3f5ad2e6fe206e77277f948ada70bbebed672c
HEAD_SHA: 1c3f5ad2e6fe206e77277f948ada70bbebed672c

OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**

READ_ONLY_PATHS:
  - .decisions/**, docs/adr/**, docs/engineering/** (outside OWNED_PATHS),
    AGENTS.md, apps/**, packages/**

PROHIBITED_PATHS:
  - apps/**, packages/**, docker/**, .github/**,
    .decisions/**, WORK_STATE.md, LANES.md,
    docs/engineering/dispatch/tasks/design-addproduct-mobile/**,
    docs/engineering/dispatch/tasks/design-adr-0018-amendment/**,
    docs/engineering/dispatch/tasks/design-review-*/**,
    EVERY Penpot board

ARTIFACT_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-6.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-metadata-6.yaml
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/traceability-matrix-6.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/report-revision-6.md

RISK_LEVEL: 3
RISK_RATIONALE: >
  Unchanged and re-affirmed, not inherited. Per DESIGN_GOVERNANCE.md:94-99, Level 3 requires
  product/design/architecture human approval, which this revision does NOT have and does not claim.
  All six grounds are confirmed present at 1c3f5ad: 898b07d0 makes a Product visible before
  registration commits; RegistrationCommitState is a five-state client model and state 4 is
  currently indistinguishable from state 1 (G-14); § R.11g item 3 adds a resume route from the
  product into the credential flow; this is the first handling of key material by SHIP IT; the SSH
  transport seam has no precedent and carries a half-implemented ADR requirement (G-4) on the
  credential path; and the credential-minting endpoint declares no authentication.
  THE TALLY IS UNCHANGED AND VERBATIM: "0 reasons IMPROVED, 2 reasons UNCHANGED (R1, R6), 4
  reasons WORSE (R2, R3, R4, R5)". Revision 6 moves no reason's status in either direction and
  claims no new reason — claiming one for bookkeeping is the same error class as H10. Three new
  open governance entries (G-18, G-19, G-20) are an argument FOR level 3, not against it: a design
  at level 1 does not accumulate governance debt.

CHANGELOG:
  - B-R5-1 part 1: G-18 registered in BOTH § R.18.2-h and requirements_gaps, identical id/summary/owner.
  - B-R5-1 part 2: § 10.1 item 12 assigns the four-board edit to the design-system owner; both
    blocks recorded (no board ownership exists; Penpot binding down). NOT a human question.
  - B-R5-1 part 3: § R.11g-h scopes the "boards are authoritative" rule (false of the copy line) and
    states FOUR edits — the three code edits plus the board edit — each with a named owner.
  - B-R5-1 part 4: G-19 registered. The target .decisions/27ea6536 is Manager-owned and PROHIBITED;
    nothing was written there. The exact append-only record fix is specified, ready to apply.
  - M-R5-1: § 0.4's L8 row, which still carried the :925 inversion, is gone; the corrected content is
    carried in § 0.4 and § R.11g-i, agreeing with Revision 5's body at :2414. Revision 4's correct
    _buildFooter numbers are preserved.
  - M-R5-2: § 0.4's M5 row is gone, and the FULL SWEEP was performed: § 0.4 replaces the map and
    every row was checked against the section it names. 16 check out; L8 and M5 were wrong; one
    further error found and disclosed (the L13 per-artifact pin claim).
  - M-R5-3: the count is 19 findings and 5 MEDIUM, corrected throughout every artifact this revision
    controls. Revision 5's thirteen occurrences are left in its committed artifacts as the historical
    record of what they said.
  - M-R5-4: § 0.7's PROVENANCE_GAP reconciled and CLOSED. 289f1d3 IS the commit that persisted the
    rev-4 report and IS an ancestor of 1c3f5ad; the 19 findings reconcile line by line. Residue
    registered separately as G-20.
  - L-R5-1: report-revision-6.md prints the metadata's OWN blob hash; every artifacts[] entry carries
    a real blob_hash; the § 10.2 item 10 falsifier is restated against content_pins.this_revision.
  - L-R5-2: recorded for the Manager's ledger. 5436a4d IS 289f1d3's direct parent, contrary to the
    Rev-5 review's dispatch. Revision 5's re-base story is BETTER than that dispatch's.
  - L-R5-3: real board names with · separators and · Light/Dark suffixes; SM named as two states of
    one mobile design already satisfying the mobile spec. No mobile board edit required.
  - § 0.4 re-derived in full rather than amended — a map wrong about two rows cannot be the index a
    reviewer is told to check.
  - G-20 registered: the chain's supersession is not on disk, and a false Manager premise was declined.
  - SC-01..SC-20 and the risk tally carried unchanged; no reason moves and no new reason is claimed.

TRACEABILITY:
  REQUIREMENTS_COVERED:
    - R-B1 provenance — CLOSED. BASE_SHA = HEAD_SHA = 1c3f5ad by fast-forward. The merge precondition,
      the 11 uncommitted banners carried forward, and the false premise declined are all recorded (§ 0.3).
    - R-B2 compensation construct — CLOSED, unchanged. § R.5.7's five obligations and both forms.
    - R-B3 state 4 renderable — UNCHANGED. § R.11.2; G-14 open and unaffected.
    - R-B4 per-tier specification — UNCHANGED. § R.9 untouched by every Rev-5 finding.
    - R-B5 ADR acceptance cited, acceptance-is-not-review — CLOSED and CONFIRMED by the Rev-5 reviewer;
      re-derived by nobody.
    - R-B6 cross-product disclosure — CLOSED, unchanged. § R.14.1 step 3a and T-L; G-16 stays first.
    - R-R1 ADR 0018 dependence — UNCHANGED. G-17 open, unedited, unclaimed (docs/adr/** PROHIBITED).
    - R-UX1 refusal leaves no residue — UNCHANGED. § R.11g item 5.
    - R-UX2 boards match code and code matches boards — ★ PARTIALLY COVERED, and this is what B-R5-1
      was about. Code side fully specified (three edits). Board side was NOT specified at all by
      Revision 5 and is now: G-18, § R.11g-h, § 10.1 item 12. The requirement is COVERED; the
      OBLIGATION is UNOWNED and BLOCKED. Coverage and completion are different claims and only the
      first is true.
  REQUIREMENTS_GAPS:
    - G-3, G-4, G-5, G-6, G-8, G-9(closed), G-10, G-11, G-12, G-13, G-14, G-15, G-16, G-17, L-6,
      ADR 0018 :103 wording — CARRIED UNCHANGED by reference to Revision 5's registers. No row
      weakened, removed or re-owned. Verified in agreement by the Rev-5 reviewer.
    - G-18 — ★ NEW (B-R5-1). The four desktop S boards carry a Footer TEXT layer at 236,862 holding the
      build's own copy string, so 27ea6536's "No footer copy" desktop clause is NOT satisfied on the
      boards that decision declares authoritative. Divider and right-aligned disclosure ARE satisfied.
      Required edit: remove that one layer from all four boards, nothing else. Owner: design-system
      owner (§ 10.1 item 12), blocked on Penpot. Not a human question.
    - G-19 — ★ NEW (B-R5-1 part 4). 27ea6536's record carries a demonstrably false factual claim in two
      places. Same class as G-17: a decision record denying a thing that exists. NOT a re-opening — the
      outcome stands untouched and only the record's factual basis is wrong. Owner: Manager. Nothing
      written; the exact fix is specified.
    - G-20 — ★ NEW (M-R5-4). Revision 3's four artifacts were never added on any ref, and eleven
      supersession banners are uncommitted. A false Manager premise was declined rather than adopted.
      Owner: Manager.
    - "the Rev-4 review report" — ★ CLOSED (M-R5-4). Recovered at 289f1d3; reconciled; residue as G-20.

DESIGN_SYSTEM_COMPLIANCE: PARTIAL
UX_ACCESSIBILITY_SCORE: PARTIAL
IMPLEMENTATION_FEASIBILITY: MEDIUM

DISCOVERIES:
  - CONTRADICTION (escalated, not resolved): the dispatch's premise that design-revision-3.md "exists
    and is committed on main" is FALSE for this lane — untracked, never added on any ref. True for two
    other lanes. Adopting it would have retired a revision from the record on a false statement.
  - CONTRADICTION (escalated, not resolved): 27ea6536's record denies a Footer TEXT layer two
    independent reviewers measured. Same class as G-17. Recorded as G-19; exact record fix specified
    for the Manager. The human is NOT asked to re-decide the footer.
  - PROJECT_FACT (persisted in this lane's discoveries.md): a correction map a document tells a
    reviewer to TRUST must be swept against its targets before the document ships — two of the two
    rows spot-checked were wrong.
  - PROJECT_FACT (persisted): closing a provenance gap can create the conditions for the next one; a
    gap closure must record its residue separately.
  - WORKFLOW_IMPROVEMENT (reported for independent review): a Manager premise about where an artifact
    lives was false, and one `git log --all --diff-filter=A -- <path>` would have caught it in advance.
  - AUTOMATION_OPPORTUNITY (reported): the metadata self-pin loop (L-R5-1) is mechanically preventable.

KNOWLEDGE_PERSISTED:
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/discoveries.md — D-32..D-34 added:
    (D-32) the trusted-correction-map rule, (D-33) close-a-gap-must-record-its-residue,
    (D-34) the false-premise check. D-1..D-31 unchanged. CONTRADICTION-class items are REPORTED, not
    persisted, per LEARNING_POLICY.md.
  - Nothing outside OWNED_PATHS. No board. No .decisions/**. No docs/adr/**. No production source.

BLOCKERS:
  - NONE in the design content. All 8 Rev-5 findings are APPLIED (B-R5-1 x4 parts; M-R5-1..4;
    L-R5-1..3).
  - UNOWNED, and registered rather than resolved — the Manager owns all three:
      * G-18 — the four-board edit has no owner and is blocked on the Penpot instance binding.
        § 10.1 item 12. THE WORK ITEM MUST NOT CLOSE BEFORE THIS HAS AN OWNER.
      * G-19 — the record fix to .decisions/27ea6536. Specified and ready to apply (§ 8). This lane
        wrote nothing there.
      * G-20 — Revision 3's artifacts and eleven supersession banners are uncommitted. § 2a, § 2b.
  - Penpot remains unreachable from every lane: penpot_execute_code fails with "No Penpot instance
    connected for user token" before the JavaScript executes.
  - This revision is NOT self-approved. READY_FOR_INDEPENDENT_DESIGN_REVIEW is a statement about
    readiness, not a verdict, and no approval of any kind stands behind Revisions 1-6.

READY_FOR_INDEPENDENT_DESIGN_REVIEW: YES
```

**What the reviewer should check hardest, in order.** (1) **`G-18` is in BOTH registers** and § 10.1 item 12
names the owner `27ea6536` itself named; (2) **the "boards are authoritative" sentence is scoped, not
asserted**; (3) **`G-19` is registered and § 6 asks to correct a record, not re-open a decision**; (4)
**§ 0.4's sweep result is true and its limit is honestly stated**; (5) **the count is 19 and 5**;
(6) **§ 0.5's reconciliation is real** — `289f1d3` is the commit that persisted the rev-4 report;
(7) **the metadata's own hash is printed in the report**; (8) **`G-20` exists**, so § 0.5's closure did not
bury a residue; and (9) **the two false Manager premises** — Revision 3's status and `5436a4d`'s topology —
were genuinely checked rather than adopted.