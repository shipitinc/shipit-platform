# Dispatch — review-qa-passed-auto-deploy (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-qa-passed-auto-deploy
TASK_TYPE: review
FEATURE: qa_passed auto-advance to deploying + deploymentApproval -> Needs You
AREA: deploy_gate_sweep + shared deploy_advance
WORKTREE: /private/tmp/shipit-feat-qa-deploy
BRANCH: feat/qa-passed-auto-deploy
BASE_SHA: 4eb53c4
HEAD_SHA_UNDER_REVIEW: 7df90d7ffcd99b785dbe356b2e193a93f2a09bbd
ROUTING_CLASS: PRECISION
```

Independent read-only review of `7df90d7` — new `runDeployGateSweep`
(apps/server/lib/src/deploy/deploy_gate_sweep.dart) wired into the tick after the QA drain:
for each `qa_passed` item it fires `qaPassed->deploying` (artifact from the producer's
AgentResult) then `requestHumanDecision(deploymentApproval)` -> `waiting_for_human_decision`.
Shared logic extracted to `deploy_advance.dart` (used by both the sweep and `advanceToDeploy`).

Verify rigorously:
1. The sweep's advance — `qaPassed->deploying` (orchestrator-actor via `deploy-sweep`) with a
   REAL `deploymentArtifact` from the producer's durable AgentResult (`producedCommitFor` +
   `workspace.startingRevision` fallback); no fabricated artifact. The artifact build and the
   `requestHumanDecision(deploymentApproval)` are the same shared logic `advanceToDeploy` uses
   (extracted verbatim to `deploy_advance.dart` — verify no drift between the two call sites).
2. Two-durable-step crash-safety — a gateless `deploying` item (interrupted advance, whoever
   started it) is FINISHED not re-transitioned; idempotent on re-tick; the rejected-transition
   idempotency-key concern is handled (the `deploy-sweep:<id>:advance:v<version>` scoping the
   implementer described).
3. Deferral honesty — an item with no completed producer result or a live job is deferred, not
   advanced on a fabricated artifact or failed.
4. The Needs You surface — `pendingDecisions` (real store) surfaces the item after the sweep.
5. The refactor — `advanceToDeploy` now shares `deploy_advance.dart`; verify the operator path
   is behavior-identical (no drift) and the sweep uses the same durable write.
6. Tests — `deploy_gate_sweep_test.dart` (12 tests) covers the 4 mandated regressions +
   deferral + containment + the Needs You surface — non-vacuous.
7. Gates re-run: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart
   analyze` (apps/server + touched), `dart run tool/run_unit_tests.dart` (apps/server) — own
   numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:`.
