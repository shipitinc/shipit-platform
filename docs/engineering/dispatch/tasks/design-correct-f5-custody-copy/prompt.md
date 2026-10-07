# Subtask Prompt — design-correct-f5-custody-copy (F5: the false key-custody string, 8 boards + BP measurement)

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: design-correct-f5-custody-copy
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — F5: false key-custody copy on 8 boards; measure the 2 BP boards
AREA: Penpot — 8 boards carrying the false string, plus a read-only measurement of 2 BP boards
WORKTREE: none required — Penpot is a live shared file. Report to the canonical checkout.
BRANCH: (no branch — read-only in git; you write no source and commit nothing)
OWNED_PATHS:
  - Penpot "Page 1" (d8ac01df-6646-81d2-8008-a366c09aa9d3) — the 8 boards holding the false string:
      BP · Add Product · Light/Dark
      S · Add Product · Unknown host · Light/Dark
      S · Add Product · Verified · Light/Dark
      BPM · Add Product · Light/Dark
  - docs/engineering/dispatch/tasks/design-correct-f5-custody-copy/report.md
READ_ONLY_PATHS:
  - apps/control_plane/lib/features/products/add_product_page.dart  (the build's copy — read only)
PROHIBITED_PATHS:
  - the four `SM - Add Product - …` boards — ALREADY CLEAN and part of an APPROVED artifact set.
    READ them if useful. NEVER edit one.
  - every other board on the page
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, docs/adr/**, WORK_STATE.md, LANES.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**, design-addproduct-mobile/**
ACCEPTANCE_CRITERIA: |
  The 8 boards carry the A3-correct custody string. The 2 BP boards are measured under the same
  footer criterion and reported.
VALIDATION_COMMANDS:
  - penpot: penpotUtils.getPages() must return Page 1
ROUTING_CLASS: STANDARD
```

## THE EDIT — one string, on eight boards

Replace the false key-custody string with:

```
ed25519 · generated on the server · the private half stays in the secret manager
```

**That is the whole grant: change the text of one layer on each of eight boards. Change nothing else.**

## Why the current copy is false — this is a security claim, not a label

Human Decision **`9417f8bf`**, `OPTION_C` / **A3, an external secret manager**: *"SHIP IT never holds key
bytes, only a reference, and asks the manager for the material at push time."*

Two distinct strings are live, and **this is the trap**:

| boards | current string |
|---|---|
| **6 desktop** (`BP`, `S ·`) | `ed25519 · created on this device · the private half stays in the keychain` |
| **2 mobile** (`BPM`) | `ed25519 · private half stays in the keychain` |

**Same false clause, different full strings.** A whole-string page-wide replacement **will corrupt one
platform.** Locate each layer by **id and current characters**, never by matching one string across the
page.

**Both claims are false for the same reason:** under A3 the private half is **not on the device and not in
any local keychain** — it is not SHIP IT's at all. The replacement names the secret manager, which is the
substrate the human chose.

## The four `SM` boards are already correct — do not touch them

They already carry the replacement string verbatim. They are the **APPROVED** artifact set: mobile
revision 6 was approved with 0 blockers / 0 HIGH / 0 MEDIUM / 0 LOW *because it touched nothing it was not
granted*. **Editing one of them invalidates that approval.** Read them as your reference for the exact
target string and its layer naming; **never edit one.**

## Also measure the two `BP · Add Product · Light/Dark` boards — read-only

`27ea6536` resolved that Add Product carries **no footer copy**, naming the four `S` boards and the two
`BPM` boards. It **does not name the two `BP` boards**, which carry a `Footer` layer whose type and
position have never been measured.

**The owner has directed that they be measured under the same criterion and reported.** Specifically:

- Is the `BP` `Footer` layer a **text** layer (copy) or a **rectangle** (divider)?
- What are its position and size?
- Does the `BP` board otherwise match `27ea6536`'s desktop clause — divider plus a right-aligned
  `Show technical details` text button?

**REPORT. DO NOT EDIT `BP`.** This pass measures; the grant to change them, if warranted, comes after.

## ⚠ A lane that timed out mid-write on the last task — read this before you act

The previous board lane **issued its four deletions, the call timed out (`MCP error -32001`), and Penpot
went dormant**, so it could not tell whether the edit had landed and correctly reported
`DESIGN_REVISION_BLOCKED`. A verification pass later established it had — but that consumed two extra
lanes.

**Consequences for you:**

- **Keep each `penpot_execute_code` call SMALL and bounded. Measure and edit ONE BOARD PER CALL.**
  The call that failed had already issued four deletions; the one that timed out afterwards was a
  four-board loop.
- **Record each board's result as you go**, so a timeout costs you one board rather than the batch.
- **Read `penpot_high_level_overview` before any other Penpot tool.**
- **If a call fails with a timeout or heartbeat error, STOP and report what you already measured, with
  child counts.** Do not retry in a loop. A timed-out write **may still have executed** — say so rather
  than assuming either way.
- Penpot has gone dormant **four times today**. **Penpot has no version history** — your recorded
  before-state is the only record of it.

## Mechanism notes that will bite if you skip them

- **`parentX`/`parentY` are READ-ONLY computed values.** To *find* a layer, use
  `penpotUtils.findShapes(predicate, board)` matching on **`s.characters`** or `s.name` — **never
  construct a position to match a number.** A board-local `parentX` of 236 and an absolute `x` of 236 are
  different quantities.
- **Editing text:** set `text.characters = <new string>`. **The new string is longer than the old one on
  the desktop boards** — after setting it, **re-read `textBounds`** and check whether the layer still
  fits its box, whether it wraps, and whether it now **overlaps the adjacent disclosure**. The old
  desktop string was 75 chars; the replacement is 80. **A silent overlap is a worse outcome than a
  visible one.** Report what you find rather than shrinking the font — **that is a second edit you were
  not granted.**
- **Verify every board id from your own `findShapes` call.** This page has 12 `Add Product` boards and
  **8 are yours**. The ids share long substrings — e.g. `…a9a03d9da341` (`S · Unknown host · Dark`) also
  appears inside `…a9ac5f5ad2dc` (`BPM · Dark`).

## Verify — the before/after is the deliverable

For **each** of the 8 boards, before and after: the layer's name, type, `characters`, position, size, and
the board's child count. Then confirm: **zero remaining occurrences of `keychain` or `created on this
device` anywhere on the page**, **8 occurrences of `secret manager`** where before there were 4, and the
**four `SM` boards unchanged**.

## Hard rules

- **Run NO Docker or Compose command whatsoever** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has ALREADY lost its QA database to a lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`.** Do not test this rule.
- **Never edit a board you do not own** — especially the four `SM` boards.
- Write no production source. Touch no `.decisions/**` or `docs/adr/**`. Commit nothing, push nothing.
  **`add_product_page.dart:542` and `:1038` carry the same false claim in shipped code — REPORT them for
  the implementer; the build fix is a separate lane with different OWNED_PATHS.**
- **PERSIST YOUR FULL REPORT TO DISK** at
  `docs/engineering/dispatch/tasks/design-correct-f5-custody-copy/report.md` in the canonical checkout
  `/Users/alkebut/air/shipit-platform`. **Reports have been lost three times in this work item.**
- **Do not approve your own work.**

## Report format

```
RESULT: DESIGN_REVISION_COMPLETE | DESIGN_REVISION_BLOCKED
```

Include: per-board before/after evidence, any layer that **wrapped or overlapped** after the longer
string, confirmation the four `SM` boards are untouched, the page-wide string census after the edit, your
**`BP` footer measurement**, and whether every one of the 8 was actually changed or only some.