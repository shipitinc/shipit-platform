# Dispatch — fix-infra-decision-resolve (F-250)

```yaml
MANAGER: orchestrator-main
TASK_ID: fix-infra-decision-resolve
TASK_TYPE: implement
FEATURE: resolveDecision 500s on system:provider-health decisions — the endpoint can't map a non-work-item decision
AREA: decision resolution endpoint / view mapping
WORKTREE: /private/tmp/shipit-fix-infra-decision
BRANCH: fix/infra-decision-resolve
BASE_SHA: HEAD
OWNED_PATHS: [apps/server/lib/src/endpoints/**, apps/server/lib/src/services/**, packages/control_plane_client/lib/src/views/**]
READ_ONLY_PATHS: [packages/workflow_engine/**, packages/workflow_store/**]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/**]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root, dart pub get first), dart analyze (apps/server + touched packages), dart run tool/run_unit_tests.dart (apps/server)]
ROUTING_CLASS: PRECISION
```

## Confirmed defect (live)

`POST /workflowEndpoints/resolveDecision` with `decisionId=hd-provider-openrouter-...` (a
`system:provider-health` infrastructure_decision) returns `Internal Server Error`. The endpoint
builds `ResolveDecisionView(workItem: UiViewMappers.workItemView(workItem), ...)` — the
`system:provider-health` "work item" isn't a real work item, so the view mapping throws. ~28
stale `hd-all-down-*` + `hd-provider-*` infrastructure_decisions sit pending forever — they
can't be resolved via the sanctioned endpoint (they pile up as noise).

## Task — investigate the 500 then fix honestly

1. Reproduce the exact throw: `ResolveDecisionView`/`workItemView`/`resolveHumanDecision` on a
   `system:provider-health` workItemId — WHERE does it fail (the view mapping? the engine's
   resolve for a system item? something else)?
2. Fix honestly:
   - If `resolveHumanDecision` genuinely resolves the decision (engine-side) but the VIEW build
     fails on the system item — fix the view/mapper to handle non-work-item decisions (return a
     system-decision view, or the decision without a work-item view, or the correct shape).
   - If the ENGINE can't resolve a system-work-item decision — that's the deeper bug; the
     provider-health decisions need a resolution path (the health monitor probably resolves
     them on recovery itself, but the operator path should work too).
   Verify which it is — a fix that patches the view while the decision stays unresolved isn't
   a fix.
3. Verify the ~28 stale `hd-all-down-*` decisions CAN then be resolved as `acknowledge` (the
   resolution path works end-to-end for system items).
4. Regression test: resolveDecision on a `system:provider-health` decision resolves + returns a
   valid view (no 500); a normal work-item decision unchanged.
5. Report the root cause + fix + whether infra decisions auto-resolve on provider recovery too
   (is the pending stack a UI defect only, or are they meant to self-resolve?).

## Rules
New commits; no push; no docker/DB writes (read-only DB inspection OK); nothing outside
OWNED_PATHS — IMPLEMENTATION_BLOCKED if it needs packages outside owned paths or composition
outside them. Report per subtask-report.md: `RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`,
HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`, `ROOT CAUSE:`, `AUTO-RESOLVES-ON-RECOVERY:`.
