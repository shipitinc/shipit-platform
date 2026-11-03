# Dispatch — integrate-impl-qa-contract-instruction

```yaml
MANAGER: orchestrator-main
TASK_ID: integrate-impl-qa-contract-instruction
TASK_TYPE: integrate
FEATURE: implement_feature instruction no longer sends the agent hunting a DB-resident QA contract
WORKTREE: /private/tmp/shipit-fix-contract-instr + canonical /Users/alkebut/air/shipit-platform
BRANCH: fix/impl-qa-contract-instruction
BASE_SHA: 975d145
APPROVED_HEAD: eb58bf8a706836723fc7e12ad63bc1c173ecd8ff
REVIEW_VERDICT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP (wording verified honest; inlining infeasible)
CURRENT_MAIN: HEAD
ROUTING_CLASS: STANDARD
```

Stop at MERGE_APPROVED / INTEGRATION_BLOCKED — no merge, no push. Two files
(implement_feature.dart + implement_feature_prompt_contract_test.dart, all packages/scheduler/**).
Verify: approved HEAD unchanged; rehearsal clean, reviewed blobs identical; gates on merged tree:
`dart format --set-exit-if-changed .` (root, dart pub get first), `dart analyze` + `dart test`
(packages/scheduler, +468); make test-integration needed (the instruction drives agent calls that
produce durable executions — the scheduler-side dispatch path is DB-facing; reasoning). No merge,
no push, no docker beyond make test-integration, no DB. Report ending exactly
`RESULT: MERGE_APPROVED` or `RESULT: INTEGRATION_BLOCKED`.
