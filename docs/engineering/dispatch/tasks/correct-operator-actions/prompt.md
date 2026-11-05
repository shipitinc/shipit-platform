# Dispatch — correct-operator-actions (correction lane for DO_NOT_MERGE on 5b56608)

```yaml
MANAGER: orchestrator-main
TASK_ID: correct-operator-actions
TASK_TYPE: correct
FEATURE: correction — operator-actions DO_NOT_MERGE findings (Flutter coverage + contract-doc invariant)
WORKTREE: /private/tmp/shipit-feat-operator-actions
BRANCH: feat/operator-actions
BASE_SHA: 6a4d307
HEAD_SHA: 5b56608da51e72b297d355ba8dceba612c89eba9
OWNED_PATHS: [apps/control_plane/lib/**, apps/control_plane/test/**, packages/workflow_store/lib/src/**]
READ_ONLY_PATHS: [apps/server/lib/**, packages/workflow_engine/**]
PROHIBITED_PATHS: [.agents/ .claude/ AGENTS.md docs/adr/** .decisions/** **/generated/**]
ROUTING_CLASS: PRECISION
```

Independent review found 2 MEDIUMs + actionable LOWs — correct them on top of `5b56608`,
preserve the reviewed HEAD (new commits only, no rewrite):

MEDIUM 1 — zero Flutter-side coverage. Add tests per repo convention:
  - `OperatorActionPanel` widget: offered actions render with deploy vs reclaim copy; confirm
    strip requires non-blank reason; requestId minted once per confirmation + reused on submit
    retry; Escape cancels.
  - `operatorActionAnnouncementFor`: 'deploy'/'reclaim' + 'accepted' return the new sentences;
    all other outcomes delegate to the existing vocabulary.
  - `run_detail_bloc` routing: action 'deploy' -> advanceToDeploy, 'reclaim' ->
    reclaimStrandedExecution, unknown -> stopFailedWorkItem.
  Precedents: failed_work_item_action_panel_test.dart, review_repair_affordance_test.dart,
  operator_action_copy_test.dart, run_detail_bloc_test.dart.

MEDIUM 2 — contract-doc invariant now false. `WorkflowStore.appendOperatorAction`
  (packages/workflow_store/lib/src/store/workflow_store.dart:39-42) and `OperatorActionRecord`
  (operator_action_record.dart:36-40) both assert no append exists outside DurableWorkflowEngine
  .transition's transaction — the interrupted-advance path in advanceToDeploy
  (work_item_action_endpoints.dart:1010-1024) appends standalone. Amend BOTH docs to name the
  gateless-deploying exception + its audit-first convergence rule (or route the append through a
  transaction that verifies the item is still gateless-deploying — implementer picks the honest
  option; doc-amend is likely correct since the behavior is deliberate).

LOWs to also address:
  - Doc drift on the closed-set comments (OperatorActionRecord.action "'retry'|'stop'",
    run_detail_event.dart, work_item_action_view.yaml) — extend for 'deploy'/'reclaim'.
  - producedCommitFor's CommitProduced arm unexercised — add a stamped-producer test asserting
    commitBasis 'producedCommit'.

Gates: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart analyze`
(apps/control_plane + touched), `flutter test` (apps/control_plane), `dart test`
(packages/workflow_store if touched). New commits on the existing branch; no push; no docker/DB.
Report per subtask-report.md: `RESULT: CORRECTED` / `CORRECTION_BLOCKED`, HEAD_SHA,
`READY_FOR_FOCUSED_REVIEW:`.
