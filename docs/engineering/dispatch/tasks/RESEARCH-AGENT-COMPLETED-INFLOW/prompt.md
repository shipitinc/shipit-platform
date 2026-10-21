MANAGER: orchestrator-main
TASK_ID: RESEARCH-AGENT-COMPLETED-INFLOW
TASK_TYPE: research
FEATURE: Why finished work never reaches implementation or review — the agent_completed / review_in_progress stall
AREA: packages/scheduler dispatch, inflow and supersession policy
WORKTREE: (none — READ-ONLY. You operate from /Users/alkebut/air/shipit-platform at e8cd0ce)
BRANCH: (none)
BASE_SHA: e8cd0ce
OWNED_PATHS:
  - (none — this lane is strictly read-only and MUST NOT create, edit, stage or commit any file)
READ_ONLY_PATHS:
  - packages/scheduler/**
  - packages/workflow_store/**
  - packages/execution_coordinator/**
  - apps/server/lib/**
  - apps/server/test/**
PROHIBITED_PATHS:
  - every file — you have no write authority on this task, by design
ACCEPTANCE_CRITERIA:
  - A precise, evidence-backed root cause for EACH of the three stalls below, naming the exact file:line
    and the exact branch of logic that produces it.
  - For each root cause, the MINIMAL fix location, expressed as a proposed `OWNED_PATHS` set that does
    not intersect IMPL-TRANSITION-ROW-500 or IMPL-WORKER-REGISTRATION.
  - A statement of which existing tests cover the behaviour and which do not, by test name.
  - Explicit statement of anything you could NOT determine, with what evidence would settle it.
VALIDATION_COMMANDS:
  - (none — read-only. You may READ tests. Do NOT run `dart test` against the live stack or any
     docker command.)
ROUTING_CLASS: STANDARD

## The original request, verbatim

"could work you on these concurrently (you're the orchestrator) where they don't conflict?"

## Live state, measured by the Manager against the running QA stack

14 work items exist. **Zero have finished.** Their states:

| state | count | ids |
|---|---|---|
| `agent_completed` | 4 | `defect-DEF-1791684557133597`, `defect-DEF-1791684804452198`, `defect-DEF-1791686704991884`, `defect-DEF-1791686085546076` |
| `review_in_progress` | 4 | `defect-DEF-1791685024220546`, `defect-DEF-1791685924503981`, `defect-DEF-1791686357139031`, `defect-DEF-1791685264570406` |
| `agent_failed` | 2 | `defect-DEF-1791685722309971`, `defect-DEF-1791685401972067` |
| `planned` | 2 | `design-remediation-DEF-1791686085546076`, `design-remediation-DEF-1791685264570406` |
| `planned` / `draft` | 2 | `WI-feature-1791823723502264` / `WI-feature-1791686174076431` (the `draft` one has ZERO transitions) |

Job table totals: **926 jobs — 870 cancelled, 28 succeeded, 25 failed, 3 queued.**
By type: `triage_defect` 12 failed / 18 succeeded; `engineering_review` **11 failed / 4 succeeded /
3 queued / 870 cancelled**; `implement_feature` 2 failed / 5 succeeded.

### Question 1 — the `agent_completed` stall (4 items)

`packages/scheduler/lib/src/implement_feature.dart` declares:

    entryStates: {WorkItemState.implementationReady},
    completionInflowFrom: {WorkItemState.agentCompleted},

and documents the intended discriminator: an item at `agent_completed` whose producer left **no**
commit routes to `implementationReady` (a triage run writes a report and no file, "so this is every
item triage has ever finished"); one that left a commit routes to `reviewInProgress`.

One item demonstrably traversed this path. `defect-DEF-1791685722309971` has this transition:

    agent_completed -> implementation_ready  (system_event, orchestrator, accepted)
        reason: "the producer of defect-DEF-1791685722309971 left no implementation artifact
                 (the producing execution reached 9...)"
    implementation_ready -> agent_executing  (accepted)
    agent_executing -> agent_failed         (accepted)

The 4 items in `agent_completed` have NO such transition. Their last transition is instead:

    agent_completed -> agent_completed  (accepted)
        reason: "One-time data repair (IMPL-A8-REPOINT-DEFECTS). NO STATE CHANGE: this row records
                 a product repoint only, whic..."

**Question: why does `completionInflowFrom` fire for one item and not the other four?**
Determine what distinguishes them — a metadata field, `triageAttempt`, the presence of an execution
record, `producedCommitFor`'s actual implementation, or the dedupe discriminator. Note that
`defect-DEF-1791684557133597`'s history shows the item DID reach `review_in_progress` earlier, took a
`waiting_for_human_decision` rework, and was then pulled back.

### Question 2 — the `review_in_progress` stall (4 items)

These entered review but 11 `engineering_review` jobs are `failed` and nothing recovers them.
`engineeringReviewDefinition` is declared at `packages/scheduler/lib/src/scheduler.dart:3179` with
`entryStates: {WorkItemState.agentCompleted}`. **An item at `review_in_progress` is therefore NOT in
its own lane's entry set.** Determine what is supposed to move an item out of `review_in_progress`
after a failed review — is there any producer for that edge at all, or is `review_in_progress`
terminal-absent-by-omission?

### Question 3 — 870 cancelled review jobs

They are created in pairs sharing an identical `createdAt` to the microsecond and cancelled seconds
later. The newest pair: created `2026-10-15T19:25:35.061399Z`, both `cancelled`, with events
`job_queued -> job_claimed -> job_dispatched -> job_cancelled` within 5 seconds.
Determine what creates the duplicate pair and what cancels them. Relevant prior art in the history:
`a9-reviewkey` / commit `20099aa` "A9 correction: one unreadable marker must not kill the review
tick", and `b8-stall` / `67a738b`.

## Where to start reading

- `packages/scheduler/lib/src/implement_feature.dart` (the inflow contract and its docs)
- `packages/scheduler/lib/src/scheduler.dart` — `engineeringReviewDefinition` at :3179; note the
  `entryStates` handling at :1249, :1416, :1501, :2403
- `packages/scheduler/lib/src/policy/runnable_work.dart` — `RunnableWorkEvaluator.evaluate`, the
  entry-state rejection at :172
- `packages/scheduler/lib/src/policy/entry_hop.dart` — `EntryHopper`, the hop-target check at :288
- `packages/scheduler/lib/src/triage_defect.dart` — its `entryStates` set and the dedupe discussion
- `apps/server/lib/src/triage/stalled_work_item_gate.dart` — written about exactly this stall
- EXISTING tests that already cover adjacent behaviour — read them before concluding anything is
  uncovered: `apps/server/test/implementation_inflow_tick_order_test.dart`,
  `apps/server/test/inflow_vs_review_route_test.dart`,
  `apps/server/test/stalled_work_item_gate_test.dart`,
  `apps/server/test/scheduler_retry_dispatches_again_test.dart`,
  `apps/server/test/tick_reconcile_failure_reporting_test.dart`,
  `apps/server/test/tick_single_flight_test.dart`

## Authoritative sources

- `AGENTS.md` (root)
- `docs/engineering/WORKFLOW.md` — workflow authority
- `docs/engineering/HUMAN_DECISIONS.md` — two decisions are OPEN and may bear on Question 1:
  `HD-6` (`67ec3b62`, design approval vs the triage dedupe discriminator) and
  `HD-7` (`b1e4d3a0`, recorded PENDING but effectively answered by commit `254dbec`).
  If your analysis shows HD-6 is load-bearing for Question 1, say so explicitly and quantify what
  changes depending on the answer — do NOT assume an answer.

## Other lanes running concurrently

- **IMPL-TRANSITION-ROW-500** — writing `db_row_util.dart`, `postgres_workflow_store.dart`,
  `apps/server/migrations/**`
- **IMPL-WORKER-REGISTRATION** — writing `apps/server/lib/server.dart`, `packages/worker_runtime/**`

You write nothing, so you cannot conflict. But if your proposed fix would need a path one of them
owns, say so in your report so the Manager can sequence it.

## Hard constraints

- **Do NOT run any docker or docker compose command.** AGENTS.md binds every lane.
- **Do NOT connect to or modify the live QA database** (no psql against localhost:5432). Read-only
  `psql` SELECTs are acceptable ONLY if you need a column the Manager did not supply; if you use one,
  say exactly what you queried.
- **Do NOT edit, create, stage, or commit any file.** This lane produces findings, not changes.
- Do not restate the Manager's framing as your conclusion. Several times in this repository a lane
  has been handed an incorrect premise by the Manager; if the evidence contradicts what I wrote above,
  say so plainly and show the evidence.