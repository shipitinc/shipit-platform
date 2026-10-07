# Subtask Prompt — design-rereview-mobile-rev6

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: design-rereview-mobile-rev6
TASK_TYPE: review            # focused re-review, read-only
FEATURE: Add Product rebuild — mobile Design Revision 6
WORKTREE: read-only; canonical checkout + live Penpot page "Page 1"
BASE_SHA: 1c3f5ad
HEAD_SHA: af8e30f
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-rereview-mobile-rev6/**   (your report)
READ_ONLY_PATHS: everything else, including every Penpot board
PROHIBITED_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**   (artifacts under review)
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/**
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, WORK_STATE.md, LANES.md
ACCEPTANCE_CRITERIA: |
  Focused re-review of revision 6 against MR5-1..MR5-7 and the three record corrections, plus
  regression risk. Revisions 1-5 were already independently approved in substance.
VALIDATION_COMMANDS:
  - cd /Users/alkebut/air/shipit-platform && git rev-parse --short HEAD    # af8e30f
ROUTING_CLASS: STANDARD
```

## Scope — this is FOCUSED. Do not re-review what rev 5's review already cleared

`docs/engineering/dispatch/tasks/design-review-addproduct-mobile-rev5/report.md` verified **essentially
everything live** and found the artifact set sound: the custody string, layer names, the 436→446 and
456→466 moves with 4px preserved slack, the two-line wrap inferred from layer height, `Trust Created`
containment, `Disclose` left-aligned at 16 with zero dividers and zero footer copy, inventory 160/164,
layer counts 44/44/36/36 and 29/29/24/24, `Register product` 1/2,1/2,1/1,1/1, all 13 M-1 numbers, all
three L-1 pointers, every source citation, and all ten contrast figures to 0.00. **All 15 artifacts were
independently checked byte-identical at copy time.**

Review only:
1. **MR5-1…MR5-7** — did the correction land correctly?
2. **The three record corrections** the rev-5 review required.
3. **Regression risk** from the edits — the lane reports **zero board writes**, so confirm that.

## The three record corrections — the substance of this pass

- **The suffix count.** Wrong in two of three published forms; **16 is correct**, proven by measuring
  exactly 8 unsuffixed `Trust *` layers on each Unknown board. The lane reports `7 ×` in two files and
  `17`/`Seventeen` in two more were wrong, that `design-revision-5.md:169` used *sixteen* correctly but
  named it as covering both markers, and that it split the population into **4 + 16 = 20**. **Verify the
  arithmetic and that all five published forms now agree.**
- **`design-brief.md` SC-7.** Was recording F6 as met while citing §6.3 (which is D-8) instead of §6.4,
  and F6 appeared nowhere in the brief. Now `MET on mobile · NOT MET on desktop (F6)`, citing §6.4, with
  F6/N6b greppable at `brief:98`.
- **G-7's site table.** Was missing `ui_view_mappers.dart:176`, the server-side view constructor that
  route N6a sends to the implementer. Now site 7 in rev-5 §6.1, N6a, metadata-5 and the matrix.

## Claims to press on

- **Line movement.** The lane states the corrections moved lines and published the migration rather than
  leaving it to be discovered: `rev-5.md:588 → :600` (+12) and `metadata-5.yaml:99 → :101` (+2), with every
  other cited anchor unmoved, and that it **re-shaped three of its own edits specifically to hold line
  counts constant.** **Verify a sample of those numbers and the "unmoved" claim** — cross-reference drift
  has been published as measured before in this work item.
- **Two of its own pre-flight claims.** `git merge --ff-only 16cd497` was *refused* because revision 5 was
  uncommitted; the lane compared all 14 artifacts to the copies at `16cd497` (**14/14 byte-identical**),
  backed up, fast-forwarded, re-compared (**21/21**) and retained a stash. **Verify that comparison and
  that the stash is intact.**
- **It says it nearly shipped a new defect (F8):** its first draft of `design-revision-metadata-6.yaml`
  had 2 of 7 fenced YAML blocks unparseable — **the same defect revision 4's metadata has** — caught by
  parsing rather than eyeballing. **Verify both metadata files parse, and check whether revision 4's
  metadata defect is still present and unrecorded.** That is a real question: a defect inherited from rev 4
  and left in place is not the same as one caught in a new draft.
- **It DECLINED the reviewer's `NOT_VERIFIABLE` alternative** on the suffix count, reasoning that the
  *before* state is unverifiable but the *end* state is not, so the right number beats no number. **Judge
  that judgement.**
- **`RISK_LEVEL: 3` carried**, with the lane arguing the *marginal* risk of a record-only pass is Level 0
  while the gate stays discharged. Check that is coherent and that the gate was not re-opened.

## Do NOT re-open

- **D-8 resolved** (`SM` and `BPM` are two states of one mobile design) · **every board claim already
  independently verified live** · **SC-9 is a correct scoping call**, carry it as a scoped gap, do not work
  around the boundary · **the Level-3 gate is discharged** (5 decisions RESOLVED) · **G-7's two UI render
  sites are production sites** — record and route, do not edit production source.

## F6 is open and owned by nobody — confirm, do not absorb

`27ea6536`'s desktop clause *"No footer copy"* is **not satisfied** on the four desktop `S` boards: a
`Footer` **text** layer at `(236,862)`, byte-identical to
`apps/control_plane/lib/features/products/add_product_page.dart:383-384`, with the divider at `(236,848)`.
Those boards are `PROHIBITED` to every lane. It is the **only BLOCKER in the keys rev-5 review** and is
now registered there as **`G-18`** with a design-system owner.

**It needs an ownership grant, not a re-decision.** Report it as open. **Do not fix it, and do not edit a
board you do not own.** `BPM` also carries the same false custody string and the now-false
`NOT REGISTERED YET` eyebrow.

## Hard rules

- **Run NO Docker or Compose command whatsoever** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has ALREADY lost its QA database to a `design-reviewer` lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`.** Do not test this rule.
- **READ-ONLY in Penpot.** Read what you need. **Edit, rename or delete nothing.**
- **READ-ONLY in git.** Edit nothing except your own report directory.
- **You are independent.** The producing lane explicitly declined to approve itself.
- **PERSIST YOUR FULL REPORT TO DISK** at `docs/engineering/dispatch/tasks/design-rereview-mobile-rev6/report.md`.
  **A review report has been lost three times in this work item.**
- **Search the domain's own vocabulary, not the requester's phrasing.** Three times in this work item a
  lane grepped one identifier and concluded an artifact was absent — and **the Manager did it himself
  last session**, stating a file was committed when a glob had matched a *different* lane's file of the
  same name. **Use `git log --all --diff-filter=A -- <exact path>`, and glob with the full path, never a
  basename.** Verify a path exists before trusting an UNCHANGED result.
- **State explicitly what you did NOT review.**

## Report format

Per `.agents/skills/aef-orchestrator/templates/subtask-report.md`, `RESULT:` block verbatim from
`.agents/agents/design-reviewer.md`:

```
RESULT: DESIGN_REVIEW_APPROVED | DESIGN_REVIEW_CHANGES_REQUIRED | DESIGN_REVIEW_HUMAN_DECISION_REQUIRED
```

Include `CORRECTION_REQUIRED`, `HUMAN_DECISION_REQUIRED`, `INDEPENDENT_RISK_LEVEL`,
`RISK_LEVEL_AGREEMENT`, and — because rev 6 is record-only — **whether the boards need any change at all**,
stated plainly.