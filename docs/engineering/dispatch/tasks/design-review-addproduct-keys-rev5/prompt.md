# Subtask Prompt — design-review-addproduct-keys-rev5 (first review of revision 5)

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: design-review-addproduct-keys-rev5
TASK_TYPE: design-review
FEATURE: Add Product rebuild — server-side deploy-key service, Design Revision 5 (7C1E4A96)
AREA: Independent, read-only design review of the keys revision 5 artifact set
WORKTREE: read-only; inspect the canonical checkout at /Users/alkebut/air/shipit-platform
         plus the producing worktree /private/tmp/shipit-correct-addproduct-keys (uncommitted)
BRANCH: design-correct-addproduct-keys @ 5436a4d (producing worktree is AHEAD OF ITS BASE — see below)
BASE_SHA: 43d328b
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-review-addproduct-keys-rev5/**   (your report, read-only review)
READ_ONLY_PATHS: everything else — you read, you never edit
PROHIBITED_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**   (the artifacts under review)
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**        (sibling lane)
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/**        (third lane)
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, docs/engineering/WORK_STATE.md, docs/engineering/dispatch/LANES.md
ACCEPTANCE_CRITERIA: |
  An independent verdict on Design Revision 5 (7C1E4A96), covering completeness, design-system
  compliance, UX/accessibility, IA integrity, implementation feasibility, and traceability — with
  every finding verified against source, not against the producer's claims.
VALIDATION_COMMANDS:
  - cd /Users/alkebut/air/shipit-platform && git rev-parse --short HEAD    # 289f1d3
ROUTING_CLASS: PRECISION
```

## CRITICAL — where revision 5 actually lives

Revision 5 is **NOT committed.** The producing worktree
`/private/tmp/shipit-correct-addproduct-keys`, branch `design-correct-addproduct-keys`, HEAD `5436a4d`,
has **19 uncommitted/untracked** files. `design-revision-5.md`, `design-revision-metadata-5.yaml`,
`traceability-matrix-5.md` and `report-revision-5.md` are among them.

**The Manager has copied the entire artifact set to the canonical checkout at
`docs/engineering/dispatch/tasks/design-addproduct-keyservice/`. Review the canonical copies** — they
are byte-identical to the producing worktree, verified by `diff -q` at copy time. You may read the
producing worktree to confirm provenance, but do not review a stale worktree state.

`main` = `289f1d3`. `5436a4d` is **not** an ancestor of `289f1d3` — the branch was never rebased. Record
that as a provenance observation if you judge it material.

## What is new since the last review

Revision 4 (`F2D5AF31-…`) was returned `DESIGN_REVIEW_CHANGES_REQUIRED` with **2 BLOCKERS, 3 HIGH,
4 MEDIUM, 9 LOW**. That review report was **lost from disk** before the correction lane was dispatched
and was only recovered afterwards — it now exists at
`docs/engineering/dispatch/tasks/design-review-addproduct-keys-rev4/report.md`.
**Read it first.** It is the finding set revision 5 claims to close.

Revision 5 claims **all 18 rev-4 findings applied**, `RISK_LEVEL: 3`, and — the thing most worth your
scrutiny — **republished its risk tally as `0 IMPROVED / 2 UNCHANGED / 4 WORSE`**, withdrawing rev 4's
single IMPROVED leg because it rested on an ADR acceptance that was never on the record.

**That self-downgrade is a point in the producer's favour, not against it.** Verify it honestly rather
than looking for the opposite.

## The two findings you must judge most carefully

**B5 — the ADR acceptance.** Rev 4 asserted human acceptance of the ADR 0018 A2 amendment in at least
thirteen places; no `.decisions/` object recorded one. **That has now changed:**
`.decisions/876c6b97-3e23-459d-aa9d-3a5faeb33702.yaml` exists on `main` and **RESOLVES** the ADR
acceptance (OPTION_A, "Is ADR 0018 amendment A2 accepted, with its four knowingly-open gaps accepted").
Confirm revision 5 cites it accurately and that no unrecorded acceptance is still claimed anywhere.

**D-3 — a cross-lane defect this lane previously got wrong.** R.11g item 7 claimed mobile's
`TechnicalDetails` has no `note:`. That is **false**:
`apps/control_plane/lib/features/products/add_product_page.dart:317-319` (desktop) and `:926-928`
(mobile) **both** pass a note. "No footer copy" is therefore **two `note:` sites**, plus deleting
`_buildFooter` (`:375`, carrying the `:383` copy). The sibling mobile lane has now measured this
independently and agrees. **Verify it yourself and check revision 5 carries the correction.**

## Coupled: the human's footer ruling

`27ea6536` is **RESOLVED** and its `rationale` is normative:

> - **Desktop** (`S - Add Product · …`): a divider, and a **right-aligned** `Show technical details`
>   text button. **No footer copy.**
> - **Mobile** (`BPM - Add Product · Light/Dark`): `Show technical details` **left-aligned, with no
>   divider**. **No footer copy.**

The sibling mobile lane has established (revision 5, D-8) that `SM` and `BPM` are two **states** of one
mobile design, and that the mobile spec was **already satisfied** on all four `SM` boards — so H-1(b)
required no mobile board edit. Check revision 5 is consistent with that.

**One finding from the mobile lane you must weigh** — F6, raised as an ownership blocker, not a human
question: `27ea6536`'s desktop clause *"No footer copy"* is **not satisfied** on the four desktop `S`
boards. All four carry a **`Footer` text layer at exactly (236,862)**; the divider is at (236,**848**).
The decision itself calls those boards authoritative. **If you agree, say so and classify it** — it is a
real gap between a resolved human decision and the boards it governs, and no lane currently owns the fix.

## Hard rules

- **Run NO Docker or Compose command whatsoever** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has already lost a QA database to a `design-reviewer` lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`.** Do not test this rule.
- **Read-only.** Edit nothing except your own report directory.
- Do not approve the producer's work as the producer. You are independent.
- **PERSIST YOUR FULL REPORT TO DISK** at
  `docs/engineering/dispatch/tasks/design-review-addproduct-keys-rev5/report.md` before returning.
  **Two review reports were lost to a relay in this work item** and receiving lanes had to work from
  paraphrase. This one will not be the third.
- Verify every finding against source. **Three times in this work item a lane grepped one identifier and
  concluded an artifact was absent** — `deployKey` vs `credential` (the domain's word is `credential`,
  and a large existing contract/table/store/engine/16-test suite was wrongly declared non-existent);
  `docs/engineering/adr/` vs `docs/adr/` (**ADR 0018 exists**, 21 product ADRs, and the design had
  presented as open four things it had already decided); a centralised label vs a literal grep. **Search
  the domain's own vocabulary, not the requester's phrasing. If an identifier is cited, follow the
  citations.** Enumerate locations with `glob`, not `ls` on a guessed path.
- Every result carries exact provenance: reviewed HEAD, artifact paths, revision id.

## Report format

Report per `.agents/skills/aef-orchestrator/templates/subtask-report.md`, with the `RESULT:` block
verbatim from `.agents/agents/design-reviewer.md`:

```
RESULT: DESIGN_REVIEW_APPROVED | DESIGN_REVIEW_CHANGES_REQUIRED | DESIGN_REVIEW_HUMAN_DECISION_REQUIRED
```

Include `CORRECTION_REQUIRED`, `HUMAN_DECISION_REQUIRED`, `INDEPENDENT_RISK_LEVEL` and
`RISK_LEVEL_AGREEMENT`. If you publish findings, publish them with evidence, and state explicitly what
you did **not** review — a prior reviewer here did that well and it is the pattern to keep.

## Related open context (do not act on it, do not re-open it)

Nine Human Decisions are RESOLVED: `9417f8bf` (OPTION_C / **A3 external secret manager** — SHIP IT never
holds key bytes, only a reference), `898b07d0` (OPTION_A — split identity from registration),
`ae1c1f79` (OPTION_A — **a substrate refusal creates nothing**, so the precondition precedes any write),
`27ea6536`, `7b1bc8b7`, `79e860e2`, `4d2c6b81`, `b869ec24`, `876c6b97`. **Do not re-raise any of them.**