# Subtask Prompt — design-approve-mobile-rev6 (final focused re-review — 0 open findings)

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: design-approve-mobile-rev6
TASK_TYPE: review            # focused re-review, read-only — NO correction lane needed
FEATURE: Add Product rebuild — mobile Design Revision 6, final pass
WORKTREE: read-only; canonical checkout (Penpot NOT required — see §1)
BASE_SHA: 1c3f5ad
HEAD_SHA: 762e5cd
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-approve-mobile-rev6/**   (your report)
READ_ONLY_PATHS: everything else
PROHIBITED_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**   (artifacts under review)
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/**
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, WORK_STATE.md, LANES.md
  - EVERY Penpot board
ACCEPTANCE_CRITERIA: |
  Confirm MR6-1 and MR6-2 are correctly closed and revision 6 is APPROVED for Design Contract
  freeze, or state precisely what remains.
VALIDATION_COMMANDS:
  - cd /Users/alkebut/air/shipit-platform && git rev-parse --short HEAD
ROUTING_CLASS: STANDARD
```

## §1 — PENPOT IS CURRENTLY DORMANT. You do not need it.

**The plugin tab is suspended** — `getPages()` returns *"no heartbeat for 42s"*. **Do not call any Penpot
tool.** This is a deliberate constraint, not an accident: the prior re-review of revision 6 **verified
every board claim live** and concluded **revision 6 needs NO board change**, and **that finding stands and
needs no re-verification.** Re-reading the boards would add nothing.

**If you judge a board claim MUST be re-verified, report it as a blocker naming the claim** — do not
attempt the call.

## Your finding set — already closed by the Manager

`docs/engineering/dispatch/tasks/design-rereview-mobile-rev6/report.md`

```
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
BLOCKERS: NONE    HIGH: NONE    MEDIUM: MR6-1    LOW: MR6-2 (+ 4 LOW needing no correction)
CORRECTION_REQUIRED: YES      RISK_LEVEL 3, agreement YES
```

**Both open findings were corrected by the Manager at `bd01bc0`:**

- **MR6-1 (MEDIUM)** — `correction-report-6.md:3-4` declared the report persisted at
  `design-correct-addproduct-mobile-6/report.md`. **That path never existed** — the directory holds
  `prompt.md` only. The substance was never at risk, since the report *is* that file and was committed at
  `1c3f5ad`; only the declaration was false, **in the one area where this work item has lost three
  reports.** Corrected in place with the finding cited, **not deleted**.
- **MR6-2 (LOW)** — `design-revision-6.md:77` credited MR5-6 with MR5-1's `NOT_VERIFIABLE` alternative.
  **MR5-6 is "SC-8 cites the wrong section"**; the `NOT_VERIFIABLE` option belongs to MR5-1. Corrected.

## Your job

1. **Verify both closures are correct and complete** — not merely present.
2. **Verify the corrections introduced no new error.** Two wrong-record findings in one pass, both in the
   *record* rather than the design, is the pattern this artifact set has shown repeatedly. **The prior
   re-reviewer also found the dispatch's own F8 premise was wrong** — revision 4's metadata defect was
   never unrecorded (recorded twice at revision 5); the real gap was narrower, and rev 6 closes it.
3. **Confirm no board change is needed.** The prior reviewer's evidence: inventory **160/164**,
   `SM` layer counts **44/44/36/36**, exactly **8 unsuffixed `Trust *` layers on each Unknown board and 0
   on Verified**, and the `S` footer band byte-identical. Accept this or name what you dispute.
4. **Give the verdict.** If revision 6 is clean, say `APPROVED` plainly — **this work item has produced
   two design artifacts in a row that could not reach approval, and the record corrections above are the
   entirety of what remains.** Do not manufacture a finding to justify a cycle.

## What the prior re-reviewer already verified — do not repeat

All seven findings MR5-1…MR5-7 landed exactly, every anchor read from the file rather than the report.
**16 is correct** — measured live, 8 × 2 — and the `4 + 16 = 20` split resolves because the 16 is an
end-state measurement while the **4** is record-derived from `rev-5:158-163` §3.2. **All six published
forms agree.** **Line movement is exact** — one +12 in `rev-5.md`, one +2 in `metadata-5.yaml`,
`:588→600`, `:643→655`, `:660→672`, `:671→683`, `:99→101` all confirmed, and **every "unmoved" claim
holds**, including three edits re-shaped to hold line counts constant. **14/14 byte-identical reproduced**
by sha256; **stash intact** at `1b0114d`. **`metadata-6` 7/7 and `metadata-5` 7/7 parse**;
`metadata-4/-3/-2` all still fail, exactly as recorded.

Three judgement calls it endorsed: the `NOT_VERIFYABLE` decline (the before-state and end-state are two
different propositions; the end state is measurable and the boundary is published); **`RISK_LEVEL: 3`
carried is the only defensible move** — a lane cannot downgrade itself, and the gate was verified
discharged at 14/14 RESOLVED with follow-ups 2/3/2/2/1, **not re-opened**; and the four LOW observations
needing no correction.

## ⚠ F6 / G-18 — the ownership grant is now decided

`27ea6536`'s desktop "No footer copy" is unsatisfied on the four desktop `S` boards: a `Footer` **text**
layer at (236,862), byte-identical to `add_product_page.dart:383-384`, divider at (236,848). **Measured
three times, read-only, by three independent lanes.**

**The repository owner has now GRANTED board ownership** — a scoped design-system lane will own the four
desktop `S - Add Product` boards (and `BPM`) to remove that single layer. **That lane is dispatched but
currently blocked: Penpot is dormant.**

**It is registered in the keys lane as `G-18`, recorded as decided-but-not-discharged.** A grant is not
an execution. **The work item must not close over it.**

**Note for your verdict:** mobile's own footer spec is a **separate, live** obligation — `D-2`.
`design_primitives.dart:396` paints the `ContentRule` unconditionally, so **`TechnicalDetails` cannot
express mobile's spec** (no divider, left-aligned). That is a **Level 1** design-system-owner item, **not a
human gate** — the human already decided the outcome. **Confirm mobile carries it as specified and not
as an unfunded requirement.** Your predecessor's review called SC-9's scoping correct; check D-2 is not
in the same position.

## Hard rules

- **Run NO Docker or Compose command whatsoever** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has ALREADY lost its QA database to a `design-reviewer` lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`.** Do not test this rule.
- **Do NOT call any Penpot tool** — see §1.
- **READ-ONLY in git.** Edit nothing except your own report directory.
- **You are independent.** The producing lane declined to approve itself.
- **PERSIST YOUR FULL REPORT TO DISK** at `docs/engineering/dispatch/tasks/design-approve-mobile-rev6/report.md`.
- **Word-boundary greps.** `F8` matches the `brief_id` `52CB4098-**FF87**-4B78-81DA-1104269551A1`. The prior
  re-reviewer hit this; the executable form belongs in `N11`.
- **Search the domain's own vocabulary.** Use `git log --all --diff-filter=A -- <exact path>` and glob full
  paths, never basenames.
- **State explicitly what you did NOT review.**

## Report format

Per `.agents/skills/aef-orchestrator/templates/subtask-report.md`, `RESULT:` verbatim from
`.agents/agents/design-reviewer.md`:

```
RESULT: DESIGN_REVIEW_APPROVED | DESIGN_REVIEW_CHANGES_REQUIRED | DESIGN_REVIEW_HUMAN_DECISION_REQUIRED
```

Include `CORRECTION_REQUIRED`, `HUMAN_DECISION_REQUIRED`, `INDEPENDENT_RISK_LEVEL`,
`RISK_LEVEL_AGREEMENT`, and state plainly **whether revision 6 is approved for Design Contract freeze**.