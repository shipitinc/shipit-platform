# Report — Independent Design Review, deploy-key Design Revision 5 (Gate D3)

Persisted per `aef-orchestrator` §14. Reviewer: fresh `design-reviewer`, read-only.
**REVIEWED_HEAD `289f1d3`** · **REVISION_ID `7C1E4A96-2B58-4D3F-A0C7-5E19D28B4F63`** ·
`RISK_LEVEL` claimed 3, independently 3.

```
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED

REVIEWED_HEAD: 289f1d3

REVISION_ID: 7C1E4A96-2B58-4D3F-A0C7-5E19D28B4F63

BLOCKERS: B-R5-1

HIGH: none

MEDIUM: M-R5-1, M-R5-2, M-R5-3, M-R5-4

LOW: L-R5-1, L-R5-2, L-R5-3

INDEPENDENT_RISK_LEVEL: 3
RISK_LEVEL_AGREEMENT: YES

TRACEABILITY_GAPS: none — every design element maps to a requirement, a resolved decision, a named
  architecture clause or an artifact at 5436a4d. § R.18.2 and `requirements_gaps` agree, including
  G-16 and G-17 in both registers. The defect is not traceability but the ABSENCE of one register
  entry (see B-R5-1).

CORRECTION_REQUIRED: YES

HUMAN_DECISION_REQUIRED: NO

HUMAN_DECISION_TYPE: DESIGN

SAFE_PARALLEL_WORK:
  - Implementation of G-11 (D-4 / D-5 / D-6, both tiers, eight columns) — § R.9 is untouched by
    every finding below and I verified its citations exactly.
  - G-13 step 3 + G-16 step 3a + T-L + SC-20 (§ R.14.1) — B6's remedy is fully specified and
    independently verified; no finding touches it. Ship G-16 first.
  - G-14 (§ R.11.2) — one method, no schema change; unaffected.
  - The retirement of the `repositoryId: productId` placeholder (§ 10.1 item 7).
  NOT SAFE while this correction runs: any board edit; the § R.11g footer consumption contract;
    § 0.4's correction map; anything that treats the four desktop `S` boards as conformant.
```

> **Persistence note.** This report is written to disk **before** being returned, at the path above,
> for the reason stated in the dispatch: two review reports were already lost to a relay in this work
> item. If you are reading a paraphrase of this review rather than this file, the receiving lane is
> working from second-hand evidence.

---

## 0. Provenance — what I actually reviewed

| | |
|---|---|
| Canonical checkout reviewed | `/Users/alkebut/air/shipit-platform`, branch `main`, **`git rev-parse --short HEAD` = `289f1d3`** |
| Artifacts reviewed (canonical copies) | `docs/engineering/dispatch/tasks/design-addproduct-keyservice/` — `design-revision-5.md` (3372 lines), `design-revision-metadata-5.yaml` (858), `traceability-matrix-5.md` (248), `report-revision-5.md` (587) |
| Producing worktree consulted for provenance only | `/private/tmp/shipit-correct-addproduct-keys`, `design-correct-addproduct-keys` @ `5436a4d`, 11 modified + 8 untracked = **19 files** |
| Finding set read first | `docs/engineering/dispatch/tasks/design-review-addproduct-keys-rev4/report.md` (123 lines) |
| Product ADRs read | `docs/adr/0018-per-product-git-credentials.md` (580 lines) — **in `docs/adr/`, not `docs/engineering/adr/`**, which holds only framework-distribution ADRs |
| Decisions read in full | `.decisions/876c6b97-…` (164 lines), `.decisions/27ea6536-…` (161 lines); status of all 14 decision objects checked |

**The Manager's byte-identical copy claim is VERIFIED.** `git hash-object` on all four artifacts is
identical in the canonical checkout and in the producing worktree:

```
fb99f9e216b10db655b673111062355e690d61fa  design-revision-5.md
bae3c019be3a28c2d9347944eacc8eca4ccecec6  design-revision-metadata-5.yaml
0778b37d567c25d60efd4a6fb2dbac316212334c  traceability-matrix-5.md
121273aee65c2e771f2cc3cf3be25f534fe09d14  report-revision-5.md
```

**L13's content pins are real and three of the four verify.** `design-revision-5.md`,
`traceability-matrix-5.md` and `report-revision-5.md` match the hashes the metadata records, exactly.
The fourth does not exist anywhere — see **L-R5-1**.

### A provenance correction to the dispatch itself

The dispatch states: *"`5436a4d` is **not** an ancestor of `289f1d3` — the branch was never rebased."*
**That is false.** `git merge-base --is-ancestor 5436a4d 289f1d3` succeeds; `git log` shows `5436a4d` is
the direct parent of `289f1d3`; and `git branch --contains 5436a4d` lists `main`. Rev 5's own § 0.3 /
§ 10.1 re-base story is therefore **better** than the dispatch says: the producing branch was fast-
forwarded onto `main` and `main` then advanced by exactly one commit (`289f1d3`) after it. Recorded as
**L-R5-2**; it is a ledger fix, not a defect in the artifact.

---

## 1. Verdict summary

Revision 5 is a **substantial and honest correction pass**, and its central self-downgrade is real. It
withdrew its own single IMPROVED leg because the acceptance that leg rested on was not on the record at
its base, and it did so in the same place it published the new tally. That is the opposite of the failure
mode B5 was raised about, and I verified the withdrawal against the amendment lane's own metadata
(`status: DRAFT`, `approved_by: null`, `reviewed_by: null`, `human_gate.required: true`,
`blocking_items: ["ADR 0018 status remains Proposed. This lane does not declare it Accepted."]`) — the
rev-4 finding was right and rev 5's correction is right.

**Both blockers are genuinely discharged on substance.** The citation discipline is not merely claimed; I
opened roughly twenty-five `file:line` references across five source files and **every one resolved
exactly**, including several that are load-bearing and easy to get wrong. The risk tally is byte-identical
in all three places, verified by grep. The gap registers agree. § 9.3's gate table is honest about
everything it did not run.

**What it does not clear is three things:** a real, verified, unowned gap between a resolved decision and
the boards that decision declares authoritative (**B-R5-1**), and two places where the correction map
that § 10.2 tells a reviewer to trust **contradicts the artifact it maps** (**M-R5-1**, **M-R5-2**) —
together with two provenance bookkeeping errors that the recovery of the rev-4 report has now made
checkable (**M-R5-3**, **M-R5-4**).

None of these touch the design's content about the key flow. The correction is small and I have made it
actionable below.

---

## 2. The three things I was told to weigh most carefully

### 2.1 B5 / the ADR acceptance — **CONFIRMED, and the withdrawal is honest**

`.decisions/876c6b97-3e23-459d-aa9d-3a5faeb33702.yaml` exists, is `type: ARCHITECTURE`, `status: RESOLVED`,
`selected_option: OPTION_A`, `decided_at: 2026-10-06T14:20:00Z`, `created_by: orchestrator-main`, and
records the owner's verbatim answer *"Accept A2, record the gaps as accepted."* Revision 5 cites it
**accurately** — I compared its § 0.2 table, § R.17.1, § 9.1 R6, the metadata `risk_rationale` R6 and
the changelog B5 entry field by field against the object, and every quoted attribute matches.

I then verified the second citation, the amendment revision 2 metadata, because rev 5's whole argument
for keeping R6 at UNCHANGED rather than moving it to IMPROVED rests on it:

```
design-adr-0018-amendment/design-revision-metadata-2.yaml
  :17   status: "ACCEPTED"
  :144  reviewed_by: null          :145  reviewed_at: null
  :151  approved_by: "repository owner (ADR owner, interactive structured question UI, …)"
  :152  approved_at: "2026-10-06"
  :184  acceptance_is_not_review: true
  :201-203  human_gate: { required: false, level: 3 }
  :212  blocking_items: []
```

Every one of rev 5's § 0.2 claims about that file is exact. **"Acceptance is not review" is stated where
it matters** — § 0.2, § R.17.1, the metadata's `acceptance_of_dependency_is_not_acceptance_of_this_design`,
§ 9.1 R6 and § 10.2 item 13 — and § 10.1 action 1a assigns the missing review to the independent design
reviewer, which is also what `876c6b97`'s own first follow-up action says. The producer did not claim
review it does not have.

**I searched for a surviving unrecorded acceptance and did not find one.** § 10.2 item 13's falsifier is
*"a bare 'Accepted' survives anywhere without a citation beside it"*. I enumerated every occurrence of
`[Aa]ccepted` in all four artifacts. Every instance is one of: (a) quoting Revision 4's claim and marking
it false at its base; (b) quoting ADR 0018's own Status line **with** `ADR:4` cited; (c) `"So: accepted,
yes. Reviewed, no."`; (d) `human-accepted` paired with `never independently reviewed` and a pointer to
§ R.17.1. **B5 is closed.**

**And G-17 is real and correctly reported.** `docs/adr/0018-per-product-git-credentials.md:16-21` reads
*"**no Human Decision object on disk records this acceptance** … the acceptance has no citable decision
id"*, and `:572-580` repeats it. `git log --diff-filter=A` confirms `876c6b97` was added by `5436a4d` —
**the same commit** that added those 434 lines of ADR text. So the ADR denies, in one file, the existence
of an object that landed in the same commit that wrote the denial. Rev 5 registered this as **G-17**,
routed it to § 10.1 action 1b, and did **not** edit `docs/adr/**` (correctly `PROHIBITED_PATHS`) or claim
to have done so. That is exactly right.

### 2.2 D-3 / R.11g item 7 — **CONFIRMED, and rev 5's correction is right in the body and wrong in the map**

**The finding is real.** `apps/control_plane/lib/features/products/add_product_page.dart`:

| | Desktop | Mobile |
|---|---|---|
| `TechnicalDetails` | `:316` (inside `_DesktopAddProduct`, `:276`) | `:925` (inside `_MobileAddProduct`, `:774`) |
| its `note:` | **`:317-319`** — *"Registering records the product. Nothing is governed until you approve a baseline."* | **`:926-928`** — the same string |
| `_buildFooter` | definition **`:375`**, call site **`:314`**, copy `:382-386` (literal `:383-384`) | not called |

So **"no footer copy" is two `note:` sites plus a `_buildFooter` — three edits**, exactly as the dispatch
and the sibling mobile lane state. Revision 4's claim that mobile's `TechnicalDetails` has no `note:` was
false, and rev 5 § R.11g item 7's eleven-row table (`:2397-2408`) reproduces all eleven locations
correctly. I checked every row.

**Rev 5 also corrected the reviewer, and it was right to.** The rev-4 report says *":925 is the desktop
one that does."* `:925` is inside `_MobileAddProduct`, class opened at `:774`. The reviewer's attribution
was inverted. Rev 5 says so at `:2414`, in the metadata changelog, and in the matrix — and, importantly,
concludes that only the *substance* of the finding survived (the mobile site exists and has a `note:`),
not the reviewer's *wording*. That is the correct handling.

**But the correction did not survive into § 0.4.** See **M-R5-1**.

### 2.3 F6 — the desktop board conformance gap. **CONFIRMED INDEPENDENTLY, BY ME, LIVE**

I reached Penpot from this session (read-only) and measured the footer band of all four desktop `S`
boards myself. I did not adopt the sibling lane's measurement.

```
S · Add Product · Unknown host · Dark / Verified · Dark / Unknown host · Light / Verified · Light
  ALL FOUR IDENTICAL IN THE FOOTER BAND:

  Footer Rule   rectangle  parentX 236  parentY 848   1020×1    <- the divider
  Footer        TEXT       parentX 236  parentY 862   1020×15   align: left
                "Your decision is recorded permanently. The same piece of work then continues
                 — nothing is restarted."
  Disclose      text       parentX 1036 parentY 862   220×15
                "Show technical details ▸"   right edge 1256 = 236 + 1020
```

Board inventory corroborates the sibling lane independently: 160 boards; the six named boards sit at the
recorded positions with the recorded child counts (`S` Unknown host 69/69, `S` Verified 65/65, `BPM` 36/36).

Clause by clause against `27ea6536`'s normative `rationale`:

| `27ea6536` desktop clause | Measured | Verdict |
|---|---|---|
| a divider | `Footer Rule`, 236,848, 1020×1, **all four** | **SATISFIED** |
| a **right-aligned** `Show technical details` text button | `Disclose` right edge 1256 = the content column's right edge | **SATISFIED** |
| **No footer copy** | a `Footer` **text** layer at 236,862 on **all four**, carrying the exact string from `add_product_page.dart:383-384` | **NOT SATISFIED** |

**F6 is real.** And it is stronger than a coordinate dispute: the `Footer` layer's characters are
byte-identical to `_buildFooter`'s copy string in the shipped Dart, which is what makes this the board's
rendering of the desktop footer's copy line rather than some other text a human could plausibly have
misread. `27ea6536`'s `supersedes_design_lane_reading` calls that coordinate reading *"a misidentification."*
It is not a misidentification; it is the same string the code renders.

I classified it as the sibling lane did — an **ownership blocker, not a human question** — for a reason I
want on the record: **I did not re-open `27ea6536`.** Its outcome is settled and unambiguous (no footer
copy on either platform; per-platform alignment; boards authoritative) and it already assigns `_buildFooter`
deletion to the implementer. Nothing about the outcome needs re-deciding. What is missing is an owner for
a four-board edit that `27ea6536`'s own OPTION_B predicted: *"editing the four existing desktop boards,
which no current lane owns."*

---

## 3. BLOCKERS

### B-R5-1 — The desktop board-conformance gap is real, unowned, and **absent from Revision 5's gap register and change list**

This is the finding I weigh most heavily after B6, because it is the one place where Revision 5 adopts an
**unverified premise in a normative section**, and it is the place the blocked sibling most needs.

§ R.11g item 7 (`:2388-2393`) states the footer spec and then rules:

> *"The human's instruction — 'Stay true to both designs in Penpot and in code' — governs, and **the
> boards are authoritative over both lanes' readings**."*

It then specifies the build change as **three edits** (`:2419-2420`, `:2464`) and stops. Consequence:

- Applying "the boards are authoritative" to a board that carries footer copy, against a spec quoted two
  paragraphs earlier that says no footer copy, **moves the build away from the authoritative artifact.**
- Rev 5 records **no** board-conformance requirement, **no** gap-register entry, and **no** Manager action
  for the four-board edit. `G-4`…`G-17` do not contain it; § 10.1 items 1–11 do not contain it; § 9.3 does
  not contain it. The strings `(236,862)`, `Footer Rule` and `NOT SATISFIED` appear **nowhere** in the
  artifact set (`rg` over `design-addproduct-keyservice/` — 27 hits on "footer", all of them about
  `_buildFooter`, the two `note:` sites and the `ContentRule`).
- Rev 5 § 10.1 action 6 tells the Manager to **notify** the sibling of item 7's corrected line numbers —
  i.e. to send the blocked lane toward the code change — while the boards it must match still carry the
  copy, and while the lane that discovered this (the sibling) is Penpot-blocked and cannot ask.

**Why BLOCKER and not HIGH.** The defect is in Revision 5's *coupling*, not in its reading of the
decision: the footer spec is right, the three edits are right, `design_primitives.dart:396` is right
(I confirmed `:396` paints the `ContentRule` unconditionally and `:402-410` renders
`Row[Expanded(note ?? SizedBox.shrink()), InlineLink]`, so the desktop spec falls out of `note: null` for
free and the mobile spec is genuinely not expressible today). But a gate that passes Revision 5 with this
omission ships a build that cannot match its own declared authority, and closes the work item with the
divergence owned by nobody. That is the definition of an unowned blocker.

**Attribution, stated honestly: the sibling mobile lane found this first, and I am not claiming it.**
Its `penpot-board-evidence.md` § 6.4 is where the measurement lives; I reproduced it independently
because the dispatch asked me to and because adopting a sibling's number is how this work item already
produced three false "artifact absent" conclusions.

**Required correction, in four parts:**
1. Add a gap-register entry — **`G-18`** — in **both** § R.18.2 and `requirements_gaps`: *"the four desktop
   `S` boards carry a `Footer` text layer at 236,862 carrying the code's copy string, so `27ea6536`'s
   desktop clause 'No footer copy' is not satisfied on the boards that decision declares authoritative."*
2. Add a § 10.1 Manager action assigning the four-board edit an owner (design-system owner per
   `27ea6536`'s OPTION_B), and note it is blocked on the Penpot instance binding.
3. Amend § R.11g item 7 so the "boards are authoritative" sentence is not asserted against a board that
   contradicts the spec, and state the required board edit alongside the three code edits.
4. Register the parallel defect: **`27ea6536`'s own record carries a demonstrably false factual claim**
   (`supersedes_design_lane_reading`: the `(236,862)` reading is *"a misidentification"*), in the same
   class as `G-17` — a decision record denying a thing that exists. Owner: ADR/decision owner. **Not a
   re-opening**: the outcome stands untouched; only the record's factual basis is wrong. Name it
   `G-19` or fold into `G-17`'s class.

---

## 4. MEDIUM

### M-R5-1 — § 0.4's L8 row states the inversion Revision 5 corrected. `design-revision-5.md:245`

```
| **L8** § R.11g item 7 inverts `_buildFooter`'s definition and call site | LOW | … **And the claim that
mobile's `TechnicalDetails` has no `note:` is false: `:925` is the DESKTOP one and it does.** Both `note:`
sites named. …
```

That is false. `:925` is the **mobile** site, inside `_MobileAddProduct` (class at `:774`). The artifact
says the opposite **three times elsewhere**:

- `design-revision-5.md:2414` — *"`:925` is inside `_MobileAddProduct`, so it is the **mobile** site, not
  the desktop one"*
- `design-revision-metadata-5.yaml:739-742` — *"the REVIEWER'S OWN ATTRIBUTION IS INVERTED, and I say so
  in the artifact"*
- `traceability-matrix-5.md:139` — *"The review's own attribution of `:925` to the desktop site is
  inverted and is said so"*

`:245` is the **only** surviving instance of the error, and it sits in § 0.4 — the table § 10.2 tells a
reviewer to use to confirm that each finding landed where it claims. A reviewer comparing Revision 4's
finding text against this row concludes the producer adopted the reviewer's inversion, which is the exact
reasoning error the dispatch warned about. It also means the artifact contradicts itself on a *user-of-the-
artifact* line about a *consumption contract a blocked lane is pointed at*.

**Fix:** change `:245` to match `:2414` — `:925` is the **mobile** site and it **does** carry a `note:` —
and while there, note that Revision 4's `_buildFooter` definition/call numbers were correct and preserved
(the metadata changelog L8 says so at `:747-748`; `:245` still repeats the reviewer's "inverts …" wording
in its Finding column).

### M-R5-2 — § 0.4's M5 row contradicts § 10.1 and the metadata. `design-revision-5.md:239`

```
| **M5** the amendment is not "not in `docs/adr/**`" | MEDIUM | … the amendment is an **in-place edit of
`docs/adr/0018-per-product-git-credentials.md`**, **uncommitted and unmerged** at this base · **§ 10.1**
action 1 re-worded to ***commit and land that edit*** · …
```

Both clauses are wrong, and the artifact itself says so elsewhere:

- *"uncommitted and unmerged **at this base**"* — its base **is** `5436a4d`, which is the commit
  *"docs(adr): record ADR 0018 A2 acceptance"*. It is committed and merged. The metadata's M5 entry
  (`:677-680`) says precisely this: *"the finding's premise was correct about the in-place edit and is
  superseded about uncommitted: main's 5436a4d is 'docs(adr): record ADR 0018 A2 acceptance'."*
- *"§ 10.1 action 1 re-worded to **commit and land that edit**"* — § 10.1 action 1 does not say that. It
  reads (`:3240-3247`) *"★ REPLACES Revision 4's 'merge the ADR amendment'"*, and the withdrawn-actions table
  (`:3236`) reads *"★ WITHDRAWN — the premise was false (M5) … There was never a merge to perform.
  Replaced by actions 1a and 1b below"*. **The action this row claims is where the correction landed has
  been withdrawn and replaced.** The row points a reader at a remediation that no longer exists.

**Why MEDIUM and not LOW:** § 0.4 is the correction map, and § 10.2's entire premise is that each finding
is now *"checkable — what to run and what would falsify it."* Two of its rows describe a state the body
contradicts. A map that is wrong about two of eighteen rows cannot be used as the index a reviewer is told
to check.

**Fix:** sweep **all eighteen rows of § 0.4** against the sections they name, not just `:239` and `:245`.
The two I found are the two I had reason to check; the others I did not verify row-by-row (see § 7).

### M-R5-3 — The finding set is counted wrong: it is **19 findings and 5 MEDIUM**, not 18 and 4

Revision 5 says *"2 BLOCKERS, 3 HIGH, 4 MEDIUM, 9 LOW"* in **five** places —
`design-revision-5.md:11`, `design-revision-metadata-5.yaml:8` and `:520`,
`traceability-matrix-5.md:119`, `report-revision-5.md:90` — and *"the **18** findings"* in **eight** places
(`design-revision-5.md:304`, `metadata:16/515/529/845`, `traceability-matrix-5.md:121`,
`report-revision-5.md:64/204/501`).

The correct count is **19**. The rev-4 review's own `RESULT:` block reads `MEDIUM: M3, M4, M5, M6, M7` —
**five** — and its section heading is `## M3–M7 and L5–L13`. 2 + 3 + 5 + 9 = 19.

**Revision 5 enumerates the nineteen itself, under a heading that says eighteen**, three lines apart:

```
design-revision-metadata-5.yaml:515
# 18 findings: B5, B6 (BLOCKERS); H8, H9, H10 (HIGH); M3, M4, M5, M6, M7 (MEDIUM);
#              L5, L6, L7, L8, L9, L10, L11, L12, L13 (LOW).
```

and `design-revision-5.md:304`: *"I took **18 findings** — B5, B6, H8, H9, H10, **M3–M7**, L5–L13"*.

This is visible **without** the rev-4 report, purely from the artifact's internal arithmetic — which
makes it the same class as H10 (a count wrong in five places) and L7 (the "verbatim" discipline), and it
is now externally checkable because the report is on disk.

**Credit where due:** `report-revision-5.md:90` is the one place that flags it honestly —
*"4 MEDIUM (M3, M4, M5, M6, M7 — **five named**)"*. It was not propagated.

**Fix:** change `18` → `19` and `4 MEDIUM` → `5 MEDIUM` in all thirteen locations, keeping
`report-revision-5.md:90`'s parenthetical.

### M-R5-4 — § 0.7 and the `PROVENANCE_GAP` blocker are stale at the reviewed HEAD

§ 0.7 (`:292-318`), § 9.3's last-but-one row, the metadata header (`:12-18`), `gates.rev4_review_report`,
`requirements_gaps`, the metadata's `blockers[0].type: PROVENANCE_GAP`, and § 10.1 action 11 all assert
that the rev-4 review report **does not exist in any worktree, in the canonical repository, or in any
commit reachable from any ref**.

**At Revision 5's base (`5436a4d`) that was true.** At the **reviewed HEAD (`289f1d3`)** it is false, and
falsely so: `289f1d3` is the commit *"docs(review): ADR amendment review; keys rev5; persist the rev4
review that never landed"* and it **adds** `design-review-addproduct-keys-rev4/report.md`. The report I was
told to read first exists at the very commit under review.

This is base-scoping, not dishonesty, and I record it as such. But as published the artifact tells a
reviewer the finding set of record does not exist, and instructs (*§ 0.7: "A reviewer **MUST** read the
actual report before approving"*) an action that is now impossible to take as written.

**Substance is safe — I did the reconciliation.** I read the recovered report and compared it against
Revision 5's § 0.4 correction map and the metadata changelog finding by finding: **B5, B6, H8, H9, H10,
M3, M4, M5, M6, M7, L5, L6, L7, L8, L9, L10, L11, L12, L13 are all present, all correctly described, and all
correctly corrected.** The producer's disclosed gap did real work: the two corrections it made *against
source rather than against the relay* (the `:925` inversion and `confirmHostKey :1006-1011` → `:1018-1025`)
are both corrections I independently confirmed are right.

**Fix:** add one line to § 0.7 — *"the report was recovered at `289f1d3`; its nineteen findings were
reconciled against § 0.4 line by line at that revision"* — and downgrade `blockers[0]` from an open
`PROVENANCE_GAP` to closed, with the count corrected per M-R5-3.

---

## 5. LOW

### L-R5-1 — L13's pin is incomplete for the metadata, and § 10.2 item 10's falsifier is unexecutable

`design-revision-metadata-5.yaml` hashes to `bae3c019be3a28c2d9347944eacc8eca4ccecec6`. **That string
appears nowhere in the repository** (`rg -rn "bae3c019"` → 0 matches). The metadata declares itself
self-excluded and says *"A FILE CANNOT CONTAIN ITS OWN HASH, so this file's own value is printed in
`report-revision-5.md`"* (`:206-209`, `:214`). It is not printed there: `report-revision-5.md:29` reads
`design-revision-metadata-5.yaml (pinned in the Manager-facing report)` — a document that does not exist
as a named artifact — and `:31` declares the report itself self-excluded. So the pointer is circular and
dangling, and the **unpinned** file is the one carrying `risk_level`, `gates`, `requirements_gaps` and the
`changelog`.

Compounding it, § 10.2 item 10's falsifier reads *"any artifact's blob hash differs from the metadata's
`artifacts[].blob_hash`"* — but only **one** of the four `artifacts[]` entries has a `blob_hash` key, and
its value is the pointer string `"RECORDED IN § 0.3 AND report-revision-5.md — see L13"`, not a hash.
`traceability-matrix-5.md:20-22`'s *"recorded **per artifact**"* is not literally true.

**Fix:** print the metadata's own hash in `report-revision-5.md` under the report's existing pin table
(a report written after the metadata can hold it — which is the whole reason the metadata points there),
and give all four `artifacts[]` entries a real `blob_hash`, or drop the field and restate § 10.2 item 10's
falsifier against `provenance.content_pins.this_revision`, which is where the hashes actually live.

### L-R5-2 — Provenance observation, owned by the Manager/ledger

The dispatch's claim that `5436a4d` is not an ancestor of `289f1d3` is false (§ 0 above). `5436a4d` **is**
`289f1d3`'s parent. No artifact correction needed; the dispatch text and any ledger row repeating it should
be corrected so the next lane does not re-derive a topology concern that does not exist.

### L-R5-3 — Board names in the consumption contract are imprecise, and the mobile citation names 2 of 4 conformant boards

§ R.11g item 7 (`:2388-2391`) cites the boards as `S - Add Product - Unknown host`, `S - Add Product -
Verified` and `BPM - Add Product`. The live file's names are `S · Add Product · Unknown host · Light` /
`· Dark`, `S · Add Product · Verified · Light` / `· Dark`, and `BPM · Add Product · Light` / `· Dark` — the
hyphenation comes from `27ea6536`'s `human_correction_verbatim`, not from the file, and the `· Light/Dark`
suffix is dropped everywhere.

More substantively: the sibling lane's evidence records that **all four `SM` boards** also satisfy the
mobile half, and that `SM` and `BPM` are **two states of one mobile design** (its D-8). Revision 5 names
only `BPM`, so the spec as written appears to govern two mobile boards when it governs four, and does not
reflect the two-states-one-design finding the dispatch asked me to check for consistency with. **There is
no substantive conflict** — the mobile lane reports the mobile spec as already met, and rev 5 asks for no
mobile board edit — but the citation is under-specified for a contract a blocked lane must consume.

**Fix:** cite the real board names with suffixes, and state that `SM` and `BPM` are two states of one
mobile design whose spec is already satisfied (naming the sibling lane's evidence file as the source, not
as authority).

---

## 6. Risk level — independently re-derived, 3, agreement YES

Per `DESIGN_GOVERNANCE.md:92-99`, Level 3 is *"Change to core workflow, navigation structure, or
information architecture affecting multiple features or user mental models"*, and requires
product/design/architecture human approval.

Reached **3 on IA grounds, independently and before reading the producer's rationale**:

1. `898b07d0` makes a `Product` visible **before** registration commits and turns registration into a
   commit — this changes what a Product *is* across the Products page, product detail and Add Product.
2. `RegistrationCommitState` introduces a **five-state client model**; § R.11.1 state 4 changes what the
   product detail page asserts, and is currently indistinguishable from state 1 (`G-14`).
3. § R.11g item 3 adds a **resume route from the product into the credential flow** — new IA, and without
   it `898b07d0`'s accepted consequence becomes a dead end.
4. First handling of key material by SHIP IT; irreversible from SHIP IT's side.
5. An SSH transport seam with no precedent carrying an ADR requirement that is **half-implemented**
   (`G-4`), on the credential path.
6. A credential-minting endpoint on a control plane `server.dart:71-73` declares **no authentication for**.

**INDEPENDENT_RISK_LEVEL: 3. RISK_LEVEL_AGREEMENT: YES** — on the level, on the re-derivation discipline,
and on the tally. I checked the tally by grep in all three places: the sentence *"0 reasons IMPROVED,
2 reasons UNCHANGED (R1, R6), 4 reasons WORSE (R2, R3, R4, R5)"* is present **once** in each of
`design-revision-5.md` § 9.1 (`:3089`), `design-revision-metadata-5.yaml` (`:131`) and
`report-revision-5.md` (`:159`), identically; Revision 4's superseded sentence is printed beside it and named
as withdrawn in all three; and no fourth tally exists. **L7 is discharged, and H6's discipline held.**

**Recorded explicitly, because a binary field cannot carry it:** I agree with the level and with the
*direction* of the self-downgrade, and I found no reason to hunt for the opposite. The producer withdrew a
tally leg that flattered it, kept the leg's underlying fact visible, and added two further reasons against
itself (the amendment's revision-1 factual error; acceptance-is-not-review). R6's UNCHANGED status rests on
three stated grounds and all three check out against source — I verified `rotateCredential` revokes first
(`engine:1116`) before `recordGeneratedCredential` (`engine:1122`), which is the fact that makes the
amendment's revision-1 index claim wrong and makes `D-4`, not `D-2`, the thing that closes A1.

---

## 7. What I verified, and what I did NOT review

### Verified against source (not against the producer's claims)

- **Provenance / L13:** canonical-vs-worktree byte identity (4/4); the three recorded content pins; the
  ancestry of `5436a4d`; `5436a4d` as the parent of `289f1d3`.
- **B5:** `.decisions/876c6b97` read in full; every attribute rev 5 quotes about it; every attribute rev 5
  quotes about amendment revision 2's metadata; the exhaustive search for a surviving bare "Accepted".
- **G-17:** `ADR:16-21` and `:572-580` read; `git log --diff-filter=A` confirming `876c6b97` landed in the
  same commit as that ADR text; `ADR:4` Status line; `## Accepted risks` at `:446` → `## Known gaps` at
  `:525`, so `:446-524` is exact.
- **B6 / G-16 / G-13:** `engine:1135-1142` (`_ensureOwned` at `:1140`, then the store call),
  `engine:150-170` (`readProduct` at `:159`, "existence + scope", never `_ensureOwned`), `engine:176-183`
  (`_ensureOwned` at `:181`), `engine:1784-1790` (`CrossProductAccessException`), `store:370-381`
  (no product notion, `status <> 'revoked'`), `store:136-142` (**`"productId" = EXCLUDED."productId"` at
  `:137`** — the reparenting hazard is real), `store:92-100` (`name :93` … `version :99`),
  `in_memory:221-232`, `in_memory:236-238` (**bare `where().toList()`, no ordering**).
  **B6's substance is confirmed and Revision 5's step 3a is a correct and complete remedy.**
- **H8:** `add_product_page.dart` — the two `note:` sites, `_buildFooter` at `:375/:314/:383-384`, the
  duplicated `ContentRule` at `:380` and `:300`, `_MobileAddProduct` at `:774`, file length 1117. All
  eleven rows of § R.11g item 7's table verified individually.
- **H9:** `definition.sql:632` is exactly `"lastFailureReason" text,` (nullable) — verified in
  `migrations/20261006150645000/definition.sql`.
- **M3:** `repository_credential_view.yaml:8-25` carries the 14 fields rev 5 lists and **neither**
  `revokedAt` **nor** `revokedReason`. Confirmed.
- **M4 / M7:** `store:389` is exactly `'ORDER BY "createdAt" ASC'`; `in_memory:236-238` has no ordering;
  `engine:977` is exactly `version: 1`; `engine:1105` declares `String? credentialId`; `engine:1129`
  forwards it verbatim; `engine:1116` revokes first.
- **L10:** `postgres_product_registry_store.dart:306-320` is the comment rev 5 says is truncated;
  `:312-319` is the paragraph the § 10.2 item 14 check targets, and the trailing `rotateCredential`
  sentence the reviewer's blockquote deleted is at `:319-320`.
- **Design-system claim:** `design_primitives.dart:396` paints `TechnicalDetails`' `ContentRule`
  unconditionally and `:402-410` renders `Row[Expanded(note ?? SizedBox.shrink()), InlineLink]`. The
  desktop spec is free from `note: null`; the mobile spec is genuinely not expressible today.
- **Traceability:** § R.18.2 carries G-3…G-17; `requirements_gaps` carries the same set. `G-16` and `G-17`
  are in **both** registers. § 10.2 item 12 passes.
- **F6:** measured myself, live, read-only, on all four desktop `S` boards (see § 2.3).
- **Decisions:** all 14 `.decisions/` objects are `RESOLVED`; the nine named by the dispatch are all
  RESOLVED. **None re-opened.**
- **Discipline claims:** the tally's byte-identity in three places; § 9.3's `NOT_RUN` table is consistent
  with what the artifact claims and with the metadata's `gates` block.

### NOT reviewed — stated explicitly

- **I ran no Docker or Compose command of any kind** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **No database was started, created, queried or touched.** This repository has already
  lost its QA database to a design-reviewer lane; I did not test whether that had been remediated, because
  testing it is the forbidden act. Compose files were not read either.
- **I ran no gate.** No `dart analyze`, no `flutter analyze`, no build, no `dart test`, no
  `make test-integration`, no contrast measurement. Every `NOT_RUN` in § 9.3 remains `NOT_RUN` as far as I
  am concerned.
- **I did not verify all 22 rows of § 0.3's citation index exhaustively.** I spot-checked ~25 `file:line`
  citations across five source files, chosen for load-bearing-ness. Every one resolved exactly. A
  different sample could differ; I did not find any error and I did not prove there are none.
- **I did not verify § 0.4's eighteen rows one by one against the body.** I checked the two I had reason to
  check (M5, L8) and **both are wrong**. Other rows may be too. M-R5-2's fix is a full sweep, not a
  two-row patch, precisely because I cannot certify the rest.
- **I did not verify § 0.3's ADR re-anchoring table.** Its `:NN` numbers are explicitly A1-revision
  numbers, not current-base line numbers; checking them means adjudicating the amendment, which is
  `PROHIBITED_PATHS` here and is § 10.1 action 1a.
- **I did not review the design content of the ADR amendment** (`design-adr-0018-amendment/design-revision-2.md`),
  the mobile lane's Design Revision 5, or Revisions 1–4's bodies below their supersession banners. I read
  the amendment's *metadata* only for the fields rev 5 cites, and the mobile lane's
  `penpot-board-evidence.md` § 6.4 only as a claim to reproduce.
- **I did not adjudicate the four desktop boards as a design.** `C-11` is the mobile lane's. I read the
  footer band read-only to test F6 and made no edit, no move and no rename.
- **I did not verify `G-3` (zero tests import `add_product_page.dart`), `G-4`'s five-token grep, `G-10`
  (A3 reachability), `G-12` (the duplicate audit), or any `docker/compose.yaml` line.** None is load-bearing
  for any finding above.
- **I did not re-open any of the nine resolved decisions**, and I did not treat F6 as grounds to do so.
- **I did not review the sibling mobile lane's D-8 claim** that `SM` and `BPM` are two states of one
  mobile design; I took its board inventory as corroboration for F6 and recorded the SM-board omission
  (L-R5-3) as a citation gap, not as a challenge to that lane.

---

## 8. What the correction lane has to do, in order

1. **`G-18`** (B-R5-1, parts 1–3): register the desktop board-conformance gap in § R.18.2 **and**
   `requirements_gaps`; amend § R.11g item 7 so the "boards are authoritative" rule is not asserted against
   boards that contradict the spec; state the four-board edit alongside the three code edits.
2. **`G-19`** (B-R5-1, part 4): register that `27ea6536`'s record carries a false factual claim about its
   own authority basis — the same class as `G-17`. Owner: ADR/decision owner. **Do not re-open the
   decision**; its outcome stands.
3. **`:245`** (M-R5-1): fix § 0.4's L8 row to match `:2414`.
4. **`:239`** (M-R5-2): fix § 0.4's M5 row — it is committed and merged at this base, and § 10.1's old merge
   action is WITHDRAWN, replaced by 1a/1b. Then **sweep all eighteen § 0.4 rows** against the sections
   they name.
5. **Thirteen locations** (M-R5-3): `18` → `19`, `4 MEDIUM` → `5 MEDIUM`.
6. **§ 0.7 + `blockers[0]`** (M-R5-4): record that the rev-4 report was recovered at `289f1d3` and that its
   nineteen findings reconcile against § 0.4 line by line; downgrade `PROVENANCE_GAP` to closed.
7. **L-R5-1:** print the metadata's own blob hash in `report-revision-5.md`; give the `artifacts[]` entries
   real hashes or restate § 10.2 item 10's falsifier against `provenance.content_pins.this_revision`.
8. **L-R5-3:** correct the board names with `·` and `· Light/Dark`, and record that `SM` and `BPM` are two
   states of one design already satisfying the mobile spec.

None of items 1–8 requires re-opening a decision, editing `docs/adr/**`, or touching a board. None of them
touches § R.9, § R.14.1, § R.11.1/§ R.11.2 or the risk rationale — which is why `G-11`, `G-13`, `G-14` and
`G-16` can proceed in parallel.
