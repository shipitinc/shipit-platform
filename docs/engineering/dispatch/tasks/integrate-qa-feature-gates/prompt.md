# Dispatch — integrate-qa-feature-gates

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-qa-feature-gates
TASK_TYPE: integrate
FEATURE: Producer-aware QA gate evaluation — non-triage producers get notApplicable on the triage-shaped gate
WORKTREE: /private/tmp/shipit-fix-qa-gates + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/qa-feature-gates
BASE_SHA: 5a2ef09
APPROVED_HEAD: c58352a264bf7ff745de88c595828c24da6fd167
REVIEW_VERDICT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP (mechanism verified; lib-test enumeration residual filed)
CURRENT_MAIN: HEAD
ROUTING_CLASS: STANDARD
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. Three files
(producer_scoped_gate.dart new + test + production_qa_sources.dart, all apps/server/lib/src/qa/**).
Verify: approved HEAD unchanged; rehearsal clean, reviewed blobs identical; gates on merged tree:
`dart format --set-exit-if-changed .` (root, dart pub get first), `dart analyze` (apps/server +
touched packages), `dart test` (producer_scoped_gate_test + qa_drain_reentry_test — the new lib-
co-located tests need explicit paths), `dart run tool/run_unit_tests.dart` (apps/server); make
test-integration needed (QA gate evaluation drives durable transitions — DB-facing; reasoning).
No merge, no push, no docker beyond make test-integration, no DB. Report ending exactly
`RESULT: MERGE_APPROVED` or `RESULT: INTEGRATION_BLOCKED`.
