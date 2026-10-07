# Design Revision 6 — precision correction pass over Revision 5, closing B-R5-1

**Revision ID**: `d26658219dea4955b0d2b4004a70aa4d`
**Brief ID**: `97484D0E-E16C-485E-BAA2-A277889C0FB6` · **Brief version**: `1.1.0` (`design-brief-1.1.0.md`) —
**NOT re-issued**; no brief acceptance changes.
**Revision number**: 6 · **Status**: `DRAFT` · **Risk level**: **3** (carried from Revision 5, re-affirmed
independently at `1c3f5ad` — § 2)
**Supersedes**: `7C1E4A96-2B58-4D3F-A0C7-5E19D28B4F63` (Revision 5). Revision 5's four artifacts are
**retained byte-identical** at `fb99f9e2…` / `bae3c019…` / `0778b37d…` / `121273ae…`, **committed on `main`
at `16cd497`** and carried into this base unchanged. **Revision 6 edits no line of them** — § 0.3 says why
this lane did not extend their supersession banners.
**Worktree**: `/private/tmp/shipit-correct-addproduct-keys` · **Branch**: `design-correct-addproduct-keys`
· **Base SHA**: `1c3f5ad` · **HEAD SHA**: `1c3f5ad` · **Committed**: **NO** · **Pushed**: **NO**

> **No revision in this chain has ever been approved.** Revision 2's `DESIGN_REVIEW_APPROVED` certified
> Revision 2's content and did not carry over. Revision 3 returned `CHANGES_REQUIRED`. Revision 4 returned
> `CHANGES_REQUIRED`. Revision 5 returned `CHANGES_REQUIRED` (`REVIEWED_HEAD 289f1d3`). **Revision 6 carries
> no approval of any kind behind it**, and **its author does not approve it.**

**No Docker or Compose command was executed by this lane** — none issued, not even a read-only one. No
analyzer, build, test, contrast tool or **Penpot tool** was run. No Penpot board was read, edited, renamed,
moved or deleted; this lane holds **no board ownership** and cites the measurement rather than reproducing it
(§ R.11g-h). Every gate this lane did not run is reported `NOT_RUN` (§ 7).

---

## 0. What this pass is, and what it deliberately is not

### 0.1 The verdict it answers

Revision 5's independent review returned
`RESULT: DESIGN_REVIEW_CHANGES_REQUIRED` — **1 BLOCKER (`B-R5-1`), 0 HIGH, 4 MEDIUM
(`M-R5-1`…`M-R5-4`), 3 LOW (`L-R5-1`…`L-R5-3`)**, `TRACEABILITY_GAPS: none`. The reviewer's own summary of
the size of the work:

> *"None of these touch the design's content about the key flow. **The correction is small and I have made
> it actionable below.**"*

**This revision therefore changes no design content about the key flow, and says so rather than
manufacturing change.** What it corrects is Revision 5's **coupling** and its **self-description**: one real,
verified, previously-unowned gap that Revision 5 recorded **nowhere**, two rows of the correction map that
contradicted the artifact they mapped, a finding count that was arithmetically wrong **in thirteen places**,
and a provenance gap that was true at Revision 5's base and **false at the reviewed HEAD**.

### 0.2 What the reviewer confirmed and this lane therefore did **not** re-derive

Recorded here because a correction pass that re-litigates settled ground is itself a defect. Each was
verified by the reviewer against source, and **this lane re-read the source files it cites at this lane's own
base to confirm the citations still resolve** (§ 7, table `V-1`) — which is a citation check, not a
re-argument:

| The reviewer confirmed | This lane's position |
|---|---|
| **B5 / the ADR acceptance is real and cited accurately.** `876c6b97` is `RESOLVED`/`OPTION_A`; amendment revision 2's metadata (`ACCEPTED`, `approved_by` populated, `reviewed_by: null`, `acceptance_is_not_review: true`, `human_gate.required: false`, `blocking_items: []`) is exact; **no surviving bare "Accepted"** | **Accepted as settled.** § 0.4's `M5` row is corrected for a *different* clause of that finding (M-R5-2), not for this one |
| **Revision 5's self-downgrade to 0 IMPROVED / 2 UNCHANGED / 4 WORSE is honest**, and its withdrawal was made in the same place the tally is published | **Accepted as settled.** The tally is carried verbatim and unchanged (§ 2.1) |
| **`G-17` is real**: `876c6b97` landed in the same commit (`5436a4d`) that wrote ADR 0018's denial of its own existence | **Accepted as settled.** Carried forward unchanged; `G-19` is registered **as its sibling, not as a correction of it** (§ R.18.2) |
| **`D-3` is confirmed**: desktop `note:` at `:317-319`, mobile `note:` at `:926-928`, `_buildFooter` at `:375` — **three edits, not two** | **Accepted as settled.** Revision 5's **body** is right; only § 0.4's `L8` row still carried the inversion (M-R5-1) |
| **`design_primitives.dart:396`** paints the `ContentRule` unconditionally and `:402-410` renders `Row[Expanded(note ?? SizedBox.shrink()), InlineLink]`, so the desktop spec falls out of `note: null` for free and **mobile's is genuinely not expressible today** | **Accepted as settled.** Carried forward unchanged (§ R.11g-h) |
| **Risk level 3**, independently re-derived, agreement YES | **Re-affirmed** (§ 2) |

### 0.3 Provenance — base `1c3f5ad`, and two things this lane found about its own pre-flight

**This revision's base is `1c3f5ad`, not Revision 5's `5436a4d`.** The pre-flight was run and its results are
recorded here in full, including the part that is not a formality.

#### 0.3.1 The fast-forward, and the merge precondition it hit

Revision 5's four artifacts were **untracked in this worktree** *and* **committed on `main`** — the same
condition Revision 5 documented for its own predecessor (L13's evidence). `git merge --ff-only 1c3f5ad` was
**refused** by git: *"The following untracked working tree files would be overwritten by merge."*

Before removing anything, all four untracked copies were compared with `git hash-object` against the blobs
`1c3f5ad` carries, and **all four were byte-identical**:

```
fb99f9e216b10db655b673111062355e690d61fa  design-revision-5.md
bae3c019be3a28c2d9347944eacc8eca4ccecec6  design-revision-metadata-5.yaml
0778b37d567c25d60efd4a6fb2dbac316212334c  traceability-matrix-5.md
121273aee65c2e771f2cc3cf3be25f534fe09d14  report-revision-5.md
```

A copy was also taken **outside the repository** first. The four untracked working-tree copies were then
removed, the fast-forward proceeded, and the four files were **restored by the merge at those same four
hashes** — re-verified after the merge. **No content was discarded.** This is recorded as a move of
untracked copies, not as nothing having happened.

#### 0.3.2 Eleven tracked files were modified in the working tree and the fast-forward carried them forward

`git status` at `5436a4d` showed **11 tracked files modified** and **8 untracked** in this lane's own
directory. Every one of the 11 is a **supersession banner or a `discoveries.md` addition** written by
Revisions 3, 4 and 5 and never committed (§ 0.3.3). `git diff 5436a4d 1c3f5ad` shows **none of the 11 is
changed by the fast-forward** (`UNCHANGED-BY-MERGE`, 11/11), so `git merge --ff-only` carried all 11
modifications forward intact. **They are still uncommitted in this worktree.** This lane did not create,
revert or alter them, and **does not claim they are committed**. See § 0.3.4.

#### 0.3.3 ⚠ A Manager premise in this lane's dispatch is FALSE, and this lane will not adopt it

The dispatch states: *"`design-revision-3.md` is **no longer an untracked file** — it exists and is committed
on `main`."*

**It is not.** Checked four ways, because this work item has a documented history of an artifact being
declared present or absent on one grep:

```
$ git ls-tree --name-only main:docs/engineering/dispatch/tasks/design-addproduct-keyservice/ | grep -- '-3\.'
(0 matches — absent from main's tree)

$ git log --all --oneline --diff-filter=A -- \
    docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-3.md
(empty — NEVER ADDED on any ref)

$ ls docs/engineering/dispatch/tasks/design-addproduct-keyservice/ | grep -- '-3\.'
design-revision-3.md   design-revision-metadata-3.yaml   report-revision-3.md   traceability-matrix-3.md
```

**The premise is true for two *other* lanes and false for this one.** `git log --all --diff-filter=A --
'*design-revision-3.md'` returns exactly two commits, and both add a **different lane's** file:
`16cd497` adds `design-adr-0018-amendment/design-revision-3.md`, and `4e2d237` adds
`design-addproduct-mobile/design-revision-3.md`. **This lane's four Revision-3 artifacts exist only as
untracked working-tree files** (137,494 bytes for `design-revision-3.md`, blob
`13647274346f183f87ef6510ca2da9d539120a6a`).

**Consequence, stated because it is the consequence.** The Manager's premise, if adopted, would have
retired a **revision from the record on a false statement about where it lives**. Revision 6 therefore:
(a) records Revision 3 as **present and untracked**, not committed; (b) **does not** mark it committed; and
(c) flags it in § 7 as a live provenance condition this lane cannot discharge, because committing it is not
this lane's to do (`COMMITTED: NO`, § 0.3.4).

**⚠ Same class, one step further: the eleven uncommitted supersession banners of § 0.3.2 mean Revision 5's
own supersession of Revisions 1–4 — the thing that makes the chain readable — is itself not on disk.** This
is the same `PROVENANCE_GAP` class Revision 5 disclosed and that `289f1d3` then partly cured for the rev-4
report (§ 0.5). It is registered as **`G-20`**.

#### 0.3.4 This lane's own commit status, stated without ambiguity

| | |
|---|---|
| Revision 5's four artifacts | **COMMITTED** on `main` at `16cd497`, carried into `1c3f5ad` unchanged |
| The 11 modified supersession banners (§ 0.3.2) | **UNCOMMITTED** in this worktree. Carried forward by the fast-forward. Not this lane's to commit |
| This lane's four Revision-6 artifacts | **UNCOMMITTED** in this worktree, as instructed. **Revision 5 is committed underneath them** |
| `.decisions/**` | **NOT TOUCHED.** `G-19`'s target is Manager-owned and `PROHIBITED_PATHS`; the exact record fix is in § 6 and in `report-revision-6.md` |

### 0.4 Correction map — the Rev-5 review, **19 findings and 5 MEDIUM**, every row swept

**This is Revision 6's correction map, and it replaces Revision 5's § 0.4 rather than amending it.** Revision
5's § 0.4 was the map § 10.2 of that revision told reviewers to **trust**, and the reviewer found **two of
the rows it spot-checked were both wrong** (M-R5-1, M-R5-2). It is therefore **re-derived in full** here and
**every row was swept against the section it names**, which is the sweep M-R5-2 asked for and which
Revision 5 did not perform. § 0.4.1 records what the sweep found.

**The count is 19, and it is now visible from the artifact's own arithmetic** (M-R5-3): the Rev-4 review's
`RESULT:` block reads `MEDIUM: M3, M4, M5, M6, M7` — **five**, under the heading `## M3–M7 and L5–L13`.
2 + 3 + 5 + 9 = **19**.

| # | Finding | Class | Where this revision corrects it | Swept? |
|---|---|---|---|---|
| **B-R5-1** | the desktop board-conformance gap is real, unowned, and **absent from Revision 5's gap register and change list** | **BLOCKER** | **`G-18` in § R.18.2-h and in `requirements_gaps`** (part 1) · **§ R.11g-h**, with § R.11g item 7 amended so *"the boards are authoritative"* is not asserted against a board that contradicts the spec, and the **required four-board edit stated alongside the three code edits** (part 3) · **§ 10.1 item 12**, assigning the four-board edit an owner (part 2) · **`G-19`** registered, same class as `G-17`, target `.decisions/27ea6536…` (part 4) · § R.11g-i carries the measured evidence and the exact board names | ✅ |
| **M-R5-1** | § 0.4's `L8` row states the `:925` inversion Revision 5 corrected in the body | MEDIUM | **§ 0.4's `L8` row is gone.** Its corrected content is carried in this table and in § R.11g-h, where it agrees with Revision 5's body at `design-revision-5.md:2414`, with `design-revision-metadata-5.yaml:739-742` and with `traceability-matrix-5.md:139`. `:925` is the **mobile** site and it **does** carry a `note:` at `:926-928`; Revision 4's `_buildFooter` definition/call numbers (`:375` / `:314`) were **correct and are preserved** | ✅ |
| **M-R5-2** | § 0.4's `M5` row contradicts § 10.1 and the metadata | MEDIUM | **§ 0.4's `M5` row is gone.** The two false clauses are corrected where they belong: the amendment **is** an in-place edit of `docs/adr/0018-per-product-git-credentials.md` and **is committed and landed** (at `5436a4d`, and unchanged through `1c3f5ad`), and § 10.1's *"merge the ADR amendment"* action **is withdrawn**, replaced by **1a** (the review) and **1b** (`G-17`) | ✅ |
| **M-R5-3** | the finding set is counted **19 findings and 5 MEDIUM**, not 18 and 4 | MEDIUM | **§ 0.4's heading**, `traceability-matrix-6.md`, and every count in § 0.1 and § 7. Revision 5's own `18`/`4` occurrences are recorded and **left byte-identical in Revision 5** (§ 0.5) rather than edited, because editing a committed superseded artifact's text is how a chain stops being auditable | ✅ |
| **M-R5-4** | § 0.7 and the `PROVENANCE_GAP` blocker are **stale at the reviewed HEAD** | MEDIUM | **§ 0.5** — the reconciliation is **performed and recorded**, not deferred; `blockers[0]` is **downgraded to CLOSED** in `design-revision-metadata-6.yaml`, with the surviving residue registered separately as **`G-20`** | ✅ |
| **L-R5-1** | the metadata's own pin is a **circular, dangling** pointer, and § 10.2 item 10's falsifier is unexecutable | LOW | **`report-revision-6.md` prints this file's own blob hash** under its pin table (a file written after the metadata can hold it — the whole reason the metadata points there); **all four `artifacts[]` entries carry a real `blob_hash`**; § 7's `V-2` falsifier is restated against `provenance.content_pins.this_revision` | ✅ |
| **L-R5-2** | provenance observation: `5436a4d` **is** `289f1d3`'s parent | LOW | **§ 0.6** — recorded as a ledger fact for the Manager. **No artifact correction needed**; Revision 5's re-base story is *better* than the dispatch said | ✅ |
| **L-R5-3** | board names in the consumption contract are imprecise, and the mobile citation names 2 of 4 conformant boards | LOW | **§ R.11g-h** cites the real names with `·` separators and `· Light/Dark` suffixes, and states that **`SM` and `BPM` are two states of one mobile design** whose spec is **already satisfied** on all four `SM` boards — naming the sibling lane's evidence file as the **source of the measurement, not as authority** | ✅ |

### 0.4.1 What the full § 0.4 sweep found — reported as the sweep's own result

M-R5-2's fix is *"sweep **all** rows of § 0.4 against the sections they name, not just the two I checked."*
**That sweep was performed. Its result, stated plainly:**

- **`B5`, `B6`, `H8`, `H9`, `H10`, `M3`, `M4`, `M6`, `M7`, `L5`, `L6`, `L7`, `L9`, `L10`, `L11`, `L12`,
  `L13` — all sixteen rows check out** against the sections they name, at Revision 5's own base. Their named
  targets carry the content the row claims.
- **`L8` and `M5` were wrong** — the reviewer's two, and the only two. **`18`/`4 MEDIUM` was wrong in thirteen
  locations across four artifacts** (M-R5-3) and is **not itself a § 0.4 row error**; it is a count error and is
  corrected as one.
- **One additional error the reviewer did not find, found by this sweep and disclosed here: § 0.4's `L13`
  row claims content pins were recorded "**per artifact**" in § 0.3, and only three of the four had pins.**
  `design-revision-metadata-5.yaml` — the file that carries `risk_level`, `gates`, `requirements_gaps` and the
  whole changelog — was the unpinned one. This is L-R5-1's substance, confirmed against § 0.3 from the
  inside. Corrected here.

**This sweep's own limit, stated rather than implied.** The rows were checked **against the sections they
name in Revision 5**, whose citations were verified at `5436a4d`. This lane re-verified at `1c3f5ad` only the
citations its own corrected text carries (§ 7, `V-1`) — **not** all nineteen rows' file:line references. § 0.3's
citation index was inherited, not re-derived.

### 0.5 § 0.7's `PROVENANCE_GAP` is stale at this base — **reconciled and closed** (M-R5-4)

**What Revision 5 said**, and it was **true at `5436a4d`**: the Rev-4 review report *does not exist in any
worktree, in the canonical repository, or in any commit reachable from any ref*; `289f1d3` did not exist.

**What is true at `289f1d3`, at which Revision 5 was reviewed, and at `1c3f5ad`, which is this lane's base:**

```
$ git log --oneline --diff-filter=A -- docs/engineering/dispatch/tasks/design-review-addproduct-keys-rev4/report.md
289f1d3 docs(review): ADR amendment review; keys rev5; persist the rev4 review that never landed

$ git log -1 --format=%s 289f1d3
docs(review): ADR amendment review; keys rev5; persist the rev4 review that never landed

$ git merge-base --is-ancestor 289f1d3 1c3f5ad   →  0 (YES, ancestor)
```

**`289f1d3` is the commit that persisted the Rev-4 review report**, and the report **exists** at this base.
The gap Revision 5 disclosed has therefore **no longer existed since `289f1d3`** — the reviewed HEAD itself.

**The reconciliation, performed and recorded (M-R5-4's fix).** The recovered report was read and its
`RESULT:` block compared against Revision 5's § 0.4 finding-by-finding:

```
$ sed -n '6,18p' docs/engineering/dispatch/tasks/design-review-addproduct-keys-rev4/report.md
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
REVIEWED_HEAD: 361256c8948b00da7f0609a4f29cf075eef26ca2
BLOCKERS: B5, B6
HIGH: H8, H9, H10
MEDIUM: M3, M4, M5, M6, M7
LOW: L5 … L13
```

**All nineteen findings are present in Revision 5's correction map, all correctly described, and all
correctly corrected.** Independently: the reviewer of Revision 5 reached the same conclusion
(*"**B5, B6, H8, H9, H10, M3, M4, M5, M6, M7, L5, L6, L7, L8, L9, L10, L11, L12, L13 are all present, all
correctly described, and all correctly corrected**"*), and this lane agrees and adds that the report's own
`MEDIUM:` line is what exposes the **19 / 5** count error (M-R5-3) — **so the recovered report is the source
of the correction, not merely its confirmation.**

**Closure.** `design-revision-metadata-6.yaml` → `blockers[]` no longer carries an open `PROVENANCE_GAP`. It
is recorded as **CLOSED**, with the reconciliation above as its evidence. **The residue is not hidden inside
that closure** — § 0.3.3's uncommitted Revision 3 and § 0.3.2's uncommitted banners are registered separately
as **`G-20`**, because closing one provenance gap must not become a reason to stop looking.

### 0.6 L-R5-2, recorded for the Manager's ledger — no artifact correction needed

The dispatch for Revision 5's review stated: *"`5436a4d` is **not** an ancestor of `289f1d3` — the branch was
never rebased."* **That is false.** Verified at this base:

```
$ git merge-base --is-ancestor 5436a4d 289f1d3   →  0 (YES)
$ git log --oneline 289f1d3 -1 … parent            →  5436a4d is the DIRECT PARENT of 289f1d3
$ git branch --contains 5436a4d                    →  main (among others)
```

Revision 5's own § 0.3 / § 10.1 re-base account is therefore **better than the dispatch's**: the producing
branch was **fast-forwarded onto `main`**, and `main` then advanced by exactly one commit (`289f1d3`)
afterward. Nothing was rewritten and there is no topology concern. **Recorded so the next lane does not
re-derive a defect that does not exist.** Revision 5's § 0.5/§ 0.6 text needed no change and none was made.

---

## R.1 — Incorporated from Revision 5, unchanged, and where to find it

**Revision 6 is a precision correction pass. It does not restate Revision 5's design.** The following
sections of `design-revision-5.md` are **incorporated verbatim by reference** and are **not** reproduced here.
Reproducing them would create a second copy that can drift, which is a defect, not a completeness.

| Revision 5 § | Content | Status at Revision 6 |
|---|---|---|
| § 0.2 | the ADR acceptance, with its two citations and *acceptance is not review* | **Incorporated unchanged.** Confirmed accurate by the Rev-5 reviewer |
| § 0.3 | provenance and the 22-row citation index | **Incorporated unchanged.** § 0.3 above is Revision 6's own provenance; it does not replace it |
| § R.1 | the at-rest model — CLOSED, incl. R.1.7 the composition boundary | **Incorporated unchanged** |
| § R.2, § R.2.4 | what the existing domain constrains; the substrate as a runtime dependency | **Incorporated unchanged** |
| § R.3, incl. § R.3.2's twelve-rows-across-six-files change list | `referenceName` leaves `RepositoryCredentialView` | **Incorporated unchanged** |
| § R.4 | the four-option substrate set — WITHDRAWN | **Incorporated unchanged** |
| § R.5, incl. **§ R.5.7's FIVE obligations and BOTH forms** | fail-closed, the mint sequence, the refusal, the compensation construct | **Incorporated unchanged** |
| § R.6, § R.6.1–R.6.3 | two-sided revocation, and what it depends on | **Incorporated unchanged** |
| § R.7, § R.7.1 | transport exposure and the threat model's A3 row | **Incorporated unchanged** |
| § R.8, incl. § R.8.4's blast-radius accounting and § R.8.5's two falsified comments | the store invariant and what rests on it | **Incorporated unchanged** |
| **§ R.9** | `D-4`/`D-5`/`D-6` per tier, the eight-column set, `T-A`…`T-L`, the store contract doc | **Incorporated unchanged.** Untouched by every Rev-5 finding |
| § R.10, incl. § R.10.2's `N-1`–`N-9` | the key flow, the state machine, `D-3` | **Incorporated unchanged** |
| § R.11, § R.11.1, § R.11.2 | the five client states and the selection rule | **Incorporated unchanged** |
| § R.12–§ R.15 | the read path, *check access*, the three endpoints, exposure | **Incorporated unchanged** |
| § R.16, § R.17, § R.17.1 | the reuse table; ADR 0018 and what is superseded | **Incorporated unchanged** |
| § R.18.1 | gaps this revision closes | **Incorporated unchanged** |
| § 8 | success criteria `SC-01`–`SC-20` | **Incorporated unchanged.** **No `SC` is added, removed or re-scoped by Revision 6** — a correction pass that changed success criteria would be a redesign |
| § 9.2 | the three ratings and the per-component feasibility table | **Incorporated unchanged** |
| § 10.2 | what a reviewer should check hardest | **Carried with § 10.2-h below**, which restates items 10 and 12 (L-R5-1) and adds the new items this pass creates |

**Why incorporation, and why it is honest.** Revision 5 is **3372 lines** and **committed**, so it is a
stable referent; a reviewer can diff § R.11g-h against `design-revision-5.md:2388-2393` with
`git diff`. The sibling lane took exactly this shape for its own Revision 6 (745-line Revision 5 → 389-line
Revision 6), so this is the established convention in this work item and not an invention. **What Revision 6
*does* restate in full is every sentence it changes** — § R.11g-h, § R.18.2-h, § 10.1 item 12, § 0.4, § 0.5,
§ 2. Nothing normative is left implicit.

---

## 2 — Risk level: **3**, carried and re-affirmed

### 2.1 The tally is unchanged, and is reproduced verbatim

Revision 5's tally sentence is carried **character for character**, and remains the only tally in this
artifact set:

> **0 reasons IMPROVED, 2 reasons UNCHANGED (R1, R6), 4 reasons WORSE (R2, R3, R4, R5)**

**Revision 6 does not move any reason's status, in either direction.** Its corrections are to Revision 5's
coupling and self-description, not to any of the six reasons. **This pass therefore has no effect on the risk
level, and no new reason is claimed** — claiming one would be claiming a risk reason for bookkeeping, which is
the same error class as H10 (a count wrong in five places).

### 2.2 Level 3 re-affirmed on Revision 6's own content

Revision 6 introduces **no** new workflow, navigation or IA. But an unchanged level is not a carried label;
it is re-derived, and the ground is stated because the level is what gates this revision's approval:

1. `898b07d0` makes a `Product` visible **before** registration commits and turns registration into a commit —
   what a `Product` *is* changes across the Products page, product detail and Add Product.
2. `RegistrationCommitState` is a **five-state client model**; § R.11.1 state 4 changes what product detail
   asserts and is currently indistinguishable from state 1 (`G-14`).
3. § R.11g item 3 adds a **resume route from the product into the credential flow** — new IA, and without it
   `898b07d0`'s accepted consequence is a dead end.
4. First handling of key material by SHIP IT, irreversible from SHIP IT's side.
5. An SSH transport seam with **no precedent**, carrying an ADR requirement that is **half-implemented**
   (`G-4`), on the credential path.
6. A credential-minting endpoint on a control plane declaring **no authentication**.

**Every one of the six is present at `1c3f5ad`.** Level 3 therefore requires **product/design/architecture
human approval** at Gate D4 (`DESIGN_GOVERNANCE.md:99`), and this revision **does not** have it.

### 2.3 The gap register grew by three entries, and two of them are open governance items

`G-18`, `G-19`, `G-20` are new and open (§ R.18.2-h). `G-18` is **newly-discovered and now owned**; `G-19`
and `G-20` are **records that are wrong or missing and are not this lane's to write**. **Three open
governance items against a design whose level is 3 is itself an argument for level 3, not against it** — a
design at level 1 does not accumulate governance debt.

---

## R.11g — the consumption contract for `design-addproduct-mobile`, amended

### R.11g-h ★ AMENDED — item 7, and why the amendment was necessary (B-R5-1 part 3)

**The defect.** Revision 5's § R.11g item 7 states the footer spec, rules that *"the boards are authoritative
over both lanes' readings"*, specifies **three code edits**, and stops. It records **no** board-conformance
requirement, **no** gap-register entry, and **no** action for the four-board edit. The consequence the
reviewer identified: applying *"the boards are authoritative"* to a board that carries footer copy, against a
spec quoted two paragraphs earlier that says **no footer copy**, **moves the build away from the
authoritative artifact.**

**The measured fact, cited and not reproduced.** Two **independent** read-only measurements — the sibling
mobile lane's `penpot-board-evidence.md` § 6.4, and the Rev-5 reviewer's own live Penpot pass (§ 2.3 of its
report, which it states it performed *"rather than adopt the sibling lane's measurement"*) — report the same
result on all four desktop `S` boards:

| Layer | type | rel x, y | w × h | Content |
|---|---|---|---|---|
| `Footer Rule` | rectangle | 236, 848 | 1020 × 1 | the divider |
| **`Footer`** | **text** | **236, 862** | **1020 × 15** | **`align: left`** — *"Your decision is recorded permanently. The same piece of work then continues — nothing is restarted."* |
| `Disclose` | text | 1036, 862 | 220 × 15 | `Show technical details ▸` — right edge 1256 = 236 + 1020 |

**Clause by clause against `27ea6536`'s normative `rationale`:**

| `27ea6536` desktop clause | Measured | Verdict |
|---|---|---|
| a divider | `Footer Rule`, 236, 848, 1020 × 1, **all four** | **SATISFIED** |
| a **right-aligned** `Show technical details` text button | `Disclose` right edge 1256 = the content column's right edge | **SATISFIED** |
| **No footer copy** | a `Footer` **text** layer at 236, 862 on **all four**, carrying the exact string `add_product_page.dart:383-384` renders | **NOT SATISFIED** |

**This lane did not read, edit, rename, move or delete any board, and makes no claim to have done so.** It
holds **no board ownership** (§ 0). The measurement is cited, not re-attempted — reproducing a Penpot
measurement is not in this lane's authority, and an unowned second measurement would not have made the first
one more true.

**The three amendments to item 7.**

1. **The board names are corrected (L-R5-3).** The consumption contract cites
   `S · Add Product · Unknown host · Light` / `· Dark`,
   `S · Add Product · Verified · Light` / `· Dark` and `BPM · Add Product · Light` / `· Dark` — the real
   names, with the `·` separator and the `· Light/Dark` suffix that Revision 5 dropped everywhere. The
   hyphenated forms Revision 5 used come from `27ea6536`'s `human_correction_verbatim`, **which is the
   human's quoted words, not the file's names**; quoting a human verbatim and citing a board are different
   acts and were conflated.
2. **`SM` is named (L-R5-3).** The mobile half of the same spec is reported **already satisfied on all four
   `SM` boards** — `Disclose` left-aligned at `parentX` 16, no divider, no footer copy — and the sibling lane
   reports `SM` and `BPM` as **two states of one mobile design**. Revision 5 named only `BPM`, so its spec
   appeared to govern two mobile boards when it governs four. **There is no substantive conflict and no mobile
   board edit is required**: the mobile spec is met. **Source of the measurement: the sibling lane's
   `penpot-board-evidence.md` — named as evidence, not as authority.**
3. **★ The "boards are authoritative" rule is scoped, not asserted (B-R5-1 part 3).** The rule as Revision 5
   wrote it is unsound here, because the board **contradicts the spec the same item states**. The corrected
   rule:

   > **The boards are authoritative for the footer, subject to one named exception.** For the divider and the
   > right-aligned `Show technical details` text button, the boards are authoritative over both lanes'
   > readings and `27ea6536`'s specification matches them. **For the desktop footer's copy line the boards are
   > NOT currently conformant**: all four `S · Add Product · …` boards carry a `Footer` text layer at 236, 862
   > holding the build's own copy string, which `27ea6536`'s *"No footer copy"* clause forbids. **The
   > specification governs; the boards require the edit named below (`G-18`, § 10.1 item 12).** Until that edit
   > lands, *"the boards are authoritative"* is **true of the divider and the alignment and false of the
   > copy line**, and this item must not be read as authorising the copy.

**The change list for item 7 is now FOUR edits, not three** — the three code edits Revision 5 got right,
plus the board edit that closes the divergence:

| # | Edit | Where | Owner |
|---|---|---|---|
| 1 | delete `_buildFooter` (definition `:375`, block `:375-389`; call site `:314`; copy `:383-384`) | `apps/control_plane/lib/features/products/add_product_page.dart` | implementer (`27ea6536`'s own follow-up) |
| 2 | `note: null` at the **desktop** `TechnicalDetails` | **`:317-319`** | implementer |
| 3 | `note: null` at the **mobile** `TechnicalDetails` — **it exists** | **`:926-928`** | implementer |
| **4** | **★ remove the `Footer` text layer at rel 236, 862 on all four desktop `S · Add Product · …` boards**, leaving the `Footer Rule` divider and the right-aligned `Disclose` | **four Penpot boards** | **design-system owner** — § 10.1 item 12. **No current lane owns these boards** |

**Why edit 4 is required rather than optional, stated so it cannot be argued away later.** `27ea6536`'s
OPTION_B predicted this cost **in its own words**: *"Requires `note: null` at `add_product_page.dart:317`
**and editing the four existing desktop boards, which no current lane owns** — so it needs a
design-system-owner board edit."* The human chose the copy-removal outcome. **The build can reach the
specification; the boards cannot reach it without an edit that nobody is currently authorised to make.**
That is a gap in ownership, not a gap in the design — which is exactly why it is registered rather than
described as "out of scope".

**This lane's own part is finished.** It specified the edit, named its owner, and registered the gap. It
cannot make the edit: the four boards are `PROHIBITED_PATHS`, and this lane holds no board ownership.

### R.11g-i ★ The three corrected `L8` numbers, restated where a blocked lane can consume them (M-R5-1)

Revision 5's **body** is right and this revision leaves it in force. It is restated here because Revision 5's
**§ 0.4 map** — the artifact a reader uses to check — carried the inversion, and because the sibling lane is
**blocked on Penpot and cannot ask**:

- **`:925` is the MOBILE site** (inside `_MobileAddProduct`, class opened at `:774`), and it **does** carry a
  `note:` at **`:926-928`**, with the same string as desktop's `:317-319`. The Rev-4 review's attribution of
  `:925` to the desktop site was **inverted**, Revision 5 said so at `:2414`, and this revision carries that
  correction forward. **The substance of `D-3` survived; the review's wording did not.**
- **Revision 4's `_buildFooter` numbers were CORRECT and are preserved**: definition `:375`, call site
  `:314`, copy `:383`. This revision does not repeat Revision 4's *"inverts …"* wording, which was wrong.
- **Therefore "no footer copy" is three code edits, not two**, and with `G-18` it is **four edits of any kind**.

---

## R.18.2-h — the gap register, additions only

Revision 5's § R.18.2 table is **incorporated unchanged**, including `G-3`…`G-17` and the two entries it
records as out of scope. **Three entries are added. The table's row count goes from 19 to 22.**

### `G-18` — ★ NEW (B-R5-1) — the four desktop `S` boards do not satisfy `27ea6536`'s desktop clause

| | |
|---|---|
| **Gap** | **The four desktop `S · Add Product · …` boards carry a `Footer` text layer at 236, 862 holding the build's own footer copy string, so `27ea6536`'s desktop clause *"No footer copy"* is **NOT satisfied** on the boards that same decision declares authoritative.** |
| **Measured** | `Footer Rule` rectangle 236, 848, 1020 × 1 — the divider, **SATISFIED**; `Disclose` text 1036, 862, 220 × 15, right edge 1256 = 236 + 1020 — the right-aligned button, **SATISFIED**; `Footer` **text** 236, 862, 1020 × 15, `align: left`, carrying *"Your decision is recorded permanently. The same piece of work then continues — nothing is restarted."* — **NOT SATISFIED**. **All four boards identical in the footer band.** |
| **Why it is a gap and not an observation** | `27ea6536`'s outcome is settled and unimpeachable: no footer copy on either platform. **The gap is that satisfying it requires editing four boards that no current lane owns** — `27ea6536`'s own OPTION_B said so in advance. Until an owner exists, the work item would close with the build and its declared authority **permanently divergent**. |
| **Not a re-opening** | **`27ea6536` is `RESOLVED` and is not re-opened here.** Its outcome, its per-platform clauses and its `boards are authoritative` instruction all stand. **This entry records an unowned cost the decision's outcome creates — nothing more.** The human is **not** asked to re-decide the footer. |
| **Owner** | **Design-system owner** — § 10.1 item 12. **Blocked on the Penpot instance binding** that already blocks the sibling lane (`penpot_execute_code`: *"No Penpot instance connected for user token"*). |
| **Not mine** | This lane specifies the edit and registers the gap. It has **no board ownership** and read no board. |

### `G-19` — ★ NEW (B-R5-1 part 4) — `27ea6536`'s record carries a **demonstrably false factual claim**

| | |
|---|---|
| **Gap** | **`.decisions/27ea6536-8a4e-4cf1-b24c-cdd3ce5bdab0.yaml`'s own record asserts a falsehood about the evidence it rests on.** Two places: (a) `resolution.supersedes_design_lane_reading` states the desktop boards carry *"NO footer copy"*, while recording that the design lane *"recorded that the desktop state boards carry a footer copy line at (236,862)"* — a coordinate reading now **measured twice, independently, to exist at exactly that coordinate**; (b) its third `follow_up_action` directs that *"the design lane's coordinate-based reading of a 'Footer' layer at (236,862) **should be treated as a misidentification**."* **It is not a misidentification — it is the same string `_buildFooter` renders at `add_product_page.dart:383-384`.** What the decision overrules is the lane's **conclusion**, not its **observation**. |
| **Class** | **The same class as `G-17`**: a decision record **denying a thing that exists**. `G-17` is ADR 0018 asserting no decision object records its acceptance, in the same commit that added the object. `G-19` is a decision object asserting a board layer is a misidentification, on a coordinate two reviewers have since measured. **Neither is a mis-reading; both are records that will not be re-checked because they are authoritative.** |
| **What is NOT in question** | **The outcome stands untouched.** No footer copy on either platform; per-platform alignment; boards authoritative. `27ea6536` is **not re-opened**, its `status: RESOLVED` stands, `selected_option` stands, `decided_at` stands, and **no human is asked to re-decide anything.** **Only the record's factual basis is wrong.** |
| **Owner** | **ADR/decision owner — the Manager.** `.decisions/**` is `PROHIBITED_PATHS` for this lane. **I did not write it and make no claim of having done so.** The exact record fix is specified in § 6 and repeated in `report-revision-6.md`. |
| **Class note** | Named `G-19` rather than folded into `G-17`, because the two live in **different files** with **different owners** (`docs/adr/**` vs `.decisions/**`) and merging them would hide one of them behind the other. |

### `G-20` — ★ NEW (M-R5-4) — this lane's own supersession chain is not on disk

| | |
|---|---|
| **Gap** | **Revision 5's supersession of Revisions 1–4 — and Revision 3's own artifacts — exist only as uncommitted working-tree files.** § 0.3.2: **11 tracked files** carry Revision 3/4/5 supersession banners and `discoveries.md` additions, **modified and uncommitted**. § 0.3.3: the four **Revision-3 artifacts** were **never added on any ref**; `git log --all --diff-filter=A` returns nothing for them. |
| **Why it is a gap** | It is the **same `PROVENANCE_GAP` class § 0.5 closed** — and it was found *while* closing that one. The chain's readability depends on those banners being on disk, and they are not. It is recorded **here** rather than inside the § 0.5 closure precisely so that closing one gap does not become a reason to stop looking. |
| **Not this lane's to fix** | Committing them is the Manager's call and this lane is instructed `COMMITTED: NO`. **This lane made no commit and pushed nothing.** |
| **Owner** | **Manager** — commit the eleven modified banners and the four Revision-3 artifacts, or record a decision not to. |

**`G-20` also carries a second, smaller item, recorded rather than split:** `27ea6536`'s
`human_correction_verbatim` is quoted in § R.11g-h alongside the real board names, and the two differ. That is
**correct practice** — a human's quoted words are not a file's names — but a reader who has only one of them
will be misled by whichever they have. **One sentence in the record that would prevent it.**

---

## 10.1-h — ★ NEW Manager action 12, assigning the four-board edit (B-R5-1 part 2)

**Added to § 10.1's open list. All § 10.1 items 1–11 stand as Revision 5 left them**, including the withdrawn
table and actions 1a/1b.

> **12. `G-18` — assign an owner for the four-board edit, and clear the Penpot instance binding.**
>    The four desktop `S · Add Product · …` boards carry a `Footer` **text** layer at 236, 862 holding the
>    build's own copy string, so `27ea6536`'s *"No footer copy"* desktop clause is **not satisfied** on the
>    boards that decision declares authoritative (§ R.11g-h, `G-18`).
>    **The required edit is: remove that layer from all four boards, leaving the `Footer Rule` divider at 236,
>    848 and the right-aligned `Disclose` at 1036, 862. Nothing else on those boards changes.**
>    **Owner: the design-system owner**, which is what `27ea6536`'s OPTION_B named in advance (*"it needs a
>    design-system-owner board edit"*).
>    **Two things block it, and both are Manager-owned.** (a) **No lane currently owns those boards.** This
>    design lane has `PROHIBITED_PATHS` on every board and holds no board ownership; the mobile lane has the
>    same prohibition. **(b) The Penpot instance binding is down** — `penpot_execute_code` fails with *"No
>    Penpot instance connected for user token"* on every instance-bound call, **before the JavaScript
>    executes**, so no board edit is possible from any lane until it is cleared.
>    **This is an ownership grant plus an infrastructure fix, not a design question.** **`27ea6536` is not
>    re-opened and the human is not asked to re-decide the footer** — the outcome is settled; what is missing is
>    an owner for a cost that outcome creates.
>    **Do not close the work item before this has an owner.** § 10.1 item 6 already notifies the sibling of
>    item 7's corrected line numbers; that notification must **not** be read as clearance for the build to
>    diverge from its declared authority. (`G-19` is separate and is § 6.)

---

## 6 — ★ `G-19`: the exact record fix `.decisions/27ea6536-8a4e-4cf1-b24c-cdd3ce5bdab0.yaml` needs

**For the Manager to apply. This lane did not write it — `.decisions/**` is `PROHIBITED_PATHS` — and makes no
claim of having done so.** Follow the `876c6b97` precedent: an **append-only dated `SCOPE NOTE` comment**, with
**no line above the marker altered**, because that object is the citable id for a human answer and its
`resolution` must stay byte-verifiable.

**Place the note at the end of the file, after `created_by`/`created_at`/`updated_at`, and set**
`updated_at` to the date of the edit — **matching `876c6b97`'s pattern exactly** (`:164` reads
`updated_at: "2026-10-07T00:00:00Z"   # scope note appended; the resolution itself is unaltered`).

```
# ---- SCOPE NOTE appended <YYYY-MM-DD> by orchestrator-main. APPEND-ONLY: no line above this
# comment is altered. The resolution above stands, is NOT withdrawn, and no clause of the
# owner's answer is re-opened. --------------------------------------------------
#
# RECORD-CORRECTION FINDING (G-19). Two statements in this file assert something that two
# independent read-only measurements have since measured to be FALSE. Both concern the
# factual BASIS on which the owner's answer rests. Neither concerns the ANSWER.
#
# 1. resolution.supersedes_design_lane_reading states the desktop state boards "carry NO
#    footer copy - only a divider and a right-aligned Show technical details text button".
#    MEASURED, twice, independently, on all four desktop S boards: a layer named `Footer`,
#    of type TEXT, at parentX 236 / parentY 862, size 1020 x 15, align left, carrying
#    "Your decision is recorded permanently. The same piece of work then continues - nothing
#    is restarted." - which is the SAME string _buildFooter renders in the shipped build at
#    apps/control_plane/lib/features/products/add_product_page.dart:383-384. The divider is at
#    (236, 848); the right-aligned "Show technical details" text layer is at (1036, 862) with
#    its right edge at 1256 = 236 + 1020.
#
# 2. follow_up_action #3 directs that the design lane's coordinate-based reading of a
#    'Footer' layer at (236,862) "should be treated as a misidentification". IT IS NOT A
#    MISIDENTIFICATION. The layer exists, at that coordinate, on all four boards.
#
# WHAT THE DECISION OVERRULED WAS THE LANE'S CONCLUSION, NOT THE LANE'S OBSERVATION. The
# observation was correct and is now measured; the conclusion - that the copy stays - is what
# the owner reversed, and the owner was entitled to reverse it. Nothing here disturbs that.
#
# WHAT IS UNCHANGED - stated explicitly, because this object is the citable id:
#   - The OUTCOME stands: no footer copy on either platform; desktop = divider +
#     right-aligned "Show technical details" text button; mobile = left-aligned button, no
#     divider; the boards are authoritative for footer structure. ALL OF IT.
#   - status: RESOLVED stands. selected_option and deviation_from_presented_options stand.
#   - decided_at: 2026-10-06T13:05:00Z and decided_by stand.
#   - human_correction_verbatim stands AS THE OWNER'S WORDS, and is NOT corrected. The
#     hyphenated board names in it ("S - Add Product - Unknown host - Light/Dark") are the
#     owner's spelling; the file's names are "S · Add Product · Unknown host · Light" and
#     "· Dark". A verbatim quote is not a file listing and must not be edited into one.
#   - All four follow_up_action owners stand.
#
# THIS IS THE SAME CLASS AS G-17. There, ADR 0018 asserted that no Human Decision object
# records its acceptance - in the same commit that added the object. Here, this object
# asserts a board layer is a misidentification - on a coordinate two reviewers have since
# measured. In both cases an authoritative record denies a thing that exists, and in both
# cases nothing will re-check it, because it is authoritative.
#
# STILL OPEN, AND NOT CLOSED BY THIS NOTE: the boards themselves. All four desktop S boards
# carry the copy this decision forbids, so the decision's outcome and the boards it declares
# authoritative are in conflict on exactly one clause. Removing the layer needs a
# design-system-owner board edit, which no current lane owns, and it is blocked on the Penpot
# instance binding. Registered as G-18 by design revision d26658219dea4955b0d2b4004a70aa4d.
# That gap is an ownership gap, not a re-decision, and the human is NOT asked to re-decide
# the footer.
#
# Correcting source of record for the design side:
# docs/engineering/dispatch/tasks/design-addproduct-keyservice/design-revision-6.md, § R.11g-h
# and § R.18.2-h (G-18, G-19); matrix traceable to
# docs/engineering/dispatch/tasks/design-addproduct-mobile/penpot-board-evidence.md § 6.4.
```

**What must NOT change, and this lane asks for none of it:** `status`, `selected_option`,
`decided_at`, `decided_by`, `human_correction_verbatim`, `deviation_from_presented_options`, the
`rationale`'s outcome clauses, and the four `follow_up_action` owners. **A record correction that re-opens a
resolved decision is a different act and is not requested here.**

---

## 7 — Validation, verification and what this lane did not do

### 7.1 What was run

| # | Check | Result |
|---|---|---|
| **V-1** | **Every source citation this revision carries, re-read at `1c3f5ad`** | **Pass.** `add_product_page.dart` **UNCHANGED** between `5436a4d` and `1c3f5ad`; `design_primitives.dart` **UNCHANGED** between them (and verified at its real path, `apps/control_plane/lib/shared/design_primitives.dart`). Re-read: `_buildFooter` def `:375`, call `:314`, copy `:383-384`; desktop `note:` `:317-319`; mobile `note:` `:926-928`; `design_primitives.dart:396` paints `const ContentRule()` **unconditionally**; `:402-410` renders `Expanded(child: widget.note == null ? const SizedBox.shrink() : Text(widget.note!…))` beside `InlineLink`. **All resolve exactly as Revision 5 stated.** |
| **V-2** | **Content pins** — `git hash-object` per artifact | **Pass.** Revision 5's four blobs verified **byte-identical** before and after the fast-forward (§ 0.3.1). Revision 6's four are printed in `report-revision-6.md` § pins, **including this metadata file's own hash** (L-R5-1's fix) |
| **V-3** | **Pre-flight** — branch, fast-forward, HEAD | **Pass**, with the two disclosures at § 0.3.2 and § 0.3.3. `git rev-parse --short HEAD` = `1c3f5ad` |
| **V-4** | **The `PROVENANCE_GAP` reconciliation** (M-R5-4) | **Pass** — § 0.5. `289f1d3` confirmed as the commit that added the rev-4 report, and as an ancestor of `1c3f5ad`; its `RESULT:` block read and compared finding-by-finding against Revision 5's map |
| **V-5** | **§ 0.4's full sweep** (M-R5-2's fix) | **Pass** — § 0.4.1. 16 rows check out; `L8` and `M5` wrong; one further error found and disclosed (the `L13`/pin gap, = L-R5-1) |

### 7.2 `NOT_RUN` — nothing is claimed that was not observed

| Command / check | Status | Note |
|---|---|---|
| **`docker` / `docker compose`, any subcommand** | **NOT_RUN — none issued** | Not `info`, not `ps`, not `logs`, not `config`, not `down`. **This repository has already lost its QA database** to a lane running `docker compose -f docker/compose.qa.yaml down -v --rmi local`; the rule is not tested, because testing it is the forbidden act. Compose files were **not read** this pass |
| **Any Penpot tool** — `penpot_execute_code`, `penpot_export_shape`, `penpot_high_level_overview`, the Penpot MCP resources | **NOT_RUN — none called** | **No board was read, listed, edited, renamed, moved, exported or deleted.** This lane has **no board ownership** in this pass. The F6/G-18 measurement is **cited from two independent sources**, not reproduced. **Confirmation is in `report-revision-6.md`** |
| `dart analyze` / `flutter analyze` | **NOT_RUN** | Implementation-lane gate |
| Build | **NOT_RUN** | — |
| `dart test packages/product_registry/test` | **NOT_RUN** | No claim about `D-4`/`D-5`/`D-6` |
| `make test-integration` | **NOT_RUN** | The only sanctioned Docker exemption; not needed and not used |
| `T-A` … `T-L` execution | **NOT_RUN** | **Specified, not executed.** `T-A`/`T-B`/`GAP-2` remain reported-passing by the implementer's report; not adopted as this lane's result |
| Contrast-ratio measurement | **NOT_RUN** | Figures **inherited** from `design-register-button/report.md:71-76`, not re-measured |
| ADR 0018 amendment — merge, edit, review | **NOT_RUN — none of the three** | `docs/adr/**` is `PROHIBITED_PATHS`. `G-17` stands, unedited and unclaimed |
| `.decisions/**` — read, edit, create | **READ ONLY**, for the two decisions named in this dispatch | **Nothing written.** `G-19`'s target is Manager-owned; the fix is in § 6 |
| Commit / push | **NOT_RUN** | `COMMITTED: NO`, `PUSHED: NO`, as instructed |
| Deletions | **NONE MADE** outside my `OWNED_PATHS` | Four **untracked** Revision-5 working-tree copies were removed **after** being verified byte-identical to `1c3f5ad`'s blobs and **copied outside the repository**; the fast-forward restored them at the same four hashes (§ 0.3.1). **No tracked file was deleted, moved or renamed, and the eleven modified banners were carried forward untouched** |

### 7.3 `UNVERIFIED` — with what a human should run

| Claim | Status | What a human should run |
|---|---|---|
| **The four desktop boards still carry the `Footer` text layer at 236, 862** | **UNVERIFIED by this lane — cited, not measured.** Two independent read-only measurements at `16cd497`/`1c3f5ad` say yes; this lane ran no Penpot tool and holds no board ownership | Read the four boards read-only and re-read the layer's type, position and text |
| **A3 is reachable in this repository's target topology** | `UNVERIFIED` — `G-10` | Provision the manager; run `verifyProtection` against it from the server container |
| A real SSH transport accepts the generated public key | `UNVERIFIED` | A stack under an explicit `-p`; install the returned `publicKey` in a scratch repo's `authorized_keys`; run a real check |
| `D-4`/`D-5`/`D-6` behave as specified **on both tiers** | `UNVERIFIED` | `T-C`…`T-G`, `T-J`, `T-K` on both tiers |
| The mint endpoint refuses a foreign `repositoryId` on both tiers | `UNVERIFIED** — **Revision 4's sequence would NOT have** | `T-L`, both store tiers |
| The duplicate-credential audit finds no duplicates anywhere deployed | **`NOT_RUN, and not runnable from any lane** — `G-12` | The **corrected** query, by a human, before migration `20261006150645000` is applied anywhere |
| **§ 0.4's file:line references** | **Inherited, not re-derived at `1c3f5ad`** | § 0.4.1 states this limit. Only this revision's own citations were re-read (`V-1`) |

---

## 8 — Safe parallelism

**Unaffected by every finding above, and safe to proceed on now.** The Rev-5 reviewer's `SAFE_PARALLEL_WORK`
list is carried unchanged, because **no Rev-5 finding touched any of it**:

- **Implementation of `G-11`** (`D-4`/`D-5`/`D-6`, both tiers, eight columns) — § R.9 is untouched.
- **`G-13` step 3a + `G-16` step 3a + `T-L` + `SC-20`** (§ R.14.1) — B6's remedy is fully specified.
  **Ship `G-16` first.**
- **`G-14`** (§ R.11.2) — one method, no schema change.
- The retirement of the `repositoryId: productId` placeholder (§ 10.1 item 7).

**NOT SAFE while `G-18` and `G-19` are open:** any board edit; treating § R.11g item 7's
*"boards are authoritative"* as unconditional; and **closing the work item**, because the build would then be
able to diverge permanently from the authority it declares.

**§ 8's success criteria are carried unchanged** (`SC-01`–`SC-20`). **No `SC` was added, removed or re-scoped
by this pass** — `G-18`'s board edit is a *conformance* obligation, not a new user-visible success criterion,
and inventing one for it would be a redesign.

---

## 9 — Readiness

**Ready for Independent Design Review of Revision 6. Not approved by its author.** Revision 5's review was
`CHANGES_REQUIRED`; Revision 4's was too; Revision 3's was too; Revision 2's approval does not carry over;
and **this revision carries no approval from any reviewer.**

**Gate D4 status is unchanged.** The nine decisions are `RESOLVED`. `9417f8bf` and `876c6b97` carry
**append-only dated scope notes** appended by the Manager at `1c3f5ad`; this revision cites both **at their
scoped reading** and **re-opens neither**. **Specifically: the absolute *"never holds key bytes"* is true only
in the STORAGE dimension** — at transport time SHIP IT must materialise the private half in process memory,
which is what "transmit it" requires of it. That absolute appears at **four** sites, `9417f8bf:140` being the
load-bearing uniqueness argument. **No accepted-risk count changed: exactly four were put to the owner and
exactly four are recorded.**

**One caveat stated so the reviewer is not surprised.** Three of this pass's items concern artifacts this
revision does not own: the four boards (`G-18`), `27ea6536`'s record (`G-19`), and this lane's own
uncommitted supersession chain (`G-20`). **All three are recorded with owners; none was edited by me.** `G-18`
and `G-19` are the two the reviewer must check hardest, because both are claims about another owner's record
and this lane could only cite, never verify, them.