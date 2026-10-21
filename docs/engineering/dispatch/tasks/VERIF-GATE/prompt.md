MANAGER: ses_orchestrator_main
TASK_ID: VERIF-GATE
TASK_TYPE: implement
FEATURE: Gate work-item completion on platform verification outcome
AREA: packages/execution_coordinator — agent completion transition
WORKTREE: /Users/alkebut/air/.aef-lanes/verification-gated-completion
BRANCH: impl/verification-gated-completion
BASE_SHA: 10f5a7d
OWNED_PATHS:
  - packages/execution_coordinator/lib/src/coordinator/execution_coordinator.dart
  - packages/execution_coordinator/test/**
READ_ONLY_PATHS:
  - packages/workflow_engine/lib/src/transitions/work_item_transitions.dart
  - packages/execution_coordinator/lib/src/store/**
PROHIBITED_PATHS:
  - apps/**
  - packages/scheduler/**
  - packages/worker_runtime/**
  - packages/workflow_engine/**
  - packages/platform_contracts/**
  - docs/**
  - docker/**
ACCEPTANCE_CRITERIA:
  - When a platform verification RUNS and FAILS, the work item transitions to
    WorkItemState.agentFailed, NOT agentCompleted.
  - When verification runs and PASSES, behaviour is unchanged (agentCompleted).
  - When no verification plan exists (plan == null), behaviour is unchanged
    (agentCompleted) — a missing check is not a failure.
  - The engineeringReviewer role is untouched: it must still not transition out
    of reviewInProgress.
  - The alreadySettled short-circuit is preserved.
  - metadataMerge of producerActorId on the success path is preserved byte for byte.
VALIDATION_COMMANDS:
  - cd /Users/alkebut/air/.aef-lanes/verification-gated-completion/packages/execution_coordinator && dart format --output=none --set-exit-if-changed lib test
  - cd /Users/alkebut/air/.aef-lanes/verification-gated-completion/packages/execution_coordinator && dart analyze
  - cd /Users/alkebut/air/.aef-lanes/verification-gated-completion/packages/execution_coordinator && dart test
ROUTING_CLASS: STANDARD

## Request (verbatim)

"before runnign qa-up let's tackle the necessary work to ensure that those defects/features can successfully complete the flow. Also FYI you're the orchestrator."

## Evidence and reasoning

Read `packages/execution_coordinator/lib/src/coordinator/execution_coordinator.dart`, `_completeSuccess` (currently lines 632-709).

It runs the platform verification at ~643-667, records the outcome, and then at ~674 transitions the work item to `WorkItemState.agentCompleted` **unconditionally, regardless of whether verification passed or failed**.

Live QA evidence (read-only, do not mutate the DB): 10 work items are stranded at `agent_completed` while their worker executions are `executedFail` and their jobs are terminal `failed`, with job failure reason `executionFailed: verification ... failed`. That is this defect in production.

`_completeFailure` (line 711) already transitions to `agentFailed`. The gap is only that a failed *verification* on an otherwise-completed session takes the success path.

The target edge is legal: `packages/workflow_engine/lib/src/transitions/work_item_transitions.dart:105` declares
`(WorkItemState.agentExecuting, WorkItemState.agentFailed)` with only
`GuardConditions.actorAllowed([ActorType.orchestrator])`. The coordinator's `_orchestrator` actor satisfies it.

Why this unblocks the operator: the UI maps `agent_failed` to `PlainStatus.needsYouItFailed`
("Needs you — it failed", red) via `apps/control_plane/lib/core/plain_language.dart:93`, and the operator retry
endpoint accepts only `WorkItemState.agentFailed`
(`apps/server/lib/src/endpoints/work_item_action_endpoints.dart:454`). `agentCompleted` maps to
`awaitingReview` and retry returns `notApplicable`. So moving failed verifications to `agentFailed` makes the
EXISTING UI and EXISTING retry affordance work, with no UI change needed.

Note for your report (do NOT act on it): the retry target is `agentFailed -> designNotRequired`, which is in
`triageDefectDefinition.entryStates`, so a retry re-runs triage.

## Tests you must add

In `packages/execution_coordinator/test/`, add coverage proving:
1. verification fails -> work item state is `agentFailed`.
2. verification passes -> work item state is `agentCompleted` (regression guard).
3. no verification plan -> `agentCompleted`.
4. the engineeringReviewer role still does not transition out of `reviewInProgress`.

Reuse the existing test helpers in that package. Do not weaken or delete any existing test.

## Constraints

- Stay strictly inside OWNED_PATHS. Do not edit apps/**, scheduler, workflow_engine, or platform_contracts.
- Do NOT run any state-changing Docker or Compose command. `make test-integration` is the only sanctioned DB path
  and is NOT needed here — these tests use in-memory stores.
- You may not approve your own work. Return a structured IMPLEMENTATION_RESULT; an independent reviewer gates this.
- Report exact `git rev-parse HEAD` and the branch you worked on, plus the exact validation output.

## Cleanup checklist

- Confirm `git status --porcelain` in the worktree lists ONLY files under OWNED_PATHS.
- Do not merge, push, or delete the worktree.