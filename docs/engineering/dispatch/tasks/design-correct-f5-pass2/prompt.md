# Subtask Prompt — design-correct-f5-pass2 (BPM overlap + the 8 remaining false layers)

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: design-correct-f5-pass2
TASK_TYPE: design-produce
FEATURE: Add Product rebuild — F5 pass 2: repair the BPM overlap, then fix the 8 remaining false layers
AREA: Penpot — 2 BPM board layouts, then 8 remaining text layers across 6 boards
WORKTREE: none required — Penpot is a live shared file. Report to the canonical checkout.
BRANCH: (no branch — read-only in git; no source changes, no commits)
OWNED_PATHS:
  - Penpot "Page 1" (d8ac01df-6646-81d2-8008-a366c09aa9d3):
      · layout repair on `BPM · Add Product · Light/Dark`   — Art S box + Key State position
      · ONE text layer on each of the 8 remaining boards holding a false string (see §3)
  - docs/engineering/dispatch/tasks/design-correct-f5-pass2/report.md
READ_ONLY_PATHS:
  - apps/control_plane/lib/features/products/add_product_page.dart   (the build's copy — read only)
  - the four `SM - Add Product - …` boards  (APPROVED — the reference, never write)
PROHIBITED_PATHS:
  - every board not named in OWNED_PATHS. **The four `SM` boards are APPROVED — never edit one.**
  - apps/**, packages/**, docker/**, .github/**
  - .decisions/**, docs/adr/**, WORK_STATE.md, LANES.md
  - docs/engineering/dispatch/tasks/design-addproduct-keyservice/**, design-addproduct-mobile/**
ACCEPTANCE_CRITERIA: |
  1. BPM's Art S / Key State overlap cleared by matching the approved SM treatment.
  2. All 8 remaining false layers carry a true, A3-consistent string.
VALIDATION_COMMANDS:
  - penpot: penpotUtils.getPages() must return Page 1
ROUTING_CLASS: STANDARD
```

## Why this pass exists

A prior lane replaced the false custody string on 8 boards as granted. **It achieved the copy fix and
introduced a layout regression on two of them.** Read its report first — it is the evidence you are
continuing:

`docs/engineering/dispatch/tasks/design-correct-f5-custody-copy/report.md`

It also **falsified its own scope premise**, which is the most valuable thing in it: searching on the
known-bad phrase finds only *some* of the lie.

---

# PART 1 — repair the `BPM` overlap (do this FIRST)

## The measured facts

On both `BPM · Add Product · Light/Dark`, after pass 1:

- `Art S` box is **220×15** at parentXY **(138,418)**, characters now
  `ed25519 · generated on the server · the private half stays in the secret manager`
- its `textBounds` renders **h=25** (two lines) against a measured **h=13** single-line baseline on that
  same board, giving `textBounds.y + height = 11192`
- `Key State` box is 220×15 at **(138,436)**, `textBounds.y = 11185`
- **so the text overruns by 7px and overlaps**

## The approved reference — measure this yourself first, then copy it exactly

On the approved `SM - Add Product - Unknown host - Light`:

| layer | parentXY | size |
|---|---|---|
| `Art S` | **(138,418)** | **220×24** |
| `Key State` | **(138,446)** | 220×15 |

That is a **4px gap** (446 − 418 − 24). The SM boards were authored at **220×24 specifically to hold this
string**; `BPM`'s box was sized for the shorter old one. **Copy approved on one platform's board is not
thereby approved on another's.**

**Your grant, and it is exact:**

1. Resize `Art S` on each `BPM` board from **220×15 → 220×24** (`shape.resize(220, 24)`).
2. Move `Key State` on each `BPM` board from **parentY 436 → 446**.

**Then verify the result against the SM reference rather than against your own expectation.** After the
edit, re-read `textBounds` in a **separate call** and confirm: the text no longer overlaps `Key State`
(`art.textBounds.y + height <= key.textBounds.y`), and the gap is **4px** as on `SM`. **If it is not 4px,
report it — do not tune it into place.** A third variable is a change you were not granted.

## ⚠ Do not shrink the font, and do not shorten the copy

Both are design decisions outside your grant, and one of them re-creates the exact problem this pass
exists to fix: a second distinct custody string on the same page.

---

# PART 2 — the 8 remaining false layers

The prior lane's filter was keyed on the phrase `private half stays in the keychain`. **A broader search
finds FIVE distinct false strings on 16 layers across 16 boards** — sibling phrasings of the same lie:
`this device's keychain`, `held in the keychain`, `never leaves the keychain`.

**Part 1 of the prior lane already fixed 8 of them.** Your grant is the **8 that remain**.

## Establish your own list first — do not take the count on faith

The prior lane's own report notes its count was once wrong (it said 16 where the measured figure was 8).
**Sweep the page yourself**, with a needle broad enough to catch sibling phrasings — search for
`keychain`, `this device`, `created here`, `generated here`, `never leaves`, `held in` — and enumerate
**every** layer that still asserts device-side custody of the private half. **Report your count before
you edit anything.**

## `BP · Rotate Key` is the priority — the exact inverse of A3

It reads **`Generated here · the private half never leaves the keychain`**. Under `9417f8bf`'s A3 the
private half is not generated locally *and* not held locally; it is not SHIP IT's at all. This is the
single worst instance on the page, on the key-rotation screen. **Fix it first.**

## Which string do the others get?

The **approved** one, byte-identical, which the prior lane derived at runtime from the approved `SM`
boards rather than typing it — **derive it that way again:**

```
ed25519 · generated on the server · the private half stays in the secret manager
```

**Except `BP · Rotate Key`, where that string is wrong in a different way.** It is not describing key
custody metadata, it is describing **where generation happens** — and A3's generation is server-side, so
"generated here" is false. **Report the exact current string and your proposed replacement for that layer
and confirm it is A3-consistent before applying it.** If you judge that needs a design decision rather
than a substitution, **stop and report it instead of guessing.**

## The box-height trap will recur

The string is ~80 characters and renders two lines at this size. **On every board you touch, after setting
`characters`, re-read `textBounds` and check for wrap and overlap** — exactly as you did for `BPM`. A
board whose box was sized for a shorter string will overflow. **Report every one you find; do not resize,
do not reflow.** This pass fixes the two `BPM` boxes and their stack **only**.

---

## Penpot discipline — the failures that have actually happened

- **A Penpot write timeout does NOT mean the write failed.** **Twice now in this work item, both writes
  had landed.** Never re-apply on a timeout — **read first**, then decide.
- **Reading `textBounds` in the SAME call that sets `characters` returns a STALE value** (measured
  identical before and after). **A settled re-read needs a separate call.** This is why Part 1 has an
  explicit verify step.
- **Keep every call small and bounded — ONE BOARD PER CALL.** A four-board loop is what timed out.
- **Record each board's result as you go**, with child counts, so a timeout costs one board not the batch.
- **Read `penpot_high_level_overview` before any other Penpot tool.**
- **If a call fails with a timeout or heartbeat error, STOP and report what you have measured.** Do not
  retry in a loop.
- **Penpot has NO version history.** Your recorded before-state is the only record of it.
- **Verify every board id from your own `findShapes` call** — this page has 12 `Add Product` boards and
  the ids share long substrings.
- `parentX`/`parentY` are **READ-ONLY computed** values; find layers by `s.characters`/`s.name`, never by
  constructing a position.

## Also report, do not fix

**The build has FOUR false-claim sites, not the two previously named:** `add_product_page.dart:542` and
`:1038`, plus **`:480-481` and `:979-980`** — the `Ev Body` pair. A fix scoped to the two named sites would
correct the eyebrow while leaving the copy directly beneath it contradicting it. **Verify all four and
report them for the implementer.** Production source is outside your grant.

## Hard rules

- **Run NO Docker or Compose command whatsoever** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has ALREADY lost its QA database to a lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`.** Do not test this rule.
- **Never edit a board you do not own** — especially the four `SM` boards, whose revision is APPROVED.
- Write no production source. Touch no `.decisions/**` or `docs/adr/**`. Commit nothing, push nothing.
- **PERSIST YOUR FULL REPORT TO DISK** at
  `docs/engineering/dispatch/tasks/design-correct-f5-pass2/report.md` in the canonical checkout
  `/Users/alkebut/air/shipit-platform`.
- **Do not approve your own work.** A lane that writes ten boards cannot certify them.

## Report format

```
RESULT: DESIGN_REVISION_COMPLETE | DESIGN_REVISION_BLOCKED
```

Include: your **own sweep count** of remaining false layers before editing; Part 1's before/after bounds
with the resulting gap **compared against the SM reference's 4px**; per-board evidence for Part 2;
**every layer that wrapped or overlapped after the longer string**; the `BP · Rotate Key` replacement you
applied and why it is A3-consistent; the four `add_product_page.dart` sites; and confirmation the four
`SM` boards are untouched.