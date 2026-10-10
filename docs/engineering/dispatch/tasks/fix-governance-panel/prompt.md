# Dispatch — fix-governance-panel

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: fix-governance-panel
TASK_TYPE: correct
FEATURE: Make the Governance panel operational — real actions, real errors, and a way to propose a baseline
AREA: apps/control_plane Product Detail governance panel + client repository
WORKTREE: /private/tmp/shipit-fix-governance
BRANCH: fix/governance-panel
BASE_SHA: 42999b2
OWNED_PATHS:
  - apps/control_plane/lib/**
  - apps/control_plane/test/**
READ_ONLY_PATHS:
  - apps/server/lib/src/endpoints/product_registry_endpoints.dart
  - apps/server/lib/src/endpoints/credential_endpoints.dart
  - packages/workflow_engine/lib/src/transitions/product_transitions.dart
  - packages/product_registry/lib/src/engine/product_registry_engine.dart
  - docs/engineering/dispatch/tasks/research-dead-governance-actions/report.md
  - apps/control_plane/lib/features/products/add_product_page.dart
PROHIBITED_PATHS:
  - apps/server/**
  - packages/**
  - docker/**
  - .github/**
  - docs/adr/**
  - .decisions/**
  - docs/engineering/**
ACCEPTANCE_CRITERIA: >
  Every governance action offered on Product Detail performs its server call and reports its real
  outcome; failures are visible in place; a registered product can reach baselinePending; a
  product in baselineReview can be approved or sent back; offboarding a governed product requires a
  typed confirmation.
VALIDATION_COMMANDS:
  - dart pub get
  - dart format --output=none --set-exit-if-changed .
  - cd apps/control_plane && flutter analyze
  - cd apps/control_plane && flutter test
ROUTING_CLASS: PRECISION
```

---

## Why this lane exists — the panel is entirely non-functional

The operator found **Offboard this product** does nothing. The root cause is worse and was found by
assessment (`docs/engineering/dispatch/tasks/research-dead-governance-actions/report.md` — read it, it is
your primary input). Verify these yourself rather than inheriting them:

1. **`pendingDecision` has no consumer in production.** `product_detail_page.dart:37-56` mounts the
   `BlocListener` that navigates to `/needs-you/<id>` **only when `widget.bloc` is injected** — a
   test-only seam. Production takes the `else` branch and builds a bare `BlocProvider`. So a raised gate
   is **write-only**: `proposeBaseline` and `reviewBaseline` raise a real server gate that **nothing ever
   displays**. They are as dead as Offboard.
2. **`_onGovernanceActionRequested` (`product_detail_bloc.dart:64-76`) switches on only two actions.**
   `pause`, `resume`, `offboard`, `revokePolicy` all take `_ => null`.
3. **The resolve half does not exist.** `ControlPlaneRepository.resolveLifecycleDecision` has **zero
   callers**. Raising a gate without a resolve path creates a `blocking: true` gate nobody can action —
   exactly what `product_registry_endpoints.dart:164-165` promises never to happen.
4. **The needs-you route cannot render a lifecycle decision** — `DecisionDetailPage` → `inspectDecision`
   → `readWorkItem` throws for the synthetic scope `product-lifecycle:<productId>`. So do **not** route
   lifecycle gates there. Render them **in place** on Product Detail.
5. **The catch is inert.** `clearError: true` at `:88` wins inside `copyWith` (`:246`), discarding every
   governance error — which is why a refusal was invisible.

## Server capabilities already exist — this is a client-only lane

Do NOT add server endpoints. Verify these signatures yourself:

```dart
Future<DecisionView>      proposeBaseline({required String productId, required List<BaselineFact> facts})
Future<DecisionView>      requestBaselineApproval({...})
Future<DecisionView>      requestLifecycleDecision({required String productId, required String action, bool drainInFlight = true})
                                               // action ∈ pause | resume | offboard | reinstate
Future<DecisionView>      resolveLifecycleDecision({required String decisionId, required String choice, required String decider, required String rationale, required String signature, required String publicKey, ...})
Future<DecisionView>      resolveBaselineApproval({...})
Future<DecisionView>      baselineApproval({required String productId, required String baselineId})
Future<ProductDetailView> verifyBaseline({required String productId, required String baselineId, required String verifiedBy, String kind = 'platform_verified_evidence'})
```

## Scope — in priority order

### 1. An in-place decision panel on Product Detail

Mirror the existing `_BaselineApprovalGate` pattern (`product_detail_page.dart:~184`, which has the reason
field, Approve / Request changes / Reject, and `onResolve`). Render it from a **state field that production
actually consumes** — do not rely on the injected-bloc listener. Keep the existing gate card for baselines.

Both halves must exist and be called: **raise** then **resolve**. A raise without a resolve leaves a
`blocking: true` gate stranded.

### 2. `availableFor` — offer the actions that are actually reachable

A `registered` product currently gets **only** `offboard`. `proposeBaseline` is gated behind `governed`,
which is a chicken-and-egg: you cannot propose a baseline until you are already governed.

Add a baseline-proposal action for `registered` (and `baselineBlocked` where sensible), wired to
`requestBaselineApproval`. **Verify the server accepts it for those states** before assuming it — if it
refuses, report that rather than building a control that 500s.

### 3. Typed confirmation for a GOVERNED offboard only

Human Decision recorded 2026-10-09 (`docs/engineering/dispatch/DECISIONS.md`): offboarding a **governed**
product requires typing the product id; a **registered** product offboards in one tap. Governing discards an
accepted baseline and is irreversible without a fresh baseline review, so that case is fenced. Your case
today is registered and must stay one tap.

### 4. Make failures visible, in place

An action-scoped error message inside the Governance panel. Do **not** take over the whole page with
`DesignErrorState` — its copy ("No decision was recorded and no work was started") **misdescribes a
refusal**, which is the opposite of what happened.

### 5. `isRaisingGate` and accessibility

`isRaisingGate` is set, cleared, and read by nothing — no in-flight affordance, and a double tap fires two
requests. Wire it: disable actions while a gate is in flight and show progress. The action links are
`Semantics(link: true)` on a `GestureDetector` (`design_primitives.dart:221-228`) — give them a real
button role, a focusable node, and a real disabled state.

### 6. `revokePolicy` — implement or remove, decide and say which

It throws `UnimplementedError` (`product_detail_bloc.dart:124`) despite complete server support
(`revokeStandingPolicy`, `product_registry_endpoints.dart:295-308`). It is an **attributed write, not a
decision gate**, so it does not belong in the decision switch. Your call: implement it as a plain
attributed write, or stop offering it. Say which and why. **Do not** leave it in a list where tapping it
throws.

## What this lane must NOT do — a real limit, not a scope preference

The server's transition table (`packages/workflow_engine/lib/src/transitions/product_transitions.dart`)
makes the chain explicit:

| | Edge | Guards |
|---|---|---|
| 1 | `registered → baselinePending` | **none — unconditional** |
| 2 | `baselinePending → baselineReview` | `baselineProposed` + `baselineVerifiedIndependently` |
| 3 | `baselineReview → governed` | `baselineApproved` + `decisionActorIsHuman` |

**Hop 2 requires a baseline to be built and independently verified, and no worker does that.** So the
newest action you build will move a registered product to **baselinePending and stop there**. The product
will read "Not governed yet — baseline pending", not "Governed". `verifyBaseline` exists as an endpoint, but
`baselineVerifiedIndependently` is a substantive claim about independently verified evidence — **do not
call it just to turn a product green.** Say so plainly in your report.

## Tests — the widget level, and they must bite

The 266-test baseline missed the unreachable-flow defect because tests drove the bloc. **Render the screen.**

1. **Each action issues its real server call** — assert the repository method is invoked with the right
   arguments, and that a raised gate renders the in-place panel in a production build (no injected bloc).
2. **The panel appears for a production-constructed bloc.** This is the regression guard for finding 1.
3. **A rejection surfaces visibly in place** — not a whole-page takeover. Covers the inert `catch`.
4. **Governed offboard requires typing the product id; registered offboard does not.** Cover both.
5. **A registered product can reach a raised baseline gate.**

## Constraints

- `apps/server/**`, `packages/**`, `docker/**`, `docs/**`, `.decisions/**` are PROHIBITED.
- **ZERO mutating Docker/Compose commands.** The QA stack is live and I am driving it. Never `make clean`
  / `make qa-down` / `make test-env-down` / `make e2e-down` / bare `down -v`.
- Never print, log, or echo private key material.
- Do not weaken, skip, `@Ignore`, filter, or delete any test.

## Gates — verbatim

`dart pub get` at **REPO ROOT** first; `dart format --output=none --set-exit-if-changed .`;
`cd apps/control_plane && flutter analyze`; `cd apps/control_plane && flutter test` (baseline **+271**).

Commit in logical commits. **Do not push, merge, or touch `main`.**
Report `READY_FOR_INDEPENDENT_REVIEW: YES`, plus `SAFE_PARALLEL_WORK` / `PROHIBITED_PARALLEL_WORK`.