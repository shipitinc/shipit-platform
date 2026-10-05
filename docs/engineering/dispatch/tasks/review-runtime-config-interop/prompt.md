MANAGER: orchestrator-main
TASK_ID: review-runtime-config-interop
TASK_TYPE: review
FEATURE: Replace discontinued package:js annotations in control_plane runtime config reader
AREA: control-plane/data
WORKTREE: /Users/alkebut/air/shipit-platform (canonical checkout — READ-ONLY review lane, no writers running)
BRANCH: main
BASE_SHA: bfbbd68
OWNED_PATHS:
  - (none — this is a read-only review lane; you must not modify any file)
READ_ONLY_PATHS:
  - apps/control_plane/lib/data/client_provider.dart
  - apps/control_plane/lib/data/runtime_config_web.dart
  - apps/control_plane/lib/data/runtime_config_stub.dart
  - apps/control_plane/pubspec.yaml
  - apps/control_plane/web/index.html
  - docker/config.js.template
  - docker/entrypoint.client.sh
  - .decisions/130f3a7e-c364-4c1e-acd5-409d7af80675.yaml
PROHIBITED_PATHS:
  - apps/server/*
  - packages/*
  - apps/control_plane/lib/features/*
  - apps/control_plane/test/*
  - .dart_tool/*
  - build/*
  - /private/tmp/shipit-*
ACCEPTANCE_CRITERIA: >
  Judge only the five paths listed above. The change must (a) remove the three
  `undefined_annotation` analyzer errors without weakening any lint or test,
  (b) preserve the original runtime behaviour of reading
  window.SHIPIT_CONFIG.CONTROL_PLANE_API with a String.fromEnvironment
  fallback, (c) compile for BOTH the web/JavaScript target and the Dart VM
  (tests), and (d) not introduce a web-only import into a VM-reachable path.
VALIDATION_COMMANDS:
  - cd apps/control_plane && flutter analyze --no-pub
  - cd apps/control_plane && dart format --set-exit-if-changed --output=none lib/data/client_provider.dart lib/data/runtime_config_web.dart lib/data/runtime_config_stub.dart
  - cd apps/control_plane && flutter test --no-pub
  - cd apps/control_plane && flutter build web --no-pub
  - git diff -- apps/control_plane/lib/data/client_provider.dart apps/control_plane/pubspec.yaml
ROUTING_CLASS: STANDARD

## Isolation pre-flight (read-only lane)

There is NO dedicated worktree for this lane and that is deliberate: the change under review
lives only in the canonical checkout's uncommitted working tree, because the repository has no
committed product baseline yet (Human Decision 130f3a7e). Do NOT create a worktree and do NOT
check out any branch — checking out would destroy the very state under review. Verify instead:

```bash
cd /Users/alkebut/air/shipit-platform
git rev-parse --short HEAD          # must equal bfbbd68
git branch --show-current           # must equal main
shasum apps/control_plane/lib/data/client_provider.dart        # must equal caa002c3fc62209eb7e5b04acf5101e1f5387869
shasum apps/control_plane/lib/data/runtime_config_web.dart     # must equal b23b5ccdb6cd3d8c921a81007341939a2bcdcdca
shasum apps/control_plane/lib/data/runtime_config_stub.dart    # must equal 65a32d9a2e0505f52616085f2e347aa3dbe695a0
```

If any hash differs, STOP and report `RESULT: DO_NOT_MERGE` with the observed values.

IMPORTANT: this working tree contains ~390 OTHER uncommitted files that are NOT part of this
review. Ignore them entirely. Review ONLY the five paths in READ_ONLY_PATHS.

## Original request (verbatim)

The human selected Human Decision 130f3a7e option OPTION_C, "Fix analyze in place first":

> Correct the three client_provider.dart JS-interop errors directly in the canonical checkout,
> verify flutter analyze is green, then create the baseline commit.

The three errors, reproduced before the change by `flutter analyze --no-pub` in
`apps/control_plane` (exit code 1):

```
error • Undefined name 'JS' used as an annotation. Try defining the name or importing it from another library • lib/data/client_provider.dart:5:1 • undefined_annotation
error • Undefined name 'JS' used as an annotation. Try defining the name or importing it from another library • lib/data/client_provider.dart:8:1 • undefined_annotation
error • Undefined name 'anonymous' used as an annotation. Try defining the name or importing it from another library • lib/data/client_provider.dart:9:1 • undefined_annotation
```

Root cause as diagnosed: `package:js/js.dart` (js 0.7.2) is `@Deprecated('Use dart:js_interop
instead')` and re-exports `JS`/`anonymous` from the private SDK library `dart:_js_annotations`,
which is unavailable to the analyzer's default target, hence `undefined_annotation`.

## Context and authoritative sources

- Product/requirement artifact: `.decisions/130f3a7e-c364-4c1e-acd5-409d7af80675.yaml` (RESOLVED, OPTION_C)
- Architecture / repository rules: `AGENTS.md` (note: § Product-specific policy is still `TBD`; there is NO project-declared validation gate, path ownership map, or Dart conventions section)
- Design Contract / approved design revision ref: n/a (infrastructure fix, no design artifact)
- QA Contract ref: n/a
- ADRs / recorded decisions that apply: `.decisions/130f3a7e-c364-4c1e-acd5-409d7af80675.yaml`
- Dependencies that must already be merged: none — this change is self-contained
- Other lanes currently running (and their `OWNED_PATHS`): none. No production-writing lane is running.
- Work this lane blocks: the baseline commit, and therefore FEATURE c46b6807
- Open Human Decision ids this lane depends on: 130f3a7e (RESOLVED)

## What the Manager changed (claim to challenge, not trust)

1. `lib/data/client_provider.dart` — replaced the `package:js/js.dart` import and the
   `@JS`/`@anonymous` declarations with a conditional import selecting
   `runtime_config_web.dart` when `dart.library.js_interop` is available and
   `runtime_config_stub.dart` otherwise. The original `try`/`catch` fallback to
   `String.fromEnvironment('CONTROL_PLANE_API', defaultValue: 'http://localhost:8080/')`
   was preserved.
2. `lib/data/runtime_config_web.dart` — NEW. Reads the value via a `@JS`-annotated
   extension type `SHIPITConfig` with `external JSString? operator [](String key)`.
3. `lib/data/runtime_config_stub.dart` — NEW. Returns `null` on the VM.
4. `pubspec.yaml` — removed the now-unused `js: ^0.7.0` dependency; `flutter pub get` run.

Manager-claimed gate results (verify these yourself, do not take them on trust):
`flutter analyze --no-pub` → 0 errors, 34 pre-existing infos + 1 pre-existing warning
(`unused_local_variable` at `lib/data/control_plane_repository.dart:951`, NOT part of this change);
`dart format --set-exit-if-changed` → exit 0; `flutter test --no-pub` → 190/190 passed;
`flutter build web --no-pub` → succeeded.

## Acceptance criteria

- [ ] All three `undefined_annotation` errors are genuinely eliminated at the exact hashes above
- [ ] No lint, test, or analyzer rule was weakened, suppressed, `// ignore`d, or deleted to reach green
- [ ] Behaviour is preserved: `window.SHIPIT_CONFIG.CONTROL_PLANE_API` is read when present and non-empty; otherwise the build-time `String.fromEnvironment` default `http://localhost:8080/` is used
- [ ] The VM path is genuinely free of web-only imports and `flutter test` compiles and passes
- [ ] The web build genuinely compiles the interop and `config.js` injection still reaches the reader
- [ ] Removing the `js` dependency is safe: confirm nothing else in the workspace still imports `package:js/`
- [ ] Findings are concrete and actionable enough for a correction lane to act on without re-deriving the analysis

## Required validation commands

Run each command below and report its exact result. Report `n/a` only with a stated reason.

- [ ] `cd /Users/alkebut/air/shipit-platform && shasum` the three Dart files — must match the pre-flight hashes
- [ ] `cd apps/control_plane && flutter analyze --no-pub` — must show **0 errors**; distinguish pre-existing infos/warnings from anything this change introduced
- [ ] `cd apps/control_plane && dart format --set-exit-if-changed --output=none lib/data/client_provider.dart lib/data/runtime_config_web.dart lib/data/runtime_config_stub.dart` — must exit 0
- [ ] `cd apps/control_plane && flutter test --no-pub` — must pass; report the exact count
- [ ] `cd apps/control_plane && flutter build web --no-pub` — must succeed; this is the only proof the JS interop actually compiles for the web target
- [ ] `grep -rn "package:js/" --include=*.dart .` — must return nothing, proving the dependency removal is safe
- [ ] Read `docker/config.js.template` and `docker/entrypoint.client.sh` and confirm the property name `CONTROL_PLANE_API` on `window.SHIPIT_CONFIG` matches what `runtime_config_web.dart` reads, and that config.js is actually loaded by `apps/control_plane/web/index.html` **before** the Flutter main script
- [ ] `git diff -- apps/control_plane/lib/data/client_provider.dart apps/control_plane/pubspec.yaml` — confirm the change is minimal and contains nothing unrelated

Do not weaken, skip, delete, or ignore a test to reach a green result. If a required command cannot
pass, report the failure with evidence instead of working around it.

## Hard rules for the child

- You are READ-ONLY. Do not modify, format, stage, or commit any file. Do not run `flutter pub get`,
  `git checkout`, `git stash`, `git add`, or any command that mutates the working tree.
- Write only inside OWNED_PATHS; never touch PROHIBITED_PATHS.
- Do not approve your own work. Reviewer lanes never modify production code.
- Stop and report rather than resolving a product, architecture, security, infrastructure,
  destructive-operation, or deployment-authority question yourself; it is a
  `HUMAN_DECISION_REQUIRED` blocker.
- Every result carries exact repository/worktree/HEAD provenance.
- Challenge the Manager's claims. Deterministic evidence you produce yourself is authoritative;
  the Manager's reported gate results are not.

## Cleanup before returning

- [ ] Stop every server, watcher, or stub process you started; report any port/PID left running.
- [ ] Remove `apps/control_plane/build/` if you created it and it did not exist before.
- [ ] Confirm the three Dart file hashes are UNCHANGED from the pre-flight values before you finish.

## Report format

Return a report conforming to `subtask-report.md` (in `.opencode/skill/aef-orchestrator/templates/`).
It must be parseable without reading conversational prose, and must include the mandatory header,
files touched, validation results, documentation updated, unresolved issues, the model/reasoning
effort actually used, and a recommended next action.

Your `RESULT:` must be one of your own agent file's tokens, copied verbatim from
`.agents/agents/engineering-reviewer.md`: `APPROVE_FOR_MERGE`,
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP`, or `DO_NOT_MERGE`. Do not invent tokens, do not emit an
envelope status, and do not add a `VERDICT` field.