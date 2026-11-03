# Dispatch — review-infra-decision-resolve (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-infra-decision-resolve
TASK_TYPE: review
FEATURE: resolveDecision 500s on system:provider-health — routes system-scope decisions to store-level resolve
AREA: decision resolution endpoint / system-scope decisions
WORKTREE: /private/tmp/shipit-fix-infra-decision
BRANCH: fix/infra-decision-resolve
BASE_SHA: 18172c6
HEAD_SHA_UNDER_REVIEW: ccb6538135d21382c5a78974de77b3d69a113409
ROUTING_CLASS: PRECISION
```

Independent read-only review of `ccb6538` — the implementer's diagnosis: TWO throw sites before
any view build — (1) `HumanDecisionChoice.fromWire('acknowledge')` throws FormatException (the
enum lacks the infra option vocabulary), (2) `DurableWorkflowEngine.resolveHumanDecision` calls
`readWorkItem('system:provider-health')` → WorkItemNotFound (system-scope is a decision
namespace, not a real work item). Fix: `ControlPlaneService.resolveDecision(raw String choice)`
routes system-scoped decisions to `_resolveSystemScopeDecision` — a store-level resolve that
validates the answer against the decision's own option menu (refusal writes nothing), persists
status=resolved + resolvedOptionId + signature (choice NULL — the enum lacks the vocabulary);
work-item path unchanged. `ResolveDecisionView.workItem` non-nullable → `systemScopeWorkItemView`
projects state:'system'.

Verify rigorously:
1. The mechanism — the router: how does it decide system-vs-work-item (the `system:` prefix?
   the missing work_item row?). Verify the system path validates the answer against the
   decision's own optionsJson (an unoffered answer is refused with nothing written), persists
   resolvedOptionId + decider/rationale/signature honestly, and is idempotent (replay an
   already-resolved decision returns the stored record, doesn't re-write).
2. The view — `systemScopeWorkItemView` projects state:'system' (deliberately not a WorkItemState
   wire value) — verify ResolveDecisionView still satisfies the wire contract (workItem
   non-nullable — does a 'system' state render sanely in the UI or does it break a mapper on
   the client side?).
3. Work-item path unchanged — the resolveHumanDecision engine path for real items is byte-
   identical (fromWire + verdict guards + scope grant + handoff all intact).
4. The residual disclosures — inspect/listDecisions/jobsForWorkItem still 500 on system items;
   DecisionView lacks resolvedOptionId on the wire; HumanDecisionChoice lacks the infra
   vocabulary — are these honestly disclosed as follow-ups not silently left?
5. AUTO-RESOLVES-ON-RECOVERY: NO claim — on recovery the monitor removes the in-memory ticket,
   nothing writes resolution to the durable rows — verify (are the ~28 stale decisions genuinely
   meant to be operator-acknowledgements, not self-resolving?).
6. Tests — system_scope_resolve_decision_test (5) covers both ticket shapes resolve end-to-end,
   replay idempotent, refusal writes nothing, work-item path unchanged — non-vacuous.
7. Gates re-run: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart analyze`
   (apps/server), `dart test` the new test + `dart run tool/run_unit_tests.dart` (apps/server).
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:`.
