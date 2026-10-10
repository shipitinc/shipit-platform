# Dispatch — correct-governance-durable-gate

```yaml
MANAGER: engineering-manager (shipit-platform Add Product work item)
TASK_ID: correct-governance-durable-gate
TASK_TYPE: correct
FEATURE: Make a raised lifecycle gate durable so it cannot be stranded by navigating away
AREA: product_detail lifecycle gate state — client AND the minimal server-side field
WORKTREE: /private/tmp/shipit-fix-governance
BRANCH: fix/governance-panel
BASE_SHA: 0bc016a97b70eb8a6baca593290d0fd58b244016
OWNED_PATHS:
  - apps/control_plane/lib/features/product_detail/**
  - apps/control_plane/lib/data/control_plane_repository.dart
  - apps/control_plane/test/widgets/product_detail_governance_test.dart
  - apps/server/lib/src/endpoints/product_registry_endpoints.dart
  - apps/server/lib/src/persistence/**
  - apps/server/lib/src/generated/**
  - apps/server/lib/src/models/**
  - apps/server/lib/src/services/**
  - apps/server/test/**
  - packages/control_plane_client/lib/src/protocol/**
READ_ONLY_PATHS:
  - packages/product_registry/lib/**
  - packages/workflow_engine/lib/**
  - packages/control_plane_client/lib/src/protocol/client.dart
PROHIBITED_PATHS:
  - packages/**            (EXCEPT packages/control_plane_client/lib/src/protocol/**, granted above)
  - docker/**
  - .github/**
  - docs/**
  - .decisions/**
  - apps/control_plane/lib/features/products/**
ACCEPTANCE_CRITERIA: >
  A raised lifecycle gate survives leaving and re-entering the product detail route, a second
  lifecycle gate cannot be raised while one is open, and an open gate can always be resolved.
VALIDATION_COMMANDS:
  - dart pub get
  - dart format --output=none --set-exit-if-changed .
  - dart analyze apps/server
  - make test-integration
  - cd apps/control_plane && flutter analyze
  - cd apps/control_plane && flutter test
ROUTING_CLASS: PRECISION
```

---

## Read first

- Your prior correction: `docs/engineering/dispatch/tasks/fix-governance-panel/report.md`
- The blocking review: `docs/engineering/dispatch/tasks/review-fix-governance-panel/report.md` — **`DO_NOT_APPROVE_CORRECTIONS`**, `READY_FOR_MERGE: NO`

**Your work was otherwise accepted in full.** All five original findings closed and independently verified;
all three extra defects you found confirmed real and correctly fixed; `noWorkInFlight` soundness accepted;
the `paused` fence deviation judged a faithful application of the recorded decision; and your tests were
verified to bite — **seven independent reverts reproduced by the reviewer**, with the inert-catch revert
alone failing 5 tests. The 304 = 271 + 33 arithmetic was confirmed by deleting your test file.

`OWNED_PATHS` is **widened** — see the HUMAN PATH GRANT below, authorised 2026-10-09.

## HUMAN PATH GRANT (authorised 2026-10-09)

The previous attempt returned CORRECTION_BLOCKED on a path question, having proved with two reverted
`serverpod generate` probes that **every** shape of the fix rewrites `packages/control_plane_client/**` —
including a new endpoint method that adds no model field. `packages/**` being prohibited made the fix
unimplementable, and the client-only mitigation was rejected as shipping the panel still non-functional.

The human granted, explicitly:
- `packages/control_plane_client/lib/src/protocol/**` → **OWNED**
- `apps/server/lib/src/models/**` and `apps/server/lib/src/services/**` → **OWNED**
- `apps/control_plane/lib/data/control_plane_repository.dart` → moved **READ_ONLY → OWNED**

`packages/control_plane_client/lib/src/protocol/client.dart` is the one exception inside that directory and
stays **READ_ONLY** unless you find it unavoidable — say so explicitly if you must touch it, since it is the
widest blast radius in the generated client.

You also now own `apps/server/lib/src/services/**`, which contains `loadProductDetail`
(`control_plane_service.dart:380-397`) — the durable read the fix hangs off, previously unowned by anyone.

## B1 — a raised lifecycle gate is client-memory only

`product_detail_bloc.dart:152`/`:209` and `product_detail_page.dart:666`. `pendingLifecycleDecision` is
set from the **raise response** and cleared on resolve. Unlike the baseline gate, which is re-derived from
durable state, this one evaporates when the route is left.

The reviewer reproduced the full failure:

```
gates raised = [pause, offboard]   # after leaving and returning
after offboard approve, product state: archived
pause gate status: pending  blocking=true
re-raise REFUSED: no legal transition from archived to paused
```

Two `blocking: true` gates coexist. Resolving one leaves the other **permanently** pending and blocking,
with no surface able to raise, list, or resolve it — exactly what
`product_registry_endpoints.dart:164-165` promises never happens.

**This is new behaviour created by your correction** — the actions were unreachable before, so this could
not happen. And it is undisclosed, which is what decides it: you applied the right standard to two
comparable limits and passed over a third of the same species. The asymmetry is visible in two adjacent
doc comments (`_baselineGate`: "driven by durable state"; `_lifecycleGate`: "the gate this screen raised").

## What to change

Make the open lifecycle gate **durable and re-derivable**, the way the baseline gate already is.

- The blocker names the shape: a durable `ProductDetail.pendingLifecycleDecisionId` (or equivalent) under
  `apps/server/**`, surfaced through the product detail view, plus a client-side `gateOpen` state derived
  from durable state rather than from the raise response.
- **While a lifecycle gate is open, withhold the other lifecycle actions** so a second cannot be raised.
  That alone prevents the strand even if the field is imperfect.
- An open gate must be **resolvable on return** without raising again.
- Preserve everything your prior commit established. Do not regress the in-place panel, the action-scoped
  error surface, `isRaisingGate`, the accessibility work, `noWorkInFlight` as an explicit operator
  statement, or the `rework` wire fix.

Two mitigations were offered and **one is not acceptable**: simply withholding lifecycle actions when the
screen cannot prove no gate is open would ship the panel still non-functional. Fix it properly.

## Migration note

If the durable field needs a schema change, it is a **Serverpod model field**, not a hand-maintained object.
Read `apps/server/tool/schema_bootstrap.dart`'s header before touching anything under `migrations/`, and run
`bash apps/server/tool/verify_schema_bootstrap.sh` afterwards — the two hand-maintained indexes must stay
absent from generated definitions.

## Tests — must bite, and must cover the strand

1. **Leave the route, return, and the open gate is still shown and resolvable.** This is the regression
   guard for B1 and it is the test that was missing.
2. **A second lifecycle action is withheld while one is open.**
3. **After resolving, the actions return.**
4. Reproduce the reviewer's exact sequence and show the strand no longer occurs.

Show the strand reproduction failing before your change and passing after.

## Gates — verbatim

`dart pub get` at **REPO ROOT** first; `dart format --output=none --set-exit-if-changed .`;
`dart analyze apps/server`; `cd apps/control_plane && flutter analyze`;
`cd apps/control_plane && flutter test` (baseline **304**); `make test-integration`; and if you changed
Serverpod models, `serverpod generate` (report exit status) plus `verify_schema_bootstrap.sh`.

On `make test-integration`: known to report one failure, `dogfood_shipit_postgres_test.dart`, because a
**linked worktree** has `.git` as a file and `Directory('.git').existsSync()` is false. In a **primary
clone** it is `+192 All tests passed!`. Report the real number and say whether the sole failure is dogfood.
Do not chase it.

## Constraints

- `packages/**` PROHIBITED. `docker/**` PROHIBITED — **the QA stack is live and I am driving it.** ZERO
  mutating Docker/Compose commands; `make test-integration` is the only sanctioned database path and it
  self-cleans. Never `make clean` / `make qa-down` / `make test-env-down` / `make e2e-down` / bare
  `down -v`.
- Never print, log, or echo private key material.
- Do not weaken, skip, `@Ignore`, filter, or delete any test.

## Out of scope

G-7, M-4, M-5, N-1, F-A/F-B and the other recorded deferrals. Also **do not** attempt to make a
`registered` product reach `baselinePending` — the engine has no such edge and the only first-baseline
author is `apps/server/bin/onboard_shipit_dev.dart`. Your earlier report of that is correct and accepted.

Commit in logical commits. **Do not push, merge, or touch `main`.**
Report `READY_FOR_FOCUSED_REVIEW: YES` and `FOCUSED_RE_REVIEW`.