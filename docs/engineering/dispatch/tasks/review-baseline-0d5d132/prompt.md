MANAGER: orchestrator-main
TASK_ID: review-baseline-0d5d132
TASK_TYPE: review
FEATURE: Independent review of the product baseline commit 0d5d132
AREA: repository
WORKTREE: /private/tmp/shipit-review-baseline (create it yourself; see Isolation pre-flight)
BRANCH: (detached at 0d5d132)
BASE_SHA: bfbbd68
OWNED_PATHS:
  - (none — read-only review lane; you must not modify any file)
READ_ONLY_PATHS:
  - apps/**
  - packages/**
  - docker/**
  - infrastructure/**
  - schemas/**
  - docs/**
  - .decisions/**
  - AGENTS.md
  - framework-manifest.yaml
PROHIBITED_PATHS:
  - (all paths are read-only; do not write, stage, or commit anything)
ACCEPTANCE_CRITERIA: >
  Risk-stratified independent review of the baseline commit. This is explicitly
  NOT a line-by-line review of 204k lines — it is scoped and must say so. Focus on
  the highest-risk surfaces and report honestly what you did and did not cover.
VALIDATION_COMMANDS:
  - git worktree add --detach /private/tmp/shipit-review-baseline 0d5d132
  - cd /private/tmp/shipit-review-baseline && flutter pub get
  - cd /private/tmp/shipit-review-baseline/apps/control_plane && flutter analyze --no-pub
  - cd /private/tmp/shipit-review-baseline/apps/control_plane && flutter test --no-pub
  - cd /private/tmp/shipit-review-baseline/apps/control_plane && flutter build web --no-pub
  - cd /private/tmp/shipit-review-baseline && dart analyze packages apps/server
ROUTING_CLASS: PRECISION

## Isolation pre-flight

You MUST work in your own throwaway worktree, NOT the canonical checkout:

```bash
cd /Users/alkebut/air/shipit-platform
git worktree add --detach /private/tmp/shipit-review-baseline 0d5d132
cd /private/tmp/shipit-review-baseline
git rev-parse --short HEAD      # must equal 0d5d132
```

Do NOT touch the canonical checkout at /Users/alkebut/air/shipit-platform beyond
reading git metadata. It holds 63 deliberate uncommitted entries (golden-test
byproducts, operator scratch files, .aef/) that must not be disturbed. When done:
`git worktree remove /private/tmp/shipit-review-baseline --force`.

## Original request (verbatim)

Human Decision `130f3a7e-c364-4c1e-acd5-409d7af80675` (RESOLVED, OPTION_C):
"Fix analyze in place first" — and then create the baseline commit.

That produced `0d5d132` on branch `baseline/product-2026-10-05`. The integrator lane
(`integrate-baseline-product`) then returned `RESULT: INTEGRATION_BLOCKED` naming as its
sole hard blocker:

> **B1.** 585 files / ~204k insertions have no independent engineering review.
> Resolution: dispatch `engineering-reviewer` on `0d5d132`. This is the sole hard blocker.

## Context and authoritative sources

- Product/requirement artifact: `.decisions/130f3a7e-c364-4c1e-acd5-409d7af80675.yaml`
- Architecture / repository rules: `AGENTS.md` — NOTE: § Product-specific policy is still `TBD`; there is no declared validation gate, no declared path ownership map, and none of the `§2 Dart Conventions` / `§8 Forbidden Patterns` / `§13 Penpot credentials` sections that prior dispatch prompts cited actually exist
- Design Contract / approved design revision ref: n/a — this is a baseline recovery, not a designed change
- QA Contract ref: n/a
- ADRs / recorded decisions that apply: `.decisions/130f3a7e-*.yaml`; ADRs under `docs/engineering/adr/` and `docs/adr/`
- Dependencies that must already be merged: none
- Other lanes currently running (and their OWNED_PATHS): none — you are the only running lane
- Work this lane blocks: FEATURE c46b6807 and all future production-writing lanes
- Open Human Decision ids this lane depends on: `70b47372-8814-4098-81b2-6614497bad12` (PENDING — may an unreviewed baseline land on main?)

## What this commit is, and the honest scope of your review

`0d5d132` is a **recovery commit**, not new work. It materialises ~390 files of the
repository owner's own previously-uncommitted implementation so that a citable `BASE_SHA`
exists — before it, NO commit on any branch or in origin contained
`ControlPlaneRepository.createProduct` or `lib/shared/form_primitives.dart`, and no lane
worktree could contain the product at all.

Diff: 585 files changed, +203997/-4838 (389 added, 194 modified, 1 deleted, 1 renamed).

**Do not pretend to have reviewed 204k lines line-by-line. That would be a false claim.**
Perform a RISK-STRATIFIED review and state your coverage explicitly. Prioritise:

1. **Secrets and credentials.** The integrator found a hardcoded Postgres superuser
   password `fd6239170e2e5511e8ac0fa79a03695f28781037d4c8b644` that was removed from
   `apps/server/bin/onboard_shipit_dev.dart` but propagated into a NEW file
   `apps/server/bin/test_pod.dart`. Independently confirm, and sweep for any OTHER
   credential, key, token, connection string, or private key anywhere in the 585 files.
   Report severity honestly.
2. **The activated migration.** `apps/server/migrations/20260925181113034/migration.sql`
   is a rename of `20260921_defect_tables/definition.sql`, so it goes from INERT
   (`definition.sql` is not auto-applied) to an ACTIVE migration creating `defect` and
   `defect_clarification` tables plus 8 indexes. Verify that reading of the migration
   directory convention, and assess the blast radius of it running for the first time in
   an environment that has already applied the older schema.
3. **Security and authorisation boundaries** in `apps/server` endpoints and
   `packages/platform_contracts` — the engine's decision/gate logic is the product's core
   invariant. Look for missing authz checks, unvalidated input at trust boundaries, and
   `eval`-like dynamic dispatch.
4. **Durability / correctness of the workflow engine and stores** —
   `packages/workflow_engine`, `packages/workflow_store`, `packages/scheduler`,
   `packages/execution_coordinator`, `packages/worker_runtime`. Look for lost-update and
   missing claim-CAS races, since these were introduced as "durable" primitives.
5. **Test quality.** Are the 190 control_plane tests real assertions or tautologies? Do
   they pin the behaviour they claim? Are any golden tests self-fulfilling? Do NOT weaken
   or delete any test.
6. **The one already-reviewed change.** `apps/control_plane/lib/data/client_provider.dart`
   plus `runtime_config_web.dart` / `runtime_config_stub.dart` already passed independent
   review (`RESULT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP`). Confirm it is present and
   correct; do not re-review it from scratch.
7. **Junk and debris.** Confirm `.bak` files, scratch scripts, editor droppings, or
   generated output are not newly committed beyond the known findings.

## Acceptance criteria

- [ ] Independently re-run `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build web` from your fresh worktree and report exact results
- [ ] Run `dart analyze` over `packages/` and `apps/server` and report errors — this has NOT been done by any prior lane
- [ ] Confirm or refute the hardcoded-credential finding, and sweep for others
- [ ] Confirm or refute the activated-migration finding and state the real blast radius
- [ ] Report findings on the risk-stratified areas above, each with `file:line`
- [ ] State EXPLICITLY which areas you covered and which you did NOT, so the coverage claim is auditable
- [ ] Give a clear verdict on whether this baseline is a safe foundation to build feature work on, given it is the isolation anchor for every future lane
- [ ] Do NOT weaken, delete, skip or ignore anything to reach a green result

## Required validation commands

- [ ] `git worktree add --detach /private/tmp/shipit-review-baseline 0d5d132`
- [ ] `cd /private/tmp/shipit-review-baseline && flutter pub get` — deps must resolve
- [ ] `cd /private/tmp/shipit-review-baseline/apps/control_plane && flutter analyze --no-pub` — expect 0 errors, 33 info + 1 pre-existing warning, exit 1. Report any ERROR.
- [ ] `cd /private/tmp/shipit-review-baseline/apps/control_plane && flutter test --no-pub` — expect 190/190
- [ ] `cd /private/tmp/shipit-review-baseline/apps/control_plane && flutter build web --no-pub` — must succeed
- [ ] `cd /private/tmp/shipit-review-baseline && dart analyze packages apps/server` — NOT previously run; report all errors
- [ ] Credential sweep: search the diff for passwords, keys, tokens, `postgres://user:pass@`, PEM blocks, cloud credential prefixes (`AKIA`, `ghp_`, `sk-`, `xox`, `AIza`, `glpat-`, `npm_`), and JWTs
- [ ] `git show --stat 0d5d132` and `git diff --stat bfbbd68..0d5d132` — confirm scope
- [ ] `git worktree remove /private/tmp/shipit-review-baseline --force` when finished

## Hard rules for the child

- You are READ-ONLY on all source. Do not edit, format, stage, or commit any file.
- Do NOT touch the canonical checkout's working tree; it holds 63 deliberate uncommitted entries.
- Do not approve your own work — you did not write any of this, but be equally sceptical of
  the previous lanes' and the Manager's claims.
- Stop and report rather than resolving a product, architecture, security, infrastructure,
  destructive-operation, or deployment-authority question yourself; it is a
  `HUMAN_DECISION_REQUIRED` blocker.
- Every result carries exact repository/HEAD provenance.
- If you find a security issue, report it as a finding with severity; do NOT attempt to fix it.

## Cleanup before returning

- [ ] Remove `/private/tmp/shipit-review-baseline`
- [ ] Stop every server, watcher, or stub process you started; report any port/PID left running
- [ ] Confirm the canonical checkout is untouched: `git -C /Users/alkebut/air/shipit-platform status --porcelain | wc -l` should be unchanged from what you observed

## Report format

Return a report conforming to `subtask-report.md` (in
`.opencode/skill/aef-orchestrator/templates/`). Your `RESULT:` must be verbatim one of
`APPROVE_FOR_MERGE`, `APPROVE_WITH_NON_BLOCKING_FOLLOWUP`, `DO_NOT_MERGE` per
`.agents/agents/engineering-reviewer.md`. Include `CORRECTION_REQUIRED: YES|NO`,
`HUMAN_DECISION_REQUIRED: YES|NO`, `SAFE_PARALLEL_WORK` and `PROHIBITED_PARALLEL_WORK`,
and a `MODEL_USED` / `ROUTING_CLASS_REQUESTED` block. Do not invent tokens, do not emit an
envelope status, do not add a VERDICT field.

If your honest conclusion is that this baseline cannot be meaningfully reviewed within one
lane, say so plainly and return `RESULT: DO_NOT_MERGE` with `HUMAN_DECISION_REQUIRED: YES`
and a concrete proposal for how to scope the review — that is a valid and useful outcome.
Do NOT return an approval that overstates your coverage.