# Subtask Prompt — design-correct-addproduct-keys-6 (revision 6, 1 BLOCKER)

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: design-correct-addproduct-keys-6
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — server-side deploy-key service, Design Revision 6
WORKTREE: /private/tmp/shipit-correct-addproduct-keys
BRANCH: design-correct-addproduct-keys
BASE_SHA: 1c3f5ad
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**
READ_ONLY_PATHS:
  - apps/**, packages/**, docs/adr/**, docs/engineering/**, AGENTS.md, .decisions/**
PROHIBITED_PATHS:
  - apps/**, packages/**            (production source — you design it, you do not write it)
  - docker/**, .github/**
  - .decisions/**, WORK_STATE.md, LANES.md
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**      (mobile lane)
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/**    (ADR lane)
  - docs/engineering/dispatch/tasks/design-review-*/**              (reviewers)
  - EVERY Penpot board — you have NO board ownership in this pass. See §F6.
ACCEPTANCE_CRITERIA: |
  Design Revision 6 closing B-R5-1 and M-R5-1..M-R5-4 and L-R5-1..L-R5-3 from the first review of
  revision 5.
VALIDATION_COMMANDS:
  - cd /private/tmp/shipit-correct-addproduct-keys && git rev-parse --short HEAD
ROUTING_CLASS: PRECISION
```

## Isolation pre-flight

```bash
cd /private/tmp/shipit-correct-addproduct-keys
git branch --show-current    # design-correct-addproduct-keys
git merge --ff-only 1c3f5ad
git rev-parse HEAD
```

Revision 5's artifacts are **committed on `main` now** (`16cd497`). Your worktree is behind; fast-forward
first, then correct. **Do not leave revision 5 uncommitted again** — its review had to be re-verified
against a commit that did not exist.

## The finding set

`docs/engineering/dispatch/tasks/design-review-addproduct-keys-rev5/report.md`

```
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
REVISION_ID: 7C1E4A96-2B58-4D3F-A0C7-5E19D28B4F63
BLOCKERS: B-R5-1        HIGH: none
MEDIUM: M-R5-1, M-R5-2, M-R5-3, M-R5-4        LOW: L-R5-1, L-R5-2, L-R5-3
CORRECTION_REQUIRED: YES      HUMAN_DECISION_REQUIRED: NO
TRACEABILITY_GAPS: none — the defect is NOT traceability but the ABSENCE of one register entry.
```

Read § 3 (B-R5-1) in full before writing. **The reviewer's verdict is that this is the smallest and
cleanest correction in the work item: "the correction is small and I have made it actionable below."**
It states the footer spec is right, the three build edits are right, and `design_primitives.dart:396`
is right. **Do not redesign anything.**

### B-R5-1, the four required parts

1. Add gap-register entry **`G-18`** in **both** § R.18.2 and `requirements_gaps` — *"the four desktop
   `S` boards carry a `Footer` text layer at 236,862 carrying the code's copy string, so `27ea6536`'s
   desktop clause 'No footer copy' is not satisfied on the boards that decision declares authoritative."*
2. Add a § 10.1 Manager action assigning the four-board edit an owner.
3. Amend § R.11g item 7 so the *"boards are authoritative"* sentence is not asserted against a board that
   contradicts the spec, and state the required board edit alongside the three code edits.
4. Register the parallel defect as **`G-19`** (or fold into G-17's class): `27ea6536`'s own
   `supersedes_design_lane_reading` carries a **demonstrably false factual claim** — it calls the
   `(236,862)` reading *"a misidentification"*, and two independent reviewers have since measured a
   `Footer` **text** layer at exactly that coordinate. **Same class as G-17: a decision record denying a
   thing that exists.** Owner: ADR/decision owner. **Not a re-opening — the outcome stands untouched;
   only the record's factual basis is wrong.**

### §F6 — ownership decisions the Manager has made, so you do not stall on them

- **The four-board edit is NOT yours and NOT the mobile lane's.** Both lanes have the `S -`/`DESKTOP -`
  and `BPM -` boards in `PROHIBITED_PATHS`. **Penpot has no board-ownership grant for anyone.**
- **I have granted the four parts above as record corrections inside your own artifacts.** Apply them.
- **G-19's target is `.decisions/27ea6536…`, which is Manager-owned and PROHIBITED to you.** Do not
  write it. Register the gap; **I apply the record fix.** Be precise about what needs changing: the
  `supersedes_design_lane_reading` block's *outcome* stands and the decision is **not** re-opened — only
  its factual basis is wrong.
- **Do not ask the human to re-decide the footer.** `27ea6536` is RESOLVED and its outcome is not in
  question. What is in question is a **measured conflict with a recorded human check**, which I own and
  am escalating separately. **Record it; do not resolve it.**

### Two of its findings you must check before applying

- **M-R5-3** — the finding set is counted **19 findings and 5 MEDIUM, not 18 and 4**, visible from rev 5's
  own enumeration three lines under a heading that says eighteen. **Rev 5's § 0.7 `PROVENANCE_GAP` is
  stale at the reviewed HEAD** (M-R5-4): `289f1d3` **is** the commit that persisted the rev-4 report, so
  the gap the reviewer was asked to reconcile **no longer exists**. Both reviewers already did that
  reconciliation — do it too, and record that it is done.
- **§ 0.4's L8 and M5 rows are wrong** (M-R5-1, M-R5-2): L8 still states the inversion revision 5
  corrected in the body, and M5 both mis-states the uncommitted status and points at a § 10.1 action that
  was **withdrawn and replaced by 1a/1b**. **§ 0.4 is the correction map § 10.2 tells reviewers to
  trust — fix it as a full sweep, not a two-line patch.** The rev-5 reviewer warned that the two rows it
  spot-checked were *both* wrong.

## What the reviewer verified — do not re-verify

- **B5 / the ADR acceptance is real and cited accurately.** `.decisions/876c6b97` is RESOLVED/OPTION_A;
  amendment rev-2's metadata fields (`ACCEPTED`, `approved_by` populated, `reviewed_by: null`,
  `acceptance_is_not_review: true`, `human_gate.required: false`, `blocking_items: []`) are exact. **No
  surviving bare "Accepted".** The rev-5 self-downgrade to **0 IMPROVED / 2 UNCHANGED / 4 WORSE** is
  honest. **G-17 is real**: `876c6b97` landed in the same commit (`5436a4d`) that wrote ADR 0018's
  denial of its own existence.
- **D-3 is confirmed** — desktop `note:` at `:317-319`, mobile `note:` at `:926-928`, `_buildFooter` at
  `:375`. **Three edits, not two.** Rev 5's body is right; **§ 0.4's L8 row still carries the inversion.**
- **`design_primitives.dart:396`** paints the `ContentRule` unconditionally and `:402-410` renders
  `Row[Expanded(note ?? SizedBox.shrink()), InlineLink]` — the desktop spec falls out of `note: null` for
  free and **mobile's is genuinely not expressible today.** Do not re-derive.
- Risk level **3**, independently re-derived, agreement YES.
- The reviewer found **nothing wrong with the design's content about the key flow.**

## Also settled — do not re-open

Nine Human Decisions are RESOLVED: `9417f8bf` **OPTION_C / A3**, `898b07d0` **OPTION_A**, `ae1c1f79`
**OPTION_A**, `27ea6536`, `7b1bc8b7`, `79e860e2`, `4d2c6b81`, `b869ec24`, `876c6b97`.

**`9417f8bf` and `876c6b97` now carry appended, dated scope notes** (Manager-applied at `1c3f5ad`).
They record that *"never holds key bytes"* is true only in the **storage** dimension — at transport time
SHIP IT must materialise the private half in process memory — and that the absolute appears at **four**
sites, `9417f8bf:140` being the load-bearing uniqueness argument. **The decisions are not re-opened and
no accepted-risk count changed.** Cite them at their scoped reading.

`design-revision-3.md` is **no longer an untracked file** — it exists and is committed on `main`. Rev 5
supersedes it.

## Hard rules

- **Run NO Docker or Compose command whatsoever** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has ALREADY lost a QA database to a lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`.** Do not test this rule.
- **You have NO Penpot board ownership in this pass.** Do not read, edit, rename or delete any board.
  Cite the measurement; do not attempt to reproduce it.
- No production source. No `.decisions/**`. Do not edit the mobile lane's or ADR lane's directories.
- Do not commit or push. **Leave revision 6 in your worktree with revision 5 committed underneath it.**
- Do not approve your own work.
- **PERSIST YOUR FULL REPORT TO DISK** before returning, with the `RESULT:` block verbatim from
  `.agents/agents/design-agent.md`. **A review report has been lost three times in this work item.**
- **This work item has a documented history of a lane accepting a Manager premise that turned out false**
  and of an artifact being declared absent on one grep. **Search the domain's own vocabulary** — the word
  is `credential`, not `deployKey`; the ADRs are in `docs/adr/`, not `docs/engineering/adr/`. Verify a
  path exists before trusting an UNCHANGED result.
- Every result carries exact provenance.

## Report format

```
RESULT: DESIGN_REVISION_COMPLETE | DESIGN_REVISION_BLOCKED
```

Include `RISK_LEVEL` with rationale; per-finding disposition for B-R5-1 and M-R5-1..M-R5-4 and
L-R5-1..L-R5-3; **the exact record fix `.decisions/27ea6536…` needs** (G-19) for me to apply; and
confirmation that you touched no Penpot board.