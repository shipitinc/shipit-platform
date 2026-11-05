# Dispatch — review-operator-actions (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-operator-actions
TASK_TYPE: review
FEATURE: operator actions — qa_passed->deploy advance + stranded agent_executing->reclaim
AREA: work_item_action endpoints + generated connectors + UI action surface
WORKTREE: /private/tmp/shipit-feat-operator-actions
BRANCH: feat/operator-actions
BASE_SHA: 6a4d307
HEAD_SHA_UNDER_REVIEW: 5b56608da51e72b297d355ba8dceba612c89eba9
ROUTING_CLASS: PRECISION
```

Independent read-only review of `5b56608` — `advanceToDeploy` (qa_passed->deploying + deploymentApproval decision) and `reclaimStrandedExecution` (agent_executing->agent_failed audited 'reclaim') exposed via actionContext; generated serverpod connectors (permitted artifact); client repository + operator_action_panel + copy; run_detail bloc/page wiring.

Verify rigorously:
1. The deploy action — transition(qaPassed->deploying, orchestrator, context={deploymentArtifact built from producer AgentResult via producedCommitFor}) then requestHumanDecision(deploymentApproval) -> waiting_for_human_decision. Verify the artifact context makes artifactBuilt() pass honestly (not fabricated), the producedCommitFor reuse is correct (producer's workspace.startingRevision fallback), and a completed producer AgentResult is required (no result -> not offered/notApplicable). The two-durable-step sequence: a crash between the halves leaves a gateless `deploying` item — the 'deploy' action finishes it by requestId replay or fresh intent (verify, don't just assert).
2. The reclaim — detects agent_executing + no non-terminal AgentExecution + no active job -> agent_failed audited 'reclaim' (lands at agent_failed -> retriable via existing retry). Verify the detection predicate is right (a live execution is NOT reclaimed) and the audit token rides the free-form action column correctly.
3. actionContext — the actions are only offered for the right states (deploy for qa_passed, reclaim for stranded agent_executing), not others.
4. Generated surface — endpoints.dart/protocol.yaml/client.dart/serverpod_test_tools regenerated via `serverpod generate` (the mechanical artifact is consistent with the endpoint change, not hand-edited).
5. The OperatorActionKind discovery — 'deploy'/'reclaim' ride OperatorActionRecord.action as wire tokens (closed enum, no schema change) — verify the comments + audit recording are honest.
6. Tests — the new work_item_action_endpoints_test (+520) covers deploy-offered/reclaim-offered/not-offered-for-live-execution/reclaim-then-retry — non-vacuous; the Flutter panel + bloc tests pass.
7. Gates re-run: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart analyze` (apps/server + apps/control_plane + touched), `dart run tool/run_unit_tests.dart` (apps/server), `flutter test` (apps/control_plane) — own numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` / `APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` + `HUMAN_DECISION_REQUIRED:`.
