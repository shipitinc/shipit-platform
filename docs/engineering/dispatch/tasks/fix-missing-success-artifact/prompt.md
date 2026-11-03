# Dispatch — fix-missing-success-artifact (F-247, investigate-then-fix)

```yaml
MANAGER: orchestrator-main
TASK_ID: fix-missing-success-artifact
TASK_TYPE: implement
FEATURE: Investigate + fix: IMPLEMENTER/ENGINEERING_REVIEWER executions run real paid calls but produce no success artifact (no commit / no verdict)
AREA: agent result/artifact production + success-artifact check
WORKTREE: /private/tmp/shipit-fix-artifact
BRANCH: fix/missing-success-artifact
BASE_SHA: HEAD
OWNED_PATHS: [packages/agent_runtime/**, packages/worker_runtime/**, packages/execution_coordinator/**, packages/platform_contracts/**]
READ_ONLY_PATHS: [apps/server/lib/**, packages/scheduler/**, packages/workflow_store/**, packages/workflow_engine/**]
PROHIBITED_PATHS: [apps/server/**, .agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/**]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root, dart pub get first), dart analyze + dart test (each touched package)]
ROUTING_CLASS: PRECISION
```

## Confirmed failures (live, model_execution_record)

- `defect-DEF-1791686357139031` — IMPLEMENTER execution produced `missing_success_artifact:
  IMPLEMENTER execution agx-wx-... produced no commit` — the model ran real tokens
  (sonnet-5.5, cost>0) but emitted no commit.
- `defect-DEF-1791685401972067` + `DEF-fresh-test` — same implement/no-commit class.
- `design-remediation-DEF-1791686085546076` — ENGINEERING_REVIEWER `missing_success_artifact:
  ... completed with` — ran, no verdict.

This is a NEW failure class distinct from the quota/permission stalls: the model engages,
consumes tokens, the session terminates — but the execution lacks the success artifact the
platform requires (a commit for implementer, a verdict for reviewer).

## Task — investigate first, then fix honestly

1. REPRODUCE/DIAGNOSE first: what does the success-artifact check actually require, where is it
   enforced (agent result → artifact/commit emission → the missing_success_artifact record), and
   WHY did these executions produce no commit/verdict? Candidates to test honestly:
   (a) the cheap model (deepseek-flash) produces output that doesn't satisfy the commit/verdict
       contract — an output-format/capability issue, not a platform bug;
   (b) the platform's artifact extraction/commit-write path drops the artifact (a real bug);
   (c) the execution ran to budget/event termination without the commit step ever running.
   Inspect the failing executions' events/result records to classify which.
2. Then fix the honest root: if it's (a) model output, the fix is the artifact-contract prompt/
   extraction + escalation, NOT suppressing the check; if (b) a platform bug, fix the emission/
   commit path; if (c) a lifecycle defect, fix the settle path.
3. Regression test for whichever root you find.
4. Report the root cause classification + the fix + whether the platform should treat
   missing_success_artifact as provider-failure (auto-escalate) or work-failure (no escalation).

## Rules
New commits; no push; no docker/DB writes (read-only DB inspection to pull the failing
executions' events/result OK); nothing outside OWNED_PATHS — IMPLEMENTATION_BLOCKED if the root
needs apps/server composition outside owned paths. Report per subtask-report.md:
`RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`, HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`,
`ROOT CAUSE:` and `ESCALATE-ON-MISSING-ARTIFACT:`.
