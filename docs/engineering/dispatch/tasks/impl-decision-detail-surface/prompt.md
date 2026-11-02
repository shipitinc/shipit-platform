# Dispatch — impl-decision-detail-surface

```yaml
MANAGER: orchestrator-main
TASK_ID: impl-decision-detail-surface
TASK_TYPE: implement
FEATURE: Decision-detail page surfaces the review verdict, findings, artifact under review, full context, and real option consequences — not just the truncated defect description
AREA: control_plane decision detail UI (+ detail-endpoint view if the payload strips metadata)
WORKTREE: /private/tmp/shipit-decision-surface
BRANCH: feat/decision-detail-surface
BASE_SHA: HEAD
OWNED_PATHS: [apps/control_plane/lib/features/decision_detail/**, apps/control_plane/lib/data/**, packages/control_plane_client/lib/src/protocol/**]
READ_ONLY_PATHS: [apps/server/lib/src/endpoints/work_item_action_endpoints.dart, apps/server/lib/src/endpoints/home_endpoints.dart]
PROHIBITED_PATHS: [apps/server/** (except adding a view field IF the detail payload already omits it — escalate if more), .agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/**]
VALIDATION_COMMANDS: [dart format --output=none --set-exit-if-changed . (root — dart pub get first on fresh worktree), dart analyze (apps/control_plane, control_plane_client), flutter test (apps/control_plane), dart test (control_plane_client)]
ROUTING_CLASS: PRECISION
```

## The gap (verified live — human confirmed the page's "WHAT THIS IS ABOUT" is ellipsized and the verdict/findings are absent)

The decision-detail page (`dec-hnrsbbnk2c-d96769`, engineering_review type) renders only the
truncated defect description + generic option text. The decision's `metadataJson` ALREADY carries
`engineeringReviewResult` (verdict `approved_with_minor_findings`, findings[] with severity/
category/evidence/requiredCorrection/affectedSurface, revisionId, reviewExecutionId) — verified
directly in `human_decision.metadataJson` on QA. The detail view just doesn't surface it.

## Task

1. VERIFY first: does the decision-detail endpoint/view already serialize `metadataJson` /
  `engineeringReviewResult`? (`work_item_action_endpoints.dart:1788/1885` already parses it —
  check whether it reaches the client view or is stripped there.) If it reaches the client → pure
  client rendering; if stripped → add the field to the view (small; escalate if it needs more).
2. Client renders decisionType-aware sections:
   - **Full context** — complete description + the item TITLE as header (currently only the
     truncated description body shows).
   - **Review verdict block** — verdict badge (approved_with_minor_findings / approved / rejected)
     + findings as cards: severity, category, evidence quote, requiredCorrection, affectedSurface.
   - **The artifact under review** — the revisionId / files touched / reviewExecutionId so the
     decider sees WHAT they're approving.
   - **Real option consequences** — approve/reject/rework map to actual outcomes (lands the fix /
     records rejection / sends back for correction with the finding), not three identical
     "Records your decision" strings.
3. **Generalize as a decisionType→renderer map** — engineering_review renders the review result;
   leave a typed extension point so future decision types (deploy gates, escalations) render their
   own context — NOT a one-off hardcode for this card.
4. Cancelled decisions still render read-only (the earlier fix — don't regress it).
5. Tests: the review-result section renders verdict+findings; non-review decisionTypes still
   render the generic path; option-consequence text is per-option.

## Rules
New commits; no push; no docker/DB; nothing outside OWNED_PATHS — report IMPLEMENTATION_BLOCKED if
the endpoint genuinely can't surface the data. Report per subtask-report.md:
`RESULT: IMPLEMENTED` / `IMPLEMENTATION_BLOCKED`, HEAD_SHA, `READY_FOR_INDEPENDENT_REVIEW:`,
and `SERVER CHANGE NEEDED: yes/no`.
