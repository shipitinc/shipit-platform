# Subtask Prompt — design-correct-g18-desktop-boards (G-18: the four-board footer edit)

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: design-correct-g18-desktop-boards
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — G-18: bring the four desktop `S` boards into conformance with 27ea6536
AREA: Penpot desktop `S · Add Product · …` boards. ONE layer deleted on each. Nothing else.
WORKTREE: none required — Penpot is a live shared file, not a git artifact. Your report goes to the
          canonical checkout /Users/alkebut/air/shipit-platform.
BRANCH: (no branch — read-only in git; you write no source and commit nothing)
OWNED_PATHS:
  - Penpot "Page 1" (d8ac01df-6646-81d2-8008-a366c09aa9d3) — EXACTLY these four boards:
      S · Add Product · Unknown host · Light   b5b63334-c22a-80a6-8008-a9a96fc40fa5
      S · Add Product · Unknown host · Dark    b5b63334-c22a-80a6-8008-a9a03d9da341
      S · Add Product · Verified · Light       b5b63334-c22a-80a6-8008-a9a979cd8fbc
      S · Add Product · Verified · Dark        b5b63334-c22a-80a6-8008-a9a04943d6ae
  - docs/engineering/dispatch/tasks/design-correct-g18-desktop-boards/report.md
READ_ONLY_PATHS:
  - apps/control_plane/lib/features/products/add_product_page.dart  (the string's source — read only)
PROHIBITED_PATHS:
  - EVERY other Penpot board. That includes:
      · the four `BP · Add Product · Light/Dark` boards
      · both `BPM · Add Product · Light/Dark` boards (390x844)
      · all four `SM - Add Product - …` boards (390x844) — these are the APPROVED artifact set,
        frozen by design review. Touching one invalidates mobile revision 6's approval.
      · any non-`Add Product` board on the page
    READ them if you need to. NEVER edit, rename, move or delete one.
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, docs/adr/**, WORK_STATE.md, LANES.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**, design-addproduct-mobile/**
ACCEPTANCE_CRITERIA: |
  The four desktop `S · Add Product · …` boards satisfy `27ea6536`'s desktop clause — no footer copy.
  One layer deleted from each. Divider and right-aligned disclosure untouched.
VALIDATION_COMMANDS:
  - penpot: penpotUtils.getPages() must return Page 1
  - penpot: read all four boards before and after; the before/after is your evidence
ROUTING_CLASS: STANDARD
```

## THE TASK — one deletion per board. That is all.

Your decision to make, and the only one:

> **Delete the `Footer` text layer at (236,862) on each of the four boards. Change nothing else.**

The layer carries the string *"Your decision is recorded permanently. The same piece of work then
continues — nothing is restarted."* — **byte-identical** to what `_buildFooter` renders in the shipped
build at `apps/control_plane/lib/features/products/add_product_page.dart:383-384`.

### Why this edit exists — read this so you do not "improve" it

Human Decision **`27ea6536`** resolved, by the repository owner's direct statement *"I just checked"*:

> - **Desktop** (`S · Add Product · …`): a divider, and a **right-aligned** `Show technical details`
>   text button. **No footer copy.**
> - **Mobile** (`BPM · Add Product · …`): left-aligned, **no divider**. **No footer copy.**
> - *"Stay true to both designs in Penpot and in code."*

**The boards were declared authoritative, and on one clause they do not match.** That is the whole
finding. It is registered as **`G-18`** in the keys lane and **`F6`/`N6b`** in the mobile lane; both
recorded it as an ownership gap, **not** a re-decision. **The owner has now granted board ownership to
this lane.**

### Do NOT touch these — they are already correct

Three independent read-only lanes measured all four boards and agreed on every value:

| element | state | verdict |
|---|---|---|
| `Footer Rule` divider at **(236,848)** | present | **correct — leave it** |
| `Show technical details` / `Disclose` — **right** edge at **1256** = 236 + 1020 | right-aligned | **correct — leave it** |
| `Footer` **text** layer at **(236,862)**, 1020×15, align left | **copy line** | **DELETE THIS ONE** |

**If you find yourself wanting to adjust the divider, the alignment, the button text, the theme, spacing
or anything else — stop. Report it instead.** Your grant is one deletion. A second edit turns a
conformance fix into an unreviewed redesign, and mobile revision 6 is now approved precisely because it
touched nothing it was not granted.

## Penpot mechanics — the trap this task is most likely to fall into

**This page has 12 `Add Product` boards and only 4 are yours.** Identified live:

| board | id | yours? |
|---|---|---|
| `BP · Add Product · Light/Dark` | `…a9a8f06e3586` / `…a9a03d9da341`* | **no** |
| `S · Add Product · Unknown host · Light/Dark` | `…a9a96fc40fa5` / `…a9a03d9da341` | **YES** |
| `S · Add Product · Verified · Light/Dark` | `…a9a979cd8fbc` / `…a9a04943d6ae` | **YES** |
| `BPM · Add Product · Light/Dark` | `…a9ad42be419b` / `…a9ac5f5ad2dc` | **no** |
| `SM - Add Product - …` ×4 | `6d055762-…` | **no — APPROVED, frozen** |

\* read the ids from your own `findShapes` call; **verify every id before you act on one.** A wrong id on
a shared live file is not recoverable by re-running a command.

**`parentX`/`parentY` are READ-ONLY computed values.** Position is `x`/`y` in absolute page
coordinates. To *find* the layer, use `penpotUtils.findShapes(s => s.type === 'text' && s.name ===
'Footer', board)` — or match on its characters. **Do not construct a position to match a number**; a
board-local `parentX` of 236 and an absolute `x` of 236 are different quantities and confusing them moves
the wrong thing.

**To delete:** `shape.remove()`. The layer is a plain text shape, **not** inside a component, so this
removes it outright rather than making it invisible. **Confirm that is true of your target before you
call it** — the Penpot API documents that descendants of a board used as a component asset are made
invisible instead of removed, and you do not want to discover that after the fact.

## Verify — the before/after is the deliverable

1. **Before:** read all four boards; record the `Footer` layer's name, type, position, size and
   `characters` on each, and the **total child count of each board**. Record the page inventory.
2. **Delete** on each of the four.
3. **After:** re-read all four; confirm the layer is gone, the child count dropped by exactly one each,
   the divider at (236,848) is intact, and the `Disclose` right edge is still 1256.
4. **Confirm you touched nothing else:** the page inventory is unchanged, and the eight boards you do not
   own have unchanged child counts.
5. **Note honestly that Penpot has no version history** — the pre-edit state cannot be reconstructed
   later, so your recorded before-state is the only record of it. That is why step 1 is not optional.

## Two open questions you may settle — but report, do not assume

- **`BPM`.** The owner granted this lane `BPM` too, but **no measurement supports a `BPM` footer edit** —
   it is unverified in **both** directions, and the keys lane registered that as `G-23`. **Establish what
   `BPM` actually carries** and report it. **Do not edit `BPM` this pass** — an unmeasured edit is not
   what the grant was for.
- **`F5` on `BPM`.** `BPM` carries the same false custody string (`…private half stays in the keychain`,
   false under `9417f8bf`'s A3) and the now-false `NOT REGISTERED YET` eyebrow. **Measure and report.**

If either is genuinely wrong, that is a finding for the next pass with an owner — not for this one.

## Hard rules

- **Run NO Docker or Compose command whatsoever** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has ALREADY lost its QA database to a lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`.** Do not test this rule.
- Read `penpot_high_level_overview` before any other Penpot tool.
- **Penpot can go dormant mid-session** — it did twice today, returning *"no heartbeat"*. **If a call
  fails that way, stop and report `RESULT: DESIGN_REVISION_BLOCKED` with the exact error.** Do not retry
  in a loop, and do not guess at a board's contents from memory.
- **Never edit a board you do not own** — especially the four `SM` boards, whose revision is APPROVED.
- Write no production source. Touch no `.decisions/**`. Commit nothing, push nothing.
- **PERSIST YOUR FULL REPORT TO DISK** at
  `docs/engineering/dispatch/tasks/design-correct-g18-desktop-boards/report.md` in the canonical
  checkout. **Reports have been lost three times in this work item.**
- **Do not approve your own work.** A lane that edits four boards cannot be the lane that certifies them.

## Report format

```
RESULT: DESIGN_REVISION_COMPLETE | DESIGN_REVISION_BLOCKED
```

Include: per-board before/after evidence, the child counts, confirmation the other eight boards are
untouched, the page inventory before and after, your `BPM` and `F5` findings, and — plainly — whether
`G-18` is now **discharged** or merely **partially** so.