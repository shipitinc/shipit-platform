# Dispatch — feat-deploy-main-reroute (F-261)

```yaml
MANAGER: orchestrator-main
TASK_ID: feat-deploy-main-reroute
TASK_TYPE: implement
FEATURE: two deploy-process fixes — land into the product's DEFAULT branch (main), and a rework path deployed->implementation_ready so label-deploys that produced no commit can be rerouted to implementation
AREA: deploy_landing (target branch) + workflow_engine transition table (deployed exit) + operator action
WORKTREE: /private/tmp/shipit-feat-deploy-main
BRANCH: feat/deploy-main-reland-reroute
BASE_SHA: HEAD
OWNED_PATHS: [apps/server/lib/src/**, apps/server/lib/src/generated/**, apps/server/test/**, packages/control_plane_client/lib/src/**, packages/workflow_engine/lib/src/**]
READ_ONLY_PATHS: [packages/workflow_store/**, packages/execution_coordinator/**, packages/scheduler/**]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/**]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root, dart pub get first), dart analyze (apps/server + workflow_engine + touched), dart run tool/run_unit_tests.dart (apps/server), dart test (packages/workflow_engine)]
ROUTING_CLASS: PRECISION
```

## Confirmed gaps (live, verified)

1. `landApprovedDeployment`/`relandDeployedItem` merge `--no-ff` into `repositoryPath`'s
   CURRENT branch — 7 items landed on `shipit/impl/defect-DEF-1791686085546076` (whatever
   branch the clone happened to have checked out), not main. Human directive: deploys must
   land on the product's default branch (main).
2. `deployed` has exactly one exit — `deployed -> completed` (`work_item_transitions.dart:896`).
   The 6 items that refused re-land (implementer produced no commit — `notApplicable`,
   nothing to merge) are parked `deployed` forever with no path back to implementation.

## Verified facts to reuse

- `landApprovedDeployment` mechanism: producedCommitFor -> rev-parse verify -> branch
  (currently `symbolic-ref` current branch) -> merge --no-ff -> merge-base --is-ancestor.
- `relandDeployedWorkItem` operator action pattern (owed guard, refusals write nothing,
  stamp-CAS + audit in one tx).
- Existing rework precedent: engineering-review rework resolves to `implementation_ready`.
- `OperatorActionRecord.action` free-form string — new wire token e.g. 'reroute' rides it.

## Task

A. Land on the default branch: the deploy land must merge the produced commit into the
   product repo's DEFAULT branch (resolve it honestly — e.g. `symbolic-ref refs/remotes/
   origin/HEAD` or the recorded product default branch; for a local clone without remote
   HEAD, a recorded/explicit default like `main`). Do NOT silently keep merging into
   whatever branch the checkout has checked out. If the default branch can't be resolved,
   refuse honestly. Existing already-landed stamps are unaffected.
B. Rework path: add a `deployed -> implementation_ready` edge to the transition table
   (orchestrator actor; consider whether it needs a guard — an audit/operator action, not
   a free transition) + a `rerouteToImplementation` operator action for `deployed` items —
   lands the item back at implementation entry. Deliberately NOT necessarily in
   actionContext if the UI arm would dead-button — follow the reland precedent (endpoint +
   generated client; UI arm is a flagged follow-up).
C. Regression tests: land merges into the default branch even when the checkout sits on a
   lane branch; unresolved default refuses; reroute moves `deployed` -> `implementation_ready`
   honestly + wrong-state refusals write nothing.
D. Report `DEPLOY_TARGET:` + `REROUTE:` and how the 6 stranded items get rerouted (the
   orchestrator fires `rerouteToImplementation` per item after deploy).

## Rules
New commits; no push; no docker/DB writes (scratch git repos under the worktree for tests);
generated only via `serverpod generate`; nothing outside OWNED_PATHS — IMPLEMENTATION_BLOCKED
if it needs more. Report per subtask-report.md: `RESULT: IMPLEMENTED`/`IMPLEMENTATION_BLOCKED`,
HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`, `DEPLOY_TARGET:`, `REROUTE:`.
