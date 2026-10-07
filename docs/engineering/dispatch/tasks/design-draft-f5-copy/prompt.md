# Subtask Prompt — design-draft-f5-copy (22 proposals, grouped by slot type — DRAFT ONLY, WRITE NOTHING)

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: design-draft-f5-copy
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — draft A3-correct replacement copy for the 22 false custody layers
AREA: Penpot READ-ONLY. You write NO board and NO source. You produce a proposal document.
WORKTREE: none required. Report to the canonical checkout.
BRANCH: (no branch — read-only in git)
OWNED_PATHS:
  - docs/engineering/dispatch/tasks/design-draft-f5-copy/report.md
READ_ONLY_PATHS:
  - every Penpot board (ALL of them — you write none)
  - apps/control_plane/lib/features/products/add_product_page.dart
PROHIBITED_PATHS:
  - EVERY Penpot board. THIS IS A DRAFTING LANE. YOU CHANGE NOTHING ANYWHERE.
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, docs/adr/**, WORK_STATE.md, LANES.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**, design-addproduct-mobile/**
ACCEPTANCE_CRITERIA: |
  A proposal for every one of the 22 false custody layers, grouped by slot type, each A3-consistent
  and fit-verified against its actual box. Approved by the human before anything is applied.
VALIDATION_COMMANDS:
  - penpot: penpotUtils.getPages() must return Page 1
ROUTING_CLASS: PRECISION
```

## ⚠ YOU ARE DRAFTING, NOT EDITING

**The human has authorized drafting the 22 proposals for one grouped approval. Nothing else.** You
**write no board and no source file.** Your deliverable is a document. A separate lane applies it after
the human approves the copy.

This distinction is load-bearing: **two prior lanes in this work item were given write grants, and both
introduced regressions that cost three further lanes to repair.** Your grant is the safe one.

## The three prior passes — read all three reports before drafting

1. `docs/engineering/dispatch/tasks/design-correct-f5-custody-copy/report.md` — pass 1
2. `docs/engineering/dispatch/tasks/design-correct-f5-pass2/report.md` — pass 2. **Its §5b and §5c
   already contain measured proposals for all 22.** Start there and improve them; do not start from zero.
3. `docs/engineering/dispatch/tasks/design-correct-f5-bpm-stack/report.md` — pass 3, the geometry fix

## What the copy must satisfy

Human Decision **`9417f8bf`**, `OPTION_C` / **A3, an external secret manager**: *"SHIP IT never holds key
bytes, only a reference, and asks the manager for the material at push time."*

Consequences your proposals must respect:

- The private half is **never on the device and never in any local keychain** — it is not SHIP IT's at all.
- **Generation is server-side.** Under A3, SHIP IT asks the manager for material at push time; it does
  not generate a keypair locally. Any string saying "generated here" or "created on this device" is false
  on that axis alone.
- **A2 is permanently excluded**, and **the reference itself is now the most sensitive artifact SHIP IT
  holds** — which is why `9417f8bf` elevated **G-7 to REQUIRED**. Do not propose copy that re-exposes the
  reference.
- Read `.decisions/9417f8bf-73b8-4827-9515-bdfe92e5a9d5.yaml` in full, **including the two appended
  scope notes** — the first scopes the "never holds key bytes" absolute to **storage**, and the second
  corrects a citation in that same file.

## The trap that blocked pass 2 — this is why you exist

**The approved string is an EYEBROW keyed on key type, not a universal replacement:**

```
ed25519 · generated on the server · the private half stays in the secret manager
```

It is 80 characters and renders two lines. **Pasting it into a body-prose layer, a metadata row keyed on
`GIT_PRODUCT_PR_SHIP_SSH`, or a 26-character step label would delete that layer's content.** Pass 2
correctly escalated rather than applying it blindly.

**So classify every layer by SLOT TYPE first, then write copy that fits that slot.** The measured
taxonomy from pass 2:

| slot type | count | what it carries |
|---|---|---|
| **eyebrow** | 8 | key type + custody, the slot the approved string fits |
| **body prose** | 8 | a sentence explaining custody |
| **metadata row** | 4 | keyed on `GIT_PRODUCT_PR_SHIP_SSH`, a variable placeholder |
| **step label** | 4 | 26-char labels in a sequence |

**Verify that taxonomy yourself against the live page — pass 2's own counts were once wrong.**

## `BP · Rotate Key` is the priority

It asserts the lie **three times** (`Art Sub`, `Tech 0`, `L Sub`). **Fixing one layer would leave that
screen contradicting itself** — a custody fix's unit is the board, not the layer. **Draft all three, as
one coherent set.** Its string (`Generated here · the private half never leaves the keychain`) is the
*exact inverse* of A3: wrong on both the generation axis and the custody axis.

## For EVERY proposal: measure its fit

A proposal that renders wider than its box wraps, and a wrap causes a real overlap — **that is how pass 1
broke `BPM`.** For each layer:

1. Read its current `characters`, its box (`width`/`height`), and its `fontSize`.
2. Compute or measure the proposed string's rendered width and line count **against that box**.
3. **Flag every proposal that does not fit**, with the measured overflow. Do not silently shorten to fit
   and do not propose resizing — **a box change is a design decision, and the human decides it here.**

Establish a single-line baseline at that font size on that board first, or you cannot tell a wrap from a
plausible height — pass 2 learned this by nearly reporting a non-wrap as a wrap.

## Also report, do not fix

**The build has FOUR false-claim sites, not two:** `add_product_page.dart:542` and `:1038` (eyebrow) plus
**`:480-481` and `:979-980`** (the `Ev Body` pair, confirmed by the paired `MicroLabel` at `:475`/`:974`).
**A fix scoped to the eyebrow would correct it while leaving the copy directly beneath it contradicting
it.** Draft the proposed replacement for **all four** too, so the human approves boards and build together
— **they currently diverge: the boards are current, the build is stale on both axes.**

**And `BP`'s footer**, measured last pass: `Footer` is a **TEXT layer carrying 100 chars at (236,862)
1020×15**, not a divider — so `BP` violates `27ea6536`'s no-footer-copy intent at the same coordinates the
`S` boards did. **Report it; it is a separate grant.**

## Penpot discipline

- **You are READ-ONLY. No `characters`, no `resize()`, no `setParentXY`, no `remove()`.**
- **ONE BOARD PER CALL.** Four-board loops are what timed out twice today.
- **Read `penpot_high_level_overview` before any other Penpot tool.** If a call fails with a timeout or
  heartbeat error, stop and report what you have measured; do not retry in a loop.
- **Match layer names by PREFIX, not equality.** `Art L1 · Copy key` is missed by `name === 'Art L1'` — a
  lane nearly lost its reference measurement to this. **A search returning zero rows is evidence about
  the query, not about the file.**
- **Needle breadth is the whole lesson of this work item.** Search for the *semantic* family —
  `keychain`, `this device`, `created here`, `generated here`, `never leaves`, `held in`, `local secret`,
  `on device` — **not** for the previously-known string. Three counts in a row were wrong because each
  inherited the last one's blind spots.
- Verify every board id from your own `findShapes` call; 12 `Add Product` boards exist and ids share
  substrings.

## Hard rules

- **Run NO Docker or Compose command whatsoever** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has ALREADY lost its QA database to a lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`.** Do not test this rule.
- Write no production source. Touch no `.decisions/**` or `docs/adr/**`. Commit nothing, push nothing.
- **PERSIST YOUR FULL REPORT TO DISK** at
  `docs/engineering/dispatch/tasks/design-draft-f5-copy/report.md` in the canonical checkout
  `/Users/alkebut/air/shipit-platform`.
- **Do not approve your own copy.** The human approves content.

## Report format

```
RESULT: DESIGN_REVISION_COMPLETE | DESIGN_REVISION_BLOCKED
```

Structure it for a grouped human approval — **this document is what the human reads**:

1. **Your own verified census**: layer count, board count, distinct-string count, slot-type taxonomy.
2. **A table per slot type**: board, layer name, current string, proposed string, measured fit, flags.
3. **`BP · Rotate Key` as one coherent three-layer set**, first.
4. **Every proposal that does not fit its box**, with the measured overflow and what a fix would cost.
5. **The four `add_product_page.dart` proposals**, and the current boards/build divergence.
6. **`BP`'s footer finding**, reported not fixed.
7. **Anything you could not reach**, stated as not-measured rather than assumed.

**Do not pad it.** A proposal the human cannot adjudicate in one pass is a failed deliverable.