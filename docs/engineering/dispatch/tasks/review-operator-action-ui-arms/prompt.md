# Dispatch — review-operator-action-ui-arms (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-operator-action-ui-arms
TASK_TYPE: review
FEATURE: expose reland + reroute in actionContext + UI arms (F-260 + F-262)
AREA: work_item_action_endpoints actionsFor + run_detail bloc/copy/panel + repository
WORKTREE: /private/tmp/shipit-feat-ui-arms
BRANCH: feat/operator-action-ui-arms
BASE_SHA: d28bb9a
HEAD_SHA_UNDER_REVIEW: 79675d79ceb8c9961fe688a44a166d3727d74f93
ROUTING_CLASS: PRECISION
```

Independent read-only review of `79675d7` — `actionContext` offers 'reland' (deployed +
deployedCommit absent + no active job) and 'reroute' (any deployed + no active job); bloc
switch arms route to relandDeployedWorkItem/rerouteToImplementation; per-action copy +
OperatorActionPanel third mode; priorActions ledger labels (reland='LANDED AFTERWARDS',
reroute='SENT BACK', retry='STARTED AGAIN', etc.).

Verify rigorously:
1. The offer conditions are honest and match the write paths' guards — 'reland' only when
   deployRelandIsOwed (deployed + stamp absent); 'reroute' on any deployed; both withheld on
   live job (the endpoints refuse alreadyRunning — offering would dead-button). An unstamped
   item offers [reland, reroute] in that order.
2. The offers sit behind durable-fact flags defaulting false (the implementer's discovery:
   operator_retry_limit_test enumerates every state with default flags — an ungated offer
   breaks AC-1/AC-2). Verify relandOwed/deployedIdle are computed from durable facts and the
   deployed-pair branch can't fire on non-deployed states.
3. Bloc routing — 'reland'→relandDeployedWorkItem, 'reroute'→rerouteToImplementation before
   `_ =>` fallthrough; unknown actions still hit stopFailedWorkItem; repository methods call
   the right generated client methods.
4. Copy + panel — third mode keyed on OFFERED actions (not state); per-action label/
   consequence/accent in the confirm strip; blank-reason gate; announcements for both.
5. Ledger labels — per-action labels are honest; unknown ids render their own token not a
   fabricated word; 'STARTED AGAIN' only on retry.
6. Tests — server offer tests (both actions × stamp/job shapes + state scoping), bloc routing,
   copy groups, panel contexts, ledger labels — non-vacuous; run key files.
7. Gates re-run: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart
   analyze` (apps/server + apps/control_plane), `dart run tool/run_unit_tests.dart`
   (apps/server), `flutter test` (apps/control_plane, +571) — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:` — note the flagged residual (work_item_action_view.yaml closed-set
comment + generated mirrors need a generated-path lane — same F-255 class).
