# Dispatch — integrate-fix-product-detail-custody

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: integrate-fix-product-detail-custody
TASK_TYPE: integrate
FEATURE: Integrate the approved H-R2 custody-claim correction and its golden refresh
AREA: main branch integration — 2 reviewed commits
WORKTREE: /Users/alkebut/air/shipit-platform  (the Manager's canonical checkout)
BRANCH: fix/product-detail-custody-claim -> main
BASE_SHA: 43ede2e
HEAD_SHA: a7b58b1e4801a824a0720834bd229a201241d466
OWNED_PATHS:
  - main (merge ref only)
READ_ONLY_PATHS:
  - apps/control_plane/lib/features/product_detail/product_detail_page.dart
  - apps/control_plane/test/goldens/
PROHIBITED_PATHS:
  - apps/**
  - packages/**
  - docker/**
  - docs/adr/**
  - .decisions/**
ACCEPTANCE_CRITERIA:
  - "main contains both reviewed commits, non-squashed, with history preserved."
  - "Post-integration gates pass at their exact baselines."
  - "origin/main == main, 0/0 ahead/behind."
VALIDATION_COMMANDS:
  - dart pub get
  - dart format --output=none --set-exit-if-changed .
  - cd apps/control_plane && flutter analyze
  - cd apps/control_plane && flutter test
  - bash apps/server/tool/verify_schema_bootstrap.sh
ROUTING_CLASS: STANDARD
```

---

## What you are integrating

Branch `fix/product-detail-custody-claim` in worktree `/private/tmp/shipit-fix-pd-custody`, **two commits**
on top of `main` at `43ede2e`:

| SHA | Subject | Reviewed by |
|---|---|---|
| `878c3327` | `fix(product-detail): correct the false key-custody claim in the Access block` | `focused-reviewer` → `APPROVE_CORRECTIONS` (string approved; merge withheld on R1 only) |
| `a7b58b1e` | `test(goldens): refresh Product Detail mobile baselines after custody-claim fix` | `focused-reviewer` → **`APPROVE_CORRECTIONS`, `READY_FOR_MERGE: YES`** |

Total content: **1 line of Dart source** (`product_detail_page.dart:614`) + **2 regenerated golden PNGs**.
`git diff 43ede2e a7b58b1 --stat` should show 3 files, 1 insertion, 1 deletion, 2 binaries.

Both reviews are at `docs/engineering/dispatch/tasks/review-fix-product-detail-custody-claim/report.md`
and `.../review-fix-product-detail-goldens-r1/report.md`. Read them.

## Integration strategy — fast-forward, do NOT squash

Merge with `--ff-only` so both commits keep their identity and provenance. Both were independently
reviewed at their exact SHAs; squashing would collapse two reviewed revisions into one unreviewed SHA and
destroy the provenance the reviews depend on. **No amend, no rebase, no force-push, no squash.**

## Preconditions to verify before merging

1. `main` is still `43ede2e` and has not advanced. If it has, **stop and report `INTEGRATION_BLOCKED`** —
   do not rebase someone else's reviewed history.
2. `a7b58b1`'s parent chain is exactly `878c332` → `43ede2e`. Confirm no unexpected commits.
3. The worktree diff is still 3 files. If the source change or goldens differ from what was reviewed,
   **stop and report `INTEGRATION_BLOCKED`**.

## Post-integration gates — run on merged `main`, report verbatim

- `dart format --output=none --set-exit-if-changed .` → expect `631 files (0 changed)`
- `cd apps/control_plane && flutter analyze` → expect `No issues found!`
- `cd apps/control_plane && flutter test` → expect `+190: All tests passed!`
- `bash apps/server/tool/verify_schema_bootstrap.sh` → expect pass

Run `dart pub get` at the **REPO ROOT** first if `.dart_tool/` is missing.

## Constraints

- **Do not push with `--force`.** Plain `git push origin main`.
- **Do not delete** the lane worktree `/private/tmp/shipit-fix-pd-custody` or its branch — the Manager
  cleans those up after verifying the push.
- **ZERO Docker/Compose commands.** The QA stack is up and healthy; do not touch it. Not `ps`, not `logs`.
- Do not commit the pre-existing modified tracked files in the canonical checkout. That checkout has
  long-standing unrelated modifications under `apps/control_plane/test/failures/` and QA scratch files,
  dated weeks before this work. **Leave them exactly as they are, unstaged.** A `git commit -a` or
  `git add -A` would sweep them in — stage only the merge.

## Authority

Independent approval is in hand, so you are authorized to merge and push `main`. Report
`MERGE_APPROVED` with the resulting `main` SHA and the `main...origin/main` counts.