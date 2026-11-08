# Dispatch — feat-schema-drift-migration (F-264)

```yaml
TASK_ID: feat-schema-drift-migration
TASK_TYPE: implement
FEATURE: schema drift — design_revision.declared_owned_paths column + missing indexes flagged by the schema analyzer
AREA: apps/server/migrations + generated schema
WORKTREE: /private/tmp/shipit-feat-schema-drift
BRANCH: feat/schema-drift-migration
BASE_SHA: HEAD
OWNED_PATHS: [apps/server/migrations/**, apps/server/lib/src/generated/**, apps/server/test/**]
READ_ONLY_PATHS: [packages/workflow_store/**, packages/workflow_engine/**]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/**]
ROUTING_CLASS: PRECISION
```

F-264 (deploy-lane verified residual): the schema analyzer warns the generated schema is ahead
of applied migrations — `Missing Column design_revision.declared_owned_paths` + 3 missing
indexes (design_revision + product_credential). Non-fatal WARNING in staging but the drift
widens every release.

Task: (1) inspect `apps/server/lib/src/database/*.spy.yaml` vs applied
`apps/server/migrations/**` + `migration_registry.txt`; (2) author the migration(s) that bring
the applied schema to the generated one (column + indexes), following the existing migration
convention + registry entry; (3) regen if the convention requires it; (4) regression-verifiable
(the migration applies cleanly and the analyzer's missing-column/index warnings close).
Gates: `dart format --set-exit-if-changed .`, `dart analyze` (apps/server), `dart run
tool/run_unit_tests.dart` (apps/server). New commits; no push; no docker/DB writes (the QA DB
applies it at the next deploy). Report `RESULT: IMPLEMENTED`/`BLOCKED`, HEAD_SHA,
`READY_FOR_INDEPENDENT_REVIEW:`, `MIGRATION:`.
