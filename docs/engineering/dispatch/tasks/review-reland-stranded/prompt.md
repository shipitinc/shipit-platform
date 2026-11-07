# Dispatch — review-reland-stranded (PRECISION)

```yaml
MANAGER: orchestrator-main
TASK_ID: review-reland-stranded
TASK_TYPE: review
FEATURE: re-land path — `relandDeployedWorkItem` lands the produced commit for label-only `deployed` items
AREA: deploy_landing + work_item_action_endpoints + generated client
WORKTREE: /private/tmp/shipit-feat-reland
BRANCH: feat/reland-stranded-deployed
BASE_SHA: 1457603
HEAD_SHA_UNDER_REVIEW: 959bef45faeb328f7effe85145441e52bd5568c0
ROUTING_CLASS: PRECISION
```

Independent read-only review of `959bef4` — new `relandDeployedWorkItem` operator action (wire
token 'reland') + `deployRelandIsOwed`/`relandDeployedItem`/`deployLandingStampedItem` in
deploy_landing.dart; generated connectors + client method.

Verify rigorously:
1. The owed test — `deployed` AND `deployedCommit` absent is the right predicate (the five
   deployed* keys are one atomic write); re-asserted inside `relandDeployedItem` so no caller
   can re-land over a real stamp.
2. The land — `landApprovedDeployment` verbatim (resolveProducerExecution -> producedCommitFor/
   workspace.startingRevision -> merge --no-ff into repositoryPath -> merge-base --is-ancestor);
   already-ancestor -> alreadyLanded no re-merge.
3. Idempotency — ledger replay by requestId, owed-test refuses a second intent, the
   merged-but-unstamped crash window finishes via the already-landed arm. Refusals write
   nothing (notApplicable/invalidRequest/alreadyRunning).
4. The actionContext omission is honest — 'reland' deliberately NOT offered (the UI would
   misroute/dead-button without an apps/control_plane arm — verified claim, not laziness);
   invocable via the generated client. Verify it isn't sneak-exposed.
5. The shared `deployLandingStampedItem` transform — verify `maybeLandApprovedDeployment` uses
   it identically (no drift between the approve-time and re-land stamps; deployedBy differs
   honestly: 'deploy_landing_reland').
6. Tests — `deploy_reland_test.dart` (11 tests, real scratch git repo) covers owed/not-owed/
   replay/crash-window/refusals — non-vacuous.
7. Gates re-run: `dart format --set-exit-if-changed .` (root, dart pub get first), `dart
   analyze` (apps/server + touched), `dart run tool/run_unit_tests.dart` (apps/server) — own
   numbers.
Read-only; no docker, no DB. End with exactly `RESULT: APPROVE_FOR_MERGE` /
`APPROVE_WITH_NON_BLOCKING_FOLLOWUP` / `DO_NOT_MERGE` + `CORRECTION_REQUIRED:` +
`HUMAN_DECISION_REQUIRED:` — and note the flagged residual (UI arm needed to expose `reland`
via actionContext + the 'STARTED AGAIN' ledger mislabel).
