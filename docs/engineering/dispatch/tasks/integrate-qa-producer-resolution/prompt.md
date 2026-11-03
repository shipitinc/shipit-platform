# Dispatch — integrate-qa-producer-resolution

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-qa-producer-resolution
TASK_TYPE: integrate
FEATURE: resolveProducerExecution contract-aware — requiredRole scope
WORKTREE: /private/tmp/shipit-fix-producer-res + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/qa-producer-resolution
BASE_SHA: 00d236b
APPROVED_HEAD: 1c37bf31baefc1cf7d6967340dfbce43760021e7
REVIEW_VERDICT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP (mechanism + mapping + consistency verified)
CURRENT_MAIN: HEAD
ROUTING_CLASS: STANDARD
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. Four files
(producer_execution.dart + required_role test + production_qa_sources.dart + contract_producer
test, under packages/execution_coordinator + apps/server/lib/src/qa). Verify: approved HEAD
unchanged; rehearsal clean, reviewed blobs identical; gates on merged tree: `dart format
--set-exit-if-changed .` (root, dart pub get first), `dart analyze` + `dart test`
(execution_coordinator + apps/server co-located qa suites), `dart run tool/run_unit_tests.dart`
(apps/server); make test-integration needed (the drain drives durable transitions — DB-facing;
reasoning). No merge, no push, no docker beyond make test-integration, no DB. Report ending
exactly `RESULT: MERGE_APPROVED` or `RESULT: INTEGRATION_BLOCKED`.
