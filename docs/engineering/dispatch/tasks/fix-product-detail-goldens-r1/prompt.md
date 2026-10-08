# Dispatch — fix-product-detail-goldens-r1

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: fix-product-detail-goldens-r1
TASK_TYPE: correct
FEATURE: Regenerate the two Product Detail mobile goldens so they stop painting a retired security claim
AREA: apps/control_plane/test — golden baselines for product_detail_mobile_back_link
WORKTREE: /private/tmp/shipit-fix-pd-custody
BRANCH: fix/product-detail-custody-claim
BASE_SHA: 878c3327aea383a2501fe7d698282b9dcc0bb586
OWNED_PATHS:
  - apps/control_plane/test/goldens/product_detail_mobile_back_link.png
  - apps/control_plane/test/goldens/product_detail_mobile_back_link_dark.png
READ_ONLY_PATHS:
  - apps/control_plane/test/product_detail_mobile_golden_test.dart
  - apps/control_plane/test/helpers/golden_tolerance.dart
  - apps/control_plane/lib/features/product_detail/product_detail_page.dart
  - docs/engineering/dispatch/tasks/review-fix-product-detail-custody-claim/report.md
PROHIBITED_PATHS:
  - apps/control_plane/test/helpers/**
  - apps/control_plane/test/**.dart
  - apps/control_plane/test/goldens/** (every golden other than the two named above)
  - apps/control_plane/lib/**
  - apps/server/**
  - packages/**
  - docker/**
  - docs/adr/**
  - .decisions/**
ACCEPTANCE_CRITERIA:
  - "Both goldens are regenerated from the current source and now show the secret-manager custody clause."
  - "NEITHER golden_tolerance.dart NOR any test .dart file is modified — tolerance is not widened."
  - "No golden other than the two named is modified."
  - "The regenerated light golden visually reads: One key per repository. The private half stays in the secret manager."
  - "format, analyze, and tests pass, and the golden test now exercises a real comparison."
VALIDATION_COMMANDS:
  - dart pub get
  - dart format --output=none --set-exit-if-changed .
  - cd apps/control_plane && flutter analyze
  - cd apps/control_plane && flutter test
ROUTING_CLASS: STANDARD
```

---

## Context

You are continuing in the **same worktree and on the same branch** as the preceding correction
(`fix-product-detail-custody-claim`, NEW_HEAD `878c3327`). That lane is finished; you are the only writer.
You will add **one new commit** on top.

That lane changed one string at
`apps/control_plane/lib/features/product_detail/product_detail_page.dart:614`:

```diff
-  'One key per repository. The private half never leaves this device.',
+  'One key per repository. The private half stays in the secret manager.',
```

All four gates passed. An independent `focused-reviewer` then returned **`APPROVE_CORRECTIONS`** on the
string itself — the composition is correct — but raised one HIGH regression that it could not fix itself,
because `apps/control_plane/test/**` was PROHIBITED to the preceding lane. **That regression is your task.**

## R1 — the goldens still paint the retired claim

`apps/control_plane/test/goldens/product_detail_mobile_back_link.png` and its `_dark` sibling render
Product Detail at the 390 px mobile viewport and **therefore paint the Access block**, including the line
you just changed. The reviewer opened the light golden and confirmed it still shows:

> One key per repository. The private half never leaves
> this device.

Both files were last generated at `0d5d132`, so the render is necessarily stale.

**The dangerous part:** `flutter test` still reports the golden test as **passing**. `useTolerantGoldens()`
in `apps/control_plane/test/helpers/golden_tolerance.dart:43` installs a comparator with
`threshold = 0.005`, and the re-wrapped line falls inside that tolerance. So the only visual guard on
Product Detail mobile **no longer constrains this copy at all**, and a human golden reviewer looking at
the baseline is shown a **false security guarantee** that the product no longer makes.

## What to do

Regenerate **exactly those two goldens** from the current source, using the project's normal golden-update
mechanism (`flutter test --update-goldens` scoped to the Product Detail golden test — confirm the exact
invocation from the test file and any project docs first; do not guess a flag).

**Hard constraints:**

- **Never widen or otherwise touch `golden_tolerance.dart`.** The tolerance is not the defect; the stale
  baseline is. Changing the comparator to force a pass would hide future regressions.
- **Never modify any test `.dart` file.** No assertion change, no skip, no `@Ignore`, no filter.
- **Regenerate only the two named goldens.** The repo has **54** goldens; the other 52 must be
  byte-identical. If `--update-goldens` rewrites others, revert those and report it — a broad rewrite
  would mean other copy drifted and that is a separate finding, not yours to silently absorb.
- Do **not** touch `apps/control_plane/lib/**`. The string is already correct.

## Verification you must perform and report

1. **Visually confirm** the regenerated `product_detail_mobile_back_link.png` reads
   `One key per repository. The private half stays in the secret manager.` **Open the image and look at
   it** — do not infer it from the source string. Report what you actually see.
2. Report the diff against `878c3327`: expect **2 files changed, 2 insertions, 2 deletions** (binary),
   and `git status --porcelain` showing **exactly those two paths**.
3. Confirm `git diff --stat 43ede2e` (the branch point) still shows the original one-line source change
   **plus** the two goldens — i.e. no test `.dart` file and no third file crept in.
4. Re-run the full gate set and report verbatim output. Run `dart pub get` at the **REPO ROOT** first if
  `.dart_tool/` is missing.

## A note on what you will and will not be able to prove

Regenerating the baseline makes it *current*; it does **not** prove the copy is *correct*. No board scopes
copy to `:614` — the reviewer confirmed this as a separate open MEDIUM finding (F1, design-authority gap).
Your golden is a **candidate for human review**, exactly as the test file's own header says. Do not claim
board verification, and do not treat "the golden now matches" as evidence the string is approved. Say so
plainly in your report.

## Other lanes

No other lane is writing `apps/control_plane/test/goldens/**`. The Manager holds
`docs/engineering/dispatch/LANES.md` and `WORK_STATE.md`; design lanes hold `.decisions/**` and
`docs/adr/**`. Report `SAFE_PARALLEL_WORK` and `PROHIBITED_PARALLEL_WORK`.

## Cleanup

- **ZERO Docker/Compose commands** — not `ps`, not `logs`, not `info`. The QA stack is up and healthy and
  must not be disturbed. This repository has already lost its QA database irrecoverably to a lane that ran
  a `down -v`.
- `make test-integration`: **NOT required** — golden baselines need no database.
- Commit your two regenerated binaries in **one commit** on the existing branch. **Do not push, do not
  merge, do not touch `main`.**

## You cannot approve this

Report `READY_FOR_FOCUSED_REVIEW: YES` with recommended next action `FOCUSED_RE_REVIEW`. A fresh
independent `focused-reviewer` will verify you.