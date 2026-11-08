# Dispatch — fix-gen-doc-drift (F-255 + F-263)

```yaml
TASK_ID: fix-gen-doc-drift
TASK_TYPE: implement
FEATURE: reconcile stale generated-doc comments — closed-set action tokens + "not offered through actionContext" + operator_action.spy "only producer is the transaction"
AREA: yaml model/db docs + generated mirrors (serverpod generate)
WORKTREE: /private/tmp/shipit-fix-gen-drift
BRANCH: fix/gen-doc-drift
BASE_SHA: HEAD
OWNED_PATHS: [apps/server/lib/src/models/**, apps/server/lib/src/database/**, apps/server/lib/src/generated/**, packages/control_plane_client/lib/src/**, apps/server/test/**]
READ_ONLY_PATHS: [packages/workflow_engine/**, packages/workflow_store/**]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/**]
ROUTING_CLASS: PRECISION
```

F-255/F-263 (verified live): stale `'retry' | 'stop' — a closed set` docs in
`apps/server/lib/src/models/work_item_action_view.yaml`, `operator_action_summary_view.yaml`,
`apps/server/lib/src/database/operator_action.spy.yaml` (+ "only producer is the transaction"
claim now false — the gateless-deploying standalone append exists), and generated
`client.dart`'s stale "NOT OFFERED THROUGH actionContext" on `relandDeployedWorkItem` (the
endpoint doc was updated but codegen wasn't re-run). The action vocabulary is now retry/stop/
deploy/reclaim/reland/reroute.

Task: (1) fix the yaml doc comments to name the real vocabulary + the gateless-deploying
exception (matching the workflow_store doc amendments); (2) `serverpod generate` to regen the
mirrors (`apps/server/lib/src/generated/**`, `packages/control_plane_client/lib/src/protocol/**`);
(3) verify `client.dart`'s reland doc picks up the corrected endpoint doc; (4) report which files
changed in codegen vs by hand. Gates: `dart format --set-exit-if-changed .` (root, dart pub get),
`dart analyze` (apps/server + control_plane_client), `dart run tool/run_unit_tests.dart`
(apps/server). New commits; no push; no docker/DB. Report `RESULT: IMPLEMENTED`/`BLOCKED`,
HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`.
