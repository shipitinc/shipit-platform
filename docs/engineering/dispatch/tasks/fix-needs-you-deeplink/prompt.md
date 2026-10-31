# Dispatch — fix-needs-you-deeplink (CLIENT, PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: fix-needs-you-deeplink
TASK_TYPE: implement
FEATURE: Home "Waiting for your approval" card deep-links to /needs-you/<id> WITHOUT ?wi= → "We could not open this decision" for ANY decision
AREA: control-plane client (Flutter)
WORKTREE: /private/tmp/shipit-fix-needs-you-link
BRANCH: fix/needs-you-deeplink
BASE_SHA: a155ef5
OWNED_PATHS:
  - apps/control_plane/lib/**
  - apps/control_plane/test/**
READ_ONLY_PATHS:
  - apps/server/lib/src/endpoints/home_endpoints.dart
  - apps/server/lib/src/services/control_plane_service.dart
  - packages/control_plane_client/lib/src/protocol/**
PROHIBITED_PATHS:
  - apps/server/** (server already fixed on fix/pending-decision-card)
  - packages/**/lib/src/generated/** , apps/control_plane/lib/src/generated/**
  - .agents/ .claude/ .opencode/ .junie/** AGENTS.md docs/adr/** .decisions/**
VALIDATION_COMMANDS:
  - dart format --output=none --set-exit-if-changed .
  - flutter analyze            # apps/control_plane
  - flutter test               # apps/control_plane
ROUTING_CLASS: PRECISION
```

## Confirmed client bug (server-lane discovery, human-reported on QA)

`apps/control_plane/lib/features/home/home_page.dart:538,871` — the Home "Waiting for your
approval" card navigates `/needs-you/<decisionId>` **without `?wi=`**. `DecisionDetailBloc`/
`inspectDecision` then passes the decisionId as workItemId → `readWorkItem` throws →
"We could not open this decision" — for EVERY decision, not just cancelled ones.

The needs-you card and run-detail card pass `?wi=${workItemId}` and render correctly (GateSummary
already carries `workItemId` — append it in the Home card's route the same way).

## Task

1. Fix the Home card navigation to append `?wi=${gate.workItemId}` (whatever the GateSummary
   field is actually named — check the model).
2. Audit ALL other `/needs-you/:decisionId` navigation sites in the client for the same missing
   `?wi=` (needs_you_page, run_detail, anywhere else routing to that path) — fix every one.
3. Read-only rendering for `status == 'cancelled'` decisions: a voided decision opened via `?wi=`
   currently renders "WAITING FOR YOU" with a live submit panel (client treats `choice == null`
   as unresolved). Render cancelled decisions read-only — the server already ships
   `status: 'cancelled'` on the wire.
4. Regression tests: Home card builds the `?wi=` route; a cancelled decision renders read-only
   (no live submit affordance).
5. If GateSummary/the client model doesn't carry workItemId, stop and report
   IMPLEMENTATION_BLOCKED with the exact contract gap.

## Rules

- New commits on `fix/needs-you-deeplink`; no push. No docker, no DB.
- Report per subtask-report.md: `RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`, HEAD_SHA,
  `READY_FOR_INDEPENDENT_REVIEW: YES|NO`.
