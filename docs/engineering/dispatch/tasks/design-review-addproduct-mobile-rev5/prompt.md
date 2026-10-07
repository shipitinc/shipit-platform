# Subtask Prompt — design-review-addproduct-mobile-rev5 (first review of revision 5)

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: design-review-addproduct-mobile-rev5
TASK_TYPE: design-review
FEATURE: Add Product rebuild — mobile Design Revision 5
AREA: Independent, read-only design review of the SM mobile boards and revision 5
WORKTREE: read-only; canonical checkout + live Penpot page "Page 1"
BRANCH: design-correct-addproduct-mobile @ 289f1d3 (producing worktree UNCOMMITTED — see below)
BASE_SHA: 289f1d3
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-review-addproduct-mobile-rev5/**   (your report)
READ_ONLY_PATHS: everything else, including every Penpot board
PROHIBITED_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**   (artifacts under review)
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/**
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, WORK_STATE.md, LANES.md
ACCEPTANCE_CRITERIA: |
  An independent verdict on mobile revision 5 covering completeness, design-system compliance,
  UX/accessibility, IA integrity, implementation feasibility and traceability, with every board claim
  verified against the live Penpot file.
VALIDATION_COMMANDS:
  - cd /Users/alkebut/air/shipit-platform && git rev-parse --short HEAD    # 08c7590
ROUTING_CLASS: PRECISION
```

## CRITICAL — Penpot is available to YOU, and previous reviewers could not use it

Two earlier review passes were **unable to verify a single board claim** because Penpot was unreachable.
**It is now reachable.** `penpotUtils.getPages()` returns `["Page 1"]`.

**This makes your review strictly more valuable than any prior one on this artifact set, and it is the
main thing I want from you: verify the board claims against the live file.** The prior rev-4 reviewer
said every board-read claim should be treated as unconfirmed by it. **You do not have that excuse.**

Read `penpot_high_level_overview` before any other Penpot tool. Page `d8ac01df-6646-81d2-8008-a366c09aa9d3`.

The four boards under review, with ids the producer published:

| board | id |
|---|---|
| `SM - Add Product - Unknown host - Light` | `6d055762-a70b-804c-8008-bf65ff750422` |
| `SM - Add Product - Unknown host - Dark` | `6d055762-a70b-804c-8008-bf65e644269b` |
| `SM - Add Product - Verified - Light` | `6d055762-a70b-804c-8008-bf660e124738` |
| `SM - Add Product - Verified - Dark` | `6d055762-a70b-804c-8008-bf65f36b1c9a` |

All four are 390x844. **Penpot has no version history**, so the pre-edit board state is **not
reconstructible** — the producer disclosed this. Judge the boards as they stand; do not penalise the
lane for an unanswerable before/after.

## Where revision 5 lives

Uncommitted in the producing worktree `/private/tmp/shipit-correct-addproduct-mobile`; the Manager has
copied the **entire** artifact set byte-identically into the canonical checkout at
`docs/engineering/dispatch/tasks/design-addproduct-mobile/` (verified by `diff -q` at copy time).
**Review the canonical copies.** Key files: `design-revision-5.md`, `design-revision-metadata-5.yaml`,
`traceability-matrix-5.md`, `correction-report-5c.md`, `penpot-board-evidence.md`, `design-brief.md`.

## ⚠ The lane was cancelled once and resumed — read this before trusting provenance

A prior invocation was **cancelled mid-flight** after applying board edits with **no revision artifact
and no report**. The Manager measured the live state, wrote a resume note
(`tasks/design-correct-addproduct-mobile-5b/resume-note.md`), and dispatched again. The resumed lane
reports it verified every Manager claim independently rather than trusting it.

**Verify that for yourself.** The Manager's summary claimed the four boards already carried the corrected
custody string and the identity-split copy. **Check the live boards**, and check whether the resumed
lane's own record of *what it kept and what it reverted* is complete and honest — including its claim
that the cancelled lane's two published-as-measured numbers were wrong (**F6** and **F7**).

## What the lane claims, and where to press

`RESULT: DESIGN_REVISION_COMPLETE`, `RISK_LEVEL: 3`, compliance **PARTIAL**, a11y **PASS**,
feasibility **MEDIUM**. It re-derived risk rather than inheriting it and re-verified that the **Level-3
gate is already discharged** (`9417f8bf`, `27ea6536`, `898b07d0` all RESOLVED, all naming
`design-agent`) — **verify that claim yourself, since the risk level rests on it.**

Two findings it raised for others, both unowned and worth your judgement:

- **F6 — a resolved human decision is not satisfied by the boards it governs.** `27ea6536` says the
  desktop `S - Add Product` boards carry **no footer copy**, and names those boards authoritative. **All
  four carry a `Footer` text layer at `(236,862)`** — byte-identical to
  `apps/control_plane/lib/features/products/add_product_page.dart:383-384` — while the divider sits at
  `(236,848)`. **Measure this yourself on the `S` boards (read-only).** This became the **only BLOCKER**
  in the keys rev-5 review.
- **D-8 — `SM` and `BPM` are two *states* of one mobile design**, established by a measured coordinate
  table. Consequence claimed: `27ea6536`'s mobile footer spec was **already satisfied** on all four
  `SM` boards, so no mobile board edit was needed. **Check the table is measured, not asserted.**

Also note: the lane reports **SC-9 NOT MET, reported not claimed** — the A3 remediation copy is fully
specified but rendering it needs boards outside its `OWNED_PATHS`, and R.11g item 5 forbids folding it
onto the Unknown-host board. Judge whether that is a correct scoping call or an unfunded requirement.

## Things it claims you should check rather than accept

- **G-7 measured at 6 sites, and two are UI render sites.** Under `9417f8bf`'s A3, SHIP IT holds only a
  reference — and an ARN or secret path **discloses vault topology**. If two render sites expose it, that
  is user-facing, not an internal contract detail. Verify.
- **`flutter analyze` NOT_RUN.** Honest, and expected — no production change. But it means feasibility is
  **MEDIUM on reasoning, not on a green build**.
- A withdrawn `214.53px` Penpot figure, attributed to an unreconcilable `textBounds` scale. Check the
  withdrawal is honest rather than convenient.
- **M-1 was hit live.** The lane reports that its own §4.4 edit to rev 3 invalidated rev 4's `:633`, its
  own first-draft `:570`, and three citations in retained reports, and it fixed them — recording the
  lesson as *"re-reading what you edited is necessary but not sufficient; you must re-read what you write
  about it."* **Spot-check a sample of those numbers yourself.** Cross-reference drift is this work
  item's most repeated defect and it has been published as measured before.

## Hard rules

- **Run NO Docker or Compose command whatsoever** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has ALREADY lost its QA database to a `design-reviewer` lane
  running `docker compose -f docker/compose.qa.yaml down -v --rmi local`.** Do not test this rule. Do
  not start a database; if you believe you need one, that is a blocker to report.
- **READ-ONLY in Penpot too.** You may read every board. **Edit, rename or delete nothing** — not the
  four `SM` boards, not `BPM -`, not `S -`/`DESKTOP -`.
- **READ-ONLY in git.** Edit nothing except your own report directory.
- **You are independent.** The producer never approves its own work; the resumed lane explicitly
  declined to.
- **PERSIST YOUR FULL REPORT TO DISK** at
  `docs/engineering/dispatch/tasks/design-review-addproduct-mobile-rev5/report.md` before returning.
  **Two review reports were lost to a relay in this work item** and receiving lanes worked from
  paraphrase. **A third review report — the `APPROVE_CORRECTIONS` verdict authorising this morning's
  merge — is still untracked on disk.** Do not be the next.
- **Search the domain's own vocabulary, not the requester's phrasing.** Three times in this work item a
  lane grepped one identifier and concluded an artifact was absent: `deployKey` vs **`credential`**; and
  `docs/engineering/adr/` vs **`docs/adr/`**, which wrongly declared **ADR 0018 itself** absent. Follow
  citations; enumerate with `glob`, not `ls` on a guessed path. **Verify a path exists before trusting an
  UNCHANGED result** — one lane's `git diff --quiet` passed because the path did not exist.
- **State explicitly what you did NOT review.**

## Settled — do not re-open

Nine Human Decisions are RESOLVED. `9417f8bf` **OPTION_C / A3** (external secret manager; SHIP IT holds
only a reference), `898b07d0` **OPTION_A** (split identity from registration), `ae1c1f79` **OPTION_A**
(a substrate refusal creates **nothing**), `27ea6536`, `7b1bc8b7`, `79e860e2`, `4d2c6b81`,
`b869ec24`, `876c6b97`. **Do not re-raise any of them, and do not re-raise B2/N1, B4/N2, N4/G9, N6, N10.**

One residual component is **not** human-decided and is **not** a gate: **D-2** —
`TechnicalDetails` must be able to suppress its `ContentRule` (`design_primitives.dart:396` paints it
unconditionally) and align its disclosure start-aligned. That is a **Level 1** design-system-owner
notification. The human already decided the outcome.

## Report format

Report per `.agents/skills/aef-orchestrator/templates/subtask-report.md` with the `RESULT:` block
verbatim from `.agents/agents/design-reviewer.md`:

```
RESULT: DESIGN_REVIEW_APPROVED | DESIGN_REVIEW_CHANGES_REQUIRED | DESIGN_REVIEW_HUMAN_DECISION_REQUIRED
```

Include `CORRECTION_REQUIRED`, `HUMAN_DECISION_REQUIRED`, `INDEPENDENT_RISK_LEVEL`,
`RISK_LEVEL_AGREEMENT`. Publish findings with evidence. Carry exact provenance: reviewed HEAD, artifact
paths, revision id, and **which board claims you verified live versus took on trust**.