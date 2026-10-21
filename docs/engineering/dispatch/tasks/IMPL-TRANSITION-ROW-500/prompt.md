MANAGER: orchestrator-main
TASK_ID: IMPL-TRANSITION-ROW-500
TASK_TYPE: implement
FEATURE: Malformed guardEvaluationsJson bricks the work-item and defect detail endpoints (HTTP 500)
AREA: apps/server persistence row decoding + one repair migration
WORKTREE: /Users/alkebut/.aef-lanes/transition-row-500
BRANCH: fix/transition-row-malformed-guard
BASE_SHA: e8cd0ce
OWNED_PATHS:
  - apps/server/lib/src/persistence/util/db_row_util.dart
  - apps/server/lib/src/persistence/postgres_workflow_store.dart
  - apps/server/migrations/            (exactly ONE new migration directory + its migration_registry.txt entry)
  - apps/server/test/transition_row_malformed_guard_test.dart        (new file, this name only)
  - apps/server/test/malformed_guard_evaluation_repair_migration_test.dart  (new file, this name only)
READ_ONLY_PATHS:
  - apps/server/lib/src/services/control_plane_service.dart
  - apps/server/lib/src/endpoints/workflow_endpoints.dart
  - apps/server/lib/src/endpoints/defect_endpoints.dart
  - packages/platform_contracts/lib/src/types/workflow_transition_record.dart
  - apps/server/tool/schema_bootstrap.sql
PROHIBITED_PATHS:
  - apps/server/lib/server.dart                      (OWNED BY CONCURRENT LANE IMPL-WORKER-REGISTRATION)
  - packages/worker_runtime/**                       (OWNED BY CONCURRENT LANE IMPL-WORKER-REGISTRATION)
  - packages/scheduler/**                            (read-only to you; lane RESEARCH-AGENT-COMPLETED-INFLOW is investigating)
  - packages/execution_coordinator/**
  - apps/control_plane/**
  - docker/**  .github/**  infrastructure/**
  - any file under apps/server/lib/src/persistence/ OTHER THAN the two named in OWNED_PATHS
ACCEPTANCE_CRITERIA:
  - A single malformed `work_item_transition` row can no longer produce an HTTP 500 from
    `workflowEndpoints.inspect` or `defectEndpoints.inspect`.
  - The malformed case is handled EXPLICITLY and is observable (logged / reported), not silently coerced.
  - `decodeJsonArray`'s existing strict contract is NOT silently weakened for its other callers
    (postgres_execution_store.dart and others) as a side effect. If you do change it, every caller
    is audited and the behaviour change is stated in your report.
  - A repair migration exists that rewrites the malformed rows' `guardEvaluationsJson` to a valid
    JSON array WITHOUT destroying the repair metadata those rows carry, and is registered in
    `migration_registry.txt`.
  - Regression tests cover: malformed-object, malformed-scalar, NULL, and the already-valid cases.
VALIDATION_COMMANDS:
  - cd /Users/alkebut/.aef-lanes/transition-row-500 && dart format --output=none --set-exit-if-changed apps/server/lib apps/server/test
  - cd /Users/alkebut/.aef-lanes/transition-row-500 && dart analyze apps/server
  - cd /Users/alkebut/.aef-lanes/transition-row-500 && dart test apps/server/test/transition_row_malformed_guard_test.dart apps/server/test/malformed_guard_evaluation_repair_migration_test.dart
ROUTING_CLASS: PRECISION

## The original request, verbatim

"could work you on these concurrently (you're the orchestrator) where they don't conflict?"

## Evidence (independently reproduced by the Manager against the live QA database)

The QA control plane at `localhost:8081` returns **HTTP 500** for the defect detail screen of
**exactly 5** of its 10 human-reported defects:

    defect-DEF-1791684557133597   workflowInspect 500  defectInspect 500
    defect-DEF-1791685024220546   workflowInspect 500  defectInspect 500
    defect-DEF-1791685264570406   workflowInspect 500  defectInspect 500
    defect-DEF-1791685924503981   workflowInspect 500  defectInspect 500
    defect-DEF-1791686357139031   workflowInspect 500  defectInspect 500

The other 5 return 200. The correlation is exact and total (5/5, no false positives, no false
negatives) with this query:

    SELECT "workItemId","transitionId" FROM "work_item_transition"
    WHERE "guardEvaluationsJson" IS NOT NULL
      AND (left(btrim("guardEvaluationsJson"),1) <> '[');

Every matching row has `transitionId` beginning `tr-unreviewed-review-repair-` and was written by
migration `20261014210000000`. Its value is a repair-metadata **JSON object**, for example:

    {"migration": "20261014210000000", "decisionId": "dec-hn7h7d9j8i-1oh8pgm",
     "newTriageAttempt": 3, "priorTriageAttempt": 2, ...}

The column is declared to hold an array of guard evaluations. The crash path:

1. `apps/server/lib/src/endpoints/workflow_endpoints.dart:50` calls `service.readTransitionHistory(workItemId)`
2. `apps/server/lib/src/services/control_plane_service.dart:1838` -> `workflowStore.readTransitionHistory`
3. `apps/server/lib/src/persistence/postgres_workflow_store.dart:224` maps rows through `_transitionFromRow`
4. `_transitionFromRow` (`postgres_workflow_store.dart:359-378`) passes
   `decodeJsonArray(m['guardEvaluationsJson'] as String?)` into `WorkflowTransitionRecord.fromJson`
5. `apps/server/lib/src/persistence/util/db_row_util.dart:29` is `jsonDecode(value) as List<dynamic>`
   — a decoded `Map<String,dynamic>` fails this cast, throwing a `TypeError`
6. `workflow_endpoints.dart:79-85` logs and rethrows -> Serverpod returns 500

`defectEndpoints.inspect` (`apps/server/lib/src/endpoints/defect_endpoints.dart:116-147`) reaches the
same reader and fails identically.

**A NULL `guardEvaluationsJson` is NOT the cause.** 12 work items carry NULL in that column
(`decodeJsonArray` returns null for it) and every one of them reads fine. Do not "fix" the NULL case.

## Authoritative sources

- `AGENTS.md` (root) — repository invariants; note the read-only-over-Docker rule
- `docs/engineering/WORKFLOW.md` — workflow authority
- `docs/engineering/STRUCTURED_RESULTS.md` — the `IMPLEMENTATION_RESULT` envelope your report must satisfy

## Other lanes running concurrently (you must not touch their paths)

- **IMPL-WORKER-REGISTRATION** — owns `apps/server/lib/server.dart` and `packages/worker_runtime/**`
- **RESEARCH-AGENT-COMPLETED-INFLOW** — read-only, investigating `packages/scheduler/**`

Your `OWNED_PATHS` and theirs do not intersect. If you believe you need a file one of them owns,
STOP and report `IMPLEMENTATION_BLOCKED` naming the exact file and why. Do not edit it.

## Cleanup checklist (mandatory)

- [ ] `git branch --show-current` == `fix/transition-row-malformed-guard`
- [ ] `git rev-parse HEAD` still descends from `e8cd0ce` before you start
- [ ] exactly ONE new migration directory; `migration_registry.txt` updated to match
- [ ] all VALIDATION_COMMANDS run and genuinely passing — report the real output, not a summary
- [ ] commit your work on your branch (a real commit, not just a dirty tree)
- [ ] report exact `git rev-parse HEAD` of your worktree
- [ ] **Do NOT run any docker or docker compose command.** The AGENTS.md rule binds every lane.
- [ ] **Do NOT connect to or modify the live QA database.** Do not run psql against localhost:5432.
      The migration is authored and committed; APPLYING it is a separate human action.