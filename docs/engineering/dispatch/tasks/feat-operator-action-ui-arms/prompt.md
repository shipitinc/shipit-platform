# Dispatch — feat-operator-action-ui-arms (F-260 + F-262)

```yaml
MANAGER: orchestrator-main
TASK_ID: feat-operator-action-ui-arms
TASK_TYPE: implement
FEATURE: expose `reland` + `reroute` operator actions in the UI — actionContext offers, bloc switch arms, copy, panel, and the 'STARTED AGAIN' ledger mislabel
AREA: work_item_action_endpoints (actionsFor) + apps/control_plane action surface
WORKTREE: /private/tmp/shipit-feat-ui-arms
BRANCH: feat/operator-action-ui-arms
BASE_SHA: HEAD
OWNED_PATHS: [apps/server/lib/src/**, apps/control_plane/lib/**, apps/control_plane/test/**]
READ_ONLY_PATHS: [packages/workflow_engine/**, packages/workflow_store/**, packages/control_plane_client/lib/src/**]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/**]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root, dart pub get first), dart analyze (apps/server + apps/control_plane + touched), dart run tool/run_unit_tests.dart (apps/server), flutter test (apps/control_plane)]
ROUTING_CLASS: PRECISION
```

## Confirmed gaps (verified by prior lanes)

- `relandDeployedWorkItem` + `rerouteToImplementation` endpoints are LIVE but deliberately
  absent from `actionContext`/`actionsFor` — the implementer verified the UI would dead-button
  (run_detail_bloc's switch has retry/deploy/reclaim arms; unknown actions fall through `_ =>`
  to stopFailedWorkItem; FailedWorkItemActionPanel renders retry/stop lookups only).
- `priorActions` rendering labels every non-'stop' audit row "STARTED AGAIN" — 'reland' and
  'reroute' rows would mislabel.

## Verified facts to reuse

- Owed predicates already exist: `deployRelandIsOwed` (deployed + deployedCommit absent) and
  the reroute's `deployed` state guard. `actionContext`/`actionsFor` must offer 'reland' only
  for deployed items missing the stamp and 'reroute' for deployed items generally — verify
  the intended offer condition per action (reroute on ALL deployed? or only unlanded? —
  choose honestly; a landed item could still legitimately be sent back to build).
- Precedent: the existing 'deploy'/'reclaim' actionContext offers + the run_detail bloc
  dispatch (run_detail_bloc.dart switch arms ~162-186), operator_action_copy.dart
  announcements, and OperatorActionPanel rendering.
- Client methods already exist in generated protocol (advanceToDeploy, reclaimStranded-
  Execution, relandDeployedWorkItem, rerouteToImplementation) — the repository layer needs
  the calls if absent.

## Task

1. Server — `actionsFor`/`actionContext`: offer 'reland' for deployed items missing the
   deployedCommit stamp, and 'reroute' for deployed items (per the chosen condition — state
   it). Use the existing WorkItemActionView tokens.
2. Client — `run_detail_bloc`: add 'reland' → repository.relandDeployedWorkItem and
   'reroute' → repository.rerouteToImplementation switch arms (before the `_ =>` fallback);
   repository methods if missing; `operator_action_copy.dart` announcements for both
   (accepted + refusal sentences, following deploy/reclaim voice); OperatorActionPanel
   rendering (confirm strip, reason field — same pattern); the priorActions ledger label
   fix so 'reland'/'reroute' rows render honest copy instead of 'STARTED AGAIN'.
3. Regression tests: actionContext offers each action for the right state only; bloc routes
   each to the right repository call; copy announcements; panel renders with non-blank-
   reason gate; ledger label. Follow the existing test precedents
   (operator_action_panel_test, operator_action_copy_test, run_detail_bloc_test,
   work_item_action_endpoints_test).
4. Report `ACTIONS EXPOSED:` + `LEDGER LABEL:`.

## Rules
New commits; no push; no docker/DB writes; nothing outside OWNED_PATHS — IMPLEMENTATION_BLOCKED
if it needs generated/server changes beyond actionsFor (generated client already has the
methods). Report per subtask-report.md: `RESULT: IMPLEMENTED`/`IMPLEMENTATION_BLOCKED`,
HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`, `ACTIONS EXPOSED:`, `LEDGER LABEL:`.
