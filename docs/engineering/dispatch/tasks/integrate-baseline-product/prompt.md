MANAGER: orchestrator-main
TASK_ID: integrate-baseline-product
TASK_TYPE: integrate
FEATURE: Integrate the product baseline commit onto main
AREA: repository
WORKTREE: /Users/alkebut/air/shipit-platform (canonical checkout, branch baseline/product-2026-10-05)
BRANCH: baseline/product-2026-10-05
BASE_SHA: 0d5d132
OWNED_PATHS:
  - (none — verify and report only; you must not merge, push, rebase, or rewrite history)
READ_ONLY_PATHS:
  - apps/**
  - packages/**
  - docker/**
  - docs/**
  - .decisions/**
  - framework-manifest.yaml
PROHIBITED_PATHS:
  - (all paths are read-only for this lane)
ACCEPTANCE_CRITERIA: >
  Verify the baseline commit is genuinely integration-ready and report a safe
  integration strategy. Per aef-orchestrator §10 you MUST stop at
  RESULT: MERGE_APPROVED / READY_FOR_INTEGRATION and MUST NOT push, merge,
  force-push, squash, or rebase. Repository policy does not authorize integration.
VALIDATION_COMMANDS:
  - git -C /Users/alkebut/air/shipit-platform log --oneline -3
  - git -C /Users/alkebut/air/shipit-platform status --porcelain
  - git -C /Users/alkebut/air/shipit-platform rev-list --left-right --count main...baseline/product-2026-10-05
  - git -C /Users/alkebut/air/shipit-platform rev-list --left-right --count origin/main...baseline/product-2026-10-05
  - git -C /Users/alkebut/air/shipit-platform diff --stat bfbbd68..0d5d132
  - cd /private/tmp/shipit-verify-baseline && flutter pub get && cd apps/control_plane && flutter analyze --no-pub && flutter test --no-pub
ROUTING_CLASS: STANDARD

## Isolation pre-flight

```bash
cd /Users/alkebut/air/shipit-platform
git rev-parse --short HEAD            # must equal 0d5d132
git branch --show-current             # must equal baseline/product-2026-10-05
```

Do NOT create or switch worktrees in the canonical checkout. To verify the baseline
independently, create your OWN throwaway worktree OUTSIDE the canonical checkout:

```bash
git worktree add --detach /private/tmp/shipit-verify-baseline 0d5d132
```

## Original request (verbatim)

> Fix analyze in place first

That was the human's selection of OPTION_C for Human Decision
`130f3a7e-c364-4c1e-acd5-409d7af80675`. The full option text was:

> Correct the three client_provider.dart JS-interop errors directly in the canonical
> checkout, verify flutter analyze is green, then create the baseline commit.

The analyze fix is done and independently reviewed. The baseline commit has been
created. Your lane verifies whether it is safe to integrate and reports the strategy.

## Context and authoritative sources

- Product/requirement artifact: `.decisions/130f3a7e-c364-4c1e-acd5-409d7af80675.yaml` (RESOLVED, OPTION_C)
- Architecture / repository rules: `AGENTS.md` (note: § Product-specific policy is still `TBD`; there is NO project-declared validation gate and NO project-declared path ownership map)
- Design Contract / approved design revision ref: n/a (infrastructure/baseline work)
- QA Contract ref: n/a
- ADRs / recorded decisions that apply: `.decisions/130f3a7e-c364-4c1e-acd5-409d7af80675.yaml`
- Dependencies that must already be merged: none
- Other lanes currently running (and their OWNED_PATHS): none
- Work this lane blocks: FEATURE c46b6807 and every future production-writing lane
- Open Human Decision ids this lane depends on: 130f3a7e (RESOLVED)

## State you must verify

- `main` is at `bfbbd68` and is 1 commit ahead of `origin/main` (`ea9b03d`).
- `baseline/product-2026-10-05` is at `0d5d132`, one commit on top of `bfbbd68`.
- `0d5d132` adds 585 files. It is **EXPLICITLY UNREVIEWED** except for the
  runtime-config change, which passed independent engineering review with
  `RESULT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP` (see
  `docs/engineering/dispatch/tasks/review-runtime-config-interop/`).
- The canonical checkout has 62 leftover working-tree entries that were
  deliberately NOT committed: golden-test byproducts under
  `apps/control_plane/test/failures/`, ten root-level operator scratch files
  (`check_baselines.sql`, `check_facts{,2,3}.sql`, `export_human_claims.sql`,
  `insert_baseline.sql`, `insert_decision.sql`, `insert_human_facts.sql`,
  `human_claims_export.txt`, `wipe_database.sql`), `cloudbuild.release.yaml.archive`,
  and `.aef/`.

## Acceptance criteria

- [ ] Confirm `0d5d132` is a single clean commit on top of `bfbbd68` with no unrelated history rewriting
- [ ] Confirm the 585-file diff contains no committed secrets, credentials, private keys, build outputs, or `node_modules`
- [ ] Confirm the baseline is functionally sound from a FRESH worktree: deps resolve, `flutter analyze` reports 0 errors, and `flutter test` passes
- [ ] Report the exact `main...baseline` and `origin/main...baseline` ahead/behind counts
- [ ] State a concrete, safe integration strategy and its risks — in particular whether this unreviewed 585-file baseline should land on `main` before or after the feature work it unblocks
- [ ] Identify anything that would make integration unsafe, and say so plainly if so

## Required validation commands

Run each and report the exact result. Report `n/a` only with a stated reason.

- [ ] `git log --oneline -3` and `git status --porcelain` on the canonical checkout
- [ ] `git rev-list --left-right --count main...baseline/product-2026-10-05`
- [ ] `git rev-list --left-right --count origin/main...baseline/product-2026-10-05`
- [ ] `git diff --stat bfbbd68..0d5d132` — confirm the scope matches what is claimed
- [ ] Fresh-worktree verification: `git worktree add --detach /private/tmp/shipit-verify-baseline 0d5d132`, then `flutter pub get`, then in `apps/control_plane`: `flutter analyze --no-pub` (must be 0 errors) and `flutter test --no-pub` (must pass)
- [ ] `git diff --cached --stat` and `git show --stat 0d5d132` — confirm the commit contains what it claims and nothing else
- [ ] Remove your throwaway worktree when finished: `git worktree remove /private/tmp/shipit-verify-baseline --force`

Do not weaken, skip, delete, or ignore a test to reach a green result.

## Hard rules for the child

- **DO NOT merge, push, force-push, rebase, squash, reset, or rewrite history.** You stop at
  `RESULT: MERGE_APPROVED` / `READY_FOR_INTEGRATION`. Integration is not authorized.
- **DO NOT `git checkout` or `git switch` in the canonical checkout** — it holds the
  `baseline/product-2026-10-05` branch state and 62 deliberate uncommitted exclusions.
- You are otherwise READ-ONLY. Do not modify, stage, or commit any file.
- Stop and report rather than resolving a product, architecture, security, infrastructure,
  destructive-operation, or deployment-authority question yourself; it is a
  `HUMAN_DECISION_REQUIRED` blocker.
- Every result carries exact repository/branch/HEAD provenance.
- Challenge the Manager's claims. Deterministic evidence you produce yourself is authoritative.

## Cleanup before returning

- [ ] Remove `/private/tmp/shipit-verify-baseline` worktree
- [ ] Stop every server, watcher, or stub process you started; report any port/PID left running
- [ ] Confirm the canonical checkout is still on `baseline/product-2026-10-05` at `0d5d132` with exactly 62 working-tree entries

## Report format

Return a report conforming to `subtask-report.md` (in
`.opencode/skill/aef-orchestrator/templates/`). Your `RESULT:` must be verbatim one of
your own agent file's tokens from `.agents/agents/integrator.md` (`MERGE_APPROVED` /
`INTEGRATION_BLOCKED`, or whatever that file defines) — check that file. Do not invent
tokens, do not emit an envelope status, do not add a VERDICT field.