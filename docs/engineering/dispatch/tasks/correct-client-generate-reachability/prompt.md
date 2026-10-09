# Dispatch — correct-client-generate-reachability

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: correct-client-generate-reachability
TASK_TYPE: correct
FEATURE: Make the deploy-key flow reachable from an empty state — the Register button is still unusable
AREA: apps/control_plane Add Product — the missing generate affordance
WORKTREE: /private/tmp/shipit-client-keyflow
BRANCH: impl/client-addproduct-keyflow
BASE_SHA: 2f6b78dfd721598b8ea60ae29ad70194c53a92e1
OWNED_PATHS:
  - apps/control_plane/lib/**
  - apps/control_plane/test/**
READ_ONLY_PATHS:
  - packages/control_plane_client/**
  - apps/server/lib/src/endpoints/credential_endpoints.dart
PROHIBITED_PATHS:
  - apps/server/**
  - packages/**
  - docker/**
  - .github/**
  - docs/adr/**
  - .decisions/**
ACCEPTANCE_CRITERIA: >
  From a cold empty state, filling product name and repository surfaces a working control that
  mints a real deploy key, after which Copy public key and Check access become reachable.
VALIDATION_COMMANDS:
  - dart pub get
  - dart format --output=none --set-exit-if-changed .
  - cd apps/control_plane && flutter analyze
  - cd apps/control_plane && flutter test
ROUTING_CLASS: PRECISION
```

---

## The blocker: the flow is unreachable, not merely disabled

Verified mechanically across `apps/control_plane/lib/features/products/add_product_page.dart`:

| Fact | Lines |
|---|---|
| `deployKey` is SET in exactly one place — inside `_onCheckAccessRequested`'s emit | `:159` (plus the `copyWith` default at `:359`) |
| `_buildKeyBox` is called ONLY under `if (state.deployKey != null)` | `:600`, `:1085` |
| `CheckAccessRequested` is dispatched ONLY from inside `_buildKeyBox` | `:723`, `:1300` |

Therefore: `deployKey` starts `null` → `_buildKeyBox` never renders → **nothing can dispatch
`CheckAccessRequested`** → `deployKey` can never become non-null. **Circular.** The Register button's own
subtext is the giveaway: `_registerButtonSubtext` returns `"Generate a deploy key first"` when
`state.deployKey == null` (`:897`) — **and no control anywhere says "Generate a deploy key".**

Confirmed against the **live QA UI**: with name and repository filled, Register reads *"Generate a deploy key
first"* and there is no control to satisfy it.

## Why this survived your own test suite

Your tests drove the **bloc** directly, so `canRegister` transitions were exercised and passed — but nothing
ever rendered the page and tried to *reach* the handler through the widget tree. A green suite proved the
state machine works while the UI cannot enter it. **That is the gap to close.**

## What to change

Add a **generate affordance that renders when `state.deployKey == null`** and dispatches
`CheckAccessRequested` — which, in your branch, now correctly mints a real key via
`_repository.generateDeployKey` and calls `_ensureProductAndRepository` first.

- Gate it on `state.canGenerateKey` (product name + repository present, not already checking) so it does
  not offer an action that cannot succeed.
- It must exist on **both** desktop and mobile paths (`:600` and `:1085` regions) — the mobile twin was the
  one historically missed.
- Keep the existing approved copy and step text. `_buildStepRow` already marks step 1 done on
  `state.deployKey != null` (`:820`, `:1111`), so the step list is already consistent.
- Do **not** weaken `canRegister`. It is correct: Register should require a verified key.

## Tests you must write — the widget level is the point

1. **A widget test that starts cold**: render the page with empty state, confirm **no** generate control
   yet; fill product name and repository; confirm the control appears; tap it; confirm a key appears and
   `Copy public key` becomes reachable. **This test must fail on `2f6b78d`** — verify that it does before
   you commit, and report the failure output. A test that passes on the broken revision is worthless.
2. The same reachability on the **mobile** layout.
3. Existing `canRegister` transitions stay green — Register false with no key, false while unverified, true
   once `verifyAccess` succeeds.

## Constraints

- `apps/server/**` and `packages/**` PROHIBITED. Do not run `serverpod generate` — the client package at this
  branch is reviewed state and regenerating it would rewrite it.
- `docker/**` PROHIBITED. **The QA stack is up and healthy on a stopgap run-mode override — do not disturb
  it.** Read compose as text.
- **ZERO mutating Docker/Compose commands.** Never `make clean` / `make qa-down` / `make test-env-down` /
  `make e2e-down` / bare `down -v`. This repository has already lost a QA database to a `down -v`.
- Do not weaken, skip, `@Ignore`, filter, or delete any test.

## Gates — verbatim

`dart pub get` at **REPO ROOT** first; `dart format --output=none --set-exit-if-changed .`;
`cd apps/control_plane && flutter analyze` → expect `No issues found!`;
`cd apps/control_plane && flutter test` → baseline is **+266**; report the real number.

Do **not** run `make test-integration` — this change is client-side.

## Proof required

1. The new cold-start widget test **fails at `2f6b78d`** and passes at your HEAD. Show both.
2. A grep showing `CheckAccessRequested` now dispatched from at least one place **outside** `_buildKeyBox`.
3. The mobile twin reaches it too.

## Other lanes

`impl/credential-key-service` (`4f96c78`, generate fix + guard) and `fix/hostkey-config-wiring`
(`437cdb6`) are complete and awaiting review. **No path overlap** — but `437cdb6` must integrate **after**
this branch, since its config keys depend on your `readRuntimeConfigValue`.

Report `SAFE_PARALLEL_WORK` and `PROHIBITED_PARALLEL_WORK`.

## Cleanup

Commit on your branch. **Do not push, merge, or touch `main`.**

Report `READY_FOR_FOCUSED_REVIEW: YES`. You cannot approve your own work.