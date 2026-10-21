MANAGER: orchestrator-main
TASK_ID: IMPL-INFLOW-BOUND-SCOPE
TASK_TYPE: implement
FEATURE: maxImplementationInflows suppresses the review route, which is not an implementation entry
WORKTREE: /Users/alkebut/.aef-lanes/inflow-bound-scope
BRANCH: fix/inflow-bound-scope
BASE_SHA: e8cd0ce
OWNED_PATHS:
  - packages/scheduler/lib/src/scheduler.dart
  - packages/scheduler/lib/src/implementation_inflow.dart
  - packages/scheduler/test/implementation_completion_inflow_test.dart
  - apps/server/test/implementation_inflow_tick_order_test.dart
READ_ONLY_PATHS:
  - packages/scheduler/lib/src/policy/**
  - apps/server/lib/src/review/engineering_review_gate.dart   (owned by IMPL-REVIEW-GATE-PARK - do NOT edit)
  - apps/server/lib/**
PROHIBITED_PATHS:
  - apps/control_plane/**   apps/server/lib/**   apps/server/migrations/**  apps/server/test/**
    (except the two named test files above)
  - packages/worker_runtime/**  packages/execution_coordinator/**
ACCEPTANCE_CRITERIA:
  - The maxImplementationInflows bound is evaluated ONLY for routes that enter the implementation lane.
    A route to reviewInProgress - which is engineeringReviewDefinition.entryStates, not an implementation
    entry - is not suppressed by an implementation-lane counter.
  - The bound's cycle-safety intent is preserved: a commit-producing item that loops must still terminate.
    State how you preserved it.
  - The refusal path that hands the item to a human gate still fires when it should.
VALIDATION_COMMANDS:
  - dart format --output=none --set-exit-if-changed packages/scheduler apps/server/test
  - dart analyze packages/scheduler apps/server
  - dart test test/implementation_completion_inflow_test.dart test/implementation_inflow_tick_order_test.dart
ROUTING_CLASS: STANDARD

ROOT CAUSE (research lane RESEARCH-AGENT-COMPLETED-INFLOW, verified against the live QA database):
Scheduler._routeOneCompletion computes the route at packages/scheduler/lib/src/scheduler.dart:1561 and
then checks the bound BEFORE the write, FOR BOTH ROUTES, at :1582. maxImplementationInflows = 3
(implementation_inflow.dart:264). Measured triageAttempt: the one item that routed had 2; the four that
stalled had 3, 4, 3, 4. defect-DEF-1791684557133597 DID produce a commit (f58d6fb1 -> 612dab2f) and
completionRouteFor named reviewInProgress - an entry into the REVIEW lane, not the implementation lane -
and the bound still refused it. implementation_inflow.dart:246-257 justifies the stand-down by pointing
at the human gate, but that justification does not hold for a route that never entered this lane.

CAUTION - two things this change must NOT pretend to fix:
  - defect-DEF-1791684804452198, -1791686085546076, -1791686704991884 have ZERO agent_execution rows
    (their producers ran before 254dbec wired PostgresExecutionStore). agentResultValid() therefore
    cannot be satisfied and the fail-closed park is unreachable. Backfilling those rows is EXPLICITLY
    REJECTED by docs/engineering/learning/the-writer-and-the-reader-were-different-stores.md:119-136.
    Do not backfill. Do not weaken a guard to make them pass. Report them as still-stranded.
  - defect-DEF-1791684557133597 also holds a consumed dedupe key (:a3 held by a failed job), so a code
    fix alone will not make a job mint for it.

Read packages/scheduler/test/implementation_completion_inflow_test.dart and
apps/server/test/inplementation_inflow_tick_order_test.dart BEFORE writing; state which existing tests
cover this behaviour and which do not.

CONSTRAINTS: no docker/compose. No psql. Do not edit outside OWNED_PATHS. Commit your work. You may not
approve your own work.
