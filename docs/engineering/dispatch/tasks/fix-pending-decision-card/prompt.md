# Dispatch — fix-pending-decision-card

```yaml
MANAGER: orchestrator-main
TASK_ID: fix-pending-decision-card
TASK_TYPE: implement
FEATURE: "Needs your approval" card links to a cancelled decision → "We could not open this decision"
AREA: control-plane decision surfacing
WORKTREE: /private/tmp/shipit-fix-decision-card
BRANCH: fix/pending-decision-card
BASE_SHA: 226ceb8
OWNED_PATHS:
  - apps/server/lib/src/endpoints/home_endpoints.dart
  - apps/server/lib/src/services/control_plane_service.dart
  - apps/server/lib/src/persistence/**
  - apps/server/test/**
  - packages/platform_contracts/lib/src/enums/human_decision.dart
READ_ONLY_PATHS:
  - apps/control_plane/lib/features/needs_you/**
  - packages/scheduler/**
PROHIBITED_PATHS:
  - apps/control_plane/lib/** (server-side fix only — if the client itself is wrong,
    stop and report IMPLEMENTATION_BLOCKED)
  - .agents/ .claude/ .opencode/ .junie/** AGENTS.md docs/adr/** .decisions/**
  - **/generated/**
VALIDATION_COMMANDS:
  - dart format --output=none --set-exit-if-changed .
  - dart analyze                                       # apps/server + platform_contracts
  - dart run tool/run_unit_tests.dart                  # apps/server
  - dart test                                          # packages/platform_contracts
ROUTING_CLASS: STANDARD
```

## Confirmed bug (live on QA, human-reported)

`pendingDecisions` (`apps/server/lib/src/endpoints/home_endpoints.dart:215-256`) selects
`itemDecisions.where((d) => !d.isResolved && d.blocking == true).firstOrNull`.
`HumanDecisionStatus.isResolved` is `this == resolved` — `cancelled` is NOT resolved, so a voided/
cancelled decision counts as pending and `firstOrNull` serves it instead of the real pending one.

Live evidence: work item `defect-DEF-1791685264570406` (`waiting_for_human_decision`) has TWO
blocking decisions — `dec-hn7h7daum6-2atjhe` (cancelled, voided by migration 20261014210000000)
and `dec-hn9zf6jgzn-158lz0o` (pending, the item's actual `blockingHumanDecisionId`). The card links
to the cancelled id; the detail page refuses it → "We could not open this decision."

## Required fix — choose the structurally correct shape, don't patch a symptom

1. `pendingDecisions` must surface the decision the item is ACTUALLY blocked on — candidates:
   (a) filter `d.status == HumanDecisionStatus.pending && d.blocking` (status = awaiting an answer);
   (b) resolve the decision named by `item.blockingHumanDecisionId` directly (the item itself names
   its blocker — most precise). Inspect `readHumanDecisionsForWorkItem` ordering too — `firstOrNull`
   on the wrong order is a second latent hazard.
2. Audit `HumanDecisionStatus.isResolved` callers (`!isResolved` = "open" elsewhere:
   `control_plane_service.dart:518,567`, `recentDecisions` at home_endpoints:184). Decide whether
   `cancelled` should count as resolved centrally (voided decisions ARE terminal — arguably they
   also belong in "Already decided" as audit) vs the minimal pendingDecisions filter. Pick the
   correct semantic; document the choice.
3. Regression test: a work item with a cancelled blocking decision + a pending blocking decision —
   the pending one surfaces on `pendingDecisions`, never the cancelled.
4. The detail-page "could not open" behavior for a genuinely cancelled decision: evaluate whether
   it should render read-only (audit value) or the refusal is correct — report the finding; fix it
   only if it's a small adjacent correction within owned paths.

## Rules

- New commits on `fix/pending-decision-card`; no push. No docker, no DB.
- Report per subtask-report.md: `RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`, HEAD_SHA,
  `READY_FOR_INDEPENDENT_REVIEW: YES|NO`.
