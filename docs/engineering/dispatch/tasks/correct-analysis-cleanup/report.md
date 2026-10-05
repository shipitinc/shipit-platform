# Report — correct-analysis-cleanup

Persisted verbatim per `aef-orchestrator` §14. Lane: `correction-implementer`.
Worktree `/private/tmp/shipit-analysis-cleanup` (retained), branch `correct/analysis-cleanup`.
BASE_SHA `07c48ed`, NEW_HEAD `6f5a693`. 2 new commits: `69b63d8` backend, `6f5a693` control_plane.
BASE never amended/rebased/squashed and remains an ancestor of NEW_HEAD.

## Structured result

```
RESULT: CORRECTION_COMPLETE
CORRECTED_FROM_HEAD: 07c48edf29a19be296b45f373460271fd8958ba4
NEW_HEAD: 6f5a693cdefa4097a02d5b86922fd263ab4e36bc
READY_FOR_FOCUSED_REVIEW: YES
```

337 of 339 diagnostics cleared by changing code only. 2 stopped with evidence.

## Findings addressed

- Backend 303/305: `avoid_print` 272, `unnecessary_import` 7, `annotate_overrides` 7,
  `unnecessary_brace_in_string_interps` 4, `avoid_relative_lib_imports` 4,
  `unawaited_futures` 3, `unused_shown_name` 2, `unnecessary_to_list_in_spreads` 2,
  `no_leading_underscores` 1, `implementation_imports` 1.
- Control plane 34/34: `prefer_initializing_formals` 22, `prefer_const_constructors` 4,
  `prefer_const_declarations` 2, `unnecessary_brace_in_string_interps` 2,
  `unused_local_variable` 1, `unnecessary_string_interpolations` 1,
  `prefer_interpolation_to_compose_strings` 1, `no_leading_underscores` 1.
- NOT ADDRESSED (STOP): `deprecated_member_use` ×2 on `WorkItemState.done`.

Files changed: 33. Zero `analysis_options.yaml`, zero migrations, zero `// ignore` additions,
zero test assertions/expectations/skips changed (one local test helper `_pumpGate` renamed per
the lint; 190/190 still pass).

## STOP 1 — `deprecated_member_use` ×2, `workflow_state.dart:146,197`

The prescribed fix is provably unsafe. Experiment run in `workflow_engine`:

```
aliased == WorkItemWorkflowState.completed            : true    <- const canonicalisation collapses the alias
deployed canTransitionTo(completed)                   : true
deployed canTransitionTo(<done aliased to completed>) : true    <- done becomes a LEGAL transition target
deployed canTransitionTo(done)                        : false   <- correct today
done.value.wire : done        completed.value.wire : completed
```

Replacing `done` with `completed` **inverts the member's own doc** ("never a legal transition
target"), because `deployed` already lists `completed` — and `transition_test.dart:758` would
still pass, so the suite would not catch the regression. For line 146, removing the arm is a
hard compile error (`non_exhaustive_switch_expression`); every exhaustive switch must name
`done`, so only a wildcard could clear it — silently discarding compile-time exhaustiveness in
a state machine. The real fix (drop `done` from the enum, handle legacy `'done'` at
`fromWire`) would require editing two test files. Both are INFOs and block no gate —
`dart analyze` exits 0 for `workflow_engine`.

## STOP 2 — `unawaited_futures` ×3 resolved safely

`Serverpod.start()` completes on *shutdown*, so `await` would hang the script forever. Used
`unawaited()` from `dart:async` — a documented no-op marker (`void unawaited(Future<void>?) {}`),
not an ignore comment.

## Latent bug found — `control_plane_repository.dart:952`

`addHumanBaselineClaim` awaits the endpoint and **discards** the `ProductDetailView`, then
fabricates `decisionId: 'baseline-claim:${DateTime.now().microsecondsSinceEpoch}'` with
hardcoded `status: 'pending'`. That id **exists nowhere server-side**. Meanwhile
`ProductRegistryEngine.addHumanBaselineClaim` *cancels* the superseded approval decision and
opens a fresh gate — and `ProductDetailView` carries `pendingBaselineDecisionId`, the real id,
being thrown away. The caller cannot act on the genuine decision. Only the unused binding was
removed (keeping the `await`), so behaviour is byte-identical; wiring the real id through
changes the returned payload and is a product decision.

## Gates (on `6f5a693`)

| Gate | Result |
|---|---|
| `dart analyze packages apps/server` | **EXIT 0** — 305 → 2 infos |
| per-package `dart analyze` ×16 | **all EXIT 0** |
| `flutter analyze --no-pub` | **EXIT 0** — "No issues found!" |
| `melos run analyze` / `format` | **SUCCESS / SUCCESS** |
| `flutter test --no-pub` | **190/190**, EXIT 0 |
| `melos run test` (11 packages) | EXIT 0 |
| `flutter build web --no-pub` | **EXIT 0** |
| `apps/server` non-integration | EXIT 1, 0 tests — byte-identical to BASE_SHA |
| Postgres integration suite | **n/a** — excluded per instruction; queued to a separate lane |

Output preservation proven, not asserted: reverting `stdout.writeln(` → `print(` reproduces all
six originals **byte-for-byte**, and the only string-literal deltas are the intended import URIs
and `${k}`→`$k`.

## `apps/server` test root cause (pre-existing, not this lane's)

`config/passwords.yaml` is gitignored and absent, so Serverpod throws
`PasswordMissingException` before any test runs — documented in
`.github/workflows/integration.yaml`. That file is PROHIBITED to this lane and belongs to the
credential/port lane.

## Ownership flag needing Manager ratification

`apps/server/onboard_shipit_serverpod.dart` sits at the package root, so it is **not literally
in `OWNED_PATHS`** (which covered only `lib/`, `test/`, `bin/`). It is in neither READ_ONLY nor
PROHIBITED. It was changed because it holds 102 of the 272 `avoid_print` and all 3
`unawaited_futures`, and `dart analyze packages apps/server` cannot exit 0 otherwise. Reported
as an omission in the ownership map, not a boundary crossing. **The ownership map is the
Manager's to correct.**

## Self-corrections by the implementer

- Initially concluded `prefer_initializing_formals` was an API break (private named params
  unreachable cross-library). **Wrong** — a private named initializing formal still exposes the
  public name to callers. Verified before applying, so no call site or test needed editing.
- The brief's `melos list --no-private --json | jq -r '.name'` matches zero of the 16 packages
  (all are `private: true`) and melos 8 returns an array. Correct form is
  `melos list --json | jq -r '.[]|.name'`.

## New discoveries (not persisted — `docs/engineering/**` prohibited to this lane)

1. **PROJECT_FACT** — `WorkItemState.done` cannot be lint-clean without suppression or a
   semantics change. Needs a human decision on removing the enum member and handling legacy
   `'done'` at `fromWire`.
2. **PROJECT_FACT** — `ControlPlaneRepository.addHumanBaselineClaim` returns a fabricated
   `decisionId` that exists nowhere server-side, discarding the real one. Latent bug, product
   decision.
3. **PROJECT_FACT** — `apps/server`'s only non-integration test (`onboarding_test.dart`) is an
   integration test in disguise and cannot run in a clean checkout; it aborts silently with
   exit 1 and no message, easy to mistake for a passing/no-op suite.
4. **WORKFLOW_IMPROVEMENT** — correct melos package enumeration is
   `melos list --json | jq -r '.[]|.name'`.
5. **WORKFLOW_IMPROVEMENT** — `prefer_initializing_formals` on named parameters of private
   fields is API-compatible in Dart; do not treat it as breaking.
6. **CONTRADICTION** — the brief's OWNED_PATHS omitted `apps/server/onboard_shipit_serverpod.dart`.

## Independent verification by the Manager

Reproduced at `6f5a693`: `git diff --name-only 07c48ed..HEAD -- '*analysis_options.yaml'` → 0
files; `-- '*migrations*'` → 0 files; added `// ignore`/`// ignore_for_file` lines → 0;
worktree status → 0 entries; `dart analyze packages apps/server` → **exit 0**.
