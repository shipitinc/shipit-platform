# Subtask Prompt — implement-add-product-custody-and-footer (the build side of the Add Product rebuild)

Persisted per `aef-orchestrator` §14 before launch, §2 bookkeeping only.

```yaml
MANAGER: orchestrator-main
TASK_ID: implement-add-product-custody-and-footer
TASK_TYPE: implement
FEATURE: Add Product rebuild — correct the false key-custody copy and the forbidden footer copy in the build
AREA: apps/control_plane/lib/features/products/add_product_page.dart and the shared TechnicalDetails primitive
WORKTREE: /private/tmp/shipit-implement-custody-footer
BRANCH: implement/add-product-custody-and-footer
BASE_SHA: 52d0894
OWNED_PATHS:
  - apps/control_plane/lib/features/products/add_product_page.dart
  - apps/control_plane/lib/core/design_primitives.dart        (ONLY the TechnicalDetails primitive)
  - apps/control_plane/test/**                                  (tests you add)
READ_ONLY_PATHS: apps/**, packages/**, docs/**, .decisions/**
PROHIBITED_PATHS:
  - packages/**                       (no server-side work; the substrate is unbuilt)
  - apps/server/**
  - docker/**, .github/**
  - .decisions/**, docs/adr/**, WORK_STATE.md, LANES.md
  - apps/control_plane/test/failures/**   (pre-existing dirty binary baselines — NOT yours)
ACCEPTANCE_CRITERIA: |
  The build no longer asserts device-side custody of the deploy-key private half, and no longer
  renders the footer copy 27ea6536 forbids — on either platform — without deleting the body prose
  the decision never condemned.
VALIDATION_COMMANDS:
  - cd apps/control_plane && flutter analyze
  - cd apps/control_plane && flutter test
  - cd apps/control_plane && dart format --output=none --set-exit-if-changed lib test
ROUTING_CLASS: PRECISION
```

## Isolation pre-flight

```bash
git worktree add -b implement/add-product-custody-and-footer /private/tmp/shipit-implement-custody-footer 52d0894
cd /private/tmp/shipit-implement-custody-footer && git rev-parse --short HEAD
```

**Note the pre-flight hazard this work item has hit repeatedly:** `git merge --ff-only` fails when
untracked files shadow content already on the branch. If a fast-forward is refused, **compare the
shadowing files byte-for-byte, back them up outside the repo, and move rather than delete.**

## THE TRAP THAT WILL HURT YOU — read this before touching `:409`

`Registering records the product…` occurs **three** times in this file:

| site | what it is | in scope? |
|---|---|---|
| `:318` | `TechnicalDetails(note:)` — footer band | **YES — remove** |
| `:927` | `TechnicalDetails(note:)` — footer band | **YES — remove** |
| **`:409-411`** | **mid-page body prose under "What you're registering"** | **NO — DO NOT TOUCH** |

`27ea6536` forbids **footer copy**. It says nothing about mid-page explanatory prose, and `:409-411` is
exactly that. **A search-and-replace on this string would delete copy the decision never condemned.**
**Scope the change to the two `TechnicalDetails` sites only, by their call sites, not by their text.**

## Part 1 — the four false key-custody sites

Under `9417f8bf`'s **A3 (external secret manager)**, the private half is **not on the device and not in
any local keychain** — it is not SHIP IT's at all — and **generation is server-side**. Four sites:

| site | what it says | approved replacement |
|---|---|---|
| `:480-481` | `Ev Body` — desktop | from the draft, below |
| `:542` | key-meta eyebrow — desktop | `ed25519 · generated on the server · the private half stays in the secret manager` |
| `:979-980` | `Ev Body` — mobile | from the draft, below |
| `:1038` | key-meta eyebrow — mobile | same string as `:542` |

**The replacements are drafted and human-approved.** Read them here — **do not invent copy**:

`docs/engineering/dispatch/tasks/design-draft-f5-copy/report.md` **§7** carries the four
`add_product_page.dart` proposals with measured fit.

⚠ **The eyebrow replacement is 80 characters and the desktop board measured it at 392.78px against a
380px box — it does NOT fit.** The drafting lane found this and drafted a shorter fitting variant. **Use
the variant from §7, not the 80-char string.** A string that overflows its box is the exact regression
that cost this work item three lanes on the boards.

⚠ **The boards and the build currently diverge**, and the draft reports it precisely: the **eyebrow** is
current on the boards but stale in the build, while the **body** is stale on **both**. Fix all four, or
the build will contradict the boards on one axis while both contradict A3 on the other.

## Part 2 — the three forbidden footer sites

`27ea6536` resolved that Add Product carries **no footer copy**, on either platform:

| site | what it is | action |
|---|---|---|
| `:380` | duplicate `ContentRule` inside `_buildFooter` | removed with the block |
| `:383-384` | the footer copy string | removed with the block |
| `:314` | the `_buildFooter` **call site** | remove the call |
| `:317-319` | desktop `TechnicalDetails(note:)` | remove the `note:` argument |
| `:926-928` | mobile `TechnicalDetails(note:)` | remove the `note:` argument |

**Delete `_buildFooter` entirely** — it is the source of both the copy and the duplicate rule — **and its
call site at `:314`.** Then drop `note:` at the two `TechnicalDetails` sites.

⚠ **Verify each site against source rather than trusting these line numbers.** This work item has a long
record of a lane adopting a cited `:NNN` that was 40+ lines off — one citation in a **resolved human
decision** was 43 lines wrong and survived four passes. Confirm the string and the structure at each
line you touch.

## Part 3 — the `TechnicalDetails` primitive (D-2, Level 1, already decided)

`apps/control_plane/lib/core/design_primitives.dart:396` **paints the `ContentRule` unconditionally**, and
`:398-410` renders `Row[Expanded(note ?? SizedBox.shrink()), InlineLink]`.

That means:

- **Desktop's** spec — divider + **right-aligned** disclosure + no copy — is produced **for free** by
  passing `note: null`. **No change needed for desktop.**
- **Mobile's** spec — left-aligned, **no divider** — is **NOT expressible today.**

The human has already decided the outcome: `27ea6536` states mobile is left-aligned with **no divider**.
**Extend `TechnicalDetails` so it can suppress its `ContentRule` and align its disclosure start-aligned.**
This is a **Level 1 design-system-owner notification, not a human gate** — the outcome is settled.

⚠ **⚠ THIS IS A SHARED PRIMITIVE.** It is used by **every** form in the app, not just Add Product.
**Default every new parameter to today's behaviour**, so no other call site changes. Then verify the
caller count before and after — if any other form's rendering shifts, that is a regression, not a
consequence.

⚠ **The em dash and the exact string matter.** Do not normalise punctuation in the copy you keep.

## Hard rules

- **Run NO Docker or Compose command whatsoever** — not `info`, not `ps`, not `logs`, not `config`, not
  any mutating one. **This repository has ALREADY lost its QA database to a lane running
  `docker compose -f docker/compose.qa.yaml down -v --rmi local`.** Do not test this rule.
- Write only inside `OWNED_PATHS`. **No `packages/**` and no `apps/server/**`** — the substrate
  (`SecretProvider`, the three endpoints) does not exist and A3's reachability is `UNVERIFIED`. Building
  against it would be inventing architecture.
- **Do not touch `apps/control_plane/test/failures/**`** — 48 pre-existing dirty binary baselines, not
  yours. Do not stage, revert or clean them.
- Do not commit or push unless instructed. **It is not.** Leave the tree for review; the Manager commits.
- **Do not approve your own work.**
- **PERSIST YOUR FULL REPORT TO DISK** before returning, conforming to
  `.agents/skills/aef-orchestrator/templates/subtask-report.md`, with the `RESULT:` block verbatim from
  `.agents/agents/implementer.md`.
- **Zero tests import `add_product_page.dart`** — 0 of 26 test files. Whatever you change here is
  **unverified by any existing test.** If you add coverage, say so; if you do not, say that plainly
  rather than implying the gates cover it.

## Gates

Run each and report its exact result against these baselines:

- `dart format --output=none --set-exit-if-changed .` — baseline **631 files, 0 changed**
- `flutter analyze` (apps/control_plane) — baseline **0 errors**, and the file's own note
- `flutter test` — baseline **190/190**
- `make test-integration` — **only if you need it.** It is the sole sanctioned way to get a real
  database: disposable, project `shipit_integration_<pid>`, self-cleaning on success, failure and
  interrupt alike. You almost certainly do not — this is a copy change with no data path.

**`NOT_RUN` is acceptable; a fabricated pass is not.** A count differing from baseline is a finding to
investigate, not something to absorb.

## Report format

Report per `.agents/skills/aef-orchestrator/templates/subtask-report.md` with the `RESULT:` block verbatim
from `.agents/agents/implementer.md`. Include: per-site before/after for all seven build sites, **proof
you did not touch `:409-411`**, the `TechnicalDetails` signature change with its default, the caller count
before and after, and every gate's exact result.