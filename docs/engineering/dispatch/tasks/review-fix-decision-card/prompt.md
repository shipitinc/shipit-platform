# Dispatch — review-fix-decision-card

```yaml
MANAGER: orchestrator-main
TASK_ID: review-fix-decision-card
TASK_TYPE: review
FEATURE: "Needs your approval" card links to cancelled decision — server fix
AREA: control-plane decision surfacing (server)
WORKTREE: /private/tmp/shipit-fix-decision-card
BRANCH: fix/pending-decision-card
BASE_SHA: 226ceb8
HEAD_SHA_UNDER_REVIEW: 57655fbed406c95614fdf0c387a7470870572a7c
ROUTING_CLASS: STANDARD
```

Independent read-only review. Verify at `57655fb` (diff vs 226ceb8: home_endpoints.dart,
control_plane_service.dart, human_decision.dart, new home_pending_decisions_test.dart):
1. `pendingDecisions` now resolves `item.blockingHumanDecisionId` + surfaces only while
   `status.isOpen` — verify the pointer resolution and that a stale/terminal pointer yields
   nothing (not a wrong decision).
2. `HumanDecisionStatus.isTerminal`/`isOpen` semantics — cancelled is terminal-but-not-resolved;
   `isResolved` deliberately unchanged — verify the engine replay callers weren't widened and
   the 3 migrated `!isResolved`→`isOpen` sites (waitingOnYou, pendingBaselineDecisionId,
   openLifecycleGate) are semantically correct (esp. openLifecycleGate's oldest-first read).
3. `readDecisionsForWorkItem` newest-first — verify this doesn't break callers expecting ASC
   (esp. `openLifecycleGate` which deliberately reads oldest).
4. The 7 tests are non-vacuous (either-order selection, stale pointers, overview agreement).
5. Re-run gates yourself: format root, analyze apps/server + platform_contracts,
   run_unit_tests apps/server, dart test platform_contracts — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`RESULT: APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `RESULT: DO_NOT_MERGE` +
`CORRECTION_REQUIRED:` + `HUMAN_DECISION_REQUIRED:`.
