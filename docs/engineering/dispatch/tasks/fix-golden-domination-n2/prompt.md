# Dispatch — fix-golden-domination-n2

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: fix-golden-domination-n2
TASK_TYPE: implement
FEATURE: Add a tolerance-domination CI check and regenerate the 44 stale golden baselines
AREA: apps/control_plane/test/goldens + golden test helpers + CI workflow
WORKTREE: /private/tmp/shipit-fix-golden-domination
BRANCH: fix/golden-domination-n2
BASE_SHA: 1657082
OWNED_PATHS:
  - apps/control_plane/test/**
  - .github/workflows/**
READ_ONLY_PATHS:
  - apps/control_plane/lib/features/product_detail/product_detail_page.dart
  - apps/control_plane/lib/features/products/add_product_page.dart
  - docs/engineering/dispatch/tasks/fix-product-detail-goldens-r1/report.md
  - docs/engineering/dispatch/tasks/review-fix-product-detail-goldens-r1/report.md
  - .decisions/cff0e948-80a5-48ab-9a7b-f2a99be6f870.yaml
PROHIBITED_PATHS:
  - apps/control_plane/lib/**
  - apps/server/**
  - packages/**
  - docker/**
  - docs/adr/**
  - .decisions/**
  - .agents/**
  - .claude/**
  - .junie/**
  - .opencode/**
ACCEPTANCE_CRITERIA: >
  A check exists that FAILS the build when a golden's pixel delta is dominated by the tolerance,
  such that a stale baseline cannot silently report PASS. All 44 stale baselines are regenerated
  so none is knowingly out of step with its source. golden_tolerance.dart's threshold is
  unchanged at 0.005. No test is weakened, skipped, @Ignore'd, or deleted.
VALIDATION_COMMANDS:
  - dart pub get
  - dart format --output=none --set-exit-if-changed .
  - cd apps/control_plane && flutter analyze
  - cd apps/control_plane && flutter test
ROUTING_CLASS: STANDARD
```

---

## Authority

Human Decision `cff0e948-80a5-48ab-9a7b-f2a99be6f870`, **RESOLVED / OPTION_A** ("Add the domination
check + regenerate all 44"), via the structured question UI on 2026-10-08. Read it — it is your authority
and it contains scope discipline you must follow.

## The defect you are fixing

**A green golden test does not mean a current golden.**

`apps/control_plane/test/helpers/golden_tolerance.dart:43` installs a tolerant comparator:

```dart
void useTolerantGoldens({double threshold = 0.005}) {
```

At **0.005** a re-wrapped copy line falls inside tolerance, so a stale baseline reports PASS. Measured:
the Product Detail mobile baseline sat **0.3172%** of pixels (0.3172% of 329160 px, peak channel delta
212/255) from the current render — under threshold, therefore invisible. That baseline was still painting
a **retired security claim** ("The private half never leaves this device.") to any human golden reviewer
while the suite went green.

Manager sweep of all 54 goldens, 2026-10-08: **44 carry no Needs-you nav badge; 10 do** (at 196 and 200
orange pixels). The 44 are the same stale-frame class. Every one passes only because its delta sits under
tolerance.

## Part 1 — the check (the durable fix)

Implement a check that **distinguishes "changed a little, legitimately" from "stale and silent."**

Design notes, not prescriptions:

- The comparator must keep doing a **real byte/pixel comparison**. Your check is a **classification layer
  on top**, not a replacement for it.
- A useful discriminator: compare each golden's current render against its baseline and against a
  **freshly rendered** capture, and report the delta **as a number**. A baseline whose delta is within
  tolerance of a known-good render is fine; the failure mode to catch is a baseline that is stale yet
  under tolerance. Consider what "known-good render" means — it may require regenerating and diffing
  against a second capture rather than trusting a single pass.
- Wire it into the **CI workflow** you own (`.github/workflows/`), not only into a local test, or it will
  not prevent recurrence.
- It must **fail loudly** and name the file and the measured delta.

## Part 2 — regenerate the 44

Regenerate every golden in the stale set using the project's normal mechanism. **Confirm the exact
invocation from in-repo sources first — do not guess a flag.** (`add_product_ui_learning.md:53`,
`DESIGN-HANDOFF.md:535` and `S2_NON_VISUAL_RELEASE_BLOCKER_CLOSURE.md:609` document it; verify.)

- After regeneration, the badge sweep should show **all 54 carrying the badge**. Verify this yourself and
  report the numbers.
- Report the regenerated file list **explicitly**, so a 44-binary diff is reviewable by name rather than
  content. Do not hide it in a summary count.

## Absolute prohibitions

- **`golden_tolerance.dart` must not change.** Not the threshold, not the comparator, not a bypass. The
  tolerance is not the defect; the stale baseline is. It is blob-identical across `43ede2e`, `878c332` and
  `a7b58b1` and must stay so. Widening or weakening it to force a pass is a task failure.
- **No test may be weakened, skipped, `@Ignore`d, filtered, or deleted** to make the suite pass.
- **No production source change.** `apps/control_plane/lib/**` is PROHIBITED. The copy is correct; if a
  golden disagrees with source, the golden is wrong, not the source.
- **`make test-integration`: NOT required.** You need no database.
- **ZERO Docker/Compose commands** — not `ps`, not `logs`, not `info`. This repository has already lost its
  QA database irrecoverably to a lane that ran a `down -v`. The QA stack is up and healthy and must not be
  disturbed.
- Do not regenerate goldens outside `apps/control_plane/test/goldens/**`.

## Gates — verbatim output required

| Gate | Command | Expected |
|---|---|---|
| deps | `dart pub get` at **REPO ROOT** | `Got dependencies!` |
| format | `dart format --output=none --set-exit-if-changed .` | `631 files (0 changed)` |
| analyze | `cd apps/control_plane && flutter analyze` | `No issues found!` |
| tests | `cd apps/control_plane && flutter test` | `+190: All tests passed!` (or more if you added a test file) |

If a gate fails, report `IMPLEMENTATION_BLOCKED` and stop. Do not weaken anything to make it pass.

## Report requirements beyond the standard contract

1. The **badge sweep after regeneration** — how many of 54 carry the badge.
2. The **regenerated file list**, by name.
3. `git diff --stat <BASE_SHA>` and the split between `.dart`/workflow files and binaries.
4. Explicit confirmation that `golden_tolerance.dart` is unchanged, with its blob hash before and after.
5. What your check does when it fires — and **prove it fires**: demonstrate it failing on a deliberately
   stale baseline (e.g. temporarily revert one golden, show the check fails, restore it). A check that has
   never been observed failing is not a check.

## Other lanes

- `design-qa-startup-restructure` holds design artifacts and compose/entrypoint **design only**; you own
  `test/**` and CI. No overlap.
- Two design re-reviewers are read-only.
- Manager holds `LANES.md` / `WORK_STATE.md` / `.decisions/**`.

Report `SAFE_PARALLEL_WORK` and `PROHIBITED_PARALLEL_WORK`.

## Cleanup

Commit in **logical commits** (check/CI separately from the 44 binaries — they are independently
reviewable and should be separable). **Do not push, do not merge, do not touch `main`.** Start no
container and no database, so there is nothing to tear down.

## You cannot approve this

You are writing CI gates every future build depends on. Report `READY_FOR_INDEPENDENT_REVIEW: YES` with
recommended next action `INDEPENDENT_REVIEW`. An independent `engineering-reviewer` will verify you.