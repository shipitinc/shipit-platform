# Dispatch — Design Brief: the missing operator screen for a failed work item

Captured verbatim-in-substance from the Engineering Manager's dispatch message so the requirements
traced in `design-brief.md` §15 have a durable record in the repository. (The `design-work-entry`
revision had to record the absence of its dispatch file; this one is written up front.)

## Feature

Produce a **Design Brief** for the missing operator screen in the ShipIt control plane.
**Design only — do NOT implement production code.**

## Repository

`/Users/alkebut/air/shipit-platform`

Read the existing control-plane conventions before designing. Key files named by the dispatch:

- `apps/control_plane/lib/core/plain_language.dart` — the plain-language vocabulary and the
  state→label mapping. `agent_executing` reads "Working on it". **THIS IS THE BINDING VOCABULARY;
  do not invent new jargon.**
- `apps/control_plane/lib/features/runs/runs_page.dart`, `runs_event.dart` — where run cards render
  state labels and elapsed time.
- `apps/control_plane/lib/features/home/home_page.dart` — the "Needs you / Waiting for your
  approval" treatment and its copy doctrine ("Nothing moves forward until you decide. There is no
  time pressure beyond the limits shown.").
- `apps/server/lib/src/endpoints/home_endpoints.dart` — how the server counts and gates work.
- `packages/workflow_engine/lib/src/transitions/work_item_transitions.dart` — the transition table,
  which is the **AUTHORITY** on what is legal.

## The situation (observed in live QA, verified)

A work item sits in `agent_failed` after an agent execution failed. The UI shows a card reading
"Needs you — it failed", but there is **no action panel, no restart control, and no way for a human
to do anything**. The run detail page `/#/runs/defect-DEF-1791686704991884` has no affordance at all.

The deeper design problem: `WorkItemState.agentFailed` is deliberately excluded from **every**
dispatch entry set in `RunnableWorkEvaluator`, so the item is intentionally routed to a human and
will never auto-retry. That decision is correct and must not be undone. The missing piece is the
screen a human is supposed to use. ShipIt currently routes work to a person and then gives them
nothing to click.

## Hard constraints the design must respect

1. **The transition table is the authority.** From `agent_failed` there is exactly ONE explicit legal
   edge: `agentFailed -> agentExecuting` (retry), plus the generic workflow-terminal escape
   (cancelled/terminated). The design MUST NOT offer any action the table forbids. Verify against
   the file; do not assume.
2. **"Retry" re-runs a real AI agent and spends real model credits.** The design MUST make that
   consequence visible and unambiguous before the human commits. This is the whole point of the
   screen.
3. **Retry must respect the execution capacity guard** (global cap
   `SHIPIT_DISPATCH_MAX_CONCURRENT_AGENTS`, default 2) and the zombie/timeout protections already
   built. If there is no capacity, the human must be told that plainly and offered a queued
   alternative, NOT left with a button that silently does nothing. Decide and specify what "retry"
   means when the guard denies.
4. **No raw SQL, no hand-written state mutation.** Any server-side move MUST go through
   `DurableWorkflowEngine`/`WorkItemTransitions` with the same injected policy, exactly as
   `packages/scheduler/lib/src/scheduler.dart` does for its reclaim path. (Context: a manual SQL
   write during an incident used a camelCase state and broke every scheduler tick — the transition
   path is what prevents that class of error.)
5. **Durability/idempotency.** A retry is a state transition that will dispatch work. Specify what
   happens on double-click, on refresh mid-flight, on a lost response, and on a capacity denial.
   Follow the repo's existing idempotency conventions (see the `idempotencyKey` usage in the
   scheduler and in existing workflow transitions).
6. **Plain language, existing vocabulary.** No engineer jargon in user-facing copy. The repo has an
   explicit doctrine that a quiet log / empty screen must never be indistinguishable from a healthy
   one.

## What the brief must decide and specify

a. The exact action set offered, mapped to legal transitions, and the copy for each. Consider at
   minimum: retry, abandon/cancel, and inspect-why (showing the failure reason from the
   `work_item_transition` `reason` column). Decide whether "abandon" is genuinely wanted or is scope
   creep, and justify.
b. The layout/interaction for the action panel: where it sits on the run detail page, what it shows
   about WHY it failed, and how the human confirms a retry that spends credits.
c. The client→server contract: the RPC name and shape. Note that **no server RPC currently exists to
   move a work item** — this is new surface, so specify it as such (method, params, result, error
   cases).
d. Behaviour when the capacity guard denies, and when the underlying job/execution is in a weird
   state.
e. Accessibility and the existing design-system conventions.
f. What the screen must NOT do — e.g. it must not offer a way to bypass the capacity guard, and
   must not present a retry as free.
g. The "9 parked items" problem is **OUT OF SCOPE** for this screen. Nine work items sit in
   `agent_completed`, which is NOT a terminal state, so the portal counts all 12 as "Working on it".
   That is a separate defect (stale-state/labeling) and must not be conflated with or solved by this
   screen. Note it as a follow-up only.

## Deliverable

A Design Brief in the repo's existing design-artifact location and format (inspect
`docs/engineering/dispatch/tasks/` for the established convention and follow it exactly — look at an
existing task such as `design-work-entry` for structure). Include: problem statement with the
verified evidence, scope, the action set mapped to the real transition table with file:line
citations, the RPC contract, UX/copy, error and capacity-denied behaviour, accessibility,
acceptance criteria, risks, and explicit non-goals.

Declare OWNED_PATHS (design artifacts only) and state READ_ONLY_PATHS. **Do not modify production
source under `apps/**` or `packages/**`.**

## Hard constraints on the lane

- **ZERO Docker/Compose mutating commands** — QA is LIVE and the Manager is driving it.
  `docker exec <container> <read-only command>` is permitted for reading state only.
  Never `make clean` / `make qa-down` / `make test-env-down` / `make e2e-down` / bare `down -v`.
  Reading a compose file as TEXT is the supported way to learn what a stack does.
- **Do NOT touch live database state.**