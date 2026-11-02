# Dispatch — integrate-qa-drain-loop

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-qa-drain-loop
TASK_TYPE: integrate
FEATURE: qa.drain loop fix — qaAttempt-scoped idempotency + qaFailed candidate arm
WORKTREE: /private/tmp/shipit-fix-drain-loop + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/qa-drain-loop
BASE_SHA: 7ace9ef
APPROVED_HEAD: 158d8317ec9026a7eab0fb2489b5fb7ed7ad38d2
REVIEW_VERDICT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP (mechanism verified; product decision flagged)
CURRENT_MAIN: HEAD
ROUTING_CLASS: STANDARD
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. Two files
(qa_drain.dart + qa_drain_reentry_test.dart, all apps/server/lib/src/qa/**). Verify: approved
HEAD unchanged; rehearsal clean, reviewed blobs identical; gates on merged tree:
`dart format --set-exit-if-changed .` (root, dart pub get first), `dart analyze` (apps/server),
`dart test` (qa_drain_reentry_test + qa_drain_test), `dart run tool/run_unit_tests.dart`
(apps/server); make test-integration needed (qa_drain drives durable transitions — DB-facing;
reasoning). No merge, no push, no docker beyond make test-integration, no DB. Report ending
exactly `RESULT: MERGE_APPROVED` or `RESULT: INTEGRATION_BLOCKED`.
