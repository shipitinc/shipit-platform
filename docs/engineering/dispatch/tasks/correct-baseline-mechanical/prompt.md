MANAGER: orchestrator-main
TASK_ID: correct-baseline-mechanical
TASK_TYPE: correct
FEATURE: Clear the mechanical review blockers so the baseline compiles and passes CI
AREA: apps/server/bin, formatting across workspace, repo hygiene, committed credentials
WORKTREE: /private/tmp/shipit-correct-baseline
BRANCH: correct/baseline-mechanical
BASE_SHA: 0d5d132
OWNED_PATHS:
  - apps/server/bin/onboard_simple.dart        # DELETE
  - apps/server/bin/onboard_direct.dart        # DELETE
  - apps/server/bin/onboard_fixed.dart         # DELETE
  - apps/server/bin/add_human_claims_mature.dart  # DELETE
  - apps/server/bin/test_pod.dart              # credential removal
  - apps/server/bin/onboard_shipit.dart        # credential removal
  - apps/server/onboard_shipit_serverpod.dart  # credential removal
  - apps/server/lib/src/endpoints/human_direction_endpoints.dart.bak   # DELETE
  - S2_NON_VISUAL_RELEASE_BLOCKER_CLOSURE.md   # relocate to docs/reports/
  - docs/reports/
  - **/lib/**                                 # dart format ONLY
  - **/test/**                                # dart format ONLY
READ_ONLY_PATHS:
  - apps/server/lib/server.dart
  - apps/server/pubspec.yaml
  - .github/workflows/ci.yaml
  - pubspec.yaml
  - docs/engineering/dispatch/tasks/review-baseline-0d5d132/report.md
  - .decisions/048f3367-5836-43c8-af05-747dbc9d3afd.yaml
PROHIBITED_PATHS:
  - apps/server/migrations/**      # M1/H1/H2 — human-owned, DO NOT TOUCH
  - apps/server/lib/src/**          # only dart format; no logic changes
  - apps/control_plane/lib/features/**  # only dart format; no logic changes
  - packages/**/lib/**              # only dart format; no logic changes
  - docker/**
  - infrastructure/**
  - .decisions/**
  - docs/engineering/**
  - .github/**
ACCEPTANCE_CRITERIA: >
  The tree compiles and passes the CI gates that were red at BASE_SHA, with no
  behaviour change and no weakened gate.
VALIDATION_COMMANDS:
  - cd /private/tmp/shipit-correct-baseline && dart analyze packages apps/server
  - cd /private/tmp/shipit-correct-baseline && dart format --output=none --set-exit-if-changed lib test   # per package, as melos run format does
  - cd /private/tmp/shipit-correct-baseline && flutter pub get
  - cd /private/tmp/shipit-correct-baseline/apps/control_plane && flutter analyze --no-pub
  - cd /private/tmp/shipit-correct-baseline/apps/control_plane && flutter test --no-pub
  - cd /private/tmp/shipit-correct-baseline/apps/control_plane && flutter build web --no-pub
ROUTING_CLASS: STANDARD

## Isolation pre-flight

```bash
cd /private/tmp/shipit-correct-baseline
git branch --show-current    # must equal correct/baseline-mechanical
git rev-parse --short HEAD   # must equal 0d5d132
```

Do NOT touch the canonical checkout at /Users/alkebut/air/shipit-platform.

## Original request (verbatim)

Human Decision `048f3367-5836-43c8-af05-747dbc9d3afd`, resolved as **OPTION_C**:

> Fix and add authentication

> Remove all three committed credential literals, rotate the PostgreSQL superuser
> password if any instance was initialised with it, AND implement authentication on the
> control-plane API before anything is staged.

This lane covers ONLY the mechanical, no-judgement-required parts. Authentication
implementation is explicitly NOT yours — it is a cross-cutting architecture change that
needs its own Design Brief, Design Contract and independent review, tracked as a
follow-up action on decision 048f3367.

## Context and authoritative sources

- Product/requirement artifact: `docs/engineering/dispatch/tasks/review-baseline-0d5d132/report.md` — your findings are B1, B2, B3, M2, M3, M7
- Architecture / repository rules: `AGENTS.md` (note: § Product-specific policy is still `TBD`)
- Design Contract / approved design revision ref: n/a — corrections to a known-bad state, no design artifact
- QA Contract ref: n/a
- ADRs / recorded decisions that apply: `.decisions/048f3367-5836-43c8-af05-747dbc9d3afd.yaml` (RESOLVED, OPTION_C)
- Dependencies that must already be merged: baseline `0d5d132`
- Other lanes currently running (and their `OWNED_PATHS`): none
- Work this lane blocks: every production-writing lane, including FEATURE c46b6807
- Open Human Decision ids this lane depends on: `70b47372-8814-4098-81b2-6614497bad12` (PENDING)

## Findings you must clear

**B1 — `apps/server` does not compile: 10 errors.** All in four scratch scripts that
`0d5d132` newly added and that NOTHING in the repository references. The real entrypoint
is `bin/main.dart` (`apps/server/pubspec.yaml:49`).
  - `apps/server/bin/onboard_simple.dart` — `undefined_function` DatabaseConfig (31),
    `undefined_named_parameter` timeout (54), `undefined_function` PersistenceDatabase (59),
    PostgresWorkflowStore (60), PostgresHumanDecisionStore (61), PostgresProductRegistryStore (62)
  - `apps/server/bin/onboard_direct.dart` — `undefined_function` DatabaseConfig (31),
    `argument_type_not_assignable` Connection->Database (55)
  - `apps/server/bin/onboard_fixed.dart` — `argument_type_not_assignable` (43)
  - `apps/server/bin/add_human_claims_mature.dart` — `argument_type_not_assignable` (35)
  **Action: DELETE all four.** Before deleting, verify each is genuinely unreferenced
  (`grep -rn` for its basename across the repo, including docker/, .github/, docs/ and
  Makefile). If any IS referenced, STOP and report rather than deleting it.

**B2 — CI format gate fails on 40 files across 8 packages.** `.github/workflows/ci.yaml:19`
runs `melos run format`, defined at `pubspec.yaml:37-40` as
`dart format --output=none --set-exit-if-changed lib test` per package.
  - `packages/agent_runtime` (1), `packages/execution_coordinator` (2),
    `packages/platform_contracts` (8), `packages/product_registry` (4),
    `packages/scheduler` (1), `packages/workflow_engine` (1), `apps/server` (9),
    `apps/control_plane` (14)
  **Action: run `dart format lib test` in each of those 8 packages.** This must produce a
  clean `--set-exit-if-changed` run. Formatting only — no logic edits.

**B3 — committed credentials (HD 048f3367 follow-up action 1).** Replace with env/config
reads; do not merely delete the line.
  - `apps/server/bin/test_pod.dart:16` — Postgres **superuser** `postgres` password
    `fd6239170e2e5511e8ac0fa79a03695f28781037d4c8b644`
  - `apps/server/bin/onboard_shipit.dart:28` — `control_plane_test_pw`
  - `apps/server/onboard_shipit_serverpod.dart:38` — `shipit`
  Follow the pattern already established at `apps/server/bin/onboard_shipit_dev.dart`, which
  the baseline already fixed to use `_env('SERVERPOD_DATABASE_PASSWORD','shipit')`. Match
  that existing convention rather than inventing a new one. **Do NOT rotate anything** —
  rotation is the human's action.

**M2 — committed editor backup.** DELETE
`apps/server/lib/src/endpoints/human_direction_endpoints.dart.bak` (the live
`human_direction_endpoints.dart` beside it stays). Verify the `.bak` is not referenced first.

**M3 — 51 KB operator status report at repository root.** MOVE
`S2_NON_VISUAL_RELEASE_BLOCKER_CLOSURE.md` to `docs/reports/`. Preserve content byte-for-byte
and fix any internal relative links that the move breaks. Do NOT edit its content or its
verdict — it is the authoritative record of why the tree is not mergeable.

**M7 (optional, only if you can do it safely) — inert `.gitignore` rules.** `.gitignore:15`
adds `**/test/failures/` but 80 byproducts remain tracked. Do NOT `git rm --cached` these:
that is a 585-file-scale history decision, not a mechanical fix. Report it, skip it.

## Explicitly NOT yours

- **Migrations** (`apps/server/migrations/**`): finding M1 (a shipped migration was edited
  with a false rationale) and H1/H2 (nine migrations activated, never executed; lineage
  brick unremediated). Human-owned. Touching them could destroy the only record of the
  migration state.
- **API authentication implementation**: needs its own design and review.
- **L1** (`job_queue.dart:180-192` phantom `Job` return) and **L3/L4/L5/L6**: tracked
  follow-ups, not corrections.
- **36 unreconciled goldens (M6)** and the ADR 0021 architecture decision.

## Acceptance criteria

- [ ] `dart analyze packages apps/server` exits 0 with zero errors
- [ ] The melos-equivalent format gate passes: `dart format --output=none --set-exit-if-changed lib test` clean in all 17 packages
- [ ] `flutter analyze --no-pub` in `apps/control_plane` still reports 0 errors
- [ ] `flutter test --no-pub` still reports 190/190 — no test weakened, skipped or deleted
- [ ] `flutter build web --no-pub` still succeeds
- [ ] No committed credential literal remains at the three locations in B3
- [ ] `git diff 0d5d132..HEAD --stat` shows ONLY: 4 deletions + 1 `.bak` deletion +
      the report relocation + formatting-only changes + the 3 credential edits
- [ ] Every change is a NEW commit on top of `0d5d132` — never amend, rebase or squash it

## Required validation commands

Run each and report the exact result. Do not weaken, skip, delete or ignore anything to
reach a green result.

- [ ] `grep -rn "onboard_simple\|onboard_direct\|onboard_fixed\|add_human_claims_mature" .` — must find no references before you delete
- [ ] `grep -rn "human_direction_endpoints.dart.bak" .` — must find no references
- [ ] `cd /private/tmp/shipit-correct-baseline && dart analyze packages apps/server` — must exit 0
- [ ] Per-package `dart format --output=none --set-exit-if-changed lib test` across all 17 workspace packages — must all pass
- [ ] `cd /private/tmp/shipit-correct-baseline && flutter pub get`
- [ ] `cd apps/control_plane && flutter analyze --no-pub` — expect 0 errors, 33 info
- [ ] `cd apps/control_plane && flutter test --no-pub` — expect 190/190
- [ ] `cd apps/control_plane && flutter build web --no-pub` — must succeed
- [ ] `grep -rn "fd6239170e2e5511e8ac0fa79a03695f28781037d4c8b644\|control_plane_test_pw" apps/ packages/` — must return nothing
- [ ] `git diff 0d5d132..HEAD --stat` and `git log --oneline 0d5d132..HEAD` — confirm scope and that history was not rewritten

## Hard rules for the child

- Write only inside `OWNED_PATHS`; never touch `PROHIBITED_PATHS`.
- In `**/lib/**` and `**/test/**` you may ONLY run `dart format`. Any logic change outside
  the specifically enumerated files is out of scope — stop and report instead.
- **Do not amend, rebase, squash or reset `0d5d132`.** It carries reviewed provenance for
  `apps/control_plane/lib/data/{client_provider,runtime_config_web,runtime_config_stub}.dart`.
  All your work goes in new commits on top.
- Commit your work on `correct/baseline-mechanical` (the prompt authorizes committing here).
  Do NOT push, merge, or touch `main`.
- Do not rotate credentials or touch any live database.
- Stop and report rather than resolving a product, architecture, security, infrastructure,
  destructive-operation, or deployment-authority question yourself; it is a
  `HUMAN_DECISION_REQUIRED` blocker. Deleting a script that turns out to be referenced IS
  such a blocker — stop.
- Every result carries exact repository/worktree/HEAD provenance.

## Cleanup before returning

- [ ] Stop every server, watcher, or stub process you started; report any port/PID left running
- [ ] Leave the worktree's tracked files clean and committed, matching the reported HEAD_SHA
- [ ] Do NOT remove your own worktree — the Manager needs it for the re-review

## Report format

Return a report conforming to `subtask-report.md` (in
`.opencode/skill/aef-orchestrator/templates/`). Your `RESULT:` must be verbatim one of your
own agent file's tokens from `.agents/agents/correction-implementer.md`. Do not invent tokens,
do not emit an envelope status, do not add a VERDICT field.