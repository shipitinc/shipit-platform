# Report — Focused Independent Design Re-Review, mobile Design Revision 6

Persisted per `aef-orchestrator` §14. Reviewer: `design-reviewer`, **read-only in git and in Penpot**.
Persisted to `docs/engineering/dispatch/tasks/design-rereview-mobile-rev6/report.md` (committed at `1c3f5ad`
or later — verified, see §2 — so it cannot be lost a fourth time).

```yaml
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
TASK_ID: design-rereview-mobile-rev6
TASK_TYPE: review
FEATURE: Add Product rebuild — mobile Design Revision 6 (focused re-review)
WORKTREE: /Users/alkebut/air/shipit-platform   (canonical checkout; read-only)
BRANCH: main
BASE_SHA: 1c3f5ad   # dispatch-declared
HEAD_SHA: af8e30f   # dispatch-declared; independently confirmed
PRODUCING_WORKTREE: /private/tmp/shipit-correct-addproduct-mobile @ 16cd497 [design-correct-addproduct-mobile]
COMMITTED: YES       # this report only; nothing else was written
```

```
REVIEWED_HEAD: af8e30f
REVISION_ID: CB4BEECA-CA9D-4F26-9464-E1B6F7C9BDCB   (carried from rev 5 — same design, corrected record)
BRIEF_ID: 52CB4098-FF87-4B78-81DA-1104269551A1

BLOCKERS: NONE
HIGH: NONE
MEDIUM: MR6-1
LOW: MR6-2
   (+ 4 LOW observations that require no correction — see §8)

INDEPENDENT_RISK_LEVEL: 3
RISK_LEVEL_AGREEMENT: YES

TRACEABILITY_GAPS: G13, G14/SC-9 (the lane's own, carried unchanged and correctly), F6 / N6b (OPEN, OWNED BY
   NOBODY — confirmed still open, NOT absorbed by this pass), F5 / BPM (OPEN, reported not touched),
   F8 (pre-existing in metadata-4/-3/-2; RECORDED at revision 5 and re-confirmed at revision 6), plus
   MR6-1 and MR6-2 below.

CORRECTION_REQUIRED: YES
HUMAN_DECISION_REQUIRED: NO
HUMAN_DECISION_TYPE: (none)

SAFE_PARALLEL_WORK: SEE §11
```

---

## 1. Headline — the plain answer first

**DO THE BOARDS NEED ANY CHANGE BECAUSE OF REVISION 6? NO. Not one board, not one layer, not one
string.** Revision 6 is a genuine record-only pass and I verified that on the live file, not on the
lane's word: the page inventory is unchanged at **160 boards / 164 root children**, the `SM` boards'
top-level child counts are unchanged at **44 / 44 / 36 / 36**, each Unknown board still carries exactly
**8 unsuffixed `Trust *` layers** and each Verified board **0**, and the four desktop `S` boards' footer
band is byte-identical to what the rev-5 review measured. A board was not created, deleted, renamed,
moved or written. **I am not asking for any board change.**

**Separately, and independently of this revision: the four desktop `S` boards DO need a change** — the
`Footer` text layer at rel (236,862) is still there, so `27ea6536`'s desktop *"No footer copy"* clause is
still unsatisfied. **F6 is OPEN and OWNED BY NOBODY.** I confirmed it live and I did **not** absorb it,
did not re-decide it, and did not touch a board I do not own. It needs an **ownership grant**.

**All seven findings MR5-1…MR5-7 landed exactly**, each on the anchor it claims, each read from the live
file rather than from the report. **All three record corrections landed exactly.** The line-movement
account is **precise to the line and fully reproducible from `git diff`** — I did not take it on trust.
The 14/14 pre-flight byte-comparison is **independently reproducible and reproduces**. Both metadata files
parse 7/7, and I checked the revision-4 defect the dispatch asked about: it is **still present, and it
was never unrecorded** — the dispatch's premise there is wrong, and I say so in §6.

**I return two findings, one MEDIUM and one LOW.** Neither touches a board, a string, a geometry, a
token, a requirement or a decision. Both are one-line in-place record fixes.

---

## 2. Provenance — verified

| Check | Result |
|---|---|
| `git rev-parse --short HEAD` | **`af8e30f`** — matches the dispatch's `VALIDATION_COMMANDS` ✓ |
| Branch | `main` ✓ |
| Dispatch `BASE_SHA: 1c3f5ad` | ✓ — and `1c3f5ad` is the commit that persisted revision 6 |
| `git log --all --diff-filter=A -- <exact full path>` for `design-revision-6.md`, `design-revision-metadata-6.yaml`, `correction-report-6.md` | all three **added at `1c3f5ad`**, by full path, not by basename ✓ |
| All three rev-6 artifacts present and committed at the reviewed head `af8e30f` | ✓ **COMMITTED** (verified with `git cat-file -e af8e30f:<full path>`, one path at a time) |
| `git status --porcelain -- docs/.../design-addproduct-mobile/` | **empty — the artifact set under review is clean** ✓ |
| The rev-5 review report I used as baseline | **COMMITTED** at `af8e30f` ✓ — it will not be lost |
| Producing worktree | `/private/tmp/shipit-correct-addproduct-mobile` @ **`16cd497`**, branch `design-correct-addproduct-mobile` ✓ (from `git worktree list`) |
| Producing worktree `git status --short` | exactly the **nine** artifact paths the lane claims + `?? design-correct-addproduct-mobile-6/` (its own task directory). No `apps/`, `packages/`, `docker/`, `.github/`, `.decisions/`, `WORK_STATE.md`, `LANES.md` ✓ |
| `revision_id` | `CB4BEECA-…` in rev-6 header **and** metadata-6 front matter — consistent, and identical to rev 5's ✓ |
| `supersedes` | `CB4BEECA-…` = revision 5, retained ✓ |
| Self-approval | `status: UNDER_REVIEW`, `reviewed_by: null`, `reviewed_at: null`, `approved_by: null`, `approved_at: null` ✓ — the lane did not approve itself |

**Ownership boundary — respected, with one clarification I will not let pass unstated.** `1c3f5ad`
(the Manager's persistence commit) also carries `.decisions/876c6b97-…yaml` and
`.decisions/9417f8bf-…yaml`. **Those are the ADR-0018 amendment lane's dated scope notes**, not the
mobile lane's work — the commit message names both lanes, and the mobile lane's own worktree status
contains no `.decisions/` entry. **The mobile correction lane wrote nothing in `.decisions/**`.** The
bundling is a Manager-side persistence decision and outside my scope.

**No Docker or Compose command was issued in this review** — not `info`, not `ps`, not `logs`, not
`config`, not any mutating one. **None. No breach.** Nothing here needed a database.

---

## 3. MR5-1 … MR5-7 — every finding landed, every anchor verified from the live file

I read each claimed line in the file it names. Not the report; the file.

| Finding | Where it had to land | What the file reads now | ✓ |
|---|---|---|---|
| **MR5-1** .1 | `design-revision-5.md:361` | `` | 8 × `Trust *` names | … **16 suffixes across the pair** — this cell published `7 ×` until revision 6 (MR5-1) `` | ✓ |
| **MR5-1** .2 | `penpot-board-evidence.md:262` | `` | 8 × `Trust *` layer names | … **16 across the two Unknown boards; this cell published `7 ×` until revision 6 (MR5-1)** `` | ✓ |
| **MR5-1** .3 | `design-revision-metadata-5.yaml:101` | `**Sixteen** · PROVISIONAL` suffixes retired (8 `Trust *` layers on each of the two Unknown boards; …)` | ✓ |
| **MR5-1** .4 | `traceability-matrix-5.md:77` | `**16** · PROVISIONAL suffixes retired *(published as 17 until revision 6 — MR5-1)*` | ✓ |
| **MR5-1** .5 | `design-revision-5.md:169-172` | *"…two populations… **4** … plus **16** … **20 in all**"* + the `CORRECTED AT REVISION 6 (MR5-1)` note | ✓ |
| **MR5-2** | `design-brief.md:98` | `**MET on mobile · NOT MET on desktop (F6).**` … §**6.4** (desktop) and §6.3 (mobile) … names the `Footer` text layer at rel **236,862**, divider at 236,848, finding **F6**, routed as **N6b**, needs an **ownership grant, not a re-decision** | ✓ |
| **MR5-3** | `design-revision-5.md:424` | `` | 7 | **`apps/server/lib/src/services/ui_view_mappers.dart:176`** … `` — the seventh site | ✓ |
| **MR5-3** | `design-revision-5.md:426-435` | *"**7 sites, not 6** … this call site WILL NOT COMPILE"*, plus the deliberate-retention paragraph (`:430-435`) naming `platform_contracts` / `product_credential` / `postgres_product_registry_store.dart` / `schema_bootstrap.dart` and `generated/protocol.dart:3841` | ✓ |
| **MR5-3** | `design-revision-5.md:655` (N6a) | names the constructor and the compile break | ✓ |
| **MR5-3** | `design-revision-metadata-5.yaml:230` and `:237` | `MEASURED 6 sites (**7 as of revision 6, MR5-3**)` · `apps/server/lib/src/services/ui_view_mappers.dart:176` | ✓ |
| **MR5-3** | `traceability-matrix-5.md:85` | `**7** sites measured … and the **server-side view constructor …:176**, which **will not compile**` | ✓ |
| **MR5-4** | `design-revision-4.md:160` · `rev-5:62` · `rev-5:600` · `metadata-4:154` | all four now read **`:623-644`** ✓ — and I re-measured it myself: `design-revision-3.md:623` = `## 12. The verification-discipline lesson…` (heading), `:642` = last content line, `:643` = blank, `:644` = `---`. **The lane's re-measurement is exact.** |
| **MR5-5** | `rev-5:18` · `:235` · `:672` · `:683` · `metadata-5:18-20` | head `16cd497` stated; empty-diff claim **qualified, not deleted**; per-citation basis substituted — all five present ✓ |
| **MR5-6** | `design-brief.md:99` | `**§5.1 / §5.2 of `design-revision-5.md`** *(rev 6 corrected this from §4, which is H-1(b), the footer — MR5-6)*` ✓ |
| **MR5-7** | `design-revision-5.md:376-377` · `penpot-board-evidence.md:266-267` | *"zero intra-panel overlaps **other than the button-rect-plus-label idiom**"* + the two measured enclosures named + the substantive claims explicitly left standing ✓ |

**Residual wrong values — I re-ran the lane's own grep and it is clean.** `7 ×` survives only inside the
two in-cell correction markers that quote the old value. `Seventeen` survives only inside the
`metadata-5.yaml:102` marker. `17 suffixes`, `all sixteen layer names` (outside the marker) and
**`:624-644` (anywhere at all)** return nothing. **The lane's §6 row is accurate.**

**MR5-3's seventh site is real — I read the production file, not the record.**
`apps/server/lib/src/services/ui_view_mappers.dart:176` reads exactly `referenceName: c.referenceName,`,
inside `static RepositoryCredentialView repositoryCredentialView(` (declared at `:169`), directly under
the comment *"Reference name only — the private half is never in this payload."* **Recorded and routed,
not implemented — correct, and I agree that these are production sites this lane does not own.**

---

## 4. The three record corrections

### 4.1 The suffix count — the arithmetic is right, and I re-measured the end state myself

**`16` is correct, and it is correct for a reason that survives scrutiny.**

```
SM - Add Product - Unknown host - Light   trustCount 8  suffixed []  Trust Bg|Body|Btn|Btn L|Created|Edge|Host|K
SM - Add Product - Unknown host - Dark    trustCount 8  suffixed []  (identical)
SM - Add Product - Verified - Light       trustCount 0
SM - Add Product - Verified - Dark        trustCount 0
```

**8 × 2 = 16.** All **five** published forms now agree, and I read each one:

| Where | Reads |
|---|---|
| `design-revision-5.md:361` | `8 ×` + *"16 suffixes across the pair"* |
| `penpot-board-evidence.md:262` | `8 ×` + *"16 across the two Unknown boards"* |
| `design-revision-metadata-5.yaml:101` | `**Sixteen**` |
| `traceability-matrix-5.md:77` | `**16**` |
| `design-revision-5.md:169-172` | the two populations split |

…plus the reference form `penpot-board-evidence.md:182-187` (*"All sixteen suffixes retired"*, eight
layers enumerated), which was the one that was right and is unchanged. **Six forms, one number. Done.**

**The `4 + 16 = 20` split — the second half is record-derived, and I checked its source.** The **16** is an
**end-state measurement** (8 unsuffixed layers × 2 boards — I measured it live just now). The **4** is
**not**; after the rename no layer is named `· PENDING D4`, so 4 cannot be measured from the end state.
It comes from the artifact's own record, and that record supports it: `design-revision-5.md:158` §3.2 is
headed *"Measured before / after, **all four boards**"* and `:163` reads
`` | `Art S` layer **name** | `Art S · PENDING D4 (at-rest model)` | **`Art S`** | `` — one per board, four
boards, **4**. Corroborated at `:687` ("All four `SM` boards: forbidden layer names | **0** for `PENDING
D4` and `PROVISIONAL**, all four ✓"). **So 4 + 16 = 20 is arithmetically sound, and the two halves are
supported by different kinds of evidence — which is the honest way for it to be.**

### 4.2 `design-brief.md` SC-7 — corrected, and greppable

```
:98  | **SC-7** *(added rev 5; disposition corrected rev 6)* | … | **MET on mobile · NOT MET on desktop
     (F6).** … `penpot-board-evidence.md` **§6.4** (desktop) and §6.3 (mobile). The desktop *"no copy"*
     clause fails on **all four** `S` boards — a `Footer` **text** layer at rel **236,862**, with the
     divider at 236,848 — finding **F6**, routed as **N6b**. Those boards are read-only to this lane
     *and* to the keys lane, and **no lane owns them**, so F6 needs an **ownership grant**, not a
     re-decision; the decision's outcome is not in question |
```

`grep -nE '(^|[^F])F6([^0-9]|$)' design-brief.md` → **one hit, `:98`**. `grep -n 'N6b'` → `:98`. Both
desktop §6.4 and mobile §6.3 are cited, so the reader is sent to the section that can contain each answer.
**All three defects in one row fixed, on one line, with the brief held at 169 lines.** ✓

### 4.3 G-7's site table — seven sites, everywhere that matters

Site 7 is in `design-revision-5.md` §6.1 (`:424`), in **N6a** (`:655`) — the row an implementer works
from — in `design-revision-metadata-5.yaml` (`:230`, `:237`) and in `traceability-matrix-5.md:85`. The
deliberate **retentions** under `9417f8bf:167` are now stated so a future lane does not "helpfully"
strip them. **The 6-site scope was right and is unchanged** — I agree with the reviewer on that and with
the lane for not re-deriving it.

---

## 5. LINE MOVEMENT — the strongest claim in the pass, and it is exact

The lane says the corrections moved lines, published the migration, and **re-shaped three of its own
edits to hold line counts constant**. Cross-reference drift has been published as measured before in this
work item, so I reproduced it from `git diff` rather than believing it. **It is exact.**

`git diff --unified=0 16cd497 af8e30f -- design-revision-5.md` yields **ten hunks**. Nine are in place;
**exactly one** insertion exists, `@@ -423,0 +424,12 @@` — 12 lines added above old `:424`. Therefore every
anchor below `:423` shifts by exactly +12, and everything above is unmoved. Measured:

| Anchor | Claim | Measured | ✓ |
|---|---|---|---|
| `design-revision-5.md:588` | → `:600` (+12) | 588 + 12 = **600**, and `:600` is the `:623-644` line MR5-4 is about | ✓ |
| `:643` (N6a) | → `:655` | diff hunk header `@@ -643 +655 @@` | ✓ |
| `:660` | → `:672` | `@@ -660 +672 @@` | ✓ |
| `:671` | → `:683` | `@@ -671 +683 @@` | ✓ |
| `metadata-5.yaml:99` | → `:101` (+2) | the **only** insertion above it is `@@ -18 +18,3 @@` (the provenance comment) → +2. The MR5-3 edits at old `:226`/`:231`/`:238` are all **below** `:101`, so they cannot affect it | ✓ |
| **file totals** | — | `design-revision-5.md` **734 → 746 (+12)**; `metadata-5.yaml` **304 → 318 (+14 = 2 + 2 + 7 + 3)** — fully accounted for by the four insertions | ✓ |

**Every "unmoved" claim verified.** `rev-5:18`, `:62`, `:235`, `:361` are single-line hunks.
`rev-5:169-172` is the clever one — the paragraph went **2 lines → 1** at `:169` and **1 → 2** at `:171/172`,
**net 0**, held at exactly four lines, so nothing below it moved. `rev-5:376-377` is **2 → 2**, net 0.
`traceability-matrix-5.md` **132 → 132 (+0)**. `penpot-board-evidence.md` **455 → 455 (+0)**.
`design-brief.md` **169 → 169 (+0)**. `design-revision-4.md` **886 → 886 (+0)**. **Every one holds.**

**One nice incidental confirmation:** rev-6 §5 says the keys review's citations (`design-revision-5.md:2414`,
`design-revision-metadata-5.yaml:739-742`) are "out of range for files of **746 and 318** lines". Those are
**exactly** this lane's files' sizes — measured 746 and 318. The lane used the right numbers to prove a
sibling's citations point at a different file of the same name, which is precisely the trap the dispatch
warned about. **Well done, and correct.**

*(Counting note, so a later reader is not misled by `wc -l`: these files have **no trailing newline**, so
`wc -l` under-reports by one. `wc -l` says 745/317/131/454/168 where the true last-line index is
746/318/132/455/169.)*

---

## 6. The pre-flight claims, the near-miss, and the `NOT_VERIFIABLE` judgement

### 6.1 14/14 byte-identical — I reproduced it

The stash's name is `rev5-uncommitted-identical-to-16cd497`, which is a claim, not evidence. So I hashed
every stashed blob against the blob committed at `16cd497`:

```
IDENTICAL  design-brief.md                      IDENTICAL  correction-report-5-retry.md (untracked)
IDENTICAL  design-revision-2.md                 IDENTICAL  correction-report-5.md      (untracked)
IDENTICAL  design-revision-3.md                 IDENTICAL  correction-report-5c.md     (untracked)
IDENTICAL  design-revision-4.md                 IDENTICAL  design-revision-5.md       (untracked)
IDENTICAL  design-revision-metadata-4.yaml      IDENTICAL  design-revision-metadata-5.yaml (untracked)
IDENTICAL  design-revision.md                   IDENTICAL  traceability-matrix-5.md   (untracked)
IDENTICAL  penpot-board-evidence.md             IDENTICAL  report.md
--> TOTAL byte-identical to 16cd497: 14 / 14   differing: 0
```

**14/14 — reproduced independently, sha256 on every file.** And the **8 modified + 6 untracked = 14**
decomposition matches exactly the lane's account of *why* `git merge --ff-only 16cd497` was refused.
**It did the right thing: it compared before it forced, backed up, then fast-forwarded.**

**The stash is intact.** `stash@{0}` = `1b0114d157de214d711ee5e0ba1bfbbfdbc8713c`, three parents
(`289f1d3` base + index + untracked), message `On design-correct-addproduct-mobile:
rev5-uncommitted-identical-to-16cd497`. **Not dropped**, and the message says what it is.

**The `21 of 21` post-fast-forward re-comparison cannot be replayed** — the temp backup path is gone.
I checked for it and it is not there. I record that as **not-replayable**, not as unverified-bad,
because it is arithmetically coherent: the directory held **21** files pre-pass and holds **24** now =
21 + the 3 new rev-6 artifacts. *(No finding; a reviewer cannot replay a temp backup three commits
later, and the lane is not required to keep one.)*

### 6.2 The near-miss — and **the dispatch's premise about the inherited defect is wrong**

**Both metadata files parse. 7/7 each.** I parsed every fenced block with a real YAML parser
(Ruby Psych), across the whole metadata family:

| File | blocks | parse OK | fail | |
|---|---|---|---|---|
| `design-revision-metadata-6.yaml` | **7** | **7** | 0 | ✓ the lane's claim |
| `design-revision-metadata-5.yaml` | **7** | **7** | 0 | ✓ F8's claim, unbroken by these edits |
| `design-revision-metadata-4.yaml` | 1 | 0 | **1** | `mapping values are not allowed in this context at line 53` |
| `design-revision-metadata-3.yaml` | 1 | 0 | **1** | same class, line 37 |
| `design-revision-metadata-2.yaml` | 1 | 0 | **1** | same class, line 42 |
| `design-revision-metadata.yaml` (rev 1) | 1 | 1 | 0 | parses |

**The near-miss is real and the discipline was right.** Catching 2-of-7 by parsing rather than eyeballing,
in the revision created to record corrections, is exactly the lesson this work item keeps paying for.
Routing it out as `N11` rather than building the tool — correct, this lane has no tooling ownership.

**Now the part the dispatch asked me to check, and the answer is not the expected one.**
The dispatch asked whether revision 4's metadata defect "is still present **and unrecorded**".

**It is still present. It was never unrecorded.** It was recorded **twice at revision 5**, before this
pass: `design-revision-5.md:625` (`| **F8** *(new)* | **design-revision-metadata-4.yaml**'s first fenced
YAML block does not parse — a `-` list item whose continuation line contains `": "` … |`) and
`traceability-matrix-5.md:115` (*"**Pre-existing** — confirmed by parsing the committed blob, which fails
identically … reported, **not** fixed"*). **The one genuine gap was narrower than the dispatch assumed**:
revision 5's `design-revision-metadata-5.yaml` `non_requirement_gaps` table omitted F8. **`1c3f5ad`/
revision 6 closes exactly that gap** — `design-revision-metadata-6.yaml:236` lists F8, states it is
pre-existing and not fixed, and re-confirms that metadata-4, -3 and -2 all still fail while metadata-5's
7 of 7 still parse. **I verified every clause of that row against the parser output above. It is exact.**

So the honest summary is: the lane did **not** inherit-and-ignore a defect, and it did **not** ship a new
one. It caught a new one in its own draft and closed a real one-line omission in the metadata.

### 6.3 The `NOT_VERIFIABLE` alternative — **I endorse the decline, and here is why it is the better call**

The reviewer's item 6 offered to retire the count as `NOT_VERIFIABLE`. The lane declined and published its
reasoning. **My judgement: the decline is correct, and it is correct for a sharper reason than the lane
gives.**

`NOT_VERIFYABLE` is a claim about *what can be known*. What can be known here: the end state is directly
observable — 8 unsuffixed `Trust *` layers on each of two boards, `Trust Bg / Edge / Btn / K / Body /
Created / Host / Btn L`. What cannot be known is the *before* state, because Penpot exposes no version
history. Those are **two different propositions**, and the artifact now keeps them apart: the **16** is
published as an end-state count, and the before-state is named as unverifiable in
`design-revision-6.md:77-82`, in `correction-report-6.md` L-4 ("live-verifiable as 8 unsuffixed …
**while the *before* state is not**"), and in `design-revision-5.md:169-172` (which adds an independent
re-read of zero forbidden names on all four boards). **Stamping `NOT_VERIFIABLE` over a figure that is
measurable would trade a wrong number for a false absence of knowledge** — the lane has it exactly right.

One refinement I would offer for the next lane, recorded as an observation and **not** as a finding: the
`4` in `4 + 16 = 20` is record-derived while the `16` is measured (§4.1). The artifacts already say so. A
future reader should not be left assuming both halves rest on the same kind of evidence. **It is already
sufficiently stated; I am noting it so nobody "helpfully" hardens it later.**

### 6.4 RISK_LEVEL 3 carried — coherent, conservative, and the gate was **not** re-opened

**I re-derived the risk independently and reached 3. `RISK_LEVEL_AGREEMENT: YES`.**

**Carrying 3 rather than dropping to 0 is the only defensible move.** Two framings are in play here — that
the level describes the *change*, or the *artifact* — and the lane states both (marginal 0 for the delta,
3 carried for the artifact). That is not a contradiction; it is the artifact's standing risk versus this
pass's delta. The artifact still contains Level-3 design content: the workflow-meaning change from
`898b07d0` (what *"Register product"* means), a new user-facing element (`Trust Created`) absent from every
prior revision, and R.11g item 3's resume route on `ProductDetailPage`. **And carrying 3 is the
conservative direction** — a lane cannot downgrade its own risk level with no authority to do so. Had it
dropped to 0, I would have pushed back hard. It did not.

**The gate is discharged and was NOT re-opened — verified directly, not inherited.**
All **14 of 14** files in `.decisions/**` are `status: RESOLVED` (not nine — fourteen). The five
load-bearing decisions' `owner: design-agent` follow-up counts are **2 / 3 / 2 / 2 / 1** for
`9417f8bf` / `27ea6536` / `898b07d0` / `ae1c1f79` / `7b1bc8b7` — **exactly** the table rev 6 §2 publishes.
`human_decision_gate.required: NO` rests on that discharge, not on a lowered risk. **Correct.**
`not_re_raised` correctly lists D-8 and SC-9's scoping call. **Coherent.**

**The `27ea6536` quote F6's routing rests on is verbatim accurate.** `implications:` for `OPTION_B` reads:
*"Requires `note: null` at `add_product_page.dart:317` **and** editing the four existing desktop boards,
which no current lane owns — so it needs a design-system-owner board edit."* — which is what
`design-revision-6.md:124-125` and `correction-report-6.md:189-191` quote, with a correct elision.

---

## 7. Penpot — READ-ONLY. Zero board writes confirmed as far as the file allows

`penpot_high_level_overview` read first, as required. `penpotUtils.getPages()` → `["Page 1"]`, id
`d8ac01df-6646-81d2-8008-a366c09aa9d3`. **The tab was suspended on first contact and needed waking.**
**I edited, renamed, moved and deleted nothing.** I read only what the zero-write claim and F6 required.

| What I checked | Result |
|---|---|
| Page inventory | **160 boards / 164 root children** — unchanged, so **no board was created or deleted** |
| `SM` top-level child counts | **44 / 44 / 36 / 36** — unchanged |
| `Trust *` layers per `SM` board | **8 / 8** on the Unknown pair, **0 / 0** on the Verified pair, **zero suffixed** — the end-state measurement for the count of 16 **reproduces exactly** |
| `BPM` board set | 2 boards, present, untouched |

**Penpot has no version history, so "zero writes" cannot be proved as a negative.** What I can say, and am
saying, is what the end state supports: **the inventory is unchanged, the layer counts are unchanged, and
every measured element is byte-for-byte what the rev-5 review measured.** That is the strongest statement
available and the lane's is the honest one.

### F6 — **CONFIRMED STILL OPEN. NOT ABSORBED. NOT FIXED.**

All four `S · Add Product · …` boards (1280×900), identical on all four, read just now:

| Layer | type | rel x, y | w × h | content |
|---|---|---|---|---|
| `Footer Rule` | rectangle | **236, 848** | 1020 × 1 | the divider |
| **`Footer`** | **TEXT** | **236, 862** | **1020 × 15** | *"Your decision is recorded permanently. The same piece of work then continues — nothing is restarted."* |
| `Disclose` | text | 1036, 862 | 220 × 15 | `Show technical details ▸` — right edge **1256 = 236+1020** |

The copy is byte-identical to `apps/control_plane/lib/features/products/add_product_page.dart:383-384`,
which I read directly. Against `27ea6536`'s desktop clauses (`:135`): **divider — SATISFIED.
Right-aligned — SATISFIED. "No footer copy" — NOT SATISFIED, on all four boards.**

**This is the only outstanding board change in the work item, it is pre-existing, it is owned by nobody,
and revision 6 correctly did not touch it.** The four boards are `PROHIBITED` to this lane and to the keys
lane. `27ea6536` is RESOLVED and its OPTION_B named this exact cost in advance. **It needs an ownership
grant, not a re-decision — and I am not the lane that gets it.** Registered in five places:
`design-revision-6.md` §3, `design-revision-metadata-6.yaml` `requirements_gaps` (`status: OPEN — NOT MINE,
NOT FIXED, NOT ABSORBED`), `traceability-matrix-5.md:107`, `design-revision-5.md` §12 (N6b), and
`design-brief.md` SC-7.

### F5 / `BPM` — also still open, also reported not touched

Both `BPM · Add Product · Dark` and `· Light` still carry the false custody string
`ed25519 · private half stays in the keychain` and the now-false `NOT REGISTERED YET` eyebrow. Confirmed
live. Reported, not edited. Correct.

---

## 8. Findings

### MR6-1 (MEDIUM) — the correction report declares a persistence path that does not exist

`docs/engineering/dispatch/tasks/design-addproduct-mobile/correction-report-6.md:3-4`:

> Persisted per `aef-orchestrator` §14. Lane: `design-agent`. **Report persists to
> `docs/engineering/dispatch/tasks/design-correct-addproduct-mobile-6/report.md`.**

**That directory contains exactly one file: `prompt.md`. There is no `report.md` at the declared path.**
Verified with the full path, not a basename — the Manager's exact error from last session, and I checked
the full path precisely because of it. This lane's own dispatch (line 122) said:

> **PERSIST YOUR FULL REPORT TO DISK** before returning … **A review report has been lost three times in
> this work item.**

**The report's substance is NOT lost** — it is committed at `1c3f5ad` as
`design-addproduct-mobile/correction-report-6.md`, and I read all 333 lines of it. Nothing is at risk of
being lost today. But the *declaration* is false, and this is the exact check that would catch a report
that genuinely had been lost. A lane that asserts where its report is must be able to point at it.

**Required:** either place the report at the declared path, or correct the declaration to the path
actually used. One line, or one copy.

*Why MEDIUM and not LOW:* it is not a design defect and it changes nothing about the design — but it is a
**published statement that is false**, it is a discipline failure in the one area this work item has
already lost three times, and it is the kind of thing that hides a real loss next time. It is not a
blocker because the artifact is verifiably safe on disk.

### MR6-2 (LOW) — `design-revision-6.md:77` attributes MR5-1's alternative to MR5-6

`design-revision-6.md:77`:

> **Why the reviewer's alternative was not taken.** **MR5-6's** option of retiring the count as
> `NOT_VERIFIABLE` was declined …

The alternative is **MR5-1 requirement 6** — the baseline's `report.md:325`, *"Retiring the count as
`NOT_VERIFIABLE` would also be honest — Penpot has no version history — but since the end state is
live-verifiable…"*. **MR5-6 is *"SC-8 cites the wrong section"*** (baseline `report.md:403`), which has
nothing to do with a count. A reader following "MR5-6" lands on a section about a section citation and
learns nothing about the number.

**This is a single instance.** `correction-report-6.md:79` and `design-revision-metadata-6.yaml:42` both
say "the reviewer's alternative" with no finding number, and both are right. **Required:** `MR5-6's` →
`MR5-1's` at `design-revision-6.md:77`.

*Why LOW:* the value (16), its measurement, and the reasoning are all correct and published correctly
three other times. Nothing is misread about the count. But it is **the same wrong-reference class as
MR5-2 and MR5-6 themselves**, in a new artifact, in the paragraph explaining the one number this pass
exists to fix.

### LOW observations — no correction required

1. **`correction-report-6.md:318`** says *"git status --short in the worktree shows exactly the nine paths
   above and nothing else."* The worktree also shows `?? design-correct-addproduct-mobile-6/` — the
   lane's own task directory. "Nothing else" is true **within the owned artifact set** but not literally.
   Cosmetic.
2. **`F8` is an overloaded identifier.** `design-revision.md` and `report.md` use it for a *different*
   finding (Penpot's IBM Plex Sans has no 500 weight). Pre-existing from revision 1; revision 5 marked
   its F8 `*(new)*`. Ambiguity, not an error — but it is a live trap for a future lane.
3. **The dispatch's own warning bit me, and I am persisting the executable form of it.** `grep -n 'F8'`
   on `design-brief.md` **and** `design-revision-metadata-5.yaml` returns a hit — because the
   `brief_id` UUID `52CB4098-**FF87**-4B78-81DA-1104269551A1` contains the substring `FF87`, which
   contains `F8`. **A naive grep would have concluded F6/F8 records existed in the brief.** They do not.
   Word-boundary greps were required throughout (`grep -nE '(^|[^F])F6([^0-9]|$)'`). **This is the
   fourth instance of this work item's identifier-vocabulary trap** and the concrete argument for the
   lane's `N11`: the checker must anchor identifiers, not substring-match them.
4. **`.decisions/` bundling.** `1c3f5ad` carries two `.decisions/` files alongside the mobile artifacts.
   Those are the ADR-0018 lane's scope notes, not the mobile lane's — the mobile lane's own worktree
   status contains no `.decisions/` entry. **Not a rev-6 finding**, but the Manager should know the
   persistence commit is multi-lane, because it means "what did this lane write" cannot be answered from
   a commit diff alone.

---

## 9. Regression risk — checked, and clean

| Risk | Result |
|---|---|
| A correction weakening the substantive claim it sits next to | **No.** MR5-7 *names* the button-rect-plus-label exception and explicitly leaves the substantive claims standing (`Trust Created` contained, chain geometry unchanged, zero nav collisions). MR5-1's split adds the combined total rather than replacing a figure. MR5-2 marks SC-7 NOT MET rather than deleting the criterion. |
| A correction dropping a retention a future lane needs | **No, and improved.** MR5-3 now *states* the deliberate retentions under `9417f8bf:167`, which revision 5 left implicit. |
| New anchors introduced by the new artifacts | **Checked and exact.** Every `file:NNN` in `design-revision-6.md`, `design-revision-metadata-6.yaml` and `correction-report-6.md` that names a file I could resolve was read. §5 of rev 6 reproduces the measured deltas exactly; §6 Table 1's 15 correction anchors are exact; the metadata's `:230`/`:237` are exact. **One exception: MR6-2.** |
| Line-count drift in a file a sibling cites | **No.** Four of the five modified files are unchanged in length; the fifth grew by exactly the published amount, and the migration table publishes it. |
| An old value re-introduced anywhere | **No.** Re-ran the lane's own greps (§3). Only in-cell correction markers quote the old values. `:624-644` appears nowhere. |
| A decision re-opened | **No.** 14/14 RESOLVED; follow-up counts unchanged; `not_re_raised` correct. |
| Production source written | **No.** `git diff --name-only 16cd497 af8e30f -- apps/control_plane apps/server packages` is **empty** — so every citation the lane re-read at its base **still holds at the reviewed head**, which I checked rather than assumed. G-7's seventh site was recorded and routed. |
| A new non-parsing YAML block | **No.** metadata-6 **7/7**, metadata-5 **7/7**. |
| `design-brief.md` (the acceptance baseline) left inconsistent | **No.** One line, 169 lines held, SC-7 and SC-8 both now cite the sections that contain their answers. |

---

## 10. What I did **NOT** review — stated explicitly

- **Any board claim the rev-5 review already verified.** I did **not** re-verify the custody string's 80
  characters, the layer renames, the 436→446 / 456→466 moves, the 4px of slack, the two-line wrap,
  `Trust Created`'s box/font/fill/containment, the `Disclose` alignment, the ten forbidden strings, the
  D-8 coordinate table, all 13 M-1 numbers, all three L-1 pointers, every source citation, or all ten
  contrast figures. I took those as my baseline, as instructed.
- **Where I *did* touch Penpot, and why:** page inventory, the `SM` boards' child counts and `Trust *`
  layer names, the four `S` boards' footer band, and `BPM`'s two strings. That is the minimum needed to
  confirm the **zero-board-write** claim and to confirm **F6 is still open** — the two things the
  dispatch asked me to confirm. It is not a re-review of the board claims.
- **Pre-edit board state.** Penpot exposes no version history. I cannot judge any before/after and did
  not try.
- **Attribution of any board write.** I verified the end state, not who made it.
- **The other 156 boards** on the page, except by inventory count.
- **Any Flutter widget render, app runtime, screenshot, build, `flutter analyze` or `flutter pub get`.**
  `implementation_feasibility: MEDIUM` rests on reasoning, not a green build. Accepted as the lane states it.
- **Any Docker or Compose command whatsoever** — not `info`, `ps`, `logs`, `config`, or any mutating one.
  **None issued. No breach.** I did not start a database and needed none.
- **The keys lane's artifacts, the ADR-0018 amendment artifacts, `WORK_STATE.md`, `LANES.md`.** I read the
  two `.decisions/` files only to confirm status and one verbatim quote.
- **The nine settled items** — B2/N1, B4/N2, N4/G9, N6, N10, B3, the N-1 no-Cancel rule, **D-8**,
  **SC-9's scoping call** — and **all fourteen resolved decisions beyond confirming RESOLVED** and
  reading the five load-bearing ones. **None re-raised.**
- **A full layer-by-layer walk of the six Add Product boards.** I read the footer band, the `Trust *`
  names and the top-level counts — the same bound the producer declared. Not more.
- **The lost rev-4 design-review report** authorising an earlier merge. It is not mine to recover.
- **Re-deriving the 6-site scope of G-7.** I accepted the reviewer's classification and checked only that
  site 7 exists and is recorded.
- **Whether the `21 of 21` post-fast-forward comparison happened.** The backup is gone; I recorded it as
  not-replayable and checked the arithmetic instead.

---

## 11. SAFE_PARALLEL_WORK

**SAFE**

- **Persisting and merging revision 6** — after MR6-1 and MR6-2, which are two one-line in-place record
  fixes. The design content needs no further pass.
- **N6a / G-7 (REQUIRED security change)** — disjoint paths, and now **correctly specified**: work all
  **seven** sites, including `apps/server/lib/src/services/ui_view_mappers.dart:176`, and **leave the
  `platform_contracts` / `product_credential` / persistence-layer occurrences alone** — `9417f8bf:167`
  keeps them deliberately. This is the highest-value item in the work item: under A3 the two
  `product_detail_page.dart` render sites are currently showing vault topology to users.
- **The keys lane's independent review** — disjoint paths; its R.11g numbers were re-verified here.
- **Non-UI implementation prep on `add_product_page.dart`** — custody string at `:542` **and** `:1038`
  (D-4), `note: null` at `:317` and `:926`, `_buildFooter` deletion (`:375` / `:314`) (D-3). Every number
  re-read by me at the reviewed head and unchanged since `16cd497`.
- **ADR 0018's A2 amendment** recording the `9417f8bf` supersession.
- **The Manager assigning the two board owners this cycle**, as the rev-5 reviewer recommended and this
  lane endorses: **N6b** (a grant over the four `S` boards) and **N6c** (a grant over two new ones).
  **Neither needs a human decision.** Both block implementation.

**PROHIBITED**

- **Any lane editing the four `S` boards, the `BPM` boards, or the four `SM` boards** — including any
  lane tempted to "helpfully" delete the F6 `Footer` layer. **No lane holds that grant.** This is the
  single most likely accidental breach in the next cycle, because the fix is a one-click delete and the
  decision is RESOLVED and unambiguous. **It is still not authorised.**
- **Any edit to `.decisions/**`** — including appending a note about F6. `27ea6536` has already been
  given its G-19 scope note; it does not need another.
- **Authoring the refused-mint surface on the Unknown-host board** — forbidden by R.11g item 5.
- **"Helping" with G-7** by also stripping `referenceName` from `platform_contracts` /
  `product_credential` / the persistence layer.
- **Building the N11 stale-anchor checker** by any lane without tooling ownership — reported, not built.
  The executable form of `N11` should anchor identifiers (§8 obs. 3), not substring-match them.
- **A Design Contract freeze of revision 6** — two ownership blockers are open and this pass closed
  neither.

---

## 12. Judgement

**This is a well-executed record-only pass, and it is the rare one in this work item whose claims all
reproduce.** I set out to disbelieve it and could not. The suffix count is right and I re-measured it
live. The four-plus-sixteen split is right and I traced the 4 to the record that supports it. The brief's
SC-7 now records the blocker as a blocker and sends the reader to the section that can answer it. G-7's
site table now names the file that breaks the build. The line-movement account is exact to the line and
reproducible from `git diff` in one command — including the three edits re-shaped to hold line counts
constant, which is the right engineering answer and not merely a documented one. The pre-flight was done
properly: compared before forcing, backed up, then fast-forwarded, and I reproduced **14/14** myself.
The near-miss was caught by parsing, not by looking, and the same parsing pass showed that the revision-4
defect the dispatch asked about was **already recorded twice at revision 5** — so the dispatch's premise
was wrong, and the lane's record is more complete than the question assumed. Risk 3 carried, gate
discharged and not re-opened, `NOT_VERIFIABLE` correctly declined with the epistemic boundary published.

**Two findings, both one-line fixes to the record.** A report that says it persisted to a path where
nothing exists, in the one area this work item has already lost three times — with the substance safe on
disk, so nothing is actually at risk today. And a wrong finding number in the paragraph explaining the
one number this pass exists to correct, in the same wrong-reference class as two of the findings it
closed. **Neither touches a board, a string, a geometry, a token, a requirement or a decision.**

**And to answer the dispatch's real question plainly: the boards need no change because of revision 6 —
none. The one board change outstanding in this work item is F6, and it is not this revision's, it is not
authorized, and it needs a grant from the Manager. `BPM`'s identical false custody string and false
eyebrow (F5) sit beside it, equally unowned. I have confirmed both, absorbed neither, and fixed neither,
and I would not have edited a board I do not own if it were easier to close a finding.**

**Risk level 3, agreed. Gate discharge independently verified. No human decision is needed and none is
requested.** The two things that block implementation both need an **ownership grant**, and neither is a
design question.

---

## 13. Disclosure — uncommitted modified PNGs in `apps/control_plane/test/failures/` are NOT mine

`git status` at the reviewed head shows **48 modified files** under
`apps/control_plane/test/failures/` (`*_diff.png`, `*_masterImage.png`, `*_testImage.png` for the
mobile and desktop golden-baseline sets), plus a `melos_shipit_platform.iml` modification.

**These were already modified before this lane began.** My first command in this session was
`git status --porcelain=v1`, and it listed exactly these 48 paths before I had read a single artifact or
issued a single git write. **I did not cause them, and I did not modify them.** I am disclosing them
because a later reader diffing `git status` will see production-tree modifications in a read-only review
lane and reasonably suspect a breach — and because this repository's rule is that a lane discloses
immediately rather than letting a worse-looking report stand.

I did **not** investigate their origin: that is not mine to determine, no board was involved, and
`AGENTS.md` is explicit that reading a compose file as text is the supported way to establish what a
stack does. **No Docker or Compose command of any kind was issued by this lane, including read-only
ones.** My only writes in this entire session were `docs/engineering/dispatch/tasks/design-rereview-mobile-rev6/report.md`.

**The report above is on disk and UNCOMMITTED.** I am read-only in git and did not commit, per the
dispatch. **The Manager should commit it** — three reports have already been lost in this work item, and
this one is verified present and intact at 42 KB / 591 lines.
