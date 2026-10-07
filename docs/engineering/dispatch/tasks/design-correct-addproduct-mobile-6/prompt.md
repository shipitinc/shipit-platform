# Subtask Prompt — design-correct-addproduct-mobile-6 (revision 6, 0 BLOCKERS)

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: design-correct-addproduct-mobile-6
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — mobile Design Revision 6
WORKTREE: /private/tmp/shipit-correct-addproduct-mobile
BRANCH: design-correct-addproduct-mobile
BASE_SHA: 16cd497
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/**
  - Penpot "Page 1" — your four boards ONLY:
      SM - Add Product - Unknown host - Light   6d055762-a70b-804c-8008-bf65ff750422
      SM - Add Product - Unknown host - Dark    6d055762-a70b-804c-8008-bf65e644269b
      SM - Add Product - Verified - Light       6d055762-a70b-804c-8008-bf660e124738
      SM - Add Product - Verified - Dark        6d055762-a70b-804c-8008-bf65f36b1c9a
READ_ONLY_PATHS: apps/**, packages/**, docs/adr/**, docs/engineering/**, AGENTS.md, .decisions/**
PROHIBITED_PATHS:
  - apps/**, packages/**          (production source — you design it, you do not write it)
  - docker/**, .github/**
  - .decisions/**, WORK_STATE.md, LANES.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**    (keys lane)
  - docs/engineering/dispatch/tasks/design-adr-0018-amendment/**      (ADR lane)
  - docs/engineering/dispatch/tasks/design-review-*/**                (reviewers)
  - EVERY other Penpot board — including all `BPM -` and `S -`/`DESKTOP -`. Read them; never edit,
    rename or delete them.
ACCEPTANCE_CRITERIA: |
  Design Revision 6 closing MR5-1..MR5-7 from the first review of revision 5.
VALIDATION_COMMANDS:
  - cd /private/tmp/shipit-correct-addproduct-mobile && git rev-parse --short HEAD
  - penpot: penpotUtils.getPages() must return Page 1
ROUTING_CLASS: STANDARD
```

## Isolation pre-flight

```bash
cd /private/tmp/shipit-correct-addproduct-mobile
git branch --show-current    # design-correct-addproduct-mobile
git merge --ff-only 16cd497  # the bookkeeping commit; artifacts are identical, expect a fast-forward
git rev-parse HEAD
```

## The finding set — read the review in full first

`docs/engineering/dispatch/tasks/design-review-addproduct-mobile-rev5/report.md`

```
RESULT: DESIGN_REVIEW_CHANGES_REQUIRED
REVISION_ID: CB4BEECA-CA9D-4F26-9464-E1B6F7C9BDCB
BLOCKERS: NONE        HIGH: NONE
MEDIUM: MR5-1, MR5-2, MR5-3
LOW: MR5-4, MR5-5, MR5-6, MR5-7
CORRECTION_REQUIRED: YES      HUMAN_DECISION_REQUIRED: NO
INDEPENDENT_RISK_LEVEL: 3      RISK_LEVEL_AGREEMENT: YES
```

**Zero blockers and zero HIGH. All three record corrections — no design change is required.** This is
the cleanest correction in the work item. Do not invent redesign work to justify the cycle.

**Read the reviewer's §"What I verified" carefully. It verified essentially everything live and found
the artifact set sound**, including all 13 M-1 numbers, all three L-1 pointers, every source citation,
all ten contrast figures to 0.00, and the honesty of the 214.53px withdrawal. It also **confirmed both
errors by the cancelled lane** (F6, F7) and found the resumed lane's correction sound. **Do not re-verify
what it verified — that is not your pass to spend.**

### What the review says remains

Per its own summary, three record corrections:

- **A suffix count is wrong in two of its three published forms. The correct value is 16**, and the
  reviewer proved it — it measured exactly 8 unsuffixed `Trust *` layers on each Unknown board. Fix all
  three forms, and say which one was right.
- **`design-brief.md` SC-7 records F6 as met**, citing §6.3 (which is D-8) **instead of §6.4**, and F6
  appears **nowhere in the brief**. Fix the citation and record F6 where the brief can carry it.
- **G-7's site table is missing `ui_view_mappers.dart:176`** — the server-side view constructor, which is
  the build break that route **N6a** sends to the implementer. Add it.

MR5-4…MR5-7 (LOW) are in the report. Apply them the same way.

## ⚠ Do NOT re-open these — the review settled them

- **D-8 RESOLVED**: `SM` and `BPM` are two **states** of one mobile design, verified by a measured
  coordinate table — all 8 rows × 3 columns reproduce. **H-1(b) needed no mobile board edit** because the
  human's mobile footer spec was already satisfied. Do not re-measure.
- **Every board claim is independently verified against the live Penpot file.** The custody string, layer
  names, the 436→446 and 456→466 moves with 4px preserved slack, the two-line wrap inferred from layer
  height, `Trust Created` containment, `Disclose` left-aligned at 16 with zero dividers and zero footer
  copy, inventory 160/164, layer counts 44/44/36/36 and 29/29/24/24, `Register product` 1/2,1/2,1/1,1/1.
  **The boards are right.**
- **SC-9 is a CORRECT scoping call, not an unfunded requirement.** Rendering the A3 remediation copy
  needs boards outside your `OWNED_PATHS` and R.11g item 5 forbids folding it onto the Unknown-host
  board. **Carry it as a scoped gap; do not work around the boundary.**
- **The Level-3 gate is discharged and independently verified** — five decisions RESOLVED, `decided_by`
  verbatim, design-agent follow-ups 2/3/2/2/1. **Do not re-open it.**
- **G-7's two UI render sites are a finding, not a defect you may fix** — under A3 the reference discloses
  vault topology, and those are production render sites. Record and route; do not edit production source.

## F6 remains owned by nobody — state it, do not absorb it

F6 is the **only BLOCKER in the keys rev-5 review**, and it is **not yours**: the desktop `S -` boards
carry a `Footer` text layer at `(236,862)` (byte-identical to
`apps/control_plane/lib/features/products/add_product_page.dart:383-384`) with the divider at `(236,848)`,
so `27ea6536`'s desktop "No footer copy" is unsatisfied on the boards it names authoritative. Those boards
are `PROHIBITED` to you and to the keys lane. `BPM` carries the same false custody string and the
now-false `NOT REGISTERED YET` eyebrow.

**It needs an ownership grant, not a re-decision.** Report it as an open ownership gap in your report and
in your metadata's traceability gaps. **Do not fix it, and do not edit a board you do not own.**

## Hard rules

- **Run NO Docker or Compose command whatsoever** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has ALREADY lost a QA database to a lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`.** Do not test this rule.
- Read `penpot_high_level_overview` before any other Penpot tool.
- **Only your four `SM` boards are writable.** Every `BPM -` and `S -`/`DESKTOP -` board is read-only.
- Do not commit or push. Do not approve your own work.
- **PERSIST YOUR FULL REPORT TO DISK** before returning, with the `RESULT:` block verbatim from
  `.agents/agents/design-agent.md`. **A review report has been lost three times in this work item.**
- **This work item has a documented history of a lane accepting a Manager premise that turned out false.**
  Re-verify claims before relying on them, and report a premise you find wrong rather than working around it.
- Cross-reference drift has been published as measured before: **read the live file after each edit and
  re-read what you write about it** — a marker written at a cited line moves that line. The review
  confirmed all 13 M-1 numbers are currently exact; keep them exact.
- Every result carries exact provenance.

## Report format

```
RESULT: DESIGN_REVISION_COMPLETE | DESIGN_REVISION_BLOCKED
```

Include `RISK_LEVEL` with rationale, an item-by-item disposition of MR5-1…MR5-7 and the three record
corrections, and your report on which published suffix count was correct.