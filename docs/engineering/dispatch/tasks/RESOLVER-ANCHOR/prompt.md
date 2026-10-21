MANAGER: ses_orchestrator_main
TASK_ID: RESOLVER-ANCHOR
TASK_TYPE: implement
FEATURE: Anchor the engineering-review workload resolver to the implementer's execution
AREA: apps/server — engineering review gate resolver
WORKTREE: /Users/alkebut/air/.aef-lanes/resolver-implementer-anchor
BRANCH: impl/resolver-implementer-anchor
BASE_SHA: 10f5a7d
OWNED_PATHS:
  - apps/server/lib/src/review/engineering_review_gate.dart
  - apps/server/test/engineering_review_workload_test.dart
READ_ONLY_PATHS:
  - packages/platform_contracts/lib/src/types/worker_execution.dart
  - packages/platform_contracts/lib/src/types/work_item.dart
  - packages/worker_runtime/lib/src/worker/local_worker.dart
  - packages/execution_coordinator/lib/src/coordinator/execution_coordinator.dart
PROHIBITED_PATHS:
  - apps/server/lib/server.dart
  - apps/server/lib/src/review/** (other files)
  - packages/**
  - docs/**
  - docker/**
ACCEPTANCE_CRITERIA:
  - engineeringReviewWorkloadResolver selects ONLY the worker execution that produced
    the IMPLEMENTER's artifact for the given work item, identified by the work item's
    producerActorId metadata matching that execution's agentExecutionId.
  - It returns null (fail closed) when producerActorId is absent, when no execution
    matches it, or when the matching execution produced no artifact
    (endingRevision == requestedStartingRevision or null).
  - It never returns a REVIEWER execution (requiredCapabilities contains
    WorkerCapability.engineeringReview).
  - It never returns an execution belonging to a different work item.
  - When several implementer executions exist for the work item, the one matching
    producerActorId wins outright; latest-by-time is no longer the selection rule.
  - engineeringReviewMissingArtifact is NOT changed by this task.
VALIDATION_COMMANDS:
  - cd /Users/alkebut/air/.aef-lanes/resolver-implementer-anchor/apps/server && dart format --output=none --set-exit-if-changed lib test
  - cd /Users/alkebut/air/.aef-lanes/resolver-implementer-anchor/apps/server && dart analyze
  - cd /Users/alkebut/air/.aef-lanes/resolver-implementer-anchor/apps/server && dart test test/engineering_review_workload_test.dart test/engineering_review_e2e_test.dart
ROUTING_CLASS: STANDARD

## Request (verbatim)

"before runnign qa-up let's tackle the necessary work to ensure that those defects/features can successfully complete the flow. Also FYI you're the orchestrator."

## The finding (reviewer M1 from an independent review of 10f5a7d)

`engineeringReviewWorkloadResolver` currently selects the LATEST worker execution for the work item whose
`endingRevision != requestedStartingRevision` and whose capabilities do NOT include `engineeringReview`
(`engineering_review_gate.dart`, the resolver function).

That is wrong in this deployment. Live QA evidence (read-only): every defect execution runs with
`repositoryPath = /triage-repo` — a scratch repository containing only a README, not the product repository —
and the triage agent is a non-reviewer role. Because `LocalWorker` now commits an artifact for EVERY non-reviewer
role, a triage execution that dirties its worktree creates `shipit/impl/<workItemId>` and becomes a resolver
candidate. The resolver would then hand a reviewer the triage scratch-repo commit as if it were the
implementation under review — the exact wrong-revision dispatch this work was written to eliminate.

`WorkerExecution` carries no `role` field, so selection must be anchored on identity instead.

## How to anchor (verify this yourself before relying on it)

- The coordinator stamps the producing execution id onto the work item's metadata as `producerActorId`
  (`packages/execution_coordinator/lib/src/coordinator/execution_coordinator.dart`, `metadataMerge` in
  `_completeSuccess`).
- `LocalWorker` records the agent execution id on the worker execution as `agentExecutionId`
  (`packages/worker_runtime/lib/src/worker/local_worker.dart`).
- Therefore: the implementer's worker execution is the one whose `agentExecutionId` equals
  `workItem.metadata['producerActorId']`.

Read those two files and CONFIRM this linkage holds end to end before you rely on it. If it does not hold,
STOP and report `IMPLEMENTATION_BLOCKED` with the evidence rather than implementing a fallback that guesses.

## Tests you must add / update

In `apps/server/test/engineering_review_workload_test.dart`:
1. selects the execution whose agentExecutionId matches producerActorId;
2. returns null when producerActorId is absent;
3. returns null when the producer execution produced no artifact (endingRevision == requestedStartingRevision);
4. returns null when the producer execution has a null endingRevision;
5. a LATER non-reviewer execution (a triage run) does NOT win over the anchored implementer execution;
6. a reviewer execution is never returned.

Do not weaken or delete existing tests.

## Constraints

- Stay strictly inside OWNED_PATHS. In particular do NOT edit `apps/server/lib/server.dart` — another concern
  (the fail-closed no-op when no agent result exists) is blocked pending a human decision, and that file is
  outside your ownership.
- Do NOT run any state-changing Docker or Compose command. `apps/server` integration tests require Postgres;
  run ONLY the two test files named in VALIDATION_COMMANDS.
- You may not approve your own work. Return a structured IMPLEMENTATION_RESULT for independent review.

## Cleanup checklist

- Confirm `git status --porcelain` in the worktree lists ONLY files under OWNED_PATHS.
- Do not merge, push, or delete the worktree.