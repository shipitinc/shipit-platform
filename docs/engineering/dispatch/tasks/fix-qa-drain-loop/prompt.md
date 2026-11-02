# Dispatch — fix-qa-drain-loop (F-245)

```yaml
MANAGER: orchestrator-main
TASK_ID: fix-qa-drain-loop
TASK_TYPE: implement
FEATURE: qa.drain loops forever on review_approved items — requestHumanDecision needs a nonexistent reviewApproved→waitingForHumanDecision edge
AREA: QA drain / transition table
WORKTREE: /private/tmp/shipit-fix-drain-loop
BRANCH: fix/qa-drain-loop
BASE_SHA: HEAD
OWNED_PATHS: [apps/server/lib/src/qa/**, packages/workflow_engine/**, packages/workflow_store/**]
READ_ONLY_PATHS: [packages/platform_contracts/**, packages/scheduler/**, apps/server/lib/server.dart]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/**]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root, dart pub get first), dart analyze (each touched package), dart test (each touched package), dart run tool/run_unit_tests.dart (apps/server if touched)]
ROUTING_CLASS: PRECISION
```

## Confirmed defect (live, verbatim log)

Every tick the drain evaluates `WI-feature-1791823723502264` + `defect-DEF-1791685024220546`
(both `review_approved` since Oct 31), settles them `not_pass` (contract gates
`triage-classification-admitted`, `triage-evidence-grounded` / `intake-structured-result-admitted`
fail), then `requestHumanDecision` fails with:
`Transition from WorkItemState.reviewApproved to WorkItemState.waitingForHumanDecision is not allowed`
→ `qa.drain.decision_refused` ~60/15min, forever. The settle records intent but the item never
moves — the transition `reviewApproved → qaFailed` also may not exist (verify); the item stays
`review_approved` and the loop repeats.

## Root-cause space — decide honestly, don't pick the easy fix if it's wrong

Two candidate framings, and the correct fix may be either or both:

1. **Candidate selection**: the drain pulls items whose contract hasn't reached a terminal
   verdict — including `review_approved` items that are arguably PAST the QA lane. If an item is
   `review_approved`, re-evaluating its contract and demanding a waiver decision re-litigates an
   approved item — the drain's candidate query may need a state filter (which states are
   legitimately in scope?). BUT: if a `review_approved` item's contract genuinely fails, is that
   a real signal the platform wants to swallow, or a mis-evaluation? Investigate what
   `review_approved` means for QA (the work WAS approved — should a failing contract still gate it?).
2. **The missing edge(s)**: if `review_approved` items ARE legitimately in scope (a contract can
   outlive the review verdict), then the waiver path needs `reviewApproved → waitingForHumanDecision`
   and/or `reviewApproved → qaFailed` edges — investigate the transition table's intent
   (work_item_transitions.dart) and whether the drain's assumption (item can reach
   waitingForHumanDecision from any pre-decision state) holds.

Also investigate: WHY do the triage contracts keep failing `triage-classification-admitted` /
`triage-evidence-grounded` / `intake-structured-result-admitted` — are those gate names
satisfiable (does triage emit what they check)? If the contract is mis-specified the items are
permanently undrainable and exclusion is cosmetic. Report whether the gates are satisfiable.

## Required

1. The loop stops — no per-tick decision_refused on the same items.
2. The fix preserves the drain's honesty: a genuinely failing contract still gets a decision
   raised where the transition table admits it; a state that legitimately can't get a decision
   is handled deliberately (skip-with-reason / the correct edge), not silently.
3. Regression test: a `review_approved` item with a failing contract does not produce the
   refusal loop (either skipped with reason or transitions correctly); a normal `qa_failed`
   path unchanged.
4. Report the chosen root cause + whether the triage gates are satisfiable.

## Rules
New commits; no push; no docker/DB; nothing outside OWNED_PATHS — IMPLEMENTATION_BLOCKED if the
correct fix needs apps/server composition outside `src/qa/**`. Report per subtask-report.md:
`RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`, HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`,
and `ROOT CAUSE CHOSEN:` + `TRIAGE GATES SATISFIABLE:`.
