MANAGER: orchestrator-main
TASK_ID: correct-analysis-cleanup
TASK_TYPE: correct
FEATURE: Clear all analyzer warnings and infos so `melos run analyze` exits 0
AREA: whole Dart workspace — lint fixes in lib/, test/, bin/ across all 16 packages
WORKTREE: /private/tmp/shipit-analysis-cleanup
BRANCH: correct/analysis-cleanup
BASE_SHA: 07c48ed
OWNED_PATHS:
  - apps/server/lib/**
  - apps/server/test/**
  - apps/server/bin/**
  - apps/control_plane/lib/**
  - apps/control_plane/test/**
  - packages/*/lib/**
  - packages/*/test/**
READ_ONLY_PATHS:
  - apps/server/analysis_options.yaml
  - apps/control_plane/analysis_options.yaml
  - packages/control_plane_client/analysis_options.yaml
  - pubspec.yaml
  - .github/workflows/ci.yaml
  - docs/engineering/dispatch/tasks/review-baseline-0d5d132/report.md
PROHIBITED_PATHS:
  - apps/server/migrations/**          # H1/H2 — human-owned, DO NOT TOUCH
  - apps/server/config/**              # owned by the credential/port lane
  - apps/server/docker-compose.yaml    # owned by the credential/port lane
  - apps/server/tool/**                # owned by the credential/port lane
  - .github/**                         # owned by the credential/port lane
  - docker/**
  - infrastructure/**
  - **/analysis_options.yaml          # DO NOT MODIFY — see "Hard rules"
  - .decisions/**
  - docs/engineering/**
  - .aef/**
ACCEPTANCE_CRITERIA: >
  Every analyzer error, warning and info is cleared by changing CODE, so that
  `dart analyze` exits 0 in all 16 workspace packages and CI's `melos run analyze`
  goes green — with no lint rule weakened, no diagnostic suppressed, and no test changed.
VALIDATION_COMMANDS:
  - cd /private/tmp/shipit-analysis-cleanup && for p in $(melos list --no-private --json | jq -r '.name'); do (cd $p && dart analyze) ; done   # every package must exit 0
  - cd /private/tmp/shipit-analysis-cleanup && dart analyze packages apps/server
  - cd /private/tmp/shipit-analysis-cleanup/apps/control_plane && flutter analyze --no-pub
  - cd /private/tmp/shipit-analysis-cleanup/apps/control_plane && flutter test --no-pub
  - cd /private/tmp/shipit-analysis-cleanup && dart format --output=none --set-exit-if-changed lib test   # per package
ROUTING_CLASS: STANDARD

## Isolation pre-flight

```bash
cd /private/tmp/shipit-analysis-cleanup
git branch --show-current    # must equal correct/analysis-cleanup
git rev-parse --short HEAD   # must equal 07c48ed
```

Do NOT touch the canonical checkout at /Users/alkebut/air/shipit-platform.

## Original request (verbatim)

> And the then the other correction lane related to analysis error. Let's get those
> corrected. I'm unsure how we accumulated all those analysis warnings/infos after every
> piece of work those should be cleaned up. Please correct those.

## Context and authoritative sources

- Product/requirement artifact: `docs/engineering/dispatch/tasks/review-baseline-0d5d132/report.md` findings B2-followup and the correction lane's `PROJECT_FACT` discovery #1
- Architecture / repository rules: `AGENTS.md` (note: § Product-specific policy is still `TBD` — no declared validation gate exists, which is the root cause of this debt accumulating)
- Design Contract / approved design revision ref: n/a
- QA Contract ref: n/a
- ADRs / recorded decisions that apply: n/a
- Dependencies that must already be merged: `0d5d132` baseline + `07c48ed` mechanical corrections
- Other lanes currently running (and their `OWNED_PATHS`): none. A credential/port lane is QUEUED, not running — see "Sequencing".
- Work this lane blocks: the baseline merge, and therefore FEATURE c46b6807
- Open Human Decision ids this lane depends on: none

## The debt, measured at BASE_SHA 07c48ed

`dart analyze packages apps/server` → exit 2, **305 issues**. `flutter analyze --no-pub` in
`apps/control_plane` → exit 1, **34 issues**.

| Code | Count | Severity |
|---|---|---|
| `avoid_print` | 272 | info |
| `unnecessary_import` | 7 | info |
| `annotate_overrides` | 7 | info |
| `unnecessary_brace_in_string_interps` | 4 | info |
| `avoid_relative_lib_imports` | 4 | info |
| `unawaited_futures` | 3 | info |
| `unused_shown_name` | **2** | **warning** |
| `unnecessary_to_list_in_spreads` | 2 | info |
| `deprecated_member_use` | 2 | info |
| `no_leading_underscores_for_local_identifiers` | 1 | info |
| `implementation_imports` | 1 | info |

Plus `apps/control_plane`: `prefer_initializing_formals` 22, `prefer_const_constructors` 4,
`prefer_const_declarations` 2, `unnecessary_brace_in_string_interps` 2,
`unused_local_variable` **1 warning**, `unnecessary_string_interpolations` 1,
`prefer_interpolation_to_compose_strings` 1, `no_leading_underscores_for_local_identifiers` 1.

`avoid_print` by file: `apps/server/onboard_shipit_serverpod.dart` 102,
`apps/server/test/onboarding_test.dart` 87, `apps/server/bin/onboard_shipit_dev.dart` 40,
`apps/server/bin/onboard_shipit.dart` 30, `apps/server/bin/add_human_claims.dart` 11,
`apps/server/bin/test_pod.dart` 2.

## CRITICAL: fix the code, do NOT weaken the rules

`avoid_print: true` was **deliberately opted into** `apps/server/analysis_options.yaml` and
`apps/control_plane/analysis_options.yaml`. It is NOT part of `package:lints/recommended.yaml`
or `core.yaml` — verified against the SDK. Someone chose to enable it and then never cleared
the resulting debt. Turning it off would silently overturn a deliberate project decision and
would be exactly the "weakened gate" the framework forbids.

**Therefore: replace the `print` calls in code. Do not disable, scope, or downgrade the rule.**

For CLI and seed scripts the idiomatic, behaviour-identical replacement is `dart:io`:

```dart
import 'dart:io';
stdout.writeln(x);   // replaces print(x) — same bytes on stdout, lint-clean
```

Use `stderr.writeln(x)` only where the original wrote to stderr. Most `bin/` scripts already
import `dart:io`; add the import where missing. **Preserve output exactly** — these are operator
onboarding and seed scripts whose output is read by humans and by
`apps/server/tool/seed_overview_qa.sql`. Do not reword, reorder, add prefixes, or remove lines.

For the other 33 backend items and the 34 frontend items, make the real fix:
`unnecessary_import` → delete the redundant import; `annotate_overrides` → add `@override`;
`unnecessary_brace_in_string_interps` → `${x}` → `$x`; `avoid_relative_lib_imports` → use a
`package:` import; `unawaited_futures` → add the `await` (only if it does not change ordering
semantics — if it does, STOP and report); `unused_shown_name` → drop the unused name from the
`show` list; `unnecessary_to_list_in_spreads` → drop `.toList()`;
`deprecated_member_use` at `workflow_state.dart:146,197` → **the deprecated member is `done`,
which its own doc says is parse-only and never a legal transition target — investigate before
changing; if replacing it would alter state-machine semantics, STOP and report**;
`implementation_imports` → import the package's public library;
`no_leading_underscores_for_local_identifiers` → rename; `unused_local_variable` at
`apps/control_plane/lib/data/control_plane_repository.dart:952` → inspect and either use it or
remove it, and **report what it was clearly meant to be** — it may be a real latent bug.

## Sequencing — do NOT run the Postgres integration suite

A credential/port lane is QUEUED to run `dart test test/integration/` against a real Postgres
and to close the never-executed-migrations finding. If you run those tests concurrently you
will contend for the same database and produce untrustworthy results for both lanes.

- DO run `apps/server` NON-integration tests, and `apps/control_plane`'s full suite (190 tests).
- DO NOT run `apps/server/test/integration/`. Report `n/a` with that reason.
- DO NOT start, stop, or touch any Docker container or database.

## Acceptance criteria

- [ ] `dart analyze` exits 0 in **all 16** workspace packages
- [ ] `dart analyze packages apps/server` exits 0 — currently exit 2 with 305 issues
- [ ] `flutter analyze --no-pub` in `apps/control_plane` exits 0 — currently exit 1 with 34 issues
- [ ] The melos-equivalent format gate still passes: per-package `dart format --output=none --set-exit-if-changed lib test`
- [ ] `flutter test --no-pub` in `apps/control_plane` still reports 190/190
- [ ] `apps/server` non-integration tests still pass, at the same count as at BASE_SHA
- [ ] **Zero** changes to any `analysis_options.yaml`
- [ ] **Zero** `// ignore`, `// ignore_for_file`, or `analyzer: exclude:` additions
- [ ] **Zero** changes to `apps/server/migrations/**`
- [ ] Operator script stdout byte-identical for `avoid_print` replacements
- [ ] Every commit is NEW on top of `07c48ed` — never amend, rebase or squash

## Required validation commands

Run each and report exact results. Do not weaken, skip, delete or ignore anything to reach green.

- [ ] Baseline census first: record `dart analyze` counts per package BEFORE you change anything
- [ ] `cd /private/tmp/shipit-analysis-cleanup && dart analyze packages apps/server` → must exit 0
- [ ] `cd apps/control_plane && flutter analyze --no-pub` → must exit 0
- [ ] Per-package `dart analyze` across all 16 workspace packages → all exit 0
- [ ] Per-package `dart format --output=none --set-exit-if-changed lib test` → all clean
- [ ] `cd apps/control_plane && flutter test --no-pub` → expect 190/190
- [ ] `cd apps/server && dart test` excluding `test/integration/` → report exact pass count
- [ ] `cd apps/control_plane && flutter build web --no-pub` → must still succeed
- [ ] `git diff --stat 07c48ed..HEAD` and `git log --oneline 07c48ed..HEAD` — confirm scope, and that history was not rewritten
- [ ] `git diff 07c48ed..HEAD -- '*analysis_options.yaml' '*migrations*'` → must be EMPTY

## Hard rules for the child

- **Never modify an `analysis_options.yaml`.** They are `PROHIBITED_PATHS`. The debt is cleared
  in code. If you believe a rule is genuinely wrong for this codebase, STOP and report that as
  a blocker with your reasoning — do not act on it.
- **Never add `// ignore` or `ignore_for_file`.** That is suppression, not correction.
- **Never change a test to make it pass, and never delete or skip a test.** The lint fixes must
  be behaviour-preserving. If a lint fix would change observable behaviour, STOP and report.
- `apps/server/migrations/**` is `PROHIBITED` — nine never-executed migrations and a
  migration-lineage brick live there. Do not read-modify them.
- Do not commit, push, or touch `main`. Commit on `correct/analysis-cleanup` only.
- Stop and report rather than resolving a product, architecture, security, infrastructure,
  destructive-operation, or deployment-authority question yourself; it is a
  `HUMAN_DECISION_REQUIRED` blocker. The two `unawaited_futures` and two
  `deprecated_member_use` items are the likely candidates — treat them as blockers if semantics
  are unclear, not as mechanical edits.
- Every result carries exact repository/worktree/HEAD provenance.

## Cleanup before returning

- [ ] Stop every process you started; report any port/PID left running
- [ ] Confirm you started no Docker container and touched no database
- [ ] Leave the worktree clean and committed, matching the reported HEAD_SHA
- [ ] Do NOT remove your own worktree — the Manager needs it for re-review

## Report format

Return a report conforming to `subtask-report.md` (in
`.opencode/skill/aef-orchestrator/templates/`). Your `RESULT:` must be verbatim one of your
own agent file's tokens from `.agents/agents/correction-implementer.md`. Do not invent tokens,
do not emit an envelope status, do not add a VERDICT field.

Report separately: the count fixed per diagnostic code, anything you had to stop on, and — for
`control_plane_repository.dart:952` — what you believe the unused `result` variable was meant
to do, since it may be a latent bug rather than lint noise.