MANAGER: orchestrator-main
TASK_ID: IMPL-REVIEW-GATE-PARK
TASK_TYPE: implement
FEATURE: review_in_progress is terminal-by-omission when a review job fails permanently
WORKTREE: /Users/alkebut/.aef-lanes/review-gate-park
BRANCH: fix/review-gate-permanent-failure
BASE_SHA: e8cd0ce
OWNED_PATHS:
  - apps/server/lib/src/review/engineering_review_gate.dart
  - apps/server/test/engineering_review_verdict_absent_decision_test.dart
  - apps/server/test/engineering_review_verdict_absent_smoke_test.dart
  - apps/server/test/execution_store_wiring_test.dart
  - apps/server/test/engineering_review_never_fabricates_verdict_test.dart
READ_ONLY_PATHS:
  - packages/scheduler/**
  - apps/server/lib/src/endpoints/**
  - apps/server/lib/src/services/**
PROHIBITED_PATHS:
  - apps/server/lib/server.dart   apps/server/migrations/**   apps/control_plane/**
  - packages/scheduler/**   packages/worker_runtime/**   packages/execution_coordinator/**
  - apps/server/test/**   (except the four named above)
ACCEPTANCE_CRITERIA:
  - A work item at reviewInProgress whose review job has reached a TERMINAL state with NO retry still
    owed reaches a human, rather than sitting forever.
  - The trigger condition is "no retry is still owed" (job terminal, or maxAttempts spent) - NOT
    "the review completed". A permanent failure settles the execution failed/interrupted and can never
    satisfy the current status == completed gate at engineering_review_gate.dart:1016.
  - It must NOT fabricate a verdict. engineering_review_gate.dart:899-917 and the b1 rule stand: the
    absence of a verdict is recorded as absence, and a verdict-less decision asserts no verdict.
  - Transient failures that still have a retry owed must NOT raise - that is the retry-return edge
    reviewInProgress -> agentCompleted (work_item_transitions.dart:388), and it must keep working.
  - While you are in this file, engineering_review_gate.dart:1253 uses the role-blind
    latestExecutionForWorkItem. Assess and, if safe, fix it - it is recorded unresolved at
    docs/engineering/learning/236-transition-rows-that-moved-nothing.md section 8. If fixing it is not
    safe in this lane, say so explicitly rather than silently leaving it.
VALIDATION_COMMANDS:
  - dart format --output=none --set-exit-if-changed apps/server/lib apps/server/test
  - dart analyze apps/server
  - dart test test/engineering_review_verdict_absent_decision_test.dart test/engineering_review_verdict_absent_smoke_test.dart test/execution_store_wiring_test.dart test/engineering_review_never_fabricates_verdict_test.dart
ROUTING_CLASS: STANDARD

ROOT CAUSE (research lane RESEARCH-AGENT-COMPLETED-INFLOW): three candidate producers can move an item
out of reviewInProgress after a failed review, and every one refuses for a PERMANENT failure:
  1. retry-return edge - requires job.state == retryWaiting AND failure.kind.isRetryable, i.e. transient.
     _adopt routes permanent straight to complete(failed) (scheduler.dart:2040-2048) and never schedules a retry.
  2. the verdict path (engineering_review_gate.dart:1082) - needs a parsed ReviewVerdict; there is none.
  3. raiseVerdictAbsentDecision (:1020-1032) - gated on execution.status == completed (:1016), which a
     permanent failure never reaches.
And the review lane can never re-mint: reviewInProgress is NOT in engineeringReviewDefinition.entryStates
({agentCompleted}), so RunnableWorkEvaluator returns noAction BEFORE any policy probe
(runnable_work.dart:172-174), and _retireSupersededForItem (scheduler.dart:2914) sweeps anything queued.
Live victims: defect-DEF-1791685024220546 and defect-DEF-1791686357139031, both
'AgpTransportException: ACP request timed out', job failed with kind permanent.

NOTE: defect-DEF-1791685264570406 and -1791685924503981 are stuck for a DIFFERENT reason - their
reviewers COMPLETED but recorded structuredResultJson = {}. Those two are fixed by DEPLOYING HEAD
(the live build predates 2b29bdd, whose instruction change is what asks for a verdict at all). Do not
duplicate that fix here; do not let your change regress it.

CONSTRAINTS: no docker/compose. No psql. Do not edit outside OWNED_PATHS. Commit your work. You may not
approve your own work.
