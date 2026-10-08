# Dispatch — fix-product-detail-custody-claim

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: fix-product-detail-custody-claim
TASK_TYPE: correct
FEATURE: Remove the last false key-custody claim (H-R2) from Product Detail
AREA: apps/control_plane — product_detail feature, one string literal
WORKTREE: /private/tmp/shipit-fix-pd-custody
BRANCH: fix/product-detail-custody-claim
BASE_SHA: 43ede2e
OWNED_PATHS:
  - apps/control_plane/lib/features/product_detail/product_detail_page.dart
READ_ONLY_PATHS:
  - apps/control_plane/lib/features/products/add_product_page.dart
  - docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r3.md
  - docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-2.md
  - docs/adr/0018-per-product-git-credentials.md
  - docs/engineering/dispatch/LANES.md
PROHIBITED_PATHS:
  - apps/server/**
  - packages/**
  - docker/**
  - .github/**
  - .decisions/**
  - docs/adr/**
  - apps/control_plane/test/**
  - apps/control_plane/lib/features/products/**
  - apps/control_plane/lib/shared/**
  - .claude/**
  - .junie/**
  - .opencode/**
ACCEPTANCE_CRITERIA:
  - "The false claim at product_detail_page.dart:614 is gone from the source."
  - "The replacement preserves the per-repository framing (this block lists one credential per repository)."
  - "The replacement states custody per A3: the private half is held in the secret manager, never shown/logged/stored."
  - "No other line in the file changes. No test file changes. No new file."
  - "format, analyze, and tests pass at their exact existing baselines."
VALIDATION_COMMANDS:
  - dart pub get
  - dart format --output=none --set-exit-if-changed .
  - cd apps/control_plane && flutter analyze
  - cd apps/control_plane && flutter test
ROUTING_CLASS: PRECISION
```

---

## The finding

`apps/control_plane/lib/features/product_detail/product_detail_page.dart:614`, inside `_AccessBlock`:

```dart
Text(
  'One key per repository. The private half never leaves this device.',
  style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
),
```

This is **H-R2** from `docs/engineering/dispatch/tasks/design-addproduct-mobile/design-revision-2.md:456`,
raised by the mobile design review and routed as **production source — PROHIBITED to that lane**, so it
was never fixed by the four-site custody correction that shipped as `c32f4f4`. It is the **last** false
key-custody claim anywhere in the client.

`grep -rniE "never leaves|stays on this device|created on this device|keychain"` over
`apps/control_plane/lib` returns this line plus four **unrelated, correct** "this device" strings
(`sidebar.dart` "Signed in on this device"; `decision_detail_page.dart` ×2 and
`defect_detail_page.dart` "Saved as you, on this device"). Those describe *session/decision authorship*,
not key custody. **Leave all four alone.** Do not "fix" them.

## Why the claim is false

Human Decision `9417f8bf` (A3) and `ADR 0018` establish that the private half is transmitted to an
**external secret manager** and is never persisted locally. The literal is false on the same axis as the
four sites already corrected.

## The replacement value — use this, and only this

The approved F5 string registry, `docs/engineering/dispatch/tasks/design-apply-f5-copy/report-r3.md` §5.3
"the approved strings, verbatim from the draft", gives the approved custody vocabulary. Two entries bear
directly on this slot:

- key **B** — `One key, for this product only. The private half stays in the secret manager.`
  → goes to `L Sub` ×2
- key **A** — `It clones over SSH. The private half stays in the secret manager — never shown, logged or stored.`
  → goes to `Ev Body` ×4

Key **B** is the structurally-matching entry: a two-sentence access-block subtitle whose second sentence
is the custody statement, exactly the shape of `:614`. Its custody clause
(`The private half stays in the secret manager.`) is **already shipped and verified** at
`add_product_page.dart:460` and `:958` as string A, confirmed byte-for-byte against 4 boards.

**Critical — do not copy key B verbatim.** Its first sentence, *"One key, for this product only"*, is a
**different fact** from what `:614` says. `:614` says **one key per repository**, and that is the truth
here: `_AccessBlock` iterates `detail.repositories` and pairs each with its own
`detail.credentials` entry, so there is one credential **per repository**, not per product. Copying B
verbatim would replace one false claim with a different false claim. This is precisely the class of error
the mobile review caught in G6.

So: **keep the first sentence's meaning (`One key per repository.`) exactly as it is, and replace only the
second sentence** with the approved custody clause. Concretely, the target is:

```dart
Text(
  'One key per repository. The private half stays in the secret manager.',
  style: ShipItType.monoMeta.copyWith(color: palette.inkTertiary),
),
```

If you believe a different value is correct, **stop and report `IMPLEMENTATION_BLOCKED`** with your
reasoning rather than shipping a value you invented. There is a real design-authority gap here — no board
designs Product Detail's `Access` block, and the approved registry has no entry scoped to
`product_detail_page.dart:614`. The Manager has made the call that the minimal edit — preserve the true
per-repository clause, swap the false custody clause for the board-approved one — is within reach of
existing approved copy. Flag it in your report either way.

## Constraints

- **Style:** this file uses plain ASCII apostrophes are irrelevant here (no apostrophe in the string), but
  note `product_detail_page.dart` — match the file's existing quoting convention exactly. Do not
  introduce `\u00b7` escapes or any escape sequence; the target string contains none.
- **Do not touch** `TechnicalDetails(note:)` at `:442`, which a previous lane already handled. Do not
  touch anything else in the file.
- **No test may be added, modified, weakened, skipped, `@Ignore`d, or deleted.** A string-literal change
  with no test is the established pattern in this work item.
- **`make test-integration`: NOT required** — string literal, no data path.
- **Docker: issue ZERO commands.** Not `ps`, not `logs`, not `info`. This repository has already lost its
  QA database irrecoverably to a lane that ran a `down -v`. You do not need a database. The QA stack is
  currently up and healthy at the Manager's request and must not be disturbed.
- **Penpot: you have no Penpot access** and need none — the approved values are in the registry file you
  are given read access to. Do not claim board verification you did not perform.

## Gates — report exact output

| Gate | Command | Expected baseline |
|---|---|---|
| deps | `dart pub get` at **repo root** (fresh worktree) | `Got dependencies!` |
| format | `dart format --output=none --set-exit-if-changed .` | `631 files (0 changed)` |
| analyze | `cd apps/control_plane && flutter analyze` | `No issues found!` |
| tests | `cd apps/control_plane && flutter test` | `+190: All tests passed!` |

`dart pub get` MUST be run at the repository root before the format gate — a fresh worktree has no
`.dart_tool/`, and running it in a subpackage has previously produced spurious changes under
`apps/server` (PROHIBITED to you — if you see any, do not stage them).

Report the **verbatim** output line for each gate. If a gate fails, report `IMPLEMENTATION_BLOCKED` and
stop — do not weaken anything to make it pass.

## Scope proof required in your report

Prove the edit is exactly one line. Reconstruct the pre-edit state and diff, and report:
- the differing line numbers (expect exactly `[614]`)
- the file's line count before and after (must be identical)
- `git diff --stat` against `BASE_SHA` (expect `1 file changed, 1 insertion(+), 1 deletion(-)`)
- `git status --porcelain` (expect exactly one entry)

## Other lanes running

None are writing `apps/control_plane/lib/features/product_detail/product_detail_page.dart`. Design lanes
hold `.decisions/**` and `docs/adr/**`; the Manager holds `docs/engineering/dispatch/LANES.md` and
`WORK_STATE.md`. Report `SAFE_PARALLEL_WORK` and `PROHIBITED_PARALLEL_WORK`.

## Cleanup

Commit your change with a conventional commit message on your branch. **Do not push, do not merge, do not
touch `main`.** Nothing to tear down — you started no container and no database.

## You cannot approve this

Report `READY_FOR_FOCUSED_REVIEW: YES` and a recommended next action of `FOCUSED_RE_REVIEW` when
`RESULT: CORRECTION_COMPLETE`. A fresh independent `focused-reviewer` will verify you. Do not
self-certify.