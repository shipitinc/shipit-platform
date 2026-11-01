# Dispatch — fix-contract-gate (F-242)

```yaml
MANAGER: orchestrator-main
TASK_ID: fix-contract-gate
TASK_TYPE: implement
FEATURE: F-242 contractless items reach implement jobs → guaranteed permanent failure at agentCompleted
AREA: implementation readiness / QA-contract precondition
WORKTREE: /private/tmp/shipit-fix-contract-gate
BRANCH: fix/contract-gate
BASE_SHA: HEAD
OWNED_PATHS: [apps/server/lib/**/*, apps/server/test/**/]
READ_ONLY_PATHS: [packages/workflow_engine/**/*, packages/platform_contracts/**/*, packages/scheduler/**/*]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/**]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root), dart analyze + dart run tool/run_unit_tests.dart (apps/server), dart analyze + dart test (packages/scheduler)]
ROUTING_CLASS: STANDARD
```

## Confirmed defect (live on QA)
Items with NO `qaContractId` (DEF-fresh-test, DEF-f223-test, and any item without a QA contract)
fail `Workflow transition rejected: agentExecuting -> agentCompleted (QA contract must exist
before implementation completes)` at the FINAL transition — the job does the agent work, then
the transition is rejected and the attempt is gone. Every retry burns an attempt on a
guaranteed-fail gate.

## Task — choose the structurally correct fix, don't patch a symptom
The precondition should be enforced BEFORE the agent work is consumed. Options (evaluate the
codebase's own pattern first — `implementation_readiness_probe.dart` already gates product
state/onboarding/durable clone): (a) extend the readiness probe to also defer `agentExecuting`
when no `qaContractId` exists (implementation.deferred.qa_contract_missing — resumable once a
contract is minted); (b) have the upstream lane mint the QA contract before implementation jobs
are reachable. Inspect where the `QA contract must exist` transition check fires and where the
readiness probe sits — implement the remedy at the correct layer. Regression test: an item with
no qaContractId is deferred/never dispatched an implement job rather than burning an attempt to
the rejected transition.

## Rules
New commits on the branch; no push; no docker/DB. If the correct fix needs paths outside
OWNED_PATHS, report `IMPLEMENTATION_BLOCKED` with the exact contract. Report per
subtask-report.md: `RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`, HEAD_SHA,
`READY_FOR_INDEPENDENT_REVIEW:`.
