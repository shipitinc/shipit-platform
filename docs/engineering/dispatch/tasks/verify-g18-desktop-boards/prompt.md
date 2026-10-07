# Subtask Prompt — verify-g18-desktop-boards (read-only verification of the timed-out edit)

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: verify-g18-desktop-boards
TASK_TYPE: review            # read-only verification, NOT a correction
FEATURE: Add Product rebuild — verify the G-18 desktop board edit landed correctly
AREA: Penpot desktop `S · Add Product · …` boards. You change NOTHING.
WORKTREE: none — Penpot is a live shared file. Report to the canonical checkout.
BRANCH: (no branch — read-only in git)
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/verify-g18-desktop-boards/report.md
READ_ONLY_PATHS: everything, including every Penpot board
PROHIBITED_PATHS:
  - EVERY Penpot board — including the four you are verifying. This is a VERIFICATION lane.
  - apps/**, packages/**, docker/**, .github/**, .decisions/**, docs/adr/**
ACCEPTANCE_CRITERIA: |
  An independent read of the four boards establishing whether the G-18 edit landed, changed only
  what it was granted, and left the boards conformant with 27ea6536.
VALIDATION_COMMANDS:
  - penpot: penpotUtils.getPages() must return Page 1
ROUTING_CLASS: STANDARD
```

## ⚠ THE SITUATION — a lane reported BLOCKED, and the Manager then measured otherwise

A `design-agent` lane was granted the four desktop boards and issued the deletions. **The call timed out**
(`MCP error -32001`) and Penpot then went dormant, so the lane could not read the result and correctly
reported **`RESULT: DESIGN_REVISION_BLOCKED`** with "unknown outcome".

**The Manager has since re-measured, read-only. The deletions DID execute.** Measured directly:

| board | id | children | `Footer` text layers | `Footer Rule` divider |
|---|---|---|---|---|
| `S · Add Product · Unknown host · Light` | `…a9a96fc40fa5` | **68** | **0** | **(236,848)** intact |
| `S · Add Product · Unknown host · Dark` | `…a9a03d9da341` | **68** | **0** | **(236,848)** intact |
| `S · Add Product · Verified · Light` | `…a9a979cd8fbc` | **64** | **0** | **(236,848)** intact |
| `S · Add Product · Verified · Dark` | `…a9a04943d6ae` | **64** | **0** | **(236,848)** intact |

**That is a Manager observation, not a verified fact.** Penpot went dormant again before the Manager
could complete the check, and this work item has a documented history of a Manager premise turning out
false. **Your job is to reproduce or refute it — do not accept it.**

**The lane's report records the PRE-edit state** (68/68/64/64 with one `Footer` layer each, so the
expected post-state is 67/67/63/63 — **check whether the counts are 68/68/64/64 or 67/67/63/63, because
that single number decides whether the edit ran once or not at all**). Read the lane's §2 (before-state)
and §3 (expected post-state) before measuring.

## What was granted, and what was not

**Granted: delete the `Footer` text layer at (236,862) on each of the four boards. One deletion each.**
Nothing else.

**Explicitly NOT granted, and the lane was told to report rather than act:**

- **`BPM · Add Product · Light/Dark`** — the owner granted `BPM` too, but **no measurement supported a
  `BPM` footer edit** (registered as `G-23`). The lane claims **G-23 is discharged**: dumping all 59
  descendants of both `BPM` boards shows `Disclose` at parentXY (16,580) — left-aligned on the content
  column — **no `Footer Rule`**, and no text after it until the bottom nav. **Verify that. It would mean
  `BPM` needed no edit and all three of `27ea6536`'s mobile clauses were already satisfied.**
- **`F5`** — the false custody string. The lane reports it is **wider than `BPM`**: **16 layers on 8
  boards in TWO distinct strings** — desktop carries `"ed25519 · created on this device · the private half
  stays in the keychain"`, `BPM` carries `"ed25519 · private half stays in the keychain"`. **Same false
  clause, different full string — a whole-string replacement applied page-wide would corrupt one
  platform.** Verify the counts and both strings. **The four `SM` boards are claimed clean.**

## Verify, in this order

1. **Did the edit land exactly once on each board?** Child counts vs the lane's recorded before-state.
2. **Did it change only what it was granted?** The `Disclose` right edge must still be **1256**
   (= 236 + 1020, right-aligned); the `Footer Rule` divider must still be at **(236,848)**; theme,
   spacing and all other text untouched. **The Manager confirmed the divider but NOT the `Disclose`
   alignment** — the call that would have measured it timed out. **That check is yours.**
3. **Are the other eight `Add Product` boards untouched?** Two `BP · Add Product`, two
   `BPM · Add Product`, four `SM - Add Product`. **The four `SM` boards are the APPROVED artifact set** —
   mobile revision 6 was approved with 0 blockers/high/medium/low *because it touched nothing it was not
   granted*. **If a child count on any `SM` board has moved, that approval is invalid and this is a
   BLOCKER.** Record their counts.
4. **Is the page inventory unchanged** (the Manager's earlier baseline: **160 boards / 164 root
   children**)?
5. **Is `G-18` now conformant?** The four boards should carry divider + right-aligned disclosure + **no
   footer copy**, exactly as `27ea6536` decided.
6. **`BPM` and `F5`** — reproduce or refute the lane's claims above.

## ⚠ Penpot goes dormant — plan for it

It has gone dormant **three times today**, returning *"no heartbeat"*, and a call that took too long
**times out without a result**. This is a live, shared file with **no version history** — a write that
executes but whose acknowledgement is lost is exactly what happened here.

- **Read `penpot_high_level_overview` before any other Penpot tool.**
- **Keep each `penpot_execute_code` call SMALL and bounded.** The call that failed had already issued
  four deletions; the one that timed out afterwards was a four-board loop. **Measure one board per call**
  and record results as you go, so a timeout never costs you the whole batch.
- **If a call fails with a timeout or heartbeat error, stop and report what you had already measured.**
  Do not retry in a loop. Partial verified facts are worth more than a clean report you did not earn.

## Hard rules

- **You change NOTHING.** No board edit, no rename, no delete, no move. Not even a "fix" you are sure
  about. **If you find a defect, report it — a verification lane that repairs is not a verification.**
- **Run NO Docker or Compose command whatsoever** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has ALREADY lost its QA database to a review lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`.** Do not test this rule.
- Write no production source. Commit nothing, push nothing.
- **PERSIST YOUR FULL REPORT TO DISK** at
  `docs/engineering/dispatch/tasks/verify-g18-desktop-boards/report.md` in the canonical checkout
  `/Users/alkebut/air/shipit-platform`. **Reports have been lost three times in this work item.**
- **Do not approve your own work.** You did not make the edit; you are checking it.

## Report format

```
RESULT: DESIGN_REVIEW_APPROVED | DESIGN_REVIEW_CHANGES_REQUIRED
```

State plainly, in this order: **did the edit land? exactly once? only what it was granted?** then the
`Disclose` alignment, the untouched-board counts, the page inventory, `BPM`, `F5`, and finally:

> **Is `G-18` DISCHARGED, PARTIALLY DISCHARGED, or still UNDISCHARGED?**

Say which, and state what is verified versus what you could not reach.